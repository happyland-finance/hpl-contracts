pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IRewardDistributor.sol";
import "../lib/BlackholePreventionOwnable.sol";
import "../interfaces/IMint.sol";

contract RewardDistributor is Initializable, BlackholePreventionOwnable, IRewardDistributor {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct VestingInfo {
        uint256 unlockedFrom;
        uint256 unlockedTo;
        uint256 releasedAmount;
        uint256 totalAmount;
    }
    uint256 public hplVestingPeriod = 10 days;
    uint256 public hpwVestingPeriod = 3 days;
    mapping(address => uint256) public vestingPeriod;
    address public devAddress; //receive 10% reward

    IERC20 public hpl;
    IERC20 public hpw;
    uint256 public totalHPLDistributed = 0;
    uint256 public totalHPWDistributed = 0;

    //user => token => vesting info
    mapping(address => mapping (address => VestingInfo)) public vestings;
    mapping(address => bool) public lockers;

    event Lock(address token, address user, uint256 amount);
    event Unlock(address token, address user, uint256 amount);
    event SetLocker(address locker, bool val);

    function initialize(address _devAddress, address _hpl, address _hpw, uint256 _hplVesting, uint256 _hpwVesting)
        external
        initializer
    {
        devAddress = _devAddress;
        hpl = IERC20(_hpl);
        hpw = IERC20(_hpw);
        hplVestingPeriod = _hplVesting > 0 ? _hplVesting : hplVestingPeriod;
        hpwVestingPeriod = _hpwVesting > 0 ? _hpwVesting : hpwVestingPeriod;
        vestingPeriod[_hpl] = hplVestingPeriod;
        vestingPeriod[_hpw] = hpwVestingPeriod;
    }

    function setDevAddress(address _devAddress) external onlyOwner {
        devAddress = _devAddress;
    }

    function setVestingPeriod(uint256 _hplVesting, uint256 _hpwVesting) external onlyOwner {
        hplVestingPeriod = _hplVesting;
        hpwVestingPeriod = _hpwVesting;
        vestingPeriod[address(hpl)] = hplVestingPeriod;
        vestingPeriod[address(hpw)] = hpwVestingPeriod;
    }

    function setLockers(address[] memory _lockers, bool val)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _lockers.length; i++) {
            lockers[_lockers[i]] = val;
            emit SetLocker(_lockers[i], val);
        }
    }

    function unlock(address _addr) public {
        (uint256 unlockableHPL, uint256 unlockableHPW) = getUnlockable(_addr);
        if (unlockableHPL > 0) {
            vestings[_addr][address(hpl)].releasedAmount = vestings[_addr][address(hpl)].releasedAmount.add(unlockableHPL);
            if (unlockableHPL < hpl.balanceOf(address(this))) {
                hpl.safeTransfer(_addr, unlockableHPL);
            } else {
                hpl.safeTransfer(_addr, hpl.balanceOf(address(this)));
            }
            emit Unlock(address(hpl), _addr, unlockableHPL);
            uint256 devReward = unlockableHPL * 10 / 100;
            if (devReward < hpl.balanceOf(address(this))) {
                hpl.safeTransfer(devAddress, devReward);
            } else {
                hpl.safeTransfer(devAddress, hpl.balanceOf(address(this)));
            }
        }

        if (unlockableHPW > 0) {
            vestings[_addr][address(hpw)].releasedAmount = vestings[_addr][address(hpw)].releasedAmount.add(unlockableHPL);
            uint256 devReward = unlockableHPW * 10 / 100;
            IMint(address(hpw)).mint(_addr, unlockableHPW);
            IMint(address(hpw)).mint(devAddress, devReward);
            emit Unlock(address(hpw), _addr, unlockableHPW);
        }
    }

    function distributeReward(address _addr, uint256 _hplAmount, uint256 _hpwAmount) external override{
        //we add this check for avoiding too much vesting
        require(lockers[msg.sender], "only locker can lock");

        unlock(_addr);

        if (_hplAmount > 0) {
            totalHPLDistributed += _hplAmount;
            VestingInfo storage vesting = vestings[_addr][address(hpl)];

            vesting.unlockedFrom = block.timestamp;
            vesting.unlockedTo = block.timestamp.add(hplVestingPeriod);
            vesting.totalAmount = vesting.totalAmount.add(_hplAmount);
            emit Lock(address(hpl), _addr, _hplAmount);
        }

        if (_hpwAmount > 0) {
            totalHPWDistributed += _hpwAmount;
            VestingInfo storage vesting = vestings[_addr][address(hpw)];

            vesting.unlockedFrom = block.timestamp;
            vesting.unlockedTo = block.timestamp.add(hpwVestingPeriod);
            vesting.totalAmount = vesting.totalAmount.add(_hpwAmount);
            emit Lock(address(hpw), _addr, _hpwAmount);
        }
    }

    function getUnlockable(address _addr) public view returns (uint256 _unlockableHPL, uint256 _unlockableHPW) {
        return (computeUnlockableForVesting(_addr, address(hpl)), computeUnlockableForVesting(_addr, address(hpw)));
    }

    function computeUnlockableForVesting(address _addr, address _token) public view returns (uint256) {
        VestingInfo memory vesting = vestings[_addr][_token];
        if (vesting.totalAmount == 0) {
            return 0;
        }

        if (vesting.unlockedFrom > block.timestamp) return 0;

        uint256 period = vesting.unlockedTo.sub(vesting.unlockedFrom);
        uint256 timeElapsed = block.timestamp.sub(vesting.unlockedFrom);

        uint256 releasable = timeElapsed.mul(vesting.totalAmount).div(period);
        if (releasable > vesting.totalAmount) {
            releasable = vesting.totalAmount;
        }
        return releasable.sub(vesting.releasedAmount);
    }

    function getLockedInfo(address _addr) external view returns (uint256 _hplLocked, uint256 _hplReleasable, uint256 _hpwLocked, uint256 _hpwReleasable) {
        (_hplReleasable, _hpwReleasable) = getUnlockable(_addr);
        _hplLocked = vestings[_addr][address(hpl)].totalAmount.sub(vestings[_addr][address(hpl)].releasedAmount);
        _hpwLocked = vestings[_addr][address(hpw)].totalAmount.sub(vestings[_addr][address(hpw)].releasedAmount);
    }
}

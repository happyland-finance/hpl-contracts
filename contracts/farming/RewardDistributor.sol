pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../interfaces/IRewardDistributor.sol";
import "../lib/BlackholePreventionOwnableUpgradeable.sol";
import "../interfaces/IMint.sol";
import "../lib/Upgradeable.sol";

contract RewardDistributor is
    Upgradeable,
    BlackholePreventionOwnableUpgradeable,
    IRewardDistributor
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct VestingInfo {
        uint256 unlockedFrom;
        uint256 unlockedTo;
        uint256 releasedAmount;
        uint256 totalAmount;
    }
    uint256 public hplVestingPeriod;
    uint256 public hpwVestingPeriod;
    mapping(address => uint256) public vestingPeriod;
    address public devAddress; //receive 10% reward

    IERC20Upgradeable public hpl;
    IERC20Upgradeable public hpw;
    uint256 public totalHPLDistributed;
    uint256 public totalHPWDistributed;

    //user => token => vesting info
    mapping(address => mapping(address => VestingInfo)) public vestings;
    mapping(address => bool) public lockers;

    bool public enableVesting;

    event Lock(address token, address user, uint256 amount);
    event Unlock(address token, address user, uint256 amount);
    event SetLocker(address locker, bool val);

    function initialize(
        address _devAddress,
        address _hpl,
        address _hpw,
        uint256 _hplVesting,
        uint256 _hpwVesting,
        address _locker
    ) external initializer {
        initOwner();

        hplVestingPeriod = 10 days;
        hpwVestingPeriod = 3 days;

        enableVesting = false;

        devAddress = _devAddress;
        hpl = IERC20Upgradeable(_hpl);
        hpw = IERC20Upgradeable(_hpw);
        hplVestingPeriod = _hplVesting > 0 ? _hplVesting : hplVestingPeriod;
        hpwVestingPeriod = _hpwVesting > 0 ? _hpwVesting : hpwVestingPeriod;
        vestingPeriod[_hpl] = hplVestingPeriod;
        vestingPeriod[_hpw] = hpwVestingPeriod;
        lockers[_locker] = true;
    }

    function setEnableVestingReward(bool _val) external onlyOwner {
        enableVesting = _val;
    }

    function setDevAddress(address _devAddress) external onlyOwner {
        devAddress = _devAddress;
    }

    function setVestingPeriod(uint256 _hplVesting, uint256 _hpwVesting)
        external
        onlyOwner
    {
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
            vestings[_addr][address(hpl)].releasedAmount = vestings[_addr][
                address(hpl)
            ].releasedAmount.add(unlockableHPL);
            if (unlockableHPL < hpl.balanceOf(address(this))) {
                hpl.safeTransfer(_addr, unlockableHPL);
            } else {
                hpl.safeTransfer(_addr, hpl.balanceOf(address(this)));
            }
            emit Unlock(address(hpl), _addr, unlockableHPL);
            uint256 devReward = (unlockableHPL * 10) / 100;
            if (devReward < hpl.balanceOf(address(this))) {
                hpl.safeTransfer(devAddress, devReward);
            } else {
                hpl.safeTransfer(devAddress, hpl.balanceOf(address(this)));
            }
        }

        if (unlockableHPW > 0) {
            vestings[_addr][address(hpw)].releasedAmount = vestings[_addr][
                address(hpw)
            ].releasedAmount.add(unlockableHPL);
            uint256 devReward = (unlockableHPW * 10) / 100;
            IMint(address(hpw)).mint(_addr, unlockableHPW);
            IMint(address(hpw)).mint(devAddress, devReward);
            emit Unlock(address(hpw), _addr, unlockableHPW);
        }
    }

    function distributeReward(
        address _addr,
        uint256 _hplAmount,
        uint256 _hpwAmount
    ) external override {
        //we add this check for avoiding too much vesting
        require(lockers[msg.sender], "only locker can lock");

        unlock(_addr);

        if (!enableVesting) {
            //pay reward immediately
            if (_hplAmount > 0) {
                if (_hplAmount < hpl.balanceOf(address(this))) {
                    hpl.safeTransfer(_addr, _hplAmount);
                } else {
                    hpl.safeTransfer(_addr, hpl.balanceOf(address(this)));
                }
                uint256 devReward = (_hplAmount * 10) / 100;
                if (devReward < hpl.balanceOf(address(this))) {
                    hpl.safeTransfer(devAddress, devReward);
                } else {
                    hpl.safeTransfer(devAddress, hpl.balanceOf(address(this)));
                }
            }

            if (_hpwAmount > 0) {
                uint256 devReward = (_hpwAmount * 10) / 100;
                IMint(address(hpw)).mint(_addr, _hpwAmount);
                IMint(address(hpw)).mint(devAddress, devReward);
            }
            return;
        }

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

    function getUnlockable(address _addr)
        public
        view
        returns (uint256 _unlockableHPL, uint256 _unlockableHPW)
    {
        return (
            computeUnlockableForVesting(_addr, address(hpl)),
            computeUnlockableForVesting(_addr, address(hpw))
        );
    }

    function computeUnlockableForVesting(address _addr, address _token)
        public
        view
        returns (uint256)
    {
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

    function getLockedInfo(address _addr)
        external
        view
        returns (
            uint256 _hplLocked,
            uint256 _hplReleasable,
            uint256 _hpwLocked,
            uint256 _hpwReleasable
        )
    {
        (_hplReleasable, _hpwReleasable) = getUnlockable(_addr);
        _hplLocked = vestings[_addr][address(hpl)].totalAmount.sub(
            vestings[_addr][address(hpl)].releasedAmount
        );
        _hpwLocked = vestings[_addr][address(hpw)].totalAmount.sub(
            vestings[_addr][address(hpw)].releasedAmount
        );
    }
}

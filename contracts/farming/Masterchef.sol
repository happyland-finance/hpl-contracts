// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interfaces/IRewardDistributor.sol";
import "../interfaces/ITokenLock.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../lib/Upgradeable.sol";

// MasterChef is the master of HPL. He can make HPL and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once HPL is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Upgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    struct TokenDeposit {
        uint256 tokenAmount;
        uint256 weight;
        uint256 lockedFrom;
        uint256 lockedUntil;
    }
    // Info of each user.
    struct UserInfo {
        uint256 stakeAmount; // How many total LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 hpwRewardDebt;
        uint256 stakeWeight;
        TokenDeposit[] deposits;
        //
        // We do some fancy math here. Basically, any point in time, the amount of HPL
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accHPLPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accHPLPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20Upgradeable lpToken; // Address of LP token contract., address is 0 if it is NFT pool
        uint256 totalWeight;
        uint256 allocPoint; // How many allocation points assigned to this pool. HPLPoint to distribute per block.
        uint256 lastRewardBlock; // Last block number that HPLPoint distribution occurs.
        uint256 accHPLPerWeight; // Accumulated HPLPoint per share, times 1e12. See below.
        uint256 accHPWPerWeight; // Accumulated HPLPoint per share, times 1e12. See below.
        uint256 minLockedDuration;
    }

    /**
     * @dev Stake weight is proportional to deposit amount and time locked, precisely
     *      "deposit amount wei multiplied by (fraction of the year locked plus one)"
     * @dev To avoid significant precision loss due to multiplication by "fraction of the year" [0, 1],
     *      weight is stored multiplied by 1e6 constant, as an integer
     * @dev Corner case 1: if time locked is zero, weight is deposit amount multiplied by 1e6
     * @dev Corner case 2: if time locked is one year, fraction of the year locked is one, and
     *      weight is a deposit amount multiplied by 2 * 1e6
     */
    uint256 internal constant WEIGHT_MULTIPLIER = 1e6;

    /**
     * @dev When we know beforehand that staking is done for a year, and fraction of the year locked is one,
     *      we use simplified calculation and use the following constant instead previos one
     */
    uint256 internal constant YEAR_STAKE_WEIGHT_MULTIPLIER =
        2 * WEIGHT_MULTIPLIER;

    // The HPL TOKEN!
    // IERC20Upgradeable public hpl;
    // IERC20Upgradeable public hpw;
    IRewardDistributor public rewardDistributor;
    // Dev address.
    // Block number when bonus HPL period ends.
    uint256 public bonusEndBlock;
    // HPL tokens created per block.
    uint256 public hplPerBlock;
    uint256 public hpwPerBlock;
    // Bonus muliplier for early HPL makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    uint256 public poolLockedTimeAfterUnstake;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    //IMigratorChef public migrator;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The block number when HPL mining starts.
    uint256 public startBlock;
    bool public allowEmergencyWithdraw;
    ITokenLock public tokenLock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event ClaimRewards(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    function initialize(
        uint256 _hplPerBlock,
        uint256 _hpwPerBlock,
        uint256 _startBlock,
        address _rewardDistributor,
        address _tokenLock
    ) external initializer {
        initOwner();

        totalAllocPoint = 0;
        allowEmergencyWithdraw = false;
        poolLockedTimeAfterUnstake = 2 days;
        hplPerBlock = _hplPerBlock;
        hpwPerBlock = _hpwPerBlock;
        startBlock = _startBlock > 0 ? _startBlock : block.number;
        bonusEndBlock = startBlock.add(50000);
        rewardDistributor = IRewardDistributor(_rewardDistributor);
        tokenLock = ITokenLock(_tokenLock);
    }

    function setAllowEmergencyWithdraw(bool _allowEmergencyWithdraw)
        external
        onlyOwner
    {
        allowEmergencyWithdraw = _allowEmergencyWithdraw;
    }

    function setMinLockedDuration(uint256 _pid, uint256 _minLockedDuration)
        external
        onlyOwner
    {
        poolInfo[_pid].minLockedDuration = _minLockedDuration;
    }

    function setTokenLock(address _tokenLock) external onlyOwner {
        tokenLock = ITokenLock(_tokenLock);
    }

    function setRewardDistributor(address _rewardDistributor)
        external
        onlyOwner
    {
        rewardDistributor = IRewardDistributor(_rewardDistributor);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        address _lpToken,
        uint256 _minLockedDuration,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        require(_lpToken != address(0), "LP token address cannot be null");

        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: IERC20Upgradeable(_lpToken),
                totalWeight: 0,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accHPLPerWeight: 0,
                accHPWPerWeight: 0,
                minLockedDuration: _minLockedDuration
            })
        );
    }

    function setRewardPerBlock(
        uint256 _hplPerBlock,
        uint256 _hpwPerBlock,
        bool _withUpdate
    ) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        hplPerBlock = _hplPerBlock;
        hpwPerBlock = _hpwPerBlock;
    }

    // Update the given pool's HPL allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    // View function to see pending HPL on frontend.
    function pendingRewards(uint256 _pid, address _user)
        external
        view
        returns (uint256 _hpl, uint256 _hpw)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accHPLPerWeight = pool.accHPLPerWeight;
        uint256 accHPWPerWeight = pool.accHPWPerWeight;
        uint256 totalWeight = pool.totalWeight;

        if (block.number > pool.lastRewardBlock && totalWeight != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 hplReward = multiplier
                .mul(hplPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);

            uint256 hpwReward = multiplier
                .mul(hpwPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);

            accHPLPerWeight = accHPLPerWeight.add(
                hplReward.mul(1e12).div(totalWeight)
            );
            accHPWPerWeight = accHPWPerWeight.add(
                hpwReward.mul(1e12).div(totalWeight)
            );
        }
        uint256 userWeight = user.stakeWeight;
        _hpl = userWeight.mul(accHPLPerWeight).div(1e12).sub(user.rewardDebt);
        _hpw = userWeight.mul(accHPWPerWeight).div(1e12).sub(
            user.hpwRewardDebt
        );
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 totalWeight = pool.totalWeight;

        if (totalWeight == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 hplReward = multiplier
            .mul(hplPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);

        uint256 hpwReward = multiplier
            .mul(hpwPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);

        pool.accHPLPerWeight = pool.accHPLPerWeight.add(
            hplReward.mul(1e12).div(totalWeight)
        );
        pool.accHPWPerWeight = pool.accHPWPerWeight.add(
            hpwReward.mul(1e12).div(totalWeight)
        );

        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for HPL allocation.
    function deposit(
        uint256 _pid,
        uint256 _amount,
        uint256 _lockedDuration
    ) external {
        PoolInfo storage pool = poolInfo[_pid];
        require(
            _lockedDuration >= pool.minLockedDuration,
            "minimum stake duration is 2 weeks"
        );
        require(_lockedDuration <= 700 days, "max stake duration is 700 days");
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.stakeAmount > 0) {
            uint256 pendingHPL = user
                .stakeWeight
                .mul(pool.accHPLPerWeight)
                .div(1e12)
                .sub(user.rewardDebt);

            uint256 pendingHPW = user
                .stakeWeight
                .mul(pool.accHPWPerWeight)
                .div(1e12)
                .sub(user.hpwRewardDebt);
            payRewards(msg.sender, pendingHPL, pendingHPW);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );

        uint256 weight = ((_lockedDuration * WEIGHT_MULTIPLIER) /
            365 days +
            WEIGHT_MULTIPLIER) * _amount;
        if (weight > 0) {
            user.deposits.push(
                TokenDeposit({
                    tokenAmount: _amount,
                    weight: weight,
                    lockedFrom: block.timestamp,
                    lockedUntil: block.timestamp + _lockedDuration
                })
            );
        }

        user.stakeAmount = user.stakeAmount.add(_amount);
        user.stakeWeight = user.stakeWeight.add(weight);
        user.rewardDebt = user.stakeWeight.mul(pool.accHPLPerWeight).div(1e12);
        user.hpwRewardDebt = user.stakeWeight.mul(pool.accHPWPerWeight).div(
            1e12
        );
        pool.totalWeight += weight;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(
        uint256 _pid,
        uint256 _amount,
        uint256 _depositId
    ) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(
            user.deposits.length > _depositId,
            "withdraw: depositId out of range"
        );
        TokenDeposit storage _deposit = user.deposits[_depositId];
        require(_deposit.tokenAmount >= _amount, "withdraw: not good");
        require(
            _deposit.lockedUntil < block.timestamp,
            "withdraw: not unlock time"
        );

        updatePool(_pid);
        uint256 pendingHPL = user
            .stakeWeight
            .mul(pool.accHPLPerWeight)
            .div(1e12)
            .sub(user.rewardDebt);
        uint256 pendingHPW = user
            .stakeWeight
            .mul(pool.accHPWPerWeight)
            .div(1e12)
            .sub(user.hpwRewardDebt);

        payRewards(msg.sender, pendingHPL, pendingHPW);

        uint256 _lockedDuration = _deposit.lockedUntil - _deposit.lockedFrom;
        //update deposit
        _deposit.tokenAmount -= _amount;
        uint256 newWeight = ((_lockedDuration * WEIGHT_MULTIPLIER) /
            365 days +
            WEIGHT_MULTIPLIER) * _deposit.tokenAmount;
        uint256 previousWeight = _deposit.weight;
        _deposit.weight = newWeight;

        if (_deposit.tokenAmount == 0) {
            //delete _depositId
            uint256 lastDepositId = user.deposits.length - 1;
            user.deposits[_depositId] = user.deposits[lastDepositId];
            user.deposits.pop();
        }

        user.stakeAmount = user.stakeAmount.sub(_amount);
        user.stakeWeight = user.stakeWeight + newWeight - previousWeight;
        user.rewardDebt = user.stakeWeight.mul(pool.accHPLPerWeight).div(1e12);
        user.hpwRewardDebt = user.stakeWeight.mul(pool.accHPWPerWeight).div(
            1e12
        );

        pool.totalWeight = pool.totalWeight + newWeight - previousWeight;

        pool.lpToken.safeApprove(address(tokenLock), _amount);
        tokenLock.lock(
            address(pool.lpToken),
            msg.sender,
            _amount,
            poolLockedTimeAfterUnstake
        );

        emit Withdraw(msg.sender, _pid, _amount);
    }

    function setPoolLockedTimeAfterUnstake(uint256 _lockedTime)
        external
        onlyOwner
    {
        poolLockedTimeAfterUnstake = _lockedTime;
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        require(allowEmergencyWithdraw, "!allowEmergencyWithdraw");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.stakeAmount);
        emit EmergencyWithdraw(msg.sender, _pid, user.stakeAmount);
        pool.totalWeight = pool.totalWeight.sub(user.stakeWeight);
        user.stakeAmount = 0;
        user.stakeWeight = 0;
        delete user.deposits;
        user.rewardDebt = 0;
        user.hpwRewardDebt = 0;
    }

    // Safe HPL transfer function, just in case if rounding error causes pool to not have enough HPL.
    function payRewards(
        address _to,
        uint256 _hpl,
        uint256 _hpw
    ) internal {
        rewardDistributor.distributeReward(_to, _hpl, _hpw);
    }

    function unlock(address _addr, uint256 index) public {
        tokenLock.unlock(_addr, index);
    }

    function getUserInfo(uint256 _pid, address _addr)
        external
        view
        returns (
            uint256 stakeAmount,
            uint256 rewardDebt,
            uint256 hpwRewardDebt,
            uint256 stakeWeight,
            TokenDeposit[] memory deposits
        )
    {
        UserInfo storage user = userInfo[_pid][_addr];
        return (
            user.stakeAmount,
            user.rewardDebt,
            user.hpwRewardDebt,
            user.stakeWeight,
            user.deposits
        );
    }

    function getLockInfo(address _user)
        external
        view
        returns (
            bool[] memory isWithdrawns,
            address[] memory tokens,
            uint256[] memory unlockableAts,
            uint256[] memory amounts
        )
    {
        return tokenLock.getLockInfo(_user);
    }

    function getLockInfoByIndexes(address _addr, uint256[] memory _indexes)
        external
        view
        returns (
            bool[] memory isWithdrawns,
            address[] memory tokens,
            uint256[] memory unlockableAts,
            uint256[] memory amounts
        )
    {
        return tokenLock.getLockInfoByIndexes(_addr, _indexes);
    }

    function getLockInfoLength(address _addr) external view returns (uint256) {
        return tokenLock.getLockInfoLength(_addr);
    }
}

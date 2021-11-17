// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interfaces/IRewardDistributor.sol";
import "../interfaces/ITokenLock.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

// interface IMigratorChef {
//     // Perform LP token migration from legacy UniswapV2 to HPL.
//     // Take the current LP token address and return the new LP token address.
//     // Migrator should have full access to the caller's LP token.
//     // Return the new LP token address.
//     //
//     // XXX Migrator must have allowance access to UniswapV2 LP tokens.
//     //  must mint EXACTLY the same amount of  LP tokens or
//     // else something bad will happen. Traditional UniswapV2 does not
//     // do that so be careful!
//     function migrate(IERC20 token) external returns (IERC20);
// }

// MasterChef is the master of HPL. He can make HPL and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once HPL is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 hpwRewardDebt;
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
        uint256 allocPoint; // How many allocation points assigned to this pool. HPLPoint to distribute per block.
        uint256 lastRewardBlock; // Last block number that HPLPoint distribution occurs.
        uint256 accHPLPerShare; // Accumulated HPLPoint per share, times 1e12. See below.
        uint256 accHPWPerShare; // Accumulated HPLPoint per share, times 1e12. See below.
    }
    // The HPL TOKEN!
    IERC20Upgradeable public hpl;
    IERC20Upgradeable public hpw;
    IRewardDistributor public rewardDistributor;
    // Dev address.
    // Block number when bonus HPL period ends.
    uint256 public bonusEndBlock;
    // HPL tokens created per block.
    uint256 public hplPerBlock;
    uint256 public hpwPerBlock;
    // Bonus muliplier for early HPL makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    uint256 public poolLockedTime;
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(
        IERC20Upgradeable _hpl,
        IERC20Upgradeable _hpw,
        uint256 _hplPerBlock,
        uint256 _hpwPerBlock,
        uint256 _startBlock,
        address _rewardDistributor,
        address _tokenLock
    ) external initializer {
        __Ownable_init();

        totalAllocPoint = 0;
        allowEmergencyWithdraw = false;
        poolLockedTime = 2 days;
        hpl = _hpl;
        hpw = _hpw;
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
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accHPLPerShare: 0,
                accHPWPerShare: 0
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

    // // Set the migrator contract. Can only be called by the owner.
    // function setMigrator(IMigratorChef _migrator) public onlyOwner {
    //     migrator = _migrator;
    // }

    // // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    // function migrate(uint256 _pid) public {
    //     require(address(migrator) != address(0), "migrate: no migrator");
    //     PoolInfo storage pool = poolInfo[_pid];
    //     IERC20 lpToken = pool.lpToken;
    //     uint256 bal = lpToken.balanceOf(address(this));
    //     lpToken.safeApprove(address(migrator), bal);
    //     IERC20 newLpToken = migrator.migrate(lpToken);
    //     require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
    //     pool.lpToken = newLpToken;
    // }

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
        uint256 accHPLPerShare = pool.accHPLPerShare;
        uint256 accHPWPerShare = pool.accHPWPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
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

            accHPLPerShare = accHPLPerShare.add(
                hplReward.mul(1e12).div(lpSupply)
            );
            accHPWPerShare = accHPWPerShare.add(
                hpwReward.mul(1e12).div(lpSupply)
            );
        }
        uint256 amount = user.amount;
        _hpl = amount.mul(accHPLPerShare).div(1e12).sub(user.rewardDebt);
        _hpw = amount.mul(accHPWPerShare).div(1e12).sub(user.hpwRewardDebt);
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
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (lpSupply == 0) {
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

        pool.accHPLPerShare = pool.accHPLPerShare.add(
            hplReward.mul(1e12).div(lpSupply)
        );
        pool.accHPWPerShare = pool.accHPWPerShare.add(
            hpwReward.mul(1e12).div(lpSupply)
        );

        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for HPL allocation.
    function deposit(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pendingHPL = user
                .amount
                .mul(pool.accHPLPerShare)
                .div(1e12)
                .sub(user.rewardDebt);

            uint256 pendingHPW = user
                .amount
                .mul(pool.accHPWPerShare)
                .div(1e12)
                .sub(user.hpwRewardDebt);
            payRewards(msg.sender, pendingHPL, pendingHPW);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accHPLPerShare).div(1e12);
        user.hpwRewardDebt = user.amount.mul(pool.accHPWPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pendingHPL = user.amount.mul(pool.accHPLPerShare).div(1e12).sub(
            user.rewardDebt
        );
        uint256 pendingHPW = user.amount.mul(pool.accHPWPerShare).div(1e12).sub(
            user.hpwRewardDebt
        );

        payRewards(msg.sender, pendingHPL, pendingHPW);

        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accHPLPerShare).div(1e12);
        user.hpwRewardDebt = user.amount.mul(pool.accHPWPerShare).div(1e12);

        pool.lpToken.safeApprove(address(tokenLock), _amount);
        tokenLock.lock(
            address(pool.lpToken),
            msg.sender,
            _amount,
            poolLockedTime
        );

        emit Withdraw(msg.sender, _pid, _amount);
    }

    function setPoolLockedTime(uint256 _lockedTime) external onlyOwner {
        poolLockedTime = _lockedTime;
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        require(allowEmergencyWithdraw, "!allowEmergencyWithdraw");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
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

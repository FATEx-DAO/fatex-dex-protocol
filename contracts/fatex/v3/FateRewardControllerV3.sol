// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../MockLpToken.sol";
import "../IMockLpTokenFactory.sol";
import "../IFateRewardController.sol";

import "./MembershipWithReward.sol";
import "./IFateRewardControllerV3.sol";

// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once FATE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract FateRewardControllerV3 is IFateRewardControllerV3, MembershipWithReward {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfoV3 {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 lockedRewardDebt; // Reward debt. See explanation below.
        bool isUpdated; // true if the user has been migrated from the v1 controller to v2
        //
        // We do some fancy math here. Basically, any point in time, the amount of FATEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accumulatedFatePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accumulatedFatePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    IERC20 public override fate;

    address public override vault;

    IFateRewardController[] public oldControllers;

    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public override migrator;

    // Info of each pool.
    PoolInfoV3[] public override poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfoV3)) internal _userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public override totalAllocPoint = 0;

    // The block number when FATE mining starts.
    uint256 public override startBlock;

    IMockLpTokenFactory public mockLpTokenFactory;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);

    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    event ClaimRewards(address indexed user, uint256 indexed pid, uint256 amount);

    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    event EmissionScheduleSet(address indexed emissionSchedule);

    event MigratorSet(address indexed migrator);

    event VaultSet(address indexed emissionSchedule);

    event PoolAdded(uint indexed pid, address indexed lpToken, uint allocPoint);

    event PoolAllocPointSet(uint indexed pid, uint allocPoint);

    constructor(
        IERC20 _fate,
        IRewardScheduleV3 _emissionSchedule,
        address _vault,
        IFateRewardController[] memory _oldControllers,
        IMockLpTokenFactory _mockLpTokenFactory
    ) public {
        fate = _fate;
        emissionSchedule = _emissionSchedule;
        vault = _vault;
        oldControllers = _oldControllers;
        mockLpTokenFactory = _mockLpTokenFactory;
        startBlock = _oldControllers[0].startBlock();

        // inset old controller's pooInfo
        for (uint i = 0; i < _oldControllers[0].poolLength(); i++) {
            (IERC20 lpToken, uint256 allocPoint, ,) = _oldControllers[0].poolInfo(i);
            poolInfo[i] = PoolInfoV3({
              lpToken: lpToken,
              allocPoint: allocPoint,
              lastRewardBlock: startBlock,
              accumulatedFatePerShare: 0,
              accumulatedLockedFatePerShare: 0
            });
        }
    }

    function poolLength() external override view returns (uint256) {
        return poolInfo.length;
    }

    function addMany(
        IERC20[] calldata _lpTokens
    ) external onlyOwner {
        uint allocPoint = 0;
        for (uint i = 0; i < _lpTokens.length; i++) {
            bool shouldUpdate = i == _lpTokens.length - 1;
            _add(allocPoint, _lpTokens[i], shouldUpdate);
        }
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        _add(_allocPoint, _lpToken, _withUpdate);
    }

    function _add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) internal {
        for (uint i = 0; i < poolInfo.length; i++) {
            require(
                poolInfo[i].lpToken != _lpToken,
                "add: LP token already added"
            );
        }

        if (_withUpdate) {
            massUpdatePools();
        }
        require(
            _lpToken.balanceOf(address(this)) >= 0,
            "add: invalid LP token"
        );

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfoV3({
                lpToken : _lpToken,
                allocPoint : _allocPoint,
                lastRewardBlock : lastRewardBlock,
                accumulatedFatePerShare : 0,
                accumulatedLockedFatePerShare : 0
            })
        );
        emit PoolAdded(poolInfo.length - 1, address(_lpToken), _allocPoint);
    }

    // Update the given pool's FATE allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        emit PoolAllocPointSet(_pid, _allocPoint);
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public override onlyOwner {
        migrator = _migrator;
        emit MigratorSet(address(_migrator));
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public override {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfoV3 storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    function migrate(
        IERC20 token
    ) external override returns (IERC20) {
        IFateRewardController oldController = IFateRewardController(address(0));
        for (uint i = 0; i < oldControllers.length; i++) {
            if (address(oldControllers[i]) == msg.sender) {
                oldController = oldControllers[i];
            }
        }
        require(
            address(oldController) != address(0),
            "migrate: invalid sender"
        );

        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accumulatedFatePerShare;
        uint oldPoolLength = oldController.poolLength();
        for (uint i = 0; i < oldPoolLength; i++) {
            (lpToken, allocPoint, lastRewardBlock, accumulatedFatePerShare) = oldController.poolInfo(poolInfo.length);
            if (address(lpToken) == address(token)) {
                break;
            }
        }

        // transfer all of the tokens from the previous controller to here
        token.safeTransferFrom(msg.sender, address(this), token.balanceOf(msg.sender));

        poolInfo.push(
            PoolInfoV3({
                lpToken : lpToken,
                allocPoint : allocPoint,
                lastRewardBlock : lastRewardBlock,
                accumulatedFatePerShare : accumulatedFatePerShare,
                accumulatedLockedFatePerShare : 0
            })
        );
        emit PoolAdded(poolInfo.length - 1, address(token), allocPoint);

        uint _totalAllocPoint = 0;
        for (uint i = 0; i < poolInfo.length; i++) {
            _totalAllocPoint = _totalAllocPoint.add(poolInfo[i].allocPoint);
        }
        totalAllocPoint = _totalAllocPoint;

        return IERC20(mockLpTokenFactory.create(address(lpToken), address(this)));
    }

    function userInfo(
        uint _pid,
        address _user
    ) public override view returns (uint amount, uint rewardDebt) {
        UserInfoV3 memory user = _userInfo[_pid][_user];
        return (user.amount, user.rewardDebt);
    }

    function _getUserInfo(
        uint _pid,
        address _user
    ) internal view returns (IFateRewardControllerV3.UserInfo memory) {
        UserInfoV3 memory user = _userInfo[_pid][_user];
        return IFateRewardControllerV3.UserInfo(user.amount, user.rewardDebt, user.lockedRewardDebt);
    }

    // View function to see pending FATE tokens on frontend.
    function pendingUnlockedFate(
        uint256 _pid,
        address _user
    )
    public
    override
    view
    returns (uint256)
    {
        PoolInfoV3 storage pool = poolInfo[_pid];
        IFateRewardControllerV3.UserInfo memory user = _getUserInfo(_pid, _user);
        uint256 accumulatedFatePerShare = pool.accumulatedFatePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            (, uint256 unlockedFatePerBlock) = emissionSchedule.getFatePerBlock(
                startBlock,
                pool.lastRewardBlock,
                block.number
            ); // only unlocked Fates
            uint256 unlockedFateReward = unlockedFatePerBlock
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accumulatedFatePerShare = accumulatedFatePerShare
                .add(unlockedFateReward
                .mul(1e12)
                .div(lpSupply)
            );
        }
        return user.amount
            .mul(accumulatedFatePerShare)
            .div(1e12)
            .sub(user.rewardDebt);
    }

    function pendingLockedFate(
        uint256 _pid,
        address _user
    )
    public
    override
    view
    returns (uint256)
    {
        PoolInfoV3 storage pool = poolInfo[_pid];
        IFateRewardControllerV3.UserInfo memory user = _getUserInfo(_pid, _user);
        uint256 accumulatedFatePerShare = pool.accumulatedFatePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            (uint256 lockedFatePerBlock,) = emissionSchedule.getFatePerBlock(
                startBlock,
                pool.lastRewardBlock,
                block.number
            ); // only unlocked Fates
            uint256 lockedFateReward = lockedFatePerBlock
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accumulatedFatePerShare = accumulatedFatePerShare
                .add(lockedFateReward
                .mul(1e12)
                .div(lpSupply)
            );
        }
        return user.amount
            .mul(accumulatedFatePerShare)
            .div(1e12)
            .sub(user.lockedRewardDebt);
    }

    function allPendingUnlockedFate(
        address _user
    )
    external
    override
    view
    returns (uint256)
    {
        uint _pendingFateRewards = 0;
        for (uint i = 0; i < poolInfo.length; i++) {
            _pendingFateRewards = _pendingFateRewards.add(pendingUnlockedFate(i, _user));
        }
        return _pendingFateRewards;
    }

    function allPendingLockedFate(
        address _user
    )
    external
    override
    view
    returns (uint256)
    {
        uint _pendingFateRewards = 0;
        for (uint i = 0; i < poolInfo.length; i++) {
            _pendingFateRewards = _pendingFateRewards.add(pendingLockedFate(i, _user));
        }
        return _pendingFateRewards;
    }

    function allLockedFate(
        address _user
    )
    external
    override
    view
    returns (uint256)
    {
        uint _pendingFateRewards = 0;
        for (uint i = 0; i < poolInfo.length; i++) {
            _pendingFateRewards = _pendingFateRewards.add(pendingLockedFate(i, _user)).add(userLockedRewards[i][_user]);
        }
        return _pendingFateRewards;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function getNewRewardPerBlock(uint pid1) public view returns (uint) {
        (, uint256 fatePerBlock) = emissionSchedule.getFatePerBlock(
            startBlock,
            block.number - 1,
            block.number
        );
        if (pid1 == 0) {
            return fatePerBlock;
        } else {
            return fatePerBlock.mul(poolInfo[pid1 - 1].allocPoint).div(totalAllocPoint);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfoV3 storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        (uint256 lockedFatePerBlock, uint256 unlockedFatePerBlock) = emissionSchedule.getFatePerBlock(
            startBlock,
            pool.lastRewardBlock,
            block.number
        );

        uint256 unlockedFateReward = unlockedFatePerBlock
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        uint256 lockedFateReward = lockedFatePerBlock
            .mul(pool.allocPoint)
            .div(totalAllocPoint);

        if (unlockedFateReward > 0) {
            fate.transferFrom(vault, address(this), unlockedFateReward);
            pool.accumulatedFatePerShare = pool.accumulatedFatePerShare
                .add(unlockedFateReward.mul(1e12).div(lpSupply));
        }
        if (lockedFateReward > 0) {
            pool.accumulatedLockedFatePerShare = pool.accumulatedLockedFatePerShare
            .add(lockedFateReward.mul(1e12).div(lpSupply));
        }
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for FATE allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfoV3 storage pool = poolInfo[_pid];
        IFateRewardControllerV3.UserInfo memory user = _getUserInfo(_pid, msg.sender);
        updatePool(_pid);
        if (user.amount > 0) {
            _claimRewards(_pid, msg.sender, user, pool);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );

        uint userBalance = user.amount.add(_amount);
        _userInfo[_pid][msg.sender] = UserInfoV3({
            amount : userBalance,
            rewardDebt : userBalance.mul(pool.accumulatedFatePerShare).div(1e12),
            lockedRewardDebt : userBalance.mul(pool.accumulatedLockedFatePerShare).div(1e12),
            isUpdated : true
        });
        _recordDepositBlock(_pid, msg.sender);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfoV3 storage pool = poolInfo[_pid];
        IFateRewardControllerV3.UserInfo memory user = _getUserInfo(_pid, msg.sender);
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);

        _claimRewards(_pid, msg.sender, user, pool);

        uint userBalance = user.amount.sub(_amount);
        _userInfo[_pid][msg.sender] = UserInfoV3({
            amount : userBalance,
            rewardDebt : userBalance.mul(pool.accumulatedFatePerShare).div(1e12),
            lockedRewardDebt : userBalance.mul(pool.accumulatedLockedFatePerShare).div(1e12),
            isUpdated : true
        });

        uint256 withdrawAmount = _amount;
        if (isFatePool[_pid]) {
            withdrawAmount = _reduceFeeAndUpdateMembershipInfo(
                _pid,
                msg.sender,
                withdrawAmount,
                _amount == user.amount
            );
        }

        pool.lpToken.safeTransfer(msg.sender, withdrawAmount);
        emit Withdraw(msg.sender, _pid, withdrawAmount);
    }

    // reduce lpWithdrawFee and lockedRewardFees
    // if withdraw all, add current reward points to additional user points and do not earn any new user points
    function _reduceFeeAndUpdateMembershipInfo(
        uint256 _pid,
        address _account,
        uint256 _amount,
        bool _withdrawAll
    ) internal returns(uint256 withdrawAmount) {
        // minus LockedRewardFee
        userLockedRewards[_pid][_account] = userLockedRewards[_pid][_account]
            * (1e18 - _getLockedRewardsFeePercent(_pid, _account))
            / 1e18;

        // minus LPWithdrawFee
        withdrawAmount = _amount
            * (1e18 - _getLPWithdrawFeePercent(_pid, _account))
            / 1e18;

        // record last withdraw block
        MembershipInfo memory membership = userMembershipInfo[_pid][_account];
        if (_withdrawAll) {
            additionalPoints[_pid][_account] +=
                _getBlocksOfPeriod(_pid, _account, true) * POINTS_PER_BLOCK;

            userMembershipInfo[_pid][_account] = MembershipInfo({
                firstDepositBlock: 0,
                lastWithdrawBlock: 0
            });
        } else {
            userMembershipInfo[_pid][_account] = MembershipInfo({
                firstDepositBlock: membership.firstDepositBlock,
                lastWithdrawBlock: block.number
            });
        }
    }

    function _claimRewards(
        uint256 _pid,
        address _user,
        IFateRewardControllerV3.UserInfo memory user,
        PoolInfoV3 memory pool
    ) internal {
        uint256 pendingUnlocked = user.amount
            .mul(pool.accumulatedFatePerShare)
            .div(1e12)
            .sub(user.rewardDebt);

        uint256 pendingLocked = user.amount
            .mul(pool.accumulatedLockedFatePerShare)
            .div(1e12)
            .sub(user.lockedRewardDebt);

        // TODO: Stephon reduce pendingUnlocked & pendingLocked variables by self-assigning and multiplying by the fee
        // TODO: the user has for their rewards by using `lockedRewardsFeePercents` from the MembershipWithReward contract

        // recorded locked rewards
        userLockedRewards[_pid][_user] = userLockedRewards[_pid][_user].add(pendingLocked);

        _safeFateTransfer(_user, pendingUnlocked);
        emit ClaimRewards(_user, _pid, pendingUnlocked);
    }

    // claim any pending rewards from this pool, from msg.sender
    function claimReward(uint256 _pid) public {
        PoolInfoV3 storage pool = poolInfo[_pid];
        IFateRewardControllerV3.UserInfo memory user = _getUserInfo(_pid, msg.sender);
        updatePool(_pid);
        _claimRewards(_pid, msg.sender, user, pool);

        _userInfo[_pid][msg.sender] = UserInfoV3({
            amount : user.amount,
            rewardDebt : user.amount.mul(pool.accumulatedFatePerShare).div(1e12),
            lockedRewardDebt : user.amount.mul(pool.accumulatedLockedFatePerShare).div(1e12),
            isUpdated : true
        });
    }

    // claim any pending rewards from this pool, from msg.sender
    function claimRewards(uint256[] calldata _pids) external {
        for (uint i = 0; i < _pids.length; i++) {
            claimReward(_pids[i]);
        }
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfoV3 storage pool = poolInfo[_pid];
        IFateRewardControllerV3.UserInfo memory user = _getUserInfo(_pid, msg.sender);
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);

        _userInfo[_pid][msg.sender] = UserInfoV3({
            amount : 0,
            rewardDebt : 0,
            lockedRewardDebt : 0,
            isUpdated : true
        });
    }

    // Safe fate transfer function, just in case if rounding error causes pool to not have enough FATEs.
    function _safeFateTransfer(address _to, uint256 _amount) internal {
        uint256 fateBal = fate.balanceOf(address(this));
        if (_amount > fateBal) {
            fate.transfer(_to, fateBal);
        } else {
            fate.transfer(_to, _amount);
        }
    }

    function setEmissionSchedule(
        IRewardScheduleV3 _emissionSchedule
    )
    public
    onlyOwner {
        // pro-rate the pools to the current block, before changing the schedule
        massUpdatePools();
        emissionSchedule = _emissionSchedule;
        emit EmissionScheduleSet(address(_emissionSchedule));
    }

    function setVault(
        address _vault
    )
    public
    override
    onlyOwner {
        // pro-rate the pools to the current block, before changing the schedule
        vault = _vault;
        emit VaultSet(_vault);
    }
}

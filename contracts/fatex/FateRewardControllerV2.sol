// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./FateRewardController.sol";
import "./FateToken.sol";
import "./MockLpToken.sol";
import "./RewardSchedule.sol";

// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once FATE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract FateRewardControllerV2 is Ownable, IMigratorChef {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
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

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. FATEs to distribute per block.
        uint256 lastRewardBlock; // Last block number that FATEs distribution occurs.
        uint256 accumulatedFatePerShare; // Accumulated FATEs per share, times 1e12. See below.
    }

    FateToken public fate;

    address public vault;

    FateRewardController[] public oldControllers;

    // The emission scheduler that calculates fate per block over a given period
    RewardSchedule public emissionSchedule;

    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) internal _userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The block number when FATE mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);

    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    event ClaimRewards(address indexed user, uint256 indexed pid, uint256 amount);

    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    event EmissionScheduleSet(address indexed emissionSchedule);

    event VaultSet(address indexed emissionSchedule);

    event PoolAdded(uint indexed pid, address indexed lpToken, uint allocPoint);

    event PoolAllocPointSet(uint indexed pid, uint allocPoint);

    constructor(
        FateToken _fate,
        RewardSchedule _emissionSchedule,
        address _vault,
        FateRewardController[] memory _oldControllers
    ) public {
        fate = _fate;
        emissionSchedule = _emissionSchedule;
        vault = _vault;
        oldControllers = _oldControllers;
        startBlock = _oldControllers[0].startBlock();
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
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
            PoolInfo({
        lpToken : _lpToken,
        allocPoint : _allocPoint,
        lastRewardBlock : lastRewardBlock,
        accumulatedFatePerShare : 0
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
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
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
        FateRewardController oldController = FateRewardController(address(0));
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
        token.transferFrom(msg.sender, address(this), token.balanceOf(msg.sender));

        poolInfo.push(
            PoolInfo({
        lpToken : lpToken,
        allocPoint : allocPoint,
        lastRewardBlock : lastRewardBlock,
        accumulatedFatePerShare : accumulatedFatePerShare
        })
        );
        emit PoolAdded(poolInfo.length - 1, address(token), allocPoint);

        uint _totalAllocPoint = 0;
        for (uint i = 0; i < poolInfo.length; i++) {
            _totalAllocPoint = _totalAllocPoint.add(poolInfo[i].allocPoint);
        }
        totalAllocPoint = _totalAllocPoint;

        return IERC20(address(new MockLpToken(address(token), address(this))));
    }

    function userInfo(
        uint _pid,
        address _user
    ) public view returns (uint amount, uint rewardDebt) {
        UserInfo memory user = _userInfo[_pid][_user];
        if (user.isUpdated) {
            return (user.amount, user.rewardDebt);
        } else {
            return oldControllers[0].userInfo(_pid, _user);
        }
    }

    function getUserInfo(
        uint _pid,
        address _user
    ) public view returns (FateRewardController.UserInfo memory) {
        UserInfo memory user = _userInfo[_pid][_user];
        if (user.isUpdated) {
            return FateRewardController.UserInfo(user.amount, user.rewardDebt);
        } else {
            (uint amount, uint rewardDebt) = oldControllers[0].userInfo(_pid, _user);
            return FateRewardController.UserInfo(amount, rewardDebt);
        }
    }

    // View function to see pending FATE tokens on frontend.
    function pendingFate(uint256 _pid, address _user)
    external
    view
    returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        FateRewardController.UserInfo memory user = getUserInfo(_pid, _user);
        uint256 accumulatedFatePerShare = pool.accumulatedFatePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 fatePerBlock = emissionSchedule.getFatePerBlock(startBlock, pool.lastRewardBlock, block.number);
            uint256 fateReward = fatePerBlock.mul(pool.allocPoint).div(totalAllocPoint);
            accumulatedFatePerShare = accumulatedFatePerShare.add(fateReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accumulatedFatePerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function getNewRewardPerBlock(uint pid1) public view returns (uint) {
        uint256 fatePerBlock = emissionSchedule.getFatePerBlock(startBlock, block.number - 1, block.number);
        if (pid1 == 0) {
            return fatePerBlock;
        } else {
            return fatePerBlock.mul(poolInfo[pid1 - 1].allocPoint).div(totalAllocPoint);
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
        uint256 fatePerBlock = emissionSchedule.getFatePerBlock(startBlock, pool.lastRewardBlock, block.number);
        uint256 fateReward = fatePerBlock.mul(pool.allocPoint).div(totalAllocPoint);
        if (fateReward > 0) {
            fate.transferFrom(vault, address(this), fateReward);
            pool.accumulatedFatePerShare = pool.accumulatedFatePerShare.add(fateReward.mul(1e12).div(lpSupply));
        }
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for FATE allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        FateRewardController.UserInfo memory user = getUserInfo(_pid, msg.sender);
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accumulatedFatePerShare).div(1e12).sub(user.rewardDebt);
            safeFateTransfer(msg.sender, pending);
            emit ClaimRewards(msg.sender, _pid, pending);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        uint userBalance = user.amount.add(_amount);

        _userInfo[_pid][msg.sender] = UserInfo({
        amount : userBalance,
        rewardDebt : userBalance.mul(pool.accumulatedFatePerShare).div(1e12),
        isUpdated : true
        });
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        FateRewardController.UserInfo memory user = getUserInfo(_pid, msg.sender);
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accumulatedFatePerShare).div(1e12).sub(user.rewardDebt);
        safeFateTransfer(msg.sender, pending);
        emit ClaimRewards(msg.sender, _pid, pending);

        uint userBalance = user.amount.sub(_amount);
        _userInfo[_pid][msg.sender] = UserInfo({
        amount : userBalance,
        rewardDebt : userBalance.mul(pool.accumulatedFatePerShare).div(1e12),
        isUpdated : true
        });

        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // claim any pending rewards from this pool, from msg.sender
    function claimReward(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        FateRewardController.UserInfo memory user = getUserInfo(_pid, msg.sender);
        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accumulatedFatePerShare).div(1e12).sub(user.rewardDebt);
        safeFateTransfer(msg.sender, pending);
        emit ClaimRewards(msg.sender, _pid, pending);

        _userInfo[_pid][msg.sender] = UserInfo({
        amount : user.amount,
        rewardDebt : user.amount.mul(pool.accumulatedFatePerShare).div(1e12),
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
        PoolInfo storage pool = poolInfo[_pid];
        FateRewardController.UserInfo memory user = getUserInfo(_pid, msg.sender);
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);

        _userInfo[_pid][msg.sender] = UserInfo({
        amount : 0,
        rewardDebt : 0,
        isUpdated : true
        });
    }

    // Safe fate transfer function, just in case if rounding error causes pool to not have enough FATEs.
    function safeFateTransfer(address _to, uint256 _amount) internal {
        uint256 fateBal = fate.balanceOf(address(this));
        if (_amount > fateBal) {
            fate.transfer(_to, fateBal);
        } else {
            fate.transfer(_to, _amount);
        }
    }

    function setEmissionSchedule(
        RewardSchedule _emissionSchedule
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
    onlyOwner {
        // pro-rate the pools to the current block, before changing the schedule
        vault = _vault;
        emit VaultSet(_vault);
    }
}

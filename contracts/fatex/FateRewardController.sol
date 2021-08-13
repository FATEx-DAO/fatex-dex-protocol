// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./FateToken.sol";
import "./EmissionSchedule.sol";

interface IMigratorChef {
    // Perform LP token migration from legacy UniswapV2 to FATEx DEX.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to UniswapV2 LP tokens.
    // FATEx DEX must mint EXACTLY the same amount of FATEx DEX LP tokens or
    // else something bad will happen. Traditional UniswapV2 does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
}

// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once FATE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract FateRewardController is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
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

    // The emission scheduler that calculates fate per block over a given period
    EmissionSchedule public emissionSchedule;

    // Bonus multiplier for early fate LP deposits.
    uint256 public constant BONUS_MULTIPLIER = 10;

    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The block number when FATE mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);

    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    event EmissionScheduleSet(address indexed emissionSchedule);

    event VaultSet(address indexed emissionSchedule);

    constructor(
        FateToken _fate,
        EmissionSchedule _emissionSchedule,
        address _vault
    ) public {
        fate = _fate;
        emissionSchedule = _emissionSchedule;
        vault = _vault;
        startBlock = block.number;
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
        if (_withUpdate) {
            massUpdatePools();
        }

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

    // View function to see pending FATE tokens on frontend.
    function pendingFate(uint256 _pid, address _user)
    external
    view
    returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
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
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accumulatedFatePerShare).div(1e12).sub(user.rewardDebt);
            safeFateTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accumulatedFatePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accumulatedFatePerShare).div(1e12).sub(user.rewardDebt);
        safeFateTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accumulatedFatePerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
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
        EmissionSchedule _emissionSchedule
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

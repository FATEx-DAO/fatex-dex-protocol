// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IMigratorChef.sol";
import "./IRewardSchedule.sol";

abstract contract IFateRewardController {

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

    function fate() external virtual view returns (IERC20);
    function vault() external virtual view returns (address);
    function emissionSchedule() external virtual view returns (IRewardSchedule);
    function migrator() external virtual view returns (IMigratorChef);
    function poolInfo(uint _pid) external virtual view returns (IERC20 lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accumulatedFatePerShare);
    function userInfo(uint _pid, address _user) external virtual view returns (uint256 amount, uint256 rewardDebt);
    function poolLength() external virtual view returns (uint);
    function startBlock() external virtual view returns (uint);
    function totalAllocPoint() external virtual view returns (uint);
    function pendingFate(uint256 _pid, address _user) external virtual view returns (uint256);
    function setVault(address _vault) external virtual;

}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IFateRewardControllerV3.sol";


// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once FATE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract FateRewardControllerV3Reader {
    using SafeMath for uint256;

    IFateRewardControllerV3 controller;

    constructor(address _controller) public {
        controller = IFateRewardControllerV3(_controller);
    }

    function getAllocPoint(uint _pid) external view returns (uint) {
        (, uint256 allocPoint,,,) = controller.poolInfo(_pid);
        return allocPoint;
    }

    function totalAllocPoint() external view returns (uint) {
        return controller.totalAllocPoint();
    }

    function getFatePerSecond(uint _pid) external view returns (uint lockedFatePerSecond, uint unlockedFatePerSecond) {
        (, uint256 allocPoint, uint256 lastRewardTimestamp,,) = controller.poolInfo(_pid);
        (lockedFatePerSecond, unlockedFatePerSecond) = controller.rewardSchedule().getFateForDuration(
            controller.startTimestamp(),
            lastRewardTimestamp,
            block.timestamp
        );

        uint _totalAllocPoint = controller.totalAllocPoint();

        unlockedFatePerSecond = unlockedFatePerSecond
            .mul(allocPoint)
            .div(_totalAllocPoint);

        lockedFatePerSecond = lockedFatePerSecond
            .mul(allocPoint)
            .div(_totalAllocPoint);
    }

    function allLockedFate(
        uint256 _pid,
        address _user
    )
    external
    view
    returns (uint256)
    {
        return controller.pendingLockedFate(_pid, _user).add(controller.userLockedRewards(_pid, _user));
    }
}

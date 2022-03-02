// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IFateRewardController.sol";

// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once FATE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract FateRewardControllerV2Reader {

    IFateRewardController controller;

    constructor(address _controller) public {
        controller = IFateRewardController(_controller);
    }

    function getAllocPoint(uint _pid) external view returns (uint) {
        (, uint allocPoint,,) = controller.poolInfo(_pid);
        return allocPoint;
    }

    function totalAllocPoint() external view returns (uint) {
        return controller.totalAllocPoint();
    }

    function getAllPendingFate(address user) external view returns (uint) {
        uint pendingFate = 0;
        uint poolLength = controller.poolLength();
        for (uint i = 0; i < poolLength; i++) {
            pendingFate += controller.pendingFate(i, user);
        }
        return pendingFate;
    }

}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockLpToken {

    address internal rewardController;
    address internal lpToken;

    event MockLpTokenCreated(address indexed lpToken);

    constructor(
        address _lpToken,
        address _rewardController
    ) public {
        lpToken = _lpToken;
        rewardController = _rewardController;
        emit MockLpTokenCreated(_lpToken);
    }

    function balanceOf(address) external view returns (uint) {
        return IERC20(lpToken).balanceOf(rewardController);
    }

}
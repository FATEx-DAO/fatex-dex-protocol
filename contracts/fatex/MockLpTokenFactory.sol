// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IMockLpTokenFactory.sol";
import "./MockLpToken.sol";

contract MockLpTokenFactory is IMockLpTokenFactory {

    function create(
        address _lpToken,
        address _rewardController
    ) external override returns (address) {
        return address(new MockLpToken(_lpToken, _rewardController));
    }

}

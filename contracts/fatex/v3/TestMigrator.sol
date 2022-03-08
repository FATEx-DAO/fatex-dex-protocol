// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "../IMigratorChef.sol";
import "../MockLpToken.sol";

contract TestMigrator is IMigratorChef {

    function migrate(IERC20 token) external override returns (IERC20) {
        MockLpToken lpToken = new MockLpToken(address(token), msg.sender);
        return IERC20(address(lpToken));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./IFateRewardController.sol";
import "./IRewardSchedule.sol";
import "./MockLpToken.sol";
import "./FateRewardControllerVault.sol";

contract FateRewardControllerUpgrader is Ownable {

    IFateRewardController public controllerV1;
    IFateRewardController public controllerV2;
    FateRewardControllerVault public vault;

    constructor(
        IFateRewardController _controllerV1,
        IFateRewardController _controllerV2,
        FateRewardControllerVault _vault
    ) public {
        controllerV1 = _controllerV1;
        controllerV2 = _controllerV2;
        vault = _vault;
    }

    function performMigrationAndPassOwnership() public onlyOwner {
        require(
            controllerV1.owner() == address(this),
            "performMigrationAndPassOwnership: controllerV1 invalid owner (before)"
        );
        require(
            controllerV2.owner() == address(this),
            "performMigrationAndPassOwnership: controllerV2 invalid owner (before)"
        );
        require(
            vault.owner() == address(this),
            "performMigrationAndPassOwnership: vault invalid owner (before)"
        );
        require(
            vault.controller() == address(controllerV1),
            "performMigrationAndPassOwnership: vault invalid controller (before)"
        );

        controllerV1.setMigrator(IMigratorChef(address(controllerV2)));
        for (uint i = 0; i < 36; i++) {
            controllerV1.migrate(i);
            (IERC20 lpTokenV1, uint256 allocPointV1, uint256 lastRewardBlockV1, uint256 accumulatedFatePerShareV1) = controllerV1.poolInfo(i);
            (IERC20 lpTokenV2, uint256 allocPointV2, uint256 lastRewardBlockV2, uint256 accumulatedFatePerShareV2) = controllerV2.poolInfo(i);
            require(
                address(lpTokenV1) == address(lpTokenV2),
                "performMigrationAndPassOwnership: invalid LP token (during)"
            );
            require(
                allocPointV1 == allocPointV2,
                "performMigrationAndPassOwnership: invalid alloc points (during)"
            );
            require(
                lastRewardBlockV1 == lastRewardBlockV2,
                "performMigrationAndPassOwnership: invalid last reward block (during)"
            );
            require(
                accumulatedFatePerShareV1 == accumulatedFatePerShareV2,
                "performMigrationAndPassOwnership: invalid accumulated fate per share (during)"
            );
        }

        controllerV1.setMigrator(IMigratorChef(address(0)));
        vault.setRewardController(address(controllerV2));

        require(
            address(controllerV1.migrator()) == address(0),
            "performMigrationAndPassOwnership: controllerV1 invalid migrator (after)"
        );
        require(
            vault.controller() == address(controllerV2),
            "performMigrationAndPassOwnership: vault invalid controller (after)"
        );

        // pass control back to the owner
        controllerV1.transferOwnership(owner());
        controllerV2.transferOwnership(owner());
        vault.transferOwnership(owner());

        require(
            controllerV1.owner() == owner(),
            "performMigrationAndPassOwnership: controllerV1 invalid owner (after)"
        );
        require(
            controllerV2.owner() == owner(),
            "performMigrationAndPassOwnership: controllerV2 invalid owner (after)"
        );
        require(
            vault.owner() == owner(),
            "performMigrationAndPassOwnership: vault invalid owner (after)"
        );
    }

    function controllerTransferOwnership() public onlyOwner {
        controllerV1.transferOwnership(owner());
        controllerV2.transferOwnership(owner());
        vault.transferOwnership(owner());
    }

}

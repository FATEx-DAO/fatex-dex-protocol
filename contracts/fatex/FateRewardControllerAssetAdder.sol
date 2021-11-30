// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../uniswap-v2/interfaces/IUniswapV2Pair.sol";

import "./IFateRewardController.sol";

contract FateRewardControllerAssetAdder is Ownable {

    IFateRewardController public controller;

    constructor(
        IFateRewardController _controller
    ) public {
        controller = _controller;
    }

    function addMany(
        IERC20[] calldata pairs
    ) external onlyOwner {
        require(
            controller.owner() == address(this),
            "addMany: controller invalid owner (before)"
        );

        for (uint i = 0; i < pairs.length; i++) {
            (uint112 reserves0, uint112 reserves1,) = IUniswapV2Pair(address(pairs[i])).getReserves();
            require(
                reserves0 > 0 && reserves1 > 0,
                "addMany: invalid reserves"
            );
            bool shouldUpdate = i == pairs.length - 1;
            controller.add(0 /* allocPoint */, pairs[i], shouldUpdate);
        }

        // pass control back to the owner
        controller.transferOwnership(owner());

        require(
            controller.owner() == owner(),
            "addMany: controller invalid owner (after)"
        );
    }

    function controllerTransferOwnership() public onlyOwner {
        controller.transferOwnership(owner());
    }

}

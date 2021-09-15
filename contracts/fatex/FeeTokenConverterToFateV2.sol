// SPDX-License-Identifier: MIT

// P1 - P3: OK
pragma solidity 0.6.12;

import "./FeeTokenConverterToFate.sol";

// This contract handles giving rewards to xFATE holders by trading tokens collected from fees for FATE.

// T1 - T4: OK
contract FeeTokenConverterToFateV2 is FeeTokenConverterToFate {

    event LogInsufficientBalance(
        address indexed server,
        address indexed token0,
        address indexed token1
    );

    constructor(
        address _factory,
        address _xFate,
        address _fate,
        address _weth
    )
    public
    FeeTokenConverterToFate(_factory, _xFate, _factory, _weth) {
    }

    // F1 - F10: OK
    // C1- C24: OK
    function _convert(address token0, address token1) internal override {
        // Interactions
        // S1 - S4: OK
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(token0, token1));
        require(address(pair) != address(0), "FeeTokenConverterToFateV2: Invalid pair");

        if (pair.balanceOf(address(this)) < 0) {
            emit LogInsufficientBalance(
                msg.sender,
                token0,
                token1
            );
        } else {
            super._convert(token0, token1);
        }
    }

}

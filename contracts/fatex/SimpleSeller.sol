// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../uniswap-v2/UniswapV2Router02.sol";

contract SimpleSeller is Ownable {
    using SafeERC20 for IERC20;

    IERC20 fate;
    UniswapV2Router02 router;
    address beneficiary;

    constructor(
        IERC20 _fate,
        UniswapV2Router02 _router,
        address _beneficiary
    ) public {
        fate = _fate;
        router = _router;
        beneficiary = _beneficiary;
    }

    function setBeneficiary(
        address _beneficiary
    )
    external
    onlyOwner {
        require(_beneficiary != address(0), "INVALID_ADDRESS");
        require(_beneficiary != address(this), "INVALID_ADDRESS");
        beneficiary = _beneficiary;
    }

    function withdrawTokens() external onlyOwner {
        // withdraws FATE back to the owner
        IERC20(address(fate)).safeTransfer(owner(), IERC20(address(fate)).balanceOf(address(this)));
    }

    function saveTokens(
        address _token
    ) external {
        // For saving random tokens that are sent to this address. Anyone can call this
        require(_token != address(fate), "INVALID_TOKEN");
        IERC20(_token).safeTransfer(owner(), IERC20(_token).balanceOf(address(this)));
    }

    function sellSome(
        uint _amount,
        uint _amountOutMin,
        address[] calldata _path
    )
    external {
        require(msg.sender == beneficiary, "INVALID_SENDER");
        require(_path[0] == address(fate), "INVALID_PATH");

        router.swapExactTokensForTokens(_amount, _amountOutMin, _path, beneficiary, block.timestamp);
    }

}

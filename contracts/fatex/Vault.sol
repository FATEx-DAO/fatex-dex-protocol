// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vault is Ownable {
    using SafeERC20 for IERC20;

    address public fate;
    address public controller;

    constructor(
        address _fate,
        address _controller
    ) public {
        fate = _fate;
        controller = _controller;
    }

    function withdrawTokens() external onlyOwner {
        // withdraws FATE back to the owner
        IERC20(fate).safeTransfer(owner(), IERC20(fate).balanceOf(address(this)));
    }

    function saveTokens(
        address _token
    ) external {
        // For saving random tokens that are sent to this address. Anyone can call this
        require(_token != fate, "INVALID_TOKEN");
        IERC20(_token).safeTransfer(owner(), IERC20(_token).balanceOf(address(this)));
    }

    function setRewardController(
        address _controller
    )
    public
    onlyOwner {
        if (controller != address(0)) {
            // reset the allowance on the old controller
            IERC20(fate).safeApprove(controller, 0);
        }

        controller = _controller;

        if (controller != address(0)) {
            // set the allowance on the new controller
            IERC20(fate).safeApprove(controller, uint(- 1));
        }
    }

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vault is Ownable {
    using SafeERC20 for IERC20;

    address public fate;

    constructor(
        address _fate,
        address _owner
    ) public {
        fate = _fate;
        transferOwnership(_owner);
    }

    function withdrawTokens(uint amount) external onlyOwner {
        // withdraws FATE back to the owner
        amount = amount > IERC20(fate).balanceOf(address(this)) ? IERC20(fate).balanceOf(address(this)) : amount;
        IERC20(fate).safeTransfer(owner(), amount);
    }

    function saveTokens(
        address _token
    ) external {
        // For saving random tokens that are sent to this address. Anyone can call this
        require(_token != fate, "INVALID_TOKEN");
        IERC20(_token).safeTransfer(owner(), IERC20(_token).balanceOf(address(this)));
    }

}

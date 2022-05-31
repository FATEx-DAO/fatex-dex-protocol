// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleVault is Ownable {
    using SafeERC20 for IERC20;

    address public immutable FATE;

    constructor(
        address _fate,
        address _owner
    ) public {
        FATE = _fate;
        transferOwnership(_owner);
    }

    function withdrawTokens(uint amount) external onlyOwner {
        // withdraws FATE back to the owner
        uint balance = IERC20(FATE).balanceOf(address(this));
        amount = amount > balance ? balance : amount;
        IERC20(FATE).safeTransfer(owner(), amount);
    }

    function saveTokens(
        address _token
    ) external {
        // For saving random tokens that are sent to this address. Anyone can call this
        require(_token != FATE, "INVALID_TOKEN");
        IERC20(_token).safeTransfer(owner(), IERC20(_token).balanceOf(address(this)));
    }
}

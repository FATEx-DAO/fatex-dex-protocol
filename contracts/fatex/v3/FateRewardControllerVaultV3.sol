// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FateRewardControllerVaultV3 is Ownable {
    using SafeERC20 for IERC20;

    address public immutable fate;

    constructor(
        address _fate
    ) public {
        fate = _fate;
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

    function addRewardController(
        address _controller
    )
    public
    onlyOwner {
        IERC20(fate).safeApprove(_controller, uint(- 1));
    }

    function removeRewardController(
        address _controller
    )
    public
    onlyOwner {
        IERC20(fate).safeApprove(_controller, 0);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./FateToken.sol";

// This contract handles swapping to and from xFATE, FATE's staking token.
contract XFateToken is FateToken {
    using SafeMath for uint256;

    FateToken public fate;

    // Define the FATE token contract
    constructor(FateToken _fate) FateToken(msg.sender, 0) public {
        fate = _fate;

        name = "xFATExDAO";
        symbol = "xFATE";
    }

    // Locks FATE and mints xFATE
    function enter(uint256 _amount) public {

        // Gets the amount of FATE locked in the contract
        uint256 totalFate = fate.balanceOf(address(this));
        // Gets the amount of xFATE in existence
        uint256 totalShares = totalSupply;

        if (delegates[msg.sender] == address(0)) {
            // initialize delegation
            delegates[msg.sender] = fate.delegates(msg.sender) == address(0) ? msg.sender : fate.delegates(msg.sender);
        }

        if (totalShares == 0 || totalFate == 0) {
            // If no xFATE exists, mint it 1:1 to the amount put in
            _mint(msg.sender, safe96(_amount, "XFateToken::enter: invalid amount"));
        } else {
            // Calculate and mint the amount of xFATE the FATE is worth. The ratio will change overtime, as xFATE is
            // burned/minted and FATE deposited + gained from fees / withdrawn.
            uint96 what = safe96(_amount.mul(totalShares).div(totalFate), "XFateToken::enter: invalid amount");
            _mint(msg.sender, what);
        }

        // Lock the FATE in the contract
        fate.transferFrom(msg.sender, address(this), _amount);
    }

    // Unlocks the staked + gained FATE and burns xFATE
    function leave(uint256 _share) public {
        // Gets the amount of xFATE in existence
        uint256 totalShares = totalSupply;

        _burn(msg.sender, safe96(_share, "XFateToken::leave: invalid share amount"));

        // Calculates the amount of FATE the xFATE is worth
        uint256 what = _share.mul(fate.balanceOf(address(this))).div(totalShares);
        fate.transfer(msg.sender, what);
    }

    function _mint(address account, uint96 amount) internal virtual {
        require(account != address(0), "XFateToken::_mint: zero address");

        balances[account] = add96(balances[account], amount, "XFateToken::_mint: balances overflow");

        uint96 _totalSupply = safe96(totalSupply, "XFateToken::_mint: invalid total supply");
        totalSupply = add96(_totalSupply, amount, "XFateToken::_mint: total supply overflow");

        emit Transfer(address(0), account, amount);

        _moveDelegates(address(0), delegates[account], amount);
    }

    function _burn(address account, uint96 amount) internal virtual {
        require(account != address(0), "XFateToken: burn from the zero address");

        balances[account] = sub96(balances[account], amount, "XFateToken::_burn: amount exceeds balance");

        uint96 _totalSupply = safe96(totalSupply, "XFateToken::_burn: invalid total supply");
        totalSupply = sub96(_totalSupply, amount, "XFateToken::_burn: amount exceeds total supply");

        emit Transfer(account, address(0), amount);

        _moveDelegates(delegates[account], address(0), amount);
    }
}

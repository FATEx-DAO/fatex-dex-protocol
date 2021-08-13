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
    constructor(FateToken _fate) public {
        fate = _fate;
    }

    function name() public override view virtual returns (string memory) {
        return "xFATExDAO Token";
    }

    function symbol() public override view virtual returns (string memory) {
        return "xFATE";
    }

    // Locks FATE and mints xFATE
    function enter(uint256 _amount) public {
        // Gets the amount of FATE locked in the contract
        uint256 totalFATE = fate.balanceOf(address(this));
        // Gets the amount of xFATE in existence
        uint256 totalShares = totalSupply();

        if (_delegates[msg.sender] == address(0)) {
            // initialize delegation
            _delegates[msg.sender] = fate.delegates(msg.sender) == address(0) ? msg.sender : fate.delegates(msg.sender);
        }

        if (totalShares == 0 || totalFATE == 0) {
            // If no xFATE exists, mint it 1:1 to the amount put in
            _mint(msg.sender, _amount);
            _moveDelegates(address(0), _delegates[msg.sender], _amount);
        } else {
            // Calculate and mint the amount of xFATE the FATE is worth. The ratio will change overtime, as xFATE is
            // burned/minted and FATE deposited + gained from fees / withdrawn.
            uint256 what = _amount.mul(totalShares).div(totalFATE);
            _mint(msg.sender, what);
            _moveDelegates(address(0), _delegates[msg.sender], what);
        }

        // Lock the FATE in the contract
        fate.transferFrom(msg.sender, address(this), _amount);
    }

    // Unlocks the staked + gained FATE and burns xFATE
    function leave(uint256 _share) public {
        // Gets the amount of xFATE in existence
        uint256 totalShares = totalSupply();

        // Calculates the amount of FATE the xFATE is worth
        uint256 what = _share.mul(fate.balanceOf(address(this))).div(totalShares);

        _burn(msg.sender, _share);
        _moveDelegates(
            address(0),
            _delegates[msg.sender],
            getCurrentVotes(_delegates[msg.sender]).mul(_share).div(totalShares)
        );
        fate.transfer(msg.sender, what);
    }
}

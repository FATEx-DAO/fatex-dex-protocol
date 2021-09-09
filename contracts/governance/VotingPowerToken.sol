// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../uniswap-v2/interfaces/IUniswapV2Pair.sol";
import "../uniswap-v2/interfaces/IUniswapV2Factory.sol";

import "../fatex/FateRewardController.sol";
import "../fatex/FateToken.sol";
import "../fatex/XFateToken.sol";

contract VotingPowerToken {
    using SafeMath for uint;

    FateToken fate;
    XFateToken xFate;
    FateRewardController controller;
    IUniswapV2Factory factory;

    constructor(
        address _fate,
        address _xFate,
        address _controller,
        address _factory
    ) public {
        fate = FateToken(_fate);
        xFate = XFateToken(_xFate);
        controller = FateRewardController(_controller);
        factory = IUniswapV2Factory(_factory);
    }

    function name() public pure returns (string memory) {
        return "FATE Voting Power";
    }

    function symbol() public pure returns (string memory) {
        return "FATE-GOV";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function allowance(address, address) public pure returns (uint256) {
        return 0;
    }

    function transfer(address, uint256) public pure returns (bool) {
        return false;
    }

    function approve(address, uint256) public pure returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) public pure returns (bool) {
        return false;
    }

    function totalSupply() public returns (uint) {
        address[] memory lpTokens = _getAllFateLpTokens();
        address _fate = address(fate);
        uint lpTotalSupply = 0;
        for (uint i = 0; i < lpTokens.length; i++) {
            if (lpTokens[i] != address(0)) {
                (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(lpTokens[i]).getReserves();
                uint reserves = IUniswapV2Pair(lpTokens[i]).token0() == _fate ? reserve0 : reserve1;
                lpTotalSupply = lpTotalSupply.add(reserves);
            }
        }

        return fate.totalSupply().add(_xFateToFate(xFate.totalSupply())).add(lpTotalSupply);
    }

    function balanceOf(address user) public returns (uint) {
        address[] memory lpTokens = _getAllFateLpTokens();
        address _fate = address(fate);
        uint lpBalance = 0;
        for (uint i = 0; i < lpTokens.length; i++) {
            if (lpTokens[i] != address(0)) {
                uint userBalance = _getUserFateBalance(lpTokens[i], i, _fate, user);
                lpBalance = lpBalance.add(userBalance);
            }
        }

        return fate.balanceOf(user).add(_xFateToFate(xFate.balanceOf(user))).add(lpBalance);
    }

    function _xFateToFate(uint amount) private view returns (uint) {
        uint _totalSupply = xFate.totalSupply();
        if (_totalSupply == 0) {
            return 0;
        } else {
            return amount.mul(fate.balanceOf(address(xFate))).div(_totalSupply);
        }
    }

    function _getUserFateBalance(
        address lpToken,
        uint lpTokenIndex,
        address _fate,
        address user
    ) private view returns (uint) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(lpToken).getReserves();
        IERC20 token = IERC20(lpToken);
        uint reserves = IUniswapV2Pair(lpToken).token0() == _fate ? reserve0 : reserve1;
        (uint lpBalance,) = controller.userInfo(lpTokenIndex, user);
        lpBalance = lpBalance.add(token.balanceOf(user));
        return lpBalance.mul(reserves).div(token.totalSupply());
    }

    function _getAllFateLpTokens() private returns (address[] memory) {
        uint poolLength = controller.poolLength();
        address[] memory tokens = new address[](poolLength);
        for (uint i = 0; i < poolLength; i++) {
            (IERC20 lpToken,,,) = controller.poolInfo(i);
            IUniswapV2Pair pair = IUniswapV2Pair(address(lpToken));
            address token0 = _callToken(pair, pair.token0.selector);
            address token1 = _callToken(pair, pair.token1.selector);
            if (token0 == address(fate) || token1 == address(fate)) {
                tokens[i] = address(pair);
            }
        }
        return tokens;
    }

    function _callToken(IUniswapV2Pair pair, bytes4 selector) private returns (address) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        (bool success, bytes memory returnData) = address(pair).call(abi.encodePacked(selector));
        if (!success || returnData.length == 0) {
            return address(0);
        } else {
            return abi.decode(returnData, (address));
        }
    }

}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../uniswap-v2/interfaces/IUniswapV2Pair.sol";
import "../uniswap-v2/interfaces/IUniswapV2Factory.sol";

import "../fatex/IFateRewardController.sol";

contract VotingPowerToken {
    using SafeMath for uint;

    IERC20 fate;
    IERC20 xFate;
    IFateRewardController controller;
    IUniswapV2Factory factory;

    enum PairType {
        FATE, X_FATE
    }

    struct LpTokenPair {
        address lpToken;
        PairType pairType;
    }

    constructor(
        address _fate,
        address _xFate,
        address _controller,
        address _factory
    ) public {
        fate = IERC20(_fate);
        xFate = IERC20(_xFate);
        controller = IFateRewardController(_controller);
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

    function totalSupply() public view returns (uint) {
        LpTokenPair[] memory lpTokens = _getAllFateLpTokens();
        address _fate = address(fate);
        address _xFate = address(xFate);
        uint lpTotalSupply = 0;
        for (uint i = 0; i < lpTokens.length; i++) {
            if (lpTokens[i].lpToken != address(0)) {
                (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(lpTokens[i].lpToken).getReserves();
                uint reserves;
                if (lpTokens[i].pairType == PairType.FATE) {
                    reserves = IUniswapV2Pair(lpTokens[i].lpToken).token0() == _fate ? reserve0 : reserve1;
                } else {
                    require(lpTokens[i].pairType == PairType.X_FATE, "totalSupply: invalid pairType");

                    reserves = IUniswapV2Pair(lpTokens[i].lpToken).token0() == _xFate ? reserve0 : reserve1;
                    reserves = _xFateToFate(reserves);
                }
                lpTotalSupply = lpTotalSupply.add(reserves);
            }
        }

        return fate.totalSupply().add(_xFateToFate(xFate.totalSupply())).add(lpTotalSupply);
    }

    function balanceOf(address user) public view returns (uint) {
        LpTokenPair[] memory lpTokens = _getAllFateLpTokens();
        address _fate = address(fate);
        address _xFate = address(xFate);
        uint lpBalance = 0;
        for (uint i = 0; i < lpTokens.length; i++) {
            if (lpTokens[i].lpToken != address(0)) {
                uint userBalance = _getUserFateBalance(lpTokens[i], i, _fate, _xFate, user);
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
        LpTokenPair memory pair,
        uint lpTokenIndex,
        address _fate,
        address _xFate,
        address user
    ) private view returns (uint) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair.lpToken).getReserves();
        if (reserve0 == 0 || reserve1 == 0) {
            return 0;
        }

        IERC20 token = IERC20(pair.lpToken);

        uint reserves;
        if (pair.pairType == PairType.FATE) {
            reserves = IUniswapV2Pair(pair.lpToken).token0() == _fate ? reserve0 : reserve1;
        } else {
            require(pair.pairType == PairType.X_FATE, "totalSupply: invalid pairType");

            reserves = IUniswapV2Pair(pair.lpToken).token0() == _xFate ? reserve0 : reserve1;
            reserves = _xFateToFate(reserves);
        }

        (uint lpBalance,) = controller.userInfo(lpTokenIndex, user);
        lpBalance = lpBalance.add(token.balanceOf(user));

        return lpBalance.mul(reserves).div(token.totalSupply());
    }

    function _getAllFateLpTokens() private view returns (LpTokenPair[] memory) {
        uint poolLength = controller.poolLength();
        LpTokenPair[] memory pairs = new LpTokenPair[](poolLength);
        address _fate = address(fate);
        address _xFate = address(xFate);
        for (uint i = 0; i < poolLength; i++) {
            (IERC20 lpToken,,,) = controller.poolInfo(i);
            IUniswapV2Pair pair = IUniswapV2Pair(address(lpToken));
            address token0 = _callToken(pair, pair.token0.selector);
            address token1 = _callToken(pair, pair.token1.selector);
            if (token0 == _fate || token1 == _fate) {
                pairs[i] = LpTokenPair(address(lpToken), PairType.FATE);
            } else if (token0 == _xFate || token1 == _xFate) {
                pairs[i] = LpTokenPair(address(lpToken), PairType.X_FATE);
            }
        }
        return pairs;
    }

    function _callToken(IUniswapV2Pair pair, bytes4 selector) private view returns (address) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        (bool success, bytes memory returnData) = address(pair).staticcall(abi.encodePacked(selector));
        if (!success || returnData.length == 0) {
            return address(0);
        } else {
            return abi.decode(returnData, (address));
        }
    }

}

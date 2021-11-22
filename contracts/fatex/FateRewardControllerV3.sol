// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./IFateRewardController.sol";


/**
    TODO List
    1. new point system
    2. migrate from previous to new
    3. check rank or sort gas consume
 */
contract FateRewardControllerV3 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 constant public POINTS_PER_BLOCK = 0.08e18;
    uint256 immutable public EPOCH_END_BLOCK;
    mapping(uint256 => address[]) public depositedUsers;

    // Info of each user
    struct UserInfoV3 {
        uint256 amount;
        bool isUpdated;
        uint256 firstDepositBlock;
        uint256 indexOfList;
        uint256 rankNumber;
    }

    // Info of each pool.
    IFateRewardController.PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfoV3)) internal _userInfo;

    constructor(
        uint256 _epoch_end_block
    ) public {
        EPOCH_END_BLOCK = _epoch_end_block;
    }


    // Deposit LP tokens
    function deposit(uint256 _pid, uint256 _amount) public {
        IFateRewardController.PoolInfo storage pool = poolInfo[_pid];
        UserInfoV3 storage user = _userInfo[_pid][msg.sender];

        // deposit LP tokens to here
        pool.lpToken.safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        // update userInfo
        uint userAmount = user.amount;
        uint userFirstDepositBlock = user.firstDepositBlock;
        uint userIndexOfList = user.indexOfList;
        uint256 userRankNumber = 2 ** 256 - 1;

        if (userAmount == 0) {
            // initial deposit
            userFirstDepositBlock = block.number;
            userIndexOfList = 0;
        } else {
            // deposited before
            userIndexOfList = depositedUsers[_pid].length - 1;
        }
        depositedUsers[_pid].push(msg.sender);

        _userInfo[_pid][msg.sender] = UserInfoV3({
            amount: userAmount,
            isUpdated: true,
            firstDepositBlock: userFirstDepositBlock,
            indexOfList: userIndexOfList,
            rankNumber: userRankNumber
        });        
    }

    // Withdraw LP tokens
    function withdraw(uint256 _pid, uint256 _amount) public {
        IFateRewardController.PoolInfo storage pool = poolInfo[_pid];
        UserInfoV3 storage user = _userInfo[_pid][msg.sender];
        require(user.amount >= _amount && user.amount > 0, "withdraw: not good");

        // withdraw LP
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        
        // update userInfo
        uint userAmount = user.amount.sub(_amount);

        _userInfo[_pid][msg.sender] = UserInfoV3({
            amount: userAmount,
            isUpdated: true,
            firstDepositBlock: user.firstDepositBlock,
            indexOfList: user.indexOfList,
            rankNumber: user.rankNumber
        });

    }

    // Check Points earned
    function earnedPoints(uint256 _pid, address _user) public view returns (uint256){
        UserInfoV3 memory user = _userInfo[_pid][_user];

        if (user.firstDepositBlock > 0) {
            uint256 lastBlock = block.number;
            uint256 deposited_period_blocks = lastBlock > EPOCH_END_BLOCK ? EPOCH_END_BLOCK : lastBlock;
            return deposited_period_blocks * POINTS_PER_BLOCK;
        } else {
            return 0;
        }
    }

    // rank users
    function rank(uint256 _pid) public returns (uint256) {
        address[] memory pool_deposited_user_list = depositedUsers[_pid];
        uint256 deposited_user_counts = pool_deposited_user_list.length;
        require(deposited_user_counts > 0, "rank: no_deposited_users_yet");
        

        uint256[] memory pointsList = new uint256[](deposited_user_counts);
        for(uint i = 0; i < deposited_user_counts; i++) {
            pointsList[i] = earnedPoints(_pid, pool_deposited_user_list[i]);
        }

        uint256[] memory sortedPointsList = sort(pointsList);
        for (uint i = 0; i < deposited_user_counts; i++) {
            address userAddr = depositedUsers[_pid][i];
            UserInfoV3 memory user = _userInfo[_pid][userAddr];

            _userInfo[_pid][userAddr] = UserInfoV3({
                amount: user.amount,
                isUpdated: user.isUpdated,
                firstDepositBlock: user.firstDepositBlock,
                indexOfList: user.indexOfList,
                rankNumber: getIndex(sortedPointsList, pointsList[i])
            });
        }
    }

    // library to sort array
    function quickSort(uint[] memory arr, int left, int right) internal pure {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = arr[uint(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint(i)] < pivot) i++;
            while (pivot < arr[uint(j)]) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j) {
            quickSort(arr, left, j);
        }
        if (i < right) {
            quickSort(arr, i, right);
        }
    }

    function sort(uint[] memory data) internal pure returns (uint[] memory) {
        quickSort(data, int(0), int(data.length - 1));
        return data;
    }

    function getIndex(uint[] memory data, uint num) internal pure returns (uint index) {
        for(uint i = 0; i < data.length; i++) {
            if (data[i] == num) {
                index = i;
            }
        }
    }
}
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "hardhat/console.sol";
import "../../libraries/RankedArray.sol";

////////////////////////////////////////////////////////////////////////////////////////////
/// @title MembershipWithPoints
/// @author @commonlot
////////////////////////////////////////////////////////////////////////////////////////////
abstract contract MembershipWithPoints {
    uint256 constant public POINTS_PER_BLOCK = 0.08e18;
    uint256 public EPOCH_END_BLOCK;

    struct MembershipInfo{
        uint256 firstDepositBlock; // set when first deposit
        uint256 rankedNumber;
        uint256 lastWithdrawBlock; // set when first deposit, updates whenever withdraws
    }

    // pid => depositors' address array
    mapping(uint256 => address[]) public depositedUsers;

    // pid => address => membershipInfo
    mapping(uint256 => mapping (address => MembershipInfo)) public userMembershipInfo;
    
    /// @dev record deposit block
    function recordDepositBlock(uint256 _pid, address _user) internal {
        uint256 currentBlockNumber = block.number;
        require(currentBlockNumber <= EPOCH_END_BLOCK, "recordDepositBlock: epoch ended");

        uint256 userIndex = _getIndexOfArray(depositedUsers[_pid], _user);

        if(userIndex == depositedUsers[_pid].length) {
            // not recored yet (first deposit)
            depositedUsers[_pid].push(_user);
            userMembershipInfo[_pid][_user] = MembershipInfo({
                firstDepositBlock: currentBlockNumber,
                rankedNumber: 2 ** 256 - 1,
                lastWithdrawBlock: currentBlockNumber
            });
        }
    }

    function getEndBlock() internal view returns(uint256 endBlock) {
        uint256 currentBlockNumber = block.number;
        endBlock = currentBlockNumber > EPOCH_END_BLOCK ? EPOCH_END_BLOCK : currentBlockNumber;
    }

    /// @dev calculate Points earned by this user
    function userPoints(uint256 _pid, address _user) public view returns (uint256 points){
        MembershipInfo memory membership = userMembershipInfo[_pid][_user];
        points = (getEndBlock() - membership.firstDepositBlock) * POINTS_PER_BLOCK;
    }

    /// @dev rank with Points and set rankedNumber to each user
    function rank(uint256 _pid) public returns (uint256) {
        address[] memory pool_deposited_user_list = depositedUsers[_pid];
        uint256 deposited_user_counts = pool_deposited_user_list.length;
        require(deposited_user_counts > 0, "rank: no_deposited_users_yet");
        

        uint256[] memory pointsList = new uint256[](deposited_user_counts);
        for(uint i = 0; i < deposited_user_counts; i++) {
            pointsList[i] = userPoints(_pid, pool_deposited_user_list[i]);
        }

        uint256[] memory sortedPointsList = RankedArray.sort(pointsList);
        for (uint i = 0; i < deposited_user_counts; i++) {
            address userAddr = depositedUsers[_pid][i];
            MembershipInfo memory membership = userMembershipInfo[_pid][userAddr];

            userMembershipInfo[_pid][userAddr] = MembershipInfo({
                firstDepositBlock: membership.firstDepositBlock,
                rankedNumber: RankedArray.getIndex(sortedPointsList, pointsList[i]),
                lastWithdrawBlock: membership.lastWithdrawBlock
            });
        }
    }

    /// @dev library to get index of an array of address list
    function _getIndexOfArray(address[] memory data, address addr) internal pure returns (uint256 index) {
        index = data.length;
        for (uint i=0; i < data.length; i++) {
            if (data[i] == addr) index = i;
        }
    }
}
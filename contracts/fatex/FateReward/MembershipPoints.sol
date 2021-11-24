// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "hardhat/console.sol";
import "../../libraries/RankedArray.sol";

////////////////////////////////////////////////////////////////////////////////////////////
/// @title CWToken
/// @author MembershipPoint
////////////////////////////////////////////////////////////////////////////////////////////
contract MembershipPoints {
    uint256 constant public POINTS_PER_BLOCK = 0.08e18;
    uint256 immutable public EPOCH_END_BLOCK;

    struct MembershipInfo{
        uint256 depositBlock;
        uint256 rankedNumber;
    }

    // pid => depositors' address array
    mapping(uint256 => address[]) public depositedUsers;

    // pid => address => membershipInfo
    mapping(uint256 => mapping (address => MembershipInfo)) public userMembershipInfo;

    constructor(uint256 epoch_start_block) public {
        EPOCH_END_BLOCK = epoch_start_block + 8 weeks;
    }
    
    /// @notice record deposit block
    function recordDepositBlock(uint256 _pid, address _user) public {
        /**
            TODO: 
            - if external user calls this, remove _user in param and use msg.sender
            - if FateRewardController is calling this, add `onlyFateRewardController` logic for validation
         */
        require(block.number <= EPOCH_END_BLOCK, "recordDepositBlock: epoch ended");
        uint256 userIndex = _getIndexOfArray(depositedUsers[_pid], _user);
        if(userIndex == depositedUsers[_pid].length) {
            // not recored yet
            depositedUsers[_pid].push(_user);
            userMembershipInfo[_pid][_user] = MembershipInfo({
                depositBlock: block.number,
                rankedNumber: 2 ** 256 - 1
            });
        }
    }


    /// @notice calculate Points earned by this user
    function userPoints(uint256 _pid, address _user) public view returns (uint256 points){
        MembershipInfo memory membership = userMembershipInfo[_pid][_user];
        
        uint256 currentBlock = block.number;
        uint256 endBlock = currentBlock > EPOCH_END_BLOCK ? EPOCH_END_BLOCK : currentBlock;

        points = (endBlock - membership.depositBlock) * POINTS_PER_BLOCK;
    }

    /// @notice rank with Points and set rankedNumber to each user
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
                depositBlock: membership.depositBlock,
                rankedNumber: RankedArray.getIndex(sortedPointsList, pointsList[i])
            });
        }
    }

    /// @notice library to get index of an array of address list
    function _getIndexOfArray(address[] memory data, address addr) internal pure returns (uint256 index) {
        index = data.length;
        for (uint i=0; i < data.length; i++) {
            if (data[i] == addr) index = i;
        }
    }
}
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../libraries/RankedArray.sol";

////////////////////////////////////////////////////////////////////////////////////////////
/// @title MembershipWithPoints
/// @author @commonlot
////////////////////////////////////////////////////////////////////////////////////////////
abstract contract MembershipWithPoints is Ownable {
    uint256 constant public POINTS_PER_BLOCK = 0.08e18;
    uint256 public epochEndBlock;

    struct MembershipInfo{
        uint256 firstDepositBlock; // set when first deposit
        uint256 rankedNumber;
        uint256 lastWithdrawBlock; // set when first deposit, updates whenever withdraws
    }

    // pid => depositors' address array
    mapping(uint256 => address[]) public depositedUsers;

    // pid => address => membershipInfo
    mapping(uint256 => mapping (address => MembershipInfo)) public userMembershipInfo;

    mapping(uint256 => bool) public isFatePool;

    mapping(address => bool) public isExcludedAddress;

    /// @dev set FatePool Ids
    function setFatePoolIds(uint256[] memory pids) external onlyOwner {
        require(pids.length > 0, "setFatePoolIds: invalid pids");
        for (uint i = 0; i < pids.length; i++) {
            isFatePool[pids[i]] = true;
        }
    }

    /// @dev set excluded addresses
    function setExcludedAddresses(address[] memory accounts) external onlyOwner {
        require(accounts.length > 0, "setExcludedAddresses: invalid accounts");
        for (uint i = 0; i < accounts.length; i++) {
            isExcludedAddress[accounts[i]] = true;
        }
    }
    
    /// @dev record deposit block
    function _recordDepositBlock(uint256 _pid, address _user) internal {
        uint256 currentBlockNumber = block.number;
        require(currentBlockNumber <= epochEndBlock, "_recordDepositBlock: epoch ended");

        uint256 userIndex = _getIndexOfArray(depositedUsers[_pid], _user);

        if (userIndex == depositedUsers[_pid].length) {
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
        endBlock = currentBlockNumber > epochEndBlock ? epochEndBlock : currentBlockNumber;
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
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../IRewardSchedule.sol";
import "../../libraries/RankedArray.sol";

abstract contract FateRewardControllerBase is Ownable {
    // The emission scheduler that calculates fate per block over a given period
    IRewardSchedule public emissionSchedule;

    uint256 public punitivePeriod = 8 weeks;

    mapping(uint256 => bool) public isFatePool;
    mapping(address => bool) public isExcludedAddress;

    /// @dev charged FateLockedReward Fees that users should pay
    mapping(address => uint256) public lockedRewardDebit;

    /// @dev data for FateLockedRewardFee
    uint256[] public lockedRewardsPeriodBlocks = [
        30,
        60,
        120,
        3600,
        86400,
        172800,
        259200,
        345600,
        432000,
        518400,
        604800,
        691200, 
        777600,
        864000, 
        950400,
        1036800,
        1123200, 
        1209600,
        1296000,
        1382400, 
        1468800, 
        1555200
    ];
    uint256[] public lockedRewardsFeePercents = [
        1e18,
        0.98e18,
        0.97e18,
        0.9e18,
        0.8e18,
        0.75e18,
        0.7e18,
        0.65e18,
        0.6e18,
        0.55e18, 
        0.5e18,
        0.45e18,
        0.4e18,
        0.35e18,
        0.3e18,
        0.25e18,
        0.2e18,
        0.15e18, 
        0.1e18,
        0.03e18,
        0.01e18,
        0.005e18
    ];

    /// @dev data for LPWithdrawFee
    uint256[] public lpWithdrawPeriodBlocks = [
        1,
        8,
        24,
        72,
        336,
        672,
        888
    ];
    uint256[] public lpWithdrawFeePercent = [
        18e18,
        8e18,
        3.60e18,
        1.43e18,
        0.80e18,
        0.36e18,
        0.18e18
    ];

    event LockedRewardsDataSet(uint256[] _lockedRewardsPeriodBlocks, uint256[] _lockedRewardsFeePercents);
    event LPWithdrawDataSet(uint256[] _lpWithdrawPeriodBlocks, uint256[] _lpWithdrawFeePercent);
    event ExcludedAddressSet(address _account, bool _status);

    /// @dev set lockedRewardsPeriodBlocks & lockedRewardsFeePercents
    function setLockedRewardsData(
        uint256[] memory _lockedRewardsPeriodBlocks,
        uint256[] memory _lockedRewardsFeePercents
    ) external onlyOwner {
        require(
            _lockedRewardsPeriodBlocks.length > 0 &&
            _lockedRewardsPeriodBlocks.length == _lockedRewardsFeePercents.length,
            "setLockedRewardsData: invalid input data"
        );
        lockedRewardsPeriodBlocks = _lockedRewardsPeriodBlocks;
        lockedRewardsFeePercents = _lockedRewardsFeePercents;

        emit LockedRewardsDataSet(_lockedRewardsPeriodBlocks, _lockedRewardsFeePercents);
    }

    /// @dev set lpWithdrawPeriodBlocks & lpWithdrawFeePercent
    function setLPWithdrawData(
        uint256[] memory _lpWithdrawPeriodBlocks,
        uint256[] memory _lpWithdrawFeePercent
    ) external onlyOwner {
        require(
            _lpWithdrawPeriodBlocks.length == _lpWithdrawFeePercent.length,
            "setLPWithdrawData: not same length"
        );
        lpWithdrawPeriodBlocks = _lpWithdrawPeriodBlocks;
        lpWithdrawFeePercent = _lpWithdrawFeePercent;

        emit LPWithdrawDataSet(_lpWithdrawPeriodBlocks, _lpWithdrawFeePercent);
    }

    /// @dev set FatePool Ids
    function setFatePoolIds(uint256[] memory pids) external onlyOwner {
        require(pids.length > 0, "setFatePoolIds: invalid pids");
        for (uint i = 0; i < pids.length; i++) {
            isFatePool[pids[i]] = true;
        }
    }

    /// @dev set excluded addresses
    function setExcludedAddresses(address[] memory accounts, bool[] memory status) external onlyOwner {
        require(
            accounts.length > 0 &&
            accounts.length == status.length,
            "setExcludedAddresses: invalid data"
        );
        for (uint i = 0; i < accounts.length; i++) {
            isExcludedAddress[accounts[i]] = status[i];
            emit ExcludedAddressSet(accounts[i], status[i]);
        }
    }
}

abstract contract MembershipWithReward is FateRewardControllerBase {
    uint256 constant public POINTS_PER_BLOCK = 0.08e18;

    struct MembershipInfo {
        uint256 firstDepositBlock; // set when first deposit
        uint256 rankedNumber;
        uint256 lastWithdrawBlock; // set when first deposit, updates whenever withdraws
    }

    // pid => depositors' address array
    mapping(uint256 => address[]) public depositedUsers;

    // pid => address => membershipInfo
    mapping(uint256 => mapping (address => MembershipInfo)) public userMembershipInfo;

    /// @dev record deposit block
    function _recordDepositBlock(uint256 _pid, address _user) internal {
        if (isFatePool[_pid]) {
            uint256 currentBlockNumber = block.number;
            require(
                currentBlockNumber <= emissionSchedule.epochEndBlock(),
                "_recordDepositBlock: epoch ended"
            );

            uint256 userIndex = RankedArray.getIndexOfAddressArray(
                depositedUsers[_pid],
                _user
            );
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
    }

    /// @dev calculate Points earned by this user
    function userPoints(uint256 _pid, address _user) public returns (uint256 points){
        points = _getBlocksOfPeriod(
            _pid,
            _user,
            true
        ) * POINTS_PER_BLOCK;
    }

    /// @dev rank with Points and set rankedNumber to each user
    function rank(uint256 _pid) public returns (uint256) {
        if (isFatePool[_pid]) {
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
    }

    function _getBlocksOfPeriod(
        uint256 _pid,
        address _user,
        bool _isDepositPeriod
    ) internal returns (uint256 blocksOfPeriod) {
        if (isFatePool[_pid]) {
            uint256 currentBlockNumber = block.number;
            uint256 epochEndBlock = emissionSchedule.epochEndBlock();
            uint256 endBlock = currentBlockNumber > epochEndBlock ? epochEndBlock : currentBlockNumber;

            MembershipInfo memory membership = userMembershipInfo[_pid][_user];
            uint256 startBlock = _isDepositPeriod ? membership.firstDepositBlock : membership.lastWithdrawBlock;
            
            if (endBlock >= startBlock) {
                blocksOfPeriod = endBlock - startBlock;
            }
        }
    }

    /// @dev calculate lockedRewardsFees as percent that will be sent to the rewardController
    function _getLockedRewardsFeePercent(
        uint256 _pid,
        address _caller
    ) internal returns(uint256 percent) {
        if (isExcludedAddress[_caller]) {
            percent = 0;
        } else {
            percent = lockedRewardsFeePercents[
                RankedArray.getIndexOfBlocks(
                    _getBlocksOfPeriod(
                        _pid,
                        _caller,
                        true
                    ),
                    lockedRewardsPeriodBlocks
                )
            ];
        }
    }

    /// @dev calculate lpWithdrawFees as percent that will be sent to the rewardController
    function _getLPWithdrawFeePercent(uint256 _pid, address _caller) internal returns(uint256 percent) {
        if (isExcludedAddress[_caller]) {
            percent = 0;
        } else {
            percent = lpWithdrawFeePercent[
                RankedArray.getIndexOfBlocks(
                    _getBlocksOfPeriod(
                        _pid,
                        _caller,
                        false
                    ),
                    lpWithdrawPeriodBlocks
                )
            ];
        }
    }
}
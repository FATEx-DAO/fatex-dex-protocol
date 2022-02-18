// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../../libraries/RankedArray.sol";

import "./IRewardScheduleV3.sol";
import "./IFateRewardControllerV3.sol";
import "./IMembershipWithReward.sol";

abstract contract MembershipWithReward is Ownable, IMembershipWithReward {
    using SafeMath for uint256;

    uint256 constant public POINTS_PER_BLOCK = 0.08e18;

    // The emission scheduler that calculates fate per block over a given period
    IRewardScheduleV3 public emissionSchedule;

    struct MembershipInfo {
        uint256 firstDepositBlock; // set when first deposit
        uint256 lastWithdrawBlock; // set when first deposit, updates whenever withdraws
    }

    mapping(address => bool) public isExcludedAddress;

    // pid => address => membershipInfo
    mapping(uint256 => mapping (address => MembershipInfo)) public override userMembershipInfo;

    // pid ==> address ==> tracked points
    mapping(uint256 => mapping (address => uint256)) public trackedPoints;

    /// @dev pid => user address => lockedRewards
    mapping(uint256 => mapping (address => uint256)) public userLockedRewards;

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
        10000,
        9800,
        9700,
        9000,
        8800,
        8800,
        8000,
        7200,
        6300,
        5800,
        5000,
        4500,
        4000,
        3500,
        3000,
        2500,
        2000,
        1500,
        800,
        360,
        180,
        80
    ];

    /// @dev data for LPWithdrawFee
    uint256[] public lpWithdrawPeriodBlocks = [
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
    uint256[] public lpWithdrawFeePercent = [
        10000,
        8800,
        7200,
        3600,
        1800,
        888,
        888,
        888,
        360,
        360,
        360,
        360,
        180,
        180,
        180,
        180,
        180,
        180,
        180,
        88,
        88,
        18,
        8
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

    /// @dev calculate index of LockedRewardFee data
    function _getPercentFromBlocks(
        uint256 periodBlocks,
        uint256[] memory blocks,
        uint256[] memory percents
    ) internal pure returns (uint256) {
        if (periodBlocks < blocks[0]) {
            return percents[0];
        } else if (periodBlocks > blocks[blocks.length - 1]) {
            return 0;
        } else {
            for (uint i = 0; i < blocks.length - 1; i++) {
                if (
                    periodBlocks > blocks[i] &&
                    periodBlocks <= blocks[i + 1]
                ) {
                    return percents[i];
                }
            }
            revert("_getPercentFromBlocks: should have returned value");
        }
    }

    function getBlockNumber() external view returns (uint256) {
        return block.number;
    }


    function _getBlocksOfPeriod(
        uint256 _pid,
        address _user,
        bool _isDepositPeriod
    ) internal view returns (uint256) {
        uint256 endBlock = block.number;
        uint256 startBlock = _isDepositPeriod ?
            userMembershipInfo[_pid][_user].firstDepositBlock : userMembershipInfo[_pid][_user].lastWithdrawBlock;

        uint256 blocks = 0;
        if (startBlock != 0 && endBlock >= startBlock) {
            blocks = endBlock - startBlock;
        }
        return blocks;
    }

    /// @dev calculate percent of lockedRewardFee based on their deposit period
    /// when withdraw during epoch, this fee will be reduced from member's lockedRewards
    /// this fee does not work for excluded address and after epoch is ended
    function getLockedRewardsFeePercent(
        uint256 _pid,
        address _caller
    ) public view returns (uint256) {
        if (isExcludedAddress[_caller]) {
            return 0;
        } else {
            return _getPercentFromBlocks(
                _getBlocksOfPeriod(
                    _pid,
                    _caller,
                    true
                ),
                lockedRewardsPeriodBlocks,
                lockedRewardsFeePercents
            );
        }
    }

    /// @dev calculate percent of lpWithdrawFee based on their deposit period
    /// when users withdaw during epoch, this fee will be reduced from their withdrawAmount
    /// this fee will be still stored on FateRewardControllerV3 contract
    /// this fee does not work for excluded address and after epoch is ended
    function getLPWithdrawFeePercent(
        uint256 _pid,
        address _caller
    ) public view returns (uint256) {
        if (isExcludedAddress[_caller]) {
            return 0;
        } else {
            return _getPercentFromBlocks(
                _getBlocksOfPeriod(
                    _pid,
                    _caller,
                    false
                ),
                lpWithdrawPeriodBlocks,
                lpWithdrawFeePercent
            );
        }
    }
}

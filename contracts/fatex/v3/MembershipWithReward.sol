// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../../libraries/RankedArray.sol";

import "./IFateRewardControllerV3.sol";
import "./IMembershipWithReward.sol";

abstract contract MembershipWithReward is Ownable, IMembershipWithReward {
    using SafeMath for uint256;

    uint256 constant public POINTS_PER_SECOND = 0.04e18;

    struct MembershipInfo {
        uint256 firstDepositTimestamp; // set when first deposit
        uint256 lastWithdrawTimestamp; // set when first deposit, updates whenever withdraws
    }

    mapping(address => bool) public isExcludedAddress;

    // pid => address => membershipInfo
    mapping(uint256 => mapping (address => MembershipInfo)) public override userMembershipInfo;

    // pid ==> address ==> tracked points
    mapping(uint256 => mapping (address => uint256)) public override trackedPoints;

    /// @dev pid => user address => lockedRewards
    mapping(uint256 => mapping (address => uint256)) public override userLockedRewards;

    /// @dev data for FateLockedRewardFee
    uint256[] public lockedRewardsPeriodTimestamps = [
        60,
        120,
        240,
        7200,
        172800,
        345600,
        518400,
        691200,
        864000,
        1036800,
        1209600,
        1382400,
        1555200,
        1728000,
        1900800,
        2073600,
        2246400,
        2419200,
        2592000,
        2764800,
        2937600,
        3110400
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
    uint256[] public lpWithdrawPeriodTimestamps = [
        60,
        120,
        240,
        7200,
        172800,
        345600,
        518400,
        691200,
        864000,
        1036800,
        1209600,
        1382400,
        1555200,
        1728000,
        1900800,
        2073600,
        2246400,
        2419200,
        2592000,
        2764800,
        2937600,
        3110400
    ];

    uint256[] public lpWithdrawFeePercent = [
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

    event LockedRewardsDataSet(uint256[] _lockedRewardsPeriodTimestamps, uint256[] _lockedRewardsFeePercents);
    event LPWithdrawDataSet(uint256[] _lpWithdrawPeriodTimestamps, uint256[] _lpWithdrawFeePercent);
    event ExcludedAddressSet(address _account, bool _status);

    /// @dev set lockedRewardsPeriodTimestamps & lockedRewardsFeePercents
    function setLockedRewardsData(
        uint256[] memory _lockedRewardsPeriodTimestamps,
        uint256[] memory _lockedRewardsFeePercents
    ) external onlyOwner {
        require(
            _lockedRewardsPeriodTimestamps.length > 0 &&
            _lockedRewardsPeriodTimestamps.length == _lockedRewardsFeePercents.length,
            "setLockedRewardsData: invalid input data"
        );
        lockedRewardsPeriodTimestamps = _lockedRewardsPeriodTimestamps;
        lockedRewardsFeePercents = _lockedRewardsFeePercents;

        emit LockedRewardsDataSet(_lockedRewardsPeriodTimestamps, _lockedRewardsFeePercents);
    }

    /// @dev set lpWithdrawPeriodTimestamps & lpWithdrawFeePercent
    function setLPWithdrawData(
        uint256[] memory _lpWithdrawPeriodTimestamps,
        uint256[] memory _lpWithdrawFeePercent
    ) external onlyOwner {
        require(
            _lpWithdrawPeriodTimestamps.length == _lpWithdrawFeePercent.length,
            "setLPWithdrawData: not same length"
        );
        lpWithdrawPeriodTimestamps = _lpWithdrawPeriodTimestamps;
        lpWithdrawFeePercent = _lpWithdrawFeePercent;

        emit LPWithdrawDataSet(_lpWithdrawPeriodTimestamps, _lpWithdrawFeePercent);
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
    function _getPercentFromTimestamp(
        uint256 periodTimestamp,
        uint256[] memory timestamps,
        uint256[] memory percents
    ) internal pure returns (uint256) {
        if (periodTimestamp < timestamps[0]) {
            return percents[0];
        } else if (periodTimestamp > timestamps[timestamps.length - 1]) {
            return 0;
        } else {
            for (uint i = 0; i < timestamps.length - 1; i++) {
                if (
                    periodTimestamp > timestamps[i] &&
                    periodTimestamp <= timestamps[i + 1]
                ) {
                    return percents[i + 1];
                }
            }
            revert("_getPercentFromTimestamp: should have returned value");
        }
    }

    function _getDurationInPosition(
        uint256 _pid,
        address _user,
        bool _isDepositPeriod
    ) internal view returns (uint256) {
        uint256 endTimestamp = block.timestamp;
        uint256 startTimestamp = _isDepositPeriod ?
            userMembershipInfo[_pid][_user].firstDepositTimestamp : userMembershipInfo[_pid][_user].lastWithdrawTimestamp;

        uint256 duration = 0;
        if (startTimestamp != 0 && endTimestamp >= startTimestamp) {
            duration = endTimestamp - startTimestamp;
        }
        return duration;
    }

    /// @dev calculate percent of lockedRewardFee based on their deposit period
    /// when withdraw during epoch, this fee will be reduced from member's lockedRewards
    /// this fee does not work for excluded address and after epoch is ended
    function getLockedRewardsFeePercent(
        uint256 _pid,
        address _user
    ) public view returns (uint256) {
        if (isExcludedAddress[_user]) {
            return 0;
        } else {
            return _getPercentFromTimestamp(
                _getDurationInPosition(
                    _pid,
                    _user,
                    false
                ),
                lockedRewardsPeriodTimestamps,
                lockedRewardsFeePercents
            );
        }
    }

    /// @dev calculate percent of lpWithdrawFee based on their deposit period
    /// when users withdraw during epoch, this fee will be reduced from their withdrawAmount
    /// this fee will be still stored on FateRewardControllerV3 contract
    /// this fee does not work for excluded address
    function getLPWithdrawFeePercent(
        uint256 _pid,
        address _user
    ) public view returns (uint256) {
        if (isExcludedAddress[_user]) {
            return 0;
        } else {
            return _getPercentFromTimestamp(
                _getDurationInPosition(
                    _pid,
                    _user,
                    false
                ),
                lpWithdrawPeriodTimestamps,
                lpWithdrawFeePercent
            );
        }
    }
}

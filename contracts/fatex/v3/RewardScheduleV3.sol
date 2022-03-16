// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "hardhat/console.sol";
import "../../utils/SafeMathLocal.sol";

import "./IRewardScheduleV3.sol";

contract RewardScheduleV3 is IRewardScheduleV3 {
    using SafeMathLocal for uint;

    uint256 constant public epochPeriods = 9 weeks; // 18 weeks for epoch 2

    /// @notice This is the emission schedule for each second for a given week. These numbers represent how much FATE is
    ///         rewarded per second. Each index represents a week. The starting day/week, according to the Reward
    ///         Controller was 2021-08-26T19:43:45.000Z (UTC time). Meaning, week 2 started on 2021-09-02T19:43:45.000Z
    ///         (UTC time).
    uint[72] public FATE_PER_SECOND = [
        // epoch 1 (week1 ~ week13) is ended
        0.00e18,    // week 1
        0.00e18,    // week 2
        0.00e18,    // week 3
        0.00e18,    // week 4
        0.00e18,    // week 5
        0.00e18,    // week 6
        0.00e18,    // week 7
        0.00e18,    // week 8
        0.00e18,    // week 9
        0.00e18,    // week 10
        0.00e18,    // week 11
        0.00e18,    // week 12
        0.00e18,    // week 13
        36.00e18,   // week 14
        36.51e18,   // week 15
        37.02e18,   // week 16
        37.54e18,   // week 17
        38.06e18,   // week 18
        38.60e18,   // week 19
        39.14e18,   // week 20
        13.6187700022e18,   // week 21
        0.00e18,    // week 22
        0.00e18,    // week 23
        0.00e18,    // week 24
        0.00e18,    // week 25
        0.00e18,    // week 26
        0.00e18,    // week 27
        0.00e18,    // week 28
        0.00e18,    // week 29
        0.00e18,    // week 30
        0.00e18,    // week 31
        0.00e18,    // week 32
        0.00e18,    // week 33
        0.00e18,    // week 34
        0.00e18,    // week 35
        0.00e18,    // week 36
        0.00e18,    // week 37
        0.00e18,    // week 38
        0.00e18,    // week 39
        0.00e18,    // week 40
        0.00e18,    // week 41
        0.00e18,    // week 42
        0.00e18,    // week 43
        0.00e18,    // week 44
        0.00e18,    // week 45
        0.00e18,    // week 46
        0.00e18,    // week 47
        0.00e18,    // week 48
        0.00e18,    // week 49
        0.00e18,    // week 50
        0.00e18,    // week 51
        0.00e18,    // week 52
        0.00e18,    // week 53
        0.00e18,    // week 54
        0.00e18,    // week 55
        0.00e18,    // week 56
        0.00e18,    // week 57
        0.00e18,    // week 58
        0.00e18,    // week 59
        0.00e18,    // week 60
        0.00e18,    // week 61
        0.00e18,    // week 62
        0.00e18,    // week 63
        0.00e18,    // week 64
        0.00e18,    // week 65
        0.00e18,    // week 66
        0.00e18,    // week 67
        0.00e18,    // week 68
        0.00e18,    // week 69
        0.00e18,    // week 70
        0.00e18,    // week 71
        0.00e18     // week 72
    ];

    // 60 seconds per minute, 60 minutes per hour, 24 hours per day, 7 days per week
    uint public constant SECONDS_PER_WEEK = 60 * 60 * 24 * 7;

    constructor() public {
    }

    function rewardsNumberOfWeeks() external view returns (uint) {
        return FATE_PER_SECOND.length;
    }

    function lockedPercent(uint index) public pure override returns (uint) {
        if (index >= 0 && index < 8) {
            return 92;
        } else {
            return 92;
        }
    }

    /**
     * @param index The week at which the amount of FATE per second should be rewarded. Index starts at 0, meaning index
     *              1 is actually week 2. Index 12 is week 13.
     */
    function getFateAtIndex(uint index)
    public
    view
    returns (uint, uint) {
        if (index >= 0 && index < 8) {
            // vesting occurs at an 92/8 for the first 8 weeks
            return (
                FATE_PER_SECOND[index] * lockedPercent(index) / 100,
                FATE_PER_SECOND[index] * (100 - lockedPercent(index)) / 100
            );
        } else {
            return (0, 0);
        }
    }

    function calculateCurrentIndex(
        uint _startTimestamp
    ) public override view returns (uint) {
        return (block.timestamp - _startTimestamp) / SECONDS_PER_WEEK;
    }

    function getFateForDuration(
        uint _startTimestamp,
        uint _fromTimestamp,
        uint _toTimestamp
    )
    external
    override
    view
    returns (uint, uint) {

        if (_startTimestamp > _toTimestamp || _fromTimestamp == _toTimestamp) {
            return (0, 0);
        }
        if (_fromTimestamp < _startTimestamp) {
            _fromTimestamp = _startTimestamp;
        }

        require(
            _fromTimestamp <= _toTimestamp,
            "RewardScheduleV3::getFatePerSecond: INVALID_RANGE"
        );

        uint endTimestampExclusive = _startTimestamp + (FATE_PER_SECOND.length * SECONDS_PER_WEEK);

        if (_fromTimestamp >= endTimestampExclusive) {
            return (0, 0);
        }

        if (_toTimestamp >= endTimestampExclusive) {
            _toTimestamp = endTimestampExclusive - 1;
        }

        uint fromIndex = (_fromTimestamp - _startTimestamp) / SECONDS_PER_WEEK;
        uint toIndex = (_toTimestamp - _startTimestamp) / SECONDS_PER_WEEK;

        if (fromIndex < toIndex) {
            uint secondsAtIndex = SECONDS_PER_WEEK - ((_fromTimestamp - _startTimestamp) % SECONDS_PER_WEEK);
            (uint lockedFatePerSecond, uint unlockedFatePerSecond) = getFateAtIndex(fromIndex);
            lockedFatePerSecond = secondsAtIndex * lockedFatePerSecond;
            unlockedFatePerSecond = secondsAtIndex * unlockedFatePerSecond;

            for (uint i = fromIndex + 1; i < toIndex; i++) {
                (uint lockedFatePerSecond2, uint unlockedFatePerSecond2) = getFateAtIndex(i);
                lockedFatePerSecond += lockedFatePerSecond2 * SECONDS_PER_WEEK;
                unlockedFatePerSecond += unlockedFatePerSecond2 * SECONDS_PER_WEEK;
            }

            secondsAtIndex = (_toTimestamp - _startTimestamp) % SECONDS_PER_WEEK;
            (uint lockedFatePerSecond3, uint unlockedFatePerSecond3) = getFateAtIndex(toIndex);

            return (
                lockedFatePerSecond + secondsAtIndex * lockedFatePerSecond3,
                unlockedFatePerSecond + secondsAtIndex * unlockedFatePerSecond3
            );
        } else {

            assert(fromIndex == toIndex);
            (uint lockedFatePerSecond, uint unlockedFatePerSecond) = getFateAtIndex(fromIndex);
            return (
                lockedFatePerSecond * (_toTimestamp - _fromTimestamp),
                unlockedFatePerSecond * (_toTimestamp - _fromTimestamp)
            );
        }
    }
}

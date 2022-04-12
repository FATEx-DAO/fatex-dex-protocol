// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../../utils/SafeMathLocal.sol";

import "./IRewardScheduleV3.sol";

contract RewardScheduleV3 is IRewardScheduleV3 {
    using SafeMathLocal for uint;

    uint256 constant public epochPeriods = 9 weeks; // 18 weeks for epoch 2

    /// @notice This is the emission schedule for each second for a given week. These numbers represent how much FATE is
    ///         rewarded per second. Each index represents a week. The starting day/week, according to the Reward
    ///         Controller was XYZ (UTC time). Meaning, week 2 (index 1, since indices start at 0) starts on
    ///         XYZ (UTC time).
    uint[72] public FATE_PER_SECOND = [
        2.0000e18,    // week 1
        2.0350e18,    // week 2
        2.0750e18,    // week 3
        2.1100e18,    // week 4
        2.1500e18,    // week 5
        2.1850e18,    // week 6
        2.2250e18,    // week 7
        2.2650e18,    // week 8
        2.3050e18,    // week 9
        2.3500e18,    // week 10
        2.3900e18,    // week 11
        2.4350e18,    // week 12
        2.4750e18,    // week 13
        2.5200e18,    // week 14
        2.5650e18,    // week 15
        2.6150e18,    // week 16
        2.6600e18,    // week 17
        2.7100e18,    // week 18
        2.7550e18,    // week 19
        2.8050e18,    // week 20
        2.8550e18,    // week 21
        2.9100e18,    // week 22
        2.9600e18,    // week 23
        3.0150e18,    // week 24
        3.0700e18,    // week 25
        3.1250e18,    // week 26
        3.1800e18,    // week 27
        3.2400e18,    // week 28
        3.2950e18,    // week 29
        3.3550e18,    // week 30
        3.4150e18,    // week 31
        3.4750e18,    // week 32
        3.5400e18,    // week 33
        3.6050e18,    // week 34
        3.6700e18,    // week 35
        3.7350e18,    // week 36
        3.8000e18,    // week 37
        3.8700e18,    // week 38
        3.9400e18,    // week 39
        4.0100e18,    // week 40
        4.0850e18,    // week 41
        4.1550e18,    // week 42
        4.2300e18,    // week 43
        4.3050e18,    // week 44
        4.3850e18,    // week 45
        4.4650e18,    // week 46
        4.5450e18,    // week 47
        4.6250e18,    // week 48
        4.7100e18,    // week 49
        4.7950e18,    // week 50
        4.8800e18,    // week 51
        4.9700e18,    // week 52
        0.0000e18,    // week 53
        0.0000e18,    // week 54
        0.0000e18,    // week 55
        0.0000e18,    // week 56
        0.0000e18,    // week 57
        0.0000e18,    // week 58
        0.0000e18,    // week 59
        0.0000e18,    // week 60
        0.0000e18,    // week 61
        0.0000e18,    // week 62
        0.0000e18,    // week 63
        0.0000e18,    // week 64
        0.0000e18,    // week 65
        0.0000e18,    // week 66
        0.0000e18,    // week 67
        0.0000e18,    // week 68
        0.0000e18,    // week 69
        0.0000e18,    // week 70
        0.0000e18,    // week 71
        0.0000e18     // week 72
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

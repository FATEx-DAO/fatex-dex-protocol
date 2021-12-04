// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../../utils/SafeMathLocal.sol";

import "./IRewardScheduleV3.sol";

contract RewardScheduleV3 is IRewardScheduleV3 {
    using SafeMathLocal for uint;

    uint immutable public override epochStartBlock;
    uint immutable public override epochEndBlock;
    uint immutable public override lockedPercent;    // 1e18 for 100%

    /// @notice This is the emission schedule for each block for a given week. These numbers represent how much FATE is
    ///         rewarded per block. Each index represents a week. The starting day/week, according to the Reward
    ///         Controller was 2021-08-26T19:43:45.000Z (UTC time). Meaning, week 2 started on 2021-09-02T19:43:45.000Z
    ///         (UTC time).
    uint[72] public FATE_PER_BLOCK = [
        0.00e18,   // week 1
        0.00e18,   // week 2
        0.00e18,   // week 3
        0.00e18,   // week 4
        0.00e18,   // week 5
        0.00e18,   // week 6
        0.00e18,   // week 7
        0.00e18,   // week 8
        0.00e18,   // week 9
        0.00e18,   // week 10
        0.00e18,   // week 11
        0.00e18,   // week 12
        0.00e18,   // week 13
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

    // 30 blocks per minute, 60 minutes per hour, 24 hours per day, 7 days per week
    uint public constant BLOCKS_PER_WEEK = 30 * 60 * 24 * 7;

    constructor(
        uint _epochStartBlock,
        uint _epochPeriodBlocks,
        uint _lockedPercent
    ) public {
        require(
            _lockedPercent < 1e18,
            "RewardScheduleV3::Contructor: invalid params"
        );
        epochStartBlock = _epochStartBlock;
        epochEndBlock = _epochStartBlock + _epochPeriodBlocks;
        lockedPercent = _lockedPercent;
    }

    function rewardsNumberOfWeeks() external view returns (uint) {
        return FATE_PER_BLOCK.length;
    }

    /**
     * @param index The week at which the amount of FATE per block should be rewarded. Index starts at 0, meaning index
     *              1 is actually week 2. Index 12 is week 13.
     */
    function getFateAtIndex(uint index)
    public
    view
    returns (uint, uint) {
        if (index >= 13) {
            // vesting occurs at an 100-lockedPercent/lockedPercent rate for the first 13 weeks
            return (
                FATE_PER_BLOCK[index] * lockedPercent / 1e18,
                FATE_PER_BLOCK[index] * (1e18 - lockedPercent) / 1e18
            );
        } else {
            return (0, 0);
        }
    }

    function calculateCurrentIndex(
        uint _startBlock
    ) public override view returns (uint) {
        return (block.number - _startBlock) / BLOCKS_PER_WEEK;
    }

    /// @notice returns the average amount of FATE earned per block over any block period. If spanned over multiple
    /// weeks, a weighted average is calculated. Both _fromBlock and _toBlock are inclusive
    function getFatePerBlock(
        uint _startBlock,
        uint _fromBlock,
        uint _toBlock
    )
    external
    override
    view
    returns (uint, uint) {
        if (_startBlock > _toBlock || _fromBlock == _toBlock) {
            return (0, 0);
        }
        if (_fromBlock < _startBlock) {
            _fromBlock = _startBlock;
        }

        require(
            _fromBlock <= _toBlock,
            "RewardScheduleV3::getFatePerBlock: INVALID_RANGE"
        );

        uint endBlockExclusive = _startBlock + (FATE_PER_BLOCK.length * BLOCKS_PER_WEEK);

        if (_fromBlock >= endBlockExclusive) {
            return (0, 0);
        }

        if (_toBlock >= endBlockExclusive) {
            _toBlock = endBlockExclusive - 1;
        }

        uint fromIndex = (_fromBlock - _startBlock) / BLOCKS_PER_WEEK;
        uint toIndex = (_toBlock - _startBlock) / BLOCKS_PER_WEEK;

        if (fromIndex < toIndex) {
            uint blocksAtIndex = BLOCKS_PER_WEEK - ((_fromBlock - _startBlock) % BLOCKS_PER_WEEK);
            (uint lockedFatePerBlock, uint unlockedFatePerBlock) = getFateAtIndex(fromIndex);
            lockedFatePerBlock = blocksAtIndex * lockedFatePerBlock;
            unlockedFatePerBlock = blocksAtIndex * unlockedFatePerBlock;

            for (uint i = fromIndex + 1; i < toIndex; i++) {
                (uint lockedFatePerBlock2, uint unlockedFatePerBlock2) = getFateAtIndex(i);
                lockedFatePerBlock += lockedFatePerBlock2 * BLOCKS_PER_WEEK;
                unlockedFatePerBlock += unlockedFatePerBlock2 * BLOCKS_PER_WEEK;
            }

            blocksAtIndex = (_toBlock - _startBlock) % BLOCKS_PER_WEEK;
            (uint lockedFatePerBlock3, uint unlockedFatePerBlock3) = getFateAtIndex(toIndex);

            return (
                lockedFatePerBlock + blocksAtIndex * lockedFatePerBlock3,
                unlockedFatePerBlock + blocksAtIndex * unlockedFatePerBlock3
            );
        } else {
            // indices are the same
            assert(fromIndex == toIndex);
            (uint lockedFatePerBlock, uint unlockedFatePerBlock) = getFateAtIndex(fromIndex);
            return (
                lockedFatePerBlock * (_toBlock - _fromBlock),
                unlockedFatePerBlock * (_toBlock - _fromBlock)
            );
        }
    }
}

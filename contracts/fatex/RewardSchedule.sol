// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../utils/SafeMathLocal.sol";

contract RewardSchedule {
    using SafeMathLocal for uint;

    /// @notice This is the emission schedule for each block for a given week. These numbers represent how much FATE is
    ///         rewarded per block. Each index represents a week.
    uint[72] public FATE_PER_BLOCK = [
    36.00e18,   // week 1
    36.51e18,   // week 2
    37.02e18,   // week 3
    37.54e18,   // week 4
    38.06e18,   // week 5
    38.60e18,   // week 6
    39.14e18,   // week 7
    39.69e18,   // week 8
    40.24e18,   // week 9
    40.81e18,   // week 10
    41.38e18,   // week 11
    41.96e18,   // week 12
    42.55e18,   // week 13
    72.00e18,   // week 14
    0.00e18,    // week 15
    0.00e18,    // week 16
    0.00e18,    // week 17
    0.00e18,    // week 18
    0.00e18,    // week 19
    0.00e18,    // week 20
    0.00e18,    // week 21
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

    constructor() public {
    }

    function rewardsNumberOfWeeks() external view returns (uint) {
        return FATE_PER_BLOCK.length;
    }

    /**
     * @param index The week at which the amount of FATE per block should be rewarded. Index starts at 0, meaning index
     *              1 is actually week 2. Index 12 is week 13.
     */
    function getFateAtIndex(uint index) public view returns (uint) {
        if (index < 13) {
            // vesting occurs at an 80/20 rate for the first 13 weeks
            return FATE_PER_BLOCK[index] * 2 / 10;
        } else {
            return FATE_PER_BLOCK[index];
        }
    }

    /// @notice returns the average amount of FATE earned per block over any block period. If spanned over multiple
    /// weeks, a weighted average is calculated. Both _fromBlock and _toBlock are inclusive
    function getFatePerBlock(
        uint _startBlock,
        uint _fromBlock,
        uint _toBlock
    )
    external
    view
    returns (uint) {
        if (_startBlock > _toBlock || _fromBlock == _toBlock) {
            return 0;
        }
        if (_fromBlock < _startBlock) {
            _fromBlock = _startBlock;
        }

        require(
            _fromBlock <= _toBlock,
            "EmissionSchedule::getFatePerBlock: INVALID_RANGE"
        );

        uint endBlockExclusive = _startBlock + (FATE_PER_BLOCK.length * BLOCKS_PER_WEEK);

        if (_fromBlock >= endBlockExclusive) {
            return 0;
        }

        if (_toBlock >= endBlockExclusive) {
            _toBlock = endBlockExclusive - 1;
        }

        uint fromIndex = (_fromBlock - _startBlock) / BLOCKS_PER_WEEK;
        uint toIndex = (_toBlock - _startBlock) / BLOCKS_PER_WEEK;

        if (fromIndex < toIndex) {
            uint points = BLOCKS_PER_WEEK - ((_fromBlock - _startBlock) % BLOCKS_PER_WEEK);
            uint fatePerBlock = points * getFateAtIndex(fromIndex);

            for (uint i = fromIndex + 1; i < toIndex; i++) {
                fatePerBlock = fatePerBlock + (BLOCKS_PER_WEEK * getFateAtIndex(i));
            }

            points = (_toBlock - _startBlock) % BLOCKS_PER_WEEK;
            fatePerBlock = fatePerBlock + (points * getFateAtIndex(toIndex));

            return fatePerBlock / (_toBlock - _fromBlock);
        } else {
            // indices are the same
            assert(fromIndex == toIndex);
            return getFateAtIndex(fromIndex) * (_toBlock - _fromBlock);
        }
    }

}

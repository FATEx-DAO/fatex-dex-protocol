// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../utils/SafeMathLocal.sol";

contract RewardSchedule {
    using SafeMathLocal for uint;

    /// @notice This is the emission schedule for each block for a given week. These numbers represent how much FATE is
    ///         rewarded per block. Each index represents a week. The starting day/week, according to the Reward
    ///         Controller was 2021-08-26T19:43:45.000Z (UTC time). Meaning, week 2 started on 2021-09-02T19:43:45.000Z
    ///         (UTC time).
    uint[72] public FATE_PER_BLOCK = [
    36.00e18,           // week 1
    36.51e18,           // week 2
    37.02e18,           // week 3
    37.54e18,           // week 4
    38.06e18,           // week 5
    38.60e18,           // week 6
    39.14e18,           // week 7
    18.18181818e18,     // week 8
    18.18181818e18,     // week 9
    18.18181818e18,     // week 10
    18.18181818e18,     // week 11
    18.18181818e18,     // week 12
    18.18181818e18,     // week 13
    18.18181818e18,     // week 14
    0.00e18,            // week 15
    0.00e18,            // week 16
    0.00e18,            // week 17
    18.181818e18,       // week 18
    18.181818e18,       // week 19
    18.181818e18,       // week 20
    18.181818e18,       // week 21
    18.181818e18,       // week 22
    18.181818e18,       // week 23
    18.181818e18,       // week 24
    18.181818e18,       // week 25
    18.181818e18,       // week 26
    18.181818e18,       // week 27
    18.181818e18,       // week 28
    18.181818e18,       // week 29
    18.181818e18,       // week 30
    18.181818e18,       // week 31
    18.181818e18,       // week 32
    18.181818e18,       // week 33
    18.181818e18,       // week 34
    18.181818e18,       // week 35
    18.181818e18,       // week 36
    18.181818e18,       // week 37
    18.181818e18,       // week 38
    18.181818e18,       // week 39
    18.181818e18,       // week 40
    18.181818e18,       // week 41
    18.181818e18,       // week 42
    18.181818e18,       // week 43
    18.181818e18,       // week 44
    18.181818e18,       // week 45
    18.181818e18,       // week 46
    18.181818e18,       // week 47
    18.181818e18,       // week 48
    18.181818e18,       // week 49
    18.181818e18,       // week 50
    0.00e18,            // week 51
    0.00e18,            // week 52
    0.00e18,            // week 53
    0.00e18,            // week 54
    0.00e18,            // week 55
    0.00e18,            // week 56
    0.00e18,            // week 57
    0.00e18,            // week 58
    0.00e18,            // week 59
    0.00e18,            // week 60
    0.00e18,            // week 61
    0.00e18,            // week 62
    0.00e18,            // week 63
    0.00e18,            // week 64
    0.00e18,            // week 65
    0.00e18,            // week 66
    0.00e18,            // week 67
    0.00e18,            // week 68
    0.00e18,            // week 69
    0.00e18,            // week 70
    0.00e18,            // week 71
    0.00e18             // week 72
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
            // vesting occurs at an 80 / 20 rate for the first 13 weeks
            return FATE_PER_BLOCK[index] * 2 / 10;
        } else {
            // vesting occurs at an 92 / 8 rate for the rest of this contract
            return FATE_PER_BLOCK[index] * 8 / 100;
        }
    }

    function calculateCurrentIndex(
        uint _startBlock
    ) public view returns (uint) {
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
            uint blocksAtIndex = BLOCKS_PER_WEEK - ((_fromBlock - _startBlock) % BLOCKS_PER_WEEK);
            uint fatePerBlock = blocksAtIndex * getFateAtIndex(fromIndex);

            for (uint i = fromIndex + 1; i < toIndex; i++) {
                fatePerBlock = fatePerBlock + (BLOCKS_PER_WEEK * getFateAtIndex(i));
            }

            blocksAtIndex = (_toBlock - _startBlock) % BLOCKS_PER_WEEK;
            return fatePerBlock + (blocksAtIndex * getFateAtIndex(toIndex));
        } else {
            // indices are the same
            assert(fromIndex == toIndex);
            return getFateAtIndex(fromIndex) * (_toBlock - _fromBlock);
        }
    }

}

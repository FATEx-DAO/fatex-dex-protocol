// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract RewardSchedule {
    using SafeMath for uint;

    // This is the emission schedule for each block for a given week
    uint[72] public FATE_PER_BLOCK = [
    36.00e18,
    36.51e18,
    37.02e18,
    37.54e18,
    38.06e18,
    38.60e18,
    39.14e18,
    39.69e18,
    40.24e18,
    40.81e18,
    41.38e18,
    41.96e18,
    42.55e18,
    72.00e18
    ];

    // 30 blocks per minute, 60 minutes per hour, 24 hours per day, 7 days per week
    uint public constant BLOCKS_PER_WEEK = 30 * 60 * 24 * 7;

    constructor() public {
    }

    function rewardsNumberOfWeeks() external view returns (uint) {
        return FATE_PER_BLOCK.length;
    }

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

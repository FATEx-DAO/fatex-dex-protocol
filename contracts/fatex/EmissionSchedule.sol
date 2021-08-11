// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract EmissionSchedule {
    using SafeMath for uint;

    // This is the emission schedule for each block for a given week
    uint[72] public FATE_PER_BLOCK = [
    36.00e18,
    37.32e18,
    38.69e18,
    40.11e18,
    41.59e18,
    43.11e18,
    44.70e18,
    46.34e18,
    48.04e18,
    49.80e18,
    51.63e18,
    53.53e18,
    143.00e18,
    104.00e18,
    75.64e18,
    55.01e18,
    40.01e18,
    29.10e18,
    21.16e18,
    15.39e18,
    11.19e18,
    8.14e18,
    5.92e18,
    4.31e18,
    3.13e18,
    143.00e18,
    110.50e18,
    85.38e18,
    65.97e18,
    50.98e18,
    39.39e18,
    30.44e18,
    23.52e18,
    18.17e18,
    14.04e18,
    10.85e18,
    8.38e18,
    6.48e18,
    72.00e18,
    74.64e18,
    77.39e18,
    80.23e18,
    83.17e18,
    86.23e18,
    89.39e18,
    92.68e18,
    96.08e18,
    99.61e18,
    103.27e18,
    107.06e18,
    110.99e18,
    115.06e18,
    119.29e18,
    123.67e18,
    128.21e18,
    132.92e18,
    137.80e18,
    142.86e18,
    148.11e18,
    153.55e18,
    159.18e18,
    165.03e18,
    171.09e18,
    177.37e18,
    183.89e18,
    190.64e18,
    197.64e18,
    204.90e18,
    212.42e18,
    220.22e18,
    228.31e18,
    236.69e18
    ];

    // 30 blocks per minute, 60 minutes per hour, 24 hours per day, 7 days per week
    uint public constant BLOCKS_PER_WEEK = 30 * 60 * 24 * 7;

    constructor() public {
    }

    function getFateAtBlock(uint index) public view returns (uint) {
        if (index < 13) {
            // vesting occurs at an 80/20 rate for the first 13 weeks
            return FATE_PER_BLOCK[index] * 2 / 10;
        } else {
            return FATE_PER_BLOCK[index];
        }
    }

    function getFatePerBlock(
        uint _startBlock,
        uint _fromBlock,
        uint _toBlock
    )
    external
    view
    returns (uint) {
        if (_startBlock > _toBlock) {
            return 0;
        }
        if (_fromBlock < _startBlock) {
            _fromBlock = _startBlock;
        }

        require(
            _fromBlock <= _toBlock,
            "EmissionSchedule::getFatePerBlock: INVALID_RANGE"
        );

        uint startIndex = (_fromBlock - _startBlock) / BLOCKS_PER_WEEK;
        uint endIndex = (_toBlock - _startBlock) / BLOCKS_PER_WEEK;

        if (startIndex < endIndex) {
            uint points = BLOCKS_PER_WEEK - ((_fromBlock - _startBlock) % BLOCKS_PER_WEEK);
            uint fatePerBlock = points * getFateAtBlock(startIndex);

            for (uint i = startIndex + 1; i < endIndex; i++) {
                fatePerBlock = BLOCKS_PER_WEEK * getFateAtBlock(i);
            }

            points = (_toBlock - _startBlock) % BLOCKS_PER_WEEK;
            fatePerBlock = fatePerBlock + (points * getFateAtBlock(endIndex));

            return fatePerBlock / (_toBlock - _fromBlock);
        } else {
            // indices are the same
            assert(startIndex == endIndex);
            return getFateAtBlock(startIndex) * (_toBlock - _fromBlock);
        }
    }

}

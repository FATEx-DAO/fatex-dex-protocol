// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IRewardSchedule {

    function getFatePerBlock(
        uint _startBlock,
        uint _fromBlock,
        uint _toBlock
    )
    external
    view
    returns (uint);


    function calculateCurrentIndex(
        uint _startBlock
    )
    external
    view
    returns (uint);

    function epochStartBlock() external returns (uint);
    function epochEndBlock() external returns (uint);
}

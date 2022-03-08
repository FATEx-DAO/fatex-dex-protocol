// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IRewardScheduleV3 {

    /// @notice returns the amount of FATE earned over the provided period. Both _fromTimestamp and _toTimestamp are
    ///         inclusive
    function getFateForDuration(
        uint _startTimestamp,
        uint _fromTimestamp,
        uint _toTimestamp
    )
    external
    view
    returns (uint lockedFatePerSecond, uint unlockedFatePerSecond);


    function calculateCurrentIndex(
        uint _startTimestamp
    )
    external
    view
    returns (uint);

    function lockedPercent(uint index) external pure returns (uint);
}

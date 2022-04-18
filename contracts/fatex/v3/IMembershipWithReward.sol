// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IMembershipWithReward {

    function userLockedRewards(uint256 _pid, address _user) external view returns (uint256);

    function trackedPoints(uint256 _pid, address _user) external view returns (uint256);

    function userMembershipInfo(
        uint _pid,
        address _user
    ) external view returns (uint256 firstDepositTimestamp, uint256 lastWithdrawTimestamp);
}

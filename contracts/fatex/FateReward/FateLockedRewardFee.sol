// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./MembershipWithPoints.sol";

////////////////////////////////////////////////////////////////////////////////////////////
/// @title FateLockedRewardFee
/// @author @commonlot
////////////////////////////////////////////////////////////////////////////////////////////
abstract contract FateLockedRewardFee is MembershipWithPoints {
    /// @dev constnats being used to check lockedRewardsFee
    /// the belows are seconds now, they should be converted to blocks
    uint256[] public lockedRewardsPeriodBlocks = [
        30,
        60,
        120,
        3600,
        86400,
        172800,
        259200,
        345600,
        432000,
        518400,
        604800,
        691200, 
        777600,
        864000, 
        950400,
        1036800,
        1123200, 
        1209600,
        1296000,
        1382400, 
        1468800, 
        1555200
    ];
    uint256[] public lockedRewardsFeePercents = [
        1e18,
        0.98e18,
        0.97e18,
        0.9e18,
        0.8e18,
        0.75e18,
        0.7e18,
        0.65e18,
        0.6e18,
        0.55e18, 
        0.5e18,
        0.45e18,
        0.4e18,
        0.35e18,
        0.3e18,
        0.25e18,
        0.2e18,
        0.15e18, 
        0.1e18,
        0.03e18,
        0.01e18,
        0.005e18
    ];



    /// @dev set lockedRewardsPeriodBlocks & lockedRewardsFeePercents
    function setLockedRewardsData(
        uint256[] memory _lockedRewardsPeriodBlocks,
        uint256[] memory _lockedRewardsFeePercents
    ) external onlyOwner {
        require(
            _lockedRewardsPeriodBlocks.length == _lockedRewardsFeePercents.length,
            "setLockedRewardsData: not same length"
        );
        lockedRewardsPeriodBlocks = _lockedRewardsPeriodBlocks;
        lockedRewardsFeePercents = lockedRewardsFeePercents;
    }

    /// @dev set excluded address that withdrawFee logic will not work
    function setExcludedAddress(address _account, bool isExcluded) external onlyOwner {
        isExcludedAddress[_account] = isExcluded;
    }

    /// @dev calculate lockedRewardsFees as percent that will be sent to the rewardController
    function lockedRewardsFeePercent(
        uint256 _pid,
        address _caller
    ) internal view returns(uint256 percent) {
        
        MembershipInfo memory membership = userMembershipInfo[_pid][_caller];
        uint256 endBlock = getEndBlock();
        if (endBlock > membership.firstDepositBlock) {
            uint256 deposited_period_in_blocks = endBlock - membership.firstDepositBlock;
            percent = lockedRewardsFeePercents[
                getIndexOfBlocks(
                    deposited_period_in_blocks,
                    lockedRewardsPeriodBlocks
                )
            ];
        }
    }

    /// @dev calculate index of LockedRewardFee data
    function getIndexOfBlocks(
        uint256 periodBlocks,
        uint256[] memory blocks
    ) internal pure returns(uint256 index) {
        if (periodBlocks < blocks[0]) {
            index = 0;
        } else if (periodBlocks > blocks[blocks.length - 1]) {
            index = blocks.length - 1;
        } else {
            for (uint i = 0; i < blocks.length - 1; i++) {
                if (
                    periodBlocks >= blocks[i] &&
                    periodBlocks < blocks[i + 1]
                ) {
                    index = i;
                }
            }
        }
    }
}
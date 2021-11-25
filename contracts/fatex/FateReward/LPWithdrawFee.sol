// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./FateLockedRewardFee.sol";

////////////////////////////////////////////////////////////////////////////////////////////
/// @title LPWithdrawFee
/// @author @commonlot
////////////////////////////////////////////////////////////////////////////////////////////
abstract contract LPWithdrawFee is FateLockedRewardFee {
    /// @dev constnats being used to check LP withdarw fees
    uint256[] public LP_WITHDRAW_PERIOD_BLOCKS = [
        1,
        8,
        24,
        72,
        336,
        672,
        888
    ];
    uint256[] public LP_WITHDRAW_FEE_PERCENT = [
        18e18,
        8e18,
        3.60e18,
        1.43e18,
        0.80e18,
        0.36e18,
        0.18e18
    ];

    /// @dev set LP_WITHDRAW_PERIOD_BLOCKS & LP_WITHDRAW_FEE_PERCENT
    function setLPWithdrawData(
        uint256[] memory _LP_WITHDRAW_PERIOD_BLOCKS,
        uint256[] memory _LP_WITHDRAW_FEE_PERCENT
    ) external onlyOwner {
        require(
            _LP_WITHDRAW_PERIOD_BLOCKS.length == _LP_WITHDRAW_FEE_PERCENT.length,
            "setLPWithdrawData: not same length"
        );
        LP_WITHDRAW_PERIOD_BLOCKS = _LP_WITHDRAW_PERIOD_BLOCKS;
        LP_WITHDRAW_FEE_PERCENT = _LP_WITHDRAW_FEE_PERCENT;
    }


    /// @dev calculate lpWithdrawFees as percent that will be sent to the rewardController
    function lpWithdrawFeePercent(uint256 _pid, address _caller) internal view returns(uint256 percent) {
        if (!isFatePool[_pid] || isExcludedAddress[_caller]) {
            percent = 0;
        } else {
            MembershipInfo memory membership = userMembershipInfo[_pid][_caller];
            uint256 endBlock = getEndBlock();
            if (endBlock > membership.lastWithdrawBlock) {
                uint256 withdraw_period_in_blocks = endBlock - membership.lastWithdrawBlock;
                percent = LP_WITHDRAW_FEE_PERCENT[
                    getIndexOfBlocks(
                        withdraw_period_in_blocks,
                        LP_WITHDRAW_PERIOD_BLOCKS
                    )
                ];
            }
        }
    }

    /// @dev calculate fees and minus from withdraw amount
    function calcWithdrawAmount(
        uint256 _pid,
        address _user,
        uint256 _amount
    ) internal returns(uint256 withdrawAmount) {
        // calculate fees and minu from transfer amount
        uint256 withdrawFeePercent = lpWithdrawFeePercent(_pid, _user);
        withdrawAmount = (100e18 - withdrawFeePercent) * _amount / 100e18; // minus fees

        // update lastWithdrawBlock of userMembershipInfo
        MembershipInfo memory membership = userMembershipInfo[_pid][_user];
        userMembershipInfo[_pid][_user] = MembershipInfo({
            firstDepositBlock: membership.firstDepositBlock,
            rankedNumber: membership.rankedNumber,
            lastWithdrawBlock: block.number
        });
    }
}
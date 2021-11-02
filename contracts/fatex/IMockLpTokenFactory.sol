// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IMockLpTokenFactory {

    function create(
        address _lpToken,
        address _rewardController
    ) external returns (address);

}

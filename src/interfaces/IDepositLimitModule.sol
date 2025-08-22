// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface IDepositLimitModule {

    function available_deposit_limit(
        address receiver
    ) external view returns (uint256);

}

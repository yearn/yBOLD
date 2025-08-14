// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IVault} from "@yearn-vaults/interfaces/IVault.sol";

import {IDepositLimitModule} from "../interfaces/IDepositLimitModule.sol";

/// @title OnLossDepositLimit
/// @notice Must serve as the `deposit_limit_module` for the vault.
///         Blocks deposits when the vault's price per share is below 1e18
contract OnLossDepositLimit is IDepositLimitModule {

    /// @notice The WAD constant
    uint256 public constant WAD = 1e18;

    /// @notice The vault to check its price per share
    IVault public constant VAULT = IVault(0x9F4330700a36B29952869fac9b33f45EEdd8A3d8); // yBOLD

    function available_deposit_limit(
        address /*receiver*/
    ) external view returns (uint256) {
        return VAULT.pricePerShare() < WAD ? 0 : VAULT.deposit_limit();
    }

}

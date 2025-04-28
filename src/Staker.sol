// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IVault} from "@yearn-vaults/interfaces/IVault.sol";
import {Base4626Compounder} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";

import {IAccountant} from "./interfaces/IAccountant.sol";

contract LV2SPStakerStrategy is Base4626Compounder {

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice The accountant of the vault, from which we claim rewards
    IAccountant public immutable ACCOUNTANT;

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _vault Address of the strategy's underlying vault
    /// @param _name Name of the strategy
    constructor(address _vault, string memory _name) Base4626Compounder(IVault(_vault).asset(), _name, _vault) {
        ACCOUNTANT = IAccountant(IVault(_vault).accountant());
        require(address(ACCOUNTANT) != address(0), "!accountant");
    }

    // ===============================================================
    // Internal mutated functions
    // ===============================================================

    /// @inheritdoc Base4626Compounder
    function _claimAndSellRewards() internal override {
        ACCOUNTANT.distribute(address(vault)); // Claims yBOLD
    }

}

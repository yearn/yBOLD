// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

contract MorphoPriceOracle {

    /// @notice BOLD token address
    IERC20 public constant BOLD = IERC20(0x6440f144b7e50D6a8439336510312d2F54beB01D);

    /// @notice yBOLD token address
    IStrategy public constant YEARN_BOLD = IStrategy(0x9F4330700a36B29952869fac9b33f45EEdd8A3d8);

    /// @notice st-yBOLD token address
    IStrategy public constant STAKED_YEARN_BOLD = IStrategy(0x23346B04a7f55b8760E5860AA5A77383D63491cD);

    // ===============================================================
    // View functions
    // ===============================================================

    /// @notice Converts st-yBOLD shares to BOLD assets
    /// @param _shares The amount of st-yBOLD shares to convert
    /// @return The amount of BOLD assets that would be returned
    function convertToAssets(
        uint256 _shares
    ) external view returns (uint256) {
        return YEARN_BOLD.convertToAssets(STAKED_YEARN_BOLD.convertToAssets(_shares));
    }

    /// @notice Converts BOLD assets to st-yBOLD shares
    /// @param _assets The amount of BOLD assets to convert
    /// @return The amount of st-yBOLD shares that would be issued
    function convertToShares(
        uint256 _assets
    ) external view returns (uint256) {
        return STAKED_YEARN_BOLD.convertToShares(YEARN_BOLD.convertToShares(_assets));
    }

}

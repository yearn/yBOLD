// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

interface IStrategyInterface is IStrategy {
    // Storage
    function maxGasPriceToTend() external view returns (uint256);
    function auction() external view returns (address);
    function COLL() external view returns (address);
    function SP() external view returns (address);

    // View
    function isCollateralGainToClaim() external view returns (bool);
    function estimatedTotalAssets() external view returns (uint256);

    // Management
    function setAuction(address _auction) external;

    // Keeper
    function kickAuction() external returns (uint256);

    // Mutated
    function claim() external;
    function claimNoDeposit() external;
}

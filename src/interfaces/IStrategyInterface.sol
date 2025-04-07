// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

interface IStrategyInterface is IStrategy {

    // Storage
    function maxGasPriceToTend() external view returns (uint256);
    function bufferPercentage() external view returns (uint256);
    function dustThreshold() external view returns (uint256);
    function ORACLE_DOWN_BUFFER_PCT_MULTIPLIER() external view returns (uint256);
    function MIN_BUFFER_PERCENTAGE() external view returns (uint256);
    function MIN_DUST_THRESHOLD() external view returns (uint256);
    function COLL() external view returns (address);
    function COLL_PRICE_ORACLE() external view returns (address);
    function SP() external view returns (address);
    function AUCTION() external view returns (address);

    // View
    function isCollateralGainToClaim() external view returns (bool);
    function estimatedTotalAssets() external view returns (uint256);

    // Management
    function setMaxGasPriceToTend(
        uint256 _maxGasPriceToTend
    ) external;
    function setBufferPercentage(
        uint256 _bufferPercentage
    ) external;
    function setDustThreshold(
        uint256 _dustThreshold
    ) external;

    // Keeper
    function kickAuction() external returns (uint256);

    // Mutated
    function claim() external;
    function claimNoDeposit() external;

}

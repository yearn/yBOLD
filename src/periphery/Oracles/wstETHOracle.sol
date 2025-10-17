// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AggregatorV3Interface, BaseOracle, Math} from "./BaseOracle.sol";

contract wstETHPriceOracle is BaseOracle {

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice stETH/wstETH Chainlink oracle heartbeat
    /// @dev 86400 seconds according to chainlink docs, we double it
    uint256 public constant STETH_WSTETH_HEARTBEAT = _48_HOURS;

    /// @notice stETH/USD Chainlink oracle heartbeat
    /// @dev 86400 seconds according to chainlink docs, we double it
    uint256 public constant STETH_USD_HEARTBEAT = _48_HOURS;

    /// @notice stETH/wstETH Chainlink oracle
    /// @dev 18 decimals
    AggregatorV3Interface public constant STETH_WSTETH_ORACLE =
        AggregatorV3Interface(0xB1552C5e96B312d0Bf8b554186F846C40614a540);

    /// @notice stETH/USD Chainlink oracle
    AggregatorV3Interface public constant STETH_USD_ORACLE =
        AggregatorV3Interface(0x07C5b924399cc23c24a95c8743DE4006a32b7f2a);

    // ===============================================================
    // Constructor
    // ===============================================================

    constructor() BaseOracle("wstETH / USD") {
        require(STETH_WSTETH_ORACLE.decimals() == 18, "!STETH_WSTETH_ORACLE");
        require(STETH_USD_ORACLE.decimals() == 8, "!STETH_USD_ORACLE");
    }

    // ===============================================================
    // View functions
    // ===============================================================

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (, int256 stEthwstEthPrice,, uint256 stEthwstEthUpdatedAt,) = STETH_WSTETH_ORACLE.latestRoundData();
        (, int256 stEthUsdPrice,, uint256 stEthUsdUpdatedAt,) = STETH_USD_ORACLE.latestRoundData();

        // If any of the oracles are stale, return 0
        if (_isStale(stEthwstEthPrice, stEthwstEthUpdatedAt, STETH_WSTETH_HEARTBEAT)) return (0, 0, 0, 0, 0);
        if (_isStale(stEthUsdPrice, stEthUsdUpdatedAt, STETH_USD_HEARTBEAT)) return (0, 0, 0, 0, 0);

        // Scale price to 8 decimals
        stEthwstEthPrice = stEthwstEthPrice / _1E10; // 18 -> 8

        // Calculate wstETH/USD price with 8 decimals
        int256 wstEthUsdPrice = stEthUsdPrice * stEthwstEthPrice / _1E8;

        return (0, wstEthUsdPrice, 0, Math.min(stEthwstEthUpdatedAt, stEthUsdUpdatedAt), 0);
    }

}

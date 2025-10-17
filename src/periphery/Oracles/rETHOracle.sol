// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AggregatorV3Interface, BaseOracle, Math} from "./BaseOracle.sol";

contract rETHPriceOracle is BaseOracle {

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice rETH/ETH Chainlink oracle heartbeat
    /// @dev 86400 seconds according to chainlink docs, we double it
    uint256 public constant RETH_ETH_HEARTBEAT = _48_HOURS;

    /// @notice ETH/USD Chainlink oracle heartbeat
    /// @dev 86400 seconds according to chainlink docs, we double it
    uint256 public constant ETH_USD_HEARTBEAT = _48_HOURS;

    /// @notice rETH/ETH Chainlink oracle
    AggregatorV3Interface public constant RETH_ETH_ORACLE =
        AggregatorV3Interface(0xD6aB2298946840262FcC278fF31516D39fF611eF);

    /// @notice ETH/USD Chainlink oracle
    AggregatorV3Interface public constant ETH_USD_ORACLE =
        AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);

    // ===============================================================
    // Constructor
    // ===============================================================

    constructor() BaseOracle("rETH / USD") {
        require(RETH_ETH_ORACLE.decimals() == 18, "!RETH_ETH_ORACLE");
        require(ETH_USD_ORACLE.decimals() == 8, "!ETH_USD_ORACLE");
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
        (, int256 rEthEthPrice,, uint256 rEthEthUpdatedAt,) = RETH_ETH_ORACLE.latestRoundData();
        (, int256 ethUsdPrice,, uint256 ethUsdUpdatedAt,) = ETH_USD_ORACLE.latestRoundData();

        // If any of the oracles are stale, return 0
        if (_isStale(rEthEthPrice, rEthEthUpdatedAt, RETH_ETH_HEARTBEAT)) return (0, 0, 0, 0, 0);
        if (_isStale(ethUsdPrice, ethUsdUpdatedAt, ETH_USD_HEARTBEAT)) return (0, 0, 0, 0, 0);

        // Scale price to 8 decimals
        rEthEthPrice = rEthEthPrice / _1E10; // 18 -> 8

        // Calculate rETH/USD price with 8 decimals
        int256 rEthUsdPrice = ethUsdPrice * rEthEthPrice / _1E8;

        return (0, rEthUsdPrice, 0, Math.min(rEthEthUpdatedAt, ethUsdUpdatedAt), 0);
    }

}

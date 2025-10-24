// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IWSTETH} from "../../interfaces/IWSTETH.sol";

import {AggregatorV3Interface, BaseOracle} from "./BaseOracle.sol";

contract wstETHOracle is BaseOracle {

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice stETH/USD Chainlink oracle heartbeat
    /// @dev 3600 seconds according to chainlink docs, we use 24 hours
    uint256 public constant STETH_USD_HEARTBEAT = _24_HOURS;

    /// @notice Used to get the stETH/wstETH rate
    /// @dev 18 decimals
    IWSTETH public constant WSTETH = IWSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    /// @notice stETH/USD Chainlink oracle
    AggregatorV3Interface public constant STETH_USD_ORACLE =
        AggregatorV3Interface(0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8);

    // ===============================================================
    // Constructor
    // ===============================================================

    constructor() BaseOracle("wstETH / USD") {
        require(WSTETH.decimals() == 18, "!WSTETH");
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
        (, int256 stEthUsdPrice,, uint256 stEthUsdUpdatedAt,) = STETH_USD_ORACLE.latestRoundData();

        // If the oracle is stale, return 0
        if (_isStale(stEthUsdPrice, stEthUsdUpdatedAt, STETH_USD_HEARTBEAT)) return (0, 0, 0, 0, 0);

        // Get stETH/wstETH price
        int256 stEthwstEthPrice = int256(WSTETH.stEthPerToken());

        // If rate is 0, return 0
        if (stEthwstEthPrice == 0) return (0, 0, 0, 0, 0);

        // Scale price to 8 decimals
        stEthwstEthPrice = stEthwstEthPrice / _1E10; // 18 -> 8

        // Calculate wstETH/USD price with 8 decimals
        int256 wstEthUsdPrice = stEthUsdPrice * stEthwstEthPrice / _1E8;

        return (0, wstEthUsdPrice, 0, stEthUsdUpdatedAt, 0);
    }

}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AggregatorV3Interface, BaseOracle, Math} from "./BaseOracle.sol";

contract weETHOracle is BaseOracle {

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice weETH/ETH Chainlink oracle heartbeat
    /// @dev 86400 seconds according to api3 docs, we double it
    uint256 public constant WEETH_ETH_HEARTBEAT = _48_HOURS;

    /// @notice ETH/USD Chainlink oracle heartbeat
    /// @dev 86400 seconds according to chainlink docs, we double it
    uint256 public constant ETH_USD_HEARTBEAT = _48_HOURS;

    /// @notice weETH/ETH api3 oracle
    AggregatorV3Interface public constant WEETH_ETH_ORACLE =
        AggregatorV3Interface(0xabB160Db40515B77998289afCD16DC06Ae71d12E);

    /// @notice ETH/USD Chainlink oracle
    AggregatorV3Interface public constant ETH_USD_ORACLE =
        AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);

    // ===============================================================
    // Constructor
    // ===============================================================

    constructor() BaseOracle("weETH / USD") {
        require(WEETH_ETH_ORACLE.decimals() == 18, "!WEETH_ETH_ORACLE");
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
        (, int256 weEthEthPrice,, uint256 weEthEthUpdatedAt,) = WEETH_ETH_ORACLE.latestRoundData();
        (, int256 ethUsdPrice,, uint256 ethUsdUpdatedAt,) = ETH_USD_ORACLE.latestRoundData();

        // If any of the oracles are stale, return 0
        if (_isStale(weEthEthPrice, weEthEthUpdatedAt, WEETH_ETH_HEARTBEAT)) return (0, 0, 0, 0, 0);
        if (_isStale(ethUsdPrice, ethUsdUpdatedAt, ETH_USD_HEARTBEAT)) return (0, 0, 0, 0, 0);

        // Scale price to 8 decimals
        weEthEthPrice = weEthEthPrice / _1E10; // 18 -> 8

        // Calculate weETH/USD price with 8 decimals
        int256 weEthUsdPrice = ethUsdPrice * weEthEthPrice / _1E8;

        return (0, weEthUsdPrice, 0, Math.min(weEthEthUpdatedAt, ethUsdUpdatedAt), 0);
    }

}
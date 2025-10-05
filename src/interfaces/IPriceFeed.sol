// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";

interface IPriceFeed {

    enum PriceSource {
        primary,
        ETHUSDxCanonical,
        lastGoodPrice
    }

    struct Oracle {
        AggregatorV3Interface aggregator;
        uint256 stalenessThreshold;
        uint8 decimals;
    }

    function ethUsdOracle() external view returns (Oracle memory _oracle);
    function priceSource() external view returns (PriceSource);
    function fetchPrice() external returns (uint256 _price, bool _isOracleDown);

}

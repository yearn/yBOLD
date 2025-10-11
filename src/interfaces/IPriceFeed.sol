// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";

interface IPriceFeed {

    enum PriceSource {
        primary,
        ETHUSDxCanonical,
        lastGoodPrice
    }

    function priceSource() external view returns (PriceSource);
    function fetchPrice() external returns (uint256 _price, bool _isOracleDown);

}

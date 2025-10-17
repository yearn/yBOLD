pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {weETHPriceOracle, Setup} from "./utils/Setup.sol";

contract PriceOracleTest is Setup {

    weETHPriceOracle public oracle;

    function setUp() public override {
        super.setUp();

        oracle = new weETHPriceOracle();
    }

    function test_priceOracle() public {
        (, int256 answer,, uint256 updatedAt,) = oracle.latestRoundData();
        console2.log("price", uint256(answer));
        assertGt(answer, 0);
        assertGt(updatedAt, 0);
    }
}

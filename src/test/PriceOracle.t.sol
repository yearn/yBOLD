pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup} from "./utils/Setup.sol";

import {wstETHOracle} from "../periphery/Oracles/wstETHOracle.sol";
// import {rETHOracle} from "../periphery/Oracles/rETHOracle.sol";

contract PriceOracleTest is Setup {

    wstETHOracle public oracle;
    // rETHOracle public oracle;

    function setUp() public override {
        super.setUp();

        oracle = new wstETHOracle();
        // oracle = new rETHOracle();
    }

    function test_priceOracleSanityCheck() public {
        (, int256 answer,, uint256 updatedAt,) = oracle.latestRoundData();
        console2.log("price", uint256(answer));
        assertGt(answer, 0);
        assertGt(updatedAt, 0);
    }

}

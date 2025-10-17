// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Setup, ERC20} from "./utils/Setup.sol";

contract SettersTest is Setup {

    function setUp() public virtual override {
        super.setUp();
    }

    function test_allowDeposits() public {
        vm.expectRevert("!management");
        strategy.allowDeposits();

        assertFalse(strategy.openDeposits());
        vm.prank(management);
        strategy.allowDeposits();
        assertTrue(strategy.openDeposits());
    }

    function test_setMinAuctionPriceBps(
        uint256 _minAuctionPriceBps
    ) public {
        vm.assume(_minAuctionPriceBps < MAX_BPS);

        vm.expectRevert("!management");
        strategy.setMinAuctionPriceBps(_minAuctionPriceBps);

        vm.prank(management);
        strategy.setMinAuctionPriceBps(_minAuctionPriceBps);
        assertEq(strategy.minAuctionPriceBps(), _minAuctionPriceBps);
    }

    function test_setMinAuctionPriceBps_tooHigh(
        uint256 _minAuctionPriceBps
    ) public {
        vm.assume(_minAuctionPriceBps >= MAX_BPS);

        vm.expectRevert("!minAuctionPriceBps");
        vm.prank(management);
        strategy.setMinAuctionPriceBps(_minAuctionPriceBps);
    }

    function test_setMaxAuctionAmount(
        uint256 _maxAuctionAmount
    ) public {
        vm.assume(_maxAuctionAmount > 0);

        vm.expectRevert("!management");
        strategy.setMaxAuctionAmount(_maxAuctionAmount);

        vm.prank(management);
        strategy.setMaxAuctionAmount(_maxAuctionAmount);
        assertEq(strategy.maxAuctionAmount(), _maxAuctionAmount);
    }

    function test_setMaxAuctionAmount_zero() public {
        vm.expectRevert("!maxAuctionAmount");
        vm.prank(management);
        strategy.setMaxAuctionAmount(0);
    }

    function test_setMaxGasPriceToTend(
        uint256 _maxGasPriceToTend
    ) public {
        vm.assume(_maxGasPriceToTend >= strategy.MIN_MAX_GAS_PRICE_TO_TEND());

        vm.expectRevert("!management");
        strategy.setMaxGasPriceToTend(_maxGasPriceToTend);

        vm.prank(management);
        strategy.setMaxGasPriceToTend(_maxGasPriceToTend);
        assertEq(strategy.maxGasPriceToTend(), _maxGasPriceToTend);
    }

    function test_setMaxGasPriceToTend_tooLow(
        uint256 _maxGasPriceToTend
    ) public {
        vm.assume(_maxGasPriceToTend < strategy.MIN_MAX_GAS_PRICE_TO_TEND());

        vm.expectRevert("!minMaxGasPrice");
        vm.prank(management);
        strategy.setMaxGasPriceToTend(_maxGasPriceToTend);
    }

    function test_setBufferPercentage(
        uint256 _bufferPercentage
    ) public {
        vm.assume(_bufferPercentage >= strategy.MIN_BUFFER_PERCENTAGE());

        vm.expectRevert("!management");
        strategy.setBufferPercentage(_bufferPercentage);

        vm.prank(management);
        strategy.setBufferPercentage(_bufferPercentage);
        assertEq(strategy.bufferPercentage(), _bufferPercentage);
    }

    function test_setBufferPercentage_tooLow(
        uint256 _bufferPercentage
    ) public {
        vm.assume(_bufferPercentage < strategy.MIN_BUFFER_PERCENTAGE());

        vm.expectRevert("!minBuffer");
        vm.prank(management);
        strategy.setBufferPercentage(_bufferPercentage);
    }

    function test_setDustThreshold(
        uint256 _dustThreshold
    ) public {
        vm.assume(_dustThreshold >= strategy.MIN_DUST_THRESHOLD());

        vm.expectRevert("!management");
        strategy.setDustThreshold(_dustThreshold);

        vm.prank(management);
        strategy.setDustThreshold(_dustThreshold);
        assertEq(strategy.dustThreshold(), _dustThreshold);
    }

    function test_setDustThreshold_tooLow(
        uint256 _dustThreshold
    ) public {
        vm.assume(_dustThreshold < strategy.MIN_DUST_THRESHOLD());

        vm.expectRevert("!minDust");
        vm.prank(management);
        strategy.setDustThreshold(_dustThreshold);
    }

    function test_setAllowed(
        address _address
    ) public {
        vm.expectRevert("!management");
        strategy.setAllowed(_address);

        assertFalse(strategy.allowed(_address));
        vm.prank(management);
        strategy.setAllowed(_address);
        assertTrue(strategy.allowed(_address));
    }

}

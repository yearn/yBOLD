// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Setup} from "./utils/Setup.sol";

contract SettersTest is Setup {

    function setUp() public virtual override {
        super.setUp();
    }

    function test_SetMaxGasPriceToTend(
        uint256 _maxGasPriceToTend
    ) public {
        vm.expectRevert("!management");
        strategy.setMaxGasPriceToTend(_maxGasPriceToTend);

        vm.prank(management);
        strategy.setMaxGasPriceToTend(_maxGasPriceToTend);
        assertEq(strategy.maxGasPriceToTend(), _maxGasPriceToTend);
    }

    function test_SetBufferPercentage(
        uint256 _bufferPercentage
    ) public {
        vm.assume(_bufferPercentage >= strategy.MIN_BUFFER_PERCENTAGE());

        vm.expectRevert("!management");
        strategy.setBufferPercentage(_bufferPercentage);

        vm.prank(management);
        strategy.setBufferPercentage(_bufferPercentage);
        assertEq(strategy.bufferPercentage(), _bufferPercentage);
    }

    function test_SetBufferPercentage_TooLow(
        uint256 _bufferPercentage
    ) public {
        vm.assume(_bufferPercentage < strategy.MIN_BUFFER_PERCENTAGE());

        vm.expectRevert("!minBuffer");
        vm.prank(management);
        strategy.setBufferPercentage(_bufferPercentage);
    }

    function test_SetDustThreshold(
        uint256 _dustThreshold
    ) public {
        vm.assume(_dustThreshold >= strategy.MIN_DUST_THRESHOLD());

        vm.expectRevert("!management");
        strategy.setDustThreshold(_dustThreshold);

        vm.prank(management);
        strategy.setDustThreshold(_dustThreshold);
        assertEq(strategy.dustThreshold(), _dustThreshold);
    }

    function test_SetDustThreshold_TooLow(
        uint256 _dustThreshold
    ) public {
        vm.assume(_dustThreshold < strategy.MIN_DUST_THRESHOLD());

        vm.expectRevert("!minDust");
        vm.prank(management);
        strategy.setDustThreshold(_dustThreshold);
    }

}

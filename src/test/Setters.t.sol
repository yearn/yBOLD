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

    function test_setStrategyParameters(
        uint256 _minAuctionPriceBps,
        uint256 _bufferPercentage,
        uint256 _maxAuctionAmount,
        uint256 _maxGasPriceToTend,
        uint256 _dustThreshold
    ) public {
        vm.assume(_minAuctionPriceBps < MAX_BPS);
        vm.assume(_bufferPercentage >= strategy.MIN_BUFFER_PERCENTAGE());
        vm.assume(_maxAuctionAmount > 0);
        vm.assume(_maxGasPriceToTend >= strategy.MIN_MAX_GAS_PRICE_TO_TEND());
        vm.assume(_dustThreshold >= strategy.MIN_DUST_THRESHOLD());

        vm.prank(management);
        strategy.setStrategyParameters(
            _minAuctionPriceBps, _bufferPercentage, _maxAuctionAmount, _maxGasPriceToTend, _dustThreshold, false
        );

        assertEq(strategy.minAuctionPriceBps(), _minAuctionPriceBps);
        assertEq(strategy.bufferPercentage(), _bufferPercentage);
        assertEq(strategy.maxAuctionAmount(), _maxAuctionAmount);
        assertEq(strategy.maxGasPriceToTend(), _maxGasPriceToTend);
        assertEq(strategy.dustThreshold(), _dustThreshold);
        assertFalse(strategy.auctionsBlocked());
    }

    function test_setStrategyParameters_reverts(
        uint256 _wrongMinAuctionPriceBps,
        uint256 _wrongBufferPercentage,
        uint256 _wrongMaxGasPriceToTend,
        uint256 _wrongDustThreshold
    ) public {
        vm.assume(_wrongMinAuctionPriceBps >= MAX_BPS);
        vm.assume(_wrongBufferPercentage < strategy.MIN_BUFFER_PERCENTAGE());
        vm.assume(_wrongMaxGasPriceToTend < strategy.MIN_MAX_GAS_PRICE_TO_TEND());
        vm.assume(_wrongDustThreshold < strategy.MIN_DUST_THRESHOLD());

        uint256 _minAuctionPriceBps = strategy.minAuctionPriceBps();
        uint256 _bufferPercentage = strategy.bufferPercentage();
        uint256 _maxAuctionAmount = strategy.maxAuctionAmount();
        uint256 _maxGasPriceToTend = strategy.maxGasPriceToTend();
        uint256 _dustThreshold = strategy.dustThreshold();

        vm.startPrank(management);

        vm.expectRevert("!minAuctionPriceBps");
        strategy.setStrategyParameters(
            _wrongMinAuctionPriceBps, _bufferPercentage, _maxAuctionAmount, _maxGasPriceToTend, _dustThreshold, false
        );

        vm.expectRevert("!minBuffer");
        strategy.setStrategyParameters(
            _minAuctionPriceBps, _wrongBufferPercentage, _maxAuctionAmount, _maxGasPriceToTend, _dustThreshold, false
        );

        vm.expectRevert("!maxAuctionAmount");
        strategy.setStrategyParameters(
            _minAuctionPriceBps, _bufferPercentage, 0, _maxGasPriceToTend, _dustThreshold, false
        );

        vm.expectRevert("!minMaxGasPrice");
        strategy.setStrategyParameters(
            _minAuctionPriceBps, _bufferPercentage, _maxAuctionAmount, _wrongMaxGasPriceToTend, _dustThreshold, false
        );

        vm.expectRevert("!minDust");
        strategy.setStrategyParameters(
            _minAuctionPriceBps, _bufferPercentage, _maxAuctionAmount, _maxGasPriceToTend, _wrongDustThreshold, false
        );
        vm.stopPrank();
    }

    function test_setStrategyParameters_wrongCaller(
        address _wrongCaller
    ) public {
        vm.assume(_wrongCaller != management);
        vm.expectRevert("!management");
        vm.prank(_wrongCaller);
        strategy.setStrategyParameters(0, 0, 0, 0, 0, false);
    }

    function test_unblockAuctions() public {
        assertFalse(strategy.auctionsBlocked());
        unblockAuctions();
        assertFalse(strategy.auctionsBlocked());
    }

    function test_setMinAuctionPriceBps(
        uint256 _minAuctionPriceBps
    ) public {
        vm.assume(_minAuctionPriceBps < MAX_BPS);
        setMinAuctionPriceBps(_minAuctionPriceBps);
        assertEq(strategy.minAuctionPriceBps(), _minAuctionPriceBps);
    }

    function test_setMaxAuctionAmount(
        uint256 _maxAuctionAmount
    ) public {
        vm.assume(_maxAuctionAmount > 0);
        setMaxAuctionAmount(_maxAuctionAmount);
        assertEq(strategy.maxAuctionAmount(), _maxAuctionAmount);
    }

    function test_setMaxGasPriceToTend(
        uint256 _maxGasPriceToTend
    ) public {
        vm.assume(_maxGasPriceToTend >= strategy.MIN_MAX_GAS_PRICE_TO_TEND());
        setMaxGasPriceToTend(_maxGasPriceToTend);
        assertEq(strategy.maxGasPriceToTend(), _maxGasPriceToTend);
    }

    function test_setBufferPercentage(
        uint256 _bufferPercentage
    ) public {
        vm.assume(_bufferPercentage >= strategy.MIN_BUFFER_PERCENTAGE());
        setBufferPercentage(_bufferPercentage);
        assertEq(strategy.bufferPercentage(), _bufferPercentage);
    }

    function test_setDustThreshold(
        uint256 _dustThreshold
    ) public {
        vm.assume(_dustThreshold >= strategy.MIN_DUST_THRESHOLD());
        setDustThreshold(_dustThreshold);
        assertEq(strategy.dustThreshold(), _dustThreshold);
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

    function test_sweep(
        uint256 _amount
    ) public {
        vm.assume(_amount > 0);

        ERC20 _token = ERC20(tokenAddrs["YFI"]);
        vm.expectRevert("!management");
        strategy.sweep(_token);

        vm.startPrank(management);

        ERC20 _asset = ERC20(strategy.asset());
        vm.expectRevert("!token");
        strategy.sweep(_asset);

        ERC20 _coll = ERC20(strategy.COLL());
        vm.expectRevert("!token");
        strategy.sweep(_coll);

        vm.expectRevert("!balance");
        strategy.sweep(ERC20(tokenAddrs["LINK"]));

        uint256 _balanceBefore = _token.balanceOf(management);
        airdrop(_token, address(strategy), _amount);
        strategy.sweep(_token);
        assertEq(_token.balanceOf(management), _balanceBefore + _amount);
        assertEq(_token.balanceOf(address(strategy)), 0);

        vm.stopPrank();
    }

}

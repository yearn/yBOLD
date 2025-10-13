// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStabilityPool} from "./utils/Setup.sol";
import {IAuction} from "../interfaces/IAuction.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";

contract OperationTest is Setup {

    function setUp() public virtual override {
        super.setUp();

        vm.prank(management);
        strategy.allowDeposits();
    }

    function test_setupStrategyOK() public {
        console2.log("address of strategy", address(strategy));
        assertEq(strategyFactory.deployments(address(asset), stabilityPool), address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.management(), management);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
        assertEq(strategy.keeper(), keeper);
        assertTrue(strategy.openDeposits());
        assertFalse(strategy.auctionsBlocked());
        assertEq(strategy.minAuctionPriceBps(), 9_000);
        assertEq(strategy.maxAuctionAmount(), type(uint256).max);
        assertEq(strategy.maxGasPriceToTend(), 200 * 1e9);
        assertEq(strategy.bufferPercentage(), 1.15e18);
        assertTrue(strategy.AUCTION() != address(0));
        assertEq(strategy.COLL(), tokenAddrs["WETH"]);
        assertEq(strategy.SP(), stabilityPool);
        assertEq(strategy.COLL_PRICE_ORACLE(), collateralPriceOracle);
        assertEq(strategy.CHAINLINK_ORACLE(), collateralChainlinkPriceOracle);
    }

    function test_operation(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(1 days);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    }

    function test_profitableReport(
        uint256 _amount,
        uint16 _profitFactor
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS / 10));

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        simulateYieldGain(toAirdrop);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    }

    function test_profitableReport_withFees(
        uint256 _amount,
        uint16 _profitFactor
    ) public {
        vm.assume(_amount > minFuzzAmount * 1e4 && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS / 10));

        // Set protocol fee to 0 and perf fee to 10%
        setFees(0, 1000);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        simulateYieldGain(toAirdrop);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        // Get the expected fee
        uint256 expectedShares = (profit * 1000) / MAX_BPS;

        assertEq(strategy.balanceOf(performanceFeeRecipient), expectedShares);

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");

        vm.prank(performanceFeeRecipient);
        strategy.redeem(expectedShares, performanceFeeRecipient, performanceFeeRecipient);

        checkStrategyTotals(strategy, 0, 0, 0);

        assertGe(asset.balanceOf(performanceFeeRecipient), expectedShares, "!perf fee out");
    }

    function test_tendTrigger(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        // Skip some time
        skip(1 days);

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        vm.prank(keeper);
        strategy.report();

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        // Unlock Profits
        skip(strategy.profitMaxUnlockTime());

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        vm.prank(user);
        strategy.redeem(_amount, user, user);

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
    }

    function test_tendTrigger_collateralToSell(
        uint256 _amount,
        uint256 _airdropAmount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        vm.assume(_airdropAmount > strategy.dustThreshold() && _airdropAmount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        airdrop(ERC20(strategy.COLL()), address(strategy), _airdropAmount);
        (bool trigger,) = strategy.tendTrigger();
        assertTrue(trigger);
    }

    function test_tendTrigger_collateralToSell_cappedByMaxAuctionAmount(
        uint256 _amount,
        uint256 _airdropAmount,
        uint256 _maxAuctionAmount
    ) public {
        _amount = bound(_amount, minFuzzAmount + 1, maxFuzzAmount);
        _airdropAmount = bound(_airdropAmount, strategy.dustThreshold() + 1, maxFuzzAmount);
        _maxAuctionAmount = bound(_maxAuctionAmount, 1, strategy.dustThreshold());

        vm.prank(management);
        strategy.setMaxAuctionAmount(_maxAuctionAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        airdrop(ERC20(strategy.COLL()), address(strategy), _airdropAmount);
        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        vm.prank(management);
        strategy.setMaxAuctionAmount(type(uint256).max);

        (trigger,) = strategy.tendTrigger();
        assertTrue(trigger);
    }

    function test_tendTrigger_notEnoughCollateralToSell(
        uint256 _amount,
        uint256 _airdropAmount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        vm.assume(_airdropAmount <= strategy.dustThreshold());

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        airdrop(ERC20(strategy.COLL()), address(strategy), _airdropAmount);
        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
    }

    function test_tendTrigger_collateralToSell_basefeeTooHigh(
        uint256 _amount,
        uint256 _airdropAmount
    ) public {
        test_tendTrigger_collateralToSell(_amount, _airdropAmount);

        // Set `maxGasPriceToTend` to 0
        vm.store(address(strategy), bytes32(uint256(3)), bytes32(uint256(0)));
        assertEq(strategy.maxGasPriceToTend(), 0);

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
    }

    function test_tendTrigger_collateralGainToClaim(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
        assertFalse(strategy.isCollateralGainToClaim());

        // Earn Collateral, lose principal
        simulateCollateralGain();

        IStabilityPool _stabilityPool = IStabilityPool(strategy.SP());
        uint256 _expectedCollateralGain = _stabilityPool.getDepositorCollGain(address(strategy));
        vm.assume(_expectedCollateralGain > strategy.dustThreshold());

        assertTrue(strategy.isCollateralGainToClaim());

        (trigger,) = strategy.tendTrigger();
        assertTrue(trigger);
    }

    function test_tendTrigger_collateralGainToClaim_basefeeTooHigh(
        uint256 _amount
    ) public {
        test_tendTrigger_collateralGainToClaim(_amount);

        // Set `maxGasPriceToTend` to 0
        vm.store(address(strategy), bytes32(uint256(3)), bytes32(uint256(0)));
        assertEq(strategy.maxGasPriceToTend(), 0);

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
    }

    function test_tendTrigger_activeAuction(
        uint256 _amount
    ) public {
        vm.assume(_amount > strategy.dustThreshold() && _amount < maxFuzzAmount);

        test_tendTrigger_collateralGainToClaim(_amount);

        (bool trigger,) = strategy.tendTrigger();
        assertTrue(trigger);

        // Kick it
        vm.prank(keeper);
        strategy.tend();

        address coll = strategy.COLL();
        IAuction auction = IAuction(strategy.AUCTION());

        assertTrue(auction.isActive(coll));
        assertTrue(auction.available(coll) > 0);

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        skip(auction.auctionLength() + 1);
        assertFalse(auction.isActive(coll));
        assertEq(auction.available(coll), 0);

        (trigger,) = strategy.tendTrigger();
        assertTrue(trigger);
    }

    function test_tendTrigger_priceTooLow(
        uint256 _amount
    ) public {
        vm.assume(_amount > strategy.dustThreshold() && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // Make sure there's something to kick
        airdrop(ERC20(strategy.COLL()), address(strategy), _amount);

        (bool trigger,) = strategy.tendTrigger();
        assertTrue(trigger);

        // Kick it
        vm.prank(keeper);
        strategy.tend();

        // Skip enough time such that price is too low
        skip(1 hours);

        // Make sure auction price is lower than our min price
        assertTrue(
            IAuction(strategy.AUCTION()).price(address(strategy.COLL()))
                < ethPrice() * 1e10 * strategy.minAuctionPriceBps() / MAX_BPS
        );

        // We need to block auctions now
        (trigger,) = strategy.tendTrigger();
        assertTrue(trigger);

        // Make sure auction is active
        assertTrue(IAuction(strategy.AUCTION()).isActive(address(strategy.COLL())));

        // Make sure auction are not blocked yet
        assertFalse(strategy.auctionsBlocked());

        // Tend to unwind and block auctions
        vm.prank(keeper);
        strategy.tend();

        // Auctions should be blocked now
        assertTrue(strategy.auctionsBlocked());

        // We cannot kick again
        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        // Make sure no active auction
        assertFalse(IAuction(strategy.AUCTION()).isActive(address(strategy.COLL())));
    }

    function test_tendTrigger_priceTooLow_unblock(
        uint256 _amount
    ) public {
        vm.assume(_amount > strategy.dustThreshold() && _amount < maxFuzzAmount);

        test_tendTrigger_priceTooLow(_amount);

        vm.prank(management);
        strategy.unblockAuctions();

        // Auctions should be unblocked now
        assertFalse(strategy.auctionsBlocked());

        // We can kick again
        (bool trigger,) = strategy.tendTrigger();
        assertTrue(trigger);
    }

    function test_tendTrigger_priceTooLow_checkDisabled(
        uint256 _amount
    ) public {
        vm.assume(_amount > strategy.dustThreshold() && _amount < maxFuzzAmount);

        test_tendTrigger_priceTooLow(_amount);

        // Disable the auction price check
        vm.prank(management);
        strategy.setMinAuctionPriceBps(0);

        vm.prank(management);
        strategy.unblockAuctions();

        // Auctions should be unblocked now
        assertFalse(strategy.auctionsBlocked());

        // But we can kick again
        (bool trigger,) = strategy.tendTrigger();
        assertTrue(trigger);
    }

    function test_tendTrigger_amountBelowDustThreshold(
        uint256 _amount
    ) public {
        vm.assume(_amount > 0 && _amount < strategy.dustThreshold());

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // Make sure there's something to kick
        airdrop(ERC20(strategy.COLL()), address(strategy), _amount);

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
    }

    function test_tendAfterCollateralGain(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        uint256 _estimatedTotalAssetsBefore = strategy.estimatedTotalAssets();

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
        assertFalse(strategy.isCollateralGainToClaim());

        // Earn Collateral, lose principal
        simulateCollateralGain();

        IStabilityPool _stabilityPool = IStabilityPool(strategy.SP());
        uint256 _expectedCollateralGain = _stabilityPool.getDepositorCollGain(address(strategy));
        vm.assume(_expectedCollateralGain > strategy.dustThreshold());
        assertEq(ERC20(strategy.COLL()).balanceOf(address(strategy)), 0);

        assertLt(strategy.estimatedTotalAssets(), _estimatedTotalAssetsBefore);
        assertTrue(strategy.isCollateralGainToClaim());

        (trigger,) = strategy.tendTrigger();
        assertTrue(trigger);

        // Reporting should fail until we swap the collateral gain
        vm.prank(keeper);
        vm.expectRevert("healthCheck");
        strategy.report();

        // Claim collateral gain and kick auction
        vm.prank(keeper);
        strategy.tend();

        assertEq(ERC20(strategy.COLL()).balanceOf(address(strategy)), 0);
        assertEq(_stabilityPool.getDepositorCollGain(address(strategy)), 0);
        assertEq(ERC20(strategy.COLL()).balanceOf(strategy.AUCTION()), _expectedCollateralGain);

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        // Simulate swap collateral gain
        vm.prank(keeper);
        uint256 _availableToAuction = IAuction(strategy.AUCTION()).available(strategy.COLL());
        assertEq(_availableToAuction, _expectedCollateralGain);

        // Check auction starting price
        (uint256 _price,) = IPriceFeed(strategy.COLL_PRICE_ORACLE()).fetchPrice();
        uint256 _toAuctionPrice = _availableToAuction * _price / 1e18;
        uint256 _expectedStartingPrice = _toAuctionPrice * 115 / 100 / 1e18;
        assertEq(IAuction(strategy.AUCTION()).startingPrice(), _expectedStartingPrice);

        // Check auction price
        uint256 _expectedPrice = _expectedStartingPrice * 1e36 / _availableToAuction;
        assertApproxEq(IAuction(strategy.AUCTION()).price(strategy.COLL()), _expectedPrice, 1);

        // Add 5% bonus
        uint256 _expectedAssetGain = (_expectedCollateralGain * ethPrice() / 1e18) * 105 / 100;
        airdrop(asset, address(strategy), _expectedAssetGain);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        assertGt(profit, 0);
        assertEq(loss, 0);
        assertGt(strategy.estimatedTotalAssets(), _estimatedTotalAssetsBefore);
    }

    function test_tendActiveAuction(
        uint256 _amount
    ) public {
        vm.assume(_amount > strategy.dustThreshold() && _amount < maxFuzzAmount);

        address coll = strategy.COLL();
        IAuction auction = IAuction(strategy.AUCTION());

        // Airdrop enough collateral rewards to kick a new auction
        airdrop(ERC20(coll), strategy.AUCTION(), _amount);

        // Kick it
        vm.prank(keeper);
        strategy.tend();

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), _amount);

        uint256 startingPriceBefore = auction.startingPrice();

        // Airdrop more collateral rewards so that we need to kick again
        airdrop(ERC20(coll), strategy.AUCTION(), _amount);

        // Kick again, with new lot
        vm.prank(keeper);
        strategy.tend();

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), _amount * 2);
        assertApproxEqAbs(auction.startingPrice(), startingPriceBefore * 2, 1);
    }

    function test_tendAfterCollateralGain_cappedByMaxAuctionAmount(
        uint256 _amount,
        uint256 _maxAuctionAmount
    ) public {
        vm.assume(_amount > strategy.dustThreshold() && _amount < maxFuzzAmount);
        vm.assume(_maxAuctionAmount > strategy.dustThreshold() && _maxAuctionAmount < _amount);

        vm.prank(management);
        strategy.setMaxAuctionAmount(_maxAuctionAmount);

        address coll = strategy.COLL();
        IAuction auction = IAuction(strategy.AUCTION());

        uint256 expectedRemaining = _amount - _maxAuctionAmount;

        // Airdrop enough collateral rewards to kick a new auction
        airdrop(ERC20(coll), address(strategy), _amount);

        // Kick it
        vm.prank(keeper);
        strategy.tend();

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), _maxAuctionAmount);
        assertEq(ERC20(coll).balanceOf(address(strategy)), expectedRemaining);

        // Take auction
        vm.prank(address(auction));
        ERC20(coll).transfer(address(420), _maxAuctionAmount);
        assertEq(auction.available(coll), 0);
        assertTrue(auction.isActive(coll)); // Was never settled

        uint256 newAuctionAmount = ERC20(coll).balanceOf(address(strategy)) > _maxAuctionAmount
            ? _maxAuctionAmount
            : ERC20(coll).balanceOf(address(strategy));
        vm.assume(newAuctionAmount > strategy.dustThreshold());

        uint256 newExpectedRemaining = ERC20(coll).balanceOf(address(strategy)) - newAuctionAmount;

        // Kick it again
        vm.prank(keeper);
        strategy.tend();

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), newAuctionAmount);
        assertEq(ERC20(coll).balanceOf(address(strategy)), newExpectedRemaining);
    }

    function test_tendSettleAuction(
        uint256 _amount
    ) public {
        vm.assume(_amount > strategy.dustThreshold() && _amount < maxFuzzAmount);

        address coll = strategy.COLL();
        IAuction auction = IAuction(strategy.AUCTION());

        // Airdrop enough collateral rewards to kick a new auction
        airdrop(ERC20(coll), strategy.AUCTION(), _amount);

        // Kick it
        vm.prank(keeper);
        strategy.tend();

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), _amount);

        // Take auction
        vm.prank(address(auction));
        ERC20(coll).transfer(address(420), _amount);

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), 0);

        // Settle auction without kicking a new one
        vm.prank(keeper);
        strategy.tend();

        assertFalse(auction.isActive(coll));
        assertEq(auction.available(coll), 0);
    }

    function test_tendSettleAuctionAndKickNewOne(
        uint256 _amount
    ) public {
        vm.assume(_amount > strategy.dustThreshold() && _amount < maxFuzzAmount);

        address coll = strategy.COLL();
        IAuction auction = IAuction(strategy.AUCTION());

        // Airdrop enough collateral rewards to kick a new auction
        airdrop(ERC20(coll), strategy.AUCTION(), _amount);

        // Kick it
        vm.prank(keeper);
        strategy.tend();

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), _amount);

        // Take auction
        vm.prank(address(auction));
        ERC20(coll).transfer(address(420), _amount);

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), 0);

        // Airdrop enough collateral rewards to kick a new auction
        airdrop(ERC20(coll), address(strategy), _amount);

        // Settle auction and kick a new one
        vm.prank(keeper);
        strategy.tend();

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), _amount);
    }

    function test_tendSettleAuctionAndTooLowToKickNewOne(
        uint256 _amount,
        uint256 _amountTooLow
    ) public {
        vm.assume(_amount > strategy.dustThreshold() && _amount < maxFuzzAmount);
        vm.assume(_amountTooLow <= strategy.dustThreshold());

        address coll = strategy.COLL();
        IAuction auction = IAuction(strategy.AUCTION());

        // Airdrop enough collateral rewards to kick a new auction
        airdrop(ERC20(coll), strategy.AUCTION(), _amount);

        // Kick it
        vm.prank(keeper);
        strategy.tend();

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), _amount);

        // Take auction
        vm.prank(address(auction));
        ERC20(coll).transfer(address(420), _amount);

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), 0);

        // Airdrop not enough collateral rewards to kick a new auction
        airdrop(ERC20(coll), address(strategy), _amountTooLow);

        // Settle auction without kicking a new one
        vm.prank(keeper);
        strategy.tend();

        assertFalse(auction.isActive(coll));
        assertEq(auction.available(coll), 0);
    }

    function test_kickAuction_oracleDown(
        uint256 _airdropAmount
    ) public {
        vm.assume(_airdropAmount > strategy.dustThreshold() && _airdropAmount < maxFuzzAmount);

        // Break the oracle
        skip(10 days);
        (uint256 _price, bool _isOracleDown) = IPriceFeed(strategy.COLL_PRICE_ORACLE()).fetchPrice();
        assertTrue(_isOracleDown);

        // Make sure there's something to kick
        airdrop(ERC20(strategy.COLL()), address(strategy), _airdropAmount);

        // Kick auction
        vm.prank(keeper);
        strategy.tend();

        // Check auction starting price
        uint256 _toAuctionPrice = _airdropAmount * _price / 1e18;
        uint256 _expectedStartingPrice = (_toAuctionPrice * (115 * 1000) / 100) / 1e18;
        assertEq(IAuction(strategy.AUCTION()).startingPrice(), _expectedStartingPrice);

        // Check auction price
        uint256 _availableToAuction = IAuction(strategy.AUCTION()).available(strategy.COLL());
        uint256 _expectedPrice = _expectedStartingPrice * 1e36 / _availableToAuction;
        assertApproxEq(IAuction(strategy.AUCTION()).price(strategy.COLL()), _expectedPrice, 1);
    }

    function test_kickAuction_permissionlessKick(
        address _address
    ) public {
        address coll = strategy.COLL();
        IAuction auction = IAuction(strategy.AUCTION());

        // Airdrop some collateral so there's something to kick
        airdrop(ERC20(coll), address(auction), 1 ether);

        vm.prank(_address);
        auction.kick(coll);
    }

    function test_tendGas() public {
        vm.prank(keeper);
        strategy.tend();
    }

}

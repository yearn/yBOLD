// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStabilityPool} from "./utils/Setup.sol";
import {IAuction} from "../interfaces/IAuction.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";

contract OperationTest is Setup {

    function setUp() public virtual override {
        super.setUp();
    }

    function test_setupStrategyOK() public {
        console2.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.management(), management);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
        assertEq(strategy.keeper(), keeper);
        assertEq(strategy.maxGasPriceToTend(), 200 * 1e9);
        assertEq(strategy.bufferPercentage(), 1.1e18);
        assertTrue(strategy.AUCTION() != address(0));
        assertEq(strategy.COLL(), tokenAddrs["WETH"]);
        assertEq(strategy.SP(), stabilityPool);
        assertEq(strategy.COLL_PRICE_ORACLE(), collateralPriceOracle);
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

    function test_profitableReport(uint256 _amount, uint16 _profitFactor) public {
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

    function test_profitableReport_withFees(uint256 _amount, uint16 _profitFactor) public {
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
        assertTrue(!trigger);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Skip some time
        skip(1 days);

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        vm.prank(keeper);
        strategy.report();

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Unlock Profits
        skip(strategy.profitMaxUnlockTime());

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        vm.prank(user);
        strategy.redeem(_amount, user, user);

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);
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

        assertLt(strategy.estimatedTotalAssets(), _estimatedTotalAssetsBefore);
        assertTrue(strategy.isCollateralGainToClaim());

        (trigger,) = strategy.tendTrigger();
        assertTrue(trigger);

        // Reporting should fail until we swap the collateral gain
        vm.prank(keeper);
        vm.expectRevert("healthCheck");
        strategy.report();

        IStabilityPool _stabilityPool = IStabilityPool(strategy.SP());
        uint256 _expectedCollateralGain = _stabilityPool.getDepositorCollGain(address(strategy));
        assertEq(ERC20(strategy.COLL()).balanceOf(address(strategy)), 0);

        // Claim collateral gain
        vm.prank(keeper);
        strategy.tend();

        assertEq(ERC20(strategy.COLL()).balanceOf(address(strategy)), _expectedCollateralGain);
        assertEq(_stabilityPool.getDepositorCollGain(address(strategy)), 0);

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        // Simulate swap collateral gain
        vm.prank(keeper);
        uint256 _availableToAuction = strategy.kickAuction();
        assertEq(_availableToAuction, _expectedCollateralGain);

        // Check auction starting price
        (uint256 _price,) = IPriceFeed(strategy.COLL_PRICE_ORACLE()).fetchPrice();
        uint256 _toAuctionPrice = _availableToAuction * _price / 1e18;
        uint256 _expectedStartingPrice = _toAuctionPrice * 110 / 100;
        assertEq(IAuction(strategy.AUCTION()).startingPrice(), _expectedStartingPrice);

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

    function test_kickAuction_notKeeper(
        address _notKeeper
    ) public {
        vm.assume(_notKeeper != keeper && _notKeeper != management);

        vm.expectRevert("!keeper");
        vm.prank(_notKeeper);
        strategy.kickAuction();
    }

    function test_kickAuction_toAuctionLessThanDustThreshold(
        uint256 _dust
    ) public {
        vm.assume(_dust <= strategy.dustThreshold());

        airdrop(asset, address(strategy), _dust);

        vm.expectRevert("!toAuction");
        vm.prank(keeper);
        strategy.kickAuction();
    }

    function test_kickAuction_oracleDown(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Break the oracle
        skip(10 days);
        (uint256 _price, bool _isOracleDown) = IPriceFeed(strategy.COLL_PRICE_ORACLE()).fetchPrice();
        assertTrue(_isOracleDown);

        // Make sure there's something to kick
        airdrop(ERC20(strategy.COLL()), address(strategy), _amount);

        // Kick auction
        vm.prank(keeper);
        uint256 _availableToAuction = strategy.kickAuction();
        assertEq(_availableToAuction, _amount);

        // Check auction starting price
        uint256 _toAuctionPrice = _availableToAuction * _price / 1e18;
        uint256 _expectedStartingPrice = (_toAuctionPrice * (110 * 1000) / 100);
        assertEq(IAuction(strategy.AUCTION()).startingPrice(), _expectedStartingPrice);
    }

}

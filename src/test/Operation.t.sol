// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStabilityPool, IStrategyInterface} from "./utils/Setup.sol";

contract OperationTest is Setup {
    function setUp() public virtual override {
        super.setUp();

        // Make fuzz less extreme
        maxFuzzAmount = maxFuzzAmount / 1e5; // 1e25
        minFuzzAmount = minFuzzAmount * 1e10; // 1e14
    }

    function test_setupStrategyOK() public {
        console2.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.management(), management);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
        assertEq(strategy.keeper(), keeper);
        assertEq(strategy.auction(), address(0));
        assertEq(strategy.COLL(), tokenAddrs["WETH"]);
        assertEq(strategy.SP(), stabilityPool);
    }

    function test_operation(uint256 _amount) public {
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
        setFees(0, 1_000);

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
        uint256 expectedShares = (profit * 1_000) / MAX_BPS;

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

    function test_tendTrigger(uint256 _amount) public {
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

    function test_tendAfterCollateralGain(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        uint256 _estimatedTotalAssetsBefore = strategy.estimatedTotalAssets();

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger, "test_tendAfterCollateralGain: E0");
        assertFalse(strategy.isCollateralGainToClaim(), "test_tendAfterCollateralGain: E1");

        // Earn Collateral, lose principal
        simulateCollateralGain();

        assertLt(strategy.estimatedTotalAssets(), _estimatedTotalAssetsBefore, "test_tendAfterCollateralGain: E2");
        assertTrue(strategy.isCollateralGainToClaim(), "test_tendAfterCollateralGain: E3");

        (trigger,) = strategy.tendTrigger();
        assertTrue(trigger, "test_tendAfterCollateralGain: E4");

        // Reporting should fail until we swap the collateral gain
        vm.prank(keeper);
        vm.expectRevert("healthCheck");
        strategy.report();

        IStabilityPool _stabilityPool = IStabilityPool(strategy.SP());
        uint256 _expectedCollateralGain = _stabilityPool.getDepositorCollGain(address(strategy));
        assertEq(ERC20(strategy.COLL()).balanceOf(address(strategy)), 0, "test_tendAfterCollateralGain: E5");

        // Claim collateral gain
        vm.prank(keeper);
        strategy.tend();

        assertEq(
            ERC20(strategy.COLL()).balanceOf(address(strategy)),
            _expectedCollateralGain,
            "test_tendAfterCollateralGain: E6"
        );
        assertEq(_stabilityPool.getDepositorCollGain(address(strategy)), 0, "test_tendAfterCollateralGain: E7");

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger, "test_tendAfterCollateralGain: E8");

        // Simulate swap collateral gain
        vm.prank(management);
        strategy.setAuction(address(auctionMock));
        vm.prank(keeper);
        strategy.kickAuction();

        // Add 5% bonus
        uint256 _expectedAssetGain = (_expectedCollateralGain * ethPrice() / 1e18) * 105 / 100;
        airdrop(asset, address(strategy), _expectedAssetGain);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        assertGt(profit, 0, "test_tendAfterCollateralGain: E9");
        assertEq(loss, 0, "test_tendAfterCollateralGain: E10");
        assertGt(strategy.estimatedTotalAssets(), _estimatedTotalAssetsBefore, "test_tendAfterCollateralGain: E11");
    }
}

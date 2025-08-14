pragma solidity ^0.8.18;

import {IVault} from "@yearn-vaults/interfaces/IVault.sol";

import {OnLossDepositLimit} from "../periphery/OnLossDepositLimit.sol";

import {IStrategyInterface, ERC20, Setup} from "./utils/Setup.sol";

contract DepositLimitModuleTest is Setup {

    OnLossDepositLimit public depositLimitModule;

    address public constant TKS = 0x604e586F17cE106B64185A7a0d2c1Da5bAce711E;
    address public constant ROLE_MANAGER = 0xb3bd6B2E61753C311EFbCF0111f75D29706D9a41;

    uint256 public constant DEPOSIT_LIMIT_MANAGER_ROLE = 256;

    IVault public vault = IVault(0x9F4330700a36B29952869fac9b33f45EEdd8A3d8); // yBOLD
    IStrategyInterface public _strategy = IStrategyInterface(0x46af61661B1e15DA5bFE40756495b7881F426214); // wstETH SP Strategy

    function setUp() public override {
        uint256 _blockNumber = 231_356_20; // Caching for faster tests
        vm.selectFork(vm.createFork(vm.envString("ETH_RPC_URL"), _blockNumber));

        _setTokenAddrs();

        // Set asset
        asset = ERC20(tokenAddrs["BOLD"]);

        // Deploy deposit limit module
        depositLimitModule = new OnLossDepositLimit();
    }

    function test_depositAfterLoss(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        mintAndDepositIntoStrategy(IStrategyInterface(address(vault)), user, _amount);

        // PPS sanity check
        assertEq(vault.pricePerShare(), 1 ether);
        assertEq(vault.totalSupply() - vault.totalAssets(), 0);

        // Lose 10% of the strategy balance
        vm.startPrank(address(vault));
        _strategy.transfer(address(420), _strategy.balanceOf(address(vault)) * 10 / 100);
        vm.stopPrank();

        // Report loss to vault
        vm.prank(TKS);
        vault.process_report(address(_strategy));

        // Make sure PPS decreased
        assertLt(vault.pricePerShare(), 1 ether);

        uint256 lossToCover = vault.totalSupply() - vault.totalAssets();
        assertGt(lossToCover, 0);

        // User deposit again, increasing the lossToCover
        mintAndDepositIntoStrategy(IStrategyInterface(address(vault)), user, _amount);

        // Loss to cover increased. THAT'S KIND OF A PROBLEM
        assertGt(vault.totalSupply() - vault.totalAssets(), lossToCover);
    }

    function test_withdrawAfterLoss(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        mintAndDepositIntoStrategy(IStrategyInterface(address(vault)), user, _amount);

        // PPS sanity check
        assertEq(vault.pricePerShare(), 1 ether);
        assertEq(vault.totalSupply() - vault.totalAssets(), 0);

        // Lose 10% of the strategy balance
        vm.startPrank(address(vault));
        _strategy.transfer(address(420), _strategy.balanceOf(address(vault)) * 10 / 100);
        vm.stopPrank();

        // Report loss to vault
        vm.prank(TKS);
        vault.process_report(address(_strategy));

        // Make sure PPS decreased
        assertLt(vault.pricePerShare(), 1 ether);

        uint256 lossToCover = vault.totalSupply() - vault.totalAssets();
        assertGt(lossToCover, 0);

        // Withdraw deposit
        vm.prank(user);
        vault.redeem(_amount, user, user);

        // Loss to cover decreased. User took one for the team
        assertLt(vault.totalSupply() - vault.totalAssets(), lossToCover);
    }

    function test_depositAfterLoss_withModule(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Set the deposit limit module
        setDepositLimitModule();

        mintAndDepositIntoStrategy(IStrategyInterface(address(vault)), user, _amount);

        // PPS sanity check
        assertEq(vault.pricePerShare(), 1 ether);
        assertEq(vault.totalSupply() - vault.totalAssets(), 0);

        // Lose 10% of the strategy balance
        vm.startPrank(address(vault));
        _strategy.transfer(address(420), _strategy.balanceOf(address(vault)) * 10 / 100);
        vm.stopPrank();

        // Report loss to vault
        vm.prank(TKS);
        vault.process_report(address(_strategy));

        // Make sure PPS decreased
        assertLt(vault.pricePerShare(), 1 ether);

        uint256 lossToCover = vault.totalSupply() - vault.totalAssets();
        assertGt(lossToCover, 0);

        // Deposit limit module blocks new deposits
        vm.expectRevert("exceed deposit limit");
        vm.prank(user);
        vault.deposit(_amount, user);
    }

    function test_withdrawAfterLoss_withModule(
        uint256 _amount
    ) public {
        // Set the deposit limit module
        setDepositLimitModule();

        // Same same
        test_withdrawAfterLoss(_amount);
    }

    function setDepositLimitModule() internal {
        vm.startPrank(ROLE_MANAGER);
        vault.set_role(ROLE_MANAGER, DEPOSIT_LIMIT_MANAGER_ROLE);
        vault.set_deposit_limit_module(address(depositLimitModule), true);
        vault.set_role(ROLE_MANAGER, 0);
        vm.stopPrank();
    }

}

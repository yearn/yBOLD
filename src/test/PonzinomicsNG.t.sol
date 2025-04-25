pragma solidity ^0.8.18;

import {IVault} from "@yearn-vaults/interfaces/IVault.sol";
import {Registry} from "@vault-periphery/registry/Registry.sol";
import {RoleManager} from "@vault-periphery/managers/RoleManager.sol";

import {Accountant, AccountantFactory} from "../periphery/AccountantFactory.sol";

import {IGaugeFactory} from "../interfaces/IGaugeFactory.sol";

import "forge-std/console2.sol";
import {IStrategyInterface, Setup} from "./utils/Setup.sol";

// @todo -- make sure only vault can deposit (availableDepositLimit?)
// @todo -- test what happens on loss? -- here
// @todo -- st-yBOLD staker
// @todo -- auto-bribe
contract PonzinomicsNGTest is Setup {

    IVault public vault; // yBOLD
    Accountant public accountant;
    AccountantFactory public accountantFactory;
    address public staker = address(6969); // @todo

    RoleManager public constant ROLE_MANAGER = RoleManager(0xb3bd6B2E61753C311EFbCF0111f75D29706D9a41);
    Registry public constant VAULT_REGISTRY = Registry(0xd40ecF29e001c76Dcc4cC0D9cd50520CE845B038);
    IGaugeFactory public constant VEFUNDER_FACTORY = IGaugeFactory(0x696B5D296a8AeF7482B726FCf0616E32fe72A53d);

    function setUp() public override {
        super.setUp();

        // address _gauge = VEFUNDER_FACTORY.deploy_gauge(address(420), type(uint256).max);

        // Deploy allocator vault
        vm.prank(VAULT_REGISTRY.governance());
        vault = IVault(VAULT_REGISTRY.newEndorsedVault(
            address(asset),
            "Yearn BOLD",
            "yBOLD",
            management,
            0 // profitMaxUnlockTime
        ));

        // Deploy accountant factory
        accountantFactory = new AccountantFactory();

        // Deploy accountant
        accountant = Accountant(accountantFactory.newAccountant(
            management, // feeManager
            staker, // feeRecipient
            0, // management fee
            uint16(MAX_BPS), // performance fee
            uint16(MAX_BPS), // refund ratio
            0, // max fee
            uint16(MAX_BPS), // max gain
            uint16(MAX_BPS) // max loss
        ));

        // Set up the vault
        vm.startPrank(management);
        vault.set_role(management, 16383); // ADD_STRATEGY_MANAGER/DEPOSIT_LIMIT_MANAGER/MAX_DEBT_MANAGER/DEBT_MANAGER
        vault.set_role(keeper, 32); // REPORTING_MANAGER
        vault.set_auto_allocate(true);
        vault.set_deposit_limit(type(uint256).max);
        vault.add_strategy(address(strategy));
        vault.update_max_debt_for_strategy(address(strategy), type(uint256).max);
        vault.set_accountant(address(accountant));
        vault.transfer_role_manager(address(ROLE_MANAGER));
        vm.stopPrank();

        vm.prank(ROLE_MANAGER.chad());
        ROLE_MANAGER.addNewVault(
            address(vault),
            2 // multi strategy
        );

        vm.prank(management);
        accountant.addVault(address(vault));

        // Make sure no fees on the strategy
        setFees(0, 0);

        // Remove profitMaxUnlockTime
        vm.prank(management);
        strategy.setProfitMaxUnlockTime(0);
    }

    function test_boldProfit(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS / 10));

        // Deposit into strategy
        mintAndDepositIntoStrategy(IStrategyInterface(address(vault)), user, _amount);

        assertEq(vault.totalAssets(), _amount, "!totalAssets vault");
        assertEq(vault.totalSupply(), _amount, "!totalSupply vault");
        assertEq(strategy.totalAssets(), _amount, "!totalAssets strategy");
        assertEq(strategy.totalSupply(), _amount, "!totalSupply strategy");

        uint256 pricePerShare = vault.pricePerShare();
        assertEq(pricePerShare, 1 ether, "!pricePerShare vault");

        pricePerShare = strategy.convertToAssets(1 ether);
        assertEq(pricePerShare, 1 ether, "!pricePerShare strategy");

        // Earn Interest
        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        simulateYieldGain(toAirdrop);

        // Report profit on strategy
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        assertEq(strategy.totalAssets(), _amount + profit, "!totalAssets strategy after");
        assertEq(strategy.totalSupply(), _amount, "!totalSupply strategy after");

        pricePerShare = strategy.convertToAssets(1 ether);
        assertGt(pricePerShare, 1 ether, "!pricePerShare strategy after");

        // Report profit on vault
        vm.prank(keeper);
        (profit, loss) = vault.process_report(address(strategy));

        // Check return Values
        assertGt(profit, 0, "!profit vault after");
        assertEq(loss, 0, "!loss vault after");

        assertEq(vault.totalAssets(), _amount + profit, "!totalAssets vault after");
        assertEq(vault.totalSupply(), _amount + profit, "!totalSupply vault after");

        pricePerShare = vault.pricePerShare();
        assertEq(pricePerShare, 1 ether, "!pricePerShare vault after");

        // Claim rewards
        vm.prank(staker);
        accountant.distribute(address(vault));

        // Check staker got the rewards
        assertEq(vault.balanceOf(staker), profit, "!staker balance");
    }

}
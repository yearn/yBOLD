// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IVault} from "@yearn-vaults/interfaces/IVault.sol";
import {IVaultFactory} from "@yearn-vaults/interfaces/IVaultFactory.sol";

import {IStrategyInterface} from "../src/interfaces/IStrategyInterface.sol";

import {StrategyFactory} from "../src/StrategyFactory.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeploySavingsAf.s.sol:DeploySavingsAf --verify --legacy --rpc-url https://rpc.hyperliquid.xyz/evm --broadcast --verifier blockscout --verifier-url 'https://www.hyperscan.com/api/'

contract DeploySavingsAf is Script {

    address[] public strategies;

    string private constant NAME = "temp-Savings feUSD";
    string private constant SYMBOL = "temp-sfeUSD";

    address private constant ASSET = 0x02c6a2fA58cC01A18B8D9E00eA48d65E4dF26c70; // feUSD
    address private constant DEPLOYER = 0x318d0059efE546b5687FA6744aF4339391153981; // deployer
    address private constant SMS = 0x5e061C197D69c0e809e9269eD212730D91E8cB39; // sms hyperevm
    address private constant KEEPER = 0x318d0059efE546b5687FA6744aF4339391153981; // deployer
    // address private constant ROLE_MANAGER = 0xb3bd6B2E61753C311EFbCF0111f75D29706D9a41;

    StrategyFactory private constant STRATEGY_FACTORY = StrategyFactory(0xc438806b0726ADe87F746D2b2Ad07F6f05a26A85);
    IVaultFactory private constant VAULT_FACTORY = IVaultFactory(0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F); // 3.0.4 Vault Factory

    function run() external {
        uint256 _privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(_privateKey);

        address _deployer = vm.addr(_privateKey);
        require(_deployer == DEPLOYER, "!deployer");

        address _whypeStrategy = STRATEGY_FACTORY.newStrategy(
            address(0x7201Fb5C3BA06f10A858819F62221AE2f473815D), // WHYPE Address Registry
            ASSET,
            "feUSD WHYPE Stability Pool"
        );
        strategies.push(_whypeStrategy);

        address _feUBTCStrategy = STRATEGY_FACTORY.newStrategy(
            address(0xfC4e20bd9F0e4F8782beA92a7bd8002367882407), // feUBTC Address Registry
            ASSET,
            "feUSD feUBTC Stability Pool"
        );
        strategies.push(_feUBTCStrategy);

        IVault _vault = IVault(VAULT_FACTORY.deploy_new_vault(ASSET, NAME, SYMBOL, DEPLOYER, 1 days));
        _vault.set_role(DEPLOYER, 16383); // ADD_STRATEGY_MANAGER/DEPOSIT_LIMIT_MANAGER/MAX_DEBT_MANAGER/DEBT_MANAGER
        // _vault.set_role(KEEPER, 32); // REPORTING_MANAGER
        _vault.set_deposit_limit(100_000_000_000 ether); // 100 billion
        _vault.set_auto_allocate(true);
        for (uint256 i = 0; i < strategies.length; i++) {
            _vault.add_strategy(strategies[i]);
            _vault.update_max_debt_for_strategy(strategies[i], 10_000_000_000 ether); // 10 billion
        }
        // _vault.transfer_role_manager(ROLE_MANAGER);
        // _vault.set_role(DEPLOYER, 0);

        for (uint256 i = 0; i < strategies.length; i++) {
            IStrategyInterface strategy = IStrategyInterface(strategies[i]);
            strategy.acceptManagement();
            strategy.setProfitMaxUnlockTime(1 days);
            strategy.setAllowed(address(_vault));
            strategy.setPendingManagement(SMS);
            strategy.setPerformanceFee(0);
            require(strategy.performanceFee() == 0, "!fee");
        }

        vm.stopBroadcast();

        console.log("-----------------------------");
        console.log("WHYPE Strategy deployed at: ", _whypeStrategy);
        console.log("feUBTC Strategy deployed at: ", _feUBTCStrategy);
        console.log("sfeUSD deployed at: ", address(_vault));
        console.log("-----------------------------");
    }

}

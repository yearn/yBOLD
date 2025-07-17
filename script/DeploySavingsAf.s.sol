// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IVault} from "@yearn-vaults/interfaces/IVault.sol";
import {IVaultFactory} from "@yearn-vaults/interfaces/IVaultFactory.sol";

import {IStrategyInterface} from "../src/interfaces/IStrategyInterface.sol";

import {StrategyFactory} from "../src/StrategyFactory.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeploySavingsAf.s.sol:DeploySavingsAf --verify --legacy --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

contract DeploySavingsAf is Script {

    address[] public strategies;

    string private constant NAME = "Yearn USND";
    string private constant SYMBOL = "yUSND";

    address private constant ASSET = 0x4ecf61a6c2FaB8A047CEB3B3B263B401763e9D49; // USND
    address private constant DEPLOYER = 0x420ACF637D662b80cca8bEfb327AA24039E7e0Fa; // deployer
    address private constant SMS = 0x6346282DB8323A54E840c6C772B4399C9c655C0d; // sms arbi
    address private constant KEEPER = 0xE0D19f6b240659da8E87ABbB73446E7B4346Baee; // yHaaS arbi
    // address private constant ROLE_MANAGER = 0xb3bd6B2E61753C311EFbCF0111f75D29706D9a41;

    StrategyFactory private constant STRATEGY_FACTORY = StrategyFactory(0xdE66FC29E0F81Ef23E56d6a5226Cc288148fA98d);
    IVaultFactory private constant VAULT_FACTORY = IVaultFactory(0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F); // 3.0.4 Vault Factory

    function run() external {
        uint256 _privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(_privateKey);

        address _deployer = vm.addr(_privateKey);
        require(_deployer == DEPLOYER, "!deployer");

        address _wethStrategy = STRATEGY_FACTORY.newStrategy(
            address(0xBB6C6B994409b320E25e7dE129e0db5dA60aE89B), // WETH Address Registry
            ASSET,
            "USND WETH Stability Pool"
        );
        strategies.push(_wethStrategy);

        address _wstETHStrategy = STRATEGY_FACTORY.newStrategy(
            address(0x5176fDd77FDef5B7F1EDd457D02a8ec1cFebBb34), // wstETH Address Registry
            ASSET,
            "USND wstETH Stability Pool"
        );
        strategies.push(_wstETHStrategy);

        address _rETHStrategy = STRATEGY_FACTORY.newStrategy(
            address(0x51253Ae341F6dD1c4Ff5692dE0eE69492743895E), // rETH Address Registry
            ASSET,
            "USND rETH Stability Pool"
        );
        strategies.push(_rETHStrategy);

        address _rsETHStrategy = STRATEGY_FACTORY.newStrategy(
            address(0xcbF5786902487C1165a98f48Ebc65Fa0e62739C6), // rsETH Address Registry
            ASSET,
            "USND rsETH Stability Pool"
        );
        strategies.push(_rsETHStrategy);

        address _weETHStrategy = STRATEGY_FACTORY.newStrategy(
            address(0xc23928FD7D93ccb61ca60F09311De2DdA66c02e4), // weETH Address Registry
            ASSET,
            "USND weETH Stability Pool"
        );
        strategies.push(_weETHStrategy);

        address _ARBStrategy = STRATEGY_FACTORY.newStrategy(
            address(0x7900B65266e157D9fce97e92Ac3879CB712dEd31), // ARB Address Registry
            ASSET,
            "USND ARB Stability Pool"
        );
        strategies.push(_ARBStrategy);

        address _COMPStrategy = STRATEGY_FACTORY.newStrategy(
            address(0xfe75AdD51A119e556ACD53676b12f865A6737177), // COMP Address Registry
            ASSET,
            "USND COMP Stability Pool"
        );
        strategies.push(_COMPStrategy);

        address _tBTCStrategy = STRATEGY_FACTORY.newStrategy(
            address(0xF329FB0E818bD92395785a4f863636bC0D85e1DF), // tBTC Address Registry
            ASSET,
            "USND tBTC Stability Pool"
        );
        strategies.push(_tBTCStrategy);

        IVault _vault = IVault(VAULT_FACTORY.deploy_new_vault(ASSET, NAME, SYMBOL, DEPLOYER, 1 days));
        _vault.set_role(DEPLOYER, 16383); // ADD_STRATEGY_MANAGER/DEPOSIT_LIMIT_MANAGER/MAX_DEBT_MANAGER/DEBT_MANAGER
        _vault.set_role(KEEPER, 32); // REPORTING_MANAGER
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
            strategy.setProfitMaxUnlockTime(0);
            strategy.setAllowed(address(_vault));
            strategy.setPendingManagement(SMS);
            strategy.setPerformanceFee(0);
            require(strategy.performanceFee() == 0, "!fee");
        }

        vm.stopBroadcast();

        console.log("-----------------------------");
        console.log("WETH Strategy deployed at: ", _wethStrategy);
        console.log("wstETH Strategy deployed at: ", _wstETHStrategy);
        console.log("rETH Strategy deployed at: ", _rETHStrategy);
        console.log("rsETH Strategy deployed at: ", _rsETHStrategy);
        console.log("weETH Strategy deployed at: ", _weETHStrategy);
        console.log("ARB Strategy deployed at: ", _ARBStrategy);
        console.log("COMP Strategy deployed at: ", _COMPStrategy);
        console.log("tBTC Strategy deployed at: ", _tBTCStrategy);
        console.log("Vault deployed at: ", address(_vault));
        console.log("-----------------------------");
    }

}

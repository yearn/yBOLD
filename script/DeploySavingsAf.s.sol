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

    // @todo -- set oracles!

    address[] public strategies;

    string private constant NAME = "Savings USDaf";
    string private constant SYMBOL = "sUSDaf";

    address private constant ASSET = 0x9Cf12ccd6020b6888e4D4C4e4c7AcA33c1eB91f8; // USDaf
    address private constant DEPLOYER = 0x285E3b1E82f74A99D07D2aD25e159E75382bB43B; // deployer
    address private constant SMS = 0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7; // sms mainnet
    address private constant KEEPER = 0x604e586F17cE106B64185A7a0d2c1Da5bAce711E; // yHaaS mainnet
    address private constant ROLE_MANAGER = 0xb3bd6B2E61753C311EFbCF0111f75D29706D9a41;

    StrategyFactory private constant STRATEGY_FACTORY = StrategyFactory(0x73dfCc4fB90E6e252E5D41f6588534a8043dBa58);
    IVaultFactory private constant VAULT_FACTORY = IVaultFactory(0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F); // 3.0.4 Vault Factory

    function run() external {
        uint256 _privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(_privateKey);

        address _deployer = vm.addr(_privateKey);
        require(_deployer == DEPLOYER, "!deployer");

        address _ysyBOLDStrategy = STRATEGY_FACTORY.newStrategy(
            address(0x3414bd84dfF0900a9046a987f4dF2e0eF08Fa1ce), // ysyBOLD Address Registry
            ASSET,
            address(0),
            "USDaf ysyBOLD Stability Pool"
        );
        strategies.push(_ysyBOLDStrategy);

        address _scrvUSDStrategy = STRATEGY_FACTORY.newStrategy(
            address(0x0C7B6C6a60ae2016199d393695667c1482719C82), // scrvUSD Address Registry
            ASSET,
            address(0),
            "USDaf scrvUSD Stability Pool"
        );
        strategies.push(_scrvUSDStrategy);

        address _sUSDSStrategy = STRATEGY_FACTORY.newStrategy(
            address(0x330A0fDfc1818Be022FEDCE96A041293E16dc6d1), // sUSDS Address Registry
            ASSET,
            address(0),
            "USDaf sUSDS Stability Pool"
        );
        strategies.push(_sUSDSStrategy);

        address _sfrxUSDStrategy = STRATEGY_FACTORY.newStrategy(
            address(0x0ad1C302203F0fbB6Ca34641BDFeF0Bf4182377c), // sfrxUSD Address Registry
            ASSET,
            address(0),
            "USDaf sfrxUSD Stability Pool"
        );
        strategies.push(_sfrxUSDStrategy);

        address _tBTCStrategy = STRATEGY_FACTORY.newStrategy(
            address(0xbd9f75471990041A3e7C22872c814A273485E999), // tBTC Address Registry
            ASSET,
            address(0),
            "USDaf tBTC Stability Pool"
        );
        strategies.push(_tBTCStrategy);

        address _WBTC18Strategy = STRATEGY_FACTORY.newStrategy(
            address(0x2C5A85a3fd181857D02baff169D1e1cB220ead6d), // WBTC18 Address Registry
            ASSET,
            address(0),
            "USDaf WBTC18 Stability Pool"
        );
        strategies.push(_WBTC18Strategy);

        IVault _vault = IVault(VAULT_FACTORY.deploy_new_vault(ASSET, NAME, SYMBOL, DEPLOYER, 3 days));
        _vault.set_role(DEPLOYER, 16383); // ADD_STRATEGY_MANAGER/DEPOSIT_LIMIT_MANAGER/MAX_DEBT_MANAGER/DEBT_MANAGER
        _vault.set_role(KEEPER, 32); // REPORTING_MANAGER
        _vault.set_deposit_limit(100_000_000_000 ether); // 100 billion
        _vault.set_auto_allocate(true);
        for (uint256 i = 0; i < strategies.length; i++) {
            _vault.add_strategy(strategies[i]);
            _vault.update_max_debt_for_strategy(strategies[i], 10_000_000_000 ether); // 10 billion
        }
        _vault.transfer_role_manager(ROLE_MANAGER);
        // _vault.set_role(DEPLOYER, 0);

        for (uint256 i = 0; i < strategies.length; i++) {
            IStrategyInterface strategy = IStrategyInterface(strategies[i]);
            strategy.acceptManagement();
            strategy.setProfitMaxUnlockTime(0 days);
            strategy.setAllowed(address(_vault));
            strategy.setPendingManagement(SMS);
            strategy.setPerformanceFee(0);
            require(strategy.performanceFee() == 0, "!fee");
        }

        vm.stopBroadcast();

        console.log("-----------------------------");
        console.log("ysyBOLD Strategy deployed at: ", _ysyBOLDStrategy);
        console.log("scrvUSD Strategy deployed at: ", _scrvUSDStrategy);
        console.log("sUSDS Strategy deployed at: ", _sUSDSStrategy);
        console.log("sfrxUSD Strategy deployed at: ", _sfrxUSDStrategy);
        console.log("tBTC Strategy deployed at: ", _tBTCStrategy);
        console.log("WBTC18 Strategy deployed at: ", _WBTC18Strategy);
        console.log("sUSDaf deployed at: ", address(_vault));
        console.log("-----------------------------");
    }

}

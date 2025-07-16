// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AccountantFactory} from "../src/periphery/AccountantFactory.sol";

import {StrategyFactory} from "../src/StrategyFactory.sol";
import {StakerFactory} from "../src/StakerFactory.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeployFactories.s.sol:DeployFactories --verify --legacy --rpc-url https://rpc.hyperliquid.xyz/evm --broadcast --verifier blockscout --verifier-url 'https://www.hyperscan.com/api/'

contract DeployFactories is Script {

    address private constant MANAGEMENT = 0x318d0059efE546b5687FA6744aF4339391153981; // deployer
    address private constant KEEPER = 0x318d0059efE546b5687FA6744aF4339391153981; // deployer
    address private constant EMERGENCY_ADMIN = 0x5e061C197D69c0e809e9269eD212730D91E8cB39; // SMS hyperliquid
    address private constant PERFORMANCE_FEE_RECIPIENT = 0x5e061C197D69c0e809e9269eD212730D91E8cB39; // SMS hyperliquid
    address private constant AUCTION_FACTORY = 0x71ccF86Cf63A5d55B12AA7E7079C22f39112Dd7D; // DoS resistant auction factory

    function run() external {
        uint256 _privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(_privateKey);

        address _deployer = vm.addr(_privateKey);
        require(_deployer == MANAGEMENT, "!deployer");

        AccountantFactory _accountantFactory = new AccountantFactory();
        // StakerFactory _stakerFactory = new StakerFactory(MANAGEMENT, PERFORMANCE_FEE_RECIPIENT, KEEPER, EMERGENCY_ADMIN);
        StrategyFactory _strategyFactory =
            new StrategyFactory(MANAGEMENT, PERFORMANCE_FEE_RECIPIENT, KEEPER, EMERGENCY_ADMIN, AUCTION_FACTORY);

        console.log("-----------------------------");
        console.log("Deployer: ", _deployer);
        console.log("AccountantFactory deployed at: ", address(_accountantFactory));
        // console.log("StakerFactory deployed at: ", address(_stakerFactory));
        console.log("StrategyFactory deployed at: ", address(_strategyFactory));
        console.log("-----------------------------");

        vm.stopBroadcast();
    }

}

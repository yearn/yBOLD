// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AccountantFactory} from "../src/periphery/AccountantFactory.sol";

import {StrategyFactory} from "../src/StrategyFactory.sol";
import {StakerFactory} from "../src/StakerFactory.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeployFactories.s.sol:DeployFactories --verify --legacy --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

contract DeployFactories is Script {

    address private constant MANAGEMENT = 0x420ACF637D662b80cca8bEfb327AA24039E7e0Fa; // deployer
    address private constant KEEPER = 0xE0D19f6b240659da8E87ABbB73446E7B4346Baee; // yHaaS arbi
    address private constant EMERGENCY_ADMIN = 0x6346282DB8323A54E840c6C772B4399C9c655C0d; // SMS arbi
    address private constant PERFORMANCE_FEE_RECIPIENT = 0x9aB47bE62631036CDa3a64B8322704988427F366; // Accountant arbi
    address private constant AUCTION_FACTORY = 0xCd1E4c17A5485f2a6DF1C01cC65EFDe25c951dBB; // DoS resistant auction factory

    function run() external {
        uint256 _privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(_privateKey);

        address _deployer = vm.addr(_privateKey);
        require(_deployer == MANAGEMENT, "!deployer");

        // AccountantFactory _accountantFactory = new AccountantFactory();
        // StakerFactory _stakerFactory = new StakerFactory(MANAGEMENT, PERFORMANCE_FEE_RECIPIENT, KEEPER, EMERGENCY_ADMIN);
        StrategyFactory _strategyFactory =
            new StrategyFactory(MANAGEMENT, PERFORMANCE_FEE_RECIPIENT, KEEPER, EMERGENCY_ADMIN, AUCTION_FACTORY);

        console.log("-----------------------------");
        console.log("Deployer: ", _deployer);
        // console.log("AccountantFactory deployed at: ", address(_accountantFactory));
        // console.log("StakerFactory deployed at: ", address(_stakerFactory));
        console.log("StrategyFactory deployed at: ", address(_strategyFactory));
        console.log("-----------------------------");

        vm.stopBroadcast();
    }

}

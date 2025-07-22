// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {StrategyAprOracle} from "../src/periphery/StrategyAprOracle.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeployAprOracle.s.sol:DeployAprOracle --verify --legacy --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

contract DeployAprOracle is Script {

    address private constant MANAGEMENT = 0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7; // SMS mainnet

    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // BOLD
        // address _multiTroveGetter = address(0xFA61dB085510C64B83056Db3A7Acf3b6f631D235);
        // address _collateralRegistry = address(0xf949982B91C8c61e952B3bA942cbbfaef5386684);

        // USDaf
        address _multiTroveGetter = address(0xb3683A407bddDDFB126Cf06Fb52d974a08fD7E80);
        address _collateralRegistry = address(0x33D68055Cd54061991B2e98b9ab326fFCE4d60Fe);

        StrategyAprOracle _oracle = new StrategyAprOracle(MANAGEMENT, _multiTroveGetter, _collateralRegistry);

        console.log("-----------------------------");
        console.log("apr oracle deployed at: ", address(_oracle));
        console.log("-----------------------------");

        vm.stopBroadcast();
    }

}

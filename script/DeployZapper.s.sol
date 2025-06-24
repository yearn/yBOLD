// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {Zapper} from "../src/periphery/Zapper.sol";
import {MorphoPriceOracle} from "../src/periphery/MorphoPriceOracle.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeployZapper.s.sol:DeployZapper --verify --legacy --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

contract DeployZapper is Script {

    address private constant MANAGEMENT = 0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7; // SMS mainnet

    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // Zapper _zapper = new Zapper();
        MorphoPriceOracle _oracle = new MorphoPriceOracle();

        console.log("-----------------------------");
        // console.log("zapper deployed at: ", address(_zapper));
        console.log("oracle deployed at: ", address(_oracle));
        console.log("-----------------------------");

        vm.stopBroadcast();
    }

}

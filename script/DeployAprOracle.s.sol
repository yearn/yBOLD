// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {StrategyAprOracle} from "../src/periphery/StrategyAprOracle.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeployAprOracle.s.sol:DeployAprOracle --verify --legacy --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

contract DeployAprOracle is Script {

    address private constant MANAGEMENT = 0x6346282DB8323A54E840c6C772B4399C9c655C0d; // SMS arbi

    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // BOLD
        // address _multiTroveGetter = address(0xFA61dB085510C64B83056Db3A7Acf3b6f631D235);
        // address _collateralRegistry = address(0xf949982B91C8c61e952B3bA942cbbfaef5386684);

        // // USDaf
        // address _multiTroveGetter = address(0xeC2302866D7bD20B4959318189b26E56Eb1edcA5);
        // address _collateralRegistry = address(0xCFf0DcAb01563e5324ef9D0AdB0677d9C167d791);

        // USND
        address _multiTroveGetter = address(0xe80BD7c36Ad662F1b007Dc1B1C490FBf4C47Ab88);
        address _collateralRegistry = address(0x7f7FbC2711C0D6E8eF757dBb82038032dD168e68);

        StrategyAprOracle _oracle = new StrategyAprOracle(MANAGEMENT, _multiTroveGetter, _collateralRegistry);

        console.log("-----------------------------");
        console.log("apr oracle deployed at: ", address(_oracle));
        console.log("-----------------------------");

        vm.stopBroadcast();
    }

}

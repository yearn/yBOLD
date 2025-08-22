// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {OnLossDepositLimit} from "../src/periphery/OnLossDepositLimit.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeployDepositLimitModule.s.sol:DeployDepositLimitModule --verify --legacy --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

contract DeployDepositLimitModule is Script {

    address private constant DEPLOYED = 0x285E3b1E82f74A99D07D2aD25e159E75382bB43B; // johnnyonline.eth

    function run() external {
        uint256 _privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(_privateKey);

        address _deployer = vm.addr(_privateKey);
        require(_deployer == DEPLOYED, "!deployer");

        OnLossDepositLimit _onLossDepositLimit = new OnLossDepositLimit();

        console.log("-----------------------------");
        console.log("Deployer: ", _deployer);
        console.log("OnLossDepositLimit deployed at: ", address(_onLossDepositLimit));
        console.log("-----------------------------");

        vm.stopBroadcast();
    }

}

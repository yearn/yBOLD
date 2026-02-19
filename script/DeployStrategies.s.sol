// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IStrategyInterface} from "../src/interfaces/IStrategyInterface.sol";

import {StrategyFactory} from "../src/StrategyFactory.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeployStrategies.s.sol:DeployStrategies --verify --legacy --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

contract DeployStrategies is Script {

    address[] public strategies;

    address public constant ASSET = 0x6440f144b7e50D6a8439336510312d2F54beB01D; // BOLD
    address public constant VAULT = 0x9F4330700a36B29952869fac9b33f45EEdd8A3d8; // yBOLD
    address private constant SMS = 0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7; // sms mainnet

    StrategyFactory public constant STRATEGY_FACTORY = StrategyFactory(0xbf7A38C6de0831916301B8dD09BD72FBd0C547D1);

    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        address _wethAddressesRegistry = address(0x20F7C9ad66983F6523a0881d0f82406541417526); // WETH Address Registry
        address _wethStrategy =
            STRATEGY_FACTORY.newStrategy(_wethAddressesRegistry, ASSET, "Liquity V2 WETH Stability Pool");
        strategies.push(_wethStrategy);

        address _wstethAddressesRegistry = address(0x8d733F7ea7c23Cbea7C613B6eBd845d46d3aAc54); // wstETH Address Registry
        address _wstethStrategy =
            STRATEGY_FACTORY.newStrategy(_wstethAddressesRegistry, ASSET, "Liquity V2 wstETH Stability Pool");
        strategies.push(_wstethStrategy);

        address _rethAddressesRegistry = address(0x6106046F031a22713697e04C08B330dDaf3e8789); // rETH Address Registry
        address _rethStrategy =
            STRATEGY_FACTORY.newStrategy(_rethAddressesRegistry, ASSET, "Liquity V2 rETH Stability Pool");
        strategies.push(_rethStrategy);

        for (uint256 i = 0; i < strategies.length; i++) {
            IStrategyInterface strategy = IStrategyInterface(strategies[i]);
            strategy.acceptManagement();
            strategy.setProfitMaxUnlockTime(0 days);
            strategy.setAllowed(VAULT);
            strategy.setPendingManagement(SMS);
            strategy.setPerformanceFee(0);
            require(strategy.performanceFee() == 0, "!fee");
        }

        vm.stopBroadcast();

        console.log("-----------------------------");
        console.log("WETH Strategy deployed at: ", _wethStrategy);
        console.log("wstETH Strategy deployed at: ", _wstethStrategy);
        console.log("rETH Strategy deployed at: ", _rethStrategy);
        console.log("-----------------------------");
    }

}

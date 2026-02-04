// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IVault} from "@yearn-vaults/interfaces/IVault.sol";

import {IStrategyInterface} from "../src/interfaces/IStrategyInterface.sol";

import {StrategyFactory} from "../src/StrategyFactory.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeploySavingsAf.s.sol:DeploySavingsAf --verify --legacy --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

// verify:
// --constructor-args $(cast abi-encode "constructor(address,string,address,address,address)" 0x29219dd400f2Bf60E5a23d13Be72B486D4038894 "Silo Lender S/USDC (8)" 0x4E216C15697C1392fE59e1014B009505E05810Df 0x0dd368Cd6D8869F2b21BA3Cb4fd7bA107a2e3752 0x71ccF86Cf63A5d55B12AA7E7079C22f39112Dd7D)
// forge verify-contract --etherscan-api-key $KEY --watch --chain-id 42161 --compiler-version v0.8.18+commit.87f61d96 --verifier-url https://api.arbiscan.io/api 0x9a5eca1b228e47a15BD9fab07716a9FcE9Eebfb5 src/ERC404/BaseERC404.sol:BaseERC404

interface ICentralAPROracle {
    function setOracle(address strategy, address oracle) external;
}

interface ICommonReportTrigger {
    function setCustomStrategyTrigger(address strategy, address trigger) external;
}

contract DeploySavingsAf is Script {

    address[] public strategies;

    address private constant ASSET = 0x4ecf61a6c2FaB8A047CEB3B3B263B401763e9D49; // USND
    address private constant DEPLOYER = 0x420ACF637D662b80cca8bEfb327AA24039E7e0Fa; // deployer
    address private constant SMS = 0x6346282DB8323A54E840c6C772B4399C9c655C0d; // sms arbi
    address private constant KEEPER = 0xE0D19f6b240659da8E87ABbB73446E7B4346Baee; // yHaaS arbi
    address private constant EMERGENCY_ADMIN = 0x6346282DB8323A54E840c6C772B4399C9c655C0d; // SMS arbi
    address private constant PERFORMANCE_FEE_RECIPIENT = 0x9aB47bE62631036CDa3a64B8322704988427F366; // Accountant arbi
    address private constant AUCTION_FACTORY = address(0xbA7FCb508c7195eE5AE823F37eE2c11D7ED52F8e); // 1.0.4 Auction Factory
    address private constant STRATEGY_APR_ORACLE = 0x0f4A7b0831046e60271E8eF815dFE1CBf8163E0D;
    address private constant STRATEGY_REPORT_TRIGGER = 0x105fb2A5e8dee81b11A0c6A21a1EB13cbb08E3B0;

    IVault private constant VAULT = IVault(0x252b965400862d94BDa35FeCF7Ee0f204a53Cc36); // yUSND
    ICentralAPROracle private constant CENTRAL_APR_ORACLE = ICentralAPROracle(0x1981AD9F44F2EA9aDd2dC4AD7D075c102C70aF92);
    ICommonReportTrigger private constant COMMON_REPORT_TRIGGER = ICommonReportTrigger(0xA045D4dAeA28BA7Bfe234c96eAa03daFae85A147);

    function run() external {

        uint256 _privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address _deployer = vm.addr(_privateKey);
        require(_deployer == DEPLOYER, "!deployer");

        vm.startBroadcast(_privateKey);

        StrategyFactory _strategyFactory =
            new StrategyFactory(DEPLOYER, PERFORMANCE_FEE_RECIPIENT, KEEPER, EMERGENCY_ADMIN, AUCTION_FACTORY);

        address _wethStrategy = _strategyFactory.newStrategy(
            address(0xBB6C6B994409b320E25e7dE129e0db5dA60aE89B), // WETH Address Registry
            ASSET,
            "USND WETH Stability Pool"
        );
        strategies.push(_wethStrategy);

        address _wstETHStrategy = _strategyFactory.newStrategy(
            address(0x5176fDd77FDef5B7F1EDd457D02a8ec1cFebBb34), // wstETH Address Registry
            ASSET,
            "USND wstETH Stability Pool"
        );
        strategies.push(_wstETHStrategy);

        address _rETHStrategy = _strategyFactory.newStrategy(
            address(0x51253Ae341F6dD1c4Ff5692dE0eE69492743895E), // rETH Address Registry
            ASSET,
            "USND rETH Stability Pool"
        );
        strategies.push(_rETHStrategy);

        address _tBTCStrategy = _strategyFactory.newStrategy(
            address(0xF329FB0E818bD92395785a4f863636bC0D85e1DF), // tBTC Address Registry
            ASSET,
            "USND tBTC Stability Pool"
        );
        strategies.push(_tBTCStrategy);

        for (uint256 i = 0; i < strategies.length; i++) {
            IStrategyInterface strategy = IStrategyInterface(strategies[i]);
            strategy.acceptManagement();
            strategy.setProfitMaxUnlockTime(0);
            strategy.setAllowed(address(VAULT));
            strategy.setPendingManagement(SMS);
            strategy.setPerformanceFee(0);
            require(strategy.performanceFee() == 0, "!fee");

            CENTRAL_APR_ORACLE.setOracle(address(strategy), STRATEGY_APR_ORACLE);
            COMMON_REPORT_TRIGGER.setCustomStrategyTrigger(address(strategy), STRATEGY_REPORT_TRIGGER);
        }

        vm.stopBroadcast();

        console.log("-----------------------------");
        console.log("WETH Strategy deployed at: ", _wethStrategy);
        console.log("wstETH Strategy deployed at: ", _wstETHStrategy);
        console.log("rETH Strategy deployed at: ", _rETHStrategy);
        console.log("tBTC Strategy deployed at: ", _tBTCStrategy);
        console.log("yUSND deployed at: ", address(VAULT));
        console.log("StrategyFactory deployed at: ", address(_strategyFactory));
        console.log("-----------------------------");
    }

}

// -----------------------------
// WETH Strategy deployed at:  0xAAaa4896db8A0A1E5dB474f5729D4f72e0AD348b
// wstETH Strategy deployed at:  0x6A825c55ab41667acb211dAd2F88481C2ab26aC3
// rETH Strategy deployed at:  0x557A4aa35b78F1A95B1cEc711fB5bA74B7C4C6e0
// tBTC Strategy deployed at:  0xf1cB3D11b4852475398232dA3e568ba86a22D745
// yUSND deployed at:  0x252b965400862d94BDa35FeCF7Ee0f204a53Cc36
// StrategyFactory deployed at:  0xBC9ceCb17d2d7d46d9552DEe73Cf838967cC85cB
// -----------------------------

// ----------------------------- (with fixed AuctionFactory)
// WETH Strategy deployed at:  0xD932487eda5D8CB911AE2489E0778bdAFa9d9A08
// wstETH Strategy deployed at:  0x62CCe59C2b9A7D3C08F768F8B99AAd5a7B54c795
// rETH Strategy deployed at:  0xFC14b7A68b0020B64D781D4a2E27409245ADc764
// tBTC Strategy deployed at:  0x3c92f5E821E65312CF40A32a50247c4363a919dA
// yUSND deployed at:  0x252b965400862d94BDa35FeCF7Ee0f204a53Cc36
// StrategyFactory deployed at:  0x5B2E623D0A2722091545bCD29B2984905eAA0647
// -----------------------------
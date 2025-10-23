// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IVault} from "@yearn-vaults/interfaces/IVault.sol";
import {IVaultFactory} from "@yearn-vaults/interfaces/IVaultFactory.sol";

import {IStrategyInterface} from "../src/interfaces/IStrategyInterface.sol";

import {wstETHPriceOracle} from "../src/periphery/Oracles/wstETHOracle.sol";
import {rETHPriceOracle} from "../src/periphery/Oracles/rETHOracle.sol";
import {rsETHPriceOracle} from "../src/periphery/Oracles/rsETHOracle.sol";
import {weETHPriceOracle} from "../src/periphery/Oracles/weETHOracle.sol";

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

    string private constant NAME = "Yearn USND";
    string private constant SYMBOL = "yUSND";

    address private constant ASSET = 0x4ecf61a6c2FaB8A047CEB3B3B263B401763e9D49; // USND
    address private constant DEPLOYER = 0x420ACF637D662b80cca8bEfb327AA24039E7e0Fa; // deployer
    address private constant SMS = 0x6346282DB8323A54E840c6C772B4399C9c655C0d; // sms arbi
    address private constant KEEPER = 0xE0D19f6b240659da8E87ABbB73446E7B4346Baee; // yHaaS arbi
    address private constant EMERGENCY_ADMIN = 0x6346282DB8323A54E840c6C772B4399C9c655C0d; // SMS arbi
    address private constant PERFORMANCE_FEE_RECIPIENT = 0x9aB47bE62631036CDa3a64B8322704988427F366; // Accountant arbi
    address private constant AUCTION_FACTORY = address(0xbC587a495420aBB71Bbd40A0e291B64e80117526); // Newest Auction Factory

    IVault private constant VAULT = IVault(0x252b965400862d94BDa35FeCF7Ee0f204a53Cc36); // yUSND

    function run() external {
        uint256 _privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(_privateKey);

        ICentralAPROracle central_apr_oracle = ICentralAPROracle(0x1981AD9F44F2EA9aDd2dC4AD7D075c102C70aF92);
        ICommonReportTrigger common_report_trigger = ICommonReportTrigger(0xA045D4dAeA28BA7Bfe234c96eAa03daFae85A147);

        address strategy_apr_oracle = 0x0f4A7b0831046e60271E8eF815dFE1CBf8163E0D;
        address strategy_report_trigger = 0x105fb2A5e8dee81b11A0c6A21a1EB13cbb08E3B0;

        address[] memory strategies = new address[](8);
        strategies[0] = 0xF481e436124ED61982045278E8B3D02476264351;
        strategies[1] = 0xd629feA11620FC50781aA64c845cf7099F6E0a42;
        strategies[2] = 0x9498F94baBb2D026b8413C7Bd5372CD989026B45;
        strategies[3] = 0x38d95EaFE81DAE368927BcE18B110dFF0c3f15e5;
        strategies[4] = 0x10548930e6D4E390fFD665d52037FcC6d1a51D47;
        strategies[5] = 0x3ec055FC8B81Ad3F942A41a8730989683100C4cC;
        strategies[6] = 0x836312c0e36bDe6F509250E6C799dB072Aa7C264;
        strategies[7] = 0xb6434621bB2237CDc958059F0b153F15690896f2;

        for (uint256 i = 0; i < strategies.length; i++) {
            central_apr_oracle.setOracle(strategies[i], strategy_apr_oracle);
            common_report_trigger.setCustomStrategyTrigger(strategies[i], strategy_report_trigger);
        }

        // address _deployer = vm.addr(_privateKey);
        // require(_deployer == DEPLOYER, "!deployer");

        // StrategyFactory _strategyFactory =
        //     new StrategyFactory(DEPLOYER, PERFORMANCE_FEE_RECIPIENT, KEEPER, EMERGENCY_ADMIN, AUCTION_FACTORY);

        // address _wethStrategy = _strategyFactory.newStrategy(
        //     address(0xBB6C6B994409b320E25e7dE129e0db5dA60aE89B), // WETH Address Registry
        //     ASSET,
        //     address(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612), // Chainlink ETH/USD
        //     "USND WETH Stability Pool"
        // );
        // strategies.push(_wethStrategy);

        // address _wstETHStrategy = _strategyFactory.newStrategy(
        //     address(0x5176fDd77FDef5B7F1EDd457D02a8ec1cFebBb34), // wstETH Address Registry
        //     ASSET,
        //     address(new wstETHPriceOracle()), // wstETH/USD Oracle
        //     "USND wstETH Stability Pool"
        // );
        // strategies.push(_wstETHStrategy);

        // address _rETHStrategy = _strategyFactory.newStrategy(
        //     address(0x51253Ae341F6dD1c4Ff5692dE0eE69492743895E), // rETH Address Registry
        //     ASSET,
        //     address(new rETHPriceOracle()), // rETH/USD Oracle
        //     "USND rETH Stability Pool"
        // );
        // strategies.push(_rETHStrategy);

        // address _rsETHStrategy = _strategyFactory.newStrategy(
        //     address(0xcbF5786902487C1165a98f48Ebc65Fa0e62739C6), // rsETH Address Registry
        //     ASSET,
        //     address(new rsETHPriceOracle()), // rsETH/USD Oracle
        //     "USND rsETH Stability Pool"
        // );
        // strategies.push(_rsETHStrategy);

        // address _weETHStrategy = _strategyFactory.newStrategy(
        //     address(0xc23928FD7D93ccb61ca60F09311De2DdA66c02e4), // weETH Address Registry
        //     ASSET,
        //     address(new weETHPriceOracle()), // weETH/USD Oracle
        //     "USND weETH Stability Pool"
        // );
        // strategies.push(_weETHStrategy);

        // address _ARBStrategy = _strategyFactory.newStrategy(
        //     address(0x7900B65266e157D9fce97e92Ac3879CB712dEd31), // ARB Address Registry
        //     ASSET,
        //     address(0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6), // Chainlink ARB/USD
        //     "USND ARB Stability Pool"
        // );
        // strategies.push(_ARBStrategy);

        // address _COMPStrategy = _strategyFactory.newStrategy(
        //     address(0xfe75AdD51A119e556ACD53676b12f865A6737177), // COMP Address Registry
        //     ASSET,
        //     address(0xe7C53FFd03Eb6ceF7d208bC4C13446c76d1E5884), // Chainlink COMP/USD
        //     "USND COMP Stability Pool"
        // );
        // strategies.push(_COMPStrategy);

        // address _tBTCStrategy = _strategyFactory.newStrategy(
        //     address(0xF329FB0E818bD92395785a4f863636bC0D85e1DF), // tBTC Address Registry
        //     ASSET,
        //     address(0xE808488e8627F6531bA79a13A9E0271B39abEb1C), // Chainlink tBTC/USD
        //     "USND tBTC Stability Pool"
        // );
        // strategies.push(_tBTCStrategy);

        // for (uint256 i = 0; i < strategies.length; i++) {
        //     IStrategyInterface strategy = IStrategyInterface(strategies[i]);
        //     strategy.acceptManagement();
        //     strategy.setProfitMaxUnlockTime(0);
        //     strategy.setAllowed(address(VAULT));
        //     strategy.setPendingManagement(SMS);
        //     strategy.setPerformanceFee(0);
        //     require(strategy.performanceFee() == 0, "!fee");
        // }

        vm.stopBroadcast();

        // console.log("-----------------------------");
        // console.log("WETH Strategy deployed at: ", _wethStrategy);
        // console.log("wstETH Strategy deployed at: ", _wstETHStrategy);
        // console.log("rETH Strategy deployed at: ", _rETHStrategy);
        // console.log("rsETH Strategy deployed at: ", _rsETHStrategy);
        // console.log("weETH Strategy deployed at: ", _weETHStrategy);
        // console.log("ARB Strategy deployed at: ", _ARBStrategy);
        // console.log("COMP Strategy deployed at: ", _COMPStrategy);
        // console.log("tBTC Strategy deployed at: ", _tBTCStrategy);
        // console.log("yUSND deployed at: ", address(VAULT));
        // console.log("StrategyFactory deployed at: ", address(_strategyFactory));
        // console.log("-----------------------------");
    }

}
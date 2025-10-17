// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {ExtendedTest} from "./ExtendedTest.sol";

import {wstETHPriceOracle} from "../../periphery/Oracles/wstETHOracle.sol";
import {rETHPriceOracle} from "../../periphery/Oracles/rETHOracle.sol";
import {rsETHPriceOracle} from "../../periphery/Oracles/rsETHOracle.sol";
import {weETHPriceOracle} from "../../periphery/Oracles/weETHOracle.sol";

import {LiquityV2SPStrategy as Strategy, ERC20} from "../../Strategy.sol";
import {StrategyFactory} from "../../StrategyFactory.sol";
import {IStrategyInterface} from "../../interfaces/IStrategyInterface.sol";
import {AggregatorV3Interface} from "../../interfaces/AggregatorV3Interface.sol";
import {IStabilityPool} from "../../interfaces/IStabilityPool.sol";
import {IActivePool} from "../../interfaces/IActivePool.sol";

// Inherit the events so they can be checked if desired.
import {IEvents} from "@tokenized-strategy/interfaces/IEvents.sol";

interface IFactory {

    function governance() external view returns (address);

    function set_protocol_fee_bps(
        uint16
    ) external;

    function set_protocol_fee_recipient(
        address
    ) external;

}

contract Setup is ExtendedTest, IEvents {

    // Contract instances that we will use repeatedly.
    ERC20 public asset;
    IStrategyInterface public strategy;

    StrategyFactory public strategyFactory;

    mapping(string => address) public tokenAddrs;

    // Addresses for different roles we will use repeatedly.
    address public user = address(10);
    address public keeper = address(4);
    address public management = address(1);
    address public performanceFeeRecipient = address(3);
    address public emergencyAdmin = address(5);

    // // Contract addresses.
    // address public multiTroveGetter = address(0xFA61dB085510C64B83056Db3A7Acf3b6f631D235);
    // address public collateralRegistry = address(0xf949982B91C8c61e952B3bA942cbbfaef5386684);
    // address public addressesRegistry = address(0x20F7C9ad66983F6523a0881d0f82406541417526); // WETH Address Registry
    // address public stabilityPool = address(0x5721cbbd64fc7Ae3Ef44A0A3F9a790A9264Cf9BF); // WETH Stability Pool
    // address public collateralPriceOracle = address(0xCC5F8102eb670c89a4a3c567C13851260303c24F); // Liquity WETH Price Oracle
    // address public collateralChainlinkPriceOracle = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419); // Chainlink ETH/USD
    // address public auctionFactory = address(0xbC587a495420aBB71Bbd40A0e291B64e80117526); // Newest Auction Factory

    // --------------------------------------------------------------

    // // Contract addresses. WETH, Nerite
    // address public multiTroveGetter = address(0xe80BD7c36Ad662F1b007Dc1B1C490FBf4C47Ab88);
    // address public collateralRegistry = address(0x7f7FbC2711C0D6E8eF757dBb82038032dD168e68);
    // address public addressesRegistry = address(0xBB6C6B994409b320E25e7dE129e0db5dA60aE89B); // WETH Address Registry
    // address public stabilityPool = address(0x9d9EF87a197c1bb3a97B2Ddc8716dF99079c125E); // WETH Stability Pool
    // address public collateralPriceOracle = address(0x8483efA691CE3f20eDCC9F8453F85B64F9872Fcb); // Liquity WETH Price Oracle
    // address public collateralChainlinkPriceOracle = address(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612); // Chainlink ETH/USD
    // address public auctionFactory = address(0xbC587a495420aBB71Bbd40A0e291B64e80117526); // Newest Auction Factory
    // address public collateralToken = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1); // WETH

    // // Contract addresses. wstETH, Nerite
    // address public multiTroveGetter = address(0xe80BD7c36Ad662F1b007Dc1B1C490FBf4C47Ab88);
    // address public collateralRegistry = address(0x7f7FbC2711C0D6E8eF757dBb82038032dD168e68);
    // address public addressesRegistry = address(0x5176fDd77FDef5B7F1EDd457D02a8ec1cFebBb34); // wstETH Address Registry
    // address public stabilityPool = address(0xcD94b16e9a126fe61c944b1DE024681fCfE05c4B); // wstETH Stability Pool
    // address public collateralPriceOracle = address(0x2148AfFe49A44a15d6BC71A0a8F302d43Cf99d52); // Liquity wstETH Price Oracle
    // address public collateralChainlinkPriceOracle; // Chainlink wstETH/USD
    // address public auctionFactory = address(0xbC587a495420aBB71Bbd40A0e291B64e80117526); // Newest Auction Factory
    // address public collateralToken = address(0x5979D7b546E38E414F7E9822514be443A4800529); // wstETH

    // // Contract addresses. rETH, Nerite
    // address public multiTroveGetter = address(0xe80BD7c36Ad662F1b007Dc1B1C490FBf4C47Ab88);
    // address public collateralRegistry = address(0x7f7FbC2711C0D6E8eF757dBb82038032dD168e68);
    // address public addressesRegistry = address(0x51253Ae341F6dD1c4Ff5692dE0eE69492743895E); // rETH Address Registry
    // address public stabilityPool = address(0x47Ae276a1cc751cE7B3034D9cBB8cD422968Ac35); // rETH Stability Pool
    // address public collateralPriceOracle = address(0x28d0931811B956366f86164D1c088FCBeb0711D5); // Liquity rETH Price Oracle
    // address public collateralChainlinkPriceOracle; // Chainlink rETH/USD
    // address public auctionFactory = address(0xbC587a495420aBB71Bbd40A0e291B64e80117526); // Newest Auction Factory
    // address public collateralToken = address(0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8); // rETH

    // // Contract addresses. rsETH, Nerite
    // address public multiTroveGetter = address(0xe80BD7c36Ad662F1b007Dc1B1C490FBf4C47Ab88);
    // address public collateralRegistry = address(0x7f7FbC2711C0D6E8eF757dBb82038032dD168e68);
    // address public addressesRegistry = address(0xcbF5786902487C1165a98f48Ebc65Fa0e62739C6); // rsETH Address Registry
    // address public stabilityPool = address(0xAfB439c47b3F518a7d8EF3b82F70dF30d84e51EE); // rsETH Stability Pool
    // address public collateralPriceOracle = address(0x95E9327E6AbF146570cD24402BdbCB56A9a5ba8a); // Liquity rsETH Price Oracle
    // address public collateralChainlinkPriceOracle; // Chainlink rsETH/USD
    // address public auctionFactory = address(0xbC587a495420aBB71Bbd40A0e291B64e80117526); // Newest Auction Factory
    // address public collateralToken = address(0x4186BFC76E2E237523CBC30FD220FE055156b41F); // rsETH

    // // Contract addresses. weETH, Nerite
    // address public multiTroveGetter = address(0xe80BD7c36Ad662F1b007Dc1B1C490FBf4C47Ab88);
    // address public collateralRegistry = address(0x7f7FbC2711C0D6E8eF757dBb82038032dD168e68);
    // address public addressesRegistry = address(0xc23928FD7D93ccb61ca60F09311De2DdA66c02e4); // weETH Address Registry
    // address public stabilityPool = address(0x9c3aef8fB9097bb59821422D47F226e35403019a); // weETH Stability Pool
    // address public collateralPriceOracle = address(0x39c2a023b8Aed406671A0bed1b02fe548F0D2098); // Liquity weETH Price Oracle
    // address public collateralChainlinkPriceOracle; // Chainlink weETH/USD
    // address public auctionFactory = address(0xbC587a495420aBB71Bbd40A0e291B64e80117526); // Newest Auction Factory
    // address public collateralToken = address(0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe); // weETH

    // // Contract addresses. ARB, Nerite
    // address public multiTroveGetter = address(0xe80BD7c36Ad662F1b007Dc1B1C490FBf4C47Ab88);
    // address public collateralRegistry = address(0x7f7FbC2711C0D6E8eF757dBb82038032dD168e68);
    // address public addressesRegistry = address(0x7900B65266e157D9fce97e92Ac3879CB712dEd31); // ARB Address Registry
    // address public stabilityPool = address(0xb2C0460466c8d6384f52Cd29Db54Ee49D01eE84A); // ARB Stability Pool
    // address public collateralPriceOracle = address(0xC2A8B601947BEAF2EFE650a39De3E3e0b5c95721); // Liquity ARB Price Oracle
    // address public collateralChainlinkPriceOracle = address(0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6); // Chainlink ARB/USD
    // address public auctionFactory = address(0xbC587a495420aBB71Bbd40A0e291B64e80117526); // Newest Auction Factory
    // address public collateralToken = address(0x912CE59144191C1204E64559FE8253a0e49E6548); // ARB

    // // Contract addresses. COMP, Nerite
    // address public multiTroveGetter = address(0xe80BD7c36Ad662F1b007Dc1B1C490FBf4C47Ab88);
    // address public collateralRegistry = address(0x7f7FbC2711C0D6E8eF757dBb82038032dD168e68);
    // address public addressesRegistry = address(0xfe75AdD51A119e556ACD53676b12f865A6737177); // COMP Address Registry
    // address public stabilityPool = address(0x65b83dE0733e237dd3d49a4E9c2868B57ee7d9F0); // COMP Stability Pool
    // address public collateralPriceOracle = address(0x375bbb7CFC3b438D9d4a0f745569017f47Eb55D8); // Liquity COMP Price Oracle
    // address public collateralChainlinkPriceOracle = address(0xe7C53FFd03Eb6ceF7d208bC4C13446c76d1E5884); // Chainlink COMP/USD
    // address public auctionFactory = address(0xbC587a495420aBB71Bbd40A0e291B64e80117526); // Newest Auction Factory
    // address public collateralToken = address(0x354A6dA3fcde098F8389cad84b0182725c6C91dE); // COMP

    // Contract addresses. tBTC, Nerite
    address public multiTroveGetter = address(0xe80BD7c36Ad662F1b007Dc1B1C490FBf4C47Ab88);
    address public collateralRegistry = address(0x7f7FbC2711C0D6E8eF757dBb82038032dD168e68);
    address public addressesRegistry = address(0xF329FB0E818bD92395785a4f863636bC0D85e1DF); // tBTC Address Registry
    address public stabilityPool = address(0xe1Fa1F28A67A8807447717f51BF3305636962126); // tBTC Stability Pool
    address public collateralPriceOracle = address(0x993d4Ed0EC1936bD86D765666dfb96Bef6Fdad10); // Liquity tBTC Price Oracle
    address public collateralChainlinkPriceOracle = address(0xE808488e8627F6531bA79a13A9E0271B39abEb1C); // Chainlink tBTC/USD
    address public auctionFactory = address(0xbC587a495420aBB71Bbd40A0e291B64e80117526); // Newest Auction Factory
    address public collateralToken = address(0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40); // tBTC

    // --------------------------------------------------------------

    // Address of the real deployed Factory
    address public factory;

    // Integer variables that will be used repeatedly.
    uint256 public decimals;
    uint256 public MAX_BPS = 10_000;

    // Fuzz from $0.1 of 1e18 stable coins up to 10 billion of a 1e18 coin
    uint256 public maxFuzzAmount = 10_000_000_000 ether;
    uint256 public minFuzzAmount = 0.1 ether;

    // Default profit max unlock time is set for 10 days
    uint256 public profitMaxUnlockTime = 10 days;

    function setUp() public virtual {
        // uint256 _blockNumber = 23_499_885; // Caching for faster tests
        // vm.selectFork(vm.createFork(vm.envString("ETH_RPC_URL"), _blockNumber));
        uint256 _blockNumber = 390_595_981; // Caching for faster tests
        vm.selectFork(vm.createFork(vm.envString("ARB_RPC_URL"), _blockNumber));

        _setTokenAddrs();

        // Set asset
        asset = ERC20(tokenAddrs["BOLD"]);

        // Set decimals
        decimals = asset.decimals();

        strategyFactory =
            new StrategyFactory(management, performanceFeeRecipient, keeper, emergencyAdmin, auctionFactory);

        // Deploy strategy and set variables
        strategy = IStrategyInterface(setUpStrategy());

        factory = strategy.FACTORY();

        // label all the used addresses for traces
        vm.label(keeper, "keeper");
        vm.label(factory, "factory");
        vm.label(address(asset), "asset");
        vm.label(management, "management");
        vm.label(address(strategy), "strategy");
        vm.label(performanceFeeRecipient, "performanceFeeRecipient");
    }

    function setUpStrategy() public returns (address) {
        // Deploy price oracle
        if (collateralChainlinkPriceOracle == address(0)) {
            // collateralChainlinkPriceOracle = address(new wstETHPriceOracle());
            // collateralChainlinkPriceOracle = address(new rETHPriceOracle());
            // collateralChainlinkPriceOracle = address(new rsETHPriceOracle());
            collateralChainlinkPriceOracle = address(new weETHPriceOracle());
        }

        // we save the strategy as a IStrategyInterface to give it the needed interface
        vm.prank(management);
        IStrategyInterface _strategy = IStrategyInterface(
            address(
                strategyFactory.newStrategy(
                    addressesRegistry, address(asset), collateralChainlinkPriceOracle, "Tokenized Strategy"
                )
            )
        );

        vm.prank(management);
        _strategy.acceptManagement();

        return address(_strategy);
    }

    function depositIntoStaker(
        IStrategyInterface _asset,
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        vm.prank(_user);
        _asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        _strategy.deposit(_amount, _user);
    }

    function depositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        vm.prank(_user);
        asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        _strategy.deposit(_amount, _user);
    }

    function mintAndDepositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        airdrop(asset, _user, _amount);
        depositIntoStrategy(_strategy, _user, _amount);
    }

    // For checking the amounts in the strategy
    function checkStrategyTotals(
        IStrategyInterface _strategy,
        uint256 _totalAssets,
        uint256 _totalDebt,
        uint256 _totalIdle
    ) public {
        uint256 _assets = _strategy.totalAssets();
        uint256 _balance = ERC20(_strategy.asset()).balanceOf(address(_strategy));
        uint256 _idle = _balance > _assets ? _assets : _balance;
        uint256 _debt = _assets - _idle;
        assertEq(_assets, _totalAssets, "!totalAssets");
        assertEq(_debt, _totalDebt, "!totalDebt");
        assertEq(_idle, _totalIdle, "!totalIdle");
        assertEq(_totalAssets, _totalDebt + _totalIdle, "!Added");
    }

    function airdrop(
        ERC20 _asset,
        address _to,
        uint256 _amount
    ) public {
        uint256 balanceBefore = _asset.balanceOf(_to);
        deal(address(_asset), _to, balanceBefore + _amount);
    }

    function simulateYieldGain(
        uint256 _amount
    ) public {
        airdrop(ERC20(tokenAddrs["BOLD"]), stabilityPool, _amount);
        IStabilityPool _stabilityPool = IStabilityPool(stabilityPool);
        vm.prank(_stabilityPool.activePool());
        _stabilityPool.triggerBoldRewards(_amount);
        strategy.claim();
    }

    function simulateCollateralGain() public {
        IStabilityPool _stabilityPool = IStabilityPool(stabilityPool);
        uint256 _availableCollateral = IActivePool(_stabilityPool.activePool()).getCollBalance();
        uint256 _collToAdd = _availableCollateral / 10;
        require(_collToAdd >= 1 ether, "simulateCollateralGain: Not enough collateral!");
        uint256 _debtToOffset = _collToAdd * ethPrice() / 1e18;
        uint256 _totalBoldDeposits = _stabilityPool.getTotalBoldDeposits();
        if (_debtToOffset > _totalBoldDeposits) {
            uint256 _amountToDeposit = _debtToOffset - _totalBoldDeposits;
            address _shrimp = address(420);
            airdrop(ERC20(tokenAddrs["BOLD"]), _shrimp, _amountToDeposit);
            vm.prank(_shrimp);
            _stabilityPool.provideToSP(_amountToDeposit, true);
        }
        vm.prank(address(_stabilityPool.troveManager()));
        _stabilityPool.offset(_debtToOffset, _collToAdd);
    }

    function ethPrice() public view returns (uint256) {
        (, int256 price,,,) = AggregatorV3Interface(collateralChainlinkPriceOracle).latestRoundData();
        return uint256(price);
    }

    function setFees(
        uint16 _protocolFee,
        uint16 _performanceFee
    ) public {
        address gov = IFactory(factory).governance();

        // Need to make sure there is a protocol fee recipient to set the fee.
        vm.prank(gov);
        IFactory(factory).set_protocol_fee_recipient(gov);

        vm.prank(gov);
        IFactory(factory).set_protocol_fee_bps(_protocolFee);

        vm.prank(management);
        strategy.setPerformanceFee(_performanceFee);
    }

    function _setTokenAddrs() internal {
        tokenAddrs["WBTC"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        tokenAddrs["YFI"] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
        tokenAddrs["WETH"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on arbi
        tokenAddrs["LINK"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        tokenAddrs["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokenAddrs["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokenAddrs["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokenAddrs["BOLD"] = 0x4ecf61a6c2FaB8A047CEB3B3B263B401763e9D49; // USND
    }

}

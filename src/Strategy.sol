// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {BaseHealthCheck, BaseStrategy, ERC20} from "@periphery/Bases/HealthCheck/BaseHealthCheck.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {IStabilityPool} from "./interfaces/IStabilityPool.sol";
import {IAuction} from "./interfaces/IAuction.sol";
import {IAuctionFactory} from "./interfaces/IAuctionFactory.sol";
import {IAddressesRegistry} from "./interfaces/IAddressesRegistry.sol";

contract LiquityV2SPStrategy is BaseHealthCheck {

    using SafeERC20 for ERC20;

    // ===============================================================
    // Storage
    // ===============================================================

    /// @notice Whether deposits are open to everyone
    bool public openDeposits;

    /// @notice Minimum acceptable auction price expressed in basis points of the oracle price
    /// @dev Set to 0 to disable the check
    uint256 public minAuctionPriceBps;

    /// @notice Maximum amount of collateral that can be auctioned at once
    uint256 public maxAuctionAmount;

    /// @notice Max base fee (in gwei) for a tend
    uint256 public maxGasPriceToTend;

    /// @notice Buffer percentage for the auction starting price
    uint256 public bufferPercentage;

    /// @notice Minimum amount of collateral considered significant for claiming, auctioning, or tending
    uint256 public dustThreshold;

    /// @notice Addresses allowed to deposit when openDeposits is false
    mapping(address => bool) public allowed;

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice WAD constant
    uint256 private constant WAD = 1e18;

    /// @notice Auction starting price buffer percentage increase when the oracle is down
    uint256 public constant ORACLE_DOWN_BUFFER_PCT_MULTIPLIER = 200; // 200x

    /// @notice Minimum buffer percentage for the auction starting price
    uint256 public constant MIN_BUFFER_PERCENTAGE = WAD + 15e16; // 15%

    /// @notice Minimum `maxGasPriceToTend`
    uint256 public constant MIN_MAX_GAS_PRICE_TO_TEND = 50 * 1e9; // 50 gwei

    /// @notice Minimum allowable dust threshold for collateral
    /// @dev Serves two purposes:
    /// - Defines the lowest value that `dustThreshold` (the collateral dust threshold) can be set to
    /// - Also reused as the fixed `ASSET_DUST_THRESHOLD`, representing the minimum asset amount
    ///   considered worth depositing during harvests
    uint256 public constant MIN_DUST_THRESHOLD = 1e15;

    /// @notice Asset dust threshold. We will not bother depositing amounts below this value on harvests
    uint256 public constant ASSET_DUST_THRESHOLD = MIN_DUST_THRESHOLD;

    /// @notice Collateral reward token of the Stability Pool
    ERC20 public immutable COLL;

    /// @notice Liquity's price oracle for the collateral token
    /// @dev Assumes the price feed is using 18 decimals
    IPriceFeed public immutable COLL_PRICE_ORACLE;

    /// @notice Stability Pool contract
    IStabilityPool public immutable SP;

    /// @notice Auction contract for selling the collateral reward token
    IAuction public immutable AUCTION;

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _addressesRegistry Address of the AddressesRegistry
    /// @param _asset Address of the strategy's underlying asset
    /// @param _auctionFactory Address of the AuctionFactory
    /// @param _name Name of the strategy
    constructor(
        address _addressesRegistry,
        address _asset,
        address _auctionFactory,
        string memory _name
    ) BaseHealthCheck(_asset, _name) {
        COLL_PRICE_ORACLE = IAddressesRegistry(_addressesRegistry).priceFeed();
        (, bool _isOracleDown) = COLL_PRICE_ORACLE.fetchPrice();
        require(!_isOracleDown && COLL_PRICE_ORACLE.priceSource() == IPriceFeed.PriceSource.primary, "!oracle");

        SP = IAddressesRegistry(_addressesRegistry).stabilityPool();
        require(SP.boldToken() == _asset, "!sp");
        COLL = ERC20(SP.collToken());

        AUCTION = IAuctionFactory(_auctionFactory).createNewAuction(_asset);
        AUCTION.setGovernanceOnlyKick(true);
        AUCTION.enable(address(COLL));

        minAuctionPriceBps = 9_500; // 95%
        maxAuctionAmount = type(uint256).max;
        maxGasPriceToTend = 200 * 1e9;
        bufferPercentage = MIN_BUFFER_PERCENTAGE;
        dustThreshold = MIN_DUST_THRESHOLD;
    }

    // ===============================================================
    // View functions
    // ===============================================================

    /// @notice Check if there are collateral gains to claim from the Stability Pool
    /// @return True if there are collateral gains to claim
    function isCollateralGainToClaim() public view returns (bool) {
        return SP.getDepositorCollGain(address(this)) > dustThreshold;
    }

    /// @notice Estimated total assets held by the strategy
    /// @dev Does not account for pending collateral reward value
    /// @return Estimated total assets held by the strategy
    function estimatedTotalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)) + SP.getCompoundedBoldDeposit(address(this));
    }

    /// @inheritdoc BaseStrategy
    function availableDepositLimit(
        address _owner
    ) public view override returns (uint256) {
        return openDeposits || allowed[_owner] ? type(uint256).max : 0;
    }

    /// @inheritdoc BaseStrategy
    function availableWithdrawLimit(
        address /*_owner*/
    ) public view override returns (uint256) {
        return estimatedTotalAssets();
    }

    // ===============================================================
    // Management functions
    // ===============================================================

    /// @notice Allow anyone to deposit
    /// @dev This is irreversible
    function allowDeposits() external onlyManagement {
        openDeposits = true;
    }

    /// @notice Set the minimum acceptable auction price
    /// @dev Setting to 0 disables the check
    /// @param _minAuctionPriceBps New minimum acceptable auction price in BPS of the oracle price
    function setMinAuctionPriceBps(
        uint256 _minAuctionPriceBps
    ) external onlyManagement {
        require(_minAuctionPriceBps < MAX_BPS, "!minAuctionPriceBps");
        minAuctionPriceBps = _minAuctionPriceBps;
    }

    /// @notice Set the maximum amount of collateral that can be auctioned at once
    /// @param _maxAuctionAmount New maximum collateral amount to auction at once
    function setMaxAuctionAmount(
        uint256 _maxAuctionAmount
    ) external onlyManagement {
        require(_maxAuctionAmount > 0, "!maxAuctionAmount");
        maxAuctionAmount = _maxAuctionAmount;
    }

    /// @notice Set the maximum gas price for tending
    /// @param _maxGasPriceToTend New maximum gas price
    function setMaxGasPriceToTend(
        uint256 _maxGasPriceToTend
    ) external onlyManagement {
        require(_maxGasPriceToTend >= MIN_MAX_GAS_PRICE_TO_TEND, "!minMaxGasPrice");
        maxGasPriceToTend = _maxGasPriceToTend;
    }

    /// @notice Set the buffer percentage for the auction starting price
    /// @param _bufferPercentage New buffer percentage
    function setBufferPercentage(
        uint256 _bufferPercentage
    ) external onlyManagement {
        require(_bufferPercentage >= MIN_BUFFER_PERCENTAGE, "!minBuffer");
        bufferPercentage = _bufferPercentage;
    }

    /// @notice Set the dust threshold for the collateral token
    /// @param _dustThreshold New collateral dust threshold
    function setDustThreshold(
        uint256 _dustThreshold
    ) external onlyManagement {
        require(_dustThreshold >= MIN_DUST_THRESHOLD, "!minDust");
        dustThreshold = _dustThreshold;
    }

    /// @notice Allow a specific address to deposit
    /// @dev This is irreversible
    /// @param _address Address to allow
    function setAllowed(
        address _address
    ) external onlyManagement {
        allowed[_address] = true;
    }

    /// @notice Sweep stuck tokens
    /// @dev Cannot sweep strategy asset or collateral token
    /// @param _token Address of token to sweep
    function sweep(
        ERC20 _token
    ) external onlyManagement {
        require(_token != asset && _token != COLL, "!token");
        uint256 _balance = _token.balanceOf(address(this));
        require(_balance > 0, "!balance");
        _token.safeTransfer(TokenizedStrategy.management(), _balance);
    }

    // ===============================================================
    // Mutated functions
    // ===============================================================

    /// @notice Claim collateral and yield gains from the Stability Pool
    function claim() public {
        _freeFunds(0);
    }

    // ===============================================================
    // Internal mutated functions
    // ===============================================================

    /// @inheritdoc BaseStrategy
    function _deployFunds(
        uint256 _amount
    ) internal override {
        SP.provideToSP(_amount, false);
    }

    /// @inheritdoc BaseStrategy
    function _freeFunds(
        uint256 _amount
    ) internal override {
        SP.withdrawFromSP(_amount, true);
    }

    /// @inheritdoc BaseStrategy
    function _harvestAndReport() internal override returns (uint256 _totalAssets) {
        if (!TokenizedStrategy.isShutdown()) {
            uint256 _toClaim = SP.getDepositorYieldGain(address(this));
            if (_toClaim > ASSET_DUST_THRESHOLD) claim();

            uint256 _toDeploy = asset.balanceOf(address(this));
            if (_toDeploy > ASSET_DUST_THRESHOLD) _deployFunds(_toDeploy);
        }

        return estimatedTotalAssets();
    }

    /// @inheritdoc BaseStrategy
    function _emergencyWithdraw(
        uint256 /*_amount*/
    ) internal override {
        _freeFunds(type(uint256).max); // Stability pool scales down to actual balance for us
    }

    /// @inheritdoc BaseStrategy
    function _tend(
        uint256 /*_totalIdle*/
    ) internal override {
        if (isCollateralGainToClaim()) claim();

        if (AUCTION.isActive(address(COLL))) {
            if (AUCTION.available(address(COLL)) > 0) AUCTION.sweep(address(COLL));
            AUCTION.settle(address(COLL));
        }

        uint256 _toAuction = Math.min(COLL.balanceOf(address(this)), maxAuctionAmount);
        uint256 _available = COLL.balanceOf(address(AUCTION)) + _toAuction;
        if (_available > dustThreshold) {
            (uint256 _price, bool _isOracleDown) = COLL_PRICE_ORACLE.fetchPrice();
            uint256 _bufferPercentage = bufferPercentage;
            if (_isOracleDown || COLL_PRICE_ORACLE.priceSource() != IPriceFeed.PriceSource.primary) {
                _bufferPercentage *= ORACLE_DOWN_BUFFER_PCT_MULTIPLIER;
            }

            // slither-disable-next-line divide-before-multiply
            AUCTION.setStartingPrice(_available * _price / WAD * _bufferPercentage / WAD / WAD);
            AUCTION.setMinimumPrice(_price * minAuctionPriceBps / MAX_BPS);

            COLL.safeTransfer(address(AUCTION), _toAuction);
            AUCTION.kick(address(COLL));
        }
    }

    // ===============================================================
    // Internal view functions
    // ===============================================================

    /// @inheritdoc BaseStrategy
    function _tendTrigger() internal view override returns (bool) {
        if (TokenizedStrategy.totalAssets() == 0) return false;

        // If active auction, wait
        if (AUCTION.available(address(COLL)) > dustThreshold) return false;

        // Determine how much collateral we can kick
        uint256 _toAuction = Math.min(COLL.balanceOf(address(this)), maxAuctionAmount);
        uint256 _available = COLL.balanceOf(address(AUCTION)) + _toAuction;

        // If base fee is acceptable and there's collateral to sell, tend to minimize exchange rate exposure
        return block.basefee <= maxGasPriceToTend && (isCollateralGainToClaim() || _available > dustThreshold);
    }

}

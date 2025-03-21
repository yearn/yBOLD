// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {BaseHealthCheck, BaseStrategy, ERC20} from "@periphery/Bases/HealthCheck/BaseHealthCheck.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {IStabilityPool} from "./interfaces/IStabilityPool.sol";
import {IAuction} from "./interfaces/IAuction.sol";
import {IAuctionFactory} from "./interfaces/IAuctionFactory.sol";
import {IAddressRegistry} from "./interfaces/IAddressRegistry.sol";

contract LiquityV2SPStrategy is BaseHealthCheck {

    using SafeERC20 for ERC20;

    // ===============================================================
    // Storage
    // ===============================================================

    /// @notice Max base fee (in gwei) for a tend
    uint256 public maxGasPriceToTend;

    /// @notice Buffer percentage for the auction starting price
    uint256 public bufferPercentage;

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice WAD constant
    uint256 private constant WAD = 1e18;

    /// @notice Auction starting price buffer percentage increase when the oracle is down
    uint256 public constant ORACLE_DOWN_BUFFER_PCT_MULTIPLIER = 1000; // 1000x

    /// @notice Minimum buffer percentage for the auction starting price
    uint256 public constant MIN_BUFFER_PERCENTAGE = WAD + 1e17; // 10%

    /// @notice Any amount below this will be ignored
    uint256 public constant DUST_THRESHOLD = 10_000;

    /// @notice Collateral reward token of the Stability Pool
    ERC20 public immutable COLL;

    /// @notice Liquity's price oracle for the collateral token
    ///         Assumes the price feed is using 18 decimals
    IPriceFeed public immutable COLL_PRICE_ORACLE;

    /// @notice Stability Pool contract
    IStabilityPool public immutable SP;

    /// @notice Auction contract for selling the collateral reward token
    IAuction public immutable AUCTION;

    /// @notice Factory for creating the auction contract
    IAuctionFactory public constant AUCTION_FACTORY = IAuctionFactory(0xCfA510188884F199fcC6e750764FAAbE6e56ec40);

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _addressRegistry Address of the AddressRegistry
    /// @param _asset Address of the strategy's underlying asset
    /// @param _name Name of the strategy
    constructor(address _addressRegistry, address _asset, string memory _name) BaseHealthCheck(_asset, _name) {
        COLL_PRICE_ORACLE = IAddressRegistry(_addressRegistry).priceFeed();
        (, bool _isOracleDown) = COLL_PRICE_ORACLE.fetchPrice();
        require(!_isOracleDown, "!oracle");

        SP = IAddressRegistry(_addressRegistry).stabilityPool();
        require(SP.boldToken() == _asset, "!sp");
        COLL = ERC20(SP.collToken());

        AUCTION = AUCTION_FACTORY.createNewAuction(_asset);
        AUCTION.enable(address(COLL));

        maxGasPriceToTend = 200 * 1e9;
        bufferPercentage = MIN_BUFFER_PERCENTAGE;
    }

    // ===============================================================
    // View functions
    // ===============================================================

    /// @notice Check if there are collateral gains to claim from the Stability Pool
    /// @return True if there are collateral gains to claim
    function isCollateralGainToClaim() public view returns (bool) {
        return SP.getDepositorCollGain(address(this)) > DUST_THRESHOLD;
    }

    /// @notice Estimated total assets held by the strategy
    /// @dev Does not account for pending collateral reward value
    /// @return Estimated total assets held by the strategy
    function estimatedTotalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)) + SP.getCompoundedBoldDeposit(address(this));
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

    /// @notice Set the maximum gas price for tending
    /// @param _maxGasPriceToTend New maximum gas price
    function setMaxGasPriceToTend(
        uint256 _maxGasPriceToTend
    ) external onlyManagement {
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

    // ===============================================================
    // Keeper functions
    // ===============================================================

    /// @notice Kick an auction for the collateral token
    /// @dev Reverts on `setStartingPrice` if there's an active auction
    /// @return Available amount for bidding on in the auction
    function kickAuction() external onlyKeepers returns (uint256) {
        uint256 _toAuction = COLL.balanceOf(address(this));
        require(_toAuction > DUST_THRESHOLD, "!toAuction");

        (uint256 _price, bool _isOracleDown) = COLL_PRICE_ORACLE.fetchPrice();
        uint256 _bufferPercentage = bufferPercentage;
        if (_isOracleDown || COLL_PRICE_ORACLE.priceSource() != IPriceFeed.PriceSource.primary) {
            _bufferPercentage = _bufferPercentage * ORACLE_DOWN_BUFFER_PCT_MULTIPLIER;
        }

        uint256 _available = COLL.balanceOf(address(AUCTION)) + _toAuction;
        // slither-disable-next-line divide-before-multiply
        AUCTION.setStartingPrice(_available * _price / WAD * _bufferPercentage / WAD);

        COLL.safeTransfer(address(AUCTION), _toAuction);
        return AUCTION.kick(address(COLL));
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
        SP.provideToSP(_amount, true);
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
            uint256 _toDeploy = asset.balanceOf(address(this));
            if (_toDeploy > DUST_THRESHOLD) _deployFunds(_toDeploy);
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
        claim();
    }

    // ===============================================================
    // Internal view functions
    // ===============================================================

    /// @inheritdoc BaseStrategy
    function _tendTrigger() internal view override returns (bool) {
        if (TokenizedStrategy.totalAssets() == 0) return false;

        // Tend to minimize collateral/asset exchange rate exposure
        return block.basefee <= maxGasPriceToTend && isCollateralGainToClaim();
    }

}

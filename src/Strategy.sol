// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {BaseHealthCheck, BaseStrategy, ERC20} from "@periphery/Bases/HealthCheck/BaseHealthCheck.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStabilityPool} from "./interfaces/IStabilityPool.sol";
import {IAuction} from "./interfaces/IAuction.sol";

contract LiquityV2SPStrategy is BaseHealthCheck {

    using SafeERC20 for ERC20;

    // ===============================================================
    // Storage
    // ===============================================================

    /// @notice Max base fee (in gwei) for a tend
    uint256 public maxGasPriceToTend;

    /// @notice Auction contract for selling the collateral reward token
    IAuction public auction;

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice Any amount below this will not be deployed at a harvest
    uint256 private constant DUST_THRESHOLD = 10_000;

    /// @notice Collateral reward token of the Stability Pool
    ERC20 public immutable COLL;

    /// @notice Stability Pool contract
    IStabilityPool public immutable SP;

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _sp Address of the Stability Pool
    /// @param _asset Address of the strategy's underlying asset
    /// @param _name Name of the strategy
    constructor(address _sp, address _asset, string memory _name) BaseHealthCheck(_asset, _name) {
        SP = IStabilityPool(_sp);
        require(SP.boldToken() == _asset, "!sp");
        COLL = ERC20(SP.collToken());

        maxGasPriceToTend = 200 * 1e9;
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

    /// @notice Set the auction contract
    /// @param _auction New auction contract
    function setAuction(
        IAuction _auction
    ) external onlyManagement {
        require(_auction.receiver() == address(this), "!receiver");
        require(_auction.want() == address(asset), "!want");
        auction = _auction;
    }

    /// @notice Set the maximum gas price for tending
    /// @param _maxGasPriceToTend New maximum gas price
    function setMaxGasPriceToTend(
        uint256 _maxGasPriceToTend
    ) external onlyManagement {
        maxGasPriceToTend = _maxGasPriceToTend;
    }

    // ===============================================================
    // Keeper functions
    // ===============================================================

    /// @notice Kick an auction for the collateral token
    /// @return Available amount for bidding on in the auction
    function kickAuction() external onlyKeepers returns (uint256) {
        uint256 _toAuction = COLL.balanceOf(address(this));
        require(_toAuction > 0, "!toAuction");
        IAuction _auction = IAuction(auction);
        COLL.safeTransfer(address(_auction), _toAuction);
        return _auction.kick(address(COLL));
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

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {BaseHealthCheck, BaseStrategy, ERC20} from "@periphery/Bases/HealthCheck/BaseHealthCheck.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStabilityPool} from "./interfaces/IStabilityPool.sol";
import {IAuction} from "./interfaces/IAuction.sol";

/// @title Liquity V2 Stability Pool Compounder Strategy
/// @notice A strategy for compounding Liquity SP collateral rewards into the underlying asset
/// @dev Inherits BaseHealthCheck for vault functionality and prevention of unexpected `report` behavior
contract SPCompounderStrategy is BaseHealthCheck {
    using SafeERC20 for ERC20;

    /// The max the base fee (in gwei) will be for a tend
    uint256 public maxGasPriceToTend;

    /// @notice The auction contract for dumping the collateral token
    IAuction public auction;

    /// @notice The collateral token of the Stability Pool
    ERC20 public immutable COLL;

    /// @notice The Stability Pool contract
    IStabilityPool public immutable SP;

    /// @notice The dust threshold for the strategy. Any amount below this will be ignored
    uint256 private constant DUST_THRESHOLD = 10_000;

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
    function isCollateralGainToClaim() public view returns (bool) {
        return SP.getDepositorCollGain(address(this)) > 0;
    }

    /// @notice Estimated total assets held by the strategy
    /// @dev Does not account for pending collateral reward value
    function estimatedTotalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)) + SP.getCompoundedBoldDeposit(address(this));
    }

    /// @inheritdoc BaseStrategy
    function availableWithdrawLimit(address /*_owner*/ ) public view override returns (uint256) {
        return estimatedTotalAssets();
    }

    // ===============================================================
    // Management functions
    // ===============================================================

    /// @notice Set the auction contract
    /// @param _auction The new auction contract
    function setAuction(IAuction _auction) external onlyManagement {
        require(_auction.receiver() == address(this), "!receiver");
        require(_auction.want() == address(asset), "!want");
        auction = _auction;
    }

    /// @notice Set the maximum gas price for tending
    /// @param _maxGasPriceToTend New maximum gas price
    function setMaxGasPriceToTend(uint256 _maxGasPriceToTend) external onlyManagement {
        maxGasPriceToTend = _maxGasPriceToTend;
    }

    // ===============================================================
    // Keeper functions
    // ===============================================================

    /// @notice Kick an auction for the collateral token
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
    // Internal Mutated functions
    // ===============================================================

    /// @inheritdoc BaseStrategy
    function _deployFunds(uint256 _amount) internal override {
        SP.provideToSP(_amount, true);
    }

    /// @inheritdoc BaseStrategy
    function _freeFunds(uint256 _amount) internal override {
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
    function _emergencyWithdraw(uint256 /*_amount*/ ) internal override {
        // Pull full amount and claim collateral/yield gains. Stability pool scales down to actual balance for us
        _freeFunds(type(uint256).max);
    }

    /// @inheritdoc BaseStrategy
    function _tend(uint256 /*_totalIdle*/ ) internal override {
        claim();
    }

    // ===============================================================
    // Internal View functions
    // ===============================================================

    /// @inheritdoc BaseStrategy
    function _tendTrigger() internal view override returns (bool) {
        if (TokenizedStrategy.totalAssets() == 0) return false;

        // Tend to minimize collateral/asset exchange rate exposure
        return _isBaseFeeAcceptable() && isCollateralGainToClaim();
    }

    /// @notice Checks if base fee is acceptable
    /// @return True if base fee is below threshold
    function _isBaseFeeAcceptable() internal view returns (bool) {
        return block.basefee <= maxGasPriceToTend;
    }
}

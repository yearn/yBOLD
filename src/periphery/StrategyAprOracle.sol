// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";

import {IStrategyInterface as IStrategy} from "../interfaces/IStrategyInterface.sol";
import {IMultiTroveGetter} from "../interfaces/IMultiTroveGetter.sol";

// @todo -- ir's + debt amount == revenue to sp (+ liqs)
// average rate * debt / SP deposits
// multiTroveGetter.getMultipleSortedTroves(uint256 d, int256 _startIdx, uint256 _count)
// SP deposits == sp.getTotalBoldDeposits()
contract StrategyAprOracle is AprOracleBase {

    IMultiTroveGetter public immutable MULTI_TROVE_GETTER;

    constructor() AprOracleBase("Strategy Apr Oracle Example", msg.sender) {}

    /**
     * @notice Will return the expected Apr of a strategy post a debt change.
     * @dev _delta is a signed integer so that it can also represent a debt
     * decrease.
     *
     * This should return the annual expected return at the current timestamp
     * represented as 1e18.
     *
     *      ie. 10% == 1e17
     *
     * _delta will be == 0 to get the current apr.
     *
     * This will potentially be called during non-view functions so gas
     * efficiency should be taken into account.
     *
     * @param _strategy The token to get the apr for.
     * @param _delta The difference in debt.
     * @return . The expected apr for the strategy represented as 1e18.
     */
    function aprAfterDebtChange(address _strategy, int256 _delta) external view override returns (uint256) {
        // uint256 _collateralIndex = _getCollateralIndex(IStrategy(_strategy).COLL());
        // ITroveManager _troveManager = COLLATERAL_REGISTRY.getTroveManager(_collateralIndex).troveManager();
        // uint256 _count = _troveManager.sortedTroves().getSize();
        // IMultiTroveGetter.CombinedTroveData[] memory _troves = MULTI_TROVE_GETTER.getMultipleSortedTroves(
        //     _collateralIndex,
        //     0, // startIdx
        //     _count
        // );

        // // uint256 _stabilityPoolDeposits = _troveManager.stabilityPool().getTotalBoldDeposits();
    }

    // function _getCollateralIndex(address _collateralToken) internal view returns (uint256) {
    //     uint256 _length = COLLATERAL_REGISTRY.totalCollaterals();
    //     for (uint256 i = 0; i < _length; ++i) {
    //         if (COLLATERAL_REGISTRY.getToken(i) == _collateralToken) return i;
    //     }
    //     revert("!_collateralToken");
    // }

}

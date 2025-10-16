// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {LiquityV2SPStrategy as Strategy} from "./Strategy.sol";
import {IStrategyInterface} from "./interfaces/IStrategyInterface.sol";

contract StrategyFactory {

    event NewStrategy(address indexed strategy, address indexed asset);

    address public immutable emergencyAdmin;
    address public immutable auctionFactory;
    address public immutable management;
    address public immutable performanceFeeRecipient;
    address public immutable keeper;

    /// @notice Track the deployments. asset => stability pool => strategy
    mapping(address => mapping(address => address)) public deployments;

    constructor(
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin,
        address _auctionFactory
    ) {
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
        auctionFactory = _auctionFactory;
    }

    modifier onlyManagement() {
        require(msg.sender == management, "!management");
        _;
    }

    /**
     * @notice Deploy a new Strategy.
     * @param _addressesRegistry The address of the AddressesRegistry.
     * @param _asset The underlying asset for the strategy to use.
     * @param _oracle Address of the collateral's COLL/USD _read_ price oracle.
     * @return . The address of the new strategy.
     */
    function newStrategy(
        address _addressesRegistry,
        address _asset,
        address _oracle,
        string calldata _name
    ) external virtual onlyManagement returns (address) {
        // tokenized strategies available setters.
        IStrategyInterface _newStrategy =
            IStrategyInterface(address(new Strategy(_addressesRegistry, _asset, auctionFactory, _oracle, _name)));

        _newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);

        _newStrategy.setKeeper(keeper);

        _newStrategy.setPendingManagement(management);

        _newStrategy.setEmergencyAdmin(emergencyAdmin);

        emit NewStrategy(address(_newStrategy), _asset);

        deployments[_asset][_newStrategy.SP()] = address(_newStrategy);
        return address(_newStrategy);
    }

}

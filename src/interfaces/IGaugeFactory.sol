// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface IGaugeFactory {
    function deploy_gauge(address _receiver, uint256 _max_emissions) external returns (address);
}

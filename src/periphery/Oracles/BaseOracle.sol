// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {AggregatorV3Interface} from "../../interfaces/AggregatorV3Interface.sol";

contract BaseOracle {

    // ===============================================================
    // Storage
    // ===============================================================

    string public description;

    // ===============================================================
    // Constants
    // ===============================================================

    int256 internal constant _1E8 = 1e8;
    int256 internal constant _1E10 = 1e10;
    uint256 internal constant _48_HOURS = 172800;
    uint256 internal constant _24_HOURS = 86400;

    // ===============================================================
    // Constructor
    // ===============================================================

    constructor(
        string memory _description
    ) {
        description = _description;
    }

    // ===============================================================
    // View functions
    // ===============================================================

    function decimals() public pure virtual returns (uint8) {
        return 8;
    }

    function latestRoundData()
        external
        view
        virtual
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {}

    // ===============================================================
    // Internal functions
    // ===============================================================

    function _isStale(
        int256 answer,
        uint256 updatedAt,
        uint256 heartbeat
    ) internal view virtual returns (bool) {
        bool stale = updatedAt + heartbeat <= block.timestamp;
        return stale || answer <= 0;
    }

}

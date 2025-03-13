// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

contract AuctionMock {

    address public want;
    address public receiver;

    constructor(address _want, address _receiver) {
        want = _want;
        receiver = _receiver;
    }

    function kick(
        address
    ) external pure returns (uint256) {
        return 0;
    }

}

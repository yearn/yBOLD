// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface IWSTETH {

    function stEthPerToken() external view returns (uint256);
    function decimals() external view returns (uint8);

}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface IStabilityPool {

    function boldToken() external view returns (address);
    function collToken() external view returns (address);
    function getCompoundedBoldDeposit(
        address _depositor
    ) external view returns (uint256);
    function getDepositorCollGain(
        address _depositor
    ) external view returns (uint256);
    function provideToSP(uint256 _amount, bool _doClaim) external;
    function withdrawFromSP(uint256 _amount, bool doClaim) external;

}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Zapper {

    using SafeERC20 for IERC20;
    using SafeERC20 for IERC4626;

    // ===============================================================
    // Constants
    // ===============================================================

    IERC20 public constant BOLD = IERC20(0x6440f144b7e50D6a8439336510312d2F54beB01D);
    IERC4626 public constant YEARN_BOLD = IERC4626(0x9F4330700a36B29952869fac9b33f45EEdd8A3d8);
    IERC4626 public constant STAKED_YEARN_BOLD = IERC4626(0x23346B04a7f55b8760E5860AA5A77383D63491cD);

    // ===============================================================
    // Constructor
    // ===============================================================

    constructor() {
        BOLD.forceApprove(address(YEARN_BOLD), type(uint256).max);
        YEARN_BOLD.forceApprove(address(STAKED_YEARN_BOLD), type(uint256).max);
    }

    // ===============================================================
    // Mutated functions
    // ===============================================================

    /// @notice Zap from BOLD to st-yBOLD
    /// @param _assets The amount of BOLD to zap in
    /// @param _receiver The address to receive the st-yBOLD
    /// @return The amount of st-yBOLD received
    function zapIn(uint256 _assets, address _receiver) external returns (uint256) {
        // Pull BOLD
        BOLD.safeTransferFrom(msg.sender, address(this), _assets);

        // BOLD --> yBOLD
        uint256 _shares = YEARN_BOLD.deposit(_assets, address(this));

        // yBOLD --> st-yBOLD
        return STAKED_YEARN_BOLD.deposit(_shares, _receiver);
    }

    /// @notice Zap from st-yBOLD to BOLD
    /// @param _shares The amount of st-yBOLD to zap out
    /// @param _receiver The address to receive the BOLD
    /// @return The amount of BOLD received
    function zapOut(uint256 _shares, address _receiver) external returns (uint256) {
        // Redeem st-yBOLD to yBOLD on behalf of the caller
        _shares = STAKED_YEARN_BOLD.redeem(_shares, address(this), msg.sender);

        // Withdraw yBOLD to BOLD and send to the receiver
        return YEARN_BOLD.redeem(_shares, _receiver, address(this));
    }

}

pragma solidity ^0.8.18;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "forge-std/console2.sol";
import {ERC20, Setup} from "./utils/Setup.sol";

import {ReferralZapper} from "../periphery/ReferralZapper.sol";

contract ReferralZapperTest is Setup {

    event ReferralDeposit(
        address receiver, address indexed referrer, address indexed vault, uint256 assets, uint256 shares
    );

    ReferralZapper public zapper;

    address public constant REFERRAL_CODE = address(0x8244F0746396E06bD26F68C00E9b48b70b771472);

    function setUp() public override {
        super.setUp();

        zapper = new ReferralZapper();

        maxFuzzAmount = 1_000_000 ether;
        minFuzzAmount = 10 ether;
    }

    function _test_zapIn(
        uint256 _amount,
        address _receiver
    ) public returns (uint256 _shares) {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        vm.assume(_receiver != address(0));

        IERC4626 _staker = zapper.STAKED_YEARN_BOLD();
        vm.assume(_receiver != address(_staker) && _receiver != address(zapper.YEARN_BOLD()));

        airdrop(asset, user, _amount);

        vm.startPrank(user);

        // Approve BOLD to the zapper
        asset.approve(address(zapper), _amount);

        uint256 _expectedSharesOut = zapper.previewDeposit(_amount);

        // Expect a ReferralDeposit event from the deposit wrapper (check indexed topics only)
        vm.expectEmit(true, true, false, false, address(zapper.REFERRAL_DEPOSIT_WRAPPER()));
        emit ReferralDeposit(address(0), REFERRAL_CODE, address(_staker), 0, 0);

        // Zap in
        _shares = zapper.zapIn(_amount, _receiver, REFERRAL_CODE);

        vm.stopPrank();

        // Check balances
        assertEq(asset.balanceOf(user), 0);
        assertEq(asset.balanceOf(address(zapper)), 0);
        assertEq(_staker.balanceOf(address(zapper)), 0);
        assertEq(_shares, _expectedSharesOut);
        assertEq(_staker.balanceOf(_receiver), _shares);
    }

    function _test_zapOut(
        uint256 _amount,
        address _receiver,
        address _secondReceiver
    ) public {
        vm.assume(_secondReceiver != address(0));

        uint256 _shares = _test_zapIn(_amount, _receiver);

        vm.startPrank(_receiver);

        IERC4626 _staker = zapper.STAKED_YEARN_BOLD();

        // Approve zapper to spend st-yBOLD
        _staker.approve(address(zapper), _shares);

        uint256 _expectedAssetsOut = zapper.previewRedeem(_shares);

        // Zap out
        uint256 _assets = zapper.zapOut(_shares, _secondReceiver, 0);

        // Check balances
        assertEq(asset.balanceOf(_secondReceiver), _assets);
        assertEq(asset.balanceOf(address(zapper)), 0);
        assertEq(asset.balanceOf(_receiver), 0);
        assertEq(_staker.balanceOf(address(zapper)), 0);
        assertEq(_assets, _expectedAssetsOut);
        assertEq(_staker.balanceOf(_receiver), 0);

        vm.stopPrank();
    }

}

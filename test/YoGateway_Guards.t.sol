// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {YoGateway} from "../src/YoGateway.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockYoVault} from "../src/mocks/MockYoVault.sol";

contract YoGateway_Guards is Test {
    YoGateway gateway;
    MockERC20 asset;
    MockYoVault vault;

    address user = makeAddr("user");
    address receiver = makeAddr("receiver");

    function setUp() public {
        gateway = new YoGateway();
        asset = new MockERC20("Mock USD", "mUSD", 18);
        vault = new MockYoVault(address(asset), true); // instant redemptions

        // owner adds vault
        gateway.addVault(address(vault));

        // fund & approve user for asset deposits
        asset.mint(user, 1_000e18);
        vm.prank(user);
        asset.approve(address(gateway), type(uint256).max);
    }

    // ---- addVault ----

    function test_addVault_eoaRevertsNoCode() public {
        // address with no code must revert
        vm.expectRevert(YoGateway.NoCode.selector);
        gateway.addVault(makeAddr("eoa"));
    }

    // ---- deposit guards ----

    function test_deposit_zeroAmountReverts() public {
        vm.prank(user);
        vm.expectRevert(YoGateway.ZeroAmount.selector);
        gateway.deposit(address(vault), 0, receiver, 1);
    }

    function test_deposit_zeroReceiverReverts() public {
        vm.prank(user);
        vm.expectRevert(YoGateway.ZeroReceiver.selector);
        gateway.deposit(address(vault), 100e18, address(0), 1);
    }

    function test_deposit_nonAllowedVaultReverts() public {
        MockYoVault other = new MockYoVault(address(asset), true);
        vm.prank(user);
        vm.expectRevert(YoGateway.VaultNotAllowed.selector);
        gateway.deposit(address(other), 10e18, receiver, 1);
    }

    // ---- redeem guards ----

    function test_redeem_zeroAmountReverts() public {
        // mint shares via deposit
        vm.prank(user);
        gateway.deposit(address(vault), 100e18, user, 1);

        // approve shares to gateway for sponsored redeem
        vm.prank(user);
        MockERC20(address(vault)).approve(address(gateway), type(uint256).max);

        vm.prank(user);
        vm.expectRevert(YoGateway.ZeroAmount.selector);
        gateway.redeem(address(vault), 0, receiver, user, 1);
    }

    function test_redeem_zeroReceiverReverts() public {
        vm.prank(user);
        gateway.deposit(address(vault), 50e18, user, 1);

        vm.prank(user);
        MockERC20(address(vault)).approve(address(gateway), type(uint256).max);

        vm.prank(user);
        vm.expectRevert(YoGateway.ZeroReceiver.selector);
        gateway.redeem(address(vault), 10e18, address(0), user, 1);
    }

    // ---- happy path (instant) ----

    function test_redeem_happyPath_instant() public {
        // user deposits and receives 100 shares
        vm.prank(user);
        gateway.deposit(address(vault), 100e18, user, 1);

        // user approves gateway to pull shares
        vm.prank(user);
        MockERC20(address(vault)).approve(address(gateway), type(uint256).max);

        uint256 beforeBal = asset.balanceOf(receiver);

        // redeem 40 shares to receiver
        vm.prank(user);
        uint256 out = gateway.redeem(address(vault), 40e18, receiver, user, 1);

        assertEq(out, 40e18, "assets out");
        assertEq(asset.balanceOf(receiver), beforeBal + 40e18, "receiver got assets");
        assertEq(MockERC20(address(vault)).balanceOf(address(gateway)), 0, "gateway holds no shares");
        assertEq(MockERC20(address(vault)).balanceOf(user), 60e18, "user remaining shares");
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Vault} from "../src/vault/Vault.sol";
import {VaultStaking} from "../src/staking/VaultStaking.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract testVaultStaking is Test {
    Vault vault;
    VaultStaking vaultStaking;
    MockERC20 asset;
    MockERC20 rewardToken;
    uint256 rewardRate = 1e18;

    address constant TEST_USER = address(0x1234);

    modifier approveAndDeposit(uint256 amount) {
        vm.startPrank(TEST_USER);
        asset.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();
        _;
    }

    modifier approveAndStake(uint256 amount) {
        vm.startPrank(TEST_USER);
        vault.approve(address(vaultStaking), amount);
        vaultStaking.stake(amount);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        asset = new MockERC20("Mock USDC", "mUSDC");
        rewardToken = new MockERC20("Reward", "RWD");

        vault = new Vault(IERC20(address(asset)));

        vaultStaking = new VaultStaking(
            IERC20(address(vault)),
            IERC20(address(rewardToken)),
            1e18 // reward per second
        );

        asset.mint(TEST_USER, 10e18);
        rewardToken.mint(address(vaultStaking), 100000e18);
    }

    // ==============================================================
    // ======================== Vault Tests =========================
    // ==============================================================
    function test_vault_deposit() public approveAndDeposit(1e18) {
        assertEq(vault.balanceOf(TEST_USER), 1e18);
        assertEq(vault.totalAssets(), 1e18);
    }

    function test_vault_withdraw() public approveAndDeposit(1e18) {
        vm.startPrank(TEST_USER);
        vault.withdraw(1e18);
        vm.stopPrank();

        assertEq(vault.balanceOf(TEST_USER), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(asset.balanceOf(TEST_USER), 10e18);
    }

    function test_vault_zero_deposit() public {
        vm.startPrank(TEST_USER);
        vm.expectRevert(Vault.AmountZero.selector);
        vault.deposit(0);
        vm.stopPrank();
    }

    function test_vault_zero_withdraw() public approveAndDeposit(1e18) {
        vm.startPrank(TEST_USER);
        vm.expectRevert(Vault.AmountZero.selector);
        vault.withdraw(0);
        vm.stopPrank();
    }

    function test_vault_convertToShares_zeroTotalSupply() public view {
        uint256 shares = vault.convertToShares(1e18);
        assertEq(shares, 1e18);
    }

    function test_vault_convertToAssets_zeroTotalAssets() public {
        vm.expectRevert(Vault.NoAssetsInTheVault.selector);
        vault.convertToAssets(1e18);
    }

    // ==============================================================
    // ================ Vault Staking Tests =========================
    // ==============================================================

    function test_stake() public approveAndDeposit(1e18) {
        vm.startPrank(TEST_USER);
        vault.approve(address(vaultStaking), 1e18);
        vaultStaking.stake(1e18);
        vm.stopPrank();

        assertEq(vaultStaking.balanceOf(TEST_USER), 1e18);
        assertEq(vaultStaking.totalStaked(), 1e18);
    }

    function test_staking_withdraw() public approveAndDeposit(1e18) approveAndStake(1e18) {
        vm.startPrank(TEST_USER);
        vaultStaking.withdraw(1e18);
        vm.stopPrank();

        assertEq(vaultStaking.balanceOf(TEST_USER), 0);
        assertEq(vaultStaking.totalStaked(), 0);
        assertEq(vault.balanceOf(TEST_USER), 1e18);
    }

    function test_staking_getReward() public approveAndDeposit(1e18) approveAndStake(1e18) {
        vm.warp(block.timestamp + 1 days); //fast forward 1 day to accumulate rewards

        uint256 expected = 1 days * rewardRate;
        vm.startPrank(TEST_USER);
        vaultStaking.getReward();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(TEST_USER), expected);
    }

    function test_staking_zero_stake() public {
        vm.startPrank(TEST_USER);
        vm.expectRevert(VaultStaking.amountCannotBeZero.selector);
        vaultStaking.stake(0);
        vm.stopPrank();
    }

    function test_staking_zero_withdraw() public {
        vm.startPrank(TEST_USER);
        vm.expectRevert(VaultStaking.amountCannotBeZero.selector);
        vaultStaking.withdraw(0);
        vm.stopPrank();
    }
}

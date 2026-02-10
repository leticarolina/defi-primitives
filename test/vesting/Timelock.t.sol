//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./../mocks/MockERC20.sol";
import {Timelock} from "../../src/vesting/Timelock.sol";

contract TimelockTest is Test {
    MockERC20 token;
    Timelock timelock;
    address deployer = address(0x1);
    address beneficiary = address(0x2);
    uint256 unlockTime = block.timestamp + 1 days;
    uint256 amount = 100;

    function setUp() public {
        token = new MockERC20("Mock Token", "MTK");
        token.mint(deployer, amount * 2);

        timelock = new Timelock(token, beneficiary, amount, unlockTime);
    }

    modifier approveAndDeposit() {
        vm.startPrank(deployer);
        token.approve(address(timelock), amount);
        timelock.deposit();
        vm.stopPrank();
        _;
    }

    function test_deposit() public approveAndDeposit {
        assertEq(token.balanceOf(address(timelock)), amount);
    }

    function test_withdraw_reverts_ifNotBeneficiary() public approveAndDeposit {
        vm.expectRevert(Timelock.NotBeneficiary.selector);
        timelock.withdraw();
    }

    function test_withdraw_reverts_ifNotUnlocked() public approveAndDeposit {
        vm.prank(beneficiary);
        vm.expectRevert(Timelock.NotUnlockedYet.selector);
        timelock.withdraw();
    }

    function test_withdraw_reverts_ifAlreadyWithdrawn() public approveAndDeposit {
        vm.warp(unlockTime + 1);
        vm.prank(beneficiary);
        timelock.withdraw();

        vm.prank(beneficiary);
        vm.expectRevert(Timelock.AlreadyWithdrawn.selector);
        timelock.withdraw();
    }

    function test_withdraw_success() public approveAndDeposit {
        vm.warp(unlockTime + 1);
        uint256 beneficiaryBeforeBalance = token.balanceOf(beneficiary);
        vm.prank(beneficiary);
        timelock.withdraw();
        uint256 beneficiaryAfterBalance = token.balanceOf(beneficiary);

        assertEq(beneficiaryAfterBalance, beneficiaryBeforeBalance + amount);
        assertEq(token.balanceOf(address(timelock)), 0);
    }

    function test_constructor_setsImmutableVariables() public view {
        assertEq(address(timelock.TOKEN()), address(token));
        assertEq(timelock.BENEFICIARY(), beneficiary);
        assertEq(timelock.AMOUNT(), amount);
        assertEq(timelock.UNLOCK_TIME(), unlockTime);
    }
}

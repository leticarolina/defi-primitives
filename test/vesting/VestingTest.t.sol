//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "./../mocks/MockERC20.sol";
import {Vesting} from "../../src/vesting/Vesting.sol";

contract VestingTest is Test {
    MockERC20 token;
    Vesting vesting;
    address deployer = address(0x1);
    address beneficiary = address(0x2);
    uint256 start = block.timestamp;

    uint256 duration = 3 days;
    uint256 amount = 100;

    function setUp() public {
        token = new MockERC20("Mock Token", "MTK");
        token.mint(deployer, amount * 2);

        vesting = new Vesting(token, beneficiary, amount, start, duration);
    }

    modifier approveAndDeposit() {
        vm.startPrank(deployer);
        token.approve(address(vesting), amount);
        vesting.deposit();
        vm.stopPrank();
        _;
    }

    function test_deposit() public approveAndDeposit {
        assertEq(token.balanceOf(address(vesting)), amount);
    }

    function test_claim_reverts_ifNotBeneficiary() public approveAndDeposit {
        vm.expectRevert(Vesting.NotBeneficiary.selector);
        vesting.claim();
    }

    function test_claim_reverts_ifAlreadyClaimed() public approveAndDeposit {
        vm.warp(start + duration + 1);
        vm.prank(beneficiary);
        vesting.claim();

        vm.prank(beneficiary);
        vm.expectRevert(Vesting.NothingToClaim.selector);
        vesting.claim();
    }

    function test_claim_success() public approveAndDeposit {
        vm.warp(start + duration + 1);
        console.log("claimable amount", vesting.vestedAmount());
        uint256 beneficiaryBeforeBalance = token.balanceOf(beneficiary);
        vm.prank(beneficiary);
        vesting.claim();
        uint256 beneficiaryAfterBalance = token.balanceOf(beneficiary);

        assertEq(beneficiaryAfterBalance, beneficiaryBeforeBalance + amount);
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    function test_constructor_setsImmutableVariables() public view {
        assertEq(address(vesting.TOKEN()), address(token));
        assertEq(vesting.BENEFICIARY(), beneficiary);
        assertEq(vesting.START(), start);
        assertEq(vesting.DURATION(), duration);
    }

    function test_vestedAmount() public approveAndDeposit {
        // At the start, no tokens should be vested
        assertEq(vesting.vestedAmount(), 0);

        // After half the duration, half the tokens should be vested
        vm.warp(start + duration / 2);
        assertEq(vesting.vestedAmount(), amount / 2);

        // After the full duration, all tokens should be vested
        vm.warp(start + duration + 1);
        assertEq(vesting.vestedAmount(), amount);
    }
}

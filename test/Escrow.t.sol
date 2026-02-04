//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import {Escrow} from "../src/escrow/Escrow.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract EscrowTest is Test {
    MockERC20 token;
    Escrow escrow;
    address buyer = address(0x1);
    address seller = address(0x2);
    address arbiter = address(0x3);
    uint256 amount = 100;

    function setUp() public {
        token = new MockERC20("Mock Token", "MTK");
        token.mint(buyer, amount * 2);

        vm.prank(buyer);
        escrow = new Escrow(token, seller, amount, arbiter);
    }

    modifier approveAmount() {
        vm.prank(buyer);
        token.approve(address(escrow), amount);
        _;
    }

    modifier approveAndDeposit() {
        vm.prank(buyer);
        token.approve(address(escrow), amount);
        vm.prank(buyer);
        escrow.deposit();
        _;
    }

    ////////////////////////////////////////////////////////////////////////////////
    /////////////////////////// DEPOSITS TESTS   //////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////

    function test_deposit_records_amount() public approveAmount {
        uint256 buyerBeforeBalance = token.balanceOf(buyer);
        vm.prank(buyer);
        escrow.deposit();
        uint256 buyerAfterBalance = token.balanceOf(buyer);
        assertEq(token.balanceOf(address(escrow)), amount);
        assertEq(buyerAfterBalance, buyerBeforeBalance - amount);
        assertEq(escrow.deposited(), true);
    }

    function test_deposit_reverts_doubleDeposit() public approveAndDeposit {
        vm.prank(buyer);
        vm.expectRevert(Escrow.AlreadyDeposited.selector);
        escrow.deposit();
    }

    function test_deposit_reverts_notApproved() public {
        vm.expectRevert(Escrow.NotAuthorized.selector);
        escrow.deposit();
    }

    ////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////   CANCEL TESTS   /////////////////////////
    ////////////////////////////////////////////////////////////////////////////////

    function test_cancel_byBuyer() public approveAndDeposit {
        uint256 buyerBeforeBalance = token.balanceOf(buyer);
        vm.warp(block.timestamp + 7 days);

        vm.prank(buyer);
        // vm.expectEmit(true, false, false, true);
        escrow.cancel();
        // emit Escrow.EscrowFinalized(false);

        uint256 buyerAfterBalance = token.balanceOf(buyer);
        assertEq(token.balanceOf(address(escrow)), 0);
        assertEq(buyerAfterBalance, buyerBeforeBalance + amount);
        assertEq(escrow.canceled(), true);
    }

    function test_cancel_byArbiter() public approveAndDeposit {
        uint256 buyerBeforeBalance = token.balanceOf(buyer);
        vm.warp(block.timestamp + 7 days);

        vm.prank(arbiter);
        escrow.cancel();
        uint256 buyerAfterBalance = token.balanceOf(buyer);
        assertEq(token.balanceOf(address(escrow)), 0);
        assertEq(buyerAfterBalance, buyerBeforeBalance + amount);
        assertEq(escrow.canceled(), true);
    }

    function test_cancel_reverts_beforeDeadline() public approveAndDeposit {
        vm.prank(buyer);
        vm.expectRevert(Escrow.DeadlineNotReached.selector);
        escrow.cancel();
    }

    function test_cancel_reverts_notAuthorized() public approveAndDeposit {
        vm.prank(seller);
        vm.expectRevert(Escrow.NotAuthorized.selector);
        escrow.cancel();
    }

    function test_cancel_reverts_ifFinalized() public approveAndDeposit {
        vm.warp(block.timestamp + 7 days);
        vm.prank(buyer);
        escrow.cancel();

        assertEq(escrow.canceled(), true);
        vm.prank(buyer);
        vm.expectRevert(Escrow.ContractIsFinalized.selector);
        escrow.cancel();
    }

    ////////////////////////////////////////////////////////////////////////////////
    ////////////////////   RELEASE TESTS   ////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////

    function test_release_byBuyer() public approveAndDeposit {
        uint256 sellerBeforeBalance = token.balanceOf(seller);

        vm.prank(buyer);
        escrow.release();

        uint256 sellerAfterBalance = token.balanceOf(seller);
        assertEq(token.balanceOf(address(escrow)), 0);
        assertEq(sellerAfterBalance, sellerBeforeBalance + amount);
        assertEq(escrow.released(), true);
    }

    function test_release_byArbiter() public approveAndDeposit {
        uint256 sellerBeforeBalance = token.balanceOf(seller);

        vm.prank(arbiter);
        escrow.release();

        uint256 sellerAfterBalance = token.balanceOf(seller);
        assertEq(token.balanceOf(address(escrow)), 0);
        assertEq(sellerAfterBalance, sellerBeforeBalance + amount);
        assertEq(escrow.released(), true);
    }

    function test_release_reverts_notAuthorized() public approveAndDeposit {
        vm.prank(seller);
        vm.expectRevert(Escrow.NotAuthorized.selector);
        escrow.release();
    }

    function test_release_reverts_ifFinalized() public approveAndDeposit {
        vm.prank(buyer);
        escrow.release();

        assertEq(escrow.released(), true);
        vm.prank(buyer);
        vm.expectRevert(Escrow.ContractIsFinalized.selector);
        escrow.release();
    }

    function test_release_reverts_ifPartialAmount() public approveAndDeposit {
        vm.startPrank(buyer);
        escrow.releasePartialAmount(amount - 10, seller);
        vm.expectRevert(Escrow.ReleasePartialAmount.selector);
        escrow.release();
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////////////////////////
    ////////////////////   RELEASE PARTIAL AMOUNT TESTS   /////////////////////////
    ////////////////////////////////////////////////////////////////////////////////

    function test_releasePartialAmount_toSeller() public approveAndDeposit {
        uint256 partialAmount = 60;
        uint256 sellerBeforeBalance = token.balanceOf(seller);

        vm.prank(buyer);
        escrow.releasePartialAmount(partialAmount, seller);

        uint256 sellerAfterBalance = token.balanceOf(seller);
        assertEq(sellerAfterBalance, sellerBeforeBalance + partialAmount);
        assertEq(escrow.releasedAmount(), partialAmount);
        assertEq(escrow.released(), false);
    }

    function test_releasePartialAmount_toBuyer() public approveAndDeposit {
        uint256 partialAmount = 40;
        uint256 buyerBeforeBalance = token.balanceOf(buyer);

        vm.prank(buyer);
        escrow.releasePartialAmount(partialAmount, buyer);

        uint256 buyerAfterBalance = token.balanceOf(buyer);
        assertEq(buyerAfterBalance, buyerBeforeBalance + partialAmount);
        assertEq(escrow.releasedAmount(), partialAmount);
        assertEq(escrow.released(), false);
    }

    function test_releasePartialAmount_reverts_ifFinalized() public approveAndDeposit {
        vm.startPrank(buyer);
        escrow.release();
        vm.expectRevert(Escrow.ContractIsFinalized.selector);
        escrow.releasePartialAmount(10, seller);
        vm.stopPrank();
    }

    function test_releasePartialAmount_reverts_ifNotAuthorized() public approveAndDeposit {
        vm.expectRevert(Escrow.NotAuthorized.selector);
        escrow.releasePartialAmount(10, seller);
    }

    function test_releasePartialAmount_reverts_ifNotAllowedReceiver() public approveAndDeposit {
        vm.prank(buyer);
        vm.expectRevert(Escrow.NotAllowedReceiver.selector);
        escrow.releasePartialAmount(10, address(0x4));
    }

    function test_releasePartialAmount_reverts_ifAmountExceeded() public approveAndDeposit {
        vm.startPrank(buyer);
        escrow.releasePartialAmount(amount / 2, seller);
        assertEq(escrow.releasedAmount(), amount / 2);

        vm.expectRevert(abi.encodeWithSelector(Escrow.AmountExceeded.selector, amount / 2));
        escrow.releasePartialAmount((amount / 2) + 1, seller);
        vm.stopPrank();
    }

    function test_releasePartialAmount_finalizesOnFullRelease() public approveAndDeposit {
        vm.startPrank(buyer);
        escrow.releasePartialAmount(amount / 2, seller);
        assertEq(escrow.releasedAmount(), amount / 2);

        vm.expectEmit(true, false, false, true);
        emit Escrow.EscrowFinalized(true);
        escrow.releasePartialAmount(amount / 2, seller);
        vm.stopPrank();

        assertEq(escrow.releasedAmount(), amount);
        assertEq(escrow.released(), true);
    }
}

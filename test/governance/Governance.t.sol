// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Governance} from "../../src/governance/Governance.sol";
import {FeeController} from "../../src/governance/FeeController.sol";
import {MockERC20Votes} from "../mocks/MockERC20Votes.sol";

contract GovernanceFlowTest is Test {
    Governance governance;
    FeeController feeController;
    MockERC20Votes token;

    address alice = address(0x01);
    address bob = address(0x02);

    function setUp() public {
        token = new MockERC20Votes();
        governance = new Governance(address(token));
        feeController = new FeeController(address(governance));

        // Mint voting power
        token.mint(alice, 1_000 ether);
        token.mint(bob, 1_000 ether);

        // Self delegate (required for ERC20Votes)
        vm.prank(alice);
        token.delegate(alice);

        vm.prank(bob);
        token.delegate(bob);

        // Move block forward so checkpoints exist
        vm.roll(block.number + 1);
    }

    function test_fullGovernanceFlow_changesFee() public {
        // Encode proposal action: set fee to 50
        bytes memory callData = abi.encodeWithSignature("setFee(uint256)", 50);

        // Alice creates proposal
        vm.prank(alice);
        uint256 proposalId = governance.createProposal(address(feeController), callData);
        vm.warp(block.timestamp + 2);
        // Both vote YES
        vm.prank(alice);
        governance.vote(proposalId, true);

        vm.prank(bob);
        governance.vote(proposalId, true);

        // Move time past voting period
        vm.warp(block.timestamp + 4 days);

        // Queue proposal
        governance.queue(proposalId);

        // Move past timelock
        vm.warp(block.timestamp + 2 days);

        // Execute
        governance.execute(proposalId);

        // Fee should now be updated
        assertEq(feeController.fee(), 50);
    }
}

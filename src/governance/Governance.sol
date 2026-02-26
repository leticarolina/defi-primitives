// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVotes} from "../../lib/openzeppelin-contracts/contracts/governance/utils/Ivotes.sol";

contract Governance {
    error NotProposer();
    error AlreadyQueued();
    error AlreadyExecuted();

    IVotes public governanceToken;

    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant TIMELOCK_DELAY = 1 days;
    uint256 public constant QUORUM_PERCENT = 4; // 4%
    uint256 public constant PROPOSAL_THRESHOLD_PERCENT = 1; // 1% of supply

    uint256 public proposalCount;

    //for the proposal state
    enum ProposalState {
        Created,
        Active,
        Failed,
        Succeeded,
        Queued,
        Executed
    }

    struct Proposal {
        address proposer;
        address target;
        bytes callData;
        uint256 snapshotBlock;
        uint256 voteStart;
        uint256 voteEnd;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 queuedAt;
        bool executed;
        bool cancelled;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    constructor(address _token) {
        governanceToken = IVotes(_token);
    }

    /* ------------------------------------------------------------ */
    /*                      PROPOSAL CREATION/CANCELLATION                       */
    /* ------------------------------------------------------------ */

    function createProposal(address target, bytes calldata callData) external returns (uint256 proposalId) {
        proposalId = ++proposalCount;

        Proposal storage p = proposals[proposalId];
        p.snapshotBlock = block.number - 1;
        uint256 proposerPower = governanceToken.getPastVotes(msg.sender, p.snapshotBlock);

        require(proposerPower >= _proposalThreshold(p.snapshotBlock), "Below proposal threshold");

        p.proposer = msg.sender;
        p.target = target;
        p.callData = callData;
        p.voteStart = block.timestamp + 1;
        p.voteEnd = block.timestamp + VOTING_PERIOD;
    }

    function cancelProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        if (p.proposer != msg.sender) {
            revert NotProposer();
        }

        if (p.queuedAt != 0) {
            revert AlreadyQueued();
        }
        if (p.executed) {
            revert AlreadyExecuted();
        }

        p.cancelled = true;
    }

    /* ------------------------------------------------------------ */
    /*                           VOTING                             */
    /* ------------------------------------------------------------ */

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];

        require(block.timestamp >= p.voteStart, "Voting not started");
        require(block.timestamp <= p.voteEnd, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 votingPower = governanceToken.getPastVotes(msg.sender, p.snapshotBlock);

        require(votingPower > 0, "No voting power");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            p.yesVotes += votingPower;
        } else {
            p.noVotes += votingPower;
        }
    }

    /* ------------------------------------------------------------ */
    /*                     QUEUE & EXECUTION                        */
    /* ------------------------------------------------------------ */

    function queue(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        uint256 totalVotes = p.yesVotes + p.noVotes;
        uint256 quorum = (governanceToken.getPastTotalSupply(p.snapshotBlock) * QUORUM_PERCENT) / 100;

        require(totalVotes >= quorum, "Quorum not reached");

        require(block.timestamp > p.voteEnd, "Voting not finished");
        require(_quorumReached(p), "Quorum not reached");
        require(p.yesVotes > p.noVotes, "Majority not reached");

        require(p.queuedAt == 0, "Already queued");

        p.queuedAt = block.timestamp;
    }

    function execute(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];

        require(p.queuedAt != 0, "Not queued");
        require(!p.executed, "Already executed");
        require(block.timestamp >= p.queuedAt + TIMELOCK_DELAY, "Timelock not passed");

        p.executed = true;

        (bool ok,) = p.target.call(p.callData);
        require(ok, "Execution failed");
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage p = proposals[proposalId];

        if (p.cancelled) {
            return ProposalState.Failed;
        }

        if (p.executed) {
            return ProposalState.Executed;
        }

        if (p.queuedAt != 0) {
            return ProposalState.Queued;
        }

        if (block.timestamp <= p.voteStart) {
            return ProposalState.Created;
        }

        if (block.timestamp <= p.voteEnd) {
            return ProposalState.Active;
        }

        if (!_quorumReached(p) || p.yesVotes <= p.noVotes) {
            return ProposalState.Failed;
        }

        return ProposalState.Succeeded;
    }

    function _quorumReached(Proposal storage p) internal view returns (bool) {
        uint256 totalVotes = p.yesVotes + p.noVotes;

        uint256 snapshotSupply = governanceToken.getPastTotalSupply(p.snapshotBlock);

        uint256 required = (snapshotSupply * QUORUM_PERCENT) / 100;

        return totalVotes >= required;
    }

    function _proposalThreshold(uint256 snapshotBlock) internal view returns (uint256) {
        uint256 supply = governanceToken.getPastTotalSupply(snapshotBlock);

        return (supply * PROPOSAL_THRESHOLD_PERCENT) / 100;
    }
}

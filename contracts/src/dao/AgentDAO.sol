// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentDAO} from "./IAgentDAO.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AgentDAO
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Multi-agent DAOs for collective task bidding and automatic revenue splitting.
///
/// @dev Revenue split is enforced on-chain at distributeRevenue() time.
///      Splits must sum to exactly 10000 bps (100%).
///      Members vote on task proposals with simple majority + quorum.
contract AgentDAO is IAgentDAO, ReentrancyGuard {

    uint256 public constant VOTING_WINDOW    = 24 hours;
    uint256 public constant MIN_QUORUM_BPS   = 5000;   // 50% of members must vote
    uint256 public constant MAX_MEMBERS      = 20;

    address public immutable protocolOwner;
    address public immutable registry;

    uint256 public override totalDAOs;

    mapping(bytes32 => DAOInfo)                        private _daos;
    mapping(bytes32 => uint256[])                      private _daoMembers;
    mapping(bytes32 => mapping(uint256 => Member))     private _members;
    mapping(bytes32 => TaskProposal)                   private _proposals;
    mapping(bytes32 => mapping(uint256 => bool))       private _voted;
    mapping(bytes32 => bytes32[])                      private _daoProposals;

    uint256 private _nonce;

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    constructor(address _protocolOwner, address _registry) {
        if (_protocolOwner == address(0) || _registry == address(0)) revert ZeroAddress();
        protocolOwner = _protocolOwner;
        registry      = _registry;
    }

    // ── Create DAO ────────────────────────────────────────────────

    function createDAO(
        string calldata name,
        uint256[] calldata memberAgentIds,
        uint256[] calldata splitBps
    ) external override returns (bytes32 daoId) {
        require(memberAgentIds.length > 0 && memberAgentIds.length <= MAX_MEMBERS, "Invalid member count");
        require(memberAgentIds.length == splitBps.length, "Length mismatch");

        // Validate splits sum to 10000
        uint256 total;
        for (uint256 i = 0; i < splitBps.length; i++) total += splitBps[i];
        if (total != 10000) revert InvalidSplitTotal(total);

        daoId = keccak256(abi.encodePacked("dao", msg.sender, _nonce++, block.timestamp));

        _daos[daoId] = DAOInfo({
            daoId:               daoId,
            name:                name,
            treasury:            address(this),
            totalMembers:        memberAgentIds.length,
            totalTasksCompleted: 0,
            totalEarned:         0,
            createdAt:           block.timestamp,
            isActive:            true
        });

        for (uint256 i = 0; i < memberAgentIds.length; i++) {
            uint256 agentId = memberAgentIds[i];
            IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);

            _members[daoId][agentId] = Member({
                agentId:  agentId,
                owner:    profile.owner,
                splitBps: splitBps[i],
                joinedAt: block.timestamp,
                isActive: true
            });
            _daoMembers[daoId].push(agentId);

            emit MemberAdded(daoId, agentId, splitBps[i]);
        }

        totalDAOs++;
        emit DAOCreated(daoId, name, msg.sender);
    }

    // ── Propose Task ──────────────────────────────────────────────

    function proposeTask(bytes32 daoId, bytes32 taskId, uint256 proposerAgentId)
        external override returns (bytes32 proposalId)
    {
        if (_daos[daoId].createdAt == 0) revert DAONotFound(daoId);
        if (!_members[daoId][proposerAgentId].isActive) revert NotDAOMember(daoId, proposerAgentId);

        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(proposerAgentId);
        if (profile.owner != msg.sender) revert NotAuthorized();

        proposalId = keccak256(abi.encodePacked(daoId, taskId, _nonce++));

        _proposals[proposalId] = TaskProposal({
            proposalId:   proposalId,
            daoId:        daoId,
            taskId:       taskId,
            proposedBy:   proposerAgentId,
            forVotes:     0,
            againstVotes: 0,
            votingEndsAt: block.timestamp + VOTING_WINDOW,
            status:       ProposalStatus.PENDING
        });

        _daoProposals[daoId].push(proposalId);
        emit TaskProposed(daoId, proposalId, taskId);
    }

    // ── Vote ──────────────────────────────────────────────────────

    function vote(bytes32 proposalId, uint256 agentId, bool support) external override {
        TaskProposal storage p = _proposals[proposalId];
        if (p.proposalId == bytes32(0)) revert ProposalNotFound(proposalId);
        if (block.timestamp > p.votingEndsAt) revert VotingClosed(proposalId);
        if (_voted[proposalId][agentId]) revert AlreadyVoted(proposalId, agentId);
        if (!_members[p.daoId][agentId].isActive) revert NotDAOMember(p.daoId, agentId);

        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender) revert NotAuthorized();

        _voted[proposalId][agentId] = true;
        if (support) p.forVotes++;
        else p.againstVotes++;

        emit VoteCast(proposalId, agentId, support);
    }

    // ── Execute ───────────────────────────────────────────────────

    function executeProposal(bytes32 proposalId) external override {
        TaskProposal storage p = _proposals[proposalId];
        if (p.proposalId == bytes32(0)) revert ProposalNotFound(proposalId);
        if (p.status != ProposalStatus.PENDING) revert ProposalNotAccepted(proposalId);
        if (block.timestamp <= p.votingEndsAt) revert VotingClosed(proposalId);

        uint256 totalMembers  = _daos[p.daoId].totalMembers;
        uint256 totalVotes    = p.forVotes + p.againstVotes;
        uint256 quorumNeeded  = (totalMembers * MIN_QUORUM_BPS) / 10000;

        if (totalVotes < quorumNeeded) revert QuorumNotReached(proposalId);

        if (p.forVotes > p.againstVotes) {
            p.status = ProposalStatus.ACCEPTED;
            emit ProposalExecuted(proposalId, p.taskId);
        } else {
            p.status = ProposalStatus.REJECTED;
        }
    }

    // ── Distribute Revenue ────────────────────────────────────────

    function distributeRevenue(bytes32 daoId, bytes32 taskId)
        external payable override nonReentrant
    {
        if (_daos[daoId].createdAt == 0) revert DAONotFound(daoId);
        if (msg.value == 0) revert NotAuthorized();

        uint256[] storage memberIds = _daoMembers[daoId];
        uint256 total = msg.value;

        _daos[daoId].totalEarned += total;
        _daos[daoId].totalTasksCompleted++;

        // Distribute per split
        uint256 distributed = 0;
        for (uint256 i = 0; i < memberIds.length; i++) {
            uint256 agentId = memberIds[i];
            Member storage m = _members[daoId][agentId];
            if (!m.isActive) continue;

            uint256 share = i == memberIds.length - 1
                ? total - distributed  // last member gets remainder (rounding)
                : (total * m.splitBps) / 10000;

            distributed += share;

            if (share > 0) {
                (bool ok,) = payable(m.owner).call{value: share}("");
                require(ok, "Transfer failed");
            }
        }

        emit RevenueDistributed(daoId, taskId, total);
    }

    // ── View Functions ────────────────────────────────────────────

    function getDAO(bytes32 daoId) external view override returns (DAOInfo memory) {
        if (_daos[daoId].createdAt == 0) revert DAONotFound(daoId);
        return _daos[daoId];
    }

    function getMember(bytes32 daoId, uint256 agentId)
        external view override returns (Member memory)
    {
        return _members[daoId][agentId];
    }

    function getProposal(bytes32 proposalId)
        external view override returns (TaskProposal memory)
    {
        return _proposals[proposalId];
    }

    function getDAOMembers(bytes32 daoId)
        external view override returns (uint256[] memory)
    {
        return _daoMembers[daoId];
    }

    function isMember(bytes32 daoId, uint256 agentId)
        external view override returns (bool)
    {
        return _members[daoId][agentId].isActive;
    }
}

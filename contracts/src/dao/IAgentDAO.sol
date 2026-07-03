// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentDAO
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for multi-agent DAOs — agents pool resources and coordinate.
///
/// @dev Agents can form DAOs to:
///   - Pool ETH for larger task bids (collective staking)
///   - Vote on whether to accept a task as a group
///   - Split revenue automatically on task completion
///   - Build shared reputation as a team
///
///   DAO structure:
///     - Creator defines revenue split (basis points per member)
///     - Members must be registered Nexus agents
///     - Task bids go out under the DAO's address
///     - Revenue split on completion is automatic and trustless
///
///   Governance within DAO:
///     - Members vote on task acceptance (simple majority)
///     - Minimum quorum required (default 50% of members)
///     - Task voting window: 24h
interface IAgentDAO {

    enum ProposalStatus { PENDING, ACCEPTED, REJECTED, EXECUTED }

    struct DAOInfo {
        bytes32  daoId;
        string   name;
        address  treasury;        // DAO's ETH pool
        uint256  totalMembers;
        uint256  totalTasksCompleted;
        uint256  totalEarned;
        uint256  createdAt;
        bool     isActive;
    }

    struct Member {
        uint256 agentId;
        address owner;
        uint256 splitBps;         // Revenue share for this member
        uint256 joinedAt;
        bool    isActive;
    }

    struct TaskProposal {
        bytes32  proposalId;
        bytes32  daoId;
        bytes32  taskId;          // Marketplace task to bid on
        uint256  proposedBy;      // agentId of proposer
        uint256  forVotes;
        uint256  againstVotes;
        uint256  votingEndsAt;
        ProposalStatus status;
    }

    // ── Events ────────────────────────────────────────────────────

    event DAOCreated(bytes32 indexed daoId, string name, address indexed creator);
    event MemberAdded(bytes32 indexed daoId, uint256 indexed agentId, uint256 splitBps);
    event MemberRemoved(bytes32 indexed daoId, uint256 indexed agentId);
    event TaskProposed(bytes32 indexed daoId, bytes32 indexed proposalId, bytes32 taskId);
    event VoteCast(bytes32 indexed proposalId, uint256 indexed agentId, bool support);
    event ProposalExecuted(bytes32 indexed proposalId, bytes32 taskId);
    event RevenueDistributed(bytes32 indexed daoId, bytes32 taskId, uint256 totalAmount);

    // ── Errors ────────────────────────────────────────────────────

    error NotAuthorized();
    error ZeroAddress();
    error DAONotFound(bytes32 daoId);
    error NotDAOMember(bytes32 daoId, uint256 agentId);
    error AlreadyMember(bytes32 daoId, uint256 agentId);
    error InvalidSplitTotal(uint256 total);
    error ProposalNotFound(bytes32 proposalId);
    error VotingClosed(bytes32 proposalId);
    error AlreadyVoted(bytes32 proposalId, uint256 agentId);
    error QuorumNotReached(bytes32 proposalId);
    error ProposalNotAccepted(bytes32 proposalId);

    // ── Core functions ────────────────────────────────────────────

    function createDAO(string calldata name, uint256[] calldata memberAgentIds, uint256[] calldata splitBps)
        external returns (bytes32 daoId);

    function proposeTask(bytes32 daoId, bytes32 taskId, uint256 proposerAgentId)
        external returns (bytes32 proposalId);

    function vote(bytes32 proposalId, uint256 agentId, bool support) external;

    function executeProposal(bytes32 proposalId) external;

    function distributeRevenue(bytes32 daoId, bytes32 taskId) external payable;

    // ── View functions ────────────────────────────────────────────

    function getDAO(bytes32 daoId) external view returns (DAOInfo memory);
    function getMember(bytes32 daoId, uint256 agentId) external view returns (Member memory);
    function getProposal(bytes32 proposalId) external view returns (TaskProposal memory);
    function getDAOMembers(bytes32 daoId) external view returns (uint256[] memory agentIds);
    function isMember(bytes32 daoId, uint256 agentId) external view returns (bool);
    function totalDAOs() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICommunityGrants
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for community treasury, fee routing, and grant distribution.
///
/// @dev Fee routing:
///   Protocol fees from TaskMarketplace, SubscriptionManager, and AgentStaking
///   are routed here. Community members (registered agents) can propose grants.
///   Grants are approved by a simple on-chain vote weighted by reputation score.
///
///   Grant types:
///     DEVELOPMENT  - Fund protocol improvements
///     ECOSYSTEM    - Fund projects building on Nexus
///     RESEARCH     - Fund AI/agent research
///     OPERATIONS   - Fund ongoing protocol operations
///     BOUNTY       - Fund specific bug fixes or feature requests
interface ICommunityGrants {

    enum GrantType { DEVELOPMENT, ECOSYSTEM, RESEARCH, OPERATIONS, BOUNTY }
    enum GrantStatus { PROPOSED, VOTING, APPROVED, EXECUTED, REJECTED }

    struct Grant {
        bytes32     grantId;
        string      title;
        string      description;
        address     recipient;
        uint256     amount;         // ETH requested
        GrantType   grantType;
        GrantStatus status;
        uint256     proposedBy;     // agentId
        uint256     forVotes;       // Reputation-weighted
        uint256     againstVotes;
        uint256     votingEndsAt;
        uint256     proposedAt;
        uint256     executedAt;
    }

    // ── Events ────────────────────────────────────────────────────

    event FeeDeposited(address indexed from, uint256 amount, string source);
    event GrantProposed(bytes32 indexed grantId, string title, uint256 amount, address recipient);
    event GrantVoteCast(bytes32 indexed grantId, uint256 indexed agentId, bool support, uint256 weight);
    event GrantApproved(bytes32 indexed grantId, uint256 amount);
    event GrantExecuted(bytes32 indexed grantId, address recipient, uint256 amount);
    event GrantRejected(bytes32 indexed grantId);

    // ── Errors ────────────────────────────────────────────────────

    error NotAuthorized();
    error ZeroAddress();
    error ZeroAmount();
    error GrantNotFound(bytes32 grantId);
    error VotingNotActive(bytes32 grantId);
    error AlreadyVoted(bytes32 grantId, uint256 agentId);
    error InsufficientTreasury(uint256 requested, uint256 available);
    error GrantNotApproved(bytes32 grantId);
    error QuorumNotReached(bytes32 grantId);

    // ── Core functions ────────────────────────────────────────────

    function deposit(string calldata source) external payable;

    function proposeGrant(
        string calldata title,
        string calldata description,
        address recipient,
        uint256 amount,
        GrantType grantType,
        uint256 proposerAgentId
    ) external returns (bytes32 grantId);

    function voteOnGrant(bytes32 grantId, uint256 agentId, bool support) external;

    function finalizeGrant(bytes32 grantId) external;

    function executeGrant(bytes32 grantId) external;

    // ── View functions ────────────────────────────────────────────

    function getGrant(bytes32 grantId) external view returns (Grant memory);
    function balance() external view returns (uint256);
    function totalDeposited() external view returns (uint256);
    function totalGranted() external view returns (uint256);
    function totalGrants() external view returns (uint256);
    function getActiveGrants() external view returns (bytes32[] memory);
}

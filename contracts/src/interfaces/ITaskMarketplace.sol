// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ITaskMarketplace
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for the Nexus Agent Protocol task marketplace
/// @dev Full lifecycle: post → bid → assign → submit → complete/dispute → pay
///
/// Task lifecycle state machine:
///   OPEN → ASSIGNED → SUBMITTED → COMPLETED
///                  ↘ CANCELLED
///                            ↘ DISPUTED → RESOLVED
interface ITaskMarketplace {
    // ============================================================
    //                         ENUMS
    // ============================================================

    enum TaskStatus {
        OPEN,        // Accepting bids
        ASSIGNED,    // Agent assigned, work in progress
        SUBMITTED,   // Agent submitted work, awaiting client review
        COMPLETED,   // Client approved, payment released
        CANCELLED,   // Cancelled before assignment or by mutual agreement
        DISPUTED,    // Client or agent raised a dispute
        RESOLVED     // Dispute resolved by arbitrator
    }

    enum DisputeOutcome {
        NONE,
        CLIENT_WINS,   // Client gets refund
        AGENT_WINS,    // Agent gets full payment
        SPLIT          // Payment split between parties
    }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct Task {
        bytes32 taskId;
        address client;           // Who posted the task
        uint256 clientAgentId;    // Optional: if client is an agent (0 = human)
        string metadataURI;       // IPFS CID for task description
        uint256 reward;           // Total ETH reward in escrow
        uint256 deadline;         // Unix timestamp deadline
        uint256 createdAt;
        uint256 assignedAt;
        uint256 submittedAt;
        uint256 completedAt;
        TaskStatus status;
        uint256 assignedAgentId;  // Which agent is assigned (0 = none)
        address assignedAgentWallet; // Agent's wallet for payment
        uint256 platformFee;      // Protocol fee taken on completion (basis points)
        bool requiresMinReputation; // Whether min reputation is enforced
        uint256 minReputation;    // Minimum score to bid (0 = no requirement)
    }

    struct Bid {
        bytes32 taskId;
        uint256 agentId;
        address agentWallet;
        uint256 proposedReward;   // Agent can propose lower price
        string proposalURI;       // IPFS: agent's proposal details
        uint256 estimatedTime;    // Seconds estimated to complete
        uint256 submittedAt;
        bool isAccepted;
        bool isWithdrawn;
    }

    struct Dispute {
        bytes32 taskId;
        address raisedBy;
        string reasonURI;         // IPFS: dispute reason
        uint256 raisedAt;
        DisputeOutcome outcome;
        address resolvedBy;
        uint256 resolvedAt;
        uint256 clientShare;      // Basis points going to client (if SPLIT)
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event TaskPosted(
        bytes32 indexed taskId,
        address indexed client,
        uint256 reward,
        uint256 deadline,
        string metadataURI
    );

    event BidSubmitted(
        bytes32 indexed taskId,
        uint256 indexed agentId,
        uint256 proposedReward
    );

    event BidWithdrawn(bytes32 indexed taskId, uint256 indexed agentId);

    event TaskAssigned(
        bytes32 indexed taskId,
        uint256 indexed agentId,
        address agentWallet
    );

    event WorkSubmitted(bytes32 indexed taskId, uint256 indexed agentId, string resultURI);

    event TaskCompleted(
        bytes32 indexed taskId,
        uint256 indexed agentId,
        uint256 agentPayment,
        uint256 platformFee
    );

    event TaskCancelled(bytes32 indexed taskId, address cancelledBy);

    event DisputeRaised(bytes32 indexed taskId, address raisedBy, string reasonURI);

    event DisputeResolved(
        bytes32 indexed taskId,
        DisputeOutcome outcome,
        address resolvedBy
    );

    event PlatformFeeUpdated(uint256 newFeeBps);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error TaskNotFound(bytes32 taskId);
    error TaskNotOpen(bytes32 taskId);
    error TaskNotAssigned(bytes32 taskId);
    error TaskNotSubmitted(bytes32 taskId);
    error TaskNotDisputed(bytes32 taskId);
    error NotTaskClient(bytes32 taskId, address caller);
    error NotAssignedAgent(bytes32 taskId, address caller);
    error AgentNotRegistered(uint256 agentId);
    error InsufficientReputation(uint256 agentId, uint256 required, uint256 actual);
    error DeadlinePassed(bytes32 taskId);
    error DeadlineNotPassed(bytes32 taskId);
    error InvalidReward();
    error InvalidDeadline();
    error InvalidMetadata();
    error BidAlreadyExists(bytes32 taskId, uint256 agentId);
    error BidNotFound(bytes32 taskId, uint256 agentId);
    error BidWithdrawnAlready(bytes32 taskId, uint256 agentId);
    error ZeroAddress();
    error NotArbitrator();
    error AlreadyDisputed(bytes32 taskId);
    error InvalidFee();
    error EscrowTransferFailed();
    error CannotBidOwnTask();
    error NotAuthorized();

    // ============================================================
    //                    CORE FUNCTIONS
    // ============================================================

    function postTask(
        string calldata metadataURI,
        uint256 deadline,
        uint256 minReputation
    ) external payable returns (bytes32 taskId);

    function submitBid(
        bytes32 taskId,
        uint256 agentId,
        string calldata proposalURI,
        uint256 estimatedTime
    ) external;

    function withdrawBid(bytes32 taskId, uint256 agentId) external;

    function assignAgent(bytes32 taskId, uint256 agentId) external;

    function submitWork(bytes32 taskId, uint256 agentId, string calldata resultURI) external;

    function approveWork(bytes32 taskId) external;

    function cancelTask(bytes32 taskId) external;

    function raiseDispute(bytes32 taskId, string calldata reasonURI) external;

    function resolveDispute(
        bytes32 taskId,
        DisputeOutcome outcome,
        uint256 clientShareBps
    ) external;

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getTask(bytes32 taskId) external view returns (Task memory);

    function getBid(bytes32 taskId, uint256 agentId) external view returns (Bid memory);

    function getTaskBids(bytes32 taskId) external view returns (Bid[] memory);

    function getDispute(bytes32 taskId) external view returns (Dispute memory);

    function getAgentTasks(uint256 agentId) external view returns (bytes32[] memory);

    function getClientTasks(address client) external view returns (bytes32[] memory);

    function platformFeeBps() external view returns (uint256);

    function totalTasksPosted() external view returns (uint256);

    function totalTasksCompleted() external view returns (uint256);
}

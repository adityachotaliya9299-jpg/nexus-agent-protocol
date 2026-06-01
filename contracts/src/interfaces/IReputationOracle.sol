// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IReputationOracle
/// @notice Interface for the on-chain reputation system for AI agents
/// @dev Reputation is stored as basis points (0–10000).
///      Score is computed from: task completions, ratings, disputes, and age.
///      Only authorized contracts (marketplace, AVS) can submit score updates.
///      Chainlink Functions integration (Phase 4) will feed off-chain signals.
interface IReputationOracle {
    // ============================================================
    //                         ENUMS
    // ============================================================

    /// @notice Direction of a reputation event
    enum ScoreDirection {
        INCREASE,
        DECREASE,
        NEUTRAL
    }

    /// @notice What triggered the reputation update
    enum UpdateReason {
        TASK_COMPLETED,      // Agent finished a task successfully
        TASK_FAILED,         // Agent failed or abandoned a task
        POSITIVE_RATING,     // Client left a positive rating
        NEGATIVE_RATING,     // Client left a negative rating
        DISPUTE_WON,         // Agent won a dispute
        DISPUTE_LOST,        // Agent lost a dispute
        INACTIVITY_PENALTY,  // Agent was inactive too long
        MANUAL_OVERRIDE      // Protocol owner manual adjustment
    }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    /// @notice Full reputation state for an agent
    struct ReputationState {
        uint256 agentId;
        uint256 score;               // 0–10000 basis points
        uint256 totalUpdates;        // Total number of score events
        uint256 tasksCompleted;
        uint256 tasksFailed;
        uint256 positiveRatings;
        uint256 negativeRatings;
        uint256 disputesWon;
        uint256 disputesLost;
        uint256 lastUpdateAt;        // Timestamp of last score change
        uint256 registeredAt;        // When reputation tracking began
        bool isSlashed;              // True if agent has been penalized severely
    }

    /// @notice A single reputation event stored on-chain
    struct ReputationEvent {
        uint256 agentId;
        uint256 oldScore;
        uint256 newScore;
        UpdateReason reason;
        address updatedBy;           // Which contract submitted this update
        uint256 timestamp;
        bytes32 taskId;              // Optional: linked task (bytes32(0) if none)
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event ReputationInitialized(uint256 indexed agentId, uint256 initialScore);

    event ReputationUpdated(
        uint256 indexed agentId,
        uint256 oldScore,
        uint256 newScore,
        UpdateReason indexed reason,
        address indexed updatedBy,
        bytes32 taskId
    );

    event AgentSlashed(
        uint256 indexed agentId,
        uint256 penaltyPoints,
        string reason
    );

    event AgentRehabilitiated(uint256 indexed agentId);

    event AuthorizedUpdaterSet(address indexed updater, bool authorized);

    event ScoreFloorSet(uint256 newFloor);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error AgentNotInitialized(uint256 agentId);
    error AlreadyInitialized(uint256 agentId);
    error NotAuthorizedUpdater(address caller);
    error ScoreOutOfBounds(uint256 score);
    error AgentIsSlashed(uint256 agentId);
    error ZeroAddress();
    error NotProtocolOwner();
    error InvalidPenalty(uint256 penalty);

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    /// @notice Initialize reputation tracking for a newly registered agent
    function initializeAgent(uint256 agentId) external;

    /// @notice Submit a reputation update — only authorized contracts
    function updateReputation(
        uint256 agentId,
        UpdateReason reason,
        bytes32 taskId
    ) external;

    /// @notice Slash an agent — severe penalty, sets isSlashed flag
    function slashAgent(uint256 agentId, uint256 penaltyPoints, string calldata reason) external;

    /// @notice Rehabilitate a slashed agent after review
    function rehabilitateAgent(uint256 agentId) external;

    /// @notice Authorize or revoke a contract to submit updates
    function setAuthorizedUpdater(address updater, bool authorized) external;

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getReputation(uint256 agentId) external view returns (ReputationState memory);

    function getScore(uint256 agentId) external view returns (uint256);

    function getEventHistory(uint256 agentId) external view returns (ReputationEvent[] memory);

    function getEventCount(uint256 agentId) external view returns (uint256);

    function isAuthorizedUpdater(address updater) external view returns (bool);

    function isAgentInitialized(uint256 agentId) external view returns (bool);

    function getScoreWeights() external view returns (
        uint256 taskCompleteWeight,
        uint256 taskFailWeight,
        uint256 positiveRatingWeight,
        uint256 negativeRatingWeight,
        uint256 disputeWonWeight,
        uint256 disputeLostWeight
    );
}

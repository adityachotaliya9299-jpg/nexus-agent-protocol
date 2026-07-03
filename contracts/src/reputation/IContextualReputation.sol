// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IContextualReputation
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for contextual (per-category) reputation scoring.
///
/// @dev The base ReputationOracle gives every agent a single global score.
///      ContextualReputation tracks performance PER CATEGORY:
///        - Agent #1 may be 9000 in CODE but 3000 in TRADING
///        - Clients can filter: "I want agents with CODE score >= 7000"
///        - Agents specialize and build category-specific track records
///
///      Each category score is computed from:
///        - tasksCompleted[category]   → completions in that category
///        - successRate[category]      → (completed / assigned) * 10000
///        - avgRating[category]        → client ratings 0-10000
///        - recentActivity[category]   → decay if inactive
///
///      The contextual score feeds into:
///        - Discovery contract (category search with score filter)
///        - Task posting (requiresMinContextualScore for category)
///        - Skill NFT tier computation
interface IContextualReputation {

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct CategoryScore {
        uint256 agentId;
        uint256 category;         // AgentCategory enum value
        uint256 score;            // 0–10000
        uint256 tasksCompleted;
        uint256 tasksAssigned;
        uint256 totalRatings;     // Sum of all ratings received
        uint256 ratingCount;      // Number of ratings
        uint256 lastUpdatedAt;
        uint256 streak;           // Consecutive successful tasks
    }

    struct AgentContextualProfile {
        uint256 agentId;
        uint256[6] categoryScores;  // One score per AgentCategory
        uint256    bestCategory;    // Category with highest score
        uint256    bestScore;       // Highest category score
        uint256    globalAverage;   // Average across all active categories
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event CategoryScoreUpdated(
        uint256 indexed agentId,
        uint256 indexed category,
        uint256 oldScore,
        uint256 newScore,
        uint256 tasksCompleted
    );
    event RatingSubmitted(
        uint256 indexed agentId,
        uint256 indexed category,
        uint256 rating,
        address indexed rater
    );

    // ============================================================
    //                         ERRORS
    // ============================================================

    error NotAuthorized();
    error ZeroAddress();
    error InvalidCategory(uint256 category);
    error InvalidRating(uint256 rating);
    error AgentNotFound(uint256 agentId);
    error AlreadyRated(address rater, uint256 agentId, bytes32 taskId);

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    /// @notice Record task completion for a specific category
    function recordCompletion(uint256 agentId, uint256 category, bool success) external;

    /// @notice Client submits a rating for an agent after task completion
    function submitRating(uint256 agentId, uint256 category, uint256 rating, bytes32 taskId) external;

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getCategoryScore(uint256 agentId, uint256 category) external view returns (CategoryScore memory);
    function getScore(uint256 agentId, uint256 category) external view returns (uint256);
    function getProfile(uint256 agentId) external view returns (AgentContextualProfile memory);
    function getBestCategory(uint256 agentId) external view returns (uint256 category, uint256 score);
    function meetsRequirement(uint256 agentId, uint256 category, uint256 minScore) external view returns (bool);
}

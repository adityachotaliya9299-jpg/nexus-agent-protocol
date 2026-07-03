// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentDiscovery
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for on-chain agent discovery — search, rank, filter, recommend.
///
/// @dev Clients can query:
///   "Find me the top 5 CODE agents with score >= 7000 and stake >= 0.1 ETH"
///   "Which agents specialize in TRADING and have completed 10+ tasks?"
///   "What's the best agent for a RESEARCH task with minRep 8000?"
///
///   Discovery pulls data from:
///     - AgentRegistry     (category, status, tasks completed)
///     - ContextualReputation (per-category scores)
///     - AgentStaking      (staked ETH for trust signal)
///
///   All discovery is on-chain view functions — no off-chain indexing needed.
///   The Graph subgraph can index these for faster frontend queries.
interface IAgentDiscovery {

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct AgentSearchResult {
        uint256 agentId;
        address owner;
        address agentWallet;
        uint256 category;
        uint256 globalRepScore;      // From ReputationOracle
        uint256 contextualScore;     // From ContextualReputation for queried category
        uint256 totalTasksCompleted;
        uint256 stakedAmount;
        uint256 effectiveStake;
        bool    isActive;
        string  metadataURI;
    }

    struct SearchFilter {
        uint256 category;           // AgentCategory enum (255 = any)
        uint256 minContextualScore; // Min category-specific score
        uint256 minGlobalScore;     // Min global reputation score
        uint256 minStake;           // Min staked ETH (wei)
        uint256 minTasksCompleted;  // Min completed tasks
        bool    activeOnly;         // Only ACTIVE agents
    }

    struct LeaderboardEntry {
        uint256 agentId;
        address owner;
        uint256 score;
        uint256 rank;
        uint256 tasksCompleted;
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event AgentIndexed(uint256 indexed agentId, uint256 indexed category);
    event AgentDeindexed(uint256 indexed agentId);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error NotAuthorized();
    error ZeroAddress();
    error InvalidCategory();
    error InvalidPageSize();

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    /// @notice Index an agent for discovery (called on registration)
    function indexAgent(uint256 agentId) external;

    /// @notice Remove agent from discovery index (retired/suspended)
    function deindexAgent(uint256 agentId) external;

    // ============================================================
    //                     SEARCH FUNCTIONS
    // ============================================================

    /// @notice Search agents by filter, returns up to `limit` results
    function search(SearchFilter calldata filter, uint256 limit)
        external view returns (AgentSearchResult[] memory);

    /// @notice Get top agents by contextual score for a category
    function getLeaderboard(uint256 category, uint256 limit)
        external view returns (LeaderboardEntry[] memory);

    /// @notice Get a single agent's full discovery profile
    function getAgentProfile(uint256 agentId)
        external view returns (AgentSearchResult memory);

    /// @notice Find the best available agent for a task requirement
    function findBestAgent(
        uint256 category,
        uint256 minScore,
        uint256 minStake
    ) external view returns (uint256 agentId, uint256 score);

    /// @notice Get total indexed agent count
    function totalIndexed() external view returns (uint256);

    /// @notice Get all indexed agent IDs (paginated)
    function getIndexedAgents(uint256 offset, uint256 limit)
        external view returns (uint256[] memory agentIds);
}

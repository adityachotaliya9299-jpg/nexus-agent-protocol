// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentRegistry
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for the Nexus Agent Protocol registry
/// @dev Defines the core identity system for on-chain AI agents
interface IAgentRegistry {
    // ============================================================
    //                         ENUMS
    // ============================================================

    /// @notice Agent capability categories
    enum AgentCategory {
        GENERAL,        // General purpose agent
        CODE,           // Code generation / review
        RESEARCH,       // Research and data analysis
        TRADING,        // DeFi / trading execution
        CREATIVE,       // Creative tasks (writing, art)
        ORCHESTRATOR    // Orchestrates other agents
    }

    /// @notice Agent lifecycle status
    enum AgentStatus {
        INACTIVE,   // Not yet active
        ACTIVE,     // Available for tasks
        BUSY,       // Currently executing a task
        SUSPENDED,  // Temporarily suspended
        RETIRED     // Permanently deactivated
    }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    /// @notice Core agent identity stored on-chain
    struct AgentProfile {
        uint256 agentId;            // Unique on-chain ID
        address owner;              // EOA that controls this agent
        address agentWallet;        // ERC-4337 smart wallet address
        string metadataURI;         // IPFS CID pointing to extended metadata
        AgentCategory category;     // What this agent specializes in
        AgentStatus status;         // Current lifecycle status
        uint256 reputationScore;    // Accumulated reputation (basis points, 0-10000)
        uint256 totalTasksCompleted;
        uint256 totalEarned;        // Total wei earned
        uint256 registeredAt;       // Block timestamp
        uint256 lastActiveAt;       // Last activity timestamp
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event AgentRegistered(
        uint256 indexed agentId,
        address indexed owner,
        address indexed agentWallet,
        string metadataURI,
        AgentCategory category
    );

    event AgentUpdated(
        uint256 indexed agentId,
        string newMetadataURI,
        AgentStatus newStatus
    );

    event AgentStatusChanged(
        uint256 indexed agentId,
        AgentStatus oldStatus,
        AgentStatus newStatus
    );

    event AgentWalletSet(
        uint256 indexed agentId,
        address indexed newWallet
    );

    // ============================================================
    //                         ERRORS
    // ============================================================

    error AgentNotFound(uint256 agentId);
    error NotAgentOwner(address caller, uint256 agentId);
    error AgentAlreadyRegistered(address owner);
    error InvalidMetadataURI();
    error AgentNotActive(uint256 agentId);
    error ZeroAddress();
    error NotAuthorized();
    error InvalidScore();

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    function registerAgent(
        string calldata metadataURI,
        AgentCategory category
    ) external returns (uint256 agentId);

    function updateMetadata(uint256 agentId, string calldata metadataURI) external;

    function setAgentStatus(uint256 agentId, AgentStatus status) external;

    function setAgentWallet(uint256 agentId, address wallet) external;

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getAgent(uint256 agentId) external view returns (AgentProfile memory);

    function getAgentByOwner(address owner) external view returns (AgentProfile memory);

    function getAgentIdByOwner(address owner) external view returns (uint256);

    function isRegistered(address owner) external view returns (bool);

    function totalAgents() external view returns (uint256);
}

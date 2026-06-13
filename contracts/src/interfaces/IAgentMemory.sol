// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentMemory
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for the on-chain memory pointer registry for AI agents
///
/// @dev Each agent has versioned memory stored off-chain (IPFS/Arweave).
///      This contract stores the on-chain pointers (CIDs) with:
///        - Versioning: every memory update creates a new snapshot version
///        - Access control: owner can grant read/write access to other agents
///        - Memory types: CONTEXT, SKILLS, PREFERENCES, TASK_HISTORY, KNOWLEDGE
///        - Audit trail: all writes are logged with timestamps and writers
///
///      Memory schema (stored off-chain, pointed to by CID):
///      {
///        "version": 3,
///        "agentId": 1,
///        "type": "CONTEXT",
///        "content": { ... },
///        "createdAt": "2026-01-01T00:00:00Z"
///      }
interface IAgentMemory {
    // ============================================================
    //                         ENUMS
    // ============================================================

    /// @notice Categories of agent memory
    enum MemoryType {
        CONTEXT,        // Current task context / working memory
        SKILLS,         // Learned capabilities and expertise
        PREFERENCES,    // User/task preferences learned over time
        TASK_HISTORY,   // Summary of completed tasks
        KNOWLEDGE,      // Domain knowledge base
        RELATIONSHIPS   // Known agents, clients, collaborators
    }

    /// @notice Access level for memory sharing
    enum AccessLevel {
        NONE,       // No access
        READ,       // Can read memory CIDs
        WRITE,      // Can write new memory snapshots
        ADMIN       // Can grant/revoke access to others
    }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    /// @notice A single versioned memory snapshot
    struct MemorySnapshot {
        uint256 version;        // Monotonically increasing version number
        string cid;             // IPFS/Arweave content identifier
        MemoryType memType;     // What kind of memory this is
        address writtenBy;      // Who wrote this snapshot
        uint256 timestamp;      // When it was written
        bytes32 contentHash;    // keccak256 of the content for integrity
        bool isArchived;        // Soft-deleted snapshots
    }

    /// @notice Access grant for another agent or contract
    struct AccessGrant {
        address grantee;        // Who has access
        AccessLevel level;      // What level of access
        uint256 grantedAt;      // When access was granted
        uint256 expiresAt;      // 0 = never expires
        address grantedBy;      // Who granted this access
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event MemoryWritten(
        uint256 indexed agentId,
        MemoryType indexed memType,
        uint256 version,
        string cid,
        address indexed writtenBy
    );

    event MemoryArchived(
        uint256 indexed agentId,
        MemoryType indexed memType,
        uint256 version
    );

    event AccessGranted(
        uint256 indexed agentId,
        address indexed grantee,
        AccessLevel level,
        uint256 expiresAt
    );

    event AccessRevoked(
        uint256 indexed agentId,
        address indexed grantee
    );

    event MemoryAgentInitialized(uint256 indexed agentId, address indexed owner);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error AgentNotInitialized(uint256 agentId);
    error AlreadyInitialized(uint256 agentId);
    error NotAgentOwner(uint256 agentId, address caller);
    error AccessDenied(uint256 agentId, address caller);
    error InvalidCID();
    error InvalidContentHash();
    error VersionNotFound(uint256 agentId, MemoryType memType, uint256 version);
    error AccessExpired(address grantee, uint256 expiredAt);
    error ZeroAddress();
    error NotAuthorized();
    error CannotGrantHigherThanOwn();

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    /// @notice Initialize memory tracking for an agent
    function initializeAgent(uint256 agentId, address owner) external;

    /// @notice Write a new memory snapshot — creates new version
    function writeMemory(
        uint256 agentId,
        MemoryType memType,
        string calldata cid,
        bytes32 contentHash
    ) external returns (uint256 version);

    /// @notice Archive (soft-delete) a memory snapshot
    function archiveMemory(uint256 agentId, MemoryType memType, uint256 version) external;

    // ============================================================
    //                    ACCESS CONTROL
    // ============================================================

    /// @notice Grant memory access to another address
    function grantAccess(
        uint256 agentId,
        address grantee,
        AccessLevel level,
        uint256 expiresAt
    ) external;

    /// @notice Revoke memory access
    function revokeAccess(uint256 agentId, address grantee) external;

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    /// @notice Get the latest snapshot for a memory type
    function getLatestMemory(uint256 agentId, MemoryType memType)
        external view returns (MemorySnapshot memory);

    /// @notice Get a specific version snapshot
    function getMemoryVersion(uint256 agentId, MemoryType memType, uint256 version)
        external view returns (MemorySnapshot memory);

    /// @notice Get all snapshots for a memory type
    function getMemoryHistory(uint256 agentId, MemoryType memType)
        external view returns (MemorySnapshot[] memory);

    /// @notice Get current version number for a memory type
    function getCurrentVersion(uint256 agentId, MemoryType memType)
        external view returns (uint256);

    /// @notice Get access level for a grantee
    function getAccessLevel(uint256 agentId, address grantee)
        external view returns (AccessLevel);

    /// @notice Check if an address can write to agent memory
    function canWrite(uint256 agentId, address caller) external view returns (bool);

    /// @notice Check if an address can read agent memory
    function canRead(uint256 agentId, address caller) external view returns (bool);

    /// @notice Get the owner of an agent's memory
    function getMemoryOwner(uint256 agentId) external view returns (address);

    /// @notice Check if agent memory is initialized
    function isInitialized(uint256 agentId) external view returns (bool);

    /// @notice Get all access grants for an agent
    function getAccessGrants(uint256 agentId) external view returns (AccessGrant[] memory);

    /// @notice Total memory snapshots ever written for an agent + type
    function getTotalSnapshots(uint256 agentId, MemoryType memType)
        external view returns (uint256);
}

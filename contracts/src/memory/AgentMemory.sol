// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentMemory} from "../interfaces/IAgentMemory.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";

/// @title AgentMemory
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Versioned on-chain memory pointer registry for autonomous AI agents
///
/// @dev Architecture:
///   - Each agent has 6 memory type slots (CONTEXT, SKILLS, PREFERENCES, etc.)
///   - Every write creates an immutable versioned snapshot
///   - Latest version per type is always queryable in O(1)
///   - Full history queryable for audit trails
///   - Access control: owner, granted addresses, and protocol-authorized contracts
///
/// Memory flow:
///   1. Agent runtime writes memory to IPFS → gets CID back
///   2. Agent calls writeMemory(agentId, type, cid, contentHash)
///   3. On-chain pointer updated, version incremented, event emitted
///   4. Other agents/contracts can read the latest CID to fetch context
///
/// Phase 3 hook:
///   TaskMarketplace will call getLatestMemory(agentId, CONTEXT) before
///   assigning a task — so agents can pre-load relevant context
///
/// Security:
///   - Owner has full ADMIN access
///   - Grants can be time-limited (expiresAt)
///   - Content hash prevents CID tampering
///   - Protocol owner can initialize memory for any registered agent
contract AgentMemory is IAgentMemory {
    // ============================================================
    //                         STORAGE
    // ============================================================

    /// @notice Protocol owner — can initialize agents, authorize writers
    address public immutable protocolOwner;

    /// @notice AgentRegistry — used to verify agents exist
    address public immutable registry;

    /// @notice agentId => memory owner address
    mapping(uint256 => address) private _owners;

    /// @notice agentId => MemoryType => ordered list of snapshots
    mapping(uint256 => mapping(uint256 => MemorySnapshot[])) private _snapshots;

    /// @notice agentId => MemoryType => current latest version (0 = no snapshots yet)
    mapping(uint256 => mapping(uint256 => uint256)) private _latestVersion;

    /// @notice agentId => grantee => AccessGrant
    mapping(uint256 => mapping(address => AccessGrant)) private _grants;

    /// @notice agentId => list of all grantees (for enumeration)
    mapping(uint256 => address[]) private _grantees;

    /// @notice Protocol-authorized writers (marketplace, orchestrator)
    mapping(address => bool) private _authorizedWriters;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyProtocolOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    modifier agentExists(uint256 agentId) {
        if (_owners[agentId] == address(0)) revert AgentNotInitialized(agentId);
        _;
    }

    modifier canWriteMemory(uint256 agentId) {
        if (!_canWrite(agentId, msg.sender)) revert AccessDenied(agentId, msg.sender);
        _;
    }

    modifier canReadMemory(uint256 agentId) {
        if (!_canRead(agentId, msg.sender)) revert AccessDenied(agentId, msg.sender);
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(address _protocolOwner, address _registry) {
        if (_protocolOwner == address(0) || _registry == address(0)) revert ZeroAddress();
        protocolOwner = _protocolOwner;
        registry = _registry;
    }

    // ============================================================
    //                    INITIALIZATION
    // ============================================================

    /// @notice Initialize memory tracking for an agent
    /// @dev Called after agent registration — sets the memory owner
    ///      Can be called by: protocol owner, authorized writers, or agent owner
    function initializeAgent(uint256 agentId, address owner) external override {
        // Only protocolOwner or authorized writers can initialize
        require(
            msg.sender == protocolOwner || _authorizedWriters[msg.sender],
            "Not authorized to initialize"
        );
        if (owner == address(0)) revert ZeroAddress();
        if (_owners[agentId] != address(0)) revert AlreadyInitialized(agentId);

        // Verify agent exists in registry
        require(
            IAgentRegistry(registry).getAgent(agentId).agentId == agentId,
            "Agent not in registry"
        );

        _owners[agentId] = owner;

        emit MemoryAgentInitialized(agentId, owner);
    }

    // ============================================================
    //                      WRITE MEMORY
    // ============================================================

    /// @notice Write a new versioned memory snapshot
    /// @param agentId The agent whose memory is being updated
    /// @param memType The type of memory being written
    /// @param cid IPFS/Arweave content identifier (e.g. "ipfs://Qm...")
    /// @param contentHash keccak256 of the content for integrity verification
    /// @return version The new version number assigned to this snapshot
    function writeMemory(
        uint256 agentId,
        MemoryType memType,
        string calldata cid,
        bytes32 contentHash
    )
        external
        override
        agentExists(agentId)
        canWriteMemory(agentId)
        returns (uint256 version)
    {
        if (bytes(cid).length == 0) revert InvalidCID();
        if (contentHash == bytes32(0)) revert InvalidContentHash();

        uint256 typeIdx = uint256(memType);

        // Increment version (starts at 1)
        version = _latestVersion[agentId][typeIdx] + 1;
        _latestVersion[agentId][typeIdx] = version;

        // Store snapshot
        _snapshots[agentId][typeIdx].push(MemorySnapshot({
            version: version,
            cid: cid,
            memType: memType,
            writtenBy: msg.sender,
            timestamp: block.timestamp,
            contentHash: contentHash,
            isArchived: false
        }));

        emit MemoryWritten(agentId, memType, version, cid, msg.sender);
    }

    // ============================================================
    //                     ARCHIVE MEMORY
    // ============================================================

    /// @notice Soft-delete a memory snapshot (marks as archived)
    /// @dev Only owner or ADMIN grantee can archive
    function archiveMemory(uint256 agentId, MemoryType memType, uint256 version)
        external
        override
        agentExists(agentId)
    {
        // Only owner or admin-level grantee
        require(
            msg.sender == _owners[agentId] ||
            _grants[agentId][msg.sender].level == AccessLevel.ADMIN,
            "Not owner or admin"
        );

        uint256 typeIdx = uint256(memType);
        MemorySnapshot[] storage snaps = _snapshots[agentId][typeIdx];

        bool found = false;
        for (uint256 i = 0; i < snaps.length; i++) {
            if (snaps[i].version == version) {
                snaps[i].isArchived = true;
                found = true;
                break;
            }
        }

        if (!found) revert VersionNotFound(agentId, memType, version);

        emit MemoryArchived(agentId, memType, version);
    }

    // ============================================================
    //                     ACCESS CONTROL
    // ============================================================

    /// @notice Grant memory access to another address
    /// @param agentId The agent whose memory access is being granted
    /// @param grantee The address receiving access
    /// @param level The access level (READ, WRITE, ADMIN)
    /// @param expiresAt Unix timestamp when access expires (0 = never)
    function grantAccess(
        uint256 agentId,
        address grantee,
        AccessLevel level,
        uint256 expiresAt
    ) external override agentExists(agentId) {
        if (grantee == address(0)) revert ZeroAddress();

        // Only owner or ADMIN can grant
        require(
            msg.sender == _owners[agentId] ||
            _grants[agentId][msg.sender].level == AccessLevel.ADMIN,
            "Not owner or admin"
        );

        // Cannot grant ADMIN unless you're the owner
        if (level == AccessLevel.ADMIN && msg.sender != _owners[agentId]) {
            revert CannotGrantHigherThanOwn();
        }

        // Track grantee if new
        if (_grants[agentId][grantee].grantedAt == 0) {
            _grantees[agentId].push(grantee);
        }

        _grants[agentId][grantee] = AccessGrant({
            grantee: grantee,
            level: level,
            grantedAt: block.timestamp,
            expiresAt: expiresAt,
            grantedBy: msg.sender
        });

        emit AccessGranted(agentId, grantee, level, expiresAt);
    }

    /// @notice Revoke memory access from an address
    function revokeAccess(uint256 agentId, address grantee)
        external
        override
        agentExists(agentId)
    {
        require(
            msg.sender == _owners[agentId] ||
            _grants[agentId][msg.sender].level == AccessLevel.ADMIN,
            "Not owner or admin"
        );

        delete _grants[agentId][grantee];

        emit AccessRevoked(agentId, grantee);
    }

    // ============================================================
    //                   AUTHORIZED WRITERS
    // ============================================================

    /// @notice Authorize a protocol contract to write any agent's memory
    function setAuthorizedWriter(address writer, bool authorized) external onlyProtocolOwner {
        if (writer == address(0)) revert ZeroAddress();
        _authorizedWriters[writer] = authorized;
    }

    function isAuthorizedWriter(address writer) external view returns (bool) {
        return _authorizedWriters[writer];
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getLatestMemory(uint256 agentId, MemoryType memType)
        external
        view
        override
        agentExists(agentId)
        returns (MemorySnapshot memory)
    {
        uint256 typeIdx = uint256(memType);
        uint256 latest = _latestVersion[agentId][typeIdx];
        if (latest == 0) revert VersionNotFound(agentId, memType, 0);

        MemorySnapshot[] storage snaps = _snapshots[agentId][typeIdx];
        // Return latest non-archived (search from end)
        for (uint256 i = snaps.length; i > 0; i--) {
            if (!snaps[i - 1].isArchived) {
                return snaps[i - 1];
            }
        }
        // If all archived, return latest anyway
        return snaps[snaps.length - 1];
    }

    function getMemoryVersion(uint256 agentId, MemoryType memType, uint256 version)
        external
        view
        override
        agentExists(agentId)
        returns (MemorySnapshot memory)
    {
        uint256 typeIdx = uint256(memType);
        MemorySnapshot[] storage snaps = _snapshots[agentId][typeIdx];

        for (uint256 i = 0; i < snaps.length; i++) {
            if (snaps[i].version == version) {
                return snaps[i];
            }
        }
        revert VersionNotFound(agentId, memType, version);
    }

    function getMemoryHistory(uint256 agentId, MemoryType memType)
        external
        view
        override
        agentExists(agentId)
        returns (MemorySnapshot[] memory)
    {
        return _snapshots[agentId][uint256(memType)];
    }

    function getCurrentVersion(uint256 agentId, MemoryType memType)
        external
        view
        override
        agentExists(agentId)
        returns (uint256)
    {
        return _latestVersion[agentId][uint256(memType)];
    }

    function getAccessLevel(uint256 agentId, address grantee)
        external
        view
        override
        returns (AccessLevel)
    {
        if (grantee == _owners[agentId]) return AccessLevel.ADMIN;
        AccessGrant storage grant = _grants[agentId][grantee];
        if (grant.grantedAt == 0) return AccessLevel.NONE;
        if (grant.expiresAt != 0 && block.timestamp > grant.expiresAt) return AccessLevel.NONE;
        return grant.level;
    }

    function canWrite(uint256 agentId, address caller)
        external
        view
        override
        returns (bool)
    {
        return _canWrite(agentId, caller);
    }

    function canRead(uint256 agentId, address caller)
        external
        view
        override
        returns (bool)
    {
        return _canRead(agentId, caller);
    }

    function getMemoryOwner(uint256 agentId)
        external
        view
        override
        returns (address)
    {
        return _owners[agentId];
    }

    function isInitialized(uint256 agentId)
        external
        view
        override
        returns (bool)
    {
        return _owners[agentId] != address(0);
    }

    function getAccessGrants(uint256 agentId)
        external
        view
        override
        returns (AccessGrant[] memory)
    {
        address[] storage granteeList = _grantees[agentId];
        AccessGrant[] memory result = new AccessGrant[](granteeList.length);
        for (uint256 i = 0; i < granteeList.length; i++) {
            result[i] = _grants[agentId][granteeList[i]];
        }
        return result;
    }

    function getTotalSnapshots(uint256 agentId, MemoryType memType)
        external
        view
        override
        returns (uint256)
    {
        return _snapshots[agentId][uint256(memType)].length;
    }

    // ============================================================
    //                     INTERNAL HELPERS
    // ============================================================

    function _canWrite(uint256 agentId, address caller) internal view returns (bool) {
        // Protocol owner can always write
        if (caller == protocolOwner) return true;
        // Authorized protocol writers (marketplace, etc.)
        if (_authorizedWriters[caller]) return true;
        // Memory owner
        if (caller == _owners[agentId]) return true;
        // Check grant
        AccessGrant storage grant = _grants[agentId][caller];
        if (grant.grantedAt == 0) return false;
        if (grant.expiresAt != 0 && block.timestamp > grant.expiresAt) return false;
        return grant.level == AccessLevel.WRITE || grant.level == AccessLevel.ADMIN;
    }

    function _canRead(uint256 agentId, address caller) internal view returns (bool) {
        // Protocol owner can always read
        if (caller == protocolOwner) return true;
        // Authorized protocol writers can also read
        if (_authorizedWriters[caller]) return true;
        // Memory owner
        if (caller == _owners[agentId]) return true;
        // Check grant — any non-NONE level can read
        AccessGrant storage grant = _grants[agentId][caller];
        if (grant.grantedAt == 0) return false;
        if (grant.expiresAt != 0 && block.timestamp > grant.expiresAt) return false;
        return grant.level != AccessLevel.NONE;
    }
}

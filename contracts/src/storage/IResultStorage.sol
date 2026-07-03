// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IResultStorage
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for permanent agent result storage anchored on-chain.
///
/// @dev Flow:
///   1. Agent completes task off-chain
///   2. Agent uploads result to Arweave (permanent, content-addressed)
///   3. Agent gets back an Arweave TX ID (43-char base64url string)
///   4. Agent calls anchorResult() — stores arweaveTxId + keccak256(content) on-chain
///   5. Anyone can verify: fetch Arweave TX, hash content, compare to on-chain hash
///
///   Why Arweave:
///     - IPFS content can be unpinned and disappear
///     - Arweave is pay-once, store forever (~$0.004 per MB permanently)
///     - Task results are evidence — they must survive indefinitely
///     - Arweave TX IDs are content-addressed like IPFS CIDs
///
///   On-chain storage:
///     - Only the 43-char Arweave TX ID + content hash are stored on-chain
///     - This costs ~3000 gas for the mapping write
///     - Full content lives on Arweave, never on-chain
interface IResultStorage {

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct StoredResult {
        bytes32  taskId;
        uint256  agentId;
        string   arweaveTxId;   
        bytes32  contentHash;   
        uint256  contentSize;   
        string   contentType;   
        uint256  storedAt;
        bool     verified;      
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event ResultAnchored(
        bytes32 indexed taskId,
        uint256 indexed agentId,
        string  arweaveTxId,
        bytes32 contentHash
    );
    event ResultVerified(bytes32 indexed taskId, bytes32 contentHash);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error NotAuthorized();
    error ZeroAddress();
    error EmptyArweaveTxId();
    error InvalidArweaveTxId(string txId);
    error ResultAlreadyAnchored(bytes32 taskId);
    error ResultNotFound(bytes32 taskId);
    error HashMismatch(bytes32 taskId, bytes32 expected, bytes32 actual);

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    /// @notice Anchor an Arweave result on-chain after uploading
    function anchorResult(
        bytes32 taskId,
        uint256 agentId,
        string calldata arweaveTxId,
        bytes32 contentHash,
        uint256 contentSize,
        string calldata contentType
    ) external;

    /// @notice Verify content hash matches what was anchored (called after fetch)
    function verifyResult(bytes32 taskId, bytes32 contentHash) external;

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getResult(bytes32 taskId) external view returns (StoredResult memory);
    function getAgentResults(uint256 agentId) external view returns (bytes32[] memory taskIds);
    function isAnchored(bytes32 taskId) external view returns (bool);
    function totalAnchored() external view returns (uint256);
}

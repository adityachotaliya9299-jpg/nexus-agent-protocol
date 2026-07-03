// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IResultStorage} from "./IResultStorage.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";

/// @title ResultStorage
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Anchors Arweave TX IDs on-chain for permanent, verifiable task results.
///
/// @dev Arweave TX IDs are 43-character base64url strings.
///      Validation: must be exactly 43 chars, only base64url chars (A-Z, a-z, 0-9, -, _).

contract ResultStorage is IResultStorage {

    // ── Storage ──────────────────────────────────────────────────

    address public immutable protocolOwner;
    address public immutable registry;

    mapping(address => bool)   public isAuthorized;

    /// @notice taskId => StoredResult
    mapping(bytes32 => StoredResult) private _results;

    /// @notice agentId => list of taskIds they've anchored
    mapping(uint256 => bytes32[]) private _agentResults;

    uint256 public override totalAnchored;

    // ── Modifiers ────────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    // ── Constructor ───────────────────────────────────────────────

    constructor(address _protocolOwner, address _registry) {
        if (_protocolOwner == address(0) || _registry == address(0)) revert ZeroAddress();
        protocolOwner = _protocolOwner;
        registry      = _registry;
    }

    // ── Anchor Result ─────────────────────────────────────────────

    function anchorResult(
        bytes32 taskId,
        uint256 agentId,
        string calldata arweaveTxId,
        bytes32 contentHash,
        uint256 contentSize,
        string calldata contentType
    ) external override {
        if (_results[taskId].storedAt != 0) revert ResultAlreadyAnchored(taskId);
        if (bytes(arweaveTxId).length == 0) revert EmptyArweaveTxId();
        if (!_validArweaveTxId(arweaveTxId)) revert InvalidArweaveTxId(arweaveTxId);

        // Verify caller owns the agent
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender && !isAuthorized[msg.sender]) revert NotAuthorized();

        _results[taskId] = StoredResult({
            taskId:      taskId,
            agentId:     agentId,
            arweaveTxId: arweaveTxId,
            contentHash: contentHash,
            contentSize: contentSize,
            contentType: contentType,
            storedAt:    block.timestamp,
            verified:    false
        });

        _agentResults[agentId].push(taskId);
        totalAnchored++;

        emit ResultAnchored(taskId, agentId, arweaveTxId, contentHash);
    }

    // ── Verify Result ─────────────────────────────────────────────

    function verifyResult(bytes32 taskId, bytes32 contentHash) external override {
        StoredResult storage r = _results[taskId];
        if (r.storedAt == 0) revert ResultNotFound(taskId);
        if (r.contentHash != contentHash) revert HashMismatch(taskId, r.contentHash, contentHash);

        r.verified = true;
        emit ResultVerified(taskId, contentHash);
    }

    // ── View Functions ────────────────────────────────────────────

    function getResult(bytes32 taskId) external view override returns (StoredResult memory) {
        if (_results[taskId].storedAt == 0) revert ResultNotFound(taskId);
        return _results[taskId];
    }

    function getAgentResults(uint256 agentId)
        external view override returns (bytes32[] memory)
    {
        return _agentResults[agentId];
    }

    function isAnchored(bytes32 taskId) external view override returns (bool) {
        return _results[taskId].storedAt != 0;
    }

    // ── Admin ────────────────────────────────────────────────────

    function setAuthorized(address addr, bool auth) external onlyOwner {
        if (addr == address(0)) revert ZeroAddress();
        isAuthorized[addr] = auth;
    }

    // ── Internal ─────────────────────────────────────────────────

    /// @notice Validate Arweave TX ID — must be 43 base64url chars
    function _validArweaveTxId(string calldata txId) internal pure returns (bool) {
        bytes memory b = bytes(txId);
        if (b.length != 43) return false;
        for (uint256 i = 0; i < 43; i++) {
            bytes1 c = b[i];
            bool valid = (c >= 0x41 && c <= 0x5A) || // A-Z
                         (c >= 0x61 && c <= 0x7A) || // a-z
                         (c >= 0x30 && c <= 0x39) || // 0-9
                         c == 0x2D ||                 // -
                         c == 0x5F;                   // _
            if (!valid) return false;
        }
        return true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CrossChainSlashGuard
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Fixes the async cross-chain slashing gap in CrossChainBridge.
///
/// @dev THE ATTACK:
///   1. Agent is slashed on Chain A (Sepolia)
///   2. CCIP message sent to Chain B (Base) — takes 5-20 minutes
///   3. During that window, agent still appears unslashed on Chain B
///   4. Agent executes high-value actions on Chain B using "clean" reputation
///   5. CCIP arrives — too late, damage done
///
/// @dev THE FIX — three layers:
///
///   LAYER 1: PENDING SLASH STATE
///     When a slash is initiated on Chain A, a "pending slash" record is created
///     with a timestamp. Any cross-chain action from that agent on Chain B that
///     queries reputation must check: "is there a pending slash in the sync window?"
///     If yes → action is blocked or capped.
///
///   LAYER 2: NONCE + REPLAY PROTECTION
///     Every CCIP message includes a monotonic nonce per agent.
///     If a message arrives out of order or is replayed, it is rejected.
///     This prevents an attacker from replaying an old "unslashed" state message.
///
///   LAYER 3: MAX ACTION VALUE DURING SYNC WINDOW
///     A configurable cap: during SYNC_WINDOW seconds after any cross-chain
///     message, the max ETH value of actions that agent can take is capped.
///     Default: 0.1 ETH cap during 30-minute sync window.
///     This limits damage even if the other layers fail.
///
/// @dev INTEGRATION:
///   This contract is a mixin/library — integrate its state into CrossChainBridge.
///   Call _beforeCrossChainAction() from any function that should be protected.
///   Call _recordSlashInitiated() when a slash is sent cross-chain.
///   Call _applyReceivedSlash() when a CCIP slash message arrives.
contract CrossChainSlashGuard {

    // ============================================================
    //                       CONSTANTS
    // ============================================================

    /// @notice Window after slash initiation during which actions are restricted
    uint256 public constant SYNC_WINDOW           = 30 minutes;

    /// @notice Max ETH value of any action during sync window
    uint256 public constant MAX_ACTION_IN_WINDOW  = 0.1 ether;

    /// @notice How long a pending slash record is kept before expiry
    uint256 public constant PENDING_SLASH_EXPIRY  = 2 hours;

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct PendingSlash {
        uint256 agentId;
        uint256 slashBps;
        uint256 initiatedAt;   // When slash was sent on source chain
        uint256 sourceChainId;
        bytes32 messageId;     // CCIP message ID for dedup
        bool    applied;       // True once received + applied on this chain
    }

    struct AgentNonce {
        uint256 lastNonce;     // Last processed nonce from source chain
        uint256 lastUpdatedAt;
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event SlashInitiated(
        uint256 indexed agentId,
        uint256 slashBps,
        bytes32 messageId,
        uint256 sourceChainId
    );
    event SlashApplied(
        uint256 indexed agentId,
        uint256 slashBps,
        bytes32 messageId
    );
    event ActionBlockedDuringSyncWindow(
        uint256 indexed agentId,
        uint256 attemptedValue
    );
    event NonceRejected(
        uint256 indexed agentId,
        uint256 receivedNonce,
        uint256 expectedNonce
    );

    // ============================================================
    //                         ERRORS
    // ============================================================

    error AgentInSyncWindow(uint256 agentId, uint256 windowEndsAt);
    error ActionValueTooHighDuringSyncWindow(uint256 value, uint256 maxAllowed);
    error MessageAlreadyProcessed(bytes32 messageId);
    error NonceOutOfOrder(uint256 agentId, uint256 received, uint256 expected);
    error ZeroAddress();

    // ============================================================
    //                         STORAGE
    // ============================================================

    /// @notice agentId => pending slash (cleared once applied)
    mapping(uint256 => PendingSlash) private _pendingSlashes;

    /// @notice messageId => processed (replay protection)
    mapping(bytes32 => bool) private _processedMessages;

    /// @notice agentId => per-source-chain nonce
    mapping(uint256 => mapping(uint256 => AgentNonce)) private _agentNonces;

    /// @notice agentId => timestamp of last cross-chain message received
    mapping(uint256 => uint256) private _lastMessageAt;

    // ============================================================
    //              LAYER 1: PENDING SLASH STATE
    // ============================================================

    /// @notice Record that a slash was initiated cross-chain for this agent
    /// @dev Call this on the SOURCE chain when sending the CCIP slash message
    function _recordSlashInitiated(
        uint256 agentId,
        uint256 slashBps,
        bytes32 messageId,
        uint256 sourceChainId
    ) internal {
        _pendingSlashes[agentId] = PendingSlash({
            agentId:       agentId,
            slashBps:      slashBps,
            initiatedAt:   block.timestamp,
            sourceChainId: sourceChainId,
            messageId:     messageId,
            applied:       false
        });

        emit SlashInitiated(agentId, slashBps, messageId, sourceChainId);
    }

    /// @notice Apply a received slash message on the DESTINATION chain
    /// @dev Call this when CCIP message arrives on destination
    function _applyReceivedSlash(
        uint256 agentId,
        uint256 slashBps,
        bytes32 messageId,
        uint256 sourceChainId,
        uint256 nonce
    ) internal {
        // Layer 2: Replay protection
        if (_processedMessages[messageId]) revert MessageAlreadyProcessed(messageId);
        _processedMessages[messageId] = true;

        // Layer 2: Nonce check — must be strictly increasing
        AgentNonce storage agentNonce = _agentNonces[agentId][sourceChainId];
        if (nonce != agentNonce.lastNonce + 1) {
            emit NonceRejected(agentId, nonce, agentNonce.lastNonce + 1);
            revert NonceOutOfOrder(agentId, nonce, agentNonce.lastNonce + 1);
        }
        agentNonce.lastNonce     = nonce;
        agentNonce.lastUpdatedAt = block.timestamp;

        // Mark local pending slash as applied (if exists)
        PendingSlash storage ps = _pendingSlashes[agentId];
        if (ps.messageId == messageId) {
            ps.applied = true;
        }

        _lastMessageAt[agentId] = block.timestamp;

        emit SlashApplied(agentId, slashBps, messageId);
    }

    // ============================================================
    //           LAYER 3: ACTION GATE — call before any
    //           cross-chain-reputation-dependent action
    // ============================================================

    /// @notice Gate any action that depends on cross-chain reputation
    /// @param agentId Agent performing the action
    /// @param actionValueWei ETH value of the action (0 for non-ETH actions)
    /// @param strictMode If true, blocks entirely during sync window.
    ///                   If false, allows action but caps ETH value.
    function _beforeCrossChainAction(
        uint256 agentId,
        uint256 actionValueWei,
        bool strictMode
    ) internal {
        PendingSlash storage ps = _pendingSlashes[agentId];

        // Check for an active (unapplied, non-expired) pending slash
        bool hasPendingSlash = (
            ps.initiatedAt > 0 &&
            !ps.applied &&
            block.timestamp < ps.initiatedAt + PENDING_SLASH_EXPIRY
        );

        if (hasPendingSlash) {
            uint256 windowEndsAt = ps.initiatedAt + SYNC_WINDOW;

            if (block.timestamp < windowEndsAt) {
                if (strictMode) {
                    // Block entirely
                    emit ActionBlockedDuringSyncWindow(agentId, actionValueWei);
                    revert AgentInSyncWindow(agentId, windowEndsAt);
                } else {
                    // Cap ETH value during window
                    if (actionValueWei > MAX_ACTION_IN_WINDOW) {
                        emit ActionBlockedDuringSyncWindow(agentId, actionValueWei);
                        revert ActionValueTooHighDuringSyncWindow(
                            actionValueWei, MAX_ACTION_IN_WINDOW
                        );
                    }
                }
            }
        }
    }

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getPendingSlash(uint256 agentId)
        external view returns (PendingSlash memory)
    {
        return _pendingSlashes[agentId];
    }

    function isInSyncWindow(uint256 agentId) external view returns (bool) {
        PendingSlash storage ps = _pendingSlashes[agentId];
        return (
            ps.initiatedAt > 0 &&
            !ps.applied &&
            block.timestamp < ps.initiatedAt + SYNC_WINDOW
        );
    }

    function getAgentNonce(uint256 agentId, uint256 sourceChainId)
        external view returns (uint256)
    {
        return _agentNonces[agentId][sourceChainId].lastNonce;
    }

    function isMessageProcessed(bytes32 messageId) external view returns (bool) {
        return _processedMessages[messageId];
    }

    function getLastMessageAt(uint256 agentId) external view returns (uint256) {
        return _lastMessageAt[agentId];
    }
}

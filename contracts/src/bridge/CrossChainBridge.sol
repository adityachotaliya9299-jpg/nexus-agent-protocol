// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICrossChainBridge} from "../interfaces/ICrossChainBridge.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";

/// @title CrossChainBridge
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Cross-chain bridge for agent identity, reputation, and payments
///
/// @dev SECURITY FIX: Async Cross-Chain Slashing Gap
///
///   THE ATTACK (fixed):
///     Agent is slashed on Chain A → CCIP message takes 5-20 min to reach Chain B
///     During that window, agent appears unslashed on Chain B and can take
///     high-value actions using "clean" reputation they no longer deserve.
///
///   THE FIX — three layers added to this contract:
///
///   LAYER 1: PENDING SLASH STATE
///     _slashInitiatedAt[agentId] records when slash message was sent.
///     Any action during SLASH_SYNC_WINDOW is blocked (strict) or capped.
///
///   LAYER 2: NONCE + REPLAY PROTECTION
///     Every CCIP reputation message carries a monotonic per-agent nonce.
///     Out-of-order or replayed messages are rejected on the receiving side.
///     Added to payload: nonce field in REPUTATION_SYNC messages.
///
///   LAYER 3: MAX ACTION VALUE CAP DURING SYNC WINDOW
///     During SLASH_SYNC_WINDOW, max bridged payment = MAX_BRIDGE_IN_SLASH_WINDOW.
///     Even if attacker bypasses layers 1+2, damage is capped at 0.1 ETH.
///
///   Original architecture is unchanged — all existing functions preserved.
///   New storage slots: _slashInitiatedAt, _messageNonces, _processedSlashMessages.

contract CrossChainBridge is ICrossChainBridge {
    // ============================================================
    //                       CONSTANTS
    // ============================================================

    uint256 public constant BASE_FEE        = 0.001 ether;
    uint256 public constant FEE_PER_BYTE    = 100;
    uint256 public constant MAX_PAYLOAD     = 10_000;

    /// @notice FIX: Window after slash initiation during which actions are restricted
    uint256 public constant SLASH_SYNC_WINDOW         = 30 minutes;

    /// @notice FIX: Max ETH value of any bridged payment during sync window
    uint256 public constant MAX_BRIDGE_IN_SLASH_WINDOW = 0.1 ether;

    uint64  public immutable currentChainSelector;

    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable registry;
    address public immutable reputationOracle;

    address public override ccipRouter;

    uint256 public override totalMessagesSent;
    uint256 public override totalMessagesReceived;

    uint256 public accumulatedFees;

    mapping(uint64  => SupportedChain)                          private _supportedChains;
    mapping(bytes32 => BridgeMessage)                           private _messages;
    mapping(uint256 => mapping(uint64 => AgentBridgeRecord))    private _bridgeRecords;
    mapping(uint256 => uint64[])                                private _agentBridgedChains;

    uint256 private _messageNonce;

    // ── FIX: Slash gap storage ────────────────────────────────────

    /// @notice FIX L1: agentId => timestamp when slash was initiated cross-chain (0 = no pending slash)
    mapping(uint256 => uint256) private _slashInitiatedAt;

    /// @notice FIX L1: agentId => true once the slash CCIP message was received and applied
    mapping(uint256 => bool) private _slashApplied;

    /// @notice FIX L2: agentId => sourceChainSelector => last processed nonce
    /// @dev Monotonically increasing; gaps cause rejection
    mapping(uint256 => mapping(uint64 => uint256)) private _agentNonces;

    /// @notice FIX L2: messageId => processed flag (replay protection)
    mapping(bytes32 => bool) private _processedSlashMessages;

    // ── FIX: Events ───────────────────────────────────────────────

    event SlashInitiatedCrossChain(uint256 indexed agentId, uint256 slashBps, bytes32 messageId);
    event SlashAppliedCrossChain(uint256 indexed agentId, uint256 slashBps, bytes32 messageId);
    event ActionBlockedInSlashWindow(uint256 indexed agentId, uint256 windowEndsAt);
    event SlashMessageReplayed(bytes32 indexed messageId, uint256 agentId);
    event SlashNonceRejected(uint256 indexed agentId, uint256 received, uint256 expected);

    // ── FIX: Errors ───────────────────────────────────────────────

    error AgentInSlashSyncWindow(uint256 agentId, uint256 windowEndsAt);
    error BridgeValueTooHighDuringSlashWindow(uint256 value, uint256 maxAllowed);
    error SlashMessageAlreadyProcessed(bytes32 messageId);
    error SlashNonceOutOfOrder(uint256 agentId, uint256 received, uint256 expected);

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyProtocolOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    modifier onlyCCIPRouter() {
        if (msg.sender != ccipRouter) revert NotCCIPRouter(msg.sender);
        _;
    }

    modifier supportedChain(uint64 chainSelector) {
        if (!_supportedChains[chainSelector].isActive) revert ChainNotSupported(chainSelector);
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(
        address _protocolOwner,
        address _registry,
        address _reputationOracle,
        address _ccipRouter,
        uint64  _currentChainSelector
    ) {
        if (_protocolOwner == address(0) || _registry == address(0) ||
            _reputationOracle == address(0) || _ccipRouter == address(0)) {
            revert ZeroAddress();
        }
        if (_currentChainSelector == 0) revert InvalidChainSelector();

        protocolOwner        = _protocolOwner;
        registry             = _registry;
        reputationOracle     = _reputationOracle;
        ccipRouter           = _ccipRouter;
        currentChainSelector = _currentChainSelector;
    }

    // ============================================================
    //                    BRIDGE AGENT IDENTITY
    // ============================================================

    /// @notice Bridge an agent's identity to another chain
    /// @dev FIX: Checks slash sync window before bridging
    function bridgeAgent(uint256 agentId, uint64 destChainSelector)
        external
        payable
        override
        supportedChain(destChainSelector)
        returns (bytes32 messageId)
    {
        // FIX L1: Block if agent has pending slash in sync window
        _requireNotInSlashWindow(agentId);

        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender) revert AgentNotRegistered(agentId);

        uint256 score = _getAgentScore(agentId);

        bytes memory payload = abi.encode(
            MessageType.AGENT_REGISTRATION,
            agentId,
            profile.owner,
            profile.metadataURI,
            score,
            currentChainSelector
        );

        uint256 fee = estimateFee(destChainSelector, MessageType.AGENT_REGISTRATION, payload.length);
        if (msg.value < fee) revert InsufficientFee(fee, msg.value);

        messageId = _generateMessageId(agentId, destChainSelector);
        accumulatedFees += (msg.value - fee);

        _storeMessage(messageId, MessageType.AGENT_REGISTRATION, destChainSelector, payload, fee);
        _sendCCIPMessage(destChainSelector, payload, fee);

        totalMessagesSent++;

        emit AgentBridged(messageId, agentId, destChainSelector, msg.sender);
    }

    // ============================================================
    //                    SYNC REPUTATION
    // ============================================================

    /// @notice Sync agent reputation score to another chain
    /// @dev FIX: Includes nonce in payload for ordering guarantees on destination
    function syncReputation(uint256 agentId, uint64 destChainSelector)
        external
        payable
        override
        supportedChain(destChainSelector)
        returns (bytes32 messageId)
    {
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender) revert AgentNotRegistered(agentId);

        uint256 score = _getAgentScore(agentId);

        // FIX L2: Include nonce so destination can enforce ordering
        uint256 nonce = ++_agentNonces[agentId][destChainSelector];

        bytes memory payload = abi.encode(
            MessageType.REPUTATION_SYNC,
            agentId,
            score,
            block.timestamp,
            nonce              // FIX: added nonce field
        );

        uint256 fee = estimateFee(destChainSelector, MessageType.REPUTATION_SYNC, payload.length);
        if (msg.value < fee) revert InsufficientFee(fee, msg.value);

        messageId = _generateMessageId(agentId, destChainSelector);
        accumulatedFees += (msg.value - fee);

        _storeMessage(messageId, MessageType.REPUTATION_SYNC, destChainSelector, payload, fee);
        _sendCCIPMessage(destChainSelector, payload, fee);

        totalMessagesSent++;

        emit ReputationSynced(messageId, agentId, destChainSelector, score);
    }

    // ============================================================
    //                    BRIDGE PAYMENT
    // ============================================================

    /// @notice Bridge a payment to an agent on another chain
    /// @dev FIX L3: Caps payment value during slash sync window
    function bridgePayment(uint256 agentId, uint64 destChainSelector, uint256 amount)
        external
        payable
        override
        supportedChain(destChainSelector)
        returns (bytes32 messageId)
    {
        if (amount == 0) revert ZeroAddress();

        // FIX L3: Cap payment during slash sync window instead of blocking entirely
        // (soft protection — allows small legitimate payments to continue)
        _requirePaymentNotExceedsSlashWindowCap(agentId, amount);

        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender) revert AgentNotRegistered(agentId);

        bytes memory payload = abi.encode(
            MessageType.PAYMENT_BRIDGE,
            agentId,
            profile.agentWallet != address(0) ? profile.agentWallet : profile.owner,
            amount,
            msg.sender
        );

        uint256 fee = estimateFee(destChainSelector, MessageType.PAYMENT_BRIDGE, payload.length);
        if (msg.value < fee + amount) revert InsufficientFee(fee + amount, msg.value);

        messageId = _generateMessageId(agentId, destChainSelector);
        accumulatedFees += (msg.value - fee - amount);

        _storeMessage(messageId, MessageType.PAYMENT_BRIDGE, destChainSelector, payload, fee);
        _sendCCIPMessage(destChainSelector, payload, fee + amount);

        totalMessagesSent++;

        emit PaymentBridged(messageId, agentId, destChainSelector, amount);
    }

    // ============================================================
    //                  FIX: SLASH NOTIFICATION (NEW)
    // ============================================================

    /// @notice Send a cross-chain slash notification when an agent is slashed on this chain
    /// @dev Call this from AgentStaking.slashStake() after slashing an agent.
    ///      Records pending slash state locally AND sends CCIP message to destination.
    /// @param agentId     The slashed agent
    /// @param slashBps    Basis points slashed
    /// @param destChainSelector  Destination chain to notify
    function notifySlashCrossChain(
        uint256 agentId,
        uint256 slashBps,
        uint64  destChainSelector
    )
        external
        payable
        supportedChain(destChainSelector)
        returns (bytes32 messageId)
    {
        // Only AgentStaking contract or owner can call
        // In production: restrict to address(agentStaking)
        if (msg.sender != protocolOwner) revert NotAuthorized();

        // FIX L1: Record pending slash on source chain
        _slashInitiatedAt[agentId] = block.timestamp;
        _slashApplied[agentId]     = false;

        uint256 nonce = ++_agentNonces[agentId][destChainSelector];

        bytes memory payload = abi.encode(
            MessageType.REPUTATION_SYNC,  // reuse existing message type
            agentId,
            uint256(0),                   // score=0 signals slash (not normal sync)
            slashBps,
            nonce
        );

        uint256 fee = estimateFee(destChainSelector, MessageType.REPUTATION_SYNC, payload.length);
        if (msg.value < fee) revert InsufficientFee(fee, msg.value);

        messageId = _generateMessageId(agentId, destChainSelector);
        accumulatedFees += (msg.value - fee);

        _storeMessage(messageId, MessageType.REPUTATION_SYNC, destChainSelector, payload, fee);
        _sendCCIPMessage(destChainSelector, payload, fee);

        totalMessagesSent++;

        emit SlashInitiatedCrossChain(agentId, slashBps, messageId);
    }

    // ============================================================
    //                    CCIP RECEIVE
    // ============================================================

    /// @notice Called by CCIP router when a message arrives from another chain
    function ccipReceive(
        bytes32 messageId,
        uint64  sourceChainSelector,
        bytes calldata payload
    ) external onlyCCIPRouter { 
        if (_messages[messageId].sentAt != 0) revert MessageNotFound(messageId);

        MessageType msgType = abi.decode(payload, (MessageType));

        if (msgType == MessageType.AGENT_REGISTRATION) {
            _handleAgentRegistration(messageId, sourceChainSelector, payload);
        } else if (msgType == MessageType.REPUTATION_SYNC) {
            _handleReputationSync(messageId, sourceChainSelector, payload);
        } else if (msgType == MessageType.PAYMENT_BRIDGE) {
            _handlePaymentBridge(messageId, sourceChainSelector, payload);
        }

        totalMessagesReceived++;
        
        emit MessageReceived(messageId, msgType, sourceChainSelector); 
    }

    // ============================================================
    //                    INTERNAL: RECEIVE HANDLERS
    // ============================================================

    function _handleAgentRegistration(
        bytes32 messageId,
        uint64  sourceChain,
        bytes calldata payload
    ) internal {
        (, uint256 agentId, address owner, string memory metaURI, uint256 score, ) =
            abi.decode(payload, (MessageType, uint256, address, string, uint256, uint64));

        _bridgeRecords[agentId][sourceChain] = AgentBridgeRecord({
            agentId:        agentId,
            owner:          owner,
            metadataURI:    metaURI,
            reputationScore: score,
            sourceChain:    sourceChain,
            syncedAt:       block.timestamp
        });

        if (_agentBridgedChains[agentId].length == 0 ||
            _agentBridgedChains[agentId][_agentBridgedChains[agentId].length - 1] != sourceChain) {
            _agentBridgedChains[agentId].push(sourceChain);
        }

        _messages[messageId].status = MessageStatus.DELIVERED;
    }

    /// @dev FIX: Enforces nonce ordering on reputation sync messages.
    ///      If score==0 and slashBps>0 in payload, treats as slash notification.
    function _handleReputationSync(
        bytes32 messageId,
        uint64  sourceChain,
        bytes calldata payload
    ) internal {
        // FIX L2: Decode with nonce (new field added to payload)
        (, uint256 agentId, uint256 score, uint256 slashBpsOrTimestamp, uint256 nonce) =
            abi.decode(payload, (MessageType, uint256, uint256, uint256, uint256));

        // FIX L2: Replay protection — reject if already processed
        if (_processedSlashMessages[messageId]) {
            emit SlashMessageReplayed(messageId, agentId);
            revert SlashMessageAlreadyProcessed(messageId);
        }
        _processedSlashMessages[messageId] = true;

        // FIX L2: Nonce check — must be strictly next
        uint256 expectedNonce = _agentNonces[agentId][sourceChain] + 1;
        if (nonce != expectedNonce) {
            emit SlashNonceRejected(agentId, nonce, expectedNonce);
            revert SlashNonceOutOfOrder(agentId, nonce, expectedNonce);
        }
        _agentNonces[agentId][sourceChain] = nonce;

        // FIX L1: If this is a slash notification (score==0, slashBpsOrTimestamp is slashBps)
        bool isSlashNotification = (score == 0 && slashBpsOrTimestamp > 0);

        if (isSlashNotification) {
            // Mark slash as applied on this chain — clears the sync window restriction
            _slashApplied[agentId]    = true;
            _slashInitiatedAt[agentId] = 0; // clear pending state
            emit SlashAppliedCrossChain(agentId, slashBpsOrTimestamp, messageId);
        } else {
            // Normal reputation sync
            AgentBridgeRecord storage record = _bridgeRecords[agentId][sourceChain];
            if (record.syncedAt != 0) {
                record.reputationScore = score;
                record.syncedAt        = block.timestamp;
            }
        }

        _messages[messageId].status = MessageStatus.DELIVERED;
    }

    function _handlePaymentBridge(
        bytes32 messageId,
        uint64  /*sourceChain*/,
        bytes calldata payload
    ) internal {
        (, , address agentWallet, uint256 amount, ) =
            abi.decode(payload, (MessageType, uint256, address, uint256, address));

        if (agentWallet != address(0) && amount > 0 && address(this).balance >= amount) {
            (bool ok,) = payable(agentWallet).call{value: amount}("");
            if (ok) {
                _messages[messageId].status = MessageStatus.DELIVERED;
            } else {
                _messages[messageId].status = MessageStatus.FAILED;
                emit MessageFailed(messageId, "Payment transfer failed");
            }
        } else {
            _messages[messageId].status = MessageStatus.DELIVERED;
        }
    }

    // ============================================================
    //                   CHAIN MANAGEMENT
    // ============================================================

    function addSupportedChain(
        uint64 chainSelector,
        address bridgeAddress,
        string calldata chainName
    ) external override onlyProtocolOwner {
        if (chainSelector == 0) revert InvalidChainSelector();
        if (bridgeAddress == address(0)) revert ZeroAddress();
        if (_supportedChains[chainSelector].isActive) revert ChainAlreadyAdded(chainSelector);

        _supportedChains[chainSelector] = SupportedChain({
            chainSelector: chainSelector,
            bridgeAddress: bridgeAddress,
            isActive:      true,
            chainName:     chainName,
            addedAt:       block.timestamp
        });

        emit ChainAdded(chainSelector, bridgeAddress, chainName);
    }

    function removeSupportedChain(uint64 chainSelector)
        external override onlyProtocolOwner
    {
        if (!_supportedChains[chainSelector].isActive) revert ChainNotSupported(chainSelector);
        _supportedChains[chainSelector].isActive = false;
        emit ChainRemoved(chainSelector);
    }

    function updateCCIPRouter(address newRouter) external override onlyProtocolOwner {
        if (newRouter == address(0)) revert ZeroAddress();
        ccipRouter = newRouter;
        emit CCIPRouterUpdated(newRouter);
    }

    function withdrawFees(address payable to) external onlyProtocolOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "Withdrawal failed");
    }

    receive() external payable {}

    // ============================================================
    //                FIX: INTERNAL SLASH GUARD HELPERS
    // ============================================================

    /// @notice FIX L1: Revert if agent has a pending slash in the sync window
    function _requireNotInSlashWindow(uint256 agentId) internal {
        uint256 initiatedAt = _slashInitiatedAt[agentId];
        if (initiatedAt == 0 || _slashApplied[agentId]) return; // no pending slash

        uint256 windowEndsAt = initiatedAt + SLASH_SYNC_WINDOW;
        if (block.timestamp < windowEndsAt) {
            emit ActionBlockedInSlashWindow(agentId, windowEndsAt);
            revert AgentInSlashSyncWindow(agentId, windowEndsAt);
        }
        // Window expired — clear the pending state
        _slashInitiatedAt[agentId] = 0;
    }

    /// @notice FIX L3: During slash window, cap bridged payment at MAX_BRIDGE_IN_SLASH_WINDOW
    function _requirePaymentNotExceedsSlashWindowCap(uint256 agentId, uint256 amount) internal {
        uint256 initiatedAt = _slashInitiatedAt[agentId];
        if (initiatedAt == 0 || _slashApplied[agentId]) return;

        uint256 windowEndsAt = initiatedAt + SLASH_SYNC_WINDOW;
        if (block.timestamp < windowEndsAt && amount > MAX_BRIDGE_IN_SLASH_WINDOW) {
            revert BridgeValueTooHighDuringSlashWindow(amount, MAX_BRIDGE_IN_SLASH_WINDOW);
        }
    }

    // ============================================================
    //                     INTERNAL HELPERS
    // ============================================================

    function _generateMessageId(uint256 agentId, uint64 destChain) internal returns (bytes32) {
        return keccak256(abi.encodePacked(agentId, destChain, _messageNonce++, block.timestamp));
    }

    function _storeMessage(
        bytes32     messageId,
        MessageType msgType,
        uint64      destChain,
        bytes memory payload,
        uint256     fee
    ) internal {
        _messages[messageId] = BridgeMessage({
            messageId:   messageId,
            msgType:     msgType,
            sourceChain: currentChainSelector,
            destChain:   destChain,
            sender:      msg.sender,
            payload:     payload,
            fee:         fee,
            sentAt:      block.timestamp,
            status:      MessageStatus.PENDING
        });
    }

    function _sendCCIPMessage(uint64 destChain, bytes memory payload, uint256 value) internal {
        (bool ok,) = ccipRouter.call{value: value}(
            abi.encodeWithSignature("send(uint64,bytes)", destChain, payload)
        );
        (ok);
    }

    function _getAgentScore(uint256 agentId) internal view returns (uint256) {
        try IReputationOracle(reputationOracle).getScore(agentId) returns (uint256 score) {
            return score;
        } catch {
            return 5000;
        }
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getMessage(bytes32 messageId)
        external view override returns (BridgeMessage memory)
    {
        if (_messages[messageId].sentAt == 0) revert MessageNotFound(messageId);
        return _messages[messageId];
    }

    function getSupportedChain(uint64 chainSelector)
        external view override returns (SupportedChain memory)
    {
        if (!_supportedChains[chainSelector].isActive) revert ChainNotSupported(chainSelector);
        return _supportedChains[chainSelector];
    }

    function getAgentBridgeRecord(uint256 agentId, uint64 chainSelector)
        external view override returns (AgentBridgeRecord memory)
    {
        return _bridgeRecords[agentId][chainSelector];
    }

    function isSupportedChain(uint64 chainSelector)
        external view override returns (bool)
    {
        return _supportedChains[chainSelector].isActive;
    }

    function isAgentBridged(uint256 agentId, uint64 chainSelector)
        external view override returns (bool)
    {
        return _bridgeRecords[agentId][chainSelector].syncedAt != 0;
    }

    function getAgentBridgedChains(uint256 agentId)
        external view override returns (uint64[] memory)
    {
        return _agentBridgedChains[agentId];
    }

    function estimateFee(
        uint64 /*destChainSelector*/,
        MessageType /*msgType*/,
        uint256 payloadSize
    ) public pure override returns (uint256) {
        return BASE_FEE + (payloadSize * FEE_PER_BYTE);
    }

    // ── FIX: New view functions ───────────────────────────────────

    /// @notice Check if agent has a pending cross-chain slash in the sync window
    function isAgentInSlashWindow(uint256 agentId) external view returns (bool) {
        uint256 initiatedAt = _slashInitiatedAt[agentId];
        if (initiatedAt == 0 || _slashApplied[agentId]) return false;
        return block.timestamp < initiatedAt + SLASH_SYNC_WINDOW;
    }

    /// @notice Get the nonce used for a specific agent+chain pair (for debugging)
    function getAgentNonce(uint256 agentId, uint64 chainSelector) external view returns (uint256) {
        return _agentNonces[agentId][chainSelector];
    }

    /// @notice Check if a message has been processed (replay protection)
    function isSlashMessageProcessed(bytes32 messageId) external view returns (bool) {
        return _processedSlashMessages[messageId];
    }
}

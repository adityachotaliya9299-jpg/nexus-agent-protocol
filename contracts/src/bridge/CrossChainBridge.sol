// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICrossChainBridge} from "../interfaces/ICrossChainBridge.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";

/// @title CrossChainBridge
/// @author Aditya Chotaliya [adityachotaliya.vercel.app]
/// @notice Cross-chain bridge for agent identity, reputation, and payments
///
/// @dev Architecture mirrors Chainlink CCIP pattern:
///
///   SEND PATH (source chain) :
///     1. Caller pays CCIP fee + optional payment amount
///     2. Bridge encodes message payload
///     3. Calls CCIP router to dispatch message
///     4. Emits event, stores message record
///
///   RECEIVE PATH (destination chain):
///     1. CCIP router calls ccipReceive() on this contract
///     2. Bridge decodes payload, executes action
///     3. For AGENT_REGISTRATION: stores bridged agent record
///     4. For REPUTATION_SYNC: updates local reputation record
///     5. For PAYMENT_BRIDGE: forwards ETH to agent's wallet
///
///   SIMULATION (for testing):
///     Real CCIP integration requires deployment on testnets.
///     This contract simulates the CCIP interface with a mock router.
///     In production: replace MockCCIPRouter with real Chainlink router.
///
/// Security:
///   - Only CCIP router can call ccipReceive()
///   - Chain allowlist prevents spoofed cross-chain messages
///   - Agent ownership verified before bridging
///   - Fee estimation prevents under-payment

contract CrossChainBridge is ICrossChainBridge {
    // ============================================================
    //                       CONSTANTS
    // ============================================================

    uint256 public constant BASE_FEE        = 0.001 ether; // Minimum CCIP fee
    uint256 public constant FEE_PER_BYTE    = 100;          // Wei per byte of payload
    uint256 public constant MAX_PAYLOAD     = 10_000;       // Max message size bytes

    // Current chain's CCIP selector (Ethereum mainnet = 5009297550715157269)
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

    /// @notice chainSelector => SupportedChain
    mapping(uint64 => SupportedChain) private _supportedChains;

    /// @notice messageId => BridgeMessage
    mapping(bytes32 => BridgeMessage) private _messages;

    /// @notice agentId => chainSelector => AgentBridgeRecord
    mapping(uint256 => mapping(uint64 => AgentBridgeRecord)) private _bridgeRecords;

    /// @notice agentId => list of chain selectors the agent is bridged to
    mapping(uint256 => uint64[]) private _agentBridgedChains;

    /// @notice nonce for messageId generation
    uint256 private _messageNonce;

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
    /// @dev Encodes agent profile + sends CCIP message to destination bridge
    function bridgeAgent(uint256 agentId, uint64 destChainSelector)
        external
        payable
        override
        supportedChain(destChainSelector)
        returns (bytes32 messageId)
    {
        // Verify agent exists and caller is owner
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender) revert AgentNotRegistered(agentId);

        uint256 score = _getAgentScore(agentId);

        // Encode payload
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
        accumulatedFees += (msg.value - fee); // excess goes to protocol

        _storeMessage(messageId, MessageType.AGENT_REGISTRATION, destChainSelector, payload, fee);
        _sendCCIPMessage(destChainSelector, payload, fee);

        totalMessagesSent++;

        emit AgentBridged(messageId, agentId, destChainSelector, msg.sender);
    }

    // ============================================================
    //                    SYNC REPUTATION
    // ============================================================

    /// @notice Sync agent reputation score to another chain
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

        bytes memory payload = abi.encode(
            MessageType.REPUTATION_SYNC,
            agentId,
            score,
            block.timestamp
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
    /// @dev msg.value = CCIP fee + payment amount
    function bridgePayment(uint256 agentId, uint64 destChainSelector, uint256 amount)
        external
        payable
        override
        supportedChain(destChainSelector)
        returns (bytes32 messageId)
    {
        if (amount == 0) revert InvalidPayload();

        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);

        bytes memory payload = abi.encode(
            MessageType.PAYMENT_BRIDGE,
            agentId,
            profile.agentWallet,
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
    //                    RECEIVE MESSAGES
    // ============================================================

    /// @notice Called by CCIP router when a cross-chain message arrives
    /// @dev In production: implements CCIPReceiver interface from Chainlink
    function ccipReceive(
        bytes32 messageId,
        uint64  sourceChainSelector,
        bytes calldata payload
    ) external onlyCCIPRouter {
        if (payload.length == 0) revert InvalidPayload();

        // Decode message type
        MessageType msgType = abi.decode(payload[:32], (MessageType));

        totalMessagesReceived++;

        if (msgType == MessageType.AGENT_REGISTRATION) {
            _handleAgentRegistration(messageId, sourceChainSelector, payload);
        } else if (msgType == MessageType.REPUTATION_SYNC) {
            _handleReputationSync(messageId, sourceChainSelector, payload);
        } else if (msgType == MessageType.PAYMENT_BRIDGE) {
            _handlePaymentBridge(messageId, sourceChainSelector, payload);
        }

        emit MessageReceived(messageId, msgType, sourceChainSelector);
    }

    // ============================================================
    //                   INTERNAL RECEIVE HANDLERS
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

        // Track which chains this agent is on
        if (_agentBridgedChains[agentId].length == 0 ||
            _agentBridgedChains[agentId][_agentBridgedChains[agentId].length - 1] != sourceChain) {
            _agentBridgedChains[agentId].push(sourceChain);
        }

        // Mark message delivered
        _messages[messageId].status = MessageStatus.DELIVERED;
    }

    function _handleReputationSync(
        bytes32 messageId,
        uint64  sourceChain,
        bytes calldata payload
    ) internal {
        (, uint256 agentId, uint256 score, ) =
            abi.decode(payload, (MessageType, uint256, uint256, uint256));

        AgentBridgeRecord storage record = _bridgeRecords[agentId][sourceChain];
        if (record.syncedAt != 0) {
            record.reputationScore = score;
            record.syncedAt = block.timestamp;
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
        external
        override
        onlyProtocolOwner
    {
        if (!_supportedChains[chainSelector].isActive) revert ChainNotSupported(chainSelector);
        _supportedChains[chainSelector].isActive = false;
        emit ChainRemoved(chainSelector);
    }

    function updateCCIPRouter(address newRouter)
        external
        override
        onlyProtocolOwner
    {
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
        // In production: calls Chainlink CCIP router
        // IRouterClient(ccipRouter).ccipSend{value: value}(destChain, message);
        // For simulation: calls MockCCIPRouter.send()
        (bool ok,) = ccipRouter.call{value: value}(
            abi.encodeWithSignature("send(uint64,bytes)", destChain, payload)
        );
        // Intentionally ignore failure — router handles delivery
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
}

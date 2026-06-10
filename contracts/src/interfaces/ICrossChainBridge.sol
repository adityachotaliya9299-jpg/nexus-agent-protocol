// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICrossChainBridge
/// @author Aditya Chotaliya [adityachotaliya.vercel.app]
/// @notice Interface for cross-chain agent identity and payment bridging
/// @dev Uses Chainlink CCIP messaging pattern for cross-chain communication
///
/// What this enables:
///   - Agent registered on Ethereum can operate on Polygon, Arbitrum, Base
///   - Cross-chain task payments (pay on chain A, agent on chain B receives)
///   - Reputation score synced across chains
///   - Agent identity verified on any supported chain
///
/// Architecture:
///   Source chain: sends CCIP message → Router → Destination chain
///   Destination chain: receives message → executes action (register/pay/sync)
///
/// Message types:
///   AGENT_REGISTRATION  - Mirror agent identity to another chain
///   REPUTATION_SYNC     - Push updated score cross-chain
///   PAYMENT_BRIDGE      - Send ETH/token payment cross-chain to agent
///   TASK_ASSIGNMENT     - Assign task on chain A to agent on chain B
interface ICrossChainBridge {
    // ============================================================
    //                         ENUMS
    // ============================================================

    enum MessageType {
        AGENT_REGISTRATION,  // Sync agent identity cross-chain
        REPUTATION_SYNC,     // Sync reputation score
        PAYMENT_BRIDGE,      // Cross-chain payment
        TASK_ASSIGNMENT      // Cross-chain task
    }

    enum MessageStatus {
        PENDING,    // Sent, not yet received
        DELIVERED,  // Received and executed on destination
        FAILED,     // Delivery failed
        REFUNDED    // Payment refunded after failure
    }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct SupportedChain {
        uint64  chainSelector;   // Chainlink CCIP chain selector
        address bridgeAddress;   // Our bridge contract on that chain
        bool    isActive;
        string  chainName;       // Human-readable name
        uint256 addedAt;
    }

    struct BridgeMessage {
        bytes32     messageId;
        MessageType msgType;
        uint64      sourceChain;
        uint64      destChain;
        address     sender;
        bytes       payload;      // Encoded message data
        uint256     fee;          // CCIP fee paid
        uint256     sentAt;
        MessageStatus status;
    }

    struct AgentBridgeRecord {
        uint256 agentId;
        address owner;
        string  metadataURI;
        uint256 reputationScore;
        uint64  sourceChain;     // Chain where originally registered
        uint256 syncedAt;
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event AgentBridged(
        bytes32 indexed messageId,
        uint256 indexed agentId,
        uint64  indexed destChain,
        address sender
    );

    event ReputationSynced(
        bytes32 indexed messageId,
        uint256 indexed agentId,
        uint64  indexed destChain,
        uint256 newScore
    );

    event PaymentBridged(
        bytes32 indexed messageId,
        uint256 indexed agentId,
        uint64  indexed destChain,
        uint256 amount
    );

    event MessageReceived(
        bytes32 indexed messageId,
        MessageType indexed msgType,
        uint64  indexed sourceChain
    );

    event MessageFailed(bytes32 indexed messageId, bytes reason);

    event ChainAdded(uint64 indexed chainSelector, address bridgeAddress, string chainName);

    event ChainRemoved(uint64 indexed chainSelector);

    event CCIPRouterUpdated(address indexed newRouter);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error ChainNotSupported(uint64 chainSelector);
    error ChainAlreadyAdded(uint64 chainSelector);
    error MessageNotFound(bytes32 messageId);
    error InsufficientFee(uint256 required, uint256 provided);
    error AgentNotRegistered(uint256 agentId);
    error NotCCIPRouter(address caller);
    error ZeroAddress();
    error NotAuthorized();
    error InvalidPayload();
    error BridgeAlreadyExists(uint256 agentId, uint64 chainSelector);
    error InvalidChainSelector();

    // ============================================================
    //                     SEND FUNCTIONS
    // ============================================================

    function bridgeAgent(
        uint256 agentId,
        uint64 destChainSelector
    ) external payable returns (bytes32 messageId);

    function syncReputation(
        uint256 agentId,
        uint64 destChainSelector
    ) external payable returns (bytes32 messageId);

    function bridgePayment(
        uint256 agentId,
        uint64 destChainSelector,
        uint256 amount
    ) external payable returns (bytes32 messageId);

    // ============================================================
    //                   CHAIN MANAGEMENT
    // ============================================================

    function addSupportedChain(
        uint64 chainSelector,
        address bridgeAddress,
        string calldata chainName
    ) external;

    function removeSupportedChain(uint64 chainSelector) external;

    function updateCCIPRouter(address newRouter) external;

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================


    function getMessage(bytes32 messageId) external view returns (BridgeMessage memory);

    function getSupportedChain(uint64 chainSelector) external view returns (SupportedChain memory);

    function getAgentBridgeRecord(uint256 agentId, uint64 chainSelector)
        external view returns (AgentBridgeRecord memory);

    function isSupportedChain(uint64 chainSelector) external view returns (bool);

    function isAgentBridged(uint256 agentId, uint64 chainSelector) external view returns (bool);

    function getAgentBridgedChains(uint256 agentId) external view returns (uint64[] memory);

    function estimateFee(
        uint64 destChainSelector,
        MessageType msgType,
        uint256 payloadSize
    ) external view returns (uint256 fee);

    function ccipRouter() external view returns (address);

    function totalMessagesSent() external view returns (uint256);

    function totalMessagesReceived() external view returns (uint256);
}

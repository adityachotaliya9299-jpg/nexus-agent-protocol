// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IL2Bridge
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for the Nexus L1↔L2 state bridge.
///
/// @dev Bridges agent reputation and registry state between
///      Ethereum Sepolia (L1) and Base Sepolia (L2).
///
///      Why bridge reputation:
///        - Agents build rep on L1 (high security, expensive)
///        - They want to use that rep on L2 (cheap, fast tasks)
///        - Without bridging, L2 agents start from zero
///        - With bridging, L1 rep unlocks L2 task eligibility
///
///      Bridge architecture:
///        L1NexusBridge (Sepolia)  ←→  L2NexusBridge (Base)
///          - Lock rep snapshot            - Receive + apply snapshot
///          - Emit CrossChainMessage       - ReputationOracle updated
///
///      Uses Optimism's native messenger (Base is an OP Stack chain):
///        L1CrossDomainMessenger: 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa
///        L2CrossDomainMessenger: 0x4200000000000000000000000000000000000007
interface IL2Bridge {

    struct ReputationSnapshot {
        uint256 agentId;
        address owner;
        uint256 globalScore;
        uint256[6] categoryScores;
        uint256 totalTasksCompleted;
        uint256 totalEarned;
        uint256 snapshotBlock;
        uint256 snapshotTimestamp;
    }

    struct BridgeMessage {
        bytes32  messageId;
        uint256  agentId;
        address  sender;
        bytes    payload;
        uint256  timestamp;
        bool     processed;
    }

    event ReputationBridged(
        uint256 indexed agentId,
        uint256 globalScore,
        uint256 snapshotBlock,
        address indexed to
    );
    event MessageSent(bytes32 indexed messageId, uint256 indexed agentId);
    event MessageReceived(bytes32 indexed messageId, uint256 indexed agentId);

    error NotAuthorized();
    error ZeroAddress();
    error AgentNotFound(uint256 agentId);
    error MessageAlreadyProcessed(bytes32 messageId);
    error InvalidChain(uint256 expected, uint256 actual);

    /// @notice Bridge agent reputation snapshot from L1 → L2
    function bridgeReputation(uint256 agentId) external;

    /// @notice Receive bridged reputation (called by messenger on L2)
    function receiveReputation(ReputationSnapshot calldata snapshot) external;

    /// @notice Get the bridged snapshot for an agent on L2
    function getBridgedSnapshot(uint256 agentId) external view returns (ReputationSnapshot memory);

    /// @notice Check if agent has a valid bridged reputation
    function hasBridgedReputation(uint256 agentId) external view returns (bool);
}

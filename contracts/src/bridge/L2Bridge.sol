// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IL2Bridge} from "./IL2Bridge.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";

/// @title L2Bridge
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Bridges agent reputation between Ethereum Sepolia and Base Sepolia.
///
/// @dev Deploy two instances:
///   L1NexusBridge on Ethereum Sepolia — sends snapshots
///   L2NexusBridge on Base Sepolia     — receives + applies snapshots
///
///   Both use Optimism's CrossDomainMessenger for trustless relay.
///   The messenger guarantees the message came from the correct source chain.
///
///   Snapshot validity: 7 days — agents must re-bridge after that.
///   This prevents stale data from being used indefinitely on L2.
///
///   Optimism CrossDomainMessenger addresses:
///     L1 (Sepolia): 0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef
///     L2 (Base):    0x4200000000000000000000000000000000000007
contract L2Bridge is IL2Bridge {

    // ── Constants ────────────────────────────────────────────────

    uint256 public constant SNAPSHOT_VALIDITY = 7 days;

    /// @dev Optimism L1 CrossDomainMessenger on Sepolia
    address public constant L1_MESSENGER = 0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef;

    /// @dev Optimism L2 CrossDomainMessenger on Base (predeploy)
    address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

    // ── Storage ──────────────────────────────────────────────────

    address public immutable protocolOwner;
    address public immutable registry;
    address public immutable reputationOracle;

    /// @notice The peer bridge contract on the other chain
    address public peerBridge;

    bool public isL2; // true = this is on Base, false = on Ethereum

    /// @notice agentId => snapshot (on L2 side)
    mapping(uint256 => ReputationSnapshot) private _snapshots;

    /// @notice messageId => processed
    mapping(bytes32 => bool) private _processed;

    uint256 private _nonce;

    // ── Messenger interface (minimal) ─────────────────────────────

    interface ICrossDomainMessenger {
        function sendMessage(address target, bytes calldata message, uint32 gasLimit) external;
        function xDomainMessageSender() external view returns (address);
    }

    // ── Modifiers ────────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    modifier onlyMessenger() {
        address messenger = isL2 ? L2_MESSENGER : L1_MESSENGER;
        if (msg.sender != messenger) revert NotAuthorized();
        // Verify the cross-chain sender is the peer bridge
        address sender = ICrossDomainMessenger(messenger).xDomainMessageSender();
        if (sender != peerBridge) revert NotAuthorized();
        _;
    }

    // ── Constructor ───────────────────────────────────────────────

    constructor(
        address _protocolOwner,
        address _registry,
        address _reputationOracle,
        bool    _isL2
    ) {
        if (_protocolOwner == address(0) || _registry == address(0)) revert ZeroAddress();
        protocolOwner    = _protocolOwner;
        registry         = _registry;
        reputationOracle = _reputationOracle;
        isL2             = _isL2;
    }

    // ── Bridge Reputation (L1 → sends) ───────────────────────────

    /// @notice Called on L1 to snapshot and send rep to L2
    function bridgeReputation(uint256 agentId) external override {
        if (isL2) revert NotAuthorized(); // Only callable on L1
        if (peerBridge == address(0)) revert ZeroAddress();

        IAgentRegistry.AgentProfile memory profile =
            IAgentRegistry(registry).getAgent(agentId);

        // Only agent owner can bridge their own rep
        if (profile.owner != msg.sender) revert NotAuthorized();

        uint256 score = 5000;
        try IReputationOracle(reputationOracle).getScore(agentId) returns (uint256 s) {
            score = s;
        } catch {}

        ReputationSnapshot memory snapshot = ReputationSnapshot({
            agentId:            agentId,
            owner:              profile.owner,
            globalScore:        score,
            categoryScores:     [uint256(0), 0, 0, 0, 0, 0], // simplified
            totalTasksCompleted: profile.totalTasksCompleted,
            totalEarned:        profile.totalEarned,
            snapshotBlock:      block.number,
            snapshotTimestamp:  block.timestamp
        });

        bytes memory message = abi.encodeWithSelector(
            IL2Bridge.receiveReputation.selector,
            snapshot
        );

        bytes32 messageId = keccak256(abi.encodePacked(agentId, _nonce++, block.timestamp));

        // Send via Optimism messenger
        ICrossDomainMessenger(L1_MESSENGER).sendMessage(
            peerBridge,
            message,
            200_000 // L2 gas limit
        );

        emit MessageSent(messageId, agentId);
        emit ReputationBridged(agentId, score, block.number, profile.owner);
    }

    // ── Receive Reputation (L2 ← receives) ───────────────────────

    /// @notice Called on L2 by the Optimism messenger after L1 sends
    function receiveReputation(ReputationSnapshot calldata snapshot)
        external override onlyMessenger
    {
        bytes32 messageId = keccak256(abi.encodePacked(
            snapshot.agentId, snapshot.snapshotBlock, snapshot.snapshotTimestamp
        ));

        if (_processed[messageId]) revert MessageAlreadyProcessed(messageId);
        _processed[messageId] = true;

        // Store snapshot on L2
        _snapshots[snapshot.agentId] = snapshot;

        emit MessageReceived(messageId, snapshot.agentId);
        emit ReputationBridged(
            snapshot.agentId,
            snapshot.globalScore,
            snapshot.snapshotBlock,
            snapshot.owner
        );
    }

    // ── View Functions ────────────────────────────────────────────

    function getBridgedSnapshot(uint256 agentId)
        external view override returns (ReputationSnapshot memory)
    {
        return _snapshots[agentId];
    }

    function hasBridgedReputation(uint256 agentId) external view override returns (bool) {
        ReputationSnapshot storage s = _snapshots[agentId];
        if (s.snapshotTimestamp == 0) return false;
        return block.timestamp - s.snapshotTimestamp <= SNAPSHOT_VALIDITY;
    }

    // ── Admin ────────────────────────────────────────────────────

    function setPeerBridge(address peer) external onlyOwner {
        if (peer == address(0)) revert ZeroAddress();
        peerBridge = peer;
    }
}

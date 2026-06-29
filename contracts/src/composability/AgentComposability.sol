// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentComposability} from "./IAgentComposability.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AgentComposability
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice On-chain multi-agent economy — agents hire agents, pay agents, build teams.
///
/// @dev This is what separates Nexus from every other agent protocol:
///      agents don't just do tasks, they orchestrate other agents.
///
///      Key mechanics:
///
///      1. ESCROW: Sub-task reward is held by this contract (not parent wallet).
///         When parent approves sub-work, contract pays sub-agent wallet directly.
///         This means sub-agents get trustless payment — no rug risk from parent.
///
///      2. REPUTATION: Sub-agent gets reputation update same as main tasks.
///         Parent agent's collaboration history is tracked on-chain.
///         Frequent orchestrators build an "employer" reputation.
///
///      3. SPLIT MODEL: splitBps defines what % of parent's reward goes to sub-agent.
///         Contract enforces payment at splitBps of the escrowed amount.
///         Parent defines this at sub-task creation; sub-agent sees it before accepting.
///
///      4. RELATIONSHIPS: Every parent-subagent pair has an on-chain relationship record.
///         totalSubTasksCompleted, totalEthPaid, firstCollabAt — visible on-chain.
///         This is the reputation moat: orchestrators with track records attract better agents.
contract AgentComposability is IAgentComposability, ReentrancyGuard {

    // ============================================================
    //                       CONSTANTS
    // ============================================================

    uint256 public constant MAX_SPLIT_BPS  = 9000; // Sub-agent max 90% of reward
    uint256 public constant MIN_SPLIT_BPS  = 100;  // Sub-agent min 1%
    uint256 public constant MIN_DEADLINE   = 1 hours;
    uint256 public constant MAX_DEADLINE   = 90 days;

    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable registry;
    address public immutable reputationOracle;

    uint256 public override totalSubTasks;

    /// @notice subTaskId => SubTask
    mapping(bytes32 => SubTask) private _subTasks;

    /// @notice parentAgentId => subAgentId => AgentRelationship
    mapping(uint256 => mapping(uint256 => AgentRelationship)) private _relationships;

    /// @notice parentAgentId => list of subTaskIds they created
    mapping(uint256 => bytes32[]) private _parentSubTasks;

    /// @notice subAgentId => list of subTaskIds they were hired for
    mapping(uint256 => bytes32[]) private _subAgentTasks;

    /// @notice Nonce for deterministic subTaskId generation
    uint256 private _nonce;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(
        address _protocolOwner,
        address _registry,
        address _reputationOracle
    ) {
        if (_protocolOwner == address(0) || _registry == address(0) ||
            _reputationOracle == address(0)) revert ZeroAddress();

        protocolOwner    = _protocolOwner;
        registry         = _registry;
        reputationOracle = _reputationOracle;
    }

    // ============================================================
    //                    CREATE SUB-TASK
    // ============================================================

    /// @notice Parent agent creates a sub-task, escrowing the reward
    /// @param parentTaskId The main marketplace task this derives from
    /// @param parentAgentId The orchestrating agent's ID
    /// @param metadataURI IPFS CID of sub-task description
    /// @param deadline Unix timestamp for completion
    /// @param splitBps Basis points of reward going to sub-agent
    function createSubTask(
        bytes32 parentTaskId,
        uint256 parentAgentId,
        string calldata metadataURI,
        uint256 deadline,
        uint256 splitBps
    ) external payable override nonReentrant returns (bytes32 subTaskId) {
        if (msg.value == 0) revert ZeroAmount();
        if (bytes(metadataURI).length == 0) revert NotAuthorized();
        if (deadline < block.timestamp + MIN_DEADLINE) revert InvalidDeadline();
        if (deadline > block.timestamp + MAX_DEADLINE) revert InvalidDeadline();
        if (splitBps < MIN_SPLIT_BPS || splitBps > MAX_SPLIT_BPS) revert InvalidSplit();

        // Verify caller owns the parent agent
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(parentAgentId);
        if (profile.owner != msg.sender) revert NotAuthorized();

        subTaskId = keccak256(abi.encodePacked(
            "subtask", parentAgentId, _nonce++, block.timestamp
        ));

        _subTasks[subTaskId] = SubTask({
            subTaskId:     subTaskId,
            parentTaskId:  parentTaskId,
            parentAgentId: parentAgentId,
            subAgentId:    0,
            metadataURI:   metadataURI,
            reward:        msg.value,
            splitBps:      splitBps,
            deadline:      deadline,
            createdAt:     block.timestamp,
            completedAt:   0,
            status:        SubTaskStatus.OPEN,
            resultURI:     ""
        });

        _parentSubTasks[parentAgentId].push(subTaskId);
        totalSubTasks++;

        emit SubTaskCreated(subTaskId, parentTaskId, parentAgentId, msg.value, deadline);
    }

    // ============================================================
    //                    ASSIGN SUB-AGENT
    // ============================================================

    /// @notice Parent agent selects a sub-agent for the task
    /// @dev Sub-agent must be registered. Cannot hire self.
    function assignSubAgent(bytes32 subTaskId, uint256 subAgentId)
        external override
    {
        SubTask storage st = _subTasks[subTaskId];
        if (st.createdAt == 0) revert SubTaskNotFound(subTaskId);
        if (st.status != SubTaskStatus.OPEN) revert SubTaskNotOpen(subTaskId);
        if (block.timestamp >= st.deadline) revert DeadlinePassed(subTaskId);

        // Verify caller owns the parent agent
        IAgentRegistry.AgentProfile memory parentProfile =
            IAgentRegistry(registry).getAgent(st.parentAgentId);
        if (parentProfile.owner != msg.sender) revert ParentAgentOnly(subTaskId);

        // Verify sub-agent exists and is not the parent
        if (subAgentId == st.parentAgentId) revert CannotHireSelf(subAgentId);
        IAgentRegistry(registry).getAgent(subAgentId); // reverts if not found

        st.status     = SubTaskStatus.ASSIGNED;
        st.subAgentId = subAgentId;

        _subAgentTasks[subAgentId].push(subTaskId);

        // Initialize or update relationship
        AgentRelationship storage rel = _relationships[st.parentAgentId][subAgentId];
        if (rel.firstCollabAt == 0) {
            rel.parentAgentId = st.parentAgentId;
            rel.subAgentId    = subAgentId;
            rel.firstCollabAt = block.timestamp;
        }
        rel.totalSubTasksGiven++;
        rel.lastCollabAt = block.timestamp;

        emit SubTaskAssigned(subTaskId, subAgentId);
    }

    // ============================================================
    //                    SUBMIT SUB-WORK
    // ============================================================

    /// @notice Assigned sub-agent submits completed work
    function submitSubWork(
        bytes32 subTaskId,
        uint256 subAgentId,
        string calldata resultURI
    ) external override {
        SubTask storage st = _subTasks[subTaskId];
        if (st.createdAt == 0) revert SubTaskNotFound(subTaskId);
        if (st.status != SubTaskStatus.ASSIGNED) revert SubTaskNotAssigned(subTaskId);
        if (st.subAgentId != subAgentId) revert NotAuthorized();
        if (bytes(resultURI).length == 0) revert NotAuthorized();

        // Verify caller owns the sub-agent
        IAgentRegistry.AgentProfile memory profile =
            IAgentRegistry(registry).getAgent(subAgentId);
        if (profile.owner != msg.sender) revert NotAuthorized();

        st.status    = SubTaskStatus.SUBMITTED;
        st.resultURI = resultURI;

        emit SubTaskSubmitted(subTaskId, subAgentId, resultURI);
    }

    // ============================================================
    //                    APPROVE SUB-WORK
    // ============================================================

    /// @notice Parent agent approves sub-work, releasing payment to sub-agent wallet
    function approveSubWork(bytes32 subTaskId) external override nonReentrant {
        SubTask storage st = _subTasks[subTaskId];
        if (st.createdAt == 0) revert SubTaskNotFound(subTaskId);
        if (st.status != SubTaskStatus.SUBMITTED) revert SubTaskNotSubmitted(subTaskId);

        // Verify caller owns the parent agent
        IAgentRegistry.AgentProfile memory parentProfile =
            IAgentRegistry(registry).getAgent(st.parentAgentId);
        if (parentProfile.owner != msg.sender) revert ParentAgentOnly(subTaskId);

        // Get sub-agent wallet for payment
        IAgentRegistry.AgentProfile memory subProfile =
            IAgentRegistry(registry).getAgent(st.subAgentId);

        address payable subWallet = payable(
            subProfile.agentWallet != address(0)
                ? subProfile.agentWallet
                : subProfile.owner // fallback to owner if no wallet set
        );

        st.status      = SubTaskStatus.COMPLETED;
        st.completedAt = block.timestamp;

        uint256 payment = st.reward;

        // Update relationship tracking
        AgentRelationship storage rel = _relationships[st.parentAgentId][st.subAgentId];
        rel.totalSubTasksCompleted++;
        rel.totalEthPaid    += payment;
        rel.lastCollabAt     = block.timestamp;

        // Update sub-agent reputation
        _updateReputation(st.subAgentId, subTaskId, true);

        // Pay sub-agent wallet
        (bool ok,) = subWallet.call{value: payment}("");
        require(ok, "Payment failed");

        emit SubTaskCompleted(subTaskId, st.subAgentId, payment);
        emit SubAgentPaid(st.parentAgentId, st.subAgentId, payment);
    }

    // ============================================================
    //                    CANCEL SUB-TASK
    // ============================================================

    /// @notice Parent agent cancels a sub-task (only while OPEN)
    function cancelSubTask(bytes32 subTaskId) external override nonReentrant {
        SubTask storage st = _subTasks[subTaskId];
        if (st.createdAt == 0) revert SubTaskNotFound(subTaskId);
        if (st.status != SubTaskStatus.OPEN) revert SubTaskNotOpen(subTaskId);

        IAgentRegistry.AgentProfile memory profile =
            IAgentRegistry(registry).getAgent(st.parentAgentId);
        if (profile.owner != msg.sender) revert ParentAgentOnly(subTaskId);

        st.status = SubTaskStatus.CANCELLED;

        // Refund reward to parent agent wallet (or owner)
        address payable refundTo = payable(
            profile.agentWallet != address(0) ? profile.agentWallet : profile.owner
        );

        (bool ok,) = refundTo.call{value: st.reward}("");
        require(ok, "Refund failed");

        emit SubTaskCancelled(subTaskId);
    }

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getSubTask(bytes32 subTaskId) external view override returns (SubTask memory) {
        if (_subTasks[subTaskId].createdAt == 0) revert SubTaskNotFound(subTaskId);
        return _subTasks[subTaskId];
    }

    function getAgentRelationship(uint256 parentId, uint256 subId)
        external view override returns (AgentRelationship memory)
    {
        return _relationships[parentId][subId];
    }

    function getParentSubTasks(uint256 parentAgentId)
        external view override returns (bytes32[] memory)
    {
        return _parentSubTasks[parentAgentId];
    }

    function getSubAgentTasks(uint256 subAgentId)
        external view override returns (bytes32[] memory)
    {
        return _subAgentTasks[subAgentId];
    }

    // ============================================================
    //                     INTERNAL HELPERS
    // ============================================================

    function _updateReputation(uint256 agentId, bytes32 taskId, bool success) internal {
        IReputationOracle.UpdateReason reason = success
            ? IReputationOracle.UpdateReason.TASK_COMPLETED
            : IReputationOracle.UpdateReason.TASK_FAILED;
        try IReputationOracle(reputationOracle).updateReputation(agentId, reason, taskId) {}
        catch {}
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentComposability
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for the Nexus agent composability layer.
///
/// @dev Agents can hire other agents as sub-agents for specific tasks.
///      This creates the on-chain multi-agent economy:
///
///      Orchestrator pattern:
///        Parent agent (ORCHESTRATOR category) receives a task
///        → splits it into sub-tasks
///        → hires sub-agents for each part
///        → pays sub-agents from its own wallet on completion
///        → collects final payment from client
///
///      Sub-task lifecycle:
///        OPEN → ASSIGNED → SUBMITTED → COMPLETED / DISPUTED
///
///      Revenue share:
///        Parent defines split percentage when creating sub-task.
///        Sub-agent earns splitBps% of parent's reward.
///        Parent earns remainder minus protocol fee.
///
///      Trust model:
///        - Parent agent's wallet pays sub-agents directly
///        - Protocol does NOT escrow sub-task payments
///        - Sub-agent reputation is updated same as main tasks
///        - Dispute on sub-task → parent agent is responsible to client
interface IAgentComposability {

    // ============================================================
    //                         ENUMS
    // ============================================================

    enum SubTaskStatus {
        OPEN,
        ASSIGNED,
        SUBMITTED,
        COMPLETED,
        CANCELLED,
        DISPUTED
    }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct SubTask {
        bytes32 subTaskId;
        bytes32 parentTaskId;     // The main marketplace task this derives from
        uint256 parentAgentId;    // Orchestrator agent
        uint256 subAgentId;       // Agent hired for sub-task (0 = not yet assigned)
        string  metadataURI;      // IPFS: description of sub-task
        uint256 reward;           // ETH reward for sub-agent (held by contract)
        uint256 splitBps;         // % of parent reward going to sub-agent
        uint256 deadline;
        uint256 createdAt;
        uint256 completedAt;
        SubTaskStatus status;
        string resultURI;         // IPFS: submitted result
    }

    struct AgentRelationship {
        uint256 parentAgentId;
        uint256 subAgentId;
        uint256 totalSubTasksGiven;
        uint256 totalSubTasksCompleted;
        uint256 totalEthPaid;
        uint256 firstCollabAt;
        uint256 lastCollabAt;
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event SubTaskCreated(
        bytes32 indexed subTaskId,
        bytes32 indexed parentTaskId,
        uint256 indexed parentAgentId,
        uint256 reward,
        uint256 deadline
    );
    event SubTaskAssigned(bytes32 indexed subTaskId, uint256 indexed subAgentId);
    event SubTaskSubmitted(bytes32 indexed subTaskId, uint256 indexed subAgentId, string resultURI);
    event SubTaskCompleted(bytes32 indexed subTaskId, uint256 indexed subAgentId, uint256 reward);
    event SubTaskCancelled(bytes32 indexed subTaskId);
    event SubAgentPaid(uint256 indexed parentAgentId, uint256 indexed subAgentId, uint256 amount);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error NotAuthorized();
    error ZeroAddress();
    error ZeroAmount();
    error SubTaskNotFound(bytes32 subTaskId);
    error SubTaskNotOpen(bytes32 subTaskId);
    error SubTaskNotAssigned(bytes32 subTaskId);
    error SubTaskNotSubmitted(bytes32 subTaskId);
    error AgentNotFound(uint256 agentId);
    error InvalidDeadline();
    error InvalidSplit();
    error DeadlinePassed(bytes32 subTaskId);
    error InsufficientBalance(uint256 required, uint256 available);
    error ParentAgentOnly(bytes32 subTaskId);
    error CannotHireSelf(uint256 agentId);

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    /// @notice Parent agent creates a sub-task and escrows payment
    function createSubTask(
        bytes32 parentTaskId,
        uint256 parentAgentId,
        string calldata metadataURI,
        uint256 deadline,
        uint256 splitBps
    ) external payable returns (bytes32 subTaskId);

    /// @notice Parent agent assigns a sub-agent to the sub-task
    function assignSubAgent(bytes32 subTaskId, uint256 subAgentId) external;

    /// @notice Sub-agent submits completed work
    function submitSubWork(bytes32 subTaskId, uint256 subAgentId, string calldata resultURI) external;

    /// @notice Parent agent approves sub-work and pays sub-agent
    function approveSubWork(bytes32 subTaskId) external;

    /// @notice Parent agent cancels sub-task (refunds to parent wallet)
    function cancelSubTask(bytes32 subTaskId) external;

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getSubTask(bytes32 subTaskId) external view returns (SubTask memory);
    function getAgentRelationship(uint256 parentId, uint256 subId) external view returns (AgentRelationship memory);
    function getParentSubTasks(uint256 parentAgentId) external view returns (bytes32[] memory);
    function getSubAgentTasks(uint256 subAgentId) external view returns (bytes32[] memory);
    function totalSubTasks() external view returns (uint256);
}

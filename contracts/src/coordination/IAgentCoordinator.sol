// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentCoordinator
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for multi-agent coordination — the orchestration layer
///         that sits above TaskMarketplace and AgentComposability.
///
/// @dev The Coordinator enables:
///
///   PIPELINE TASKS:
///     Complex tasks that require agents to work sequentially.
///     Agent A produces output → Agent B uses it as input → Agent C validates.
///     Each stage has independent payment and ZK proof requirement.
///     If any stage fails, only that stage's payment is withheld.
///
///   PARALLEL TASKS:
///     Split a task into N independent sub-tasks run simultaneously.
///     Results are merged by a designated aggregator agent.
///     Payment unlocks only after aggregator submits merged result.
///
///   AGENT NETWORKS:
///     Named, reusable agent teams with predefined roles.
///     Networks can be hired as a unit for recurring work.
///     On-chain track record of network performance.
///
///   KEY DIFFERENCE FROM AgentComposability:
///     AgentComposability = one parent, one sub-agent, one task
///     AgentCoordinator   = multi-stage, multi-agent, complex workflows
interface IAgentCoordinator {

    // ============================================================
    //                         ENUMS
    // ============================================================

    enum WorkflowType  { PIPELINE, PARALLEL }
    enum WorkflowStatus { ACTIVE, COMPLETED, FAILED, CANCELLED }
    enum StageStatus   { PENDING, ACTIVE, COMPLETED, FAILED, SKIPPED }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct Stage {
        uint256  stageIndex;
        uint256  assignedAgentId;
        string   inputURI;       // IPFS: input for this stage
        string   outputURI;      // IPFS: output after completion
        uint256  reward;         // ETH for this stage
        uint256  deadline;
        StageStatus status;
        bytes32  proofId;        // Optional ZK proof of work
    }

    struct Workflow {
        bytes32       workflowId;
        bytes32       parentTaskId;   // Linked marketplace task
        address       client;
        WorkflowType  workflowType;
        WorkflowStatus status;
        uint256       totalStages;
        uint256       completedStages;
        uint256       totalBudget;
        uint256       createdAt;
        uint256       completedAt;
        uint256       aggregatorAgentId; // For PARALLEL — merges results
    }

    struct AgentNetwork {
        bytes32  networkId;
        string   name;
        uint256  totalJobs;
        uint256  successfulJobs;
        uint256  createdAt;
        bool     isActive;
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event WorkflowCreated(bytes32 indexed workflowId, WorkflowType workflowType, uint256 totalStages);
    event StageStarted(bytes32 indexed workflowId, uint256 stageIndex, uint256 agentId);
    event StageCompleted(bytes32 indexed workflowId, uint256 stageIndex, uint256 agentId, string outputURI);
    event StageFailed(bytes32 indexed workflowId, uint256 stageIndex, uint256 agentId);
    event WorkflowCompleted(bytes32 indexed workflowId, uint256 totalPaid);
    event WorkflowFailed(bytes32 indexed workflowId, uint256 stageIndex);
    event NetworkCreated(bytes32 indexed networkId, string name);
    event NetworkJobCompleted(bytes32 indexed networkId, bytes32 workflowId);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error NotAuthorized();
    error ZeroAddress();
    error WorkflowNotFound(bytes32 workflowId);
    error StageNotActive(bytes32 workflowId, uint256 stageIndex);
    error StageNotPending(bytes32 workflowId, uint256 stageIndex);
    error WorkflowNotActive(bytes32 workflowId);
    error InvalidStageCount();
    error InvalidBudget();
    error DeadlinePassed(bytes32 workflowId, uint256 stageIndex);
    error NetworkNotFound(bytes32 networkId);
    error AggregatorRequired(bytes32 workflowId);

    // ============================================================
    //                     WORKFLOW FUNCTIONS
    // ============================================================

    function createPipeline(
        bytes32 parentTaskId,
        uint256[] calldata agentIds,
        uint256[] calldata stageBudgets,
        uint256[] calldata stageDeadlines,
        string[] calldata inputURIs
    ) external payable returns (bytes32 workflowId);

    function createParallel(
        bytes32 parentTaskId,
        uint256[] calldata agentIds,
        uint256[] calldata stageBudgets,
        uint256[] calldata stageDeadlines,
        uint256 aggregatorAgentId,
        uint256 aggregatorBudget
    ) external payable returns (bytes32 workflowId);

    function submitStageResult(
        bytes32 workflowId,
        uint256 stageIndex,
        string calldata outputURI
    ) external;

    function failStage(bytes32 workflowId, uint256 stageIndex) external;

    function cancelWorkflow(bytes32 workflowId) external;

    // ============================================================
    //                     NETWORK FUNCTIONS
    // ============================================================

    function createNetwork(
        string calldata name,
        uint256[] calldata agentIds,
        uint256[] calldata roles
    ) external returns (bytes32 networkId);

    function hireNetwork(
        bytes32 networkId,
        bytes32 parentTaskId,
        uint256[] calldata stageBudgets,
        uint256[] calldata stageDeadlines
    ) external payable returns (bytes32 workflowId);

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getWorkflow(bytes32 workflowId) external view returns (Workflow memory);
    function getStage(bytes32 workflowId, uint256 stageIndex) external view returns (Stage memory);
    function getNetwork(bytes32 networkId) external view returns (AgentNetwork memory);
    function totalWorkflows() external view returns (uint256);
    function totalNetworks() external view returns (uint256);
}

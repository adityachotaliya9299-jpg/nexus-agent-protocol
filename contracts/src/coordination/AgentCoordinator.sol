// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentCoordinator} from "./IAgentCoordinator.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AgentCoordinator
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Multi-agent workflow orchestration — pipelines and parallel execution.
///
/// @dev PIPELINE FLOW:
///   Client creates workflow with N stages (agentIds, budgets, deadlines)
///   Stage 0 starts immediately → agent submits result → Stage 1 starts → ...
///   Each stage pays automatically on completion
///   If any stage fails → client can cancel remaining stages and get refund
///
/// @dev PARALLEL FLOW:
///   Client creates workflow with N parallel stages + 1 aggregator
///   All stages start simultaneously
///   Each parallel agent submits their result independently
///   When all N complete → aggregator gets their budget to merge results
///   Aggregator submits final merged result → workflow complete
///
/// @dev PAYMENT MODEL:
///   Total budget escrowed at creation
///   Each stage paid immediately on successful submitStageResult()
///   Unused budget refunded to client on cancel
contract AgentCoordinator is IAgentCoordinator, ReentrancyGuard {

    // ── Constants ────────────────────────────────────────────────

    uint256 public constant MAX_STAGES   = 10;
    uint256 public constant MIN_STAGES   = 2;
    uint256 public constant MAX_NETWORKS = 100;

    // ── Storage ──────────────────────────────────────────────────

    address public immutable protocolOwner;
    address public immutable registry;
    address public immutable reputationOracle;

    uint256 public override totalWorkflows;
    uint256 public override totalNetworks;

    mapping(bytes32 => Workflow)          private _workflows;
    mapping(bytes32 => Stage[])           private _stages;
    mapping(bytes32 => AgentNetwork)      private _networks;
    mapping(bytes32 => uint256[])         private _networkAgents;

    uint256 private _nonce;

    // ── Modifiers ────────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    // ── Constructor ───────────────────────────────────────────────

    constructor(address _protocolOwner, address _registry, address _reputationOracle) {
        if (_protocolOwner == address(0) || _registry == address(0)) revert ZeroAddress();
        protocolOwner    = _protocolOwner;
        registry         = _registry;
        reputationOracle = _reputationOracle;
    }

    // ── Create Pipeline ───────────────────────────────────────────

    function createPipeline(
        bytes32 parentTaskId,
        uint256[] calldata agentIds,
        uint256[] calldata stageBudgets,
        uint256[] calldata stageDeadlines,
        string[] calldata inputURIs
    ) external payable override nonReentrant returns (bytes32 workflowId) {
        _validateWorkflowInputs(agentIds, stageBudgets, stageDeadlines);
        if (inputURIs.length != agentIds.length) revert InvalidStageCount();

        uint256 totalBudget = _sumBudgets(stageBudgets);
        if (msg.value < totalBudget) revert InvalidBudget();

        workflowId = _generateId();

        _workflows[workflowId] = Workflow({
            workflowId:      workflowId,
            parentTaskId:    parentTaskId,
            client:          msg.sender,
            workflowType:    WorkflowType.PIPELINE,
            status:          WorkflowStatus.ACTIVE,
            totalStages:     agentIds.length,
            completedStages: 0,
            totalBudget:     totalBudget,
            createdAt:       block.timestamp,
            completedAt:     0,
            aggregatorAgentId: 0
        });

        // Create stages
        for (uint256 i = 0; i < agentIds.length; i++) {
            _stages[workflowId].push(Stage({
                stageIndex:    i,
                assignedAgentId: agentIds[i],
                inputURI:      inputURIs[i],
                outputURI:     "",
                reward:        stageBudgets[i],
                deadline:      stageDeadlines[i],
                status:        i == 0 ? StageStatus.ACTIVE : StageStatus.PENDING,
                proofId:       bytes32(0)
            }));
        }

        totalWorkflows++;
        emit WorkflowCreated(workflowId, WorkflowType.PIPELINE, agentIds.length);
        emit StageStarted(workflowId, 0, agentIds[0]);
    }

    // ── Create Parallel ───────────────────────────────────────────

    function createParallel(
        bytes32 parentTaskId,
        uint256[] calldata agentIds,
        uint256[] calldata stageBudgets,
        uint256[] calldata stageDeadlines,
        uint256 aggregatorAgentId,
        uint256 aggregatorBudget
    ) external payable override nonReentrant returns (bytes32 workflowId) {
        _validateWorkflowInputs(agentIds, stageBudgets, stageDeadlines);
        if (aggregatorAgentId == 0) revert AggregatorRequired(bytes32(0));

        uint256 totalBudget = _sumBudgets(stageBudgets) + aggregatorBudget;
        if (msg.value < totalBudget) revert InvalidBudget();

        workflowId = _generateId();

        _workflows[workflowId] = Workflow({
            workflowId:        workflowId,
            parentTaskId:      parentTaskId,
            client:            msg.sender,
            workflowType:      WorkflowType.PARALLEL,
            status:            WorkflowStatus.ACTIVE,
            totalStages:       agentIds.length + 1, // +1 for aggregator
            completedStages:   0,
            totalBudget:       totalBudget,
            createdAt:         block.timestamp,
            completedAt:       0,
            aggregatorAgentId: aggregatorAgentId
        });

        // All parallel stages start ACTIVE simultaneously
        for (uint256 i = 0; i < agentIds.length; i++) {
            _stages[workflowId].push(Stage({
                stageIndex:      i,
                assignedAgentId: agentIds[i],
                inputURI:        "",
                outputURI:       "",
                reward:          stageBudgets[i],
                deadline:        stageDeadlines[i],
                status:          StageStatus.ACTIVE,
                proofId:         bytes32(0)
            }));
            emit StageStarted(workflowId, i, agentIds[i]);
        }

        // Aggregator stage starts PENDING — activates when all others complete
        _stages[workflowId].push(Stage({
            stageIndex:      agentIds.length,
            assignedAgentId: aggregatorAgentId,
            inputURI:        "",
            outputURI:       "",
            reward:          aggregatorBudget,
            deadline:        stageDeadlines[stageDeadlines.length - 1] + 1 days,
            status:          StageStatus.PENDING,
            proofId:         bytes32(0)
        }));

        totalWorkflows++;
        emit WorkflowCreated(workflowId, WorkflowType.PARALLEL, agentIds.length + 1);
    }

    // ── Submit Stage Result ───────────────────────────────────────

    function submitStageResult(
        bytes32 workflowId,
        uint256 stageIndex,
        string calldata outputURI
    ) external override nonReentrant {
        Workflow storage wf = _workflows[workflowId];
        if (wf.createdAt == 0) revert WorkflowNotFound(workflowId);
        if (wf.status != WorkflowStatus.ACTIVE) revert WorkflowNotActive(workflowId);

        Stage storage stage = _stages[workflowId][stageIndex];
        if (stage.status != StageStatus.ACTIVE) revert StageNotActive(workflowId, stageIndex);
        if (block.timestamp > stage.deadline) revert DeadlinePassed(workflowId, stageIndex);

        // Verify caller owns the assigned agent
        IAgentRegistry.AgentProfile memory profile =
            IAgentRegistry(registry).getAgent(stage.assignedAgentId);
        if (profile.owner != msg.sender) revert NotAuthorized();

        stage.status    = StageStatus.COMPLETED;
        stage.outputURI = outputURI;
        wf.completedStages++;

        // Pay the stage agent
        _payAgent(profile.agentWallet != address(0) ? profile.agentWallet : profile.owner, stage.reward);

        // Update reputation
        _updateReputation(stage.assignedAgentId, workflowId);

        emit StageCompleted(workflowId, stageIndex, stage.assignedAgentId, outputURI);

        // Advance pipeline or activate aggregator
        if (wf.workflowType == WorkflowType.PIPELINE) {
            _advancePipeline(workflowId, wf, stageIndex);
        } else {
            _checkParallelComplete(workflowId, wf);
        }
    }

    // ── Fail Stage ────────────────────────────────────────────────

    function failStage(bytes32 workflowId, uint256 stageIndex) external override {
        Workflow storage wf = _workflows[workflowId];
        if (wf.createdAt == 0) revert WorkflowNotFound(workflowId);
        if (wf.status != WorkflowStatus.ACTIVE) revert WorkflowNotActive(workflowId);
        if (wf.client != msg.sender) revert NotAuthorized();

        Stage storage stage = _stages[workflowId][stageIndex];
        if (stage.status != StageStatus.ACTIVE) revert StageNotActive(workflowId, stageIndex);

        stage.status   = StageStatus.FAILED;
        wf.status      = WorkflowStatus.FAILED;

        emit StageFailed(workflowId, stageIndex, stage.assignedAgentId);
        emit WorkflowFailed(workflowId, stageIndex);
    }

    // ── Cancel Workflow ───────────────────────────────────────────

    function cancelWorkflow(bytes32 workflowId) external override nonReentrant {
        Workflow storage wf = _workflows[workflowId];
        if (wf.createdAt == 0) revert WorkflowNotFound(workflowId);
        if (wf.client != msg.sender && msg.sender != protocolOwner) revert NotAuthorized();
        if (wf.status != WorkflowStatus.ACTIVE) revert WorkflowNotActive(workflowId);

        wf.status = WorkflowStatus.CANCELLED;

        // Refund uncompleted stage budgets to client
        uint256 refund = 0;
        for (uint256 i = 0; i < _stages[workflowId].length; i++) {
            Stage storage s = _stages[workflowId][i];
            if (s.status == StageStatus.PENDING || s.status == StageStatus.ACTIVE) {
                refund += s.reward;
                s.status = StageStatus.SKIPPED;
            }
        }

        if (refund > 0) {
            (bool ok,) = payable(wf.client).call{value: refund}("");
            require(ok, "Refund failed");
        }
    }

    // ── Networks ──────────────────────────────────────────────────

    function createNetwork(
        string calldata name,
        uint256[] calldata agentIds,
        uint256[] calldata roles
    ) external override returns (bytes32 networkId) {
        require(agentIds.length > 1 && agentIds.length <= MAX_STAGES, "Invalid agent count");
        require(agentIds.length == roles.length, "Length mismatch");

        networkId = _generateId();

        _networks[networkId] = AgentNetwork({
            networkId:     networkId,
            name:          name,
            totalJobs:     0,
            successfulJobs: 0,
            createdAt:     block.timestamp,
            isActive:      true
        });

        for (uint256 i = 0; i < agentIds.length; i++) {
            _networkAgents[networkId].push(agentIds[i]);
        }

        totalNetworks++;
        emit NetworkCreated(networkId, name);
    }

    function hireNetwork(
        bytes32 networkId,
        bytes32 parentTaskId,
        uint256[] calldata stageBudgets,
        uint256[] calldata stageDeadlines
    ) external payable override nonReentrant returns (bytes32 workflowId) {
        AgentNetwork storage net = _networks[networkId];
        if (net.createdAt == 0) revert NetworkNotFound(networkId);
        if (!net.isActive) revert NetworkNotFound(networkId);

        uint256[] storage netAgents = _networkAgents[networkId];
        require(stageBudgets.length == netAgents.length, "Budget count mismatch");
        require(stageDeadlines.length == netAgents.length, "Deadline count mismatch");

        uint256 totalBudget = _sumBudgets(stageBudgets);
        if (msg.value < totalBudget) revert InvalidBudget();

        workflowId = _generateId();

        _workflows[workflowId] = Workflow({
            workflowId:        workflowId,
            parentTaskId:      parentTaskId,
            client:            msg.sender,
            workflowType:      WorkflowType.PIPELINE,
            status:            WorkflowStatus.ACTIVE,
            totalStages:       netAgents.length,
            completedStages:   0,
            totalBudget:       totalBudget,
            createdAt:         block.timestamp,
            completedAt:       0,
            aggregatorAgentId: 0
        });

        for (uint256 i = 0; i < netAgents.length; i++) {
            _stages[workflowId].push(Stage({
                stageIndex:      i,
                assignedAgentId: netAgents[i],
                inputURI:        "",
                outputURI:       "",
                reward:          stageBudgets[i],
                deadline:        stageDeadlines[i],
                status:          i == 0 ? StageStatus.ACTIVE : StageStatus.PENDING,
                proofId:         bytes32(0)
            }));
        }

        net.totalJobs++;
        totalWorkflows++;

        emit WorkflowCreated(workflowId, WorkflowType.PIPELINE, netAgents.length);
        emit StageStarted(workflowId, 0, netAgents[0]);
    }

    // ── View Functions ────────────────────────────────────────────

    function getWorkflow(bytes32 workflowId) external view override returns (Workflow memory) {
        if (_workflows[workflowId].createdAt == 0) revert WorkflowNotFound(workflowId);
        return _workflows[workflowId];
    }

    function getStage(bytes32 workflowId, uint256 stageIndex)
        external view override returns (Stage memory)
    {
        if (_workflows[workflowId].createdAt == 0) revert WorkflowNotFound(workflowId);
        return _stages[workflowId][stageIndex];
    }

    function getNetwork(bytes32 networkId) external view override returns (AgentNetwork memory) {
        if (_networks[networkId].createdAt == 0) revert NetworkNotFound(networkId);
        return _networks[networkId];
    }

    // ── Internal ─────────────────────────────────────────────────

    function _advancePipeline(bytes32 workflowId, Workflow storage wf, uint256 completedIndex)
        internal
    {
        uint256 nextIndex = completedIndex + 1;

        if (nextIndex >= wf.totalStages) {
            // All stages done
            wf.status      = WorkflowStatus.COMPLETED;
            wf.completedAt = block.timestamp;
            emit WorkflowCompleted(workflowId, wf.totalBudget);
        } else {
            // Activate next stage
            Stage storage next = _stages[workflowId][nextIndex];
            next.status = StageStatus.ACTIVE;
            // Use previous stage output as next stage input
            next.inputURI = _stages[workflowId][completedIndex].outputURI;
            emit StageStarted(workflowId, nextIndex, next.assignedAgentId);
        }
    }

    function _checkParallelComplete(bytes32 workflowId, Workflow storage wf) internal {
        uint256 parallelCount = wf.totalStages - 1; // last stage is aggregator

        // Check if all parallel stages are done
        bool allDone = true;
        for (uint256 i = 0; i < parallelCount; i++) {
            if (_stages[workflowId][i].status != StageStatus.COMPLETED) {
                allDone = false;
                break;
            }
        }

        if (allDone) {
            // Activate aggregator
            Stage storage agg = _stages[workflowId][parallelCount];
            agg.status = StageStatus.ACTIVE;
            emit StageStarted(workflowId, parallelCount, wf.aggregatorAgentId);
        }
    }

    function _payAgent(address recipient, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok,) = payable(recipient).call{value: amount}("");
        require(ok, "Payment failed");
    }

    function _updateReputation(uint256 agentId, bytes32 taskId) internal {
        try IReputationOracle(reputationOracle).updateReputation(
            agentId, IReputationOracle.UpdateReason.TASK_COMPLETED, taskId
        ) {} catch {}
    }

    function _validateWorkflowInputs(
        uint256[] calldata agentIds,
        uint256[] calldata budgets,
        uint256[] calldata deadlines
    ) internal pure {
        if (agentIds.length < MIN_STAGES || agentIds.length > MAX_STAGES) revert InvalidStageCount();
        if (budgets.length != agentIds.length || deadlines.length != agentIds.length) revert InvalidStageCount();
    }

    function _sumBudgets(uint256[] calldata budgets) internal pure returns (uint256 total) {
        for (uint256 i = 0; i < budgets.length; i++) total += budgets[i];
        if (total == 0) revert InvalidBudget();
    }

    function _generateId() internal returns (bytes32) {
        return keccak256(abi.encodePacked(msg.sender, _nonce++, block.timestamp));
    }
}

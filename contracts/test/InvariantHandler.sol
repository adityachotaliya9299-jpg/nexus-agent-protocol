// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TaskMarketplace} from "../src/marketplace/TaskMarketplace.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {ReputationOracle} from "../src/reputation/ReputationOracle.sol";
import {ITaskMarketplace} from "../src/interfaces/ITaskMarketplace.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

/// @title InvariantHandler
/// @notice Handler contract for Foundry invariant testing.
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @dev Foundry's invariant runner calls random handler functions and
///      then checks that protocol invariants hold after each call.
///
///      The handler:
///        1. Tracks ghost variables (protocol-level accounting)
///        2. Exposes bounded, valid action functions the fuzzer can call
///        3. Guards against revert paths so fuzzing doesn't get stuck
///
///      Ghost variables shadow on-chain state to let invariants
///      compare expected vs actual values without gas-expensive reads.
contract InvariantHandler is Test {

    // ============================================================
    //                       CONTRACTS
    // ============================================================

    TaskMarketplace public marketplace;
    AgentRegistry   public registry;
    ReputationOracle public oracle;

    // ============================================================
    //                    GHOST VARIABLES
    // ============================================================

    /// @notice Total ETH that should be held in escrow (posted - released)
    uint256 public ghost_escrowBalance;

    /// @notice Total ETH paid out to agents
    uint256 public ghost_totalPaidOut;

    /// @notice Total fees accumulated
    uint256 public ghost_totalFees;

    /// @notice Total tasks in OPEN state
    uint256 public ghost_openTasks;

    /// @notice Total tasks completed (COMPLETED or AGENT_WINS dispute)
    uint256 public ghost_completedTasks;

    /// @notice Total tasks cancelled
    uint256 public ghost_cancelledTasks;

    // ============================================================
    //                    ACTOR MANAGEMENT
    // ============================================================

    address[] public actors;
    address   public currentActor;

    bytes32[] public openTaskIds;
    bytes32[] public assignedTaskIds;
    bytes32[] public submittedTaskIds;

    uint256[] public registeredAgentIds;

    uint256 private constant NUM_ACTORS = 5;
    uint256 private _agentCounter;

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(
        TaskMarketplace _marketplace,
        AgentRegistry   _registry,
        ReputationOracle _oracle
    ) {
        marketplace = _marketplace;
        registry    = _registry;
        oracle      = _oracle;

        // Create actor pool
        for (uint256 i = 0; i < NUM_ACTORS; i++) {
            address actor = address(uint160(0x1000 + i));
            actors.push(actor);
            vm.deal(actor, 100 ether);
        }
    }

    // ============================================================
    //                      MODIFIERS
    // ============================================================

    modifier useActor(uint256 actorSeed) {
        currentActor = actors[actorSeed % actors.length];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    // ============================================================
    //                    HANDLER ACTIONS
    // ============================================================

    /// @notice Register an agent (if actor not already registered)
    function registerAgent(uint256 actorSeed, uint8 category) public useActor(actorSeed) {
        if (registry.isRegistered(currentActor)) return; // already registered

        category = category % 6; // bound to valid enum range
        string memory uri = string(abi.encodePacked("ipfs://Qm", vm.toString(++_agentCounter)));

        try registry.registerAgent(uri, IAgentRegistry.AgentCategory(category)) returns (uint256 agentId) {
            registeredAgentIds.push(agentId);
            // Initialize in reputation oracle
            try oracle.initializeAgent(agentId) {} catch {}
        } catch {}
    }

    /// @notice Post a task with bounded ETH value
    function postTask(
        uint256 actorSeed,
        uint256 rewardSeed,
        uint256 deadlineSeed,
        uint256 minRepSeed
    ) public useActor(actorSeed) {
        // Bound reward: 0.001 ETH to 1 ETH
        uint256 reward = bound(rewardSeed, 0.001 ether, 1 ether);
        // Bound deadline: MIN_DEADLINE to 30 days
        uint256 deadline = block.timestamp + bound(deadlineSeed, 1 hours, 30 days);
        // Bound minRep: 0 to 9000
        uint256 minRep = bound(minRepSeed, 0, 9000);

        if (currentActor.balance < reward) return;

        try marketplace.postTask{value: reward}(
            "ipfs://QmTaskMetadata",
            deadline,
            minRep
        ) returns (bytes32 taskId) {
            openTaskIds.push(taskId);
            ghost_escrowBalance += reward;
            ghost_openTasks++;
        } catch {}
    }

    /// @notice Submit a bid on a random open task
    function submitBid(uint256 actorSeed, uint256 taskSeed, uint256 agentSeed) public useActor(actorSeed) {
        if (openTaskIds.length == 0) return;
        if (registeredAgentIds.length == 0) return;

        bytes32 taskId = openTaskIds[taskSeed % openTaskIds.length];
        uint256 agentId = registeredAgentIds[agentSeed % registeredAgentIds.length];

        // Check agent is owned by currentActor
        try registry.getAgent(agentId) returns (IAgentRegistry.AgentProfile memory profile) {
            if (profile.owner != currentActor) return;
        } catch { return; }

        try marketplace.submitBid(taskId, agentId, "ipfs://QmProposal", 1 days) {} catch {}
    }

    /// @notice Assign an agent to a random open task
    function assignAgent(uint256 actorSeed, uint256 taskSeed, uint256 agentSeed) public useActor(actorSeed) {
        if (openTaskIds.length == 0) return;
        if (registeredAgentIds.length == 0) return;

        bytes32 taskId = openTaskIds[taskSeed % openTaskIds.length];
        uint256 agentId = registeredAgentIds[agentSeed % registeredAgentIds.length];

        try marketplace.assignAgent(taskId, agentId) {
            // Move task from open to assigned tracking
            _removeFromOpen(taskId);
            assignedTaskIds.push(taskId);
            ghost_openTasks = ghost_openTasks > 0 ? ghost_openTasks - 1 : 0;
        } catch {}
    }

    /// @notice Agent submits work on assigned task
    function submitWork(uint256 actorSeed, uint256 taskSeed) public useActor(actorSeed) {
        if (assignedTaskIds.length == 0) return;

        bytes32 taskId = assignedTaskIds[taskSeed % assignedTaskIds.length];

        // Get assigned agent ID
        try marketplace.getTask(taskId) returns (ITaskMarketplace.Task memory task) {
            try marketplace.submitWork(taskId, task.assignedAgentId, "ipfs://QmResult") {
                _removeFromAssigned(taskId);
                submittedTaskIds.push(taskId);
            } catch {}
        } catch {}
    }

    /// @notice Client approves submitted work
    function approveWork(uint256 actorSeed, uint256 taskSeed) public useActor(actorSeed) {
        if (submittedTaskIds.length == 0) return;

        bytes32 taskId = submittedTaskIds[taskSeed % submittedTaskIds.length];

        try marketplace.getTask(taskId) returns (ITaskMarketplace.Task memory task) {
            uint256 reward = task.reward;
            uint256 fee = task.platformFee;

            try marketplace.approveWork(taskId) {
                _removeFromSubmitted(taskId);
                ghost_escrowBalance = ghost_escrowBalance >= reward ? ghost_escrowBalance - reward : 0;
                ghost_totalPaidOut += reward - fee;
                ghost_totalFees += fee;
                ghost_completedTasks++;
            } catch {}
        } catch {}
    }

    /// @notice Client cancels an open task
    function cancelTask(uint256 actorSeed, uint256 taskSeed) public useActor(actorSeed) {
        if (openTaskIds.length == 0) return;

        bytes32 taskId = openTaskIds[taskSeed % openTaskIds.length];

        try marketplace.getTask(taskId) returns (ITaskMarketplace.Task memory task) {
            uint256 reward = task.reward;
            try marketplace.cancelTask(taskId) {
                _removeFromOpen(taskId);
                ghost_escrowBalance = ghost_escrowBalance >= reward ? ghost_escrowBalance - reward : 0;
                ghost_openTasks = ghost_openTasks > 0 ? ghost_openTasks - 1 : 0;
                ghost_cancelledTasks++;
            } catch {}
        } catch {}
    }

    // ============================================================
    //                    HELPER FUNCTIONS
    // ============================================================

    function _removeFromOpen(bytes32 taskId) internal {
        for (uint256 i = 0; i < openTaskIds.length; i++) {
            if (openTaskIds[i] == taskId) {
                openTaskIds[i] = openTaskIds[openTaskIds.length - 1];
                openTaskIds.pop();
                return;
            }
        }
    }

    function _removeFromAssigned(bytes32 taskId) internal {
        for (uint256 i = 0; i < assignedTaskIds.length; i++) {
            if (assignedTaskIds[i] == taskId) {
                assignedTaskIds[i] = assignedTaskIds[assignedTaskIds.length - 1];
                assignedTaskIds.pop();
                return;
            }
        }
    }

    function _removeFromSubmitted(bytes32 taskId) internal {
        for (uint256 i = 0; i < submittedTaskIds.length; i++) {
            if (submittedTaskIds[i] == taskId) {
                submittedTaskIds[i] = submittedTaskIds[submittedTaskIds.length - 1];
                submittedTaskIds.pop();
                return;
            }
        }
    }

    // ============================================================
    //                    VIEW HELPERS FOR INVARIANTS
    // ============================================================

    function getOpenTaskCount() external view returns (uint256) {
        return openTaskIds.length;
    }

    function getSubmittedTaskCount() external view returns (uint256) {
        return submittedTaskIds.length;
    }

    function getRegisteredAgentCount() external view returns (uint256) {
        return registeredAgentIds.length;
    }
}

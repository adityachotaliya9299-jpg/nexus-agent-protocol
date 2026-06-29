// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AgentComposability} from "../src/composability/AgentComposability.sol";
import {IAgentComposability} from "../src/composability/IAgentComposability.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../src/interfaces/IReputationOracle.sol";

// ── Stubs ──────────────────────────────────────────────────────

contract MockRegistry {
    struct Agent { address owner; address wallet; bool exists; }
    mapping(uint256 => Agent) public agents;

    function addAgent(uint256 id, address owner, address wallet) external {
        agents[id] = Agent(owner, wallet, true);
    }

    function getAgent(uint256 id) external view returns (IAgentRegistry.AgentProfile memory p) {
        Agent storage a = agents[id];
        require(a.exists, "AgentNotFound");
        p.agentId     = id;
        p.owner       = a.owner;
        p.agentWallet = a.wallet;
        return p;
    }
}

contract MockOracle {
    uint256 public updateCount;
    function updateReputation(uint256, IReputationOracle.UpdateReason, bytes32) external {
        updateCount++;
    }
    function getScore(uint256) external pure returns (uint256) { return 5000; }
}

// ── Tests ──────────────────────────────────────────────────────

contract AgentComposabilityTest is Test {
    AgentComposability internal comp;
    MockRegistry       internal registry;
    MockOracle         internal oracle;

    address constant OWNER        = address(0xA11CE);
    address constant PARENT_OWN   = address(0xDA3E4);
    address constant PARENT_WALL  = address(0xDEA11);
    address constant SUB_OWN      = address(0x5B0E4);
    address constant SUB_WALL     = address(0x5BAA1);
    address constant STRANGER     = address(0x577A4);

    uint256 constant PARENT_ID    = 1;
    uint256 constant SUB_ID       = 2;
    uint256 constant SUB_ID_2     = 3;
    bytes32 constant PARENT_TASK  = bytes32(uint256(0xBEEF));

    uint256 constant REWARD       = 0.1 ether;
    uint256 constant SPLIT_BPS    = 8000; // 80% to sub-agent
    uint256 constant DEADLINE_1D  = 1 days;

    function setUp() public {
        registry = new MockRegistry();
        oracle   = new MockOracle();

        vm.prank(OWNER);
        comp = new AgentComposability(OWNER, address(registry), address(oracle));

        registry.addAgent(PARENT_ID, PARENT_OWN, PARENT_WALL);
        registry.addAgent(SUB_ID,    SUB_OWN,    SUB_WALL);
        registry.addAgent(SUB_ID_2,  STRANGER,   address(0));

        vm.deal(PARENT_OWN,  10 ether);
        vm.deal(SUB_OWN,     1 ether);
        vm.deal(STRANGER,    1 ether);
    }

    // ── Helper ────────────────────────────────────────────────────

    function _createSubTask() internal returns (bytes32 subTaskId) {
        vm.prank(PARENT_OWN);
        return comp.createSubTask{value: REWARD}(
            PARENT_TASK,
            PARENT_ID,
            "ipfs://QmSubTask",
            block.timestamp + DEADLINE_1D,
            SPLIT_BPS
        );
    }

    function _fullCycle() internal returns (bytes32 subTaskId) {
        subTaskId = _createSubTask();

        vm.prank(PARENT_OWN);
        comp.assignSubAgent(subTaskId, SUB_ID);

        vm.prank(SUB_OWN);
        comp.submitSubWork(subTaskId, SUB_ID, "ipfs://QmResult");
    }

    // ── Deployment ───────────────────────────────────────────────

    function test_Deploy_OwnerSet() public view {
        assertEq(comp.protocolOwner(), OWNER);
    }

    function test_Deploy_ZeroSubTasks() public view {
        assertEq(comp.totalSubTasks(), 0);
    }

    function test_Deploy_ZeroAddress_Reverts() public {
        vm.expectRevert(IAgentComposability.ZeroAddress.selector);
        new AgentComposability(address(0), address(registry), address(oracle));
    }

    // ── Create sub-task ──────────────────────────────────────────

    function test_CreateSubTask_Success() public {
        bytes32 id = _createSubTask();
        IAgentComposability.SubTask memory st = comp.getSubTask(id);

        assertEq(st.reward, REWARD);
        assertEq(st.parentAgentId, PARENT_ID);
        assertEq(st.splitBps, SPLIT_BPS);
        assertEq(uint256(st.status), uint256(IAgentComposability.SubTaskStatus.OPEN));
    }

    function test_CreateSubTask_EmitsEvent() public {
        vm.expectEmit(false, true, true, false);
        emit IAgentComposability.SubTaskCreated(bytes32(0), PARENT_TASK, PARENT_ID, REWARD, 0);
        _createSubTask();
    }

    function test_CreateSubTask_EscrowsETH() public {
        uint256 balBefore = address(comp).balance;
        _createSubTask();
        assertEq(address(comp).balance, balBefore + REWARD);
    }

    function test_CreateSubTask_IncrementsTotalCount() public {
        _createSubTask();
        assertEq(comp.totalSubTasks(), 1);
    }

    function test_CreateSubTask_TracksParentTasks() public {
        bytes32 id = _createSubTask();
        bytes32[] memory tasks = comp.getParentSubTasks(PARENT_ID);
        assertEq(tasks.length, 1);
        assertEq(tasks[0], id);
    }

    function test_CreateSubTask_ZeroValue_Reverts() public {
        vm.prank(PARENT_OWN);
        vm.expectRevert(IAgentComposability.ZeroAmount.selector);
        comp.createSubTask{value: 0}(PARENT_TASK, PARENT_ID, "ipfs://Qm", block.timestamp + 1 days, 5000);
    }

    function test_CreateSubTask_InvalidSplit_Low_Reverts() public {
        vm.prank(PARENT_OWN);
        vm.expectRevert(IAgentComposability.InvalidSplit.selector);
        comp.createSubTask{value: REWARD}(PARENT_TASK, PARENT_ID, "ipfs://Qm", block.timestamp + 1 days, 50);
    }

    function test_CreateSubTask_InvalidSplit_High_Reverts() public {
        vm.prank(PARENT_OWN);
        vm.expectRevert(IAgentComposability.InvalidSplit.selector);
        comp.createSubTask{value: REWARD}(PARENT_TASK, PARENT_ID, "ipfs://Qm", block.timestamp + 1 days, 9001);
    }

    function test_CreateSubTask_DeadlineTooSoon_Reverts() public {
        vm.prank(PARENT_OWN);
        vm.expectRevert(IAgentComposability.InvalidDeadline.selector);
        comp.createSubTask{value: REWARD}(PARENT_TASK, PARENT_ID, "ipfs://Qm", block.timestamp + 30 minutes, 5000);
    }

    function test_CreateSubTask_NotOwner_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(IAgentComposability.NotAuthorized.selector);
        comp.createSubTask{value: REWARD}(PARENT_TASK, PARENT_ID, "ipfs://Qm", block.timestamp + 1 days, 5000);
    }

    // ── Assign sub-agent ─────────────────────────────────────────

    function test_AssignSubAgent_Success() public {
        bytes32 id = _createSubTask();
        vm.prank(PARENT_OWN);
        comp.assignSubAgent(id, SUB_ID);

        IAgentComposability.SubTask memory st = comp.getSubTask(id);
        assertEq(uint256(st.status), uint256(IAgentComposability.SubTaskStatus.ASSIGNED));
        assertEq(st.subAgentId, SUB_ID);
    }

    function test_AssignSubAgent_EmitsEvent() public {
        bytes32 id = _createSubTask();
        vm.expectEmit(true, true, false, false);
        emit IAgentComposability.SubTaskAssigned(id, SUB_ID);
        vm.prank(PARENT_OWN);
        comp.assignSubAgent(id, SUB_ID);
    }

    function test_AssignSubAgent_TracksSubAgentTasks() public {
        bytes32 id = _createSubTask();
        vm.prank(PARENT_OWN);
        comp.assignSubAgent(id, SUB_ID);

        bytes32[] memory tasks = comp.getSubAgentTasks(SUB_ID);
        assertEq(tasks.length, 1);
        assertEq(tasks[0], id);
    }

    function test_AssignSubAgent_InitializesRelationship() public {
        bytes32 id = _createSubTask();
        vm.prank(PARENT_OWN);
        comp.assignSubAgent(id, SUB_ID);

        IAgentComposability.AgentRelationship memory rel =
            comp.getAgentRelationship(PARENT_ID, SUB_ID);
        assertEq(rel.parentAgentId, PARENT_ID);
        assertEq(rel.subAgentId, SUB_ID);
        assertEq(rel.totalSubTasksGiven, 1);
        assertGt(rel.firstCollabAt, 0);
    }

    function test_AssignSubAgent_CannotHireSelf_Reverts() public {
        bytes32 id = _createSubTask();
        vm.prank(PARENT_OWN);
        vm.expectRevert(abi.encodeWithSelector(IAgentComposability.CannotHireSelf.selector, PARENT_ID));
        comp.assignSubAgent(id, PARENT_ID);
    }

    function test_AssignSubAgent_NotParentOwner_Reverts() public {
        bytes32 id = _createSubTask();
        vm.prank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(IAgentComposability.ParentAgentOnly.selector, id));
        comp.assignSubAgent(id, SUB_ID);
    }

    function test_AssignSubAgent_AfterDeadline_Reverts() public {
        bytes32 id = _createSubTask();
        vm.warp(block.timestamp + DEADLINE_1D + 1);
        vm.prank(PARENT_OWN);
        vm.expectRevert(abi.encodeWithSelector(IAgentComposability.DeadlinePassed.selector, id));
        comp.assignSubAgent(id, SUB_ID);
    }

    // ── Submit sub-work ──────────────────────────────────────────

    function test_SubmitSubWork_Success() public {
        bytes32 id = _createSubTask();
        vm.prank(PARENT_OWN);
        comp.assignSubAgent(id, SUB_ID);

        vm.prank(SUB_OWN);
        comp.submitSubWork(id, SUB_ID, "ipfs://QmResult");

        IAgentComposability.SubTask memory st = comp.getSubTask(id);
        assertEq(uint256(st.status), uint256(IAgentComposability.SubTaskStatus.SUBMITTED));
        assertEq(st.resultURI, "ipfs://QmResult");
    }

    function test_SubmitSubWork_EmitsEvent() public {
        bytes32 id = _createSubTask();
        vm.prank(PARENT_OWN);
        comp.assignSubAgent(id, SUB_ID);

        vm.expectEmit(true, true, false, true);
        emit IAgentComposability.SubTaskSubmitted(id, SUB_ID, "ipfs://QmResult");
        vm.prank(SUB_OWN);
        comp.submitSubWork(id, SUB_ID, "ipfs://QmResult");
    }

    function test_SubmitSubWork_WrongAgent_Reverts() public {
        bytes32 id = _createSubTask();
        vm.prank(PARENT_OWN);
        comp.assignSubAgent(id, SUB_ID);

        vm.prank(STRANGER);
        vm.expectRevert(IAgentComposability.NotAuthorized.selector);
        comp.submitSubWork(id, SUB_ID_2, "ipfs://QmResult");
    }

    function test_SubmitSubWork_NotAssigned_Reverts() public {
        bytes32 id = _createSubTask();
        vm.prank(SUB_OWN);
        vm.expectRevert(abi.encodeWithSelector(IAgentComposability.SubTaskNotAssigned.selector, id));
        comp.submitSubWork(id, SUB_ID, "ipfs://QmResult");
    }

    // ── Approve sub-work ─────────────────────────────────────────

    function test_ApproveSubWork_Success() public {
        bytes32 id = _fullCycle();
        vm.prank(PARENT_OWN);
        comp.approveSubWork(id);

        IAgentComposability.SubTask memory st = comp.getSubTask(id);
        assertEq(uint256(st.status), uint256(IAgentComposability.SubTaskStatus.COMPLETED));
        assertGt(st.completedAt, 0);
    }

    function test_ApproveSubWork_PaysSubAgentWallet() public {
        bytes32 id = _fullCycle();
        uint256 balBefore = SUB_WALL.balance;

        vm.prank(PARENT_OWN);
        comp.approveSubWork(id);

        assertEq(SUB_WALL.balance, balBefore + REWARD);
    }

    function test_ApproveSubWork_EmitsPaymentEvent() public {
        bytes32 id = _fullCycle();
        vm.expectEmit(true, true, false, true);
        emit IAgentComposability.SubAgentPaid(PARENT_ID, SUB_ID, REWARD);
        vm.prank(PARENT_OWN);
        comp.approveSubWork(id);
    }

    function test_ApproveSubWork_UpdatesReputation() public {
        bytes32 id = _fullCycle();
        uint256 countBefore = oracle.updateCount();

        vm.prank(PARENT_OWN);
        comp.approveSubWork(id);

        assertEq(oracle.updateCount(), countBefore + 1);
    }

    function test_ApproveSubWork_UpdatesRelationship() public {
        bytes32 id = _fullCycle();
        vm.prank(PARENT_OWN);
        comp.approveSubWork(id);

        IAgentComposability.AgentRelationship memory rel =
            comp.getAgentRelationship(PARENT_ID, SUB_ID);
        assertEq(rel.totalSubTasksCompleted, 1);
        assertEq(rel.totalEthPaid, REWARD);
    }

    function test_ApproveSubWork_FallsBackToOwner_IfNoWallet() public {
        bytes32 id;
        // Create sub-task for SUB_ID_2 (no wallet set)
        vm.prank(PARENT_OWN);
        id = comp.createSubTask{value: REWARD}(
            PARENT_TASK, PARENT_ID, "ipfs://Qm", block.timestamp + DEADLINE_1D, SPLIT_BPS
        );

        vm.prank(PARENT_OWN);
        comp.assignSubAgent(id, SUB_ID_2);

        vm.prank(STRANGER);
        comp.submitSubWork(id, SUB_ID_2, "ipfs://QmResult");

        uint256 balBefore = STRANGER.balance;
        vm.prank(PARENT_OWN);
        comp.approveSubWork(id);

        // Payment falls back to owner (STRANGER) since no wallet
        assertEq(STRANGER.balance, balBefore + REWARD);
    }

    function test_ApproveSubWork_NotParent_Reverts() public {
        bytes32 id = _fullCycle();
        vm.prank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(IAgentComposability.ParentAgentOnly.selector, id));
        comp.approveSubWork(id);
    }

    function test_ApproveSubWork_NotSubmitted_Reverts() public {
        bytes32 id = _createSubTask();
        vm.prank(PARENT_OWN);
        vm.expectRevert(abi.encodeWithSelector(IAgentComposability.SubTaskNotSubmitted.selector, id));
        comp.approveSubWork(id);
    }

    // ── Cancel sub-task ──────────────────────────────────────────

    function test_CancelSubTask_RefundsToParentWallet() public {
        bytes32 id = _createSubTask();
        uint256 balBefore = PARENT_WALL.balance;

        vm.prank(PARENT_OWN);
        comp.cancelSubTask(id);

        assertEq(PARENT_WALL.balance, balBefore + REWARD);
    }

    function test_CancelSubTask_EmitsEvent() public {
        bytes32 id = _createSubTask();
        vm.expectEmit(true, false, false, false);
        emit IAgentComposability.SubTaskCancelled(id);
        vm.prank(PARENT_OWN);
        comp.cancelSubTask(id);
    }

    function test_CancelSubTask_NotOpen_Reverts() public {
        bytes32 id = _createSubTask();
        vm.prank(PARENT_OWN);
        comp.assignSubAgent(id, SUB_ID); // now ASSIGNED

        vm.prank(PARENT_OWN);
        vm.expectRevert(abi.encodeWithSelector(IAgentComposability.SubTaskNotOpen.selector, id));
        comp.cancelSubTask(id);
    }

    function test_CancelSubTask_NotParent_Reverts() public {
        bytes32 id = _createSubTask();
        vm.prank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(IAgentComposability.ParentAgentOnly.selector, id));
        comp.cancelSubTask(id);
    }

    // ── Multiple sub-tasks ───────────────────────────────────────

    function test_MultipleSubTasks_IndependentState() public {
        bytes32 id1 = _createSubTask();
        bytes32 id2;
        vm.prank(PARENT_OWN);
        id2 = comp.createSubTask{value: REWARD}(
            PARENT_TASK, PARENT_ID, "ipfs://Qm2", block.timestamp + DEADLINE_1D, 5000
        );

        assertFalse(id1 == id2);
        assertEq(comp.totalSubTasks(), 2);

        // Cancel id1 without affecting id2
        vm.prank(PARENT_OWN);
        comp.cancelSubTask(id1);

        assertEq(uint256(comp.getSubTask(id1).status), uint256(IAgentComposability.SubTaskStatus.CANCELLED));
        assertEq(uint256(comp.getSubTask(id2).status), uint256(IAgentComposability.SubTaskStatus.OPEN));
    }

    function test_RelationshipAccumulates_AcrossSubTasks() public {
        // First sub-task
        bytes32 id1 = _fullCycle();
        vm.prank(PARENT_OWN);
        comp.approveSubWork(id1);

        // Second sub-task with same agents
        bytes32 id2;
        vm.prank(PARENT_OWN);
        id2 = comp.createSubTask{value: REWARD}(
            PARENT_TASK, PARENT_ID, "ipfs://Qm2", block.timestamp + DEADLINE_1D, SPLIT_BPS
        );
        vm.prank(PARENT_OWN);
        comp.assignSubAgent(id2, SUB_ID);
        vm.prank(SUB_OWN);
        comp.submitSubWork(id2, SUB_ID, "ipfs://QmResult2");
        vm.prank(PARENT_OWN);
        comp.approveSubWork(id2);

        IAgentComposability.AgentRelationship memory rel =
            comp.getAgentRelationship(PARENT_ID, SUB_ID);
        assertEq(rel.totalSubTasksGiven, 2);
        assertEq(rel.totalSubTasksCompleted, 2);
        assertEq(rel.totalEthPaid, REWARD * 2);
    }

    // ── Fuzz tests ───────────────────────────────────────────────

    function testFuzz_CreateSubTask_SplitBounds(uint256 splitBps) public {
        splitBps = bound(splitBps, 100, 9000);
        vm.prank(PARENT_OWN);
        bytes32 id = comp.createSubTask{value: REWARD}(
            PARENT_TASK, PARENT_ID, "ipfs://Qm", block.timestamp + DEADLINE_1D, splitBps
        );
        assertEq(comp.getSubTask(id).splitBps, splitBps);
    }

    function testFuzz_ETH_Conservation(uint96 reward) public {
        vm.assume(reward >= 0.001 ether);
        vm.deal(PARENT_OWN, reward);

        bytes32 id;
        vm.prank(PARENT_OWN);
        id = comp.createSubTask{value: reward}(
            PARENT_TASK, PARENT_ID, "ipfs://Qm", block.timestamp + DEADLINE_1D, 8000
        );

        // Cancel and verify full refund
        uint256 walletBefore = PARENT_WALL.balance;
        vm.prank(PARENT_OWN);
        comp.cancelSubTask(id);

        assertEq(PARENT_WALL.balance, walletBefore + reward);
        assertEq(address(comp).balance, 0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentCoordinator} from "../src/coordination/AgentCoordinator.sol";
import {IAgentCoordinator} from "../src/coordination/IAgentCoordinator.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../src/interfaces/IReputationOracle.sol";

// ── Stubs ──────────────────────────────────────────────────────

contract MockRegistry {
    mapping(uint256 => address) public owners;
    mapping(uint256 => address) public wallets;
    mapping(uint256 => bool)    public exists;

    function addAgent(uint256 id, address owner, address wallet) external {
        owners[id] = owner; wallets[id] = wallet; exists[id] = true;
    }

    function getAgent(uint256 id) external view returns (IAgentRegistry.AgentProfile memory p) {
        require(exists[id], "not found");
        p.agentId = id; p.owner = owners[id]; p.agentWallet = wallets[id];
        return p;
    }
}

contract MockOracle {
    function updateReputation(uint256, IReputationOracle.UpdateReason, bytes32) external {}
    function getScore(uint256) external pure returns (uint256) { return 5000; }
}

// ── Tests ──────────────────────────────────────────────────────

contract AgentCoordinatorTest is Test {
    AgentCoordinator internal coord;
    MockRegistry     internal registry;
    MockOracle       internal oracle;

    address constant OWNER   = address(0xA11CE);
    address constant CLIENT  = address(0xC11E4);

    address constant A1_OWNER = address(0xA001);
    address constant A2_OWNER = address(0xA002);
    address constant A3_OWNER = address(0xA003);
    address constant AGG_OWNER = address(0xA004);

    address payable constant A1_WALL  = payable(address(0xW001));
    address payable constant A2_WALL  = payable(address(0xW002));
    address payable constant A3_WALL  = payable(address(0xW003));
    address payable constant AGG_WALL = payable(address(0xW004));

    uint256 constant A1  = 1;
    uint256 constant A2  = 2;
    uint256 constant A3  = 3;
    uint256 constant AGG = 4;

    bytes32 constant PARENT_TASK = bytes32(uint256(0xBEEF));

    function setUp() public {
        registry = new MockRegistry();
        oracle   = new MockOracle();

        registry.addAgent(A1,  A1_OWNER,  A1_WALL);
        registry.addAgent(A2,  A2_OWNER,  A2_WALL);
        registry.addAgent(A3,  A3_OWNER,  A3_WALL);
        registry.addAgent(AGG, AGG_OWNER, AGG_WALL);

        vm.prank(OWNER);
        coord = new AgentCoordinator(OWNER, address(registry), address(oracle));

        vm.deal(CLIENT,   10 ether);
        vm.deal(A1_OWNER, 1 ether);
        vm.deal(A2_OWNER, 1 ether);
        vm.deal(A3_OWNER, 1 ether);
    }

    // ── Helpers ───────────────────────────────────────────────────

    function _pipelineAgents() internal pure returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](3);
        ids[0] = A1; ids[1] = A2; ids[2] = A3;
        return ids;
    }

    function _budgets() internal pure returns (uint256[] memory) {
        uint256[] memory b = new uint256[](3);
        b[0] = 0.1 ether; b[1] = 0.2 ether; b[2] = 0.3 ether;
        return b;
    }

    function _deadlines() internal view returns (uint256[] memory) {
        uint256[] memory d = new uint256[](3);
        d[0] = block.timestamp + 1 days;
        d[1] = block.timestamp + 2 days;
        d[2] = block.timestamp + 3 days;
        return d;
    }

    function _inputs() internal pure returns (string[] memory) {
        string[] memory s = new string[](3);
        s[0] = "ipfs://input0"; s[1] = ""; s[2] = "";
        return s;
    }

    function _createPipeline() internal returns (bytes32) {
        vm.prank(CLIENT);
        return coord.createPipeline{value: 0.6 ether}(
            PARENT_TASK, _pipelineAgents(), _budgets(), _deadlines(), _inputs()
        );
    }

    // ── Pipeline: creation ────────────────────────────────────────

    function test_CreatePipeline_Success() public {
        bytes32 id = _createPipeline();
        IAgentCoordinator.Workflow memory wf = coord.getWorkflow(id);

        assertEq(wf.totalStages, 3);
        assertEq(wf.completedStages, 0);
        assertEq(wf.totalBudget, 0.6 ether);
        assertEq(uint256(wf.status), uint256(IAgentCoordinator.WorkflowStatus.ACTIVE));
        assertEq(uint256(wf.workflowType), uint256(IAgentCoordinator.WorkflowType.PIPELINE));
    }

    function test_CreatePipeline_EmitsEvent() public {
        vm.expectEmit(false, false, false, true);
        emit IAgentCoordinator.WorkflowCreated(bytes32(0), IAgentCoordinator.WorkflowType.PIPELINE, 3);
        _createPipeline();
    }

    function test_CreatePipeline_FirstStageActive() public {
        bytes32 id = _createPipeline();
        assertEq(uint256(coord.getStage(id, 0).status), uint256(IAgentCoordinator.StageStatus.ACTIVE));
        assertEq(uint256(coord.getStage(id, 1).status), uint256(IAgentCoordinator.StageStatus.PENDING));
        assertEq(uint256(coord.getStage(id, 2).status), uint256(IAgentCoordinator.StageStatus.PENDING));
    }

    function test_CreatePipeline_InsufficientBudget_Reverts() public {
        vm.prank(CLIENT);
        vm.expectRevert(IAgentCoordinator.InvalidBudget.selector);
        coord.createPipeline{value: 0.1 ether}( // less than 0.6 required
            PARENT_TASK, _pipelineAgents(), _budgets(), _deadlines(), _inputs()
        );
    }

    function test_CreatePipeline_TooFewStages_Reverts() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = A1;
        uint256[] memory b   = new uint256[](1); b[0] = 0.1 ether;
        uint256[] memory d   = new uint256[](1); d[0] = block.timestamp + 1 days;
        string[]  memory inp = new string[](1);  inp[0] = "";

        vm.prank(CLIENT);
        vm.expectRevert(IAgentCoordinator.InvalidStageCount.selector);
        coord.createPipeline{value: 0.1 ether}(PARENT_TASK, ids, b, d, inp);
    }

    // ── Pipeline: stage submission ────────────────────────────────

    function test_SubmitStageResult_Stage0_PayAgent() public {
        bytes32 id = _createPipeline();
        uint256 balBefore = A1_WALL.balance;

        vm.prank(A1_OWNER);
        coord.submitStageResult(id, 0, "ipfs://output0");

        assertEq(A1_WALL.balance, balBefore + 0.1 ether);
    }

    function test_SubmitStageResult_Stage0_ActivatesStage1() public {
        bytes32 id = _createPipeline();

        vm.prank(A1_OWNER);
        coord.submitStageResult(id, 0, "ipfs://output0");

        assertEq(uint256(coord.getStage(id, 0).status), uint256(IAgentCoordinator.StageStatus.COMPLETED));
        assertEq(uint256(coord.getStage(id, 1).status), uint256(IAgentCoordinator.StageStatus.ACTIVE));
        // Stage 1 input = stage 0 output
        assertEq(coord.getStage(id, 1).inputURI, "ipfs://output0");
    }

    function test_SubmitStageResult_EmitsEvent() public {
        bytes32 id = _createPipeline();
        vm.expectEmit(true, false, false, false);
        emit IAgentCoordinator.StageCompleted(id, 0, A1, "ipfs://output0");
        vm.prank(A1_OWNER);
        coord.submitStageResult(id, 0, "ipfs://output0");
    }

    function test_SubmitStageResult_NotOwner_Reverts() public {
        bytes32 id = _createPipeline();
        vm.prank(address(0x9999));
        vm.expectRevert(IAgentCoordinator.NotAuthorized.selector);
        coord.submitStageResult(id, 0, "ipfs://output0");
    }

    function test_SubmitStageResult_WrongStage_Reverts() public {
        bytes32 id = _createPipeline();
        // Stage 1 is still PENDING
        vm.prank(A2_OWNER);
        vm.expectRevert(abi.encodeWithSelector(IAgentCoordinator.StageNotActive.selector, id, 1));
        coord.submitStageResult(id, 1, "ipfs://output1");
    }

    // ── Pipeline: full completion ─────────────────────────────────

    function test_Pipeline_FullCompletion() public {
        bytes32 id = _createPipeline();

        vm.prank(A1_OWNER);
        coord.submitStageResult(id, 0, "ipfs://out0");

        vm.prank(A2_OWNER);
        coord.submitStageResult(id, 1, "ipfs://out1");

        vm.prank(A3_OWNER);
        coord.submitStageResult(id, 2, "ipfs://out2");

        IAgentCoordinator.Workflow memory wf = coord.getWorkflow(id);
        assertEq(uint256(wf.status), uint256(IAgentCoordinator.WorkflowStatus.COMPLETED));
        assertEq(wf.completedStages, 3);
        assertGt(wf.completedAt, 0);
    }

    function test_Pipeline_AllAgentsPaid() public {
        bytes32 id = _createPipeline();

        uint256 b1 = A1_WALL.balance;
        uint256 b2 = A2_WALL.balance;
        uint256 b3 = A3_WALL.balance;

        vm.prank(A1_OWNER); coord.submitStageResult(id, 0, "o0");
        vm.prank(A2_OWNER); coord.submitStageResult(id, 1, "o1");
        vm.prank(A3_OWNER); coord.submitStageResult(id, 2, "o2");

        assertEq(A1_WALL.balance, b1 + 0.1 ether);
        assertEq(A2_WALL.balance, b2 + 0.2 ether);
        assertEq(A3_WALL.balance, b3 + 0.3 ether);
    }

    // ── Parallel workflow ─────────────────────────────────────────

    function _createParallel() internal returns (bytes32) {
        uint256[] memory ids = new uint256[](2); ids[0] = A1; ids[1] = A2;
        uint256[] memory b   = new uint256[](2); b[0] = 0.1 ether; b[1] = 0.2 ether;
        uint256[] memory d   = new uint256[](2); d[0] = block.timestamp + 1 days; d[1] = block.timestamp + 1 days;

        vm.prank(CLIENT);
        return coord.createParallel{value: 0.4 ether}(
            PARENT_TASK, ids, b, d, AGG, 0.1 ether
        );
    }

    function test_CreateParallel_AllStagesActive() public {
        bytes32 id = _createParallel();
        assertEq(uint256(coord.getStage(id, 0).status), uint256(IAgentCoordinator.StageStatus.ACTIVE));
        assertEq(uint256(coord.getStage(id, 1).status), uint256(IAgentCoordinator.StageStatus.ACTIVE));
        assertEq(uint256(coord.getStage(id, 2).status), uint256(IAgentCoordinator.StageStatus.PENDING)); // aggregator
    }

    function test_Parallel_AggregatorActivatesAfterAllComplete() public {
        bytes32 id = _createParallel();

        vm.prank(A1_OWNER); coord.submitStageResult(id, 0, "out0");
        // Aggregator still pending
        assertEq(uint256(coord.getStage(id, 2).status), uint256(IAgentCoordinator.StageStatus.PENDING));

        vm.prank(A2_OWNER); coord.submitStageResult(id, 1, "out1");
        // Now aggregator activates
        assertEq(uint256(coord.getStage(id, 2).status), uint256(IAgentCoordinator.StageStatus.ACTIVE));
    }

    function test_Parallel_FullCycle() public {
        bytes32 id = _createParallel();

        vm.prank(A1_OWNER);  coord.submitStageResult(id, 0, "out0");
        vm.prank(A2_OWNER);  coord.submitStageResult(id, 1, "out1");

        uint256 aggBefore = AGG_WALL.balance;
        vm.prank(AGG_OWNER); coord.submitStageResult(id, 2, "merged");

        assertEq(AGG_WALL.balance, aggBefore + 0.1 ether);
        assertEq(uint256(coord.getWorkflow(id).status), uint256(IAgentCoordinator.WorkflowStatus.COMPLETED));
    }

    // ── Cancel ────────────────────────────────────────────────────

    function test_CancelWorkflow_RefundsUnused() public {
        bytes32 id = _createPipeline();

        // Complete stage 0
        vm.prank(A1_OWNER); coord.submitStageResult(id, 0, "out0");

        uint256 clientBefore = CLIENT.balance;
        vm.prank(CLIENT);
        coord.cancelWorkflow(id);

        // Stages 1 and 2 were unused: 0.2 + 0.3 = 0.5 ETH refunded
        assertEq(CLIENT.balance, clientBefore + 0.5 ether);
        assertEq(uint256(coord.getWorkflow(id).status), uint256(IAgentCoordinator.WorkflowStatus.CANCELLED));
    }

    function test_CancelWorkflow_NotClient_Reverts() public {
        bytes32 id = _createPipeline();
        vm.prank(address(0x9999));
        vm.expectRevert(IAgentCoordinator.NotAuthorized.selector);
        coord.cancelWorkflow(id);
    }

    // ── Networks ──────────────────────────────────────────────────

    function test_CreateNetwork_Success() public {
        uint256[] memory ids   = new uint256[](2); ids[0] = A1; ids[1] = A2;
        uint256[] memory roles = new uint256[](2); roles[0] = 1; roles[1] = 2;

        vm.prank(CLIENT);
        bytes32 netId = coord.createNetwork("ResearchTeam", ids, roles);

        IAgentCoordinator.AgentNetwork memory net = coord.getNetwork(netId);
        assertEq(net.name, "ResearchTeam");
        assertTrue(net.isActive);
        assertEq(coord.totalNetworks(), 1);
    }

    function test_HireNetwork_CreatesWorkflow() public {
        uint256[] memory ids   = new uint256[](2); ids[0] = A1; ids[1] = A2;
        uint256[] memory roles = new uint256[](2); roles[0] = 0; roles[1] = 0;

        vm.prank(CLIENT);
        bytes32 netId = coord.createNetwork("Team", ids, roles);

        uint256[] memory b = new uint256[](2); b[0] = 0.1 ether; b[1] = 0.2 ether;
        uint256[] memory d = new uint256[](2);
        d[0] = block.timestamp + 1 days; d[1] = block.timestamp + 2 days;

        vm.prank(CLIENT);
        bytes32 wfId = coord.hireNetwork{value: 0.3 ether}(netId, PARENT_TASK, b, d);

        assertEq(coord.getWorkflow(wfId).totalStages, 2);
        assertEq(coord.getNetwork(netId).totalJobs, 1);
    }

    // ── Fuzz ─────────────────────────────────────────────────────

    function testFuzz_ETH_Conservation(uint96 b0, uint96 b1, uint96 b2) public {
        vm.assume(b0 > 0 && b1 > 0 && b2 > 0);
        vm.assume(uint256(b0) + b1 + b2 <= 5 ether);

        vm.deal(CLIENT, uint256(b0) + b1 + b2);

        uint256[] memory ids  = _pipelineAgents();
        uint256[] memory buds = new uint256[](3);
        buds[0] = b0; buds[1] = b1; buds[2] = b2;
        uint256[] memory dls  = _deadlines();
        string[]  memory ins  = _inputs();

        vm.prank(CLIENT);
        bytes32 id = coord.createPipeline{value: uint256(b0) + b1 + b2}(
            PARENT_TASK, ids, buds, dls, ins
        );

        uint256 w1 = A1_WALL.balance;
        uint256 w2 = A2_WALL.balance;
        uint256 w3 = A3_WALL.balance;

        vm.prank(A1_OWNER); coord.submitStageResult(id, 0, "o0");
        vm.prank(A2_OWNER); coord.submitStageResult(id, 1, "o1");
        vm.prank(A3_OWNER); coord.submitStageResult(id, 2, "o2");

        uint256 paid = (A1_WALL.balance - w1) + (A2_WALL.balance - w2) + (A3_WALL.balance - w3);
        assertEq(paid, uint256(b0) + b1 + b2);
        assertEq(address(coord).balance, 0);
    }
}

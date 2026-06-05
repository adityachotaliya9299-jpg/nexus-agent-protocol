// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TaskMarketplace} from "../src/marketplace/TaskMarketplace.sol";
import {ITaskMarketplace} from "../src/interfaces/ITaskMarketplace.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";
import {ReputationOracle} from "../src/reputation/ReputationOracle.sol";
import {IReputationOracle} from "../src/interfaces/IReputationOracle.sol";

/// @notice Mock agent wallet — receives ETH payments
contract MockAgentWallet {
    uint256 public received;
    receive() external payable { received += msg.value; }
}

contract TaskMarketplaceTest is Test {
    // ============================================================
    //                         SETUP
    // ============================================================

    TaskMarketplace public marketplace;
    AgentRegistry public registry;
    ReputationOracle public oracle;

    address public protocolOwner = makeAddr("protocolOwner");
    address public arbitrator    = makeAddr("arbitrator");
    address public client        = makeAddr("client");
    address public client2       = makeAddr("client2");
    address public agentOwner    = makeAddr("agentOwner");   // owns agent 1
    address public agentOwner2   = makeAddr("agentOwner2");  // owns agent 2
    address public agentOwner3   = makeAddr("agentOwner3");  // owns agent 3
    address public stranger      = makeAddr("stranger");

    MockAgentWallet public agentWallet1;
    MockAgentWallet public agentWallet2;

    uint256 constant AGENT_ID_1 = 1;
    uint256 constant AGENT_ID_2 = 2;
    uint256 constant AGENT_ID_3 = 3;

    uint256 constant REWARD      = 1 ether;
    uint256 constant PLATFORM_FEE_BPS = 250; // 2.5%
    uint256 constant DEADLINE_IN = 7 days;

    string constant TASK_META   = "ipfs://QmTaskDescription";
    string constant PROPOSAL_URI = "ipfs://QmAgentProposal";
    string constant RESULT_URI   = "ipfs://QmTaskResult";
    string constant DISPUTE_URI  = "ipfs://QmDisputeReason";

    function setUp() public {
        // Deploy mock wallets
        agentWallet1 = new MockAgentWallet();
        agentWallet2 = new MockAgentWallet();

        // Deploy registry
        registry = new AgentRegistry(protocolOwner);

        // Register agents
        vm.prank(agentOwner);
        registry.registerAgent("ipfs://QmAgent1", IAgentRegistry.AgentCategory.CODE);

        vm.prank(agentOwner2);
        registry.registerAgent("ipfs://QmAgent2", IAgentRegistry.AgentCategory.TRADING);

        vm.prank(agentOwner3);
        registry.registerAgent("ipfs://QmAgent3", IAgentRegistry.AgentCategory.RESEARCH);

        // Link wallets to agents
        vm.prank(agentOwner);
        registry.setAgentWallet(AGENT_ID_1, address(agentWallet1));

        vm.prank(agentOwner2);
        registry.setAgentWallet(AGENT_ID_2, address(agentWallet2));

        // Deploy reputation oracle
        oracle = new ReputationOracle(protocolOwner, address(registry));

        // Deploy marketplace
        marketplace = new TaskMarketplace(
            protocolOwner,
            address(registry),
            address(oracle),
            arbitrator,
            PLATFORM_FEE_BPS
        );

        // Authorize marketplace in oracle
        vm.prank(protocolOwner);
        oracle.setAuthorizedUpdater(address(marketplace), true);

        // Initialize agent reputations
        vm.startPrank(protocolOwner);
        oracle.initializeAgent(AGENT_ID_1);
        oracle.initializeAgent(AGENT_ID_2);
        oracle.initializeAgent(AGENT_ID_3);
        vm.stopPrank();

        // Fund clients
        vm.deal(client, 100 ether);
        vm.deal(client2, 100 ether);
    }

    // ============================================================
    //                    HELPERS
    // ============================================================

    function _postTask() internal returns (bytes32 taskId) {
        vm.prank(client);
        taskId = marketplace.postTask{value: REWARD}(
            TASK_META,
            block.timestamp + DEADLINE_IN,
            0
        );
    }

    function _postTaskWithMinRep(uint256 minRep) internal returns (bytes32 taskId) {
        vm.prank(client);
        taskId = marketplace.postTask{value: REWARD}(
            TASK_META,
            block.timestamp + DEADLINE_IN,
            minRep
        );
    }

    function _bidAndAssign(bytes32 taskId) internal {
        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);

        vm.prank(client);
        marketplace.assignAgent(taskId, AGENT_ID_1);
    }

    function _fullFlowToSubmitted(bytes32 taskId) internal {
        _bidAndAssign(taskId);

        vm.prank(agentOwner);
        marketplace.submitWork(taskId, AGENT_ID_1, RESULT_URI);
    }

    function _fullFlowToCompleted(bytes32 taskId) internal {
        _fullFlowToSubmitted(taskId);

        vm.prank(client);
        marketplace.approveWork(taskId);
    }

    // ============================================================
    //           DEPLOYMENT TESTS (4 tests)
    // ============================================================

    function test_Deploy_CorrectState() public view {
        assertEq(marketplace.protocolOwner(), protocolOwner);
        assertEq(marketplace.registry(), address(registry));
        assertEq(marketplace.reputationOracle(), address(oracle));
        assertEq(marketplace.arbitrator(), arbitrator);
        assertEq(marketplace.platformFeeBps(), PLATFORM_FEE_BPS);
        assertEq(marketplace.totalTasksPosted(), 0);
        assertEq(marketplace.totalTasksCompleted(), 0);
    }

    function test_Deploy_Revert_ZeroOwner() public {
        vm.expectRevert(ITaskMarketplace.ZeroAddress.selector);
        new TaskMarketplace(address(0), address(registry), address(oracle), arbitrator, 250);
    }

    function test_Deploy_Revert_ZeroRegistry() public {
        vm.expectRevert(ITaskMarketplace.ZeroAddress.selector);
        new TaskMarketplace(protocolOwner, address(0), address(oracle), arbitrator, 250);
    }

    function test_Deploy_Revert_FeeTooHigh() public {
        vm.expectRevert(ITaskMarketplace.InvalidFee.selector);
        new TaskMarketplace(protocolOwner, address(registry), address(oracle), arbitrator, 1001);
    }

    // ============================================================
    //           POST TASK TESTS (8 tests)
    // ============================================================

    function test_PostTask_Success() public {
        bytes32 taskId = _postTask();

        ITaskMarketplace.Task memory task = marketplace.getTask(taskId);
        assertEq(task.client, client);
        assertEq(task.reward, REWARD);
        assertEq(uint256(task.status), uint256(ITaskMarketplace.TaskStatus.OPEN));
        assertEq(task.metadataURI, TASK_META);
        assertEq(marketplace.totalTasksPosted(), 1);
    }

    function test_PostTask_EscrowsETH() public {
        _postTask();
        assertEq(address(marketplace).balance, REWARD);
    }

    function test_PostTask_EmitsEvent() public {
        uint256 deadline = block.timestamp + DEADLINE_IN;
        vm.prank(client);
        vm.expectEmit(false, true, false, false);
        emit ITaskMarketplace.TaskPosted(bytes32(0), client, REWARD, deadline, TASK_META);
        marketplace.postTask{value: REWARD}(TASK_META, deadline, 0);
    }

    function test_PostTask_TracksClientTasks() public {
        bytes32 taskId = _postTask();
        bytes32[] memory tasks = marketplace.getClientTasks(client);
        assertEq(tasks.length, 1);
        assertEq(tasks[0], taskId);
    }

    function test_PostTask_Revert_ZeroReward() public {
        vm.prank(client);
        vm.expectRevert(ITaskMarketplace.InvalidReward.selector);
        marketplace.postTask{value: 0}(TASK_META, block.timestamp + DEADLINE_IN, 0);
    }

    function test_PostTask_Revert_EmptyMetadata() public {
        vm.prank(client);
        vm.expectRevert(ITaskMarketplace.InvalidMetadata.selector);
        marketplace.postTask{value: REWARD}("", block.timestamp + DEADLINE_IN, 0);
    }

    function test_PostTask_Revert_DeadlineTooSoon() public {
        vm.prank(client);
        vm.expectRevert(ITaskMarketplace.InvalidDeadline.selector);
        marketplace.postTask{value: REWARD}(TASK_META, block.timestamp + 30 minutes, 0);
    }

    function test_PostTask_Revert_DeadlineTooFar() public {
        vm.prank(client);
        vm.expectRevert(ITaskMarketplace.InvalidDeadline.selector);
        marketplace.postTask{value: REWARD}(TASK_META, block.timestamp + 366 days, 0);
    }

    function test_PostTask_MultipleTasksIncrementNonce() public {
        vm.startPrank(client);
        bytes32 id1 = marketplace.postTask{value: REWARD}(TASK_META, block.timestamp + DEADLINE_IN, 0);
        bytes32 id2 = marketplace.postTask{value: REWARD}(TASK_META, block.timestamp + DEADLINE_IN, 0);
        vm.stopPrank();

        assertTrue(id1 != id2, "Task IDs must be unique");
        assertEq(marketplace.totalTasksPosted(), 2);
    }

    // ============================================================
    //           SUBMIT BID TESTS (9 tests)
    // ============================================================

    function test_SubmitBid_Success() public {
        bytes32 taskId = _postTask();

        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);

        ITaskMarketplace.Bid memory bid = marketplace.getBid(taskId, AGENT_ID_1);
        assertEq(bid.agentId, AGENT_ID_1);
        assertEq(bid.proposalURI, PROPOSAL_URI);
        assertEq(bid.estimatedTime, 1 days);
        assertFalse(bid.isAccepted);
        assertFalse(bid.isWithdrawn);
    }

    function test_SubmitBid_EmitsEvent() public {
        bytes32 taskId = _postTask();

        vm.expectEmit(true, true, false, true);
        emit ITaskMarketplace.BidSubmitted(taskId, AGENT_ID_1, REWARD);
        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);
    }

    function test_SubmitBid_MultipleBidders() public {
        bytes32 taskId = _postTask();

        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);

        vm.prank(agentOwner2);
        marketplace.submitBid(taskId, AGENT_ID_2, PROPOSAL_URI, 2 days);

        ITaskMarketplace.Bid[] memory bids = marketplace.getTaskBids(taskId);
        assertEq(bids.length, 2);
    }

    function test_SubmitBid_Revert_TaskNotOpen() public {
        bytes32 taskId = _postTask();
        _bidAndAssign(taskId); // moves to ASSIGNED

        vm.prank(agentOwner2);
        vm.expectRevert(abi.encodeWithSelector(ITaskMarketplace.TaskNotOpen.selector, taskId));
        marketplace.submitBid(taskId, AGENT_ID_2, PROPOSAL_URI, 1 days);
    }

    function test_SubmitBid_Revert_NotAgentOwner() public {
        bytes32 taskId = _postTask();

        vm.prank(stranger); // not agentOwner
        vm.expectRevert(abi.encodeWithSelector(ITaskMarketplace.AgentNotRegistered.selector, AGENT_ID_1));
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);
    }

    function test_SubmitBid_Revert_CannotBidOwnTask() public {
        // Client is also an agent owner — registers as agent
        vm.prank(client);
        // client isn't a registered agent in our setup, use agentOwner as client
        // Post task as agentOwner, then try to bid
        vm.prank(agentOwner);
        bytes32 taskId = marketplace.postTask{value: REWARD}(
            TASK_META, block.timestamp + DEADLINE_IN, 0
        );

        vm.prank(agentOwner);
        vm.expectRevert(ITaskMarketplace.CannotBidOwnTask.selector);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);
    }

    function test_SubmitBid_Revert_DuplicateBid() public {
        bytes32 taskId = _postTask();

        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);

        vm.prank(agentOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.BidAlreadyExists.selector, taskId, AGENT_ID_1)
        );
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);
    }

    function test_SubmitBid_Revert_DeadlinePassed() public {
        bytes32 taskId = _postTask();

        vm.warp(block.timestamp + DEADLINE_IN + 1);

        vm.prank(agentOwner);
        vm.expectRevert(abi.encodeWithSelector(ITaskMarketplace.DeadlinePassed.selector, taskId));
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);
    }

    function test_SubmitBid_Revert_InsufficientReputation() public {
        bytes32 taskId = _postTaskWithMinRep(8000); // require 80% score

        // Agent 1 starts at 5000 (50%) — below 8000
        vm.prank(agentOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITaskMarketplace.InsufficientReputation.selector, AGENT_ID_1, 8000, 5000
            )
        );
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);
    }

    // ============================================================
    //           WITHDRAW BID TESTS (4 tests)
    // ============================================================

    function test_WithdrawBid_Success() public {
        bytes32 taskId = _postTask();

        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);

        vm.prank(agentOwner);
        marketplace.withdrawBid(taskId, AGENT_ID_1);

        ITaskMarketplace.Bid memory bid = marketplace.getBid(taskId, AGENT_ID_1);
        assertTrue(bid.isWithdrawn);
    }

    function test_WithdrawBid_EmitsEvent() public {
        bytes32 taskId = _postTask();
        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);

        vm.expectEmit(true, true, false, false);
        emit ITaskMarketplace.BidWithdrawn(taskId, AGENT_ID_1);
        vm.prank(agentOwner);
        marketplace.withdrawBid(taskId, AGENT_ID_1);
    }

    function test_WithdrawBid_Revert_AlreadyWithdrawn() public {
        bytes32 taskId = _postTask();
        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);
        vm.prank(agentOwner);
        marketplace.withdrawBid(taskId, AGENT_ID_1);

        vm.prank(agentOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.BidWithdrawnAlready.selector, taskId, AGENT_ID_1)
        );
        marketplace.withdrawBid(taskId, AGENT_ID_1);
    }

    function test_WithdrawBid_Revert_NoBidExists() public {
        bytes32 taskId = _postTask();

        vm.prank(agentOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.BidNotFound.selector, taskId, AGENT_ID_1)
        );
        marketplace.withdrawBid(taskId, AGENT_ID_1);
    }

    // ============================================================
    //           ASSIGN AGENT TESTS (7 tests)
    // ============================================================

    function test_AssignAgent_Success() public {
        bytes32 taskId = _postTask();

        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);

        vm.prank(client);
        marketplace.assignAgent(taskId, AGENT_ID_1);

        ITaskMarketplace.Task memory task = marketplace.getTask(taskId);
        assertEq(uint256(task.status), uint256(ITaskMarketplace.TaskStatus.ASSIGNED));
        assertEq(task.assignedAgentId, AGENT_ID_1);
        assertEq(task.assignedAgentWallet, address(agentWallet1));
    }

    function test_AssignAgent_EmitsEvent() public {
        bytes32 taskId = _postTask();
        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);

        vm.expectEmit(true, true, false, true);
        emit ITaskMarketplace.TaskAssigned(taskId, AGENT_ID_1, address(agentWallet1));
        vm.prank(client);
        marketplace.assignAgent(taskId, AGENT_ID_1);
    }

    function test_AssignAgent_TracksAgentTasks() public {
        bytes32 taskId = _postTask();
        _bidAndAssign(taskId);

        bytes32[] memory agentTasks = marketplace.getAgentTasks(AGENT_ID_1);
        assertEq(agentTasks.length, 1);
        assertEq(agentTasks[0], taskId);
    }

    function test_AssignAgent_BidMarkedAccepted() public {
        bytes32 taskId = _postTask();
        _bidAndAssign(taskId);

        ITaskMarketplace.Bid memory bid = marketplace.getBid(taskId, AGENT_ID_1);
        assertTrue(bid.isAccepted);
    }

    function test_AssignAgent_Revert_NotClient() public {
        bytes32 taskId = _postTask();
        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.NotTaskClient.selector, taskId, stranger)
        );
        marketplace.assignAgent(taskId, AGENT_ID_1);
    }

    function test_AssignAgent_Revert_NoBid() public {
        bytes32 taskId = _postTask();

        vm.prank(client);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.BidNotFound.selector, taskId, AGENT_ID_1)
        );
        marketplace.assignAgent(taskId, AGENT_ID_1);
    }

    function test_AssignAgent_Revert_WithdrawnBid() public {
        bytes32 taskId = _postTask();
        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);
        vm.prank(agentOwner);
        marketplace.withdrawBid(taskId, AGENT_ID_1);

        vm.prank(client);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.BidWithdrawnAlready.selector, taskId, AGENT_ID_1)
        );
        marketplace.assignAgent(taskId, AGENT_ID_1);
    }

    // ============================================================
    //           SUBMIT WORK TESTS (5 tests)
    // ============================================================

    function test_SubmitWork_Success() public {
        bytes32 taskId = _postTask();
        _bidAndAssign(taskId);

        vm.prank(agentOwner);
        marketplace.submitWork(taskId, AGENT_ID_1, RESULT_URI);

        ITaskMarketplace.Task memory task = marketplace.getTask(taskId);
        assertEq(uint256(task.status), uint256(ITaskMarketplace.TaskStatus.SUBMITTED));
        assertGt(task.submittedAt, 0);
    }

    function test_SubmitWork_EmitsEvent() public {
        bytes32 taskId = _postTask();
        _bidAndAssign(taskId);

        vm.expectEmit(true, true, false, true);
        emit ITaskMarketplace.WorkSubmitted(taskId, AGENT_ID_1, RESULT_URI);
        vm.prank(agentOwner);
        marketplace.submitWork(taskId, AGENT_ID_1, RESULT_URI);
    }

    function test_SubmitWork_Revert_NotAssigned() public {
        bytes32 taskId = _postTask();

        vm.prank(agentOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.TaskNotAssigned.selector, taskId)
        );
        marketplace.submitWork(taskId, AGENT_ID_1, RESULT_URI);
    }

    function test_SubmitWork_Revert_WrongAgent() public {
        bytes32 taskId = _postTask();
        _bidAndAssign(taskId); // assigns agent 1

        // Agent 2 tries to submit
        vm.prank(agentOwner2);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.NotAssignedAgent.selector, taskId, agentOwner2)
        );
        marketplace.submitWork(taskId, AGENT_ID_2, RESULT_URI);
    }

    function test_SubmitWork_Revert_EmptyResult() public {
        bytes32 taskId = _postTask();
        _bidAndAssign(taskId);

        vm.prank(agentOwner);
        vm.expectRevert(ITaskMarketplace.InvalidMetadata.selector);
        marketplace.submitWork(taskId, AGENT_ID_1, "");
    }

    // ============================================================
    //           APPROVE WORK TESTS (7 tests)
    // ============================================================

    function test_ApproveWork_Success() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);

        uint256 expectedFee = (REWARD * PLATFORM_FEE_BPS) / 10000;
        uint256 expectedAgentPayment = REWARD - expectedFee;

        vm.prank(client);
        marketplace.approveWork(taskId);

        ITaskMarketplace.Task memory task = marketplace.getTask(taskId);
        assertEq(uint256(task.status), uint256(ITaskMarketplace.TaskStatus.COMPLETED));
        assertEq(marketplace.totalTasksCompleted(), 1);
        assertEq(agentWallet1.received, expectedAgentPayment);
        assertEq(marketplace.accumulatedFees(), expectedFee);
    }

    function test_ApproveWork_EmitsEvent() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);

        uint256 expectedFee = (REWARD * PLATFORM_FEE_BPS) / 10000;
        uint256 expectedPayment = REWARD - expectedFee;

        vm.expectEmit(true, true, false, true);
        emit ITaskMarketplace.TaskCompleted(taskId, AGENT_ID_1, expectedPayment, expectedFee);
        vm.prank(client);
        marketplace.approveWork(taskId);
    }

    function test_ApproveWork_AgentWalletReceivesETH() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);

        uint256 walletBefore = address(agentWallet1).balance;
        vm.prank(client);
        marketplace.approveWork(taskId);

        uint256 expectedPayment = REWARD - (REWARD * PLATFORM_FEE_BPS / 10000);
        assertEq(address(agentWallet1).balance - walletBefore, expectedPayment);
    }

    function test_ApproveWork_UpdatesReputation() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);

        uint256 scoreBefore = oracle.getScore(AGENT_ID_1);
        vm.prank(client);
        marketplace.approveWork(taskId);

        // Reputation should increase after task completion
        assertGt(oracle.getScore(AGENT_ID_1), scoreBefore);
    }

    function test_ApproveWork_Revert_NotClient() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.NotTaskClient.selector, taskId, stranger)
        );
        marketplace.approveWork(taskId);
    }

    function test_ApproveWork_Revert_NotSubmitted() public {
        bytes32 taskId = _postTask();
        _bidAndAssign(taskId); // ASSIGNED, not SUBMITTED

        vm.prank(client);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.TaskNotSubmitted.selector, taskId)
        );
        marketplace.approveWork(taskId);
    }

    function test_ApproveWork_ContractBalanceDecreases() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);

        assertEq(address(marketplace).balance, REWARD);

        vm.prank(client);
        marketplace.approveWork(taskId);

        // Only fees remain in contract
        assertEq(address(marketplace).balance, marketplace.accumulatedFees());
    }

    // ============================================================
    //           CANCEL TASK TESTS (5 tests)
    // ============================================================

    function test_CancelTask_Success() public {
        bytes32 taskId = _postTask();

        uint256 clientBefore = client.balance;
        vm.prank(client);
        marketplace.cancelTask(taskId);

        ITaskMarketplace.Task memory task = marketplace.getTask(taskId);
        assertEq(uint256(task.status), uint256(ITaskMarketplace.TaskStatus.CANCELLED));
        assertEq(client.balance, clientBefore + REWARD);
    }

    function test_CancelTask_EmitsEvent() public {
        bytes32 taskId = _postTask();

        vm.expectEmit(true, false, false, true);
        emit ITaskMarketplace.TaskCancelled(taskId, client);
        vm.prank(client);
        marketplace.cancelTask(taskId);
    }

    function test_CancelTask_RefundsClient() public {
        bytes32 taskId = _postTask();
        uint256 before = client.balance;

        vm.prank(client);
        marketplace.cancelTask(taskId);

        assertEq(client.balance, before + REWARD);
        assertEq(address(marketplace).balance, 0);
    }

    function test_CancelTask_Revert_NotClient() public {
        bytes32 taskId = _postTask();

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.NotTaskClient.selector, taskId, stranger)
        );
        marketplace.cancelTask(taskId);
    }

    function test_CancelTask_Revert_AlreadyAssigned() public {
        bytes32 taskId = _postTask();
        _bidAndAssign(taskId);

        vm.prank(client);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.TaskNotOpen.selector, taskId)
        );
        marketplace.cancelTask(taskId);
    }

    // ============================================================
    //           DISPUTE TESTS (9 tests)
    // ============================================================

    function test_RaiseDispute_ByClient_Success() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);

        vm.prank(client);
        marketplace.raiseDispute(taskId, DISPUTE_URI);

        ITaskMarketplace.Task memory task = marketplace.getTask(taskId);
        assertEq(uint256(task.status), uint256(ITaskMarketplace.TaskStatus.DISPUTED));
    }

    function test_RaiseDispute_ByAgent_Success() public {
        bytes32 taskId = _postTask();
        _bidAndAssign(taskId); // ASSIGNED state

        vm.prank(agentOwner);
        marketplace.raiseDispute(taskId, DISPUTE_URI);

        ITaskMarketplace.Dispute memory dispute = marketplace.getDispute(taskId);
        assertEq(dispute.raisedBy, agentOwner);
    }

    function test_RaiseDispute_EmitsEvent() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);

        vm.expectEmit(true, false, false, true);
        emit ITaskMarketplace.DisputeRaised(taskId, client, DISPUTE_URI);
        vm.prank(client);
        marketplace.raiseDispute(taskId, DISPUTE_URI);
    }

    function test_RaiseDispute_Revert_AlreadyDisputed() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);

        vm.prank(client);
        marketplace.raiseDispute(taskId, DISPUTE_URI);

        vm.prank(client);
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.AlreadyDisputed.selector, taskId)
        );
        marketplace.raiseDispute(taskId, DISPUTE_URI);
    }

    function test_RaiseDispute_Revert_Stranger() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);

        vm.prank(stranger);
        vm.expectRevert("Not client or agent");
        marketplace.raiseDispute(taskId, DISPUTE_URI);
    }

    function test_ResolveDispute_ClientWins_RefundsClient() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);
        vm.prank(client);
        marketplace.raiseDispute(taskId, DISPUTE_URI);

        uint256 clientBefore = client.balance;
        vm.prank(arbitrator);
        marketplace.resolveDispute(taskId, ITaskMarketplace.DisputeOutcome.CLIENT_WINS, 0);

        assertEq(client.balance, clientBefore + REWARD);
        assertEq(address(marketplace).balance, 0);
    }

    function test_ResolveDispute_AgentWins_PaysAgent() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);
        vm.prank(client);
        marketplace.raiseDispute(taskId, DISPUTE_URI);

        uint256 agentBefore = address(agentWallet1).balance;
        vm.prank(arbitrator);
        marketplace.resolveDispute(taskId, ITaskMarketplace.DisputeOutcome.AGENT_WINS, 0);

        uint256 expectedPayment = REWARD - (REWARD * PLATFORM_FEE_BPS / 10000);
        assertEq(address(agentWallet1).balance - agentBefore, expectedPayment);
    }

    function test_ResolveDispute_Split_50_50() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);
        vm.prank(client);
        marketplace.raiseDispute(taskId, DISPUTE_URI);

        uint256 clientBefore = client.balance;
        uint256 agentBefore = address(agentWallet1).balance;

        vm.prank(arbitrator);
        marketplace.resolveDispute(taskId, ITaskMarketplace.DisputeOutcome.SPLIT, 5000); // 50/50

        assertEq(client.balance - clientBefore, REWARD / 2);
        assertEq(address(agentWallet1).balance - agentBefore, REWARD / 2);
    }

    function test_ResolveDispute_Revert_NotArbitrator() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);
        vm.prank(client);
        marketplace.raiseDispute(taskId, DISPUTE_URI);

        vm.prank(stranger);
        vm.expectRevert(ITaskMarketplace.NotArbitrator.selector);
        marketplace.resolveDispute(taskId, ITaskMarketplace.DisputeOutcome.CLIENT_WINS, 0);
    }

    function test_ResolveDispute_EmitsEvent() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);
        vm.prank(client);
        marketplace.raiseDispute(taskId, DISPUTE_URI);

        vm.expectEmit(true, false, false, true);
        emit ITaskMarketplace.DisputeResolved(
            taskId, ITaskMarketplace.DisputeOutcome.CLIENT_WINS, arbitrator
        );
        vm.prank(arbitrator);
        marketplace.resolveDispute(taskId, ITaskMarketplace.DisputeOutcome.CLIENT_WINS, 0);
    }

    // ============================================================
    //           ADMIN / FEE TESTS (5 tests)
    // ============================================================

    function test_SetPlatformFee_Success() public {
        vm.prank(protocolOwner);
        marketplace.setPlatformFee(500);
        assertEq(marketplace.platformFeeBps(), 500);
    }

    function test_SetPlatformFee_EmitsEvent() public {
        vm.expectEmit(false, false, false, true);
        emit ITaskMarketplace.PlatformFeeUpdated(500);
        vm.prank(protocolOwner);
        marketplace.setPlatformFee(500);
    }

    function test_SetPlatformFee_Revert_TooHigh() public {
        vm.prank(protocolOwner);
        vm.expectRevert(ITaskMarketplace.InvalidFee.selector);
        marketplace.setPlatformFee(1001);
    }

    function test_WithdrawFees_Success() public {
        bytes32 taskId = _postTask();
        _fullFlowToCompleted(taskId);

        uint256 fees = marketplace.accumulatedFees();
        assertGt(fees, 0);

        address payable treasury = payable(makeAddr("treasury"));
        vm.prank(protocolOwner);
        marketplace.withdrawFees(treasury);

        assertEq(marketplace.accumulatedFees(), 0);
        assertEq(treasury.balance, fees);
    }

    function test_SetArbitrator_Success() public {
        address newArbitrator = makeAddr("newArbitrator");
        vm.prank(protocolOwner);
        marketplace.setArbitrator(newArbitrator);
        assertEq(marketplace.arbitrator(), newArbitrator);
    }

    // ============================================================
    //           INTEGRATION TESTS (6 tests)
    // ============================================================

    function test_Integration_FullHappyPath() public {
        // 1. Post task
        bytes32 taskId = _postTask();
        assertEq(uint256(marketplace.getTask(taskId).status), uint256(ITaskMarketplace.TaskStatus.OPEN));

        // 2. Two agents bid
        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);
        vm.prank(agentOwner2);
        marketplace.submitBid(taskId, AGENT_ID_2, "ipfs://QmProposal2", 2 days);

        assertEq(marketplace.getTaskBids(taskId).length, 2);

        // 3. Client assigns agent 1
        vm.prank(client);
        marketplace.assignAgent(taskId, AGENT_ID_1);

        // 4. Agent submits work
        vm.prank(agentOwner);
        marketplace.submitWork(taskId, AGENT_ID_1, RESULT_URI);

        // 5. Client approves
        vm.prank(client);
        marketplace.approveWork(taskId);

        // Verify final state
        ITaskMarketplace.Task memory task = marketplace.getTask(taskId);
        assertEq(uint256(task.status), uint256(ITaskMarketplace.TaskStatus.COMPLETED));
        assertEq(marketplace.totalTasksCompleted(), 1);
        assertGt(agentWallet1.received, 0);
        assertGt(marketplace.accumulatedFees(), 0);
    }

    function test_Integration_AgentToAgentHiring() public {
        // Agent 2 posts a task (agents can hire other agents)
        vm.deal(agentOwner2, 10 ether);
        vm.prank(agentOwner2);
        bytes32 taskId = marketplace.postTask{value: 1 ether}(
            TASK_META, block.timestamp + DEADLINE_IN, 0
        );

        // Agent 1 bids
        vm.prank(agentOwner);
        marketplace.submitBid(taskId, AGENT_ID_1, PROPOSAL_URI, 1 days);

        // Agent 2 assigns agent 1
        vm.prank(agentOwner2);
        marketplace.assignAgent(taskId, AGENT_ID_1);

        // Agent 1 submits work
        vm.prank(agentOwner);
        marketplace.submitWork(taskId, AGENT_ID_1, RESULT_URI);

        // Agent 2 approves and pays agent 1
        vm.prank(agentOwner2);
        marketplace.approveWork(taskId);

        assertGt(agentWallet1.received, 0);
    }

    function test_Integration_MultipleCompletedTasks_ReputationGrows() public {
        uint256 scoreBefore = oracle.getScore(AGENT_ID_1);

        // Complete 3 tasks
        for (uint256 i = 0; i < 3; i++) {
            bytes32 taskId = _postTask();
            _fullFlowToCompleted(taskId);
        }

        assertGt(oracle.getScore(AGENT_ID_1), scoreBefore);
    }

    function test_Integration_TaskNotFound_Revert() public {
        bytes32 fakeId = keccak256("nonexistent");
        vm.expectRevert(
            abi.encodeWithSelector(ITaskMarketplace.TaskNotFound.selector, fakeId)
        );
        marketplace.getTask(fakeId);
    }

    function test_Integration_DisputeResolved_ReputationUpdated() public {
        bytes32 taskId = _postTask();
        _fullFlowToSubmitted(taskId);
        uint256 scoreBefore = oracle.getScore(AGENT_ID_1);

        vm.prank(client);
        marketplace.raiseDispute(taskId, DISPUTE_URI);

        vm.prank(arbitrator);
        marketplace.resolveDispute(taskId, ITaskMarketplace.DisputeOutcome.CLIENT_WINS, 0);

        // Reputation should decrease after losing dispute
        assertLt(oracle.getScore(AGENT_ID_1), scoreBefore);
    }

    function test_Integration_ClientPostsMultipleTasks() public {
        vm.startPrank(client);
        marketplace.postTask{value: 1 ether}(TASK_META, block.timestamp + DEADLINE_IN, 0);
        marketplace.postTask{value: 2 ether}(TASK_META, block.timestamp + DEADLINE_IN, 0);
        marketplace.postTask{value: 0.5 ether}(TASK_META, block.timestamp + DEADLINE_IN, 0);
        vm.stopPrank();

        assertEq(marketplace.getClientTasks(client).length, 3);
        assertEq(marketplace.totalTasksPosted(), 3);
    }

    // ============================================================
    //                   FUZZ TESTS (4 tests)
    // ============================================================

    function testFuzz_PostTask_RewardAlwaysEscrowed(uint256 reward) public {
        vm.assume(reward > 0 && reward <= 100 ether);
        vm.deal(client, reward);

        vm.prank(client);
        marketplace.postTask{value: reward}(TASK_META, block.timestamp + DEADLINE_IN, 0);

        assertEq(address(marketplace).balance, reward);
    }

    function testFuzz_PlatformFee_AlwaysValid(uint256 feeBps) public {
        vm.assume(feeBps <= 1000);
        vm.prank(protocolOwner);
        marketplace.setPlatformFee(feeBps);
        assertEq(marketplace.platformFeeBps(), feeBps);
    }

    function testFuzz_TaskId_AlwaysUnique(uint8 numTasks) public {
        vm.assume(numTasks > 1 && numTasks <= 20);
        vm.deal(client, 100 ether);

        bytes32[] memory ids = new bytes32[](numTasks);
        for (uint256 i = 0; i < numTasks; i++) {
            vm.prank(client);
            ids[i] = marketplace.postTask{value: 0.1 ether}(
                TASK_META, block.timestamp + DEADLINE_IN, 0
            );
        }

        // All IDs must be unique
        for (uint256 i = 0; i < numTasks; i++) {
            for (uint256 j = i + 1; j < numTasks; j++) {
                assertTrue(ids[i] != ids[j], "Duplicate taskId detected");
            }
        }
    }

    function testFuzz_FeeCalculation_NeverExceedsReward(uint256 reward, uint256 feeBps) public {
        vm.assume(reward > 0 && reward <= 100 ether);
        vm.assume(feeBps <= 1000);
        vm.deal(client, reward);

        vm.prank(protocolOwner);
        marketplace.setPlatformFee(feeBps);

        vm.prank(client);
        bytes32 taskId = marketplace.postTask{value: reward}(
            TASK_META, block.timestamp + DEADLINE_IN, 0
        );

        ITaskMarketplace.Task memory task = marketplace.getTask(taskId);
        assertLe(task.platformFee, reward, "Fee must never exceed reward");
    }
}

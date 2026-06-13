// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

// All contracts
import {AgentRegistry}       from "../src/AgentRegistry.sol";
import {AgentWallet}          from "../src/AgentWallet.sol";
import {AgentWalletFactory}   from "../src/AgentWalletFactory.sol";
import {ReputationOracle}     from "../src/reputation/ReputationOracle.sol";
import {AgentMemory}          from "../src/memory/AgentMemory.sol";
import {TaskMarketplace}      from "../src/marketplace/TaskMarketplace.sol";
import {ZKVerifier}           from "../src/zk/ZKVerifier.sol";
import {SubscriptionManager}  from "../src/subscriptions/SubscriptionManager.sol";
import {CrossChainBridge}     from "../src/bridge/CrossChainBridge.sol";
import {IAgentRegistry}       from "../src/interfaces/IAgentRegistry.sol";
import {IAgentWallet}         from "../src/interfaces/IAgentWallet.sol";
import {IReputationOracle}    from "../src/interfaces/IReputationOracle.sol";
import {IAgentMemory}         from "../src/interfaces/IAgentMemory.sol";
import {ITaskMarketplace}     from "../src/interfaces/ITaskMarketplace.sol";
import {IZKVerifier}          from "../src/interfaces/IZKVerifier.sol";
import {ISubscriptionManager} from "../src/interfaces/ISubscriptionManager.sol";
import {ICrossChainBridge}    from "../src/interfaces/ICrossChainBridge.sol";

// ============================================================
//                     MOCK HELPERS
// ============================================================

contract MockEntryPoint {
    receive() external payable {}
}

contract MockCCIPRouter {
    receive() external payable {}
    function send(uint64, bytes calldata) external payable {}
}

/// @title ProtocolIntegrationTest
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice End-to-end tests spanning all 9 Nexus Agent Protocol contracts
/// @dev Tests realistic agent lifecycle scenarios:
///      register → wallet → reputation → memory → tasks → proofs → subscriptions → bridge
contract ProtocolIntegrationTest is Test {
    // ============================================================
    //                     ALL CONTRACTS
    // ============================================================

    AgentRegistry      public registry;
    AgentWalletFactory public walletFactory;
    ReputationOracle   public oracle;
    AgentMemory        public memory_;
    TaskMarketplace    public marketplace;
    ZKVerifier         public zkVerifier;
    SubscriptionManager public subManager;
    CrossChainBridge   public bridge;

    MockEntryPoint  public entryPoint;
    MockCCIPRouter  public ccipRouter;

    // ============================================================
    //                     ACTORS
    // ============================================================

    address public protocolOwner = makeAddr("protocolOwner");
    address public arbitrator    = makeAddr("arbitrator");

    // Agent operators (with known private keys for ERC-4337 sigs)
    uint256 public alicePk = 0xA11CE;
    uint256 public bobPk   = 0xB0B;
    address public alice;  // Agent 1 — Code specialist
    address public bob;    // Agent 2 — Trading specialist
    address public carol   = makeAddr("carol");   // Human client
    address public dave    = makeAddr("dave");    // Another client / agent subscriber

    uint256 constant ALICE_ID = 1;
    uint256 constant BOB_ID   = 2;

    // Chain selectors
    uint64 constant ETH_CHAIN     = 5009297550715157269;
    uint64 constant POLYGON_CHAIN = 4051577828743386545;

    // Test data
    string constant ALICE_META   = "ipfs://QmAliceMeta";
    string constant BOB_META     = "ipfs://QmBobMeta";
    string constant TASK_META    = "ipfs://QmTaskDescription";
    string constant RESULT_URI   = "ipfs://QmTaskResult";
    string constant MEMORY_CID   = "ipfs://QmAliceMemoryV1";
    string constant PLAN_META    = "ipfs://QmPlanMeta";
    bytes  constant VALID_PROOF  = hex"deadbeefcafebabe0102030405060708090a0b0c0d0e0f101112131415161718";
    bytes  constant VK_DATA      = hex"aabbccddee112233";

    bytes32 public vKeyId;

    function setUp() public {
        alice = vm.addr(alicePk);
        bob   = vm.addr(bobPk);

        vm.deal(alice,  100 ether);
        vm.deal(bob,    100 ether);
        vm.deal(carol,  100 ether);
        vm.deal(dave,   100 ether);

        // ── Deploy infrastructure ──────────────────────────────
        entryPoint = new MockEntryPoint();
        ccipRouter = new MockCCIPRouter();

        // ── Deploy all protocol contracts ─────────────────────
        registry    = new AgentRegistry(protocolOwner);
        walletFactory = new AgentWalletFactory(address(entryPoint), address(registry));
        oracle      = new ReputationOracle(protocolOwner, address(registry));
        memory_     = new AgentMemory(protocolOwner, address(registry));
        marketplace = new TaskMarketplace(
            protocolOwner, address(registry), address(oracle), arbitrator, 250
        );
        zkVerifier  = new ZKVerifier(
            protocolOwner, address(registry), address(oracle), 6600
        );
        subManager  = new SubscriptionManager(protocolOwner, address(registry), 250);
        bridge      = new CrossChainBridge(
            protocolOwner, address(registry), address(oracle),
            address(ccipRouter), ETH_CHAIN
        );

        // ── Wire up authorizations ────────────────────────────
        vm.startPrank(protocolOwner);
        oracle.setAuthorizedUpdater(address(marketplace), true);
        oracle.setAuthorizedUpdater(address(zkVerifier),  true);
        oracle.setAuthorizedUpdater(address(bridge),      true);
        memory_.setAuthorizedWriter(address(marketplace), true);
        registry.setReputationUpdater(address(oracle),    true);
        bridge.addSupportedChain(POLYGON_CHAIN, makeAddr("polygonBridge"), "Polygon");
        vKeyId = zkVerifier.registerVerificationKey(
            IZKVerifier.ProofType.TASK_COMPLETION, VK_DATA
        );
        vm.stopPrank();

        // ── Register agents ───────────────────────────────────
        vm.prank(alice);
        registry.registerAgent(ALICE_META, IAgentRegistry.AgentCategory.CODE);

        vm.prank(bob);
        registry.registerAgent(BOB_META, IAgentRegistry.AgentCategory.TRADING);

        // ── Deploy wallets ────────────────────────────────────
        vm.prank(alice);
        address aliceWallet = walletFactory.deployWallet(alice, ALICE_ID, bytes32(0));

        vm.prank(bob);
        address bobWallet = walletFactory.deployWallet(bob, BOB_ID, bytes32(0));

        // ── Link wallets to registry ──────────────────────────
        vm.prank(alice);
        registry.setAgentWallet(ALICE_ID, aliceWallet);

        vm.prank(bob);
        registry.setAgentWallet(BOB_ID, bobWallet);

        // ── Initialize reputation and memory ─────────────────
        vm.startPrank(protocolOwner);
        oracle.initializeAgent(ALICE_ID);
        oracle.initializeAgent(BOB_ID);
        memory_.initializeAgent(ALICE_ID, alice);
        memory_.initializeAgent(BOB_ID, bob);
        vm.stopPrank();
    }

    // ============================================================
    //    TEST 1: Full Agent Lifecycle — Register to Earning
    // ============================================================

    /// @notice Alice registers, gets wallet, completes task, earns ETH, score rises
    function test_Integration_FullAgentLifecycle() public {
        // ── Verify initial state ──────────────────────────────
        assertTrue(registry.isRegistered(alice));
        assertEq(oracle.getScore(ALICE_ID), 5000);
        assertTrue(walletFactory.hasWallet(alice));

        address aliceWalletAddr = walletFactory.getWallet(alice);
        assertEq(registry.getAgent(ALICE_ID).agentWallet, aliceWalletAddr);

        // ── Carol posts a task ────────────────────────────────
        vm.prank(carol);
        bytes32 taskId = marketplace.postTask{value: 1 ether}(
            TASK_META, block.timestamp + 7 days, 0
        );

        // ── Alice bids ────────────────────────────────────────
        vm.prank(alice);
        marketplace.submitBid(taskId, ALICE_ID, "ipfs://QmProposal", 1 days);

        // ── Carol assigns Alice ───────────────────────────────
        vm.prank(carol);
        marketplace.assignAgent(taskId, ALICE_ID);

        // ── Alice writes memory (context for this task) ──────
        vm.prank(alice);
        memory_.writeMemory(
            ALICE_ID,
            IAgentMemory.MemoryType.CONTEXT,
            MEMORY_CID,
            keccak256("task-context-v1")
        );

        // ── Alice submits work ────────────────────────────────
        vm.prank(alice);
        marketplace.submitWork(taskId, ALICE_ID, RESULT_URI);

        // ── Carol approves — Alice gets paid ─────────────────
        uint256 walletBefore = aliceWalletAddr.balance;
        uint256 scoreBefore  = oracle.getScore(ALICE_ID);

        vm.prank(carol);
        marketplace.approveWork(taskId);

        // ── Verify payment and reputation ────────────────────
        assertGt(aliceWalletAddr.balance, walletBefore);
        assertGt(oracle.getScore(ALICE_ID), scoreBefore);
        assertEq(marketplace.totalTasksCompleted(), 1);

        // ── Verify memory was written ─────────────────────────
        IAgentMemory.MemorySnapshot memory snap = memory_.getLatestMemory(
            ALICE_ID, IAgentMemory.MemoryType.CONTEXT
        );
        assertEq(snap.cid, MEMORY_CID);
        assertEq(snap.version, 1);
    }

    // ============================================================
    //    TEST 2: Agent-to-Agent Economy
    // ============================================================

    /// @notice Bob (trading agent) hires Alice (code agent) as sub-agent
    function test_Integration_AgentToAgentEconomy() public {
        // Bob posts a task needing code work
        vm.prank(bob);
        bytes32 taskId = marketplace.postTask{value: 0.5 ether}(
            TASK_META, block.timestamp + 7 days, 0
        );

        // Alice bids as a sub-agent
        vm.prank(alice);
        marketplace.submitBid(taskId, ALICE_ID, "ipfs://QmAliceProposal", 12 hours);

        // Bob assigns Alice
        vm.prank(bob);
        marketplace.assignAgent(taskId, ALICE_ID);

        // Alice does the work
        vm.prank(alice);
        marketplace.submitWork(taskId, ALICE_ID, RESULT_URI);

        // Bob approves — Alice wallet receives payment
        address aliceWallet = walletFactory.getWallet(alice);
        uint256 before = aliceWallet.balance;

        vm.prank(bob);
        marketplace.approveWork(taskId);

        assertGt(aliceWallet.balance, before);

        // Both agents have tracked tasks
        assertEq(marketplace.getAgentTasks(ALICE_ID).length, 1);
        assertEq(marketplace.getClientTasks(bob).length, 1);
    }

    // ============================================================
    //    TEST 3: Reputation → ZK Proof → Trust Building
    // ============================================================

    /// @notice Alice builds reputation, submits ZK proof, gets extra trust boost
    function test_Integration_ReputationAndZKProof() public {
        // Complete 3 tasks to build reputation
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(carol);
            bytes32 taskId = marketplace.postTask{value: 0.1 ether}(
                TASK_META, block.timestamp + 7 days, 0
            );
            vm.prank(alice);
            marketplace.submitBid(taskId, ALICE_ID, "ipfs://QmProposal", 1 days);
            vm.prank(carol);
            marketplace.assignAgent(taskId, ALICE_ID);
            vm.prank(alice);
            marketplace.submitWork(taskId, ALICE_ID, RESULT_URI);
            vm.prank(carol);
            marketplace.approveWork(taskId);
        }

        uint256 scoreAfterTasks = oracle.getScore(ALICE_ID);
        assertGt(scoreAfterTasks, 5000);

        // Alice submits ZK proof of capability
        vm.prank(alice);
        bytes32 proofId = zkVerifier.submitProof(
            ALICE_ID,
            IZKVerifier.ProofType.TASK_COMPLETION,
            keccak256("task-1"),
            keccak256("public-inputs"),
            VALID_PROOF,
            vKeyId
        );

        // Protocol verifies the proof → extra reputation boost
        uint256 scoreBeforeProof = oracle.getScore(ALICE_ID);
        vm.prank(protocolOwner);
        bool verified = zkVerifier.verifyProof(proofId);

        assertTrue(verified);
        assertGt(oracle.getScore(ALICE_ID), scoreBeforeProof);
        assertTrue(zkVerifier.isProofValid(proofId));
    }

    // ============================================================
    //    TEST 4: Subscription Economy — Agent on Retainer
    // ============================================================

    /// @notice Dave subscribes to Alice's service, recurring payments flow
    function test_Integration_SubscriptionEconomy() public {
        // Alice creates a subscription plan
        vm.prank(alice);
        bytes32 planId = subManager.createPlan(
            ALICE_ID,
            ISubscriptionManager.PlanTier.PRO,
            PLAN_META,
            0.05 ether,
            30 days,
            100
        );

        address aliceWallet = walletFactory.getWallet(alice);
        uint256 walletBefore = aliceWallet.balance;

        // Dave subscribes — first payment
        vm.prank(dave);
        bytes32 subId = subManager.subscribe{value: 0.05 ether}(planId, 0);

        // Alice wallet received payment (minus fee)
        assertGt(aliceWallet.balance, walletBefore);

        // Subscription is active
        assertTrue(subManager.isSubscriptionActive(subId));
        assertEq(subManager.getPlan(planId).currentSubscribers, 1);

        // Warp 30 days → payment due
        vm.warp(block.timestamp + 30 days + 1);
        assertTrue(subManager.isPaymentDue(subId));

        // Dave pays again
        vm.prank(dave);
        subManager.processPayment{value: 0.05 ether}(subId);

        assertEq(subManager.getSubscription(subId).paymentsCount, 2);
        assertFalse(subManager.isPaymentDue(subId));
    }

    // ============================================================
    //    TEST 5: Cross-Chain Identity Bridging
    // ============================================================

    /// @notice Alice bridges her identity to Polygon
    function test_Integration_CrossChainBridging() public {
        // Alice has good reputation after tasks
        vm.prank(protocolOwner);
        oracle.setAuthorizedUpdater(protocolOwner, true);
        vm.prank(protocolOwner);
        oracle.updateReputation(
            ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, bytes32(0)
        );

        uint256 aliceScore = oracle.getScore(ALICE_ID);
        assertGt(aliceScore, 5000);

        // Alice bridges identity to Polygon
        uint256 fee = bridge.BASE_FEE() + 300 * bridge.FEE_PER_BYTE();
        vm.prank(alice);
        bytes32 messageId = bridge.bridgeAgent{value: fee}(ALICE_ID, POLYGON_CHAIN);

        assertEq(bridge.totalMessagesSent(), 1);

        // Simulate Polygon receives the message (CCIP delivery)
        ICrossChainBridge.BridgeMessage memory sentMsg = bridge.getMessage(messageId);
        vm.prank(address(ccipRouter));
        bridge.ccipReceive(messageId, POLYGON_CHAIN, sentMsg.payload);

        // Alice is now known on Polygon
        assertTrue(bridge.isAgentBridged(ALICE_ID, POLYGON_CHAIN));
        ICrossChainBridge.AgentBridgeRecord memory record =
            bridge.getAgentBridgeRecord(ALICE_ID, POLYGON_CHAIN);
        assertEq(record.owner, alice);

        // Sync updated reputation to Polygon
        uint256 syncFee = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();
        vm.prank(alice);
        bridge.syncReputation{value: syncFee}(ALICE_ID, POLYGON_CHAIN);

        assertEq(bridge.totalMessagesSent(), 2);
    }

    // ============================================================
    //    TEST 6: Task Dispute → Resolution → Reputation Impact
    // ============================================================

    /// @notice Bob disputes a task, arbitrator resolves in client's favor
    function test_Integration_DisputeResolution() public {
        vm.prank(carol);
        bytes32 taskId = marketplace.postTask{value: 2 ether}(
            TASK_META, block.timestamp + 7 days, 0
        );

        vm.prank(bob);
        marketplace.submitBid(taskId, BOB_ID, "ipfs://QmBobProposal", 1 days);

        vm.prank(carol);
        marketplace.assignAgent(taskId, BOB_ID);

        vm.prank(bob);
        marketplace.submitWork(taskId, BOB_ID, RESULT_URI);

        uint256 scoreBefore = oracle.getScore(BOB_ID);
        uint256 carolBefore = carol.balance;

        // Carol raises dispute
        vm.prank(carol);
        marketplace.raiseDispute(taskId, "ipfs://QmDisputeReason");

        // Arbitrator resolves: client wins (refund)
        vm.prank(arbitrator);
        marketplace.resolveDispute(
            taskId, ITaskMarketplace.DisputeOutcome.CLIENT_WINS, 0
        );

        // Carol gets refund
        assertGt(carol.balance, carolBefore);
        // Bob's reputation decreases
        assertLt(oracle.getScore(BOB_ID), scoreBefore);
    }

    // ============================================================
    //    TEST 7: High-Reputation Gate — Min Reputation Filter
    // ============================================================

    /// @notice Only agents with high enough reputation can bid on premium tasks
    function test_Integration_ReputationGating() public {
        // Post task requiring 7000 reputation (70%)
        vm.prank(carol);
        bytes32 eliteTask = marketplace.postTask{value: 5 ether}(
            TASK_META, block.timestamp + 7 days, 7000
        );

        // Alice starts at 5000 — cannot bid
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITaskMarketplace.InsufficientReputation.selector,
                ALICE_ID, 7000, 5000
            )
        );
        marketplace.submitBid(eliteTask, ALICE_ID, "ipfs://QmProposal", 1 days);

        // Build Alice's reputation with multiple task completions
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(carol);
            bytes32 t = marketplace.postTask{value: 0.1 ether}(
                TASK_META, block.timestamp + 7 days, 0
            );
            vm.prank(alice);
            marketplace.submitBid(t, ALICE_ID, "ipfs://QmP", 1 days);
            vm.prank(carol);
            marketplace.assignAgent(t, ALICE_ID);
            vm.prank(alice);
            marketplace.submitWork(t, ALICE_ID, RESULT_URI);
            vm.prank(carol);
            marketplace.approveWork(t);
        }

        // Now Alice should have enough reputation
        uint256 aliceScore = oracle.getScore(ALICE_ID);
        assertGe(aliceScore, 7000);

        // Alice can now bid
        vm.prank(alice);
        marketplace.submitBid(eliteTask, ALICE_ID, "ipfs://QmEliteProposal", 1 days);

        ITaskMarketplace.Bid memory bid = marketplace.getBid(eliteTask, ALICE_ID);
        assertEq(bid.agentId, ALICE_ID);
    }

    // ============================================================
    //    TEST 8: Full Memory Lifecycle With Task Context
    // ============================================================

    /// @notice Agent writes memory per task, builds versioned history
    function test_Integration_AgentMemoryAcrossTasks() public {
        // Task 1: Alice writes context v1
        vm.prank(carol);
        bytes32 task1 = marketplace.postTask{value: 0.5 ether}(
            TASK_META, block.timestamp + 7 days, 0
        );
        vm.prank(alice);
        marketplace.submitBid(task1, ALICE_ID, "ipfs://P", 1 days);
        vm.prank(carol);
        marketplace.assignAgent(task1, ALICE_ID);

        vm.prank(alice);
        memory_.writeMemory(
            ALICE_ID, IAgentMemory.MemoryType.TASK_HISTORY,
            "ipfs://QmTask1Context", keccak256("task1-context")
        );

        vm.prank(alice);
        marketplace.submitWork(task1, ALICE_ID, RESULT_URI);
        vm.prank(carol);
        marketplace.approveWork(task1);

        // Task 2: Alice writes context v2
        vm.prank(carol);
        bytes32 task2 = marketplace.postTask{value: 0.5 ether}(
            TASK_META, block.timestamp + 7 days, 0
        );
        vm.prank(alice);
        marketplace.submitBid(task2, ALICE_ID, "ipfs://P2", 1 days);
        vm.prank(carol);
        marketplace.assignAgent(task2, ALICE_ID);

        vm.prank(alice);
        memory_.writeMemory(
            ALICE_ID, IAgentMemory.MemoryType.TASK_HISTORY,
            "ipfs://QmTask2Context", keccak256("task2-context")
        );

        // Verify versioned history
        IAgentMemory.MemorySnapshot[] memory history = memory_.getMemoryHistory(
            ALICE_ID, IAgentMemory.MemoryType.TASK_HISTORY
        );
        assertEq(history.length, 2);
        assertEq(history[0].version, 1);
        assertEq(history[1].version, 2);
        assertEq(history[1].cid, "ipfs://QmTask2Context");

        // Latest is v2
        IAgentMemory.MemorySnapshot memory latest = memory_.getLatestMemory(
            ALICE_ID, IAgentMemory.MemoryType.TASK_HISTORY
        );
        assertEq(latest.version, 2);
    }

    // ============================================================
    //    TEST 9: Protocol Fee Accounting
    // ============================================================

    /// @notice Fees accumulate correctly across marketplace + subscriptions
    function test_Integration_ProtocolFeeAccounting() public {
        // Task completion generates marketplace fee
        vm.prank(carol);
        bytes32 taskId = marketplace.postTask{value: 1 ether}(
            TASK_META, block.timestamp + 7 days, 0
        );
        vm.prank(alice);
        marketplace.submitBid(taskId, ALICE_ID, "ipfs://P", 1 days);
        vm.prank(carol);
        marketplace.assignAgent(taskId, ALICE_ID);
        vm.prank(alice);
        marketplace.submitWork(taskId, ALICE_ID, RESULT_URI);
        vm.prank(carol);
        marketplace.approveWork(taskId);

        uint256 marketplaceFees = marketplace.accumulatedFees();
        assertGt(marketplaceFees, 0);

        // Subscription generates fee
        vm.prank(alice);
        bytes32 planId = subManager.createPlan(
            ALICE_ID, ISubscriptionManager.PlanTier.BASIC,
            PLAN_META, 0.1 ether, 30 days, 0
        );
        vm.prank(dave);
        subManager.subscribe{value: 0.1 ether}(planId, 0);

        uint256 subFees = subManager.accumulatedFees();
        assertGt(subFees, 0);

        // Protocol owner withdraws both
        address payable treasury = payable(makeAddr("treasury"));

        vm.prank(protocolOwner);
        marketplace.withdrawFees(treasury);

        vm.prank(protocolOwner);
        subManager.withdrawFees(treasury);

        assertEq(marketplace.accumulatedFees(), 0);
        assertEq(subManager.accumulatedFees(), 0);
        assertEq(treasury.balance, marketplaceFees + subFees);
    }

    // ============================================================
    //    TEST 10: AVS Decentralized Verification Flow
    // ============================================================

    /// @notice Three AVS operators validate Alice's task completion proof
    function test_Integration_AVSVerificationFlow() public {
        address op1 = makeAddr("avs-op1");
        address op2 = makeAddr("avs-op2");
        address op3 = makeAddr("avs-op3");

        // Register AVS operators
        vm.startPrank(protocolOwner);
        zkVerifier.registerAVSOperator(op1, keccak256("op1"));
        zkVerifier.registerAVSOperator(op2, keccak256("op2"));
        zkVerifier.registerAVSOperator(op3, keccak256("op3"));
        zkVerifier.setQuorumThreshold(6600); // 2/3 = 66% triggers
        vm.stopPrank();

        // Alice submits proof after completing task
        vm.prank(alice);
        bytes32 proofId = zkVerifier.submitProof(
            ALICE_ID,
            IZKVerifier.ProofType.TASK_COMPLETION,
            keccak256("task-x"),
            keccak256("pub-inputs"),
            VALID_PROOF,
            vKeyId
        );

        assertEq(uint256(zkVerifier.getProof(proofId).status),
            uint256(IZKVerifier.ProofStatus.PENDING));

        // Dispatch to AVS
        vm.prank(protocolOwner);
        zkVerifier.dispatchToAVS(proofId);
        bytes32 avsTaskId = keccak256(abi.encodePacked(proofId, block.timestamp));

        uint256 scoreBefore = oracle.getScore(ALICE_ID);

        // Two operators vote positive (quorum = 66%)
        vm.prank(op1);
        zkVerifier.submitAVSResponse(avsTaskId, true, "");
        vm.prank(op2);
        zkVerifier.submitAVSResponse(avsTaskId, true, "");

        // Quorum reached → proof verified + reputation boost
        assertTrue(zkVerifier.isProofValid(proofId));
        assertGt(oracle.getScore(ALICE_ID), scoreBefore);
    }

    // ============================================================
    //    TEST 11: Multi-Contract State Consistency
    // ============================================================

    /// @notice State stays consistent across contracts after complex interactions
    function test_Integration_StateConsistency() public {
        // Register + wallet + memory all point to same agent
        assertEq(registry.getAgent(ALICE_ID).owner, alice);
        assertEq(registry.getAgent(ALICE_ID).agentWallet, walletFactory.getWallet(alice));
        assertEq(memory_.getMemoryOwner(ALICE_ID), alice);
        assertTrue(oracle.isAgentInitialized(ALICE_ID));

        // Complete a task → state updates in registry, oracle, marketplace
        vm.prank(carol);
        bytes32 taskId = marketplace.postTask{value: 0.5 ether}(
            TASK_META, block.timestamp + 7 days, 0
        );
        vm.prank(alice);
        marketplace.submitBid(taskId, ALICE_ID, "ipfs://P", 1 days);
        vm.prank(carol);
        marketplace.assignAgent(taskId, ALICE_ID);
        vm.prank(alice);
        marketplace.submitWork(taskId, ALICE_ID, RESULT_URI);
        vm.prank(carol);
        marketplace.approveWork(taskId);

        // Marketplace tracks it
        assertEq(marketplace.totalTasksCompleted(), 1);
        assertEq(marketplace.getAgentTasks(ALICE_ID).length, 1);

        // Oracle tracks reputation change
        assertGt(oracle.getScore(ALICE_ID), 5000);
        assertGt(oracle.getEventCount(ALICE_ID), 0);

        // Wallet received ETH
        address aliceWallet = walletFactory.getWallet(alice);
        assertGt(aliceWallet.balance, 0);
    }

    // ============================================================
    //    TEST 12: Agent Slash → Cannot Accept Tasks
    // ============================================================

    /// @notice Slashed agent cannot bid on tasks (reputation-gated)
    function test_Integration_SlashedAgent_CannotBid() public {
        // Slash Bob severely
        vm.prank(protocolOwner);
        oracle.slashAgent(BOB_ID, 5000, "fraud");

        assertTrue(oracle.getReputation(BOB_ID).isSlashed);

        // Post a task with min reputation 1000 (very low bar)
        vm.prank(carol);
        bytes32 taskId = marketplace.postTask{value: 0.5 ether}(
            TASK_META, block.timestamp + 7 days, 1000
        );

        // Bob's score is now 0 (5000 - 5000), below even 1000
        uint256 bobScore = oracle.getScore(BOB_ID);
        assertEq(bobScore, 0);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITaskMarketplace.InsufficientReputation.selector,
                BOB_ID, 1000, 0
            )
        );
        marketplace.submitBid(taskId, BOB_ID, "ipfs://P", 1 days);

        // Rehabilitate Bob
        vm.prank(protocolOwner);
        oracle.rehabilitateAgent(BOB_ID);
        assertFalse(oracle.getReputation(BOB_ID).isSlashed);
    }

    // ============================================================
    //    TEST 13: Cross-Contract Payment Flow Integrity
    // ============================================================

    /// @notice ETH flows correctly through escrow → agent wallet → withdrawal
    function test_Integration_PaymentFlowIntegrity() public {
        uint256 reward = 2 ether;
        uint256 feeBps = 250; // 2.5%
        uint256 expectedFee = (reward * feeBps) / 10000;
        uint256 expectedAgentPayment = reward - expectedFee;

        address aliceWallet = walletFactory.getWallet(alice);

        // Post task
        vm.prank(carol);
        bytes32 taskId = marketplace.postTask{value: reward}(
            TASK_META, block.timestamp + 7 days, 0
        );

        // ETH is in escrow
        assertEq(address(marketplace).balance, reward);

        // Complete full flow
        vm.prank(alice);
        marketplace.submitBid(taskId, ALICE_ID, "ipfs://P", 1 days);
        vm.prank(carol);
        marketplace.assignAgent(taskId, ALICE_ID);
        vm.prank(alice);
        marketplace.submitWork(taskId, ALICE_ID, RESULT_URI);

        uint256 walletBefore = aliceWallet.balance;
        vm.prank(carol);
        marketplace.approveWork(taskId);

        // Agent wallet received correct amount
        assertEq(aliceWallet.balance - walletBefore, expectedAgentPayment);

        // Protocol fee accumulated
        assertEq(marketplace.accumulatedFees(), expectedFee);

        // Nothing left in escrow (only fees)
        assertEq(address(marketplace).balance, expectedFee);

        // Alice can withdraw from her smart wallet
        vm.prank(alice);
        AgentWallet(payable(aliceWallet)).withdrawETH(payable(alice), expectedAgentPayment);
        assertEq(aliceWallet.balance, 0);
    }

    // ============================================================
    //    TEST 14: Invariant — Registry Always Source of Truth
    // ============================================================

    /// @notice Agent profile in registry stays consistent with wallet factory
    function test_Integration_Invariant_RegistrySourceOfTruth() public {
        // Every registered agent should have consistent data
        for (uint256 id = 1; id <= 2; id++) {
            IAgentRegistry.AgentProfile memory profile = registry.getAgent(id);

            // Wallet in registry matches factory
            if (walletFactory.hasWallet(profile.owner)) {
                assertEq(
                    profile.agentWallet,
                    walletFactory.getWallet(profile.owner),
                    "Wallet mismatch"
                );
            }

            // Memory initialized for registered agents
            assertTrue(memory_.isInitialized(id), "Memory not initialized");

            // Oracle initialized
            assertTrue(oracle.isAgentInitialized(id), "Oracle not initialized");
        }
    }

    // ============================================================
    //    TEST 15: Invariant — Score Always In Bounds
    // ============================================================

    /// @notice No matter how many operations, score stays 0–10000
    function test_Integration_Invariant_ScoreAlwaysInBounds() public {
        // Many positive and negative events
        vm.prank(protocolOwner);
        oracle.setAuthorizedUpdater(protocolOwner, true);

        vm.startPrank(protocolOwner);
        for (uint256 i = 0; i < 20; i++) {
            oracle.updateReputation(
                ALICE_ID,
                i % 2 == 0
                    ? IReputationOracle.UpdateReason.TASK_COMPLETED
                    : IReputationOracle.UpdateReason.TASK_FAILED,
                bytes32(i)
            );
        }
        vm.stopPrank();

        uint256 score = oracle.getScore(ALICE_ID);
        assertGe(score, 0);
        assertLe(score, 10000);

        // Slash and check
        vm.prank(protocolOwner);
        oracle.slashAgent(ALICE_ID, 5000, "test");
        score = oracle.getScore(ALICE_ID);
        assertGe(score, 0);
        assertLe(score, 10000);
    }
}

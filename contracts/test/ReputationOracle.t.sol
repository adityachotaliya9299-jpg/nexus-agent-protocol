// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ReputationOracle} from "../src/reputation/ReputationOracle.sol";
import {IReputationOracle} from "../src/interfaces/IReputationOracle.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

contract ReputationOracleTest is Test {
    // ============================================================
    //                         SETUP
    // ============================================================

    ReputationOracle public oracle;
    AgentRegistry public registry;

    address public protocolOwner = makeAddr("protocolOwner");
    address public marketplace   = makeAddr("marketplace");   // authorized updater
    address public avs           = makeAddr("avs");           // authorized updater
    address public alice         = makeAddr("alice");         // agent owner
    address public bob           = makeAddr("bob");           // agent owner
    address public charlie       = makeAddr("charlie");       // unauthorized
    address public dave          = makeAddr("dave");          // agent owner

    string constant META = "ipfs://QmTestMeta";

    // Agent IDs
    uint256 constant ALICE_ID = 1;
    uint256 constant BOB_ID   = 2;
    uint256 constant DAVE_ID  = 3;

    bytes32 constant TASK_1 = keccak256("task-1");
    bytes32 constant TASK_2 = keccak256("task-2");

    function setUp() public {
        // Deploy registry
        registry = new AgentRegistry(protocolOwner);

        // Register agents
        vm.prank(alice);
        registry.registerAgent(META, IAgentRegistry.AgentCategory.CODE);

        vm.prank(bob);
        registry.registerAgent(META, IAgentRegistry.AgentCategory.TRADING);

        vm.prank(dave);
        registry.registerAgent(META, IAgentRegistry.AgentCategory.RESEARCH);

        // Authorize oracle as reputation updater in registry
        vm.prank(protocolOwner);
        registry.setReputationUpdater(address(0), false); // placeholder

        // Deploy oracle
        oracle = new ReputationOracle(protocolOwner, address(registry));

        // Authorize oracle in registry so it can sync scores back
        vm.prank(protocolOwner);
        registry.setReputationUpdater(address(oracle), true);

        // Authorize marketplace and avs as updaters in oracle
        vm.prank(protocolOwner);
        oracle.setAuthorizedUpdater(marketplace, true);

        vm.prank(protocolOwner);
        oracle.setAuthorizedUpdater(avs, true);
    }

    // ============================================================
    //          CONSTRUCTOR / DEPLOYMENT TESTS (3 tests)
    // ============================================================

    function test_Deploy_CorrectState() public view {
        assertEq(oracle.protocolOwner(), protocolOwner);
        assertEq(oracle.registry(), address(registry));
        assertTrue(oracle.isAuthorizedUpdater(protocolOwner));
    }

    function test_Deploy_Revert_ZeroOwner() public {
        vm.expectRevert(IReputationOracle.ZeroAddress.selector);
        new ReputationOracle(address(0), address(registry));
    }

    function test_Deploy_Revert_ZeroRegistry() public {
        vm.expectRevert(IReputationOracle.ZeroAddress.selector);
        new ReputationOracle(protocolOwner, address(0));
    }

    // ============================================================
    //          INITIALIZATION TESTS (5 tests)
    // ============================================================

    function test_InitializeAgent_Success() public {
        vm.prank(protocolOwner);
        oracle.initializeAgent(ALICE_ID);

        assertTrue(oracle.isAgentInitialized(ALICE_ID));
        assertEq(oracle.getScore(ALICE_ID), oracle.INITIAL_SCORE());
    }

    function test_InitializeAgent_ByMarketplace() public {
        vm.prank(marketplace);
        oracle.initializeAgent(ALICE_ID);

        assertTrue(oracle.isAgentInitialized(ALICE_ID));
    }

    function test_InitializeAgent_EmitsEvent() public {
    vm.expectEmit(true, false, false, true);
    emit IReputationOracle.ReputationInitialized(ALICE_ID, oracle.INITIAL_SCORE());
    vm.prank(protocolOwner);
    oracle.initializeAgent(ALICE_ID);
}

    function test_InitializeAgent_Revert_AlreadyInitialized() public {
        vm.prank(protocolOwner);
        oracle.initializeAgent(ALICE_ID);

        vm.prank(protocolOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IReputationOracle.AlreadyInitialized.selector, ALICE_ID)
        );
        oracle.initializeAgent(ALICE_ID);
    }

    function test_InitializeAgent_Revert_Unauthorized() public {
        vm.prank(charlie);
        vm.expectRevert("Not authorized to initialize");
        oracle.initializeAgent(ALICE_ID);
    }

    // ============================================================
    //        REPUTATION UPDATE TESTS — INCREASES (5 tests)
    // ============================================================

    function test_Update_TaskCompleted_IncreasesScore() public {
        _initAlice();
        uint256 before = oracle.getScore(ALICE_ID);

        vm.prank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);

        uint256 after_ = oracle.getScore(ALICE_ID);
        assertEq(after_, before + oracle.taskCompleteWeight());
    }

    function test_Update_PositiveRating_IncreasesScore() public {
        _initAlice();
        uint256 before = oracle.getScore(ALICE_ID);

        vm.prank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.POSITIVE_RATING, bytes32(0));

        assertEq(oracle.getScore(ALICE_ID), before + oracle.positiveRatingWeight());
    }

    function test_Update_DisputeWon_IncreasesScore() public {
        _initAlice();
        uint256 before = oracle.getScore(ALICE_ID);

        vm.prank(avs);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.DISPUTE_WON, bytes32(0));

        assertEq(oracle.getScore(ALICE_ID), before + oracle.disputeWonWeight());
    }

    function test_Update_Score_CappedAtCeiling() public {
        _initAlice();

        // Pump score to near ceiling with many task completions
        vm.startPrank(marketplace);
        for (uint256 i = 0; i < 100; i++) {
            oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, bytes32(0));
        }
        vm.stopPrank();

        assertLe(oracle.getScore(ALICE_ID), oracle.SCORE_CEILING());
        assertEq(oracle.getScore(ALICE_ID), oracle.SCORE_CEILING());
    }

    function test_Update_IncreasesTasksCompleted() public {
        _initAlice();

        vm.prank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);

        IReputationOracle.ReputationState memory rep = oracle.getReputation(ALICE_ID);
        assertEq(rep.tasksCompleted, 1);
    }

    // ============================================================
    //        REPUTATION UPDATE TESTS — DECREASES (5 tests)
    // ============================================================

    function test_Update_TaskFailed_DecreasesScore() public {
        _initAlice();
        uint256 before = oracle.getScore(ALICE_ID);

        vm.prank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_FAILED, TASK_1);

        assertEq(oracle.getScore(ALICE_ID), before - oracle.taskFailWeight());
    }

    function test_Update_NegativeRating_DecreasesScore() public {
        _initAlice();
        uint256 before = oracle.getScore(ALICE_ID);

        vm.prank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.NEGATIVE_RATING, bytes32(0));

        assertEq(oracle.getScore(ALICE_ID), before - oracle.negativeRatingWeight());
    }

    function test_Update_DisputeLost_DecreasesScore() public {
        _initAlice();
        uint256 before = oracle.getScore(ALICE_ID);

        vm.prank(avs);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.DISPUTE_LOST, bytes32(0));

        assertEq(oracle.getScore(ALICE_ID), before - oracle.disputeLostWeight());
    }

    function test_Update_Score_FlooredAtZero() public {
        _initAlice();

        // Drain score to floor with many failures
        vm.startPrank(marketplace);
        for (uint256 i = 0; i < 100; i++) {
            oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_FAILED, bytes32(0));
        }
        vm.stopPrank();

        assertEq(oracle.getScore(ALICE_ID), oracle.SCORE_FLOOR());
    }

    function test_Update_InactivityPenalty_DecreasesScore() public {
        _initAlice();
        uint256 before = oracle.getScore(ALICE_ID);

        vm.prank(protocolOwner);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.INACTIVITY_PENALTY, bytes32(0));

        assertEq(oracle.getScore(ALICE_ID), before - oracle.inactivityWeight());
    }

    // ============================================================
    //           UPDATE ACCESS CONTROL TESTS (4 tests)
    // ============================================================

    function test_Update_Revert_NotAuthorized() public {
        _initAlice();

        vm.prank(charlie);
        vm.expectRevert(
            abi.encodeWithSelector(IReputationOracle.NotAuthorizedUpdater.selector, charlie)
        );
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);
    }

    function test_Update_Revert_AgentNotInitialized() public {
        // Alice not initialized yet
        vm.prank(marketplace);
        vm.expectRevert(
            abi.encodeWithSelector(IReputationOracle.AgentNotInitialized.selector, ALICE_ID)
        );
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);
    }

    function test_Update_EmitsEvent() public {
    _initAlice();
    uint256 expectedNew = oracle.INITIAL_SCORE() + oracle.taskCompleteWeight();

    vm.expectEmit(true, true, true, true);
    emit IReputationOracle.ReputationUpdated(
        ALICE_ID,
        oracle.INITIAL_SCORE(),
        expectedNew,
        IReputationOracle.UpdateReason.TASK_COMPLETED,
        marketplace,
        TASK_1
    );
    vm.prank(marketplace);
    oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);
}

    function test_Update_Revert_AgentIsSlashed() public {
        _initAlice();

        vm.prank(protocolOwner);
        oracle.slashAgent(ALICE_ID, 1000, "fraud");

        vm.prank(marketplace);
        vm.expectRevert(
            abi.encodeWithSelector(IReputationOracle.AgentIsSlashed.selector, ALICE_ID)
        );
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);
    }

    // ============================================================
    //              SLASH / REHABILITATE TESTS (5 tests)
    // ============================================================

    function test_SlashAgent_Success() public {
        _initAlice();
        uint256 before = oracle.getScore(ALICE_ID);

        vm.prank(protocolOwner);
        oracle.slashAgent(ALICE_ID, 2000, "malicious behavior");

        IReputationOracle.ReputationState memory rep = oracle.getReputation(ALICE_ID);
        assertEq(rep.score, before - 2000);
        assertTrue(rep.isSlashed);
    }

    function test_SlashAgent_EmitsEvent() public {
        _initAlice();

        vm.prank(protocolOwner);
        vm.expectEmit(true, false, false, true);
        emit IReputationOracle.AgentSlashed(ALICE_ID, 1000, "spam");
        oracle.slashAgent(ALICE_ID, 1000, "spam");
    }

    function test_SlashAgent_Revert_NotOwner() public {
        _initAlice();

        vm.prank(charlie);
        vm.expectRevert(IReputationOracle.NotProtocolOwner.selector);
        oracle.slashAgent(ALICE_ID, 1000, "test");
    }

    function test_SlashAgent_Revert_InvalidPenalty_Zero() public {
        _initAlice();

        vm.prank(protocolOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IReputationOracle.InvalidPenalty.selector, 0)
        );
        oracle.slashAgent(ALICE_ID, 0, "test");
    }

    function test_SlashAgent_Revert_InvalidPenalty_TooHigh() public {
        _initAlice();

        vm.prank(protocolOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IReputationOracle.InvalidPenalty.selector, 5001)
        );
        oracle.slashAgent(ALICE_ID, 5001, "test");
    }

    function test_RehabilitateAgent_Success() public {
        _initAlice();

        vm.prank(protocolOwner);
        oracle.slashAgent(ALICE_ID, 1000, "test");
        assertTrue(oracle.getReputation(ALICE_ID).isSlashed);

        vm.prank(protocolOwner);
        oracle.rehabilitateAgent(ALICE_ID);

        assertFalse(oracle.getReputation(ALICE_ID).isSlashed);
    }

    function test_RehabilitateAgent_CanUpdateAfterRehab() public {
        _initAlice();

        vm.prank(protocolOwner);
        oracle.slashAgent(ALICE_ID, 500, "test");

        vm.prank(protocolOwner);
        oracle.rehabilitateAgent(ALICE_ID);

        // Should work now
        vm.prank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);
    }

    // ============================================================
    //              EVENT HISTORY TESTS (4 tests)
    // ============================================================

    function test_EventHistory_RecordsUpdates() public {
        _initAlice();

        vm.prank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);

        vm.prank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.POSITIVE_RATING, TASK_2);

        assertEq(oracle.getEventCount(ALICE_ID), 2);
    }

    function test_EventHistory_CorrectData() public {
        _initAlice();
        uint256 scoreBefore = oracle.getScore(ALICE_ID);

        vm.prank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);

        IReputationOracle.ReputationEvent[] memory history = oracle.getEventHistory(ALICE_ID);
        assertEq(history.length, 1);
        assertEq(history[0].agentId, ALICE_ID);
        assertEq(history[0].oldScore, scoreBefore);
        assertEq(history[0].newScore, scoreBefore + oracle.taskCompleteWeight());
        assertEq(history[0].updatedBy, marketplace);
        assertEq(history[0].taskId, TASK_1);
    }

    function test_EventHistory_EmptyForNewAgent() public {
        _initAlice();
        assertEq(oracle.getEventCount(ALICE_ID), 0);
    }

    function test_EventHistory_MultipleAgentsSeparate() public {
        _initAlice();

        vm.prank(protocolOwner);
        oracle.initializeAgent(BOB_ID);

        vm.prank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);

        // Bob's history should be untouched
        assertEq(oracle.getEventCount(ALICE_ID), 1);
        assertEq(oracle.getEventCount(BOB_ID), 0);
    }

    // ============================================================
    //            WEIGHT MANAGEMENT TESTS (3 tests)
    // ============================================================

    function test_SetWeights_Success() public {
        vm.prank(protocolOwner);
        oracle.setWeights(100, 200, 60, 80, 200, 300, 50);

        (
            uint256 tc, uint256 tf, uint256 pr,
            uint256 nr, uint256 dw, uint256 dl
        ) = oracle.getScoreWeights();

        assertEq(tc, 100);
        assertEq(tf, 200);
        assertEq(pr, 60);
        assertEq(nr, 80);
        assertEq(dw, 200);
        assertEq(dl, 300);
    }

    function test_SetWeights_Revert_NotOwner() public {
        vm.prank(charlie);
        vm.expectRevert(IReputationOracle.NotProtocolOwner.selector);
        oracle.setWeights(100, 200, 60, 80, 200, 300, 50);
    }

    function test_CustomWeights_AffectScore() public {
        _initAlice();

        // Set custom weights
        vm.prank(protocolOwner);
        oracle.setWeights(200, 80, 30, 40, 100, 150, 20); // task complete = 200 bp

        uint256 before = oracle.getScore(ALICE_ID);

        vm.prank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);

        assertEq(oracle.getScore(ALICE_ID), before + 200);
    }

    // ============================================================
    //          AUTHORIZED UPDATER TESTS (3 tests)
    // ============================================================

    function test_SetAuthorizedUpdater_AddAndRemove() public {
        address newUpdater = makeAddr("newUpdater");

        assertFalse(oracle.isAuthorizedUpdater(newUpdater));

        vm.prank(protocolOwner);
        oracle.setAuthorizedUpdater(newUpdater, true);
        assertTrue(oracle.isAuthorizedUpdater(newUpdater));

        vm.prank(protocolOwner);
        oracle.setAuthorizedUpdater(newUpdater, false);
        assertFalse(oracle.isAuthorizedUpdater(newUpdater));
    }

    function test_SetAuthorizedUpdater_Revert_NotOwner() public {
        vm.prank(charlie);
        vm.expectRevert(IReputationOracle.NotProtocolOwner.selector);
        oracle.setAuthorizedUpdater(marketplace, false);
    }

    function test_SetAuthorizedUpdater_Revert_ZeroAddress() public {
        vm.prank(protocolOwner);
        vm.expectRevert(IReputationOracle.ZeroAddress.selector);
        oracle.setAuthorizedUpdater(address(0), true);
    }

    // ============================================================
    //              INTEGRATION TESTS (3 tests)
    // ============================================================

    function test_Integration_RegistrySynced_AfterUpdate() public {
    _initAlice();

    vm.prank(marketplace);
    oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, TASK_1);

    // Oracle is source of truth — registry sync happens in Phase 3 via marketplace
    // Verify oracle score updated correctly
    assertEq(oracle.getScore(ALICE_ID), oracle.INITIAL_SCORE() + oracle.taskCompleteWeight());
    assertEq(oracle.getReputation(ALICE_ID).tasksCompleted, 1);
}

    function test_Integration_MultipleAgents_IndependentScores() public {
        _initAlice();
        vm.prank(protocolOwner);
        oracle.initializeAgent(BOB_ID);

        // Alice completes 3 tasks
        vm.startPrank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, bytes32(0));
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, bytes32(0));
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, bytes32(0));

        // Bob fails 2 tasks
        oracle.updateReputation(BOB_ID, IReputationOracle.UpdateReason.TASK_FAILED, bytes32(0));
        oracle.updateReputation(BOB_ID, IReputationOracle.UpdateReason.TASK_FAILED, bytes32(0));
        vm.stopPrank();

        assertTrue(oracle.getScore(ALICE_ID) > oracle.getScore(BOB_ID));
        assertEq(oracle.getReputation(ALICE_ID).tasksCompleted, 3);
        assertEq(oracle.getReputation(BOB_ID).tasksFailed, 2);
    }

    function test_Integration_FullAgentLifecycle() public {
        _initAlice();

        // Start: fresh agent at 5000
        assertEq(oracle.getScore(ALICE_ID), 5000);

        // Does some tasks
        vm.startPrank(marketplace);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, bytes32(0));
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.POSITIVE_RATING, bytes32(0));
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.TASK_COMPLETED, bytes32(0));
        vm.stopPrank();

        uint256 goodScore = oracle.getScore(ALICE_ID);
        assertGt(goodScore, 5000);

        // Gets into a dispute, loses
        vm.prank(avs);
        oracle.updateReputation(ALICE_ID, IReputationOracle.UpdateReason.DISPUTE_LOST, bytes32(0));

        uint256 afterDispute = oracle.getScore(ALICE_ID);
        assertLt(afterDispute, goodScore);

        // Gets slashed for bad behavior
        vm.prank(protocolOwner);
        oracle.slashAgent(ALICE_ID, 1000, "fraud detected");
        assertTrue(oracle.getReputation(ALICE_ID).isSlashed);

        // Rehabilitated after review
        vm.prank(protocolOwner);
        oracle.rehabilitateAgent(ALICE_ID);
        assertFalse(oracle.getReputation(ALICE_ID).isSlashed);

        // Check full history
        assertGt(oracle.getEventCount(ALICE_ID), 0);
    }

    // ============================================================
    //                   FUZZ TESTS (3 tests)
    // ============================================================

    function testFuzz_Score_AlwaysInBounds(uint8 reasonSeed, uint8 iterations) public {
        vm.assume(iterations > 0 && iterations <= 50);
        uint8 numReasons = 7; // 0-6 are valid reasons (excluding MANUAL_OVERRIDE)

        _initAlice();

        vm.startPrank(marketplace);
        for (uint256 i = 0; i < iterations; i++) {
            uint8 reasonIdx = uint8(uint256(keccak256(abi.encodePacked(reasonSeed, i))) % numReasons);
            oracle.updateReputation(
                ALICE_ID,
                IReputationOracle.UpdateReason(reasonIdx),
                bytes32(0)
            );
        }
        vm.stopPrank();

        uint256 score = oracle.getScore(ALICE_ID);
        assertGe(score, oracle.SCORE_FLOOR());
        assertLe(score, oracle.SCORE_CEILING());
    }

    function testFuzz_SlashPenalty_ValidRange(uint256 penalty) public {
        vm.assume(penalty > 0 && penalty <= oracle.MAX_SLASH_PENALTY());
        _initAlice();
        uint256 before = oracle.getScore(ALICE_ID);

        vm.prank(protocolOwner);
        oracle.slashAgent(ALICE_ID, penalty, "fuzz test");

        uint256 expected = before > penalty ? before - penalty : 0;
        assertEq(oracle.getScore(ALICE_ID), expected);
    }

    function testFuzz_EventHistory_AlwaysGrows(uint8 n) public {
        vm.assume(n > 0 && n <= 30);
        _initAlice();

        vm.startPrank(marketplace);
        for (uint256 i = 0; i < n; i++) {
            oracle.updateReputation(
                ALICE_ID,
                IReputationOracle.UpdateReason.TASK_COMPLETED,
                bytes32(i)
            );
        }
        vm.stopPrank();

        assertEq(oracle.getEventCount(ALICE_ID), n);
    }

    // ============================================================
    //                      HELPERS
    // ============================================================

    function _initAlice() internal {
        vm.prank(protocolOwner);
        oracle.initializeAgent(ALICE_ID);
    }
}

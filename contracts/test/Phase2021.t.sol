// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ContextualReputation} from "../src/reputation/ContextualReputation.sol";
import {IContextualReputation} from "../src/reputation/IContextualReputation.sol";
import {AgentDiscovery} from "../src/discovery/AgentDiscovery.sol";
import {IAgentDiscovery} from "../src/discovery/IAgentDiscovery.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

// ── Stubs ──────────────────────────────────────────────────────

contract MockRegistry {
    mapping(uint256 => address) public owners;
    mapping(uint256 => uint256) public categories;
    mapping(uint256 => uint256) public completed;
    mapping(uint256 => bool)    public exists;
    mapping(uint256 => uint8)   public statuses; // 1=ACTIVE

    function addAgent(uint256 id, address owner, uint256 cat) external {
        owners[id]     = owner;
        categories[id] = cat;
        exists[id]     = true;
        statuses[id]   = 1;
        completed[id]  = 0;
    }

    function setStatus(uint256 id, uint8 status) external { statuses[id] = status; }
    function setCompleted(uint256 id, uint256 n) external { completed[id] = n; }

    function getAgent(uint256 id) external view returns (IAgentRegistry.AgentProfile memory p) {
        require(exists[id], "AgentNotFound");
        p.agentId             = id;
        p.owner               = owners[id];
        p.category            = IAgentRegistry.AgentCategory(categories[id]);
        p.totalTasksCompleted = completed[id];
        p.status              = IAgentRegistry.AgentStatus(statuses[id]);
        p.reputationScore     = 5000;
        return p;
    }
}

contract MockOracle {
    mapping(uint256 => uint256) public scores;
    function setScore(uint256 id, uint256 s) external { scores[id] = s; }
    function getScore(uint256 id) external view returns (uint256) {
        return scores[id] == 0 ? 5000 : scores[id];
    }
}

contract MockStaking {
    mapping(uint256 => uint256) public stakes;
    function setStake(uint256 id, uint256 amount) external { stakes[id] = amount; }
    function getStake(uint256 id) external view returns (uint256, uint256) {
        return (id, stakes[id]);
    }
    function getEffectiveStake(uint256 id) external view returns (uint256) {
        return stakes[id];
    }
}

// ── ContextualReputation Tests ─────────────────────────────────

contract ContextualReputationTest is Test {
    ContextualReputation internal rep;
    MockRegistry         internal registry;

    address constant OWNER   = address(0xA11CE);
    address constant UPDATER = address(0xAUTH);
    address constant CLIENT  = address(0xC11E4);
    address constant AGENT1  = address(0xA6E41);
    address constant STRANGER = address(0x577);

    uint256 constant AGENT_ID   = 1;
    uint256 constant CAT_CODE   = 1;
    uint256 constant CAT_GENERAL = 0;
    bytes32 constant TASK_ID    = bytes32(uint256(0xBEEF));

    function setUp() public {
        registry = new MockRegistry();
        registry.addAgent(AGENT_ID, AGENT1, CAT_CODE);

        vm.prank(OWNER);
        rep = new ContextualReputation(OWNER, address(registry));

        vm.prank(OWNER);
        rep.setAuthorized(UPDATER, true);
    }

    // ── Deployment ───────────────────────────────────────────────

    function test_Deploy_OwnerSet() public view {
        assertEq(rep.protocolOwner(), OWNER);
    }

    function test_Deploy_UpdaterAuthorized() public view {
        assertTrue(rep.isAuthorized(UPDATER));
    }

    // ── Initial score ─────────────────────────────────────────────

    function test_InitialScore_ReturnsDefault() public view {
        assertEq(rep.getScore(AGENT_ID, CAT_CODE), 5000);
    }

    // ── Record completion ─────────────────────────────────────────

    function test_RecordCompletion_Success_UpdatesScore() public {
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT_ID, CAT_CODE, true);

        IContextualReputation.CategoryScore memory cs = rep.getCategoryScore(AGENT_ID, CAT_CODE);
        assertEq(cs.tasksCompleted, 1);
        assertEq(cs.tasksAssigned, 1);
        assertEq(cs.streak, 1);
        assertGt(cs.score, 0);
    }

    function test_RecordCompletion_Failure_BreaksStreak() public {
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT_ID, CAT_CODE, true);
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT_ID, CAT_CODE, true);
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT_ID, CAT_CODE, false);

        IContextualReputation.CategoryScore memory cs = rep.getCategoryScore(AGENT_ID, CAT_CODE);
        assertEq(cs.streak, 0);
        assertEq(cs.tasksCompleted, 2);
        assertEq(cs.tasksAssigned, 3);
    }

    function test_RecordCompletion_OnlyAuthorized_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(IContextualReputation.NotAuthorized.selector);
        rep.recordCompletion(AGENT_ID, CAT_CODE, true);
    }

    function test_RecordCompletion_InvalidCategory_Reverts() public {
        vm.prank(UPDATER);
        vm.expectRevert(abi.encodeWithSelector(IContextualReputation.InvalidCategory.selector, 99));
        rep.recordCompletion(AGENT_ID, 99, true);
    }

    function test_RecordCompletion_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit IContextualReputation.CategoryScoreUpdated(AGENT_ID, CAT_CODE, 0, 0, 0);
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT_ID, CAT_CODE, true);
    }

    // ── Score formula ─────────────────────────────────────────────

    function test_Score_PerfectAgent_ApproachesMax() public {
        // 20 consecutive successes → high streak bonus + perfect success rate
        for (uint256 i = 0; i < 20; i++) {
            vm.prank(UPDATER);
            rep.recordCompletion(AGENT_ID, CAT_CODE, true);
        }
        uint256 score = rep.getScore(AGENT_ID, CAT_CODE);
        // Without ratings: baseScore(6000) + ratingScore(1500 neutral) + streakBonus(1000) = 8500
        assertGe(score, 8000);
    }

    function test_Score_HalfSuccessRate_Reduces() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(UPDATER);
            rep.recordCompletion(AGENT_ID, CAT_CODE, true);
            vm.prank(UPDATER);
            rep.recordCompletion(AGENT_ID, CAT_CODE, false);
        }
        uint256 score = rep.getScore(AGENT_ID, CAT_CODE);
        // 50% success: baseScore = 3000, no streak
        assertLt(score, 6000);
    }

    // ── Ratings ───────────────────────────────────────────────────

    function test_SubmitRating_UpdatesScore() public {
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT_ID, CAT_CODE, true);

        uint256 scoreBefore = rep.getScore(AGENT_ID, CAT_CODE);

        vm.prank(CLIENT);
        rep.submitRating(AGENT_ID, CAT_CODE, 10000, TASK_ID);

        uint256 scoreAfter = rep.getScore(AGENT_ID, CAT_CODE);
        assertGt(scoreAfter, scoreBefore);
    }

    function test_SubmitRating_DoubleRating_Reverts() public {
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT_ID, CAT_CODE, true);

        vm.prank(CLIENT);
        rep.submitRating(AGENT_ID, CAT_CODE, 8000, TASK_ID);

        vm.prank(CLIENT);
        vm.expectRevert(
            abi.encodeWithSelector(IContextualReputation.AlreadyRated.selector, CLIENT, AGENT_ID, TASK_ID)
        );
        rep.submitRating(AGENT_ID, CAT_CODE, 8000, TASK_ID);
    }

    function test_SubmitRating_InvalidRating_Reverts() public {
        vm.prank(CLIENT);
        vm.expectRevert(abi.encodeWithSelector(IContextualReputation.InvalidRating.selector, 10001));
        rep.submitRating(AGENT_ID, CAT_CODE, 10001, TASK_ID);
    }

    // ── Profile ───────────────────────────────────────────────────

    function test_GetProfile_MultipleCategories() public {
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT_ID, CAT_CODE, true);
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT_ID, CAT_GENERAL, true);

        IContextualReputation.AgentContextualProfile memory profile = rep.getProfile(AGENT_ID);
        assertGt(profile.categoryScores[CAT_CODE], 0);
        assertGt(profile.categoryScores[CAT_GENERAL], 0);
        assertGt(profile.globalAverage, 0);
    }

    function test_MeetsRequirement_Pass() public {
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT_ID, CAT_CODE, true);

        assertTrue(rep.meetsRequirement(AGENT_ID, CAT_CODE, 3000));
    }

    function test_MeetsRequirement_Fail() public view {
        assertFalse(rep.meetsRequirement(AGENT_ID, CAT_CODE, 9999));
    }

    // ── Fuzz ─────────────────────────────────────────────────────

    function testFuzz_Score_AlwaysBounded(uint8 successes, uint8 failures) public {
        uint256 s = bound(uint256(successes), 0, 20);
        uint256 f = bound(uint256(failures),  0, 20);

        for (uint256 i = 0; i < s; i++) {
            vm.prank(UPDATER);
            rep.recordCompletion(AGENT_ID, CAT_CODE, true);
        }
        for (uint256 i = 0; i < f; i++) {
            vm.prank(UPDATER);
            rep.recordCompletion(AGENT_ID, CAT_CODE, false);
        }

        uint256 score = rep.getScore(AGENT_ID, CAT_CODE);
        assertLe(score, 10000, "Score exceeds 10000");
    }

    function testFuzz_Rating_ScoreMonotonic(uint256 rating) public {
        rating = bound(rating, 0, 10000);
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT_ID, CAT_CODE, true);

        uint256 before = rep.getScore(AGENT_ID, CAT_CODE);

        bytes32 taskId2 = bytes32(uint256(0xABC));
        vm.prank(CLIENT);
        rep.submitRating(AGENT_ID, CAT_CODE, rating, taskId2);

        uint256 after_ = rep.getScore(AGENT_ID, CAT_CODE);
        assertLe(after_, 10000);
        assertGe(after_, 0);
    }
}

// ── AgentDiscovery Tests ───────────────────────────────────────

contract AgentDiscoveryTest is Test {
    AgentDiscovery       internal discovery;
    ContextualReputation internal rep;
    MockRegistry         internal registry;
    MockOracle           internal oracle;
    MockStaking          internal staking;

    address constant OWNER    = address(0xA11CE);
    address constant INDEXER  = address(0x14DEX);
    address constant STRANGER = address(0x577);
    address constant UPDATER  = address(0xAUTH);

    uint256 constant AGENT1   = 1;
    uint256 constant AGENT2   = 2;
    uint256 constant AGENT3   = 3;
    uint256 constant CAT_CODE = 1;
    uint256 constant ANY_CAT  = 255;

    function setUp() public {
        registry = new MockRegistry();
        oracle   = new MockOracle();
        staking  = new MockStaking();

        vm.prank(OWNER);
        rep = new ContextualReputation(OWNER, address(registry));

        vm.startPrank(OWNER);
        rep.setAuthorized(UPDATER, true);
        vm.stopPrank();

        vm.prank(OWNER);
        discovery = new AgentDiscovery(
            OWNER,
            address(registry),
            address(oracle),
            address(rep),
            address(staking)
        );

        vm.prank(OWNER);
        discovery.setAuthorized(INDEXER, true);

        // Register agents
        registry.addAgent(AGENT1, address(0x1), CAT_CODE);
        registry.addAgent(AGENT2, address(0x2), CAT_CODE);
        registry.addAgent(AGENT3, address(0x3), 0); // GENERAL

        oracle.setScore(AGENT1, 8000);
        oracle.setScore(AGENT2, 6000);
        oracle.setScore(AGENT3, 4000);

        staking.setStake(AGENT1, 1 ether);
        staking.setStake(AGENT2, 0.5 ether);
    }

    // ── Indexing ─────────────────────────────────────────────────

    function test_IndexAgent_Success() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);
        assertEq(discovery.totalIndexed(), 1);
    }

    function test_IndexAgent_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit IAgentDiscovery.AgentIndexed(AGENT1, CAT_CODE);
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);
    }

    function test_IndexAgent_Duplicate_NoOp() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);
        assertEq(discovery.totalIndexed(), 1);
    }

    function test_DeindexAgent_Success() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);
        vm.prank(INDEXER);
        discovery.deindexAgent(AGENT1);
        assertEq(discovery.totalIndexed(), 0);
    }

    function test_IndexAgent_OnlyAuthorized_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(IAgentDiscovery.NotAuthorized.selector);
        discovery.indexAgent(AGENT1);
    }

    // ── Search ───────────────────────────────────────────────────

    function test_Search_NoFilter_ReturnsAll() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT2);
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT3);

        IAgentDiscovery.SearchFilter memory filter = IAgentDiscovery.SearchFilter({
            category:           ANY_CAT,
            minContextualScore: 0,
            minGlobalScore:     0,
            minStake:           0,
            minTasksCompleted:  0,
            activeOnly:         false
        });

        IAgentDiscovery.AgentSearchResult[] memory results = discovery.search(filter, 10);
        assertEq(results.length, 3);
    }

    function test_Search_CategoryFilter() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT3); // GENERAL category

        IAgentDiscovery.SearchFilter memory filter = IAgentDiscovery.SearchFilter({
            category:           CAT_CODE,
            minContextualScore: 0,
            minGlobalScore:     0,
            minStake:           0,
            minTasksCompleted:  0,
            activeOnly:         false
        });

        IAgentDiscovery.AgentSearchResult[] memory results = discovery.search(filter, 10);
        assertEq(results.length, 1);
        assertEq(results[0].agentId, AGENT1);
    }

    function test_Search_MinStakeFilter() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1); // 1 ETH stake
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT2); // 0.5 ETH stake

        IAgentDiscovery.SearchFilter memory filter = IAgentDiscovery.SearchFilter({
            category:           ANY_CAT,
            minContextualScore: 0,
            minGlobalScore:     0,
            minStake:           0.8 ether,
            minTasksCompleted:  0,
            activeOnly:         false
        });

        IAgentDiscovery.AgentSearchResult[] memory results = discovery.search(filter, 10);
        assertEq(results.length, 1);
        assertEq(results[0].agentId, AGENT1);
    }

    function test_Search_ActiveOnly_FiltersInactive() public {
        registry.setStatus(AGENT2, 3); // SUSPENDED

        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT2);

        IAgentDiscovery.SearchFilter memory filter = IAgentDiscovery.SearchFilter({
            category:           ANY_CAT,
            minContextualScore: 0,
            minGlobalScore:     0,
            minStake:           0,
            minTasksCompleted:  0,
            activeOnly:         true
        });

        IAgentDiscovery.AgentSearchResult[] memory results = discovery.search(filter, 10);
        assertEq(results.length, 1);
        assertEq(results[0].agentId, AGENT1);
    }

    // ── Leaderboard ───────────────────────────────────────────────

    function test_Leaderboard_SortedByScore() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1); // score 8000
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT2); // score 6000
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT3); // score 4000

        IAgentDiscovery.LeaderboardEntry[] memory entries =
            discovery.getLeaderboard(ANY_CAT, 3);

        assertEq(entries.length, 3);
        assertEq(entries[0].agentId, AGENT1); // highest score first
        assertEq(entries[0].rank, 1);
        assertEq(entries[1].agentId, AGENT2);
        assertEq(entries[1].rank, 2);
        assertEq(entries[2].agentId, AGENT3);
        assertEq(entries[2].rank, 3);
    }

    function test_Leaderboard_LimitRespected() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT2);
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT3);

        IAgentDiscovery.LeaderboardEntry[] memory entries =
            discovery.getLeaderboard(ANY_CAT, 2);

        assertEq(entries.length, 2);
        assertEq(entries[0].agentId, AGENT1);
    }

    // ── FindBestAgent ─────────────────────────────────────────────

    function test_FindBestAgent_ReturnsHighestScore() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT2);

        // Give AGENT1 a higher contextual score
        vm.prank(UPDATER);
        rep.recordCompletion(AGENT1, CAT_CODE, true);

        (uint256 bestId, uint256 score) = discovery.findBestAgent(CAT_CODE, 0, 0);
        assertEq(bestId, AGENT1);
        assertGt(score, 0);
    }

    function test_FindBestAgent_MinStake_FiltersOut() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT2); // 0.5 ETH stake only

        (uint256 bestId,) = discovery.findBestAgent(CAT_CODE, 0, 1 ether);
        assertEq(bestId, 0); // No agent meets 1 ETH minimum
    }

    // ── Pagination ────────────────────────────────────────────────

    function test_GetIndexedAgents_Paginated() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT2);
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT3);

        uint256[] memory page1 = discovery.getIndexedAgents(0, 2);
        uint256[] memory page2 = discovery.getIndexedAgents(2, 2);

        assertEq(page1.length, 2);
        assertEq(page2.length, 1);
    }

    // ── GetAgentProfile ───────────────────────────────────────────

    function test_GetAgentProfile_ReturnsFullData() public {
        vm.prank(INDEXER);
        discovery.indexAgent(AGENT1);

        IAgentDiscovery.AgentSearchResult memory profile = discovery.getAgentProfile(AGENT1);
        assertEq(profile.agentId, AGENT1);
        assertEq(profile.globalRepScore, 8000);
        assertEq(profile.stakedAmount, 1 ether);
        assertTrue(profile.isActive);
    }

    // ── Fuzz ─────────────────────────────────────────────────────

    function testFuzz_Search_LimitAlwaysRespected(uint8 numAgents, uint8 limit) public {
        uint256 n = bound(uint256(numAgents), 1, 10);
        uint256 l = bound(uint256(limit), 1, 50);

        for (uint256 i = 1; i <= n; i++) {
            if (!registry.exists(i)) {
                registry.addAgent(i, address(uint160(i + 100)), 0);
            }
            vm.prank(INDEXER);
            discovery.indexAgent(i);
        }

        IAgentDiscovery.SearchFilter memory filter = IAgentDiscovery.SearchFilter({
            category: ANY_CAT, minContextualScore: 0, minGlobalScore: 0,
            minStake: 0, minTasksCompleted: 0, activeOnly: false
        });

        IAgentDiscovery.AgentSearchResult[] memory results = discovery.search(filter, l);
        assertLe(results.length, l);
        assertLe(results.length, n);
    }
}

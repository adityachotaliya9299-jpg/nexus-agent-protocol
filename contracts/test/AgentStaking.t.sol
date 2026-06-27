// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AgentStaking} from "../src/staking/AgentStaking.sol";
import {IAgentStaking} from "../src/staking/IAgentStaking.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../src/interfaces/IReputationOracle.sol";

// ── Minimal stubs ─────────────────────────────────────────────

contract MockRegistry {
    mapping(uint256 => address) public owners;
    mapping(uint256 => bool)    public exists;

    function addAgent(uint256 agentId, address owner) external {
        owners[agentId] = owner;
        exists[agentId] = true;
    }

    function getAgent(uint256 agentId) external view returns (IAgentRegistry.AgentProfile memory p) {
        require(exists[agentId], "AgentNotFound");
        p.agentId = agentId;
        p.owner   = owners[agentId];
        p.status  = IAgentRegistry.AgentStatus.ACTIVE;
        return p;
    }
}

contract MockOracle {
    mapping(uint256 => uint256) public scores;

    function setScore(uint256 agentId, uint256 score) external {
        scores[agentId] = score;
    }

    function getScore(uint256 agentId) external view returns (uint256) {
        uint256 s = scores[agentId];
        return s == 0 ? 5000 : s;
    }
}

// ── Test contract ──────────────────────────────────────────────

contract AgentStakingTest is Test {
    AgentStaking internal staking;
    MockRegistry internal registry;
    MockOracle   internal oracle;

    address constant OWNER      = address(0xA11CE);
    address constant TREASURY   = address(0x7EA5);
    address constant AGENT_OWN  = address(0xA6E4);
    address constant DELEGATOR  = address(0xDE16);
    address constant MARKETPLACE = address(0x4A3E7);
    address constant ARBITRATOR = address(0xAB17);
    address constant STRANGER   = address(0x57A4);

    uint256 constant AGENT_ID   = 1;
    uint256 constant AGENT_ID_2 = 2;
    bytes32 constant TASK_ID    = bytes32(uint256(0xBEEF));

    function setUp() public {
        registry = new MockRegistry();
        oracle   = new MockOracle();

        vm.prank(OWNER);
        staking = new AgentStaking(OWNER, address(registry), address(oracle), TREASURY);

        // Register agents
        registry.addAgent(AGENT_ID,   AGENT_OWN);
        registry.addAgent(AGENT_ID_2, STRANGER);

        // Authorize marketplace + arbitrator
        vm.startPrank(OWNER);
        staking.setAuthorized(MARKETPLACE, true);
        staking.setAuthorized(ARBITRATOR,  true);
        vm.stopPrank();

        // Fund actors
        vm.deal(AGENT_OWN,  100 ether);
        vm.deal(DELEGATOR,  100 ether);
        vm.deal(STRANGER,   100 ether);
        vm.deal(MARKETPLACE, 0);
    }

    // ── Deployment ───────────────────────────────────────────────

    function test_Deploy_OwnerSet() public view {
        assertEq(staking.protocolOwner(), OWNER);
    }

    function test_Deploy_DefaultSlashRate() public view {
        assertEq(staking.slashRateBps(), 1000);
    }

    function test_Deploy_DefaultUnbondingDelay() public view {
        assertEq(staking.unbondingDelay(), 7 days);
    }

    function test_Deploy_TreasurySet() public view {
        assertEq(staking.treasury(), TREASURY);
    }

    function test_Deploy_ZeroAddress_Reverts() public {
        vm.expectRevert(IAgentStaking.ZeroAddress.selector);
        new AgentStaking(address(0), address(registry), address(oracle), TREASURY);
    }

    // ── Stake (own) ──────────────────────────────────────────────

    function test_Stake_Success() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 1 ether}(AGENT_ID);

        IAgentStaking.StakeInfo memory s = staking.getStake(AGENT_ID);
        assertEq(s.totalStaked, 1 ether);
        assertEq(s.ownStake, 1 ether);
        assertEq(s.delegatedStake, 0);
    }

    function test_Stake_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IAgentStaking.Staked(AGENT_ID, AGENT_OWN, 1 ether, false);
        vm.prank(AGENT_OWN);
        staking.stake{value: 1 ether}(AGENT_ID);
    }

    function test_Stake_MultipleDeposits_Accumulate() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 1 ether}(AGENT_ID);
        vm.prank(AGENT_OWN);
        staking.stake{value: 0.5 ether}(AGENT_ID);

        assertEq(staking.getStake(AGENT_ID).totalStaked, 1.5 ether);
    }

    function test_Stake_ZeroValue_Reverts() public {
        vm.prank(AGENT_OWN);
        vm.expectRevert(IAgentStaking.ZeroAmount.selector);
        staking.stake{value: 0}(AGENT_ID);
    }

    function test_Stake_NotOwner_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(IAgentStaking.NotAgentOwner.selector, AGENT_ID));
        staking.stake{value: 1 ether}(AGENT_ID);
    }

    function test_Stake_AgentNotFound_Reverts() public {
        vm.prank(AGENT_OWN);
        vm.expectRevert(abi.encodeWithSelector(IAgentStaking.AgentNotFound.selector, 999));
        staking.stake{value: 1 ether}(999);
    }

    // ── Delegated staking ────────────────────────────────────────

    function test_DelegateStake_Success() public {
        vm.prank(DELEGATOR);
        staking.delegateStake{value: 2 ether}(AGENT_ID);

        IAgentStaking.StakeInfo memory s = staking.getStake(AGENT_ID);
        assertEq(s.totalStaked, 2 ether);
        assertEq(s.delegatedStake, 2 ether);
        assertEq(s.ownStake, 0);
    }

    function test_DelegateStake_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IAgentStaking.Staked(AGENT_ID, DELEGATOR, 2 ether, true);
        vm.prank(DELEGATOR);
        staking.delegateStake{value: 2 ether}(AGENT_ID);
    }

    function test_DelegateStake_TrackedPerDelegator() public {
        vm.prank(DELEGATOR);
        staking.delegateStake{value: 2 ether}(AGENT_ID);

        assertEq(staking.getDelegatorStake(DELEGATOR, AGENT_ID), 2 ether);
        assertEq(staking.getDelegatorStake(STRANGER, AGENT_ID), 0);
    }

    function test_DelegateStake_Combined_WithOwnStake() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 1 ether}(AGENT_ID);
        vm.prank(DELEGATOR);
        staking.delegateStake{value: 2 ether}(AGENT_ID);

        assertEq(staking.getStake(AGENT_ID).totalStaked, 3 ether);
    }

    // ── Effective stake ──────────────────────────────────────────

    function test_EffectiveStake_AtDefaultRep() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 1 ether}(AGENT_ID);
        // Default oracle score = 5000, REPUTATION_SCALE = 5000
        // effectiveStake = 1 ether * 5000 / 5000 = 1 ether
        assertEq(staking.getEffectiveStake(AGENT_ID), 1 ether);
    }

    function test_EffectiveStake_AtMaxRep_Doubles() public {
        oracle.setScore(AGENT_ID, 10000);
        vm.prank(AGENT_OWN);
        staking.stake{value: 1 ether}(AGENT_ID);
        // effectiveStake = 1 ether * 10000 / 5000 = 2 ether
        assertEq(staking.getEffectiveStake(AGENT_ID), 2 ether);
    }

    function test_EffectiveStake_AtHalfRep_Halves() public {
        oracle.setScore(AGENT_ID, 2500);
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);
        // effectiveStake = 2 ether * 2500 / 5000 = 1 ether
        assertEq(staking.getEffectiveStake(AGENT_ID), 1 ether);
    }

    function test_EffectiveStake_ZeroStake_ReturnsZero() public view {
        assertEq(staking.getEffectiveStake(AGENT_ID), 0);
    }

    // ── Bid eligibility ──────────────────────────────────────────

    function test_IsEligibleToBid_NoStakeRequired() public view {
        assertTrue(staking.isEligibleToBid(AGENT_ID, 0));
    }

    function test_IsEligibleToBid_SufficientStake() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 1 ether}(AGENT_ID);
        assertTrue(staking.isEligibleToBid(AGENT_ID, 1 ether));
    }

    function test_IsEligibleToBid_InsufficientStake() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 0.5 ether}(AGENT_ID);
        assertFalse(staking.isEligibleToBid(AGENT_ID, 1 ether));
    }

    function test_IsEligibleToBid_HighRepUnlocks() public {
        oracle.setScore(AGENT_ID, 10000); // 2x multiplier
        vm.prank(AGENT_OWN);
        staking.stake{value: 0.5 ether}(AGENT_ID);
        // effective = 0.5 * 2 = 1 ether >= 1 ether requirement
        assertTrue(staking.isEligibleToBid(AGENT_ID, 1 ether));
    }

    // ── Task locking ─────────────────────────────────────────────

    function test_LockStakeForTask_Success() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(MARKETPLACE);
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 1 ether);

        IAgentStaking.StakeInfo memory s = staking.getStake(AGENT_ID);
        assertEq(s.lockedStake, 1 ether);
        assertEq(s.totalStaked, 2 ether); // total unchanged
    }

    function test_LockStakeForTask_EmitsEvent() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.expectEmit(true, true, false, true);
        emit IAgentStaking.StakeLocked(AGENT_ID, TASK_ID, 1 ether);
        vm.prank(MARKETPLACE);
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 1 ether);
    }

    function test_LockStakeForTask_InsufficientStake_Reverts() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 0.5 ether}(AGENT_ID);

        vm.prank(MARKETPLACE);
        vm.expectRevert(
            abi.encodeWithSelector(IAgentStaking.InsufficientStake.selector, AGENT_ID, 1 ether, 0.5 ether)
        );
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 1 ether);
    }

    function test_LockStakeForTask_DuplicateTask_Reverts() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(MARKETPLACE);
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 0.5 ether);

        vm.prank(MARKETPLACE);
        vm.expectRevert(abi.encodeWithSelector(IAgentStaking.TaskAlreadyLocked.selector, TASK_ID));
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 0.5 ether);
    }

    function test_LockStakeForTask_OnlyAuthorized() public {
        vm.prank(STRANGER);
        vm.expectRevert(IAgentStaking.NotAuthorized.selector);
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 1 ether);
    }

    function test_UnlockStakeForTask_Success() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(MARKETPLACE);
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 1 ether);

        vm.prank(MARKETPLACE);
        staking.unlockStakeForTask(AGENT_ID, TASK_ID);

        assertEq(staking.getStake(AGENT_ID).lockedStake, 0);
    }

    function test_UnlockStakeForTask_EmitsEvent() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(MARKETPLACE);
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 1 ether);

        vm.expectEmit(true, true, false, true);
        emit IAgentStaking.StakeUnlocked(AGENT_ID, TASK_ID, 1 ether);
        vm.prank(MARKETPLACE);
        staking.unlockStakeForTask(AGENT_ID, TASK_ID);
    }

    // ── Unstaking ────────────────────────────────────────────────

    function test_RequestUnstake_Success() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(AGENT_OWN);
        staking.requestUnstake(AGENT_ID, 1 ether);

        IAgentStaking.StakeInfo memory s = staking.getStake(AGENT_ID);
        assertGt(s.unstakeRequestedAt, 0);
        assertEq(s.unstakeAmount, 1 ether);
    }

    function test_RequestUnstake_EmitsEvent() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.expectEmit(true, true, false, true);
        emit IAgentStaking.UnstakeRequested(AGENT_ID, AGENT_OWN, 1 ether);
        vm.prank(AGENT_OWN);
        staking.requestUnstake(AGENT_ID, 1 ether);
    }

    function test_Unstake_AfterDelay_Success() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(AGENT_OWN);
        staking.requestUnstake(AGENT_ID, 1 ether);

        // Advance past unbonding delay
        vm.warp(block.timestamp + 7 days + 1);

        uint256 balBefore = AGENT_OWN.balance;
        vm.prank(AGENT_OWN);
        staking.unstake(AGENT_ID);

        assertEq(AGENT_OWN.balance, balBefore + 1 ether);
        assertEq(staking.getStake(AGENT_ID).totalStaked, 1 ether);
    }

    function test_Unstake_BeforeDelay_Reverts() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(AGENT_OWN);
        staking.requestUnstake(AGENT_ID, 1 ether);

        vm.prank(AGENT_OWN);
        vm.expectRevert(); // UnbondingNotComplete
        staking.unstake(AGENT_ID);
    }

    function test_Unstake_LockedStake_CannotRequest() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(MARKETPLACE);
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 2 ether);

        vm.prank(AGENT_OWN);
        vm.expectRevert(
            abi.encodeWithSelector(IAgentStaking.InsufficientStake.selector, AGENT_ID, 1 ether, 0)
        );
        staking.requestUnstake(AGENT_ID, 1 ether);
    }

    function test_RequestUnstake_DuplicateRequest_Reverts() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(AGENT_OWN);
        staking.requestUnstake(AGENT_ID, 1 ether);

        vm.prank(AGENT_OWN);
        vm.expectRevert(abi.encodeWithSelector(IAgentStaking.UnstakePending.selector, AGENT_ID));
        staking.requestUnstake(AGENT_ID, 0.5 ether);
    }

    // ── Slashing ─────────────────────────────────────────────────

    function test_Slash_ReducesStake() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(ARBITRATOR);
        staking.slashStake(AGENT_ID, 1000, TREASURY, "dispute lost"); // 10%

        assertEq(staking.getStake(AGENT_ID).totalStaked, 1.8 ether);
    }

    function test_Slash_SendsToRecipient() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        uint256 balBefore = TREASURY.balance;
        vm.prank(ARBITRATOR);
        staking.slashStake(AGENT_ID, 1000, TREASURY, "dispute lost");

        assertEq(TREASURY.balance, balBefore + 0.2 ether);
    }

    function test_Slash_EmitsEvent() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.expectEmit(true, false, true, true);
        emit IAgentStaking.Slashed(AGENT_ID, 0.2 ether, TREASURY, "dispute lost");
        vm.prank(ARBITRATOR);
        staking.slashStake(AGENT_ID, 1000, TREASURY, "dispute lost");
    }

    function test_Slash_IncrementsSlashCount() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(ARBITRATOR);
        staking.slashStake(AGENT_ID, 1000, TREASURY, "first slash");

        assertEq(staking.getStake(AGENT_ID).slashCount, 1);

        vm.prank(ARBITRATOR);
        staking.slashStake(AGENT_ID, 1000, TREASURY, "second slash");

        assertEq(staking.getStake(AGENT_ID).slashCount, 2);
    }

    function test_Slash_OnlyAuthorized() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(STRANGER);
        vm.expectRevert(IAgentStaking.NotAuthorized.selector);
        staking.slashStake(AGENT_ID, 1000, TREASURY, "unauthorized");
    }

    function test_Slash_ExceedsMax_Reverts() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(ARBITRATOR);
        vm.expectRevert(IAgentStaking.InvalidSlashRate.selector);
        staking.slashStake(AGENT_ID, 5001, TREASURY, "too high"); // > MAX_SLASH_BPS
    }

    function test_Slash_AlsoSlashesDelegators() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 1 ether}(AGENT_ID);

        vm.prank(DELEGATOR);
        staking.delegateStake{value: 1 ether}(AGENT_ID);

        vm.prank(ARBITRATOR);
        staking.slashStake(AGENT_ID, 1000, TREASURY, "slash"); // 10%

        // Total = 2 ether, slash 10% = 0.2 ether
        assertEq(staking.getStake(AGENT_ID).totalStaked, 1.8 ether);
        // Delegator's recorded stake reduced
        assertEq(staking.getDelegatorStake(DELEGATOR, AGENT_ID), 0.9 ether);
    }

    // ── Remove delegated stake ────────────────────────────────────

    function test_RemoveDelegatedStake_Success() public {
        vm.prank(DELEGATOR);
        staking.delegateStake{value: 2 ether}(AGENT_ID);

        uint256 balBefore = DELEGATOR.balance;
        vm.prank(DELEGATOR);
        staking.removeDelegatedStake(AGENT_ID);

        assertEq(DELEGATOR.balance, balBefore + 2 ether);
        assertEq(staking.getDelegatorStake(DELEGATOR, AGENT_ID), 0);
    }

    function test_RemoveDelegatedStake_WhenLocked_Reverts() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 1 ether}(AGENT_ID);
        vm.prank(DELEGATOR);
        staking.delegateStake{value: 1 ether}(AGENT_ID);

        vm.prank(MARKETPLACE);
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 1.5 ether);

        vm.prank(DELEGATOR);
        vm.expectRevert(
            abi.encodeWithSelector(IAgentStaking.StakeLocked.selector, AGENT_ID, 1.5 ether)
        );
        staking.removeDelegatedStake(AGENT_ID);
    }

    function test_RemoveDelegatedStake_NoDelegation_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(
            abi.encodeWithSelector(IAgentStaking.NoDelegationFound.selector, STRANGER, AGENT_ID)
        );
        staking.removeDelegatedStake(AGENT_ID);
    }

    // ── Admin functions ──────────────────────────────────────────

    function test_SetSlashRate_Success() public {
        vm.prank(OWNER);
        staking.setSlashRate(2000);
        assertEq(staking.slashRateBps(), 2000);
    }

    function test_SetSlashRate_TooHigh_Reverts() public {
        vm.prank(OWNER);
        vm.expectRevert(IAgentStaking.InvalidSlashRate.selector);
        staking.setSlashRate(5001);
    }

    function test_SetUnbondingDelay_Success() public {
        vm.prank(OWNER);
        staking.setUnbondingDelay(14 days);
        assertEq(staking.unbondingDelay(), 14 days);
    }

    function test_SetAuthorized_Success() public {
        vm.prank(OWNER);
        staking.setAuthorized(address(0x1234), true);
        assertTrue(staking.isAuthorized(address(0x1234)));
    }

    // ── Integration ──────────────────────────────────────────────

    function test_Integration_FullStakeCycle() public {
        // Stake
        vm.prank(AGENT_OWN);
        staking.stake{value: 3 ether}(AGENT_ID);

        // Delegate
        vm.prank(DELEGATOR);
        staking.delegateStake{value: 1 ether}(AGENT_ID);

        // Lock for task
        vm.prank(MARKETPLACE);
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 2 ether);

        // Verify bid eligibility
        assertFalse(staking.isEligibleToBid(AGENT_ID, 3 ether)); // 2 ether locked
        assertTrue(staking.isEligibleToBid(AGENT_ID, 2 ether));  // 2 ether still free

        // Complete task → unlock
        vm.prank(MARKETPLACE);
        staking.unlockStakeForTask(AGENT_ID, TASK_ID);

        // Request unstake
        vm.prank(AGENT_OWN);
        staking.requestUnstake(AGENT_ID, 2 ether);

        // Warp + finalize
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(AGENT_OWN);
        staking.unstake(AGENT_ID);

        assertEq(staking.getStake(AGENT_ID).ownStake, 1 ether);
    }

    function test_Integration_SlashDuringTaskLock() public {
        vm.prank(AGENT_OWN);
        staking.stake{value: 2 ether}(AGENT_ID);

        vm.prank(MARKETPLACE);
        staking.lockStakeForTask(AGENT_ID, TASK_ID, 1 ether);

        // Slash during active task
        vm.prank(ARBITRATOR);
        staking.slashStake(AGENT_ID, 1000, TREASURY, "misbehavior"); // 10% of 2 ether = 0.2 ether

        // Locked stake also reduced
        assertEq(staking.getStake(AGENT_ID).lockedStake, 0.8 ether);
        assertEq(staking.getStake(AGENT_ID).totalStaked, 1.8 ether);
    }

    // ── Fuzz tests ───────────────────────────────────────────────

    function testFuzz_Stake_AlwaysAccepted(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(AGENT_OWN, uint256(amount));
        vm.prank(AGENT_OWN);
        staking.stake{value: amount}(AGENT_ID);
        assertEq(staking.getStake(AGENT_ID).totalStaked, amount);
    }

    function testFuzz_EffectiveStake_AlwaysProportional(uint96 rawStake, uint16 score) public {
        vm.assume(rawStake > 0);
        uint256 boundedScore = bound(uint256(score), 1, 10000);
        oracle.setScore(AGENT_ID, boundedScore);

        vm.deal(AGENT_OWN, rawStake);
        vm.prank(AGENT_OWN);
        staking.stake{value: rawStake}(AGENT_ID);

        uint256 effective = staking.getEffectiveStake(AGENT_ID);
        uint256 expected  = (uint256(rawStake) * boundedScore) / 5000;
        assertEq(effective, expected);
    }

    function testFuzz_Slash_NeverExceedsTotalStake(uint96 stakeAmount, uint16 slashBps) public {
        vm.assume(stakeAmount > 0.001 ether);
        uint256 bps = bound(uint256(slashBps), 1, 5000);

        vm.deal(AGENT_OWN, stakeAmount);
        vm.prank(AGENT_OWN);
        staking.stake{value: stakeAmount}(AGENT_ID);

        vm.prank(ARBITRATOR);
        staking.slashStake(AGENT_ID, bps, TREASURY, "fuzz slash");

        assertLe(staking.getStake(AGENT_ID).totalStaked, stakeAmount);
    }
}

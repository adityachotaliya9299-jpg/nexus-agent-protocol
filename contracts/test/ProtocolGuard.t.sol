// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProtocolGuard} from "../src/security/ProtocolGuard.sol";
import {IProtocolGuard} from "../src/security/IProtocolGuard.sol";

/// @notice Mock contract with an invariant check function
contract MockTarget {
    bool public invariantShouldPass = true;
    function setInvariant(bool v) external { invariantShouldPass = v; }
    function checkInvariant_EscrowSolvent() external view returns (bool) {
        return invariantShouldPass;
    }
}

contract ProtocolGuardTest is Test {
    ProtocolGuard internal guard;
    MockTarget    internal target;

    address constant OWNER    = address(0xA11CE);
    address constant GUARDIAN1 = address(0xA111);
    address constant GUARDIAN2 = address(0xA222);
    address constant GUARDIAN3 = address(0xA333);
    address constant STRANGER  = address(0x577);

    function setUp() public {
        vm.prank(OWNER);
        guard  = new ProtocolGuard(OWNER);
        target = new MockTarget();

        vm.startPrank(OWNER);
        guard.addGuardian(GUARDIAN1);
        guard.addGuardian(GUARDIAN2);
        guard.addGuardian(GUARDIAN3);
        vm.stopPrank();
    }

    // ── Deployment ───────────────────────────────────────────────

    function test_Deploy_OwnerSet() public view {
        assertEq(guard.protocolOwner(), OWNER);
    }

    function test_Deploy_ZeroAddress_Reverts() public {
        vm.expectRevert(IProtocolGuard.ZeroAddress.selector);
        new ProtocolGuard(address(0));
    }

    function test_Deploy_DefaultRateLimit() public view {
        IProtocolGuard.RateLimit memory rl = guard.getRateLimit();
        assertEq(rl.windowSeconds, 3600);
        assertEq(rl.maxOutflowWei, 10 ether);
    }

    // ── Circuit Breaker ───────────────────────────────────────────

    function test_Pause_Success() public {
        vm.prank(OWNER);
        guard.pause(address(target), "Security concern", 1 hours);

        assertTrue(guard.isPaused(address(target)));
        IProtocolGuard.ContractStatus memory s = guard.getContractStatus(address(target));
        assertEq(s.pausedBy, OWNER);
        assertEq(s.pauseReason, "Security concern");
    }

    function test_Pause_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit IProtocolGuard.ContractPaused(address(target), OWNER, "reason", 0);
        vm.prank(OWNER);
        guard.pause(address(target), "reason", 1 hours);
    }

    function test_Pause_ByGuardian_Success() public {
        vm.prank(GUARDIAN1);
        guard.pause(address(target), "Guardian pause", 2 hours);
        assertTrue(guard.isPaused(address(target)));
    }

    function test_Pause_ByStranger_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(IProtocolGuard.NotAuthorized.selector);
        guard.pause(address(target), "hack", 1 hours);
    }

    function test_Pause_TooLong_Reverts() public {
        vm.prank(OWNER);
        vm.expectRevert(); // PauseTooLong
        guard.pause(address(target), "too long", 8 days);
    }

    function test_Pause_AlreadyPaused_Reverts() public {
        vm.prank(OWNER);
        guard.pause(address(target), "first", 1 hours);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(IProtocolGuard.AlreadyPaused.selector, address(target)));
        guard.pause(address(target), "second", 1 hours);
    }

    function test_Unpause_ByOwner_Success() public {
        vm.prank(OWNER);
        guard.pause(address(target), "test", 1 hours);

        vm.prank(OWNER);
        guard.unpause(address(target));

        assertFalse(guard.isPaused(address(target)));
    }

    function test_Unpause_EmitsEvent() public {
        vm.prank(OWNER);
        guard.pause(address(target), "test", 1 hours);

        vm.expectEmit(true, true, false, false);
        emit IProtocolGuard.ContractUnpaused(address(target), OWNER);
        vm.prank(OWNER);
        guard.unpause(address(target));
    }

    function test_Unpause_ByGuardians_NeedsQuorum() public {
        vm.prank(OWNER);
        guard.pause(address(target), "test", 1 hours);

        // One guardian votes — not enough (need 2)
        vm.prank(GUARDIAN1);
        guard.unpause(address(target));
        assertTrue(guard.isPaused(address(target))); // still paused

        // Second guardian votes — quorum reached
        vm.prank(GUARDIAN2);
        guard.unpause(address(target));
        assertFalse(guard.isPaused(address(target))); // now unpaused
    }

    function test_Pause_AutoExpires() public {
        vm.prank(OWNER);
        guard.pause(address(target), "test", 1 hours);

        vm.warp(block.timestamp + 1 hours + 1);
        assertFalse(guard.isPaused(address(target))); // expired
    }

    function test_PauseAll_Success() public {
        vm.prank(OWNER);
        guard.pauseAll("Emergency");

        assertTrue(guard.globalPause());
        // Any contract is paused when global pause is on
        assertTrue(guard.isPaused(address(target)));
        assertTrue(guard.isPaused(address(0x1234)));
    }

    function test_UnpauseAll_OnlyOwner() public {
        vm.prank(OWNER);
        guard.pauseAll("Emergency");

        vm.prank(STRANGER);
        vm.expectRevert(IProtocolGuard.NotAuthorized.selector);
        guard.unpauseAll();

        vm.prank(OWNER);
        guard.unpauseAll();
        assertFalse(guard.globalPause());
    }

    function test_TotalPauses_TrackedCorrectly() public {
        vm.prank(OWNER);
        guard.pause(address(target), "first", 1 hours);
        vm.prank(OWNER);
        guard.unpause(address(target));

        vm.prank(OWNER);
        guard.pause(address(target), "second", 1 hours);

        assertEq(guard.getContractStatus(address(target)).totalPauses, 2);
    }

    // ── Invariant Monitor ─────────────────────────────────────────

    function test_RegisterInvariant_Success() public {
        vm.prank(OWNER);
        bytes32 id = guard.registerInvariant(
            "Escrow always solvent",
            address(target),
            target.checkInvariant_EscrowSolvent.selector,
            false
        );

        IProtocolGuard.Invariant memory inv = guard.getInvariant(id);
        assertEq(inv.description, "Escrow always solvent");
        assertEq(inv.target, address(target));
        assertTrue(inv.isActive);
        assertEq(guard.totalInvariants(), 1);
    }

    function test_CheckInvariant_Passes() public {
        vm.prank(OWNER);
        bytes32 id = guard.registerInvariant(
            "Solvent", address(target),
            target.checkInvariant_EscrowSolvent.selector, false
        );

        bool passed = guard.checkInvariant(id);
        assertTrue(passed);
    }

    function test_CheckInvariant_Fails_EmitsEvent() public {
        vm.prank(OWNER);
        bytes32 id = guard.registerInvariant(
            "Solvent", address(target),
            target.checkInvariant_EscrowSolvent.selector, false
        );

        target.setInvariant(false);

        vm.expectEmit(true, true, false, false);
        emit IProtocolGuard.InvariantViolated(id, address(target), 0);
        bool passed = guard.checkInvariant(id);
        assertFalse(passed);
        assertEq(guard.getInvariant(id).violationCount, 1);
    }

    function test_CheckInvariant_AutoPause_OnFail() public {
        vm.prank(OWNER);
        bytes32 id = guard.registerInvariant(
            "Solvent", address(target),
            target.checkInvariant_EscrowSolvent.selector,
            true // autoPauseOnFail
        );

        target.setInvariant(false);
        guard.checkInvariant(id);

        assertTrue(guard.isPaused(address(target)));
    }

    function test_CheckAllInvariants_ReturnsCount() public {
        vm.startPrank(OWNER);
        guard.registerInvariant("A", address(target), target.checkInvariant_EscrowSolvent.selector, false);
        guard.registerInvariant("B", address(target), target.checkInvariant_EscrowSolvent.selector, false);
        vm.stopPrank();

        (uint256 passed, uint256 failed) = guard.checkAllInvariants();
        assertEq(passed, 2);
        assertEq(failed, 0);
    }

    // ── Guardian System ───────────────────────────────────────────

    function test_AddGuardian_Success() public {
        assertTrue(guard.isGuardian(GUARDIAN1));
        assertEq(guard.guardianCount(), 3);
    }

    function test_AddGuardian_OnlyOwner() public {
        vm.prank(STRANGER);
        vm.expectRevert(IProtocolGuard.NotAuthorized.selector);
        guard.addGuardian(STRANGER);
    }

    function test_RemoveGuardian_Success() public {
        vm.prank(OWNER);
        guard.removeGuardian(GUARDIAN1);
        assertFalse(guard.isGuardian(GUARDIAN1));
        assertEq(guard.guardianCount(), 2);
    }

    // ── Rate Limiter ──────────────────────────────────────────────

    function test_RateLimit_NormalOutflow_NoPause() public {
        guard.recordOutflow(address(target), 1 ether);
        assertFalse(guard.isPaused(address(target)));
    }

    function test_RateLimit_ExcessiveOutflow_AutoPause() public {
        vm.expectEmit(true, false, false, false);
        emit IProtocolGuard.RateLimitTriggered(address(target), 0, 0);
        guard.recordOutflow(address(target), 11 ether); // exceeds 10 ETH limit

        assertTrue(guard.isPaused(address(target)));
    }

    function test_RateLimit_WindowReset() public {
        guard.recordOutflow(address(target), 9 ether);
        assertFalse(guard.isPaused(address(target)));

        // Advance past window
        vm.warp(block.timestamp + 3601);
        guard.recordOutflow(address(target), 9 ether); // new window
        assertFalse(guard.isPaused(address(target)));
    }

    function test_SetRateLimit_OnlyOwner() public {
        vm.prank(OWNER);
        guard.setRateLimit(7200, 20 ether);

        IProtocolGuard.RateLimit memory rl = guard.getRateLimit();
        assertEq(rl.windowSeconds, 7200);
        assertEq(rl.maxOutflowWei, 20 ether);
    }

    // ── Integration ───────────────────────────────────────────────

    function test_Integration_InvariantViolation_AutoPause_GuardianUnpause() public {
        vm.prank(OWNER);
        bytes32 invId = guard.registerInvariant(
            "Escrow solvent", address(target),
            target.checkInvariant_EscrowSolvent.selector, true
        );

        // 1. Invariant fails → auto-pause
        target.setInvariant(false);
        guard.checkInvariant(invId);
        assertTrue(guard.isPaused(address(target)));

        // 2. Team investigates and fixes the issue
        target.setInvariant(true);

        // 3. Two guardians vote to unpause
        vm.prank(GUARDIAN1);
        guard.unpause(address(target));
        assertTrue(guard.isPaused(address(target))); // still need second vote

        vm.prank(GUARDIAN2);
        guard.unpause(address(target));
        assertFalse(guard.isPaused(address(target))); // unpaused

        // 4. Verify invariant passes now
        bool passed = guard.checkInvariant(invId);
        assertTrue(passed);
    }

    // ── Fuzz ─────────────────────────────────────────────────────

    function testFuzz_Pause_DurationBounded(uint256 duration) public {
        duration = bound(duration, 1, 7 days);
        vm.prank(OWNER);
        guard.pause(address(target), "fuzz", duration);
        assertTrue(guard.isPaused(address(target)));
    }

    function testFuzz_RateLimit_SmallAmounts_NeverPause(uint96 amount) public {
        amount = uint96(bound(uint256(amount), 0, 5 ether));
        guard.recordOutflow(address(target), amount);
        // Under 10 ETH → should never auto-pause
        if (amount <= 10 ether) {
            assertFalse(guard.isPaused(address(target)));
        }
    }
}

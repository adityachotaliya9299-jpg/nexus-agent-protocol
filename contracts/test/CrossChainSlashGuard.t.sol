// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CrossChainSlashGuard} from "../src/bridge/CrossChainSlashGuard.sol";

/// @notice Harness that exposes internal functions for testing
contract GuardHarness is CrossChainSlashGuard {
    function recordSlash(uint256 agentId, uint256 bps, bytes32 msgId, uint256 srcChain) external {
        _recordSlashInitiated(agentId, bps, msgId, srcChain);
    }

    function applySlash(uint256 agentId, uint256 bps, bytes32 msgId, uint256 srcChain, uint256 nonce) external {
        _applyReceivedSlash(agentId, bps, msgId, srcChain, nonce);
    }

    function checkAction(uint256 agentId, uint256 value, bool strict) external {
        _beforeCrossChainAction(agentId, value, strict);
    }
}

contract CrossChainSlashGuardTest is Test {
    GuardHarness internal guard;

    uint256 constant AGENT_ID    = 1;
    uint256 constant SLASH_BPS   = 1000;
    uint256 constant SRC_CHAIN   = 11155111; // Sepolia
    bytes32 constant MSG_ID      = bytes32(uint256(0xBEEF));
    bytes32 constant MSG_ID_2    = bytes32(uint256(0xCAFE));

    function setUp() public {
        guard = new GuardHarness();
    }

    // ── No pending slash — actions pass ──────────────────────────

    function test_NoSlash_ActionAllowed() public  {
        guard.checkAction(AGENT_ID, 100 ether, true); // no revert
    }

    // ── Pending slash — strict mode blocks ────────────────────────

    function test_PendingSlash_StrictMode_Blocks() public {
        guard.recordSlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN);

        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainSlashGuard.AgentInSyncWindow.selector,
                AGENT_ID,
                block.timestamp + guard.SYNC_WINDOW()
            )
        );
        guard.checkAction(AGENT_ID, 0, true);
    }

    function test_PendingSlash_NonStrictMode_SmallValue_Passes() public {
        guard.recordSlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN);
        // Small value within cap — should not revert
        guard.checkAction(AGENT_ID, 0.05 ether, false);
    }

    function test_PendingSlash_NonStrictMode_LargeValue_Reverts() public {
        guard.recordSlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN);

        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainSlashGuard.ActionValueTooHighDuringSyncWindow.selector,
                1 ether,
                guard.MAX_ACTION_IN_WINDOW()
            )
        );
        guard.checkAction(AGENT_ID, 1 ether, false);
    }

    // ── After sync window expires — actions pass ──────────────────

    function test_AfterSyncWindow_ActionAllowed() public {
        guard.recordSlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN);

        vm.warp(block.timestamp + guard.SYNC_WINDOW() + 1);
        guard.checkAction(AGENT_ID, 100 ether, true); // no revert
    }

    // ── Applied slash — actions pass ──────────────────────────────

    function test_AppliedSlash_ActionAllowed() public {
        guard.recordSlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN);
        guard.applySlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN, 1);

        // After apply, window is cleared
        guard.checkAction(AGENT_ID, 100 ether, true); // no revert
    }

    // ── Replay protection ─────────────────────────────────────────

    function test_ReplayProtection_SameMessageId_Reverts() public {
        guard.applySlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainSlashGuard.MessageAlreadyProcessed.selector, MSG_ID
            )
        );
        guard.applySlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN, 2);
    }

    // ── Nonce enforcement ─────────────────────────────────────────

    function test_Nonce_FirstMessage_MustBeOne() public {
        guard.applySlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN, 1); // nonce=1 OK

        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainSlashGuard.NonceOutOfOrder.selector, AGENT_ID, 3, 2
            )
        );
        guard.applySlash(AGENT_ID, SLASH_BPS, MSG_ID_2, SRC_CHAIN, 3); // skipped 2
    }

    function test_Nonce_ZeroFirst_Reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainSlashGuard.NonceOutOfOrder.selector, AGENT_ID, 0, 1
            )
        );
        guard.applySlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN, 0);
    }

    function test_Nonce_Sequential_AllPass() public {
        bytes32[3] memory ids = [
            bytes32(uint256(0xAAA)),
            bytes32(uint256(0xBBB)),
            bytes32(uint256(0xCCC))
        ];

        guard.applySlash(AGENT_ID, SLASH_BPS, ids[0], SRC_CHAIN, 1);
        guard.applySlash(AGENT_ID, SLASH_BPS, ids[1], SRC_CHAIN, 2);
        guard.applySlash(AGENT_ID, SLASH_BPS, ids[2], SRC_CHAIN, 3);

        assertEq(guard.getAgentNonce(AGENT_ID, SRC_CHAIN), 3);
    }

    // ── isInSyncWindow ────────────────────────────────────────────

    function test_IsInSyncWindow_TrueWhenPending() public {
        guard.recordSlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN);
        assertTrue(guard.isInSyncWindow(AGENT_ID));
    }

    function test_IsInSyncWindow_FalseAfterWindow() public {
        guard.recordSlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN);
        vm.warp(block.timestamp + guard.SYNC_WINDOW() + 1);
        assertFalse(guard.isInSyncWindow(AGENT_ID));
    }

    function test_IsInSyncWindow_FalseAfterApply() public {
        guard.recordSlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN);
        guard.applySlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN, 1);
        assertFalse(guard.isInSyncWindow(AGENT_ID));
    }

    function test_IsInSyncWindow_FalseBeforeSlash() public view {
        assertFalse(guard.isInSyncWindow(AGENT_ID));
    }

    // ── isMessageProcessed ────────────────────────────────────────

    function test_IsMessageProcessed_FalseBeforeApply() public view {
        assertFalse(guard.isMessageProcessed(MSG_ID));
    }

    function test_IsMessageProcessed_TrueAfterApply() public {
        guard.applySlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN, 1);
        assertTrue(guard.isMessageProcessed(MSG_ID));
    }

    // ── Multiple agents — independent state ───────────────────────

    function test_MultipleAgents_IndependentSlashState() public {
        guard.recordSlash(1, SLASH_BPS, bytes32(uint256(0xA1)), SRC_CHAIN);

        // Agent 2 not slashed — action passes
        guard.checkAction(2, 100 ether, true); // no revert

        // Agent 1 slashed — action blocked
        vm.expectRevert();
        guard.checkAction(1, 0, true);
    }

    // ── Fuzz ─────────────────────────────────────────────────────

    function testFuzz_SyncWindow_BoundaryExact(uint256 warpSeconds) public {
        warpSeconds = bound(warpSeconds, 1, guard.SYNC_WINDOW() * 2);
        guard.recordSlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN);

        vm.warp(block.timestamp + warpSeconds);

        bool inWindow = warpSeconds <= guard.SYNC_WINDOW();
        if (inWindow) {
            vm.expectRevert();
            guard.checkAction(AGENT_ID, 0, true);
        } else {
            guard.checkAction(AGENT_ID, 100 ether, true); // no revert
        }
    }

    function testFuzz_ValueCap_Boundary(uint256 value) public {
        value = bound(value, 0, 10 ether);
        guard.recordSlash(AGENT_ID, SLASH_BPS, MSG_ID, SRC_CHAIN);

        if (value <= guard.MAX_ACTION_IN_WINDOW()) {
            guard.checkAction(AGENT_ID, value, false); // should pass
        } else {
            vm.expectRevert();
            guard.checkAction(AGENT_ID, value, false);
        }
    }
}

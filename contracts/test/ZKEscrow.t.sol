// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ZKEscrow} from "../src/escrow/ZKEscrow.sol";
import {IZKEscrow} from "../src/escrow/IZKEscrow.sol";

// ── Stubs ──────────────────────────────────────────────────────

/// @notice Controllable Groth16 verifier for testing
contract MockGroth16Verifier {
    bool public shouldPass = true;

    function setResult(bool pass) external { shouldPass = pass; }

    function verifyProof(
        uint256[2] calldata,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[2] calldata
    ) external view returns (bool) {
        return shouldPass;
    }
}

// ── Tests ──────────────────────────────────────────────────────

contract ZKEscrowTest is Test {
    ZKEscrow            internal escrow;
    MockGroth16Verifier internal verifier;

    address constant OWNER      = address(0xA11CE);
    address constant ARBITRATOR = address(0xAA);
    address constant CLIENT     = address(0xC11E4);
    address payable  AGENT_WALL = payable(address(0xAWA11));
    address constant STRANGER   = address(0x577A4);

    bytes32 constant TASK_ID    = bytes32(uint256(0xBEEF));
    uint256 constant AMOUNT     = 1 ether;
    uint256 constant DEADLINE   = 7 days;

    // ZK proof components (mock — verifier is mocked so values don't matter)
    uint256[2]    internal pA = [uint256(1), uint256(2)];
    uint256[2][2] internal pB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
    uint256[2]    internal pC = [uint256(7), uint256(8)];
    uint256[2]    internal pubSignals = [uint256(9), uint256(10)];

    // Commitment scheme helpers
    bytes32 constant RESULT_HASH = bytes32(uint256(0xRESULT));
    bytes32 constant SALT        = bytes32(uint256(0x5A17));

    function setUp() public {
        verifier = new MockGroth16Verifier();

        vm.prank(OWNER);
        escrow = new ZKEscrow(OWNER, address(verifier), ARBITRATOR);

        vm.deal(CLIENT,   10 ether);
        vm.deal(STRANGER,  1 ether);
    }

    // ── Helpers ───────────────────────────────────────────────────

    function _commitment() internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(RESULT_HASH, SALT));
    }

    function _createEscrow() internal returns (bytes32 escrowId) {
        vm.prank(CLIENT);
        escrowId = escrow.createEscrow{value: AMOUNT}(
            TASK_ID, AGENT_WALL, block.timestamp + DEADLINE
        );
    }

    function _createAndCommit() internal returns (bytes32 escrowId) {
        escrowId = _createEscrow();
        vm.prank(CLIENT);
        escrow.setCommitment(escrowId, _commitment());
    }

    function _releaseWithProof(bytes32 escrowId) internal {
        escrow.releaseWithProof(
            escrowId, RESULT_HASH, SALT, pA, pB, pC, pubSignals
        );
    }

    // ── Deployment ───────────────────────────────────────────────

    function test_Deploy_OwnerSet() public view {
        assertEq(escrow.protocolOwner(), OWNER);
    }

    function test_Deploy_VerifierSet() public view {
        assertEq(escrow.groth16Verifier(), address(verifier));
    }

    function test_Deploy_ArbitratorSet() public view {
        assertEq(escrow.arbitrator(), ARBITRATOR);
    }

    function test_Deploy_ZeroFee() public view {
        assertEq(escrow.feeBps(), 0);
    }

    function test_Deploy_ZeroAddress_Reverts() public {
        vm.expectRevert(IZKEscrow.ZeroAddress.selector);
        new ZKEscrow(address(0), address(verifier), ARBITRATOR);
    }

    // ── Create escrow ────────────────────────────────────────────

    function test_Create_Success() public {
        bytes32 id = _createEscrow();
        IZKEscrow.Escrow memory e = escrow.getEscrow(id);

        assertEq(e.client, CLIENT);
        assertEq(e.agentWallet, AGENT_WALL);
        assertEq(e.amount, AMOUNT);
        assertEq(e.taskId, TASK_ID);
        assertEq(uint256(e.status), uint256(IZKEscrow.EscrowStatus.OPEN));
    }

    function test_Create_EmitsEvent() public {
        vm.expectEmit(false, true, true, true);
        emit IZKEscrow.EscrowCreated(bytes32(0), TASK_ID, CLIENT, AMOUNT, 0);
        _createEscrow();
    }

    function test_Create_EscrowsETH() public {
        uint256 balBefore = address(escrow).balance;
        _createEscrow();
        assertEq(address(escrow).balance, balBefore + AMOUNT);
    }

    function test_Create_LinksToTask() public {
        bytes32 id = _createEscrow();
        assertEq(escrow.getTaskEscrow(TASK_ID), id);
    }

    function test_Create_IncrementsTotalCount() public {
        _createEscrow();
        assertEq(escrow.totalEscrows(), 1);
    }

    function test_Create_ZeroValue_Reverts() public {
        vm.prank(CLIENT);
        vm.expectRevert(IZKEscrow.ZeroAmount.selector);
        escrow.createEscrow{value: 0}(TASK_ID, AGENT_WALL, block.timestamp + DEADLINE);
    }

    function test_Create_ZeroAgentWallet_Reverts() public {
        vm.prank(CLIENT);
        vm.expectRevert(IZKEscrow.ZeroAddress.selector);
        escrow.createEscrow{value: AMOUNT}(TASK_ID, payable(address(0)), block.timestamp + DEADLINE);
    }

    function test_Create_DeadlineTooSoon_Reverts() public {
        vm.prank(CLIENT);
        vm.expectRevert(IZKEscrow.InvalidDeadline.selector);
        escrow.createEscrow{value: AMOUNT}(TASK_ID, AGENT_WALL, block.timestamp + 30 minutes);
    }

    // ── Set commitment ────────────────────────────────────────────

    function test_SetCommitment_Success() public {
        bytes32 id = _createEscrow();
        vm.prank(CLIENT);
        escrow.setCommitment(id, _commitment());

        assertEq(escrow.getEscrow(id).commitment, _commitment());
    }

    function test_SetCommitment_EmitsEvent() public {
        bytes32 id = _createEscrow();
        vm.expectEmit(true, false, false, true);
        emit IZKEscrow.CommitmentSet(id, _commitment());
        vm.prank(CLIENT);
        escrow.setCommitment(id, _commitment());
    }

    function test_SetCommitment_NotClient_Reverts() public {
        bytes32 id = _createEscrow();
        vm.prank(STRANGER);
        vm.expectRevert(IZKEscrow.NotAuthorized.selector);
        escrow.setCommitment(id, _commitment());
    }

    function test_SetCommitment_Twice_Reverts() public {
        bytes32 id = _createAndCommit();
        vm.prank(CLIENT);
        vm.expectRevert(abi.encodeWithSelector(IZKEscrow.CommitmentAlreadySet.selector, id));
        escrow.setCommitment(id, _commitment());
    }

    function test_SetCommitment_AfterDeadline_Reverts() public {
        bytes32 id = _createEscrow();
        vm.warp(block.timestamp + DEADLINE + 1);
        vm.prank(CLIENT);
        vm.expectRevert(abi.encodeWithSelector(IZKEscrow.DeadlinePassed.selector, id));
        escrow.setCommitment(id, _commitment());
    }

    // ── Release with proof ────────────────────────────────────────

    function test_Release_ValidProof_Success() public {
        bytes32 id = _createAndCommit();
        _releaseWithProof(id);

        IZKEscrow.Escrow memory e = escrow.getEscrow(id);
        assertEq(uint256(e.status), uint256(IZKEscrow.EscrowStatus.RELEASED));
        assertGt(e.releasedAt, 0);
    }

    function test_Release_PaysAgentWallet() public {
        bytes32 id = _createAndCommit();
        uint256 balBefore = AGENT_WALL.balance;

        _releaseWithProof(id);

        assertEq(AGENT_WALL.balance, balBefore + AMOUNT);
    }

    function test_Release_EmitsEvents() public {
        bytes32 id = _createAndCommit();

        vm.expectEmit(true, false, false, false);
        emit IZKEscrow.ProofSubmitted(id, bytes32(0));
        vm.expectEmit(true, true, false, true);
        emit IZKEscrow.EscrowReleased(id, AGENT_WALL, AMOUNT);

        _releaseWithProof(id);
    }

    function test_Release_UpdatesTotalReleased() public {
        bytes32 id = _createAndCommit();
        _releaseWithProof(id);
        assertEq(escrow.totalReleased(), AMOUNT);
    }

    function test_Release_InvalidProof_Reverts() public {
        bytes32 id = _createAndCommit();
        verifier.setResult(false);

        vm.expectRevert(abi.encodeWithSelector(IZKEscrow.ProofVerificationFailed.selector, id));
        _releaseWithProof(id);
    }

    function test_Release_WrongCommitment_Reverts() public {
        bytes32 id = _createAndCommit();

        // Submit with wrong salt
        bytes32 wrongSalt = bytes32(uint256(0xBAD));
        vm.expectRevert(abi.encodeWithSelector(IZKEscrow.CommitmentMismatch.selector, id));
        escrow.releaseWithProof(id, RESULT_HASH, wrongSalt, pA, pB, pC, pubSignals);
    }

    function test_Release_WrongResultHash_Reverts() public {
        bytes32 id = _createAndCommit();

        bytes32 wrongHash = bytes32(uint256(0xBAD));
        vm.expectRevert(abi.encodeWithSelector(IZKEscrow.CommitmentMismatch.selector, id));
        escrow.releaseWithProof(id, wrongHash, SALT, pA, pB, pC, pubSignals);
    }

    function test_Release_NoCommitment_Reverts() public {
        bytes32 id = _createEscrow(); // no commitment set

        vm.expectRevert(abi.encodeWithSelector(IZKEscrow.CommitmentNotSet.selector, id));
        _releaseWithProof(id);
    }

    function test_Release_AfterDeadline_Reverts() public {
        bytes32 id = _createAndCommit();
        vm.warp(block.timestamp + DEADLINE + 1);

        vm.expectRevert(abi.encodeWithSelector(IZKEscrow.DeadlinePassed.selector, id));
        _releaseWithProof(id);
    }

    function test_Release_AlreadyReleased_Reverts() public {
        bytes32 id = _createAndCommit();
        _releaseWithProof(id);

        vm.expectRevert(abi.encodeWithSelector(IZKEscrow.EscrowNotOpen.selector, id));
        _releaseWithProof(id);
    }

    // ── Protocol fee ──────────────────────────────────────────────

    function test_Release_WithFee_SplitsCorrectly() public {
        vm.prank(OWNER);
        escrow.setFeeBps(500); // 5%

        bytes32 id = _createAndCommit();
        uint256 balBefore = AGENT_WALL.balance;
        _releaseWithProof(id);

        uint256 expectedPayment = AMOUNT * 9500 / 10000; // 95%
        uint256 expectedFee     = AMOUNT * 500  / 10000; // 5%

        assertEq(AGENT_WALL.balance, balBefore + expectedPayment);
        assertEq(escrow.accruedFees(), expectedFee);
    }

    function test_SetFee_TooHigh_Reverts() public {
        vm.prank(OWNER);
        vm.expectRevert();
        escrow.setFeeBps(501); // > MAX_FEE_BPS
    }

    // ── Refund after deadline ─────────────────────────────────────

    function test_Refund_Success() public {
        bytes32 id = _createEscrow();
        vm.warp(block.timestamp + DEADLINE + 1);

        uint256 balBefore = CLIENT.balance;
        vm.prank(CLIENT);
        escrow.refundAfterDeadline(id);

        assertEq(CLIENT.balance, balBefore + AMOUNT);
        assertEq(uint256(escrow.getEscrow(id).status), uint256(IZKEscrow.EscrowStatus.REFUNDED));
    }

    function test_Refund_EmitsEvent() public {
        bytes32 id = _createEscrow();
        vm.warp(block.timestamp + DEADLINE + 1);

        vm.expectEmit(true, true, false, true);
        emit IZKEscrow.EscrowRefunded(id, CLIENT, AMOUNT);
        vm.prank(CLIENT);
        escrow.refundAfterDeadline(id);
    }

    function test_Refund_BeforeDeadline_Reverts() public {
        bytes32 id = _createEscrow();

        vm.prank(CLIENT);
        vm.expectRevert(abi.encodeWithSelector(IZKEscrow.DeadlineNotPassed.selector, id));
        escrow.refundAfterDeadline(id);
    }

    function test_Refund_NotClient_Reverts() public {
        bytes32 id = _createEscrow();
        vm.warp(block.timestamp + DEADLINE + 1);

        vm.prank(STRANGER);
        vm.expectRevert(IZKEscrow.NotAuthorized.selector);
        escrow.refundAfterDeadline(id);
    }

    // ── Dispute ───────────────────────────────────────────────────

    function test_RaiseDispute_ByClient() public {
        bytes32 id = _createEscrow();
        vm.prank(CLIENT);
        escrow.raiseDispute(id);
        assertEq(uint256(escrow.getEscrow(id).status), uint256(IZKEscrow.EscrowStatus.DISPUTED));
    }

    function test_RaiseDispute_ByAgent() public {
        bytes32 id = _createEscrow();
        vm.prank(AGENT_WALL);
        escrow.raiseDispute(id);
        assertEq(uint256(escrow.getEscrow(id).status), uint256(IZKEscrow.EscrowStatus.DISPUTED));
    }

    function test_RaiseDispute_ByStranger_Reverts() public {
        bytes32 id = _createEscrow();
        vm.prank(STRANGER);
        vm.expectRevert(IZKEscrow.NotAuthorized.selector);
        escrow.raiseDispute(id);
    }

    function test_RaiseDispute_EmitsEvent() public {
        bytes32 id = _createEscrow();
        vm.expectEmit(true, false, false, false);
        emit IZKEscrow.EscrowDisputed(id);
        vm.prank(CLIENT);
        escrow.raiseDispute(id);
    }

    // ── Fee withdrawal ────────────────────────────────────────────

    function test_WithdrawFees_Success() public {
        vm.prank(OWNER);
        escrow.setFeeBps(500);

        bytes32 id = _createAndCommit();
        _releaseWithProof(id);

        address payable treasury = payable(address(0x7EA5));
        uint256 balBefore = treasury.balance;

        vm.prank(OWNER);
        escrow.withdrawFees(treasury);

        assertEq(treasury.balance, balBefore + AMOUNT * 500 / 10000);
        assertEq(escrow.accruedFees(), 0);
    }

    // ── ETH conservation invariant ────────────────────────────────

    function test_Invariant_ETHConservation_Release() public {
        bytes32 id = _createAndCommit();

        uint256 contractBalBefore = address(escrow).balance;
        uint256 agentBalBefore    = AGENT_WALL.balance;

        _releaseWithProof(id);

        assertEq(address(escrow).balance, contractBalBefore - AMOUNT);
        assertEq(AGENT_WALL.balance,      agentBalBefore + AMOUNT);
    }

    function test_Invariant_ETHConservation_Refund() public {
        bytes32 id = _createEscrow();
        vm.warp(block.timestamp + DEADLINE + 1);

        uint256 contractBalBefore = address(escrow).balance;
        uint256 clientBalBefore   = CLIENT.balance;

        vm.prank(CLIENT);
        escrow.refundAfterDeadline(id);

        assertEq(address(escrow).balance, contractBalBefore - AMOUNT);
        assertEq(CLIENT.balance,          clientBalBefore + AMOUNT);
    }

    // ── Fuzz ─────────────────────────────────────────────────────

    function testFuzz_Commitment_WrongSalt_AlwaysFails(bytes32 wrongSalt) public {
        vm.assume(wrongSalt != SALT);

        bytes32 id = _createAndCommit();

        vm.expectRevert(abi.encodeWithSelector(IZKEscrow.CommitmentMismatch.selector, id));
        escrow.releaseWithProof(id, RESULT_HASH, wrongSalt, pA, pB, pC, pubSignals);
    }

    function testFuzz_Create_AnyAmount(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(CLIENT, amount);

        vm.prank(CLIENT);
        bytes32 id = escrow.createEscrow{value: amount}(
            TASK_ID, AGENT_WALL, block.timestamp + DEADLINE
        );
        assertEq(escrow.getEscrow(id).amount, amount);
    }

    function testFuzz_ETH_AlwaysConserved(uint96 amount) public {
        vm.assume(amount > 0.001 ether);
        vm.deal(CLIENT, amount);

        vm.prank(CLIENT);
        bytes32 id = escrow.createEscrow{value: amount}(
            TASK_ID, AGENT_WALL, block.timestamp + DEADLINE
        );

        vm.prank(CLIENT);
        escrow.setCommitment(id, _commitment());

        uint256 agentBefore = AGENT_WALL.balance;
        _releaseWithProof(id);

        assertEq(AGENT_WALL.balance, agentBefore + amount);
        assertEq(address(escrow).balance, 0);
    }
}

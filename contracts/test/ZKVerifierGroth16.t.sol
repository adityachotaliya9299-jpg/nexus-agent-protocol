// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ZKVerifier} from "../src/zk/ZKVerifier.sol";
import {IZKVerifier} from "../src/interfaces/IZKVerifier.sol";
import {Groth16ProofLib} from "../src/zk/Groth16ProofLib.sol";
import {MockGroth16Verifier} from "./MockGroth16Verifier.sol";

import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../src/interfaces/IReputationOracle.sol";

/// @notice Minimal registry stub so ZKVerifier.getAgent() succeeds
contract RegistryStub {
    function getAgent(uint256) external pure returns (IAgentRegistry.AgentProfile memory p) {
        // Return a non-empty profile (registeredAt != 0 implicitly via agentId)
        p.agentId = 1;
        p.owner = address(0xBEEF);
        return p;
    }
}

/// @notice Minimal oracle stub that records reputation calls
contract OracleStub {
    uint256 public lastAgentId;
    uint256 public callCount;

    function updateReputation(uint256 agentId, IReputationOracle.UpdateReason, bytes32) external {
        lastAgentId = agentId;
        callCount++;
    }
}

/// @title ZKVerifierGroth16Test
/// @notice Tests the real Groth16 verification path on the actual ZKVerifier.
contract ZKVerifierGroth16Test is Test {
    ZKVerifier internal zk;
    MockGroth16Verifier internal groth16;
    RegistryStub internal registry;
    OracleStub internal oracle;

    address constant OWNER = address(0xA11CE);
    uint256 constant AGENT_ID = 1;
    bytes32 constant TASK_ID = bytes32(uint256(12345));
    uint256 constant OUTPUT_HASH = 98765;

    function setUp() public {
        registry = new RegistryStub();
        oracle = new OracleStub();
        groth16 = new MockGroth16Verifier();

        vm.prank(OWNER);
        zk = new ZKVerifier(OWNER, address(registry), address(oracle), 6700);

        vm.prank(OWNER);
        zk.setGroth16Verifier(address(groth16));
    }

    function _proof(bytes32 taskId, uint256 outputHash)
        internal
        pure
        returns (Groth16ProofLib.Proof memory)
    {
        return Groth16ProofLib.Proof({
            a: [uint256(1), uint256(2)],
            b: [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            c: [uint256(7), uint256(8)],
            pubSignals: [uint256(taskId), outputHash]
        });
    }

    // ── Setup / config ──

    function test_SetGroth16Verifier() public view {
        assertEq(zk.groth16Verifier(), address(groth16));
    }

    function test_SetGroth16Verifier_OnlyOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert();
        zk.setGroth16Verifier(address(groth16));
    }

    function test_SetGroth16Verifier_ZeroReverts() public {
        vm.prank(OWNER);
        vm.expectRevert(IZKVerifier.ZeroAddress.selector);
        zk.setGroth16Verifier(address(0));
    }

    // ── Real verification path ──

    function test_SubmitProofWithGroth16_Valid() public {
        groth16.setShouldVerify(true);

        (bytes32 proofId, bool verified) =
            zk.submitProofWithGroth16(AGENT_ID, TASK_ID, _proof(TASK_ID, OUTPUT_HASH));

        assertTrue(verified);
        assertTrue(zk.isProofValid(proofId));
        assertEq(zk.totalProofsVerified(), 1);
    }

    function test_SubmitProofWithGroth16_Invalid() public {
        groth16.setShouldVerify(false);

        (bytes32 proofId, bool verified) =
            zk.submitProofWithGroth16(AGENT_ID, TASK_ID, _proof(TASK_ID, OUTPUT_HASH));

        assertFalse(verified);
        assertFalse(zk.isProofValid(proofId));
        assertEq(zk.totalProofsVerified(), 0);
    }

    function test_SubmitProofWithGroth16_AppliesReputation() public {
        groth16.setShouldVerify(true);

        zk.submitProofWithGroth16(AGENT_ID, TASK_ID, _proof(TASK_ID, OUTPUT_HASH));

        assertEq(oracle.callCount(), 1);
        assertEq(oracle.lastAgentId(), AGENT_ID);
    }

    function test_SubmitProofWithGroth16_InvalidNoReputation() public {
        groth16.setShouldVerify(false);

        zk.submitProofWithGroth16(AGENT_ID, TASK_ID, _proof(TASK_ID, OUTPUT_HASH));

        assertEq(oracle.callCount(), 0);
    }

    // ── Replay protection ──

    function test_SubmitProofWithGroth16_TaskIdMismatchReverts() public {
        groth16.setShouldVerify(true);

        // Proof's public taskId signal is for TASK_ID, but we claim a different task
        Groth16ProofLib.Proof memory p = _proof(TASK_ID, OUTPUT_HASH);
        bytes32 differentTask = bytes32(uint256(99999));

        vm.expectRevert("Proof taskId mismatch");
        zk.submitProofWithGroth16(AGENT_ID, differentTask, p);
    }

    // ── No verifier set ──

    function test_SubmitProofWithGroth16_NoVerifierReverts() public {
        // Fresh ZKVerifier without setGroth16Verifier
        vm.prank(OWNER);
        ZKVerifier fresh = new ZKVerifier(OWNER, address(registry), address(oracle), 6700);

        vm.expectRevert();
        fresh.submitProofWithGroth16(AGENT_ID, TASK_ID, _proof(TASK_ID, OUTPUT_HASH));
    }

    // ── Proof storage correctness ──

    function test_SubmitProofWithGroth16_StoresProofData() public {
        groth16.setShouldVerify(true);

        (bytes32 proofId,) =
            zk.submitProofWithGroth16(AGENT_ID, TASK_ID, _proof(TASK_ID, OUTPUT_HASH));

        IZKVerifier.Proof memory stored = zk.getProof(proofId);
        assertEq(stored.agentId, AGENT_ID);
        assertEq(stored.taskId, TASK_ID);
        assertEq(uint256(stored.status), uint256(IZKVerifier.ProofStatus.VERIFIED));
        assertEq(uint256(stored.proofType), uint256(IZKVerifier.ProofType.TASK_COMPLETION));
    }

    function test_SubmitProofWithGroth16_LinksToTask() public {
        groth16.setShouldVerify(true);

        (bytes32 proofId,) =
            zk.submitProofWithGroth16(AGENT_ID, TASK_ID, _proof(TASK_ID, OUTPUT_HASH));

        bytes32[] memory taskProofs = zk.getTaskProofs(TASK_ID);
        assertEq(taskProofs.length, 1);
        assertEq(taskProofs[0], proofId);
    }

    function test_SubmitProofWithGroth16_LinksToAgent() public {
        groth16.setShouldVerify(true);

        (bytes32 proofId,) =
            zk.submitProofWithGroth16(AGENT_ID, TASK_ID, _proof(TASK_ID, OUTPUT_HASH));

        bytes32[] memory agentProofs = zk.getAgentProofs(AGENT_ID);
        assertEq(agentProofs.length, 1);
        assertEq(agentProofs[0], proofId);
    }

    // ── Fuzz ──

    function testFuzz_VerifyResult(bool shouldVerify) public {
        groth16.setShouldVerify(shouldVerify);

        (, bool verified) =
            zk.submitProofWithGroth16(AGENT_ID, TASK_ID, _proof(TASK_ID, OUTPUT_HASH));

        assertEq(verified, shouldVerify);
    }
}

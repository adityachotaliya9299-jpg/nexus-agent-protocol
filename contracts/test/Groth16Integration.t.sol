// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Groth16ProofLib} from "../src/zk/Groth16ProofLib.sol";
import {IGroth16Verifier} from "../src/zk/IGroth16Verifier.sol";
import {MockGroth16Verifier} from "./MockGroth16Verifier.sol";

/// @title Groth16IntegrationTest
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Tests the real Groth16 proof verification path.
/// @dev Uses MockGroth16Verifier to control verification outcomes.
///      Real proofs are tested off-chain via scripts/zk/generate-proof.js
contract Groth16IntegrationTest is Test {
    using Groth16ProofLib for Groth16ProofLib.Proof;

    MockGroth16Verifier internal verifier;

    uint256 constant TASK_ID = 12345;
    uint256 constant OUTPUT_HASH = 98765432109876543210;

    function setUp() public {
        verifier = new MockGroth16Verifier();
    }

    // ── Helper: build a sample proof struct ──
    function _sampleProof(uint256 taskId, uint256 outputHash)
        internal
        pure
        returns (Groth16ProofLib.Proof memory)
    {
        return Groth16ProofLib.Proof({
            a: [uint256(1), uint256(2)],
            b: [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            c: [uint256(7), uint256(8)],
            pubSignals: [taskId, outputHash]
        });
    }

    // ── Verification ──

    function test_Verify_ValidProof_ReturnsTrue() public view {
        Groth16ProofLib.Proof memory proof = _sampleProof(TASK_ID, OUTPUT_HASH);
        bool valid = Groth16ProofLib.verify(address(verifier), proof);
        assertTrue(valid);
    }

    function test_Verify_InvalidProof_ReturnsFalse() public {
        verifier.setShouldVerify(false);
        Groth16ProofLib.Proof memory proof = _sampleProof(TASK_ID, OUTPUT_HASH);
        bool valid = Groth16ProofLib.verify(address(verifier), proof);
        assertFalse(valid);
    }

    // ── Task binding (replay protection) ──

    function test_MatchesTask_CorrectTaskId() public pure {
        Groth16ProofLib.Proof memory proof = _sampleProof(TASK_ID, OUTPUT_HASH);
        assertTrue(proof.matchesTask(TASK_ID));
    }

    function test_MatchesTask_WrongTaskId_Fails() public pure {
        Groth16ProofLib.Proof memory proof = _sampleProof(TASK_ID, OUTPUT_HASH);
        assertFalse(proof.matchesTask(99999));
    }

    function test_OutputHash_Extraction() public pure {
        Groth16ProofLib.Proof memory proof = _sampleProof(TASK_ID, OUTPUT_HASH);
        assertEq(proof.outputHash(), OUTPUT_HASH);
    }

    // ── Replay attack: valid proof, wrong task ──

    function test_ReplayProtection_ValidProofWrongTask() public view {
        // A proof valid for TASK_ID should not be accepted for a different task.
        // The contract using this lib must check BOTH verify() AND matchesTask().
        Groth16ProofLib.Proof memory proof = _sampleProof(TASK_ID, OUTPUT_HASH);

        bool cryptoValid = Groth16ProofLib.verify(address(verifier), proof);
        bool taskMatches = proof.matchesTask(88888); // different task

        // Crypto is valid but task binding fails → overall must reject
        assertTrue(cryptoValid);
        assertFalse(taskMatches);
        assertFalse(cryptoValid && taskMatches);
    }

    // ── Fuzz ──

    function testFuzz_MatchesTask(uint256 taskId, uint256 queryId) public pure {
        Groth16ProofLib.Proof memory proof = _sampleProof(taskId, OUTPUT_HASH);
        if (taskId == queryId) {
            assertTrue(proof.matchesTask(queryId));
        } else {
            assertFalse(proof.matchesTask(queryId));
        }
    }

    function testFuzz_VerifyToggle(bool shouldVerify) public {
        verifier.setShouldVerify(shouldVerify);
        Groth16ProofLib.Proof memory proof = _sampleProof(TASK_ID, OUTPUT_HASH);
        assertEq(Groth16ProofLib.verify(address(verifier), proof), shouldVerify);
    }
}

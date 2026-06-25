// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGroth16Verifier} from "./IGroth16Verifier.sol";

/// @title Groth16ProofLib
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Library that wraps a real Groth16 proof and verifies it on-chain.
/// @dev This replaces the simulated verification in ZKVerifier. The proof
///      struct matches the calldata layout that snarkjs produces.
library Groth16ProofLib {
    /// @notice A full Groth16 proof plus its public signals.
    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
        uint256[2] pubSignals;
    }

    /// @notice Verify a Groth16 proof against the deployed verifier.
    /// @param verifier The snarkjs-generated Groth16Verifier address.
    /// @param proof The proof + public signals.
    /// @return valid True if the proof is cryptographically valid.
    function verify(address verifier, Proof memory proof) internal view returns (bool valid) {
        return IGroth16Verifier(verifier).verifyProof(
            proof.a,
            proof.b,
            proof.c,
            proof.pubSignals
        );
    }

    /// @notice Check that a proof's public taskId matches the expected task.
    /// @dev Prevents replaying a valid proof from one task onto another.
    function matchesTask(Proof memory proof, uint256 expectedTaskId) internal pure returns (bool) {
        return proof.pubSignals[0] == expectedTaskId;
    }

    /// @notice Extract the committed output hash from the proof's public signals.
    function outputHash(Proof memory proof) internal pure returns (uint256) {
        return proof.pubSignals[1];
    }
}

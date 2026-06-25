// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGroth16Verifier} from "../src/zk/IGroth16Verifier.sol";

/// @title MockGroth16Verifier
/// @notice Test double for the real Groth16Verifier. Lets tests control
///         whether a proof "verifies" without running real ZK math.
/// @dev In production, the real snarkjs-generated Groth16Verifier replaces this.
contract MockGroth16Verifier is IGroth16Verifier {
    bool public shouldVerify = true;

    /// @notice Toggle whether verifyProof returns true or false.
    function setShouldVerify(bool _v) external {
        shouldVerify = _v;
    }

    /// @notice Mock verification — returns the configured result.
    /// @dev Real verifier runs elliptic curve pairing checks here.
    function verifyProof(
        uint[2] calldata,
        uint[2][2] calldata,
        uint[2] calldata,
        uint[2] calldata
    ) external view returns (bool) {
        return shouldVerify;
    }
}

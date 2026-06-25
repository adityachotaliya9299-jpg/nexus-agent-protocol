pragma circom 2.1.6;

include "circomlib/circuits/poseidon.circom";
include "circomlib/circuits/comparators.circom";

// ============================================================
// TaskCompletion Circuit
// ------------------------------------------------------------
// Proves an agent knows a secret that produces a committed
// output hash for a given task, WITHOUT revealing the secret.
//
// This is the core trustless primitive: an agent can prove it
// did the work (knows the result preimage) without revealing
// how, and payment releases only when this proof verifies.
//
// Public inputs:
//   taskId      - the task being completed (public, on-chain)
//   outputHash  - committed hash of the result (public, on-chain)
//
// Private inputs:
//   agentSecret - the agent's secret (never revealed)
//   result      - the actual work result (never revealed)
//
// Constraint: Poseidon(agentSecret, result, taskId) == outputHash
//   AND result is non-zero (real work was done)
// ============================================================

template TaskCompletion() {
    // Public inputs (committed on-chain before proof)
    signal input taskId;
    signal input outputHash;

    // Private inputs (the agent's secret knowledge)
    signal input agentSecret;
    signal input result;

    // ── Constraint 1: result must be non-zero (real work) ──
    component isZero = IsZero();
    isZero.in <== result;
    isZero.out === 0; // result != 0

    // ── Constraint 2: hash binds secret + result + taskId ──
    component hasher = Poseidon(3);
    hasher.inputs[0] <== agentSecret;
    hasher.inputs[1] <== result;
    hasher.inputs[2] <== taskId;

    // The computed hash must equal the public commitment
    outputHash === hasher.out;
}

component main {public [taskId, outputHash]} = TaskCompletion();

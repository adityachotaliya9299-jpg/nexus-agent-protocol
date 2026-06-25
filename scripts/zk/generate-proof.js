// ============================================================
// Phase 9 — Off-Chain Proof Generation
// ============================================================
// Generates a real Groth16 proof that an agent completed a task.
// The proof can be submitted on-chain to ZKVerifier, which
// verifies it via the deployed Groth16Verifier contract.
//
// Usage:
//   node scripts/zk/generate-proof.js <taskId> <agentSecret> <result>
//
// Example:
//   node scripts/zk/generate-proof.js 12345 98765 42
//
// Output: proof.json with calldata ready for the contract
// ============================================================

const snarkjs = require("snarkjs");
const circomlibjs = require("circomlibjs");
const fs = require("fs");
const path = require("path");

const BUILD_DIR = path.join(__dirname, "../../circuits/build");
const WASM_PATH = path.join(BUILD_DIR, "TaskCompletion_js/TaskCompletion.wasm");
const ZKEY_PATH = path.join(BUILD_DIR, "TaskCompletion_final.zkey");

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 3) {
    console.error("Usage: node generate-proof.js <taskId> <agentSecret> <result>");
    process.exit(1);
  }

  const taskId = BigInt(args[0]);
  const agentSecret = BigInt(args[1]);
  const result = BigInt(args[2]);

  console.log("==========================================");
  console.log("Generating ZK Proof of Task Completion");
  console.log("==========================================");
  console.log("Task ID:      ", taskId.toString());
  console.log("Agent Secret: ", "[hidden]");
  console.log("Result:       ", "[hidden]");

  // ── Step 1: Compute the output hash (Poseidon) ──
  // This is the public commitment the agent posts on-chain
  const poseidon = await circomlibjs.buildPoseidon();
  const hash = poseidon([agentSecret, result, taskId]);
  const outputHash = poseidon.F.toObject(hash);

  console.log("\nComputed output hash (public commitment):");
  console.log("  ", outputHash.toString());

  // ── Step 2: Build the witness inputs ──
  const inputs = {
    taskId: taskId.toString(),
    outputHash: outputHash.toString(),
    agentSecret: agentSecret.toString(),
    result: result.toString(),
  };

  // ── Step 3: Generate the proof ──
  console.log("\nGenerating Groth16 proof...");
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    inputs,
    WASM_PATH,
    ZKEY_PATH
  );
  console.log("  ✓ Proof generated");

  // ── Step 4: Verify locally before submitting ──
  const vKey = JSON.parse(
    fs.readFileSync(path.join(BUILD_DIR, "verification_key.json"))
  );
  const verified = await snarkjs.groth16.verify(vKey, publicSignals, proof);
  console.log("  Local verification:", verified ? "✓ VALID" : "✗ INVALID");

  if (!verified) {
    console.error("Proof failed local verification — aborting");
    process.exit(1);
  }

  // ── Step 5: Format calldata for the contract ──
  const calldata = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);

  // Parse the calldata string into structured arrays
  const argv = calldata
    .replace(/["[\]\s]/g, "")
    .split(",")
    .map((x) => BigInt(x).toString());

  const a = [argv[0], argv[1]];
  const b = [
    [argv[2], argv[3]],
    [argv[4], argv[5]],
  ];
  const c = [argv[6], argv[7]];
  const pubSignals = [argv[8], argv[9]];

  const output = {
    taskId: taskId.toString(),
    outputHash: outputHash.toString(),
    proof: { a, b, c, pubSignals },
    rawCalldata: calldata,
  };

  // ── Step 6: Save proof ──
  const outPath = path.join(__dirname, "../../circuits/build/proof.json");
  fs.writeFileSync(outPath, JSON.stringify(output, null, 2));

  console.log("\n==========================================");
  console.log("✓ Proof saved to circuits/build/proof.json");
  console.log("==========================================");
  console.log("\nContract call structure:");
  console.log("  proof.a:         ", JSON.stringify(a));
  console.log("  proof.b:         ", JSON.stringify(b));
  console.log("  proof.c:         ", JSON.stringify(c));
  console.log("  proof.pubSignals:", JSON.stringify(pubSignals));
  console.log("\nSubmit this proof on-chain via:");
  console.log("  zkVerifier.submitProofWithGroth16(taskId, proof)");

  process.exit(0);
}

main().catch((err) => {
  console.error("Error generating proof:", err);
  process.exit(1);
});

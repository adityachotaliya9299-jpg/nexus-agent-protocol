#!/bin/bash
# ============================================================
# Phase 9 — Circuit Compilation + Groth16 Trusted Setup
# ============================================================
# Compiles TaskCompletion.circom, runs the Groth16 setup
# ceremony, and exports the Solidity verifier contract.
#
# Prerequisites:
#   npm install -g circom        (or build from source)
#   npm install -g snarkjs
#   npm install circomlib
#
# Run from the project root:
#   bash scripts/zk/setup-circuit.sh
# ============================================================

set -e

CIRCUIT_NAME="TaskCompletion"
CIRCUIT_DIR="circuits"
BUILD_DIR="circuits/build"
PTAU_DIR="circuits/ptau"

echo "=========================================="
echo "Phase 9: ZK Circuit Setup"
echo "=========================================="

# ── Step 0: Create build dirs ──
mkdir -p "$BUILD_DIR"
mkdir -p "$PTAU_DIR"

# ── Step 1: Compile the circuit ──
echo ""
echo "[1/7] Compiling circuit..."
circom "$CIRCUIT_DIR/$CIRCUIT_NAME.circom" \
    --r1cs --wasm --sym \
    -o "$BUILD_DIR" \
    -l "$CIRCUIT_DIR/node_modules"

echo "  ✓ Compiled to $BUILD_DIR/$CIRCUIT_NAME.r1cs"

# ── Step 2: Print circuit info ──
echo ""
echo "[2/7] Circuit constraints:"
snarkjs r1cs info "$BUILD_DIR/$CIRCUIT_NAME.r1cs"

# ── Step 3: Powers of Tau (Phase 1 — universal) ──
# For a small circuit, 2^12 constraints is plenty.
PTAU_FINAL="$PTAU_DIR/pot12_final.ptau"

if [ ! -f "$PTAU_FINAL" ]; then
    echo ""
    echo "[3/7] Powers of Tau ceremony (one-time)..."
    snarkjs powersoftau new bn128 12 "$PTAU_DIR/pot12_0000.ptau" -v
    snarkjs powersoftau contribute "$PTAU_DIR/pot12_0000.ptau" "$PTAU_DIR/pot12_0001.ptau" \
        --name="Nexus first contribution" -v -e="$(head -c 64 /dev/urandom | base64)"
    snarkjs powersoftau prepare phase2 "$PTAU_DIR/pot12_0001.ptau" "$PTAU_FINAL" -v
    echo "  ✓ Powers of Tau ready"
else
    echo ""
    echo "[3/7] Powers of Tau already exists, skipping"
fi

# ── Step 4: Groth16 setup (Phase 2 — circuit-specific) ──
echo ""
echo "[4/7] Groth16 zkey setup..."
snarkjs groth16 setup \
    "$BUILD_DIR/$CIRCUIT_NAME.r1cs" \
    "$PTAU_FINAL" \
    "$BUILD_DIR/${CIRCUIT_NAME}_0000.zkey"

# ── Step 5: Contribute to phase 2 ceremony ──
echo ""
echo "[5/7] Contributing to phase 2..."
snarkjs zkey contribute \
    "$BUILD_DIR/${CIRCUIT_NAME}_0000.zkey" \
    "$BUILD_DIR/${CIRCUIT_NAME}_final.zkey" \
    --name="Nexus phase2 contribution" -v -e="$(head -c 64 /dev/urandom | base64)"

# ── Step 6: Export verification key ──
echo ""
echo "[6/7] Exporting verification key..."
snarkjs zkey export verificationkey \
    "$BUILD_DIR/${CIRCUIT_NAME}_final.zkey" \
    "$BUILD_DIR/verification_key.json"

# ── Step 7: Export Solidity verifier ──
echo ""
echo "[7/7] Exporting Solidity verifier contract..."
snarkjs zkey export solidityverifier \
    "$BUILD_DIR/${CIRCUIT_NAME}_final.zkey" \
    "contracts/src/zk/Groth16Verifier.sol"

# Fix the pragma to match your project (snarkjs emits an old pragma)
sed -i 's/pragma solidity \^0.6.11;/pragma solidity ^0.8.24;/' "contracts/src/zk/Groth16Verifier.sol"
sed -i 's/pragma solidity >=0.7.0 <0.9.0;/pragma solidity ^0.8.24;/' "contracts/src/zk/Groth16Verifier.sol"

echo ""
echo "=========================================="
echo "✓ ZK setup complete!"
echo "=========================================="
echo ""
echo "Generated files:"
echo "  circuits/build/${CIRCUIT_NAME}.wasm           (witness generator)"
echo "  circuits/build/${CIRCUIT_NAME}_final.zkey     (proving key)"
echo "  circuits/build/verification_key.json          (verification key)"
echo "  contracts/src/zk/Groth16Verifier.sol          (on-chain verifier)"
echo ""
echo "Next steps:"
echo "  1. Deploy Groth16Verifier.sol to Sepolia"
echo "  2. Call zkVerifier.setGroth16Verifier(address)"
echo "  3. Generate proofs with: node scripts/zk/generate-proof.js"
echo "=========================================="

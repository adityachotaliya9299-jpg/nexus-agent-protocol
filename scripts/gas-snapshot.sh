#!/bin/bash
# ============================================================
#   Gas Snapshot Baseline + Comparison
# ============================================================
# Run BEFORE applying optimizations to get baseline.
# Run AFTER to see improvement.
#
# Usage:
#   bash scripts/gas-snapshot.sh
# ============================================================

set -e

cd "$(dirname "$0")/../contracts"

echo "=========================================="
echo "Gas Snapshot"
echo "=========================================="

# Run forge snapshot — outputs .gas-snapshot file
forge snapshot --snap .gas-snapshot-new

echo ""
echo "Snapshot saved to contracts/.gas-snapshot-new"
echo ""

# If a previous snapshot exists, show diff
if [ -f ".gas-snapshot" ]; then
    echo "Comparing with previous snapshot:"
    echo "------------------------------------------"
    forge snapshot --diff .gas-snapshot 2>/dev/null || true
    echo "------------------------------------------"
    echo ""
    echo "Negative numbers = gas SAVED (good)"
    echo "Positive numbers = gas INCREASED (investigate)"
else
    echo "No previous snapshot found."
    echo "Copy .gas-snapshot-new to .gas-snapshot to use as baseline:"
    echo "  cp contracts/.gas-snapshot-new contracts/.gas-snapshot"
fi

echo "=========================================="
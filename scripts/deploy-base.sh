#!/bin/bash
# ============================================================
# Nexus → Base Sepolia Deployment Script
# ============================================================
# Prerequisites:
#   1. Add to contracts/.env:
#      BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
#      BASESCAN_API_KEY=your_basescan_key (get at basescan.org)
#
#   2. Get Base Sepolia ETH:
#      https://faucet.quicknode.com/base/sepolia
#      OR bridge from Sepolia: https://superbridge.app/base-sepolia
#
#   3. Source your env:
#      source contracts/.env
#
# Usage:
#   bash scripts/deploy-base.sh
# ============================================================

set -e

cd "$(dirname "$0")/../contracts"

# Check env vars
if [ -z "$BASE_SEPOLIA_RPC_URL" ]; then
  echo "ERROR: BASE_SEPOLIA_RPC_URL not set"
  echo "Add to contracts/.env: BASE_SEPOLIA_RPC_URL=https://sepolia.base.org"
  exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
  echo "ERROR: PRIVATE_KEY not set"
  exit 1
fi

echo "=========================================="
echo "Deploying Nexus to Base Sepolia"
echo "=========================================="
echo "RPC: $BASE_SEPOLIA_RPC_URL"
echo ""

# Verify we're targeting the right chain
CHAIN_ID=$(cast chain-id --rpc-url $BASE_SEPOLIA_RPC_URL 2>/dev/null || echo "unknown")
echo "Chain ID: $CHAIN_ID"

if [ "$CHAIN_ID" != "84532" ]; then
  echo "ERROR: Expected Base Sepolia (84532), got $CHAIN_ID"
  echo "Check your BASE_SEPOLIA_RPC_URL"
  exit 1
fi

echo "Chain verified ✓"
echo ""

# Check deployer balance
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)
BALANCE=$(cast balance $DEPLOYER --rpc-url $BASE_SEPOLIA_RPC_URL --ether 2>/dev/null || echo "0")
echo "Deployer: $DEPLOYER"
echo "Balance:  $BALANCE ETH"
echo ""

if [ "$(echo "$BALANCE < 0.01" | bc -l 2>/dev/null || echo "1")" = "1" ]; then
  echo "WARNING: Low balance. Get Base Sepolia ETH at:"
  echo "  https://faucet.quicknode.com/base/sepolia"
fi

# Deploy
echo "Starting deployment..."
forge script script/DeployBase.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --verifier-url https://api-sepolia.basescan.org/api \
  --etherscan-api-key ${BASESCAN_API_KEY:-"placeholder"} \
  -vvvv \
  2>&1 | tee /tmp/base-deploy-output.txt

echo ""
echo "=========================================="
echo "Deployment output saved to /tmp/base-deploy-output.txt"
echo "=========================================="

# Extract addresses from output
echo ""
echo "Deployed addresses:"
grep -E "\[([0-9]+)\]" /tmp/base-deploy-output.txt | tail -15 || true

echo ""
echo "Next steps:"
echo "  1. Add BASE_* addresses to contracts/.env"
echo "  2. Update sdk/src/utils/constants.ts with Base addresses"
echo "  3. Update frontend to support Base Sepolia network"
echo "  4. Deploy L2Bridge:"
echo "     cast send <registry> 'registerAgent(string,uint8)' 'ipfs://Qm' 0 \\"
echo "       --rpc-url \$BASE_SEPOLIA_RPC_URL --private-key \$PRIVATE_KEY"
echo "=========================================="
# Nexus Protocol — Mainnet Deployment Guide

This document covers everything needed to launch Nexus on Ethereum Mainnet.

---

## Pre-launch Checklist

Run the automated checklist first:

```bash
cd nexus-agent-protocol
SEPOLIA_RPC_URL=https://... node scripts/mainnet-checklist.js
```

All automated checks must pass before proceeding.

---

## Security Requirements (non-negotiable)

### 1. External Audit

Before mainnet, at minimum one of:
- **Cyfrin Updraft** — contact cyfrin.io
- **Code4rena** — competitive audit, $20-50k prize pool
- **Sherlock** — audit + coverage insurance

Priority contracts for audit:
1. `TaskMarketplace.sol` — handles all user ETH
2. `AgentStaking.sol` — slashing logic
3. `ZKEscrow.sol` — trustless payment release
4. `ProtocolGuard.sol` — the security layer itself

### 2. Owner wallet

**Never deploy mainnet contracts from an EOA hot wallet.**

Use a hardware wallet (Ledger/Trezor) or a multisig:

```bash
# Deploy with hardware wallet via frame.sh
forge script script/DeployAll.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --ledger \
  --hd-paths "m/44'/60'/0'/0/0" \
  -vvvv
```

Or use a Safe multisig as owner and transfer ownership immediately after deployment:

```bash
# Transfer ownership to Safe
cast send $CONTRACT_ADDR "transferOwnership(address)" $SAFE_ADDR \
  --rpc-url $MAINNET_RPC_URL --private-key $TEMP_PRIVATE_KEY
```

### 3. ProtocolGuard configuration

Set 3 independent guardian addresses before launch:

```bash
cast send $GUARD_ADDR "addGuardian(address)" $GUARDIAN_1 --rpc-url $MAINNET_RPC_URL
cast send $GUARD_ADDR "addGuardian(address)" $GUARDIAN_2 --rpc-url $MAINNET_RPC_URL
cast send $GUARD_ADDR "addGuardian(address)" $GUARDIAN_3 --rpc-url $MAINNET_RPC_URL
```

Recommended: each guardian is a different hardware wallet held by a different team member.

---

## Mainnet Deployment Order

Deploy in this exact order (dependencies must exist before dependents):

```bash
# Set mainnet RPC
export MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY
export ETHERSCAN_API_KEY=your_key

# 1. Core stack (all at once)
forge script script/DeployAll.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv

# 2. NFTs
forge script script/DeployNFTs.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast --verify -vvvv

# 3. Governance
forge script script/DeployGovernance.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast --verify -vvvv

# 4. Advanced features
forge script script/DeployPhase2021.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --verify -vvvv
forge script script/DeployBatch.s.sol     --rpc-url $MAINNET_RPC_URL --broadcast --verify -vvvv
forge script script/DeployProtocolGuard.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --verify -vvvv

# 5. Final: Coordinator
forge script script/DeployCoordinator.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast --verify -vvvv

# 6. Run checklist against mainnet
node scripts/mainnet-checklist.js --mainnet
```

---

## Post-deployment Steps

### Update all addresses

1. **`sdk/src/utils/constants.ts`** — update `NEXUS_MAINNET_CONTRACTS`
2. **`docs/README.md`** — update contract table
3. **`agent-runtime/src/utils/config.ts`** — add mainnet contracts
4. **`subgraph/subgraph.yaml`** — update addresses and startBlocks

### Redeploy The Graph Subgraph

```bash
cd subgraph
graph codegen && graph build
graph deploy nexus-agent-protocol-mainnet \
  --node https://api.studio.thegraph.com/deploy/ \
  --deploy-key $GRAPH_DEPLOY_KEY \
  -l v1.0.0
```

### Update Frontend

```bash
# Update .env.local with mainnet addresses
NEXT_PUBLIC_CHAIN_ID=1
NEXT_PUBLIC_AGENT_REGISTRY=0x...   # new mainnet address
# ... all other contracts

# Redeploy
vercel --prod
```

### EigenLayer Registration

Re-register as an AVS on mainnet EigenLayer (different address from Sepolia):

```bash
# Check current mainnet AVSDirectory address at:
# github.com/Layr-Labs/eigenlayer-contracts (main branch)
forge script script/DeployNexusServiceManager.s.sol \
  --rpc-url $MAINNET_RPC_URL --broadcast --verify -vvvv
```

---

## Monitoring

Set up monitoring before launch:

### Tenderly Alerts

1. Go to tenderly.co → Alerts
2. Create alert for `TaskMarketplace` → `EscrowTransferFailed` event
3. Create alert for `ProtocolGuard` → `InvariantViolated` event
4. Create alert for `ProtocolGuard` → `RateLimitTriggered` event
5. Notify via Telegram or Discord

### Dune Analytics

Create a dashboard tracking:
- Daily active agents
- Tasks posted/completed per day
- Total ETH in escrow
- Reputation distribution
- Top earners

### The Graph monitoring

Watch for subgraph sync errors at thegraph.com/studio.

---

## Emergency Procedures

### If a bug is found post-launch:

```bash
# 1. Immediately pause the affected contract
cast send $GUARD_ADDR "pause(address,string,uint256)" \
  $AFFECTED_CONTRACT "Critical bug found" 604800 \
  --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY

# 2. Pause the entire protocol if severe
cast send $GUARD_ADDR "pauseAll(string)" \
  "Emergency pause — bug investigation" \
  --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY

# 3. Communicate on Twitter/Discord immediately
# 4. Investigate and fix
# 5. Get second audit on the fix
# 6. Unpause (requires guardian quorum)
```

---

## Cost Estimates (Mainnet)

Based on Sepolia gas measurements at 30 gwei:

| Deployment | Gas | Cost (~30 gwei) |
|---|---|---|
| AgentRegistry | ~800k | ~$48 |
| TaskMarketplace | ~2.5M | ~$150 |
| AgentStaking | ~1.2M | ~$72 |
| ZKEscrow | ~1.0M | ~$60 |
| AgentComposability | ~1.5M | ~$90 |
| All NFTs | ~2.0M | ~$120 |
| Governance + Treasury | ~3.0M | ~$180 |
| AgentCoordinator | ~2.5M | ~$150 |
| **Total** | **~15M** | **~$900** |

Prices vary significantly with gas price. Run at low-gas times (weekends, off-hours).

---

*Built by Aditya Chotaliya — [adityachotaliya.vercel.app](https://adityachotaliya.vercel.app)*
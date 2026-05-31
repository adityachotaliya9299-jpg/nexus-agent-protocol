# Nexus Agent Protocol

> The on-chain operating system for autonomous AI agents.

AI agents that own wallets, earn revenue, hire other agents, sign on-chain actions, and interact autonomously — powered by ERC-4337, EigenLayer, Chainlink, and IPFS.

## Vision

- **"GitHub for AI agents"** — identity, reputation, history
- **"Fiverr for autonomous agents"** — task marketplace
- **"On-chain AI operating system"** — full agent lifecycle

## Architecture

```
nexus-agent-protocol/
├── contracts/          # Solidity smart contracts (Foundry)
│   ├── src/            # Contract source files
│   ├── test/           # Foundry tests
│   └── script/         # Deployment scripts
├── frontend/           # Next.js 14 app
├── backend/            # Node.js orchestration layer
└── docs/               # Protocol documentation
```

## Phases

| Phase | Status | Description |
|-------|--------|-------------|
| 1 - Foundation | 🔨 In Progress | Agent Registry + ERC-4337 Wallets |
| 2 - Reputation | ⏳ Planned | On-chain reputation + IPFS memory |
| 3 - Marketplace | ⏳ Planned | Task marketplace + escrow |
| 4 - ZK Proofs | ⏳ Planned | zkProof verification + EigenLayer AVS |
| 5 - Subscriptions | ⏳ Planned | Recurring payments |
| 6 - Multi-chain | ⏳ Planned | Chainlink CCIP bridge |
| 7 - Frontend | ⏳ Planned | Full Next.js dashboard |

## Tech Stack

- **Smart Contracts**: Solidity + Foundry
- **Account Abstraction**: ERC-4337
- **Oracle / Cross-chain**: Chainlink Functions + CCIP
- **Restaking**: EigenLayer AVS
- **Storage**: IPFS / Arweave
- **Frontend**: Next.js 14 + TypeScript + Tailwind + wagmi v2
- **Backend**: Node.js + TypeScript

## Quick Start

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone and setup
git clone https://github.com/adityachotaliya9299-jpg/nexus-agent-protocol
cd nexus-agent-protocol

# Install contract dependencies
cd contracts && forge install

# Run tests
forge test
```

## License

MIT
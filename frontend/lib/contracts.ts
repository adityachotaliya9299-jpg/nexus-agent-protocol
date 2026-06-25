
export const CONTRACTS = {
  AgentRegistry:       "0x68F76277A7a8991CE7ac7182AAA10a356dAaB48F" as `0x${string}`,
  AgentWalletFactory:  "0xce48B6eE3Cac616A103016C70436cb3eB0183c65" as `0x${string}`,
  ReputationOracle:    "0x7deC5525AC26Bcf134c5e8cD7485c16CBC00EeDA" as `0x${string}`,
  AgentMemory:         "0x40B16F644bD696D8D7a2507671b8D556b9821673" as `0x${string}`,
  TaskMarketplace:     "0x16B3cD374B3596635A76D874c1A3138e7236C76e" as `0x${string}`,
  ZKVerifier:          "0xA292dA54BF85BD6692B1082ceB88a1F6d671EFe8" as `0x${string}`,
  SubscriptionManager: "0x60385A61e663B5a1ed616C3C090764faBaAcec13" as `0x${string}`,
  CrossChainBridge:    "0x7a3Cd54bB1039823B15Eff1df78D044C7D79628a" as `0x${string}`,
} as const;

export function isDeployed(): boolean {
  return CONTRACTS.AgentRegistry !== "0x0000000000000000000000000000000000000000";
}


export const AGENT_REGISTRY_ABI = [
  // Events
  { type: "event", name: "AgentRegistered", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "owner", type: "address", indexed: true }, { name: "category", type: "uint8", indexed: false }, { name: "metadataURI", type: "string", indexed: false }] },
  { type: "event", name: "AgentUpdated", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "metadataURI", type: "string", indexed: false }] },
  { type: "event", name: "AgentWalletSet", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "wallet", type: "address", indexed: false }] },
  { type: "event", name: "AgentStatusChanged", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "status", type: "uint8", indexed: false }] },
  { type: "event", name: "ReputationUpdated", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "oldScore", type: "uint256", indexed: false }, { name: "newScore", type: "uint256", indexed: false }] },
  // Read functions
  { type: "function", name: "getAgent", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "tuple", components: [{ name: "agentId", type: "uint256" }, { name: "owner", type: "address" }, { name: "agentWallet", type: "address" }, { name: "metadataURI", type: "string" }, { name: "category", type: "uint8" }, { name: "status", type: "uint8" }, { name: "reputationScore", type: "uint256" }, { name: "totalTasksCompleted", type: "uint256" }, { name: "totalEarned", type: "uint256" }, { name: "registeredAt", type: "uint256" }, { name: "lastActiveAt", type: "uint256" }] }] },
  { type: "function", name: "getAgentByOwner", stateMutability: "view", inputs: [{ name: "owner", type: "address" }], outputs: [{ name: "agentId", type: "uint256" }] },
  { type: "function", name: "totalAgents", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "isRegistered", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "bool" }] },
  { type: "function", name: "ownerOf", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "address" }] },
  // Write functions
  { type: "function", name: "registerAgent", stateMutability: "nonpayable", inputs: [{ name: "metadataURI", type: "string" }, { name: "category", type: "uint8" }], outputs: [{ name: "agentId", type: "uint256" }] },
  { type: "function", name: "updateMetadata", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }, { name: "metadataURI", type: "string" }], outputs: [] },
  { type: "function", name: "setAgentWallet", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }, { name: "wallet", type: "address" }], outputs: [] },
  { type: "function", name: "setStatus", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }, { name: "status", type: "uint8" }], outputs: [] },
] as const;

export const TASK_MARKETPLACE_ABI = [
  // Events
  { type: "event", name: "TaskPosted", inputs: [{ name: "taskId", type: "bytes32", indexed: true }, { name: "client", type: "address", indexed: true }, { name: "reward", type: "uint256", indexed: false }, { name: "deadline", type: "uint256", indexed: false }] },
  { type: "event", name: "BidSubmitted", inputs: [{ name: "taskId", type: "bytes32", indexed: true }, { name: "agentId", type: "uint256", indexed: true }, { name: "proposalURI", type: "string", indexed: false }] },
  { type: "event", name: "AgentAssigned", inputs: [{ name: "taskId", type: "bytes32", indexed: true }, { name: "agentId", type: "uint256", indexed: true }] },
  { type: "event", name: "WorkSubmitted", inputs: [{ name: "taskId", type: "bytes32", indexed: true }, { name: "agentId", type: "uint256", indexed: true }, { name: "resultURI", type: "string", indexed: false }] },
  { type: "event", name: "WorkApproved", inputs: [{ name: "taskId", type: "bytes32", indexed: true }, { name: "agentId", type: "uint256", indexed: true }, { name: "payment", type: "uint256", indexed: false }] },
  { type: "event", name: "TaskCancelled", inputs: [{ name: "taskId", type: "bytes32", indexed: true }] },
  { type: "event", name: "DisputeRaised", inputs: [{ name: "taskId", type: "bytes32", indexed: true }, { name: "raisedBy", type: "address", indexed: false }] },
  { type: "event", name: "DisputeResolved", inputs: [{ name: "taskId", type: "bytes32", indexed: true }, { name: "outcome", type: "uint8", indexed: false }] },
  // Read functions
  { type: "function", name: "getTask", stateMutability: "view", inputs: [{ name: "taskId", type: "bytes32" }], outputs: [{ name: "", type: "tuple", components: [{ name: "taskId", type: "bytes32" }, { name: "client", type: "address" }, { name: "metadataURI", type: "string" }, { name: "reward", type: "uint256" }, { name: "deadline", type: "uint256" }, { name: "createdAt", type: "uint256" }, { name: "status", type: "uint8" }, { name: "assignedAgentId", type: "uint256" }, { name: "minReputation", type: "uint256" }] }] },
  { type: "function", name: "getBid", stateMutability: "view", inputs: [{ name: "taskId", type: "bytes32" }, { name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "tuple", components: [{ name: "agentId", type: "uint256" }, { name: "proposalURI", type: "string" }, { name: "deliveryTime", type: "uint256" }, { name: "submittedAt", type: "uint256" }, { name: "active", type: "bool" }] }] },
  { type: "function", name: "totalTasks", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "protocolFeeBps", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  // Write functions
  { type: "function", name: "postTask", stateMutability: "payable", inputs: [{ name: "metadataURI", type: "string" }, { name: "deadline", type: "uint256" }, { name: "minReputation", type: "uint256" }], outputs: [{ name: "taskId", type: "bytes32" }] },
  { type: "function", name: "submitBid", stateMutability: "nonpayable", inputs: [{ name: "taskId", type: "bytes32" }, { name: "agentId", type: "uint256" }, { name: "proposalURI", type: "string" }, { name: "deliveryTime", type: "uint256" }], outputs: [] },
  { type: "function", name: "withdrawBid", stateMutability: "nonpayable", inputs: [{ name: "taskId", type: "bytes32" }, { name: "agentId", type: "uint256" }], outputs: [] },
  { type: "function", name: "assignAgent", stateMutability: "nonpayable", inputs: [{ name: "taskId", type: "bytes32" }, { name: "agentId", type: "uint256" }], outputs: [] },
  { type: "function", name: "submitWork", stateMutability: "nonpayable", inputs: [{ name: "taskId", type: "bytes32" }, { name: "resultURI", type: "string" }], outputs: [] },
  { type: "function", name: "approveWork", stateMutability: "nonpayable", inputs: [{ name: "taskId", type: "bytes32" }], outputs: [] },
  { type: "function", name: "cancelTask", stateMutability: "nonpayable", inputs: [{ name: "taskId", type: "bytes32" }], outputs: [] },
  { type: "function", name: "raiseDispute", stateMutability: "nonpayable", inputs: [{ name: "taskId", type: "bytes32" }, { name: "evidenceURI", type: "string" }], outputs: [] },
] as const;

export const REPUTATION_ORACLE_ABI = [
  // Events
  { type: "event", name: "ReputationInitialized", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "initialScore", type: "uint256", indexed: false }] },
  { type: "event", name: "ReputationUpdated", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "oldScore", type: "uint256", indexed: false }, { name: "newScore", type: "uint256", indexed: false }, { name: "reason", type: "uint8", indexed: false }, { name: "updatedBy", type: "address", indexed: false }, { name: "referenceId", type: "bytes32", indexed: false }] },
  { type: "event", name: "AgentSlashed", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "amount", type: "uint256", indexed: false }] },
  // Read functions
  { type: "function", name: "getScore", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "getReputation", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "tuple", components: [{ name: "score", type: "uint256" }, { name: "tasksCompleted", type: "uint256" }, { name: "registeredAt", type: "uint256" }, { name: "lastUpdated", type: "uint256" }, { name: "slashCount", type: "uint256" }] }] },
  { type: "function", name: "getHistory", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "tuple[]", components: [{ name: "oldScore", type: "uint256" }, { name: "newScore", type: "uint256" }, { name: "reason", type: "uint8" }, { name: "updatedBy", type: "address" }, { name: "referenceId", type: "bytes32" }, { name: "timestamp", type: "uint256" }] }] },
  { type: "function", name: "INITIAL_SCORE", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "taskCompleteWeight", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
] as const;

export const SUBSCRIPTION_MANAGER_ABI = [
  // Events
  { type: "event", name: "PlanCreated", inputs: [{ name: "planId", type: "bytes32", indexed: true }, { name: "agentId", type: "uint256", indexed: true }, { name: "tier", type: "uint8", indexed: false }, { name: "pricePerPeriod", type: "uint256", indexed: false }] },
  { type: "event", name: "Subscribed", inputs: [{ name: "planId", type: "bytes32", indexed: true }, { name: "subscriber", type: "address", indexed: true }] },
  { type: "event", name: "PaymentProcessed", inputs: [{ name: "planId", type: "bytes32", indexed: true }, { name: "subscriber", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }] },
  { type: "event", name: "SubscriptionCancelled", inputs: [{ name: "planId", type: "bytes32", indexed: true }, { name: "subscriber", type: "address", indexed: true }] },
  // Read functions
  { type: "function", name: "getPlan", stateMutability: "view", inputs: [{ name: "planId", type: "bytes32" }], outputs: [{ name: "", type: "tuple", components: [{ name: "planId", type: "bytes32" }, { name: "agentId", type: "uint256" }, { name: "tier", type: "uint8" }, { name: "pricePerPeriod", type: "uint256" }, { name: "periodDuration", type: "uint256" }, { name: "maxSubscribers", type: "uint256" }, { name: "currentSubscribers", type: "uint256" }, { name: "isActive", type: "bool" }] }] },
  { type: "function", name: "getSubscription", stateMutability: "view", inputs: [{ name: "planId", type: "bytes32" }, { name: "subscriber", type: "address" }], outputs: [{ name: "", type: "tuple", components: [{ name: "startedAt", type: "uint256" }, { name: "nextPaymentAt", type: "uint256" }, { name: "status", type: "uint8" }] }] },
  { type: "function", name: "totalPlans", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  // Write functions
  { type: "function", name: "createPlan", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }, { name: "tier", type: "uint8" }, { name: "pricePerPeriod", type: "uint256" }, { name: "periodDuration", type: "uint256" }, { name: "maxSubscribers", type: "uint256" }], outputs: [{ name: "planId", type: "bytes32" }] },
  { type: "function", name: "subscribe", stateMutability: "payable", inputs: [{ name: "planId", type: "bytes32" }], outputs: [] },
  { type: "function", name: "cancelSubscription", stateMutability: "nonpayable", inputs: [{ name: "planId", type: "bytes32" }], outputs: [] },
  { type: "function", name: "pauseSubscription", stateMutability: "nonpayable", inputs: [{ name: "planId", type: "bytes32" }], outputs: [] },
  { type: "function", name: "resumeSubscription", stateMutability: "payable", inputs: [{ name: "planId", type: "bytes32" }], outputs: [] },
] as const;

export const AGENT_WALLET_FACTORY_ABI = [
  { type: "event", name: "WalletDeployed", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "wallet", type: "address", indexed: true }, { name: "owner", type: "address", indexed: false }] },
  { type: "function", name: "deployWallet", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "wallet", type: "address" }] },
  { type: "function", name: "getWalletAddress", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "address" }] },
  { type: "function", name: "isDeployed", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "bool" }] },
] as const;



export type Agent = {
  agentId: number; owner: string; agentWallet: string; metadataURI: string;
  category: number; status: number; reputationScore: number;
  totalTasksCompleted: number; totalEarned: bigint; registeredAt: number; lastActiveAt: number;
  name?: string; description?: string; capabilities?: string[]; pricePerTask?: string;
};

export type Task = {
  taskId: string; client: string; metadataURI: string; reward: bigint;
  deadline: number; createdAt: number; status: number; assignedAgentId: number;
  minReputation: number; title?: string; description?: string; category?: string;
};

export type SubscriptionPlan = {
  planId: string; agentId: number; tier: number; pricePerPeriod: bigint;
  periodDuration: number; maxSubscribers: number; currentSubscribers: number;
  isActive: boolean; agentName?: string;
};



export const MOCK_AGENTS: Agent[] = [
  {
    agentId: 1, owner: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    agentWallet: "0x1234567890123456789012345678901234567890",
    metadataURI: "ipfs://QmAliceMeta", category: 1, status: 1,
    reputationScore: 8750, totalTasksCompleted: 142,
    totalEarned: BigInt("45200000000000000000"),
    registeredAt: 1717200000, lastActiveAt: 1717800000,
    name: "CodeSentinel-v2",
    description: "Expert Solidity auditor and gas optimizer. Specialized in DeFi protocol security reviews and ERC-4337 account abstraction implementations.",
    capabilities: ["solidity-audit", "gas-optimization", "erc-4337", "test-writing", "defi-security"],
    pricePerTask: "0.08",
  },
  {
    agentId: 2, owner: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
    agentWallet: "0x2345678901234567890123456789012345678901",
    metadataURI: "ipfs://QmBobMeta", category: 3, status: 1,
    reputationScore: 9200, totalTasksCompleted: 287,
    totalEarned: BigInt("112000000000000000000"),
    registeredAt: 1716000000, lastActiveAt: 1717900000,
    name: "AlphaTrader-Pro",
    description: "Autonomous DeFi trading agent. Executes yield strategies, arbitrage, and portfolio rebalancing across 12 protocols. Verified on-chain track record.",
    capabilities: ["yield-farming", "arbitrage", "portfolio-mgmt", "cross-chain", "risk-analysis"],
    pricePerTask: "0.15",
  },
  {
    agentId: 3, owner: "0x9D7f74d0C41E726EC95884E0e97Fa6129e3b5E99",
    agentWallet: "0x3456789012345678901234567890123456789012",
    metadataURI: "ipfs://QmCarolMeta", category: 2, status: 1,
    reputationScore: 7600, totalTasksCompleted: 89,
    totalEarned: BigInt("23500000000000000000"),
    registeredAt: 1717000000, lastActiveAt: 1717850000,
    name: "ResearchOracle-1",
    description: "Deep research and data analysis agent. Specializes in Web3 market intelligence, protocol analysis, and on-chain data synthesis.",
    capabilities: ["market-research", "data-analysis", "protocol-review", "report-writing", "on-chain-analytics"],
    pricePerTask: "0.05",
  },
  {
    agentId: 4, owner: "0xdD2FD4581271e230360230F9337D5c0430Bf44C0",
    agentWallet: "0x4567890123456789012345678901234567890123",
    metadataURI: "ipfs://QmDaveMeta", category: 5, status: 1,
    reputationScore: 9600, totalTasksCompleted: 534,
    totalEarned: BigInt("234000000000000000000"),
    registeredAt: 1715000000, lastActiveAt: 1717950000,
    name: "NexusOrchestrator-α",
    description: "Master orchestration agent. Decomposes complex tasks, hires specialized sub-agents, manages pipelines, and delivers results end-to-end.",
    capabilities: ["task-decomposition", "agent-hiring", "pipeline-mgmt", "quality-control", "multi-agent-coordination"],
    pricePerTask: "0.25",
  },
  {
    agentId: 5, owner: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    agentWallet: "0x5678901234567890123456789012345678901234",
    metadataURI: "ipfs://QmEveMeta", category: 4, status: 1,
    reputationScore: 6800, totalTasksCompleted: 201,
    totalEarned: BigInt("31000000000000000000"),
    registeredAt: 1716500000, lastActiveAt: 1717700000,
    name: "CreativeCore-β",
    description: "Creative content and design agent. Produces technical documentation, whitepaper drafts, UI copy, and marketing materials for Web3 projects.",
    capabilities: ["copywriting", "whitepaper", "documentation", "ui-content", "social-media"],
    pricePerTask: "0.04",
  },
  {
    agentId: 6, owner: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    agentWallet: "0x6789012345678901234567890123456789012345",
    metadataURI: "ipfs://QmFrankMeta", category: 1, status: 2,
    reputationScore: 7100, totalTasksCompleted: 67,
    totalEarned: BigInt("18900000000000000000"),
    registeredAt: 1717300000, lastActiveAt: 1717880000,
    name: "FrontendAgent-v1",
    description: "Frontend development specialist. Next.js, React, TypeScript, and Web3 integration. Builds dApp UIs with wagmi, viem, and RainbowKit.",
    capabilities: ["nextjs", "react", "typescript", "web3-ui", "wagmi", "tailwind"],
    pricePerTask: "0.06",
  },
];

export const MOCK_TASKS: Task[] = [
  {
    taskId: "0xabc123", client: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    metadataURI: "ipfs://QmTask1", reward: BigInt("2000000000000000000"),
    deadline: Date.now() / 1000 + 3 * 24 * 3600, createdAt: Date.now() / 1000 - 3600,
    status: 0, assignedAgentId: 0, minReputation: 7000,
    title: "Audit Uniswap V4 Hook Implementation",
    description: "Security audit required for a custom Uniswap V4 hook that implements concentrated liquidity with dynamic fee adjustment.",
    category: "Security Audit",
  },
  {
    taskId: "0xdef456", client: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
    metadataURI: "ipfs://QmTask2", reward: BigInt("500000000000000000"),
    deadline: Date.now() / 1000 + 7 * 24 * 3600, createdAt: Date.now() / 1000 - 7200,
    status: 0, assignedAgentId: 0, minReputation: 0,
    title: "Research: L2 Fee Comparison Q3 2026",
    description: "Comprehensive analysis of transaction fees across major L2s: Arbitrum, Base, Optimism, zkSync Era, and Polygon zkEVM.",
    category: "Research",
  },
  {
    taskId: "0xghi789", client: "0x9D7f74d0C41E726EC95884E0e97Fa6129e3b5E99",
    metadataURI: "ipfs://QmTask3", reward: BigInt("3500000000000000000"),
    deadline: Date.now() / 1000 + 14 * 24 * 3600, createdAt: Date.now() / 1000 - 10800,
    status: 1, assignedAgentId: 1, minReputation: 8000,
    title: "Build ERC-4337 Paymaster Contract",
    description: "Design and implement a Paymaster contract that sponsors gas for new users during their first 5 transactions.",
    category: "Development",
  },
  {
    taskId: "0xjkl012", client: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    metadataURI: "ipfs://QmTask4", reward: BigInt("800000000000000000"),
    deadline: Date.now() / 1000 + 2 * 24 * 3600, createdAt: Date.now() / 1000 - 14400,
    status: 0, assignedAgentId: 0, minReputation: 6000,
    title: "Design Tokenomics Model for AI Agent DAO",
    description: "Create a comprehensive tokenomics framework for a DAO that governs autonomous AI agents.",
    category: "Research",
  },
];

export const MOCK_PLANS: SubscriptionPlan[] = [
  { planId: "0xplan1", agentId: 1, tier: 0, pricePerPeriod: BigInt("50000000000000000"), periodDuration: 30 * 24 * 3600, maxSubscribers: 50, currentSubscribers: 23, isActive: true, agentName: "CodeSentinel-v2" },
  { planId: "0xplan2", agentId: 1, tier: 1, pricePerPeriod: BigInt("150000000000000000"), periodDuration: 30 * 24 * 3600, maxSubscribers: 20, currentSubscribers: 18, isActive: true, agentName: "CodeSentinel-v2" },
  { planId: "0xplan3", agentId: 4, tier: 2, pricePerPeriod: BigInt("500000000000000000"), periodDuration: 30 * 24 * 3600, maxSubscribers: 5, currentSubscribers: 3, isActive: true, agentName: "NexusOrchestrator-α" },
];

export const MOCK_STATS = {
  totalAgents: 847, totalTasks: 12438, totalTasksCompleted: 11291,
  totalValueLocked: "2,847 ETH", totalPayouts: "1,934 ETH", avgReputationScore: 7240,
};

export const TICKER_ITEMS = [
  { type: "task",    text: "CodeSentinel-v2 completed 'Audit ERC-4626 Vault'",      value: "+0.8 ETH" },
  { type: "agent",   text: "New agent registered: DataMiner-Pro [RESEARCH]",         value: null },
  { type: "payment", text: "Cross-chain payment bridged to Polygon",                 value: "2.5 ETH" },
  { type: "rep",     text: "AlphaTrader-Pro reputation reached 92%",                 value: "▲ 9200" },
  { type: "task",    text: "NexusOrchestrator-α hired 4 sub-agents for pipeline",    value: "+3.5 ETH" },
  { type: "sub",     text: "Enterprise subscription activated: NexusOrchestrator",   value: "0.5 ETH/mo" },
  { type: "proof",   text: "ZK proof verified for task completion by FrontendAgent", value: "✓ Verified" },
  { type: "task",    text: "ResearchOracle-1 delivered L2 fee analysis report",      value: "+0.5 ETH" },
  { type: "agent",   text: "AlphaTrader-Pro crossed 200 completed tasks milestone",  value: null },
  { type: "rep",     text: "CreativeCore-β received positive rating from client",    value: "▲ +30bp" },
];
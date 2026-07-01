import type { NexusContracts } from "../types";

// ── Sepolia deployed addresses ─────────────────────────────────

export const NEXUS_SEPOLIA_CONTRACTS: NexusContracts = {
  AgentRegistry:       "0x68F76277A7a8991CE7ac7182AAA10a356dAaB48F",
  AgentWalletFactory:  "0xce48B6eE3Cac616A103016C70436cb3eB0183c65",
  ReputationOracle:    "0x7deC5525AC26Bcf134c5e8cD7485c16CBC00EeDA",
  AgentMemory:         "0x40B16F644bD696D8D7a2507671b8D556b9821673",
  TaskMarketplace:     "0x16B3cD374B3596635A76D874c1A3138e7236C76e",
  ZKVerifier:          "0xA292dA54BF85BD6692B1082ceB88a1F6d671EFe8",
  SubscriptionManager: "0x60385A61e663B5a1ed616C3C090764faBaAcec13",
  CrossChainBridge:    "0x7a3Cd54bB1039823B15Eff1df78D044C7D79628a",
  Groth16Verifier:     "0x68F76277A7a8991CE7ac7182AAA10a356dAaB48F",
  NexusServiceManager: "0x2E1eF805b574094AFDF84f86b4B9bf07697F3080",
  AgentStaking:        "0x30852aE83c52a6140A64F63d62d5AeA284d3e723",
  AgentIdentityNFT:    "0xB09a7a641dBF6c8cB0430EDA307e48eAdFa9EA50",
  AgentSkillNFT:       "0x8f45Bd7d2FFa5fB1c17612D4CcE89c1d9d4746A4",
  AgentComposability:  "0x4628ba31A9264e7eA204b62849e17AF5E10b1f55",
  ZKEscrow:            "0x2EcD5ce3d5140aB7Df3063aAB817AF1336d04416",
};

export const SEPOLIA_CHAIN_ID = 11155111;

// ── Minimal ABIs (only what SDK needs) ────────────────────────

export const AGENT_REGISTRY_ABI = [
  {
    name: "registerAgent",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "metadataURI", type: "string" },
      { name: "category", type: "uint8" },
    ],
    outputs: [{ name: "agentId", type: "uint256" }],
  },
  {
    name: "getAgent",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "agentId", type: "uint256" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "agentId", type: "uint256" },
          { name: "owner", type: "address" },
          { name: "agentWallet", type: "address" },
          { name: "metadataURI", type: "string" },
          { name: "category", type: "uint8" },
          { name: "status", type: "uint8" },
          { name: "reputationScore", type: "uint256" },
          { name: "totalTasksCompleted", type: "uint256" },
          { name: "totalEarned", type: "uint256" },
          { name: "registeredAt", type: "uint256" },
          { name: "lastActiveAt", type: "uint256" },
        ],
      },
    ],
  },
  {
    name: "getAgentByOwner",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "agentId", type: "uint256" },
          { name: "owner", type: "address" },
          { name: "agentWallet", type: "address" },
          { name: "metadataURI", type: "string" },
          { name: "category", type: "uint8" },
          { name: "status", type: "uint8" },
          { name: "reputationScore", type: "uint256" },
          { name: "totalTasksCompleted", type: "uint256" },
          { name: "totalEarned", type: "uint256" },
          { name: "registeredAt", type: "uint256" },
          { name: "lastActiveAt", type: "uint256" },
        ],
      },
    ],
  },
  {
    name: "getAgentIdByOwner",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "isRegistered",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    name: "totalAgents",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "setAgentWallet",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "agentId", type: "uint256" },
      { name: "wallet", type: "address" },
    ],
    outputs: [],
  },
  {
    name: "AgentRegistered",
    type: "event",
    inputs: [
      { name: "agentId", type: "uint256", indexed: true },
      { name: "owner", type: "address", indexed: true },
      { name: "agentWallet", type: "address", indexed: true },
      { name: "metadataURI", type: "string", indexed: false },
      { name: "category", type: "uint8", indexed: false },
    ],
  },
] as const;

export const TASK_MARKETPLACE_ABI = [
  {
    name: "postTask",
    type: "function",
    stateMutability: "payable",
    inputs: [
      { name: "metadataURI", type: "string" },
      { name: "deadline", type: "uint256" },
      { name: "minReputation", type: "uint256" },
    ],
    outputs: [{ name: "taskId", type: "bytes32" }],
  },
  {
    name: "submitBid",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "taskId", type: "bytes32" },
      { name: "agentId", type: "uint256" },
      { name: "proposalURI", type: "string" },
      { name: "estimatedTime", type: "uint256" },
    ],
    outputs: [],
  },
  {
    name: "assignAgent",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "taskId", type: "bytes32" },
      { name: "agentId", type: "uint256" },
    ],
    outputs: [],
  },
  {
    name: "submitWork",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "taskId", type: "bytes32" },
      { name: "agentId", type: "uint256" },
      { name: "resultURI", type: "string" },
    ],
    outputs: [],
  },
  {
    name: "approveWork",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "taskId", type: "bytes32" }],
    outputs: [],
  },
  {
    name: "getTask",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "taskId", type: "bytes32" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "taskId", type: "bytes32" },
          { name: "client", type: "address" },
          { name: "clientAgentId", type: "uint256" },
          { name: "metadataURI", type: "string" },
          { name: "reward", type: "uint256" },
          { name: "deadline", type: "uint256" },
          { name: "createdAt", type: "uint256" },
          { name: "assignedAt", type: "uint256" },
          { name: "submittedAt", type: "uint256" },
          { name: "completedAt", type: "uint256" },
          { name: "status", type: "uint8" },
          { name: "assignedAgentId", type: "uint256" },
          { name: "assignedAgentWallet", type: "address" },
          { name: "platformFee", type: "uint256" },
          { name: "requiresMinReputation", type: "bool" },
          { name: "minReputation", type: "uint256" },
        ],
      },
    ],
  },
  {
    name: "getClientTasks",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "client", type: "address" }],
    outputs: [{ name: "", type: "bytes32[]" }],
  },
  {
    name: "getAgentTasks",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "agentId", type: "uint256" }],
    outputs: [{ name: "", type: "bytes32[]" }],
  },
  {
    name: "totalTasksPosted",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "totalTasksCompleted",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "TaskPosted",
    type: "event",
    inputs: [
      { name: "taskId", type: "bytes32", indexed: true },
      { name: "client", type: "address", indexed: true },
      { name: "reward", type: "uint256", indexed: false },
      { name: "deadline", type: "uint256", indexed: false },
      { name: "metadataURI", type: "string", indexed: false },
    ],
  },
  {
    name: "TaskCompleted",
    type: "event",
    inputs: [
      { name: "taskId", type: "bytes32", indexed: true },
      { name: "agentId", type: "uint256", indexed: true },
      { name: "agentPayment", type: "uint256", indexed: false },
      { name: "fee", type: "uint256", indexed: false },
    ],
  },
] as const;

export const REPUTATION_ORACLE_ABI = [
  {
    name: "getScore",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "agentId", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

export const AGENT_STAKING_ABI = [
  {
    name: "stake",
    type: "function",
    stateMutability: "payable",
    inputs: [{ name: "agentId", type: "uint256" }],
    outputs: [],
  },
  {
    name: "getStake",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "agentId", type: "uint256" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "agentId", type: "uint256" },
          { name: "totalStaked", type: "uint256" },
          { name: "ownStake", type: "uint256" },
          { name: "delegatedStake", type: "uint256" },
          { name: "lockedStake", type: "uint256" },
          { name: "slashCount", type: "uint256" },
          { name: "totalSlashed", type: "uint256" },
          { name: "lastStakedAt", type: "uint256" },
          { name: "unstakeRequestedAt", type: "uint256" },
          { name: "unstakeAmount", type: "uint256" },
        ],
      },
    ],
  },
  {
    name: "getEffectiveStake",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "agentId", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "isEligibleToBid",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "agentId", type: "uint256" },
      { name: "taskMinStake", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    name: "requestUnstake",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "agentId", type: "uint256" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
  },
  {
    name: "unstake",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "agentId", type: "uint256" }],
    outputs: [],
  },
] as const;

export const ZK_ESCROW_ABI = [
  {
    name: "createEscrow",
    type: "function",
    stateMutability: "payable",
    inputs: [
      { name: "taskId", type: "bytes32" },
      { name: "agentWallet", type: "address" },
      { name: "deadline", type: "uint256" },
    ],
    outputs: [{ name: "escrowId", type: "bytes32" }],
  },
  {
    name: "setCommitment",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "escrowId", type: "bytes32" },
      { name: "commitment", type: "bytes32" },
    ],
    outputs: [],
  },
  {
    name: "releaseWithProof",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "escrowId", type: "bytes32" },
      { name: "resultHash", type: "bytes32" },
      { name: "salt", type: "bytes32" },
      { name: "pA", type: "uint256[2]" },
      { name: "pB", type: "uint256[2][2]" },
      { name: "pC", type: "uint256[2]" },
      { name: "pubSignals", type: "uint256[2]" },
    ],
    outputs: [],
  },
  {
    name: "refundAfterDeadline",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "escrowId", type: "bytes32" }],
    outputs: [],
  },
  {
    name: "getEscrow",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "escrowId", type: "bytes32" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "escrowId", type: "bytes32" },
          { name: "taskId", type: "bytes32" },
          { name: "client", type: "address" },
          { name: "agentWallet", type: "address" },
          { name: "amount", type: "uint256" },
          { name: "commitment", type: "bytes32" },
          { name: "deadline", type: "uint256" },
          { name: "createdAt", type: "uint256" },
          { name: "releasedAt", type: "uint256" },
          { name: "status", type: "uint8" },
          { name: "proofId", type: "bytes32" },
        ],
      },
    ],
  },
] as const;

export const AGENT_COMPOSABILITY_ABI = [
  {
    name: "createSubTask",
    type: "function",
    stateMutability: "payable",
    inputs: [
      { name: "parentTaskId", type: "bytes32" },
      { name: "parentAgentId", type: "uint256" },
      { name: "metadataURI", type: "string" },
      { name: "deadline", type: "uint256" },
      { name: "splitBps", type: "uint256" },
    ],
    outputs: [{ name: "subTaskId", type: "bytes32" }],
  },
  {
    name: "assignSubAgent",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "subTaskId", type: "bytes32" },
      { name: "subAgentId", type: "uint256" },
    ],
    outputs: [],
  },
  {
    name: "submitSubWork",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "subTaskId", type: "bytes32" },
      { name: "subAgentId", type: "uint256" },
      { name: "resultURI", type: "string" },
    ],
    outputs: [],
  },
  {
    name: "approveSubWork",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "subTaskId", type: "bytes32" }],
    outputs: [],
  },
  {
    name: "getSubTask",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "subTaskId", type: "bytes32" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "subTaskId", type: "bytes32" },
          { name: "parentTaskId", type: "bytes32" },
          { name: "parentAgentId", type: "uint256" },
          { name: "subAgentId", type: "uint256" },
          { name: "metadataURI", type: "string" },
          { name: "reward", type: "uint256" },
          { name: "splitBps", type: "uint256" },
          { name: "deadline", type: "uint256" },
          { name: "createdAt", type: "uint256" },
          { name: "completedAt", type: "uint256" },
          { name: "status", type: "uint8" },
          { name: "resultURI", type: "string" },
        ],
      },
    ],
  },
  {
    name: "getAgentRelationship",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "parentId", type: "uint256" },
      { name: "subId", type: "uint256" },
    ],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "parentAgentId", type: "uint256" },
          { name: "subAgentId", type: "uint256" },
          { name: "totalSubTasksGiven", type: "uint256" },
          { name: "totalSubTasksCompleted", type: "uint256" },
          { name: "totalEthPaid", type: "uint256" },
          { name: "firstCollabAt", type: "uint256" },
          { name: "lastCollabAt", type: "uint256" },
        ],
      },
    ],
  },
] as const;

// ── Enum mappings ──────────────────────────────────────────────

export const AGENT_CATEGORY_TO_UINT: Record<string, number> = {
  GENERAL: 0, CODE: 1, RESEARCH: 2,
  TRADING: 3, CREATIVE: 4, ORCHESTRATOR: 5,
};

export const UINT_TO_AGENT_CATEGORY: Record<number, string> = {
  0: "GENERAL", 1: "CODE", 2: "RESEARCH",
  3: "TRADING", 4: "CREATIVE", 5: "ORCHESTRATOR",
};

export const UINT_TO_AGENT_STATUS: Record<number, string> = {
  0: "INACTIVE", 1: "ACTIVE", 2: "BUSY",
  3: "SUSPENDED", 4: "RETIRED",
};

export const UINT_TO_TASK_STATUS: Record<number, string> = {
  0: "OPEN", 1: "ASSIGNED", 2: "SUBMITTED",
  3: "COMPLETED", 4: "CANCELLED", 5: "DISPUTED", 6: "RESOLVED",
};

export const UINT_TO_ESCROW_STATUS: Record<number, string> = {
  0: "OPEN", 1: "RELEASED", 2: "REFUNDED", 3: "DISPUTED",
};

export const UINT_TO_SKILL_TIER: Record<number, string> = {
  0: "NONE", 1: "BRONZE", 2: "SILVER",
  3: "GOLD", 4: "PLATINUM", 5: "DIAMOND",
};
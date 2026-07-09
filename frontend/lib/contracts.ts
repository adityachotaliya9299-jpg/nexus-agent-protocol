

export const CONTRACTS = {
  AgentRegistry:        "0x68F76277A7a8991CE7ac7182AAA10a356dAaB48F" as `0x${string}`,
  AgentWalletFactory:   "0xce48B6eE3Cac616A103016C70436cb3eB0183c65" as `0x${string}`,
  ReputationOracle:     "0x7deC5525AC26Bcf134c5e8cD7485c16CBC00EeDA" as `0x${string}`,
  AgentMemory:          "0x40B16F644bD696D8D7a2507671b8D556b9821673" as `0x${string}`,
  TaskMarketplace:      "0x16B3cD374B3596635A76D874c1A3138e7236C76e" as `0x${string}`,
  ZKVerifier:           "0xA292dA54BF85BD6692B1082ceB88a1F6d671EFe8" as `0x${string}`,
  SubscriptionManager:  "0x60385A61e663B5a1ed616C3C090764faBaAcec13" as `0x${string}`,
  CrossChainBridge:     "0x7a3Cd54bB1039823B15Eff1df78D044C7D79628a" as `0x${string}`,

  // ── New contracts (phases 9-29) ───────────────────────────────
  Groth16Verifier:      "0x68F76277A7a8991CE7ac7182AAA10a356dAaB48F" as `0x${string}`,
  NexusServiceManager:  "0x2E1eF805b574094AFDF84f86b4B9bf07697F3080" as `0x${string}`,
  AgentStaking:         "0x30852aE83c52a6140A64F63d62d5AeA284d3e723" as `0x${string}`,
  AgentIdentityNFT:     "0xB09a7a641dBF6c8cB0430EDA307e48eAdFa9EA50" as `0x${string}`,
  AgentSkillNFT:        "0x8f45Bd7d2FFa5fB1c17612D4CcE89c1d9d4746A4" as `0x${string}`,
  AgentComposability:   "0x4628ba31A9264e7eA204b62849e17AF5E10b1f55" as `0x${string}`,
  ZKEscrow:             "0x2EcD5ce3d5140aB7Df3063aAB817AF1336d04416" as `0x${string}`,
  ContextualReputation: "0xAFE6c16FA37bB0BD9E7A24901705C7Fe725A910A" as `0x${string}`,
  AgentDiscovery:       "0x08787B020D4Ded4Beb9Ff116e041047491A7F126" as `0x${string}`,
  L1Bridge:             "0x539C3a8E6Df66B4cA743e05d6B49c04E2490Ec2a" as `0x${string}`,
  L2Bridge:             "0x7acD2Fca97F2d5b4C85CF56B2c6e49C73b5B640F" as `0x${string}`,
  AgentCoordinator:  "0xa14b2dd25279e5bCd8aF219e336b3A48b47124B1" as `0x${string}`,  

  // NexusTreasury:     "" as `0x${string}`,  // forge script DeployGovernance.s.sol
  // NexusGovernor:     "" as `0x${string}`,  // forge script DeployGovernance.s.sol
  // ResultStorage:     "" as `0x${string}`,  // forge script DeployBatch.s.sol
  // AgentDAO:          "" as `0x${string}`,  // forge script DeployBatch.s.sol
  // CommunityGrants:   "" as `0x${string}`,  // forge script DeployBatch.s.sol
  // ProtocolGuard:     "" as `0x${string}`,  // forge script DeployProtocolGuard.s.sol
} as const;

// Convenience alias used by new UI components
export const NEXUS_CONTRACTS = CONTRACTS;

export function isDeployed(): boolean {
  return CONTRACTS.AgentRegistry !== "0x0000000000000000000000000000000000000000";
}

// ── Chain config ──────────────────────────────────────────────

export const SEPOLIA_CHAIN_ID = 11155111;

// ── Helper constants ──────────────────────────────────────────

export const CATEGORIES = ['GENERAL','CODE','RESEARCH','TRADING','CREATIVE','ORCHESTRATOR'] as const;
export type Category = typeof CATEGORIES[number];

export const CATEGORY_COLORS: Record<string, string> = {
  GENERAL:      '#64748B',
  CODE:         '#8B5CF6',
  RESEARCH:     '#06B6D4',
  TRADING:      '#10B981',
  CREATIVE:     '#F59E0B',
  ORCHESTRATOR: '#F43F5E',
};

export const TIER_LABELS = ['Novice','Rising','Established','Advanced','Expert','Elite'] as const;
export const TIER_COLORS = ['#64748B','#06B6D4','#10B981','#8B5CF6','#F59E0B','#F43F5E'] as const;

export function getTier(score: number) {
  if (score >= 10000) return { label: 'Elite',       color: '#F43F5E', index: 5 };
  if (score >= 8000)  return { label: 'Expert',      color: '#F59E0B', index: 4 };
  if (score >= 6000)  return { label: 'Advanced',    color: '#8B5CF6', index: 3 };
  if (score >= 4000)  return { label: 'Established', color: '#10B981', index: 2 };
  if (score >= 2000)  return { label: 'Rising',      color: '#06B6D4', index: 1 };
  return                    { label: 'Novice',       color: '#64748B', index: 0 };
}

export function shortenAddr(addr: string) {
  return `${addr.slice(0,6)}…${addr.slice(-4)}`;
}

export function formatEth(wei: bigint) {
  const eth = Number(wei) / 1e18;
  if (eth === 0) return '0 ETH';
  if (eth < 0.001) return '<0.001 ETH';
  return `${eth.toFixed(3)} ETH`;
}

// ================================================================
// ABIs — ORIGINAL (preserved exactly)
// ================================================================

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
  { type: "function", name: "totalTasksPosted", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "totalTasksCompleted", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "protocolFeeBps", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "platformFeeBps", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
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
  { type: "event", name: "SubscriptionCancelled", inputs: [{ name: "planId", type: "bytes32", indexed: true }, { name: "subscriber", type: "address", indexed: true }] },
  // Read functions
  { type: "function", name: "getPlan", stateMutability: "view", inputs: [{ name: "planId", type: "bytes32" }], outputs: [{ name: "", type: "tuple", components: [{ name: "planId", type: "bytes32" }, { name: "agentId", type: "uint256" }, { name: "tier", type: "uint8" }, { name: "pricePerPeriod", type: "uint256" }, { name: "periodDuration", type: "uint256" }, { name: "maxSubscribers", type: "uint256" }, { name: "currentSubscribers", type: "uint256" }, { name: "isActive", type: "bool" }] }] },
  { type: "function", name: "isSubscribed", stateMutability: "view", inputs: [{ name: "planId", type: "bytes32" }, { name: "subscriber", type: "address" }], outputs: [{ name: "", type: "bool" }] },
  // Write functions
  { type: "function", name: "createPlan", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }, { name: "tier", type: "uint8" }, { name: "pricePerPeriod", type: "uint256" }, { name: "periodDuration", type: "uint256" }, { name: "maxSubscribers", type: "uint256" }], outputs: [{ name: "planId", type: "bytes32" }] },
  { type: "function", name: "subscribe", stateMutability: "payable", inputs: [{ name: "planId", type: "bytes32" }], outputs: [] },
  { type: "function", name: "cancelSubscription", stateMutability: "nonpayable", inputs: [{ name: "planId", type: "bytes32" }], outputs: [] },
] as const;

// ================================================================
// ABIs — NEW (phases 9-29)
// ================================================================

export const AGENT_STAKING_ABI = [
  { type: "event", name: "Staked", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "staker", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }] },
  { type: "event", name: "Slashed", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "slashBps", type: "uint256", indexed: false }, { name: "totalSlashed", type: "uint256", indexed: false }] },
  { type: "event", name: "UnstakeRequested", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "amount", type: "uint256", indexed: false }] },
  // Read
  { type: "function", name: "getStake", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "tuple", components: [{ name: "agentId", type: "uint256" }, { name: "totalStaked", type: "uint256" }, { name: "ownStake", type: "uint256" }, { name: "delegatedStake", type: "uint256" }, { name: "lockedStake", type: "uint256" }, { name: "slashCount", type: "uint256" }, { name: "totalSlashed", type: "uint256" }, { name: "lastStakedAt", type: "uint256" }, { name: "unstakeRequestedAt", type: "uint256" }, { name: "unstakeAmount", type: "uint256" }] }] },
  { type: "function", name: "getEffectiveStake", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "isEligibleToBid", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }, { name: "taskMinStake", type: "uint256" }], outputs: [{ name: "", type: "bool" }] },
  { type: "function", name: "slashRateBps", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "MAX_SLASH_BPS", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  // Write
  { type: "function", name: "stake", stateMutability: "payable", inputs: [{ name: "agentId", type: "uint256" }], outputs: [] },
  { type: "function", name: "requestUnstake", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }, { name: "amount", type: "uint256" }], outputs: [] },
  { type: "function", name: "unstake", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }], outputs: [] },
  { type: "function", name: "delegateStake", stateMutability: "payable", inputs: [{ name: "agentId", type: "uint256" }], outputs: [] },
] as const;

export const ZK_ESCROW_ABI = [
  { type: "event", name: "EscrowCreated", inputs: [{ name: "escrowId", type: "bytes32", indexed: true }, { name: "taskId", type: "bytes32", indexed: true }, { name: "client", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }, { name: "deadline", type: "uint256", indexed: false }] },
  { type: "event", name: "CommitmentSet", inputs: [{ name: "escrowId", type: "bytes32", indexed: true }, { name: "commitment", type: "bytes32", indexed: false }] },
  { type: "event", name: "EscrowReleased", inputs: [{ name: "escrowId", type: "bytes32", indexed: true }, { name: "agentWallet", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }] },
  { type: "event", name: "EscrowRefunded", inputs: [{ name: "escrowId", type: "bytes32", indexed: true }, { name: "client", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }] },
  // Read
  { type: "function", name: "getEscrow", stateMutability: "view", inputs: [{ name: "escrowId", type: "bytes32" }], outputs: [{ name: "", type: "tuple", components: [{ name: "escrowId", type: "bytes32" }, { name: "taskId", type: "bytes32" }, { name: "client", type: "address" }, { name: "agentWallet", type: "address" }, { name: "amount", type: "uint256" }, { name: "commitment", type: "bytes32" }, { name: "deadline", type: "uint256" }, { name: "createdAt", type: "uint256" }, { name: "releasedAt", type: "uint256" }, { name: "status", type: "uint8" }, { name: "proofId", type: "bytes32" }] }] },
  { type: "function", name: "getTaskEscrow", stateMutability: "view", inputs: [{ name: "taskId", type: "bytes32" }], outputs: [{ name: "", type: "bytes32" }] },
  { type: "function", name: "totalEscrows", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "totalReleased", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "accruedFees", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  // Write
  { type: "function", name: "createEscrow", stateMutability: "payable", inputs: [{ name: "taskId", type: "bytes32" }, { name: "agentWallet", type: "address" }, { name: "deadline", type: "uint256" }], outputs: [{ name: "escrowId", type: "bytes32" }] },
  { type: "function", name: "setCommitment", stateMutability: "nonpayable", inputs: [{ name: "escrowId", type: "bytes32" }, { name: "commitment", type: "bytes32" }], outputs: [] },
  { type: "function", name: "releaseWithProof", stateMutability: "nonpayable", inputs: [{ name: "escrowId", type: "bytes32" }, { name: "resultHash", type: "bytes32" }, { name: "salt", type: "bytes32" }, { name: "pA", type: "uint256[2]" }, { name: "pB", type: "uint256[2][2]" }, { name: "pC", type: "uint256[2]" }, { name: "pubSignals", type: "uint256[2]" }], outputs: [] },
  { type: "function", name: "refundAfterDeadline", stateMutability: "nonpayable", inputs: [{ name: "escrowId", type: "bytes32" }], outputs: [] },
  { type: "function", name: "raiseDispute", stateMutability: "nonpayable", inputs: [{ name: "escrowId", type: "bytes32" }], outputs: [] },
] as const;

export const AGENT_COMPOSABILITY_ABI = [
  { type: "event", name: "SubTaskCreated", inputs: [{ name: "subTaskId", type: "bytes32", indexed: true }, { name: "parentTaskId", type: "bytes32", indexed: true }, { name: "parentAgentId", type: "uint256", indexed: true }, { name: "reward", type: "uint256", indexed: false }, { name: "deadline", type: "uint256", indexed: false }] },
  { type: "event", name: "SubTaskAssigned", inputs: [{ name: "subTaskId", type: "bytes32", indexed: true }, { name: "subAgentId", type: "uint256", indexed: true }] },
  { type: "event", name: "SubTaskCompleted", inputs: [{ name: "subTaskId", type: "bytes32", indexed: true }, { name: "subAgentId", type: "uint256", indexed: true }, { name: "payment", type: "uint256", indexed: false }] },
  // Read
  { type: "function", name: "getSubTask", stateMutability: "view", inputs: [{ name: "subTaskId", type: "bytes32" }], outputs: [{ name: "", type: "tuple", components: [{ name: "subTaskId", type: "bytes32" }, { name: "parentTaskId", type: "bytes32" }, { name: "parentAgentId", type: "uint256" }, { name: "subAgentId", type: "uint256" }, { name: "metadataURI", type: "string" }, { name: "reward", type: "uint256" }, { name: "splitBps", type: "uint256" }, { name: "deadline", type: "uint256" }, { name: "createdAt", type: "uint256" }, { name: "completedAt", type: "uint256" }, { name: "status", type: "uint8" }, { name: "resultURI", type: "string" }] }] },
  { type: "function", name: "getAgentRelationship", stateMutability: "view", inputs: [{ name: "parentId", type: "uint256" }, { name: "subId", type: "uint256" }], outputs: [{ name: "", type: "tuple", components: [{ name: "parentAgentId", type: "uint256" }, { name: "subAgentId", type: "uint256" }, { name: "totalSubTasksGiven", type: "uint256" }, { name: "totalSubTasksCompleted", type: "uint256" }, { name: "totalEthPaid", type: "uint256" }, { name: "firstCollabAt", type: "uint256" }, { name: "lastCollabAt", type: "uint256" }] }] },
  { type: "function", name: "totalSubTasks", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  // Write
  { type: "function", name: "createSubTask", stateMutability: "payable", inputs: [{ name: "parentTaskId", type: "bytes32" }, { name: "parentAgentId", type: "uint256" }, { name: "metadataURI", type: "string" }, { name: "deadline", type: "uint256" }, { name: "splitBps", type: "uint256" }], outputs: [{ name: "subTaskId", type: "bytes32" }] },
  { type: "function", name: "assignSubAgent", stateMutability: "nonpayable", inputs: [{ name: "subTaskId", type: "bytes32" }, { name: "subAgentId", type: "uint256" }], outputs: [] },
  { type: "function", name: "submitSubWork", stateMutability: "nonpayable", inputs: [{ name: "subTaskId", type: "bytes32" }, { name: "subAgentId", type: "uint256" }, { name: "resultURI", type: "string" }], outputs: [] },
  { type: "function", name: "approveSubWork", stateMutability: "nonpayable", inputs: [{ name: "subTaskId", type: "bytes32" }], outputs: [] },
] as const;

export const CONTEXTUAL_REPUTATION_ABI = [
  { type: "event", name: "CategoryScoreUpdated", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "category", type: "uint256", indexed: true }, { name: "oldScore", type: "uint256", indexed: false }, { name: "newScore", type: "uint256", indexed: false }, { name: "tasksCompleted", type: "uint256", indexed: false }] },
  { type: "event", name: "RatingSubmitted", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "category", type: "uint256", indexed: true }, { name: "rating", type: "uint256", indexed: false }, { name: "rater", type: "address", indexed: true }] },
  // Read
  { type: "function", name: "getProfile", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "tuple", components: [{ name: "agentId", type: "uint256" }, { name: "categoryScores", type: "uint256[6]" }, { name: "bestCategory", type: "uint256" }, { name: "bestScore", type: "uint256" }, { name: "globalAverage", type: "uint256" }] }] },
  { type: "function", name: "getScore", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }, { name: "category", type: "uint256" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "getCategoryScore", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }, { name: "category", type: "uint256" }], outputs: [{ name: "", type: "tuple", components: [{ name: "agentId", type: "uint256" }, { name: "category", type: "uint256" }, { name: "score", type: "uint256" }, { name: "tasksCompleted", type: "uint256" }, { name: "tasksAssigned", type: "uint256" }, { name: "totalRatings", type: "uint256" }, { name: "ratingCount", type: "uint256" }, { name: "lastUpdatedAt", type: "uint256" }, { name: "streak", type: "uint256" }] }] },
  { type: "function", name: "getBestCategory", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "category", type: "uint256" }, { name: "score", type: "uint256" }] },
  { type: "function", name: "meetsRequirement", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }, { name: "category", type: "uint256" }, { name: "minScore", type: "uint256" }], outputs: [{ name: "", type: "bool" }] },
  // Write
  { type: "function", name: "recordCompletion", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }, { name: "category", type: "uint256" }, { name: "success", type: "bool" }], outputs: [] },
  { type: "function", name: "submitRating", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }, { name: "category", type: "uint256" }, { name: "rating", type: "uint256" }, { name: "taskId", type: "bytes32" }], outputs: [] },
] as const;

export const AGENT_DISCOVERY_ABI = [
  { type: "event", name: "AgentIndexed", inputs: [{ name: "agentId", type: "uint256", indexed: true }, { name: "category", type: "uint256", indexed: true }] },
  { type: "event", name: "AgentDeindexed", inputs: [{ name: "agentId", type: "uint256", indexed: true }] },
  // Read
  { type: "function", name: "search", stateMutability: "view", inputs: [{ name: "filter", type: "tuple", components: [{ name: "category", type: "uint256" }, { name: "minContextualScore", type: "uint256" }, { name: "minGlobalScore", type: "uint256" }, { name: "minStake", type: "uint256" }, { name: "minTasksCompleted", type: "uint256" }, { name: "activeOnly", type: "bool" }] }, { name: "limit", type: "uint256" }], outputs: [{ name: "", type: "tuple[]", components: [{ name: "agentId", type: "uint256" }, { name: "owner", type: "address" }, { name: "agentWallet", type: "address" }, { name: "category", type: "uint256" }, { name: "globalRepScore", type: "uint256" }, { name: "contextualScore", type: "uint256" }, { name: "totalTasksCompleted", type: "uint256" }, { name: "stakedAmount", type: "uint256" }, { name: "effectiveStake", type: "uint256" }, { name: "isActive", type: "bool" }, { name: "metadataURI", type: "string" }] }] },
  { type: "function", name: "getLeaderboard", stateMutability: "view", inputs: [{ name: "category", type: "uint256" }, { name: "limit", type: "uint256" }], outputs: [{ name: "", type: "tuple[]", components: [{ name: "agentId", type: "uint256" }, { name: "owner", type: "address" }, { name: "score", type: "uint256" }, { name: "rank", type: "uint256" }, { name: "tasksCompleted", type: "uint256" }] }] },
  { type: "function", name: "getAgentProfile", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }], outputs: [{ name: "", type: "tuple", components: [{ name: "agentId", type: "uint256" }, { name: "owner", type: "address" }, { name: "agentWallet", type: "address" }, { name: "category", type: "uint256" }, { name: "globalRepScore", type: "uint256" }, { name: "contextualScore", type: "uint256" }, { name: "totalTasksCompleted", type: "uint256" }, { name: "stakedAmount", type: "uint256" }, { name: "effectiveStake", type: "uint256" }, { name: "isActive", type: "bool" }, { name: "metadataURI", type: "string" }] }] },
  { type: "function", name: "findBestAgent", stateMutability: "view", inputs: [{ name: "category", type: "uint256" }, { name: "minScore", type: "uint256" }, { name: "minStake", type: "uint256" }], outputs: [{ name: "agentId", type: "uint256" }, { name: "score", type: "uint256" }] },
  { type: "function", name: "totalIndexed", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "getIndexedAgents", stateMutability: "view", inputs: [{ name: "offset", type: "uint256" }, { name: "limit", type: "uint256" }], outputs: [{ name: "agentIds", type: "uint256[]" }] },
  // Write
  { type: "function", name: "indexAgent", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }], outputs: [] },
  { type: "function", name: "deindexAgent", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }], outputs: [] },
] as const;

export const AGENT_IDENTITY_NFT_ABI = [
  { type: "function", name: "name", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "string" }] },
  { type: "function", name: "tokenURI", stateMutability: "view", inputs: [{ name: "tokenId", type: "uint256" }], outputs: [{ name: "", type: "string" }] },
  { type: "function", name: "ownerOf", stateMutability: "view", inputs: [{ name: "tokenId", type: "uint256" }], outputs: [{ name: "", type: "address" }] },
  { type: "function", name: "balanceOf", stateMutability: "view", inputs: [{ name: "owner", type: "address" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "mint", stateMutability: "nonpayable", inputs: [{ name: "agentId", type: "uint256" }], outputs: [] },
] as const;

export const AGENT_SKILL_NFT_ABI = [
  { type: "function", name: "balanceOf", stateMutability: "view", inputs: [{ name: "account", type: "address" }, { name: "id", type: "uint256" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "uri", stateMutability: "view", inputs: [{ name: "id", type: "uint256" }], outputs: [{ name: "", type: "string" }] },
  { type: "function", name: "getSkillBadge", stateMutability: "view", inputs: [{ name: "agentId", type: "uint256" }, { name: "category", type: "uint256" }], outputs: [{ name: "", type: "tuple", components: [{ name: "agentId", type: "uint256" }, { name: "category", type: "uint256" }, { name: "completions", type: "uint256" }, { name: "tier", type: "uint8" }, { name: "lastUpdatedAt", type: "uint256" }] }] },
] as const;


export const AGENT_WALLET_FACTORY_ABI = [
  {
    "type": "constructor",
    "inputs": [
      { "name": "_entryPoint", "type": "address", "internalType": "address" },
      { "name": "_registry", "type": "address", "internalType": "address" }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "computeWalletAddress",
    "inputs": [
      { "name": "owner", "type": "address", "internalType": "address" },
      { "name": "agentId", "type": "uint256", "internalType": "uint256" },
      { "name": "salt", "type": "bytes32", "internalType": "bytes32" }
    ],
    "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "deployWallet",
    "inputs": [
      { "name": "owner", "type": "address", "internalType": "address" },
      { "name": "agentId", "type": "uint256", "internalType": "uint256" },
      { "name": "salt", "type": "bytes32", "internalType": "bytes32" }
    ],
    "outputs": [{ "name": "wallet", "type": "address", "internalType": "address" }],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "entryPoint",
    "inputs": [],
    "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getWallet",
    "inputs": [{ "name": "owner", "type": "address", "internalType": "address" }],
    "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "hasWallet",
    "inputs": [{ "name": "owner", "type": "address", "internalType": "address" }],
    "outputs": [{ "name": "", "type": "bool", "internalType": "bool" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "registry",
    "inputs": [],
    "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "WalletDeployed",
    "inputs": [
      { "name": "wallet", "type": "address", "indexed": true, "internalType": "address" },
      { "name": "owner", "type": "address", "indexed": true, "internalType": "address" },
      { "name": "agentId", "type": "uint256", "indexed": true, "internalType": "uint256" },
      { "name": "salt", "type": "bytes32", "indexed": false, "internalType": "bytes32" }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "DeploymentFailed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "WalletAlreadyExists",
    "inputs": [{ "name": "owner", "type": "address", "internalType": "address" }]
  },
  {
    "type": "error",
    "name": "ZeroAddress",
    "inputs": []
  }
] as const;

// ================================================================
// TYPES (preserved from original)
// ================================================================

export interface Agent {
  agentId: number;
  owner: string;
  agentWallet: string;
  metadataURI: string;
  category: number;
  status: number;
  reputationScore: number;
  totalTasksCompleted: number;
  totalEarned: bigint;
  registeredAt: number;
  lastActiveAt: number;
  // UI extras (not on-chain)
  name?: string;
  description?: string;
  capabilities?: string[];
  pricePerTask?: string;
}

export interface Task {
  taskId: string;
  client: string;
  metadataURI: string;
  reward: bigint;
  deadline: number;
  createdAt: number;
  status: number;
  assignedAgentId: number;
  minReputation: number;
  // UI extras
  title?: string;
  description?: string;
  category?: string;
}

export interface SubscriptionPlan {
  planId: string;
  agentId: number;
  tier: number;
  pricePerPeriod: bigint;
  periodDuration: number;
  maxSubscribers: number;
  currentSubscribers: number;
  isActive: boolean;
  agentName?: string;
}

// ================================================================
// MOCK DATA (preserved exactly from original)
// ================================================================

export const MOCK_AGENTS: Agent[] = [
  {
    agentId: 1, owner: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    agentWallet: "0x1234567890123456789012345678901234567890",
    metadataURI: "ipfs://QmCodeSentinelMeta", category: 1, status: 1,
    reputationScore: 9200, totalTasksCompleted: 147,
    totalEarned: BigInt("42000000000000000000"),
    registeredAt: 1716000000, lastActiveAt: 1717900000,
    name: "CodeSentinel-v2",
    description: "Advanced smart contract auditor specializing in DeFi protocol security. Expert in reentrancy, flash loan attacks, and MEV vulnerabilities.",
    capabilities: ["solidity-audit", "foundry", "slither", "echidna", "formal-verification"],
    pricePerTask: "0.08",
  },
  {
    agentId: 2, owner: "0x8ba1f109551bD432803012645Ac136ddd64DBA72",
    agentWallet: "0x2345678901234567890123456789012345678901",
    metadataURI: "ipfs://QmResearchOracleMeta", category: 2, status: 1,
    reputationScore: 8750, totalTasksCompleted: 203,
    totalEarned: BigInt("31500000000000000000"),
    registeredAt: 1715500000, lastActiveAt: 1717950000,
    name: "ResearchOracle-1",
    description: "Deep research agent for DeFi market analysis, tokenomics modeling, and protocol comparisons.",
    capabilities: ["market-analysis", "tokenomics", "defi-research", "report-writing", "data-analysis"],
    pricePerTask: "0.05",
  },
  {
    agentId: 3, owner: "0x9D7f74d0C41E726EC95884E0e97Fa6129e3b5E99",
    agentWallet: "0x3456789012345678901234567890123456789012",
    metadataURI: "ipfs://QmAlphaTradeMeta", category: 3, status: 1,
    reputationScore: 8100, totalTasksCompleted: 89,
    totalEarned: BigInt("67200000000000000000"),
    registeredAt: 1716200000, lastActiveAt: 1717800000,
    name: "AlphaTrader-Pro",
    description: "Quantitative trading strategy agent. Specializes in on-chain arbitrage detection and DeFi yield optimization.",
    capabilities: ["arbitrage", "yield-farming", "dex-analysis", "on-chain-data", "strategy-backtesting"],
    pricePerTask: "0.12",
  },
  {
    agentId: 4, owner: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    agentWallet: "0x4567890123456789012345678901234567890123",
    metadataURI: "ipfs://QmNexusOrchestratorMeta", category: 5, status: 1,
    reputationScore: 9500, totalTasksCompleted: 312,
    totalEarned: BigInt("145000000000000000000"),
    registeredAt: 1714000000, lastActiveAt: 1717980000,
    name: "NexusOrchestrator-α",
    description: "Master orchestration agent that breaks complex tasks into sub-tasks, delegates to specialized agents, and coordinates deliverables.",
    capabilities: ["task-decomposition", "agent-hiring", "project-management", "quality-assurance", "multi-agent"],
    pricePerTask: "0.20",
  },
  {
    agentId: 5, owner: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    agentWallet: "0x5678901234567890123456789012345678901234",
    metadataURI: "ipfs://QmCreativeCoreMeta", category: 4, status: 1,
    reputationScore: 7800, totalTasksCompleted: 91,
    totalEarned: BigInt("22300000000000000000"),
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
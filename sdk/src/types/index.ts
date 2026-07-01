import type { Address, Hash, Hex } from "viem";

// ── Chain config ───────────────────────────────────────────────

export interface NexusConfig {
  /** RPC URL (public or Infura/Alchemy) */
  rpcUrl: string;
  /** Chain ID — 11155111 for Sepolia */
  chainId: number;
  /** Deployed contract addresses */
  contracts: NexusContracts;
  /** Optional: private key for write operations */
  privateKey?: Hex;
}

export interface NexusContracts {
  AgentRegistry:       Address;
  AgentWalletFactory:  Address;
  ReputationOracle:    Address;
  AgentMemory:         Address;
  TaskMarketplace:     Address;
  ZKVerifier:          Address;
  SubscriptionManager: Address;
  CrossChainBridge:    Address;
  Groth16Verifier:     Address;
  NexusServiceManager: Address;
  AgentStaking:        Address;
  AgentIdentityNFT:    Address;
  AgentSkillNFT:       Address;
  AgentComposability:  Address;
  ZKEscrow:            Address;
}

// ── Agent types ────────────────────────────────────────────────

export type AgentCategory =
  | "GENERAL"
  | "CODE"
  | "RESEARCH"
  | "TRADING"
  | "CREATIVE"
  | "ORCHESTRATOR";

export type AgentStatus =
  | "INACTIVE"
  | "ACTIVE"
  | "BUSY"
  | "SUSPENDED"
  | "RETIRED";

export interface AgentProfile {
  agentId:             bigint;
  owner:               Address;
  agentWallet:         Address;
  metadataURI:         string;
  category:            AgentCategory;
  status:              AgentStatus;
  reputationScore:     bigint;
  totalTasksCompleted: bigint;
  totalEarned:         bigint;
  registeredAt:        bigint;
  lastActiveAt:        bigint;
}

export interface RegisterAgentParams {
  metadataURI: string;
  category:    AgentCategory;
}

// ── Task types ─────────────────────────────────────────────────

export type TaskStatus =
  | "OPEN"
  | "ASSIGNED"
  | "SUBMITTED"
  | "COMPLETED"
  | "CANCELLED"
  | "DISPUTED"
  | "RESOLVED";

export interface Task {
  taskId:               Hash;
  client:               Address;
  clientAgentId:        bigint;
  metadataURI:          string;
  reward:               bigint;
  deadline:             bigint;
  createdAt:            bigint;
  assignedAt:           bigint;
  submittedAt:          bigint;
  completedAt:          bigint;
  status:               TaskStatus;
  assignedAgentId:      bigint;
  assignedAgentWallet:  Address;
  platformFee:          bigint;
  requiresMinReputation: boolean;
  minReputation:        bigint;
}

export interface PostTaskParams {
  metadataURI:    string;
  deadline:       bigint;
  minReputation?: bigint;
  reward:         bigint; // in wei
}

export interface Bid {
  taskId:         Hash;
  agentId:        bigint;
  agentWallet:    Address;
  proposedReward: bigint;
  proposalURI:    string;
  estimatedTime:  bigint;
  submittedAt:    bigint;
  isAccepted:     boolean;
  isWithdrawn:    boolean;
}

export interface SubmitBidParams {
  taskId:        Hash;
  agentId:       bigint;
  proposalURI:   string;
  estimatedTime: bigint;
}

// ── Reputation types ───────────────────────────────────────────

export interface ReputationState {
  agentId:          bigint;
  score:            bigint;
  totalUpdates:     bigint;
  isSlashed:        boolean;
  lastUpdatedAt:    bigint;
}

// ── Staking types ──────────────────────────────────────────────

export interface StakeInfo {
  agentId:             bigint;
  totalStaked:         bigint;
  ownStake:            bigint;
  delegatedStake:      bigint;
  lockedStake:         bigint;
  slashCount:          bigint;
  totalSlashed:        bigint;
  lastStakedAt:        bigint;
  unstakeRequestedAt:  bigint;
  unstakeAmount:       bigint;
}

// ── Sub-task types ─────────────────────────────────────────────

export type SubTaskStatus =
  | "OPEN"
  | "ASSIGNED"
  | "SUBMITTED"
  | "COMPLETED"
  | "CANCELLED"
  | "DISPUTED";

export interface SubTask {
  subTaskId:     Hash;
  parentTaskId:  Hash;
  parentAgentId: bigint;
  subAgentId:    bigint;
  metadataURI:   string;
  reward:        bigint;
  splitBps:      bigint;
  deadline:      bigint;
  createdAt:     bigint;
  completedAt:   bigint;
  status:        SubTaskStatus;
  resultURI:     string;
}

export interface CreateSubTaskParams {
  parentTaskId: Hash;
  parentAgentId: bigint;
  metadataURI:  string;
  deadline:     bigint;
  splitBps:     bigint;
  reward:       bigint;
}

// ── ZK Escrow types ────────────────────────────────────────────

export type EscrowStatus = "OPEN" | "RELEASED" | "REFUNDED" | "DISPUTED";

export interface Escrow {
  escrowId:    Hash;
  taskId:      Hash;
  client:      Address;
  agentWallet: Address;
  amount:      bigint;
  commitment:  Hash;
  deadline:    bigint;
  createdAt:   bigint;
  releasedAt:  bigint;
  status:      EscrowStatus;
  proofId:     Hash;
}

export interface Groth16Proof {
  pA: [bigint, bigint];
  pB: [[bigint, bigint], [bigint, bigint]];
  pC: [bigint, bigint];
  pubSignals: [bigint, bigint];
}

// ── NFT types ──────────────────────────────────────────────────

export type SkillTier =
  | "NONE"
  | "BRONZE"
  | "SILVER"
  | "GOLD"
  | "PLATINUM"
  | "DIAMOND";

export interface SkillBadge {
  agentId:       bigint;
  category:      bigint;
  completions:   bigint;
  tier:          SkillTier;
  lastUpdatedAt: bigint;
}

// ── Event types ────────────────────────────────────────────────

export interface NexusEvent {
  type:      string;
  blockNumber: bigint;
  txHash:    Hash;
  data:      Record<string, unknown>;
}

// ── SDK return types ───────────────────────────────────────────

export interface TxResult {
  hash:        Hash;
  blockNumber: bigint;
  gasUsed:     bigint;
}

export interface ReadResult<T> {
  data:    T;
  cached?: boolean;
}
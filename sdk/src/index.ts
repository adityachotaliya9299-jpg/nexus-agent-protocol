export { NexusClient } from "./client/NexusClient";

// Types
export type {
  NexusConfig,
  NexusContracts,
  AgentProfile,
  AgentCategory,
  AgentStatus,
  Task,
  TaskStatus,
  Bid,
  StakeInfo,
  SubTask,
  SubTaskStatus,
  Escrow,
  EscrowStatus,
  Groth16Proof,
  SkillBadge,
  SkillTier,
  TxResult,
  PostTaskParams,
  SubmitBidParams,
  CreateSubTaskParams,
} from "./types";

// Constants
export {
  NEXUS_SEPOLIA_CONTRACTS,
  SEPOLIA_CHAIN_ID,
  AGENT_REGISTRY_ABI,
  TASK_MARKETPLACE_ABI,
  REPUTATION_ORACLE_ABI,
  AGENT_STAKING_ABI,
  ZK_ESCROW_ABI,
  AGENT_COMPOSABILITY_ABI,
  AGENT_CATEGORY_TO_UINT,
  UINT_TO_AGENT_CATEGORY,
  UINT_TO_TASK_STATUS,
  UINT_TO_ESCROW_STATUS,
  UINT_TO_SKILL_TIER,
} from "./utils/constants";

// Version
export const SDK_VERSION = "0.1.0";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
  type PublicClient,
  type WalletClient,
  type Address,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { sepolia } from "viem/chains";
import { logger } from "../utils/logger";
import type { RuntimeConfig } from "../utils/config";

const REGISTRY_ABI = [
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
    name: "isRegistered",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    name: "getAgentIdByOwner",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

const STAKING_ABI = [
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
] as const;

const CATEGORY_MAP: Record<string, number> = {
  GENERAL: 0, CODE: 1, RESEARCH: 2,
  TRADING: 3, CREATIVE: 4, ORCHESTRATOR: 5,
};

export interface AgentState {
  agentId:        bigint;
  owner:          Address;
  reputationScore: bigint;
  totalCompleted: bigint;
  totalEarned:    bigint;
  stakedAmount:   bigint;
}

export class AgentIdentity {
  private pub:  PublicClient;
  private wal:  WalletClient;
  private cfg:  RuntimeConfig;
  public  state: AgentState | null = null;

  constructor(cfg: RuntimeConfig) {
    this.cfg = cfg;
    const account = privateKeyToAccount(cfg.privateKey);

    this.pub = createPublicClient({
      chain:     sepolia,
      transport: http(cfg.rpcUrl),
    });

    this.wal = createWalletClient({
      account,
      chain:     sepolia,
      transport: http(cfg.rpcUrl),
    });
  }

  get address(): Address {
    return this.wal.account!.address;
  }

  get publicClient(): PublicClient {
    return this.pub;
  }

  get walletClient(): WalletClient {
    return this.wal;
  }

  // ── Bootstrap ────────────────────────────────────────────────

  async bootstrap(): Promise<AgentState> {
    logger.info("AgentIdentity", `Bootstrapping agent for ${this.address}`);

    const isRegistered = await this.pub.readContract({
      address:      this.cfg.contracts.AgentRegistry,
      abi:          REGISTRY_ABI,
      functionName: "isRegistered",
      args:         [this.address],
    }) as boolean;

    if (!isRegistered) {
      logger.action("AgentIdentity", "Not registered — registering now...");
      await this._register();
    } else {
      logger.info("AgentIdentity", "Already registered ✓");
    }

    const agentId = await this.pub.readContract({
      address:      this.cfg.contracts.AgentRegistry,
      abi:          REGISTRY_ABI,
      functionName: "getAgentIdByOwner",
      args:         [this.address],
    }) as bigint;

    const profile = await this.pub.readContract({
      address:      this.cfg.contracts.AgentRegistry,
      abi:          REGISTRY_ABI,
      functionName: "getAgentByOwner",
      args:         [this.address],
    }) as any;

    // Optionally stake on startup
    if (
      this.cfg.stakeAmountEth !== "0" &&
      parseFloat(this.cfg.stakeAmountEth) > 0
    ) {
      await this._ensureStake(agentId);
    }

    const stakeInfo = await this.pub.readContract({
      address:      this.cfg.contracts.AgentStaking,
      abi:          STAKING_ABI,
      functionName: "getStake",
      args:         [agentId],
    }) as any;

    this.state = {
      agentId,
      owner:           this.address,
      reputationScore: profile.reputationScore,
      totalCompleted:  profile.totalTasksCompleted,
      totalEarned:     profile.totalEarned,
      stakedAmount:    stakeInfo.totalStaked,
    };

    logger.info("AgentIdentity", `Agent ready`, {
      agentId:    agentId.toString(),
      reputation: profile.reputationScore.toString(),
      staked:     stakeInfo.totalStaked.toString(),
    });

    return this.state;
  }

  async refresh(): Promise<void> {
    if (!this.state) return;
    const profile = await this.pub.readContract({
      address:      this.cfg.contracts.AgentRegistry,
      abi:          REGISTRY_ABI,
      functionName: "getAgentByOwner",
      args:         [this.address],
    }) as any;

    this.state.reputationScore = profile.reputationScore;
    this.state.totalCompleted  = profile.totalTasksCompleted;
    this.state.totalEarned     = profile.totalEarned;
  }

  // ── Private ──────────────────────────────────────────────────

  private async _register(): Promise<void> {
    const categoryUint = CATEGORY_MAP[this.cfg.agentCategory] ?? 0;
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.AgentRegistry,
      abi:          REGISTRY_ABI,
      functionName: "registerAgent",
      args:         [this.cfg.agentMetadataURI, categoryUint],
      account:      this.wal.account!,
      chain:        sepolia,
    });

    logger.chain("AgentIdentity", `Registration TX: ${hash}`);
    await this.pub.waitForTransactionReceipt({ hash });
    logger.action("AgentIdentity", "Registered ✓");
  }

  private async _ensureStake(agentId: bigint): Promise<void> {
    const stakeInfo = await this.pub.readContract({
      address:      this.cfg.contracts.AgentStaking,
      abi:          STAKING_ABI,
      functionName: "getStake",
      args:         [agentId],
    }) as any;

    if (stakeInfo.totalStaked > 0n) {
      logger.info("AgentIdentity", `Already staked: ${stakeInfo.totalStaked.toString()} wei`);
      return;
    }

    logger.action("AgentIdentity", `Staking ${this.cfg.stakeAmountEth} ETH...`);
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.AgentStaking,
      abi:          STAKING_ABI,
      functionName: "stake",
      args:         [agentId],
      value:        parseEther(this.cfg.stakeAmountEth),
      account:      this.wal.account!,
      chain:        sepolia,
    });

    logger.chain("AgentIdentity", `Stake TX: ${hash}`);
    await this.pub.waitForTransactionReceipt({ hash });
    logger.action("AgentIdentity", "Staked ✓");
  }
}
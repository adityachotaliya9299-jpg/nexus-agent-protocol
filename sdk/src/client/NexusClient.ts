import {
  createPublicClient,
  createWalletClient,
  http,
  keccak256,
  encodePacked,
  parseEther,
  type PublicClient,
  type WalletClient,
  type Chain,
  type Hash,
  type Address,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { sepolia } from "viem/chains";

import type {
  NexusConfig,
  AgentProfile,
  AgentCategory,
  Task,
  Bid,
  StakeInfo,
  SubTask,
  Escrow,
  Groth16Proof,
  TxResult,
  PostTaskParams,
  SubmitBidParams,
  CreateSubTaskParams,
} from "../types";

import {
  NEXUS_SEPOLIA_CONTRACTS,
  AGENT_REGISTRY_ABI,
  TASK_MARKETPLACE_ABI,
  REPUTATION_ORACLE_ABI,
  AGENT_STAKING_ABI,
  ZK_ESCROW_ABI,
  AGENT_COMPOSABILITY_ABI,
  AGENT_CATEGORY_TO_UINT,
  UINT_TO_AGENT_CATEGORY,
  UINT_TO_AGENT_STATUS,
  UINT_TO_TASK_STATUS,
  UINT_TO_ESCROW_STATUS,
} from "../utils/constants";

/// @title NexusClient
/// @notice Main SDK entry point for interacting with Nexus Agent Protocol.
/// @author Aditya Chotaliya <adityachotaliya.xyz>
///
/// Usage:
///   // Read-only
///   const nexus = NexusClient.readOnly({ rpcUrl: "https://..." });
///
///   // With signer
///   const nexus = NexusClient.withPrivateKey({
///     rpcUrl: "https://...",
///     privateKey: "0x..."
///   });
///
///   // Register an agent
///   const { hash } = await nexus.agents.register({
///     metadataURI: "ipfs://Qm...",
///     category: "CODE",
///   });
///
///   // Post a task
///   const { taskId } = await nexus.tasks.post({
///     metadataURI: "ipfs://Qm...",
///     deadline: BigInt(Date.now() / 1000) + 86400n,
///     reward: parseEther("0.1"),
///   });
export class NexusClient {
  private publicClient: PublicClient;
  private walletClient: WalletClient | null;
  private config: NexusConfig;

  // Sub-clients
  public agents:        AgentClient;
  public tasks:         TaskClient;
  public reputation:    ReputationClient;
  public staking:       StakingClient;
  public composability: ComposabilityClient;
  public zkescrow:      ZKEscrowClient;

  constructor(config: NexusConfig) {
    this.config = {
      ...config,
      contracts: config.contracts ?? NEXUS_SEPOLIA_CONTRACTS,
    };

    const chain = this._getChain(config.chainId ?? 11155111);

    this.publicClient = createPublicClient({
      chain,
      transport: http(config.rpcUrl),
    });

    this.walletClient = config.privateKey
      ? createWalletClient({
          account: privateKeyToAccount(config.privateKey),
          chain,
          transport: http(config.rpcUrl),
        })
      : null;

    // Init sub-clients
    this.agents        = new AgentClient(this.publicClient, this.walletClient, this.config);
    this.tasks         = new TaskClient(this.publicClient, this.walletClient, this.config);
    this.reputation    = new ReputationClient(this.publicClient, this.config);
    this.staking       = new StakingClient(this.publicClient, this.walletClient, this.config);
    this.composability = new ComposabilityClient(this.publicClient, this.walletClient, this.config);
    this.zkescrow      = new ZKEscrowClient(this.publicClient, this.walletClient, this.config);
  }

  // ── Factory methods ──────────────────────────────────────────

  static readOnly(opts: { rpcUrl: string; chainId?: number }): NexusClient {
    return new NexusClient({
      rpcUrl:    opts.rpcUrl,
      chainId:   opts.chainId ?? 11155111,
      contracts: NEXUS_SEPOLIA_CONTRACTS,
    });
  }

  static withPrivateKey(opts: {
    rpcUrl:     string;
    privateKey: `0x${string}`;
    chainId?:   number;
  }): NexusClient {
    return new NexusClient({
      rpcUrl:     opts.rpcUrl,
      chainId:    opts.chainId ?? 11155111,
      privateKey: opts.privateKey,
      contracts:  NEXUS_SEPOLIA_CONTRACTS,
    });
  }

  // ── Helpers ──────────────────────────────────────────────────

  private _getChain(chainId: number): Chain {
    if (chainId === 11155111) return sepolia;
    throw new Error(`Unsupported chain ID: ${chainId}. Currently only Sepolia (11155111) is supported.`);
  }

  getAddress(): Address | null {
    return this.walletClient?.account?.address ?? null;
  }

  get contracts() {
    return this.config.contracts;
  }
}

// ── AgentClient ────────────────────────────────────────────────

class AgentClient {
  constructor(
    private pub: PublicClient,
    private wal: WalletClient | null,
    private cfg: NexusConfig,
  ) {}

  async register(params: { metadataURI: string; category: AgentCategory }): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");

    const categoryUint = AGENT_CATEGORY_TO_UINT[params.category];
    const hash = await this.wal.writeContract({
      address: this.cfg.contracts.AgentRegistry,
      abi:     AGENT_REGISTRY_ABI,
      functionName: "registerAgent",
      args: [params.metadataURI, categoryUint],
      account: this.wal.account!,
      chain:   this.wal.chain!,
    });

    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return {
      hash,
      blockNumber: receipt.blockNumber,
      gasUsed:     receipt.gasUsed,
    };
  }

  async get(agentId: bigint): Promise<AgentProfile> {
    const raw = await this.pub.readContract({
      address:      this.cfg.contracts.AgentRegistry,
      abi:          AGENT_REGISTRY_ABI,
      functionName: "getAgent",
      args:         [agentId],
    }) as any;
    return this._parse(raw);
  }

  async getByOwner(owner: Address): Promise<AgentProfile> {
    const raw = await this.pub.readContract({
      address:      this.cfg.contracts.AgentRegistry,
      abi:          AGENT_REGISTRY_ABI,
      functionName: "getAgentByOwner",
      args:         [owner],
    }) as any;
    return this._parse(raw);
  }

  async getIdByOwner(owner: Address): Promise<bigint> {
    return await this.pub.readContract({
      address:      this.cfg.contracts.AgentRegistry,
      abi:          AGENT_REGISTRY_ABI,
      functionName: "getAgentIdByOwner",
      args:         [owner],
    }) as bigint;
  }

  async isRegistered(owner: Address): Promise<boolean> {
    return await this.pub.readContract({
      address:      this.cfg.contracts.AgentRegistry,
      abi:          AGENT_REGISTRY_ABI,
      functionName: "isRegistered",
      args:         [owner],
    }) as boolean;
  }

  async totalAgents(): Promise<bigint> {
    return await this.pub.readContract({
      address:      this.cfg.contracts.AgentRegistry,
      abi:          AGENT_REGISTRY_ABI,
      functionName: "totalAgents",
      args:         [],
    }) as bigint;
  }

  async setWallet(agentId: bigint, wallet: Address): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.AgentRegistry,
      abi:          AGENT_REGISTRY_ABI,
      functionName: "setAgentWallet",
      args:         [agentId, wallet],
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }

  private _parse(raw: any): AgentProfile {
    return {
      agentId:             raw.agentId,
      owner:               raw.owner,
      agentWallet:         raw.agentWallet,
      metadataURI:         raw.metadataURI,
      category:            UINT_TO_AGENT_CATEGORY[Number(raw.category)] as AgentCategory,
      status:              UINT_TO_AGENT_STATUS[Number(raw.status)] as any,
      reputationScore:     raw.reputationScore,
      totalTasksCompleted: raw.totalTasksCompleted,
      totalEarned:         raw.totalEarned,
      registeredAt:        raw.registeredAt,
      lastActiveAt:        raw.lastActiveAt,
    };
  }
}

// ── TaskClient ─────────────────────────────────────────────────

class TaskClient {
  constructor(
    private pub: PublicClient,
    private wal: WalletClient | null,
    private cfg: NexusConfig,
  ) {}

  async post(params: PostTaskParams): Promise<{ hash: Hash; taskId?: Hash }> {
    if (!this.wal) throw new Error("No signer configured");

    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.TaskMarketplace,
      abi:          TASK_MARKETPLACE_ABI,
      functionName: "postTask",
      args:         [params.metadataURI, params.deadline, params.minReputation ?? 0n],
      value:        params.reward,
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });

    const receipt = await this.pub.waitForTransactionReceipt({ hash });

    const log = receipt.logs.find(l =>
      l.topics[0] === "0x" // TaskPosted topic hash
    );

    return { hash };
  }

  async get(taskId: Hash): Promise<Task> {
    const raw = await this.pub.readContract({
      address:      this.cfg.contracts.TaskMarketplace,
      abi:          TASK_MARKETPLACE_ABI,
      functionName: "getTask",
      args:         [taskId],
    }) as any;
    return this._parse(raw);
  }

  async submitBid(params: SubmitBidParams): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.TaskMarketplace,
      abi:          TASK_MARKETPLACE_ABI,
      functionName: "submitBid",
      args:         [params.taskId, params.agentId, params.proposalURI, params.estimatedTime],
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }

  async assignAgent(taskId: Hash, agentId: bigint): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.TaskMarketplace,
      abi:          TASK_MARKETPLACE_ABI,
      functionName: "assignAgent",
      args:         [taskId, agentId],
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }

  async submitWork(taskId: Hash, agentId: bigint, resultURI: string): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.TaskMarketplace,
      abi:          TASK_MARKETPLACE_ABI,
      functionName: "submitWork",
      args:         [taskId, agentId, resultURI],
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }

  async approveWork(taskId: Hash): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.TaskMarketplace,
      abi:          TASK_MARKETPLACE_ABI,
      functionName: "approveWork",
      args:         [taskId],
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }

  async getClientTasks(client: Address): Promise<Hash[]> {
    return await this.pub.readContract({
      address:      this.cfg.contracts.TaskMarketplace,
      abi:          TASK_MARKETPLACE_ABI,
      functionName: "getClientTasks",
      args:         [client],
    }) as Hash[];
  }

  async getAgentTasks(agentId: bigint): Promise<Hash[]> {
    return await this.pub.readContract({
      address:      this.cfg.contracts.TaskMarketplace,
      abi:          TASK_MARKETPLACE_ABI,
      functionName: "getAgentTasks",
      args:         [agentId],
    }) as Hash[];
  }

  async totalPosted(): Promise<bigint> {
    return await this.pub.readContract({
      address: this.cfg.contracts.TaskMarketplace,
      abi: TASK_MARKETPLACE_ABI,
      functionName: "totalTasksPosted",
      args: [],
    }) as bigint;
  }

  private _parse(raw: any): Task {
    return {
      taskId:               raw.taskId,
      client:               raw.client,
      clientAgentId:        raw.clientAgentId,
      metadataURI:          raw.metadataURI,
      reward:               raw.reward,
      deadline:             raw.deadline,
      createdAt:            raw.createdAt,
      assignedAt:           raw.assignedAt,
      submittedAt:          raw.submittedAt,
      completedAt:          raw.completedAt,
      status:               UINT_TO_TASK_STATUS[Number(raw.status)] as any,
      assignedAgentId:      raw.assignedAgentId,
      assignedAgentWallet:  raw.assignedAgentWallet,
      platformFee:          raw.platformFee,
      requiresMinReputation: raw.requiresMinReputation,
      minReputation:        raw.minReputation,
    };
  }
}

// ── ReputationClient ───────────────────────────────────────────

class ReputationClient {
  constructor(private pub: PublicClient, private cfg: NexusConfig) {}

  async getScore(agentId: bigint): Promise<bigint> {
    return await this.pub.readContract({
      address:      this.cfg.contracts.ReputationOracle,
      abi:          REPUTATION_ORACLE_ABI,
      functionName: "getScore",
      args:         [agentId],
    }) as bigint;
  }

  async getTier(agentId: bigint): Promise<string> {
    const score = await this.getScore(agentId);
    const n = Number(score);
    if (n >= 10000) return "ELITE";
    if (n >= 8000)  return "EXPERT";
    if (n >= 6000)  return "ADVANCED";
    if (n >= 4000)  return "ESTABLISHED";
    if (n >= 2000)  return "RISING";
    return "NOVICE";
  }
}

// ── StakingClient ──────────────────────────────────────────────

class StakingClient {
  constructor(
    private pub: PublicClient,
    private wal: WalletClient | null,
    private cfg: NexusConfig,
  ) {}

  async stake(agentId: bigint, amountEth: string): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.AgentStaking,
      abi:          AGENT_STAKING_ABI,
      functionName: "stake",
      args:         [agentId],
      value:        parseEther(amountEth),
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }

  async getStake(agentId: bigint): Promise<StakeInfo> {
    const raw = await this.pub.readContract({
      address:      this.cfg.contracts.AgentStaking,
      abi:          AGENT_STAKING_ABI,
      functionName: "getStake",
      args:         [agentId],
    }) as any;
    return raw as StakeInfo;
  }

  async getEffectiveStake(agentId: bigint): Promise<bigint> {
    return await this.pub.readContract({
      address:      this.cfg.contracts.AgentStaking,
      abi:          AGENT_STAKING_ABI,
      functionName: "getEffectiveStake",
      args:         [agentId],
    }) as bigint;
  }

  async isEligibleToBid(agentId: bigint, taskMinStake: bigint): Promise<boolean> {
    return await this.pub.readContract({
      address:      this.cfg.contracts.AgentStaking,
      abi:          AGENT_STAKING_ABI,
      functionName: "isEligibleToBid",
      args:         [agentId, taskMinStake],
    }) as boolean;
  }

  async requestUnstake(agentId: bigint, amount: bigint): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.AgentStaking,
      abi:          AGENT_STAKING_ABI,
      functionName: "requestUnstake",
      args:         [agentId, amount],
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }
}

// ── ComposabilityClient ────────────────────────────────────────

class ComposabilityClient {
  constructor(
    private pub: PublicClient,
    private wal: WalletClient | null,
    private cfg: NexusConfig,
  ) {}

  async createSubTask(params: CreateSubTaskParams): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.AgentComposability,
      abi:          AGENT_COMPOSABILITY_ABI,
      functionName: "createSubTask",
      args:         [params.parentTaskId, params.parentAgentId, params.metadataURI, params.deadline, params.splitBps],
      value:        params.reward,
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }

  async assignSubAgent(subTaskId: Hash, subAgentId: bigint): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.AgentComposability,
      abi:          AGENT_COMPOSABILITY_ABI,
      functionName: "assignSubAgent",
      args:         [subTaskId, subAgentId],
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }

  async getSubTask(subTaskId: Hash): Promise<SubTask> {
    const raw = await this.pub.readContract({
      address:      this.cfg.contracts.AgentComposability,
      abi:          AGENT_COMPOSABILITY_ABI,
      functionName: "getSubTask",
      args:         [subTaskId],
    }) as any;
    return raw as SubTask;
  }

  async getRelationship(parentId: bigint, subId: bigint) {
    return await this.pub.readContract({
      address:      this.cfg.contracts.AgentComposability,
      abi:          AGENT_COMPOSABILITY_ABI,
      functionName: "getAgentRelationship",
      args:         [parentId, subId],
    });
  }
}

// ── ZKEscrowClient ─────────────────────────────────────────────

class ZKEscrowClient {
  constructor(
    private pub: PublicClient,
    private wal: WalletClient | null,
    private cfg: NexusConfig,
  ) {}

  async create(params: {
    taskId:      Hash;
    agentWallet: Address;
    deadline:    bigint;
    reward:      bigint;
  }): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.ZKEscrow,
      abi:          ZK_ESCROW_ABI,
      functionName: "createEscrow",
      args:         [params.taskId, params.agentWallet, params.deadline],
      value:        params.reward,
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }

  /// @notice Compute the commitment hash from resultHash + salt
  computeCommitment(resultHash: Hash, salt: Hash): Hash {
    return keccak256(encodePacked(["bytes32", "bytes32"], [resultHash, salt]));
  }

  async setCommitment(escrowId: Hash, commitment: Hash): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.ZKEscrow,
      abi:          ZK_ESCROW_ABI,
      functionName: "setCommitment",
      args:         [escrowId, commitment],
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }

  async releaseWithProof(escrowId: Hash, resultHash: Hash, salt: Hash, proof: Groth16Proof): Promise<TxResult> {
    if (!this.wal) throw new Error("No signer configured");
    const hash = await this.wal.writeContract({
      address:      this.cfg.contracts.ZKEscrow,
      abi:          ZK_ESCROW_ABI,
      functionName: "releaseWithProof",
      args:         [escrowId, resultHash, salt, proof.pA, proof.pB, proof.pC, proof.pubSignals],
      account:      this.wal.account!,
      chain:        this.wal.chain!,
    });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    return { hash, blockNumber: receipt.blockNumber, gasUsed: receipt.gasUsed };
  }

  async get(escrowId: Hash): Promise<Escrow> {
    const raw = await this.pub.readContract({
      address:      this.cfg.contracts.ZKEscrow,
      abi:          ZK_ESCROW_ABI,
      functionName: "getEscrow",
      args:         [escrowId],
    }) as any;
    return {
      ...raw,
      status: UINT_TO_ESCROW_STATUS[Number(raw.status)] as any,
    };
  }
}
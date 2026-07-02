import { type Hash, type WalletClient, type PublicClient } from "viem";
import { sepolia } from "viem/chains";
import { logger } from "../utils/logger";
import type { RuntimeConfig } from "../utils/config";
import type { AgentState } from "../agent/AgentIdentity";
import type { OpenTask } from "../tasks/TaskScanner";

const MARKETPLACE_ABI = [
  {
    name: "submitBid",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "taskId",        type: "bytes32" },
      { name: "agentId",       type: "uint256" },
      { name: "proposalURI",   type: "string"  },
      { name: "estimatedTime", type: "uint256" },
    ],
    outputs: [],
  },
  {
    name: "submitWork",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "taskId",    type: "bytes32" },
      { name: "agentId",   type: "uint256" },
      { name: "resultURI", type: "string"  },
    ],
    outputs: [],
  },
  {
    name: "getAgentTasks",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "agentId", type: "uint256" }],
    outputs: [{ name: "", type: "bytes32[]" }],
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
          { name: "taskId",              type: "bytes32" },
          { name: "client",              type: "address" },
          { name: "clientAgentId",       type: "uint256" },
          { name: "metadataURI",         type: "string"  },
          { name: "reward",              type: "uint256" },
          { name: "deadline",            type: "uint256" },
          { name: "createdAt",           type: "uint256" },
          { name: "assignedAt",          type: "uint256" },
          { name: "submittedAt",         type: "uint256" },
          { name: "completedAt",         type: "uint256" },
          { name: "status",              type: "uint8"   },
          { name: "assignedAgentId",     type: "uint256" },
          { name: "assignedAgentWallet", type: "address" },
          { name: "platformFee",         type: "uint256" },
          { name: "requiresMinReputation", type: "bool"  },
          { name: "minReputation",       type: "uint256" },
        ],
      },
    ],
  },
] as const;

// Task status enum
const STATUS = { OPEN: 0, ASSIGNED: 1, SUBMITTED: 2, COMPLETED: 3 };

export class ChainWatcher {
  private pub:          PublicClient;
  private wal:          WalletClient;
  private cfg:          RuntimeConfig;
  private agentState:   AgentState;
  private pendingBids:  Set<string> = new Set(); // taskIds we've bid on
  private assignedTasks: Map<string, boolean> = new Map(); // taskId → submitted?

  constructor(
    pub:        PublicClient,
    wal:        WalletClient,
    cfg:        RuntimeConfig,
    agentState: AgentState,
  ) {
    this.pub        = pub;
    this.wal        = wal;
    this.cfg        = cfg;
    this.agentState = agentState;
  }

  // ── Submit a bid ─────────────────────────────────────────────

  async submitBid(
    task:          OpenTask,
    proposalURI:   string,
    estimatedHours: number,
  ): Promise<boolean> {
    if (this.pendingBids.size >= this.cfg.maxActiveBids) {
      logger.warn("ChainWatcher", `Max active bids (${this.cfg.maxActiveBids}) reached, skipping`);
      return false;
    }

    if (this.pendingBids.has(task.taskId)) {
      logger.debug("ChainWatcher", `Already bid on ${task.taskId.slice(0, 10)}...`);
      return false;
    }

    try {
      logger.action("ChainWatcher", `Submitting bid on ${task.taskId.slice(0, 18)}...`);

      const hash = await this.wal.writeContract({
        address:      this.cfg.contracts.TaskMarketplace,
        abi:          MARKETPLACE_ABI,
        functionName: "submitBid",
        args:         [
          task.taskId,
          this.agentState.agentId,
          proposalURI,
          BigInt(estimatedHours * 3600),
        ],
        account: this.wal.account!,
        chain:   sepolia,
      });

      logger.chain("ChainWatcher", `Bid TX: ${hash}`);
      await this.pub.waitForTransactionReceipt({ hash });

      this.pendingBids.add(task.taskId);
      logger.action("ChainWatcher", `Bid accepted ✓ on ${task.taskId.slice(0, 10)}...`);
      return true;
    } catch (err) {
      const msg = (err as Error).message;
      // Ignore "already bid" errors
      if (msg.includes("BidAlreadyExists")) {
        this.pendingBids.add(task.taskId);
        return false;
      }
      logger.error("ChainWatcher", `Bid failed: ${msg}`);
      return false;
    }
  }

  // ── Check assigned tasks and submit work ─────────────────────

  async checkAndSubmitWork(generateResult: (task: OpenTask) => Promise<string>): Promise<void> {
    try {
      const taskIds = await this.pub.readContract({
        address:      this.cfg.contracts.TaskMarketplace,
        abi:          MARKETPLACE_ABI,
        functionName: "getAgentTasks",
        args:         [this.agentState.agentId],
      }) as Hash[];

      for (const taskId of taskIds) {
        if (this.assignedTasks.get(taskId)) continue; // already submitted

        const task = await this.pub.readContract({
          address:      this.cfg.contracts.TaskMarketplace,
          abi:          MARKETPLACE_ABI,
          functionName: "getTask",
          args:         [taskId],
        }) as any;

        if (Number(task.status) !== STATUS.ASSIGNED) continue;
        if (task.assignedAgentId !== this.agentState.agentId) continue;

        logger.action("ChainWatcher", `Task assigned! Generating result for ${taskId.slice(0, 10)}...`);

        const openTask: OpenTask = {
          taskId,
          client:        task.client,
          metadataURI:   task.metadataURI,
          reward:        task.reward,
          deadline:      task.deadline,
          minReputation: task.minReputation,
        };

        const resultURI = await generateResult(openTask);

        try {
          const hash = await this.wal.writeContract({
            address:      this.cfg.contracts.TaskMarketplace,
            abi:          MARKETPLACE_ABI,
            functionName: "submitWork",
            args:         [taskId, this.agentState.agentId, resultURI],
            account:      this.wal.account!,
            chain:        sepolia,
          });

          logger.chain("ChainWatcher", `Submit work TX: ${hash}`);
          await this.pub.waitForTransactionReceipt({ hash });
          this.assignedTasks.set(taskId, true);
          logger.action("ChainWatcher", `Work submitted ✓ for ${taskId.slice(0, 10)}...`);
        } catch (err) {
          logger.error("ChainWatcher", `Submit work failed: ${(err as Error).message}`);
        }
      }
    } catch (err) {
      logger.error("ChainWatcher", `Check assigned tasks failed: ${(err as Error).message}`);
    }
  }

  get activeBidCount(): number {
    return this.pendingBids.size;
  }

  removeBid(taskId: string): void {
    this.pendingBids.delete(taskId);
  }
}
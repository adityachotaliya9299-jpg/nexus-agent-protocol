import { type PublicClient, parseEther, type Hash } from "viem";
import { logger } from "../utils/logger";
import type { RuntimeConfig } from "../utils/config";

const MARKETPLACE_ABI = [
  {
    name: "totalTasksPosted",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "getClientTasks",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "client", type: "address" }],
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
    name: "TaskPosted",
    type: "event",
    inputs: [
      { name: "taskId",     type: "bytes32",  indexed: true },
      { name: "client",     type: "address",  indexed: true },
      { name: "reward",     type: "uint256",  indexed: false },
      { name: "deadline",   type: "uint256",  indexed: false },
      { name: "metadataURI",type: "string",   indexed: false },
    ],
  },
] as const;

export interface OpenTask {
  taskId:       Hash;
  client:       string;
  metadataURI:  string;
  reward:       bigint;
  deadline:     bigint;
  minReputation: bigint;
}

export class TaskScanner {
  private pub:          PublicClient;
  private cfg:          RuntimeConfig;
  private seenTaskIds:  Set<string> = new Set();
  private lastBlock:    bigint      = 0n;

  constructor(pub: PublicClient, cfg: RuntimeConfig) {
    this.pub = pub;
    this.cfg = cfg;
  }

  // ── Scan for new open tasks via event logs ────────────────────

  async scanNewTasks(): Promise<OpenTask[]> {
    try {
      const currentBlock = await this.pub.getBlockNumber();
      const fromBlock    = this.lastBlock > 0n
        ? this.lastBlock + 1n
        : currentBlock - 100n; // Start from last 100 blocks on first run

      if (fromBlock > currentBlock) return [];

      logger.debug("TaskScanner", `Scanning blocks ${fromBlock}–${currentBlock}`);

      const logs = await this.pub.getLogs({
        address:   this.cfg.contracts.TaskMarketplace,
        event:     MARKETPLACE_ABI[3], // TaskPosted event
        fromBlock,
        toBlock:   currentBlock,
      });

      this.lastBlock = currentBlock;

      const newTasks: OpenTask[] = [];

      for (const log of logs) {
        const taskId = log.topics[1] as Hash;
        if (!taskId || this.seenTaskIds.has(taskId)) continue;

        try {
          const task = await this.pub.readContract({
            address:      this.cfg.contracts.TaskMarketplace,
            abi:          MARKETPLACE_ABI,
            functionName: "getTask",
            args:         [taskId],
          }) as any;

          // Only consider OPEN tasks (status == 0)
          if (Number(task.status) !== 0) continue;

          // Filter by min reward
          const minReward = parseEther(this.cfg.minRewardEth);
          if (task.reward < minReward) {
            logger.debug("TaskScanner", `Task ${taskId.slice(0, 10)}... reward too low`);
            continue;
          }

          // Filter by deadline
          const nowSec      = BigInt(Math.floor(Date.now() / 1000));
          const maxDeadline = nowSec + BigInt(this.cfg.maxDeadlineHours * 3600);
          if (task.deadline < nowSec + 3600n) {
            logger.debug("TaskScanner", `Task ${taskId.slice(0, 10)}... deadline too soon`);
            continue;
          }

          this.seenTaskIds.add(taskId);
          newTasks.push({
            taskId,
            client:        task.client,
            metadataURI:   task.metadataURI,
            reward:        task.reward,
            deadline:      task.deadline,
            minReputation: task.minReputation,
          });

          logger.chain("TaskScanner", `Found open task`, {
            taskId:  taskId.slice(0, 18) + "...",
            reward:  task.reward.toString(),
            meta:    task.metadataURI,
          });
        } catch {
          // Task may not exist or already closed — skip
        }
      }

      return newTasks;
    } catch (err) {
      logger.error("TaskScanner", `Scan failed: ${(err as Error).message}`);
      return [];
    }
  }

  // ── Get task details ─────────────────────────────────────────

  async getTask(taskId: Hash): Promise<any | null> {
    try {
      return await this.pub.readContract({
        address:      this.cfg.contracts.TaskMarketplace,
        abi:          MARKETPLACE_ABI,
        functionName: "getTask",
        args:         [taskId],
      });
    } catch {
      return null;
    }
  }

  clearSeen(): void {
    this.seenTaskIds.clear();
  }
}
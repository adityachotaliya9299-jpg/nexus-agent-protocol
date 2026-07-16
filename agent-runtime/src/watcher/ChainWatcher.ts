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

const RESULT_STORAGE_ABI = [
  {
    name: "anchorResult",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "taskId",      type: "bytes32" },
      { name: "agentId",     type: "uint256" },
      { name: "arweaveTxId", type: "string"  },
      { name: "contentHash", type: "bytes32" },
      { name: "contentSize", type: "uint256" },
      { name: "contentType", type: "string"  },
    ],
    outputs: [],
  },
] as const;

// Task status enum
const STATUS = { OPEN: 0, ASSIGNED: 1, SUBMITTED: 2, COMPLETED: 3 };

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

/** Retries an RPC call on timeout/network errors with 2s → 4s → 8s backoff. */
async function withRetry<T>(label: string, fn: () => Promise<T>, retries = 3): Promise<T> {
  let lastErr: Error | undefined;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err as Error;
      const msg = lastErr.message ?? "";
      const transient = /timeout|timed out|ETIMEDOUT|ECONNRESET|ECONNREFUSED|fetch failed|429|503/i.test(msg);
      if (!transient || attempt === retries) throw lastErr;
      const delay = 2000 * 2 ** attempt;
      logger.warn("ChainWatcher", `${label} failed (${msg.slice(0, 80)}), retry ${attempt + 1}/${retries} in ${delay / 1000}s`);
      await sleep(delay);
    }
  }
  throw lastErr;
}

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

      const hash = await withRetry("submitBid", () =>
        this.wal.writeContract({
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
        })
      );

      logger.chain("ChainWatcher", `Bid TX: ${hash}`);
      await withRetry("bid receipt", () => this.pub.waitForTransactionReceipt({ hash }));

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
          await withRetry("work receipt", () => this.pub.waitForTransactionReceipt({ hash }));
          this.assignedTasks.set(taskId, true);
          logger.action("ChainWatcher", `Work submitted ✓ for ${taskId.slice(0, 10)}...`);

          // permanence: push the result to Arweave and anchor the hash on-chain
          await this.anchorToArweave(taskId, resultURI);
        } catch (err) {
          logger.error("ChainWatcher", `Submit work failed: ${(err as Error).message}`);
        }
      }
    } catch (err) {
      logger.error("ChainWatcher", `Check assigned tasks failed: ${(err as Error).message}`);
    }
  }

  // uploads the result to Arweave and anchors the tx id + content hash in
  // ResultStorage. Skips quietly when no Arweave key is configured or the
  // optional `arweave` package isn't installed.
  private async anchorToArweave(taskId: Hash, resultURI: string): Promise<void> {
    const keyFile = (this.cfg as any).arweaveKeyFile ?? process.env.ARWEAVE_KEY_FILE;
    const storageAddr = (this.cfg.contracts as any).ResultStorage ?? process.env.RESULT_STORAGE_ADDR;
    if (!keyFile || !storageAddr) return;

    try {
      const { readFileSync } = await import("fs");
      const { keccak256, toBytes } = await import("viem");
      const ArweaveMod: any = await import("arweave").catch(() => null);
      if (!ArweaveMod) {
        logger.warn("ChainWatcher", "arweave package not installed — skipping upload (npm install arweave)");
        return;
      }

      const arweave = (ArweaveMod.default ?? ArweaveMod).init({
        host: "arweave.net", port: 443, protocol: "https",
      });
      const jwk = JSON.parse(readFileSync(keyFile, "utf8"));

      const content = decodeURIComponent(resultURI.replace(/^data:text\/plain,/, ""));
      const tx = await arweave.createTransaction({ data: content }, jwk);
      tx.addTag("Content-Type", "text/plain");
      tx.addTag("App-Name", "agora-agent-runtime");
      await arweave.transactions.sign(tx, jwk);
      await arweave.transactions.post(tx);

      logger.chain("ChainWatcher", `Arweave upload: ${tx.id}`);

      const contentHash = keccak256(toBytes(content));
      const hash = await withRetry("anchorResult", () =>
        this.wal.writeContract({
          address:      storageAddr,
          abi:          RESULT_STORAGE_ABI,
          functionName: "anchorResult",
          args:         [taskId, this.agentState.agentId, tx.id, contentHash, BigInt(content.length), "text/plain"],
          account:      this.wal.account!,
          chain:        sepolia,
        })
      );
      await withRetry("anchor receipt", () => this.pub.waitForTransactionReceipt({ hash }));
      logger.action("ChainWatcher", `Result anchored on-chain ✓ (ar://${tx.id.slice(0, 12)}...)`);
    } catch (err) {
      // anchoring is best-effort — the marketplace submission already went through
      logger.warn("ChainWatcher", `Arweave anchoring skipped: ${(err as Error).message}`);
    }
  }

  get activeBidCount(): number {
    return this.pendingBids.size;
  }

  removeBid(taskId: string): void {
    this.pendingBids.delete(taskId);
  }
}
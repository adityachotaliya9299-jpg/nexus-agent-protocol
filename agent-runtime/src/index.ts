/**
 * Nexus Agent Runtime - Autonomous Agent Loop
 *
 * This process runs continuously and:
 *   1. Registers itself on-chain if not already registered
 *   2. Optionally stakes ETH for bid eligibility
 *   3. Polls for new open tasks every POLL_INTERVAL_MS
 *   4. Uses Groq LLM to evaluate each task and decide whether to bid
 *   5. Submits bids on suitable tasks
 *   6. Monitors for task assignments
 *   7. Generates work results using the LLM and submits them on-chain
 *
 * Setup:
 *   cp .env.example .env
 *   # Fill in SEPOLIA_RPC_URL, PRIVATE_KEY, GROQ_API_KEY
 *   npm run dev
 */

import { logger }        from "./utils/logger";
import { loadConfig }    from "./utils/config";
import { AgentIdentity } from "./agent/AgentIdentity";
import { TaskScanner }   from "./tasks/TaskScanner";
import { BidStrategy }   from "./strategies/BidStrategy";
import { ChainWatcher }  from "./watcher/ChainWatcher";

async function main() {
  logger.info("Runtime", "═".repeat(50));
  logger.info("Runtime", " Nexus Agent Runtime v0.1.0");
  logger.info("Runtime", "═".repeat(50));

  // ── 1. Load config ────────────────────────────────────────────
  const cfg = loadConfig();
  logger.info("Runtime", `Agent: ${cfg.agentName} | Category: ${cfg.agentCategory}`);
  logger.info("Runtime", `Poll interval: ${cfg.pollIntervalMs}ms | Max bids: ${cfg.maxActiveBids}`);
  logger.info("Runtime", `Min reward: ${cfg.minRewardEth} ETH`);

  // ── 2. Bootstrap agent identity ───────────────────────────────
  const identity = new AgentIdentity(cfg);
  const agentState = await identity.bootstrap();

  logger.info("Runtime", `Agent ID: ${agentState.agentId} | Address: ${identity.address}`);

  // ── 3. Init components ────────────────────────────────────────
  const scanner  = new TaskScanner(identity.publicClient, cfg);
  const strategy = new BidStrategy(cfg);
  const watcher  = new ChainWatcher(
    identity.publicClient,
    identity.walletClient,
    cfg,
    agentState,
  );

  // ── 4. Main loop ──────────────────────────────────────────────
  logger.info("Runtime", "Starting main loop...");
  logger.info("Runtime", "─".repeat(50));

  let iteration = 0;

  while (true) {
    iteration++;
    logger.info("Runtime", `── Iteration ${iteration} ──`);

    try {
      // 4. Refresh agent state (reputation may have changed)
      if (iteration % 10 === 0) {
        await identity.refresh();
        logger.debug("Runtime", `Rep score: ${agentState.reputationScore}`);
      }

      // 4. Check assigned tasks and submit work
      await watcher.checkAndSubmitWork((task) => strategy.generateResult(task));

      // 4. Scan for new open tasks
      const newTasks = await scanner.scanNewTasks();

      if (newTasks.length > 0) {
        logger.info("Runtime", `Found ${newTasks.length} new open task(s)`);
      } else {
        logger.debug("Runtime", "No new tasks found");
      }

      // 4. Evaluate and bid on tasks
      for (const task of newTasks) {
        const decision = await strategy.evaluate(task, agentState);

        logger.info("Runtime", `Task ${task.taskId.slice(0, 14)}... → ${decision.shouldBid ? "BID" : "SKIP"}: ${decision.reasoning}`);

        if (decision.shouldBid) {
          await watcher.submitBid(task, decision.proposalURI, decision.estimatedHours);
        }
      }

    } catch (err) {
      logger.error("Runtime", `Loop error: ${(err as Error).message}`);
    }

    // 4. Wait before next iteration
    logger.debug("Runtime", `Sleeping ${cfg.pollIntervalMs}ms...`);
    await sleep(cfg.pollIntervalMs);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ── Graceful shutdown ─────────────────────────────────────────

process.on("SIGINT",  () => { logger.info("Runtime", "Shutting down (SIGINT)");  process.exit(0); });
process.on("SIGTERM", () => { logger.info("Runtime", "Shutting down (SIGTERM)"); process.exit(0); });

main().catch(err => {
  logger.error("Runtime", `Fatal error: ${err.message}`);
  process.exit(1);
});
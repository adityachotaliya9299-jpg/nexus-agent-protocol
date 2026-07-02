import { ChatGroq } from "@langchain/groq";
import { logger } from "../utils/logger";
import type { RuntimeConfig } from "../utils/config";
import type { OpenTask } from "../tasks/TaskScanner";
import type { AgentState } from "../agent/AgentIdentity";

export interface BidDecision {
  shouldBid:    boolean;
  proposalURI:  string;   
  estimatedHours: number;
  reasoning:    string;
}

export class BidStrategy {
  private llm: ChatGroq;
  private cfg: RuntimeConfig;

  constructor(cfg: RuntimeConfig) {
    this.cfg = cfg;
    this.llm = new ChatGroq({
      apiKey:      cfg.groqApiKey,
      model:       cfg.llmModel,
      temperature: 0.3,
    });
  }

  // ── Decide whether to bid on a task ──────────────────────────

  async evaluate(task: OpenTask, agentState: AgentState): Promise<BidDecision> {
    const rewardEth    = Number(task.reward) / 1e18;
    const deadlineDate = new Date(Number(task.deadline) * 1000).toISOString();
    const hoursLeft    = Math.floor((Number(task.deadline) - Date.now() / 1000) / 3600);

    const prompt = `You are an autonomous AI agent on the Nexus Protocol deciding whether to bid on a task.

AGENT STATE:
- Category: ${this.cfg.agentCategory}
- Reputation Score: ${agentState.reputationScore.toString()} / 10000
- Tasks Completed: ${agentState.totalCompleted.toString()}
- Staked ETH: ${Number(agentState.stakedAmount) / 1e18} ETH

TASK DETAILS:
- Task ID: ${task.taskId.slice(0, 18)}...
- Metadata URI: ${task.metadataURI}
- Reward: ${rewardEth.toFixed(4)} ETH
- Deadline: ${deadlineDate} (${hoursLeft} hours from now)
- Min Reputation Required: ${task.minReputation.toString()}

RULES:
1. Only bid if the task seems doable for a ${this.cfg.agentCategory} agent
2. Don't bid if reputation requirement > our score
3. Don't bid if less than 2 hours remain
4. Estimate realistic completion time

Respond in this EXACT JSON format (no markdown, no explanation outside JSON):
{
  "shouldBid": true/false,
  "reasoning": "one sentence why",
  "estimatedHours": <number>,
  "proposal": "brief description of how you would complete this task"
}`;

    try {
      const response = await this.llm.invoke(prompt);
      const text     = typeof response.content === "string"
        ? response.content
        : JSON.stringify(response.content);

      // Extract JSON from response
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) throw new Error("No JSON in response");

      const decision = JSON.parse(jsonMatch[0]);

      // Safety check: never bid if reputation requirement not met
      if (task.minReputation > agentState.reputationScore) {
        return {
          shouldBid:      false,
          proposalURI:    "",
          estimatedHours: 0,
          reasoning:      `Reputation too low (${agentState.reputationScore} < ${task.minReputation})`,
        };
      }

      logger.debug("BidStrategy", `LLM decision for ${task.taskId.slice(0, 10)}...`, decision);

      return {
        shouldBid:      Boolean(decision.shouldBid),
        proposalURI:    `data:text/plain,${encodeURIComponent(decision.proposal ?? "Autonomous agent bid")}`,
        estimatedHours: Number(decision.estimatedHours ?? 24),
        reasoning:      String(decision.reasoning ?? ""),
      };
    } catch (err) {
      logger.warn("BidStrategy", `LLM evaluation failed, defaulting to bid: ${(err as Error).message}`);
      // Default: bid on everything we can
      return {
        shouldBid:      true,
        proposalURI:    "data:text/plain,Autonomous%20Nexus%20agent%20bid",
        estimatedHours: 24,
        reasoning:      "LLM unavailable — default bid",
      };
    }
  }

  // ── Generate work result ─────────────────────────────────────

  async generateResult(task: OpenTask): Promise<string> {
    const prompt = `You are an autonomous AI agent that just completed a task on the Nexus Protocol.

Task metadata URI: ${task.metadataURI}
Task reward: ${Number(task.reward) / 1e18} ETH

Generate a brief (2-3 sentence) description of the completed work result.
This will be stored as the task result URI.
Respond with only the description, no JSON, no formatting.`;

    try {
      const response = await this.llm.invoke(prompt);
      const text = typeof response.content === "string"
        ? response.content
        : String(response.content);
      return `data:text/plain,${encodeURIComponent(text.trim())}`;
    } catch {
      return "data:text/plain,Task%20completed%20by%20Nexus%20autonomous%20agent";
    }
  }
}
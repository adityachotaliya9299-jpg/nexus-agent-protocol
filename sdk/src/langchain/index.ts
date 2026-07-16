/**
 * LangChain tool wrappers for Nexus Agent Protocol.
 *
 * Allows LangChain agents / AutoGen agents to interact
 * with the Nexus protocol as on-chain tools.
 *
 * Usage:
 *   import { createNexusTools } from "@nexus-agent/sdk/langchain";
 *   import { ChatOpenAI } from "@langchain/openai";
 *   import { AgentExecutor, createToolCallingAgent } from "langchain/agents";
 *
 *   const tools = createNexusTools(nexusClient);
 *   const agent = createToolCallingAgent({ llm, tools, prompt });
 *   const executor = AgentExecutor.fromAgentAndTools({ agent, tools });
 *   await executor.invoke({ input: "Register me as a CODE agent" });
 */

import { NexusClient } from "../client/NexusClient";
import { parseEther } from "viem";
import type { Hash, Address } from "viem";

// ── Tool definition type (framework-agnostic) ──────────────────

export interface NexusTool {
  name:        string;
  description: string;
  schema:      Record<string, { type: string; description: string; required?: boolean }>;
  call:        (input: Record<string, any>) => Promise<string>;
}

// ── Tool factory ───────────────────────────────────────────────

export function createNexusTools(client: NexusClient): NexusTool[] {
  return [
    // ── Agent tools ─────────────────────────────────────────────

    {
      name: "nexus_get_agent",
      description:
        "Get a Nexus agent's profile including reputation score, category, status, and total earnings. Use when you need to look up an agent by their ID.",
      schema: {
        agentId: { type: "string", description: "The agent's numeric ID on Nexus", required: true },
      },
      call: async ({ agentId }) => {
        const agent = await client.agents.get(BigInt(agentId));
        return JSON.stringify({
          agentId:             agent.agentId.toString(),
          owner:               agent.owner,
          agentWallet:         agent.agentWallet,
          category:            agent.category,
          status:              agent.status,
          reputationScore:     agent.reputationScore.toString(),
          totalTasksCompleted: agent.totalTasksCompleted.toString(),
          totalEarned:         agent.totalEarned.toString(),
        });
      },
    },

    {
      name: "nexus_register_agent",
      description:
        "Register a new AI agent on the Nexus protocol. The agent gets an on-chain identity with a metadata URI pointing to their capabilities. Category must be one of: GENERAL, CODE, RESEARCH, TRADING, CREATIVE, ORCHESTRATOR.",
      schema: {
        metadataURI: { type: "string", description: "IPFS URI to agent metadata JSON", required: true },
        category:    { type: "string", description: "Agent specialization category", required: true },
      },
      call: async ({ metadataURI, category }) => {
        const result = await client.agents.register({ metadataURI, category });
        return JSON.stringify({
          success: true,
          txHash:  result.hash,
          message: `Agent registered in block ${result.blockNumber}. Gas used: ${result.gasUsed}`,
        });
      },
    },

    {
      name: "nexus_get_agent_reputation",
      description:
        "Get an agent's current reputation score (0-10000) and tier. Tiers: NOVICE(0-1999), RISING(2000-3999), ESTABLISHED(4000-5999), ADVANCED(6000-7999), EXPERT(8000-9999), ELITE(10000).",
      schema: {
        agentId: { type: "string", description: "The agent's numeric ID", required: true },
      },
      call: async ({ agentId }) => {
        const [score, tier] = await Promise.all([
          client.reputation.getScore(BigInt(agentId)),
          client.reputation.getTier(BigInt(agentId)),
        ]);
        return JSON.stringify({
          agentId,
          score:    score.toString(),
          tier,
          percent:  `${(Number(score) / 100).toFixed(1)}%`,
        });
      },
    },

    // ── Task tools ───────────────────────────────────────────────

    {
      name: "nexus_get_task",
      description:
        "Get details of a task on the Nexus marketplace including status, reward, deadline, and assigned agent.",
      schema: {
        taskId: { type: "string", description: "The task's bytes32 ID (hex string)", required: true },
      },
      call: async ({ taskId }) => {
        const task = await client.tasks.get(taskId as Hash);
        return JSON.stringify({
          taskId:          task.taskId,
          client:          task.client,
          status:          task.status,
          reward:          task.reward.toString(),
          deadline:        task.deadline.toString(),
          metadataURI:     task.metadataURI,
          assignedAgentId: task.assignedAgentId.toString(),
          platformFee:     task.platformFee.toString(),
        });
      },
    },

    {
      name: "nexus_post_task",
      description:
        "Post a new task to the Nexus marketplace with an ETH reward. Agents can then bid on it. The reward is held in escrow until the task is completed.",
      schema: {
        metadataURI:    { type: "string",  description: "IPFS URI describing the task requirements", required: true },
        rewardEth:      { type: "string",  description: "Reward amount in ETH (e.g. '0.1')", required: true },
        deadlineHours:  { type: "number",  description: "Hours from now until task deadline", required: true },
        minReputation:  { type: "number",  description: "Minimum reputation score required to bid (0 = no minimum)", required: false },
      },
      call: async ({ metadataURI, rewardEth, deadlineHours, minReputation }) => {
        const deadline = BigInt(Math.floor(Date.now() / 1000) + (deadlineHours * 3600));
        const result = await client.tasks.post({
          metadataURI,
          deadline,
          reward:        parseEther(rewardEth),
          minReputation: BigInt(minReputation ?? 0),
        });
        return JSON.stringify({
          success: true,
          txHash:  result.hash,
          message: `Task posted in block ${result.blockNumber}. Check tx for taskId.`,
        });
      },
    },

    {
      name: "nexus_submit_bid",
      description:
        "Submit a bid for a task on the Nexus marketplace as an agent. You need a registered agentId and the task must be in OPEN status.",
      schema: {
        taskId:           { type: "string", description: "The task bytes32 ID to bid on", required: true },
        agentId:          { type: "string", description: "Your agent's numeric ID", required: true },
        proposalURI:      { type: "string", description: "IPFS URI of your proposal", required: true },
        estimatedHours:   { type: "number", description: "Estimated hours to complete the task", required: true },
      },
      call: async ({ taskId, agentId, proposalURI, estimatedHours }) => {
        const result = await client.tasks.submitBid({
          taskId:        taskId as Hash,
          agentId:       BigInt(agentId),
          proposalURI,
          estimatedTime: BigInt(estimatedHours * 3600),
        });
        return JSON.stringify({
          success: true,
          txHash:  result.hash,
          message: `Bid submitted in block ${result.blockNumber}`,
        });
      },
    },

    {
      name: "nexus_submit_work",
      description:
        "Submit completed work for an assigned task. The result is stored as an IPFS URI. The client must then approve the work to release payment.",
      schema: {
        taskId:    { type: "string", description: "The task bytes32 ID", required: true },
        agentId:   { type: "string", description: "Your agent's numeric ID", required: true },
        resultURI: { type: "string", description: "IPFS URI of the completed work", required: true },
      },
      call: async ({ taskId, agentId, resultURI }) => {
        const result = await client.tasks.submitWork(taskId as Hash, BigInt(agentId), resultURI);
        return JSON.stringify({
          success: true,
          txHash:  result.hash,
          message: `Work submitted in block ${result.blockNumber}. Awaiting client approval.`,
        });
      },
    },

    {
      name: "nexus_get_agent_tasks",
      description:
        "Get all task IDs that have been assigned to a specific agent. Returns an array of bytes32 task IDs.",
      schema: {
        agentId: { type: "string", description: "The agent's numeric ID", required: true },
      },
      call: async ({ agentId }) => {
        const taskIds = await client.tasks.getAgentTasks(BigInt(agentId));
        return JSON.stringify({
          agentId,
          taskCount: taskIds.length,
          taskIds,
        });
      },
    },

    // ── Staking tools ────────────────────────────────────────────

    {
      name: "nexus_get_agent_stake",
      description:
        "Get an agent's staking information including total staked ETH, locked stake, and slash history.",
      schema: {
        agentId: { type: "string", description: "The agent's numeric ID", required: true },
      },
      call: async ({ agentId }) => {
        const [stake, effective] = await Promise.all([
          client.staking.getStake(BigInt(agentId)),
          client.staking.getEffectiveStake(BigInt(agentId)),
        ]);
        return JSON.stringify({
          agentId,
          totalStaked:     stake.totalStaked.toString(),
          ownStake:        stake.ownStake.toString(),
          delegatedStake:  stake.delegatedStake.toString(),
          lockedStake:     stake.lockedStake.toString(),
          effectiveStake:  effective.toString(),
          slashCount:      stake.slashCount.toString(),
        });
      },
    },

    {
      name: "nexus_stake_for_agent",
      description:
        "Stake ETH as collateral for your agent. Higher effective stake improves bid eligibility for high-value tasks. Reputation multiplies the effective stake.",
      schema: {
        agentId:   { type: "string", description: "Your agent's numeric ID", required: true },
        amountEth: { type: "string", description: "Amount of ETH to stake (e.g. '0.5')", required: true },
      },
      call: async ({ agentId, amountEth }) => {
        const result = await client.staking.stake(BigInt(agentId), amountEth);
        return JSON.stringify({
          success: true,
          txHash:  result.hash,
          message: `Staked ${amountEth} ETH for agent ${agentId} in block ${result.blockNumber}`,
        });
      },
    },

    // ── Composability tools ──────────────────────────────────────

    {
      name: "nexus_hire_sub_agent",
      description:
        "As an orchestrator agent, hire a sub-agent for a specific sub-task. The reward is escrowed trustlessly — the sub-agent gets paid without needing your approval if they prove their work.",
      schema: {
        parentTaskId:  { type: "string", description: "The parent marketplace task ID", required: true },
        parentAgentId: { type: "string", description: "Your orchestrator agent ID", required: true },
        metadataURI:   { type: "string", description: "IPFS URI describing the sub-task", required: true },
        rewardEth:     { type: "string", description: "ETH reward for the sub-agent", required: true },
        deadlineHours: { type: "number", description: "Hours until sub-task deadline", required: true },
        splitBps:      { type: "number", description: "Basis points of reward going to sub-agent (100-9000)", required: true },
      },
      call: async ({ parentTaskId, parentAgentId, metadataURI, rewardEth, deadlineHours, splitBps }) => {
        const deadline = BigInt(Math.floor(Date.now() / 1000) + (deadlineHours * 3600));
        const result = await client.composability.createSubTask({
          parentTaskId:  parentTaskId as Hash,
          parentAgentId: BigInt(parentAgentId),
          metadataURI,
          deadline,
          splitBps:      BigInt(splitBps),
          reward:        parseEther(rewardEth),
        });
        return JSON.stringify({
          success: true,
          txHash:  result.hash,
          message: `Sub-task created in block ${result.blockNumber}. Assign a sub-agent next.`,
        });
      },
    },

    {
      name: "nexus_get_agent_relationship",
      description:
        "Get the on-chain collaboration history between two agents — how many sub-tasks they've worked on together and total ETH paid.",
      schema: {
        parentAgentId: { type: "string", description: "The orchestrator agent ID", required: true },
        subAgentId:    { type: "string", description: "The sub-agent ID", required: true },
      },
      call: async ({ parentAgentId, subAgentId }) => {
        const rel = await client.composability.getRelationship(
          BigInt(parentAgentId),
          BigInt(subAgentId),
        ) as any;
        return JSON.stringify({
          parentAgentId:          rel.parentAgentId.toString(),
          subAgentId:             rel.subAgentId.toString(),
          totalSubTasksGiven:     rel.totalSubTasksGiven.toString(),
          totalSubTasksCompleted: rel.totalSubTasksCompleted.toString(),
          totalEthPaid:           rel.totalEthPaid.toString(),
          firstCollabAt:          new Date(Number(rel.firstCollabAt) * 1000).toISOString(),
          lastCollabAt:           new Date(Number(rel.lastCollabAt) * 1000).toISOString(),
        });
      },
    },

    // ── ZK Escrow tools ──────────────────────────────────────────

    {
      name: "nexus_create_escrow",
      description:
        "Create a ZK-gated escrow for a task. Locks ETH that releases automatically to the agent's wallet once they submit a valid zero-knowledge proof of the committed result — no client approval needed.",
      schema: {
        taskId:        { type: "string", description: "The marketplace task bytes32 ID", required: true },
        agentWallet:   { type: "string", description: "The agent wallet address that will receive payment", required: true },
        rewardEth:     { type: "string", description: "ETH amount to lock in escrow (e.g. '0.1')", required: true },
        deadlineHours: { type: "number", description: "Hours until the escrow can be refunded to the client", required: true },
      },
      call: async ({ taskId, agentWallet, rewardEth, deadlineHours }) => {
        const deadline = BigInt(Math.floor(Date.now() / 1000) + deadlineHours * 3600);
        const result = await client.zkescrow.create({
          taskId:      taskId as Hash,
          agentWallet: agentWallet as Address,
          deadline,
          reward:      parseEther(rewardEth),
        });
        return JSON.stringify({
          success: true,
          txHash:  result.hash,
          message: `Escrow created in block ${result.blockNumber}. Set the commitment next.`,
        });
      },
    },

    {
      name: "nexus_set_commitment",
      description:
        "Set the result commitment on an escrow. The commitment is keccak256(resultHash, salt) — compute it from the expected result hash and a random salt, then share the salt with the agent off-chain.",
      schema: {
        escrowId:   { type: "string", description: "The escrow bytes32 ID", required: true },
        resultHash: { type: "string", description: "keccak256 hash of the expected result (bytes32 hex)", required: true },
        salt:       { type: "string", description: "Random bytes32 salt (share with the agent off-chain)", required: true },
      },
      call: async ({ escrowId, resultHash, salt }) => {
        const commitment = client.zkescrow.computeCommitment(resultHash as Hash, salt as Hash);
        const result = await client.zkescrow.setCommitment(escrowId as Hash, commitment);
        return JSON.stringify({
          success: true,
          txHash:  result.hash,
          commitment,
          message: `Commitment set in block ${result.blockNumber}. Share the salt with the agent.`,
        });
      },
    },

    {
      name: "nexus_release_with_proof",
      description:
        "Release an escrow by submitting a Groth16 zero-knowledge proof of the committed result. Payment transfers to the agent wallet instantly if the proof verifies. Generate the proof off-chain with scripts/zk/generate-proof.js.",
      schema: {
        escrowId:   { type: "string", description: "The escrow bytes32 ID", required: true },
        resultHash: { type: "string", description: "keccak256 hash of the actual result (bytes32 hex)", required: true },
        salt:       { type: "string", description: "The salt shared by the client (bytes32 hex)", required: true },
        proofJson:  { type: "string", description: "JSON string with pA, pB, pC, pubSignals from the proof generator", required: true },
      },
      call: async ({ escrowId, resultHash, salt, proofJson }) => {
        const proof = JSON.parse(proofJson);
        const result = await client.zkescrow.releaseWithProof(
          escrowId as Hash,
          resultHash as Hash,
          salt as Hash,
          proof,
        );
        return JSON.stringify({
          success: true,
          txHash:  result.hash,
          message: `Proof verified — escrow released in block ${result.blockNumber}.`,
        });
      },
    },

    {
      name: "nexus_get_escrow",
      description:
        "Get details of a ZK-gated escrow including status, amount, and commitment hash.",
      schema: {
        escrowId: { type: "string", description: "The escrow bytes32 ID", required: true },
      },
      call: async ({ escrowId }) => {
        const esc = await client.zkescrow.get(escrowId as Hash);
        return JSON.stringify({
          escrowId:    esc.escrowId,
          status:      esc.status,
          amount:      esc.amount.toString(),
          client:      esc.client,
          agentWallet: esc.agentWallet,
          deadline:    new Date(Number(esc.deadline) * 1000).toISOString(),
          hasCommitment: esc.commitment !== "0x0000000000000000000000000000000000000000000000000000000000000000",
        });
      },
    },

    {
      name: "nexus_create_dao",
      description:
        "Form a DAO of registered agents with an automatic revenue split. Splits are in basis points and must sum to 10000 (e.g. two agents at 6000/4000 = 60%/40%). Revenue from DAO tasks distributes trustlessly.",
      schema: {
        name:           { type: "string", description: "Human-readable DAO name", required: true },
        memberAgentIds: { type: "string", description: "Comma-separated agent IDs, e.g. '1,4,7'", required: true },
        splitBps:       { type: "string", description: "Comma-separated basis points matching the members, must sum to 10000, e.g. '5000,3000,2000'", required: true },
      },
      call: async ({ name, memberAgentIds, splitBps }) => {
        const ids = memberAgentIds.split(",").map((s: string) => BigInt(s.trim()));
        const bps = splitBps.split(",").map((s: string) => BigInt(s.trim()));
        const result = await client.dao.create(name, ids, bps);
        return JSON.stringify({
          success: true,
          txHash:  result.hash,
          message: `DAO "${name}" created in block ${result.blockNumber} with ${ids.length} members.`,
        });
      },
    },

    {
      name: "nexus_propose_grant",
      description:
        "Propose a grant from the community treasury. Grant types: DEVELOPMENT, ECOSYSTEM, RESEARCH, OPERATIONS, BOUNTY. Registered agents then vote, weighted by reputation.",
      schema: {
        title:           { type: "string", description: "Short grant title", required: true },
        description:     { type: "string", description: "What the grant funds and why", required: true },
        recipient:       { type: "string", description: "Address that receives the funds if approved", required: true },
        amountEth:       { type: "string", description: "ETH amount requested (e.g. '0.5')", required: true },
        grantType:       { type: "string", description: "One of DEVELOPMENT, ECOSYSTEM, RESEARCH, OPERATIONS, BOUNTY", required: true },
        proposerAgentId: { type: "string", description: "Your agent's numeric ID", required: true },
      },
      call: async ({ title, description, recipient, amountEth, grantType, proposerAgentId }) => {
        const result = await client.grants.propose({
          title,
          description,
          recipient:       recipient as Address,
          amountEth,
          grantType,
          proposerAgentId: BigInt(proposerAgentId),
        });
        return JSON.stringify({
          success: true,
          txHash:  result.hash,
          message: `Grant "${title}" proposed in block ${result.blockNumber}. Voting is now open.`,
        });
      },
    },

    // ── Protocol stats ────────────────────────────────────────────

    {
      name: "nexus_protocol_stats",
      description:
        "Get overall Nexus protocol statistics including total agents, tasks posted, and tasks completed.",
      schema: { dummy: { type: "string", description: "unused", required: false } },
      call: async () => {
        const [totalAgents, totalPosted] = await Promise.all([
          client.agents.totalAgents(),
          client.tasks.totalPosted(),
        ]);
        return JSON.stringify({
          totalAgents:  totalAgents.toString(),
          totalPosted:  totalPosted.toString(),
          network:      "Sepolia Testnet",
          contracts:    client.contracts,
        });
      },
    },
  ];
}

// ── LangChain adapter (optional — only if langchain installed) ─

export function toLangChainTools(nexusTools: NexusTool[]) {
  try {
    const { DynamicStructuredTool } = require("@langchain/core/tools");
    const { z } = require("zod");

    return nexusTools.map(tool => {
      // Build zod schema from tool schema
      const zodShape: Record<string, any> = {};
      for (const [key, def] of Object.entries(tool.schema)) {
        let field = def.type === "number" ? z.number() : z.string();
        if (!def.required) field = field.optional();
        zodShape[key] = field.describe(def.description);
      }

      return new DynamicStructuredTool({
        name:        tool.name,
        description: tool.description,
        schema:      z.object(zodShape),
        func:        tool.call,
      });
    });
  } catch {
    throw new Error(
      "LangChain not installed. Run: npm install @langchain/core langchain"
    );
  }
}
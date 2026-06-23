import { BigInt } from "@graphprotocol/graph-ts";
import {
  AgentRegistered,
  AgentUpdated,
  AgentWalletSet,
  AgentStatusChanged,
  ReputationUpdated,
} from "../generated/AgentRegistry/AgentRegistry";
import { Agent, ProtocolStats } from "../generated/schema";

function getOrCreateStats(): ProtocolStats {
  let stats = ProtocolStats.load("global");
  if (!stats) {
    stats = new ProtocolStats("global");
    stats.totalAgents = BigInt.fromI32(0);
    stats.totalTasks = BigInt.fromI32(0);
    stats.totalTasksCompleted = BigInt.fromI32(0);
    stats.totalValueLocked = BigInt.fromI32(0);
    stats.totalPayouts = BigInt.fromI32(0);
    stats.totalSubscriptionRevenue = BigInt.fromI32(0);
    stats.lastUpdatedBlock = BigInt.fromI32(0);
  }
  return stats;
}

export function handleAgentRegistered(event: AgentRegistered): void {
  let agentId = event.params.agentId.toString();
  let agent = new Agent(agentId);

  agent.agentId = event.params.agentId;
  agent.owner = event.params.owner;
  agent.agentWallet = null;
  agent.metadataURI = event.params.metadataURI;
  agent.category = event.params.category;
  agent.status = 1; // ACTIVE
  agent.reputationScore = BigInt.fromI32(5000); // INITIAL_SCORE
  agent.totalTasksCompleted = BigInt.fromI32(0);
  agent.totalEarned = BigInt.fromI32(0);
  agent.registeredAt = event.block.timestamp;
  agent.lastActiveAt = event.block.timestamp;
  agent.save();

  let stats = getOrCreateStats();
  stats.totalAgents = stats.totalAgents.plus(BigInt.fromI32(1));
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

export function handleAgentUpdated(event: AgentUpdated): void {
  let agent = Agent.load(event.params.agentId.toString());
  if (!agent) return;

  agent.metadataURI = event.params.metadataURI;
  agent.lastActiveAt = event.block.timestamp;
  agent.save();
}

export function handleAgentWalletSet(event: AgentWalletSet): void {
  let agent = Agent.load(event.params.agentId.toString());
  if (!agent) return;

  agent.agentWallet = event.params.wallet;
  agent.save();
}

export function handleAgentStatusChanged(event: AgentStatusChanged): void {
  let agent = Agent.load(event.params.agentId.toString());
  if (!agent) return;

  agent.status = event.params.status;
  agent.lastActiveAt = event.block.timestamp;
  agent.save();
}

export function handleRegistryReputationUpdated(event: ReputationUpdated): void {
  // Registry mirrors oracle updates — keep agent score in sync
  let agent = Agent.load(event.params.agentId.toString());
  if (!agent) return;

  agent.reputationScore = event.params.newScore;
  agent.lastActiveAt = event.block.timestamp;
  agent.save();
}
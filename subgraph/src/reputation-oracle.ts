import { BigInt } from "@graphprotocol/graph-ts";
import {
  ReputationInitialized,
  ReputationUpdated,
  AgentSlashed,
} from "../generated/ReputationOracle/ReputationOracle";
import { Agent, ReputationEvent } from "../generated/schema";

export function handleReputationInitialized(event: ReputationInitialized): void {
  let agent = Agent.load(event.params.agentId.toString());
  if (!agent) return;

  agent.reputationScore = event.params.initialScore;
  agent.save();
}

export function handleReputationUpdated(event: ReputationUpdated): void {
  let agent = Agent.load(event.params.agentId.toString());
  if (!agent) return;

  agent.reputationScore = event.params.newScore;
  agent.lastActiveAt = event.block.timestamp;
  agent.save();

  // Store event in history
  let eventId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let repEvent = new ReputationEvent(eventId);
  repEvent.agent = event.params.agentId.toString();
  repEvent.oldScore = event.params.oldScore;
  repEvent.newScore = event.params.newScore;
  repEvent.delta = event.params.newScore.minus(event.params.oldScore);
  repEvent.reason = event.params.reason;
  repEvent.updatedBy = event.params.updatedBy;
  repEvent.referenceId = event.params.referenceId;
  repEvent.timestamp = event.block.timestamp;
  repEvent.blockNumber = event.block.number;
  repEvent.transactionHash = event.transaction.hash;
  repEvent.save();
}

export function handleAgentSlashed(event: AgentSlashed): void {
  let agent = Agent.load(event.params.agentId.toString());
  if (!agent) return;

  // Score already updated by ReputationUpdated event — just update activity
  agent.lastActiveAt = event.block.timestamp;
  agent.save();
}
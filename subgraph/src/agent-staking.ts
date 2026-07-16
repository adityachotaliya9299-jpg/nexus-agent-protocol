import { BigInt } from "@graphprotocol/graph-ts";
import { Staked, Slashed, UnstakeRequested } from "../generated/AgentStaking/AgentStaking";
import { StakeEvent } from "../generated/schema";

function eventId(txHash: string, logIndex: BigInt): string {
  return txHash + "-" + logIndex.toString();
}

export function handleStaked(event: Staked): void {
  const e = new StakeEvent(eventId(event.transaction.hash.toHexString(), event.logIndex));
  e.agentId = event.params.agentId;
  e.staker = event.params.staker;
  e.kind = "STAKED";
  e.amount = event.params.amount;
  e.timestamp = event.block.timestamp;
  e.blockNumber = event.block.number;
  e.transactionHash = event.transaction.hash;
  e.save();
}

export function handleSlashed(event: Slashed): void {
  const e = new StakeEvent(eventId(event.transaction.hash.toHexString(), event.logIndex));
  e.agentId = event.params.agentId;
  e.kind = "SLASHED";
  e.amount = event.params.totalSlashed;
  e.timestamp = event.block.timestamp;
  e.blockNumber = event.block.number;
  e.transactionHash = event.transaction.hash;
  e.save();
}

export function handleUnstakeRequested(event: UnstakeRequested): void {
  const e = new StakeEvent(eventId(event.transaction.hash.toHexString(), event.logIndex));
  e.agentId = event.params.agentId;
  e.kind = "UNSTAKE_REQUESTED";
  e.amount = event.params.amount;
  e.timestamp = event.block.timestamp;
  e.blockNumber = event.block.number;
  e.transactionHash = event.transaction.hash;
  e.save();
}

import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  TaskPosted,
  BidSubmitted,
  AgentAssigned,
  WorkSubmitted,
  WorkApproved,
  TaskCancelled,
  DisputeRaised,
  DisputeResolved,
} from "../generated/TaskMarketplace/TaskMarketplace";
import { Task, Bid, Dispute, Agent, ProtocolStats } from "../generated/schema";

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

export function handleTaskPosted(event: TaskPosted): void {
  let taskId = event.params.taskId.toHexString();
  let task = new Task(taskId);

  task.taskId = event.params.taskId;
  task.rawClient = event.params.client;
  task.metadataURI = ""; // fetched from contract if needed
  task.reward = event.params.reward;
  task.deadline = event.params.deadline;
  task.createdAt = event.block.timestamp;
  task.status = 0; // OPEN
  task.minReputation = BigInt.fromI32(0);
  task.resultURI = null;
  task.payment = null;
  task.blockNumber = event.block.number;
  task.blockTimestamp = event.block.timestamp;
  task.transactionHash = event.transaction.hash;

  // Link client agent if they are a registered agent
  // (client may be a non-agent address — check Agent entity exists)
  let clientAgent = Agent.load(event.params.client.toHexString());
  if (clientAgent) {
    task.clientAddress = clientAgent.id;
  }

  task.save();

  let stats = getOrCreateStats();
  stats.totalTasks = stats.totalTasks.plus(BigInt.fromI32(1));
  stats.totalValueLocked = stats.totalValueLocked.plus(event.params.reward);
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

export function handleBidSubmitted(event: BidSubmitted): void {
  let taskId = event.params.taskId.toHexString();
  let agentId = event.params.agentId.toString();
  let bidId = taskId + "-" + agentId;

  let bid = new Bid(bidId);
  bid.task = taskId;
  bid.agent = agentId;
  bid.proposalURI = event.params.proposalURI;
  bid.active = true;
  bid.submittedAt = event.block.timestamp;
  bid.blockNumber = event.block.number;
  bid.transactionHash = event.transaction.hash;
  bid.save();

  // Update agent activity
  let agent = Agent.load(agentId);
  if (agent) {
    agent.lastActiveAt = event.block.timestamp;
    agent.save();
  }
}

export function handleAgentAssigned(event: AgentAssigned): void {
  let task = Task.load(event.params.taskId.toHexString());
  if (!task) return;

  task.status = 1; // ASSIGNED
  task.assignedAgent = event.params.agentId.toString();
  task.save();

  // Deactivate all other bids on this task (they're no longer competing)
  // Note: we mark the winning bid as still active; others stay as-is
  // (subgraph doesn't loop — accept the minor inaccuracy or track via contract events)
}

export function handleWorkSubmitted(event: WorkSubmitted): void {
  let task = Task.load(event.params.taskId.toHexString());
  if (!task) return;

  task.status = 2; // SUBMITTED
  task.resultURI = event.params.resultURI;
  task.save();

  let agent = Agent.load(event.params.agentId.toString());
  if (agent) {
    agent.lastActiveAt = event.block.timestamp;
    agent.save();
  }
}

export function handleWorkApproved(event: WorkApproved): void {
  let task = Task.load(event.params.taskId.toHexString());
  if (!task) return;

  task.status = 3; // COMPLETED
  task.payment = event.params.payment;
  task.save();

  // Update agent stats
  let agent = Agent.load(event.params.agentId.toString());
  if (agent) {
    agent.totalTasksCompleted = agent.totalTasksCompleted.plus(BigInt.fromI32(1));
    agent.totalEarned = agent.totalEarned.plus(event.params.payment);
    agent.lastActiveAt = event.block.timestamp;
    agent.save();
  }

  // Update global stats
  let stats = getOrCreateStats();
  stats.totalTasksCompleted = stats.totalTasksCompleted.plus(BigInt.fromI32(1));
  stats.totalValueLocked = stats.totalValueLocked.minus(task.reward);
  stats.totalPayouts = stats.totalPayouts.plus(event.params.payment);
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

export function handleTaskCancelled(event: TaskCancelled): void {
  let task = Task.load(event.params.taskId.toHexString());
  if (!task) return;

  task.status = 5; // CANCELLED
  task.save();

  let stats = getOrCreateStats();
  stats.totalValueLocked = stats.totalValueLocked.minus(task.reward);
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

export function handleDisputeRaised(event: DisputeRaised): void {
  let taskId = event.params.taskId.toHexString();
  let task = Task.load(taskId);
  if (!task) return;

  task.status = 4; // DISPUTED
  task.save();

  let dispute = new Dispute(taskId);
  dispute.task = taskId;
  dispute.raisedBy = event.params.raisedBy;
  dispute.raisedAt = event.block.timestamp;
  dispute.outcome = null;
  dispute.resolvedAt = null;
  dispute.blockNumber = event.block.number;
  dispute.transactionHash = event.transaction.hash;
  dispute.save();
}

export function handleDisputeResolved(event: DisputeResolved): void {
  let taskId = event.params.taskId.toHexString();
  let dispute = Dispute.load(taskId);
  if (!dispute) return;

  dispute.outcome = event.params.outcome;
  dispute.resolvedAt = event.block.timestamp;
  dispute.save();

  let task = Task.load(taskId);
  if (!task) return;

  // outcome 0 = CLIENT_WINS (refund) → CANCELLED, 1 = AGENT_WINS → COMPLETED, 2 = SPLIT
  if (event.params.outcome == 1) {
    task.status = 3; // COMPLETED
  } else {
    task.status = 5; // CANCELLED / refunded
  }
  task.save();

  let stats = getOrCreateStats();
  stats.totalValueLocked = stats.totalValueLocked.minus(task.reward);
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}
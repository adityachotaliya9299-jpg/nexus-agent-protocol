import { BigInt } from "@graphprotocol/graph-ts";
import {
  PlanCreated,
  Subscribed,
  PaymentProcessed,
  SubscriptionCancelled,
} from "../generated/SubscriptionManager/SubscriptionManager";
import { SubscriptionPlan, AgentSubscription, Agent, ProtocolStats } from "../generated/schema";

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

export function handlePlanCreated(event: PlanCreated): void {
  let planId = event.params.planId.toHexString();
  let plan = new SubscriptionPlan(planId);

  plan.planId = event.params.planId;
  plan.agent = event.params.agentId.toString();
  plan.tier = event.params.tier;
  plan.pricePerPeriod = event.params.pricePerPeriod;
  plan.periodDuration = BigInt.fromI32(0); // not in event — filled on first payment
  plan.maxSubscribers = BigInt.fromI32(0); // not in event — use contract read if needed
  plan.currentSubscribers = BigInt.fromI32(0);
  plan.isActive = true;
  plan.createdAt = event.block.timestamp;
  plan.save();
}

export function handleSubscribed(event: Subscribed): void {
  let planId = event.params.planId.toHexString();
  let subId = planId + "-" + event.params.subscriber.toHexString().toLowerCase();

  let plan = SubscriptionPlan.load(planId);
  if (plan) {
    plan.currentSubscribers = plan.currentSubscribers.plus(BigInt.fromI32(1));
    plan.save();
  }

    let sub = new AgentSubscription(subId);
  sub.plan = planId;
  sub.subscriber = event.params.subscriber;
  sub.startedAt = event.block.timestamp;
  sub.lastPaymentAt = event.block.timestamp;
  sub.totalPaid = BigInt.fromI32(0);
  sub.status = 0; // ACTIVE
  sub.save();
}

export function handlePaymentProcessed(event: PaymentProcessed): void {
  let planId = event.params.planId.toHexString();
  let subId = planId + "-" + event.params.subscriber.toHexString().toLowerCase();

  let sub = AgentSubscription.load(subId);
  if (sub) {
    sub.lastPaymentAt = event.block.timestamp;
    sub.totalPaid = sub.totalPaid.plus(event.params.amount);
    sub.save();
  }

  let stats = getOrCreateStats();
  stats.totalSubscriptionRevenue = stats.totalSubscriptionRevenue.plus(event.params.amount);
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

export function handleSubscriptionCancelled(event: SubscriptionCancelled): void {
  let planId = event.params.planId.toHexString();
  let subId = planId + "-" + event.params.subscriber.toHexString().toLowerCase();

  let plan = SubscriptionPlan.load(planId);
  if (plan && plan.currentSubscribers.gt(BigInt.fromI32(0))) {
    plan.currentSubscribers = plan.currentSubscribers.minus(BigInt.fromI32(1));
    plan.save();
  }

  let sub = AgentSubscription.load(subId);
  if (sub) {
    sub.status = 2; // CANCELLED
    sub.save();
  }
}
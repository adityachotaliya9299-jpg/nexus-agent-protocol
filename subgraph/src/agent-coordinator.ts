import { BigInt } from "@graphprotocol/graph-ts";
import { WorkflowCreated as WorkflowCreatedEvent, StageCompleted, WorkflowCompleted, WorkflowFailed } from "../generated/AgentCoordinator/AgentCoordinator";
import { WorkflowCreated } from "../generated/schema";

export function handleWorkflowCreated(event: WorkflowCreatedEvent): void {
  const w = new WorkflowCreated(event.params.workflowId.toHexString());
  w.workflowId = event.params.workflowId;
  w.workflowType = event.params.workflowType;
  w.totalStages = event.params.totalStages;
  w.completedStages = BigInt.zero();
  w.status = 0;
  w.createdAt = event.block.timestamp;
  w.transactionHash = event.transaction.hash;
  w.save();
}

export function handleStageCompleted(event: StageCompleted): void {
  const w = WorkflowCreated.load(event.params.workflowId.toHexString());
  if (w == null) return;
  w.completedStages = w.completedStages.plus(BigInt.fromI32(1));
  w.save();
}

export function handleWorkflowCompleted(event: WorkflowCompleted): void {
  const w = WorkflowCreated.load(event.params.workflowId.toHexString());
  if (w == null) return;
  w.status = 1;
  w.totalPaid = event.params.totalPaid;
  w.save();
}

export function handleWorkflowFailed(event: WorkflowFailed): void {
  const w = WorkflowCreated.load(event.params.workflowId.toHexString());
  if (w == null) return;
  w.status = 2;
  w.save();
}

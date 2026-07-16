import { SubTaskCreated as SubTaskCreatedEvent, SubTaskAssigned, SubTaskCompleted } from "../generated/AgentComposability/AgentComposability";
import { SubTaskCreated } from "../generated/schema";

export function handleSubTaskCreated(event: SubTaskCreatedEvent): void {
  const e = new SubTaskCreated(event.params.subTaskId.toHexString());
  e.subTaskId = event.params.subTaskId;
  e.parentTaskId = event.params.parentTaskId;
  e.parentAgentId = event.params.parentAgentId;
  e.reward = event.params.reward;
  e.deadline = event.params.deadline;
  e.status = 0;
  e.createdAt = event.block.timestamp;
  e.transactionHash = event.transaction.hash;
  e.save();
}

export function handleSubTaskAssigned(event: SubTaskAssigned): void {
  const e = SubTaskCreated.load(event.params.subTaskId.toHexString());
  if (e == null) return;
  e.subAgentId = event.params.subAgentId;
  e.status = 1;
  e.save();
}

export function handleSubTaskCompleted(event: SubTaskCompleted): void {
  const e = SubTaskCreated.load(event.params.subTaskId.toHexString());
  if (e == null) return;
  e.status = 2;
  e.payment = event.params.payment;
  e.save();
}

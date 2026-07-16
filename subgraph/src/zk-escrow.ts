import { EscrowCreated as EscrowCreatedEvent, CommitmentSet, EscrowReleased, EscrowRefunded } from "../generated/ZKEscrow/ZKEscrow";
import { EscrowCreated } from "../generated/schema";

export function handleEscrowCreated(event: EscrowCreatedEvent): void {
  const e = new EscrowCreated(event.params.escrowId.toHexString());
  e.escrowId = event.params.escrowId;
  e.taskId = event.params.taskId;
  e.client = event.params.client;
  e.amount = event.params.amount;
  e.deadline = event.params.deadline;
  e.status = 0;
  e.hasCommitment = false;
  e.createdAt = event.block.timestamp;
  e.transactionHash = event.transaction.hash;
  e.save();
}

export function handleCommitmentSet(event: CommitmentSet): void {
  const e = EscrowCreated.load(event.params.escrowId.toHexString());
  if (e == null) return;
  e.hasCommitment = true;
  e.save();
}

export function handleEscrowReleased(event: EscrowReleased): void {
  const e = EscrowCreated.load(event.params.escrowId.toHexString());
  if (e == null) return;
  e.status = 1;
  e.agentWallet = event.params.agentWallet;
  e.settledAt = event.block.timestamp;
  e.save();
}

export function handleEscrowRefunded(event: EscrowRefunded): void {
  const e = EscrowCreated.load(event.params.escrowId.toHexString());
  if (e == null) return;
  e.status = 2;
  e.settledAt = event.block.timestamp;
  e.save();
}

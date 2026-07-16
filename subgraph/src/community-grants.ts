import { BigInt } from "@graphprotocol/graph-ts";
import { GrantProposed as GrantProposedEvent, GrantVoteCast, GrantApproved, GrantExecuted, GrantRejected } from "../generated/CommunityGrants/CommunityGrants";
import { GrantProposed } from "../generated/schema";

export function handleGrantProposed(event: GrantProposedEvent): void {
  const g = new GrantProposed(event.params.grantId.toHexString());
  g.grantId = event.params.grantId;
  g.title = event.params.title;
  g.recipient = event.params.recipient;
  g.amount = event.params.amount;
  g.status = 0;
  g.forVotes = BigInt.zero();
  g.againstVotes = BigInt.zero();
  g.proposedAt = event.block.timestamp;
  g.transactionHash = event.transaction.hash;
  g.save();
}

export function handleGrantVoteCast(event: GrantVoteCast): void {
  const g = GrantProposed.load(event.params.grantId.toHexString());
  if (g == null) return;
  if (event.params.support) {
    g.forVotes = g.forVotes.plus(event.params.weight);
  } else {
    g.againstVotes = g.againstVotes.plus(event.params.weight);
  }
  g.save();
}

export function handleGrantApproved(event: GrantApproved): void {
  const g = GrantProposed.load(event.params.grantId.toHexString());
  if (g == null) return;
  g.status = 2;
  g.save();
}

export function handleGrantExecuted(event: GrantExecuted): void {
  const g = GrantProposed.load(event.params.grantId.toHexString());
  if (g == null) return;
  g.status = 3;
  g.save();
}

export function handleGrantRejected(event: GrantRejected): void {
  const g = GrantProposed.load(event.params.grantId.toHexString());
  if (g == null) return;
  g.status = 4;
  g.save();
}

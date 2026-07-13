"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useParams } from "next/navigation";
import { formatEther } from "viem";
import { useAccount } from "wagmi";
import { ArrowLeft, AlertTriangle, Undo2 } from "lucide-react";
import { Reveal } from "@/components/fx/Reveal";
import { Field, InfoRow, StepTracker } from "@/components/ui/Primitives";
import { EscrowStatusBadge } from "@/components/escrow/EscrowStatusCard";
import { ProofSubmitForm } from "@/components/escrow/ProofSubmitForm";
import { TxButton } from "@/components/wallet/TxButton";
import {
  useEscrow,
  useSetCommitment,
  useRefundAfterDeadline,
  useRaiseEscrowDispute,
} from "@/lib/hooks/useZKEscrow";
import { shortenAddr } from "@/lib/contracts";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;
const ZERO32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

export default function EscrowDetailPage() {
  const params = useParams<{ id: string }>();
  const escrowId = (params?.id ?? "") as `0x${string}`;
  const validId = HEX32.test(escrowId);

  const { address } = useAccount();
  const { data: escrow, isLoading, refetch } = useEscrow(validId ? escrowId : undefined);

  const setCommitmentTx = useSetCommitment();
  const refundTx = useRefundAfterDeadline();
  const disputeTx = useRaiseEscrowDispute();
  const [commitmentInput, setCommitmentInput] = useState("");

  const e = escrow as
    | {
        escrowId: `0x${string}`;
        taskId: `0x${string}`;
        client: `0x${string}`;
        agentWallet: `0x${string}`;
        amount: bigint;
        commitment: `0x${string}`;
        deadline: bigint;
        createdAt: bigint;
        releasedAt: bigint;
        status: number;
        proofId: `0x${string}`;
      }
    | undefined;

  const exists = e && e.escrowId !== ZERO32;
  const hasCommitment = exists && e!.commitment !== ZERO32;
  const isClient = exists && address?.toLowerCase() === e!.client.toLowerCase();
  const deadlinePassed = exists && Number(e!.deadline) * 1000 < Date.now();

  const step = useMemo(() => {
    if (!exists) return 0;
    if (e!.status === 1) return 3; // released
    if (hasCommitment) return 2; // waiting on proof
    return 1; // waiting on commitment
  }, [exists, e, hasCommitment]);

  if (!validId) {
    return (
      <div className="ag-section py-24 text-center">
        <h1 className="ag-h1 text-3xl">Invalid escrow ID</h1>
        <p className="text-text-secondary mt-3">Escrow IDs are 32-byte hex strings.</p>
        <Link href="/escrow" className="btn-secondary mt-8 inline-flex"><ArrowLeft size={15} /> Back to escrows</Link>
      </div>
    );
  }

  return (
    <div className="ag-section py-12 space-y-8">
      <Reveal>
        <Link href="/escrow" className="btn-ghost -ml-4"><ArrowLeft size={15} /> All escrows</Link>
        <div className="mt-4 flex flex-wrap items-center gap-4">
          <h1 className="ag-h1 text-3xl md:text-4xl">Escrow</h1>
          {exists && <EscrowStatusBadge status={e!.status} />}
        </div>
        <p className="address mt-2">{escrowId}</p>
      </Reveal>

      {isLoading && <div className="card p-12 text-center text-text-secondary">Reading escrow from chain…</div>}

      {!isLoading && !exists && (
        <div className="card p-12 text-center">
          <h3 className="font-display font-bold text-xl text-bone">No escrow found</h3>
          <p className="text-sm text-text-secondary mt-2">Nothing is stored at this ID on Sepolia.</p>
        </div>
      )}

      {exists && (
        <>
          <Reveal className="ag-panel p-6">
            <StepTracker steps={["Funded", "Committed", "Proof", "Paid"]} current={step} />
          </Reveal>

          <div className="grid lg:grid-cols-2 gap-8 items-start">
            <Reveal variant="left" className="ag-panel p-6">
              <h3 className="font-display font-bold text-lg text-bone mb-2">Details</h3>
              <InfoRow label="Amount">{Number(formatEther(e!.amount)).toFixed(4)} ETH</InfoRow>
              <InfoRow label="Task">
                <Link href={`/tasks/${e!.taskId}`} className="text-gold hover:underline font-mono text-xs">
                  {shortenAddr(e!.taskId)}
                </Link>
              </InfoRow>
              <InfoRow label="Client"><span className="font-mono text-xs">{shortenAddr(e!.client)}</span></InfoRow>
              <InfoRow label="Agent wallet"><span className="font-mono text-xs">{shortenAddr(e!.agentWallet)}</span></InfoRow>
              <InfoRow label="Deadline">
                {new Date(Number(e!.deadline) * 1000).toLocaleString()}
                {deadlinePassed && <span className="text-blood ml-2 text-xs">passed</span>}
              </InfoRow>
              <InfoRow label="Commitment">
                {hasCommitment ? <span className="font-mono text-xs text-jade">{shortenAddr(e!.commitment)}</span> : <span className="text-text-muted">not set</span>}
              </InfoRow>
              {e!.releasedAt > BigInt(0) && (
                <InfoRow label="Released">{new Date(Number(e!.releasedAt) * 1000).toLocaleString()}</InfoRow>
              )}

              {/* client actions */}
              {e!.status === 0 && (
                <div className="mt-6 space-y-4">
                  {!hasCommitment && (
                    <div className="space-y-3">
                      <Field label="Set commitment (client)" hint="From the commitment helper on the create page.">
                        <input className="input font-mono" placeholder="0x…" value={commitmentInput} onChange={(ev) => setCommitmentInput(ev.target.value.trim())} />
                      </Field>
                      <TxButton
                        onClick={() => setCommitmentTx.setCommitment(escrowId, commitmentInput as `0x${string}`)}
                        disabled={!HEX32.test(commitmentInput) || !isClient}
                        isPending={setCommitmentTx.isPending}
                        isConfirming={setCommitmentTx.isConfirming}
                        isSuccess={setCommitmentTx.isSuccess}
                        className="btn-primary w-full"
                        successText="Commitment set ✓"
                      >
                        {isClient ? "Set commitment" : "Only the client can commit"}
                      </TxButton>
                    </div>
                  )}

                  <div className="flex flex-wrap gap-3">
                    <TxButton
                      onClick={() => refundTx.refund(escrowId)}
                      disabled={!deadlinePassed}
                      isPending={refundTx.isPending}
                      isConfirming={refundTx.isConfirming}
                      isSuccess={refundTx.isSuccess}
                      className="btn-secondary"
                      successText="Refunded ✓"
                    >
                      <Undo2 size={15} /> {deadlinePassed ? "Refund after deadline" : "Refund unlocks after deadline"}
                    </TxButton>
                    <TxButton
                      onClick={() => disputeTx.raiseDispute(escrowId)}
                      isPending={disputeTx.isPending}
                      isConfirming={disputeTx.isConfirming}
                      isSuccess={disputeTx.isSuccess}
                      className="btn-secondary"
                      successText="Dispute raised"
                    >
                      <AlertTriangle size={15} /> Raise dispute
                    </TxButton>
                  </div>
                  {(setCommitmentTx.isSuccess || refundTx.isSuccess) && (
                    <button className="btn-ghost text-xs" onClick={() => refetch()}>Refresh state</button>
                  )}
                </div>
              )}
            </Reveal>

            <Reveal variant="right" delay={120}>
              {e!.status === 0 && hasCommitment ? (
                <ProofSubmitForm escrowId={escrowId} />
              ) : (
                <div className="ag-panel p-8 text-center">
                  <h3 className="font-display font-bold text-lg text-bone">
                    {e!.status === 1 ? "Paid out by proof" : e!.status === 2 ? "Refunded to client" : e!.status === 3 ? "In dispute" : "Waiting for commitment"}
                  </h3>
                  <p className="text-sm text-text-secondary mt-2 leading-relaxed">
                    {e!.status === 0
                      ? "The proof form unlocks once the client sets the result commitment."
                      : e!.status === 1
                        ? "A valid Groth16 proof released this escrow to the agent's wallet."
                        : e!.status === 2
                          ? "The deadline passed without a valid proof, and the deposit returned to the client."
                          : "This escrow was flagged for dispute resolution."}
                  </p>
                </div>
              )}
            </Reveal>
          </div>
        </>
      )}
    </div>
  );
}

"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { formatEther } from "viem";
import { ArrowLeft, XCircle } from "lucide-react";
import { Reveal } from "@/components/fx/Reveal";
import { InfoRow, Pill } from "@/components/ui/Primitives";
import { TxButton } from "@/components/wallet/TxButton";
import { StageRow } from "@/components/workflows/StageRow";
import {
  useWorkflow,
  useCancelWorkflow,
  WORKFLOW_TYPE_LABELS,
  WORKFLOW_STATUS_LABELS,
} from "@/lib/hooks/useWorkflowCoordinator";
import { shortenAddr } from "@/lib/contracts";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;
const ZERO32 = "0x0000000000000000000000000000000000000000000000000000000000000000";
const STATUS_TONES = ["gold", "jade", "blood", "muted"] as const;

export default function WorkflowDetailPage() {
  const params = useParams<{ id: string }>();
  const workflowId = (params?.id ?? "") as `0x${string}`;
  const validId = HEX32.test(workflowId);

  const { data, isLoading, refetch } = useWorkflow(validId ? workflowId : undefined);
  const cancelTx = useCancelWorkflow();

  const w = data as
    | {
        workflowId: `0x${string}`;
        parentTaskId: `0x${string}`;
        client: `0x${string}`;
        workflowType: number;
        status: number;
        totalStages: bigint;
        completedStages: bigint;
        totalBudget: bigint;
        createdAt: bigint;
        completedAt: bigint;
        aggregatorAgentId: bigint;
      }
    | undefined;

  const exists = w && w.workflowId !== ZERO32;
  const stageCount = exists ? Number(w!.totalStages) : 0;
  const progress = exists && stageCount > 0 ? Number(w!.completedStages) / stageCount : 0;

  if (!validId) {
    return (
      <div className="ag-section py-24 text-center">
        <h1 className="ag-h1 text-3xl">Invalid workflow ID</h1>
        <Link href="/workflows" className="btn-secondary mt-8 inline-flex"><ArrowLeft size={15} /> Back to workflows</Link>
      </div>
    );
  }

  return (
    <div className="ag-section py-12 space-y-8">
      <Reveal>
        <Link href="/workflows" className="btn-ghost -ml-4"><ArrowLeft size={15} /> All workflows</Link>
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <h1 className="ag-h1 text-3xl md:text-4xl">Workflow</h1>
          {exists && (
            <>
              <Pill tone={w!.workflowType === 0 ? "gold" : "sky"}>{WORKFLOW_TYPE_LABELS[w!.workflowType]}</Pill>
              <Pill tone={STATUS_TONES[w!.status] ?? "muted"}>{WORKFLOW_STATUS_LABELS[w!.status]}</Pill>
            </>
          )}
        </div>
        <p className="address mt-2">{workflowId}</p>
      </Reveal>

      {isLoading && <div className="card p-12 text-center text-text-secondary">Reading workflow…</div>}
      {!isLoading && !exists && (
        <div className="card p-12 text-center">
          <h3 className="font-display font-bold text-xl text-bone">No workflow found at this ID</h3>
        </div>
      )}

      {exists && (
        <>
          <div className="grid lg:grid-cols-[1fr_1.6fr] gap-8 items-start">
            <Reveal variant="left" className="ag-panel p-6">
              <h3 className="font-display font-bold text-lg text-bone mb-2">Overview</h3>
              <InfoRow label="Client"><span className="font-mono text-xs">{shortenAddr(w!.client)}</span></InfoRow>
              <InfoRow label="Parent task"><span className="font-mono text-xs">{shortenAddr(w!.parentTaskId)}</span></InfoRow>
              <InfoRow label="Total budget">{Number(formatEther(w!.totalBudget)).toFixed(4)} ETH</InfoRow>
              <InfoRow label="Stages">{w!.completedStages.toString()} / {w!.totalStages.toString()} complete</InfoRow>
              {w!.workflowType === 1 && <InfoRow label="Aggregator">Agent #{w!.aggregatorAgentId.toString()}</InfoRow>}
              <InfoRow label="Created">{new Date(Number(w!.createdAt) * 1000).toLocaleString()}</InfoRow>

              <div className="mt-5">
                <div className="flex justify-between text-[11px] font-mono text-text-muted mb-1.5">
                  <span>PROGRESS</span>
                  <span className="text-gold">{Math.round(progress * 100)}%</span>
                </div>
                <div className="rep-bar h-2">
                  <div className="h-full transition-all duration-700" style={{ width: `${progress * 100}%`, background: "var(--ag-flare)" }} />
                </div>
              </div>

              {w!.status === 0 && (
                <TxButton
                  onClick={() => cancelTx.cancelWorkflow(workflowId)}
                  isPending={cancelTx.isPending}
                  isConfirming={cancelTx.isConfirming}
                  isSuccess={cancelTx.isSuccess}
                  className="btn-secondary w-full mt-6"
                  successText="Cancelled ✓"
                >
                  <XCircle size={15} /> Cancel workflow
                </TxButton>
              )}
              {cancelTx.isSuccess && <button className="btn-ghost text-xs mt-2" onClick={() => refetch()}>Refresh</button>}
            </Reveal>

            <Reveal variant="right" delay={120} className="space-y-3">
              <h3 className="font-display font-bold text-lg text-bone">Stages</h3>
              {Array.from({ length: stageCount }, (_, i) => (
                <StageRow key={i} workflowId={workflowId} index={i} />
              ))}
            </Reveal>
          </div>
        </>
      )}
    </div>
  );
}

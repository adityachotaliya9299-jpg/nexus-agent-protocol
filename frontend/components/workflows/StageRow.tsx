"use client";

import { useState } from "react";
import { formatEther } from "viem";
import { Pill, Field } from "@/components/ui/Primitives";
import { TxButton } from "@/components/wallet/TxButton";
import { useStage, useSubmitStageResult, STAGE_STATUS_LABELS } from "@/lib/hooks/useWorkflowCoordinator";

const TONES = ["muted", "gold", "jade", "blood", "sky"] as const;

/** One stage of a workflow with inline result submission when active. */
export function StageRow({ workflowId, index }: { workflowId: `0x${string}`; index: number }) {
  const { data, refetch } = useStage(workflowId, index);
  const { submitStageResult, isPending, isConfirming, isSuccess } = useSubmitStageResult();
  const [outputURI, setOutputURI] = useState("");

  const s = data as
    | { stageIndex: bigint; assignedAgentId: bigint; inputURI: string; outputURI: string; reward: bigint; deadline: bigint; status: number; proofId: `0x${string}` }
    | undefined;

  if (!s) return <div className="card h-20 animate-pulse" />;

  const active = s.status === 1;

  return (
    <div className={`card p-5 ${active ? "border-gold/40 shadow-[0_0_24px_rgba(242,169,59,0.08)]" : ""}`}>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-4">
          <span
            className={`w-9 h-9 rounded-xl flex items-center justify-center font-mono text-sm border ${
              s.status === 2 ? "bg-jade/15 border-jade/40 text-jade" : active ? "bg-gold/15 border-gold/50 text-gold" : "bg-raised border-border text-text-muted"
            }`}
          >
            {s.status === 2 ? "✓" : index + 1}
          </span>
          <div>
            <div className="font-display font-semibold text-bone">Stage {index + 1} · Agent #{s.assignedAgentId.toString()}</div>
            <div className="text-xs text-text-muted font-mono mt-0.5">
              {Number(formatEther(s.reward)).toFixed(4)} ETH · due {new Date(Number(s.deadline) * 1000).toLocaleDateString()}
            </div>
          </div>
        </div>
        <Pill tone={TONES[s.status] ?? "muted"}>{STAGE_STATUS_LABELS[s.status] ?? "?"}</Pill>
      </div>

      {s.inputURI && <p className="mt-3 text-xs text-text-secondary font-mono break-all">in: {s.inputURI}</p>}
      {s.outputURI && <p className="mt-1 text-xs text-jade font-mono break-all">out: {s.outputURI}</p>}

      {active && (
        <div className="mt-4 grid sm:grid-cols-[1fr_auto] gap-3 items-end">
          <Field label="Result URI (assigned agent)">
            <input className="input" placeholder="ipfs://… or ar://…" value={outputURI} onChange={(e) => setOutputURI(e.target.value)} />
          </Field>
          <TxButton
            onClick={() => submitStageResult(workflowId, index, outputURI)}
            disabled={!outputURI}
            isPending={isPending}
            isConfirming={isConfirming}
            isSuccess={isSuccess}
            successText="Submitted ✓"
          >
            Submit
          </TxButton>
        </div>
      )}
      {isSuccess && <button className="btn-ghost text-xs mt-2" onClick={() => refetch()}>Refresh</button>}
    </div>
  );
}

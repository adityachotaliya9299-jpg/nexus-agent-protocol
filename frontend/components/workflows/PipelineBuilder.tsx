"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { Plus, Trash2, ArrowDown } from "lucide-react";
import { Field } from "@/components/ui/Primitives";
import { TxButton } from "@/components/wallet/TxButton";
import { useCreatePipeline, type PipelineStageInput } from "@/lib/hooks/useWorkflowCoordinator";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;

interface StageRow {
  agentId: string;
  budgetEth: string;
  deadline: string;
  inputURI: string;
}

const EMPTY: StageRow = { agentId: "", budgetEth: "", deadline: "", inputURI: "" };

export function PipelineBuilder() {
  const { isConnected } = useAccount();
  const { createPipeline, isPending, isConfirming, isSuccess, error } = useCreatePipeline();

  const [parentTaskId, setParentTaskId] = useState("");
  const [stages, setStages] = useState<StageRow[]>([{ ...EMPTY }, { ...EMPTY }]);

  const totalBudget = stages.reduce((s, r) => s + (parseFloat(r.budgetEth) || 0), 0);
  const valid =
    HEX32.test(parentTaskId) &&
    stages.length >= 2 &&
    stages.every((s) => Number(s.agentId) > 0 && parseFloat(s.budgetEth || "0") > 0 && !!s.deadline);

  const update = (i: number, patch: Partial<StageRow>) =>
    setStages(stages.map((s, j) => (j === i ? { ...s, ...patch } : s)));

  const submit = () => {
    const input: PipelineStageInput[] = stages.map((s) => ({
      agentId: Number(s.agentId),
      budgetEth: s.budgetEth,
      deadline: Math.floor(new Date(s.deadline).getTime() / 1000),
      inputURI: s.inputURI || "",
    }));
    createPipeline(parentTaskId as `0x${string}`, input);
  };

  return (
    <div className="space-y-5">
      <Field label="Parent task ID (bytes32)">
        <input className="input font-mono" placeholder="0x…" value={parentTaskId} onChange={(e) => setParentTaskId(e.target.value.trim())} />
      </Field>

      <div className="space-y-3">
        {stages.map((stage, i) => (
          <div key={i}>
            <div className="ag-panel p-5 border-l-2 border-l-gold/60">
              <div className="flex items-center justify-between mb-4">
                <span className="font-mono text-xs text-gold tracking-[0.25em]">STAGE {String(i + 1).padStart(2, "0")}</span>
                <button className="btn-ghost !px-2 !py-1" onClick={() => setStages(stages.filter((_, j) => j !== i))} disabled={stages.length <= 2} aria-label="Remove stage">
                  <Trash2 size={14} />
                </button>
              </div>
              <div className="grid sm:grid-cols-3 gap-3">
                <input className="input" type="number" min="1" placeholder="Agent ID" value={stage.agentId} onChange={(e) => update(i, { agentId: e.target.value })} />
                <input className="input" type="number" min="0" step="0.001" placeholder="Budget (ETH)" value={stage.budgetEth} onChange={(e) => update(i, { budgetEth: e.target.value })} />
                <input className="input" type="datetime-local" value={stage.deadline} onChange={(e) => update(i, { deadline: e.target.value })} />
              </div>
              <input className="input mt-3" placeholder={i === 0 ? "Input URI (task brief)" : "Input URI (optional — defaults to previous stage output)"} value={stage.inputURI} onChange={(e) => update(i, { inputURI: e.target.value })} />
            </div>
            {i < stages.length - 1 && (
              <div className="flex justify-center py-1.5 text-gold/50"><ArrowDown size={16} /></div>
            )}
          </div>
        ))}
      </div>

      <div className="flex items-center justify-between">
        <button className="btn-ghost text-xs" onClick={() => setStages([...stages, { ...EMPTY }])}>
          <Plus size={14} /> Add stage
        </button>
        <span className="font-mono text-xs text-text-secondary">Total locked: <span className="text-gold">{totalBudget.toFixed(4)} ETH</span></span>
      </div>

      <TxButton
        onClick={submit}
        disabled={!isConnected || !valid}
        isPending={isPending}
        isConfirming={isConfirming}
        isSuccess={isSuccess}
        className="btn-primary w-full"
        successText="Pipeline launched ✓"
      >
        {isConnected ? `Launch pipeline (${stages.length} stages)` : "Connect wallet first"}
      </TxButton>
      {error && <p className="text-xs text-blood break-all">{error.message.split("\n")[0]}</p>}
    </div>
  );
}

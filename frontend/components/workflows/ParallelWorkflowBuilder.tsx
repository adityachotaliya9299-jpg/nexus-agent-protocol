"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { Plus, Trash2, GitMerge } from "lucide-react";
import { Field } from "@/components/ui/Primitives";
import { TxButton } from "@/components/wallet/TxButton";
import { useCreateParallel } from "@/lib/hooks/useWorkflowCoordinator";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;

interface BranchRow {
  agentId: string;
  budgetEth: string;
  deadline: string;
}

const EMPTY: BranchRow = { agentId: "", budgetEth: "", deadline: "" };

export function ParallelWorkflowBuilder() {
  const { isConnected } = useAccount();
  const { createParallel, isPending, isConfirming, isSuccess, error } = useCreateParallel();

  const [parentTaskId, setParentTaskId] = useState("");
  const [branches, setBranches] = useState<BranchRow[]>([{ ...EMPTY }, { ...EMPTY }]);
  const [aggregatorId, setAggregatorId] = useState("");
  const [aggregatorBudget, setAggregatorBudget] = useState("");

  const totalBudget =
    branches.reduce((s, r) => s + (parseFloat(r.budgetEth) || 0), 0) + (parseFloat(aggregatorBudget) || 0);
  const valid =
    HEX32.test(parentTaskId) &&
    branches.length >= 2 &&
    branches.every((b) => Number(b.agentId) > 0 && parseFloat(b.budgetEth || "0") > 0 && !!b.deadline) &&
    Number(aggregatorId) > 0 &&
    parseFloat(aggregatorBudget || "0") > 0;

  const update = (i: number, patch: Partial<BranchRow>) =>
    setBranches(branches.map((b, j) => (j === i ? { ...b, ...patch } : b)));

  const submit = () => {
    createParallel(parentTaskId as `0x${string}`, {
      agentIds: branches.map((b) => Number(b.agentId)),
      budgetsEth: branches.map((b) => b.budgetEth),
      deadlines: branches.map((b) => Math.floor(new Date(b.deadline).getTime() / 1000)),
      aggregatorAgentId: Number(aggregatorId),
      aggregatorBudgetEth: aggregatorBudget,
    });
  };

  return (
    <div className="space-y-5">
      <Field label="Parent task ID (bytes32)">
        <input className="input font-mono" placeholder="0x…" value={parentTaskId} onChange={(e) => setParentTaskId(e.target.value.trim())} />
      </Field>

      <div className="grid sm:grid-cols-2 gap-3">
        {branches.map((b, i) => (
          <div key={i} className="ag-panel p-5 border-t-2 border-t-sky/60">
            <div className="flex items-center justify-between mb-4">
              <span className="font-mono text-xs text-sky tracking-[0.25em]">BRANCH {String(i + 1).padStart(2, "0")}</span>
              <button className="btn-ghost !px-2 !py-1" onClick={() => setBranches(branches.filter((_, j) => j !== i))} disabled={branches.length <= 2} aria-label="Remove branch">
                <Trash2 size={14} />
              </button>
            </div>
            <div className="space-y-3">
              <input className="input" type="number" min="1" placeholder="Agent ID" value={b.agentId} onChange={(e) => update(i, { agentId: e.target.value })} />
              <input className="input" type="number" min="0" step="0.001" placeholder="Budget (ETH)" value={b.budgetEth} onChange={(e) => update(i, { budgetEth: e.target.value })} />
              <input className="input" type="datetime-local" value={b.deadline} onChange={(e) => update(i, { deadline: e.target.value })} />
            </div>
          </div>
        ))}
      </div>

      <button className="btn-ghost text-xs" onClick={() => setBranches([...branches, { ...EMPTY }])}>
        <Plus size={14} /> Add branch
      </button>

      <div className="ag-panel p-5 border-t-2 border-t-ember/70">
        <div className="flex items-center gap-2 mb-4">
          <GitMerge size={15} className="text-ember" />
          <span className="font-mono text-xs text-ember tracking-[0.25em]">AGGREGATOR</span>
        </div>
        <p className="text-xs text-text-muted mb-3">Merges all branch outputs. Paid only after the merged result lands.</p>
        <div className="grid sm:grid-cols-2 gap-3">
          <input className="input" type="number" min="1" placeholder="Aggregator agent ID" value={aggregatorId} onChange={(e) => setAggregatorId(e.target.value)} />
          <input className="input" type="number" min="0" step="0.001" placeholder="Aggregator budget (ETH)" value={aggregatorBudget} onChange={(e) => setAggregatorBudget(e.target.value)} />
        </div>
      </div>

      <div className="text-right font-mono text-xs text-text-secondary">
        Total locked: <span className="text-gold">{totalBudget.toFixed(4)} ETH</span>
      </div>

      <TxButton
        onClick={submit}
        disabled={!isConnected || !valid}
        isPending={isPending}
        isConfirming={isConfirming}
        isSuccess={isSuccess}
        className="btn-primary w-full"
        successText="Swarm dispatched ✓"
      >
        {isConnected ? `Dispatch parallel swarm (${branches.length} + aggregator)` : "Connect wallet first"}
      </TxButton>
      {error && <p className="text-xs text-blood break-all">{error.message.split("\n")[0]}</p>}
    </div>
  );
}

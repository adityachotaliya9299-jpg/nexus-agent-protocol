"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { Plus, Trash2 } from "lucide-react";
import { Field } from "@/components/ui/Primitives";
import { TxButton } from "@/components/wallet/TxButton";
import { useCreateDAO } from "@/lib/hooks/useAgentDAO";
import { RevenueSplitPie } from "./RevenueSplitPie";

interface MemberRow {
  agentId: string;
  splitBps: string;
}

export function CreateDAOForm() {
  const { isConnected } = useAccount();
  const { createDAO, isPending, isConfirming, isSuccess, error } = useCreateDAO();

  const [name, setName] = useState("");
  const [rows, setRows] = useState<MemberRow[]>([
    { agentId: "", splitBps: "5000" },
    { agentId: "", splitBps: "5000" },
  ]);

  const totalBps = rows.reduce((s, r) => s + (Number(r.splitBps) || 0), 0);
  const valid =
    name.length > 1 &&
    rows.length > 0 &&
    rows.every((r) => Number(r.agentId) > 0 && Number(r.splitBps) > 0) &&
    totalBps === 10000;

  const update = (i: number, patch: Partial<MemberRow>) =>
    setRows(rows.map((r, j) => (j === i ? { ...r, ...patch } : r)));

  return (
    <div className="ag-panel p-6 space-y-5">
      <div>
        <h3 className="font-display font-bold text-lg text-bone">Found a DAO</h3>
        <p className="text-xs text-text-muted mt-1">
          Splits are basis points and must sum to exactly 10,000 (100%). Revenue distributes automatically.
        </p>
      </div>

      <Field label="DAO name">
        <input className="input" placeholder="The Audit Guild" value={name} onChange={(e) => setName(e.target.value)} />
      </Field>

      <div>
        <span className="label">Members & splits</span>
        <div className="mt-2 space-y-2">
          {rows.map((row, i) => (
            <div key={i} className="grid grid-cols-[1fr_1fr_auto] gap-2">
              <input
                className="input"
                type="number"
                min="1"
                placeholder={`Agent ID #${i + 1}`}
                value={row.agentId}
                onChange={(e) => update(i, { agentId: e.target.value })}
              />
              <input
                className="input"
                type="number"
                min="1"
                max="10000"
                placeholder="Split bps"
                value={row.splitBps}
                onChange={(e) => update(i, { splitBps: e.target.value })}
              />
              <button
                type="button"
                className="btn-ghost px-3"
                onClick={() => setRows(rows.filter((_, j) => j !== i))}
                disabled={rows.length <= 1}
                aria-label="Remove member"
              >
                <Trash2 size={15} />
              </button>
            </div>
          ))}
        </div>
        <div className="mt-3 flex items-center justify-between">
          <button type="button" className="btn-ghost text-xs" onClick={() => setRows([...rows, { agentId: "", splitBps: "" }])}>
            <Plus size={14} /> Add member
          </button>
          <span className={`font-mono text-xs ${totalBps === 10000 ? "text-jade" : "text-blood"}`}>
            Σ {totalBps.toLocaleString()} / 10,000 bps
          </span>
        </div>
      </div>

      {rows.some((r) => Number(r.splitBps) > 0) && (
        <RevenueSplitPie
          size={150}
          slices={rows
            .filter((r) => Number(r.splitBps) > 0)
            .map((r, i) => ({ label: r.agentId ? `Agent #${r.agentId}` : `Member ${i + 1}`, bps: Number(r.splitBps) }))}
        />
      )}

      <TxButton
        onClick={() => createDAO(name, rows.map((r) => Number(r.agentId)), rows.map((r) => Number(r.splitBps)))}
        disabled={!isConnected || !valid}
        isPending={isPending}
        isConfirming={isConfirming}
        isSuccess={isSuccess}
        className="btn-primary w-full"
        successText="DAO founded ✓"
      >
        {isConnected ? "Create DAO" : "Connect wallet first"}
      </TxButton>

      {error && <p className="text-xs text-blood break-all">{error.message.split("\n")[0]}</p>}
      {isSuccess && (
        <p className="text-xs text-jade">
          Founded. The DAOCreated event in your transaction carries the daoId — open it via the lookup panel.
        </p>
      )}
    </div>
  );
}

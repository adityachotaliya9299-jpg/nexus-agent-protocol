"use client";

import { useState } from "react";
import { formatEther } from "viem";
import { Handshake } from "lucide-react";
import { Reveal } from "@/components/fx/Reveal";
import { Field, InfoRow } from "@/components/ui/Primitives";
import { useAgentRelationship } from "@/lib/hooks/useAgentComposability";

/** Shows the on-chain collaboration history between two agents. */
export function RelationshipCard() {
  const [parentId, setParentId] = useState("");
  const [subId, setSubId] = useState("");
  const [query, setQuery] = useState<{ p: number; s: number } | undefined>();

  const { data, isLoading } = useAgentRelationship(query?.p, query?.s);

  const rel = data as
    | {
        parentAgentId: bigint;
        subAgentId: bigint;
        totalSubTasksGiven: bigint;
        totalSubTasksCompleted: bigint;
        totalEthPaid: bigint;
        firstCollabAt: bigint;
        lastCollabAt: bigint;
      }
    | undefined;

  const hasHistory = rel && rel.totalSubTasksGiven > BigInt(0);

  return (
    <Reveal className="ag-panel p-6">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-ember/10 border border-ember/25 flex items-center justify-center">
          <Handshake size={18} className="text-ember" />
        </div>
        <div>
          <h3 className="font-display font-bold text-lg text-bone">Collaboration history</h3>
          <p className="text-xs text-text-muted">Trustless track record between any two agents.</p>
        </div>
      </div>

      <div className="mt-5 grid grid-cols-[1fr_1fr_auto] gap-3 items-end">
        <Field label="Parent agent">
          <input className="input" type="number" min="1" placeholder="#" value={parentId} onChange={(e) => setParentId(e.target.value)} />
        </Field>
        <Field label="Sub-agent">
          <input className="input" type="number" min="1" placeholder="#" value={subId} onChange={(e) => setSubId(e.target.value)} />
        </Field>
        <button
          className={`btn-secondary ${!parentId || !subId ? "opacity-50 pointer-events-none" : ""}`}
          onClick={() => setQuery({ p: Number(parentId), s: Number(subId) })}
        >
          Check
        </button>
      </div>

      {query && (
        <div className="mt-5">
          {isLoading ? (
            <p className="text-sm text-text-secondary">Reading chain…</p>
          ) : hasHistory ? (
            <div>
              <InfoRow label="Sub-tasks given">{rel!.totalSubTasksGiven.toString()}</InfoRow>
              <InfoRow label="Completed">{rel!.totalSubTasksCompleted.toString()}</InfoRow>
              <InfoRow label="ETH paid">{Number(formatEther(rel!.totalEthPaid)).toFixed(4)} ETH</InfoRow>
              <InfoRow label="First collab">{new Date(Number(rel!.firstCollabAt) * 1000).toLocaleDateString()}</InfoRow>
              <InfoRow label="Latest collab">{new Date(Number(rel!.lastCollabAt) * 1000).toLocaleDateString()}</InfoRow>
            </div>
          ) : (
            <p className="text-sm text-text-muted">
              No collaboration between agent #{query.p} and agent #{query.s} yet.
            </p>
          )}
        </div>
      )}
    </Reveal>
  );
}

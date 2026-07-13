"use client";

import { useEffect } from "react";
import { useDAOMember } from "@/lib/hooks/useAgentDAO";
import { shortenAddr } from "@/lib/contracts";

/** Single DAO member line; reports its split upward for the pie chart. */
export function MemberRow({
  daoId,
  agentId,
  onSplit,
}: {
  daoId: `0x${string}`;
  agentId: number;
  onSplit?: (bps: number) => void;
}) {
  const { data } = useDAOMember(daoId, agentId);
  const m = data as
    | { agentId: bigint; owner: `0x${string}`; splitBps: bigint; joinedAt: bigint; isActive: boolean }
    | undefined;

  useEffect(() => {
    if (m && onSplit) onSplit(Number(m.splitBps));
  }, [m, onSplit]);

  return (
    <div className="flex items-center justify-between gap-3 px-4 py-3 rounded-xl bg-raised border border-border/70">
      <div className="flex items-center gap-3">
        <span className="w-8 h-8 rounded-full bg-gold/10 border border-gold/25 text-gold font-mono text-xs flex items-center justify-center">
          #{agentId}
        </span>
        <span className="font-mono text-xs text-text-secondary">{m ? shortenAddr(m.owner) : "…"}</span>
      </div>
      <span className="font-mono text-sm text-gold">{m ? `${(Number(m.splitBps) / 100).toFixed(1)}%` : "—"}</span>
    </div>
  );
}

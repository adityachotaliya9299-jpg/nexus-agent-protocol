"use client";

import { Pill } from "@/components/ui/Primitives";
import { useContractStatus } from "@/lib/hooks/useProtocolGuard";
import { shortenAddr } from "@/lib/contracts";

export function ContractStatusRow({ name, address }: { name: string; address: `0x${string}` }) {
  const { data } = useContractStatus(address);
  const s = data as
    | { target: `0x${string}`; isPaused: boolean; pausedAt: bigint; pauseExpiresAt: bigint; pausedBy: `0x${string}`; pauseReason: string; totalPauses: bigint }
    | undefined;

  const paused = s?.isPaused ?? false;

  return (
    <div className={`flex items-center justify-between gap-3 px-4 py-3 rounded-xl border ${paused ? "border-blood/40 bg-blood/5" : "border-border/70 bg-raised"}`}>
      <div className="min-w-0">
        <div className="font-display font-semibold text-sm text-bone truncate">{name}</div>
        <div className="font-mono text-[11px] text-text-muted">{shortenAddr(address)}</div>
        {paused && s?.pauseReason && (
          <div className="text-[11px] text-blood mt-1 truncate">
            “{s.pauseReason}” · expires {new Date(Number(s.pauseExpiresAt) * 1000).toLocaleString()}
          </div>
        )}
      </div>
      <div className="flex items-center gap-2 shrink-0">
        {s && s.totalPauses > BigInt(0) && (
          <span className="font-mono text-[10px] text-text-muted">{s.totalPauses.toString()}× paused</span>
        )}
        <Pill tone={paused ? "blood" : "jade"}>{paused ? "PAUSED" : "LIVE"}</Pill>
      </div>
    </div>
  );
}

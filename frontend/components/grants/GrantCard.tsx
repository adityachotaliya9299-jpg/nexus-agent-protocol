"use client";

import Link from "next/link";
import { formatEther } from "viem";
import { ArrowUpRight } from "lucide-react";
import { Pill } from "@/components/ui/Primitives";
import { useGrant, GRANT_TYPES, GRANT_STATUS_LABELS } from "@/lib/hooks/useCommunityGrants";

const TYPE_TONES = ["ember", "gold", "sky", "orchid", "jade"] as const;
const STATUS_TONES = ["muted", "gold", "jade", "sky", "blood"] as const;

export function GrantCard({ grantId, delay = 0 }: { grantId: `0x${string}`; delay?: number }) {
  const { data } = useGrant(grantId);
  const g = data as
    | {
        grantId: `0x${string}`;
        title: string;
        recipient: `0x${string}`;
        amount: bigint;
        grantType: number;
        status: number;
        forVotes: bigint;
        againstVotes: bigint;
        votingEndsAt: bigint;
      }
    | undefined;

  if (!g) return <div className="card p-6 h-40 animate-pulse" />;

  const totalVotes = Number(g.forVotes + g.againstVotes);
  const forPct = totalVotes > 0 ? (Number(g.forVotes) / totalVotes) * 100 : 0;

  return (
    <Link
      href={`/grants/${grantId}`}
      className="card-hover p-6 block group rv"
      style={{ ["--rv-delay" as string]: `${delay}ms` }}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex flex-wrap gap-2">
          <Pill tone={TYPE_TONES[g.grantType] ?? "muted"}>{GRANT_TYPES[g.grantType] ?? "?"}</Pill>
          <Pill tone={STATUS_TONES[g.status] ?? "muted"}>{GRANT_STATUS_LABELS[g.status] ?? "?"}</Pill>
        </div>
        <ArrowUpRight size={16} className="text-text-muted group-hover:text-gold transition-colors shrink-0" />
      </div>

      <h3 className="font-display font-bold text-lg text-bone mt-4 line-clamp-2">{g.title || "Untitled grant"}</h3>
      <div className="mt-2 font-mono text-sm text-gold">{Number(formatEther(g.amount)).toFixed(4)} ETH</div>

      <div className="mt-4">
        <div className="flex justify-between text-[11px] font-mono text-text-muted mb-1.5">
          <span className="text-jade">FOR {Number(g.forVotes).toLocaleString()}</span>
          <span className="text-blood">AGAINST {Number(g.againstVotes).toLocaleString()}</span>
        </div>
        <div className="rep-bar">
          <div className="h-full bg-gradient-to-r from-jade to-jade/70 transition-all" style={{ width: `${forPct}%` }} />
        </div>
      </div>
    </Link>
  );
}

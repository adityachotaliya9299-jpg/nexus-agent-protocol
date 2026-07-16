"use client";

import Link from "next/link";
import { CheckCircle, Clock, Zap, Sparkles } from "lucide-react";
import { useReadContract, useReadContracts } from "wagmi";
import { MOCK_AGENTS, CONTRACTS, AGENT_REGISTRY_ABI, type Agent } from "@/lib/contracts";
import {
  shortAddress, repToPercent, repBarColor, repColor,
  formatEth, timeAgo, CATEGORY_LABELS, CATEGORY_COLORS,
} from "@/lib/utils";

const STATUS_CONFIG: Record<number, { label: string; color: string; icon: React.ComponentType<{ className?: string }> }> = {
  0: { label: "Inactive",  color: "text-text-secondary", icon: Clock },
  1: { label: "Active",    color: "text-emerald",        icon: CheckCircle },
  2: { label: "Busy",      color: "text-amber",          icon: Zap },
  3: { label: "Suspended", color: "text-rose",           icon: Clock },
};

function agentName(a: Agent): string {
  if (a.name) return a.name;
  const uri = a.metadataURI?.trim() ?? "";
  if (uri.startsWith("{")) {
    try { return JSON.parse(uri).name ?? `Agent #${a.agentId}`; } catch { /* not json */ }
  }
  return `Agent #${a.agentId}`;
}

function AgentCard({ agent, showcase }: { agent: Agent; showcase?: boolean }) {
  const repPct = repToPercent(agent.reputationScore);
  const status = STATUS_CONFIG[agent.status] ?? STATUS_CONFIG[0];
  const StatusIcon = status.icon;

  return (
    <Link href={`/agents/${agent.agentId}`} className="card-hover p-5 sm:p-6 flex flex-col gap-4 group cursor-pointer">
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <span className="font-mono text-[10px] text-text-muted">#{agent.agentId}</span>
            <h3 className="font-display font-semibold text-bone group-hover:text-gold transition-colors truncate">
              {agentName(agent)}
            </h3>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <span className={`badge ${CATEGORY_COLORS[agent.category]}`}>
              {CATEGORY_LABELS[agent.category]}
            </span>
            <span className={`flex items-center gap-1 text-[10px] font-mono ${status.color}`}>
              <StatusIcon className="w-3 h-3" />
              {status.label}
            </span>
            {showcase && (
              <span className="flex items-center gap-1 text-[10px] font-mono text-gold">
                <Sparkles className="w-3 h-3" /> Showcase
              </span>
            )}
          </div>
        </div>

        <div className="text-right shrink-0">
          <div className={`font-mono font-bold text-xl ${repColor(agent.reputationScore)}`}>{repPct}%</div>
          <div className="label text-[9px]">reputation</div>
        </div>
      </div>

      <div className="rep-bar">
        <div
          className={`h-full rounded-full transition-all ${repBarColor(agent.reputationScore)}`}
          style={{ width: `${repPct}%` }}
        />
      </div>

      {agent.description && (
        <p className="text-sm text-text-secondary leading-relaxed line-clamp-2">{agent.description}</p>
      )}

      {(agent.capabilities?.length ?? 0) > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {agent.capabilities!.slice(0, 3).map(cap => (
            <span key={cap} className="text-[10px] px-2 py-0.5 rounded-full font-mono border border-border bg-muted/20 text-text-secondary">
              {cap}
            </span>
          ))}
          {(agent.capabilities?.length ?? 0) > 3 && (
            <span className="text-[10px] px-2 py-0.5 rounded-full font-mono border border-border bg-muted/20 text-text-secondary">
              +{agent.capabilities!.length - 3}
            </span>
          )}
        </div>
      )}

      <div className="grid grid-cols-3 gap-2 pt-4 border-t border-border mt-auto">
        <div className="text-center">
          <div className="font-mono font-semibold text-sm text-bone">{agent.totalTasksCompleted}</div>
          <div className="label text-[9px]">Tasks</div>
        </div>
        <div className="text-center">
          <div className="font-mono font-semibold text-sm text-bone">{formatEth(agent.totalEarned, 2)} ETH</div>
          <div className="label text-[9px]">Earned</div>
        </div>
        <div className="text-center">
          <div className="font-mono text-[10px] text-text-secondary pt-0.5">
            {agent.lastActiveAt > 0 ? timeAgo(agent.lastActiveAt) : "—"}
          </div>
          <div className="label text-[9px]">Last active</div>
        </div>
      </div>
    </Link>
  );
}

export function AgentGrid() {
  const { data: totalAgents } = useReadContract({
    address: CONTRACTS.AgentRegistry,
    abi: AGENT_REGISTRY_ABI,
    functionName: "totalAgents",
  });

  const count = totalAgents ? Math.min(Number(totalAgents), 30) : 0;
  const { data: agentReads, isLoading } = useReadContracts({
    contracts: Array.from({ length: count }, (_, i) => ({
      address: CONTRACTS.AgentRegistry,
      abi: AGENT_REGISTRY_ABI as any,
      functionName: "getAgent",
      args: [BigInt(i + 1)],
    })),
    query: { enabled: count > 0 },
  });

  const liveAgents: Agent[] = (agentReads ?? [])
    .filter(r => r.status === "success")
    .map(r => {
      const a = r.result as any;
      return {
        agentId: Number(a.agentId),
        owner: a.owner,
        agentWallet: a.agentWallet,
        metadataURI: a.metadataURI,
        category: Number(a.category),
        status: Number(a.status),
        reputationScore: Number(a.reputationScore),
        totalTasksCompleted: Number(a.totalTasksCompleted),
        totalEarned: a.totalEarned as bigint,
        registeredAt: Number(a.registeredAt),
        lastActiveAt: Number(a.lastActiveAt),
      };
    })
    .filter(a => a.agentId > 0);

  const loading = totalAgents === undefined || (count > 0 && isLoading);

  return (
    <div>
      <div className="flex items-center justify-between mb-5 flex-wrap gap-2">
        <span className="font-mono text-xs text-text-secondary">
          <span className="text-bone font-medium">{liveAgents.length}</span> on-chain
          {" · "}
          <span className="text-gold font-medium">{MOCK_AGENTS.length}</span> showcase
        </span>
        <span className="font-mono text-xs text-text-muted">Live from Sepolia</span>
      </div>

      {loading && (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5 mb-5">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="card h-64 animate-pulse" />
          ))}
        </div>
      )}

      {!loading && liveAgents.length > 0 && (
        <div className="mb-10">
          <div className="flex items-center gap-2 mb-4">
            <div className="w-2 h-2 rounded-full bg-emerald pulse-dot" />
            <span className="label">Registered on Sepolia</span>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5">
            {liveAgents.map(agent => <AgentCard key={agent.agentId} agent={agent} />)}
          </div>
        </div>
      )}

      <div>
        <div className="flex items-center gap-2 mb-4">
          <Sparkles className="w-3.5 h-3.5 text-gold" />
          <span className="label">Showcase agents — what a mature economy looks like</span>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5">
          {MOCK_AGENTS.map(agent => <AgentCard key={agent.agentId} agent={agent} showcase />)}
        </div>
      </div>
    </div>
  );
}

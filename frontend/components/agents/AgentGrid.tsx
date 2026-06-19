import Link from "next/link";
import { CheckCircle, Clock, Zap } from "lucide-react";
import { MOCK_AGENTS, type Agent } from "@/lib/contracts";
import {
  shortAddress, repToPercent, repBarColor, repColor,
  formatEth, timeAgo, CATEGORY_LABELS, CATEGORY_COLORS,
} from "@/lib/utils";

const STATUS_CONFIG: Record<number, { label: string; color: string; icon: React.ComponentType<{ className?: string }> }> = {
  0: { label: "Inactive", color: "text-[#8892B0]",  icon: Clock },
  1: { label: "Active",   color: "text-emerald", icon: CheckCircle },
  2: { label: "Busy",     color: "text-amber",   icon: Zap },
  3: { label: "Suspended",color: "text-rose",    icon: Clock },
};

function AgentCard({ agent }: { agent: Agent }) {
  const repPct    = repToPercent(agent.reputationScore);
  const barColor  = repBarColor(agent.reputationScore);
  const scoreColor = repColor(agent.reputationScore);
  const status    = STATUS_CONFIG[agent.status] ?? STATUS_CONFIG[0];
  const StatusIcon = status.icon;

  return (
    <Link
      href={`/agents/${agent.agentId}`}
      className="card-hover p-6 flex flex-col gap-4 group cursor-pointer"
    >
      {/* Header row */}
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          {/* Agent ID + name */}
          <div className="flex items-center gap-2 mb-1">
            <span className="font-mono text-[10px] text-[#4A5568]">#{agent.agentId}</span>
            <h3 className="font-display font-semibold text-[#F0F4FF] group-hover:text-cyan transition-colors truncate">
              {agent.name}
            </h3>
          </div>
          {/* Category + status */}
          <div className="flex items-center gap-2">
            <span className={`badge ${CATEGORY_COLORS[agent.category]}`}>
              {CATEGORY_LABELS[agent.category]}
            </span>
            <span className={`flex items-center gap-1 text-[10px] font-mono ${status.color}`}>
              <StatusIcon className="w-3 h-3" />
              {status.label}
            </span>
          </div>
        </div>

        {/* Reputation score */}
        <div className="text-right shrink-0">
          <div className={`font-mono font-bold text-xl ${scoreColor}`}>{repPct}%</div>
          <div className="label text-[9px]">reputation</div>
        </div>
      </div>

      {/* Reputation bar */}
      <div className="rep-bar">
        <div
          className={`h-full rounded-full transition-all ${barColor}`}
          style={{ width: `${repPct}%` }}
        />
      </div>

      {/* Description */}
      <p className="text-sm text-[#8892B0] leading-relaxed line-clamp-2">
        {agent.description}
      </p>

      {/* Capabilities */}
      <div className="flex flex-wrap gap-1.5">
        {agent.capabilities?.slice(0, 3).map((cap) => (
          <span key={cap} className="badge-inactive text-[10px] px-2 py-0.5 rounded font-mono border border-[#1A2035] bg-[#2A3555]/20 text-[#8892B0]">
            {cap}
          </span>
        ))}
        {(agent.capabilities?.length ?? 0) > 3 && (
          <span className="badge-inactive text-[10px] px-2 py-0.5 rounded font-mono border border-[#1A2035] bg-[#2A3555]/20 text-[#8892B0]">
            +{(agent.capabilities?.length ?? 0) - 3}
          </span>
        )}
      </div>

      {/* Stats footer */}
      <div className="grid grid-cols-3 gap-2 pt-4 border-t border-[#1A2035]">
        <div className="text-center">
          <div className="font-mono font-semibold text-sm text-[#F0F4FF]">
            {agent.totalTasksCompleted}
          </div>
          <div className="label text-[9px]">Tasks</div>
        </div>
        <div className="text-center">
          <div className="font-mono font-semibold text-sm text-[#F0F4FF]">
            {formatEth(agent.totalEarned, 1)} ETH
          </div>
          <div className="label text-[9px]">Earned</div>
        </div>
        <div className="text-center">
          <div className="font-mono text-[10px] text-[#8892B0]">
            {timeAgo(agent.lastActiveAt)}
          </div>
          <div className="label text-[9px]">Last Active</div>
        </div>
      </div>
    </Link>
  );
}

export function AgentGrid() {
  return (
    <div>
      {/* Result count */}
      <div className="flex items-center justify-between mb-5">
        <span className="font-mono text-xs text-[#8892B0]">
          Showing <span className="text-[#F0F4FF] font-medium">{MOCK_AGENTS.length}</span> of{" "}
          <span className="text-[#F0F4FF] font-medium">847</span> agents
        </span>
        <span className="font-mono text-xs text-[#4A5568]">
          Last updated: just now
        </span>
      </div>

      {/* Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5">
        {MOCK_AGENTS.map((agent) => (
          <AgentCard key={agent.agentId} agent={agent} />
        ))}
      </div>

      {/* Load more */}
      <div className="mt-10 text-center">
        <button className="btn-secondary px-8">
          Load more agents
        </button>
        <p className="mt-3 font-mono text-xs text-[#4A5568]">
          Showing 6 of 847 registered agents
        </p>
      </div>
    </div>
  );
}
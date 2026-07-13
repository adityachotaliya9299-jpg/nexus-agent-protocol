import { CheckCircle, Copy, ExternalLink, Zap, Clock } from "lucide-react";
import { type Agent } from "@/lib/contracts";
import {
  shortAddress, repToPercent, repBarColor, repColor,
  formatEth, timeAgo, CATEGORY_LABELS, CATEGORY_COLORS,
} from "@/lib/utils";

const STATUS_CONFIG: Record<number, { label: string; color: string; bg: string }> = {
  0: { label: "Inactive",  color: "text-[#A89F8D]", bg: "bg-[#3A3226]/30" },
  1: { label: "Active",    color: "text-emerald",    bg: "bg-emerald/10 border border-emerald/20" },
  2: { label: "Busy",      color: "text-amber",      bg: "bg-amber/10 border border-amber/20" },
  3: { label: "Suspended", color: "text-rose",        bg: "bg-rose/10 border border-rose/20" },
};

export function AgentProfileHeader({ agent }: { agent: Agent }) {
  const repPct     = repToPercent(agent.reputationScore);
  const barColor   = repBarColor(agent.reputationScore);
  const scoreColor = repColor(agent.reputationScore);
  const status     = STATUS_CONFIG[agent.status] ?? STATUS_CONFIG[0];

  return (
    <div className="card p-6 space-y-5">
      {/* Top row */}
      <div className="flex items-start justify-between gap-4">
        <div className="flex-1">
          {/* Name + verified */}
          <div className="flex items-center gap-2.5 mb-2">
            <h1 className="font-display font-bold text-2xl text-[#F4EFE6]">
              {agent.name}
            </h1>
            <CheckCircle className="w-5 h-5 text-emerald shrink-0" />
          </div>

          {/* Badges row */}
          <div className="flex items-center flex-wrap gap-2">
            <span className={`badge ${CATEGORY_COLORS[agent.category]}`}>
              {CATEGORY_LABELS[agent.category]}
            </span>
            <span className={`badge ${status.bg} ${status.color}`}>
              {status.label}
            </span>
            <span className="badge bg-[#2A241B] text-[#A89F8D] border border-[#2A241B]">
              ID #{agent.agentId}
            </span>
          </div>
        </div>

        {/* Rep score */}
        <div className="text-right shrink-0">
          <div className={`font-mono font-bold text-4xl ${scoreColor}`}>{repPct}%</div>
          <div className="label">reputation score</div>
          <div className="font-mono text-xs text-[#6B6355] mt-0.5">
            {agent.reputationScore.toLocaleString()} / 10000 bp
          </div>
        </div>
      </div>

      {/* Reputation bar */}
      <div>
        <div className="flex justify-between text-xs font-mono text-[#6B6355] mb-1.5">
          <span>0%</span>
          <span className={scoreColor}>
            {repPct}% — {repPct >= 80 ? "Elite" : repPct >= 60 ? "Trusted" : repPct >= 40 ? "Standard" : "New"}
          </span>
          <span>100%</span>
        </div>
        <div className="rep-bar h-2">
          <div
            className={`h-full rounded-full ${barColor} transition-all duration-700`}
            style={{ width: `${repPct}%` }}
          />
        </div>
      </div>

      {/* Description */}
      <p className="text-[#A89F8D] leading-relaxed">{agent.description}</p>

      {/* Addresses */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2 border-t border-[#2A241B]">
        <div>
          <div className="label mb-1">Owner EOA</div>
          <div className="flex items-center gap-2">
            <code className="font-mono text-xs text-[#A89F8D]">
              {shortAddress(agent.owner, 6)}
            </code>
            <button className="text-[#6B6355] hover:text-cyan transition-colors">
              <Copy className="w-3.5 h-3.5" />
            </button>
            <a
              href={`https://sepolia.etherscan.io/address/${agent.owner}`}
              target="_blank" rel="noopener noreferrer"
              className="text-[#6B6355] hover:text-cyan transition-colors"
            >
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </div>
        </div>
        <div>
          <div className="label mb-1">Smart Wallet (ERC-4337)</div>
          <div className="flex items-center gap-2">
            <code className="font-mono text-xs text-cyan">
              {shortAddress(agent.agentWallet, 6)}
            </code>
            <button className="text-[#6B6355] hover:text-cyan transition-colors">
              <Copy className="w-3.5 h-3.5" />
            </button>
            <a
              href={`https://sepolia.etherscan.io/address/${agent.agentWallet}`}
              target="_blank" rel="noopener noreferrer"
              className="text-[#6B6355] hover:text-cyan transition-colors"
            >
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </div>
        </div>
        <div>
          <div className="label mb-1">Registered</div>
          <div className="font-mono text-xs text-[#A89F8D]">
            {timeAgo(agent.registeredAt)}
          </div>
        </div>
        <div>
          <div className="label mb-1">Last Active</div>
          <div className="font-mono text-xs text-[#A89F8D]">
            {timeAgo(agent.lastActiveAt)}
          </div>
        </div>
      </div>
    </div>
  );
}
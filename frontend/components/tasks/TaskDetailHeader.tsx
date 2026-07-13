import { Clock, Shield, User, ExternalLink, AlertCircle, CheckCircle, Zap } from "lucide-react";
import { type Task } from "@/lib/contracts";
import { shortAddress, formatEth } from "@/lib/utils";

const STATUS_CONFIG: Record<number, { label: string; color: string; bg: string; icon: React.ComponentType<{ className?: string }> }> = {
  0: { label: "Open — Accepting Bids", color: "text-emerald", bg: "bg-emerald/10 border-emerald/20", icon: CheckCircle },
  1: { label: "Assigned",              color: "text-amber",   bg: "bg-amber/10 border-amber/20",      icon: Zap },
  2: { label: "Completed",             color: "text-cyan",    bg: "bg-cyan/10 border-cyan/20",         icon: CheckCircle },
  5: { label: "Disputed",              color: "text-rose",    bg: "bg-rose/10 border-rose/20",         icon: AlertCircle },
};

function timeLeft(deadline: number): string {
  const diff = deadline - Date.now() / 1000;
  if (diff <= 0) return "Deadline passed";
  const days  = Math.floor(diff / 86400);
  const hours = Math.floor((diff % 86400) / 3600);
  if (days > 0) return `${days} days ${hours} hours remaining`;
  return `${hours} hours remaining`;
}

function timeAgo(ts: number): string {
  const diff = Date.now() / 1000 - ts;
  if (diff < 3600)  return `${Math.floor(diff / 60)} minutes ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} hours ago`;
  return `${Math.floor(diff / 86400)} days ago`;
}

export function TaskDetailHeader({ task }: { task: Task }) {
  const st = STATUS_CONFIG[task.status] ?? STATUS_CONFIG[0];
  const Icon = st.icon;
  const isUrgent = task.deadline - Date.now() / 1000 < 2 * 86400 && task.status === 0;

  return (
    <div className="card p-6 space-y-5">
      {/* Status + category */}
      <div className="flex items-center flex-wrap gap-2">
        <span className={`badge border ${st.bg} ${st.color}`}>
          <Icon className="w-3.5 h-3.5" />
          {st.label}
        </span>
        {task.category && (
          <span className="badge bg-violet/10 text-violet border border-violet/20">
            {task.category}
          </span>
        )}
        {isUrgent && (
          <span className="badge bg-rose/10 text-rose border border-rose/20">
            🔥 Urgent — deadline soon
          </span>
        )}
      </div>

      {/* Title + reward */}
      <div className="flex items-start justify-between gap-4">
        <h1 className="font-display font-bold text-2xl text-[#F4EFE6] leading-tight">
          {task.title}
        </h1>
        <div className="text-right shrink-0">
          <div className="font-display font-bold text-3xl text-[#F4EFE6]">
            {formatEth(task.reward, 3)}
          </div>
          <div className="font-mono text-sm text-[#A89F8D]">ETH in escrow</div>
        </div>
      </div>

      {/* Description */}
      <p className="text-[#A89F8D] leading-relaxed">{task.description}</p>

      {/* Meta grid */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 pt-4 border-t border-[#2A241B]">
        <div>
          <div className="label mb-1">Posted by</div>
          <div className="flex items-center gap-1.5">
            <User className="w-3.5 h-3.5 text-[#6B6355]" />
            <a
              href={`https://sepolia.etherscan.io/address/${task.client}`}
              target="_blank" rel="noopener noreferrer"
              className="font-mono text-xs text-[#A89F8D] hover:text-cyan transition-colors flex items-center gap-1"
            >
              {shortAddress(task.client)}
              <ExternalLink className="w-3 h-3" />
            </a>
          </div>
        </div>
        <div>
          <div className="label mb-1">Created</div>
          <div className="font-mono text-xs text-[#A89F8D]">{timeAgo(task.createdAt)}</div>
        </div>
        <div>
          <div className="label mb-1">Deadline</div>
          <div className={`font-mono text-xs flex items-center gap-1.5 ${isUrgent ? "text-rose" : "text-[#A89F8D]"}`}>
            <Clock className="w-3.5 h-3.5" />
            {timeLeft(task.deadline)}
          </div>
        </div>
        <div>
          <div className="label mb-1">Min Reputation</div>
          {task.minReputation > 0 ? (
            <div className="flex items-center gap-1.5">
              <Shield className="w-3.5 h-3.5 text-amber" />
              <span className="font-mono text-xs text-amber">
                {Math.round(task.minReputation / 100)}%+ required
              </span>
            </div>
          ) : (
            <span className="font-mono text-xs text-emerald">Open to all agents</span>
          )}
        </div>
      </div>
    </div>
  );
}
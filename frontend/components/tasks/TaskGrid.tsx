import Link from "next/link";
import { Clock, Shield, ArrowRight, CheckCircle, Zap, AlertCircle } from "lucide-react";
import { MOCK_TASKS, type Task } from "@/lib/contracts";
import { shortAddress, formatEth } from "@/lib/utils";
import { MOCK_STATS } from "@/lib/contracts";

const STATUS_CONFIG: Record<number, { label: string; color: string; bg: string; icon: React.ComponentType<{ className?: string }> }> = {
  0: { label: "Open",       color: "text-emerald", bg: "bg-emerald/10 border-emerald/20",  icon: CheckCircle },
  1: { label: "Assigned",   color: "text-amber",   bg: "bg-amber/10 border-amber/20",      icon: Zap },
  2: { label: "Completed",  color: "text-cyan",    bg: "bg-cyan/10 border-cyan/20",         icon: CheckCircle },
  3: { label: "Cancelled",  color: "text-[#A89F8D]", bg: "bg-[#3A3226]/30 border-[#3A3226]", icon: Clock },
  5: { label: "Disputed",   color: "text-rose",    bg: "bg-rose/10 border-rose/20",         icon: AlertCircle },
};

function timeLeft(deadline: number): string {
  const diff = deadline - Date.now() / 1000;
  if (diff <= 0) return "Expired";
  const days  = Math.floor(diff / 86400);
  const hours = Math.floor((diff % 86400) / 3600);
  if (days > 0) return `${days}d ${hours}h left`;
  return `${hours}h left`;
}

function timeAgo(ts: number): string {
  const diff = Date.now() / 1000 - ts;
  if (diff < 3600)  return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

function TaskCard({ task }: { task: Task }) {
  const st = STATUS_CONFIG[task.status] ?? STATUS_CONFIG[0];
  const Icon = st.icon;
  const isUrgent = task.deadline - Date.now() / 1000 < 2 * 86400 && task.status === 0;

  return (
    <Link
      href={`/tasks/${task.taskId}`}
      className="card-hover p-6 flex flex-col gap-4 group"
    >
      {/* Header */}
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          {/* Category + status */}
          <div className="flex items-center gap-2 mb-2">
            {task.category && (
              <span className="badge bg-violet/10 text-violet border border-violet/20 text-[10px]">
                {task.category}
              </span>
            )}
            <span className={`badge border text-[10px] ${st.bg} ${st.color}`}>
              <Icon className="w-3 h-3" />
              {st.label}
            </span>
            {isUrgent && (
              <span className="badge bg-rose/10 text-rose border border-rose/20 text-[10px]">
                🔥 Urgent
              </span>
            )}
          </div>
          <h3 className="font-display font-semibold text-[#F4EFE6] group-hover:text-cyan transition-colors line-clamp-1">
            {task.title}
          </h3>
        </div>

        {/* Reward */}
        <div className="text-right shrink-0">
          <div className="font-display font-bold text-xl text-[#F4EFE6]">
            {formatEth(task.reward, 2)}
          </div>
          <div className="font-mono text-xs text-[#A89F8D]">ETH</div>
        </div>
      </div>

      {/* Description */}
      <p className="text-sm text-[#A89F8D] leading-relaxed line-clamp-2">
        {task.description}
      </p>

      {/* Footer row */}
      <div className="flex items-center justify-between pt-4 border-t border-[#2A241B]">
        <div className="flex items-center gap-4">
          {/* Deadline */}
          <div className="flex items-center gap-1.5">
            <Clock className={`w-3.5 h-3.5 ${isUrgent ? "text-rose" : "text-[#6B6355]"}`} />
            <span className={`font-mono text-xs ${isUrgent ? "text-rose" : "text-[#A89F8D]"}`}>
              {timeLeft(task.deadline)}
            </span>
          </div>

          {/* Min rep */}
          {task.minReputation > 0 && (
            <div className="flex items-center gap-1.5">
              <Shield className="w-3.5 h-3.5 text-amber" />
              <span className="font-mono text-xs text-amber">
                {Math.round(task.minReputation / 100)}%+ rep
              </span>
            </div>
          )}
        </div>

        <div className="flex items-center gap-3">
          <span className="font-mono text-[10px] text-[#6B6355]">
            by {shortAddress(task.client)} · {timeAgo(task.createdAt)}
          </span>
          <ArrowRight className="w-3.5 h-3.5 text-[#6B6355] group-hover:text-cyan transition-colors" />
        </div>
      </div>
    </Link>
  );
}

export function TaskGrid() {
  const open = MOCK_TASKS.filter((t) => t.status === 0);
  const other = MOCK_TASKS.filter((t) => t.status !== 0);

  return (
    <div>
      <div className="flex items-center justify-between mb-5">
        <span className="font-mono text-xs text-[#A89F8D]">
          <span className="text-emerald font-medium">{open.length} open</span>
          {" · "}
          <span className="text-[#F4EFE6] font-medium">{MOCK_TASKS.length}</span> total tasks
        </span>
        <span className="font-mono text-xs text-[#6B6355]">Sorted by reward</span>
      </div>

      {/* Open tasks */}
      {open.length > 0 && (
        <div className="mb-8">
          <div className="flex items-center gap-2 mb-4">
            <div className="w-2 h-2 rounded-full bg-emerald" />
            <span className="label">Open for Bids</span>
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
            {open.map((t) => <TaskCard key={t.taskId} task={t} />)}
          </div>
        </div>
      )}

      {/* Other tasks */}
      {other.length > 0 && (
        <div>
          <div className="flex items-center gap-2 mb-4">
            <div className="w-2 h-2 rounded-full bg-[#6B6355]" />
            <span className="label">In Progress / Completed</span>
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
            {other.map((t) => <TaskCard key={t.taskId} task={t} />)}
          </div>
        </div>
      )}

      <div className="mt-10 text-center">
        <button className="btn-secondary px-8">Load more tasks</button>
        <p className="mt-3 font-mono text-xs text-[#6B6355]">
          Showing {MOCK_TASKS.length} of {MOCK_STATS.totalTasks.toLocaleString()} tasks
        </p>
      </div>
    </div>
  );
}


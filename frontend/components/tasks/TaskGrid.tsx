"use client";

import Link from "next/link";
import { Clock, Shield, ArrowRight, CheckCircle, Zap, AlertCircle, Inbox } from "lucide-react";
import { useSgTasks } from "@/lib/hooks/useSubgraph";
import { parseTaskMeta, type SgTask } from "@/lib/subgraph";
import { shortAddress, formatEth } from "@/lib/utils";

const STATUS_CONFIG: Record<number, { label: string; color: string; bg: string; icon: React.ComponentType<{ className?: string }> }> = {
  0: { label: "Open",      color: "text-emerald",   bg: "bg-emerald/10 border-emerald/20", icon: CheckCircle },
  1: { label: "Assigned",  color: "text-amber",     bg: "bg-amber/10 border-amber/20",     icon: Zap },
  2: { label: "Submitted", color: "text-sky",       bg: "bg-sky/10 border-sky/20",         icon: Zap },
  3: { label: "Completed", color: "text-gold",      bg: "bg-gold/10 border-gold/20",       icon: CheckCircle },
  4: { label: "Disputed",  color: "text-rose",      bg: "bg-rose/10 border-rose/20",       icon: AlertCircle },
  5: { label: "Cancelled", color: "text-[#A89F8D]", bg: "bg-muted/30 border-muted",        icon: Clock },
};

function timeLeft(deadline: number): string {
  const diff = deadline - Date.now() / 1000;
  if (diff <= 0) return "Expired";
  const days = Math.floor(diff / 86400);
  const hours = Math.floor((diff % 86400) / 3600);
  if (days > 0) return `${days}d ${hours}h left`;
  return `${hours}h left`;
}

function timeAgo(ts: number): string {
  const diff = Date.now() / 1000 - ts;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

function TaskCard({ task }: { task: SgTask }) {
  const st = STATUS_CONFIG[task.status] ?? STATUS_CONFIG[0];
  const Icon = st.icon;
  const meta = parseTaskMeta(task.metadataURI, task.id);
  const deadline = Number(task.deadline);
  const createdAt = Number(task.createdAt);
  const minRep = Number(task.minReputation);
  const isUrgent = deadline - Date.now() / 1000 < 2 * 86400 && task.status === 0;

  return (
    <Link href={`/tasks/${task.id}`} className="card-hover p-5 sm:p-6 flex flex-col gap-4 group">
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-2 flex-wrap">
            {meta.category && (
              <span className="badge bg-violet/10 text-violet border border-violet/20 text-[10px]">
                {meta.category}
              </span>
            )}
            <span className={`badge border text-[10px] ${st.bg} ${st.color}`}>
              <Icon className="w-3 h-3" />
              {st.label}
            </span>
            {isUrgent && (
              <span className="badge bg-rose/10 text-rose border border-rose/20 text-[10px]">Urgent</span>
            )}
          </div>
          <h3 className="font-display font-semibold text-bone group-hover:text-gold transition-colors line-clamp-1">
            {meta.title}
          </h3>
        </div>

        <div className="text-right shrink-0">
          <div className="font-display font-bold text-xl text-bone">
            {formatEth(BigInt(task.reward), 3)}
          </div>
          <div className="font-mono text-xs text-text-secondary">ETH</div>
        </div>
      </div>

      <p className="text-sm text-text-secondary leading-relaxed line-clamp-2">{meta.description}</p>

      <div className="flex items-center justify-between pt-4 border-t border-border flex-wrap gap-2">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-1.5">
            <Clock className={`w-3.5 h-3.5 ${isUrgent ? "text-rose" : "text-text-muted"}`} />
            <span className={`font-mono text-xs ${isUrgent ? "text-rose" : "text-text-secondary"}`}>
              {timeLeft(deadline)}
            </span>
          </div>
          {minRep > 0 && (
            <div className="flex items-center gap-1.5">
              <Shield className="w-3.5 h-3.5 text-amber" />
              <span className="font-mono text-xs text-amber">{minRep.toLocaleString()}+ rep</span>
            </div>
          )}
        </div>

        <div className="flex items-center gap-3">
          <span className="font-mono text-[10px] text-text-muted">
            by {shortAddress(task.rawClient)} · {timeAgo(createdAt)}
          </span>
          <ArrowRight className="w-3.5 h-3.5 text-text-muted group-hover:text-gold transition-colors" />
        </div>
      </div>
    </Link>
  );
}

export function TaskGrid() {
  const { data, isLoading, isError } = useSgTasks(50);
  const tasks = data?.tasks ?? [];
  const open = tasks.filter(t => t.status === 0);
  const other = tasks.filter(t => t.status !== 0);

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="card h-48 animate-pulse" />
        ))}
      </div>
    );
  }

  if (isError || tasks.length === 0) {
    return (
      <div className="ag-panel p-12 flex flex-col items-center text-center gap-4">
        <div className="w-14 h-14 rounded-2xl border border-border bg-void flex items-center justify-center">
          <Inbox size={22} className="text-gold" />
        </div>
        <div>
          <h3 className="font-display font-bold text-xl text-bone">
            {isError ? "Indexer unavailable" : "No tasks posted yet"}
          </h3>
          <p className="text-text-secondary text-sm mt-2 max-w-md">
            {isError
              ? "The subgraph didn't respond — on-chain data is unaffected. Try again in a moment."
              : "Be the first to put the agents to work. Post a task with an ETH reward and watch the bids come in."}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-5 flex-wrap gap-2">
        <span className="font-mono text-xs text-text-secondary">
          <span className="text-emerald font-medium">{open.length} open</span>
          {" · "}
          <span className="text-bone font-medium">{tasks.length}</span> indexed tasks
        </span>
        <span className="font-mono text-xs text-text-muted">Newest first · live from The Graph</span>
      </div>

      {open.length > 0 && (
        <div className="mb-8">
          <div className="flex items-center gap-2 mb-4">
            <div className="w-2 h-2 rounded-full bg-emerald pulse-dot" />
            <span className="label">Open for bids</span>
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
            {open.map(t => <TaskCard key={t.id} task={t} />)}
          </div>
        </div>
      )}

      {other.length > 0 && (
        <div>
          <div className="flex items-center gap-2 mb-4">
            <div className="w-2 h-2 rounded-full bg-text-muted" />
            <span className="label">In progress / settled</span>
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
            {other.map(t => <TaskCard key={t.id} task={t} />)}
          </div>
        </div>
      )}
    </div>
  );
}

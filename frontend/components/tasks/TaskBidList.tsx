"use client";

import Link from "next/link";
import { Star, Clock, ArrowRight } from "lucide-react";
import { useAccount } from "wagmi";
import { type Task } from "@/lib/contracts";
import { useAssignAgent } from "@/lib/hooks/useTaskMarketplace";
import { useSgBids } from "@/lib/hooks/useSubgraph";
import { shortAddress, repToPercent, repColor, repBarColor } from "@/lib/utils";

function timeAgo(ts: number) {
  const d = Date.now() / 1000 - ts;
  if (d < 3600) return `${Math.floor(d / 60)}m ago`;
  if (d < 86400) return `${Math.floor(d / 3600)}h ago`;
  return `${Math.floor(d / 86400)}d ago`;
}

export function TaskBidList({ task }: { task: Task }) {
  const { address } = useAccount();
  const { data, isLoading } = useSgBids(task.taskId);
  const { assignAgent, isPending, isConfirming } = useAssignAgent();

  const bids = (data?.bids ?? []).filter(b => b.active);
  const isClient = address && address.toLowerCase() === task.client.toLowerCase();
  const canAssign = isClient && task.status === 0;

  return (
    <div className="card p-6">
      <div className="flex items-center justify-between mb-5">
        <div>
          <h3 className="font-display font-semibold text-bone">Agent bids</h3>
          <p className="text-xs text-text-secondary mt-0.5">
            {isLoading ? "Loading bids…" : bids.length > 0 ? `${bids.length} proposals received` : "No bids yet"}
          </p>
        </div>
        {task.status === 0 && bids.length > 0 && (
          <span className="badge badge-active">{bids.length} bids</span>
        )}
      </div>

      {bids.length === 0 && !isLoading ? (
        <div className="text-center py-10 border border-dashed border-border rounded-xl">
          <div className="font-mono text-sm text-text-muted mb-2">No bids submitted yet</div>
          <div className="font-mono text-xs text-muted">
            {task.status === 0
              ? "Registered agents can submit proposals"
              : "Task is no longer accepting bids"}
          </div>
        </div>
      ) : (
        <div className="space-y-3">
          {bids.map(bid => {
            const agentId = Number(bid.agent.agentId);
            const rep = Number(bid.agent.reputationScore);
            const repPct = repToPercent(rep);
            return (
              <div key={bid.id} className="p-4 rounded-xl bg-void border border-border hover:border-muted transition-all">
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1 min-w-0">
                    <Link
                      href={`/agents/${agentId}`}
                      className="font-display font-semibold text-sm text-bone hover:text-gold transition-colors flex items-center gap-1.5"
                    >
                      Agent #{agentId}
                      <ArrowRight className="w-3 h-3" />
                    </Link>
                    <div className="font-mono text-[10px] text-text-muted mt-0.5">
                      {shortAddress(bid.agent.owner)} · submitted {timeAgo(Number(bid.submittedAt))}
                    </div>

                    <div className="mt-2 flex items-center gap-2">
                      <div className="flex-1 rep-bar h-1">
                        <div className={`h-full rounded-full ${repBarColor(rep)}`} style={{ width: `${repPct}%` }} />
                      </div>
                      <span className={`font-mono text-xs font-semibold ${repColor(rep)}`}>{repPct}%</span>
                    </div>
                  </div>

                  <div className="text-right shrink-0">
                    <div className="flex items-center gap-1 text-text-secondary">
                      <Star className="w-3.5 h-3.5" />
                      <span className="font-mono text-xs">{rep.toLocaleString()} rep</span>
                    </div>
                    {bid.proposalURI && (
                      <div className="flex items-center gap-1 text-text-muted mt-1 max-w-[140px]">
                        <Clock className="w-3.5 h-3.5 shrink-0" />
                        <span className="font-mono text-[10px] truncate">{bid.proposalURI}</span>
                      </div>
                    )}
                  </div>
                </div>

                {canAssign && (
                  <div className="mt-3 pt-3 border-t border-border flex justify-end">
                    <button
                      onClick={() => assignAgent(task.taskId as `0x${string}`, agentId)}
                      disabled={isPending || isConfirming}
                      className="text-xs font-mono text-gold hover:text-gold-bright transition-colors disabled:opacity-50"
                    >
                      {isPending || isConfirming ? "Assigning…" : "Assign this agent →"}
                    </button>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

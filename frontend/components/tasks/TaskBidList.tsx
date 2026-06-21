import Link from "next/link";
import { Star, Clock, ArrowRight } from "lucide-react";
import { type Task } from "@/lib/contracts";
import { MOCK_AGENTS } from "@/lib/contracts";
import { shortAddress, repToPercent, repColor, repBarColor } from "@/lib/utils";

// Mock bids for the task
const MOCK_BIDS = [
  { agentId: 1, proposalURI: "ipfs://QmProp1", estimatedDays: 2, submittedAt: Date.now() / 1000 - 1800,  isAccepted: false },
  { agentId: 3, proposalURI: "ipfs://QmProp2", estimatedDays: 3, submittedAt: Date.now() / 1000 - 3600,  isAccepted: false },
  { agentId: 5, proposalURI: "ipfs://QmProp3", estimatedDays: 5, submittedAt: Date.now() / 1000 - 7200,  isAccepted: false },
];

function timeAgo(ts: number) {
  const d = Date.now() / 1000 - ts;
  if (d < 3600)  return `${Math.floor(d / 60)}m ago`;
  if (d < 86400) return `${Math.floor(d / 3600)}h ago`;
  return `${Math.floor(d / 86400)}d ago`;
}

export function TaskBidList({ task }: { task: Task }) {
  const bids = task.status === 0 ? MOCK_BIDS : [];

  return (
    <div className="card p-6">
      <div className="flex items-center justify-between mb-5">
        <div>
          <h3 className="font-display font-semibold text-[#F0F4FF]">Agent Bids</h3>
          <p className="text-xs text-[#8892B0] mt-0.5">
            {bids.length > 0 ? `${bids.length} proposals received` : "No bids yet"}
          </p>
        </div>
        {task.status === 0 && bids.length > 0 && (
          <span className="badge badge-active">{bids.length} bids</span>
        )}
      </div>

      {bids.length === 0 ? (
        <div className="text-center py-10 border border-dashed border-[#1A2035] rounded-lg">
          <div className="font-mono text-sm text-[#4A5568] mb-2">No bids submitted yet</div>
          <div className="font-mono text-xs text-[#2A3555]">
            {task.status === 0
              ? "Registered agents can submit proposals"
              : "Task is no longer accepting bids"}
          </div>
        </div>
      ) : (
        <div className="space-y-3">
          {bids.map((bid) => {
            const agent = MOCK_AGENTS.find((a) => a.agentId === bid.agentId);
            if (!agent) return null;
            const repPct    = repToPercent(agent.reputationScore);
            const scoreColor = repColor(agent.reputationScore);
            const barColor  = repBarColor(agent.reputationScore);

            return (
              <div key={bid.agentId}
                className="p-4 rounded-lg bg-[#080B12] border border-[#1A2035] hover:border-[#2A3555] transition-all">
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1">
                    {/* Agent name */}
                    <Link href={`/agents/${agent.agentId}`}
                      className="font-display font-semibold text-sm text-[#F0F4FF] hover:text-cyan transition-colors flex items-center gap-1.5">
                      {agent.name}
                      <ArrowRight className="w-3 h-3" />
                    </Link>
                    <div className="font-mono text-[10px] text-[#4A5568] mt-0.5">
                      {shortAddress(agent.owner)} · submitted {timeAgo(bid.submittedAt)}
                    </div>

                    {/* Mini rep bar */}
                    <div className="mt-2 flex items-center gap-2">
                      <div className="flex-1 rep-bar h-1">
                        <div className={`h-full rounded-full ${barColor}`} style={{ width: `${repPct}%` }} />
                      </div>
                      <span className={`font-mono text-xs font-semibold ${scoreColor}`}>{repPct}%</span>
                    </div>
                  </div>

                  <div className="text-right shrink-0">
                    <div className="flex items-center gap-1 text-amber">
                      <Clock className="w-3.5 h-3.5" />
                      <span className="font-mono text-xs">{bid.estimatedDays}d est.</span>
                    </div>
                    <div className="flex items-center gap-1 text-[#8892B0] mt-1">
                      <Star className="w-3.5 h-3.5" />
                      <span className="font-mono text-xs">{agent.totalTasksCompleted} tasks</span>
                    </div>
                  </div>
                </div>

                {/* Assign button (client only) */}
                <div className="mt-3 pt-3 border-t border-[#1A2035] flex justify-between items-center">
                  <span className="font-mono text-[10px] text-[#4A5568]">
                    Price: {agent.pricePerTask} ETH
                  </span>
                  <button className="text-xs font-mono text-cyan hover:text-cyan/80 transition-colors">
                    Assign this agent →
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
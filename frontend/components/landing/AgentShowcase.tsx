import Link from "next/link";
import { ArrowRight, CheckCircle } from "lucide-react";
import { MOCK_AGENTS } from "@/lib/contracts";
import { shortAddress, repToPercent, repBarColor, repColor, CATEGORY_LABELS, CATEGORY_COLORS } from "@/lib/utils";

export function AgentShowcase() {
  const featured = MOCK_AGENTS.slice(0, 3);

  return (
    <section className="py-24 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="flex items-end justify-between mb-12">
          <div>
            <div className="label mb-3">Top Agents</div>
            <h2 className="font-display font-bold text-4xl text-text-primary">
              Meet the Network
            </h2>
          </div>
          <Link href="/agents" className="btn-ghost hidden sm:flex">
            View all agents <ArrowRight className="w-4 h-4" />
          </Link>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
          {featured.map((agent) => {
            const repPct = repToPercent(agent.reputationScore);
            const barColor = repBarColor(agent.reputationScore);
            const scoreColor = repColor(agent.reputationScore);

            return (
              <Link
                key={agent.agentId}
                href={`/agents/${agent.agentId}`}
                className="card-hover p-6 flex flex-col gap-5 group"
              >
                {/* Header */}
                <div className="flex items-start justify-between">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="font-display font-semibold text-text-primary group-hover:text-cyan transition-colors">
                        {agent.name}
                      </h3>
                      <CheckCircle className="w-3.5 h-3.5 text-emerald shrink-0" />
                    </div>
                    <span className={`badge ${CATEGORY_COLORS[agent.category]}`}>
                      {CATEGORY_LABELS[agent.category]}
                    </span>
                  </div>
                  <div className="text-right">
                    <div className={`font-mono font-bold text-lg ${scoreColor}`}>
                      {repPct}%
                    </div>
                    <div className="label">reputation</div>
                  </div>
                </div>

                {/* Rep bar */}
                <div className="rep-bar">
                  <div
                    className={`h-full rounded-full transition-all ${barColor}`}
                    style={{ width: `${repPct}%` }}
                  />
                </div>

                {/* Description */}
                <p className="text-sm text-text-secondary leading-relaxed line-clamp-2">
                  {agent.description}
                </p>

                {/* Capabilities */}
                <div className="flex flex-wrap gap-1.5">
                  {agent.capabilities?.slice(0, 3).map((cap) => (
                    <span key={cap} className="badge badge-inactive text-[10px]">
                      {cap}
                    </span>
                  ))}
                  {(agent.capabilities?.length ?? 0) > 3 && (
                    <span className="badge badge-inactive text-[10px]">
                      +{(agent.capabilities?.length ?? 0) - 3} more
                    </span>
                  )}
                </div>

                {/* Stats */}
                <div className="grid grid-cols-3 gap-2 pt-4 border-t border-border">
                  <div className="stat-block text-center">
                    <div className="font-mono font-semibold text-sm text-text-primary">
                      {agent.totalTasksCompleted}
                    </div>
                    <div className="label text-[9px]">Tasks</div>
                  </div>
                  <div className="stat-block text-center">
                    <div className="font-mono font-semibold text-sm text-text-primary">
                      {agent.pricePerTask} ETH
                    </div>
                    <div className="label text-[9px]">Per Task</div>
                  </div>
                  <div className="stat-block text-center">
                    <div className="address text-[10px] text-text-secondary">
                      {shortAddress(agent.owner)}
                    </div>
                    <div className="label text-[9px]">Owner</div>
                  </div>
                </div>
              </Link>
            );
          })}
        </div>

        <div className="mt-6 text-center sm:hidden">
          <Link href="/agents" className="btn-secondary text-sm">
            View all agents <ArrowRight className="w-4 h-4" />
          </Link>
        </div>
      </div>
    </section>
  );
}
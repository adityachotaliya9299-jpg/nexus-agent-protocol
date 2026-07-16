import { AgentGrid } from "@/components/agents/AgentGrid";
import { AgentFilters } from "@/components/agents/AgentFilters";
import { Users, TrendingUp } from "lucide-react";
import { LiveStat } from "@/components/LiveStat";

export const metadata = {
  title: "Agent Explorer — AGORA",
  description: "Browse and discover autonomous AI agents on AGORA.",
};

export default function AgentsPage() {
  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">

      {/* Page header */}
      <div className="mb-10">
        <div className="flex items-center gap-2 mb-3">
          <span className="label">Agent Registry</span>
          <span className="font-mono text-xs text-[#6B6355]">/</span>
          <span className="font-mono text-xs text-cyan">Browse All</span>
        </div>
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-6">
          <div>
            <h1 className="font-display font-bold text-4xl text-[#F4EFE6] mb-2">
              Agent Explorer
            </h1>
            <p className="text-[#A89F8D]">
              Discover autonomous AI agents — filter by category, reputation, and availability.
            </p>
          </div>
          <div className="flex items-center gap-6">
            <div className="text-right">
              <div className="flex items-center gap-2">
                <Users className="w-4 h-4 text-cyan" />
                <LiveStat stat="totalAgents" className="font-display font-bold text-2xl text-[#F4EFE6]" />
              </div>
              <div className="label">registered agents</div>
            </div>
            <div className="text-right">
              <div className="flex items-center gap-2">
                <TrendingUp className="w-4 h-4 text-emerald" />
                <LiveStat stat="tasksCompleted" className="font-display font-bold text-2xl text-[#F4EFE6]" />
              </div>
              <div className="label">tasks completed</div>
            </div>
          </div>
        </div>
      </div>

      {/* Filters + Grid */}
      <AgentFilters />
      <AgentGrid />
    </div>
  );
}
import { TaskFilters } from "@/components/tasks/TaskFilters";
import { TaskGrid } from "@/components/tasks/TaskGrid";
import { PostTaskButton } from "@/components/tasks/PostTaskButton";
import { ShoppingBag, DollarSign } from "lucide-react";
import { MOCK_STATS } from "@/lib/contracts";

export const metadata = {
  title: "Task Marketplace — Nexus Agent Protocol",
  description: "Post tasks, browse open bounties, and hire autonomous AI agents.",
};

export default function TasksPage() {
  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">

      {/* Header */}
      <div className="mb-10">
        <div className="flex items-center gap-2 mb-3">
          <span className="label">Protocol</span>
          <span className="font-mono text-xs text-[#4A5568]">/</span>
          <span className="font-mono text-xs text-cyan">Task Marketplace</span>
        </div>
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-6">
          <div>
            <h1 className="font-display font-bold text-4xl text-[#F0F4FF] mb-2">
              Task Marketplace
            </h1>
            <p className="text-[#8892B0]">
              Post tasks with ETH escrow or browse open bounties — agents bid, execute, and get paid on-chain.
            </p>
          </div>
          <div className="flex items-center gap-6">
            <div className="text-right">
              <div className="flex items-center gap-2">
                <ShoppingBag className="w-4 h-4 text-violet" />
                <span className="font-display font-bold text-2xl text-[#F0F4FF]">
                  {MOCK_STATS.totalTasks.toLocaleString()}
                </span>
              </div>
              <div className="label">total tasks</div>
            </div>
            <div className="text-right">
              <div className="flex items-center gap-2">
                <DollarSign className="w-4 h-4 text-emerald" />
                <span className="font-display font-bold text-2xl text-[#F0F4FF]">
                  {MOCK_STATS.totalPayouts}
                </span>
              </div>
              <div className="label">paid to agents</div>
            </div>
            <PostTaskButton />
          </div>
        </div>
      </div>

      {/* Filters */}
      <TaskFilters />

      {/* Task grid */}
      <TaskGrid />
    </div>
  );
}
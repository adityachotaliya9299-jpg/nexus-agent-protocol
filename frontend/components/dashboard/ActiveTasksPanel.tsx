"use client";

import { useState } from "react";
import { shortAddress } from "@/lib/utils";

type TaskView = "overview" | "full";
type TaskFilter = "all" | "active" | "bidding" | "completed" | "disputed";

interface Task {
  id: string;
  title: string;
  status: string;
  reward: string;
  deadline: string;
  client: string;
  category: string;
  role: "worker" | "client";
}

// Mock task data for the connected agent
const AGENT_TASKS: Task[] = [
  {
    id: "0xabc1",
    title: "Build Uniswap v4 hook for dynamic fee adjustment",
    status: "active",
    reward: "0.8 ETH",
    deadline: "3d",
    client: "0x742d35Cc6634C0532925a3b8D4C9C3",
    category: "DeFi",
    role: "worker",
  },
  {
    id: "0xabc2",
    title: "Audit cross-chain bridge contract",
    status: "submitted",
    reward: "1.2 ETH",
    deadline: "1d",
    client: "0x3fC91A3afd70395Cd496C647d5a6CC",
    category: "Security",
    role: "worker",
  },
  {
    id: "0xabc3",
    title: "Design zkProof verification circuit",
    status: "bidding",
    reward: "0.5 ETH",
    deadline: "5d",
    client: "0x1f9840a85d5aF5bf1D1762F925BDa",
    category: "ZK",
    role: "client",
  },
  {
    id: "0xabc4",
    title: "Deploy EigenLayer AVS operator node",
    status: "completed",
    reward: "0.3 ETH",
    deadline: "—",
    client: "0x68b3465833fb72A70ecDF485E0e4",
    category: "Infrastructure",
    role: "worker",
  },
  {
    id: "0xabc5",
    title: "Implement on-chain oracle aggregation",
    status: "completed",
    reward: "0.45 ETH",
    deadline: "—",
    client: "0xA0Cf798816D4b9b9866b5330EEa0",
    category: "DeFi",
    role: "worker",
  },
  {
    id: "0xabc6",
    title: "Write Foundry fuzzing test suite",
    status: "disputed",
    reward: "0.25 ETH",
    deadline: "—",
    client: "0x4838B106FCe9647Bdf1E7877BF73",
    category: "Testing",
    role: "client",
  },
];

const STATUS_STYLES: Record<string, string> = {
  active: "badge-active",
  submitted: "badge badge-violet",
  bidding: "badge badge-pending",
  completed: "badge bg-[#2A241B] text-[#A89F8D] border border-[#3A3226]",
  disputed: "badge bg-red-500/10 text-red-400 border border-red-500/20",
};

const STATUS_LABEL: Record<string, string> = {
  active: "In Progress",
  submitted: "Submitted",
  bidding: "Bidding",
  completed: "Completed",
  disputed: "Disputed",
};

interface ActiveTasksPanelProps {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  tasks?: any[];
  view?: TaskView;
}

export function ActiveTasksPanel({ view = "full" }: ActiveTasksPanelProps) {
  const [filter, setFilter] = useState<TaskFilter>("all");

  const filtered =
    filter === "all"
      ? AGENT_TASKS
      : AGENT_TASKS.filter((t) => t.status === filter);

  const displayTasks = view === "overview" ? filtered.slice(0, 4) : filtered;

  return (
    <div className="card p-6 space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="font-display font-semibold text-[#F4EFE6] text-lg">
            {view === "overview" ? "Recent Tasks" : "All Tasks"}
          </h2>
          <p className="text-[#A89F8D] text-sm mt-0.5">
            Tasks as worker and as client
          </p>
        </div>
        {view === "full" && (
          <div className="flex gap-1 bg-[#0B0A08] border border-[#2A241B] rounded-md p-0.5 flex-wrap">
            {(["all", "active", "bidding", "completed", "disputed"] as TaskFilter[]).map((f) => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-3 py-1 rounded text-xs font-mono capitalize transition-all duration-150 ${
                  filter === f
                    ? "bg-[#2A241B] text-[#F4EFE6]"
                    : "text-[#A89F8D] hover:text-[#F4EFE6]"
                }`}
              >
                {f}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Task list */}
      <div className="space-y-2">
        {displayTasks.length === 0 ? (
          <div className="py-10 text-center text-[#A89F8D] text-sm">
            No tasks in this category
          </div>
        ) : (
          displayTasks.map((task) => (
            <div
              key={task.id}
              className="flex items-center gap-4 p-3.5 rounded-lg bg-[#0B0A08] border border-[#2A241B] hover:border-cyan/20 transition-colors group cursor-pointer"
            >
              {/* Role indicator */}
              <div
                className={`w-1.5 h-10 rounded-full flex-shrink-0 ${
                  task.role === "worker" ? "bg-cyan/50" : "bg-violet/50"
                }`}
              />

              {/* Title + meta */}
              <div className="flex-1 min-w-0">
                <div className="flex items-start gap-2 flex-wrap">
                  <p className="text-sm font-medium text-[#F4EFE6] group-hover:text-cyan transition-colors truncate max-w-sm">
                    {task.title}
                  </p>
                  <span className={`${STATUS_STYLES[task.status]} text-[10px] flex-shrink-0`}>
                    {STATUS_LABEL[task.status]}
                  </span>
                </div>
                <div className="flex items-center gap-3 mt-1 flex-wrap">
                  <span className="label">{task.category}</span>
                  <span className="label">
                    {task.role === "worker" ? "Client" : "Assigned Agent"}:{" "}
                    <span className="font-mono text-[#6B7A99]">
                      {shortAddress(task.client)}
                    </span>
                  </span>
                  {task.deadline !== "—" && (
                    <span className="label text-amber-400/80">
                      Deadline in {task.deadline}
                    </span>
                  )}
                </div>
              </div>

              {/* Reward */}
              <div className="text-right flex-shrink-0">
                <div className="font-mono text-sm font-semibold text-[#F4EFE6]">
                  {task.reward}
                </div>
                <div className="label text-[10px] capitalize">{task.role}</div>
              </div>

              {/* Action */}
              {(task.status === "active" || task.status === "submitted") && (
                <button
                  className="btn-ghost text-xs px-3 py-1.5 flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity"
                  onClick={(e) => e.stopPropagation()}
                >
                  {task.status === "active" ? "Submit →" : "View →"}
                </button>
              )}
            </div>
          ))
        )}
      </div>

      {/* Summary strip */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-4 border-t border-[#2A241B]">
        {[
          { label: "Active", value: AGENT_TASKS.filter((t) => t.status === "active").length, color: "text-emerald-400" },
          { label: "Pending", value: AGENT_TASKS.filter((t) => t.status === "bidding" || t.status === "submitted").length, color: "text-amber-400" },
          { label: "Done", value: AGENT_TASKS.filter((t) => t.status === "completed").length, color: "text-cyan" },
          { label: "Disputed", value: AGENT_TASKS.filter((t) => t.status === "disputed").length, color: "text-red-400" },
        ].map((s) => (
          <div key={s.label} className="stat-block items-center">
            <span className="label text-center">{s.label}</span>
            <span className={`font-mono text-xl font-bold ${s.color} mt-0.5`}>{s.value}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
"use client";

import { useState } from "react";
import { shortAddress, formatEth, repColor, repLabel } from "@/lib/utils";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
interface DashboardHeaderProps {
  agent: any;
}

const OWNER_ADDRESS = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045";

export function DashboardHeader({ agent }: DashboardHeaderProps) {
  const [copied, setCopied] = useState<"wallet" | "owner" | null>(null);

  const copy = (text: string, type: "wallet" | "owner") => {
    navigator.clipboard.writeText(text);
    setCopied(type);
    setTimeout(() => setCopied(null), 1500);
  };

  const reputation = agent?.reputation ?? agent?.reputationScore ?? 5000;
  const tasksCompleted = agent?.tasksCompleted ?? agent?.tasks ?? 0;
  const earned = agent?.earned ?? agent?.totalEarned ?? "0";
  const wallet = agent?.wallet ?? agent?.agentWallet ?? agent?.address ?? "0x0000000000000000000000000000000000000000";
  const status = agent?.status ?? "active";
  const capabilities = agent?.capabilities ?? agent?.skills ?? [];
  const description = agent?.description ?? agent?.bio ?? "";

  const repPct = (reputation / 10000) * 100;
  const color = repColor(reputation);

  return (
    <div className="card p-6 relative overflow-hidden">
      {/* Subtle glow behind agent name */}
      <div
        className="absolute top-0 left-0 w-64 h-32 pointer-events-none"
        style={{
          background: `radial-gradient(ellipse at 0% 0%, ${color}14, transparent 70%)`,
        }}
      />

      <div className="relative flex flex-col md:flex-row md:items-start gap-6">
        {/* Avatar + identity */}
        <div className="flex items-start gap-4 flex-1">
          {/* Avatar */}
          <div
            className="w-14 h-14 rounded-xl flex items-center justify-center flex-shrink-0 font-display font-bold text-xl border"
            style={{
              background: `${color}18`,
              borderColor: `${color}35`,
              color,
            }}
          >
            {agent.name.slice(0, 2).toUpperCase()}
          </div>

          {/* Name + meta */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-3 flex-wrap">
              <h1 className="font-display text-2xl font-bold text-[#F4EFE6]">
                {agent.name}
              </h1>
              <span
                className={`badge text-xs ${
                  status === "active"
                    ? "badge-active"
                    : "badge-inactive"
                }`}
              >
                <span
                  className={`w-1.5 h-1.5 rounded-full pulse-dot ${
                    agent.status === "active" ? "bg-emerald-400" : "bg-[#A89F8D]"
                  }`}
                />
                {agent.status}
              </span>
              <span className="badge badge-violet">{agent.category}</span>
            </div>

            <p className="text-[#A89F8D] text-sm mt-1 max-w-lg line-clamp-2">
                  {description}
            </p>

            {/* Addresses */}
            <div className="flex flex-wrap gap-4 mt-3">
              <button
                onClick={() => copy(agent.wallet, "wallet")}
                className="flex items-center gap-2 group"
                title="Copy agent wallet"
              >
                <span className="label">Agent Wallet</span>
                <span className="address group-hover:text-[#F4EFE6] transition-colors">
                  {shortAddress(wallet)}
                </span>
                <span className="text-[#6B6355] group-hover:text-cyan transition-colors text-xs">
                  {copied === "wallet" ? "✓" : "⎘"}
                </span>
              </button>

              <button
                onClick={() => copy(OWNER_ADDRESS, "owner")}
                className="flex items-center gap-2 group"
                title="Copy owner address"
              >
                <span className="label">Owner</span>
                <span className="address group-hover:text-[#F4EFE6] transition-colors">
                  {shortAddress(OWNER_ADDRESS)}
                </span>
                <span className="text-[#6B6355] group-hover:text-cyan transition-colors text-xs">
                  {copied === "owner" ? "✓" : "⎘"}
                </span>
              </button>

              <div className="flex items-center gap-2">
                <span className="label">Agent ID</span>
                <span className="font-mono text-xs text-[#F4EFE6]">
                  #{agent.id}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Rep score block */}
        <div className="flex flex-col items-end gap-3 flex-shrink-0">
          <div className="text-right">
            <div
              className="font-display text-3xl font-bold tabular-nums"
            style={{ color }}
          >
            {reputation.toLocaleString()}
            </div>
            <div className="label mt-0.5">Reputation Score</div>
          </div>

          {/* Rep bar */}
          <div className="w-40">
            <div className="rep-bar">
              <div
                className="h-full rounded-full transition-all duration-700"
                style={{
                  width: `${repPct}%`,
                  background: `linear-gradient(90deg, ${color}88, ${color})`,
                }}
              />
            </div>
            <div className="flex justify-between mt-1">
              <span className="label">{repLabel(agent.reputation)}</span>
              <span className="label">{repPct.toFixed(1)}%</span>
            </div>
          </div>

          {/* Quick actions */}
          <div className="flex gap-2">
            <button className="btn-secondary text-xs px-3 py-2">
              Edit Profile
            </button>
            <button className="btn-primary text-xs px-3 py-2">
              Post Task
            </button>
          </div>
        </div>
      </div>

      {/* Bottom stats strip */}
      <div className="relative mt-6 pt-5 border-t border-[#2A241B] grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { label: "Tasks Completed", value: tasksCompleted.toString(), mono: true },
          { label: "Total Earned", value: formatEth(earned), mono: true },
          { label: "Capabilities", value: capabilities.length.toString(), mono: true },
          { label: "Chain", value: "Ethereum", mono: false },
        ].map((stat) => (
          <div key={stat.label} className="stat-block">
            <span className="label">{stat.label}</span>
            <span
              className={`text-lg font-semibold text-[#F4EFE6] mt-0.5 ${
                stat.mono ? "font-mono" : "font-display"
              }`}
            >
              {stat.value}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
"use client";

import { useState } from "react";
import { ArrowRight, Shield, Clock, Info, ChevronDown } from "lucide-react";
import { type Task } from "@/lib/contracts";
import { formatEth } from "@/lib/utils";

export function TaskBidPanel({ task }: { task: Task }) {
  const [proposal, setProposal] = useState("");
  const [estimate, setEstimate] = useState("3");

  const isOpen = task.status === 0;
  const reward  = formatEth(task.reward, 3);

  return (
    <div className="space-y-4">

      {/* Reward card */}
      <div className="card p-5">
        <div className="label mb-1">Task Reward (Escrowed)</div>
        <div className="flex items-baseline gap-2 mb-4">
          <span className="font-display font-bold text-4xl text-[#F0F4FF]">{reward}</span>
          <span className="font-mono text-base text-[#8892B0]">ETH</span>
        </div>

        {/* Breakdown */}
        <div className="space-y-2 pt-3 border-t border-[#1A2035]">
          {[
            { label: "Gross reward",    value: `${reward} ETH`,  color: "text-[#F0F4FF]" },
            { label: "Platform fee (2.5%)", value: `−${(Number(task.reward) / 1e18 * 0.025).toFixed(4)} ETH`, color: "text-rose" },
            { label: "You receive",     value: `${(Number(task.reward) / 1e18 * 0.975).toFixed(4)} ETH`, color: "text-emerald" },
          ].map(({ label, value, color }) => (
            <div key={label} className="flex justify-between items-center">
              <span className="font-mono text-xs text-[#8892B0]">{label}</span>
              <span className={`font-mono text-xs font-semibold ${color}`}>{value}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Bid form */}
      <div className="card p-5 space-y-4">
        <h3 className="font-display font-semibold text-[#F0F4FF]">
          {isOpen ? "Submit Your Bid" : "Task No Longer Open"}
        </h3>

        {isOpen ? (
          <>
            {/* Proposal */}
            <div>
              <label className="label mb-1.5 block">Proposal</label>
              <textarea
                rows={4}
                value={proposal}
                onChange={(e) => setProposal(e.target.value)}
                placeholder="Describe your approach, methodology, and why you're the best fit..."
                className="input resize-none"
              />
            </div>

            {/* Time estimate */}
            <div>
              <label className="label mb-1.5 block">Estimated Completion</label>
              <div className="relative">
                <select
                  value={estimate}
                  onChange={(e) => setEstimate(e.target.value)}
                  className="input cursor-pointer appearance-none pr-8"
                >
                  <option value="1">1 day</option>
                  <option value="2">2 days</option>
                  <option value="3">3 days</option>
                  <option value="5">5 days</option>
                  <option value="7">7 days</option>
                  <option value="14">14 days</option>
                </select>
                <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#4A5568] pointer-events-none" />
              </div>
            </div>

            {/* Min rep check */}
            {task.minReputation > 0 && (
              <div className="flex items-center gap-2.5 px-3 py-2.5 rounded-lg bg-amber/5 border border-amber/20">
                <Shield className="w-4 h-4 text-amber shrink-0" />
                <div>
                  <div className="font-mono text-xs text-amber">Reputation required</div>
                  <div className="font-mono text-[10px] text-[#8892B0]">
                    Must have ≥ {Math.round(task.minReputation / 100)}% reputation to bid
                  </div>
                </div>
              </div>
            )}

            {/* Info */}
            <div className="flex items-start gap-2.5 px-3 py-2.5 rounded-lg bg-cyan/5 border border-cyan/20">
              <Info className="w-4 h-4 text-cyan shrink-0 mt-0.5" />
              <p className="font-mono text-[10px] text-[#8892B0] leading-relaxed">
                Your proposal is stored on IPFS. If selected, the task reward is paid to your
                ERC-4337 agent wallet upon client approval.
              </p>
            </div>

            <button
              disabled={!proposal.trim()}
              className="btn-primary w-full justify-center py-3 text-sm disabled:opacity-40 disabled:cursor-not-allowed"
            >
              Submit Bid <ArrowRight className="w-4 h-4" />
            </button>
          </>
        ) : (
          <div className="text-center py-6">
            <div className="w-12 h-12 rounded-full bg-[#1A2035] flex items-center justify-center mx-auto mb-3">
              <Clock className="w-5 h-5 text-[#4A5568]" />
            </div>
            <div className="font-mono text-sm text-[#4A5568]">
              {task.status === 1 ? "An agent has been assigned" :
               task.status === 2 ? "Task completed" :
               "Task is no longer accepting bids"}
            </div>
            <a href="/tasks" className="btn-ghost mt-4 text-xs">
              Browse open tasks →
            </a>
          </div>
        )}
      </div>

      {/* Deadline */}
      <div className="card p-4 flex items-center gap-3">
        <Clock className="w-4 h-4 text-[#4A5568] shrink-0" />
        <div>
          <div className="font-mono text-xs text-[#8892B0]">Deadline</div>
          <div className="font-mono text-xs text-[#F0F4FF] mt-0.5">
            {new Date(task.deadline * 1000).toLocaleDateString("en-US", {
              weekday: "long", month: "short", day: "numeric", hour: "2-digit", minute: "2-digit",
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
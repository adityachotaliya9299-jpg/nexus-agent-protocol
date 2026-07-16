"use client";

import { useState } from "react";
import { Shield, Clock, Info, ChevronDown } from "lucide-react";
import { useAccount } from "wagmi";
import { type Task } from "@/lib/contracts";
import { formatEth } from "@/lib/utils";
import { useMyAgentId } from "@/lib/hooks/useAgentRegistry";
import { useSubmitBid } from "@/lib/hooks/useTaskMarketplace";
import { TxButton } from "@/components/wallet/TxButton";

export function TaskBidPanel({ task }: { task: Task }) {
  const [proposal, setProposal] = useState("");
  const [estimate, setEstimate] = useState("3");

  const { isConnected } = useAccount();
  const { data: myAgentId } = useMyAgentId();
  const agentId = myAgentId ? Number(myAgentId) : 0;
  const hasAgent = agentId > 0;

  const { submitBid, isPending, isConfirming, isSuccess } = useSubmitBid();

  const isOpen = task.status === 0;
  const reward = formatEth(task.reward, 3);

  const onSubmit = () => {
    if (!hasAgent || !proposal.trim()) return;
    submitBid(task.taskId as `0x${string}`, agentId, proposal.trim(), Number(estimate) * 86400);
  };

  return (
    <div className="space-y-4">
      <div className="card p-5">
        <div className="label mb-1">Task reward (escrowed)</div>
        <div className="flex items-baseline gap-2 mb-4">
          <span className="font-display font-bold text-3xl sm:text-4xl text-bone">{reward}</span>
          <span className="font-mono text-base text-text-secondary">ETH</span>
        </div>

        <div className="space-y-2 pt-3 border-t border-border">
          {[
            { label: "Gross reward", value: `${reward} ETH`, color: "text-bone" },
            { label: "Platform fee (2.5%)", value: `−${(Number(task.reward) / 1e18 * 0.025).toFixed(4)} ETH`, color: "text-rose" },
            { label: "Agent receives", value: `${(Number(task.reward) / 1e18 * 0.975).toFixed(4)} ETH`, color: "text-emerald" },
          ].map(({ label, value, color }) => (
            <div key={label} className="flex justify-between items-center">
              <span className="font-mono text-xs text-text-secondary">{label}</span>
              <span className={`font-mono text-xs font-semibold ${color}`}>{value}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="card p-5 space-y-4">
        <h3 className="font-display font-semibold text-bone">
          {isOpen ? "Submit your bid" : "Task no longer open"}
        </h3>

        {isOpen ? (
          <>
            <div>
              <label className="label mb-1.5 block">Proposal</label>
              <textarea
                rows={4}
                value={proposal}
                onChange={e => setProposal(e.target.value)}
                placeholder="Describe your approach and why your agent is the best fit…"
                className="input resize-none"
              />
            </div>

            <div>
              <label className="label mb-1.5 block">Estimated completion</label>
              <div className="relative">
                <select
                  value={estimate}
                  onChange={e => setEstimate(e.target.value)}
                  className="input cursor-pointer appearance-none pr-8"
                >
                  {[1, 2, 3, 5, 7, 14].map(d => (
                    <option key={d} value={d}>{d} day{d > 1 ? "s" : ""}</option>
                  ))}
                </select>
                <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-muted pointer-events-none" />
              </div>
            </div>

            {task.minReputation > 0 && (
              <div className="flex items-center gap-2.5 px-3 py-2.5 rounded-xl bg-amber/5 border border-amber/20">
                <Shield className="w-4 h-4 text-amber shrink-0" />
                <div>
                  <div className="font-mono text-xs text-amber">Reputation required</div>
                  <div className="font-mono text-[10px] text-text-secondary">
                    Your agent needs ≥ {task.minReputation.toLocaleString()} reputation to bid
                  </div>
                </div>
              </div>
            )}

            {!isConnected ? (
              <p className="font-mono text-xs text-text-muted text-center py-2">
                Connect a wallet to bid.
              </p>
            ) : !hasAgent ? (
              <div className="flex items-start gap-2.5 px-3 py-2.5 rounded-xl bg-gold/5 border border-gold/20">
                <Info className="w-4 h-4 text-gold shrink-0 mt-0.5" />
                <p className="font-mono text-[10px] text-text-secondary leading-relaxed">
                  This wallet has no registered agent. Register one from the{" "}
                  <a href="/dashboard" className="text-gold hover:underline">dashboard</a> first.
                </p>
              </div>
            ) : (
              <TxButton
                onClick={onSubmit}
                isPending={isPending}
                isConfirming={isConfirming}
                isSuccess={isSuccess}
                disabled={!proposal.trim()}
                className="btn-primary w-full justify-center py-3 text-sm"
              >
                Submit bid as Agent #{agentId}
              </TxButton>
            )}
          </>
        ) : (
          <div className="text-center py-6">
            <div className="w-12 h-12 rounded-full bg-border flex items-center justify-center mx-auto mb-3">
              <Clock className="w-5 h-5 text-text-muted" />
            </div>
            <div className="font-mono text-sm text-text-muted">
              {task.status === 1 ? "An agent has been assigned" :
               task.status === 3 ? "Task completed" :
               "Task is no longer accepting bids"}
            </div>
            <a href="/tasks" className="btn-ghost mt-4 text-xs">Browse open tasks →</a>
          </div>
        )}
      </div>

      <div className="card p-4 flex items-center gap-3">
        <Clock className="w-4 h-4 text-text-muted shrink-0" />
        <div>
          <div className="font-mono text-xs text-text-secondary">Deadline</div>
          <div className="font-mono text-xs text-bone mt-0.5">
            {new Date(task.deadline * 1000).toLocaleDateString("en-US", {
              weekday: "long", month: "short", day: "numeric", hour: "2-digit", minute: "2-digit",
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

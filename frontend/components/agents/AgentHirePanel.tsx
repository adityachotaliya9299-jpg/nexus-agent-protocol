"use client";

import { useState } from "react";
import { ArrowRight, Zap, RefreshCw, Shield, Star, ChevronDown } from "lucide-react";
import { type Agent } from "@/lib/contracts";
import { repToPercent, repColor } from "@/lib/utils";

const TIERS = [
  { id: "basic",      label: "Basic",      price: "0.05", period: "30 days", features: ["5 tasks/month", "24h response", "Basic support"] },
  { id: "pro",        label: "Pro",        price: "0.15", period: "30 days", features: ["Unlimited tasks", "4h response", "Priority support", "ZK proofs"] },
  { id: "enterprise", label: "Enterprise", price: "0.50", period: "30 days", features: ["Dedicated pipeline", "1h response", "24/7 support", "Custom integrations"] },
];

export function AgentHirePanel({ agent }: { agent: Agent }) {
  const [tab, setTab]   = useState<"task" | "sub">("task");
  const [tier, setTier] = useState("pro");

  const selectedTier = TIERS.find((t) => t.id === tier) ?? TIERS[1];
  const repPct = repToPercent(agent.reputationScore);
  const scoreColor = repColor(agent.reputationScore);

  return (
    <div className="space-y-4">

      {/* Tab selector */}
      <div className="card p-1 flex">
        {[
          { id: "task", label: "Post Task",    icon: Zap },
          { id: "sub",  label: "Subscribe",    icon: RefreshCw },
        ].map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            onClick={() => setTab(id as "task" | "sub")}
            className={`flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-md text-sm font-medium transition-all ${
              tab === id
                ? "bg-cyan text-[#080B12] font-semibold shadow-[0_0_15px_rgba(0,229,255,0.3)]"
                : "text-[#8892B0] hover:text-[#F0F4FF]"
            }`}
          >
            <Icon className="w-3.5 h-3.5" />
            {label}
          </button>
        ))}
      </div>

      {/* Task hire panel */}
      {tab === "task" && (
        <div className="card p-5 space-y-4">
          <div>
            <div className="label mb-1">Starting Price</div>
            <div className="flex items-baseline gap-1.5">
              <span className="font-display font-bold text-3xl text-[#F0F4FF]">
                {agent.pricePerTask}
              </span>
              <span className="font-mono text-sm text-[#8892B0]">ETH / task</span>
            </div>
          </div>

          {/* Task brief input */}
          <div>
            <label className="label mb-1.5 block">Task Description</label>
            <textarea
              rows={3}
              placeholder="Describe what you need the agent to do..."
              className="input resize-none"
            />
          </div>

          {/* Deadline */}
          <div>
            <label className="label mb-1.5 block">Deadline</label>
            <div className="relative">
              <select className="input cursor-pointer appearance-none pr-8">
                <option>24 hours</option>
                <option>3 days</option>
                <option>7 days</option>
                <option>14 days</option>
                <option>30 days</option>
              </select>
              <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#4A5568] pointer-events-none" />
            </div>
          </div>

          {/* Min reputation display */}
          <div className="flex items-center justify-between px-3 py-2.5 rounded-lg bg-[#080B12] border border-[#1A2035]">
            <div className="flex items-center gap-2">
              <Shield className="w-4 h-4 text-emerald" />
              <span className="text-xs text-[#8892B0]">Agent reputation</span>
            </div>
            <span className={`font-mono font-semibold text-sm ${scoreColor}`}>
              {repPct}%
            </span>
          </div>

          <button className="btn-primary w-full justify-center py-3 text-sm">
            Post Task to Agent <ArrowRight className="w-4 h-4" />
          </button>

          <p className="text-[10px] text-[#4A5568] text-center font-mono">
            ETH held in escrow until task completion
          </p>
        </div>
      )}

      {/* Subscribe panel */}
      {tab === "sub" && (
        <div className="card p-5 space-y-4">
          <div>
            <div className="label mb-3">Choose Plan</div>
            <div className="space-y-2">
              {TIERS.map((t) => (
                <button
                  key={t.id}
                  onClick={() => setTier(t.id)}
                  className={`w-full text-left px-4 py-3 rounded-lg border transition-all ${
                    tier === t.id
                      ? "border-cyan/40 bg-cyan/5"
                      : "border-[#1A2035] bg-[#080B12] hover:border-[#2A3555]"
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      {tier === t.id && <Star className="w-3.5 h-3.5 text-cyan" />}
                      <span className={`font-display font-semibold text-sm ${tier === t.id ? "text-cyan" : "text-[#F0F4FF]"}`}>
                        {t.label}
                      </span>
                    </div>
                    <span className={`font-mono font-bold text-sm ${tier === t.id ? "text-cyan" : "text-[#8892B0]"}`}>
                      {t.price} ETH
                    </span>
                  </div>
                  <div className="font-mono text-[10px] text-[#4A5568] mt-0.5">
                    per {t.period}
                  </div>
                </button>
              ))}
            </div>
          </div>

          {/* Plan features */}
          <div className="px-3 py-3 rounded-lg bg-[#080B12] border border-[#1A2035] space-y-2">
            {selectedTier.features.map((f) => (
              <div key={f} className="flex items-center gap-2">
                <div className="w-1.5 h-1.5 rounded-full bg-cyan shrink-0" />
                <span className="text-xs text-[#8892B0]">{f}</span>
              </div>
            ))}
          </div>

          <button className="btn-primary w-full justify-center py-3 text-sm">
            Subscribe — {selectedTier.price} ETH/mo <ArrowRight className="w-4 h-4" />
          </button>

          <p className="text-[10px] text-[#4A5568] text-center font-mono">
            Cancel anytime · Recurring payment via smart contract
          </p>
        </div>
      )}

      {/* Trust signals */}
      <div className="card p-4 space-y-3">
        <div className="label">Trust & Verification</div>
        {[
          { label: "On-chain identity verified", ok: true },
          { label: "ERC-4337 wallet deployed",   ok: true },
          { label: "ZK proof on record",          ok: agent.reputationScore > 7000 },
          { label: "No disputes (last 90 days)",  ok: agent.reputationScore > 6000 },
        ].map(({ label, ok }) => (
          <div key={label} className="flex items-center gap-2.5">
            <div className={`w-4 h-4 rounded-full flex items-center justify-center ${ok ? "bg-emerald/20" : "bg-[#1A2035]"}`}>
              <div className={`w-1.5 h-1.5 rounded-full ${ok ? "bg-emerald" : "bg-[#2A3555]"}`} />
            </div>
            <span className={`text-xs font-mono ${ok ? "text-[#8892B0]" : "text-[#4A5568]"}`}>
              {label}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
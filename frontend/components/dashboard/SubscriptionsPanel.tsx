"use client";

import { useState } from "react";

type PlanTier = "BASIC" | "STANDARD" | "PREMIUM" | "ENTERPRISE";

const TIER_STYLES: Record<PlanTier, { color: string; bg: string; border: string }> = {
  BASIC: { color: "#8892B0", bg: "bg-[#1A2035]/40", border: "border-[#2A3555]" },
  STANDARD: { color: "#00E5FF", bg: "bg-cyan/5", border: "border-cyan/15" },
  PREMIUM: { color: "#8B5CF6", bg: "bg-violet/5", border: "border-violet/15" },
  ENTERPRISE: { color: "#F59E0B", bg: "bg-amber-500/5", border: "border-amber-500/15" },
};

// Plans this agent is offering
const MY_PLANS = [
  {
    id: 1,
    name: "Weekly DeFi Audit",
    tier: "STANDARD" as PlanTier,
    price: "0.1 ETH",
    interval: "7 days",
    subscribers: 3,
    maxSubs: 10,
    active: true,
    description: "Weekly review of DeFi protocol changes, risk scoring, and recommendations.",
  },
  {
    id: 2,
    name: "On-Call Security",
    tier: "PREMIUM" as PlanTier,
    price: "0.35 ETH",
    interval: "30 days",
    subscribers: 1,
    maxSubs: 5,
    active: true,
    description: "Priority access for security reviews and incident response.",
  },
];

// Subscriptions this agent has purchased from others
const MY_SUBSCRIPTIONS = [
  {
    agentName: "PriceOracle-7",
    tier: "BASIC" as PlanTier,
    price: "0.05 ETH",
    interval: "7 days",
    nextPayment: "2025-04-14",
    status: "active",
  },
  {
    agentName: "ZKProver-Alpha",
    tier: "PREMIUM" as PlanTier,
    price: "0.2 ETH",
    interval: "30 days",
    nextPayment: "2025-05-01",
    status: "active",
  },
  {
    agentName: "DataFeed-ETH",
    tier: "STANDARD" as PlanTier,
    price: "0.08 ETH",
    interval: "30 days",
    nextPayment: "—",
    status: "paused",
  },
];

export function SubscriptionsPanel() {
  const [activeSection, setActiveSection] = useState<"offered" | "subscribed">("offered");
  const [showCreatePlan, setShowCreatePlan] = useState(false);

  return (
    <div className="space-y-6">
      {/* Section toggle */}
      <div className="flex gap-1 bg-[#0D1120] border border-[#1A2035] rounded-lg p-1 w-fit">
        <button
          onClick={() => setActiveSection("offered")}
          className={`px-5 py-2 rounded-md text-sm font-medium font-display transition-all duration-150 ${
            activeSection === "offered"
              ? "bg-[#0F1A2E] text-cyan border border-cyan/20"
              : "text-[#8892B0] hover:text-[#F0F4FF]"
          }`}
        >
          Plans I Offer
        </button>
        <button
          onClick={() => setActiveSection("subscribed")}
          className={`px-5 py-2 rounded-md text-sm font-medium font-display transition-all duration-150 ${
            activeSection === "subscribed"
              ? "bg-[#0F1A2E] text-cyan border border-cyan/20"
              : "text-[#8892B0] hover:text-[#F0F4FF]"
          }`}
        >
          My Subscriptions
        </button>
      </div>

      {activeSection === "offered" ? (
        <div className="space-y-4">
          {/* Plan cards */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            {MY_PLANS.map((plan) => {
              const style = TIER_STYLES[plan.tier];
              const fillPct = (plan.subscribers / plan.maxSubs) * 100;
              return (
                <div
                  key={plan.id}
                  className={`card p-5 border ${style.border} ${style.bg} space-y-4`}
                >
                  <div className="flex items-start justify-between">
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        <span
                          className="text-[10px] font-mono font-bold px-2 py-0.5 rounded border"
                          style={{
                            color: style.color,
                            borderColor: `${style.color}30`,
                            background: `${style.color}10`,
                          }}
                        >
                          {plan.tier}
                        </span>
                        <span
                          className={`w-1.5 h-1.5 rounded-full ${
                            plan.active ? "bg-emerald-400 pulse-dot" : "bg-[#4A5568]"
                          }`}
                        />
                      </div>
                      <h3 className="font-display font-semibold text-[#F0F4FF]">
                        {plan.name}
                      </h3>
                    </div>
                    <div className="text-right">
                      <div
                        className="font-mono font-bold text-lg tabular-nums"
                        style={{ color: style.color }}
                      >
                        {plan.price}
                      </div>
                      <div className="label text-[10px]">per {plan.interval}</div>
                    </div>
                  </div>

                  <p className="text-sm text-[#8892B0]">{plan.description}</p>

                  {/* Subscriber fill */}
                  <div>
                    <div className="flex justify-between mb-1.5">
                      <span className="label">Subscribers</span>
                      <span className="font-mono text-xs text-[#F0F4FF]">
                        {plan.subscribers} / {plan.maxSubs}
                      </span>
                    </div>
                    <div className="rep-bar">
                      <div
                        className="h-full rounded-full transition-all duration-700"
                        style={{
                          width: `${fillPct}%`,
                          background: style.color,
                        }}
                      />
                    </div>
                  </div>

                  <div className="flex gap-2 pt-1">
                    <button className="btn-secondary text-xs flex-1">Edit Plan</button>
                    <button
                      className={`text-xs px-3 py-2 rounded-md border transition-colors ${
                        plan.active
                          ? "border-red-500/20 text-red-400 hover:bg-red-500/10"
                          : "border-emerald-500/20 text-emerald-400 hover:bg-emerald-500/10"
                      }`}
                    >
                      {plan.active ? "Pause" : "Activate"}
                    </button>
                  </div>
                </div>
              );
            })}

            {/* Create new plan card */}
            <button
              onClick={() => setShowCreatePlan(true)}
              className="card border border-dashed border-[#2A3555] p-5 flex flex-col items-center justify-center gap-3 hover:border-cyan/20 hover:bg-[#0F1628] transition-all duration-200 min-h-[200px]"
            >
              <div className="w-10 h-10 rounded-full bg-[#1A2035] border border-[#2A3555] flex items-center justify-center text-[#8892B0] text-xl">
                +
              </div>
              <div className="text-center">
                <p className="text-sm font-medium text-[#8892B0]">Create New Plan</p>
                <p className="text-xs text-[#4A5568] mt-0.5">Set up recurring agent services</p>
              </div>
            </button>
          </div>

          {/* Revenue summary */}
          <div className="card p-5 flex items-center gap-6">
            {[
              { label: "Monthly Recurring", value: `${(0.1 * 3 * 4 + 0.35 * 1).toFixed(2)} ETH` },
              { label: "Active Plans", value: "2" },
              { label: "Total Subscribers", value: "4" },
            ].map((stat) => (
              <div key={stat.label} className="stat-block">
                <span className="label">{stat.label}</span>
                <span className="font-mono text-lg font-semibold text-[#F0F4FF] mt-0.5">
                  {stat.value}
                </span>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="space-y-3">
          {MY_SUBSCRIPTIONS.map((sub, i) => {
            const style = TIER_STYLES[sub.tier];
            return (
              <div
                key={i}
                className={`card p-4 border ${
                  sub.status === "active" ? style.border : "border-[#1A2035]"
                } flex items-center gap-4`}
              >
                <div
                  className="w-10 h-10 rounded-lg flex items-center justify-center font-display font-bold text-sm flex-shrink-0"
                  style={{
                    background: `${style.color}15`,
                    color: style.color,
                  }}
                >
                  {sub.agentName.slice(0, 2).toUpperCase()}
                </div>

                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="font-display font-medium text-[#F0F4FF] text-sm">
                      {sub.agentName}
                    </span>
                    <span
                      className="text-[10px] font-mono px-1.5 py-0.5 rounded border"
                      style={{
                        color: style.color,
                        borderColor: `${style.color}30`,
                        background: `${style.color}10`,
                      }}
                    >
                      {sub.tier}
                    </span>
                    <span
                      className={`badge text-[10px] ${
                        sub.status === "active" ? "badge-active" : "badge-inactive"
                      }`}
                    >
                      {sub.status}
                    </span>
                  </div>
                  <div className="flex gap-3 mt-1">
                    <span className="label">{sub.price} / {sub.interval}</span>
                    {sub.nextPayment !== "—" && (
                      <span className="label">
                        Next: {new Date(sub.nextPayment).toLocaleDateString("en", { month: "short", day: "numeric" })}
                      </span>
                    )}
                  </div>
                </div>

                <div className="flex gap-2 flex-shrink-0">
                  <button
                    className={`text-xs px-3 py-1.5 rounded-md border transition-colors ${
                      sub.status === "active"
                        ? "border-amber-500/20 text-amber-400 hover:bg-amber-500/10"
                        : "border-emerald-500/20 text-emerald-400 hover:bg-emerald-500/10"
                    }`}
                  >
                    {sub.status === "active" ? "Pause" : "Resume"}
                  </button>
                  <button className="text-xs px-3 py-1.5 rounded-md border border-red-500/20 text-red-400 hover:bg-red-500/10 transition-colors">
                    Cancel
                  </button>
                </div>
              </div>
            );
          })}

          <div className="card p-4 flex items-center gap-4">
            <div className="flex-1">
              <span className="label">Monthly Outgoing</span>
              <div className="font-mono text-lg font-semibold text-red-400 mt-0.5 tabular-nums">
                −0.33 ETH
              </div>
            </div>
            <button className="btn-secondary text-sm">Browse Agent Plans</button>
          </div>
        </div>
      )}

      {/* Create plan modal */}
      {showCreatePlan && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div
            className="absolute inset-0 bg-black/70 backdrop-blur-sm"
            onClick={() => setShowCreatePlan(false)}
          />
          <div className="relative card p-6 w-full max-w-md space-y-4">
            <h3 className="font-display font-bold text-[#F0F4FF] text-lg">Create Subscription Plan</h3>
            <div>
              <label className="label block mb-1.5">Plan Name</label>
              <input className="input" placeholder="e.g. Weekly DeFi Audit" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="label block mb-1.5">Price (ETH)</label>
                <input className="input" type="number" placeholder="0.1" step="0.01" />
              </div>
              <div>
                <label className="label block mb-1.5">Interval (days)</label>
                <input className="input" type="number" placeholder="7" />
              </div>
            </div>
            <div>
              <label className="label block mb-1.5">Tier</label>
              <select className="input">
                {Object.keys(TIER_STYLES).map((t) => (
                  <option key={t} value={t}>{t}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label block mb-1.5">Max Subscribers</label>
              <input className="input" type="number" placeholder="10" />
            </div>
            <div>
              <label className="label block mb-1.5">Description</label>
              <textarea className="input resize-none" rows={2} placeholder="What does this plan include?" />
            </div>
            <div className="flex gap-3 pt-2">
              <button onClick={() => setShowCreatePlan(false)} className="btn-secondary flex-1">Cancel</button>
              <button className="btn-primary flex-1">Create Plan</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
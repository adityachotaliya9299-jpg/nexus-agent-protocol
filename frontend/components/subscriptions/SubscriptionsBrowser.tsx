"use client";

import { useEffect, useState } from "react";
import { formatEther, parseEther } from "viem";
import { useSgPlans } from "@/lib/hooks/useSubgraph";
import { useSubscribe } from "@/lib/hooks/useSubscriptionManager";

type PlanTier = "BASIC" | "STANDARD" | "PREMIUM" | "ENTERPRISE";
type Category = "All" | "On-chain" | "DeFi" | "Security" | "ZK" | "Oracle" | "Infrastructure" | "AI";
type SortBy = "popular" | "price_asc" | "price_desc" | "rep";

const TIER_STYLES: Record<PlanTier, { color: string; border: string; bg: string }> = {
  BASIC:      { color: "#A89F8D", border: "border-[#3A3226]",      bg: "bg-[#2A241B]/30" },
  STANDARD:   { color: "#F2A93B", border: "border-cyan/20",        bg: "bg-cyan/5" },
  PREMIUM:    { color: "#FF6B3D", border: "border-violet/20",      bg: "bg-violet/5" },
  ENTERPRISE: { color: "#F2A93B", border: "border-amber-500/20",   bg: "bg-amber-500/5" },
};

interface BrowserPlan {
  id: string | number;
  planId?: `0x${string}`;   // set only for real on-chain plans
  agentName: string;
  agentId: number;
  agentRep: number;
  tier: PlanTier;
  name: string;
  description: string;
  price: string;
  interval: number;
  maxSubscribers: number;
  currentSubscribers: number;
  category: string;
  features: string[];
  active: boolean;
  showcase?: boolean;
}

const TIER_BY_INDEX: PlanTier[] = ["BASIC", "STANDARD", "PREMIUM", "ENTERPRISE"];

const MOCK_PLANS = [
  {
    id: 1,
    agentName: "CodeSentinel-v2",
    agentId: 1,
    agentRep: 8750,
    tier: "PREMIUM" as PlanTier,
    name: "Weekly DeFi Audit",
    description: "Weekly deep-dive security review of DeFi protocol changes. Covers reentrancy, oracle manipulation, and access control. Includes written report and risk score.",
    price: "0.35",
    interval: 7,
    maxSubscribers: 5,
    currentSubscribers: 3,
    category: "Security",
    features: ["Weekly protocol review", "Risk scoring 0–10", "IPFS report delivery", "Priority response"],
    active: true,
  },
  {
    id: 2,
    agentName: "ZKProver-Alpha",
    agentId: 4,
    agentRep: 7200,
    tier: "STANDARD" as PlanTier,
    name: "ZK Circuit Verification",
    description: "On-demand verification of custom ZK circuits using Groth16 and PLONK backends. Submit your circuit, get a proof and verification key within 24h.",
    price: "0.2",
    interval: 30,
    maxSubscribers: 20,
    currentSubscribers: 11,
    category: "ZK",
    features: ["Groth16 + PLONK support", "24h turnaround", "On-chain proof delivery", "Circuit optimization hints"],
    active: true,
  },
  {
    id: 3,
    agentName: "PriceOracle-7",
    agentId: 2,
    agentRep: 6100,
    tier: "BASIC" as PlanTier,
    name: "ETH/USD Price Feed",
    description: "Aggregated ETH/USD price from 5 sources with outlier rejection. TWAP and spot price updated every block. Free tier includes 1000 reads/week.",
    price: "0.05",
    interval: 7,
    maxSubscribers: 100,
    currentSubscribers: 67,
    category: "Oracle",
    features: ["5-source aggregation", "TWAP + spot price", "1000 reads/week", "Uptime SLA 99.5%"],
    active: true,
  },
  {
    id: 4,
    agentName: "InfraOps-9",
    agentId: 5,
    agentRep: 5800,
    tier: "ENTERPRISE" as PlanTier,
    name: "Node Operations Suite",
    description: "Full infrastructure management for validator and RPC nodes. Includes monitoring, alerting, auto-recovery, and monthly performance reports.",
    price: "1.2",
    interval: 30,
    maxSubscribers: 3,
    currentSubscribers: 1,
    category: "Infrastructure",
    features: ["24/7 node monitoring", "Auto-recovery scripts", "Monthly perf report", "Dedicated channel"],
    active: true,
  },
  {
    id: 5,
    agentName: "DeFiQuant-3",
    agentId: 3,
    agentRep: 7800,
    tier: "STANDARD" as PlanTier,
    name: "MEV Strategy Feed",
    description: "Weekly MEV opportunity analysis including sandwich, arbitrage, and liquidation patterns. Includes backtest data and expected EV per strategy.",
    price: "0.15",
    interval: 7,
    maxSubscribers: 15,
    currentSubscribers: 8,
    category: "DeFi",
    features: ["3 strategy types", "Backtest data (90d)", "Expected EV metrics", "Private Telegram feed"],
    active: true,
  },
  {
    id: 6,
    agentName: "AIReviewer-1",
    agentId: 6,
    agentRep: 6400,
    tier: "BASIC" as PlanTier,
    name: "Code Review Subscription",
    description: "Automated Solidity code review using pattern matching and semantic analysis. Get 5 reviews per week with vulnerability classification and fix suggestions.",
    price: "0.08",
    interval: 30,
    maxSubscribers: 50,
    currentSubscribers: 22,
    category: "AI",
    features: ["5 reviews/week", "Vulnerability classification", "Fix suggestions", "Historical scan log"],
    active: true,
  },
];

const CATEGORIES: Category[] = ["All", "On-chain", "DeFi", "Security", "ZK", "Oracle", "Infrastructure", "AI"];

function repColor(score: number): string {
  if (score >= 9000) return "#F2A93B";
  if (score >= 7500) return "#F2A93B";
  if (score >= 6000) return "#FF6B3D";
  if (score >= 4500) return "#57C99B";
  return "#A89F8D";
}

function repLabel(score: number): string {
  if (score >= 9000) return "Elite";
  if (score >= 7500) return "Expert";
  if (score >= 6000) return "Advanced";
  if (score >= 4500) return "Established";
  return "Developing";
}

interface SubscribeModalProps {
  plan: BrowserPlan;
  onClose: () => void;
}

function SubscribeModal({ plan, onClose }: SubscribeModalProps) {
  const [confirming, setConfirming] = useState(false);
  const { subscribe, isPending, isConfirming, isSuccess } = useSubscribe();
  const style = TIER_STYLES[plan.tier];
  const busy = confirming || isPending || isConfirming;

  const onConfirm = () => {
    if (plan.planId) {
      // real plan — pay the period price straight into the contract
      subscribe(plan.planId, parseEther(plan.price));
    } else {
      setConfirming(true);
      setTimeout(onClose, 1500);
    }
  };

  useEffect(() => {
    if (!isSuccess) return;
    const t = setTimeout(onClose, 1200);
    return () => clearTimeout(t);
  }, [isSuccess, onClose]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={onClose} />
      <div className="relative card w-full max-w-md space-y-5 p-6">
        <div className="flex items-start justify-between">
          <div>
            <div
              className="text-[10px] font-mono font-bold px-2 py-0.5 rounded border mb-2 inline-block"
              style={{ color: style.color, borderColor: `${style.color}30`, background: `${style.color}10` }}
            >
              {plan.tier}
            </div>
            <h3 className="font-display font-bold text-[#F4EFE6] text-lg">{plan.name}</h3>
            <p className="text-[#A89F8D] text-sm mt-0.5">by {plan.agentName}</p>
          </div>
          <button onClick={onClose} className="text-[#6B6355] hover:text-[#A89F8D] text-xl leading-none">✕</button>
        </div>

        <div className="p-4 rounded-lg bg-[#0B0A08] border border-[#2A241B] space-y-2.5">
          <div className="flex justify-between">
            <span className="label">Price</span>
            <span className="font-mono text-[#F4EFE6] font-semibold">{plan.price} ETH / {plan.interval}d</span>
          </div>
          <div className="flex justify-between">
            <span className="label">Next renewal</span>
            <span className="font-mono text-sm text-[#F4EFE6]">
              {new Date(Date.now() + plan.interval * 86400000).toLocaleDateString("en", { month: "short", day: "numeric", year: "numeric" })}
            </span>
          </div>
          <div className="flex justify-between">
            <span className="label">Slots remaining</span>
            <span className="font-mono text-sm text-[#F4EFE6]">{plan.maxSubscribers - plan.currentSubscribers} of {plan.maxSubscribers}</span>
          </div>
          <div className="flex justify-between">
            <span className="label">Payment goes to</span>
            <span className="font-mono text-xs text-[#A89F8D]">{plan.agentName} wallet</span>
          </div>
        </div>

        <div className="space-y-2">
          <span className="label block">Includes</span>
          {plan.features.map((f) => (
            <div key={f} className="flex items-center gap-2.5">
              <span className="text-cyan text-xs">✓</span>
              <span className="text-sm text-[#A89F8D]">{f}</span>
            </div>
          ))}
        </div>

        <div className="flex gap-3 pt-1">
          <button onClick={onClose} className="btn-secondary flex-1">Cancel</button>
          <button
            onClick={onConfirm}
            className="btn-primary flex-1"
            disabled={busy}
          >
            {isSuccess ? "Subscribed ✓" : busy ? "Subscribing..." : `Subscribe — ${plan.price} ETH`}
          </button>
        </div>
        <p className="text-[#6B6355] text-xs text-center">
          {plan.planId
            ? "Payments flow directly to the agent's wallet via SubscriptionManager on Sepolia."
            : "Showcase plan — subscribing is simulated. Real plans settle on-chain."}
        </p>
      </div>
    </div>
  );
}

export function SubscriptionsBrowser() {
  const [category, setCategory] = useState<Category>("All");
  const [sortBy, setSortBy] = useState<SortBy>("popular");
  const [search, setSearch] = useState("");
  const [selectedTier, setSelectedTier] = useState<PlanTier | "All">("All");
  const [subscribing, setSubscribing] = useState<BrowserPlan | null>(null);

  const { data: sgPlans } = useSgPlans(50);
  const livePlans: BrowserPlan[] = (sgPlans?.subscriptionPlans ?? []).map(p => {
    const agentId = Number(p.agent.agentId);
    const tier = TIER_BY_INDEX[p.tier] ?? "BASIC";
    return {
      id: p.id,
      planId: p.id as `0x${string}`,
      agentName: `Agent #${agentId}`,
      agentId,
      agentRep: 0,
      tier,
      name: `${tier.charAt(0)}${tier.slice(1).toLowerCase()} plan — Agent #${agentId}`,
      description: "On-chain subscription plan. Payment goes directly to the agent each period via the SubscriptionManager contract.",
      price: formatEther(BigInt(p.pricePerPeriod)),
      interval: Math.max(1, Math.round(Number(p.periodDuration) / 86400)),
      maxSubscribers: Number(p.maxSubscribers),
      currentSubscribers: Number(p.currentSubscribers),
      category: "On-chain",
      features: ["Live Sepolia plan", "Automatic renewal", "Cancel anytime", "Direct agent payout"],
      active: p.isActive,
    };
  });

  const allPlans: BrowserPlan[] = [
    ...livePlans,
    ...MOCK_PLANS.map(p => ({ ...p, showcase: true } as BrowserPlan)),
  ];

  const filtered = allPlans
    .filter((p) => category === "All" || p.category === category)
    .filter((p) => selectedTier === "All" || p.tier === selectedTier)
    .filter((p) =>
      search === "" ||
      p.name.toLowerCase().includes(search.toLowerCase()) ||
      p.agentName.toLowerCase().includes(search.toLowerCase())
    )
    .sort((a, b) => {
      if (sortBy === "popular") return b.currentSubscribers - a.currentSubscribers;
      if (sortBy === "price_asc") return parseFloat(a.price) - parseFloat(b.price);
      if (sortBy === "price_desc") return parseFloat(b.price) - parseFloat(a.price);
      if (sortBy === "rep") return b.agentRep - a.agentRep;
      return 0;
    });

  const totalPlans = allPlans.length;
  const totalSubs = allPlans.reduce((s, p) => s + p.currentSubscribers, 0);
  const avgPrice = (allPlans.reduce((s, p) => s + parseFloat(p.price), 0) / Math.max(1, allPlans.length)).toFixed(3);

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="space-y-1">
        <h1 className="font-display text-3xl font-bold text-[#F4EFE6]">
          Agent Subscriptions
        </h1>
        <p className="text-[#A89F8D] text-base">
          Pay-per-period access to specialized autonomous agent services.
        </p>
      </div>

      {/* Stats bar */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: "Active Plans", value: totalPlans.toString() },
          { label: "Total Subscribers", value: totalSubs.toString() },
          { label: "Avg Price / Period", value: `${avgPrice} ETH` },
        ].map((stat) => (
          <div key={stat.label} className="card p-4 stat-block">
            <span className="label">{stat.label}</span>
            <span className="font-mono text-xl font-bold text-[#F4EFE6] mt-1">{stat.value}</span>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-3">
        {/* Search */}
        <div className="relative flex-1">
          <span className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B6355] text-sm">⌕</span>
          <input
            className="input pl-8"
            placeholder="Search plans or agents..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        {/* Tier filter */}
        <select
          className="input w-auto min-w-[140px]"
          value={selectedTier}
          onChange={(e) => setSelectedTier(e.target.value as PlanTier | "All")}
        >
          <option value="All">All Tiers</option>
          {(["BASIC", "STANDARD", "PREMIUM", "ENTERPRISE"] as PlanTier[]).map((t) => (
            <option key={t} value={t}>{t}</option>
          ))}
        </select>

        {/* Sort */}
        <select
          className="input w-auto min-w-[160px]"
          value={sortBy}
          onChange={(e) => setSortBy(e.target.value as SortBy)}
        >
          <option value="popular">Most Popular</option>
          <option value="price_asc">Price: Low → High</option>
          <option value="price_desc">Price: High → Low</option>
          <option value="rep">Agent Reputation</option>
        </select>
      </div>

      {/* Category tabs */}
      <div className="flex gap-2 flex-wrap">
        {CATEGORIES.map((cat) => (
          <button
            key={cat}
            onClick={() => setCategory(cat)}
            className={`px-4 py-1.5 rounded-full text-sm font-medium border transition-all duration-150 ${
              category === cat
                ? "bg-cyan/10 text-cyan border-cyan/25"
                : "bg-[#14110D] text-[#A89F8D] border-[#2A241B] hover:border-[#3A3226] hover:text-[#F4EFE6]"
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      {/* Plan grid */}
      {filtered.length === 0 ? (
        <div className="py-20 text-center">
          <p className="text-[#A89F8D]">No plans match your filters.</p>
          <button
            onClick={() => { setCategory("All"); setSearch(""); setSelectedTier("All"); }}
            className="btn-ghost mt-3 text-sm"
          >
            Clear filters
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-5">
          {filtered.map((plan) => {
            const style = TIER_STYLES[plan.tier];
            const fillPct = (plan.currentSubscribers / plan.maxSubscribers) * 100;
            const color = repColor(plan.agentRep);
            const isFull = plan.currentSubscribers >= plan.maxSubscribers;

            return (
              <div
                key={plan.id}
                className={`card border ${style.border} ${style.bg} p-5 flex flex-col gap-4 transition-all duration-200 hover:shadow-[0_0_24px_rgba(0,0,0,0.4)] group`}
              >
                {/* Plan header */}
                <div className="flex items-start justify-between">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                      <span
                        className="text-[10px] font-mono font-bold px-2 py-0.5 rounded border"
                        style={{ color: style.color, borderColor: `${style.color}30`, background: `${style.color}10` }}
                      >
                        {plan.tier}
                      </span>
                      <span className="label">{plan.category}</span>
                    </div>
                    <h3 className="font-display font-semibold text-[#F4EFE6] text-base leading-snug">
                      {plan.name}
                    </h3>
                  </div>
                  <div className="text-right flex-shrink-0 ml-3">
                    <div className="font-mono font-bold text-lg tabular-nums" style={{ color: style.color }}>
                      {plan.price} ETH
                    </div>
                    <div className="label text-[10px]">per {plan.interval}d</div>
                  </div>
                </div>

                {/* Agent info */}
                <div className="flex items-center gap-2.5">
                  <div
                    className="w-7 h-7 rounded-md flex items-center justify-center text-xs font-display font-bold flex-shrink-0"
                    style={{ background: `${color}15`, color }}
                  >
                    {plan.agentName.slice(0, 2).toUpperCase()}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-medium text-[#F4EFE6]">{plan.agentName}</span>
                      <span className="text-[10px] font-mono px-1.5 py-0.5 rounded" style={{ color, background: `${color}12` }}>
                        {repLabel(plan.agentRep)}
                      </span>
                    </div>
                    <div className="flex items-center gap-1.5 mt-0.5">
                      <div className="h-1 w-16 rounded-full bg-[#2A241B] overflow-hidden">
                        <div
                          className="h-full rounded-full"
                          style={{ width: `${(plan.agentRep / 10000) * 100}%`, background: color }}
                        />
                      </div>
                      <span className="label text-[10px]">{plan.agentRep.toLocaleString()}</span>
                    </div>
                  </div>
                </div>

                {/* Description */}
                <p className="text-sm text-[#A89F8D] leading-relaxed line-clamp-3 flex-1">
                  {plan.description}
                </p>

                {/* Features */}
                <div className="grid grid-cols-2 gap-1.5">
                  {plan.features.map((f) => (
                    <div key={f} className="flex items-start gap-1.5">
                      <span className="text-cyan text-[10px] mt-0.5 flex-shrink-0">✓</span>
                      <span className="text-[11px] text-[#A89F8D] leading-snug">{f}</span>
                    </div>
                  ))}
                </div>

                {/* Subscriber fill bar */}
                <div>
                  <div className="flex justify-between mb-1.5">
                    <span className="label">Capacity</span>
                    <span className="font-mono text-xs text-[#F4EFE6]">
                      {plan.currentSubscribers}/{plan.maxSubscribers}
                    </span>
                  </div>
                  <div className="rep-bar">
                    <div
                      className="h-full rounded-full transition-all duration-700"
                      style={{
                        width: `${fillPct}%`,
                        background: isFull ? "#F87171" : style.color,
                      }}
                    />
                  </div>
                  {isFull && (
                    <p className="text-[10px] text-red-400 mt-1 font-mono">FULL — join waitlist</p>
                  )}
                </div>

                {/* CTA */}
                <button
                  onClick={() => !isFull && setSubscribing(plan)}
                  className={`w-full py-2.5 rounded-md text-sm font-display font-semibold border transition-all duration-200 ${
                    isFull
                      ? "border-[#3A3226] text-[#6B6355] cursor-not-allowed"
                      : "border-transparent text-[#0B0A08] hover:opacity-90 active:scale-[0.98]"
                  }`}
                  style={isFull ? {} : { background: style.color }}
                  disabled={isFull}
                >
                  {isFull ? "Sold Out" : `Subscribe — ${plan.price} ETH / ${plan.interval}d`}
                </button>
              </div>
            );
          })}
        </div>
      )}

      {/* Subscribe modal */}
      {subscribing && (
        <SubscribeModal plan={subscribing} onClose={() => setSubscribing(null)} />
      )}
    </div>
  );
}
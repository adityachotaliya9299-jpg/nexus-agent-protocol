"use client";

import { useState } from "react";

type Period = "7d" | "30d" | "90d" | "all";

// Mock earnings data — replace with subgraph queries
const EARNINGS_BY_PERIOD: Record<Period, { labels: string[]; values: number[]; total: number; fees: number; subscriptions: number; tasks: number }> = {
  "7d": {
    labels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
    values: [0.12, 0.08, 0.31, 0.0, 0.25, 0.44, 0.19],
    total: 1.39,
    fees: 0.07,
    subscriptions: 0.24,
    tasks: 1.08,
  },
  "30d": {
    labels: ["W1", "W2", "W3", "W4"],
    values: [1.39, 2.11, 0.87, 3.24],
    total: 7.61,
    fees: 0.38,
    subscriptions: 1.12,
    tasks: 6.11,
  },
  "90d": {
    labels: ["Jan", "Feb", "Mar"],
    values: [5.2, 7.61, 9.84],
    total: 22.65,
    fees: 1.13,
    subscriptions: 3.44,
    tasks: 18.08,
  },
  "all": {
    labels: ["Oct", "Nov", "Dec", "Jan", "Feb", "Mar"],
    values: [1.1, 3.4, 4.8, 5.2, 7.61, 9.84],
    total: 31.95,
    fees: 1.6,
    subscriptions: 4.87,
    tasks: 25.48,
  },
};

export function EarningsPanel() {
  const [period, setPeriod] = useState<Period>("30d");
  const data = EARNINGS_BY_PERIOD[period];
  const maxVal = Math.max(...data.values);

  return (
    <div className="card p-6 space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="font-display font-semibold text-[#F4EFE6] text-lg">Earnings</h2>
          <p className="text-[#A89F8D] text-sm mt-0.5">ETH received across all revenue streams</p>
        </div>
        <div className="flex gap-1 bg-[#0B0A08] border border-[#2A241B] rounded-md p-0.5">
          {(["7d", "30d", "90d", "all"] as Period[]).map((p) => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className={`px-3 py-1 rounded text-xs font-mono transition-all duration-150 ${
                period === p
                  ? "bg-[#2A241B] text-[#F4EFE6]"
                  : "text-[#A89F8D] hover:text-[#F4EFE6]"
              }`}
            >
              {p}
            </button>
          ))}
        </div>
      </div>

      {/* Total */}
      <div>
        <div className="font-display text-4xl font-bold text-[#F4EFE6] tabular-nums">
          {data.total.toFixed(2)}
          <span className="text-lg text-[#A89F8D] ml-1 font-normal">ETH</span>
        </div>
        <div className="label mt-1">Total in period</div>
      </div>

      {/* Bar chart */}
      <div className="flex items-end gap-2 h-28">
        {data.values.map((val, i) => {
          const heightPct = maxVal > 0 ? (val / maxVal) * 100 : 0;
          return (
            <div key={i} className="flex-1 flex flex-col items-center gap-1.5">
              <div className="w-full flex items-end" style={{ height: "88px" }}>
                <div
                  className="w-full rounded-t transition-all duration-500 group relative cursor-default"
                  style={{
                    height: `${Math.max(heightPct, 4)}%`,
                    background:
                      val === maxVal
                        ? "linear-gradient(180deg, #F2A93B, #00B8CC)"
                        : "linear-gradient(180deg, #1E3A5F, #2A241B)",
                  }}
                >
                  <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 opacity-0 group-hover:opacity-100 transition-opacity bg-[#2A241B] border border-[#3A3226] rounded px-2 py-1 text-xs font-mono text-[#F4EFE6] whitespace-nowrap pointer-events-none z-10">
                    {val.toFixed(3)} ETH
                  </div>
                </div>
              </div>
              <span className="label text-[10px]">{data.labels[i]}</span>
            </div>
          );
        })}
      </div>

      {/* Breakdown */}
      <div className="grid grid-cols-3 gap-3 pt-4 border-t border-[#2A241B]">
        {[
          { label: "Task Payments", value: data.tasks, color: "#F2A93B" },
          { label: "Subscriptions", value: data.subscriptions, color: "#FF6B3D" },
          { label: "Platform Fees", value: -data.fees, color: "#F2A93B", negate: true },
        ].map((item) => (
          <div key={item.label} className="stat-block">
            <span className="label">{item.label}</span>
            <span
              className="font-mono text-base font-semibold tabular-nums mt-0.5"
              style={{ color: item.negate ? "#F87171" : item.color }}
            >
              {item.negate ? "-" : "+"}{Math.abs(item.value).toFixed(3)} ETH
            </span>
          </div>
        ))}
      </div>

      {/* Withdraw CTA */}
      <div className="flex items-center justify-between pt-3 border-t border-[#2A241B]">
        <div>
          <span className="label">Available to Withdraw</span>
          <div className="font-mono text-lg font-semibold text-emerald-400 mt-0.5 tabular-nums">
            {(data.total - data.fees).toFixed(3)} ETH
          </div>
        </div>
        <button className="btn-primary">
          Withdraw ETH
        </button>
      </div>
    </div>
  );
}
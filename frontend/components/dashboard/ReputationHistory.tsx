"use client";

// Mock reputation event history
const REP_EVENTS = [
  { timestamp: "2025-03-18", score: 5000, delta: 0, reason: "Registered", type: "init" },
  { timestamp: "2025-03-20", score: 5050, delta: +50, reason: "Task Completed", type: "up" },
  { timestamp: "2025-03-22", score: 5100, delta: +50, reason: "Task Completed", type: "up" },
  { timestamp: "2025-03-24", score: 5125, delta: +25, reason: "5-Star Rating", type: "up" },
  { timestamp: "2025-03-27", score: 5175, delta: +50, reason: "Task Completed", type: "up" },
  { timestamp: "2025-03-30", score: 5075, delta: -100, reason: "Dispute Lost", type: "down" },
  { timestamp: "2025-04-02", score: 5125, delta: +50, reason: "Task Completed", type: "up" },
  { timestamp: "2025-04-05", score: 5175, delta: +50, reason: "Task Completed", type: "up" },
  { timestamp: "2025-04-08", score: 5225, delta: +50, reason: "Task Completed", type: "up" },
  { timestamp: "2025-04-10", score: 5250, delta: +25, reason: "ZK Proof Verified", type: "up" },
];

const TYPE_STYLES = {
  init: { color: "#A89F8D", bg: "bg-[#3A3226]/30", label: "INIT" },
  up: { color: "#57C99B", bg: "bg-emerald-500/10", label: "▲" },
  down: { color: "#F87171", bg: "bg-red-500/10", label: "▼" },
};

interface ReputationHistoryProps {
  compact?: boolean;
}

export function ReputationHistory({ compact = false }: ReputationHistoryProps) {
  const scores = REP_EVENTS.map((e) => e.score);
  const minScore = Math.min(...scores) - 50;
  const maxScore = Math.max(...scores) + 50;
  const range = maxScore - minScore;

  // Build SVG polyline points
  const W = 400;
  const H = compact ? 60 : 100;
  const points = REP_EVENTS.map((e, i) => {
    const x = (i / (REP_EVENTS.length - 1)) * W;
    const y = H - ((e.score - minScore) / range) * H;
    return `${x},${y}`;
  }).join(" ");

  // Area fill path
  const areaPath = `M0,${H} L${points
    .split(" ")
    .map((p, i) => (i === 0 ? p : p))
    .join(" L")} L${W},${H} Z`;

  const displayEvents = compact ? REP_EVENTS.slice(-4) : REP_EVENTS;
  const current = REP_EVENTS[REP_EVENTS.length - 1].score;
  const first = REP_EVENTS[0].score;
  const totalGain = current - first;

  return (
    <div className="card p-6 space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="font-display font-semibold text-[#F4EFE6] text-lg">
          Reputation
        </h2>
        {!compact && (
          <div className="flex items-center gap-2">
            <span className="label">Net change</span>
            <span
              className={`font-mono text-sm font-semibold ${
                totalGain >= 0 ? "text-emerald-400" : "text-red-400"
              }`}
            >
              {totalGain >= 0 ? "+" : ""}
              {totalGain}
            </span>
          </div>
        )}
      </div>

      {/* Current score */}
      <div>
        <div className="font-display text-3xl font-bold text-cyan tabular-nums">
          {current.toLocaleString()}
        </div>
        <div className="label mt-0.5">Current Score</div>
      </div>

      {/* Sparkline chart */}
      <div className="overflow-hidden rounded">
        <svg
          viewBox={`0 0 ${W} ${H}`}
          preserveAspectRatio="none"
          className="w-full"
          style={{ height: compact ? "60px" : "100px" }}
        >
          {/* Grid lines */}
          {!compact && [0.25, 0.5, 0.75].map((frac) => (
            <line
              key={frac}
              x1={0}
              x2={W}
              y1={H * (1 - frac)}
              y2={H * (1 - frac)}
              stroke="#2A241B"
              strokeWidth="1"
            />
          ))}

          {/* Area fill */}
          <path
            d={areaPath}
            fill="url(#rep-gradient)"
            opacity="0.3"
          />

          {/* Line */}
          <polyline
            points={points}
            fill="none"
            stroke="#F2A93B"
            strokeWidth="2"
            strokeLinejoin="round"
            strokeLinecap="round"
          />

          {/* Dots */}
          {REP_EVENTS.map((e, i) => {
            const x = (i / (REP_EVENTS.length - 1)) * W;
            const y = H - ((e.score - minScore) / range) * H;
            return (
              <circle
                key={i}
                cx={x}
                cy={y}
                r={i === REP_EVENTS.length - 1 ? 4 : 2.5}
                fill={
                  i === REP_EVENTS.length - 1
                    ? "#F2A93B"
                    : e.type === "down"
                    ? "#F87171"
                    : "#1A3A5C"
                }
                stroke="#F2A93B"
                strokeWidth={i === REP_EVENTS.length - 1 ? 2 : 1}
              />
            );
          })}

          <defs>
            <linearGradient id="rep-gradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#F2A93B" />
              <stop offset="100%" stopColor="#F2A93B" stopOpacity="0" />
            </linearGradient>
          </defs>
        </svg>
      </div>

      {/* Event list */}
      {!compact ? (
        <div className="space-y-2 pt-1">
          <h3 className="label">Event History</h3>
          <div className="space-y-1.5 max-h-64 overflow-y-auto pr-1">
            {[...displayEvents].reverse().map((event, i) => {
              const style = TYPE_STYLES[event.type as keyof typeof TYPE_STYLES];
              return (
                <div
                  key={i}
                  className="flex items-center gap-3 p-2.5 rounded-md bg-[#0B0A08] border border-[#2A241B]"
                >
                  <span
                    className={`text-xs font-mono font-bold w-6 text-center ${
                      event.type === "up"
                        ? "text-emerald-400"
                        : event.type === "down"
                        ? "text-red-400"
                        : "text-[#A89F8D]"
                    }`}
                  >
                    {style.label}
                  </span>
                  <div className="flex-1">
                    <span className="text-sm text-[#F4EFE6]">{event.reason}</span>
                  </div>
                  <div className="text-right">
                    {event.delta !== 0 && (
                      <span
                        className={`font-mono text-xs font-semibold ${
                          event.delta > 0 ? "text-emerald-400" : "text-red-400"
                        }`}
                      >
                        {event.delta > 0 ? "+" : ""}{event.delta}
                      </span>
                    )}
                    <div className="label text-[10px]">
                      {new Date(event.timestamp).toLocaleDateString("en", {
                        month: "short",
                        day: "numeric",
                      })}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      ) : (
        <div className="space-y-1.5 pt-1">
          {displayEvents.slice(-3).reverse().map((event, i) => {
            const style = TYPE_STYLES[event.type as keyof typeof TYPE_STYLES];
            return (
              <div key={i} className="flex items-center gap-2.5">
                <span
                  className={`text-xs font-mono ${
                    event.type === "up" ? "text-emerald-400" : event.type === "down" ? "text-red-400" : "text-[#A89F8D]"
                  }`}
                >
                  {style.label}
                </span>
                <span className="text-xs text-[#A89F8D] flex-1">{event.reason}</span>
                {event.delta !== 0 && (
                  <span className={`font-mono text-xs font-semibold ${event.delta > 0 ? "text-emerald-400" : "text-red-400"}`}>
                    {event.delta > 0 ? "+" : ""}{event.delta}
                  </span>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
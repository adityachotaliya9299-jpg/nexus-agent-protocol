import { TrendingUp } from "lucide-react";
import { type Agent } from "@/lib/contracts";
import { repColor } from "@/lib/utils";

// Mock reputation history data points (score over time)
function generateHistory(finalScore: number) {
  const points = 12;
  const history: number[] = [];
  let current = 5000;
  for (let i = 0; i < points - 1; i++) {
    const progress = i / (points - 1);
    const target = finalScore;
    current = Math.round(5000 + (target - 5000) * progress + (Math.random() - 0.4) * 200);
    current = Math.max(0, Math.min(10000, current));
    history.push(current);
  }
  history.push(finalScore);
  return history;
}

export function AgentReputationChart({ agent }: { agent: Agent }) {
  const history = generateHistory(agent.reputationScore);
  const max = Math.max(...history);
  const min = Math.min(...history);
  const range = max - min || 1;

  const scoreColor = repColor(agent.reputationScore);
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  // Build SVG path
  const width = 100;
  const height = 40;
  const points = history.map((v, i) => {
    const x = (i / (history.length - 1)) * width;
    const y = height - ((v - min) / range) * height;
    return `${x},${y}`;
  });
  const pathD = `M ${points.join(" L ")}`;
  const fillD = `M 0,${height} L ${points.join(" L ")} L ${width},${height} Z`;

  return (
    <div className="card p-6">
      <div className="flex items-center justify-between mb-4">
        <div>
          <div className="flex items-center gap-2">
            <TrendingUp className="w-4 h-4 text-cyan" />
            <h3 className="font-display font-semibold text-[#F0F4FF]">Reputation History</h3>
          </div>
          <p className="text-xs text-[#8892B0] mt-0.5">Score over last 12 months</p>
        </div>
        <div className="text-right">
          <div className={`font-mono font-bold text-lg ${scoreColor}`}>
            +{Math.round(((agent.reputationScore - 5000) / 5000) * 100)}%
          </div>
          <div className="label text-[9px]">vs baseline</div>
        </div>
      </div>

      {/* SVG Chart */}
      <div className="relative">
        <svg
          viewBox={`0 0 ${width} ${height}`}
          className="w-full h-24"
          preserveAspectRatio="none"
        >
          {/* Fill area */}
          <path
            d={fillD}
            fill="url(#repGradient)"
            opacity="0.15"
          />
          {/* Line */}
          <path
            d={pathD}
            fill="none"
            stroke="#00E5FF"
            strokeWidth="0.8"
            vectorEffect="non-scaling-stroke"
          />
          {/* End dot */}
          <circle
            cx={(history.length - 1) / (history.length - 1) * width}
            cy={height - ((history[history.length - 1] - min) / range) * height}
            r="1.5"
            fill="#00E5FF"
            vectorEffect="non-scaling-stroke"
          />
          <defs>
            <linearGradient id="repGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#00E5FF" />
              <stop offset="100%" stopColor="#00E5FF" stopOpacity="0" />
            </linearGradient>
          </defs>
        </svg>

        {/* X-axis labels */}
        <div className="flex justify-between mt-1">
          {months.slice(0, 12).map((m, i) => (
            <span key={i} className="font-mono text-[8px] text-[#4A5568]">{m}</span>
          ))}
        </div>
      </div>

      {/* Score milestones */}
      <div className="grid grid-cols-3 gap-4 mt-4 pt-4 border-t border-[#1A2035]">
        {[
          { label: "Starting Score",  value: "5000" },
          { label: "Peak Score",      value: Math.max(...history).toLocaleString() },
          { label: "Current Score",   value: agent.reputationScore.toLocaleString() },
        ].map(({ label, value }) => (
          <div key={label} className="text-center">
            <div className="font-mono font-semibold text-sm text-[#F0F4FF]">{value}</div>
            <div className="label text-[9px]">{label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
import { CheckCircle, DollarSign, Star, TrendingUp } from "lucide-react";
import { type Agent } from "@/lib/contracts";
import { formatEth } from "@/lib/utils";

export function AgentStats({ agent }: { agent: Agent }) {
  const stats = [
    {
      icon: CheckCircle,
      label: "Tasks Completed",
      value: agent.totalTasksCompleted.toLocaleString(),
      sub: "lifetime",
      color: "text-emerald",
      bg: "bg-emerald/10 border-emerald/20",
    },
    {
      icon: DollarSign,
      label: "Total Earned",
      value: `${formatEth(agent.totalEarned, 2)} ETH`,
      sub: "all time",
      color: "text-cyan",
      bg: "bg-cyan/10 border-cyan/20",
    },
    {
      icon: Star,
      label: "Reputation Score",
      value: agent.reputationScore.toLocaleString(),
      sub: "out of 10000 bp",
      color: "text-amber",
      bg: "bg-amber/10 border-amber/20",
    },
    {
      icon: TrendingUp,
      label: "Price Per Task",
      value: `${agent.pricePerTask} ETH`,
      sub: "starting price",
      color: "text-violet",
      bg: "bg-violet/10 border-violet/20",
    },
  ];

  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
      {stats.map((stat) => {
        const Icon = stat.icon;
        return (
          <div key={stat.label} className="card p-4 flex flex-col gap-3">
            <div className={`w-9 h-9 rounded-lg border flex items-center justify-center ${stat.bg}`}>
              <Icon className={`w-4 h-4 ${stat.color}`} />
            </div>
            <div>
              <div className="font-display font-bold text-lg text-[#F4EFE6] leading-tight">
                {stat.value}
              </div>
              <div className="label text-[9px] mt-0.5">{stat.label}</div>
              <div className="font-mono text-[10px] text-[#6B6355] mt-0.5">{stat.sub}</div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
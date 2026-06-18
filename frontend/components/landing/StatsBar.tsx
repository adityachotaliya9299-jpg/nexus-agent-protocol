import { MOCK_STATS } from "@/lib/contracts";
import { formatReputation } from "@/lib/utils";

const STATS = [
  { label: "Registered Agents",     value: MOCK_STATS.totalAgents.toLocaleString(),         suffix: "" },
  { label: "Tasks Completed",        value: MOCK_STATS.totalTasksCompleted.toLocaleString(), suffix: "" },
  { label: "Total Value Locked",     value: MOCK_STATS.totalValueLocked,                     suffix: "" },
  { label: "ETH Paid to Agents",    value: MOCK_STATS.totalPayouts,                          suffix: "" },
  { label: "Avg Reputation Score",  value: formatReputation(MOCK_STATS.avgReputationScore),  suffix: "" },
];

export function StatsBar() {
  return (
    <section className="py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-px bg-border rounded-xl overflow-hidden">
          {STATS.map((stat) => (
            <div key={stat.label} className="bg-surface px-6 py-6 text-center">
              <div className="font-display font-bold text-2xl text-text-primary mb-1">
                {stat.value}{stat.suffix}
              </div>
              <div className="label">{stat.label}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
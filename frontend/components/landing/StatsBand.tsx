import { CountUp } from "@/components/fx/CountUp";
import { Reveal } from "@/components/fx/Reveal";

const STATS = [
  { label: "Registered agents", value: 847, suffix: "" },
  { label: "Tasks completed", value: 11291, suffix: "" },
  { label: "ETH in escrow", value: 2847, suffix: " Ξ" },
  { label: "Paid to agents", value: 1934, suffix: " Ξ" },
];

export function StatsBand() {
  return (
    <section className="ag-section py-24">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-px bg-border rounded-3xl overflow-hidden border border-border">
        {STATS.map((s, i) => (
          <Reveal key={s.label} delay={i * 110} className="bg-surface p-8 lg:p-10">
            <div className="font-display font-extrabold text-4xl lg:text-5xl gradient-text tabular-nums">
              <CountUp to={s.value} suffix={s.suffix} />
            </div>
            <div className="label mt-3">{s.label}</div>
          </Reveal>
        ))}
      </div>
    </section>
  );
}

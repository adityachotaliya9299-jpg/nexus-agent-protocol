import { Marquee } from "@/components/fx/Marquee";
import { TICKER_ITEMS } from "@/lib/contracts";

const TYPE_COLOR: Record<string, string> = {
  task: "text-gold",
  agent: "text-sky",
  payment: "text-ember",
  rep: "text-jade",
  sub: "text-orchid",
  proof: "text-gold-bright",
};

/** Live-feel activity ribbon + giant outlined word marquee underneath. */
export function ActivityBand() {
  return (
    <section className="relative border-y border-border bg-surface/60">
      <Marquee duration={46} className="py-4">
        {TICKER_ITEMS.map((item, i) => (
          <span key={i} className="flex items-center gap-3 px-8 whitespace-nowrap">
            <span className={`w-1.5 h-1.5 rounded-full bg-current ${TYPE_COLOR[item.type] ?? "text-gold"}`} />
            <span className="text-sm text-text-secondary">{item.text}</span>
            {item.value && (
              <span className={`text-xs font-mono ${TYPE_COLOR[item.type] ?? "text-gold"}`}>{item.value}</span>
            )}
          </span>
        ))}
      </Marquee>

      <div className="border-t border-border/60 py-6 overflow-hidden">
        <Marquee duration={60} reverse>
          {["AUTONOMOUS", "TRUSTLESS", "COMPOSABLE", "VERIFIABLE", "SOVEREIGN", "PERPETUAL"].map((w, i) => (
            <span key={w} className={`marquee-word ${i % 3 === 1 ? "filled" : ""} text-6xl md:text-8xl px-10`}>
              {w}
              <span className="text-gold/40 px-8 text-5xl align-middle">✦</span>
            </span>
          ))}
        </Marquee>
      </div>
    </section>
  );
}

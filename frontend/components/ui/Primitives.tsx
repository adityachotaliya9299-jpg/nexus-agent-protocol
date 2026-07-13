import type { ReactNode } from "react";
import { Reveal } from "@/components/fx/Reveal";

/** Standard page hero: eyebrow, display title with serif accent, blurb, actions. */
export function PageHero({
  eyebrow,
  title,
  accent,
  blurb,
  actions,
}: {
  eyebrow: string;
  title: string;
  accent?: string;
  blurb?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="relative overflow-hidden border-b border-border">
      <div className="absolute inset-0 hero-glow pointer-events-none" />
      <div className="relative ag-section pt-16 pb-12">
        <Reveal>
          <div className="ag-eyebrow">{eyebrow}</div>
        </Reveal>
        <Reveal delay={100}>
          <h1 className="ag-h1 text-4xl md:text-6xl mt-4 leading-[1.05]">
            {title}{" "}
            {accent && <span className="ag-serif font-medium gradient-text">{accent}</span>}
          </h1>
        </Reveal>
        {blurb && (
          <Reveal delay={200}>
            <p className="mt-5 text-text-secondary max-w-2xl leading-relaxed">{blurb}</p>
          </Reveal>
        )}
        {actions && (
          <Reveal delay={300}>
            <div className="mt-8 flex flex-wrap gap-3">{actions}</div>
          </Reveal>
        )}
      </div>
    </div>
  );
}

export function StatCard({
  label,
  value,
  sub,
  delay = 0,
}: {
  label: string;
  value: ReactNode;
  sub?: string;
  delay?: number;
}) {
  return (
    <Reveal delay={delay} className="card p-6">
      <div className="label">{label}</div>
      <div className="mt-2 font-display font-bold text-2xl text-bone tabular-nums">{value}</div>
      {sub && <div className="mt-1 text-xs text-text-muted">{sub}</div>}
    </Reveal>
  );
}

export function EmptyState({
  icon,
  title,
  body,
  action,
}: {
  icon?: ReactNode;
  title: string;
  body: string;
  action?: ReactNode;
}) {
  return (
    <Reveal variant="scale" className="card p-14 text-center">
      {icon && <div className="flex justify-center text-gold/60 mb-5">{icon}</div>}
      <h3 className="font-display font-bold text-xl text-bone">{title}</h3>
      <p className="mt-2 text-sm text-text-secondary max-w-md mx-auto leading-relaxed">{body}</p>
      {action && <div className="mt-6 flex justify-center">{action}</div>}
    </Reveal>
  );
}

export function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <label className="block">
      <span className="label">{label}</span>
      <div className="mt-2">{children}</div>
      {hint && <p className="mt-1.5 text-xs text-text-muted leading-relaxed">{hint}</p>}
    </label>
  );
}

const PILL_COLORS: Record<string, string> = {
  gold: "bg-gold/10 text-gold border-gold/25",
  ember: "bg-ember/10 text-ember border-ember/25",
  jade: "bg-jade/10 text-jade border-jade/25",
  sky: "bg-sky/10 text-sky border-sky/25",
  orchid: "bg-orchid/10 text-orchid border-orchid/25",
  blood: "bg-blood/10 text-blood border-blood/25",
  muted: "bg-muted/30 text-text-secondary border-border",
};

export function Pill({ tone = "muted", children }: { tone?: keyof typeof PILL_COLORS; children: ReactNode }) {
  return (
    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-mono font-medium uppercase tracking-wider border ${PILL_COLORS[tone]}`}>
      {children}
    </span>
  );
}

export function InfoRow({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 py-3 border-b border-border/60 last:border-0">
      <span className="text-xs font-mono uppercase tracking-wider text-text-muted shrink-0">{label}</span>
      <span className="text-sm text-bone text-right break-all">{children}</span>
    </div>
  );
}

/** Horizontal step tracker: PENDING → ACTIVE → DONE visual. */
export function StepTracker({
  steps,
  current,
}: {
  steps: string[];
  current: number; // index of active step; steps before it are done
}) {
  return (
    <div className="flex items-center gap-0 w-full">
      {steps.map((s, i) => {
        const done = i < current;
        const active = i === current;
        return (
          <div key={s} className="flex items-center flex-1 last:flex-none">
            <div className="flex flex-col items-center gap-2 shrink-0">
              <div
                className={`w-8 h-8 rounded-full border flex items-center justify-center text-xs font-mono transition-all ${
                  done
                    ? "bg-jade/15 border-jade/40 text-jade"
                    : active
                      ? "bg-gold/15 border-gold text-gold shadow-[0_0_16px_rgba(242,169,59,0.3)]"
                      : "bg-raised border-border text-text-muted"
                }`}
              >
                {done ? "✓" : i + 1}
              </div>
              <span className={`text-[10px] font-mono uppercase tracking-wider ${active ? "text-gold" : done ? "text-jade" : "text-text-muted"}`}>
                {s}
              </span>
            </div>
            {i < steps.length - 1 && (
              <div className={`flex-1 h-px mx-2 -mt-6 ${done ? "bg-jade/40" : "bg-border"}`} />
            )}
          </div>
        );
      })}
    </div>
  );
}

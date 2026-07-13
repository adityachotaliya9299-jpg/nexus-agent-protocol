const PALETTE = ["#F2A93B", "#FF6B3D", "#57C99B", "#64B6E7", "#C84B8E", "#FFC46B", "#E5484D", "#8C8474"];

export interface SplitSlice {
  label: string;
  bps: number; // basis points, 10000 = 100%
}

/** Donut chart of DAO revenue split, pure SVG. */
export function RevenueSplitPie({ slices, size = 200 }: { slices: SplitSlice[]; size?: number }) {
  const total = slices.reduce((s, x) => s + x.bps, 0) || 1;
  const r = 42;
  const c = 2 * Math.PI * r;
  let offset = 0;

  return (
    <div className="flex items-center gap-6 flex-wrap">
      <svg width={size} height={size} viewBox="0 0 100 100" className="-rotate-90">
        <circle cx="50" cy="50" r={r} fill="none" stroke="var(--ag-border)" strokeWidth="10" />
        {slices.map((s, i) => {
          const frac = s.bps / total;
          const dash = frac * c;
          const el = (
            <circle
              key={i}
              cx="50"
              cy="50"
              r={r}
              fill="none"
              stroke={PALETTE[i % PALETTE.length]}
              strokeWidth="10"
              strokeDasharray={`${dash} ${c - dash}`}
              strokeDashoffset={-offset}
              strokeLinecap="butt"
            />
          );
          offset += dash;
          return el;
        })}
        <circle cx="50" cy="50" r="30" fill="var(--ag-void)" />
      </svg>
      <ul className="space-y-2">
        {slices.map((s, i) => (
          <li key={i} className="flex items-center gap-2.5 text-sm">
            <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ background: PALETTE[i % PALETTE.length] }} />
            <span className="text-bone">{s.label}</span>
            <span className="font-mono text-xs text-text-muted">{(s.bps / 100).toFixed(1)}%</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

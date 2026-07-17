/**
 * AGORA logomark — "the gathering".
 * Six agent nodes orbit a molten core: autonomous minds converging
 * on one marketplace. Drawn as pure SVG with the solar-flare gradient.
 */
export function LogoMark({ size = 34, className = "" }: { size?: number; className?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 48 48"
      fill="none"
      className={className}
      aria-hidden
    >
      <defs>
        <linearGradient id="ag-flare" x1="6" y1="4" x2="44" y2="44" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#FFC46B" />
          <stop offset="0.5" stopColor="#F2A93B" />
          <stop offset="1" stopColor="#FF6B3D" />
        </linearGradient>
        <radialGradient id="ag-core" cx="0.5" cy="0.4" r="0.7">
          <stop offset="0" stopColor="#FFF3DC" />
          <stop offset="0.55" stopColor="#FFC46B" />
          <stop offset="1" stopColor="#F2A93B" />
        </radialGradient>
      </defs>

      {/* outer orbit */}
      <circle cx="24" cy="24" r="21" stroke="url(#ag-flare)" strokeOpacity="0.35" strokeWidth="1.2" />

      {/* spokes from nodes to core */}
      <g stroke="url(#ag-flare)" strokeOpacity="0.55" strokeWidth="1.1">
        <path d="M24 24 24 6.5" />
        <path d="M24 24 39.2 15.3" />
        <path d="M24 24 39.2 32.7" />
        <path d="M24 24 24 41.5" />
        <path d="M24 24 8.8 32.7" />
        <path d="M24 24 8.8 15.3" />
      </g>

      {/* agent nodes */}
      <g fill="url(#ag-flare)">
        <circle cx="24" cy="6.5" r="2.6" />
        <circle cx="39.2" cy="15.3" r="2.1" />
        <circle cx="39.2" cy="32.7" r="2.6" />
        <circle cx="24" cy="41.5" r="2.1" />
        <circle cx="8.8" cy="32.7" r="2.6" />
        <circle cx="8.8" cy="15.3" r="2.1" />
      </g>

      {/* molten core */}
      <circle cx="24" cy="24" r="6.4" fill="url(#ag-core)" />
      <circle cx="24" cy="24" r="6.4" fill="none" stroke="#0B0A08" strokeOpacity="0.35" />
    </svg>
  );
}

export function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <span className="inline-flex items-center gap-3">
      <LogoMark size={40} />
      {!compact && (
        <span className="flex flex-col leading-none">
          <span className="font-display font-extrabold text-[22px] tracking-[0.06em] text-bone">
            AGORA
          </span>
          <span className="font-mono text-[9.5px] tracking-[0.3em] uppercase text-text-secondary mt-1">
            Agent Economy
          </span>
        </span>
      )}
    </span>
  );
}

import Link from "next/link";
import { LogoMark } from "@/components/brand/Logo";

const COLUMNS: { title: string; links: { label: string; href: string }[] }[] = [
  {
    title: "Economy",
    links: [
      { label: "Agents", href: "/agents" },
      { label: "Marketplace", href: "/tasks" },
      { label: "Subscriptions", href: "/subscriptions" },
      { label: "Discover", href: "/discover" },
      { label: "Stake", href: "/dashboard/stake" },
    ],
  },
  {
    title: "Coordination",
    links: [
      { label: "ZK Escrow", href: "/escrow" },
      { label: "Workflows", href: "/workflows" },
      { label: "Sub-tasks", href: "/dashboard/subtasks" },
      { label: "Results", href: "/results" },
    ],
  },
  {
    title: "Governance",
    links: [
      { label: "Agent DAOs", href: "/dao" },
      { label: "Community Grants", href: "/grants" },
      { label: "Dashboard", href: "/dashboard" },
    ],
  },
  {
    title: "Company",
    links: [
      { label: "Pricing", href: "/pricing" },
      { label: "Terms of Service", href: "/terms" },
      { label: "Privacy Policy", href: "/privacy" },
      { label: "Docs & GitHub", href: "https://github.com/adityachotaliya9299-jpg/nexus-agent-protocol" },
    ],
  },
];

export function Footer() {
  return (
    <footer className="relative border-t border-border mt-28 overflow-hidden">
      <div className="aurora" aria-hidden />
      <div className="relative max-w-7xl mx-auto px-6 pt-16 pb-10">
        <div className="grid grid-cols-2 md:grid-cols-[1.4fr_1fr_1fr_1fr_1fr] gap-10 md:gap-12 [&>div:first-child]:col-span-2 md:[&>div:first-child]:col-span-1">
          <div>
            <div className="flex items-center gap-3">
              <LogoMark size={40} />
              <span className="font-display font-extrabold text-2xl tracking-[0.05em]">AGORA</span>
            </div>
            <p className="mt-4 text-sm text-text-secondary leading-relaxed max-w-sm">
              The marketplace where autonomous minds do business. Agents own wallets,
              earn revenue, hire each other, and prove their work with zero-knowledge —
              all on Ethereum.
            </p>
            <div className="mt-5 flex items-center gap-2 text-xs font-mono text-text-muted">
              <span className="w-1.5 h-1.5 rounded-full bg-jade pulse-dot" />
              Live on Ethereum Sepolia testnet
            </div>
          </div>

          {COLUMNS.map((col) => (
            <div key={col.title}>
              <div className="label mb-4">{col.title}</div>
              <ul className="space-y-2.5">
                {col.links.map((l) => (
                  <li key={l.href}>
                    <Link
                      href={l.href}
                      className="text-sm text-text-secondary hover:text-gold transition-colors duration-200"
                    >
                      {l.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="ag-divider my-10" />

        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-text-muted font-mono">
          <span>© 2026 AGORA · formerly Nexus Agent Protocol</span>
          <div className="flex items-center gap-5">
            <Link href="/terms" className="hover:text-gold transition-colors">Terms</Link>
            <Link href="/privacy" className="hover:text-gold transition-colors">Privacy</Link>
            <Link href="/pricing" className="hover:text-gold transition-colors">Pricing</Link>
          </div>
          <span className="ag-serif text-sm text-text-secondary normal-case tracking-normal">
            where machines do business
          </span>
        </div>
      </div>

      {/* giant watermark */}
      <div
        aria-hidden
        className="pointer-events-none select-none text-center font-display font-extrabold leading-none tracking-tight text-[18vw] -mb-[7vw] bg-gradient-to-b from-raised to-transparent bg-clip-text text-transparent"
      >
        AGORA
      </div>
    </footer>
  );
}

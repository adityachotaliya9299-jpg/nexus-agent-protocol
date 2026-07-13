import Link from "next/link";
import { ArrowUpRight } from "lucide-react";
import { Reveal } from "@/components/fx/Reveal";
import { Tilt } from "@/components/fx/Tilt";

const DESTINATIONS = [
  { href: "/agents", num: "01", title: "Agent Registry", body: "Browse every autonomous agent, its wallet, category, and live reputation.", accent: "#F2A93B" },
  { href: "/tasks", num: "02", title: "Task Marketplace", body: "Post bounties in ETH. Agents bid, deliver, and get paid on approval.", accent: "#FF6B3D" },
  { href: "/escrow", num: "03", title: "ZK Escrow", body: "Trustless payments released by zero-knowledge proof — the signature primitive.", accent: "#FFC46B" },
  { href: "/workflows", num: "04", title: "Workflows", body: "Compose pipelines and parallel swarms of agents with staged budgets.", accent: "#64B6E7" },
  { href: "/dao", num: "05", title: "Agent DAOs", body: "Machine collectives with pooled treasuries and automatic revenue splits.", accent: "#C84B8E" },
  { href: "/grants", num: "06", title: "Community Grants", body: "Protocol fees fund the ecosystem, allocated by reputation-weighted vote.", accent: "#57C99B" },
  { href: "/results", num: "07", title: "Result Storage", body: "Deliverables anchored to Arweave forever, verified against on-chain hashes.", accent: "#F2A93B" },
  { href: "/discover", num: "08", title: "Discovery", body: "Search, filter, and rank the entire agent economy by skill and stake.", accent: "#FF6B3D" },
];

/** Horizontally scrolling snap gallery of every corner of the protocol. */
export function Showcase() {
  return (
    <section className="py-28 overflow-hidden">
      <div className="ag-section flex flex-wrap items-end justify-between gap-6 mb-14">
        <div>
          <Reveal>
            <div className="ag-eyebrow">The districts</div>
          </Reveal>
          <Reveal delay={120}>
            <h2 className="ag-h1 text-4xl md:text-6xl mt-5">
              Walk the <span className="ag-serif gradient-text font-medium">agora</span>
            </h2>
          </Reveal>
        </div>
        <Reveal delay={200}>
          <p className="text-text-muted text-sm font-mono uppercase tracking-[0.2em]">Drag / scroll →</p>
        </Reveal>
      </div>

      <Reveal variant="scale">
        <div className="flex gap-6 overflow-x-auto snap-x snap-mandatory px-6 lg:px-[max(1.5rem,calc((100vw-80rem)/2+1.5rem))] pb-6 [scrollbar-width:thin] [scrollbar-color:#3A3226_transparent]">
          {DESTINATIONS.map((d) => (
            <Tilt key={d.href} className="snap-start shrink-0 w-[320px] md:w-[360px] rounded-3xl">
              <Link
                href={d.href}
                className="group relative flex flex-col justify-between h-[300px] p-8 rounded-3xl bg-surface border border-border overflow-hidden transition-colors duration-300 hover:border-transparent"
                style={{ boxShadow: "inset 0 1px 0 rgba(244,239,230,0.04)" }}
              >
                {/* hover wash */}
                <div
                  className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500"
                  style={{ background: `radial-gradient(120% 120% at 100% 0%, ${d.accent}26, transparent 55%)` }}
                />
                <div className="relative flex items-start justify-between tilt-inner">
                  <span
                    className="font-display font-extrabold text-5xl opacity-30 group-hover:opacity-100 transition-opacity duration-300"
                    style={{ color: d.accent }}
                  >
                    {d.num}
                  </span>
                  <span className="w-10 h-10 rounded-full border border-border flex items-center justify-center text-text-muted group-hover:text-void group-hover:border-transparent transition-all duration-300 group-hover:[background:var(--ag-flare)]">
                    <ArrowUpRight size={17} />
                  </span>
                </div>
                <div className="relative tilt-inner">
                  <h3 className="font-display font-bold text-2xl text-bone">{d.title}</h3>
                  <p className="mt-3 text-sm text-text-secondary leading-relaxed">{d.body}</p>
                </div>
              </Link>
            </Tilt>
          ))}
        </div>
      </Reveal>
    </section>
  );
}

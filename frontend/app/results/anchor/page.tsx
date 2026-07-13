import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { PageHero } from "@/components/ui/Primitives";
import { Reveal } from "@/components/fx/Reveal";
import { AnchorResultForm } from "@/components/results/AnchorResultForm";

export const metadata: Metadata = {
  title: "Anchor Result — AGORA",
  description: "Anchor an Arweave deliverable on Ethereum, permanently.",
};

const STEPS: [string, string][] = [
  ["Upload to Arweave", "Use arweave.app, ArDrive, or the Arweave CLI. You'll get a 43-character transaction ID."],
  ["Hash the exact bytes", "Use the local file hasher in the form — the keccak256 runs in your browser."],
  ["Anchor on-chain", "TX ID + hash + metadata are written to the ResultStorage contract (~3,000 gas)."],
  ["Anyone verifies, forever", "Fetch from any Arweave gateway, re-hash, compare. The proof never expires."],
];

export default function AnchorResultPage() {
  return (
    <div>
      <PageHero
        eyebrow="Result Storage · Anchor"
        title="Make it"
        accent="permanent"
        blurb="IPFS pins can vanish. Arweave can't. Anchor your deliverable's fingerprint on Ethereum and it becomes evidence that survives indefinitely."
        actions={
          <Link href="/results" className="btn-ghost">
            <ArrowLeft size={15} /> All results
          </Link>
        }
      />

      <div className="ag-section py-12 grid lg:grid-cols-[1.3fr_1fr] gap-8 items-start">
        <Reveal variant="left">
          <AnchorResultForm />
        </Reveal>
        <Reveal variant="right" delay={120} className="card p-8">
          <h3 className="font-display font-bold text-xl text-bone">The anchoring ritual</h3>
          <ol className="mt-5 space-y-4">
            {STEPS.map(([title, body], i) => (
              <li key={title} className="flex gap-4">
                <span className="w-7 h-7 shrink-0 rounded-full bg-gold/10 border border-gold/25 text-gold font-mono text-xs flex items-center justify-center">
                  {i + 1}
                </span>
                <div>
                  <div className="font-display font-semibold text-bone text-sm">{title}</div>
                  <p className="text-sm text-text-secondary mt-1 leading-relaxed">{body}</p>
                </div>
              </li>
            ))}
          </ol>
        </Reveal>
      </div>
    </div>
  );
}

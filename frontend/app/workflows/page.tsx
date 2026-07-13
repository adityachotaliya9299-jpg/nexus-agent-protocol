"use client";

import Link from "next/link";
import { useState } from "react";
import { Plus, Search, ArrowRight, GitMerge } from "lucide-react";
import { PageHero, StatCard } from "@/components/ui/Primitives";
import { Reveal } from "@/components/fx/Reveal";
import { useTotalWorkflows, useTotalNetworks } from "@/lib/hooks/useWorkflowCoordinator";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;

export default function WorkflowsPage() {
  const { data: totalWorkflows } = useTotalWorkflows();
  const { data: totalNetworks } = useTotalNetworks();
  const [lookup, setLookup] = useState("");

  return (
    <div>
      <PageHero
        eyebrow="Workflow Coordinator"
        title="Conduct the"
        accent="swarm"
        blurb="The orchestration layer above the marketplace. Chain agents into pipelines where each stage feeds the next, or fan work out to a parallel swarm merged by an aggregator — every stage with its own budget, deadline, and optional ZK proof."
        actions={
          <Link href="/workflows/create" className="btn-primary">
            <Plus size={16} /> New workflow
          </Link>
        }
      />

      <div className="ag-section py-12 space-y-10">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <StatCard label="Workflows created" value={totalWorkflows !== undefined ? String(totalWorkflows) : "—"} />
          <StatCard label="Agent networks" value={totalNetworks !== undefined ? String(totalNetworks) : "—"} delay={100} />
          <StatCard label="Failure blast radius" value="1 stage" sub="only the failed stage's ETH is withheld" delay={200} />
        </div>

        <Reveal className="ag-panel p-6">
          <h3 className="font-display font-bold text-lg text-bone">Open a workflow</h3>
          <div className="mt-4 flex gap-3">
            <input
              className="input flex-1 font-mono"
              placeholder="0x… workflow ID (from the WorkflowCreated event)"
              value={lookup}
              onChange={(e) => setLookup(e.target.value.trim())}
            />
            <Link
              href={HEX32.test(lookup) ? `/workflows/${lookup}` : "#"}
              className={`btn-primary ${!HEX32.test(lookup) ? "opacity-50 pointer-events-none" : ""}`}
            >
              <Search size={16} /> Open
            </Link>
          </div>
        </Reveal>

        <div className="grid md:grid-cols-2 gap-6">
          <Reveal variant="left" className="card-hover p-8">
            <div className="flex items-center gap-3 text-gold">
              <ArrowRight size={22} />
              <h3 className="font-display font-bold text-2xl text-bone">Pipeline</h3>
            </div>
            <p className="mt-3 text-text-secondary leading-relaxed">
              Sequential relay: Agent A&apos;s output becomes Agent B&apos;s input becomes Agent C&apos;s
              validation set. Ideal for research → build → audit chains.
            </p>
            <div className="mt-6 flex items-center gap-2 font-mono text-xs text-text-muted">
              <span className="px-3 py-1.5 rounded-full border border-gold/30 text-gold">A</span>→
              <span className="px-3 py-1.5 rounded-full border border-gold/30 text-gold">B</span>→
              <span className="px-3 py-1.5 rounded-full border border-gold/30 text-gold">C</span>
            </div>
          </Reveal>

          <Reveal variant="right" delay={120} className="card-hover p-8">
            <div className="flex items-center gap-3 text-sky">
              <GitMerge size={22} />
              <h3 className="font-display font-bold text-2xl text-bone">Parallel</h3>
            </div>
            <p className="mt-3 text-text-secondary leading-relaxed">
              Fan-out / fan-in: N agents attack independent slices simultaneously; a designated
              aggregator merges the results and unlocks payment.
            </p>
            <div className="mt-6 flex items-center gap-2 font-mono text-xs text-text-muted">
              <span className="flex flex-col gap-1">
                <span className="px-3 py-1 rounded-full border border-sky/30 text-sky">A</span>
                <span className="px-3 py-1 rounded-full border border-sky/30 text-sky">B</span>
                <span className="px-3 py-1 rounded-full border border-sky/30 text-sky">C</span>
              </span>
              <span>⇒</span>
              <span className="px-3 py-1.5 rounded-full border border-ember/40 text-ember">AGG</span>
            </div>
          </Reveal>
        </div>
      </div>
    </div>
  );
}

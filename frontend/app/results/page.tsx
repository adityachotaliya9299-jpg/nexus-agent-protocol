"use client";

import Link from "next/link";
import { useState } from "react";
import { Anchor, Plus } from "lucide-react";
import { PageHero, StatCard, EmptyState } from "@/components/ui/Primitives";
import { Reveal } from "@/components/fx/Reveal";
import { ResultCard } from "@/components/results/ResultCard";
import { useAgentResults, useTotalAnchored } from "@/lib/hooks/useResultStorage";

export default function ResultsPage() {
  const { data: totalAnchored } = useTotalAnchored();
  const [agentInput, setAgentInput] = useState("");
  const [agentId, setAgentId] = useState<number | undefined>();
  const { data: taskIds, isLoading } = useAgentResults(agentId);

  const ids = (taskIds as `0x${string}`[] | undefined) ?? [];

  return (
    <div>
      <PageHero
        eyebrow="Result Storage"
        title="Work that outlives"
        accent="everything"
        blurb="Deliverables live on Arweave — pay once, stored forever — while their keccak256 fingerprints are anchored on Ethereum. Anyone, at any time, can re-fetch the content and prove it hasn't changed by a single byte."
        actions={
          <Link href="/results/anchor" className="btn-primary">
            <Plus size={16} /> Anchor a result
          </Link>
        }
      />

      <div className="ag-section py-12 space-y-10">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <StatCard label="Results anchored" value={totalAnchored !== undefined ? String(totalAnchored) : "—"} />
          <StatCard label="Storage cost" value="~$0.004/MB" sub="one-time, permanent" delay={100} />
          <StatCard label="On-chain footprint" value="75 bytes" sub="TX ID + content hash" delay={200} />
        </div>

        <Reveal className="ag-panel p-6">
          <h3 className="font-display font-bold text-lg text-bone">Browse an agent&apos;s results</h3>
          <div className="mt-4 flex gap-3">
            <input
              className="input flex-1"
              type="number"
              min="1"
              placeholder="Agent ID (e.g. 1)"
              value={agentInput}
              onChange={(e) => setAgentInput(e.target.value)}
            />
            <button
              className={`btn-primary ${!agentInput ? "opacity-50 pointer-events-none" : ""}`}
              onClick={() => setAgentId(Number(agentInput))}
            >
              Load results
            </button>
          </div>
        </Reveal>

        {agentId !== undefined && (
          isLoading ? (
            <div className="grid sm:grid-cols-2 gap-4">{[0, 1].map((i) => <div key={i} className="card h-64 animate-pulse" />)}</div>
          ) : ids.length === 0 ? (
            <EmptyState
              icon={<Anchor size={36} />}
              title={`Agent #${agentId} has no anchored results`}
              body="Once this agent anchors a deliverable, its permanent record appears here with a live verification button."
            />
          ) : (
            <div className="grid sm:grid-cols-2 gap-4">
              {ids.map((tid) => <ResultCard key={tid} taskId={tid} />)}
            </div>
          )
        )}
      </div>
    </div>
  );
}

"use client";

import Link from "next/link";
import { useState } from "react";
import { ArrowLeft, ArrowRight, GitMerge } from "lucide-react";
import { PageHero } from "@/components/ui/Primitives";
import { Reveal } from "@/components/fx/Reveal";
import { PipelineBuilder } from "@/components/workflows/PipelineBuilder";
import { ParallelWorkflowBuilder } from "@/components/workflows/ParallelWorkflowBuilder";

export default function CreateWorkflowPage() {
  const [mode, setMode] = useState<"pipeline" | "parallel">("pipeline");

  return (
    <div>
      <PageHero
        eyebrow="Workflow · New"
        title="Design the"
        accent="assembly line"
        blurb="Pick a topology, staff each stage with an agent from the marketplace, and fund the whole run in one transaction. The coordinator escrows every stage's budget until its work lands."
        actions={
          <Link href="/workflows" className="btn-ghost">
            <ArrowLeft size={15} /> All workflows
          </Link>
        }
      />

      <div className="ag-section py-12 max-w-3xl">
        <Reveal>
          <div className="inline-flex p-1 rounded-full bg-surface border border-border mb-8">
            <button
              onClick={() => setMode("pipeline")}
              className={`flex items-center gap-2 px-6 py-2.5 rounded-full text-sm font-display font-semibold transition-all ${
                mode === "pipeline" ? "bg-gold text-void" : "text-text-secondary hover:text-bone"
              }`}
            >
              <ArrowRight size={15} /> Pipeline
            </button>
            <button
              onClick={() => setMode("parallel")}
              className={`flex items-center gap-2 px-6 py-2.5 rounded-full text-sm font-display font-semibold transition-all ${
                mode === "parallel" ? "bg-gold text-void" : "text-text-secondary hover:text-bone"
              }`}
            >
              <GitMerge size={15} /> Parallel
            </button>
          </div>
        </Reveal>

        <Reveal key={mode} variant="up">
          {mode === "pipeline" ? <PipelineBuilder /> : <ParallelWorkflowBuilder />}
        </Reveal>
      </div>
    </div>
  );
}

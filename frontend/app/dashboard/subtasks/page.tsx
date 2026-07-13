"use client";

import Link from "next/link";
import { Plus, GitBranch } from "lucide-react";
import { PageHero, StatCard } from "@/components/ui/Primitives";
import { SubTaskPanel } from "@/components/subtasks/SubTaskPanel";
import { RelationshipCard } from "@/components/subtasks/RelationshipCard";
import { useTotalSubTasks } from "@/lib/hooks/useAgentComposability";

export default function SubTasksPage() {
  const { data: total } = useTotalSubTasks();

  return (
    <div>
      <PageHero
        eyebrow="Composability"
        title="Agents hiring"
        accent="agents"
        blurb="A parent agent decomposes its job, hires specialists, and pays them a trustless basis-point split on approval. This page manages the full sub-task lifecycle: create, assign, submit, approve."
        actions={
          <Link href="/dashboard/subtasks/create" className="btn-primary">
            <Plus size={16} /> Create sub-task
          </Link>
        }
      />

      <div className="ag-section py-12 space-y-8">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <StatCard label="Total sub-tasks on-chain" value={total !== undefined ? String(total) : "—"} />
          <StatCard label="Revenue split" value="Automatic" sub="paid on approval, by basis points" delay={100} />
          <StatCard label="Middlemen" value="0" sub="parent ↔ sub-agent, direct" delay={200} />
        </div>

        <div className="grid lg:grid-cols-[1.4fr_1fr] gap-8 items-start">
          <SubTaskPanel />
          <div className="space-y-6">
            <RelationshipCard />
            <div className="card p-6">
              <div className="flex items-center gap-3">
                <GitBranch size={18} className="text-gold" />
                <h3 className="font-display font-bold text-bone">Where do IDs come from?</h3>
              </div>
              <p className="text-sm text-text-secondary mt-3 leading-relaxed">
                Creating a sub-task emits <code className="text-gold text-xs">SubTaskCreated(subTaskId, …)</code>.
                Save that ID — it&apos;s the handle for assignment, submission, and approval below.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

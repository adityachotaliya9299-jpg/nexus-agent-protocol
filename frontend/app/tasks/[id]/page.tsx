"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useReadContract } from "wagmi";
import { TaskDetailHeader } from "@/components/tasks/TaskDetailHeader";
import { TaskBidList } from "@/components/tasks/TaskBidList";
import { TaskTimeline } from "@/components/tasks/TaskTimeline";
import { TaskBidPanel } from "@/components/tasks/TaskBidPanel";
import { useSgTask } from "@/lib/hooks/useSubgraph";
import { parseTaskMeta } from "@/lib/subgraph";
import { CONTRACTS, TASK_MARKETPLACE_ABI, type Task } from "@/lib/contracts";

export default function TaskDetailPage() {
  const params = useParams();
  const id = params.id as string;
  const isHexId = /^0x[0-9a-fA-F]{64}$/.test(id);

  // chain is the source of truth, the subgraph fills in metadata faster
  const { data: chainTask, isLoading } = useReadContract({
    address: CONTRACTS.TaskMarketplace,
    abi: TASK_MARKETPLACE_ABI,
    functionName: "getTask",
    args: isHexId ? [id as `0x${string}`] : undefined,
    query: { enabled: isHexId },
  });
  const { data: sgData } = useSgTask(isHexId ? id : undefined);

  const raw = chainTask as any;
  const sg = sgData?.task;
  const exists = raw && raw.client !== "0x0000000000000000000000000000000000000000";

  const source = exists
    ? {
        client: raw.client as string,
        metadataURI: raw.metadataURI as string,
        reward: raw.reward as bigint,
        deadline: Number(raw.deadline),
        createdAt: Number(raw.createdAt),
        status: Number(raw.status),
        assignedAgentId: Number(raw.assignedAgentId),
        minReputation: Number(raw.minReputation),
      }
    : sg
    ? {
        client: sg.rawClient,
        metadataURI: sg.metadataURI,
        reward: BigInt(sg.reward),
        deadline: Number(sg.deadline),
        createdAt: Number(sg.createdAt),
        status: sg.status,
        assignedAgentId: sg.assignedAgent ? Number(sg.assignedAgent.agentId) : 0,
        minReputation: Number(sg.minReputation),
      }
    : null;

  if (!isHexId) {
    return <NotFound id={id} reason="That doesn't look like a task id." />;
  }

  if (isLoading && !source) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-5">
        {[180, 140, 220].map((h, i) => (
          <div key={i} className="card animate-pulse" style={{ height: h }} />
        ))}
      </div>
    );
  }

  if (!source) {
    return <NotFound id={id} reason="No task with this id exists on Sepolia." />;
  }

  const meta = parseTaskMeta(source.metadataURI, id);
  const task: Task = {
    taskId: id,
    client: source.client,
    metadataURI: source.metadataURI,
    reward: source.reward,
    deadline: source.deadline,
    createdAt: source.createdAt,
    status: source.status,
    assignedAgentId: source.assignedAgentId,
    minReputation: source.minReputation,
    title: meta.title,
    description: meta.description,
    category: meta.category,
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12">
      <div className="flex items-center gap-2 mb-8 font-mono text-xs text-text-secondary">
        <Link href="/tasks" className="hover:text-gold transition-colors">Marketplace</Link>
        <span className="text-text-muted">/</span>
        <span className="text-gold truncate max-w-[16rem] sm:max-w-xs">{task.title}</span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-6">
          <TaskDetailHeader task={task} />
          <TaskTimeline task={task} />
          <TaskBidList task={task} />
        </div>

        <div className="lg:col-span-1">
          <div className="lg:sticky lg:top-24">
            <TaskBidPanel task={task} />
          </div>
        </div>
      </div>
    </div>
  );
}

function NotFound({ id, reason }: { id: string; reason: string }) {
  return (
    <div className="min-h-[60vh] flex flex-col items-center justify-center gap-4 px-6 text-center">
      <h2 className="font-display font-bold text-2xl text-bone">Task not found</h2>
      <p className="text-text-secondary text-sm max-w-md break-all">
        {reason} <span className="font-mono text-xs">({id})</span>
      </p>
      <Link href="/tasks" className="btn-secondary mt-2">← Back to marketplace</Link>
    </div>
  );
}

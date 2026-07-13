import { notFound } from "next/navigation";
import { MOCK_TASKS } from "@/lib/contracts";
import { TaskDetailHeader } from "@/components/tasks/TaskDetailHeader";
import { TaskBidList }      from "@/components/tasks/TaskBidList";
import { TaskTimeline }     from "@/components/tasks/TaskTimeline";
import { TaskBidPanel }     from "@/components/tasks/TaskBidPanel";

export function generateStaticParams() {
  return MOCK_TASKS.map((t) => ({ id: t.taskId }));
}

export function generateMetadata({ params }: { params: { id: string } }) {
  const task = MOCK_TASKS.find((t) => t.taskId === params.id);
  if (!task) return { title: "Task Not Found" };
  return {
    title: `${task.title} — AGORA Task Marketplace`,
    description: task.description,
  };
}

export default function TaskDetailPage({ params }: { params: { id: string } }) {
  const task = MOCK_TASKS.find((t) => t.taskId === params.id);
  if (!task) notFound();

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">

      {/* Breadcrumb */}
      <div className="flex items-center gap-2 mb-8 font-mono text-xs text-[#A89F8D]">
        <a href="/tasks" className="hover:text-cyan transition-colors">Marketplace</a>
        <span className="text-[#6B6355]">/</span>
        <span className="text-cyan truncate max-w-xs">{task.title}</span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Left: main content */}
        <div className="lg:col-span-2 space-y-6">
          <TaskDetailHeader task={task} />
          <TaskTimeline task={task} />
          <TaskBidList task={task} />
        </div>

        {/* Right: bid panel */}
        <div className="lg:col-span-1">
          <div className="sticky top-24">
            <TaskBidPanel task={task} />
          </div>
        </div>
      </div>
    </div>
  );
}
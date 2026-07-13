import { CheckCircle, Circle, Clock } from "lucide-react";
import { type Task } from "@/lib/contracts";

type Step = { label: string; desc: string; done: boolean; active: boolean };

function getSteps(task: Task): Step[] {
  const s = task.status;
  return [
    {
      label: "Task Posted",
      desc: "Client posted task with ETH reward in escrow",
      done: true,
      active: s === 0,
    },
    {
      label: "Bids Received",
      desc: "Registered agents submit proposals",
      done: s >= 1,
      active: s === 0,
    },
    {
      label: "Agent Assigned",
      desc: "Client selected winning bid — work begins",
      done: s >= 1,
      active: s === 1,
    },
    {
      label: "Work Submitted",
      desc: "Agent delivered results for client review",
      done: s >= 2,
      active: s === 1,
    },
    {
      label: "Payment Released",
      desc: "Client approved — ETH sent to agent wallet",
      done: s === 2,
      active: s === 2,
    },
  ];
}

export function TaskTimeline({ task }: { task: Task }) {
  const steps = getSteps(task);

  return (
    <div className="card p-6">
      <h3 className="font-display font-semibold text-[#F4EFE6] mb-5">Task Timeline</h3>

      <div className="space-y-0">
        {steps.map((step, i) => {
          const isLast = i === steps.length - 1;
          const Icon = step.done ? CheckCircle : step.active ? Clock : Circle;
          const iconColor = step.done
            ? "text-emerald"
            : step.active
            ? "text-amber"
            : "text-[#3A3226]";
          const lineColor = step.done ? "bg-emerald" : "bg-[#2A241B]";

          return (
            <div key={step.label} className="flex gap-4">
              {/* Timeline spine */}
              <div className="flex flex-col items-center">
                <div className={`shrink-0 mt-1 ${iconColor}`}>
                  <Icon className="w-5 h-5" />
                </div>
                {!isLast && (
                  <div className={`w-px flex-1 mt-1 mb-1 min-h-[2rem] ${lineColor}`} />
                )}
              </div>

              {/* Content */}
              <div className={`pb-6 ${isLast ? "" : ""}`}>
                <div className={`font-display font-semibold text-sm ${
                  step.done ? "text-[#F4EFE6]" : step.active ? "text-amber" : "text-[#6B6355]"
                }`}>
                  {step.label}
                </div>
                <div className="font-mono text-xs text-[#6B6355] mt-0.5">{step.desc}</div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
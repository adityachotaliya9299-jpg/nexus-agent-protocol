"use client";

import { useReadContract } from "wagmi";
import { formatEther } from "viem";
import { CountUp } from "@/components/fx/CountUp";
import { Reveal } from "@/components/fx/Reveal";
import {
  CONTRACTS,
  AGENT_REGISTRY_ABI,
  TASK_MARKETPLACE_ABI,
  ZK_ESCROW_ABI,
} from "@/lib/contracts";

export function StatsBand() {
  const { data: totalAgents } = useReadContract({
    address: CONTRACTS.AgentRegistry,
    abi: AGENT_REGISTRY_ABI,
    functionName: "totalAgents",
  });
  const { data: tasksPosted } = useReadContract({
    address: CONTRACTS.TaskMarketplace,
    abi: TASK_MARKETPLACE_ABI,
    functionName: "totalTasksPosted",
  });
  const { data: tasksCompleted } = useReadContract({
    address: CONTRACTS.TaskMarketplace,
    abi: TASK_MARKETPLACE_ABI,
    functionName: "totalTasksCompleted",
  });
  const { data: totalReleased } = useReadContract({
    address: CONTRACTS.ZKEscrow,
    abi: ZK_ESCROW_ABI,
    functionName: "totalReleased",
  });

  const releasedEth = totalReleased !== undefined ? Number(formatEther(totalReleased as bigint)) : undefined;

  const stats = [
    { label: "Registered agents", value: totalAgents !== undefined ? Number(totalAgents) : undefined, decimals: 0, unit: "" },
    { label: "Tasks posted", value: tasksPosted !== undefined ? Number(tasksPosted) : undefined, decimals: 0, unit: "" },
    { label: "Tasks completed", value: tasksCompleted !== undefined ? Number(tasksCompleted) : undefined, decimals: 0, unit: "" },
    { label: "Paid via ZK escrow", value: releasedEth, decimals: releasedEth !== undefined && releasedEth < 100 ? 2 : 0, unit: "ETH" },
  ];

  return (
    <section className="ag-section py-16 md:py-24">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-px bg-border rounded-3xl overflow-hidden border border-border">
        {stats.map((s, i) => (
          <Reveal key={s.label} delay={i * 110} className="bg-surface p-6 md:p-8 lg:p-10 min-w-0">
            <div className="flex items-baseline gap-2 min-w-0">
              <span className="font-display font-extrabold text-3xl md:text-4xl lg:text-[42px] gradient-text tabular-nums leading-none whitespace-nowrap">
                {s.value === undefined ? (
                  <span className="inline-block w-16 h-8 rounded-lg bg-raised animate-pulse align-middle" />
                ) : (
                  <CountUp to={s.value} decimals={s.decimals} />
                )}
              </span>
              {s.unit && s.value !== undefined && (
                <span className="font-mono text-xs md:text-sm text-gold shrink-0">{s.unit}</span>
              )}
            </div>
            <div className="label mt-3">{s.label}</div>
            <div className="font-mono text-[10px] text-text-muted mt-1 uppercase tracking-widest">live · sepolia</div>
          </Reveal>
        ))}
      </div>
    </section>
  );
}

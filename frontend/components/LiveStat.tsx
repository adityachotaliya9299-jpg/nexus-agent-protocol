"use client";

import { useReadContract } from "wagmi";
import { formatEther } from "viem";
import {
  CONTRACTS,
  AGENT_REGISTRY_ABI,
  TASK_MARKETPLACE_ABI,
  ZK_ESCROW_ABI,
} from "@/lib/contracts";

const SOURCES = {
  totalAgents: { address: CONTRACTS.AgentRegistry, abi: AGENT_REGISTRY_ABI, fn: "totalAgents", kind: "count" },
  totalTasks: { address: CONTRACTS.TaskMarketplace, abi: TASK_MARKETPLACE_ABI, fn: "totalTasksPosted", kind: "count" },
  tasksCompleted: { address: CONTRACTS.TaskMarketplace, abi: TASK_MARKETPLACE_ABI, fn: "totalTasksCompleted", kind: "count" },
  escrowReleased: { address: CONTRACTS.ZKEscrow, abi: ZK_ESCROW_ABI, fn: "totalReleased", kind: "eth" },
} as const;

export function LiveStat({ stat, className = "" }: { stat: keyof typeof SOURCES; className?: string }) {
  const src = SOURCES[stat];
  const { data } = useReadContract({
    address: src.address,
    abi: src.abi as any,
    functionName: src.fn,
  });

  let text = "…";
  if (data !== undefined) {
    text = src.kind === "eth"
      ? `${Number(formatEther(data as bigint)).toLocaleString(undefined, { maximumFractionDigits: 2 })} ETH`
      : Number(data).toLocaleString();
  }

  return <span className={className}>{text}</span>;
}

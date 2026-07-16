"use client";

import { useQuery } from "@tanstack/react-query";
import {
  fetchTasks,
  fetchTask,
  fetchBids,
  fetchAgents,
  fetchAgentTasks,
  fetchPlans,
  fetchActivity,
} from "@/lib/subgraph";

const STALE = 30_000;

export function useSgTasks(first = 50) {
  return useQuery({
    queryKey: ["sg-tasks", first],
    queryFn: () => fetchTasks(first),
    staleTime: STALE,
    retry: 1,
  });
}

export function useSgTask(id: string | undefined) {
  return useQuery({
    queryKey: ["sg-task", id],
    queryFn: () => fetchTask(id!),
    enabled: !!id,
    staleTime: STALE,
    retry: 1,
  });
}

export function useSgBids(taskId: string | undefined) {
  return useQuery({
    queryKey: ["sg-bids", taskId],
    queryFn: () => fetchBids(taskId!),
    enabled: !!taskId,
    staleTime: STALE,
    retry: 1,
  });
}

export function useSgAgents(first = 50) {
  return useQuery({
    queryKey: ["sg-agents", first],
    queryFn: () => fetchAgents(first),
    staleTime: STALE,
    retry: 1,
  });
}

export function useSgAgentTasks(agentId: string | undefined) {
  return useQuery({
    queryKey: ["sg-agent-tasks", agentId],
    queryFn: () => fetchAgentTasks(agentId!),
    enabled: !!agentId,
    staleTime: STALE,
    retry: 1,
  });
}

export function useSgPlans(first = 50) {
  return useQuery({
    queryKey: ["sg-plans", first],
    queryFn: () => fetchPlans(first),
    staleTime: STALE,
    retry: 1,
  });
}

export function useSgActivity() {
  return useQuery({
    queryKey: ["sg-activity"],
    queryFn: fetchActivity,
    staleTime: 20_000,
    refetchInterval: 45_000,
    retry: 1,
  });
}

import { useReadContract } from "wagmi";
import { CONTRACTS, REPUTATION_ORACLE_ABI } from "@/lib/contracts";

/** Get the current reputation score for an agent */
export function useReputationScore(agentId: number | undefined) {
  return useReadContract({
    address: CONTRACTS.ReputationOracle,
    abi: REPUTATION_ORACLE_ABI,
    functionName: "getScore",
    args: agentId !== undefined ? [BigInt(agentId)] : undefined,
    query: { enabled: agentId !== undefined },
  });
}

/** Get full reputation struct (score, tasksCompleted, timestamps, slashCount) */
export function useReputation(agentId: number | undefined) {
  return useReadContract({
    address: CONTRACTS.ReputationOracle,
    abi: REPUTATION_ORACLE_ABI,
    functionName: "getReputation",
    args: agentId !== undefined ? [BigInt(agentId)] : undefined,
    query: { enabled: agentId !== undefined },
  });
}

/** Get full reputation event history for an agent */
export function useReputationHistory(agentId: number | undefined) {
  return useReadContract({
    address: CONTRACTS.ReputationOracle,
    abi: REPUTATION_ORACLE_ABI,
    functionName: "getEventHistory",
    args: agentId !== undefined ? [BigInt(agentId)] : undefined,
    query: { enabled: agentId !== undefined },
  });
}

/** Protocol initial score constant */
export function useInitialScore() {
  return useReadContract({
    address: CONTRACTS.ReputationOracle,
    abi: REPUTATION_ORACLE_ABI,
    functionName: "INITIAL_SCORE",
  });
}
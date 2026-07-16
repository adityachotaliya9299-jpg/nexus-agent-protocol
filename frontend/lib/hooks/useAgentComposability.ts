import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseEther } from "viem";
import { CONTRACTS, AGENT_COMPOSABILITY_ABI } from "@/lib/contracts";

export const SUBTASK_STATUS_LABELS = ["OPEN", "ASSIGNED", "SUBMITTED", "COMPLETED", "CANCELLED"] as const;

// reads
export function useSubTask(subTaskId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentComposability,
    abi: AGENT_COMPOSABILITY_ABI,
    functionName: "getSubTask",
    args: subTaskId ? [subTaskId] : undefined,
    query: { enabled: !!subTaskId },
  });
}

export function useAgentRelationship(parentId: number | undefined, subId: number | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentComposability,
    abi: AGENT_COMPOSABILITY_ABI,
    functionName: "getAgentRelationship",
    args: parentId !== undefined && subId !== undefined ? [BigInt(parentId), BigInt(subId)] : undefined,
    query: { enabled: parentId !== undefined && subId !== undefined },
  });
}

export function useTotalSubTasks() {
  return useReadContract({
    address: CONTRACTS.AgentComposability,
    abi: AGENT_COMPOSABILITY_ABI,
    functionName: "totalSubTasks",
  });
}

// writes
export function useCreateSubTask() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createSubTask = (
    parentTaskId: `0x${string}`,
    parentAgentId: number,
    metadataURI: string,
    deadline: number,
    splitBps: number,
    rewardEth: string
  ) => {
    writeContract({
      address: CONTRACTS.AgentComposability,
      abi: AGENT_COMPOSABILITY_ABI,
      functionName: "createSubTask",
      args: [parentTaskId, BigInt(parentAgentId), metadataURI, BigInt(deadline), BigInt(splitBps)],
      value: parseEther(rewardEth),
    });
  };

  return { createSubTask, hash, isPending, isConfirming, isSuccess, error };
}

export function useAssignSubAgent() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const assignSubAgent = (subTaskId: `0x${string}`, subAgentId: number) => {
    writeContract({
      address: CONTRACTS.AgentComposability,
      abi: AGENT_COMPOSABILITY_ABI,
      functionName: "assignSubAgent",
      args: [subTaskId, BigInt(subAgentId)],
    });
  };

  return { assignSubAgent, hash, isPending, isConfirming, isSuccess, error };
}

export function useSubmitSubWork() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const submitSubWork = (subTaskId: `0x${string}`, subAgentId: number, resultURI: string) => {
    writeContract({
      address: CONTRACTS.AgentComposability,
      abi: AGENT_COMPOSABILITY_ABI,
      functionName: "submitSubWork",
      args: [subTaskId, BigInt(subAgentId), resultURI],
    });
  };

  return { submitSubWork, hash, isPending, isConfirming, isSuccess, error };
}

export function useApproveSubWork() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const approveSubWork = (subTaskId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.AgentComposability,
      abi: AGENT_COMPOSABILITY_ABI,
      functionName: "approveSubWork",
      args: [subTaskId],
    });
  };

  return { approveSubWork, hash, isPending, isConfirming, isSuccess, error };
}

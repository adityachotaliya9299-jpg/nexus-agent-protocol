import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseEther } from "viem";
import { CONTRACTS, TASK_MARKETPLACE_ABI } from "@/lib/contracts";

// reads
/** Get a single task by taskId */
export function useTask(taskId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.TaskMarketplace,
    abi: TASK_MARKETPLACE_ABI,
    functionName: "getTask",
    args: taskId ? [taskId] : undefined,
    query: { enabled: !!taskId },
  });
}

/** Get a bid for a specific task + agent */
export function useBid(taskId: `0x${string}` | undefined, agentId: number | undefined) {
  return useReadContract({
    address: CONTRACTS.TaskMarketplace,
    abi: TASK_MARKETPLACE_ABI,
    functionName: "getBid",
    args: taskId && agentId !== undefined ? [taskId, BigInt(agentId)] : undefined,
    query: { enabled: !!taskId && agentId !== undefined },
  });
}

/** Protocol fee in basis points */
export function useProtocolFee() {
  return useReadContract({
    address: CONTRACTS.TaskMarketplace,
    abi: TASK_MARKETPLACE_ABI,
    functionName: "protocolFeeBps",
  });
}

/** Total tasks ever posted */
export function useTotalTasks() {
  return useReadContract({
    address: CONTRACTS.TaskMarketplace,
    abi: TASK_MARKETPLACE_ABI,
    functionName: "totalTasks",
  });
}

// writes
/** Post a new task with ETH reward */
export function usePostTask() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const postTask = (metadataURI: string, deadlineTimestamp: number, minReputation: number, rewardEth: string) => {
    writeContract({
      address: CONTRACTS.TaskMarketplace,
      abi: TASK_MARKETPLACE_ABI,
      functionName: "postTask",
      args: [metadataURI, BigInt(deadlineTimestamp), BigInt(minReputation)],
      value: parseEther(rewardEth),
    });
  };

  return { postTask, hash, isPending, isConfirming, isSuccess, error };
}

/** Submit a bid on a task */
export function useSubmitBid() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const submitBid = (taskId: `0x${string}`, agentId: number, proposalURI: string, deliveryTimeSeconds: number) => {
    writeContract({
      address: CONTRACTS.TaskMarketplace,
      abi: TASK_MARKETPLACE_ABI,
      functionName: "submitBid",
      args: [taskId, BigInt(agentId), proposalURI, BigInt(deliveryTimeSeconds)],
    });
  };

  return { submitBid, hash, isPending, isConfirming, isSuccess, error };
}

/** Withdraw a previously submitted bid */
export function useWithdrawBid() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const withdrawBid = (taskId: `0x${string}`, agentId: number) => {
    writeContract({
      address: CONTRACTS.TaskMarketplace,
      abi: TASK_MARKETPLACE_ABI,
      functionName: "withdrawBid",
      args: [taskId, BigInt(agentId)],
    });
  };

  return { withdrawBid, hash, isPending, isConfirming, isSuccess, error };
}

/** Assign a specific agent to a task (called by task client) */
export function useAssignAgent() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const assignAgent = (taskId: `0x${string}`, agentId: number) => {
    writeContract({
      address: CONTRACTS.TaskMarketplace,
      abi: TASK_MARKETPLACE_ABI,
      functionName: "assignAgent",
      args: [taskId, BigInt(agentId)],
    });
  };

  return { assignAgent, hash, isPending, isConfirming, isSuccess, error };
}

/** Submit completed work (called by assigned agent) */
export function useSubmitWork() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const submitWork = (taskId: `0x${string}`, resultURI: string) => {
    writeContract({
      address: CONTRACTS.TaskMarketplace,
      abi: TASK_MARKETPLACE_ABI,
      functionName: "submitWork",
      args: [taskId, resultURI],
    });
  };

  return { submitWork, hash, isPending, isConfirming, isSuccess, error };
}

/** Approve submitted work and release escrow (called by task client) */
export function useApproveWork() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const approveWork = (taskId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.TaskMarketplace,
      abi: TASK_MARKETPLACE_ABI,
      functionName: "approveWork",
      args: [taskId],
    });
  };

  return { approveWork, hash, isPending, isConfirming, isSuccess, error };
}

/** Cancel a task and reclaim ETH (before assignment) */
export function useCancelTask() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const cancelTask = (taskId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.TaskMarketplace,
      abi: TASK_MARKETPLACE_ABI,
      functionName: "cancelTask",
      args: [taskId],
    });
  };

  return { cancelTask, hash, isPending, isConfirming, isSuccess, error };
}

/** Raise a dispute on a submitted task */
export function useRaiseDispute() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const raiseDispute = (taskId: `0x${string}`, evidenceURI: string) => {
    writeContract({
      address: CONTRACTS.TaskMarketplace,
      abi: TASK_MARKETPLACE_ABI,
      functionName: "raiseDispute",
      args: [taskId, evidenceURI],
    });
  };

  return { raiseDispute, hash, isPending, isConfirming, isSuccess, error };
}
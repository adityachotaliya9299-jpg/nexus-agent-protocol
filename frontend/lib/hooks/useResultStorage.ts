import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { CONTRACTS, RESULT_STORAGE_ABI } from "@/lib/contracts";

// reads
export function useStoredResult(taskId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.ResultStorage,
    abi: RESULT_STORAGE_ABI,
    functionName: "getResult",
    args: taskId ? [taskId] : undefined,
    query: { enabled: !!taskId },
  });
}

export function useAgentResults(agentId: number | undefined) {
  return useReadContract({
    address: CONTRACTS.ResultStorage,
    abi: RESULT_STORAGE_ABI,
    functionName: "getAgentResults",
    args: agentId !== undefined ? [BigInt(agentId)] : undefined,
    query: { enabled: agentId !== undefined },
  });
}

export function useIsAnchored(taskId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.ResultStorage,
    abi: RESULT_STORAGE_ABI,
    functionName: "isAnchored",
    args: taskId ? [taskId] : undefined,
    query: { enabled: !!taskId },
  });
}

export function useTotalAnchored() {
  return useReadContract({ address: CONTRACTS.ResultStorage, abi: RESULT_STORAGE_ABI, functionName: "totalAnchored" });
}

// writes
export function useAnchorResult() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const anchorResult = (
    taskId: `0x${string}`,
    agentId: number,
    arweaveTxId: string,
    contentHash: `0x${string}`,
    contentSize: number,
    contentType: string
  ) => {
    writeContract({
      address: CONTRACTS.ResultStorage,
      abi: RESULT_STORAGE_ABI,
      functionName: "anchorResult",
      args: [taskId, BigInt(agentId), arweaveTxId, contentHash, BigInt(contentSize), contentType],
    });
  };

  return { anchorResult, hash, isPending, isConfirming, isSuccess, error };
}

export function useVerifyResult() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const verifyResult = (taskId: `0x${string}`, contentHash: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.ResultStorage,
      abi: RESULT_STORAGE_ABI,
      functionName: "verifyResult",
      args: [taskId, contentHash],
    });
  };

  return { verifyResult, hash, isPending, isConfirming, isSuccess, error };
}

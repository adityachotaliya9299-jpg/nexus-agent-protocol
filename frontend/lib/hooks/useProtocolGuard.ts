import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseEther } from "viem";
import { CONTRACTS, PROTOCOL_GUARD_ABI } from "@/lib/contracts";

// ── Reads ────────────────────────────────────────────────────

export function useGuardOwner() {
  return useReadContract({ address: CONTRACTS.ProtocolGuard, abi: PROTOCOL_GUARD_ABI, functionName: "owner" });
}

export function useIsPaused(target: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.ProtocolGuard,
    abi: PROTOCOL_GUARD_ABI,
    functionName: "isPaused",
    args: target ? [target] : undefined,
    query: { enabled: !!target },
  });
}

export function useContractStatus(target: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.ProtocolGuard,
    abi: PROTOCOL_GUARD_ABI,
    functionName: "getContractStatus",
    args: target ? [target] : undefined,
    query: { enabled: !!target },
  });
}

export function useRateLimit() {
  return useReadContract({ address: CONTRACTS.ProtocolGuard, abi: PROTOCOL_GUARD_ABI, functionName: "getRateLimit" });
}

export function useTotalInvariants() {
  return useReadContract({ address: CONTRACTS.ProtocolGuard, abi: PROTOCOL_GUARD_ABI, functionName: "totalInvariants" });
}

export function useGuardianCount() {
  return useReadContract({ address: CONTRACTS.ProtocolGuard, abi: PROTOCOL_GUARD_ABI, functionName: "guardianCount" });
}

// ── Writes ───────────────────────────────────────────────────

export function usePauseContract() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const pause = (target: `0x${string}`, reason: string, durationSeconds: number) => {
    writeContract({
      address: CONTRACTS.ProtocolGuard,
      abi: PROTOCOL_GUARD_ABI,
      functionName: "pause",
      args: [target, reason, BigInt(durationSeconds)],
    });
  };

  return { pause, hash, isPending, isConfirming, isSuccess, error };
}

export function useUnpauseContract() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const unpause = (target: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.ProtocolGuard,
      abi: PROTOCOL_GUARD_ABI,
      functionName: "unpause",
      args: [target],
    });
  };

  return { unpause, hash, isPending, isConfirming, isSuccess, error };
}

export function usePauseAll() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const pauseAll = (reason: string) => {
    writeContract({
      address: CONTRACTS.ProtocolGuard,
      abi: PROTOCOL_GUARD_ABI,
      functionName: "pauseAll",
      args: [reason],
    });
  };

  return { pauseAll, hash, isPending, isConfirming, isSuccess, error };
}

export function useUnpauseAll() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const unpauseAll = () => {
    writeContract({
      address: CONTRACTS.ProtocolGuard,
      abi: PROTOCOL_GUARD_ABI,
      functionName: "unpauseAll",
      args: [],
    });
  };

  return { unpauseAll, hash, isPending, isConfirming, isSuccess, error };
}

export function useSetRateLimit() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const setRateLimit = (windowSeconds: number, maxOutflowEth: string) => {
    writeContract({
      address: CONTRACTS.ProtocolGuard,
      abi: PROTOCOL_GUARD_ABI,
      functionName: "setRateLimit",
      args: [BigInt(windowSeconds), parseEther(maxOutflowEth)],
    });
  };

  return { setRateLimit, hash, isPending, isConfirming, isSuccess, error };
}

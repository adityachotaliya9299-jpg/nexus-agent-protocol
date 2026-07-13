import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseEther } from "viem";
import { CONTRACTS, ZK_ESCROW_ABI } from "@/lib/contracts";

export type EscrowStatus = 0 | 1 | 2 | 3; // OPEN | RELEASED | REFUNDED | DISPUTED
export const ESCROW_STATUS_LABELS = ["OPEN", "RELEASED", "REFUNDED", "DISPUTED"] as const;

// ── Reads ────────────────────────────────────────────────────

export function useEscrow(escrowId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.ZKEscrow,
    abi: ZK_ESCROW_ABI,
    functionName: "getEscrow",
    args: escrowId ? [escrowId] : undefined,
    query: { enabled: !!escrowId },
  });
}

export function useTaskEscrow(taskId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.ZKEscrow,
    abi: ZK_ESCROW_ABI,
    functionName: "getTaskEscrow",
    args: taskId ? [taskId] : undefined,
    query: { enabled: !!taskId },
  });
}

export function useTotalEscrows() {
  return useReadContract({ address: CONTRACTS.ZKEscrow, abi: ZK_ESCROW_ABI, functionName: "totalEscrows" });
}

export function useTotalReleased() {
  return useReadContract({ address: CONTRACTS.ZKEscrow, abi: ZK_ESCROW_ABI, functionName: "totalReleased" });
}

// ── Writes ───────────────────────────────────────────────────

export function useCreateEscrow() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createEscrow = (taskId: `0x${string}`, agentWallet: `0x${string}`, deadline: number, amountEth: string) => {
    writeContract({
      address: CONTRACTS.ZKEscrow,
      abi: ZK_ESCROW_ABI,
      functionName: "createEscrow",
      args: [taskId, agentWallet, BigInt(deadline)],
      value: parseEther(amountEth),
    });
  };

  return { createEscrow, hash, isPending, isConfirming, isSuccess, error };
}

export function useSetCommitment() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const setCommitment = (escrowId: `0x${string}`, commitment: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.ZKEscrow,
      abi: ZK_ESCROW_ABI,
      functionName: "setCommitment",
      args: [escrowId, commitment],
    });
  };

  return { setCommitment, hash, isPending, isConfirming, isSuccess, error };
}

export interface Groth16Proof {
  pA: [bigint, bigint];
  pB: [[bigint, bigint], [bigint, bigint]];
  pC: [bigint, bigint];
  pubSignals: [bigint, bigint];
}

export function useReleaseWithProof() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const releaseWithProof = (
    escrowId: `0x${string}`,
    resultHash: `0x${string}`,
    salt: `0x${string}`,
    proof: Groth16Proof
  ) => {
    writeContract({
      address: CONTRACTS.ZKEscrow,
      abi: ZK_ESCROW_ABI,
      functionName: "releaseWithProof",
      args: [escrowId, resultHash, salt, proof.pA, proof.pB, proof.pC, proof.pubSignals],
    });
  };

  return { releaseWithProof, hash, isPending, isConfirming, isSuccess, error };
}

export function useRefundAfterDeadline() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const refund = (escrowId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.ZKEscrow,
      abi: ZK_ESCROW_ABI,
      functionName: "refundAfterDeadline",
      args: [escrowId],
    });
  };

  return { refund, hash, isPending, isConfirming, isSuccess, error };
}

export function useRaiseEscrowDispute() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const raiseDispute = (escrowId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.ZKEscrow,
      abi: ZK_ESCROW_ABI,
      functionName: "raiseDispute",
      args: [escrowId],
    });
  };

  return { raiseDispute, hash, isPending, isConfirming, isSuccess, error };
}

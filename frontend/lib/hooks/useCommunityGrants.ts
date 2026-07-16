import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseEther } from "viem";
import { CONTRACTS, COMMUNITY_GRANTS_ABI } from "@/lib/contracts";

export const GRANT_TYPES = ["DEVELOPMENT", "ECOSYSTEM", "RESEARCH", "OPERATIONS", "BOUNTY"] as const;
export const GRANT_STATUS_LABELS = ["PROPOSED", "VOTING", "APPROVED", "EXECUTED", "REJECTED"] as const;

// reads
export function useGrant(grantId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.CommunityGrants,
    abi: COMMUNITY_GRANTS_ABI,
    functionName: "getGrant",
    args: grantId ? [grantId] : undefined,
    query: { enabled: !!grantId },
  });
}

export function useActiveGrants() {
  return useReadContract({
    address: CONTRACTS.CommunityGrants,
    abi: COMMUNITY_GRANTS_ABI,
    functionName: "getActiveGrants",
  });
}

export function useTreasuryBalance() {
  return useReadContract({ address: CONTRACTS.CommunityGrants, abi: COMMUNITY_GRANTS_ABI, functionName: "balance" });
}

export function useTotalDeposited() {
  return useReadContract({ address: CONTRACTS.CommunityGrants, abi: COMMUNITY_GRANTS_ABI, functionName: "totalDeposited" });
}

export function useTotalGranted() {
  return useReadContract({ address: CONTRACTS.CommunityGrants, abi: COMMUNITY_GRANTS_ABI, functionName: "totalGranted" });
}

export function useTotalGrants() {
  return useReadContract({ address: CONTRACTS.CommunityGrants, abi: COMMUNITY_GRANTS_ABI, functionName: "totalGrants" });
}

// writes
export function useProposeGrant() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const proposeGrant = (
    title: string,
    description: string,
    recipient: `0x${string}`,
    amountEth: string,
    grantType: number,
    proposerAgentId: number
  ) => {
    writeContract({
      address: CONTRACTS.CommunityGrants,
      abi: COMMUNITY_GRANTS_ABI,
      functionName: "proposeGrant",
      args: [title, description, recipient, parseEther(amountEth), grantType, BigInt(proposerAgentId)],
    });
  };

  return { proposeGrant, hash, isPending, isConfirming, isSuccess, error };
}

export function useVoteOnGrant() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const voteOnGrant = (grantId: `0x${string}`, agentId: number, support: boolean) => {
    writeContract({
      address: CONTRACTS.CommunityGrants,
      abi: COMMUNITY_GRANTS_ABI,
      functionName: "voteOnGrant",
      args: [grantId, BigInt(agentId), support],
    });
  };

  return { voteOnGrant, hash, isPending, isConfirming, isSuccess, error };
}

export function useFinalizeGrant() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const finalizeGrant = (grantId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.CommunityGrants,
      abi: COMMUNITY_GRANTS_ABI,
      functionName: "finalizeGrant",
      args: [grantId],
    });
  };

  return { finalizeGrant, hash, isPending, isConfirming, isSuccess, error };
}

export function useExecuteGrant() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const executeGrant = (grantId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.CommunityGrants,
      abi: COMMUNITY_GRANTS_ABI,
      functionName: "executeGrant",
      args: [grantId],
    });
  };

  return { executeGrant, hash, isPending, isConfirming, isSuccess, error };
}

export function useDepositToTreasury() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const deposit = (source: string, amountEth: string) => {
    writeContract({
      address: CONTRACTS.CommunityGrants,
      abi: COMMUNITY_GRANTS_ABI,
      functionName: "deposit",
      args: [source],
      value: parseEther(amountEth),
    });
  };

  return { deposit, hash, isPending, isConfirming, isSuccess, error };
}

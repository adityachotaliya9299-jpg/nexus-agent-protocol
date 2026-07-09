import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useBalance } from "wagmi";
import { CONTRACTS, AGENT_WALLET_FACTORY_ABI } from "@/lib/contracts";

// ── Reads ────────────────────────────────────────────────────

/** Get deterministic wallet address for an agentId (before deployment) */
export function useWalletAddress(agentId: number | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentWalletFactory,
    abi: AGENT_WALLET_FACTORY_ABI,
    functionName: "getWallet",
    args: agentId !== undefined ? [BigInt(agentId)] : undefined,
    query: { enabled: agentId !== undefined },
  });
}

/** Check if the wallet for an agentId has been deployed */
export function useWalletDeployed(agentId: number | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentWalletFactory,
    abi: AGENT_WALLET_FACTORY_ABI,
    functionName: "hasWallet",
    args: agentId !== undefined ? [BigInt(agentId)] : undefined,
    query: { enabled: agentId !== undefined },
  });
}

/** Get ETH balance of an agent's smart wallet */
export function useAgentWalletBalance(walletAddress: `0x${string}` | undefined) {
  return useBalance({
    address: walletAddress,
    query: { enabled: !!walletAddress },
  });
}

// ── Writes ───────────────────────────────────────────────────

/** Deploy the ERC-4337 smart wallet for an agentId */
export function useDeployWallet() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const deployWallet = (agentId: number) => {
    writeContract({
      address: CONTRACTS.AgentWalletFactory,
      abi: AGENT_WALLET_FACTORY_ABI,
      functionName: "deployWallet",
      args: [BigInt(agentId)],
    });
  };

  return { deployWallet, hash, isPending, isConfirming, isSuccess, error };
}
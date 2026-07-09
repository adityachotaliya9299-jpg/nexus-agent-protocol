import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useBalance, useAccount } from "wagmi";
import { pad } from "viem";
import { CONTRACTS, AGENT_WALLET_FACTORY_ABI } from "@/lib/contracts";

// ── Reads ────────────────────────────────────────────────────

/** Get deterministic wallet address for an agentId (before deployment) */
export function useWalletAddress(agentId: number | undefined) {
  const { address: owner } = useAccount();

  return useReadContract({
    address: CONTRACTS.AgentWalletFactory,
    abi: AGENT_WALLET_FACTORY_ABI,
    functionName: "computeWalletAddress",
    args: (owner && agentId !== undefined) 
      ? [owner, BigInt(agentId), pad("0x0", { size: 32 })] 
      : undefined,
    query: { enabled: !!owner && agentId !== undefined },
  });
}

/** Check if the wallet for an agentId has been deployed */
export function useWalletDeployed(agentId: number | undefined) {
  const { address: owner } = useAccount();

  return useReadContract({
    address: CONTRACTS.AgentWalletFactory,
    abi: AGENT_WALLET_FACTORY_ABI,
    functionName: "hasWallet",
    args: owner ? [owner] : undefined,
    query: { enabled: !!owner },
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
  const { address: owner } = useAccount();

  const deployWallet = (agentId: number) => {
    if (!owner) {
      console.error("Cannot deploy: No wallet connected");
      return;
    }

    writeContract({
      address: CONTRACTS.AgentWalletFactory,
      abi: AGENT_WALLET_FACTORY_ABI,
      functionName: "deployWallet",
      args: [owner, BigInt(agentId), pad("0x0", { size: 32 })],
    });
  };

  return { deployWallet, hash, isPending, isConfirming, isSuccess, error };
}
import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { CONTRACTS, AGENT_REGISTRY_ABI } from "@/lib/contracts";

// ── Reads ────────────────────────────────────────────────────

/** Get a single agent profile by agentId */
export function useAgent(agentId: number | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentRegistry,
    abi: AGENT_REGISTRY_ABI,
    functionName: "getAgent",
    args: agentId !== undefined ? [BigInt(agentId)] : undefined,
    query: { enabled: agentId !== undefined },
  });
}

/** Get the agentId owned by a given address (returns 0 if none) */
export function useAgentIdByOwner(owner: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentRegistry,
    abi: AGENT_REGISTRY_ABI,
    functionName: "getAgentByOwner",
    args: owner ? [owner] : undefined,
    query: { enabled: !!owner },
  });
}

/** Get the agentId of the currently connected wallet */
export function useMyAgentId() {
  const { address } = useAccount();
  return useAgentIdByOwner(address);
}

/** Get full agent profile for the connected wallet */
export function useMyAgent() {
  const { data: agentId } = useMyAgentId();
  const hasAgent = agentId !== undefined && agentId > 0n;
  const result = useAgent(hasAgent ? Number(agentId) : undefined);
  return { ...result, hasAgent };
}

/** Total registered agents */
export function useTotalAgents() {
  return useReadContract({
    address: CONTRACTS.AgentRegistry,
    abi: AGENT_REGISTRY_ABI,
    functionName: "totalAgents",
  });
}

// ── Writes ───────────────────────────────────────────────────

/** Register a new agent. Returns write function + tx state. */
export function useRegisterAgent() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const register = (metadataURI: string, category: number) => {
    writeContract({
      address: CONTRACTS.AgentRegistry,
      abi: AGENT_REGISTRY_ABI,
      functionName: "registerAgent",
      args: [metadataURI, category],
    });
  };

  return { register, hash, isPending, isConfirming, isSuccess, error };
}

/** Update agent metadata URI */
export function useUpdateAgentMetadata() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const update = (agentId: number, metadataURI: string) => {
    writeContract({
      address: CONTRACTS.AgentRegistry,
      abi: AGENT_REGISTRY_ABI,
      functionName: "updateMetadata",
      args: [BigInt(agentId), metadataURI],
    });
  };

  return { update, hash, isPending, isConfirming, isSuccess, error };
}

/** Set agent status (active/inactive) */
export function useSetAgentStatus() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const setStatus = (agentId: number, status: number) => {
    writeContract({
      address: CONTRACTS.AgentRegistry,
      abi: AGENT_REGISTRY_ABI,
      functionName: "setStatus",
      args: [BigInt(agentId), status],
    });
  };

  return { setStatus, hash, isPending, isConfirming, isSuccess, error };
}
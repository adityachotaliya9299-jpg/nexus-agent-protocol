import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseEther } from "viem";
import { CONTRACTS, AGENT_DAO_ABI } from "@/lib/contracts";

export const PROPOSAL_STATUS_LABELS = ["PENDING", "ACCEPTED", "REJECTED", "EXECUTED"] as const;

// reads
export function useDAO(daoId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentDAO,
    abi: AGENT_DAO_ABI,
    functionName: "getDAO",
    args: daoId ? [daoId] : undefined,
    query: { enabled: !!daoId },
  });
}

export function useDAOMembers(daoId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentDAO,
    abi: AGENT_DAO_ABI,
    functionName: "getDAOMembers",
    args: daoId ? [daoId] : undefined,
    query: { enabled: !!daoId },
  });
}

export function useDAOMember(daoId: `0x${string}` | undefined, agentId: number | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentDAO,
    abi: AGENT_DAO_ABI,
    functionName: "getMember",
    args: daoId && agentId !== undefined ? [daoId, BigInt(agentId)] : undefined,
    query: { enabled: !!daoId && agentId !== undefined },
  });
}

export function useDAOProposal(proposalId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentDAO,
    abi: AGENT_DAO_ABI,
    functionName: "getProposal",
    args: proposalId ? [proposalId] : undefined,
    query: { enabled: !!proposalId },
  });
}

export function useTotalDAOs() {
  return useReadContract({ address: CONTRACTS.AgentDAO, abi: AGENT_DAO_ABI, functionName: "totalDAOs" });
}

// writes
export function useCreateDAO() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createDAO = (name: string, memberAgentIds: number[], splitBps: number[]) => {
    writeContract({
      address: CONTRACTS.AgentDAO,
      abi: AGENT_DAO_ABI,
      functionName: "createDAO",
      args: [name, memberAgentIds.map(BigInt), splitBps.map(BigInt)],
    });
  };

  return { createDAO, hash, isPending, isConfirming, isSuccess, error };
}

export function useProposeDAOTask() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const proposeTask = (daoId: `0x${string}`, taskId: `0x${string}`, proposerAgentId: number) => {
    writeContract({
      address: CONTRACTS.AgentDAO,
      abi: AGENT_DAO_ABI,
      functionName: "proposeTask",
      args: [daoId, taskId, BigInt(proposerAgentId)],
    });
  };

  return { proposeTask, hash, isPending, isConfirming, isSuccess, error };
}

export function useVoteOnDAOProposal() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const vote = (proposalId: `0x${string}`, agentId: number, support: boolean) => {
    writeContract({
      address: CONTRACTS.AgentDAO,
      abi: AGENT_DAO_ABI,
      functionName: "vote",
      args: [proposalId, BigInt(agentId), support],
    });
  };

  return { vote, hash, isPending, isConfirming, isSuccess, error };
}

export function useExecuteDAOProposal() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const executeProposal = (proposalId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.AgentDAO,
      abi: AGENT_DAO_ABI,
      functionName: "executeProposal",
      args: [proposalId],
    });
  };

  return { executeProposal, hash, isPending, isConfirming, isSuccess, error };
}

export function useDistributeRevenue() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const distributeRevenue = (daoId: `0x${string}`, taskId: `0x${string}`, amountEth: string) => {
    writeContract({
      address: CONTRACTS.AgentDAO,
      abi: AGENT_DAO_ABI,
      functionName: "distributeRevenue",
      args: [daoId, taskId],
      value: parseEther(amountEth),
    });
  };

  return { distributeRevenue, hash, isPending, isConfirming, isSuccess, error };
}

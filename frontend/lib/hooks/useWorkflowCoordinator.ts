import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseEther } from "viem";
import { CONTRACTS, AGENT_COORDINATOR_ABI } from "@/lib/contracts";

export const WORKFLOW_TYPE_LABELS = ["PIPELINE", "PARALLEL"] as const;
export const WORKFLOW_STATUS_LABELS = ["ACTIVE", "COMPLETED", "FAILED", "CANCELLED"] as const;
export const STAGE_STATUS_LABELS = ["PENDING", "ACTIVE", "COMPLETED", "FAILED", "SKIPPED"] as const;

// reads
export function useWorkflow(workflowId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentCoordinator,
    abi: AGENT_COORDINATOR_ABI,
    functionName: "getWorkflow",
    args: workflowId ? [workflowId] : undefined,
    query: { enabled: !!workflowId },
  });
}

export function useStage(workflowId: `0x${string}` | undefined, stageIndex: number | undefined) {
  return useReadContract({
    address: CONTRACTS.AgentCoordinator,
    abi: AGENT_COORDINATOR_ABI,
    functionName: "getStage",
    args: workflowId && stageIndex !== undefined ? [workflowId, BigInt(stageIndex)] : undefined,
    query: { enabled: !!workflowId && stageIndex !== undefined },
  });
}

export function useTotalWorkflows() {
  return useReadContract({ address: CONTRACTS.AgentCoordinator, abi: AGENT_COORDINATOR_ABI, functionName: "totalWorkflows" });
}

export function useTotalNetworks() {
  return useReadContract({ address: CONTRACTS.AgentCoordinator, abi: AGENT_COORDINATOR_ABI, functionName: "totalNetworks" });
}

// writes
export interface PipelineStageInput {
  agentId: number;
  budgetEth: string;
  deadline: number;
  inputURI: string;
}

export function useCreatePipeline() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createPipeline = (parentTaskId: `0x${string}`, stages: PipelineStageInput[]) => {
    const totalEth = stages.reduce((sum, s) => sum + parseEther(s.budgetEth || "0"), BigInt(0));
    writeContract({
      address: CONTRACTS.AgentCoordinator,
      abi: AGENT_COORDINATOR_ABI,
      functionName: "createPipeline",
      args: [
        parentTaskId,
        stages.map((s) => BigInt(s.agentId)),
        stages.map((s) => parseEther(s.budgetEth || "0")),
        stages.map((s) => BigInt(s.deadline)),
        stages.map((s) => s.inputURI),
      ],
      value: totalEth,
    });
  };

  return { createPipeline, hash, isPending, isConfirming, isSuccess, error };
}

export interface ParallelInput {
  agentIds: number[];
  budgetsEth: string[];
  deadlines: number[];
  aggregatorAgentId: number;
  aggregatorBudgetEth: string;
}

export function useCreateParallel() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createParallel = (parentTaskId: `0x${string}`, input: ParallelInput) => {
    const total =
      input.budgetsEth.reduce((sum, b) => sum + parseEther(b || "0"), BigInt(0)) +
      parseEther(input.aggregatorBudgetEth || "0");
    writeContract({
      address: CONTRACTS.AgentCoordinator,
      abi: AGENT_COORDINATOR_ABI,
      functionName: "createParallel",
      args: [
        parentTaskId,
        input.agentIds.map(BigInt),
        input.budgetsEth.map((b) => parseEther(b || "0")),
        input.deadlines.map(BigInt),
        BigInt(input.aggregatorAgentId),
        parseEther(input.aggregatorBudgetEth || "0"),
      ],
      value: total,
    });
  };

  return { createParallel, hash, isPending, isConfirming, isSuccess, error };
}

export function useSubmitStageResult() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const submitStageResult = (workflowId: `0x${string}`, stageIndex: number, outputURI: string) => {
    writeContract({
      address: CONTRACTS.AgentCoordinator,
      abi: AGENT_COORDINATOR_ABI,
      functionName: "submitStageResult",
      args: [workflowId, BigInt(stageIndex), outputURI],
    });
  };

  return { submitStageResult, hash, isPending, isConfirming, isSuccess, error };
}

export function useCancelWorkflow() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const cancelWorkflow = (workflowId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.AgentCoordinator,
      abi: AGENT_COORDINATOR_ABI,
      functionName: "cancelWorkflow",
      args: [workflowId],
    });
  };

  return { cancelWorkflow, hash, isPending, isConfirming, isSuccess, error };
}

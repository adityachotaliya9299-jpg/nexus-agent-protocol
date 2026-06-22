import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { CONTRACTS, SUBSCRIPTION_MANAGER_ABI } from "@/lib/contracts";

// ── Reads ────────────────────────────────────────────────────

/** Get a subscription plan by planId */
export function useSubscriptionPlan(planId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.SubscriptionManager,
    abi: SUBSCRIPTION_MANAGER_ABI,
    functionName: "getPlan",
    args: planId ? [planId] : undefined,
    query: { enabled: !!planId },
  });
}

/** Get a user's subscription status for a plan */
export function useSubscription(planId: `0x${string}` | undefined, subscriber: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.SubscriptionManager,
    abi: SUBSCRIPTION_MANAGER_ABI,
    functionName: "getSubscription",
    args: planId && subscriber ? [planId, subscriber] : undefined,
    query: { enabled: !!planId && !!subscriber },
  });
}

/** Total plans ever created */
export function useTotalPlans() {
  return useReadContract({
    address: CONTRACTS.SubscriptionManager,
    abi: SUBSCRIPTION_MANAGER_ABI,
    functionName: "totalPlans",
  });
}

// ── Writes ───────────────────────────────────────────────────

/** Create a new subscription plan (called by agent owner) */
export function useCreatePlan() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createPlan = (agentId: number, tier: number, priceWei: bigint, periodSeconds: number, maxSubs: number) => {
    writeContract({
      address: CONTRACTS.SubscriptionManager,
      abi: SUBSCRIPTION_MANAGER_ABI,
      functionName: "createPlan",
      args: [BigInt(agentId), tier, priceWei, BigInt(periodSeconds), BigInt(maxSubs)],
    });
  };

  return { createPlan, hash, isPending, isConfirming, isSuccess, error };
}

/** Subscribe to a plan, sending ETH for first period */
export function useSubscribe() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const subscribe = (planId: `0x${string}`, priceWei: bigint) => {
    writeContract({
      address: CONTRACTS.SubscriptionManager,
      abi: SUBSCRIPTION_MANAGER_ABI,
      functionName: "subscribe",
      args: [planId],
      value: priceWei,
    });
  };

  return { subscribe, hash, isPending, isConfirming, isSuccess, error };
}

/** Cancel an active subscription */
export function useCancelSubscription() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const cancelSubscription = (planId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.SubscriptionManager,
      abi: SUBSCRIPTION_MANAGER_ABI,
      functionName: "cancelSubscription",
      args: [planId],
    });
  };

  return { cancelSubscription, hash, isPending, isConfirming, isSuccess, error };
}

/** Pause an active subscription */
export function usePauseSubscription() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const pauseSubscription = (planId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.SubscriptionManager,
      abi: SUBSCRIPTION_MANAGER_ABI,
      functionName: "pauseSubscription",
      args: [planId],
    });
  };

  return { pauseSubscription, hash, isPending, isConfirming, isSuccess, error };
}

/** Resume a paused subscription, paying the next period */
export function useResumeSubscription() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const resumeSubscription = (planId: `0x${string}`, priceWei: bigint) => {
    writeContract({
      address: CONTRACTS.SubscriptionManager,
      abi: SUBSCRIPTION_MANAGER_ABI,
      functionName: "resumeSubscription",
      args: [planId],
      value: priceWei,
    });
  };

  return { resumeSubscription, hash, isPending, isConfirming, isSuccess, error };
}
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { CONTRACTS, SUBSCRIPTION_MANAGER_ABI } from "@/lib/contracts";

// reads

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

/** Get a subscription by its id */
export function useSubscription(subscriptionId: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.SubscriptionManager,
    abi: SUBSCRIPTION_MANAGER_ABI,
    functionName: "getSubscription",
    args: subscriptionId ? [subscriptionId] : undefined,
    query: { enabled: !!subscriptionId },
  });
}

/** All subscription ids held by a wallet */
export function useSubscriberSubscriptions(subscriber: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.SubscriptionManager,
    abi: SUBSCRIPTION_MANAGER_ABI,
    functionName: "getSubscriberSubscriptions",
    args: subscriber ? [subscriber] : undefined,
    query: { enabled: !!subscriber },
  });
}

/** Total subscriptions ever created */
export function useTotalSubscriptions() {
  return useReadContract({
    address: CONTRACTS.SubscriptionManager,
    abi: SUBSCRIPTION_MANAGER_ABI,
    functionName: "totalSubscriptionsCreated",
  });
}

// writes

/** Create a new subscription plan (called by agent owner) */
export function useCreatePlan() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createPlan = (
    agentId: number,
    tier: number,
    metadataURI: string,
    priceWei: bigint,
    periodSeconds: number,
    maxSubs: number,
  ) => {
    writeContract({
      address: CONTRACTS.SubscriptionManager,
      abi: SUBSCRIPTION_MANAGER_ABI,
      functionName: "createPlan",
      args: [BigInt(agentId), tier, metadataURI, priceWei, BigInt(periodSeconds), BigInt(maxSubs)],
    });
  };

  return { createPlan, hash, isPending, isConfirming, isSuccess, error };
}

/** Subscribe to a plan, sending ETH for the first period.
 *  subscriberAgentId is 0 when the subscriber is a human wallet. */
export function useSubscribe() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const subscribe = (planId: `0x${string}`, priceWei: bigint, subscriberAgentId = 0) => {
    writeContract({
      address: CONTRACTS.SubscriptionManager,
      abi: SUBSCRIPTION_MANAGER_ABI,
      functionName: "subscribe",
      args: [planId, BigInt(subscriberAgentId)],
      value: priceWei,
    });
  };

  return { subscribe, hash, isPending, isConfirming, isSuccess, error };
}

/** Cancel an active subscription */
export function useCancelSubscription() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const cancelSubscription = (subscriptionId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.SubscriptionManager,
      abi: SUBSCRIPTION_MANAGER_ABI,
      functionName: "cancelSubscription",
      args: [subscriptionId],
    });
  };

  return { cancelSubscription, hash, isPending, isConfirming, isSuccess, error };
}

/** Pause an active subscription */
export function usePauseSubscription() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const pauseSubscription = (subscriptionId: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.SubscriptionManager,
      abi: SUBSCRIPTION_MANAGER_ABI,
      functionName: "pauseSubscription",
      args: [subscriptionId],
    });
  };

  return { pauseSubscription, hash, isPending, isConfirming, isSuccess, error };
}

/** Resume a paused subscription, paying the next period */
export function useResumeSubscription() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const resumeSubscription = (subscriptionId: `0x${string}`, priceWei: bigint) => {
    writeContract({
      address: CONTRACTS.SubscriptionManager,
      abi: SUBSCRIPTION_MANAGER_ABI,
      functionName: "resumeSubscription",
      args: [subscriptionId],
      value: priceWei,
    });
  };

  return { resumeSubscription, hash, isPending, isConfirming, isSuccess, error };
}

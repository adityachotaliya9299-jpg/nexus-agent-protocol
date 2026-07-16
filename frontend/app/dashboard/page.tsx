"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { Bot } from "lucide-react";
import { DashboardHeader } from "@/components/dashboard/DashboardHeader";
import { DashboardTabs } from "@/components/dashboard/DashboardTabs";
import { EarningsPanel } from "@/components/dashboard/EarningsPanel";
import { ActiveTasksPanel } from "@/components/dashboard/ActiveTasksPanel";
import { ReputationHistory } from "@/components/dashboard/ReputationHistory";
import { MemoryPanel } from "@/components/dashboard/MemoryPanel";
import { SubscriptionsPanel } from "@/components/dashboard/SubscriptionsPanel";
import { RegisterAgentModal } from "@/components/dashboard/RegisterAgentModal";
import { useMyAgentId, useAgent } from "@/lib/hooks/useAgentRegistry";

type Tab = "overview" | "tasks" | "reputation" | "memory" | "subscriptions";

export default function DashboardPage() {
  const [activeTab, setActiveTab] = useState<Tab>("overview");
  const [showRegister, setShowRegister] = useState(false);

  const { address, isConnected } = useAccount();
  const { data: myAgentId, isLoading: idLoading } = useMyAgentId();
  const agentId = myAgentId ? Number(myAgentId) : 0;
  const { data: agentData, isLoading: agentLoading } = useAgent(agentId > 0 ? agentId : undefined);

  const hasAgent = agentId > 0 && !!agentData;
  const loading = isConnected && (idLoading || (agentId > 0 && agentLoading));

  const agent = hasAgent
    ? {
        agentId,
        name: `Agent #${agentId}`,
        owner: (agentData as any).owner,
        agentWallet: (agentData as any).agentWallet,
        category: Number((agentData as any).category),
        status: Number((agentData as any).status),
        reputationScore: Number((agentData as any).reputationScore),
        totalTasksCompleted: Number((agentData as any).totalTasksCompleted),
        totalEarned: (agentData as any).totalEarned,
        registeredAt: Number((agentData as any).registeredAt),
        lastActiveAt: Number((agentData as any).lastActiveAt),
      }
    : null;

  if (!isConnected || loading || !agent) {
    return (
      <div className="min-h-screen relative">
        <div className="fixed inset-0 grid-bg opacity-100 pointer-events-none" />
        <div className="relative max-w-5xl mx-auto px-6 py-24 flex flex-col items-center justify-center text-center gap-8">
          <div className="w-16 h-16 rounded-2xl bg-surface border border-border flex items-center justify-center">
            <Bot size={26} className="text-gold" />
          </div>

          {loading ? (
            <div>
              <h1 className="font-display text-3xl font-bold text-bone mb-3">Loading your agent…</h1>
              <div className="w-48 h-2 rounded-full bg-border overflow-hidden mx-auto">
                <div className="h-full w-1/2 bg-gold animate-pulse rounded-full" />
              </div>
            </div>
          ) : (
            <>
              <div>
                <h1 className="font-display text-3xl font-bold text-bone mb-3">
                  {isConnected ? "No agent registered" : "Connect your wallet"}
                </h1>
                <p className="text-text-secondary text-base max-w-md">
                  {isConnected
                    ? "Register an on-chain agent identity to start bidding on tasks, building reputation, and earning revenue autonomously."
                    : "Connect a wallet to manage your agent, track earnings, and stake ETH."}
                </p>
              </div>
              {isConnected && (
                <button onClick={() => setShowRegister(true)} className="btn-primary text-base px-8 py-3">
                  Register agent
                </button>
              )}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 w-full max-w-lg mt-4">
                {["Agent identity", "Smart wallet", "On-chain reputation"].map(item => (
                  <div key={item} className="card p-4 text-center">
                    <p className="text-bone text-sm font-medium">{item}</p>
                    <p className="text-text-secondary text-xs mt-1">Included</p>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
        {showRegister && <RegisterAgentModal onClose={() => setShowRegister(false)} />}
      </div>
    );
  }

  return (
    <div className="min-h-screen relative">
      <div className="fixed inset-0 grid-bg opacity-100 pointer-events-none" />

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 py-8 md:py-10 space-y-6 md:space-y-8">
        <DashboardHeader agent={agent} />
        <DashboardTabs activeTab={activeTab} onChange={t => setActiveTab(t as Tab)} />

        <div>
          {activeTab === "overview" && (
            <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
              <div className="xl:col-span-2 space-y-6">
                <EarningsPanel />
                <ActiveTasksPanel view="overview" />
              </div>
              <div className="space-y-6">
                <ReputationHistory compact />
                <MemoryPanel compact />
              </div>
            </div>
          )}

          {activeTab === "tasks" && <ActiveTasksPanel view="full" />}
          {activeTab === "reputation" && <ReputationHistory />}
          {activeTab === "memory" && <MemoryPanel />}
          {activeTab === "subscriptions" && <SubscriptionsPanel />}
        </div>
      </div>

      {showRegister && <RegisterAgentModal onClose={() => setShowRegister(false)} />}
    </div>
  );
}

"use client";

import { useState } from "react";
import { DashboardHeader } from "@/components/dashboard/DashboardHeader";
import { DashboardTabs } from "@/components/dashboard/DashboardTabs";
import { EarningsPanel } from "@/components/dashboard/EarningsPanel";
import { ActiveTasksPanel } from "@/components/dashboard/ActiveTasksPanel";
import { ReputationHistory } from "@/components/dashboard/ReputationHistory";
import { MemoryPanel } from "@/components/dashboard/MemoryPanel";
import { SubscriptionsPanel } from "@/components/dashboard/SubscriptionsPanel";
import { RegisterAgentModal } from "@/components/dashboard/RegisterAgentModal";
import { MOCK_AGENTS, MOCK_TASKS } from "@/lib/contracts";

const CONNECTED_AGENT = MOCK_AGENTS[0] as any;// simulate connected wallet owns agent[0]

type Tab = "overview" | "tasks" | "reputation" | "memory" | "subscriptions";

export default function DashboardPage() {
  const [activeTab, setActiveTab] = useState<Tab>("overview");
  const [showRegister, setShowRegister] = useState(false);

  // Simulate no agent registered yet — toggle this to false to test the "no agent" state
  const hasAgent = true;

  if (!hasAgent) {
    return (
      <div className="min-h-screen relative">
        <div className="fixed inset-0 grid-bg opacity-100 pointer-events-none" />
        <div className="relative max-w-5xl mx-auto px-6 py-24 flex flex-col items-center justify-center text-center gap-8">
          <div className="w-16 h-16 rounded-full bg-[#0D1120] border border-[#1A2035] flex items-center justify-center">
            <span className="text-2xl">🤖</span>
          </div>
          <div>
            <h1 className="font-display text-3xl font-bold text-[#F0F4FF] mb-3">
              No Agent Registered
            </h1>
            <p className="text-[#8892B0] text-base max-w-md">
              Register an on-chain agent identity to start posting tasks, building reputation, and earning revenue autonomously.
            </p>
          </div>
          <button
            onClick={() => setShowRegister(true)}
            className="btn-primary text-base px-8 py-3"
          >
            Register Agent
          </button>
          <div className="grid grid-cols-3 gap-4 w-full max-w-lg mt-4">
            {["Agent Identity", "Smart Wallet", "On-Chain Reputation"].map((item) => (
              <div key={item} className="card p-4 text-center">
                <p className="text-[#F0F4FF] text-sm font-medium">{item}</p>
                <p className="text-[#8892B0] text-xs mt-1">Included</p>
              </div>
            ))}
          </div>
        </div>
        {showRegister && <RegisterAgentModal onClose={() => setShowRegister(false)} />}
      </div>
    );
  }

  return (
    <div className="min-h-screen relative">
      <div className="fixed inset-0 grid-bg opacity-100 pointer-events-none" />

      <div className="relative max-w-7xl mx-auto px-6 py-10 space-y-8">
        {/* Header — agent identity card */}
        <DashboardHeader agent={CONNECTED_AGENT} />

        {/* Tab navigation */}
        <DashboardTabs activeTab={activeTab} onChange={(t) => setActiveTab(t as Tab)} />

        {/* Tab content */}
        <div>
          {activeTab === "overview" && (
            <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
              <div className="xl:col-span-2 space-y-6">
                <EarningsPanel />
                <ActiveTasksPanel tasks={MOCK_TASKS.slice(0, 4)} view="overview" />
              </div>
              <div className="space-y-6">
                <ReputationHistory compact />
                <MemoryPanel compact />
              </div>
            </div>
          )}

          {activeTab === "tasks" && (
            <ActiveTasksPanel tasks={MOCK_TASKS} view="full" />
          )}

          {activeTab === "reputation" && (
            <ReputationHistory />
          )}

          {activeTab === "memory" && (
            <MemoryPanel />
          )}

          {activeTab === "subscriptions" && (
            <SubscriptionsPanel />
          )}
        </div>
      </div>

      {showRegister && <RegisterAgentModal onClose={() => setShowRegister(false)} />}
    </div>
  );
}
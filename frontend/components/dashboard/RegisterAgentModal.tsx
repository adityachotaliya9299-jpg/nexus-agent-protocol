"use client";

import { useState, useEffect } from "react";
import { useRegisterAgent } from "@/lib/hooks/useAgentRegistry";
import { useDeployWallet } from "@/lib/hooks/useAgentWallet";
import { TxButton } from "@/components/wallet/TxButton";

const CATEGORIES = [
  { label: "Code / Development", value: 1 },
  { label: "Research / Analysis", value: 2 },
  { label: "Trading / DeFi", value: 3 },
  { label: "Creative / Content", value: 4 },
  { label: "Orchestration", value: 5 },
  { label: "General", value: 0 },
];

const CAPABILITIES = [
  "Solidity", "Foundry", "Hardhat", "Vyper",
  "Rust / Anchor", "ZK Circuits", "Chainlink", "EigenLayer",
  "Account Abstraction", "IPFS", "The Graph", "DeFi Protocols",
  "Security Auditing", "Gas Optimization", "Cross-chain", "MEV",
];

interface RegisterAgentModalProps {
  onClose: () => void;
  onRegistered?: (agentId: number) => void;
}

type Step = 1 | 2 | 3 | 4;

export function RegisterAgentModal({ onClose, onRegistered }: RegisterAgentModalProps) {
  const [step, setStep] = useState<Step>(1);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState(1);
  const [selected, setSelected] = useState<string[]>([]);

  // Step 2: register agent tx
  const { register, isPending: regPending, isConfirming: regConfirming, isSuccess: regSuccess, error: regError } = useRegisterAgent();

  // Step 3: deploy wallet tx (after registration confirmed)
  const [newAgentId] = useState<number | null>(null);
  const { deployWallet, isPending: walletPending, isConfirming: walletConfirming, isSuccess: walletSuccess } = useDeployWallet();

  // Auto-advance after register tx confirmed
  useEffect(() => {
    if (regSuccess) setStep(3);
  }, [regSuccess]);

  // Auto-advance after wallet deploy confirmed
  useEffect(() => {
    if (walletSuccess) setStep(4);
  }, [walletSuccess]);

  const toggleCap = (cap: string) => {
    setSelected((prev) => prev.includes(cap) ? prev.filter((c) => c !== cap) : [...prev, cap]);
  };

  const handleRegister = () => {
    // Build metadata URI — in production this would be uploaded to IPFS first
    // For now we inline a JSON-encoded URI; Phase 8C will swap to real IPFS upload
    const metadata = JSON.stringify({ name, description, capabilities: selected });
    const metadataURI = `data:application/json,${encodeURIComponent(metadata)}`;
    register(metadataURI, category);
  };

  const handleDeployWallet = () => {
    if (newAgentId !== null) deployWallet(newAgentId);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={step === 4 ? onClose : undefined} />
      <div className="relative card w-full max-w-lg overflow-hidden">
        {/* Step indicator */}
        <div className="flex border-b border-[#2A241B]">
          {[
            { n: 1, label: "Identity" },
            { n: 2, label: "Capabilities" },
            { n: 3, label: "Deploy Wallet" },
            { n: 4, label: "Live" },
          ].map((s) => (
            <div
              key={s.n}
              className={`flex-1 py-3 text-center text-xs font-mono font-medium transition-colors ${
                step >= s.n ? "text-cyan border-b-2 border-cyan" : "text-[#6B6355]"
              }`}
            >
              {s.n}. {s.label}
            </div>
          ))}
        </div>

        <div className="p-6">
          {/* ── Step 1: Identity ── */}
          {step === 1 && (
            <div className="space-y-4">
              <div>
                <h3 className="font-display font-bold text-[#F4EFE6] text-lg">Agent Identity</h3>
                <p className="text-[#A89F8D] text-sm mt-1">Stored on-chain via AgentRegistry.</p>
              </div>
              <div>
                <label className="label block mb-1.5">Agent Name</label>
                <input className="input" placeholder="e.g. DeFi-Auditor-42" value={name} onChange={(e) => setName(e.target.value)} />
              </div>
              <div>
                <label className="label block mb-1.5">Category</label>
                <select className="input" value={category} onChange={(e) => setCategory(Number(e.target.value))}>
                  {CATEGORIES.map((c) => (
                    <option key={c.value} value={c.value}>{c.label}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="label block mb-1.5">Description</label>
                <textarea className="input resize-none" rows={3} placeholder="Describe your agent's purpose and specialization..." value={description} onChange={(e) => setDescription(e.target.value)} />
              </div>
              <button
                onClick={() => setStep(2)}
                disabled={!name.trim()}
                className={`btn-primary w-full ${!name.trim() ? "opacity-50 cursor-not-allowed" : ""}`}
              >
                Next: Capabilities →
              </button>
            </div>
          )}

          {/* ── Step 2: Capabilities + Register tx ── */}
          {step === 2 && (
            <div className="space-y-4">
              <div>
                <h3 className="font-display font-bold text-[#F4EFE6] text-lg">Capabilities</h3>
                <p className="text-[#A89F8D] text-sm mt-1">Shapes which tasks you can bid on.</p>
              </div>
              <div className="flex flex-wrap gap-2">
                {CAPABILITIES.map((cap) => (
                  <button
                    key={cap}
                    onClick={() => toggleCap(cap)}
                    className={`px-3 py-1.5 rounded-md text-sm font-medium border transition-all duration-150 ${
                      selected.includes(cap)
                        ? "bg-cyan/10 text-cyan border-cyan/30"
                        : "bg-[#0B0A08] text-[#A89F8D] border-[#2A241B] hover:border-[#3A3226]"
                    }`}
                  >
                    {cap}
                  </button>
                ))}
              </div>
              <p className="label">{selected.length} selected</p>

              {/* Gas estimate */}
              <div className="p-3 rounded-lg bg-[#0B0A08] border border-[#2A241B] space-y-1.5">
                <div className="flex justify-between">
                  <span className="label">Estimated gas (register)</span>
                  <span className="font-mono text-xs text-[#F4EFE6]">~0.003 ETH</span>
                </div>
                <div className="flex justify-between">
                  <span className="label">Network</span>
                  <span className="font-mono text-xs text-cyan">Sepolia</span>
                </div>
              </div>

              {regError && (
                <p className="text-red-400 text-xs bg-red-500/10 border border-red-500/20 rounded-md px-3 py-2">
                  {regError.message?.slice(0, 120)}
                </p>
              )}

              <div className="flex gap-3">
                <button onClick={() => setStep(1)} className="btn-secondary flex-1">← Back</button>
                <TxButton
                  onClick={handleRegister}
                  isPending={regPending}
                  isConfirming={regConfirming}
                  isSuccess={regSuccess}
                  disabled={selected.length === 0}
                  className="btn-primary flex-1"
                  pendingText="Sign in wallet..."
                  confirmingText="Registering..."
                  successText="Registered ✓"
                >
                  Register Agent
                </TxButton>
              </div>
            </div>
          )}

          {/* ── Step 3: Deploy ERC-4337 wallet ── */}
          {step === 3 && (
            <div className="space-y-5">
              <div>
                <h3 className="font-display font-bold text-[#F4EFE6] text-lg">Deploy Smart Wallet</h3>
                <p className="text-[#A89F8D] text-sm mt-1">
                  Your agent identity is registered. Now deploy its ERC-4337 smart wallet so it can receive ETH payments.
                </p>
              </div>
              <div className="p-4 rounded-lg bg-emerald-500/5 border border-emerald-500/20 space-y-1">
                <p className="text-emerald-400 text-sm font-medium">✓ AgentRegistry: registered</p>
                {newAgentId && <p className="label">Agent ID: #{newAgentId}</p>}
              </div>
              <div className="p-3 rounded-lg bg-[#0B0A08] border border-[#2A241B] space-y-1.5">
                <div className="flex justify-between">
                  <span className="label">Estimated gas (wallet deploy)</span>
                  <span className="font-mono text-xs text-[#F4EFE6]">~0.004 ETH</span>
                </div>
                <div className="flex justify-between">
                  <span className="label">Wallet type</span>
                  <span className="font-mono text-xs text-[#F4EFE6]">ERC-4337 (CREATE2)</span>
                </div>
              </div>
              <TxButton
                onClick={handleDeployWallet}
                isPending={walletPending}
                isConfirming={walletConfirming}
                isSuccess={walletSuccess}
                className="btn-primary w-full"
                pendingText="Sign in wallet..."
                confirmingText="Deploying wallet..."
                successText="Wallet deployed ✓"
              >
                Deploy Smart Wallet
              </TxButton>
            </div>
          )}

          {/* ── Step 4: Done ── */}
          {step === 4 && (
            <div className="text-center space-y-5 py-4">
              <div className="w-16 h-16 rounded-full bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center mx-auto text-3xl">
                ✓
              </div>
              <div>
                <h3 className="font-display font-bold text-[#F4EFE6] text-xl">Agent Live on Sepolia</h3>
                <p className="text-[#A89F8D] text-sm mt-2">
                  Your agent identity and ERC-4337 wallet are deployed. Initial reputation: 5,000.
                </p>
              </div>
              <div className="card p-4 text-left space-y-2">
                {newAgentId && (
                  <div className="flex justify-between">
                    <span className="label">Agent ID</span>
                    <span className="font-mono text-xs text-[#F4EFE6]">#{newAgentId}</span>
                  </div>
                )}
                <div className="flex justify-between">
                  <span className="label">Reputation Score</span>
                  <span className="font-mono text-xs text-cyan">5,000 (Initial)</span>
                </div>
                <div className="flex justify-between">
                  <span className="label">Network</span>
                  <span className="font-mono text-xs text-[#F4EFE6]">Sepolia</span>
                </div>
              </div>
              <button
                onClick={() => { onRegistered?.(newAgentId ?? 0); onClose(); }}
                className="btn-primary w-full"
              >
                Open Dashboard
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

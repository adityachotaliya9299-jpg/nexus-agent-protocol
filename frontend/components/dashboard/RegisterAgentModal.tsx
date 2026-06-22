"use client";

import { useState } from "react";

const CATEGORIES = [
  "DeFi Protocol",
  "Security Audit",
  "Smart Contract Dev",
  "ZK / Cryptography",
  "Oracle / Data",
  "Infrastructure",
  "NFT / Gaming",
  "Cross-chain",
  "AI / ML",
  "Other",
];

const CAPABILITIES = [
  "Solidity", "Foundry", "Hardhat", "Vyper",
  "Rust / Anchor", "ZK Circuits", "Chainlink", "EigenLayer",
  "Account Abstraction", "IPFS", "The Graph", "DeFi Protocols",
  "Security Auditing", "Gas Optimization", "Cross-chain", "MEV",
];

interface RegisterAgentModalProps {
  onClose: () => void;
}

type Step = 1 | 2 | 3;

export function RegisterAgentModal({ onClose }: RegisterAgentModalProps) {
  const [step, setStep] = useState<Step>(1);
  const [selected, setSelected] = useState<string[]>([]);
  const [submitting, setSubmitting] = useState(false);

  const toggleCap = (cap: string) => {
    setSelected((prev) =>
      prev.includes(cap) ? prev.filter((c) => c !== cap) : [...prev, cap]
    );
  };

  const handleSubmit = async () => {
    setSubmitting(true);
    // Simulate tx delay
    await new Promise((r) => setTimeout(r, 2000));
    setSubmitting(false);
    setStep(3);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        className="absolute inset-0 bg-black/70 backdrop-blur-sm"
        onClick={step === 3 ? onClose : undefined}
      />
      <div className="relative card w-full max-w-lg overflow-hidden">
        {/* Step indicator */}
        <div className="flex border-b border-[#1A2035]">
          {[
            { n: 1, label: "Identity" },
            { n: 2, label: "Capabilities" },
            { n: 3, label: "Deploy" },
          ].map((s) => (
            <div
              key={s.n}
              className={`flex-1 py-3 text-center text-xs font-mono font-medium transition-colors ${
                step >= s.n ? "text-cyan border-b-2 border-cyan" : "text-[#4A5568]"
              }`}
            >
              {s.n}. {s.label}
            </div>
          ))}
        </div>

        <div className="p-6">
          {step === 1 && (
            <div className="space-y-4">
              <div>
                <h3 className="font-display font-bold text-[#F0F4FF] text-lg">
                  Agent Identity
                </h3>
                <p className="text-[#8892B0] text-sm mt-1">
                  This will be stored on-chain via AgentRegistry.
                </p>
              </div>

              <div>
                <label className="label block mb-1.5">Agent Name</label>
                <input className="input" placeholder="e.g. DeFi-Auditor-42" />
              </div>

              <div>
                <label className="label block mb-1.5">Category</label>
                <select className="input">
                  <option value="">Select category...</option>
                  {CATEGORIES.map((c) => (
                    <option key={c} value={c}>{c}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="label block mb-1.5">Description</label>
                <textarea
                  className="input resize-none"
                  rows={3}
                  placeholder="Describe your agent's purpose and specialization..."
                />
              </div>

              <div>
                <label className="label block mb-1.5">Metadata IPFS CID (optional)</label>
                <input className="input" placeholder="Qm... — leave blank to skip for now" />
              </div>

              <button
                onClick={() => setStep(2)}
                className="btn-primary w-full"
              >
                Next: Capabilities →
              </button>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-4">
              <div>
                <h3 className="font-display font-bold text-[#F0F4FF] text-lg">
                  Capabilities
                </h3>
                <p className="text-[#8892B0] text-sm mt-1">
                  Select what your agent can do. This shapes which tasks you can bid on.
                </p>
              </div>

              <div className="flex flex-wrap gap-2">
                {CAPABILITIES.map((cap) => (
                  <button
                    key={cap}
                    onClick={() => toggleCap(cap)}
                    className={`px-3 py-1.5 rounded-md text-sm font-medium border transition-all duration-150 ${
                      selected.includes(cap)
                        ? "bg-cyan/10 text-cyan border-cyan/30"
                        : "bg-[#080B12] text-[#8892B0] border-[#1A2035] hover:border-[#2A3555]"
                    }`}
                  >
                    {cap}
                  </button>
                ))}
              </div>

              <div className="pt-1">
                <span className="label">{selected.length} selected</span>
              </div>

              <div className="flex gap-3 pt-2">
                <button onClick={() => setStep(1)} className="btn-secondary flex-1">
                  ← Back
                </button>
                <button
                  onClick={handleSubmit}
                  disabled={submitting || selected.length === 0}
                  className={`btn-primary flex-1 ${
                    submitting || selected.length === 0
                      ? "opacity-50 cursor-not-allowed"
                      : ""
                  }`}
                >
                  {submitting ? "Deploying..." : "Register Agent →"}
                </button>
              </div>

              {/* Gas estimate */}
              <div className="p-3 rounded-lg bg-[#080B12] border border-[#1A2035]">
                <div className="flex justify-between">
                  <span className="label">Estimated Gas</span>
                  <span className="font-mono text-xs text-[#F0F4FF]">~0.003 ETH</span>
                </div>
                <div className="flex justify-between mt-1">
                  <span className="label">Wallet Deployment</span>
                  <span className="font-mono text-xs text-[#F0F4FF]">~0.004 ETH</span>
                </div>
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="text-center space-y-5 py-4">
              <div className="w-16 h-16 rounded-full bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center mx-auto text-3xl">
                ✓
              </div>
              <div>
                <h3 className="font-display font-bold text-[#F0F4FF] text-xl">
                  Agent Registered
                </h3>
                <p className="text-[#8892B0] text-sm mt-2">
                  Your agent identity is live on-chain. The ERC-4337 smart wallet has been deployed and linked.
                </p>
              </div>
              <div className="card p-4 text-left space-y-2">
                <div className="flex justify-between">
                  <span className="label">Agent ID</span>
                  <span className="font-mono text-xs text-[#F0F4FF]">#42</span>
                </div>
                <div className="flex justify-between">
                  <span className="label">Reputation Score</span>
                  <span className="font-mono text-xs text-cyan">5000 (Initial)</span>
                </div>
                <div className="flex justify-between">
                  <span className="label">Status</span>
                  <span className="badge-active badge text-[10px]">Active</span>
                </div>
              </div>
              <button onClick={onClose} className="btn-primary w-full">
                Open Dashboard
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
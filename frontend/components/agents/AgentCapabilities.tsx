import { Shield, Code, Database, Globe, Cpu, Star } from "lucide-react";
import { type Agent } from "@/lib/contracts";

const CAP_ICONS: Record<string, React.ComponentType<{ className?: string }>> = {
  "solidity-audit":        Shield,
  "gas-optimization":      Cpu,
  "erc-4337":              Code,
  "test-writing":          Code,
  "defi-security":         Shield,
  "yield-farming":         Star,
  "arbitrage":             Globe,
  "portfolio-mgmt":        Database,
  "cross-chain":           Globe,
  "risk-analysis":         Shield,
  "market-research":       Database,
  "data-analysis":         Database,
  "protocol-review":       Shield,
  "report-writing":        Code,
  "on-chain-analytics":    Database,
  "task-decomposition":    Cpu,
  "agent-hiring":          Globe,
  "pipeline-mgmt":         Cpu,
  "quality-control":       Shield,
  "multi-agent-coordination": Globe,
  "copywriting":           Code,
  "whitepaper":            Code,
  "documentation":         Code,
  "ui-content":            Star,
  "social-media":          Globe,
  "nextjs":                Code,
  "react":                 Code,
  "typescript":            Code,
  "web3-ui":               Globe,
  "wagmi":                 Code,
  "tailwind":              Star,
};

export function AgentCapabilities({ agent }: { agent: Agent }) {
  if (!agent.capabilities?.length) return null;

  return (
    <div className="card p-6">
      <h3 className="font-display font-semibold text-[#F0F4FF] mb-1">Capabilities</h3>
      <p className="text-xs text-[#8892B0] mb-5">
        Verified skills and expertise areas for this agent
      </p>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
        {agent.capabilities.map((cap) => {
          const Icon = CAP_ICONS[cap] ?? Code;
          return (
            <div
              key={cap}
              className="flex items-center gap-3 px-4 py-3 rounded-lg bg-[#0D1120] border border-[#1A2035] hover:border-cyan/20 transition-colors group"
            >
              <div className="w-8 h-8 rounded-md bg-cyan/5 border border-cyan/10 flex items-center justify-center group-hover:bg-cyan/10 transition-colors">
                <Icon className="w-4 h-4 text-cyan" />
              </div>
              <div>
                <div className="font-mono text-sm text-[#F0F4FF]">{cap}</div>
                <div className="font-mono text-[10px] text-[#4A5568]">verified capability</div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
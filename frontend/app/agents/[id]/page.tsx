import { notFound } from "next/navigation";
import { MOCK_AGENTS } from "@/lib/contracts";
import { AgentProfileHeader } from "@/components/agents/AgentProfileHeader";
import { AgentStats }         from "@/components/agents/AgentStats";
import { AgentCapabilities }  from "@/components/agents/AgentCapabilities";
import { AgentTaskHistory }   from "@/components/agents/AgentTaskHistory";
import { AgentReputationChart } from "@/components/agents/AgentReputationChart";
import { AgentHirePanel }     from "@/components/agents/AgentHirePanel";

export function generateStaticParams() {
  return MOCK_AGENTS.map((a) => ({ id: String(a.agentId) }));
}

export function generateMetadata({ params }: { params: { id: string } }) {
  const agent = MOCK_AGENTS.find((a) => a.agentId === Number(params.id));
  if (!agent) return { title: "Agent Not Found" };
  return {
    title: `${agent.name} — Nexus Agent Protocol`,
    description: agent.description,
  };
}

export default function AgentProfilePage({ params }: { params: { id: string } }) {
  const agent = MOCK_AGENTS.find((a) => a.agentId === Number(params.id));
  if (!agent) notFound();

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">

      {/* Breadcrumb */}
      <div className="flex items-center gap-2 mb-8 font-mono text-xs text-[#8892B0]">
        <a href="/agents" className="hover:text-cyan transition-colors">Agents</a>
        <span className="text-[#4A5568]">/</span>
        <span className="text-cyan">#{agent.agentId} {agent.name}</span>
      </div>

      {/* Two-column layout */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">

        {/* Left: main content */}
        <div className="lg:col-span-2 space-y-6">
          <AgentProfileHeader agent={agent} />
          <AgentStats agent={agent} />
          <AgentReputationChart agent={agent} />
          <AgentCapabilities agent={agent} />
          <AgentTaskHistory agent={agent} />
        </div>

        {/* Right: hire panel */}
        <div className="lg:col-span-1">
          <div className="sticky top-24">
            <AgentHirePanel agent={agent} />
          </div>
        </div>
      </div>
    </div>
  );
}
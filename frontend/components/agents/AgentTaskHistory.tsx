import { CheckCircle, Clock, AlertCircle, ExternalLink } from "lucide-react";
import { type Agent } from "@/lib/contracts";
import { shortAddress, formatEth } from "@/lib/utils";

// Mock task history for the agent profile
const MOCK_HISTORY = [
  { taskId: "0xabc1", title: "Audit Uniswap V4 Hook", status: 2, reward: BigInt("800000000000000000"), completedAt: Date.now() / 1000 - 3600, client: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e" },
  { taskId: "0xabc2", title: "ERC-4337 Paymaster Implementation", status: 2, reward: BigInt("1200000000000000000"), completedAt: Date.now() / 1000 - 86400, client: "0x8ba1f109551bD432803012645Ac136ddd64DBA72" },
  { taskId: "0xabc3", title: "Gas Optimization for NFT Contract", status: 2, reward: BigInt("500000000000000000"), completedAt: Date.now() / 1000 - 172800, client: "0x9D7f74d0C41E726EC95884E0e97Fa6129e3b5E99" },
  { taskId: "0xabc4", title: "DeFi Protocol Security Review", status: 2, reward: BigInt("2000000000000000000"), completedAt: Date.now() / 1000 - 259200, client: "0x6B175474E89094C44Da98b954EedeAC495271d0F" },
  { taskId: "0xabc5", title: "Cross-chain Bridge Audit", status: 1, reward: BigInt("3500000000000000000"), completedAt: Date.now() / 1000 - 432000, client: "0xdD2FD4581271e230360230F9337D5c0430Bf44C0" },
];

const STATUS_MAP: Record<number, { label: string; icon: React.ComponentType<{ className?: string }>; color: string }> = {
  1: { label: "In Progress", icon: Clock,        color: "text-amber" },
  2: { label: "Completed",   icon: CheckCircle,  color: "text-emerald" },
  3: { label: "Disputed",    icon: AlertCircle,  color: "text-rose" },
};

function timeAgoShort(ts: number): string {
  const diff = Date.now() / 1000 - ts;
  if (diff < 3600)    return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400)   return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

export function AgentTaskHistory({ agent }: { agent: Agent }) {
  return (
    <div className="card p-6">
      <div className="flex items-center justify-between mb-5">
        <div>
          <h3 className="font-display font-semibold text-[#F4EFE6] mb-0.5">Task History</h3>
          <p className="text-xs text-[#A89F8D]">
            {agent.totalTasksCompleted} tasks completed lifetime
          </p>
        </div>
        <a href="/tasks" className="btn-ghost text-xs">
          View all <ExternalLink className="w-3.5 h-3.5" />
        </a>
      </div>

      <div className="space-y-2">
        {MOCK_HISTORY.map((task) => {
          const st = STATUS_MAP[task.status] ?? STATUS_MAP[2];
          const Icon = st.icon;
          return (
            <div
              key={task.taskId}
              className="flex items-center gap-4 p-4 rounded-lg bg-[#0B0A08] border border-[#2A241B] hover:border-[#3A3226] transition-colors"
            >
              {/* Status icon */}
              <div className={`shrink-0 ${st.color}`}>
                <Icon className="w-4 h-4" />
              </div>

              {/* Task info */}
              <div className="flex-1 min-w-0">
                <div className="font-display font-medium text-sm text-[#F4EFE6] truncate">
                  {task.title}
                </div>
                <div className="flex items-center gap-3 mt-0.5">
                  <span className="font-mono text-[10px] text-[#6B6355]">
                    Client: {shortAddress(task.client)}
                  </span>
                  <span className="font-mono text-[10px] text-[#6B6355]">
                    {timeAgoShort(task.completedAt)}
                  </span>
                </div>
              </div>

              {/* Reward */}
              <div className="text-right shrink-0">
                <div className="font-mono font-semibold text-sm text-emerald">
                  +{formatEth(task.reward, 2)} ETH
                </div>
                <div className={`font-mono text-[10px] ${st.color}`}>{st.label}</div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Summary footer */}
      <div className="mt-4 pt-4 border-t border-[#2A241B] grid grid-cols-3 gap-4">
        {[
          { label: "Success Rate", value: "98.2%" },
          { label: "Avg Reward",   value: "0.31 ETH" },
          { label: "Disputes",     value: "2" },
        ].map(({ label, value }) => (
          <div key={label} className="text-center">
            <div className="font-mono font-semibold text-sm text-[#F4EFE6]">{value}</div>
            <div className="label text-[9px]">{label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
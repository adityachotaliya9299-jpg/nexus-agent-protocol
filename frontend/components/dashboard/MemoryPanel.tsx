"use client";

import { useState } from "react";

type MemoryType = "TASK_HISTORY" | "CONTEXT" | "SKILLS" | "PREFERENCES" | "KNOWLEDGE" | "STATE";

const MEMORY_COLORS: Record<MemoryType, string> = {
  TASK_HISTORY: "#F2A93B",
  CONTEXT: "#FF6B3D",
  SKILLS: "#57C99B",
  PREFERENCES: "#F2A93B",
  KNOWLEDGE: "#6366F1",
  STATE: "#EC4899",
};

const MEMORY_SNAPSHOTS = [
  {
    version: 5,
    type: "TASK_HISTORY" as MemoryType,
    cid: "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
    size: "2.1 KB",
    timestamp: "2025-04-10T09:33:00Z",
    description: "Task completion log: 5 tasks, avg 4.8 rating",
    accessCount: 12,
  },
  {
    version: 4,
    type: "CONTEXT" as MemoryType,
    cid: "QmZQVmxmezAcuKfF6qrFvXxvUKrFpqCr7kxvJGQNNKGn",
    size: "5.7 KB",
    timestamp: "2025-04-08T14:21:00Z",
    description: "Current task context: Uniswap v4 hook development",
    accessCount: 8,
  },
  {
    version: 3,
    type: "SKILLS" as MemoryType,
    cid: "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB",
    size: "1.3 KB",
    timestamp: "2025-04-05T11:00:00Z",
    description: "Skill registry: Solidity, Foundry, DeFi protocols, zkProofs",
    accessCount: 24,
  },
  {
    version: 2,
    type: "PREFERENCES" as MemoryType,
    cid: "QmQiLbJFYJhkpNNNzGKQFNgHkJsT3Xh95smVBRi1bHJKnE",
    size: "0.8 KB",
    timestamp: "2025-03-28T08:15:00Z",
    description: "Task preferences: min 0.2 ETH, max 7d deadline",
    accessCount: 5,
  },
  {
    version: 1,
    type: "STATE" as MemoryType,
    cid: "QmNLei78zWmzUdbeRB3CiUfAizWUrbeeZh5K1rhAQKCh51",
    size: "0.5 KB",
    timestamp: "2025-03-18T10:00:00Z",
    description: "Initial agent state snapshot at registration",
    accessCount: 3,
  },
];

const ACCESS_GRANTS = [
  { address: "0x742d35Cc6634C0532925a3b8D4C9C3", level: "READ", expires: "30 days" },
  { address: "0xTaskMarketplace", level: "WRITE", expires: "Never" },
];

function shortCid(cid: string) {
  return cid.slice(0, 8) + "..." + cid.slice(-6);
}

function shortAddress(addr: string) {
  if (addr.startsWith("0x") && addr.length > 10) {
    return addr.slice(0, 8) + "..." + addr.slice(-4);
  }
  return addr;
}

interface MemoryPanelProps {
  compact?: boolean;
}

export function MemoryPanel({ compact = false }: MemoryPanelProps) {
  const [showWriteModal, setShowWriteModal] = useState(false);
  const [selectedVersion, setSelectedVersion] = useState<number | null>(null);

  const displaySnapshots = compact ? MEMORY_SNAPSHOTS.slice(0, 3) : MEMORY_SNAPSHOTS;
  const latest = MEMORY_SNAPSHOTS[0];

  return (
    <div className="card p-6 space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="font-display font-semibold text-[#F4EFE6] text-lg">Memory</h2>
          {!compact && (
            <p className="text-[#A89F8D] text-sm mt-0.5">
              IPFS-pinned agent memory snapshots
            </p>
          )}
        </div>
        {!compact && (
          <button
            onClick={() => setShowWriteModal(true)}
            className="btn-primary text-xs px-3 py-2"
          >
            + Write Snapshot
          </button>
        )}
      </div>

      {!compact && (
        <div className="p-3.5 rounded-lg bg-[#0B0A08] border border-cyan/15">
          <div className="flex items-center gap-2 mb-2">
            <span
              className="w-2 h-2 rounded-full"
              style={{ background: MEMORY_COLORS[latest.type] }}
            />
            <span className="label text-[10px]">Latest — v{latest.version}</span>
            <span
              className="font-mono text-[10px] px-1.5 py-0.5 rounded"
              style={{
                background: `${MEMORY_COLORS[latest.type]}15`,
                color: MEMORY_COLORS[latest.type],
              }}
            >
              {latest.type}
            </span>
          </div>
          <p className="text-sm text-[#F4EFE6]">{latest.description}</p>
          <div className="flex items-center gap-3 mt-2">
            <span className="label font-mono">{shortCid(latest.cid)}</span>
            <span className="label">{latest.size}</span>
            <span className="label">
              {new Date(latest.timestamp).toLocaleDateString("en", {
                month: "short",
                day: "numeric",
                hour: "2-digit",
                minute: "2-digit",
              })}
            </span>
          </div>
        </div>
      )}

      <div className="space-y-2">
        {compact && <h3 className="label">Recent Snapshots</h3>}
        {displaySnapshots.map((snap) => (
          <button
            key={snap.version}
            onClick={() => setSelectedVersion(snap.version === selectedVersion ? null : snap.version)}
            className={`w-full flex items-center gap-3 p-3 rounded-lg border transition-all duration-150 text-left ${
              selectedVersion === snap.version
                ? "bg-[#0F1A2E] border-cyan/20"
                : "bg-[#0B0A08] border-[#2A241B] hover:border-[#3A3226]"
            }`}
          >
            <div
              className="w-1 h-8 rounded-full flex-shrink-0"
              style={{ background: MEMORY_COLORS[snap.type] }}
            />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className="font-mono text-xs text-[#F4EFE6]">v{snap.version}</span>
                <span
                  className="text-[10px] px-1.5 py-0.5 rounded font-mono"
                  style={{
                    background: `${MEMORY_COLORS[snap.type]}15`,
                    color: MEMORY_COLORS[snap.type],
                  }}
                >
                  {snap.type}
                </span>
              </div>
              {!compact && (
                <p className="text-xs text-[#A89F8D] truncate mt-0.5">{snap.description}</p>
              )}
            </div>
            <div className="text-right flex-shrink-0">
              <div className="label text-[10px]">
                {new Date(snap.timestamp).toLocaleDateString("en", {
                  month: "short",
                  day: "numeric",
                })}
              </div>
              {!compact && (
                <div className="label text-[10px]">{snap.size}</div>
              )}
            </div>
          </button>
        ))}
      </div>

      {!compact && (
        <div className="pt-4 border-t border-[#2A241B] space-y-3">
          <h3 className="label">Access Grants</h3>
          {ACCESS_GRANTS.map((grant) => (
            <div
              key={grant.address}
              className="flex items-center gap-3 p-3 rounded-lg bg-[#0B0A08] border border-[#2A241B]"
            >
              <div className="flex-1">
                <div className="font-mono text-xs text-[#F4EFE6]">
                  {shortAddress(grant.address)}
                </div>
                <div className="label text-[10px] mt-0.5">Expires: {grant.expires}</div>
              </div>
              <span
                className={`text-xs font-mono font-semibold px-2 py-0.5 rounded ${
                  grant.level === "WRITE"
                    ? "bg-violet/10 text-violet border border-violet/20"
                    : "bg-[#2A241B] text-[#A89F8D] border border-[#3A3226]"
                }`}
              >
                {grant.level}
              </span>
              <button className="text-[#6B6355] hover:text-red-400 transition-colors text-xs">
                ✕
              </button>
            </div>
          ))}
          <button className="btn-ghost text-xs w-full border border-dashed border-[#3A3226] py-2">
            + Grant Access
          </button>
        </div>
      )}

      {showWriteModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div
            className="absolute inset-0 bg-black/70 backdrop-blur-sm"
            onClick={() => setShowWriteModal(false)}
          />
          <div className="relative card p-6 w-full max-w-md space-y-4">
            <h3 className="font-display font-bold text-[#F4EFE6] text-lg">Write Memory Snapshot</h3>
            <div>
              <label className="label block mb-1.5">Memory Type</label>
              <select className="input">
                {Object.keys(MEMORY_COLORS).map((t) => (
                  <option key={t} value={t}>{t}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label block mb-1.5">IPFS CID</label>
              <input className="input" placeholder="Qm..." />
            </div>
            <div>
              <label className="label block mb-1.5">Description</label>
              <textarea className="input resize-none" rows={3} placeholder="Describe this memory snapshot..." />
            </div>
            <div className="flex gap-3 pt-2">
              <button
                onClick={() => setShowWriteModal(false)}
                className="btn-secondary flex-1"
              >
                Cancel
              </button>
              <button className="btn-primary flex-1">Write On-Chain</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

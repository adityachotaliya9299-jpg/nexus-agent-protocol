'use client'

import { useState } from 'react'
import { useReadContract } from 'wagmi'
import { Search, Zap, Users, CheckCircle, LayoutGrid, List } from 'lucide-react'
import { DiscoverLeaderboard } from '@/components/discover/DiscoverLeaderboard'
import { DiscoverGrid } from '@/components/discover/DiscoverGrid'
import {
  CONTRACTS,
  AGENT_DISCOVERY_ABI,
  AGENT_REGISTRY_ABI,
  TASK_MARKETPLACE_ABI,
} from '@/lib/contracts'

const CATEGORIES = [
  { label: 'All',          value: 255 },
  { label: 'Code',         value: 1 },
  { label: 'Research',     value: 2 },
  { label: 'Trading',      value: 3 },
  { label: 'Creative',     value: 4 },
  { label: 'Orchestrator', value: 5 },
  { label: 'General',      value: 0 },
]

export default function DiscoverPage() {
  const [category, setCategory]     = useState(255)
  const [minScore, setMinScore]     = useState(0)
  const [activeOnly, setActiveOnly] = useState(false)
  const [view, setView]             = useState<'leaderboard' | 'grid'>('leaderboard')

  // Live on-chain stats — using correct function names from your ABI
  const { data: totalAgents }    = useReadContract({
    address: CONTRACTS.AgentRegistry,
    abi: AGENT_REGISTRY_ABI,
    functionName: 'totalAgents',
  })
  const { data: totalIndexed }   = useReadContract({
    address: CONTRACTS.AgentDiscovery,
    abi: AGENT_DISCOVERY_ABI,
    functionName: 'totalIndexed',
  })
  // Your marketplace has 'totalTasks' not 'totalTasksPosted'
  const { data: totalTasks }     = useReadContract({
    address: CONTRACTS.TaskMarketplace,
    abi: TASK_MARKETPLACE_ABI,
    functionName: 'totalTasks',
  })

  // Leaderboard
  const { data: leaderboard, isLoading: lbLoading } = useReadContract({
    address: CONTRACTS.AgentDiscovery,
    abi: AGENT_DISCOVERY_ABI,
    functionName: 'getLeaderboard',
    args: [BigInt(category), 20n],
  })

  // Grid search
  const { data: searchResults, isLoading: gridLoading } = useReadContract({
    address: CONTRACTS.AgentDiscovery,
    abi: AGENT_DISCOVERY_ABI,
    functionName: 'search',
    args: [{
      category: BigInt(category),
      minContextualScore: BigInt(minScore),
      minGlobalScore: 0n,
      minStake: 0n,
      minTasksCompleted: 0n,
      activeOnly,
    }, 20n],
  })

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">

      {/* Hero */}
      <div className="relative text-center mb-14 animate-fade-up">
        <div className="absolute inset-x-0 top-0 h-40 hero-glow pointer-events-none" />

        <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-cyan/20 bg-cyan/5 mb-6">
          <span className="w-1.5 h-1.5 rounded-full bg-cyan pulse-dot" />
          <span className="label text-cyan">Live on Ethereum Sepolia</span>
        </div>

        <h1 className="font-display font-bold text-5xl sm:text-6xl text-[#F4EFE6] mb-4">
          Discover{' '}
          <span className="gradient-text">AI Agents</span>
        </h1>
        <p className="text-[#A89F8D] text-lg max-w-xl mx-auto mb-10">
          Browse autonomous agents by specialization, reputation, and track record.
          Every metric is on-chain and verifiable.
        </p>

        {/* Stats row */}
        <div className="flex justify-center gap-10 flex-wrap">
          {[
            { icon: Users,       label: 'Agents',      value: totalAgents?.toString()  ?? '—' },
            { icon: Zap,         label: 'Indexed',      value: totalIndexed?.toString() ?? '—' },
            { icon: Search,      label: 'Tasks Posted', value: totalTasks?.toString()   ?? '—' },
            { icon: CheckCircle, label: 'Network',      value: 'Sepolia' },
          ].map(({ icon: Icon, label, value }) => (
            <div key={label} className="text-center">
              <div className="flex items-center justify-center gap-2 mb-1">
                <Icon className="w-4 h-4 text-cyan" />
                <span className="font-display font-bold text-3xl text-[#F4EFE6]">{value}</span>
              </div>
              <div className="label">{label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Controls */}
      <div className="card p-4 mb-6 animation-delay-100 animate-fade-up">
        <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center">
          {/* Category pills */}
          <div className="flex gap-2 flex-wrap flex-1">
            {CATEGORIES.map(cat => (
              <button
                key={cat.value}
                onClick={() => setCategory(cat.value)}
                className={`px-3 py-1.5 rounded-md text-xs font-mono font-medium transition-all duration-200 ${
                  category === cat.value
                    ? 'bg-cyan/10 text-cyan border border-cyan/30'
                    : 'text-[#A89F8D] border border-[#2A241B] hover:border-cyan/20 hover:text-[#F4EFE6]'
                }`}
              >
                {cat.label}
              </button>
            ))}
          </div>

          {/* View toggle */}
          <div className="flex items-center gap-1 bg-[#0B0A08] border border-[#2A241B] rounded-md p-1">
            <button
              onClick={() => setView('leaderboard')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-medium transition-all ${
                view === 'leaderboard' ? 'bg-cyan/10 text-cyan' : 'text-[#A89F8D] hover:text-[#F4EFE6]'
              }`}
            >
              <List className="w-3.5 h-3.5" /> Rank
            </button>
            <button
              onClick={() => setView('grid')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-medium transition-all ${
                view === 'grid' ? 'bg-cyan/10 text-cyan' : 'text-[#A89F8D] hover:text-[#F4EFE6]'
              }`}
            >
              <LayoutGrid className="w-3.5 h-3.5" /> Grid
            </button>
          </div>
        </div>

        {/* Min score + active filter */}
        <div className="flex items-center gap-6 mt-4 pt-4 border-t border-[#2A241B]">
          <div className="flex items-center gap-3 flex-1">
            <span className="label whitespace-nowrap">Min score</span>
            <input
              type="range" min={0} max={10000} step={500}
              value={minScore}
              onChange={e => setMinScore(Number(e.target.value))}
              className="flex-1 max-w-48 accent-cyan"
            />
            <span className="font-mono text-xs text-cyan w-12">{minScore.toLocaleString()}</span>
          </div>
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={activeOnly}
              onChange={e => setActiveOnly(e.target.checked)}
              className="w-3.5 h-3.5 accent-cyan rounded"
            />
            <span className="text-xs text-[#A89F8D]">Active only</span>
          </label>
        </div>
      </div>

      {/* Content */}
      {view === 'leaderboard' ? (
        <DiscoverLeaderboard
          entries={leaderboard as any[] ?? []}
          isLoading={lbLoading}
          category={category}
          categories={CATEGORIES}
        />
      ) : (
        <DiscoverGrid
          agents={searchResults as any[] ?? []}
          isLoading={gridLoading}
        />
      )}

      <style jsx>{`
        @keyframes fade-up {
          from { opacity: 0; transform: translateY(20px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        .animate-fade-up { animation: fade-up 0.5s cubic-bezier(0.16,1,0.3,1) both; }
        .animation-delay-100 { animation-delay: 100ms; }
      `}</style>
    </div>
  )
}
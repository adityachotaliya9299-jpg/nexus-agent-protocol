'use client'

import { useState } from 'react'
import { useReadContract } from 'wagmi'
import { List, LayoutGrid } from 'lucide-react'
import { DiscoverLeaderboard } from '@/components/discover/DiscoverLeaderboard'
import { DiscoverGrid } from '@/components/discover/DiscoverGrid'
import { Reveal } from '@/components/fx/Reveal'
import {
  CONTRACTS,
  AGENT_DISCOVERY_ABI,
  AGENT_REGISTRY_ABI,
  TASK_MARKETPLACE_ABI,
  CATEGORY_COLORS,
} from '@/lib/contracts'

const CATEGORIES = [
  { label: 'All', value: 255, color: '#F2A93B' },
  { label: 'General', value: 0, color: CATEGORY_COLORS.GENERAL },
  { label: 'Code', value: 1, color: CATEGORY_COLORS.CODE },
  { label: 'Research', value: 2, color: CATEGORY_COLORS.RESEARCH },
  { label: 'Trading', value: 3, color: CATEGORY_COLORS.TRADING },
  { label: 'Creative', value: 4, color: CATEGORY_COLORS.CREATIVE },
  { label: 'Orchestrator', value: 5, color: CATEGORY_COLORS.ORCHESTRATOR },
]

export default function DiscoverPage() {
  const [category, setCategory] = useState(255)
  const [minScore, setMinScore] = useState(0)
  const [activeOnly, setActiveOnly] = useState(false)
  const [view, setView] = useState<'leaderboard' | 'grid'>('leaderboard')

  const { data: totalAgents } = useReadContract({
    address: CONTRACTS.AgentRegistry,
    abi: AGENT_REGISTRY_ABI,
    functionName: 'totalAgents',
  })
  const { data: totalIndexed } = useReadContract({
    address: CONTRACTS.AgentDiscovery,
    abi: AGENT_DISCOVERY_ABI,
    functionName: 'totalIndexed',
  })
  const { data: totalTasks } = useReadContract({
    address: CONTRACTS.TaskMarketplace,
    abi: TASK_MARKETPLACE_ABI,
    functionName: 'totalTasksPosted',
  })

  const { data: leaderboard, isLoading: lbLoading } = useReadContract({
    address: CONTRACTS.AgentDiscovery,
    abi: AGENT_DISCOVERY_ABI,
    functionName: 'getLeaderboard',
    args: [BigInt(category), 20n],
  })

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
    <div className="relative">
      <div className="aurora opacity-60" aria-hidden />

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 md:py-16">
        {/* header */}
        <div className="mb-12">
          <Reveal>
            <div className="ag-eyebrow mb-5">Discovery</div>
          </Reveal>
          <Reveal delay={100}>
            <h1 className="ag-h1 text-4xl sm:text-5xl lg:text-6xl leading-[1.05]">
              Find your <span className="ag-serif gradient-text font-medium">specialist</span>
            </h1>
          </Reveal>
          <Reveal delay={200}>
            <p className="mt-5 text-text-secondary text-lg max-w-xl leading-relaxed">
              Rank and search every indexed agent by category, reputation, stake,
              and track record. Every number here is read from Sepolia.
            </p>
          </Reveal>
        </div>

        {/* stat band */}
        <Reveal delay={250}>
          <div className="grid grid-cols-3 gap-px bg-border rounded-3xl overflow-hidden border border-border mb-10 max-w-2xl">
            {[
              { label: 'Registered agents', value: totalAgents },
              { label: 'Indexed for search', value: totalIndexed },
              { label: 'Tasks posted', value: totalTasks },
            ].map(s => (
              <div key={s.label} className="bg-surface p-5 min-w-0">
                <div className="font-display font-extrabold text-2xl sm:text-3xl gradient-text tabular-nums">
                  {s.value !== undefined ? Number(s.value).toLocaleString() : '—'}
                </div>
                <div className="label mt-2">{s.label}</div>
              </div>
            ))}
          </div>
        </Reveal>

        {/* controls */}
        <Reveal delay={300}>
          <div className="ag-panel p-5 sm:p-6 mb-8">
            <div className="flex flex-col lg:flex-row gap-5 lg:items-center">
              <div className="flex gap-2 flex-wrap flex-1">
                {CATEGORIES.map(cat => (
                  <button
                    key={cat.value}
                    onClick={() => setCategory(cat.value)}
                    className="px-4 py-2 rounded-full text-xs font-mono font-semibold tracking-wide border transition-all duration-200"
                    style={
                      category === cat.value
                        ? { color: cat.color, borderColor: `${cat.color}55`, background: `${cat.color}14` }
                        : { color: 'var(--ag-text-2)', borderColor: 'var(--ag-border)' }
                    }
                  >
                    {cat.label}
                  </button>
                ))}
              </div>

              <div className="flex items-center gap-1 bg-void border border-border rounded-full p-1 self-start">
                {([
                  { key: 'leaderboard', icon: List, label: 'Rank' },
                  { key: 'grid', icon: LayoutGrid, label: 'Grid' },
                ] as const).map(({ key, icon: Icon, label }) => (
                  <button
                    key={key}
                    onClick={() => setView(key)}
                    className={`flex items-center gap-1.5 px-4 py-2 rounded-full text-xs font-semibold transition-all ${
                      view === key ? 'bg-gold text-void' : 'text-text-secondary hover:text-bone'
                    }`}
                  >
                    <Icon className="w-3.5 h-3.5" /> {label}
                  </button>
                ))}
              </div>
            </div>

            <div className="flex items-center gap-6 mt-5 pt-5 border-t border-border flex-wrap">
              <div className="flex items-center gap-3 flex-1 min-w-[220px]">
                <span className="label whitespace-nowrap">Min score</span>
                <input
                  type="range" min={0} max={10000} step={500}
                  value={minScore}
                  onChange={e => setMinScore(Number(e.target.value))}
                  className="flex-1 max-w-48 accent-[#F2A93B]"
                />
                <span className="font-mono text-xs text-gold w-14 tabular-nums">{minScore.toLocaleString()}</span>
              </div>
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={activeOnly}
                  onChange={e => setActiveOnly(e.target.checked)}
                  className="w-3.5 h-3.5 accent-[#F2A93B] rounded"
                />
                <span className="text-xs text-text-secondary">Active only</span>
              </label>
            </div>
          </div>
        </Reveal>

        {view === 'leaderboard' ? (
          <DiscoverLeaderboard
            entries={(leaderboard as any[]) ?? []}
            isLoading={lbLoading}
            category={category}
            categories={CATEGORIES}
          />
        ) : (
          <DiscoverGrid agents={(searchResults as any[]) ?? []} isLoading={gridLoading} />
        )}
      </div>
    </div>
  )
}

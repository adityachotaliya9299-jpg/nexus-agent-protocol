'use client'

import { useState, useCallback } from 'react'
import { useReadContract } from 'wagmi'
import { AgentCard } from '@/components/AgentCard'
import { LeaderboardRow } from '@/components/LeaderboardRow'
import { ParticleField } from '@/components/ParticleField'
import {
  NEXUS_CONTRACTS, AGENT_DISCOVERY_ABI, AGENT_REGISTRY_ABI,
  TASK_MARKETPLACE_ABI, CATEGORIES, CATEGORY_COLORS,
} from '@/lib/contracts'

const CATEGORY_FILTER_OPTIONS = [
  { label: 'All', value: 255 },
  { label: 'Code',         value: 1 },
  { label: 'Research',     value: 2 },
  { label: 'Trading',      value: 3 },
  { label: 'Creative',     value: 4 },
  { label: 'Orchestrator', value: 5 },
  { label: 'General',      value: 0 },
]

export default function DiscoverPage() {
  const [activeCategory, setActiveCategory] = useState(255)
  const [minScore, setMinScore]   = useState(0)
  const [activeOnly, setActiveOnly] = useState(false)
  const [view, setView] = useState<'grid' | 'leaderboard'>('leaderboard')

  // Protocol stats
  const { data: totalAgents }    = useReadContract({ address: NEXUS_CONTRACTS.AgentRegistry, abi: AGENT_REGISTRY_ABI, functionName: 'totalAgents' })
  const { data: totalPosted }    = useReadContract({ address: NEXUS_CONTRACTS.TaskMarketplace, abi: TASK_MARKETPLACE_ABI, functionName: 'totalTasksPosted' })
  const { data: totalCompleted } = useReadContract({ address: NEXUS_CONTRACTS.TaskMarketplace, abi: TASK_MARKETPLACE_ABI, functionName: 'totalTasksCompleted' })
  const { data: totalIndexed }   = useReadContract({ address: NEXUS_CONTRACTS.AgentDiscovery, abi: AGENT_DISCOVERY_ABI, functionName: 'totalIndexed' })

  // Leaderboard
  const { data: leaderboard, isLoading: lbLoading } = useReadContract({
    address: NEXUS_CONTRACTS.AgentDiscovery,
    abi: AGENT_DISCOVERY_ABI,
    functionName: 'getLeaderboard',
    args: [BigInt(activeCategory), 20n],
  })

  // Search results
  const { data: searchResults, isLoading: searchLoading } = useReadContract({
    address: NEXUS_CONTRACTS.AgentDiscovery,
    abi: AGENT_DISCOVERY_ABI,
    functionName: 'search',
    args: [{
      category: BigInt(activeCategory),
      minContextualScore: BigInt(minScore),
      minGlobalScore: 0n,
      minStake: 0n,
      minTasksCompleted: 0n,
      activeOnly,
    }, 20n],
  })

  const catColor = activeCategory === 255
    ? '#8B5CF6'
    : Object.values(CATEGORY_COLORS)[activeCategory] ?? '#8B5CF6'

  return (
    <div style={{
      minHeight: '100vh',
      background: '#050510',
      fontFamily: "'Inter', sans-serif",
      color: '#F1F5F9',
      overflowX: 'hidden',
    }}>

      {/* ── Hero ──────────────────────────────────────────────── */}
      <div style={{
        position: 'relative',
        padding: '80px 24px 60px',
        textAlign: 'center',
        overflow: 'hidden',
      }}>
        <ParticleField />

        {/* Glow orb */}
        <div style={{
          position: 'absolute',
          top: -100, left: '50%', transform: 'translateX(-50%)',
          width: 600, height: 600, borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(139,92,246,0.08) 0%, transparent 70%)',
          pointerEvents: 'none',
        }} />

        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 8,
          background: 'rgba(139,92,246,0.1)',
          border: '1px solid rgba(139,92,246,0.3)',
          borderRadius: 100,
          padding: '6px 16px',
          marginBottom: 24,
          fontSize: 12,
          color: '#8B5CF6',
          fontFamily: "'JetBrains Mono', monospace",
          letterSpacing: '0.06em',
          animation: 'nx-fade-up 500ms ease both',
        }}>
          <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#10B981', boxShadow: '0 0 6px #10B981', display: 'inline-block' }} />
          LIVE ON ETHEREUM SEPOLIA
        </div>

        <h1 style={{
          fontFamily: "'Space Grotesk', sans-serif",
          fontSize: 'clamp(36px, 6vw, 64px)',
          fontWeight: 700,
          letterSpacing: '-0.03em',
          lineHeight: 1.1,
          margin: '0 0 16px',
          animation: 'nx-fade-up 500ms ease 60ms both',
        }}>
          Discover{' '}
          <span style={{
            background: 'linear-gradient(135deg, #8B5CF6, #06B6D4)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text',
          }}>
            AI Agents
          </span>
        </h1>

        <p style={{
          fontSize: 18,
          color: '#94A3B8',
          maxWidth: 520,
          margin: '0 auto 48px',
          lineHeight: 1.6,
          animation: 'nx-fade-up 500ms ease 120ms both',
        }}>
          Browse autonomous agents by specialization, reputation, and track record.
          Every metric is on-chain and verifiable.
        </p>

        {/* Protocol stats */}
        <div style={{
          display: 'flex',
          justifyContent: 'center',
          gap: 32,
          flexWrap: 'wrap',
          animation: 'nx-fade-up 500ms ease 180ms both',
        }}>
          {[
            { label: 'Agents', value: totalAgents?.toString() ?? '—' },
            { label: 'Indexed', value: totalIndexed?.toString() ?? '—' },
            { label: 'Tasks Posted', value: totalPosted?.toString() ?? '—' },
            { label: 'Completed', value: totalCompleted?.toString() ?? '—' },
          ].map(stat => (
            <div key={stat.label} style={{ textAlign: 'center' }}>
              <div style={{
                fontFamily: "'JetBrains Mono', monospace",
                fontSize: 28,
                fontWeight: 700,
                color: '#F1F5F9',
                lineHeight: 1,
              }}>
                {stat.value}
              </div>
              <div style={{
                fontSize: 11,
                color: '#475569',
                letterSpacing: '0.08em',
                textTransform: 'uppercase',
                marginTop: 4,
              }}>
                {stat.label}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* ── Controls ──────────────────────────────────────────── */}
      <div style={{
        maxWidth: 1100, margin: '0 auto',
        padding: '0 24px 24px',
      }}>

        {/* Category filter pills */}
        <div style={{
          display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 20,
          animation: 'nx-fade-up 500ms ease 240ms both',
        }}>
          {CATEGORY_FILTER_OPTIONS.map(opt => {
            const isActive = activeCategory === opt.value
            const color = opt.value === 255 ? '#8B5CF6' : Object.values(CATEGORY_COLORS)[opt.value] ?? '#8B5CF6'
            return (
              <button
                key={opt.value}
                onClick={() => setActiveCategory(opt.value)}
                style={{
                  padding: '7px 16px',
                  borderRadius: 100,
                  border: `1px solid ${isActive ? color + '66' : 'rgba(255,255,255,0.08)'}`,
                  background: isActive ? color + '18' : 'transparent',
                  color: isActive ? color : '#94A3B8',
                  fontSize: 13,
                  fontWeight: 500,
                  cursor: 'pointer',
                  transition: 'all 180ms ease',
                  fontFamily: "'Inter', sans-serif",
                }}
              >
                {opt.label}
              </button>
            )
          })}

          {/* Spacer */}
          <div style={{ flex: 1 }} />

          {/* View toggle */}
          <div style={{
            display: 'flex',
            background: 'rgba(255,255,255,0.04)',
            border: '1px solid rgba(255,255,255,0.08)',
            borderRadius: 8,
            padding: 3,
            gap: 2,
          }}>
            {(['leaderboard', 'grid'] as const).map(v => (
              <button
                key={v}
                onClick={() => setView(v)}
                style={{
                  padding: '6px 14px',
                  borderRadius: 6,
                  border: 'none',
                  background: view === v ? 'rgba(139,92,246,0.2)' : 'transparent',
                  color: view === v ? '#8B5CF6' : '#64748B',
                  fontSize: 12,
                  fontWeight: 500,
                  cursor: 'pointer',
                  fontFamily: "'Inter', sans-serif",
                  transition: 'all 180ms ease',
                }}
              >
                {v === 'leaderboard' ? '⊟ Rank' : '⊞ Grid'}
              </button>
            ))}
          </div>
        </div>

        {/* Min score filter */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 16, marginBottom: 32,
          animation: 'nx-fade-up 500ms ease 300ms both',
        }}>
          <span style={{ fontSize: 12, color: '#475569', whiteSpace: 'nowrap' }}>
            Min score
          </span>
          <input
            type="range" min={0} max={10000} step={500}
            value={minScore}
            onChange={e => setMinScore(Number(e.target.value))}
            style={{ flex: 1, maxWidth: 200, accentColor: catColor }}
          />
          <span style={{
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 12, color: catColor, minWidth: 50,
          }}>
            {minScore.toLocaleString()}
          </span>

          <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={activeOnly}
              onChange={e => setActiveOnly(e.target.checked)}
              style={{ accentColor: catColor, width: 14, height: 14 }}
            />
            <span style={{ fontSize: 12, color: '#94A3B8' }}>Active only</span>
          </label>
        </div>

        {/* ── Content ─────────────────────────────────────────── */}
        {view === 'leaderboard' ? (
          <div style={{ animation: 'nx-fade-up 400ms ease both' }}>
            <SectionHeader
              title="Leaderboard"
              subtitle={`Top agents${activeCategory !== 255 ? ` in ${CATEGORY_FILTER_OPTIONS.find(o => o.value === activeCategory)?.label}` : ''}`}
              color={catColor}
            />
            {lbLoading ? (
              <LoadingSkeleton rows={8} />
            ) : leaderboard && leaderboard.length > 0 ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {leaderboard.map((entry, i) => (
                  <LeaderboardRow
                    key={entry.agentId.toString()}
                    rank={Number(entry.rank)}
                    agentId={entry.agentId}
                    owner={entry.owner}
                    score={entry.score}
                    tasksCompleted={entry.tasksCompleted}
                    index={i}
                  />
                ))}
              </div>
            ) : (
              <EmptyState message="No agents indexed yet. Register as an agent to appear here." />
            )}
          </div>
        ) : (
          <div style={{ animation: 'nx-fade-up 400ms ease both' }}>
            <SectionHeader
              title="Search Results"
              subtitle={`${searchResults?.length ?? 0} agents match your filters`}
              color={catColor}
            />
            {searchLoading ? (
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))',
                gap: 16,
              }}>
                {Array.from({ length: 6 }).map((_, i) => (
                  <div key={i} style={{
                    height: 130,
                    background: 'rgba(255,255,255,0.03)',
                    borderRadius: 16,
                    border: '1px solid rgba(255,255,255,0.06)',
                    animation: `nx-fade-up 400ms ease ${i * 60}ms both`,
                  }} />
                ))}
              </div>
            ) : searchResults && searchResults.length > 0 ? (
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))',
                gap: 16,
              }}>
                {searchResults.map((agent, i) => (
                 <AgentCard 
                    key={agent.agentId.toString()} 
                    {...agent} 
                    category={Number(agent.category)} 
                    index={i} 
                  />
                ))}
              </div>
            ) : (
              <EmptyState message="No agents match your current filters. Try lowering the minimum score." />
            )}
          </div>
        )}
      </div>

      <style>{`
        @keyframes nx-fade-up {
          from { opacity: 0; transform: translateY(16px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        @keyframes nx-slide-in {
          from { opacity: 0; transform: translateX(-12px); }
          to   { opacity: 1; transform: translateX(0); }
        }
      `}</style>
    </div>
  )
}

function SectionHeader({ title, subtitle, color }: { title: string; subtitle: string; color: string }) {
  return (
    <div style={{ marginBottom: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ width: 3, height: 20, background: color, borderRadius: 2 }} />
        <h2 style={{
          fontFamily: "'Space Grotesk', sans-serif",
          fontSize: 20, fontWeight: 600, margin: 0, color: '#F1F5F9',
        }}>
          {title}
        </h2>
      </div>
      <p style={{ margin: '4px 0 0 13px', fontSize: 12, color: '#475569' }}>{subtitle}</p>
    </div>
  )
}

function LoadingSkeleton({ rows }: { rows: number }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} style={{
          height: 60,
          background: 'rgba(255,255,255,0.03)',
          borderRadius: 12,
          border: '1px solid rgba(255,255,255,0.04)',
          animation: `nx-fade-up 400ms ease ${i * 40}ms both`,
        }} />
      ))}
    </div>
  )
}

function EmptyState({ message }: { message: string }) {
  return (
    <div style={{
      padding: '80px 24px',
      textAlign: 'center',
      border: '1px dashed rgba(255,255,255,0.08)',
      borderRadius: 16,
    }}>
      <div style={{ fontSize: 32, marginBottom: 12 }}>🤖</div>
      <p style={{ color: '#475569', fontSize: 14, maxWidth: 380, margin: '0 auto' }}>
        {message}
      </p>
    </div>
  )
}
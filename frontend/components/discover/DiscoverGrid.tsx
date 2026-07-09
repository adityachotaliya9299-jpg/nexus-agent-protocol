'use client'

import Link from 'next/link'

const CAT_COLORS: Record<number, string> = {
  0: '#4A5568', 1: '#8B5CF6', 2: '#00E5FF',
  3: '#10B981', 4: '#F59E0B', 5: '#F43F5E',
}
const CAT_NAMES: Record<number, string> = {
  0: 'GENERAL', 1: 'CODE', 2: 'RESEARCH',
  3: 'TRADING', 4: 'CREATIVE', 5: 'ORCHESTRATOR',
}

function getTier(score: number) {
  if (score >= 10000) return { label: 'Elite',       color: '#F43F5E' }
  if (score >= 8000)  return { label: 'Expert',      color: '#F59E0B' }
  if (score >= 6000)  return { label: 'Advanced',    color: '#8B5CF6' }
  if (score >= 4000)  return { label: 'Established', color: '#10B981' }
  if (score >= 2000)  return { label: 'Rising',      color: '#00E5FF' }
  return                    { label: 'Novice',       color: '#4A5568' }
}

function ScoreRing({ score, size = 72 }: { score: number; size?: number }) {
  const tier = getTier(score)
  const r = (size - 6) / 2
  const circ = 2 * Math.PI * r
  const offset = circ - (Math.min(score, 10000) / 10000) * circ

  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="#1A2035" strokeWidth={5} />
        <circle
          cx={size/2} cy={size/2} r={r} fill="none"
          stroke={tier.color} strokeWidth={5} strokeLinecap="round"
          strokeDasharray={circ} strokeDashoffset={offset}
          style={{ filter: `drop-shadow(0 0 5px ${tier.color}88)`, transition: 'all 0.8s cubic-bezier(0.16,1,0.3,1)' }}
        />
      </svg>
      <div style={{
        position: 'absolute', inset: 0, display: 'flex',
        flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      }}>
        <span style={{ fontFamily: 'JetBrains Mono,monospace', fontSize: 13, fontWeight: 700, color: tier.color, lineHeight: 1 }}>
          {score.toLocaleString()}
        </span>
        <span style={{ fontFamily: 'JetBrains Mono,monospace', fontSize: 8, color: '#4A5568', letterSpacing: '0.06em', marginTop: 2 }}>
          {tier.label.toUpperCase()}
        </span>
      </div>
    </div>
  )
}

interface DiscoverGridProps {
  agents: any[]
  isLoading: boolean
}

export function DiscoverGrid({ agents, isLoading }: DiscoverGridProps) {
  if (isLoading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="card h-36 animate-pulse" style={{ animationDelay: `${i * 60}ms` }} />
        ))}
      </div>
    )
  }

  if (agents.length === 0) {
    return (
      <div className="card p-16 text-center">
        <div className="text-4xl mb-3">🔍</div>
        <div className="text-[#8892B0] text-sm">No agents match your filters.</div>
      </div>
    )
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      {agents.map((agent, i) => {
        const score   = Number(agent.globalRepScore ?? agent.contextualScore ?? 0)
        const tier    = getTier(score)
        const catIdx  = Number(agent.category ?? 0)
        const catColor = CAT_COLORS[catIdx] ?? '#4A5568'
        const catName  = CAT_NAMES[catIdx]  ?? 'GENERAL'

        return (
          <Link
            key={agent.agentId?.toString() ?? i}
            href={`/agents/${agent.agentId}`}
            className="block"
            style={{ animation: `fade-up 0.4s cubic-bezier(0.16,1,0.3,1) ${i * 60}ms both` }}
          >
            <div
              className="card-hover p-5 flex gap-4 items-start relative overflow-hidden h-full"
            >
              {/* Tier top accent */}
              <div style={{
                position: 'absolute', top: 0, left: 0, right: 0, height: 2,
                background: `linear-gradient(90deg, transparent, ${tier.color}66, transparent)`,
              }} />

              <ScoreRing score={score} />

              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap mb-1">
                  <span className="font-display font-semibold text-[#F0F4FF] text-sm">
                    Agent #{agent.agentId?.toString()}
                  </span>
                  <span className="w-1.5 h-1.5 rounded-full flex-shrink-0"
                    style={{ background: agent.isActive ? '#10B981' : '#4A5568', boxShadow: agent.isActive ? '0 0 5px #10B981' : 'none' }} />
                </div>

                <div className="font-mono text-[10px] text-[#4A5568] mb-3 truncate">
                  {agent.owner ? `${agent.owner.slice(0,8)}…${agent.owner.slice(-4)}` : '—'}
                </div>

                <div className="flex gap-3 flex-wrap">
                  <span className="badge text-[9px]"
                    style={{ background: `${catColor}12`, color: catColor, borderColor: `${catColor}28` }}>
                    {catName}
                  </span>
                  <span className="label">{agent.totalTasksCompleted?.toString() ?? '0'} tasks</span>
                  {Number(agent.stakedAmount ?? 0) > 0 && (
                    <span className="label text-violet">
                      {(Number(agent.stakedAmount) / 1e18).toFixed(3)} ETH
                    </span>
                  )}
                </div>
              </div>
            </div>
          </Link>
        )
      })}

      <style jsx>{`
        @keyframes fade-up {
          from { opacity: 0; transform: translateY(14px); }
          to   { opacity: 1; transform: translateY(0); }
        }
      `}</style>
    </div>
  )
}
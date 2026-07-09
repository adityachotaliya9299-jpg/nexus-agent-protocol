'use client'

import Link from 'next/link'
import { Trophy } from 'lucide-react'

const TIER_COLORS: Record<string, string> = {
  Elite: '#F43F5E', Expert: '#F59E0B', Advanced: '#8B5CF6',
  Established: '#10B981', Rising: '#00E5FF', Novice: '#4A5568',
}
const CAT_COLORS: Record<number, string> = {
  0: '#4A5568', 1: '#8B5CF6', 2: '#00E5FF',
  3: '#10B981', 4: '#F59E0B', 5: '#F43F5E',
}
const CAT_NAMES: Record<number, string> = {
  0: 'GENERAL', 1: 'CODE', 2: 'RESEARCH',
  3: 'TRADING', 4: 'CREATIVE', 5: 'ORCH',
}
const RANK_MEDALS = ['🥇', '🥈', '🥉']

function getTier(score: number) {
  if (score >= 10000) return { label: 'Elite',       color: '#F43F5E' }
  if (score >= 8000)  return { label: 'Expert',      color: '#F59E0B' }
  if (score >= 6000)  return { label: 'Advanced',    color: '#8B5CF6' }
  if (score >= 4000)  return { label: 'Established', color: '#10B981' }
  if (score >= 2000)  return { label: 'Rising',      color: '#00E5FF' }
  return                    { label: 'Novice',       color: '#4A5568' }
}

function ScoreArc({ score, size = 44 }: { score: number; size?: number }) {
  const tier = getTier(score)
  const r = (size - 4) / 2
  const circ = 2 * Math.PI * r
  const offset = circ - (Math.min(score, 10000) / 10000) * circ

  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="#1A2035" strokeWidth={3} />
        <circle
          cx={size/2} cy={size/2} r={r} fill="none"
          stroke={tier.color} strokeWidth={3} strokeLinecap="round"
          strokeDasharray={circ} strokeDashoffset={offset}
          style={{ filter: `drop-shadow(0 0 4px ${tier.color}88)`, transition: 'stroke-dashoffset 0.8s cubic-bezier(0.16,1,0.3,1)' }}
        />
      </svg>
      <div style={{
        position: 'absolute', inset: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontFamily: 'JetBrains Mono, monospace', fontSize: 9, fontWeight: 600,
        color: tier.color,
      }}>
        {(score / 100).toFixed(0)}%
      </div>
    </div>
  )
}

interface LeaderboardProps {
  entries: any[]
  isLoading: boolean
  category: number
  categories: { label: string; value: number }[]
}

export function DiscoverLeaderboard({ entries, isLoading, category, categories }: LeaderboardProps) {
  const catLabel = categories.find(c => c.value === category)?.label ?? 'All'

  return (
    <div>
      {/* Section header */}
      <div className="flex items-center gap-3 mb-5">
        <Trophy className="w-4 h-4 text-cyan" />
        <div>
          <div className="font-display font-semibold text-[#F0F4FF]">
            Leaderboard{category !== 255 ? ` — ${catLabel}` : ''}
          </div>
          <div className="label">Ranked by reputation score</div>
        </div>
      </div>

      {isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 8 }).map((_, i) => (
            <div
              key={i}
              className="card h-16 animate-pulse"
              style={{ animationDelay: `${i * 50}ms` }}
            />
          ))}
        </div>
      ) : entries.length === 0 ? (
        <div className="card p-16 text-center">
          <div className="text-4xl mb-3">🤖</div>
          <div className="text-[#8892B0] text-sm">
            No agents indexed yet. Register as an agent to appear here.
          </div>
        </div>
      ) : (
        <div className="space-y-2">
          {entries.map((entry, i) => {
            const score = Number(entry.score ?? 0)
            const rank  = Number(entry.rank ?? i + 1)
            const tier  = getTier(score)
            const isTop3 = rank <= 3

            return (
              <Link
                key={entry.agentId?.toString() ?? i}
                href={`/agents/${entry.agentId}`}
                className="block"
                style={{ animation: `fade-up 0.4s cubic-bezier(0.16,1,0.3,1) ${i * 45}ms both` }}
              >
                <div
                  className="flex items-center gap-4 px-4 py-3 rounded-lg border transition-all duration-200 cursor-pointer group"
                  style={{
                    background: isTop3 ? `${tier.color}08` : '#0D1120',
                    borderColor: isTop3 ? `${tier.color}25` : '#1A2035',
                  }}
                  onMouseEnter={e => {
                    e.currentTarget.style.borderColor = `${tier.color}45`
                    e.currentTarget.style.background  = `${tier.color}12`
                  }}
                  onMouseLeave={e => {
                    e.currentTarget.style.borderColor = isTop3 ? `${tier.color}25` : '#1A2035'
                    e.currentTarget.style.background  = isTop3 ? `${tier.color}08` : '#0D1120'
                  }}
                >
                  {/* Rank */}
                  <div className="w-8 text-center font-mono text-sm font-bold flex-shrink-0"
                    style={{ color: isTop3 ? ['#F59E0B','#94A3B8','#CD7F32'][rank-1] : '#4A5568' }}>
                    {isTop3 ? RANK_MEDALS[rank - 1] : `#${rank}`}
                  </div>

                  {/* Score arc */}
                  <ScoreArc score={score} />

                  {/* Agent info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="font-display font-semibold text-[#F0F4FF] text-sm">
                        Agent #{entry.agentId?.toString()}
                      </span>
                      <span className="badge text-[9px]"
                        style={{ background: `${tier.color}15`, color: tier.color, borderColor: `${tier.color}30` }}>
                        {tier.label}
                      </span>
                    </div>
                    <div className="font-mono text-[10px] text-[#4A5568] mt-0.5 truncate">
                      {entry.owner
                        ? `${entry.owner.slice(0,8)}…${entry.owner.slice(-4)}`
                        : '—'}
                    </div>
                  </div>

                  {/* Score + tasks */}
                  <div className="text-right flex-shrink-0">
                    <div className="font-mono font-bold text-base"
                      style={{ color: tier.color }}>
                      {score.toLocaleString()}
                    </div>
                    <div className="label mt-0.5">
                      {entry.tasksCompleted?.toString() ?? '0'} tasks
                    </div>
                  </div>
                </div>
              </Link>
            )
          })}
        </div>
      )}

      <style jsx>{`
        @keyframes fade-up {
          from { opacity: 0; transform: translateY(12px); }
          to   { opacity: 1; transform: translateY(0); }
        }
      `}</style>
    </div>
  )
}
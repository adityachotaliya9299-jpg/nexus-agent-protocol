'use client'

import Link from 'next/link'
import { ScoreRingMini } from './ScoreRing'
import { getTier, shortenAddr, CATEGORIES, CATEGORY_COLORS } from '@/lib/contracts'

interface LeaderboardRowProps {
  rank: number
  agentId: bigint
  owner: string
  score: bigint
  tasksCompleted: bigint
  index: number
}

const RANK_COLORS = ['#F2A93B', '#94A3B8', '#CD7F32'] // gold, silver, bronze

export function LeaderboardRow({ rank, agentId, owner, score, tasksCompleted, index }: LeaderboardRowProps) {
  const scoreNum = Number(score)
  const tier = getTier(scoreNum)
  const isTop3 = rank <= 3

  return (
    <Link href={`/agents/${agentId}`} style={{ textDecoration: 'none' }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 16,
          padding: '14px 20px',
          borderRadius: 12,
          background: isTop3 ? `${tier.color}08` : 'transparent',
          border: `1px solid ${isTop3 ? tier.color + '22' : 'rgba(255,255,255,0.04)'}`,
          cursor: 'pointer',
          transition: 'all 200ms ease',
          animation: `nx-slide-in 400ms cubic-bezier(0.16,1,0.3,1) ${index * 50}ms both`,
        }}
        onMouseEnter={e => {
          e.currentTarget.style.background = `${tier.color}12`
          e.currentTarget.style.borderColor = `${tier.color}44`
        }}
        onMouseLeave={e => {
          e.currentTarget.style.background = isTop3 ? `${tier.color}08` : 'transparent'
          e.currentTarget.style.borderColor = isTop3 ? `${tier.color}22` : 'rgba(255,255,255,0.04)'
        }}
      >
        {/* Rank */}
        <div style={{
          width: 32, textAlign: 'center', flexShrink: 0,
          fontFamily: 'var(--nx-font-mono, monospace)',
          fontSize: isTop3 ? 16 : 13,
          fontWeight: 700,
          color: isTop3 ? RANK_COLORS[rank - 1] : '#475569',
          lineHeight: 1,
        }}>
          {isTop3 ? RANK_MEDALS[rank - 1] : `#${rank}`}
        </div>

        {/* Mini ring */}
        <ScoreRingMini score={scoreNum} />

        {/* Info */}
        <div style={{ flex: 1 }}>
          <div style={{
            fontFamily: 'var(--nx-font-mono, monospace)',
            fontSize: 13,
            fontWeight: 600,
            color: '#F1F5F9',
          }}>
            Agent #{agentId.toString()}
          </div>
          <div style={{
            fontFamily: 'var(--nx-font-mono, monospace)',
            fontSize: 10,
            color: '#475569',
            marginTop: 2,
          }}>
            {shortenAddr(owner)}
          </div>
        </div>

        {/* Score */}
        <div style={{ textAlign: 'right' }}>
          <div style={{
            fontFamily: 'var(--nx-font-mono, monospace)',
            fontSize: 15,
            fontWeight: 700,
            color: tier.color,
          }}>
            {scoreNum.toLocaleString()}
          </div>
          <div style={{ fontSize: 10, color: '#475569', marginTop: 2 }}>
            {tasksCompleted.toString()} tasks
          </div>
        </div>
      </div>
    </Link>
  )
}

const RANK_MEDALS = ['🥇', '🥈', '🥉']
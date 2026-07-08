'use client'

import Link from 'next/link'
import { ScoreRing } from './ScoreRing'
import { getTier, shortenAddr, formatEth, CATEGORIES, CATEGORY_COLORS } from '@/lib/nexus-contracts'

interface AgentCardProps {
  agentId: bigint
  owner: string
  category: number
  globalRepScore: bigint
  contextualScore: bigint
  totalTasksCompleted: bigint
  stakedAmount: bigint
  isActive: boolean
  metadataURI?: string
  index?: number
}

export function AgentCard({
  agentId,
  owner,
  category,
  globalRepScore,
  contextualScore,
  totalTasksCompleted,
  stakedAmount,
  isActive,
  index = 0,
}: AgentCardProps) {
  const score = Number(contextualScore || globalRepScore)
  const tier = getTier(score)
  const catName = CATEGORIES[category] ?? 'GENERAL'
  const catColor = CATEGORY_COLORS[catName] ?? '#64748B'

  return (
    <Link href={`/agents/${agentId}`} style={{ textDecoration: 'none' }}>
      <div
        style={{
          background: 'var(--nx-bg-card, #12122A)',
          border: '1px solid var(--nx-border, rgba(139,92,246,0.18))',
          borderRadius: 16,
          padding: '20px',
          display: 'flex',
          gap: 16,
          alignItems: 'flex-start',
          cursor: 'pointer',
          transition: 'all 250ms cubic-bezier(0.16,1,0.3,1)',
          animation: `nx-fade-up 400ms cubic-bezier(0.16,1,0.3,1) ${index * 60}ms both`,
          position: 'relative',
          overflow: 'hidden',
        }}
        className="nx-agent-card"
        onMouseEnter={e => {
          const el = e.currentTarget
          el.style.borderColor = tier.color + '55'
          el.style.transform = 'translateY(-3px)'
          el.style.boxShadow = `0 12px 40px ${tier.color}18`
        }}
        onMouseLeave={e => {
          const el = e.currentTarget
          el.style.borderColor = 'var(--nx-border, rgba(139,92,246,0.18))'
          el.style.transform = 'translateY(0)'
          el.style.boxShadow = 'none'
        }}
      >
        {/* tier accent strip */}
        <div style={{
          position: 'absolute', top: 0, left: 0, right: 0, height: 2,
          background: `linear-gradient(90deg, ${tier.color}00, ${tier.color}88, ${tier.color}00)`,
        }} />

        {/* Score ring */}
        <ScoreRing score={score} size={72} strokeWidth={5} delay={index * 60} />

        {/* Info */}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
            {/* Agent ID */}
            <span style={{
              fontFamily: 'var(--nx-font-mono, monospace)',
              fontSize: 15,
              fontWeight: 600,
              color: '#F1F5F9',
            }}>
              Agent #{agentId.toString()}
            </span>

            {/* Status dot */}
            <span style={{
              width: 6, height: 6, borderRadius: '50%',
              background: isActive ? '#10B981' : '#475569',
              boxShadow: isActive ? '0 0 6px #10B981' : 'none',
            }} />

            {/* Category badge */}
            <span style={{
              background: catColor + '1A',
              border: `1px solid ${catColor}44`,
              color: catColor,
              padding: '2px 8px',
              borderRadius: 6,
              fontSize: 10,
              fontFamily: 'var(--nx-font-mono, monospace)',
              fontWeight: 600,
              letterSpacing: '0.06em',
            }}>
              {catName}
            </span>
          </div>

          {/* Owner address */}
          <div style={{
            fontFamily: 'var(--nx-font-mono, monospace)',
            fontSize: 11,
            color: '#475569',
            marginTop: 4,
          }}>
            {shortenAddr(owner)}
          </div>

          {/* Stats row */}
          <div style={{
            display: 'flex', gap: 16, marginTop: 12, flexWrap: 'wrap',
          }}>
            <Stat label="Tasks" value={totalTasksCompleted.toString()} />
            <Stat label="Staked" value={formatEth(stakedAmount)} />
            <Stat label="Tier" value={tier.label} color={tier.color} />
          </div>
        </div>
      </div>
    </Link>
  )
}

function Stat({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <div>
      <div style={{ fontSize: 10, color: '#475569', letterSpacing: '0.06em', marginBottom: 2 }}>
        {label}
      </div>
      <div style={{
        fontFamily: 'var(--nx-font-mono, monospace)',
        fontSize: 12,
        fontWeight: 600,
        color: color ?? '#94A3B8',
      }}>
        {value}
      </div>
    </div>
  )
}
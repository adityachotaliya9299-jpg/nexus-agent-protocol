'use client'

import { useParams } from 'next/navigation'
import { useReadContract } from 'wagmi'
import { ScoreRing } from '@/components/ScoreRing'
import { ReputationRadar } from '@/components/ReputationRadar'
import { ParticleField } from '@/components/ParticleField'
import {
  NEXUS_CONTRACTS, AGENT_REGISTRY_ABI, AGENT_DISCOVERY_ABI,
  CONTEXTUAL_REP_ABI, AGENT_STAKING_ABI,
  getTier, shortenAddr, formatEth, CATEGORIES, CATEGORY_COLORS,
} from '@/lib/nexus-contracts'

const SKILL_TIERS = ['–', 'BRONZE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND']
const SKILL_TIER_COLORS = ['#475569', '#CD7F32', '#94A3B8', '#F59E0B', '#06B6D4', '#F43F5E']

export default function AgentProfilePage() {
  const { id } = useParams()
  const agentId = BigInt(id as string)

  // Core profile
  const { data: agent, isLoading: agentLoading } = useReadContract({
    address: NEXUS_CONTRACTS.AgentRegistry,
    abi: AGENT_REGISTRY_ABI,
    functionName: 'getAgent',
    args: [agentId],
  })

  // Discovery profile (includes stake info)
  const { data: discoveryProfile } = useReadContract({
    address: NEXUS_CONTRACTS.AgentDiscovery,
    abi: AGENT_DISCOVERY_ABI,
    functionName: 'getAgentProfile',
    args: [agentId],
  })

  // Contextual reputation
  const { data: contextualProfile } = useReadContract({
    address: NEXUS_CONTRACTS.ContextualReputation,
    abi: CONTEXTUAL_REP_ABI,
    functionName: 'getProfile',
    args: [agentId],
  })

  // Staking
  const { data: stakeInfo } = useReadContract({
    address: NEXUS_CONTRACTS.AgentStaking,
    abi: AGENT_STAKING_ABI,
    functionName: 'getStake',
    args: [agentId],
  })

  if (agentLoading) return <AgentProfileSkeleton />
  if (!agent) return <NotFound id={id as string} />

  const score = Number(agent.reputationScore)
  const tier = getTier(score)
  const catName = CATEGORIES[agent.category] ?? 'GENERAL'
  const catColor = CATEGORY_COLORS[catName] ?? '#8B5CF6'
  const categoryScores = contextualProfile?.categoryScores.map(Number) ?? Array(6).fill(5000)
  const isActive = Number(agent.status) === 1

  return (
    <div style={{
      minHeight: '100vh',
      background: '#050510',
      fontFamily: "'Inter', sans-serif",
      color: '#F1F5F9',
    }}>

      {/* ── Hero banner ─────────────────────────────────────── */}
      <div style={{
        position: 'relative',
        padding: '60px 24px 48px',
        overflow: 'hidden',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
      }}>
        <ParticleField />

        {/* Background glow */}
        <div style={{
          position: 'absolute', inset: 0,
          background: `radial-gradient(ellipse at 30% 50%, ${tier.color}0C 0%, transparent 60%)`,
          pointerEvents: 'none',
        }} />
        {/* Tier accent bar */}
        <div style={{
          position: 'absolute', top: 0, left: 0, right: 0, height: 3,
          background: `linear-gradient(90deg, transparent, ${tier.color}, transparent)`,
        }} />

        <div style={{ maxWidth: 900, margin: '0 auto', position: 'relative' }}>

          {/* Back link */}
          <a href="/discover" style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            color: '#475569', fontSize: 13, textDecoration: 'none',
            marginBottom: 32,
            transition: 'color 200ms',
          }}
          onMouseEnter={e => (e.currentTarget.style.color = '#94A3B8')}
          onMouseLeave={e => (e.currentTarget.style.color = '#475569')}
          >
            ← Back to discovery
          </a>

          <div style={{ display: 'flex', gap: 32, alignItems: 'flex-start', flexWrap: 'wrap' }}>

            {/* Score ring — the signature */}
            <div style={{
              position: 'relative',
              animation: 'nx-fade-up 500ms ease both',
            }}>
              <ScoreRing score={score} size={140} strokeWidth={8} animated delay={100} />
              {/* Glow halo */}
              <div style={{
                position: 'absolute', inset: -12,
                borderRadius: '50%',
                background: `radial-gradient(circle, ${tier.color}18 0%, transparent 70%)`,
                pointerEvents: 'none',
                animation: 'nx-ring-pulse 3s ease-in-out infinite',
              }} />
            </div>

            {/* Agent info */}
            <div style={{ flex: 1, minWidth: 220, animation: 'nx-fade-up 500ms ease 80ms both' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 8 }}>
                <h1 style={{
                  fontFamily: "'Space Grotesk', sans-serif",
                  fontSize: 32, fontWeight: 700, margin: 0,
                  letterSpacing: '-0.02em',
                }}>
                  Agent #{id}
                </h1>
                <span style={{
                  width: 8, height: 8, borderRadius: '50%',
                  background: isActive ? '#10B981' : '#475569',
                  boxShadow: isActive ? '0 0 8px #10B981' : 'none',
                  flexShrink: 0,
                }} />
              </div>

              <div style={{
                fontFamily: "'JetBrains Mono', monospace",
                fontSize: 13, color: '#475569', marginBottom: 16,
              }}>
                {agent.owner}
              </div>

              {/* Badges row */}
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 24 }}>
                <Badge label={catName} color={catColor} />
                <Badge label={tier.label} color={tier.color} />
                <Badge label={isActive ? 'ACTIVE' : 'INACTIVE'} color={isActive ? '#10B981' : '#475569'} />
                <Badge label="EIGENLAYER AVS" color="#8B5CF6" />
              </div>

              {/* Quick stats */}
              <div style={{ display: 'flex', gap: 24, flexWrap: 'wrap' }}>
                <QuickStat label="Tasks Completed" value={agent.totalTasksCompleted.toString()} />
                <QuickStat label="Total Earned" value={formatEth(agent.totalEarned)} color="#10B981" />
                <QuickStat label="Staked" value={stakeInfo ? formatEth(stakeInfo.totalStaked) : '—'} color="#8B5CF6" />
                <QuickStat label="Slashes" value={stakeInfo?.slashCount.toString() ?? '0'} color={Number(stakeInfo?.slashCount ?? 0) > 0 ? '#F43F5E' : '#475569'} />
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ── Body ────────────────────────────────────────────── */}
      <div style={{ maxWidth: 900, margin: '0 auto', padding: '40px 24px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 24 }}>

          {/* Contextual Reputation Radar */}
          <Card title="Specialization" subtitle="Performance by category" delay={0}>
            <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 16 }}>
              <ReputationRadar scores={categoryScores} size={220} />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6 }}>
              {CATEGORIES.map((cat, i) => (
                <div key={cat} style={{
                  display: 'flex', justifyContent: 'space-between',
                  alignItems: 'center', padding: '6px 10px',
                  background: 'rgba(255,255,255,0.03)',
                  borderRadius: 8,
                }}>
                  <span style={{
                    fontSize: 10, fontWeight: 600, letterSpacing: '0.05em',
                    color: Object.values(CATEGORY_COLORS)[i],
                    fontFamily: "'JetBrains Mono', monospace",
                  }}>
                    {cat.slice(0, 4)}
                  </span>
                  <span style={{
                    fontFamily: "'JetBrains Mono', monospace",
                    fontSize: 11, fontWeight: 600,
                    color: '#F1F5F9',
                  }}>
                    {categoryScores[i].toLocaleString()}
                  </span>
                </div>
              ))}
            </div>
          </Card>

          {/* Staking Info */}
          <Card title="Stake" subtitle="Collateral and risk" delay={80}>
            {stakeInfo ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <StakeBar
                  label="Own Stake"
                  value={Number(stakeInfo.ownStake)}
                  total={Number(stakeInfo.totalStaked)}
                  color="#8B5CF6"
                />
                <StakeBar
                  label="Delegated"
                  value={Number(stakeInfo.delegatedStake)}
                  total={Number(stakeInfo.totalStaked)}
                  color="#06B6D4"
                />
                <StakeBar
                  label="Locked"
                  value={Number(stakeInfo.lockedStake)}
                  total={Number(stakeInfo.totalStaked)}
                  color="#F59E0B"
                />

                <div style={{ height: 1, background: 'rgba(255,255,255,0.06)', margin: '8px 0' }} />

                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ fontSize: 12, color: '#475569' }}>Total Staked</span>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, fontWeight: 700, color: '#8B5CF6' }}>
                    {formatEth(stakeInfo.totalStaked)}
                  </span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ fontSize: 12, color: '#475569' }}>Slash History</span>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, fontWeight: 700, color: Number(stakeInfo.slashCount) > 0 ? '#F43F5E' : '#10B981' }}>
                    {stakeInfo.slashCount.toString()} events
                  </span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ fontSize: 12, color: '#475569' }}>Total Slashed</span>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, fontWeight: 700, color: '#94A3B8' }}>
                    {formatEth(stakeInfo.totalSlashed)}
                  </span>
                </div>
              </div>
            ) : (
              <div style={{ color: '#475569', fontSize: 13, textAlign: 'center', padding: '40px 0' }}>
                No stake data available
              </div>
            )}
          </Card>

          {/* Skill Badges */}
          <Card title="Skills" subtitle="ERC-1155 earned badges" delay={160}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
              {CATEGORIES.map((cat, i) => {
                const tierIdx = Math.floor(Math.random() * 4) // replace with real data
                const tierColor = SKILL_TIER_COLORS[tierIdx]
                return (
                  <div key={cat} style={{
                    padding: '12px 8px',
                    background: tierIdx > 0 ? `${tierColor}12` : 'rgba(255,255,255,0.03)',
                    border: `1px solid ${tierIdx > 0 ? tierColor + '33' : 'rgba(255,255,255,0.06)'}`,
                    borderRadius: 10,
                    textAlign: 'center',
                    cursor: 'pointer',
                    transition: 'all 200ms ease',
                  }}
                  onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.04)'}
                  onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
                  >
                    <div style={{ fontSize: 20, marginBottom: 4 }}>
                      {['⬡', '🔶', '⬡', '🏆', '💎', '👑'][tierIdx]}
                    </div>
                    <div style={{
                      fontSize: 9, fontWeight: 700, letterSpacing: '0.06em',
                      color: Object.values(CATEGORY_COLORS)[i],
                      fontFamily: "'JetBrains Mono', monospace",
                    }}>
                      {cat.slice(0, 5)}
                    </div>
                    <div style={{
                      fontSize: 8, color: tierIdx > 0 ? tierColor : '#475569',
                      fontFamily: "'JetBrains Mono', monospace",
                      marginTop: 2, fontWeight: 600,
                    }}>
                      {SKILL_TIERS[tierIdx]}
                    </div>
                  </div>
                )
              })}
            </div>
            <p style={{ fontSize: 10, color: '#475569', margin: '12px 0 0', textAlign: 'center' }}>
              Earned by completing tasks in each category
            </p>
          </Card>

          {/* On-chain Identity */}
          <Card title="Identity" subtitle="Soulbound ERC-721 NFT" delay={240}>
            <div style={{
              background: `linear-gradient(135deg, ${tier.color}15, rgba(6,182,212,0.08))`,
              border: `1px solid ${tier.color}33`,
              borderRadius: 12,
              padding: '20px',
              marginBottom: 16,
              textAlign: 'center',
            }}>
              <div style={{
                fontFamily: "'Space Grotesk', sans-serif",
                fontSize: 11, fontWeight: 600, color: tier.color,
                letterSpacing: '0.12em', marginBottom: 12,
              }}>
                NEXUS AGENT IDENTITY
              </div>
              <ScoreRing score={score} size={80} strokeWidth={5} animated delay={400} />
              <div style={{
                fontFamily: "'JetBrains Mono', monospace",
                fontSize: 13, color: '#94A3B8', marginTop: 12,
              }}>
                #{id} · {catName}
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {[
                { label: 'Contract', value: shortenAddr(NEXUS_CONTRACTS.AgentIdentityNFT), link: `https://sepolia.etherscan.io/address/${NEXUS_CONTRACTS.AgentIdentityNFT}` },
                { label: 'Owner', value: shortenAddr(agent.owner), link: `https://sepolia.etherscan.io/address/${agent.owner}` },
                { label: 'Registered', value: new Date(Number(agent.registeredAt) * 1000).toLocaleDateString() },
                { label: 'Last Active', value: new Date(Number(agent.lastActiveAt) * 1000).toLocaleDateString() },
              ].map(row => (
                <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 12, color: '#475569' }}>{row.label}</span>
                  {row.link ? (
                    <a href={row.link} target="_blank" rel="noreferrer" style={{
                      fontFamily: "'JetBrains Mono', monospace",
                      fontSize: 12, color: '#8B5CF6', textDecoration: 'none',
                    }}>
                      {row.value} ↗
                    </a>
                  ) : (
                    <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: '#94A3B8' }}>
                      {row.value}
                    </span>
                  )}
                </div>
              ))}
            </div>
          </Card>

        </div>
      </div>

      <style>{`
        @keyframes nx-fade-up {
          from { opacity: 0; transform: translateY(16px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        @keyframes nx-ring-pulse {
          0%,100% { opacity: 0.6; }
          50%      { opacity: 1; }
        }
      `}</style>
    </div>
  )
}

// ── Sub-components ────────────────────────────────────────────

function Badge({ label, color }: { label: string; color: string }) {
  return (
    <span style={{
      background: color + '18',
      border: `1px solid ${color}44`,
      color, padding: '3px 10px',
      borderRadius: 100,
      fontSize: 10, fontWeight: 700,
      fontFamily: "'JetBrains Mono', monospace",
      letterSpacing: '0.08em',
    }}>
      {label}
    </span>
  )
}

function QuickStat({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <div>
      <div style={{ fontSize: 10, color: '#475569', letterSpacing: '0.06em', marginBottom: 3 }}>{label}</div>
      <div style={{
        fontFamily: "'JetBrains Mono', monospace",
        fontSize: 15, fontWeight: 700,
        color: color ?? '#F1F5F9',
      }}>
        {value}
      </div>
    </div>
  )
}

function Card({ title, subtitle, children, delay = 0 }: {
  title: string; subtitle: string; children: React.ReactNode; delay?: number
}) {
  return (
    <div style={{
      background: '#12122A',
      border: '1px solid rgba(139,92,246,0.18)',
      borderRadius: 16,
      padding: '24px',
      animation: `nx-fade-up 500ms ease ${delay}ms both`,
    }}>
      <div style={{ marginBottom: 20 }}>
        <h3 style={{
          fontFamily: "'Space Grotesk', sans-serif",
          fontSize: 16, fontWeight: 600, margin: 0, color: '#F1F5F9',
        }}>
          {title}
        </h3>
        <p style={{ margin: '3px 0 0', fontSize: 11, color: '#475569' }}>{subtitle}</p>
      </div>
      {children}
    </div>
  )
}

function StakeBar({ label, value, total, color }: {
  label: string; value: number; total: number; color: string
}) {
  const pct = total > 0 ? (value / total) * 100 : 0
  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
        <span style={{ fontSize: 11, color: '#475569' }}>{label}</span>
        <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color }}>
          {formatEth(BigInt(value))}
        </span>
      </div>
      <div style={{ height: 4, background: 'rgba(255,255,255,0.06)', borderRadius: 2, overflow: 'hidden' }}>
        <div style={{
          width: `${pct}%`, height: '100%',
          background: color, borderRadius: 2,
          transition: 'width 0.8s cubic-bezier(0.16,1,0.3,1)',
          boxShadow: `0 0 6px ${color}88`,
        }} />
      </div>
    </div>
  )
}

function AgentProfileSkeleton() {
  return (
    <div style={{ minHeight: '100vh', background: '#050510', padding: '80px 24px' }}>
      <div style={{ maxWidth: 900, margin: '0 auto' }}>
        {[140, 40, 40, 60].map((h, i) => (
          <div key={i} style={{
            height: h, background: 'rgba(255,255,255,0.04)',
            borderRadius: 12, marginBottom: 16,
            animation: `nx-fade-up 400ms ease ${i * 60}ms both`,
          }} />
        ))}
      </div>
      <style>{`@keyframes nx-fade-up { from { opacity:0; transform:translateY(16px) } to { opacity:1; transform:translateY(0) } }`}</style>
    </div>
  )
}

function NotFound({ id }: { id: string }) {
  return (
    <div style={{
      minHeight: '100vh', background: '#050510',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      flexDirection: 'column', gap: 16, fontFamily: "'Inter', sans-serif",
    }}>
      <div style={{ fontSize: 48 }}>🤖</div>
      <h2 style={{ color: '#F1F5F9', margin: 0, fontFamily: "'Space Grotesk', sans-serif" }}>
        Agent #{id} not found
      </h2>
      <p style={{ color: '#475569' }}>This agent may not be registered on Nexus.</p>
      <a href="/discover" style={{
        color: '#8B5CF6', textDecoration: 'none', fontSize: 14,
      }}>
        ← Back to discovery
      </a>
    </div>
  )
}
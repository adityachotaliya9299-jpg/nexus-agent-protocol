'use client'

import { useParams } from 'next/navigation'
import { useReadContract, useReadContracts } from 'wagmi'
import Link from 'next/link'
import { ExternalLink, Lock, ArrowUpRight, Award, Hexagon, Trophy, Gem, Crown, Medal } from 'lucide-react'
import { ReputationRadar } from '@/components/ReputationRadar'
import {
  CONTRACTS,
  AGENT_REGISTRY_ABI,
  CONTEXTUAL_REPUTATION_ABI,
  AGENT_STAKING_ABI,
  AGENT_SKILL_NFT_ABI,
  MOCK_AGENTS,
  CATEGORIES,
  CATEGORY_COLORS,
  getTier,
  shortenAddr,
} from '@/lib/contracts'

const SKILL_TIERS = ['—', 'Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond']
const SKILL_COLORS = ['#6B6355', '#CD7F32', '#B8C0CC', '#F2A93B', '#9BD4E4', '#C84B8E']
const SKILL_ICONS = [Hexagon, Medal, Award, Trophy, Gem, Crown]

function formatEth(wei: bigint) {
  const eth = Number(wei) / 1e18
  return eth === 0 ? '0 ETH' : `${eth.toFixed(4)} ETH`
}

function ScoreRing({ score, size = 150 }: { score: number; size?: number }) {
  const tier = getTier(score)
  const stroke = Math.max(6, size * 0.055)
  const r = (size - stroke - 4) / 2
  const circ = 2 * Math.PI * r
  const offset = circ - (Math.min(score, 10000) / 10000) * circ

  return (
    <div className="relative shrink-0" style={{ width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="#2A241B" strokeWidth={stroke} />
        <circle
          cx={size / 2} cy={size / 2} r={r} fill="none"
          stroke={tier.color} strokeWidth={stroke} strokeLinecap="round"
          strokeDasharray={circ} strokeDashoffset={offset}
          style={{ filter: `drop-shadow(0 0 8px ${tier.color}77)`, transition: 'stroke-dashoffset 0.9s cubic-bezier(0.16,1,0.3,1)' }}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="font-mono font-bold leading-none" style={{ color: tier.color, fontSize: size * 0.16 }}>
          {score.toLocaleString()}
        </span>
        <span className="font-mono uppercase tracking-[0.12em] mt-1" style={{ color: '#6B6355', fontSize: Math.max(7, size * 0.062) }}>
          {tier.label}
        </span>
      </div>
    </div>
  )
}

function StakeBar({ label, value, total, color }: { label: string; value: bigint; total: bigint; color: string }) {
  const pct = total > 0n ? Number((value * 10000n) / total) / 100 : 0
  return (
    <div>
      <div className="flex justify-between mb-1.5">
        <span className="label">{label}</span>
        <span className="font-mono text-xs font-semibold" style={{ color }}>{formatEth(value)}</span>
      </div>
      <div className="rep-bar">
        <div
          className="h-full rounded-full transition-all duration-700"
          style={{ width: `${pct}%`, background: color, boxShadow: `0 0 5px ${color}66` }}
        />
      </div>
    </div>
  )
}

export default function AgentProfilePage() {
  const { id } = useParams()
  const agentId = BigInt(id as string)
  const agentIdNum = Number(id)

  const { data: onChainAgent, isLoading } = useReadContract({
    address: CONTRACTS.AgentRegistry,
    abi: AGENT_REGISTRY_ABI,
    functionName: 'getAgent',
    args: [agentId],
  })

  const { data: contextualProfile } = useReadContract({
    address: CONTRACTS.ContextualReputation,
    abi: CONTEXTUAL_REPUTATION_ABI,
    functionName: 'getProfile',
    args: [agentId],
    query: { enabled: !!onChainAgent },
  })

  const { data: stakeInfo } = useReadContract({
    address: CONTRACTS.AgentStaking,
    abi: AGENT_STAKING_ABI,
    functionName: 'getStake',
    args: [agentId],
    query: { enabled: !!onChainAgent },
  })

  // one read per category — the ERC-1155 badge ladder
  const { data: skillBadges } = useReadContracts({
    contracts: CATEGORIES.map((_, i) => ({
      address: CONTRACTS.AgentSkillNFT,
      abi: AGENT_SKILL_NFT_ABI as any,
      functionName: 'getSkillBadge',
      args: [agentId, BigInt(i)],
    })),
    query: { enabled: !!onChainAgent },
  })

  const mockAgent = MOCK_AGENTS.find(a => a.agentId === agentIdNum)

  const agent = onChainAgent
    ? {
        agentId: agentIdNum,
        owner: (onChainAgent as any).owner as string,
        agentWallet: (onChainAgent as any).agentWallet as string,
        name: mockAgent?.name ?? `Agent #${id}`,
        description: mockAgent?.description ?? '',
        capabilities: mockAgent?.capabilities ?? [],
        category: Number((onChainAgent as any).category),
        status: Number((onChainAgent as any).status),
        reputationScore: Number((onChainAgent as any).reputationScore),
        totalTasksCompleted: Number((onChainAgent as any).totalTasksCompleted),
        totalEarned: (onChainAgent as any).totalEarned as bigint,
        registeredAt: Number((onChainAgent as any).registeredAt),
        lastActiveAt: Number((onChainAgent as any).lastActiveAt),
        isOnChain: true,
      }
    : mockAgent
    ? { ...mockAgent, name: mockAgent.name ?? `Agent #${id}`, description: mockAgent.description ?? '', capabilities: mockAgent.capabilities ?? [], isOnChain: false }
    : null

  if (isLoading && !mockAgent) return <Skeleton />

  if (!agent) {
    return (
      <div className="min-h-[70vh] flex flex-col items-center justify-center gap-4 px-6 text-center">
        <div className="w-16 h-16 rounded-2xl border border-border bg-surface flex items-center justify-center">
          <Hexagon className="text-text-muted" />
        </div>
        <h2 className="font-display font-bold text-2xl text-bone">Agent #{id} not found</h2>
        <p className="text-text-secondary">This agent is not registered on AGORA.</p>
        <Link href="/agents" className="btn-secondary mt-2">← Back to agents</Link>
      </div>
    )
  }

  const catName = CATEGORIES[agent.category] ?? 'GENERAL'
  const catColor = CATEGORY_COLORS[catName] ?? '#8C8474'
  const tier = getTier(agent.reputationScore)
  const isActive = agent.status === 1
  const info = stakeInfo as any
  const totalS: bigint = info?.totalStaked ?? 0n

  // real contextual scores only — zeros mean "no data", never invented numbers.
  // demo agents get a plausible spread so the showcase isn't empty.
  const catScores: number[] = agent.isOnChain
    ? ((contextualProfile as any)?.categoryScores?.map(Number) ?? Array(6).fill(0))
    : CATEGORIES.map((_, i) =>
        i === agent.category
          ? agent.reputationScore
          : Math.max(0, agent.reputationScore - 2600 - ((agent.agentId * 37 + i * 613) % 2200)),
      )

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12">
      <div className="flex items-center gap-4 mb-8 flex-wrap">
        <Link href="/agents" className="text-text-secondary hover:text-bone text-sm transition-colors">
          ← All agents
        </Link>
        {!agent.isOnChain && <span className="badge badge-pending">Showcase profile — not on Sepolia</span>}
      </div>

      {/* header */}
      <div className="relative mb-6 overflow-hidden rounded-3xl border border-border bg-surface p-6 sm:p-10">
        <div
          className="absolute top-0 left-0 right-0 h-[3px]"
          style={{ background: `linear-gradient(90deg, transparent, ${tier.color}, transparent)` }}
        />
        <div
          className="absolute inset-0 pointer-events-none"
          style={{ background: `radial-gradient(ellipse 60% 90% at 85% 10%, ${tier.color}0E, transparent 60%)` }}
        />

        <div className="relative flex flex-col md:flex-row gap-8 md:items-center">
          <div className="flex-1 min-w-0 order-2 md:order-1">
            <div className="ag-eyebrow mb-3" style={{ color: catColor }}>
              Agent #{String(id).padStart(3, '0')} · {catName}
            </div>
            <div className="flex items-center gap-3 flex-wrap">
              <h1 className="ag-h1 text-3xl sm:text-4xl lg:text-5xl break-words">{agent.name}</h1>
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ background: isActive ? '#57C99B' : '#6B6355', boxShadow: isActive ? '0 0 8px #57C99B' : 'none' }}
                title={isActive ? 'Active' : 'Inactive'}
              />
            </div>

            {agent.description && (
              <p className="mt-4 text-text-secondary leading-relaxed max-w-2xl">{agent.description}</p>
            )}

            <div className="flex flex-wrap gap-2 mt-5">
              <span className="badge" style={{ background: `${tier.color}12`, color: tier.color, border: `1px solid ${tier.color}30` }}>
                {tier.label}
              </span>
              <span className={isActive ? 'badge-active' : 'badge-inactive'}>{isActive ? 'ACTIVE' : 'INACTIVE'}</span>
              {agent.isOnChain && <span className="badge-violet">EigenLayer AVS</span>}
            </div>

            {agent.capabilities.length > 0 && (
              <div className="flex flex-wrap gap-1.5 mt-5">
                {agent.capabilities.map(cap => (
                  <span key={cap} className="px-2.5 py-1 rounded-full text-[10px] font-mono text-text-secondary border border-border bg-void">
                    {cap}
                  </span>
                ))}
              </div>
            )}

            <div className="flex flex-wrap gap-3 mt-7">
              <Link href={`/escrow/create${agent.agentWallet ? `?agent=${agent.agentWallet}` : ''}`} className="btn-primary text-sm">
                Hire with ZK escrow <ArrowUpRight size={15} />
              </Link>
              <Link href="/subscriptions" className="btn-secondary text-sm">Subscribe</Link>
            </div>
          </div>

          <div className="order-1 md:order-2 flex md:block justify-center">
            <ScoreRing score={agent.reputationScore} size={150} />
          </div>
        </div>
      </div>

      {/* stat band */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-px bg-border rounded-3xl overflow-hidden border border-border mb-6">
        {[
          { label: 'Tasks completed', value: agent.totalTasksCompleted.toLocaleString(), color: '#F4EFE6' },
          { label: 'Total earned', value: formatEth(agent.totalEarned), color: '#57C99B' },
          { label: 'Staked', value: formatEth(totalS), color: '#FF6B3D' },
          { label: 'Slashes', value: (info?.slashCount ?? 0n).toString(), color: Number(info?.slashCount ?? 0n) > 0 ? '#E5484D' : '#F4EFE6' },
        ].map(s => (
          <div key={s.label} className="bg-surface p-5 sm:p-6 min-w-0">
            <div className="label mb-2">{s.label}</div>
            <div className="font-display font-bold text-lg sm:text-xl truncate" style={{ color: s.color }}>{s.value}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* specialization */}
        <div className="ag-panel p-6 sm:p-8">
          <h3 className="font-display font-bold text-xl text-bone">Specialization</h3>
          <p className="label mt-1 mb-6">Per-category reputation (on-chain)</p>
          <div className="flex justify-center mb-6">
            <ReputationRadar scores={catScores} size={230} />
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
            {CATEGORIES.map((cat, i) => (
              <div key={cat} className="flex justify-between items-center px-3.5 py-2.5 rounded-xl bg-void border border-border/60">
                <span className="font-mono text-[10px] font-semibold tracking-wider" style={{ color: CATEGORY_COLORS[cat] }}>
                  {cat}
                </span>
                <span className="font-mono text-xs text-bone font-semibold tabular-nums">
                  {(catScores[i] ?? 0).toLocaleString()}
                </span>
              </div>
            ))}
          </div>
          {agent.isOnChain && catScores.every(s => s === 0) && (
            <p className="text-text-muted text-xs mt-4 font-mono">
              Scores appear after the agent completes categorised tasks.
            </p>
          )}
        </div>

        {/* stake */}
        <div className="ag-panel p-6 sm:p-8">
          <h3 className="font-display font-bold text-xl text-bone">Stake</h3>
          <p className="label mt-1 mb-6">Collateral and risk</p>

          {totalS === 0n ? (
            <div className="flex flex-col items-center justify-center py-12 text-center">
              <div className="w-14 h-14 rounded-2xl border border-border bg-void flex items-center justify-center mb-4">
                <Lock size={20} className="text-gold" />
              </div>
              <p className="text-text-secondary text-sm">No stake on-chain yet.</p>
              {agent.isOnChain && (
                <Link href="/dashboard/stake" className="btn-primary mt-5 text-xs">Stake ETH →</Link>
              )}
            </div>
          ) : (
            <div className="space-y-4">
              <StakeBar label="Own stake" value={info?.ownStake ?? 0n} total={totalS} color="#F2A93B" />
              <StakeBar label="Delegated" value={info?.delegatedStake ?? 0n} total={totalS} color="#FF6B3D" />
              <StakeBar label="Locked" value={info?.lockedStake ?? 0n} total={totalS} color="#64B6E7" />
              <div className="border-t border-border pt-4 space-y-2">
                {[
                  { label: 'Total staked', val: totalS, color: '#F2A93B' },
                  { label: 'Total slashed', val: info?.totalSlashed ?? 0n, color: '#E5484D' },
                ].map(({ label, val, color }) => (
                  <div key={label} className="flex justify-between">
                    <span className="text-text-secondary text-sm">{label}</span>
                    <span className="font-mono text-sm font-semibold" style={{ color }}>{formatEth(val)}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* skills */}
        <div className="ag-panel p-6 sm:p-8">
          <h3 className="font-display font-bold text-xl text-bone">Skills</h3>
          <p className="label mt-1 mb-6">ERC-1155 badges earned by completed work</p>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            {CATEGORIES.map((cat, i) => {
              const badge = skillBadges?.[i]?.status === 'success' ? (skillBadges[i].result as any) : null
              const completions = badge ? Number(badge.completions) : 0
              const tierIdx = completions > 0 ? Math.min(Number(badge.tier) + 1, 5) : 0
              const TierIcon = SKILL_ICONS[tierIdx]
              const tColor = SKILL_COLORS[tierIdx]
              return (
                <div
                  key={cat}
                  className="flex flex-col items-center gap-1.5 p-4 rounded-2xl border transition-transform duration-200 hover:scale-[1.03]"
                  style={{
                    background: tierIdx > 0 ? `${tColor}0E` : 'var(--ag-void)',
                    borderColor: tierIdx > 0 ? `${tColor}30` : 'var(--ag-border)',
                  }}
                >
                  <TierIcon size={20} style={{ color: tierIdx > 0 ? tColor : '#3A3226' }} strokeWidth={1.5} />
                  <span className="font-mono text-[9px] font-bold tracking-wider" style={{ color: CATEGORY_COLORS[cat] }}>
                    {cat}
                  </span>
                  <span className="font-mono text-[9px]" style={{ color: tierIdx > 0 ? tColor : '#6B6355' }}>
                    {SKILL_TIERS[tierIdx]}{completions > 0 ? ` · ${completions}` : ''}
                  </span>
                </div>
              )
            })}
          </div>
          {agent.isOnChain && (!skillBadges || skillBadges.every(b => b.status !== 'success' || Number((b.result as any)?.completions ?? 0) === 0)) && (
            <p className="text-text-muted text-xs mt-4 font-mono">
              Badges mint automatically as the agent completes tasks in each category.
            </p>
          )}
        </div>

        {/* identity */}
        <div className="ag-panel p-6 sm:p-8">
          <h3 className="font-display font-bold text-xl text-bone">Identity</h3>
          <p className="label mt-1 mb-6">Soulbound ERC-721 profile</p>

          <div
            className="rounded-2xl border p-6 mb-6 flex items-center gap-5"
            style={{ background: `linear-gradient(135deg, ${tier.color}0E, rgba(242,169,59,0.04))`, borderColor: `${tier.color}28` }}
          >
            <ScoreRing score={agent.reputationScore} size={92} />
            <div className="min-w-0">
              <div className="label text-gold mb-1.5">AGORA identity</div>
              <div className="font-display font-bold text-bone text-lg truncate">{agent.name}</div>
              <div className="font-mono text-xs text-text-secondary mt-1">
                #{id} · {catName} · {tier.label}
              </div>
            </div>
          </div>

          <div className="space-y-3">
            {[
              { label: 'NFT contract', value: shortenAddr(CONTRACTS.AgentIdentityNFT), link: `https://sepolia.etherscan.io/address/${CONTRACTS.AgentIdentityNFT}` },
              { label: 'Owner', value: shortenAddr(agent.owner), link: `https://sepolia.etherscan.io/address/${agent.owner}` },
              { label: 'Agent wallet', value: agent.agentWallet && agent.agentWallet !== '0x0000000000000000000000000000000000000000' ? shortenAddr(agent.agentWallet) : 'Not set', link: agent.agentWallet && agent.agentWallet !== '0x0000000000000000000000000000000000000000' ? `https://sepolia.etherscan.io/address/${agent.agentWallet}` : undefined },
              { label: 'Registered', value: agent.registeredAt > 0 ? new Date(agent.registeredAt * 1000).toLocaleDateString() : '—' },
              { label: 'Last active', value: agent.lastActiveAt > 0 ? new Date(agent.lastActiveAt * 1000).toLocaleDateString() : '—' },
            ].map(row => (
              <div key={row.label} className="flex justify-between items-center gap-4">
                <span className="text-text-secondary text-sm">{row.label}</span>
                {row.link ? (
                  <a href={row.link} target="_blank" rel="noreferrer" className="flex items-center gap-1 font-mono text-xs text-gold hover:underline">
                    {row.value} <ExternalLink className="w-3 h-3" />
                  </a>
                ) : (
                  <span className="font-mono text-xs text-text-secondary">{row.value}</span>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}

function Skeleton() {
  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 space-y-5">
      {[260, 90, 340].map((h, i) => (
        <div key={i} className="card animate-pulse" style={{ height: h }} />
      ))}
    </div>
  )
}

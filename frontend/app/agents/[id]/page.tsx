'use client'

import { useParams } from 'next/navigation'
import { useReadContract } from 'wagmi'
import Link from 'next/link'
import { ExternalLink } from 'lucide-react'
import { ReputationRadar } from '@/components/ReputationRadar'
import {
  CONTRACTS,
  AGENT_REGISTRY_ABI,
  AGENT_DISCOVERY_ABI,
  CONTEXTUAL_REPUTATION_ABI,
  AGENT_STAKING_ABI,
  MOCK_AGENTS,
} from '@/lib/contracts'

// ── Helpers ───────────────────────────────────────────────────

const CATEGORIES = ['GENERAL','CODE','RESEARCH','TRADING','CREATIVE','ORCHESTRATOR']
const CAT_COLORS: Record<string, string> = {
  GENERAL:'#6B6355', CODE:'#FF6B3D', RESEARCH:'#F2A93B',
  TRADING:'#57C99B', CREATIVE:'#F2A93B', ORCHESTRATOR:'#C84B8E',
}
const SKILL_TIERS  = ['–','BRONZE','SILVER','GOLD','PLATINUM','DIAMOND']
const SKILL_COLORS = ['#475569','#CD7F32','#94A3B8','#F2A93B','#F2A93B','#C84B8E']

function getTier(score: number) {
  if (score >= 10000) return { label: 'Elite',       color: '#C84B8E' }
  if (score >= 8000)  return { label: 'Expert',      color: '#F2A93B' }
  if (score >= 6000)  return { label: 'Advanced',    color: '#FF6B3D' }
  if (score >= 4000)  return { label: 'Established', color: '#57C99B' }
  if (score >= 2000)  return { label: 'Rising',      color: '#F2A93B' }
  return                    { label: 'Novice',       color: '#6B6355' }
}

function shortenAddr(addr: string) {
  return `${addr.slice(0,6)}…${addr.slice(-4)}`
}

function formatEth(wei: bigint) {
  const eth = Number(wei) / 1e18
  return eth === 0 ? '0 ETH' : `${eth.toFixed(4)} ETH`
}

// ── Score Ring ────────────────────────────────────────────────

function ScoreRing({ score, size = 120 }: { score: number; size?: number }) {
  const tier = getTier(score)
  const r    = (size - 10) / 2
  const circ = 2 * Math.PI * r
  const offset = circ - (Math.min(score, 10000) / 10000) * circ

  return (
    <div style={{ position:'relative', width:size, height:size, flexShrink:0 }}>
      <svg width={size} height={size} style={{ transform:'rotate(-90deg)' }}>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="#2A241B" strokeWidth={8} />
        <circle
          cx={size/2} cy={size/2} r={r} fill="none"
          stroke={tier.color} strokeWidth={8} strokeLinecap="round"
          strokeDasharray={circ} strokeDashoffset={offset}
          style={{ filter:`drop-shadow(0 0 8px ${tier.color}88)`, transition:'all 0.9s cubic-bezier(0.16,1,0.3,1)' }}
        />
      </svg>
      <div style={{ position:'absolute', inset:0, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center' }}>
        <span style={{ fontFamily:'IBM Plex Mono,monospace', fontSize:20, fontWeight:700, color:tier.color, lineHeight:1 }}>
          {score.toLocaleString()}
        </span>
        <span style={{ fontFamily:'IBM Plex Mono,monospace', fontSize:9, color:'#6B6355', letterSpacing:'0.08em', marginTop:4 }}>
          {tier.label.toUpperCase()}
        </span>
      </div>
    </div>
  )
}

// ── Stake Bar ─────────────────────────────────────────────────

function StakeBar({ label, value, total, color }: { label:string; value:bigint; total:bigint; color:string }) {
  const pct = total > 0n ? Number((value * 10000n) / total) / 100 : 0
  return (
    <div>
      <div className="flex justify-between mb-1.5">
        <span className="label">{label}</span>
        <span className="font-mono text-xs font-semibold" style={{ color }}>
          {formatEth(value)}
        </span>
      </div>
      <div className="rep-bar">
        <div className="h-full rounded-full transition-all duration-700"
          style={{ width:`${pct}%`, background:color, boxShadow:`0 0 5px ${color}66` }} />
      </div>
    </div>
  )
}

// ── Main Page ─────────────────────────────────────────────────

export default function AgentProfilePage() {
  const { id } = useParams()
  const agentId = BigInt(id as string)
  const agentIdNum = Number(id)

  // Try on-chain first
  const { data: onChainAgent, isLoading, error } = useReadContract({
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

  // Fall back to mock data if not on-chain
  const mockAgent = MOCK_AGENTS.find(a => a.agentId === agentIdNum)

  // Build unified agent object
  const agent = onChainAgent
    ? {
        agentId:             agentIdNum,
        owner:               (onChainAgent as any).owner,
        agentWallet:         (onChainAgent as any).agentWallet,
        name:                mockAgent?.name ?? `Agent #${id}`,
        description:         mockAgent?.description ?? 'Autonomous AI agent on AGORA.',
        capabilities:        mockAgent?.capabilities ?? [],
        category:            Number((onChainAgent as any).category),
        status:              Number((onChainAgent as any).status),
        reputationScore:     Number((onChainAgent as any).reputationScore),
        totalTasksCompleted: Number((onChainAgent as any).totalTasksCompleted),
        totalEarned:         (onChainAgent as any).totalEarned as bigint,
        registeredAt:        Number((onChainAgent as any).registeredAt),
        lastActiveAt:        Number((onChainAgent as any).lastActiveAt),
        isOnChain:           true,
      }
    : mockAgent
    ? {
        agentId:             mockAgent.agentId,
        owner:               mockAgent.owner,
        agentWallet:         mockAgent.agentWallet,
        name:                mockAgent.name ?? `Agent #${id}`,
        description:         mockAgent.description ?? '',
        capabilities:        mockAgent.capabilities ?? [],
        category:            mockAgent.category,
        status:              mockAgent.status,
        reputationScore:     mockAgent.reputationScore,
        totalTasksCompleted: mockAgent.totalTasksCompleted,
        totalEarned:         mockAgent.totalEarned,
        registeredAt:        mockAgent.registeredAt,
        lastActiveAt:        mockAgent.lastActiveAt,
        isOnChain:           false,
      }
    : null

  if (isLoading && !mockAgent) {
    return <Skeleton />
  }

  if (!agent) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center gap-4">
        <div className="text-5xl">🤖</div>
        <h2 className="font-display font-bold text-2xl text-[#F4EFE6]">Agent #{id} not found</h2>
        <p className="text-[#A89F8D]">This agent is not registered on AGORA.</p>
        <Link href="/discover" className="text-cyan hover:underline text-sm">← Back to discovery</Link>
      </div>
    )
  }

  const catName   = CATEGORIES[agent.category] ?? 'GENERAL'
  const catColor  = CAT_COLORS[catName] ?? '#6B6355'
  const tier      = getTier(agent.reputationScore)
  const isActive  = agent.status === 1
  const info      = stakeInfo as any
  const totalS    = info?.totalStaked    ?? 0n
  const ownS      = info?.ownStake       ?? 0n
  const delegS    = info?.delegatedStake ?? 0n
  const lockedS   = info?.lockedStake    ?? 0n
  const catScores = (contextualProfile as any)?.categoryScores?.map(Number)
    ?? Array(6).fill(agent.reputationScore > 0 ? Math.floor(agent.reputationScore / 2) : 0)

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">

      {/* Back + mock warning */}
      <div className="flex items-center gap-4 mb-8">
        <Link href="/discover" className="text-[#A89F8D] hover:text-[#F4EFE6] text-sm transition-colors">
          ← Back to discovery
        </Link>
        {!agent.isOnChain && (
          <span className="badge badge-pending">Demo data — not registered on Sepolia</span>
        )}
      </div>

      {/* ── Hero ──────────────────────────────────────────────── */}
      <div className="relative mb-10 overflow-hidden rounded-xl border border-[#2A241B] bg-[#14110D] p-8">
        {/* Top accent bar */}
        <div style={{ position:'absolute', top:0, left:0, right:0, height:3,
          background:`linear-gradient(90deg, transparent, ${tier.color}, transparent)` }} />
        {/* Glow bg */}
        <div style={{ position:'absolute', inset:0, background:`radial-gradient(ellipse at 20% 50%, ${tier.color}08 0%, transparent 60%)`, pointerEvents:'none' }} />

        <div className="flex flex-col sm:flex-row gap-8 items-start relative">
          <ScoreRing score={agent.reputationScore} />

          <div className="flex-1">
            <div className="flex items-center gap-3 flex-wrap mb-2">
              <h1 className="font-display font-bold text-3xl text-[#F4EFE6]">{agent.name}</h1>
              <span className="w-2 h-2 rounded-full" style={{ background: isActive ? '#57C99B' : '#6B6355', boxShadow: isActive ? '0 0 6px #57C99B' : 'none' }} />
            </div>

            <div className="address mb-4">{agent.owner}</div>

            {/* Badges */}
            <div className="flex flex-wrap gap-2 mb-5">
              <span className="badge" style={{ background:`${catColor}12`, color:catColor, border:`1px solid ${catColor}28` }}>
                {catName}
              </span>
              <span className="badge" style={{ background:`${tier.color}12`, color:tier.color, border:`1px solid ${tier.color}28` }}>
                {tier.label}
              </span>
              <span className="badge-active">{isActive ? 'ACTIVE' : 'INACTIVE'}</span>
              {agent.isOnChain && <span className="badge-violet">EIGENLAYER AVS</span>}
              {!agent.isOnChain && <span className="badge badge-pending">DEMO</span>}
            </div>

            {/* Description */}
            {agent.description && (
              <p className="text-[#A89F8D] text-sm mb-5 max-w-xl leading-relaxed">{agent.description}</p>
            )}

            {/* Capabilities */}
            {agent.capabilities && agent.capabilities.length > 0 && (
              <div className="flex flex-wrap gap-1.5 mb-5">
                {agent.capabilities.map(cap => (
                  <span key={cap} className="px-2 py-0.5 rounded text-[10px] font-mono text-[#A89F8D] border border-[#2A241B] bg-[#0B0A08]">
                    {cap}
                  </span>
                ))}
              </div>
            )}

            {/* Quick stats */}
            <div className="flex gap-8 flex-wrap">
              {[
                { label: 'Tasks Completed', value: agent.totalTasksCompleted.toString() },
                { label: 'Total Earned',    value: typeof agent.totalEarned === 'bigint' ? formatEth(agent.totalEarned) : `${agent.totalEarned} ETH`, color: '#57C99B' },
                { label: 'Staked',          value: formatEth(totalS),  color: '#FF6B3D' },
                { label: 'Slashes',         value: (info?.slashCount ?? 0n).toString(), color: Number(info?.slashCount ?? 0n) > 0 ? '#C84B8E' : undefined },
              ].map(s => (
                <div key={s.label}>
                  <div className="label mb-1">{s.label}</div>
                  <div className="font-display font-bold text-lg" style={{ color: s.color ?? '#F4EFE6' }}>{s.value}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* ── Cards grid ────────────────────────────────────────── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">

        {/* Specialization radar */}
        <div className="card p-6">
          <h3 className="font-display font-semibold text-[#F4EFE6] mb-1">Specialization</h3>
          <p className="label mb-5">Performance by category</p>
          <div className="flex justify-center mb-4">
            <ReputationRadar scores={catScores} size={220} />
          </div>
          <div className="grid grid-cols-2 gap-2">
            {CATEGORIES.map((cat, i) => (
              <div key={cat} className="flex justify-between items-center px-3 py-2 rounded-md bg-[#0B0A08]">
                <span className="font-mono text-[10px] font-semibold" style={{ color: Object.values(CAT_COLORS)[i] }}>
                  {cat.slice(0,5)}
                </span>
                <span className="font-mono text-xs text-[#F4EFE6] font-semibold">
                  {(catScores[i] ?? 0).toLocaleString()}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Stake panel */}
        <div className="card p-6">
          <h3 className="font-display font-semibold text-[#F4EFE6] mb-1">Stake</h3>
          <p className="label mb-5">Collateral and risk</p>

          {totalS === 0n ? (
            <div className="flex flex-col items-center justify-center py-10 text-center">
              <div className="text-3xl mb-3">🔒</div>
              <p className="text-[#A89F8D] text-sm">No stake on-chain yet.</p>
              {agent.isOnChain && (
                <Link href="/dashboard/stake" className="btn-primary mt-4 text-xs">
                  Stake ETH →
                </Link>
              )}
            </div>
          ) : (
            <div className="space-y-4">
              <StakeBar label="Own Stake"       value={ownS}    total={totalS} color="#F2A93B" />
              <StakeBar label="Delegated Stake" value={delegS}  total={totalS} color="#FF6B3D" />
              <StakeBar label="Locked"          value={lockedS} total={totalS} color="#F2A93B" />
              <div className="border-t border-[#2A241B] pt-4 space-y-2">
                {[
                  { label:'Total Staked',    val:totalS,                    color:'#F2A93B' },
                  { label:'Effective Stake', val:info?.effectiveStake ?? 0n, color:'#FF6B3D' },
                  { label:'Total Slashed',   val:info?.totalSlashed ?? 0n,   color:'#C84B8E' },
                ].map(({ label, val, color }) => (
                  <div key={label} className="flex justify-between">
                    <span className="text-[#A89F8D] text-sm">{label}</span>
                    <span className="font-mono text-sm font-semibold" style={{ color }}>{formatEth(val)}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Skill badges */}
        <div className="card p-6">
          <h3 className="font-display font-semibold text-[#F4EFE6] mb-1">Skills</h3>
          <p className="label mb-5">ERC-1155 earned badges</p>
          <div className="grid grid-cols-3 gap-3">
            {CATEGORIES.map((cat, i) => {
              const tierIdx = i === agent.category ? Math.min(Math.floor(agent.reputationScore / 2000), 5) : 0
              const tColor  = SKILL_COLORS[tierIdx]
              const catCol  = Object.values(CAT_COLORS)[i]
              return (
                <div key={cat}
                  className="flex flex-col items-center gap-1 p-3 rounded-lg border transition-all duration-200 hover:scale-105"
                  style={{ background: tierIdx > 0 ? `${tColor}10` : '#0B0A08', borderColor: tierIdx > 0 ? `${tColor}25` : '#2A241B' }}
                >
                  <div className="text-xl">{['⬡','🔶','⬡','🏆','💎','👑'][tierIdx]}</div>
                  <span className="font-mono text-[9px] font-bold" style={{ color: catCol }}>{cat.slice(0,5)}</span>
                  <span className="font-mono text-[8px]" style={{ color: tierIdx > 0 ? tColor : '#6B6355' }}>
                    {SKILL_TIERS[tierIdx]}
                  </span>
                </div>
              )
            })}
          </div>
        </div>

        {/* Identity */}
        <div className="card p-6">
          <h3 className="font-display font-semibold text-[#F4EFE6] mb-1">Identity</h3>
          <p className="label mb-5">On-chain profile</p>

          {/* Mini NFT card */}
          <div className="rounded-lg border p-5 text-center mb-5"
            style={{ background:`linear-gradient(135deg, ${tier.color}10, rgba(242,169,59,0.05))`, borderColor:`${tier.color}25` }}>
            <div className="label text-cyan mb-3">AGORA AGENT IDENTITY</div>
            <ScoreRing score={agent.reputationScore} size={80} />
            <div className="font-mono text-xs text-[#A89F8D] mt-3">#{id} · {catName}</div>
          </div>

          <div className="space-y-3">
            {[
              { label:'Contract', value: shortenAddr(CONTRACTS.AgentIdentityNFT), link:`https://sepolia.etherscan.io/address/${CONTRACTS.AgentIdentityNFT}` },
              { label:'Owner',    value: shortenAddr(agent.owner), link:`https://sepolia.etherscan.io/address/${agent.owner}` },
              { label:'Registered', value: agent.registeredAt > 0 ? new Date(agent.registeredAt * 1000).toLocaleDateString() : '—' },
              { label:'Last Active', value: agent.lastActiveAt > 0 ? new Date(agent.lastActiveAt * 1000).toLocaleDateString() : '—' },
            ].map(row => (
              <div key={row.label} className="flex justify-between items-center">
                <span className="text-[#A89F8D] text-sm">{row.label}</span>
                {row.link ? (
                  <a href={row.link} target="_blank" rel="noreferrer"
                    className="flex items-center gap-1 font-mono text-xs text-cyan hover:underline">
                    {row.value} <ExternalLink className="w-3 h-3" />
                  </a>
                ) : (
                  <span className="font-mono text-xs text-[#A89F8D]">{row.value}</span>
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
      {[200, 60, 60].map((h, i) => (
        <div key={i} className="card animate-pulse" style={{ height: h }} />
      ))}
    </div>
  )
}
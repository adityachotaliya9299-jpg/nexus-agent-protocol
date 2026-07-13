'use client'

import { useState } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import { Shield, TrendingUp, Lock, AlertTriangle, CheckCircle, Loader2, ExternalLink } from 'lucide-react'
import { CONTRACTS, AGENT_REGISTRY_ABI, AGENT_STAKING_ABI } from '@/lib/contracts'

function getTier(score: number) {
  if (score >= 10000) return { label: 'Elite',       color: '#C84B8E' }
  if (score >= 8000)  return { label: 'Expert',      color: '#F2A93B' }
  if (score >= 6000)  return { label: 'Advanced',    color: '#FF6B3D' }
  if (score >= 4000)  return { label: 'Established', color: '#57C99B' }
  if (score >= 2000)  return { label: 'Rising',      color: '#F2A93B' }
  return                    { label: 'Novice',       color: '#6B6355' }
}

function StakeBar({ label, value, total, color }: { label: string; value: bigint; total: bigint; color: string }) {
  const pct = total > 0n ? Number((value * 10000n) / total) / 100 : 0
  return (
    <div>
      <div className="flex justify-between items-center mb-1.5">
        <span className="label">{label}</span>
        <span className="font-mono text-xs font-semibold" style={{ color }}>
          {Number(formatEther(value)).toFixed(4)} ETH
        </span>
      </div>
      <div className="rep-bar">
        <div
          className="h-full rounded-full transition-all duration-700"
          style={{ width: `${pct}%`, background: color, boxShadow: `0 0 6px ${color}88` }}
        />
      </div>
    </div>
  )
}

export default function StakePage() {
  const { address } = useAccount()
  const [stakeAmount, setStakeAmount]  = useState('')
  const [unstakeAmount, setUnstakeAmount] = useState('')
  const [activeTab, setActiveTab]      = useState<'stake' | 'unstake'>('stake')

  // Get agent ID
  const { data: agentId } = useReadContract({
    address: CONTRACTS.AgentRegistry,
    abi: AGENT_REGISTRY_ABI,
    functionName: 'getAgentByOwner',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })

  // Get agent profile
  const { data: agent } = useReadContract({
    address: CONTRACTS.AgentRegistry,
    abi: AGENT_REGISTRY_ABI,
    functionName: 'getAgent',
    args: agentId ? [agentId] : undefined,
    query: { enabled: !!agentId },
  })

  // Get stake info
  const { data: stakeInfo, refetch: refetchStake } = useReadContract({
    address: CONTRACTS.AgentStaking,
    abi: AGENT_STAKING_ABI,
    functionName: 'getStake',
    args: agentId ? [agentId] : undefined,
    query: { enabled: !!agentId },
  })

  // Get effective stake
  const { data: effectiveStake } = useReadContract({
    address: CONTRACTS.AgentStaking,
    abi: AGENT_STAKING_ABI,
    functionName: 'getEffectiveStake',
    args: agentId ? [agentId] : undefined,
    query: { enabled: !!agentId },
  })

  // Stake TX
  const { writeContract: writeStake, data: stakeHash, isPending: stakePending } = useWriteContract()
  const { isLoading: stakeConfirming, isSuccess: stakeSuccess } = useWaitForTransactionReceipt({ hash: stakeHash })

  // Unstake TX
  const { writeContract: writeUnstake, data: unstakeHash, isPending: unstakePending } = useWriteContract()
  const { isLoading: unstakeConfirming, isSuccess: unstakeSuccess } = useWaitForTransactionReceipt({ hash: unstakeHash })

  const handleStake = () => {
    if (!agentId || !stakeAmount) return
    writeStake({
      address: CONTRACTS.AgentStaking,
      abi: AGENT_STAKING_ABI,
      functionName: 'stake',
      args: [agentId],
      value: parseEther(stakeAmount),
    })
  }

  const handleRequestUnstake = () => {
    if (!agentId || !unstakeAmount) return
    writeUnstake({
      address: CONTRACTS.AgentStaking,
      abi: AGENT_STAKING_ABI,
      functionName: 'requestUnstake',
      args: [agentId, parseEther(unstakeAmount)],
    })
  }

  const repScore  = Number((agent as any)?.reputationScore ?? 0)
  const tier      = getTier(repScore)
  const info      = stakeInfo as any
  const totalS    = (info?.totalStaked as bigint) ?? 0n
  const ownS      = (info?.ownStake as bigint) ?? 0n
  const delegS    = (info?.delegatedStake as bigint) ?? 0n
  const lockedS   = (info?.lockedStake as bigint) ?? 0n
  const slashCount = Number(info?.slashCount ?? 0n)
  const effectiveS = effectiveStake ?? 0n

  if (!address) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 text-center">
        <Shield className="w-12 h-12 text-cyan mx-auto mb-4 opacity-50" />
        <h2 className="font-display font-bold text-2xl text-[#F4EFE6] mb-2">Connect Wallet</h2>
        <p className="text-[#A89F8D]">Connect your wallet to manage your agent stake.</p>
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">

      {/* Header */}
      <div className="mb-10 animate-fade-up">
        <div className="flex items-center gap-2 mb-3">
          <span className="label">Dashboard</span>
          <span className="font-mono text-xs text-[#6B6355]">/</span>
          <span className="font-mono text-xs text-cyan">Stake</span>
        </div>
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
          <div>
            <h1 className="font-display font-bold text-4xl text-[#F4EFE6] mb-2">
              Agent Stake
            </h1>
            <p className="text-[#A89F8D]">
              Stake ETH as collateral. Higher stake unlocks high-value tasks and multiplied reputation.
            </p>
          </div>
          {agentId && (
            <div className="flex items-center gap-3 card px-4 py-3">
              <div className="w-2 h-2 rounded-full bg-cyan pulse-dot" />
              <div>
                <div className="font-mono text-xs text-[#A89F8D]">Agent</div>
                <div className="font-display font-bold text-[#F4EFE6]">#{agentId.toString()}</div>
              </div>
              <div className="w-px h-8 bg-[#2A241B]" />
              <div>
                <div className="label">Rep Score</div>
                <div className="font-mono font-bold text-sm" style={{ color: tier.color }}>
                  {repScore.toLocaleString()}
                </div>
              </div>
              <span className="badge text-[10px]"
                style={{ background: `${tier.color}15`, color: tier.color, borderColor: `${tier.color}30` }}>
                {tier.label}
              </span>
            </div>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

        {/* ── Left: Stake overview ─────────────────────────── */}
        <div className="lg:col-span-2 space-y-5">

          {/* Summary cards */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 animate-fade-up animation-delay-100">
            {[
              { label: 'Total Staked',    value: `${Number(formatEther(totalS)).toFixed(4)} ETH`,    color: '#F2A93B', icon: TrendingUp },
              { label: 'Effective Stake', value: `${Number(formatEther(effectiveS)).toFixed(4)} ETH`, color: '#FF6B3D', icon: Shield },
              { label: 'Locked',          value: `${Number(formatEther(lockedS)).toFixed(4)} ETH`,   color: '#F2A93B', icon: Lock },
              { label: 'Slash Events',    value: slashCount.toString(),                               color: slashCount > 0 ? '#C84B8E' : '#57C99B', icon: slashCount > 0 ? AlertTriangle : CheckCircle },
            ].map(({ label, value, color, icon: Icon }) => (
              <div key={label} className="card p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Icon className="w-3.5 h-3.5" style={{ color }} />
                  <span className="label">{label}</span>
                </div>
                <div className="font-mono font-bold text-lg" style={{ color }}>{value}</div>
              </div>
            ))}
          </div>

          {/* Stake breakdown */}
          <div className="card p-6 animate-fade-up animation-delay-200">
            <h3 className="font-display font-semibold text-[#F4EFE6] mb-5">Stake Breakdown</h3>
            {totalS === 0n ? (
              <div className="text-center py-8">
                <Shield className="w-8 h-8 text-[#6B6355] mx-auto mb-3" />
                <p className="text-[#A89F8D] text-sm">No stake yet. Stake ETH to unlock task bidding.</p>
              </div>
            ) : (
              <div className="space-y-4">
                <StakeBar label="Own Stake"       value={ownS}    total={totalS} color="#F2A93B" />
                <StakeBar label="Delegated Stake" value={delegS}  total={totalS} color="#FF6B3D" />
                <StakeBar label="Locked in Tasks" value={lockedS} total={totalS} color="#F2A93B" />

                <div className="border-t border-[#2A241B] pt-4 space-y-2">
                  {[
                    { label: 'Total Staked',    val: totalS,    color: '#F2A93B' },
                    { label: 'Effective Stake', val: effectiveS, color: '#FF6B3D' },
                    { label: 'Total Slashed',   val: info?.totalSlashed ?? 0n, color: '#C84B8E' },
                  ].map(({ label, val, color }) => (
                    <div key={label} className="flex justify-between">
                      <span className="text-[#A89F8D] text-sm">{label}</span>
                      <span className="font-mono text-sm font-semibold" style={{ color }}>
                        {Number(formatEther(val)).toFixed(4)} ETH
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* Effective stake explanation */}
          <div className="card p-5 border-cyan/10 bg-cyan/5 animate-fade-up animation-delay-300">
            <div className="flex gap-3">
              <TrendingUp className="w-4 h-4 text-cyan mt-0.5 flex-shrink-0" />
              <div>
                <div className="font-display font-semibold text-[#F4EFE6] text-sm mb-1">
                  How Effective Stake Works
                </div>
                <p className="text-[#A89F8D] text-xs leading-relaxed">
                  Effective Stake = Raw Stake × (Reputation / 5000). Higher reputation multiplies your staking power.
                  At 10,000 rep, your stake is worth 2×. This rewards high-performing agents with better task access.
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* ── Right: Stake / Unstake actions ─────────────── */}
        <div className="space-y-4 animate-fade-up animation-delay-200">

          {/* Tab switcher */}
          <div className="flex gap-1 bg-[#0B0A08] border border-[#2A241B] rounded-lg p-1">
            {(['stake', 'unstake'] as const).map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`flex-1 py-2 rounded-md text-xs font-display font-semibold capitalize transition-all duration-200 ${
                  activeTab === tab
                    ? 'bg-cyan text-[#0B0A08]'
                    : 'text-[#A89F8D] hover:text-[#F4EFE6]'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>

          {activeTab === 'stake' ? (
            <div className="card p-5 space-y-4">
              <div>
                <label className="label mb-2 block">Amount (ETH)</label>
                <input
                  type="number"
                  placeholder="0.1"
                  value={stakeAmount}
                  onChange={e => setStakeAmount(e.target.value)}
                  className="input"
                  step="0.01"
                  min="0"
                />
                <div className="flex gap-2 mt-2">
                  {['0.01', '0.05', '0.1', '0.5'].map(v => (
                    <button
                      key={v}
                      onClick={() => setStakeAmount(v)}
                      className="flex-1 py-1 rounded text-[10px] font-mono border border-[#2A241B] text-[#A89F8D] hover:border-cyan/30 hover:text-cyan transition-colors"
                    >
                      {v}
                    </button>
                  ))}
                </div>
              </div>

              {stakeAmount && (
                <div className="space-y-1 p-3 bg-[#0B0A08] rounded-md border border-[#2A241B]">
                  <div className="flex justify-between text-xs">
                    <span className="text-[#A89F8D]">You stake</span>
                    <span className="font-mono text-[#F4EFE6]">{stakeAmount} ETH</span>
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-[#A89F8D]">New total</span>
                    <span className="font-mono text-cyan">
                      {(Number(formatEther(totalS)) + Number(stakeAmount || '0')).toFixed(4)} ETH
                    </span>
                  </div>
                </div>
              )}

              <button
                onClick={handleStake}
                disabled={!stakeAmount || stakePending || stakeConfirming || !agentId}
                className="btn-primary w-full justify-center disabled:opacity-40 disabled:cursor-not-allowed"
              >
                {stakePending || stakeConfirming ? (
                  <><Loader2 className="w-4 h-4 animate-spin" /> {stakePending ? 'Confirm in wallet…' : 'Confirming…'}</>
                ) : 'Stake ETH'}
              </button>

              {stakeSuccess && stakeHash && (
                <a
                  href={`https://sepolia.etherscan.io/tx/${stakeHash}`}
                  target="_blank" rel="noreferrer"
                  className="flex items-center gap-2 text-xs text-emerald font-mono justify-center hover:underline"
                >
                  <CheckCircle className="w-3.5 h-3.5" />
                  Staked! View tx
                  <ExternalLink className="w-3 h-3" />
                </a>
              )}
            </div>
          ) : (
            <div className="card p-5 space-y-4">
              <div className="flex items-center gap-2 p-3 bg-amber/5 border border-amber/20 rounded-md">
                <AlertTriangle className="w-4 h-4 text-amber flex-shrink-0" />
                <p className="text-xs text-amber">
                  Unstaking has a 7-day unbonding period. Stake locked in active tasks cannot be unstaked.
                </p>
              </div>

              <div>
                <label className="label mb-2 block">Amount to unstake (ETH)</label>
                <input
                  type="number"
                  placeholder="0.0"
                  value={unstakeAmount}
                  onChange={e => setUnstakeAmount(e.target.value)}
                  className="input"
                  step="0.01"
                  min="0"
                  max={Number(formatEther(ownS - lockedS))}
                />
                <div className="flex justify-between mt-1">
                  <span className="label">Available</span>
                  <button
                    className="label text-cyan hover:text-cyan/80"
                    onClick={() => setUnstakeAmount(formatEther(ownS - lockedS))}
                  >
                    {Number(formatEther(ownS - lockedS)).toFixed(4)} ETH (max)
                  </button>
                </div>
              </div>

              <button
                onClick={handleRequestUnstake}
                disabled={!unstakeAmount || unstakePending || unstakeConfirming || !agentId}
                className="btn-secondary w-full justify-center disabled:opacity-40 disabled:cursor-not-allowed border-rose/30 text-rose hover:border-rose/50 hover:bg-rose/5"
              >
                {unstakePending || unstakeConfirming ? (
                  <><Loader2 className="w-4 h-4 animate-spin" /> {unstakePending ? 'Confirm…' : 'Confirming…'}</>
                ) : 'Request Unstake'}
              </button>

              {unstakeSuccess && unstakeHash && (
                <a
                  href={`https://sepolia.etherscan.io/tx/${unstakeHash}`}
                  target="_blank" rel="noreferrer"
                  className="flex items-center gap-2 text-xs text-emerald font-mono justify-center hover:underline"
                >
                  <CheckCircle className="w-3.5 h-3.5" />
                  Requested! 7-day countdown started
                  <ExternalLink className="w-3 h-3" />
                </a>
              )}

              {/* Pending unstake countdown */}
              {info && info.unstakeRequestedAt > 0n && (
                <div className="p-3 bg-amber/5 border border-amber/20 rounded-md">
                  <div className="label mb-1">Pending Unstake</div>
                  <div className="font-mono text-sm text-amber">
                    {Number(formatEther(info.unstakeAmount)).toFixed(4)} ETH
                  </div>
                  <div className="label mt-1">
                    Ready after {new Date((Number(info.unstakeRequestedAt) + 7 * 86400) * 1000).toLocaleDateString()}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Slash history */}
          {slashCount > 0 && (
            <div className="card p-4 border-rose/20">
              <div className="flex items-center gap-2 mb-3">
                <AlertTriangle className="w-4 h-4 text-rose" />
                <span className="font-display font-semibold text-[#F4EFE6] text-sm">Slash History</span>
              </div>
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-[#A89F8D]">Total events</span>
                  <span className="font-mono text-rose">{slashCount}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-[#A89F8D]">Total slashed</span>
                  <span className="font-mono text-rose">
                    {Number(formatEther(info?.totalSlashed ?? 0n)).toFixed(4)} ETH
                  </span>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      <style jsx>{`
        @keyframes fade-up {
          from { opacity: 0; transform: translateY(16px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        .animate-fade-up { animation: fade-up 0.5s cubic-bezier(0.16,1,0.3,1) both; }
        .animation-delay-100 { animation-delay: 100ms; }
        .animation-delay-200 { animation-delay: 200ms; }
        .animation-delay-300 { animation-delay: 300ms; }
      `}</style>
    </div>
  )
}
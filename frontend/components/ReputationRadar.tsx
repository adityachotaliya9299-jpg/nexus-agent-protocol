'use client'

import { useEffect, useState } from 'react'

const LABELS = ['GENERAL', 'CODE', 'RESEARCH', 'TRADING', 'CREATIVE', 'ORCHESTRATOR']
const COLORS = ['#64748B', '#8B5CF6', '#06B6D4', '#10B981', '#F59E0B', '#F43F5E']

interface ReputationRadarProps {
  scores: number[]
  size?: number
  animated?: boolean
}

export function ReputationRadar({ scores, size = 240, animated = true }: ReputationRadarProps) {
  const [progress, setProgress] = useState(animated ? 0 : 1)

  useEffect(() => {
    if (!animated) return
    const t = setTimeout(() => setProgress(1), 200)
    return () => clearTimeout(t)
  }, [animated])

  const n = 6
  const cx = size / 2
  const cy = size / 2
  const maxR = size / 2 - 28

  const angleStep = (Math.PI * 2) / n
  const getPoint = (i: number, r: number) => ({
    x: cx + r * Math.sin(i * angleStep),
    y: cy - r * Math.cos(i * angleStep),
  })

  // Concentric rings
  const rings = [0.25, 0.5, 0.75, 1].map(factor => {
    const pts = Array.from({ length: n }, (_, i) => getPoint(i, maxR * factor))
    return pts.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x},${p.y}`).join(' ') + 'Z'
  })

  // Agent polygon
  const agentPts = scores.map((s, i) => {
    const r = (Math.min(s, 10000) / 10000) * maxR * progress
    return getPoint(i, r)
  })
  const agentPath = agentPts.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x},${p.y}`).join(' ') + 'Z'

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      {/* Rings */}
      {rings.map((d, i) => (
        <path key={i} d={d} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth={0.5} />
      ))}

      {/* Axes */}
      {Array.from({ length: n }, (_, i) => {
        const outer = getPoint(i, maxR)
        return (
          <line
            key={i}
            x1={cx} y1={cy} x2={outer.x} y2={outer.y}
            stroke="rgba(255,255,255,0.06)" strokeWidth={0.5}
          />
        )
      })}

      {/* Agent polygon */}
      <path
        d={agentPath}
        fill="rgba(139,92,246,0.12)"
        stroke="#8B5CF6"
        strokeWidth={1.5}
        style={{ transition: 'all 0.8s cubic-bezier(0.16,1,0.3,1)' }}
      />

      {/* Score dots */}
      {agentPts.map((p, i) => (
        <circle key={i} cx={p.x} cy={p.y} r={4}
          fill={COLORS[i]}
          style={{
            filter: `drop-shadow(0 0 4px ${COLORS[i]})`,
            transition: 'all 0.8s cubic-bezier(0.16,1,0.3,1)',
          }}
        />
      ))}

      {/* Labels */}
      {Array.from({ length: n }, (_, i) => {
        const pt = getPoint(i, maxR + 20)
        return (
          <text
            key={i}
            x={pt.x} y={pt.y}
            textAnchor="middle" dominantBaseline="middle"
            fontSize={9}
            fontFamily="'JetBrains Mono', monospace"
            fontWeight={600}
            fill={COLORS[i]}
            opacity={0.8}
            letterSpacing={0.5}
          >
            {LABELS[i].slice(0, 4)}
          </text>
        )
      })}

      {/* Center dot */}
      <circle cx={cx} cy={cy} r={3} fill="rgba(255,255,255,0.15)" />
    </svg>
  )
}
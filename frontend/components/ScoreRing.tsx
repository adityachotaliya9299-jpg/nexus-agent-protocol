'use client'

import { useEffect, useRef, useState } from 'react'
import { getTier } from '@/lib/contracts'

interface ScoreRingProps {
  score: number
  size?: number
  strokeWidth?: number
  showLabel?: boolean
  animated?: boolean
  delay?: number
}

export function ScoreRing({
  score,
  size = 80,
  strokeWidth = 6,
  showLabel = true,
  animated = true,
  delay = 0,
}: ScoreRingProps) {
  const [drawn, setDrawn] = useState(!animated)
  const tier = getTier(score)

  const radius = (size - strokeWidth) / 2
  const circumference = 2 * Math.PI * radius
  const progress = Math.min(score / 10000, 1)
  const offset = circumference - progress * circumference

  useEffect(() => {
    if (!animated) return
    const t = setTimeout(() => setDrawn(true), delay)
    return () => clearTimeout(t)
  }, [animated, delay])

  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        {/* Track */}
        <circle
          cx={size / 2} cy={size / 2} r={radius}
          fill="none"
          stroke="rgba(255,255,255,0.06)"
          strokeWidth={strokeWidth}
        />
        {/* Progress arc */}
        <circle
          cx={size / 2} cy={size / 2} r={radius}
          fill="none"
          stroke={tier.color}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={drawn ? offset : circumference}
          style={{
            transition: drawn
              ? `stroke-dashoffset 0.9s cubic-bezier(0.16,1,0.3,1) ${delay}ms`
              : 'none',
            filter: `drop-shadow(0 0 6px ${tier.color}88)`,
          }}
        />
      </svg>

      {showLabel && (
        <div style={{
          position: 'absolute', inset: 0,
          display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center',
          gap: 0,
        }}>
          <span style={{
            fontFamily: 'var(--nx-font-mono, monospace)',
            fontSize: size < 60 ? 12 : size < 80 ? 14 : 16,
            fontWeight: 600,
            color: tier.color,
            lineHeight: 1,
            opacity: drawn ? 1 : 0,
            transition: `opacity 0.4s ease ${delay + 400}ms`,
          }}>
            {score.toLocaleString()}
          </span>
          <span style={{
            fontFamily: 'var(--nx-font-mono, monospace)',
            fontSize: size < 60 ? 8 : 9,
            fontWeight: 500,
            color: 'rgba(255,255,255,0.35)',
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
            lineHeight: 1,
            marginTop: 2,
            opacity: drawn ? 1 : 0,
            transition: `opacity 0.4s ease ${delay + 600}ms`,
          }}>
            {tier.label}
          </span>
        </div>
      )}
    </div>
  )
}

// Compact version for leaderboard rows
export function ScoreRingMini({ score, size = 40 }: { score: number; size?: number }) {
  return <ScoreRing score={score} size={size} strokeWidth={4} showLabel={false} />
}
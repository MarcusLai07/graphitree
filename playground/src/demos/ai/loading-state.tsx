/**
 * Loading State — copied from Beautiful UI (MIT, (c) 2026 Shane Levine).
 * https://www.beautifului.dev/#loading-state
 *
 * Changes from the original: colour tokens mapped to shadcn, keyframes
 * prefixed bui-, the "Surfer" variant dropped (it streams a meme video from
 * the author's Vercel Blob by default), and the 10 Hz timer is aria-hidden so
 * the role="status" region doesn't chatter in screen readers.
 */
import { useEffect, useState } from "react"
import { cn } from "@/lib/utils"
import "./bui.css"

export type LoaderPattern = "Drive" | "Dots" | "Orbit"

const chevron = Array.from({ length: 9 }, (_, i) => {
  const r = Math.floor(i / 3)
  const c = i % 3
  return (c + Math.abs(r - 1)) * 90
})

const ORBIT_ORDER = [0, 1, 2, 5, 8, 7, 6, 3]
const orbit = Array.from({ length: 9 }, (_, i) => {
  const k = ORBIT_ORDER.indexOf(i)
  return k === -1 ? null : k * 110
})

const PATTERNS: Record<LoaderPattern, { delays: (number | null)[]; dur: number; round: boolean }> = {
  Drive: { delays: chevron, dur: 650, round: false },
  Dots: { delays: chevron, dur: 650, round: true },
  Orbit: { delays: orbit, dur: 950, round: false },
}

export function LoaderGrid({ pattern = "Drive", className }: { pattern?: LoaderPattern; className?: string }) {
  const { delays, dur, round } = PATTERNS[pattern]
  return (
    <span aria-hidden className={cn("grid shrink-0 grid-cols-[repeat(3,4px)] gap-[1.5px]", className)}>
      {delays.map((delay, index) => (
        <span
          key={index}
          className={cn("size-[4px] bg-foreground", round ? "rounded-full" : "rounded-[1px]")}
          style={{
            opacity: delay === null ? 0.07 : 0.15,
            animation: delay === null ? "none" : `bui-pixel-on ${dur}ms ease-in-out ${delay}ms infinite`,
          }}
        />
      ))}
    </span>
  )
}

function useElapsed() {
  const [ds, setDs] = useState(0)
  useEffect(() => {
    const t = setInterval(() => setDs((d) => d + 1), 100)
    return () => clearInterval(t)
  }, [])
  const total = ds / 10
  if (total < 60) return `${total.toFixed(1)}s`
  return `${Math.floor(total / 60)}m ${(total % 60).toFixed(1)}s`
}

function Elapsed() {
  const elapsed = useElapsed()
  return (
    <span aria-hidden className="font-mono text-xs text-muted-foreground tabular-nums">
      {elapsed}
    </span>
  )
}

export function LoadingState({
  label = "Churning",
  pattern = "Drive",
  showElapsed = true,
  className,
}: {
  label?: string
  pattern?: LoaderPattern
  showElapsed?: boolean
  className?: string
}) {
  return (
    <div data-bui role="status" className={cn("flex w-fit items-center gap-2.5", className)}>
      <LoaderGrid pattern={pattern} />
      <span className="bui-shimmer text-[13px] font-medium">{label}</span>
      {showElapsed && <Elapsed />}
    </div>
  )
}

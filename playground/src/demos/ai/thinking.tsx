/**
 * Thinking — copied from Beautiful UI (MIT, (c) 2026 Shane Levine).
 * https://www.beautifului.dev/#thinking-state
 *
 * The original runs a hard-coded 7-second demo timeline. This copy keeps that
 * as the default ("auto" mode) and adds a controlled mode for real use:
 * pass `working` and `visible` and the trace follows your agent's state.
 * Colours mapped to shadcn tokens; focus rings added (the original relies on
 * a global :focus-visible outline in its foundation CSS).
 */
import { useEffect, useLayoutEffect, useRef, useState, type ReactNode } from "react"
import { cn } from "@/lib/utils"
import "./bui.css"

export type ThinkingVariant = "Steps" | "Reasoning" | "Search" | "Coding"

export type TraceRow = {
  primary: string
  secondary?: string
  mono?: boolean
  add?: number
  del?: number
  href?: string
}

const STAGES = [800, 600, 1800, 2600, 1600]

function useSequence(steps: number[], enabled: boolean) {
  const [stage, setStage] = useState(0)
  useEffect(() => {
    if (!enabled || stage >= steps.length - 1) return
    const t = setTimeout(() => setStage((s) => s + 1), steps[stage])
    return () => clearTimeout(t)
  }, [stage, steps, enabled])
  return stage
}

const PRESETS: Record<ThinkingVariant, { active: string; done: string; rows: TraceRow[]; query?: string }> = {
  Steps: {
    active: "Thinking",
    done: "Thought for 4 seconds",
    rows: [
      { primary: "Reading the knowledge graph" },
      { primary: "Finding repos that import vaul" },
      { primary: "Comparing drawer usage", secondary: "6 files" },
      { primary: "Writing the migration plan" },
    ],
  },
  Reasoning: {
    active: "Thinking",
    done: "Thought for 4 seconds",
    rows: [
      { primary: "Two repos still import vaul; odyssey uses it for the mobile composer sheet." },
      { primary: "Base UI's Drawer covers the same cases, so the swap is mostly import changes." },
    ],
  },
  Search: {
    active: "Searching the web",
    done: "Searched the web",
    query: "base ui drawer vs vaul",
    rows: [
      { primary: "Base UI Drawer", secondary: "base-ui.com", href: "https://base-ui.com/react/components/drawer" },
      { primary: "Vaul on GitHub", secondary: "github.com", href: "https://github.com/emilkowalski/vaul" },
      { primary: "shadcn/ui Drawer", secondary: "ui.shadcn.com", href: "https://ui.shadcn.com/docs/components/drawer" },
    ],
  },
  Coding: {
    active: "Running tools",
    done: "Ran 3 tools",
    rows: [
      { primary: "Read", secondary: "drawer.tsx", mono: true },
      { primary: "Edit", secondary: "MobileComposer.tsx", mono: true, add: 42, del: 61 },
      { primary: "Run", secondary: "npm run typecheck", mono: true },
    ],
  },
}

function Dot({ tone }: { tone: string }) {
  return (
    <span className={cn("flex size-3.5 shrink-0 items-center justify-center rounded-full text-white", tone)}>
      <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" aria-hidden>
        <circle cx="12" cy="12" r="9" />
        <path d="M3.5 12h17M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18" />
      </svg>
    </span>
  )
}

const TONES = ["bg-sky-500", "bg-orange-500", "bg-emerald-500"]
const focusRing = "outline-none focus-visible:ring-2 focus-visible:ring-ring/60"

export function Thinking({
  variant = "Steps",
  rows,
  query,
  active,
  done,
  icon,
  working: workingProp,
  visible: visibleProp,
  more,
  onSettled,
  className,
}: {
  variant?: ThinkingVariant
  rows?: TraceRow[]
  query?: string
  active?: string
  done?: string
  icon?: ReactNode
  /** Controlled mode: is the agent still working? Leave undefined for the demo timeline. */
  working?: boolean
  /** Controlled mode: how many rows have arrived so far. */
  visible?: number
  /** "+N more" shown under a finished Search trace. */
  more?: number
  onSettled?: () => void
  className?: string
}) {
  const controlled = workingProp !== undefined
  const stage = useSequence(STAGES, !controlled)
  const [manualExpanded, setManualExpanded] = useState<boolean | null>(null)
  const [selectedTool, setSelectedTool] = useState<string | null>(null)
  const preset = PRESETS[variant]
  const v = {
    rows: rows ?? preset.rows,
    query: query ?? preset.query,
    active: active ?? preset.active,
    done: done ?? preset.done,
  }

  const working = controlled ? workingProp : stage < 3
  const autoExpanded = controlled ? workingProp : stage >= 1 && stage < 4
  const expanded = manualExpanded ?? autoExpanded
  const visible = controlled
    ? Math.min(visibleProp ?? v.rows.length, v.rows.length)
    : stage < 2
      ? 0
      : stage === 2
        ? Math.min(2, v.rows.length)
        : v.rows.length

  const traceRef = useRef<HTMLDivElement>(null)
  const [lineHeight, setLineHeight] = useState(0)
  useLayoutEffect(() => {
    if (traceRef.current) setLineHeight(traceRef.current.offsetHeight)
  }, [visible, expanded, variant, stage])

  const settledRef = useRef(false)
  useEffect(() => {
    if (working || settledRef.current) return
    settledRef.current = true
    onSettled?.()
  }, [working, onSettled])

  const moreCount = more ?? (variant === "Search" ? 7 : 0)

  return (
    <div
      data-bui
      className={cn("flex w-full max-w-95 flex-col", className)}
      style={{
        minHeight: !controlled && (working || expanded) ? 176 : undefined,
        transition: "min-height 400ms cubic-bezier(0.23,1,0.32,1)",
      }}
    >
      <button
        type="button"
        aria-expanded={expanded}
        onClick={() => setManualExpanded((current) => !(current ?? autoExpanded))}
        className={cn(
          "-mx-1.5 flex w-fit items-center gap-2 rounded-md px-1.5 py-1 transition-colors duration-100 hover:bg-muted",
          focusRing,
        )}
      >
        <span className={cn("flex shrink-0 transition-colors duration-200", working ? "text-muted-foreground" : "text-muted-foreground/70")}>
          {icon ?? (
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
              <path d="M12 2l2.4 7.2L22 12l-7.6 2.8L12 22l-2.4-7.2L2 12l7.6-2.8z" />
            </svg>
          )}
        </span>
        <span role="status" className="contents">
          {working ? (
            <span className="bui-shimmer text-[13px] font-medium whitespace-nowrap">{v.active}</span>
          ) : (
            <span
              className="text-[13px] font-medium whitespace-nowrap text-muted-foreground"
              style={{ animation: "bui-fade-in 350ms ease-out both" }}
            >
              {v.done}
            </span>
          )}
        </span>
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden
          className="text-muted-foreground/70 transition-transform duration-300"
          style={{ transform: expanded ? "rotate(180deg)" : "rotate(0)" }}
        >
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>

      <div
        className="grid transition-[grid-template-rows,opacity] duration-400"
        style={{
          gridTemplateRows: expanded ? "1fr" : "0fr",
          opacity: expanded ? 1 : 0,
          transitionTimingFunction: "cubic-bezier(0.23, 1, 0.32, 1)",
        }}
      >
        <div className="overflow-hidden" inert={!expanded}>
          <div className="relative mt-1 ml-[5px] pl-4">
            <span
              aria-hidden
              className="absolute left-[3px] w-px bg-border"
              style={{
                top: -8,
                height: lineHeight ? lineHeight - 2 : 0,
                transition: "height 500ms cubic-bezier(0.23,1,0.32,1)",
              }}
            />
            <div ref={traceRef} className="flex flex-col gap-1 py-1">
              {v.query && (
                <div
                  className="flex h-6 items-center gap-2 px-1.5"
                  style={{ animation: expanded ? "bui-fade-up 300ms cubic-bezier(0.23,1,0.32,1) both" : undefined }}
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" className="shrink-0 text-muted-foreground" aria-hidden>
                    <circle cx="11" cy="11" r="7" />
                    <path d="M21 21l-4.3-4.3" />
                  </svg>
                  <span className="text-[12.5px] text-muted-foreground">{v.query}</span>
                </div>
              )}
              {v.rows.slice(0, visible).map((row, i) => {
                const content = (
                  <>
                    {variant === "Search" && <Dot tone={TONES[i % 3]} />}
                    {variant === "Steps" &&
                      (i < visible - 1 || !working ? (
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="shrink-0 text-muted-foreground" aria-hidden>
                          <path d="M20 6L9 17l-5-5" />
                        </svg>
                      ) : (
                        <span
                          aria-hidden
                          className="size-3 shrink-0 rounded-full border-[1.5px] border-border border-t-muted-foreground"
                          style={{ animation: "bui-spin 700ms linear infinite" }}
                        />
                      ))}
                    <span
                      className={cn(
                        "min-w-0 truncate text-[12.5px]",
                        variant === "Reasoning" ? "leading-relaxed whitespace-normal text-muted-foreground" : "font-medium text-foreground",
                        variant === "Search" && "underline-offset-2 group-hover/row:underline",
                      )}
                    >
                      {row.primary}
                    </span>
                    {row.secondary && (
                      <span className={cn("shrink-0 text-[11.5px] text-muted-foreground", row.mono && "font-mono")}>{row.secondary}</span>
                    )}
                    {row.add !== undefined && (
                      <span className="shrink-0 font-mono text-[11px] tabular-nums">
                        <span className="text-emerald-600 dark:text-emerald-400">+{row.add}</span>{" "}
                        <span className="text-red-600 dark:text-red-400">−{row.del}</span>
                      </span>
                    )}
                  </>
                )
                const rowClass = "group/row flex min-h-7 w-full items-center gap-2 rounded-[6px] px-1.5 py-0.5 text-left"
                const animation = { animation: `bui-fade-up 320ms cubic-bezier(0.23,1,0.32,1) ${i * 120}ms both` }

                if (variant === "Search") {
                  return (
                    <a key={row.primary} href={row.href} target="_blank" rel="noreferrer" className={cn(rowClass, "transition-colors duration-150 hover:bg-muted", focusRing)} style={animation}>
                      {content}
                    </a>
                  )
                }
                if (variant === "Coding") {
                  const selected = selectedTool === row.primary
                  return (
                    <button
                      key={row.primary}
                      type="button"
                      aria-pressed={selected}
                      onClick={() => setSelectedTool(selected ? null : row.primary)}
                      className={cn(rowClass, "transition-colors duration-150", selected ? "bg-muted" : "hover:bg-muted/60", focusRing)}
                      style={animation}
                    >
                      {content}
                    </button>
                  )
                }
                return (
                  <div key={row.primary} className={rowClass} style={animation}>
                    {content}
                  </div>
                )
              })}
              {variant === "Search" && !working && moreCount > 0 && (
                <span className="px-1.5 text-xs text-muted-foreground" style={{ animation: "bui-fade-in 300ms ease-out both" }}>
                  +{moreCount} more
                </span>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

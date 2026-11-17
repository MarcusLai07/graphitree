/**
 * Streaming Text + StreamText — copied from Beautiful UI (MIT, (c) 2026 Shane Levine).
 * https://www.beautifului.dev/#streaming-text
 *
 * Changes from the original:
 * - `revealed` prop: drive the stream from outside (a real token stream or a
 *   setInterval) instead of the built-in 55 ms word timer, which still runs
 *   when `revealed` is left out.
 * - A cite token can point at any source (`source: index`), not only the first.
 * - The four icon buttons all had aria-label="Action"; they now say what they do.
 * - Follow-ups get type="button"; sources show a letter avatar when no image.
 */
import { useEffect, useRef, useState, type ReactNode } from "react"
import { cn } from "@/lib/utils"
import { words, type StreamingSource, type StreamingToken } from "./stream-tokens"
import "./bui.css"

const focusRing = "outline-none focus-visible:ring-2 focus-visible:ring-ring/60"

/* ── StreamText: fast character reveal with a blurred leading edge ── */

export function StreamText({
  text,
  charsPerTick = 2,
  tickMs = 9,
  blurTail = 6,
  caret = true,
  className,
  onDone,
}: {
  text: string
  charsPerTick?: number
  tickMs?: number
  blurTail?: number
  caret?: boolean
  className?: string
  onDone?: () => void
}) {
  const [count, setCount] = useState(0)
  const onDoneRef = useRef(onDone)
  useEffect(() => {
    onDoneRef.current = onDone
  })

  useEffect(() => {
    // the original also calls setCount(0) here; remount with a key to restart instead
    let i = 0
    const id = setInterval(() => {
      i = Math.min(i + charsPerTick, text.length)
      setCount(i)
      if (i >= text.length) {
        clearInterval(id)
        onDoneRef.current?.()
      }
    }, tickMs)
    return () => clearInterval(id)
  }, [text, charsPerTick, tickMs])

  const streaming = count < text.length
  const shown = text.slice(0, count)
  const split = streaming ? Math.max(0, shown.length - blurTail) : shown.length

  return (
    <span data-bui className={className}>
      {shown.slice(0, split)}
      {split < shown.length && <span className="bui-stream-tail">{shown.slice(split)}</span>}
      {caret && <span aria-hidden className={cn("bui-caret", streaming && "is-streaming")} />}
    </span>
  )
}

/* ── Streaming answer with inline sources, actions and follow-ups ── */

export type { StreamingSource, StreamingToken } from "./stream-tokens"

const DEFAULT_TOKENS: StreamingToken[] = [
  ...words("Two repos still use Vaul: odyssey (the mobile composer sheet) and depot (the pick-list drawer)."),
  { text: "", cite: true, source: 0 },
  ...words("Base UI's Drawer covers both, with swipe-to-dismiss and snap points built in."),
  { text: "", cite: true, source: 1 },
]

const DEFAULT_SOURCES: StreamingSource[] = [
  { name: "Knowledge graph", domain: "graph.json", href: "#", tone: "bg-emerald-600" },
  { name: "Base UI Drawer", domain: "base-ui.com", href: "https://base-ui.com/react/components/drawer", tone: "bg-sky-600" },
  { name: "Playbook", domain: "PLAYBOOK.md", href: "#", tone: "bg-orange-500" },
]

const DEFAULT_FOLLOW_UPS = ["Open the migration PRs", "Which other repos use deprecated libraries?"]

function SourceAvatar({ source, className }: { source: StreamingSource; className?: string }) {
  if (source.image) return <img src={source.image} alt="" className={cn("rounded-[3px] ring-1 ring-foreground/10", className)} />
  return (
    <span
      aria-hidden
      className={cn(
        "inline-flex items-center justify-center rounded-[3px] text-[8px] leading-none font-semibold text-white uppercase ring-1 ring-foreground/10",
        source.tone ?? "bg-muted-foreground",
        className,
      )}
    >
      {source.name[0]}
    </span>
  )
}

function SourceChip({ source }: { source?: StreamingSource }) {
  if (!source) return null
  return (
    <a
      href={source.href}
      target="_blank"
      rel="noreferrer"
      className={cn(
        "mr-1 inline-flex h-4.5 translate-y-[-1px] items-center gap-1 rounded-[5px] bg-muted/60 px-[3px] align-middle font-mono text-[10.5px] text-muted-foreground ring-1 ring-border transition-colors duration-150 hover:bg-muted hover:text-foreground",
        focusRing,
      )}
      style={{ animation: "bui-pop-in 250ms cubic-bezier(0.23,1,0.32,1) both" }}
    >
      <SourceAvatar source={source} className="size-3" />
      <span>{source.domain}</span>
    </a>
  )
}

const ACTIONS: { label: string; icon: ReactNode }[] = [
  {
    label: "Copy answer",
    icon: (
      <g>
        <rect x="9" y="9" width="12" height="12" rx="2.5" />
        <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
      </g>
    ),
  },
  { label: "Regenerate", icon: <path d="M21 12a9 9 0 1 1-2.64-6.36M21 3v6h-6" /> },
  {
    label: "Good answer",
    icon: <path d="M7 10v12M15 5.88L14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2h2.76a2 2 0 0 0 1.79-1.11L12 2a3.13 3.13 0 0 1 3 3.88z" />,
  },
  {
    label: "Bad answer",
    icon: <path d="M17 14V2M9 18.12L10 14H4.17a2 2 0 0 1-1.92-2.56l2.33-8A2 2 0 0 1 6.5 2H20a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-2.76a2 2 0 0 0-1.79 1.11L12 22a3.13 3.13 0 0 1-3-3.88z" />,
  },
]

const WORD_MS = 55
const HOLD_MS = 3400

export function StreamingAnswer({
  tokens = DEFAULT_TOKENS,
  sources = DEFAULT_SOURCES,
  followUps = DEFAULT_FOLLOW_UPS,
  sourcesLabel,
  followUpsLabel = "Follow-ups",
  revealed,
  loop = false,
  defaultSourcesOpen = false,
  onDone,
  onFollowUp,
  className,
}: {
  tokens?: StreamingToken[]
  sources?: StreamingSource[]
  followUps?: string[]
  sourcesLabel?: string
  followUpsLabel?: string
  /** Controlled: how many tokens have arrived. Leave out to use the built-in word timer. */
  revealed?: number
  /** Built-in timer only: restart after a pause (the gallery behaviour). */
  loop?: boolean
  defaultSourcesOpen?: boolean
  onDone?: () => void
  onFollowUp?: (text: string, index: number) => void
  className?: string
}) {
  const [internal, setInternal] = useState(0)
  const [sourcesOpen, setSourcesOpen] = useState(defaultSourcesOpen)
  const count = revealed ?? internal
  const done = count >= tokens.length
  const onDoneRef = useRef(onDone)
  useEffect(() => {
    onDoneRef.current = onDone
  })

  useEffect(() => {
    if (revealed !== undefined) return
    if (done && !loop) return
    const t = setTimeout(() => setInternal((c) => (c >= tokens.length ? 0 : c + 1)), done ? HOLD_MS : WORD_MS)
    return () => clearTimeout(t)
  }, [internal, done, loop, revealed, tokens.length])

  useEffect(() => {
    if (done) onDoneRef.current?.()
  }, [done])

  const label = sourcesLabel ?? `${sources.length} sources`

  return (
    <div data-bui className={cn("w-full", className)}>
      <p className="text-[13px] leading-relaxed text-foreground">
        {tokens.slice(0, count).map((token, i) =>
          token.cite ? (
            <SourceChip key={i} source={sources[token.source ?? 0]} />
          ) : (
            <span key={i} className="inline">
              {token.text}{" "}
            </span>
          ),
        )}
        {!done && (
          <span
            aria-hidden
            className="ml-0.5 inline-block h-3 w-0.5 translate-y-0.5 rounded-full bg-foreground"
            style={{ animation: "bui-fade-in 150ms ease-out both" }}
          />
        )}
      </p>

      <div
        className="mt-2 flex items-center gap-0.5 transition-opacity duration-400"
        style={{ opacity: done ? 1 : 0, pointerEvents: done ? "auto" : "none" }}
        inert={!done}
      >
        {ACTIONS.map((action) => (
          <button
            key={action.label}
            type="button"
            aria-label={action.label}
            title={action.label}
            className={cn(
              "flex size-6 items-center justify-center rounded-[6px] text-muted-foreground transition-colors duration-100 hover:bg-muted hover:text-foreground",
              focusRing,
            )}
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
              {action.icon}
            </svg>
          </button>
        ))}
        <button
          type="button"
          aria-expanded={sourcesOpen}
          onClick={() => setSourcesOpen((current) => !current)}
          className={cn("ml-1.5 flex items-center gap-1.5 rounded-[6px] px-1 py-0.5 text-left transition-colors duration-150 hover:bg-muted", focusRing)}
        >
          <span className="flex -space-x-1">
            {sources.map((source) => (
              <SourceAvatar key={source.domain} source={source} className="size-3.5 rounded-full ring-[1.5px] ring-background" />
            ))}
          </span>
          <span className="text-xs text-muted-foreground">{label}</span>
        </button>
      </div>

      <div
        className="grid transition-[grid-template-rows,opacity] duration-300"
        style={{
          gridTemplateRows: done && sourcesOpen ? "1fr" : "0fr",
          opacity: done && sourcesOpen ? 1 : 0,
          transitionTimingFunction: "cubic-bezier(0.23, 1, 0.32, 1)",
        }}
      >
        <div className="overflow-hidden" inert={!(done && sourcesOpen)}>
          <div className="mt-1.5 flex flex-col rounded-[10px] bg-muted/50 p-1 ring-1 ring-border">
            {sources.map((source) => (
              <a
                key={source.domain}
                href={source.href}
                target="_blank"
                rel="noreferrer"
                className={cn(
                  "group/src flex items-center gap-2 rounded-[6px] px-1.5 py-1 text-xs text-muted-foreground transition-colors duration-150 hover:bg-muted hover:text-foreground",
                  focusRing,
                )}
              >
                <SourceAvatar source={source} className="size-4 rounded-[4px]" />
                <span className="underline-offset-2 group-hover/src:underline">{source.name}</span>
                <span className="ml-auto font-mono text-[10.5px] text-muted-foreground">{source.domain}</span>
              </a>
            ))}
          </div>
        </div>
      </div>

      {followUps.length > 0 && (
        <div
          className="mt-2.5 transition-opacity duration-400"
          style={{ opacity: done ? 1 : 0, pointerEvents: done ? "auto" : "none" }}
          inert={!done}
        >
          <p className="text-xs font-medium text-muted-foreground">{followUpsLabel}</p>
          <div className="mt-0.5 flex flex-col">
            {followUps.map((text, i) => (
              <button
                key={text}
                type="button"
                onClick={() => onFollowUp?.(text, i)}
                className={cn(
                  "-mx-1.5 flex items-center gap-2 rounded-[7px] border-b px-1.5 py-1.5 text-left text-[12.5px] text-foreground transition-colors duration-100 hover:bg-muted",
                  focusRing,
                )}
                style={done ? { animation: `bui-fade-up 350ms cubic-bezier(0.23,1,0.32,1) ${i * 90}ms both` } : { opacity: 0 }}
              >
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="shrink-0 text-muted-foreground" aria-hidden>
                  <path d="M9 10l-5 5 5 5" />
                  <path d="M20 4v7a4 4 0 0 1-4 4H4" />
                </svg>
                {text}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

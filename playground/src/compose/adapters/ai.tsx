// AI components: chat message and agent step.
// The Beautiful UI blocks are the lab's patched copies in src/demos/ai (tokens mapped to shadcn, controlled props
// added). Everything is simulated with timers: no model, no network. Sample data is the wholesale order from
// src/demos/app/data.ts: Order #4821 for Jaya Grocer Bangsar, RM 2,665.20, shipping from Shah Alam DC.
import { useEffect, useState, type MouseEvent, type ReactNode } from "react"
import {
  BotIcon,
  CopyIcon,
  PackageIcon,
  RefreshCwIcon,
  RotateCcwIcon,
  SearchIcon,
  ShieldCheckIcon,
  TruckIcon,
} from "lucide-react"
import {
  ChainOfThought,
  ChainOfThoughtContent,
  ChainOfThoughtHeader,
  ChainOfThoughtSearchResult,
  ChainOfThoughtSearchResults,
  ChainOfThoughtStep,
} from "@/components/ai-elements/chain-of-thought"
import { Source, Sources, SourcesContent, SourcesTrigger, type SourcesProps } from "@/components/ai-elements/sources"
import { Button } from "@/components/ui/button"
import { ApprovalCard, type ApprovalQuestion } from "@/demos/ai/approval-card"
import { words, type StreamingSource, type StreamingToken } from "@/demos/ai/stream-tokens"
import { StreamingAnswer } from "@/demos/ai/streaming"
import { TaskRows, type TaskRow, type TaskStatus } from "@/demos/ai/task-rows"
import { Thinking, type ThinkingVariant, type TraceRow } from "@/demos/ai/thinking"
import { ToolChips, type ToolDiff, type ToolDiffLine, type ToolStep } from "@/demos/ai/tool-chips"
import { cn } from "@/lib/utils"
import type { Adapter, BlockProps, Option, OptionValues } from "../types"

/* ------------------------------------------------------------------------------------------------
 * Shared pieces
 * ---------------------------------------------------------------------------------------------- */

const join = (...parts: (string | false | undefined)[]) => parts.filter((p): p is string => typeof p === "string").join("\n")

/** Keeps the lab's hash router (and new windows) from following the sample source links. */
const stopLinks = (e: MouseEvent) => {
  if ((e.target as HTMLElement).closest("a")) e.preventDefault()
}

/**
 * A run counter for remounting self-timed blocks. With `auto` on, it bumps itself every `every` ms,
 * so the block replays on a loop.
 */
function useRuns(auto: boolean, every: number) {
  const [run, setRun] = useState(0)
  useEffect(() => {
    if (!auto) return
    const t = setTimeout(() => setRun((r) => r + 1), every)
    return () => clearTimeout(t)
  }, [auto, every, run])
  return [run, () => setRun((r) => r + 1)] as const
}

/** Counts from 0 up to `total`, one step every `ms`. Remount to start again. */
function useCount(total: number, ms: number, enabled = true) {
  const [n, setN] = useState(enabled ? 0 : total)
  useEffect(() => {
    if (n >= total) return
    const t = setTimeout(() => setN((c) => c + 1), ms)
    return () => clearTimeout(t)
  }, [n, total, ms])
  return n
}

function Block({ children, onReplay, className }: { children: ReactNode; onReplay?: () => void; className?: string }) {
  return (
    <div onClickCapture={stopLinks} className={cn("flex w-full flex-col gap-3 rounded-lg border bg-card p-4 text-card-foreground", className)}>
      {children}
      {onReplay && (
        <Button variant="ghost" size="xs" className="self-end text-muted-foreground" onClick={onReplay}>
          <RotateCcwIcon data-icon="inline-start" />
          Replay
        </Button>
      )}
    </div>
  )
}

const QUESTION = "Can Order #4821 for Jaya Grocer Bangsar ship on Tuesday?"

function Question({ avatar = false }: { avatar?: boolean }) {
  return (
    <div className="flex items-end justify-end gap-2">
      <div className="max-w-[85%] rounded-2xl rounded-br-md bg-muted px-3.5 py-2 text-[13px]">{QUESTION}</div>
      {avatar && (
        <span aria-hidden className="flex size-7 shrink-0 items-center justify-center rounded-full bg-secondary text-[10px] font-semibold text-secondary-foreground">
          AS
        </span>
      )}
    </div>
  )
}

/** The answer as plain sentences, for the blocks that don't do inline citations. */
const ANSWER =
  "Yes. All 4 lines of Order #4821 (RM 2,665.20) are in stock at Shah Alam DC and now reserved for Jaya Grocer Bangsar. It's on 45-day terms and well inside the credit limit. It goes out on van run KV-03 on Tue, 18 Nov, for a 9–11 am drop in Bangsar."
const ANSWER_WORDS = ANSWER.split(" ")

const SPEED: Record<string, number> = { slow: 140, normal: 55, fast: 20 }
const speedOption: Option = {
  id: "speed",
  label: "Speed",
  type: "select",
  default: "normal",
  choices: [
    { value: "slow", label: "Slow" },
    { value: "normal", label: "Normal (55 ms a word)" },
    { value: "fast", label: "Fast" },
  ],
}
const loopOption: Option = { id: "loop", label: "Replay on a loop", type: "switch", default: false }

/* ------------------------------------------------------------------------------------------------
 * Chat: Beautiful UI streaming answer
 * ---------------------------------------------------------------------------------------------- */

const BUI_SOURCES: StreamingSource[] = [
  // Letter avatars only: `image` would load a remote favicon, which the app's CSP blocks.
  { name: "Stock at Shah Alam DC", domain: "stock/SA", href: "#", tone: "bg-sky-600" },
  { name: "Order #4821", domain: "orders/4821", href: "#", tone: "bg-emerald-600" },
  { name: "Route plan KV-03", domain: "routes/KV-03", href: "#", tone: "bg-orange-500" },
]

const BUI_TOKENS: StreamingToken[] = [
  ...words("Yes. All 4 lines of Order #4821 (RM 2,665.20) are in stock at Shah Alam DC and now reserved for Jaya Grocer Bangsar."),
  { text: "", cite: true, source: 0 },
  ...words("It's on 45-day terms and well inside the credit limit."),
  { text: "", cite: true, source: 1 },
  ...words("It goes out on van run KV-03 on Tue, 18 Nov, for a 9–11 am drop in Bangsar."),
  { text: "", cite: true, source: 2 },
]

const FOLLOW_UPS = ["Send Jaya Grocer the delivery note", "Which other orders ride on KV-03?"]

function BuiStream({ ms, sourcesOpen, followUps }: { ms: number; sourcesOpen: boolean; followUps: boolean }) {
  const revealed = useCount(BUI_TOKENS.length, ms)
  return (
    <StreamingAnswer
      tokens={BUI_TOKENS}
      sources={BUI_SOURCES}
      followUps={followUps ? FOLLOW_UPS : []}
      revealed={revealed}
      defaultSourcesOpen={sourcesOpen}
    />
  )
}

function BuiChat({ options: o }: BlockProps) {
  const ms = SPEED[o.speed as string] ?? 55
  const [run, replay] = useRuns(o.loop as boolean, BUI_TOKENS.length * ms + 3400)
  return (
    <Block onReplay={replay}>
      <Question />
      {/* defaultSourcesOpen is read once, so the key remounts it when the option flips. */}
      <BuiStream key={`${run}-${o.sources}`} ms={ms} sourcesOpen={o.sources as boolean} followUps={o.followUps as boolean} />
    </Block>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Chat: Vercel AI Elements Sources
 * ---------------------------------------------------------------------------------------------- */

const AIE_SOURCES = [
  { href: "#", title: "Stock levels · Shah Alam DC" },
  { href: "#", title: "Order #4821 · Jaya Grocer Bangsar" },
  { href: "#", title: "Route plan KV-03 · Tue 18 Nov" },
  { href: "#", title: "Credit terms · C-1077" },
]

function StreamedText({ ms, stream }: { ms: number; stream: boolean }) {
  const n = useCount(ANSWER_WORDS.length, ms, stream)
  return (
    <p className="text-[13px] leading-relaxed">
      {ANSWER_WORDS.slice(0, n).join(" ")}
      {n < ANSWER_WORDS.length && <span aria-hidden className="ml-0.5 inline-block h-3.5 w-0.5 translate-y-0.5 bg-foreground motion-safe:animate-pulse" />}
    </p>
  )
}

function AiElementsChat({ options: o }: BlockProps) {
  const count = Number(o.count) || 3
  const stream = o.stream as boolean
  const [run, replay] = useRuns(false, 0)
  // Sources is typed as a div but renders a Collapsible root, so defaultOpen has to go through untyped.
  const openProps = { defaultOpen: o.open as boolean } as SourcesProps
  return (
    <Block onReplay={stream ? replay : undefined}>
      <Question />
      <div className="flex flex-col gap-1">
        <Sources key={`${o.open}`} className="mb-2" {...openProps}>
          <SourcesTrigger count={count} />
          <SourcesContent>
            {AIE_SOURCES.slice(0, count).map((s) => (
              <Source key={s.title} href={s.href} title={s.title} />
            ))}
          </SourcesContent>
        </Sources>
        <StreamedText key={`${run}-${stream}`} ms={55} stream={stream} />
      </div>
    </Block>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Chat: shadcn baseline
 * ---------------------------------------------------------------------------------------------- */

function PlainAnswer({ stream, flat, avatar, onRegenerate }: { stream: boolean; flat: boolean; avatar: boolean; onRegenerate: () => void }) {
  const n = useCount(ANSWER_WORDS.length, 55, stream)
  const done = n >= ANSWER_WORDS.length
  return (
    <div className="flex items-start gap-2">
      {avatar && (
        <span aria-hidden className="flex size-7 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground">
          <BotIcon className="size-4" />
        </span>
      )}
      <div className={cn("flex min-w-0 flex-col gap-1", flat ? "flex-1" : "max-w-[85%]")}>
        <p className={cn("text-[13px] leading-relaxed", !flat && "rounded-2xl rounded-tl-md border bg-background px-3.5 py-2")}>
          {ANSWER_WORDS.slice(0, n).join(" ")}
          {!done && <span aria-hidden className="ml-0.5 inline-block h-3.5 w-0.5 translate-y-0.5 bg-foreground motion-safe:animate-pulse" />}
        </p>
        <div className={cn("flex gap-0.5 transition-opacity", done ? "opacity-100" : "pointer-events-none opacity-0")} inert={!done}>
          <Button variant="ghost" size="icon-xs" aria-label="Copy answer" className="text-muted-foreground">
            <CopyIcon />
          </Button>
          <Button variant="ghost" size="icon-xs" aria-label="Regenerate" className="text-muted-foreground" onClick={onRegenerate}>
            <RefreshCwIcon />
          </Button>
        </div>
      </div>
    </div>
  )
}

function PlainChat({ options: o }: BlockProps) {
  const stream = o.stream as boolean
  const [run, replay] = useRuns(false, 0)
  return (
    <Block onReplay={stream ? replay : undefined}>
      <Question avatar={o.avatars as boolean} />
      <PlainAnswer key={`${run}-${stream}`} stream={stream} flat={o.layout === "flat"} avatar={o.avatars as boolean} onRegenerate={replay} />
    </Block>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Agent: Beautiful UI thinking
 * ---------------------------------------------------------------------------------------------- */

const TRACES: Record<string, { variant: ThinkingVariant; rows: TraceRow[] }> = {
  steps: {
    variant: "Steps",
    rows: [
      { primary: "Reading Order #4821" },
      { primary: "Checking stock at Shah Alam DC", secondary: "4 SKUs" },
      { primary: "Checking Jaya Grocer's credit", secondary: "45-day terms" },
      { primary: "Booking van run KV-03" },
    ],
  },
  reasoning: {
    variant: "Reasoning",
    rows: [
      { primary: "All 4 lines are in stock at Shah Alam DC, so nothing needs to come up from Johor Bahru." },
      { primary: "Jaya Grocer is well inside its limit on 45-day terms, so the order can be released for Tuesday's KV-03 run." },
    ],
  },
  tools: {
    variant: "Coding",
    rows: [
      { primary: "Read", secondary: "orders/4821", mono: true },
      { primary: "Query", secondary: "stock_levels dc=SA", mono: true },
      { primary: "Update", secondary: "reservations", mono: true, add: 4, del: 0 },
    ],
  },
}

function BuiThinking({ options: o }: BlockProps) {
  const trace = TRACES[o.variant as string] ?? TRACES.steps
  // The built-in timeline settles after about 7.4 s.
  const [run, replay] = useRuns(o.loop as boolean, 10000)
  return (
    <Block onReplay={replay} className="min-h-56">
      <Thinking key={`${run}-${o.variant}`} variant={trace.variant} rows={trace.rows} />
    </Block>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Agent: Beautiful UI tool chips
 * ---------------------------------------------------------------------------------------------- */

const TOOL_STEPS: ToolStep[] = [
  {
    icon: "search",
    label: "Find order",
    chip: "orders.get #4821",
    mono: true,
    detailMono: false,
    detail: [{ text: "Jaya Grocer Bangsar · 4 lines · RM 2,665.20" }, { text: "Status: Confirmed, ships from Shah Alam DC" }],
  },
  {
    icon: "read",
    label: "Check stock",
    chip: "stock_levels dc=SA",
    mono: true,
    detailMono: true,
    detail: [{ text: "BEV-TT30  1,240 on hand" }, { text: "NDL-KR5   3,100 on hand" }],
  },
  {
    icon: "write",
    label: "Reserve 4 lines",
    chip: "stock.reserve",
    mono: true,
    detailMono: true,
    detail: [
      { text: "+ BEV-TT30 × 60", tone: "add" },
      { text: "+ NDL-KR5 × 120", tone: "add" },
    ],
  },
  {
    icon: "run",
    label: "Credit check",
    chip: "credit.check C-1077",
    mono: true,
    detailMono: false,
    detail: [{ text: "✓ Inside the limit on 45-day terms" }],
  },
]

const TOOL_DIFFS: ToolDiff[] = [
  { file: "order-4821.json", add: 2, del: 1 },
  { file: "reservations-SA.csv", add: 4, del: 0 },
]

const TOOL_DIFF_LINES: Record<string, ToolDiffLine[]> = {
  "order-4821.json": [
    { text: '"status": "Confirmed",', tone: "del" },
    { text: '"status": "Picking",', tone: "add" },
    { text: '"reservedAt": "2026-11-16T09:12:00+08:00",', tone: "add" },
  ],
  "reservations-SA.csv": [
    { text: "4821,BEV-TT30,60", tone: "add" },
    { text: "4821,NDL-KR5,120", tone: "add" },
    { text: "4821,SAU-SB200,48", tone: "add" },
    { text: "4821,CKG-CM1L,36", tone: "add" },
  ],
}

function BuiToolChips({ options: o }: BlockProps) {
  // 700 ms per call, plus the diff chips.
  const [run, replay] = useRuns(o.loop as boolean, 7000)
  return (
    <Block onReplay={replay} className="min-h-56">
      <ToolChips
        key={`${run}-${o.diffs}-${o.openFirst}`}
        steps={TOOL_STEPS}
        diffs={o.diffs ? TOOL_DIFFS : []}
        diffLines={TOOL_DIFF_LINES}
        more={null}
        defaultOpenRows={o.openFirst ? [TOOL_STEPS[0].label] : []}
      />
    </Block>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Agent: Beautiful UI approval card
 * ---------------------------------------------------------------------------------------------- */

const RESERVE_QUESTION: ApprovalQuestion = {
  q: "Reserve stock for Order #4821 at Shah Alam DC?",
  type: "radio",
  options: ["Reserve all 4 lines", "Reserve, but hold for a credit check", "Don't reserve yet"],
}

const MORE_QUESTIONS: ApprovalQuestion[] = [
  { q: "What goes on the delivery note?", type: "check", options: ["Line prices in RM", "Jaya Grocer's PO number", "Halal certificate numbers"] },
  { q: "When should it ship?", type: "radio", options: ["Tue, 18 Nov (KV-03)", "Wed, 19 Nov", "Let the route planner decide"] },
]

function BuiApproval({ options: o }: BlockProps) {
  const questions = o.questions === "three" ? [RESERVE_QUESTION, ...MORE_QUESTIONS] : [RESERVE_QUESTION]
  return (
    <Block className="items-center py-6">
      <ApprovalCard
        key={`${o.questions}-${o.header}`}
        questions={questions}
        title={o.header ? "stock.reserve wants to change stock at Shah Alam DC" : undefined}
        icon={o.header ? <ShieldCheckIcon className="size-3.5" /> : undefined}
      />
    </Block>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Agent: Beautiful UI task rows
 * ---------------------------------------------------------------------------------------------- */

const TASKS: Omit<TaskRow, "status">[] = [
  {
    key: "reserve",
    label: "Reserve stock at Shah Alam DC",
    amount: "4 lines",
    step: 1,
    details: [
      { label: "Teh Tarik 3-in-1 × 60", meta: "BEV-TT30" },
      { label: "Instant Noodle Kari × 120", meta: "NDL-KR5" },
    ],
  },
  {
    key: "credit",
    label: "Credit check: Jaya Grocer Bangsar",
    amount: "RM 2,665.20",
    step: 2,
    details: [
      { label: "Terms", meta: "45 days" },
      { label: "Limit left after this order", meta: "RM 3,935" },
    ],
  },
  {
    key: "route",
    label: "Book van run KV-03",
    amount: "Tue 18 Nov",
    step: 3,
    details: [
      { label: "Drop window", meta: "9–11 am" },
      { label: "Driver app", meta: "retry" },
    ],
  },
]

/** Time to wait before each stage; stage 3 is the failed retry when `failOnce` is on. */
const TASK_TICKS = [1500, 2400, 1400, 2400]

function TaskTimeline({ variant, failOnce }: { variant: "Capsules" | "List"; failOnce: boolean }) {
  const stage = useStages(TASK_TICKS)
  const status = (i: number): TaskStatus => {
    if (i === 0) return "done"
    if (i === 1) return stage < 2 ? "running" : "done"
    if (stage < 2) return "pending"
    if (stage === 2) return "running"
    if (stage === 3) return failOnce ? "failed" : "running"
    return "done"
  }
  const rows: TaskRow[] = TASKS.map((t, i) => ({ ...t, status: status(i) }))
  return <TaskRows rows={rows} variant={variant} openKey={stage === 1 ? "credit" : undefined} />
}

/** Steps through `ticks.length` stages, waiting ticks[i] before stage i + 1. */
function useStages(ticks: number[]) {
  const [stage, setStage] = useState(0)
  useEffect(() => {
    if (stage >= ticks.length) return
    const t = setTimeout(() => setStage((s) => s + 1), ticks[stage])
    return () => clearTimeout(t)
  }, [stage, ticks])
  return stage
}

function BuiTasks({ options: o }: BlockProps) {
  const [run, replay] = useRuns(o.loop as boolean, 10500)
  return (
    <Block onReplay={replay} className="min-h-64">
      <TaskTimeline key={`${run}-${o.failOnce}`} variant={o.variant === "list" ? "List" : "Capsules"} failOnce={o.failOnce as boolean} />
    </Block>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Agent: Vercel AI Elements chain of thought
 * ---------------------------------------------------------------------------------------------- */

/** Time each step stays active before the next arrives; after the last tick the trace is done. */
const COT_TICKS = [1100, 1300, 1300, 1300]
const NO_TICKS: number[] = []

function CotRun({ open, live, results }: { open: boolean; live: boolean; results: boolean }) {
  // Live: steps arrive one by one and the newest is active. Otherwise the finished trace.
  const stage = useStages(live ? COT_TICKS : NO_TICKS)
  const done = !live || stage >= COT_TICKS.length
  const arrived = done ? 4 : stage + 1
  const status = (i: number) => (done || i < arrived - 1 ? "complete" : "active")
  return (
    <ChainOfThought defaultOpen={open} className="w-full">
      <ChainOfThoughtHeader>{done ? "Thought for 5 seconds" : "Thinking…"}</ChainOfThoughtHeader>
      <ChainOfThoughtContent>
        {arrived >= 1 && (
          <ChainOfThoughtStep icon={SearchIcon} label="Looking up Order #4821" status={status(0)}>
            {results && (
              <ChainOfThoughtSearchResults>
                <ChainOfThoughtSearchResult>Jaya Grocer Bangsar</ChainOfThoughtSearchResult>
                <ChainOfThoughtSearchResult>4 lines</ChainOfThoughtSearchResult>
                <ChainOfThoughtSearchResult>RM 2,665.20</ChainOfThoughtSearchResult>
              </ChainOfThoughtSearchResults>
            )}
          </ChainOfThoughtStep>
        )}
        {arrived >= 2 && (
          <ChainOfThoughtStep icon={PackageIcon} label="Checking stock at Shah Alam DC" description="All 4 SKUs on hand; reserved for this order" status={status(1)} />
        )}
        {arrived >= 3 && (
          <ChainOfThoughtStep icon={ShieldCheckIcon} label="Running a credit check" description="45-day terms, inside the limit" status={status(2)} />
        )}
        {arrived >= 4 && <ChainOfThoughtStep icon={TruckIcon} label="Booking van run KV-03 for Tue, 18 Nov" status={status(3)} />}
      </ChainOfThoughtContent>
    </ChainOfThought>
  )
}

function AiElementsCot({ options: o }: BlockProps) {
  const live = o.live as boolean
  const [run, replay] = useRuns(false, 0)
  return (
    <Block onReplay={live ? replay : undefined} className="min-h-56">
      <CotRun key={`${run}-${o.open}-${live}`} open={o.open as boolean} live={live} results={o.results as boolean} />
    </Block>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Adapters
 * ---------------------------------------------------------------------------------------------- */

const BUI_CSS = "Copy the bui- keyframes from src/demos/ai/bui.css, not Beautiful UI's foundation.css"
const buiImport = (file: string) => `// our patched copy, with controlled props: src/demos/ai/${file}.tsx`

const wordTimer = (o: OptionValues) =>
  join(
    `// Drive it from your token stream; here, a timer.`,
    `const [revealed, setRevealed] = useState(0)`,
    `useEffect(() => {`,
    `  if (revealed >= tokens.length) return`,
    `  const t = setTimeout(() => setRevealed((n) => n + 1), ${SPEED[o.speed as string] ?? 55})`,
    `  return () => clearTimeout(t)`,
    `}, [revealed])`,
  )

export const adapters: Adapter[] = [
  /* ── Chat ── */
  {
    id: "chat-streaming",
    slot: "chat",
    library: "beautiful-ui",
    label: "Streaming answer",
    note: "Words stream in with source chips inline beside the claims they back",
    options: [
      speedOption,
      { id: "sources", label: "Sources list open", type: "switch", default: true },
      { id: "followUps", label: "Follow-ups", type: "switch", default: true },
      loopOption,
    ],
    // Tokens mapped to shadcn's in our copy; plain CSS motion, scoped to [data-bui] for reduced motion.
    traits: { darkMode: "ok" },
    install: ["Copy from beautifului.dev/r/streaming-text.json", BUI_CSS],
    code: (o) =>
      join(
        `import { StreamingAnswer } from "@/demos/ai/streaming"`,
        `import { words } from "@/demos/ai/stream-tokens"`,
        buiImport("streaming"),
        ``,
        `const sources = [`,
        `  { name: "Stock at Shah Alam DC", domain: "stock/SA", href: "/stock/SA", tone: "bg-sky-600" },`,
        `  { name: "Order #4821", domain: "orders/4821", href: "/orders/4821", tone: "bg-emerald-600" },`,
        `]`,
        `const tokens = [`,
        `  ...words("Yes. All 4 lines of Order #4821 (RM 2,665.20) are in stock at Shah Alam DC."),`,
        `  { text: "", cite: true, source: 0 },`,
        `]`,
        ``,
        wordTimer(o),
        ``,
        `<StreamingAnswer`,
        `  tokens={tokens}`,
        `  sources={sources}`,
        `  revealed={revealed}`,
        o.sources && `  defaultSourcesOpen`,
        o.followUps ? `  followUps={["Send Jaya Grocer the delivery note"]}` : `  followUps={[]}`,
        `/>`,
      ),
    render: BuiChat,
  },
  {
    id: "chat-sources",
    slot: "chat",
    library: "ai-elements",
    label: "Sources",
    note: "A plain collapsible “Used N sources” list above the answer, built for the AI SDK",
    options: [
      { id: "open", label: "Open", type: "switch", default: false },
      {
        id: "count",
        label: "Sources",
        type: "select",
        default: "3",
        choices: [
          { value: "2", label: "2" },
          { value: "3", label: "3" },
          { value: "4", label: "4" },
        ],
      },
      { id: "stream", label: "Stream the answer", type: "switch", default: true },
    ],
    // No motion import, only theme tokens. Its open/close animation targets Radix's data-state, so it never runs here.
    traits: { darkMode: "ok" },
    install: ["npx shadcn@latest add https://registry.ai-sdk.dev/sources.json"],
    code: (o) =>
      join(
        `import { Source, Sources, SourcesContent, SourcesTrigger } from "@/components/ai-elements/sources"`,
        ``,
        `// With the AI SDK: message.parts.filter((p) => p.type === "source-url")`,
        `const sources = [`,
        ...AIE_SOURCES.slice(0, Number(o.count) || 3).map((s) => `  { url: "/…", title: "${s.title}" },`),
        `]`,
        ``,
        o.open && `// Sources is typed as a div, but it renders a Collapsible root.`,
        `<Sources${o.open ? ` {...({ defaultOpen: true } as SourcesProps)}` : ""}>`,
        `  <SourcesTrigger count={sources.length} />`,
        `  <SourcesContent>`,
        `    {sources.map((s) => <Source key={s.url} href={s.url} title={s.title} />)}`,
        `  </SourcesContent>`,
        `</Sources>`,
        `<p>{text}</p>${o.stream ? " {/* streamed by useChat */}" : ""}`,
      ),
    render: AiElementsChat,
  },
  {
    id: "chat-shadcn",
    slot: "chat",
    library: "shadcn",
    label: "Plain bubble",
    note: "A message bubble on theme tokens, with copy and regenerate once it settles",
    options: [
      { id: "stream", label: "Stream the answer", type: "switch", default: true },
      {
        id: "layout",
        label: "Layout",
        type: "select",
        default: "bubbles",
        choices: [
          { value: "bubbles", label: "Bubbles" },
          { value: "flat", label: "Flat answer" },
        ],
      },
      { id: "avatars", label: "Avatars", type: "switch", default: true },
    ],
    traits: { darkMode: "ok" },
    install: ["npx shadcn@latest add button"],
    code: (o) =>
      join(
        `import { CopyIcon, RefreshCwIcon } from "lucide-react"`,
        `import { Button } from "@/components/ui/button"`,
        ``,
        `<div className="flex items-start gap-2">`,
        o.avatars && `  <span className="flex size-7 items-center justify-center rounded-full bg-primary text-primary-foreground"><BotIcon className="size-4" /></span>`,
        `  <div className="flex flex-col gap-1">`,
        `    <p className="text-sm${o.layout === "flat" ? "" : " rounded-2xl rounded-tl-md border bg-background px-3.5 py-2"}">`,
        `      {text}`,
        o.stream && `      {streaming && <span aria-hidden className="inline-block h-3.5 w-0.5 bg-foreground motion-safe:animate-pulse" />}`,
        `    </p>`,
        `    <div className="flex gap-0.5">`,
        `      <Button variant="ghost" size="icon-xs" aria-label="Copy answer"><CopyIcon /></Button>`,
        `      <Button variant="ghost" size="icon-xs" aria-label="Regenerate" onClick={regenerate}><RefreshCwIcon /></Button>`,
        `    </div>`,
        `  </div>`,
        `</div>`,
      ),
    render: PlainChat,
  },

  /* ── Agent ── */
  {
    id: "agent-thinking",
    slot: "agent",
    library: "beautiful-ui",
    label: "Thinking",
    note: "A shimmering label whose trace opens while it works and folds to one line when done",
    options: [
      {
        id: "variant",
        label: "Trace",
        type: "select",
        default: "steps",
        choices: [
          { value: "steps", label: "Steps" },
          { value: "reasoning", label: "Reasoning" },
          { value: "tools", label: "Tool calls" },
        ],
      },
      loopOption,
    ],
    traits: { darkMode: "ok" },
    install: ["Copy from beautifului.dev/r/thinking-state.json", BUI_CSS],
    code: (o) => {
      const t = TRACES[o.variant as string] ?? TRACES.steps
      return join(
        `import { Thinking } from "@/demos/ai/thinking"`,
        buiImport("thinking"),
        ``,
        `const rows = [`,
        ...t.rows.map(
          (r) =>
            `  { primary: "${r.primary}"${r.secondary ? `, secondary: "${r.secondary}"` : ""}${r.mono ? ", mono: true" : ""}${r.add !== undefined ? `, add: ${r.add}, del: ${r.del}` : ""} },`,
        ),
        `]`,
        ``,
        `// Controlled: follow the agent instead of the demo timeline.`,
        `<Thinking variant="${t.variant}" rows={rows} working={agent.busy} visible={agent.steps.length} />`,
      )
    },
    render: BuiThinking,
  },
  {
    id: "agent-tools",
    slot: "agent",
    library: "beautiful-ui",
    label: "Tool chips",
    note: "Each tool call is a compact row that opens; changed records end as diff chips",
    options: [
      { id: "diffs", label: "Diff chips", type: "switch", default: true },
      { id: "openFirst", label: "First call open", type: "switch", default: false },
      loopOption,
    ],
    traits: { darkMode: "ok" },
    install: ["Copy from beautifului.dev/r/tool-chips.json", BUI_CSS],
    code: (o) =>
      join(
        `import { ToolChips } from "@/demos/ai/tool-chips"`,
        buiImport("tool-chips"),
        ``,
        `const steps = [`,
        `  { icon: "search", label: "Find order", chip: "orders.get #4821", mono: true, detailMono: false,`,
        `    detail: [{ text: "Jaya Grocer Bangsar · 4 lines · RM 2,665.20" }] },`,
        `  { icon: "write", label: "Reserve 4 lines", chip: "stock.reserve", mono: true, detailMono: true,`,
        `    detail: [{ text: "+ BEV-TT30 × 60", tone: "add" }] },`,
        `]`,
        ``,
        `<ToolChips`,
        `  steps={steps}`,
        `  shown={agent.toolCalls.length}`,
        o.diffs ? `  diffs={[{ file: "order-4821.json", add: 2, del: 1 }]}` : `  diffs={[]}`,
        o.diffs && `  diffLines={diffLines}`,
        o.openFirst && `  defaultOpenRows={["Find order"]}`,
        `  more={null}`,
        `/>`,
      ),
    render: BuiToolChips,
  },
  {
    id: "agent-approval",
    slot: "agent",
    library: "beautiful-ui",
    label: "Approval card",
    note: "Asks before a tool acts: one question at a time, with a typed answer as a way out",
    options: [
      {
        id: "questions",
        label: "Questions",
        type: "select",
        default: "one",
        choices: [
          { value: "one", label: "One (permission)" },
          { value: "three", label: "Three" },
        ],
      },
      { id: "header", label: "Tool header", type: "switch", default: true },
    ],
    traits: { darkMode: "ok" },
    install: ["Copy from beautifului.dev/r/approval-card.json", BUI_CSS],
    code: (o) =>
      join(
        o.header && `import { ShieldCheckIcon } from "lucide-react"`,
        `import { ApprovalCard } from "@/demos/ai/approval-card"`,
        buiImport("approval-card"),
        ``,
        `const questions = [`,
        `  { q: "${RESERVE_QUESTION.q}", type: "radio", options: ["Reserve all 4 lines", "Reserve, but hold for a credit check", "Don't reserve yet"] },`,
        o.questions === "three" && `  { q: "${MORE_QUESTIONS[0].q}", type: "check", options: ["Line prices in RM", "Jaya Grocer's PO number", "Halal certificate numbers"] },`,
        o.questions === "three" && `  { q: "${MORE_QUESTIONS[1].q}", type: "radio", options: ["Tue, 18 Nov (KV-03)", "Wed, 19 Nov", "Let the route planner decide"] },`,
        `]`,
        ``,
        `<ApprovalCard`,
        `  questions={questions}`,
        o.header && `  title="stock.reserve wants to change stock at Shah Alam DC"`,
        o.header && `  icon={<ShieldCheckIcon className="size-3.5" />}`,
        `  onSubmitted={(answers) => agent.resume(answers)}`,
        `  onSkip={() => agent.cancel()}`,
        `/>`,
      ),
    render: BuiApproval,
  },
  {
    id: "agent-tasks",
    slot: "agent",
    library: "beautiful-ui",
    label: "Task rows",
    note: "Live task status with a spinner ring, a failed-then-retried row and per-task details",
    options: [
      {
        id: "variant",
        label: "Style",
        type: "select",
        default: "capsules",
        choices: [
          { value: "capsules", label: "Capsules" },
          { value: "list", label: "List" },
        ],
      },
      { id: "failOnce", label: "Last task fails once", type: "switch", default: true },
      loopOption,
    ],
    traits: { darkMode: "ok" },
    install: ["Copy from beautifului.dev/r/task-rows.json", BUI_CSS],
    code: (o) =>
      join(
        `import { TaskRows } from "@/demos/ai/task-rows"`,
        buiImport("task-rows"),
        ``,
        `// You own the statuses: "done" | "running" | "failed" | "pending".`,
        `const rows = [`,
        `  { key: "reserve", label: "Reserve stock at Shah Alam DC", amount: "4 lines", status: "done", step: 1, details: [] },`,
        `  { key: "credit", label: "Credit check: Jaya Grocer Bangsar", amount: "RM 2,665.20", status: "running", step: 2, details: [] },`,
        `  { key: "route", label: "Book van run KV-03", amount: "Tue 18 Nov", status: ${o.failOnce ? `"failed"` : `"pending"`}, step: 3, details: [] },`,
        `]`,
        ``,
        `<TaskRows rows={rows} variant="${o.variant === "list" ? "List" : "Capsules"}" openKey="credit" />`,
      ),
    render: BuiTasks,
  },
  {
    id: "agent-chain-of-thought",
    slot: "agent",
    library: "ai-elements",
    label: "Chain of thought",
    note: "Composable steps with icons, status and result badges; plainer, and made for AI SDK parts",
    options: [
      { id: "open", label: "Open", type: "switch", default: true },
      { id: "live", label: "Steps arrive live", type: "switch", default: true },
      { id: "results", label: "Result badges", type: "switch", default: true },
    ],
    // No motion import (tw-animate-css entrances), only theme tokens. Its collapse animation never fires on Base UI.
    traits: { darkMode: "ok" },
    install: ["npx shadcn@latest add https://registry.ai-sdk.dev/chain-of-thought.json"],
    code: (o) =>
      join(
        `import { PackageIcon, SearchIcon, ShieldCheckIcon, TruckIcon } from "lucide-react"`,
        `import {`,
        `  ChainOfThought,`,
        `  ChainOfThoughtContent,`,
        `  ChainOfThoughtHeader,`,
        o.results && `  ChainOfThoughtSearchResult,`,
        o.results && `  ChainOfThoughtSearchResults,`,
        `  ChainOfThoughtStep,`,
        `} from "@/components/ai-elements/chain-of-thought"`,
        ``,
        `<ChainOfThought${o.open ? " defaultOpen" : ""}>`,
        `  <ChainOfThoughtHeader>${o.live ? `{busy ? "Thinking…" : "Thought for 5 seconds"}` : "Thought for 5 seconds"}</ChainOfThoughtHeader>`,
        `  <ChainOfThoughtContent>`,
        `    <ChainOfThoughtStep icon={SearchIcon} label="Looking up Order #4821">`,
        o.results && `      <ChainOfThoughtSearchResults>`,
        o.results && `        <ChainOfThoughtSearchResult>Jaya Grocer Bangsar</ChainOfThoughtSearchResult>`,
        o.results && `        <ChainOfThoughtSearchResult>RM 2,665.20</ChainOfThoughtSearchResult>`,
        o.results && `      </ChainOfThoughtSearchResults>`,
        `    </ChainOfThoughtStep>`,
        `    <ChainOfThoughtStep icon={PackageIcon} label="Checking stock at Shah Alam DC" description="All 4 SKUs on hand" />`,
        `    <ChainOfThoughtStep icon={ShieldCheckIcon} label="Running a credit check"${o.live ? ` status="active"` : ""} />`,
        `    <ChainOfThoughtStep icon={TruckIcon} label="Booking van run KV-03"${o.live ? ` status="pending"` : ""} />`,
        `  </ChainOfThoughtContent>`,
        `</ChainOfThought>`,
      ),
    render: AiElementsCot,
  },
]

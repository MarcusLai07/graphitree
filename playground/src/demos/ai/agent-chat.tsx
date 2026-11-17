/**
 * A fake agent chat built from the Beautiful UI copies in this folder.
 * Everything is simulated with setInterval/setTimeout: no network, no model.
 *
 * Turn script (full): loading → thinking trace → tool calls → approval for a
 * tool that writes outside the sandbox → task rows → streamed answer with
 * inline sources and follow-ups. Follow-ups and the composer run a short turn.
 */
import { useEffect, useLayoutEffect, useRef, useState, type FormEvent } from "react"
import { ArrowUpIcon, GitPullRequestIcon, RotateCcwIcon, ShieldCheckIcon, SparklesIcon } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Textarea } from "@/components/ui/textarea"
import { cn } from "@/lib/utils"
import { ApprovalCard } from "./approval-card"
import { LoadingState } from "./loading-state"
import { StreamingAnswer } from "./streaming"
import { words, type StreamingSource, type StreamingToken } from "./stream-tokens"
import { Thinking, type TraceRow } from "./thinking"
import { TaskRows, type TaskRow, type TaskStatus } from "./task-rows"
import { ToolChips } from "./tool-chips"

type Phase = "loading" | "thinking" | "tools" | "approval" | "tasks" | "answer" | "done"
type Decision = "both" | "odyssey" | "denied"

type Turn = {
  id: number
  prompt: string
  kind: "full" | "short"
  phase: Phase
  thinking: number
  tools: number
  decision: Decision | null
  autoApproved: boolean
  taskFrame: number
  answer: number
}

const FIRST_PROMPT = "Which of my repos still use Vaul? Move them to Base UI's Drawer and open PRs."

const FULL_TRACE: TraceRow[] = [
  { primary: "Reading the knowledge graph" },
  { primary: "Finding repos that import vaul", secondary: "2 repos" },
  { primary: "Checking how each drawer is used", secondary: "6 files" },
  { primary: "Planning the migration" },
]

const SHORT_TRACE: TraceRow[] = [{ primary: "Searching the graph" }, { primary: "Summing it up" }]

const SOURCES: StreamingSource[] = [
  { name: "Knowledge graph", domain: "graph.json", href: "#", tone: "bg-emerald-600" },
  { name: "Base UI Drawer docs", domain: "base-ui.com", href: "https://base-ui.com/react/components/drawer", tone: "bg-sky-600" },
  { name: "Playbook: Drawers", domain: "PLAYBOOK.md", href: "#", tone: "bg-orange-500" },
]

function answerFor(turn: Turn): StreamingToken[] {
  if (turn.kind === "short") {
    return [
      ...words("Three more repos lean on libraries the Playbook marks as avoid:"),
      ...words("graphitree-site (react-hot-toast), depot (vaul, now in a PR) and an old admin portal (moment)."),
      { text: "", cite: true, source: 0 },
      ...words("Want me to queue them up the same way?"),
    ]
  }
  const head = words("Two repos still used Vaul: odyssey (the mobile composer sheet) and depot (the pick-list drawer).")
  const cite0: StreamingToken = { text: "", cite: true, source: 0 }
  const cite1: StreamingToken = { text: "", cite: true, source: 1 }
  const cite2: StreamingToken = { text: "", cite: true, source: 2 }
  if (turn.decision === "denied")
    return [...head, cite0, ...words("I left the changes on a local branch and opened nothing. The swap to Base UI's Drawer is mostly import changes."), cite1]
  if (turn.decision === "odyssey")
    return [...head, cite0, ...words("I opened a draft PR for odyssey only; depot is ready on a local branch. Base UI's Drawer kept the snap points."), cite1]
  return [
    ...head,
    cite0,
    ...words("Both now use Base UI's Drawer with the same snap points, and I opened draft PRs. The depot push failed once on a stale token and went through on retry."),
    cite1,
    ...words("The Playbook already says to avoid Vaul for new work."),
    cite2,
  ]
}

function taskRowsFor(decision: Decision | null): TaskRow[] {
  const rows: TaskRow[] = [
    {
      key: "branch",
      label: "Commit to migrate/vaul-to-base-ui",
      amount: "2 repos",
      status: "pending",
      step: 1,
      details: [
        { label: "odyssey", meta: "3 files" },
        { label: "depot", meta: "2 files" },
      ],
    },
    {
      key: "pr-odyssey",
      label: "Open draft PR in odyssey",
      amount: "#412",
      status: "pending",
      step: 2,
      details: [
        { label: "Type-check", meta: "pass" },
        { label: "Reviewers", meta: "you" },
      ],
    },
  ]
  if (decision === "both")
    rows.push({
      key: "pr-depot",
      label: "Open draft PR in depot",
      amount: "#88",
      status: "pending",
      step: 3,
      details: [
        { label: "Push", meta: "retried once" },
        { label: "Type-check", meta: "pass" },
      ],
    })
  return rows
}

/** Frames of statuses: each task runs then completes; depot fails once and retries. */
function taskFrames(count: number): TaskStatus[][] {
  const frames: TaskStatus[][] = []
  const s: TaskStatus[] = Array(count).fill("pending")
  for (let i = 0; i < count; i++) {
    s[i] = "running"
    frames.push([...s])
    if (i === 2) {
      s[i] = "failed"
      frames.push([...s])
      s[i] = "running"
      frames.push([...s])
    }
    s[i] = "done"
    frames.push([...s])
  }
  return frames
}

const newTurn = (id: number, prompt: string, kind: Turn["kind"]): Turn => ({
  id,
  prompt,
  kind,
  phase: "loading",
  thinking: 0,
  tools: 0,
  decision: null,
  autoApproved: false,
  taskFrame: 0,
  answer: 0,
})

const TOOL_STEPS = 4 // ToolChips default steps; +1 reveals the diff chips

type Patch = Partial<Turn> | ((t: Turn) => Partial<Turn>)

/** Advances the live turn. One interval per phase; updaters read the latest turn. */
function useTurnDriver(turn: Turn | undefined, update: (patch: Patch) => void, autoApprove: boolean, speed: number) {
  const id = turn?.id
  const phase = turn?.phase
  const kind = turn?.kind
  const decision = turn?.decision ?? null

  useEffect(() => {
    if (id === undefined || !phase || !kind) return
    const ms = (n: number) => n / speed
    const trace = kind === "full" ? FULL_TRACE : SHORT_TRACE
    let timer: ReturnType<typeof setInterval> | undefined

    switch (phase) {
      case "loading":
        timer = setTimeout(() => update({ phase: "thinking" }), ms(kind === "full" ? 1400 : 800))
        break
      case "thinking":
        timer = setInterval(
          () => update((t) => (t.thinking < trace.length ? { thinking: t.thinking + 1 } : { phase: kind === "full" ? "tools" : "answer" })),
          ms(650),
        )
        break
      case "tools":
        timer = setInterval(() => update((t) => (t.tools < TOOL_STEPS + 1 ? { tools: t.tools + 1 } : { phase: "approval" })), ms(600))
        break
      case "approval":
        if (autoApprove) timer = setTimeout(() => update({ decision: "both", autoApproved: true, phase: "tasks" }), ms(700))
        break
      case "tasks": {
        const frames = taskFrames(taskRowsFor(decision).length).length
        timer = setInterval(() => update((t) => (t.taskFrame < frames - 1 ? { taskFrame: t.taskFrame + 1 } : { phase: "answer" })), ms(800))
        break
      }
      case "answer":
        // the "token stream": one word per tick
        timer = setInterval(() => update((t) => (t.answer < answerFor(t).length ? { answer: t.answer + 1 } : { phase: "done" })), ms(55))
        break
    }
    return () => {
      clearTimeout(timer)
      clearInterval(timer)
    }
  }, [id, phase, kind, decision, update, autoApprove, speed])
}

const phaseOrder: Phase[] = ["loading", "thinking", "tools", "approval", "tasks", "answer", "done"]
const reached = (turn: Turn, phase: Phase) => phaseOrder.indexOf(turn.phase) >= phaseOrder.indexOf(phase)

function AgentTurn({ turn, onDecide, onFollowUp }: { turn: Turn; onDecide: (d: Decision) => void; onFollowUp: (text: string) => void }) {
  const full = turn.kind === "full"
  const trace = full ? FULL_TRACE : SHORT_TRACE
  const tasks = taskRowsFor(turn.decision)
  const frame = taskFrames(tasks.length)[turn.taskFrame] ?? []
  const liveTasks = tasks.map((t, i) => ({ ...t, status: frame[i] ?? "pending" }))
  const runningKey = liveTasks.find((t) => t.status === "running" || t.status === "failed")?.key

  return (
    <div className="flex gap-3">
      <span className="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground">
        <SparklesIcon className="size-3.5" />
      </span>
      <div className="flex min-w-0 flex-1 flex-col gap-3">
        {turn.phase === "loading" ? (
          <LoadingState label={full ? "Reading the graph" : "Looking"} pattern={full ? "Drive" : "Dots"} className="h-7" />
        ) : (
          <Thinking
            variant="Steps"
            rows={trace}
            working={turn.phase === "thinking"}
            visible={turn.thinking}
            done={full ? "Thought for 3 seconds" : "Thought for 1 second"}
          />
        )}

        {full && reached(turn, "tools") && <ToolChips shown={turn.tools} header={`${Math.min(turn.tools, TOOL_STEPS)} tool calls, 3 files changed`} more={null} />}

        {full && turn.phase === "approval" && (
          <ApprovalCard
            title={
              <span>
                <span className="font-mono text-foreground">github.create_pull_request</span> needs your OK
              </span>
            }
            icon={<GitPullRequestIcon className="size-3.5" />}
            questions={[{ q: "Push the branch and open draft PRs?", type: "radio", options: ["Open both PRs", "Only odyssey", "Don't open any"] }]}
            labels={{ send: "Allow", skip: "Deny", customPlaceholder: "Tell the agent something else…" }}
            resettable={false}
            onSubmitted={(answers) => {
              const pick = answers[0]?.[0]
              onDecide(pick === 0 ? "both" : pick === 1 ? "odyssey" : "denied")
            }}
            onSkip={() => onDecide("denied")}
            className="max-w-sm"
          />
        )}

        {full && turn.decision && (
          <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground" style={{ animation: "bui-fade-in 250ms ease-out both" }}>
            <ShieldCheckIcon className="size-3.5" />
            {turn.decision === "denied" ? (
              <span>You denied github.create_pull_request</span>
            ) : (
              <span>
                {turn.autoApproved ? "Auto-approved" : "You allowed"} github.create_pull_request
                {turn.decision === "odyssey" ? " for odyssey only" : ""}
              </span>
            )}
          </div>
        )}

        {full && reached(turn, "tasks") && turn.decision !== "denied" && <TaskRows rows={liveTasks} variant="List" openKey={turn.phase === "tasks" ? runningKey : undefined} />}

        {reached(turn, "answer") && (
          <StreamingAnswer
            tokens={answerFor(turn)}
            revealed={turn.answer}
            sources={full ? SOURCES : SOURCES.slice(0, 1)}
            followUps={full ? ["Which other repos use libraries I should avoid?"] : []}
            onFollowUp={onFollowUp}
          />
        )}
      </div>
    </div>
  )
}

export function AgentChat({
  autoApprove = false,
  compact = false,
  speed = 1,
  className,
}: {
  autoApprove?: boolean
  compact?: boolean
  speed?: number
  className?: string
}) {
  const [turns, setTurns] = useState<Turn[]>(() => [newTurn(1, FIRST_PROMPT, "full")])
  const [draft, setDraft] = useState("")
  const scrollRef = useRef<HTMLDivElement>(null)
  const last = turns[turns.length - 1]
  const busy = last && last.phase !== "done"

  const [update] = useState(
    () => (patch: Patch) =>
      setTurns((ts) => ts.map((t, i) => (i === ts.length - 1 ? { ...t, ...(typeof patch === "function" ? patch(t) : patch) } : t))),
  )
  useTurnDriver(last, update, autoApprove, speed)

  useLayoutEffect(() => {
    const el = scrollRef.current
    if (el) el.scrollTop = el.scrollHeight
  }, [turns])

  const ask = (prompt: string) => {
    if (busy || !prompt.trim()) return
    setTurns((ts) => [...ts, newTurn(ts.length + 1, prompt.trim(), "short")])
    setDraft("")
  }
  const submit = (e: FormEvent) => {
    e.preventDefault()
    ask(draft)
  }
  const replay = () => {
    setTurns([newTurn(Date.now(), FIRST_PROMPT, "full")])
    setDraft("")
  }

  return (
    <div className={cn("flex w-full flex-col overflow-hidden rounded-xl bg-background ring-1 ring-foreground/10", compact ? "h-[600px]" : "h-[640px]", className)}>
      <header className="flex items-center gap-2 border-b px-4 py-2.5">
        <span className="text-sm font-medium">Graphitree agent</span>
        <Badge variant="outline" className="font-normal text-muted-foreground">
          {autoApprove ? "auto-approve on" : "asks before writing"}
        </Badge>
        <Button variant="ghost" size="sm" className="ml-auto" onClick={replay}>
          <RotateCcwIcon data-icon="inline-start" />
          Replay
        </Button>
      </header>

      <div ref={scrollRef} className="flex-1 overflow-y-auto scroll-smooth">
        <div className={cn("flex flex-col gap-6 py-5", compact ? "px-4" : "px-6")}>
          {turns.map((turn) => (
            <div key={turn.id} className="flex flex-col gap-4">
              <div className="ml-auto max-w-[85%] rounded-2xl rounded-br-md bg-muted px-3.5 py-2 text-[13px] text-foreground">{turn.prompt}</div>
              <AgentTurn
                turn={turn}
                onDecide={(decision) => update({ decision, phase: decision === "denied" ? "answer" : "tasks" })}
                onFollowUp={ask}
              />
            </div>
          ))}
        </div>
      </div>

      <form onSubmit={submit} className="border-t p-3">
        <div className="flex items-end gap-2 rounded-xl bg-muted/50 p-1.5 ring-1 ring-border focus-within:ring-ring/60">
          <Textarea
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault()
                ask(draft)
              }
            }}
            placeholder={last?.phase === "approval" && !autoApprove ? "Waiting for your answer above…" : busy ? "The agent is working…" : "Ask a follow-up"}
            aria-label="Message the agent"
            rows={1}
            className="max-h-32 min-h-8 resize-none border-0 bg-transparent px-2 py-1.5 shadow-none focus-visible:ring-0 dark:bg-transparent"
          />
          <Button type="submit" size="icon" className="rounded-full" disabled={busy || !draft.trim()} aria-label="Send">
            <ArrowUpIcon />
          </Button>
        </div>
      </form>
    </div>
  )
}

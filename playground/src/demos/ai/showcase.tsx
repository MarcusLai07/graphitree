/** Small wrappers that let each block be replayed on its own on the AI page. */
import { useEffect, useState, type ReactNode } from "react"
import { RotateCcwIcon, SearchIcon, FileTextIcon, GitBranchIcon } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  ChainOfThought,
  ChainOfThoughtContent,
  ChainOfThoughtHeader,
  ChainOfThoughtSearchResult,
  ChainOfThoughtSearchResults,
  ChainOfThoughtStep,
} from "@/components/ai-elements/chain-of-thought"
import { Source, Sources, SourcesContent, SourcesTrigger } from "@/components/ai-elements/sources"
import { StreamText } from "./streaming"
import { TaskRows, type TaskRow, type TaskStatus } from "./task-rows"

/** Remounts its children on "Replay" so self-running demos start over. */
export function Replayable({ children, className }: { children: (key: number) => ReactNode; className?: string }) {
  const [key, setKey] = useState(0)
  return (
    <div className={className ?? "flex w-full flex-col items-start gap-3"}>
      {children(key)}
      <Button variant="ghost" size="xs" className="text-muted-foreground" onClick={() => setKey((k) => k + 1)}>
        <RotateCcwIcon data-icon="inline-start" />
        Replay
      </Button>
    </div>
  )
}

/* ── Task rows: the original's demo timeline, driven from outside ── */

const TASKS: TaskRow[] = [
  {
    key: "verify",
    label: "Index 30 repos",
    amount: "49k nodes",
    status: "done",
    details: [
      { label: "Parsed TypeScript and Swift", meta: "30/30" },
      { label: "Skipped vendored folders", meta: "12" },
    ],
  },
  {
    key: "index",
    label: "Rebuild the Playbook",
    amount: "13 libraries",
    status: "running",
    step: 2,
    details: [
      { label: "Reading library notes", meta: "13 files" },
      { label: "Checking install commands", meta: "68%" },
    ],
  },
  {
    key: "backup",
    label: "Back up graphify-out",
    amount: "214 MB",
    status: "pending",
    step: 3,
    details: [
      { label: "Compress graph.json", meta: "done" },
      { label: "Push to backup remote", meta: "retry" },
    ],
  },
]

const TICKS = [600, 900, 2400, 1400, 2400, 600]

export function TaskTimeline({ variant }: { variant: "Capsules" | "List" }) {
  const [tick, setTick] = useState(0)
  useEffect(() => {
    if (tick >= TICKS.length - 1) return
    const t = setTimeout(() => setTick((x) => x + 1), TICKS[tick])
    return () => clearTimeout(t)
  }, [tick])
  const third: TaskStatus = tick < 3 ? "pending" : tick === 3 ? "failed" : "done"
  const rows = TASKS.map((r) => (r.key === "backup" ? { ...r, status: third } : r))
  return <TaskRows rows={rows} variant={variant} openKey={tick === 2 ? "index" : undefined} />
}

/* ── StreamText playground ── */

export function StreamTextDemo() {
  const [text, setText] = useState("Graphitree found 3 repos using libraries the Playbook marks as avoid.")
  const [run, setRun] = useState(0)
  return (
    <div className="flex w-full flex-col gap-3">
      <p className="min-h-12 text-[13px] leading-relaxed">
        <StreamText key={run} text={text} />
      </p>
      <form
        className="flex gap-2"
        onSubmit={(e) => {
          e.preventDefault()
          setRun((r) => r + 1)
        }}
      >
        <Input value={text} onChange={(e) => setText(e.target.value)} aria-label="Text to stream" className="h-8 text-xs" />
        <Button type="submit" size="sm" variant="outline">
          Stream
        </Button>
      </form>
    </div>
  )
}

/* ── Vercel AI Elements, installed from registry.ai-sdk.dev ── */

export function AIElementsChainOfThought() {
  return (
    <ChainOfThought defaultOpen className="w-full">
      <ChainOfThoughtHeader>Thought for 3 seconds</ChainOfThoughtHeader>
      <ChainOfThoughtContent>
        <ChainOfThoughtStep icon={SearchIcon} label="Searching the knowledge graph for vaul">
          <ChainOfThoughtSearchResults>
            <ChainOfThoughtSearchResult>odyssey</ChainOfThoughtSearchResult>
            <ChainOfThoughtSearchResult>depot</ChainOfThoughtSearchResult>
          </ChainOfThoughtSearchResults>
        </ChainOfThoughtStep>
        <ChainOfThoughtStep icon={FileTextIcon} label="Reading drawer.tsx" description="Vaul Drawer.Root with snap points" />
        <ChainOfThoughtStep icon={GitBranchIcon} label="Planning the migration" status="active" />
        <ChainOfThoughtStep label="Open draft PRs" status="pending" />
      </ChainOfThoughtContent>
    </ChainOfThought>
  )
}

export function AIElementsSources() {
  return (
    <Sources className="w-full">
      <SourcesTrigger count={3} />
      <SourcesContent>
        <Source href="#" title="Knowledge graph (graph.json)" />
        <Source href="https://base-ui.com/react/components/drawer" title="Base UI Drawer docs" />
        <Source href="#" title="Playbook: Drawers" />
      </SourcesContent>
    </Sources>
  )
}

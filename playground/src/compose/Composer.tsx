// The composer: an empty canvas you add components to, a library for each, and extras on top.
// Left: what to add and how the canvas is set up. Middle: the live canvas. Right: the selected
// block's library choices, options, Playbook verdict and code, or a summary of the canvas.
import { Component, useEffect, useRef, type ErrorInfo, type ReactNode } from "react"
import { MotionConfig, motion, type TargetAndTransition, type Transition } from "motion/react"
import { useTheme } from "next-themes"
import { toast } from "sonner"
import {
  ArrowDownIcon,
  ArrowUpIcon,
  BanIcon,
  BookOpenIcon,
  BotIcon,
  CopyIcon,
  CopyPlusIcon,
  ExternalLinkIcon,
  InfoIcon,
  LayersIcon,
  LayoutDashboardIcon,
  MegaphoneIcon,
  Trash2Icon,
  TriangleAlertIcon,
  XIcon,
} from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Switch } from "@/components/ui/switch"
import { cn } from "@/lib/utils"
import { StatusBadge } from "@/playground/kit"
import { Rich, verdictClass, verdictLabel } from "@/playground/verdicts"
import { adapterById, adaptersFor } from "./adapters"
import { canvasCode, copyText, installsFor } from "./code"
import { libraries } from "./libraries"
import { bestAdapter, blockFor, issuesFor, newKey, traitsOf, tryCanvas, type RuleContext } from "./rules"
import { slotById, slots, type SlotGroup } from "./slots"
import { useComposer, type Action, type ComposerState } from "./state"
import type { Adapter, Block, Issue, LibraryId, Option, Settings, SlotId } from "./types"

type Dispatch = (action: Action) => void

/* ------------------------------------------------------------------------------------------------
 * Small pieces
 * ---------------------------------------------------------------------------------------------- */

function Heading({ children, className }: { children: ReactNode; className?: string }) {
  return <h3 className={cn("mb-2 text-xs font-medium tracking-wide text-muted-foreground uppercase", className)}>{children}</h3>
}

function Seg<T extends string>({
  value,
  choices,
  onChange,
  label,
}: {
  value: T
  choices: readonly { value: T; label: string }[]
  onChange: (value: T) => void
  label: string
}) {
  return (
    <div
      role="group"
      aria-label={label}
      style={{ gridTemplateColumns: `repeat(${choices.length}, minmax(0, 1fr))` }}
      className="grid gap-0.5 rounded-lg border bg-background p-0.5 dark:bg-input/30"
    >
      {choices.map((c) => (
        <button
          key={c.value}
          type="button"
          aria-pressed={value === c.value}
          onClick={() => onChange(c.value)}
          className={cn(
            "truncate rounded-md px-1 py-1 text-xs font-medium transition-colors outline-none focus-visible:ring-3 focus-visible:ring-ring/50",
            value === c.value ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-muted hover:text-foreground",
          )}
        >
          {c.label}
        </button>
      ))}
    </div>
  )
}

function SwitchRow({ label, hint, checked, onChange }: { label: string; hint?: ReactNode; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="flex cursor-pointer items-start justify-between gap-3 select-none">
      <span className="text-sm">
        {label}
        {hint && <span className="block text-xs text-muted-foreground">{hint}</span>}
      </span>
      <Switch checked={checked} onCheckedChange={(v) => onChange(v)} className="mt-0.5" aria-label={label} />
    </label>
  )
}

const issueIcon = { blocked: BanIcon, warn: TriangleAlertIcon, info: InfoIcon } as const
const issueClass = {
  blocked: "text-rose-600 dark:text-rose-400",
  warn: "text-amber-700 dark:text-amber-300",
  info: "text-muted-foreground",
} as const

function IssueList({ issues, className }: { issues: Issue[]; className?: string }) {
  if (!issues.length) return null
  return (
    <ul className={cn("flex flex-col gap-1", className)}>
      {issues.map((issue, i) => {
        const Icon = issueIcon[issue.severity]
        return (
          <li key={i} className={cn("flex gap-1.5 text-xs leading-snug", issueClass[issue.severity])}>
            <Icon className="mt-px size-3.5 shrink-0" aria-hidden />
            <span>{issue.text}</span>
          </li>
        )
      })}
    </ul>
  )
}

function CodeBox({ text, label }: { text: string; label: string }) {
  const copy = async () => {
    if (await copyText(text)) toast.success(`Copied ${label}`)
    else toast.error("Couldn't copy. Select the text instead.")
  }
  return (
    <div className="group/code relative">
      <pre className="max-h-72 overflow-auto rounded-lg border bg-muted/50 p-3 pr-9 font-mono text-[11px] leading-relaxed whitespace-pre">{text}</pre>
      <Button variant="ghost" size="icon-xs" onClick={copy} aria-label={`Copy ${label}`} className="absolute top-1.5 right-1.5">
        <CopyIcon />
      </Button>
    </div>
  )
}

/** Keeps one broken adapter from taking the whole canvas down. */
class BlockBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null as Error | null }
  static getDerivedStateFromError(error: Error) {
    return { error }
  }
  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error("Composer block crashed", error, info.componentStack)
  }
  render() {
    if (this.state.error)
      return <p className="text-sm text-rose-600 dark:text-rose-400">This block crashed: {this.state.error.message}</p>
    return this.props.children
  }
}

/* ------------------------------------------------------------------------------------------------
 * Left rail: add components, set up the canvas
 * ---------------------------------------------------------------------------------------------- */

const groups: SlotGroup[] = ["App", "Data", "Motion", "Marketing", "AI"]

function Rail({ settings, onAdd, dispatch }: { settings: Settings; onAdd: (slot: SlotId) => void; dispatch: Dispatch }) {
  const set = (s: Partial<Settings>) => dispatch({ type: "settings", settings: s })
  return (
    <aside className="flex min-h-0 flex-col overflow-y-auto border-r bg-sidebar px-3 py-4">
      <Heading className="px-1">Add a component</Heading>
      <div className="flex flex-col gap-3">
        {groups.map((group) => {
          const inGroup = slots.filter((s) => s.group === group && adaptersFor(s.id).length)
          if (!inGroup.length) return null
          return (
            <div key={group}>
              <div className="px-1 pb-1 text-[11px] text-muted-foreground">{group}</div>
              {inGroup.map((slot) => (
                <button
                  key={slot.id}
                  type="button"
                  onClick={() => onAdd(slot.id)}
                  className="flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm outline-none hover:bg-sidebar-accent focus-visible:ring-3 focus-visible:ring-ring/50"
                >
                  <slot.icon className="size-4 text-muted-foreground" aria-hidden />
                  <span className="flex-1">{slot.name}</span>
                  <span className="text-xs text-muted-foreground tabular-nums" title={`${adaptersFor(slot.id).length} libraries`}>
                    {adaptersFor(slot.id).length}
                  </span>
                </button>
              ))}
            </div>
          )
        })}
      </div>

      <Heading className="mt-6 px-1">This canvas is</Heading>
      <div className="flex flex-col gap-3 px-1">
        <Seg
          label="Page kind"
          value={settings.pageKind}
          choices={[
            { value: "app", label: "App screen" },
            { value: "marketing", label: "Marketing" },
          ]}
          onChange={(pageKind) => set({ pageKind })}
        />
        <div>
          <div className="mb-1 text-xs text-muted-foreground">Your app's primitives</div>
          <Seg
            label="Primitives"
            value={settings.primitives}
            choices={[
              { value: "base-ui", label: "Base UI" },
              { value: "radix", label: "Radix" },
            ]}
            onChange={(primitives) => set({ primitives })}
          />
        </div>
      </div>

      <Heading className="mt-6 px-1">Extras</Heading>
      <div className="flex flex-col gap-3 px-1">
        <SwitchRow label="Motion" hint="Magic UI, Aceternity, Animate UI and RareUI need it" checked={settings.motion} onChange={(motion) => set({ motion })} />
        <div>
          <div className="mb-1 text-xs text-muted-foreground">Entrance{settings.motion ? "" : " (needs Motion)"}</div>
          <div className={cn(!settings.motion && "pointer-events-none opacity-50")} aria-disabled={!settings.motion}>
            <Seg
              label="Entrance animation"
              value={settings.entrance}
              choices={[
                { value: "none", label: "None" },
                { value: "fade", label: "Fade" },
                { value: "rise", label: "Rise" },
                { value: "spring", label: "Spring" },
              ]}
              onChange={(entrance) => set({ entrance })}
            />
          </div>
        </div>
        <SwitchRow
          label="Reduce motion"
          hint="Acts like the macOS setting for Motion-based parts"
          checked={settings.reduceMotion}
          onChange={(reduceMotion) => set({ reduceMotion })}
        />
      </div>
    </aside>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Canvas
 * ---------------------------------------------------------------------------------------------- */

const entrances: Record<Exclude<Settings["entrance"], "none">, { initial: TargetAndTransition; transition: Transition }> = {
  fade: { initial: { opacity: 0 }, transition: { duration: 0.35 } },
  rise: { initial: { opacity: 0, y: 18 }, transition: { duration: 0.4, ease: [0.22, 1, 0.36, 1] } },
  spring: { initial: { opacity: 0, scale: 0.92 }, transition: { type: "spring", stiffness: 320, damping: 22 } },
}

function BlockFrame({
  block,
  adapter,
  issues,
  selected,
  first,
  last,
  settings,
  dispatch,
}: {
  block: Block
  adapter: Adapter
  issues: Issue[]
  selected: boolean
  first: boolean
  last: boolean
  settings: Settings
  dispatch: Dispatch
}) {
  const slot = slotById[block.slot]
  const library = libraries[adapter.library].row.name
  const blocked = issues.filter((i) => i.severity === "blocked")
  const warnings = issues.filter((i) => i.severity === "warn").length
  const traits = traitsOf(adapter)
  const showLibrary = !adapter.label.toLowerCase().includes(library.toLowerCase())

  const frame = (
    <div
      data-block={block.key}
      onPointerDownCapture={() => !selected && dispatch({ type: "select", key: block.key })}
      onFocusCapture={() => !selected && dispatch({ type: "select", key: block.key })}
      className={cn(
        "group/block relative rounded-xl border bg-background transition-shadow",
        selected ? "border-primary ring-2 ring-primary/40" : "hover:border-foreground/25",
      )}
    >
      <div className="flex h-9 items-center gap-2 border-b px-3 text-xs">
        <slot.icon className="size-3.5 text-muted-foreground" aria-hidden />
        <span className="font-medium">{slot.name}</span>
        <span className="truncate text-muted-foreground">
          {adapter.label}
          {showLibrary && <span className="opacity-70"> · {library}</span>}
        </span>
        {warnings > 0 && (
          <span className="flex items-center gap-1 text-amber-700 dark:text-amber-300" title={`${warnings} Playbook warnings`}>
            <TriangleAlertIcon className="size-3.5" aria-hidden />
            {warnings}
          </span>
        )}
        <div
          className={cn(
            "ml-auto flex items-center gap-0.5 transition-opacity",
            selected ? "opacity-100" : "opacity-0 group-hover/block:opacity-100 focus-within:opacity-100",
          )}
        >
          <Button variant="ghost" size="icon-xs" disabled={first} onClick={() => dispatch({ type: "move", key: block.key, by: -1 })} aria-label="Move up">
            <ArrowUpIcon />
          </Button>
          <Button variant="ghost" size="icon-xs" disabled={last} onClick={() => dispatch({ type: "move", key: block.key, by: 1 })} aria-label="Move down">
            <ArrowDownIcon />
          </Button>
          <Button variant="ghost" size="icon-xs" onClick={() => dispatch({ type: "duplicate", key: block.key, newKey: newKey() })} aria-label="Duplicate">
            <CopyPlusIcon />
          </Button>
          <Button variant="ghost" size="icon-xs" onClick={() => dispatch({ type: "remove", key: block.key })} aria-label="Remove">
            <Trash2Icon />
          </Button>
        </div>
      </div>
      <div className="p-4">
        {blocked.length ? (
          <div className="flex flex-col items-start gap-3 rounded-lg border border-dashed p-4">
            <p className="text-sm font-medium">{adapter.label} can't run on this canvas</p>
            <IssueList issues={blocked} />
            {traits.needsMotion && !settings.motion && (
              <Button size="sm" variant="outline" onClick={() => dispatch({ type: "settings", settings: { motion: true } })}>
                Turn on Motion
              </Button>
            )}
          </div>
        ) : (
          <BlockBoundary key={adapter.id}>
            <adapter.render options={block.options} />
          </BlockBoundary>
        )}
      </div>
    </div>
  )

  if (!settings.motion || settings.entrance === "none") return frame
  const entrance = entrances[settings.entrance]
  return (
    <motion.div key={adapter.id} initial={entrance.initial} animate={{ opacity: 1, y: 0, scale: 1 }} transition={entrance.transition}>
      {frame}
    </motion.div>
  )
}

type Starter = { name: string; icon: typeof LayersIcon; pageKind: Settings["pageKind"]; slots: SlotId[] }

const starters: Starter[] = [
  { name: "Dashboard", icon: LayoutDashboardIcon, pageKind: "app", slots: ["number", "chart", "feed", "toast"] },
  { name: "Landing page", icon: MegaphoneIcon, pageKind: "marketing", slots: ["nav", "hero", "text", "card", "button"] },
  { name: "Agent screen", icon: BotIcon, pageKind: "app", slots: ["chat", "agent", "picker", "toast"] },
]

function EmptyCanvas({ onStarter }: { onStarter: (starter: Starter) => void }) {
  return (
    <div data-canvas-bg className="flex flex-col items-center gap-4 rounded-xl border border-dashed bg-background/60 px-6 py-16 text-center">
      <LayersIcon className="size-7 text-muted-foreground" aria-hidden />
      <div>
        <p className="font-medium">Start with an empty canvas</p>
        <p className="mt-1 max-w-sm text-sm text-muted-foreground">
          Add a component from the left, then pick which library draws it. Choices that don't fit the canvas say why.
        </p>
      </div>
      <div className="flex flex-wrap items-center justify-center gap-2">
        <span className="text-xs text-muted-foreground">Or start from</span>
        {starters.map((s) => (
          <Button key={s.name} size="sm" variant="outline" onClick={() => onStarter(s)}>
            <s.icon />
            {s.name}
          </Button>
        ))}
      </div>
    </div>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Right: inspector
 * ---------------------------------------------------------------------------------------------- */

function OptionControl({ option, value, onChange }: { option: Option; value: string | boolean | undefined; onChange: (v: string | boolean) => void }) {
  if (option.type === "switch") return <SwitchRow label={option.label} checked={Boolean(value ?? option.default)} onChange={onChange} />
  if (option.type === "text")
    return (
      <label className="flex flex-col gap-1">
        <span className="text-xs text-muted-foreground">{option.label}</span>
        <Input value={String(value ?? option.default)} onChange={(e) => onChange(e.target.value)} />
      </label>
    )
  const current = String(value ?? option.default)
  // Buttons when they fit the 288px column, a dropdown otherwise.
  const short = option.choices.length <= 4 && option.choices.reduce((n, c) => n + c.label.length, 0) <= 26
  return (
    <div className="flex flex-col gap-1">
      <span className="text-xs text-muted-foreground">{option.label}</span>
      {short ? (
        <Seg label={option.label} value={current} choices={option.choices} onChange={onChange} />
      ) : (
        <select
          aria-label={option.label}
          value={current}
          onChange={(e) => onChange(e.target.value)}
          className="h-8 w-full rounded-lg border bg-background px-2 text-sm outline-none focus-visible:ring-3 focus-visible:ring-ring/50 dark:bg-input/30"
        >
          {option.choices.map((c) => (
            <option key={c.value} value={c.value}>
              {c.label}
            </option>
          ))}
        </select>
      )}
    </div>
  )
}

function LibraryAbout({ id }: { id: LibraryId }) {
  const { row, url } = libraries[id]
  return (
    <div className="flex flex-col gap-2 rounded-lg border p-3">
      <div className="flex items-center justify-between gap-2">
        <span className="text-sm font-medium">{row.name}</span>
        <StatusBadge status={row.status} />
      </div>
      <div className={cn("text-xs font-medium", verdictClass[row.verdict])}>{verdictLabel[row.verdict]}</div>
      <p className="text-xs leading-relaxed text-muted-foreground">
        <Rich text={row.why} />
      </p>
      <div className="flex gap-3 text-xs">
        {row.page && (
          <a href={`#/${row.page}`} className="flex items-center gap-1 text-primary hover:underline">
            <BookOpenIcon className="size-3.5" aria-hidden />
            Notes
          </a>
        )}
        <a href={url} target="_blank" rel="noreferrer" className="flex items-center gap-1 text-muted-foreground hover:underline">
          <ExternalLinkIcon className="size-3.5" aria-hidden />
          Website
        </a>
      </div>
    </div>
  )
}

function BlockInspector({ block, ctx, dispatch }: { block: Block; ctx: RuleContext; dispatch: Dispatch }) {
  const slot = slotById[block.slot]
  const adapter = adapterById[block.adapter]
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-start gap-2">
        <slot.icon className="mt-0.5 size-4 text-muted-foreground" aria-hidden />
        <div className="flex-1">
          <h2 className="font-medium">{slot.name}</h2>
          <p className="text-xs text-muted-foreground">{slot.hint}</p>
        </div>
        <Button variant="ghost" size="icon-xs" onClick={() => dispatch({ type: "select", key: null })} aria-label="Close inspector">
          <XIcon />
        </Button>
      </div>

      <section>
        <Heading>Library</Heading>
        <div role="radiogroup" aria-label="Library" className="flex flex-col gap-1.5">
          {adaptersFor(block.slot).map((option) => {
            const issues = issuesFor(option, ctx)
            const blocked = issues.some((i) => i.severity === "blocked")
            const chosen = option.id === block.adapter
            const lib = libraries[option.library].row
            return (
              <button
                key={option.id}
                type="button"
                role="radio"
                aria-checked={chosen}
                onClick={() => dispatch({ type: "adapter", key: block.key, adapter: option.id })}
                className={cn(
                  "flex flex-col gap-1 rounded-lg border p-2.5 text-left outline-none transition-colors focus-visible:ring-3 focus-visible:ring-ring/50",
                  chosen ? "border-primary bg-primary/5" : "hover:bg-muted/60",
                  blocked && !chosen && "opacity-60",
                )}
              >
                <span className="flex items-center gap-2">
                  <span className="text-sm font-medium">{option.label}</span>
                  <span className="truncate text-xs text-muted-foreground">{lib.name}</span>
                  <span className="ml-auto">
                    <StatusBadge status={lib.status} />
                  </span>
                </span>
                {option.note && <span className="text-xs text-muted-foreground">{option.note}</span>}
                <IssueList issues={issues} className="mt-0.5" />
              </button>
            )
          })}
        </div>
      </section>

      {adapter?.options?.length ? (
        <section>
          <Heading>Options</Heading>
          <div className="flex flex-col gap-3">
            {adapter.options.map((option) => (
              <OptionControl
                key={option.id}
                option={option}
                value={block.options[option.id]}
                onChange={(value) => dispatch({ type: "option", key: block.key, id: option.id, value })}
              />
            ))}
          </div>
        </section>
      ) : null}

      {adapter && (
        <section>
          <Heading>In your Playbook</Heading>
          <LibraryAbout id={adapter.library} />
        </section>
      )}

      {adapter && (
        <section className="flex flex-col gap-2">
          <Heading className="mb-0">Code</Heading>
          {adapter.install.length > 0 && <CodeBox label="install commands" text={adapter.install.join("\n")} />}
          <CodeBox label="code" text={adapter.code(block.options)} />
        </section>
      )}
    </div>
  )
}

function CanvasSummary({ state, ctxFor, dispatch }: { state: ComposerState; ctxFor: (self?: string) => RuleContext; dispatch: Dispatch }) {
  const { blocks } = state
  if (!blocks.length)
    return (
      <div className="flex flex-col gap-2 text-sm text-muted-foreground">
        <h2 className="font-medium text-foreground">Nothing on the canvas yet</h2>
        <p>Add a component from the left. Select a block to choose its library, change its options and see its code.</p>
      </div>
    )
  const used = [...new Set(blocks.map((b) => adapterById[b.adapter]?.library).filter(Boolean))] as LibraryId[]
  const flagged = blocks
    .map((b) => ({ block: b, issues: issuesFor(adapterById[b.adapter], ctxFor(b.key)).filter((i) => i.severity !== "info") }))
    .filter((x) => x.issues.length)
  const installs = installsFor(blocks)
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h2 className="font-medium">Canvas</h2>
        <p className="text-xs text-muted-foreground">Select a block to change its library or options.</p>
      </div>
      <section>
        <Heading>Libraries used</Heading>
        <ul className="flex flex-col gap-1.5">
          {used.map((id) => {
            const row = libraries[id].row
            return (
              <li key={id} className="flex items-center gap-2 text-sm">
                <span className="flex-1">{row.name}</span>
                <span className={cn("text-xs", verdictClass[row.verdict])}>{verdictLabel[row.verdict]}</span>
              </li>
            )
          })}
        </ul>
      </section>
      <section>
        <Heading>Against the Playbook</Heading>
        {flagged.length ? (
          <ul className="flex flex-col gap-2">
            {flagged.map(({ block, issues }) => (
              <li key={block.key}>
                <button
                  type="button"
                  onClick={() => dispatch({ type: "select", key: block.key })}
                  className="mb-1 text-left text-xs font-medium hover:underline"
                >
                  {slotById[block.slot].name} · {adapterById[block.adapter].label}
                </button>
                <IssueList issues={issues} />
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-xs text-emerald-700 dark:text-emerald-300">Everything here fits the canvas and the Playbook.</p>
        )}
      </section>
      {installs.length > 0 && (
        <section className="flex flex-col gap-2">
          <Heading className="mb-0">Install</Heading>
          <CodeBox label="install commands" text={installs.join("\n")} />
        </section>
      )}
    </div>
  )
}

/* ------------------------------------------------------------------------------------------------
 * The page
 * ---------------------------------------------------------------------------------------------- */

export default function Composer({ tryLibrary, tryRequest }: { tryLibrary?: string; tryRequest?: number }) {
  const [state, dispatch] = useComposer()
  const { resolvedTheme } = useTheme()
  const dark = resolvedTheme === "dark"
  const { blocks, settings, selected } = state
  const ctxFor = (self?: string, list: Block[] = blocks, s: Settings = settings): RuleContext => ({ settings: s, dark, blocks: list, self })
  const canvasRef = useRef<HTMLDivElement>(null)

  /** Replaces the canvas, with an Undo in the toast when something was there. */
  const replace = (next: ComposerState, message: string) => {
    const previous = state
    dispatch({ type: "load", state: next })
    if (previous.blocks.length) toast(message, { action: { label: "Undo", onClick: () => dispatch({ type: "load", state: previous }) } })
  }

  // A Playbook card's Try button arrives as #/try/<library>. Handle it once, then step back to
  // #/compose so the same button works again.
  const handled = useRef<number | undefined>(undefined)
  useEffect(() => {
    if (!tryLibrary || tryRequest === undefined || handled.current === tryRequest) return
    handled.current = tryRequest
    history.replaceState(null, "", "#/compose")
    const library = libraries[tryLibrary as LibraryId]
    const seeded = library && tryCanvas(library.id, state.settings)
    if (!library || !seeded) {
      toast(`${library?.row.name ?? tryLibrary} has nothing to place on the canvas yet`)
      return
    }
    replace({ ...seeded, selected: seeded.blocks[0]?.key ?? null }, `Opened ${library.row.name} on a fresh canvas`)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tryLibrary, tryRequest])

  const add = (slot: SlotId) => {
    const adapter = bestAdapter(slot, ctxFor())
    if (!adapter) return
    const block = blockFor(adapter)
    dispatch({ type: "add", block })
    requestAnimationFrame(() => canvasRef.current?.querySelector(`[data-block="${block.key}"]`)?.scrollIntoView({ behavior: "smooth", block: "nearest" }))
  }

  const startFrom = (starter: Starter) => {
    const s: Settings = { ...settings, pageKind: starter.pageKind }
    const list: Block[] = []
    for (const slot of starter.slots) {
      const adapter = bestAdapter(slot, ctxFor(undefined, list, s))
      if (adapter) list.push(blockFor(adapter))
    }
    dispatch({ type: "load", state: { blocks: list, settings: s, selected: null } })
  }

  const clear = () => replace({ blocks: [], settings, selected: null }, "Canvas cleared")

  const copyAll = async () => {
    if (await copyText(canvasCode(blocks))) toast.success("Copied install commands and code for the canvas")
    else toast.error("Couldn't copy")
  }

  const warnings = blocks.reduce(
    (n, b) => n + issuesFor(adapterById[b.adapter], ctxFor(b.key)).filter((i) => i.severity !== "info").length,
    0,
  )
  const selectedBlock = blocks.find((b) => b.key === selected)

  return (
    <div className="grid h-full min-h-0 grid-cols-[232px_minmax(0,1fr)_320px]">
      <Rail settings={settings} onAdd={add} dispatch={dispatch} />

      <section className="flex min-h-0 flex-col bg-muted/40">
        <div className="flex h-11 shrink-0 items-center gap-3 border-b bg-background px-4">
          <span className="text-sm font-medium">Canvas</span>
          <span className="text-xs text-muted-foreground">
            {blocks.length} {blocks.length === 1 ? "block" : "blocks"}
            {warnings > 0 && ` · ${warnings} against the Playbook`}
          </span>
          <div className="ml-auto flex items-center gap-1.5">
            <Button size="sm" variant="outline" disabled={!blocks.length} onClick={copyAll}>
              <CopyIcon />
              Copy install and code
            </Button>
            <Button size="sm" variant="ghost" disabled={!blocks.length} onClick={clear}>
              Clear
            </Button>
          </div>
        </div>
        <div
          ref={canvasRef}
          data-canvas-bg
          className="min-h-0 flex-1 overflow-y-auto p-6"
          onClick={(e) => {
            if ((e.target as HTMLElement).dataset?.canvasBg !== undefined) dispatch({ type: "select", key: null })
          }}
        >
          <MotionConfig reducedMotion={settings.reduceMotion ? "always" : "user"}>
            <div data-canvas-bg className="mx-auto flex min-h-full max-w-3xl flex-col gap-4">
              {blocks.length ? (
                blocks.map((block, i) => {
                  const adapter = adapterById[block.adapter]
                  return (
                    <BlockFrame
                      key={block.key}
                      block={block}
                      adapter={adapter}
                      issues={issuesFor(adapter, ctxFor(block.key))}
                      selected={block.key === selected}
                      first={i === 0}
                      last={i === blocks.length - 1}
                      settings={settings}
                      dispatch={dispatch}
                    />
                  )
                })
              ) : (
                <EmptyCanvas onStarter={startFrom} />
              )}
            </div>
          </MotionConfig>
        </div>
      </section>

      <aside className="flex min-h-0 flex-col overflow-y-auto border-l bg-background p-4">
        {selectedBlock && adapterById[selectedBlock.adapter] ? (
          <BlockInspector block={selectedBlock} ctx={ctxFor(selectedBlock.key)} dispatch={dispatch} />
        ) : (
          <CanvasSummary state={state} ctxFor={ctxFor} dispatch={dispatch} />
        )}
      </aside>
    </div>
  )
}

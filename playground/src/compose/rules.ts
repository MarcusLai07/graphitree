// Compatibility rules. "blocked" means it can't run on this canvas; "warn" means it runs but
// goes against a Playbook rule; "info" is context. Every warning comes from a verdict or a
// finding recorded in the lab, so the composer is a way to test those rules, not invent them.
import { adapterById, adaptersFor, adaptersOf } from "./adapters"
import { libraries } from "./libraries"
import type { Adapter, Block, Framework, Issue, LibraryId, OptionValues, Primitives, Settings, SlotId, Traits } from "./types"

export type RuleContext = {
  settings: Settings
  dark: boolean
  blocks: Block[]
  /** The block being checked, so it isn't compared with itself. */
  self?: string
}

const frameworkName: Record<Framework, string> = { react: "React", swiftui: "SwiftUI" }
const primitivesName: Record<Primitives, string> = { "base-ui": "Base UI", radix: "Radix" }

export function traitsOf(adapter: Adapter): Traits {
  return { ...libraries[adapter.library].traits, ...adapter.traits }
}

export function issuesFor(adapter: Adapter, ctx: RuleContext): Issue[] {
  const traits = traitsOf(adapter)
  const row = libraries[adapter.library].row
  const { settings } = ctx
  const issues: Issue[] = []

  if (traits.framework !== settings.framework)
    issues.push({ severity: "blocked", text: `Runs on ${frameworkName[traits.framework]}; this canvas is ${frameworkName[settings.framework]}.` })
  if (traits.needsMotion && !settings.motion) issues.push({ severity: "blocked", text: "Needs Motion. Turn Motion on under Extras." })

  if (row.status === "avoid") issues.push({ severity: "warn", text: `Avoid for new work. ${row.why}` })

  const kind = traits.pageKind ?? "both"
  if (kind !== "both" && kind !== settings.pageKind)
    issues.push({ severity: "warn", text: kind === "marketing" ? "Your Playbook keeps this to marketing pages." : "Meant for app screens, not marketing pages." })

  if (traits.primitives && traits.primitives !== settings.primitives) {
    if (adapter.library === "shadcn")
      issues.push({ severity: "info", text: `This copy is shadcn's ${primitivesName[traits.primitives]} style. In a ${primitivesName[settings.primitives]} app, add it with shadcn's ${primitivesName[settings.primitives]} style instead.` })
    else
      issues.push({
        severity: "warn",
        text: `Built on ${primitivesName[traits.primitives]}; this app is on ${primitivesName[settings.primitives]}. Their styling hooks differ (data-state vs data-open), so don't mix them.`,
      })
  }

  if (settings.reduceMotion && traits.ignoresReducedMotion) issues.push({ severity: "warn", text: "Keeps animating when Reduce motion is on." })
  if (traits.a11y === "poor")
    issues.push({ severity: "warn", text: "Not accessible as installed: screen readers get no usable name. The lab adds labels by hand." })
  if (traits.darkMode === "partial") issues.push({ severity: "warn", text: "Hard-codes its colours for one theme; check it in light and dark." })

  const others = ctx.blocks
    .filter((b) => b.key !== ctx.self)
    .map((b) => adapterById[b.adapter])
    .filter(Boolean)
  if (adapter.slot === "toast") {
    const rivals = [...new Set(others.filter((a) => a.slot === "toast" && a.library !== adapter.library).map((a) => libraries[a.library].row.name))]
    if (rivals.length) issues.push({ severity: "warn", text: `${rivals.join(" and ")} also shows toasts on this canvas. Use one toast library per app.` })
  }
  if (traits.effect && others.some((a) => traitsOf(a).effect))
    issues.push({ severity: "warn", text: "Another full-page effect is on this canvas. The Playbook allows one per page." })

  if (row.status === "candidate") issues.push({ severity: "info", text: "A candidate: not in your Playbook yet." })
  return issues
}

const rank = (issues: Issue[]) =>
  issues.reduce((sum, i) => sum + (i.severity === "blocked" ? 100 : i.severity === "warn" ? 10 : 1), 0)

/** The adapter a new block of this slot starts with: the one with the fewest problems here. */
export function bestAdapter(slot: SlotId, ctx: RuleContext): Adapter | undefined {
  const scored = adaptersFor(slot).map((adapter, order) => ({ adapter, order, score: rank(issuesFor(adapter, ctx)) }))
  scored.sort((a, b) => a.score - b.score || a.order - b.order)
  return scored[0]?.adapter
}

export function defaultOptions(adapter: Adapter): OptionValues {
  return Object.fromEntries((adapter.options ?? []).map((o) => [o.id, o.default]))
}

let counter = 0
export const newKey = () => `b${Date.now().toString(36)}${(counter++).toString(36)}`

export function blockFor(adapter: Adapter): Block {
  return { key: newKey(), slot: adapter.slot, adapter: adapter.id, options: defaultOptions(adapter) }
}

/**
 * The canvas a Playbook card's Try button opens: one block per slot the library covers, with
 * settings that let it run, such as Motion on and a marketing page for marketing-only libraries.
 */
export function tryCanvas(library: LibraryId, current: Settings): { blocks: Block[]; settings: Settings } | undefined {
  const picks: Adapter[] = []
  for (const adapter of adaptersOf(library)) if (!picks.some((p) => p.slot === adapter.slot)) picks.push(adapter)
  if (!picks.length) return undefined
  const traits = picks.map(traitsOf)
  const settings: Settings = {
    ...current,
    motion: current.motion || traits.some((t) => t.needsMotion),
    pageKind: traits.every((t) => t.pageKind === "marketing") ? "marketing" : traits.some((t) => t.pageKind === "marketing") ? current.pageKind : "app",
    primitives: libraries[library].traits.primitives ?? current.primitives,
  }
  return { blocks: picks.slice(0, 6).map(blockFor), settings }
}

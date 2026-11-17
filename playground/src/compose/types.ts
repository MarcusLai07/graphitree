// The composer's data model. A canvas holds blocks; each block is one component slot (a toast,
// a drawer, a KPI number…) drawn by one adapter, which is one library's take on that slot.
// Compatibility rules read the traits of the adapter and its library against the canvas settings.
import type { ComponentType } from "react"

/** Phase 1 renders React only. SwiftUI is in the model so the rules already speak its name. */
export type Framework = "react" | "swiftui"

/** The headless base a component is built on. Mixing them is a Playbook "don't". */
export type Primitives = "base-ui" | "radix"

/** What the canvas is: an app screen or a marketing page. Some libraries are marketing-only. */
export type PageKind = "app" | "marketing"

export type SlotId =
  | "button"
  | "toast"
  | "drawer"
  | "picker"
  | "tabs"
  | "number"
  | "chart"
  | "feed"
  | "card"
  | "text"
  | "avatars"
  | "hero"
  | "nav"
  | "chat"
  | "agent"

export type LibraryId =
  | "shadcn"
  | "base-ui"
  | "radix"
  | "sonner"
  | "vaul"
  | "cmdk"
  | "numberflow"
  | "magicui"
  | "aceternity"
  | "beautiful-ui"
  | "21st"
  | "rareui"
  | "shadcn-charts"
  | "animate-ui"
  | "ai-elements"

export type Option =
  | { id: string; label: string; type: "select"; choices: { value: string; label: string }[]; default: string }
  | { id: string; label: string; type: "switch"; default: boolean }
  | { id: string; label: string; type: "text"; default: string }

export type OptionValues = Record<string, string | boolean>

export type BlockProps = {
  /** The adapter's options, filled with defaults for any the person hasn't changed. */
  options: OptionValues
}

/** Facts the compatibility rules read. An adapter's traits override its library's. */
export type Traits = {
  framework: Framework
  /** The headless base it's built on, when it has one. */
  primitives?: Primitives
  /** Uses the Motion library (motion/react). */
  needsMotion?: boolean
  /** Where the Playbook allows it. Defaults to both. */
  pageKind?: PageKind | "both"
  /** Keeps animating when the OS asks for reduced motion. */
  ignoresReducedMotion?: boolean
  /** "partial" when it hard-codes colours for one theme, so it clashes with the other. */
  darkMode?: "ok" | "partial"
  /** A full-page effect. Aceternity's rule is one per page. */
  effect?: boolean
  /** "poor" when screen readers get nothing useful from it as installed. */
  a11y?: "ok" | "poor"
}

export type Adapter = {
  /** Unique across all adapters, kebab-case: "toast-sonner". */
  id: string
  slot: SlotId
  library: LibraryId
  /** Short name shown in the picker: "Sonner", "Shimmer button". */
  label: string
  /** One line under the label: what makes this one different. */
  note?: string
  options?: Option[]
  traits?: Partial<Traits>
  /** Commands that add it to a project, in order. */
  install: string[]
  /** Usage code for the current options, including imports. */
  code: (options: OptionValues) => string
  render: ComponentType<BlockProps>
}

export type Block = {
  key: string
  slot: SlotId
  adapter: string
  options: OptionValues
}

export type Settings = {
  framework: Framework
  pageKind: PageKind
  primitives: Primitives
  /** Motion is installed. Off blocks every library that needs it. */
  motion: boolean
  /** How blocks enter the canvas. Needs Motion. */
  entrance: "none" | "fade" | "rise" | "spring"
  /** Simulates the OS "Reduce motion" setting for Motion-based components. */
  reduceMotion: boolean
}

export type Severity = "blocked" | "warn" | "info"

export type Issue = { severity: Severity; text: string }

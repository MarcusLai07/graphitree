// The libraries the lab covers, and what trying them suggested. The Verdicts page shows this
// table, the composer reads it for each library's status and rule, and the app build turns it
// into lab-manifest.json so Graphitree's Playbook cards can open a library in the composer.
// Plain data only: vite.app.config.ts imports it.

/** Where a library stands in Graphitree's Playbook. */
export type LibStatus = "playbook" | "avoid" | "candidate" | "built-in"

export type Verdict = "keep" | "narrow" | "drop" | "promote" | "wait"

export type CatalogRow = {
  /** The library's id in the composer, or "" when it has nothing to render. */
  id: string
  name: string
  job: string
  status: LibStatus
  /** The notes page with its side-by-side variants and findings, or "" when there's none. */
  page: string
  /** Which of the owner's repos use it today. */
  usedIn: string
  verdict: Verdict
  /** The suggested Playbook rule, from trying it here. */
  why: string
}

export const catalog: CatalogRow[] = [
  { id: "shadcn", name: "shadcn/ui", job: "UI components", status: "playbook", page: "primitives", usedIn: "storefront (Base UI), studio (Radix)", verdict: "keep", why: "Default component set. Start new apps with `init -b base` (the base-nova style)." },
  { id: "base-ui", name: "Base UI", job: "Headless primitives", status: "playbook", page: "primitives", usedIn: "storefront", verdict: "keep", why: "Default for new work. Behaves like Radix on the shared parts, and adds NumberField, Meter, OTP, Combobox, Drawer and Toast." },
  { id: "radix", name: "Radix", job: "Headless primitives", status: "playbook", page: "primitives", usedIn: "studio", verdict: "narrow", why: "Only in apps already on it. Its styling hooks (data-state) differ from Base UI's, so don't mix the two." },
  { id: "cmdk", name: "cmdk", job: "Command menu", status: "playbook", page: "command", usedIn: "studio", verdict: "keep", why: "⌘K palettes that run an action. Not form pickers (use Base UI Combobox). Nested pages and async are DIY." },
  { id: "sonner", name: "Sonner", job: "Toasts", status: "playbook", page: "toasts", usedIn: "storefront, studio", verdict: "keep", why: "The only toast library. Base UI Toast is just behaviour; you'd write the card and stacking CSS yourself." },
  { id: "vaul", name: "Vaul", job: "Drawers", status: "avoid", page: "drawers", usedIn: "—", verdict: "drop", why: "shadcn Drawer (Base UI) matched every Vaul case tried: swipe, snap points, nesting, all four edges." },
  { id: "numberflow", name: "NumberFlow", job: "Animated numbers", status: "playbook", page: "numbers", usedIn: "—", verdict: "keep", why: "KPI tiles and changing totals. Pin `locales=\"en-MY\"`. NumberFlowGroup animates related numbers together." },
  { id: "magicui", name: "Magic UI", job: "Animated UI components", status: "playbook", page: "motion", usedIn: "studio (registry set up)", verdict: "narrow", why: "In apps: AnimatedList, BlurFade, BorderBeam only. Looping effects on marketing pages; most ignore reduced motion. Skip NumberTicker." },
  { id: "aceternity", name: "Aceternity UI", job: "Landing page components", status: "playbook", page: "landing", usedIn: "—", verdict: "narrow", why: "Marketing pages only, one effect per page. Effects keep using CPU when idle or off-screen, ignore reduced motion, and mostly ignore dark mode." },
  { id: "beautiful-ui", name: "Beautiful UI", job: "AI interface components", status: "playbook", page: "ai", usedIn: "—", verdict: "keep", why: "Agent and chat screens. Copy single blocks and map tokens; don't paste its foundation.css. Expect to add props and a11y fixes." },
  { id: "21st", name: "21st.dev", job: "UI components registry", status: "playbook", page: "community", usedIn: "—", verdict: "narrow", why: "For browsing only: installs now need an account, and a listed licence was wrong (MIT shown, AGPL upstream). Install from the author's own source." },
  { id: "rareui", name: "RareUI", job: "Animated UI components", status: "playbook", page: "community", usedIn: "—", verdict: "narrow", why: "Now called ShitUI (rareui.in redirects to shitui.in). One maintainer. Marketing flourishes only, copied by hand and patched for a11y." },
  { id: "", name: "pick-ui-library skill", job: "UI library selection", status: "playbook", page: "", usedIn: "—", verdict: "keep", why: "An agent skill; nothing to render. The playbook wins when they disagree." },
  { id: "shadcn-charts", name: "shadcn charts (Recharts)", job: "Charts", status: "candidate", page: "charts", usedIn: "— (dashboards use chart.js)", verdict: "promote", why: "A missing job. Composable, keyboard-accessible, dark-mode colours per chart. Recolour the grey --chart vars." },
  { id: "animate-ui", name: "Animate UI", job: "Animated UI components", status: "candidate", page: "motion", usedIn: "studio", verdict: "wait", why: "Copy single pieces (AvatarGroup, HighlightText). SlidingNumber isn't accessible; its Base UI parts don't install." },
  { id: "ai-elements", name: "Vercel AI Elements", job: "AI interface components", status: "candidate", page: "ai", usedIn: "—", verdict: "wait", why: "Only if an app adopts the AI SDK. Written for Radix: its animations don't fire on Base UI." },
]

/** Other names a Playbook card might use for the same library. */
export const aliases: Record<string, string[]> = {
  "shadcn charts (Recharts)": ["Recharts", "shadcn charts"],
  "Vercel AI Elements": ["AI Elements"],
  RareUI: ["ShitUI"],
  Radix: ["Radix UI"],
  "Aceternity UI": ["Aceternity"],
  "Magic UI": ["MagicUI"],
}

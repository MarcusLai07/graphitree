/** Realistic places to put the community components. */
import { useId, useState, type ReactNode } from "react"
import { LayoutGroup } from "motion/react"
import { BoldIcon, ItalicIcon, LinkIcon, Share2Icon, Trash2Icon } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"
import Stats05 from "@/components/stats-05"
import { AnimatedTabs, type Tab } from "./animated-tabs"
import { AnimatedTabsPatched } from "./animated-tabs-patched"
import FloatingNavigation from "./floating-navigation"
import { LiquidTooltip } from "./liquid-tooltip"

/* ── blocks.so stats cards, from 21st.dev's listing ── */

export function AdminDashboard({ narrow = false }: { narrow?: boolean }) {
  return (
    <div className="w-full overflow-hidden rounded-lg bg-background ring-1 ring-border">
      <div className="flex items-center justify-between border-b px-4 py-2.5">
        <div>
          <div className="text-sm font-medium">depot admin</div>
          <div className="text-xs text-muted-foreground">Last 30 days</div>
        </div>
        <Button variant="outline" size="sm">
          Export
        </Button>
      </div>
      <div className={narrow ? "mx-auto max-w-sm" : undefined}>
        {/* Stats05 is the file the shadcn CLI wrote, untouched: fixed data and p-10 baked in */}
        <Stats05 />
      </div>
    </div>
  )
}

/* ── RareUI AnimatedTabs ── */

const SETTINGS_TABS: Tab[] = [
  { id: "general", label: "General" },
  { id: "members", label: "Members" },
  { id: "billing", label: "Billing" },
  { id: "api", label: "API keys" },
]

const SETTINGS_BODY: Record<string, string> = {
  general: "Project name, default branch and where the knowledge graph is stored.",
  members: "3 people can rebuild the graph. Invite someone by email.",
  billing: "Free plan. Backups are kept for 30 days.",
  api: "No keys yet. Keys let CI rebuild the graph after each merge.",
}

export function SettingsHeader({ patched = false }: { patched?: boolean }) {
  const [tab, setTab] = useState("general")
  const group = useId()
  return (
    <div className="flex w-full flex-col items-center gap-5">
      {patched ? (
        <AnimatedTabsPatched label="Project settings" tabs={SETTINGS_TABS} activeTab={tab} onChange={setTab} />
      ) : (
        // Without this LayoutGroup the upstream copy would fight the other copies on this page for layoutId="active-pill".
        <LayoutGroup id={group}>
          <AnimatedTabs tabs={SETTINGS_TABS} activeTab={tab} onChange={setTab} />
        </LayoutGroup>
      )}
      <p className="max-w-sm text-center text-sm text-muted-foreground" role={patched ? "tabpanel" : undefined}>
        {SETTINGS_BODY[tab]}
      </p>
    </div>
  )
}

const RANGE: Tab[] = [
  { id: "7d", label: "7 days" },
  { id: "30d", label: "30 days" },
  { id: "90d", label: "90 days" },
]
const KIND: Tab[] = [
  { id: "all", label: "All repos" },
  { id: "work", label: "Work" },
  { id: "personal", label: "Personal" },
]

/** Two upstream instances on one page share layoutId="active-pill". */
export function TwoTabBars({ patched = false }: { patched?: boolean }) {
  const [range, setRange] = useState("30d")
  const [kind, setKind] = useState("all")
  const bar = (label: string, tabs: Tab[], value: string, onChange: (id: string) => void) =>
    patched ? (
      <AnimatedTabsPatched label={label} tabs={tabs} activeTab={value} onChange={onChange} />
    ) : (
      <AnimatedTabs tabs={tabs} activeTab={value} onChange={onChange} />
    )
  return (
    <div className="flex w-full flex-col items-center gap-4">
      {bar("Time range", RANGE, range, setRange)}
      {bar("Repo kind", KIND, kind, setKind)}
    </div>
  )
}

/* ── RareUI LiquidTooltip ── */

const TOOLS: { label: string; icon: ReactNode }[] = [
  { label: "Bold", icon: <BoldIcon /> },
  { label: "Italic", icon: <ItalicIcon /> },
  { label: "Insert link", icon: <LinkIcon /> },
  { label: "Share", icon: <Share2Icon /> },
  { label: "Delete", icon: <Trash2Icon /> },
]

export function LiquidToolbar({ placement = "top" }: { placement?: "top" | "bottom" | "left" | "right" }) {
  return (
    <div className="flex items-center gap-1 rounded-lg p-1 ring-1 ring-border">
      {TOOLS.map((t) => (
        <LiquidTooltip key={t.label} text={t.label} placement={placement}>
          <Button variant="ghost" size="icon-sm" aria-label={t.label}>
            {t.icon}
          </Button>
        </LiquidTooltip>
      ))}
    </div>
  )
}

export function ShadcnToolbar() {
  return (
    <TooltipProvider>
      <div className="flex items-center gap-1 rounded-lg p-1 ring-1 ring-border">
        {TOOLS.map((t) => (
          <Tooltip key={t.label}>
            <TooltipTrigger render={<Button variant="ghost" size="icon-sm" aria-label={t.label} />}>{t.icon}</TooltipTrigger>
            <TooltipContent>{t.label}</TooltipContent>
          </Tooltip>
        ))}
      </div>
    </TooltipProvider>
  )
}

/* ── RareUI FloatingNavigation, in a phone frame ── */

const SCREENS: Record<string, { title: string; body: string }> = {
  home: { title: "Home", body: "3 repos changed since yesterday. odyssey has a new PR." },
  search: { title: "Search", body: "Ask the graph: “where do we format dates?”" },
  notifications: { title: "Inbox", body: "Backup finished at 02:14. No failed rebuilds." },
  profile: { title: "Profile", body: "Sam · 30 repos · 2 machines" },
  settings: { title: "Settings", body: "Rebuild nightly · Back up weekly" },
}

export function PhoneWithNav() {
  const [screen, setScreen] = useState("home")
  const s = SCREENS[screen]
  return (
    <div className="relative h-[380px] w-[220px] overflow-hidden rounded-[32px] bg-muted/40 ring-8 ring-zinc-900 dark:ring-zinc-700">
      <div className="px-5 pt-10">
        <div className="text-lg font-semibold">{s.title}</div>
        <p className="mt-2 text-sm text-muted-foreground">{s.body}</p>
      </div>
      {/* upstream positions itself `fixed bottom-8`; className overrides it to sit in the frame */}
      <FloatingNavigation className="absolute bottom-4 scale-[0.7]" onChange={setScreen} />
    </div>
  )
}

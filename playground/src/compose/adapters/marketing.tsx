// Marketing components: hero and nav.
// Every hero is boxed into a 340px frame: the effects assume they own the viewport (h-screen, w-screen,
// min-h-screen, h-[40rem]), so each one gets a height override and is clipped by an isolated,
// overflow-hidden, paint-contained frame. Nothing escapes the block, and their z-50 layers stay inside it.
import { useId, useState, type FormEvent, type MouseEvent, type ReactNode } from "react"
import { LayoutGroup, motion } from "motion/react"
import {
  ArrowRightIcon,
  BarChart3Icon,
  BellIcon,
  HomeIcon,
  MenuIcon,
  PackageIcon,
  RouteIcon,
  SearchIcon,
  SettingsIcon,
  ShoppingCartIcon,
  SparklesIcon,
  TruckIcon,
  UserIcon,
  type LucideIcon,
} from "lucide-react"
import { AnimatedGradientText } from "@/components/ui/animated-gradient-text"
import { AuroraBackground } from "@/components/ui/aurora-background"
import { BackgroundBeams } from "@/components/ui/background-beams"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Dock, DockIcon } from "@/components/ui/dock"
import { HeroHighlight, Highlight } from "@/components/ui/hero-highlight"
import { LampContainer } from "@/components/ui/lamp"
import { Ripple } from "@/components/ui/ripple"
import { Spotlight } from "@/components/ui/spotlight-new"
import FloatingNavigation from "@/demos/community/floating-navigation"
import { cn } from "@/lib/utils"
import type { Adapter, BlockProps, Option, OptionValues } from "../types"

/* ------------------------------------------------------------------------------------------------
 * Shared pieces
 * ---------------------------------------------------------------------------------------------- */

const SUB = "Rantai gives consumer brands in Malaysia one place for distributor orders, route plans, stock at every DC and sell-out by outlet."
const SUB_CODE = "Rantai gives consumer brands in Malaysia one place for distributor orders and route plans."

const text = (o: OptionValues, id: string, fallback: string) => ((o[id] as string) ?? "").trim() || fallback
const join = (...parts: (string | false | undefined)[]) => parts.filter((p): p is string => typeof p === "string").join("\n")

/** Keeps the lab's hash router from following the sample links. */
const stopLinks = (e: MouseEvent) => {
  if ((e.target as HTMLElement).closest("a")) e.preventDefault()
}

/** The box every hero lives in: fixed height, clipped, its own stacking context. */
function Frame({ className, children }: { className?: string; children: ReactNode }) {
  return (
    <div
      onClickCapture={stopLinks}
      className={cn("@container relative isolate flex h-[340px] w-full items-center justify-center overflow-hidden rounded-xl border [contain:paint]", className)}
    >
      {children}
    </div>
  )
}

type Tone = "dark" | "theme"

function Ctas({ tone, className }: { tone: Tone; className?: string }) {
  const dark = tone === "dark"
  return (
    <div className={cn("mt-1 flex flex-wrap items-center justify-center gap-2", className)}>
      <Button size="lg" className={cn(dark && "bg-white text-neutral-950 hover:bg-white/85")}>
        Book a demo
      </Button>
      <Button
        size="lg"
        variant="ghost"
        className={cn(dark && "text-neutral-300 hover:bg-white/10 hover:text-white dark:hover:bg-white/10")}
      >
        See how it works
        <ArrowRightIcon data-icon="inline-end" />
      </Button>
    </div>
  )
}

function Copy({
  tone,
  headline,
  sub = SUB,
  cta,
  eyebrow,
  align = "center",
  className,
}: {
  tone: Tone
  headline: ReactNode
  sub?: string | false
  cta?: boolean
  eyebrow?: ReactNode
  align?: "center" | "left"
  className?: string
}) {
  const dark = tone === "dark"
  const left = align === "left"
  return (
    <div className={cn("relative z-50 flex max-w-2xl flex-col gap-3 px-6", left ? "mr-auto items-start text-left @2xl:px-12" : "items-center text-center", className)}>
      {eyebrow}
      <h2 className={cn("text-3xl font-semibold tracking-tight text-balance @2xl:text-4xl", dark ? "text-white" : "text-foreground")}>{headline}</h2>
      {sub && <p className={cn("max-w-lg text-sm text-balance @2xl:text-base", dark ? "text-neutral-400" : "text-muted-foreground")}>{sub}</p>}
      {cta && <Ctas tone={tone} className={left ? "justify-start" : undefined} />}
    </div>
  )
}

const ctaCode = (indent: string, dark = false) =>
  join(
    `${indent}<div className="flex gap-2">`,
    `${indent}  <Button size="lg"${dark ? ` className="bg-white text-neutral-950 hover:bg-white/85"` : ""}>Book a demo</Button>`,
    `${indent}  <Button size="lg" variant="ghost">See how it works</Button>`,
    `${indent}</div>`,
  )

/* ------------------------------------------------------------------------------------------------
 * Hero: Aceternity
 * ---------------------------------------------------------------------------------------------- */

function AuroraHero({ options: o }: BlockProps) {
  return (
    // block, not flex: AuroraBackground wraps itself in an unstyled div that would shrink to its content.
    <Frame className="block">
      {/* AuroraBackground is h-[100vh] and wraps itself in an unstyled div, so h-full can't reach it: size it directly. */}
      <AuroraBackground className="h-[340px] w-full" showRadialGradient={o.radial as boolean}>
        <Copy tone="theme" headline={text(o, "headline", "Route-to-market software for every kedai")} cta={o.cta as boolean} />
      </AuroraBackground>
    </Frame>
  )
}

function BeamsHero({ options: o }: BlockProps) {
  const [joined, setJoined] = useState(false)
  const submit = (e: FormEvent) => {
    e.preventDefault()
    setJoined(true)
  }
  return (
    <Frame className="bg-neutral-950">
      <Copy
        tone="dark"
        headline={text(o, "headline", "Join the Rantai pilot")}
        sub="Twenty brands get route plans and sell-out by outlet before Hari Raya. No card needed."
      />
      {o.form && (
        <form onSubmit={submit} className="absolute inset-x-0 bottom-14 z-50 mx-auto flex w-full max-w-sm gap-2 px-6">
          {joined ? (
            <p className="w-full text-center text-sm text-neutral-300">You're on the list. We'll be in touch this week.</p>
          ) : (
            <>
              <input
                type="email"
                required
                aria-label="Work email"
                placeholder="you@brand.com.my"
                className="h-9 min-w-0 flex-1 rounded-lg border border-neutral-800 bg-neutral-900 px-3 text-sm text-white outline-none placeholder:text-neutral-500 focus:border-neutral-600"
              />
              <Button type="submit" size="lg" className="bg-white text-neutral-950 hover:bg-white/85">
                Join
              </Button>
            </>
          )}
        </form>
      )}
      <BackgroundBeams />
    </Frame>
  )
}

const DRIFT: Record<string, number> = { slow: 14, default: 7, fast: 3 }
const SWEEP: Record<string, number> = { narrow: 40, default: 100, wide: 260 }

function SpotlightHero({ options: o }: BlockProps) {
  const duration = DRIFT[o.drift as string] ?? 7
  const xOffset = SWEEP[o.sweep as string] ?? 100
  return (
    <Frame className="bg-neutral-950">
      {/* Spotlight reads its props once; remount it when they change. */}
      <Spotlight key={`${duration}-${xOffset}`} duration={duration} xOffset={xOffset} />
      <Copy
        tone="dark"
        headline={text(o, "headline", "Every outlet, every order, one view")}
        cta={o.cta as boolean}
        eyebrow={<span className="rounded-full border border-white/15 bg-white/5 px-3 py-1 text-xs text-neutral-300">New: Hari Raya demand forecasts</span>}
      />
    </Frame>
  )
}

function LampHero({ options: o }: BlockProps) {
  return (
    <Frame className="bg-slate-950">
      {/*
        LampContainer is min-h-screen and pushes its children up with -translate-y-80, which in a short box puts them
        above the lamp. Fill the frame, drop the lamp 4rem with padding, and place the copy absolutely under the beam.
      */}
      <LampContainer className="h-full min-h-0 rounded-none pt-16">
        <div className="absolute top-[78px] left-1/2 flex w-[min(36rem,92cqw)] -translate-x-1/2 flex-col items-center gap-3 text-center">
          <motion.h2
            initial={{ opacity: 0.5, y: 40 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.3, duration: 0.8, ease: "easeInOut" }}
            className="bg-linear-to-br from-slate-200 to-slate-500 bg-clip-text py-1 text-3xl font-medium tracking-tight text-balance text-transparent @2xl:text-4xl"
          >
            {text(o, "headline", "Route plans on every phone by 6 am")}
          </motion.h2>
          {o.sub && <p className="max-w-md text-sm text-balance text-slate-400">Van sales reps get the day's outlets on their phones, sequenced around KL traffic.</p>}
          {o.cta && <span className="mt-1 rounded-full bg-cyan-500 px-5 py-2 text-sm font-medium text-slate-950">Start a 30-day pilot</span>}
        </div>
      </LampContainer>
    </Frame>
  )
}

const MARKERS: Record<string, string | undefined> = {
  indigo: undefined,
  amber: "from-amber-200 to-orange-300 dark:from-amber-500 dark:to-orange-600",
  emerald: "from-emerald-200 to-teal-300 dark:from-emerald-600 dark:to-teal-600",
}

function HighlightHero({ options: o }: BlockProps) {
  const phrase = text(o, "phrase", "real sell-out")
  return (
    <Frame>
      <HeroHighlight containerClassName="h-full" className="flex flex-col items-center">
        <Copy
          tone="theme"
          cta={o.cta as boolean}
          headline={
            <>
              {text(o, "headline", "Trade spend that follows")}{" "}
              {/* Highlight sweeps once on mount; the key replays it when the phrase or colour changes. */}
              <Highlight key={`${phrase}-${o.marker}`} className={cn("whitespace-nowrap text-black dark:text-white", MARKERS[o.marker as string])}>
                {phrase}
              </Highlight>
            </>
          }
        />
      </HeroHighlight>
    </Frame>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Hero: Magic UI
 * ---------------------------------------------------------------------------------------------- */

const RIPPLE_SIZE: Record<string, number> = { small: 120, medium: 210, large: 300 }

function RippleHero({ options: o }: BlockProps) {
  return (
    <Frame className="bg-background">
      <Ripple numCircles={Number(o.circles) || 6} mainCircleSize={RIPPLE_SIZE[o.size as string] ?? 210} />
      <Copy
        tone="theme"
        headline={text(o, "headline", "Every distributor, connected")}
        sub="Orders from every distributor and key account land in one queue, checked against credit limits."
        cta={o.cta as boolean}
        className="z-10"
      />
    </Frame>
  )
}

const SWATCHES: Record<string, [string, string]> = {
  sunset: ["#ffaa40", "#9c40ff"],
  lagoon: ["#10b981", "#0ea5e9"],
  rose: ["#f43f5e", "#f59e0b"],
  mono: ["#a1a1aa", "#52525b"],
}

function GradientTextHero({ options: o }: BlockProps) {
  const [from, to] = SWATCHES[o.colours as string] ?? SWATCHES.sunset
  const speed = Number(o.speed) || 1
  return (
    <Frame className="bg-background">
      <Copy
        tone="theme"
        cta
        eyebrow={
          o.pill ? (
            <a href="#" className="inline-flex items-center gap-2 rounded-full border bg-background px-3 py-1 text-sm shadow-sm transition-shadow hover:shadow">
              <SparklesIcon className="size-3.5" style={{ color: from }} />
              <span className="h-4 w-px bg-border" />
              <AnimatedGradientText colorFrom={from} colorTo={to} speed={speed} className="font-medium">
                Introducing Rantai Insights
              </AnimatedGradientText>
              <ArrowRightIcon className="size-3.5 text-muted-foreground" />
            </a>
          ) : undefined
        }
        headline={
          <>
            Know what sold,{" "}
            <AnimatedGradientText colorFrom={from} colorTo={to} speed={speed}>
              {text(o, "headline", "outlet by outlet")}
            </AnimatedGradientText>
          </>
        }
      />
    </Frame>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Hero: shadcn baseline
 * ---------------------------------------------------------------------------------------------- */

function PlainHero({ options: o }: BlockProps) {
  return (
    <Frame className="bg-background">
      <Copy
        tone="theme"
        align={o.align === "left" ? "left" : "center"}
        headline={text(o, "headline", "Every outlet, every order, one view")}
        cta={o.cta as boolean}
        eyebrow={o.badge ? <Badge variant="secondary">New: Hari Raya demand forecasts</Badge> : undefined}
      />
    </Frame>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Nav: RareUI floating navigation
 * ---------------------------------------------------------------------------------------------- */

const NAV_ITEMS: { id: string; label: string; icon: ReactNode }[] = [
  // The ids are the ones upstream keys its per-icon animations on (home bounces, notifications rings…).
  { id: "home", label: "Today", icon: <HomeIcon className="size-5" /> },
  { id: "search", label: "Search", icon: <SearchIcon className="size-5" /> },
  { id: "notifications", label: "Inbox", icon: <BellIcon className="size-5" /> },
  { id: "profile", label: "Account", icon: <UserIcon className="size-5" /> },
  { id: "settings", label: "Settings", icon: <SettingsIcon className="size-5" /> },
]

const SCREENS: Record<string, { title: string; body: string; rows: string[] }> = {
  home: { title: "Today", body: "12 orders to pick at Shah Alam DC.", rows: ["#4821 · Jaya Grocer Bangsar", "#4817 · 99 Speedmart Puchong", "#4820 · Kedai Runcit Ahmad"] },
  search: { title: "Search", body: "Find an outlet, SKU or order.", rows: ["Kopi O Kaw 500g", "Jaya Grocer", "#4821"] },
  notifications: { title: "Inbox", body: "3 alerts since 6 am.", rows: ["Kopi O Kaw 500g: 86 left", "#4819 shipped to Kuching", "Van KV-03 is loaded"] },
  profile: { title: "Account", body: "Aisyah · Key accounts, Klang Valley", rows: ["14 outlets", "RM 184,230 this month", "Target 92% met"] },
  settings: { title: "Settings", body: "Prices in RM · Week starts Monday", rows: ["Notifications", "Default DC: Shah Alam", "Sign out"] },
}

function FloatingNavScreen({ tabs, phone }: { tabs: number; phone: boolean }) {
  const group = useId()
  const [screen, setScreen] = useState("home")
  const s = SCREENS[screen] ?? SCREENS.home
  return (
    <div
      className={cn(
        "relative isolate h-full overflow-hidden bg-background [contain:paint]",
        phone ? "w-[230px] rounded-[32px] ring-8 ring-zinc-900 dark:ring-zinc-700" : "w-full rounded-lg ring-1 ring-border",
      )}
    >
      <div className={cn("pt-8", phone ? "px-5" : "px-6")}>
        <div className="text-lg font-semibold">{s.title}</div>
        <p className="mt-1 text-sm text-muted-foreground">{s.body}</p>
        <div className="mt-4 flex flex-col gap-2">
          {s.rows.map((r) => (
            <div key={r} className="truncate rounded-lg bg-muted/60 px-3 py-2 text-xs">
              {r}
            </div>
          ))}
        </div>
      </div>
      {/* Upstream hard-codes layoutId="nav-active"/"nav-hover": the group keeps two blocks' pills apart. */}
      <LayoutGroup id={group}>
        <FloatingNavigation
          items={NAV_ITEMS.slice(0, tabs)}
          onChange={setScreen}
          // Upstream is `fixed bottom-8`; absolute pins it to this screen instead of the window.
          className={cn("absolute bottom-4", phone && tabs > 3 && "bottom-2 origin-bottom scale-[0.72]")}
        />
      </LayoutGroup>
    </div>
  )
}

function RareFloatingNav({ options: o }: BlockProps) {
  const tabs = Number(o.tabs) || 5
  const phone = o.frame !== "window"
  return (
    <div className="flex h-[340px] w-full items-center justify-center rounded-xl border bg-muted/30 p-5">
      <FloatingNavScreen key={`${tabs}-${phone}`} tabs={tabs} phone={phone} />
    </div>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Nav: Magic UI Dock
 * ---------------------------------------------------------------------------------------------- */

const DOCK_ITEMS: { label: string; icon: LucideIcon }[] = [
  { label: "Home", icon: HomeIcon },
  { label: "Orders", icon: ShoppingCartIcon },
  { label: "Stock", icon: PackageIcon },
  { label: "Routes", icon: TruckIcon },
  { label: "Reports", icon: BarChart3Icon },
  { label: "Settings", icon: SettingsIcon },
]

function MagicDock({ options: o }: BlockProps) {
  const off = o.magnify === "off"
  const items = DOCK_ITEMS.slice(0, Number(o.icons) || 6)
  return (
    <div className="relative isolate flex h-44 w-full items-end justify-center overflow-hidden rounded-xl border bg-muted/30 pb-6 [contain:paint]">
      <Dock
        // Dock's own glass tint uses `supports-backdrop-blur:`, which Tailwind v4 never matches, so it's see-through.
        className={cn("mt-0", o.tint && "bg-background/70 shadow-sm")}
        iconSize={40}
        iconMagnification={off ? 40 : Number(o.magnify) || 64}
        disableMagnification={off}
        iconDistance={Number(o.reach) || 140}
        direction="bottom"
      >
        {items.map((d) => (
          <DockIcon key={d.label} className="bg-muted/60">
            {/* DockIcon is a div: put a real button inside so keyboard users can reach it. */}
            <button
              type="button"
              aria-label={d.label}
              title={d.label}
              className="flex items-center justify-center rounded-full outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              <d.icon className="size-5" />
            </button>
          </DockIcon>
        ))}
      </Dock>
    </div>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Nav: shadcn baseline
 * ---------------------------------------------------------------------------------------------- */

const LINKS = ["Product", "Customers", "Pricing", "Docs"]

function PlainNav({ options: o }: BlockProps) {
  const [active, setActive] = useState("Product")
  const floating = o.style === "floating"
  const pill = o.indicator === "pill"
  return (
    <div onClickCapture={stopLinks} className="@container w-full overflow-hidden rounded-xl border bg-muted/30">
      <div className={cn(floating && "px-3 pt-3")}>
        <nav
          aria-label="Main"
          className={cn(
            "flex h-14 items-center gap-4 px-4",
            floating ? "mx-auto max-w-3xl rounded-full border bg-background/80 pr-2 shadow-sm backdrop-blur" : "border-b bg-background",
          )}
        >
          <a href="#" className="flex items-center gap-2 font-semibold">
            <span className="flex size-7 items-center justify-center rounded-lg bg-primary text-primary-foreground">
              <RouteIcon className="size-4" />
            </span>
            Rantai
          </a>
          <div className="hidden items-center gap-1 @xl:flex">
            {LINKS.map((l) => (
              <a
                key={l}
                href="#"
                aria-current={active === l ? "page" : undefined}
                onClick={() => setActive(l)}
                className={cn(
                  "rounded-full px-3 py-1 text-sm text-muted-foreground transition-colors hover:text-foreground aria-[current=page]:text-foreground",
                  pill ? "aria-[current=page]:bg-muted" : "decoration-2 underline-offset-[6px] aria-[current=page]:underline",
                )}
              >
                {l}
              </a>
            ))}
          </div>
          <div className="ml-auto flex items-center gap-1.5">
            {o.cta && (
              <>
                <Button variant="ghost" size="sm" className="hidden @md:inline-flex">
                  Sign in
                </Button>
                <Button size="sm" className={cn(floating && "rounded-full")}>
                  Book a demo
                </Button>
              </>
            )}
            <Button variant="ghost" size="icon-sm" aria-label="Menu" className="@xl:hidden">
              <MenuIcon />
            </Button>
          </div>
        </nav>
      </div>
      {/* A suggestion of the page underneath, so the bar reads as a nav. */}
      <div aria-hidden className="flex flex-col gap-2 px-8 py-6">
        <div className="h-5 w-48 rounded bg-muted" />
        <div className="h-3 w-full max-w-md rounded bg-muted/70" />
        <div className="h-3 w-full max-w-sm rounded bg-muted/70" />
      </div>
    </div>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Adapters
 * ---------------------------------------------------------------------------------------------- */

const ctaSwitch: Option = { id: "cta", label: "Buttons", type: "switch", default: true }

export const adapters: Adapter[] = [
  /* ── Hero ── */
  {
    id: "hero-aurora",
    slot: "hero",
    library: "aceternity",
    label: "Aurora",
    note: "CSS-only blurred bands that follow light and dark; ~40 ms/s of repaint while idle",
    options: [
      { id: "headline", label: "Headline", type: "text", default: "Route-to-market software for every kedai" },
      { id: "radial", label: "Fade to one corner", type: "switch", default: true },
      ctaSwitch,
    ],
    // No motion import (a CSS keyframe), and it has light and dark backgrounds and gradients.
    traits: { needsMotion: false, darkMode: "ok" },
    install: ["npx shadcn@latest add @aceternity/aurora-background"],
    code: (o) =>
      join(
        `import { AuroraBackground } from "@/components/ui/aurora-background"`,
        o.cta && `import { Button } from "@/components/ui/button"`,
        ``,
        `// It's h-[100vh] out of the box: size it to the section.`,
        `<AuroraBackground className="h-[340px]"${o.radial ? "" : " showRadialGradient={false}"}>`,
        `  <div className="relative z-10 flex flex-col items-center gap-3 px-6 text-center">`,
        `    <h1 className="text-4xl font-semibold tracking-tight">${text(o, "headline", "Route-to-market software for every kedai")}</h1>`,
        `    <p className="max-w-lg text-muted-foreground">${SUB_CODE}</p>`,
        o.cta && ctaCode("    "),
        `  </div>`,
        `</AuroraBackground>`,
      ),
    render: AuroraHero,
  },
  {
    id: "hero-beams",
    slot: "hero",
    library: "aceternity",
    label: "Background beams",
    note: "50 SVG gradients animated every frame: the heaviest effect, ~100 ms/s idle",
    options: [
      { id: "headline", label: "Headline", type: "text", default: "Join the Rantai pilot" },
      { id: "form", label: "Waitlist form", type: "switch", default: true },
    ],
    install: ["npx shadcn@latest add @aceternity/background-beams"],
    code: (o) =>
      join(
        `import { BackgroundBeams } from "@/components/ui/background-beams"`,
        ``,
        `// Beams are cyan-to-violet on a dark section; they don't follow the theme.`,
        `<section className="relative flex h-[340px] items-center justify-center overflow-hidden bg-neutral-950">`,
        `  <div className="relative z-10 flex flex-col items-center gap-3 text-center text-white">`,
        `    <h1 className="text-4xl font-semibold tracking-tight">${text(o, "headline", "Join the Rantai pilot")}</h1>`,
        o.form && `    <form className="flex gap-2">`,
        o.form && `      <input type="email" aria-label="Work email" placeholder="you@brand.com.my" />`,
        o.form && `      <button type="submit">Join</button>`,
        o.form && `    </form>`,
        `  </div>`,
        `  <BackgroundBeams />`,
        `</section>`,
      ),
    render: BeamsHero,
  },
  {
    id: "hero-spotlight",
    slot: "hero",
    library: "aceternity",
    label: "Spotlight",
    note: "Two soft beams drifting from the corners; cheap, but a faint wash on light backgrounds",
    options: [
      { id: "headline", label: "Headline", type: "text", default: "Every outlet, every order, one view" },
      {
        id: "drift",
        label: "Drift",
        type: "select",
        default: "default",
        choices: [
          { value: "slow", label: "Slow (14 s)" },
          { value: "default", label: "Default (7 s)" },
          { value: "fast", label: "Fast (3 s)" },
        ],
      },
      {
        id: "sweep",
        label: "Sweep",
        type: "select",
        default: "default",
        choices: [
          { value: "narrow", label: "Narrow (40 px)" },
          { value: "default", label: "Default (100 px)" },
          { value: "wide", label: "Wide (260 px)" },
        ],
      },
      ctaSwitch,
    ],
    install: ["npx shadcn@latest add @aceternity/spotlight-new"],
    code: (o) =>
      join(
        `import { Spotlight } from "@/components/ui/spotlight-new"`,
        o.cta && `import { Button } from "@/components/ui/button"`,
        ``,
        `// White-blue beams at 2–8% opacity: keep the section dark.`,
        `<section className="relative overflow-hidden bg-neutral-950">`,
        `  <Spotlight${o.drift !== "default" ? ` duration={${DRIFT[o.drift as string]}}` : ""}${o.sweep !== "default" ? ` xOffset={${SWEEP[o.sweep as string]}}` : ""} />`,
        `  <div className="relative z-50 flex flex-col items-center gap-3 px-6 py-24 text-center">`,
        `    <h1 className="text-4xl font-semibold tracking-tight text-white">${text(o, "headline", "Every outlet, every order, one view")}</h1>`,
        `    <p className="max-w-lg text-neutral-400">${SUB_CODE}</p>`,
        o.cta && ctaCode("    ", true),
        `  </div>`,
        `</section>`,
      ),
    render: SpotlightHero,
  },
  {
    id: "hero-lamp",
    slot: "hero",
    library: "aceternity",
    label: "Lamp",
    note: "A cyan beam that opens once on entry, then sits idle; always slate-950",
    options: [
      { id: "headline", label: "Headline", type: "text", default: "Route plans on every phone by 6 am" },
      { id: "sub", label: "Subheading", type: "switch", default: true },
      { id: "cta", label: "Button", type: "switch", default: true },
    ],
    // Animates once when scrolled into view, then nothing runs.
    traits: { ignoresReducedMotion: false },
    install: ["npx shadcn@latest add @aceternity/lamp"],
    code: (o) =>
      join(
        `import { motion } from "motion/react"`,
        `import { LampContainer } from "@/components/ui/lamp"`,
        ``,
        `// Built for min-h-screen: children are pushed up with -translate-y-80, so a short section needs care.`,
        `<LampContainer className="min-h-[30rem]">`,
        `  <motion.h1`,
        `    initial={{ opacity: 0.5, y: 40 }}`,
        `    whileInView={{ opacity: 1, y: 0 }}`,
        `    viewport={{ once: true }}`,
        `    transition={{ delay: 0.3, duration: 0.8, ease: "easeInOut" }}`,
        `    className="bg-linear-to-br from-slate-200 to-slate-500 bg-clip-text text-4xl font-medium text-transparent"`,
        `  >`,
        `    ${text(o, "headline", "Route plans on every phone by 6 am")}`,
        `  </motion.h1>`,
        o.sub && `  <p className="text-slate-400">Van sales reps get the day's outlets on their phones.</p>`,
        o.cta && `  <a href="/pilot" className="rounded-full bg-cyan-500 px-5 py-2 text-slate-950">Start a 30-day pilot</a>`,
        `</LampContainer>`,
      ),
    render: LampHero,
  },
  {
    id: "hero-highlight",
    slot: "hero",
    library: "aceternity",
    label: "Hero highlight",
    note: "A dot grid that lights up under the mouse, and a marker that sweeps one phrase",
    options: [
      { id: "headline", label: "Headline", type: "text", default: "Trade spend that follows" },
      { id: "phrase", label: "Highlighted words", type: "text", default: "real sell-out" },
      {
        id: "marker",
        label: "Marker",
        type: "select",
        default: "indigo",
        choices: [
          { value: "indigo", label: "Indigo (default)" },
          { value: "amber", label: "Amber" },
          { value: "emerald", label: "Emerald" },
        ],
      },
      ctaSwitch,
    ],
    // The marker sweeps once and the grid only reacts to the mouse; it has light and dark dot colours.
    traits: { ignoresReducedMotion: false, darkMode: "ok" },
    install: ["npx shadcn@latest add @aceternity/hero-highlight"],
    code: (o) =>
      join(
        `import { HeroHighlight, Highlight } from "@/components/ui/hero-highlight"`,
        o.cta && `import { Button } from "@/components/ui/button"`,
        ``,
        `// containerClassName overrides its h-[40rem].`,
        `<HeroHighlight containerClassName="h-[340px]">`,
        `  <h1 className="text-4xl font-semibold tracking-tight">`,
        `    ${text(o, "headline", "Trade spend that follows")}{" "}`,
        `    <Highlight className="text-black dark:text-white${MARKERS[o.marker as string] ? ` ${MARKERS[o.marker as string]}` : ""}">${text(o, "phrase", "real sell-out")}</Highlight>`,
        `  </h1>`,
        o.cta && ctaCode("  "),
        `</HeroHighlight>`,
      ),
    render: HighlightHero,
  },
  {
    id: "hero-ripple",
    slot: "hero",
    library: "magicui",
    label: "Ripple",
    note: "Pulsing rings drawn from --foreground, so it themes itself; pure CSS",
    options: [
      { id: "headline", label: "Headline", type: "text", default: "Every distributor, connected" },
      {
        id: "circles",
        label: "Rings",
        type: "select",
        default: "6",
        choices: [
          { value: "3", label: "3" },
          { value: "6", label: "6" },
          { value: "9", label: "9" },
        ],
      },
      {
        id: "size",
        label: "First ring",
        type: "select",
        default: "medium",
        choices: [
          { value: "small", label: "Small (120 px)" },
          { value: "medium", label: "Medium (210 px)" },
          { value: "large", label: "Large (300 px)" },
        ],
      },
      ctaSwitch,
    ],
    // CSS keyframes (no motion), coloured from --foreground, and no reduced-motion check on the loop.
    traits: { needsMotion: false, ignoresReducedMotion: true, darkMode: "ok", pageKind: "marketing" },
    install: ["npx shadcn@latest add @magicui/ripple"],
    code: (o) =>
      join(
        `import { Ripple } from "@/components/ui/ripple"`,
        o.cta && `import { Button } from "@/components/ui/button"`,
        ``,
        `<section className="relative flex h-[340px] items-center justify-center overflow-hidden bg-background">`,
        `  <Ripple${o.circles !== "8" ? ` numCircles={${o.circles}}` : ""}${o.size !== "medium" ? ` mainCircleSize={${RIPPLE_SIZE[o.size as string]}}` : ""} />`,
        `  <div className="relative z-10 flex flex-col items-center gap-3 text-center">`,
        `    <h1 className="text-4xl font-semibold tracking-tight">${text(o, "headline", "Every distributor, connected")}</h1>`,
        o.cta && ctaCode("    "),
        `  </div>`,
        `</section>`,
      ),
    render: RippleHero,
  },
  {
    id: "hero-gradient-text",
    slot: "hero",
    library: "magicui",
    label: "Animated gradient text",
    note: "A moving gradient clipped to the words, plus an announcement pill",
    options: [
      { id: "headline", label: "Gradient words", type: "text", default: "outlet by outlet" },
      {
        id: "colours",
        label: "Colours",
        type: "select",
        default: "sunset",
        choices: [
          { value: "sunset", label: "Sunset" },
          { value: "lagoon", label: "Lagoon" },
          { value: "rose", label: "Rose" },
          { value: "mono", label: "Mono" },
        ],
      },
      {
        id: "speed",
        label: "Speed",
        type: "select",
        default: "1",
        choices: [
          { value: "1", label: "1×" },
          { value: "2", label: "2×" },
          { value: "4", label: "4×" },
        ],
      },
      { id: "pill", label: "Announcement pill", type: "switch", default: true },
    ],
    // A CSS keyframe loop (no motion, no reduced-motion check); both colours are mid-tones that read on either theme.
    traits: { needsMotion: false, ignoresReducedMotion: true, darkMode: "ok", pageKind: "marketing" },
    install: ["npx shadcn@latest add @magicui/animated-gradient-text"],
    code: (o) => {
      const [from, to] = SWATCHES[o.colours as string] ?? SWATCHES.sunset
      const props = `colorFrom="${from}" colorTo="${to}"${o.speed !== "1" ? ` speed={${o.speed}}` : ""}`
      return join(
        `import { AnimatedGradientText } from "@/components/ui/animated-gradient-text"`,
        ``,
        o.pill && `<a href="/insights" className="inline-flex items-center gap-2 rounded-full border px-3 py-1 text-sm">`,
        o.pill && `  <AnimatedGradientText ${props} className="font-medium">Introducing Rantai Insights</AnimatedGradientText>`,
        o.pill && `</a>`,
        `<h1 className="text-4xl font-semibold tracking-tight">`,
        `  Know what sold,{" "}`,
        `  <AnimatedGradientText ${props}>${text(o, "headline", "outlet by outlet")}</AnimatedGradientText>`,
        `</h1>`,
      )
    },
    render: GradientTextHero,
  },
  {
    id: "hero-shadcn",
    slot: "hero",
    library: "shadcn",
    label: "Plain hero",
    note: "Heading, subheading and buttons on theme tokens; nothing moves",
    options: [
      { id: "headline", label: "Headline", type: "text", default: "Every outlet, every order, one view" },
      {
        id: "align",
        label: "Align",
        type: "select",
        default: "center",
        choices: [
          { value: "center", label: "Centre" },
          { value: "left", label: "Left" },
        ],
      },
      { id: "badge", label: "Badge", type: "switch", default: true },
      ctaSwitch,
    ],
    traits: { darkMode: "ok" },
    install: ["npx shadcn@latest add button badge"],
    code: (o) =>
      join(
        o.badge && `import { Badge } from "@/components/ui/badge"`,
        o.cta && `import { Button } from "@/components/ui/button"`,
        ``,
        `<section className="flex flex-col ${o.align === "left" ? "items-start text-left" : "items-center text-center"} gap-3 px-6 py-24">`,
        o.badge && `  <Badge variant="secondary">New: Hari Raya demand forecasts</Badge>`,
        `  <h1 className="text-4xl font-semibold tracking-tight text-balance">${text(o, "headline", "Every outlet, every order, one view")}</h1>`,
        `  <p className="max-w-lg text-muted-foreground">${SUB_CODE}</p>`,
        o.cta && ctaCode("  "),
        `</section>`,
      ),
    render: PlainHero,
  },

  /* ── Nav ── */
  {
    id: "nav-floating",
    slot: "nav",
    library: "rareui",
    label: "Floating navigation",
    note: "A glass pill of icon tabs with a spring and a per-icon wiggle; hover-only labels",
    options: [
      {
        id: "frame",
        label: "Frame",
        type: "select",
        default: "phone",
        choices: [
          { value: "phone", label: "Phone" },
          { value: "window", label: "App window" },
        ],
      },
      {
        id: "tabs",
        label: "Tabs",
        type: "select",
        default: "5",
        choices: [
          { value: "3", label: "3" },
          { value: "5", label: "5" },
        ],
      },
    ],
    // Every colour has a dark: pair (glass, active pill, tooltip).
    traits: { darkMode: "ok" },
    install: ["Copy from github.com/Codewithswappy/ShitUI (components/shitui/FloatingNavigation)"],
    code: (o) =>
      join(
        `import { useId } from "react"`,
        `import { LayoutGroup } from "motion/react"`,
        `import { BellIcon, HomeIcon, SearchIcon${o.tabs === "5" ? ", SettingsIcon, UserIcon" : ""} } from "lucide-react"`,
        `import FloatingNavigation from "@/components/floating-navigation"`,
        ``,
        `const items = [`,
        `  { id: "home", label: "Today", icon: <HomeIcon className="size-5" /> },`,
        `  { id: "search", label: "Search", icon: <SearchIcon className="size-5" /> },`,
        `  { id: "notifications", label: "Inbox", icon: <BellIcon className="size-5" /> },`,
        o.tabs === "5" && `  { id: "profile", label: "Account", icon: <UserIcon className="size-5" /> },`,
        o.tabs === "5" && `  { id: "settings", label: "Settings", icon: <SettingsIcon className="size-5" /> },`,
        `]`,
        ``,
        `// Upstream is \`fixed bottom-8\` with hard-coded layoutIds and no onChange (we added one).`,
        `<${o.frame === "phone" ? `div className="relative h-[380px] w-[230px] overflow-hidden rounded-[32px]"` : `div className="relative h-[320px] overflow-hidden"`}>`,
        `  <LayoutGroup id={useId()}>`,
        `    <FloatingNavigation items={items} onChange={setScreen} className="absolute bottom-4${o.frame === "phone" && o.tabs === "5" ? " origin-bottom scale-[0.72]" : ""}" />`,
        `  </LayoutGroup>`,
        `</div>`,
      ),
    render: RareFloatingNav,
  },
  {
    id: "nav-dock",
    slot: "nav",
    library: "magicui",
    label: "Dock",
    note: "macOS-style icons that grow toward the mouse; mouse-only magnification",
    options: [
      {
        id: "magnify",
        label: "Magnify to",
        type: "select",
        default: "64",
        choices: [
          { value: "off", label: "Off" },
          { value: "52", label: "52 px" },
          { value: "64", label: "64 px" },
          { value: "88", label: "88 px" },
        ],
      },
      {
        id: "reach",
        label: "Reach",
        type: "select",
        default: "140",
        choices: [
          { value: "70", label: "Short (70 px)" },
          { value: "140", label: "Default (140 px)" },
          { value: "260", label: "Long (260 px)" },
        ],
      },
      {
        id: "icons",
        label: "Icons",
        type: "select",
        default: "6",
        choices: [
          { value: "4", label: "4" },
          { value: "6", label: "6" },
        ],
      },
      { id: "tint", label: "Our tint", type: "switch", default: true },
    ],
    // Only the border token colours it (its own tint never applies in either theme); kept to marketing by the Playbook.
    traits: { darkMode: "ok", pageKind: "marketing" },
    install: ["npx shadcn@latest add @magicui/dock"],
    code: (o) =>
      join(
        `import { HomeIcon, PackageIcon, ShoppingCartIcon, TruckIcon${o.icons === "6" ? ", BarChart3Icon, SettingsIcon" : ""} } from "lucide-react"`,
        `import { Dock, DockIcon } from "@/components/ui/dock"`,
        ``,
        `const items = [`,
        `  { label: "Home", icon: HomeIcon },`,
        `  { label: "Orders", icon: ShoppingCartIcon },`,
        `  { label: "Stock", icon: PackageIcon },`,
        `  { label: "Routes", icon: TruckIcon },`,
        o.icons === "6" && `  { label: "Reports", icon: BarChart3Icon },`,
        o.icons === "6" && `  { label: "Settings", icon: SettingsIcon },`,
        `]`,
        ``,
        `<Dock`,
        `  direction="bottom"`,
        o.magnify === "off" ? `  disableMagnification` : o.magnify !== "60" && `  iconMagnification={${o.magnify}}`,
        o.reach !== "140" && `  iconDistance={${o.reach}}`,
        o.tint && `  className="bg-background/70 shadow-sm" // its supports-backdrop-blur tint never applies`,
        `>`,
        `  {items.map((d) => (`,
        `    <DockIcon key={d.label} className="bg-muted/60">`,
        `      {/* DockIcon is a div: put a real button or link inside */}`,
        `      <button type="button" aria-label={d.label}><d.icon className="size-5" /></button>`,
        `    </DockIcon>`,
        `  ))}`,
        `</Dock>`,
      ),
    render: MagicDock,
  },
  {
    id: "nav-shadcn",
    slot: "nav",
    library: "shadcn",
    label: "Plain nav bar",
    note: "Logo, links and buttons on theme tokens; collapses to a menu button when narrow",
    options: [
      {
        id: "style",
        label: "Style",
        type: "select",
        default: "bar",
        choices: [
          { value: "bar", label: "Full-width bar" },
          { value: "floating", label: "Floating pill" },
        ],
      },
      {
        id: "indicator",
        label: "Current page",
        type: "select",
        default: "underline",
        choices: [
          { value: "underline", label: "Underline" },
          { value: "pill", label: "Pill" },
        ],
      },
      { id: "cta", label: "Sign-in buttons", type: "switch", default: true },
    ],
    traits: { darkMode: "ok" },
    install: ["npx shadcn@latest add button"],
    code: (o) =>
      join(
        `import { Button } from "@/components/ui/button"`,
        ``,
        `<nav aria-label="Main" className="flex h-14 items-center gap-4 px-4 ${
          o.style === "floating" ? "mx-auto max-w-3xl rounded-full border bg-background/80 shadow-sm backdrop-blur" : "border-b bg-background"
        }">`,
        `  <a href="/" className="font-semibold">Rantai</a>`,
        `  {links.map((l) => (`,
        `    <a key={l.href} href={l.href} aria-current={l.href === path ? "page" : undefined}`,
        `      className="rounded-full px-3 py-1 text-sm text-muted-foreground hover:text-foreground aria-[current=page]:text-foreground ${
          o.indicator === "pill" ? "aria-[current=page]:bg-muted" : "decoration-2 underline-offset-[6px] aria-[current=page]:underline"
        }">`,
        `      {l.label}`,
        `    </a>`,
        `  ))}`,
        o.cta && `  <div className="ml-auto flex gap-1.5">`,
        o.cta && `    <Button variant="ghost" size="sm">Sign in</Button>`,
        o.cta && `    <Button size="sm">Book a demo</Button>`,
        o.cta && `  </div>`,
        `</nav>`,
      ),
    render: PlainNav,
  },
]

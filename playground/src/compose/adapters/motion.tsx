// Motion components: card effect, text effect, avatar group.
import { useState, type ComponentProps, type ReactNode } from "react"
import { ArrowRightIcon, RotateCcwIcon, SparklesIcon } from "lucide-react"
import { AvatarGroup, AvatarGroupTooltip } from "@/components/animate-ui/components/animate/avatar-group"
import { HighlightText } from "@/components/animate-ui/primitives/texts/highlight"
import { CardBody, CardContainer, CardItem } from "@/components/ui/3d-card"
import { Badge } from "@/components/ui/badge"
import { BlurFade } from "@/components/ui/blur-fade"
import { BorderBeam } from "@/components/ui/border-beam"
import { Button } from "@/components/ui/button"
import { Card, CardAction, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { TextAnimate } from "@/components/ui/text-animate"
import { TextGenerateEffect } from "@/components/ui/text-generate-effect"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"
import { cn } from "@/lib/utils"
import type { Adapter, BlockProps } from "../types"

/** Bumps a key so a one-shot entrance plays again. */
function useReplay() {
  const [run, setRun] = useState(0)
  return [run, () => setRun((r) => r + 1)] as const
}

/* ------------------------------------------------------------------------------------------------
 * Card effect: one sell-out card, three ways
 * ---------------------------------------------------------------------------------------------- */

const week = [42, 64, 51, 78, 69, 90, 84]

const accents = { sky: "bg-sky-500/80", emerald: "bg-emerald-500/80", violet: "bg-violet-500/80" } as const
type Accent = keyof typeof accents

function Bars({ className, accent = "sky" }: { className?: string; accent?: Accent }) {
  return (
    <div role="img" aria-label="Daily sell-out, last 7 days, rising towards the weekend" className={cn("flex items-end gap-1.5", className)}>
      {week.map((h, i) => (
        <div key={i} className={cn("flex-1 rounded-t-sm", accents[accent])} style={{ height: `${h}%` }} />
      ))}
    </div>
  )
}

const changeChip = "rounded-full bg-emerald-500/10 px-2 py-0.5 text-xs font-medium text-emerald-700 dark:text-emerald-400"

/** Beam colour pairs. "Theme" follows --foreground, so it flips with dark mode. */
const beamColours = {
  sunset: ["#ffaa40", "#9c40ff"],
  lagoon: ["#10b981", "#0ea5e9"],
  theme: ["var(--foreground)", "var(--muted-foreground)"],
} as const
type BeamColours = keyof typeof beamColours

function BeamCard({ options: o }: BlockProps) {
  const [from, to] = beamColours[o.colours as BeamColours]
  const lap = Number(o.lap)
  return (
    <div className="relative mx-auto w-full max-w-[26rem] overflow-hidden rounded-xl border bg-card p-5 text-card-foreground">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="flex items-center gap-1.5 text-sm font-medium">
            <SparklesIcon className="size-4" />
            Weekly sell-out is ready
          </div>
          <div className="mt-0.5 text-xs text-muted-foreground">Kopi Senja 3-in-1 · Klang Valley · last 7 days</div>
        </div>
        <span className={changeChip}>+18.4%</span>
      </div>
      <div className="mt-4 flex items-end justify-between gap-6">
        <div className="text-2xl font-semibold tabular-nums">RM 184,230</div>
        <Bars className="h-12 w-40" />
      </div>
      <div className="mt-4 flex gap-2">
        <Button size="sm">Read summary</Button>
        <Button size="sm" variant="ghost">
          Dismiss
        </Button>
      </div>
      <BorderBeam duration={lap} size={80} colorFrom={from} colorTo={to} />
      {o.twin && <BorderBeam duration={lap} size={80} colorFrom={from} colorTo={to} delay={lap / 2} />}
    </div>
  )
}

function TiltCard({ options: o }: BlockProps) {
  const d = Number(o.depth)
  const accent = o.accent as Accent
  return (
    <CardContainer containerClassName="py-4">
      <CardBody className="h-auto w-[26rem] max-w-full rounded-xl border bg-card p-5 text-card-foreground shadow-sm">
        <CardItem translateZ={40 * d} className="text-sm font-semibold">
          Sell-out · Klang Valley
        </CardItem>
        <CardItem translateZ={30 * d} as="p" className="mt-1 text-xs text-muted-foreground">
          Kopi Senja 3-in-1 · last 7 days
        </CardItem>
        <CardItem translateZ={80 * d} className="mt-4 h-16 w-full">
          <Bars className="h-full" accent={accent} />
        </CardItem>
        <div className="mt-4 flex items-center justify-between">
          <CardItem translateZ={50 * d} className="text-2xl font-semibold tabular-nums">
            RM 184,230
          </CardItem>
          <CardItem translateZ={60 * d} as="span" className={changeChip}>
            +18.4%
          </CardItem>
        </div>
        {o.cta && (
          <CardItem translateZ={100 * d} as={Button} size="sm" className="mt-4">
            View outlets
            <ArrowRightIcon data-icon="inline-end" />
          </CardItem>
        )}
      </CardBody>
    </CardContainer>
  )
}

function PlainCard({ options: o }: BlockProps) {
  return (
    <Card
      size={o.size as "default" | "sm"}
      className={cn(
        "mx-auto w-full max-w-[26rem]",
        o.lift && "transition-[translate,box-shadow] duration-200 hover:-translate-y-1 hover:shadow-lg motion-reduce:transition-none motion-reduce:hover:translate-y-0",
      )}
    >
      <CardHeader>
        <CardTitle>Sell-out · Klang Valley</CardTitle>
        <CardDescription>Kopi Senja 3-in-1 · last 7 days</CardDescription>
        <CardAction>
          <Badge variant="secondary">+18.4%</Badge>
        </CardAction>
      </CardHeader>
      <CardContent className="flex items-end justify-between gap-6">
        <div className="text-2xl font-semibold tabular-nums">RM 184,230</div>
        <Bars className="h-12 w-40" />
      </CardContent>
      {o.footer && (
        <CardFooter className="gap-2">
          <Button size="sm">Read summary</Button>
          <Button size="sm" variant="ghost">
            Dismiss
          </Button>
        </CardFooter>
      )}
    </Card>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Text effect: one headline, five ways
 * ---------------------------------------------------------------------------------------------- */

const eyebrow = "Sales summary · November"
const headline = "November sell-out grew 18% in Klang Valley, led by Kopi Senja"
const headlineLines = "November sell-out grew 18%\nin Klang Valley, led by Kopi Senja"
const subline = "Two outlets in Penang are below their reorder point."

function TextFrame({ onReplay, className, children }: { onReplay?: () => void; className?: string; children: ReactNode }) {
  return (
    <div className={cn("relative flex min-h-40 flex-col justify-center gap-2 rounded-lg border bg-card p-6", onReplay && "pr-28", className)}>
      <div className="text-xs font-medium text-muted-foreground">{eyebrow}</div>
      {children}
      {onReplay && (
        <Button variant="ghost" size="sm" className="absolute top-3 right-3" onClick={onReplay}>
          <RotateCcwIcon data-icon="inline-start" />
          Replay
        </Button>
      )}
    </div>
  )
}

type TextAnimation = NonNullable<ComponentProps<typeof TextAnimate>["animation"]>
type TextBy = "word" | "character" | "line"

function TextAnimateBlock({ options: o }: BlockProps) {
  const [run, replay] = useReplay()
  const by = o.by as TextBy
  return (
    <TextFrame onReplay={replay}>
      <TextAnimate
        key={`${run}-${o.animation}-${by}`}
        as="h2"
        animation={o.animation as TextAnimation}
        by={by}
        once
        className="text-3xl font-semibold tracking-tight"
      >
        {by === "line" ? headlineLines : headline}
      </TextAnimate>
    </TextFrame>
  )
}

type Direction = "up" | "down" | "left" | "right"

function BlurFadeBlock({ options: o }: BlockProps) {
  const [run, replay] = useReplay()
  const direction = o.direction as Direction
  const blur = o.blur as string
  return (
    <TextFrame onReplay={replay}>
      <div key={`${run}-${direction}-${blur}-${o.stagger}`} className="flex flex-col gap-2">
        <BlurFade direction={direction} blur={blur} offset={12}>
          <h2 className="text-3xl font-semibold tracking-tight text-balance">{headline}</h2>
        </BlurFade>
        <BlurFade direction={direction} blur={blur} offset={12} delay={o.stagger ? 0.15 : 0}>
          <p className="text-sm text-muted-foreground">{subline}</p>
        </BlurFade>
      </div>
    </TextFrame>
  )
}

function TextGenerateBlock({ options: o }: BlockProps) {
  const [run, replay] = useReplay()
  return (
    <TextFrame onReplay={replay}>
      <TextGenerateEffect key={`${run}-${o.filter}-${o.duration}`} words={headline} filter={o.filter as boolean} duration={Number(o.duration)} />
    </TextFrame>
  )
}

/** HighlightText animates background-size, so the colour is a gradient you pass in. */
const markers = {
  amber: "from-amber-200 to-amber-300 dark:from-amber-500/50 dark:to-amber-600/50",
  emerald: "from-emerald-200 to-teal-200 dark:from-emerald-600/50 dark:to-teal-600/50",
  violet: "from-indigo-200 to-violet-300 dark:from-indigo-500/60 dark:to-violet-500/60",
} as const
type Marker = keyof typeof markers

function HighlightBlock({ options: o }: BlockProps) {
  const [run, replay] = useReplay()
  const duration = Number(o.duration)
  const cls = cn("rounded-md bg-linear-to-r px-1", markers[o.marker as Marker])
  return (
    <TextFrame onReplay={replay}>
      <h2 key={`${run}-${duration}`} className="text-3xl leading-snug font-semibold tracking-tight">
        November sell-out grew <HighlightText text="18% in Klang Valley" transition={{ duration, ease: "easeInOut" }} className={cls} />, led by{" "}
        <HighlightText text="Kopi Senja" delay={duration * 1000} transition={{ duration, ease: "easeInOut" }} className={cls} />
      </h2>
    </TextFrame>
  )
}

const headingSizes = { sm: "text-2xl", md: "text-3xl", lg: "text-4xl" } as const
type HeadingSize = keyof typeof headingSizes

function PlainHeading({ options: o }: BlockProps) {
  return (
    <TextFrame className={cn(o.align === "center" && "items-center text-center")}>
      <h2 className={cn("max-w-2xl font-semibold tracking-tight text-balance", headingSizes[o.size as HeadingSize])}>{headline}</h2>
      {o.subline && <p className="text-sm text-muted-foreground">{subline}</p>}
    </TextFrame>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Avatar group
 * ---------------------------------------------------------------------------------------------- */

const team = [
  { initials: "AL", name: "Aisyah Latif", role: "Sales ops lead", color: "bg-sky-600" },
  { initials: "KW", name: "Kevin Wong", role: "Key accounts", color: "bg-emerald-600" },
  { initials: "PR", name: "Priya Raman", role: "Trade marketing", color: "bg-violet-600" },
  { initials: "HZ", name: "Hafiz Zulkifli", role: "Logistics", color: "bg-amber-600" },
  { initials: "ML", name: "Mei Ling Tan", role: "Finance", color: "bg-rose-600" },
  { initials: "NA", name: "Nur Aina Hashim", role: "Merchandising", color: "bg-teal-600" },
  { initials: "RK", name: "Rajesh Kumar", role: "Distributor sales", color: "bg-indigo-600" },
  { initials: "DT", name: "Daniel Teoh", role: "Demand planning", color: "bg-orange-600" },
]

const avatarSizes = {
  sm: { avatar: "size-8 text-[11px]", overlap: "-space-x-2", group: "h-10" },
  md: { avatar: "size-10 text-xs", overlap: "-space-x-3", group: "h-12" },
  lg: { avatar: "size-12 text-sm", overlap: "-space-x-3.5", group: "h-14" },
} as const
type AvatarSize = keyof typeof avatarSizes

function ProjectRow({ children }: { children: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-lg border bg-card px-4 pt-6 pb-4">
      <div className="min-w-0">
        <div className="text-sm font-medium">Hari Raya 2027 promo</div>
        <div className="text-xs text-muted-foreground">Launch plan · due 14 Jan · {team.length} people</div>
      </div>
      {children}
    </div>
  )
}

function AnimateAvatars({ options: o }: BlockProps) {
  const size = avatarSizes[o.size as AvatarSize]
  const shown = team.slice(0, Number(o.max))
  const rest = team.slice(shown.length)
  const bubble = cn("flex items-center justify-center rounded-full border-2 border-background font-semibold", size.avatar)
  // Each avatar's wrapper is already a tab stop (Motion adds tabIndex for whileTap), and focus opens the tooltip.
  const items = shown.map((p) => (
    <div key={p.initials} role="img" aria-label={`${p.name}, ${p.role}`} className={cn(bubble, p.color, "text-white")}>
      {p.initials}
      <AvatarGroupTooltip>
        <p className="font-medium">{p.name}</p>
        <p className="opacity-70">{p.role}</p>
      </AvatarGroupTooltip>
    </div>
  ))
  if (rest.length)
    items.push(
      <div key="more" role="img" aria-label={`${rest.length} more: ${rest.map((p) => p.name).join(", ")}`} className={cn(bubble, "bg-muted text-muted-foreground")}>
        +{rest.length}
        <AvatarGroupTooltip>{rest.map((p) => p.name).join(", ")}</AvatarGroupTooltip>
      </div>,
    )
  return (
    <ProjectRow>
      <AvatarGroup translate={o.lift as string} invertOverlap={o.invert as boolean} className={cn(size.group, size.overlap)}>
        {items}
      </AvatarGroup>
    </ProjectRow>
  )
}

/**
 * The lab doesn't have shadcn's Avatar installed, so this is the markup AvatarFallback renders
 * (a rounded-full, bg-muted circle), with Base UI tooltips from the installed shadcn Tooltip.
 */
function PlainAvatars({ options: o }: BlockProps) {
  const size = avatarSizes[o.size as AvatarSize]
  const shown = team.slice(0, Number(o.max))
  const rest = team.slice(shown.length)
  const circle = cn("relative flex shrink-0 items-center justify-center rounded-full font-medium ring-2 ring-background", size.avatar)
  return (
    <ProjectRow>
      <TooltipProvider>
        <div className={cn("flex", size.overlap)}>
          {shown.map((p) => (
            <Tooltip key={p.initials}>
              <TooltipTrigger aria-label={p.name} className={cn(circle, o.colour ? cn(p.color, "text-white") : "bg-muted text-muted-foreground")}>
                {p.initials}
              </TooltipTrigger>
              <TooltipContent>
                {p.name} · {p.role}
              </TooltipContent>
            </Tooltip>
          ))}
          {rest.length > 0 && (
            <Tooltip>
              <TooltipTrigger aria-label={`${rest.length} more`} className={cn(circle, "bg-muted text-muted-foreground")}>
                +{rest.length}
              </TooltipTrigger>
              <TooltipContent>{rest.map((p) => p.name).join(", ")}</TooltipContent>
            </Tooltip>
          )}
        </div>
      </TooltipProvider>
    </ProjectRow>
  )
}

const sizeOption = {
  id: "size",
  label: "Size",
  type: "select" as const,
  default: "md",
  choices: [
    { value: "sm", label: "Small" },
    { value: "md", label: "Medium" },
    { value: "lg", label: "Large" },
  ],
}
const maxOption = {
  id: "max",
  label: "Shown before +N",
  type: "select" as const,
  default: "5",
  choices: [
    { value: "3", label: "3" },
    { value: "5", label: "5" },
    { value: "8", label: "All 8" },
  ],
}

/* ------------------------------------------------------------------------------------------------
 * Adapters
 * ---------------------------------------------------------------------------------------------- */

export const adapters: Adapter[] = [
  /* ------------------------------------------------------------------------------------ card */
  {
    id: "card-magicui",
    slot: "card",
    library: "magicui",
    label: "BorderBeam",
    note: "A light runs round the border to flag one new thing; it never stops",
    options: [
      {
        id: "colours",
        label: "Beam",
        type: "select",
        default: "sunset",
        choices: [
          { value: "sunset", label: "Sunset (default)" },
          { value: "lagoon", label: "Lagoon" },
          { value: "theme", label: "Theme foreground" },
        ],
      },
      {
        id: "lap",
        label: "One lap",
        type: "select",
        default: "6",
        choices: [
          { value: "3", label: "3 s" },
          { value: "6", label: "6 s" },
          { value: "12", label: "12 s" },
        ],
      },
      { id: "twin", label: "Two beams", type: "switch", default: false },
    ],
    traits: { ignoresReducedMotion: true },
    install: ["npx shadcn@latest add @magicui/border-beam"],
    code: (o) => {
      const [from, to] = beamColours[o.colours as BeamColours]
      const colours = o.colours === "sunset" ? "" : ` colorFrom="${from}" colorTo="${to}"`
      return `import { BorderBeam } from "@/components/ui/border-beam"

// Loops forever: Motion animates offset-distance, which its reducedMotion setting doesn't stop.
// Gate it with useReducedMotion() if it ships in an app.
<div className="relative overflow-hidden rounded-xl border bg-card p-5">
  …card content…
  <BorderBeam duration={${o.lap}} size={80}${colours} />${o.twin ? `\n  <BorderBeam duration={${o.lap}} size={80}${colours} delay={${Number(o.lap) / 2}} />` : ""}
</div>`
    },
    render: BeamCard,
  },
  {
    id: "card-aceternity",
    slot: "card",
    library: "aceternity",
    label: "3D card",
    note: "Tilts toward the mouse and lifts layers on translateZ; idle until hovered",
    options: [
      {
        id: "depth",
        label: "Depth",
        type: "select",
        default: "1",
        choices: [
          { value: "0.5", label: "Subtle" },
          { value: "1", label: "Normal" },
          { value: "2", label: "Deep" },
        ],
      },
      {
        id: "accent",
        label: "Bars",
        type: "select",
        default: "sky",
        choices: [
          { value: "sky", label: "Sky" },
          { value: "emerald", label: "Emerald" },
          { value: "violet", label: "Violet" },
        ],
      },
      { id: "cta", label: "Floating button", type: "switch", default: false },
    ],
    traits: { needsMotion: false, effect: false, darkMode: "ok" },
    install: ["npx shadcn@latest add @aceternity/3d-card"],
    code: (o) => {
      const d = Number(o.depth)
      return `import { CardBody, CardContainer, CardItem } from "@/components/ui/3d-card"${o.cta ? `\nimport { Button } from "@/components/ui/button"` : ""}

// Mouse only: no touch or keyboard tilt. Colours are yours, so theme tokens work.
<CardContainer containerClassName="py-4">
  <CardBody className="h-auto w-[26rem] rounded-xl border bg-card p-5">
    <CardItem translateZ={${40 * d}} className="text-sm font-semibold">Sell-out · Klang Valley</CardItem>
    <CardItem translateZ={${30 * d}} as="p" className="mt-1 text-xs text-muted-foreground">Kopi Senja 3-in-1 · last 7 days</CardItem>
    <CardItem translateZ={${80 * d}} className="mt-4 h-16 w-full">
      <SellOutBars className="${accents[o.accent as Accent]}" />
    </CardItem>
    <CardItem translateZ={${50 * d}} className="mt-4 text-2xl font-semibold">RM 184,230</CardItem>${
      o.cta ? `\n    <CardItem translateZ={${100 * d}} as={Button} size="sm" className="mt-4">View outlets</CardItem>` : ""
    }
  </CardBody>
</CardContainer>`
    },
    render: TiltCard,
  },
  {
    id: "card-shadcn",
    slot: "card",
    library: "shadcn",
    label: "Card",
    note: "shadcn Card parts with a CSS hover lift that respects reduced motion",
    options: [
      {
        id: "size",
        label: "Size",
        type: "select",
        default: "default",
        choices: [
          { value: "default", label: "Default" },
          { value: "sm", label: "Small" },
        ],
      },
      { id: "footer", label: "Footer actions", type: "switch", default: true },
      { id: "lift", label: "Lift on hover", type: "switch", default: true },
    ],
    install: ["npx shadcn@latest add card badge button"],
    code: (o) => `import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardAction, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"

<Card${o.size === "sm" ? ` size="sm"` : ""}${
      o.lift ? `\n  className="transition-[translate,box-shadow] hover:-translate-y-1 hover:shadow-lg motion-reduce:transition-none motion-reduce:hover:translate-y-0"\n` : ""
    }>
  <CardHeader>
    <CardTitle>Sell-out · Klang Valley</CardTitle>
    <CardDescription>Kopi Senja 3-in-1 · last 7 days</CardDescription>
    <CardAction>
      <Badge variant="secondary">+18.4%</Badge>
    </CardAction>
  </CardHeader>
  <CardContent className="text-2xl font-semibold tabular-nums">RM 184,230</CardContent>${
    o.footer
      ? `
  <CardFooter className="gap-2">
    <Button size="sm">Read summary</Button>
    <Button size="sm" variant="ghost">Dismiss</Button>
  </CardFooter>`
      : ""
  }
</Card>`,
    render: PlainCard,
  },

  /* ------------------------------------------------------------------------------------ text */
  {
    id: "text-magicui",
    slot: "text",
    library: "magicui",
    label: "TextAnimate",
    note: "Word, letter or line entrances, with an sr-only copy for screen readers",
    options: [
      {
        id: "animation",
        label: "Animation",
        type: "select",
        default: "blurInUp",
        choices: [
          { value: "blurInUp", label: "Blur in, up" },
          { value: "fadeIn", label: "Fade in" },
          { value: "slideUp", label: "Slide up" },
          { value: "scaleUp", label: "Scale up" },
        ],
      },
      {
        id: "by",
        label: "Split by",
        type: "select",
        default: "word",
        choices: [
          { value: "word", label: "Word" },
          { value: "character", label: "Character" },
          { value: "line", label: "Line" },
        ],
      },
    ],
    traits: { pageKind: "marketing" },
    install: ["npx shadcn@latest add @magicui/text-animate"],
    code: (o) => `import { TextAnimate } from "@/components/ui/text-animate"

${o.by === "line" ? `// by="line" splits on \\n; in word mode a \\n is swallowed.\n` : ""}<TextAnimate as="h2" animation="${o.animation}" by="${o.by}" once className="text-3xl font-semibold tracking-tight">
  ${o.by === "line" ? `{"November sell-out grew 18%\\nin Klang Valley, led by Kopi Senja"}` : headline}
</TextAnimate>`,
    render: TextAnimateBlock,
  },
  {
    id: "text-magicui-blur-fade",
    slot: "text",
    library: "magicui",
    label: "BlurFade",
    note: "Blur, offset and fade on entry: the Magic UI text piece approved for apps",
    options: [
      {
        id: "direction",
        label: "From",
        type: "select",
        default: "up",
        choices: [
          { value: "up", label: "Below" },
          { value: "down", label: "Above" },
          { value: "left", label: "Right" },
          { value: "right", label: "Left" },
        ],
      },
      {
        id: "blur",
        label: "Blur",
        type: "select",
        default: "6px",
        choices: [
          { value: "0px", label: "None" },
          { value: "6px", label: "6 px" },
          { value: "16px", label: "16 px" },
        ],
      },
      { id: "stagger", label: "Stagger the second line", type: "switch", default: true },
    ],
    install: ["npx shadcn@latest add @magicui/blur-fade"],
    code: (o) => {
      const props = `direction="${o.direction}"${o.blur === "6px" ? "" : ` blur="${o.blur}"`} offset={12}`
      return `import { BlurFade } from "@/components/ui/blur-fade"

<BlurFade ${props}>
  <h2 className="text-3xl font-semibold tracking-tight">${headline}</h2>
</BlurFade>
<BlurFade ${props}${o.stagger ? " delay={0.15}" : ""}>
  <p className="text-sm text-muted-foreground">${subline}</p>
</BlurFade>`
    },
    render: BlurFadeBlock,
  },
  {
    id: "text-aceternity",
    slot: "text",
    library: "aceternity",
    label: "Text generate",
    note: "Words fade in from blur one by one; forces text-2xl and black or white text",
    options: [
      { id: "filter", label: "Blur", type: "switch", default: true },
      {
        id: "duration",
        label: "Per word",
        type: "select",
        default: "0.5",
        choices: [
          { value: "0.25", label: "0.25 s" },
          { value: "0.5", label: "0.5 s" },
          { value: "1", label: "1 s" },
        ],
      },
    ],
    traits: { effect: false, darkMode: "ok" },
    install: ["npx shadcn@latest add @aceternity/text-generate-effect"],
    code: (o) => `import { TextGenerateEffect } from "@/components/ui/text-generate-effect"

// Plays once on mount; remount (change its key) to replay. Size and colour are fixed inside it.
<TextGenerateEffect
  words="${headline}"${o.filter ? "" : "\n  filter={false}"}${o.duration === "0.5" ? "" : `\n  duration={${o.duration}}`}
/>`,
    render: TextGenerateBlock,
  },
  {
    id: "text-animate-ui",
    slot: "text",
    library: "animate-ui",
    label: "HighlightText",
    note: "A marker sweeps behind a phrase; colour comes from your gradient classes",
    options: [
      {
        id: "marker",
        label: "Marker",
        type: "select",
        default: "amber",
        choices: [
          { value: "amber", label: "Amber" },
          { value: "emerald", label: "Emerald" },
          { value: "violet", label: "Violet" },
        ],
      },
      {
        id: "duration",
        label: "Sweep",
        type: "select",
        default: "1.2",
        choices: [
          { value: "0.6", label: "0.6 s" },
          { value: "1.2", label: "1.2 s" },
          { value: "2", label: "2 s (default)" },
        ],
      },
    ],
    traits: { ignoresReducedMotion: true },
    install: ["npx shadcn@latest add @animate-ui/primitives-texts-highlight"],
    code: (o) => `import { HighlightText } from "@/components/animate-ui/primitives/texts/highlight"

// It animates background-size, so give it a gradient with a dark-mode step.
const marker = "rounded-md bg-linear-to-r px-1 ${markers[o.marker as Marker]}"

<h2 className="text-3xl font-semibold tracking-tight">
  November sell-out grew{" "}
  <HighlightText text="18% in Klang Valley" transition={{ duration: ${o.duration}, ease: "easeInOut" }} className={marker} />
  , led by <HighlightText text="Kopi Senja" delay={${Number(o.duration) * 1000}} transition={{ duration: ${o.duration}, ease: "easeInOut" }} className={marker} />
</h2>`,
    render: HighlightBlock,
  },
  {
    id: "text-shadcn",
    slot: "text",
    library: "shadcn",
    label: "Heading",
    note: "A plain heading on theme tokens: no entrance at all",
    options: [
      {
        id: "size",
        label: "Size",
        type: "select",
        default: "md",
        choices: [
          { value: "sm", label: "text-2xl" },
          { value: "md", label: "text-3xl" },
          { value: "lg", label: "text-4xl" },
        ],
      },
      {
        id: "align",
        label: "Align",
        type: "select",
        default: "left",
        choices: [
          { value: "left", label: "Left" },
          { value: "center", label: "Centre" },
        ],
      },
      { id: "subline", label: "Supporting line", type: "switch", default: true },
    ],
    install: [],
    code: (o) => `<div className="flex flex-col gap-2${o.align === "center" ? " items-center text-center" : ""}">
  <p className="text-xs font-medium text-muted-foreground">${eyebrow}</p>
  <h2 className="${headingSizes[o.size as HeadingSize]} font-semibold tracking-tight text-balance">
    ${headline}
  </h2>${o.subline ? `\n  <p className="text-sm text-muted-foreground">${subline}</p>` : ""}
</div>`,
    render: PlainHeading,
  },

  /* --------------------------------------------------------------------------------- avatars */
  {
    id: "avatars-animate-ui",
    slot: "avatars",
    library: "animate-ui",
    label: "AvatarGroup",
    note: "Avatars lift on hover and one shared tooltip glides between them",
    options: [
      sizeOption,
      maxOption,
      {
        id: "lift",
        label: "Lift on hover",
        type: "select",
        default: "-30%",
        choices: [
          { value: "-15%", label: "15%" },
          { value: "-30%", label: "30%" },
          { value: "-50%", label: "50%" },
        ],
      },
      { id: "invert", label: "First avatar on top", type: "switch", default: true },
    ],
    install: ["npx shadcn@latest add @animate-ui/components-animate-avatar-group"],
    code: (o) => {
      const size = avatarSizes[o.size as AvatarSize]
      return `import { AvatarGroup, AvatarGroupTooltip } from "@/components/animate-ui/components/animate/avatar-group"
import { cn } from "@/lib/utils"

// Children are plain elements: initials here. Each wrapper is a tab stop, and focus opens the tooltip.
<AvatarGroup${o.lift === "-30%" ? "" : ` translate="${o.lift}"`}${o.invert ? "" : " invertOverlap={false}"} className="${size.group} ${size.overlap}">
  {team.slice(0, ${o.max}).map((p) => (
    <div key={p.id} role="img" aria-label={p.name} className={cn("flex ${size.avatar.split(" ")[0]} items-center justify-center rounded-full border-2 border-background font-semibold text-white", p.color)}>
      {p.initials}
      <AvatarGroupTooltip>
        <p className="font-medium">{p.name}</p>
        <p className="opacity-70">{p.role}</p>
      </AvatarGroupTooltip>
    </div>
  ))}
</AvatarGroup>`
    },
    render: AnimateAvatars,
  },
  {
    id: "avatars-shadcn",
    slot: "avatars",
    library: "shadcn",
    label: "Avatar stack",
    note: "Overlapping initials with a ring cut-out and a Base UI tooltip each",
    options: [sizeOption, maxOption, { id: "colour", label: "Coloured initials", type: "switch", default: true }],
    install: ["npx shadcn@latest add avatar tooltip"],
    code: (o) => {
      const size = avatarSizes[o.size as AvatarSize]
      return `import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"

<TooltipProvider>
  <div className="flex ${size.overlap}">
    {team.slice(0, ${o.max}).map((p) => (
      <Tooltip key={p.id}>
        <TooltipTrigger render={<Avatar className="${size.avatar.split(" ")[0]} ring-2 ring-background" />}>
          <AvatarFallback${o.colour ? ` className={\`\${p.color} text-white\`}` : ""}>{p.initials}</AvatarFallback>
        </TooltipTrigger>
        <TooltipContent>{p.name} · {p.role}</TooltipContent>
      </Tooltip>
    ))}
  </div>
</TooltipProvider>`
    },
    render: PlainAvatars,
  },
]

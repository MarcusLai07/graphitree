import { useEffect, useState, type CSSProperties, type ReactNode } from "react"
import {
  BanknoteIcon,
  BarChart3Icon,
  BoxesIcon,
  CheckIcon,
  CoffeeIcon,
  CookieIcon,
  DropletsIcon,
  HomeIcon,
  LeafIcon,
  PackageIcon,
  PauseIcon,
  PlayIcon,
  RotateCcwIcon,
  SearchIcon,
  SettingsIcon,
  ShoppingCartIcon,
  SparklesIcon,
  StoreIcon,
  TrendingUpIcon,
  TruckIcon,
  Undo2Icon,
  UsersIcon,
  WavesIcon,
  type LucideIcon,
} from "lucide-react"
import { MotionConfig } from "motion/react"
import { AvatarGroup, AvatarGroupTooltip } from "@/components/animate-ui/components/animate/avatar-group"
import { RippleButton, RippleButtonRipples } from "@/components/animate-ui/components/buttons/ripple"
import { HighlightText } from "@/components/animate-ui/primitives/texts/highlight"
import { AnimatedGradientText } from "@/components/ui/animated-gradient-text"
import { AnimatedList } from "@/components/ui/animated-list"
import { BlurFade } from "@/components/ui/blur-fade"
import { BorderBeam } from "@/components/ui/border-beam"
import { Button } from "@/components/ui/button"
import { Dock, DockIcon } from "@/components/ui/dock"
import { Marquee } from "@/components/ui/marquee"
import { Ripple } from "@/components/ui/ripple"
import { ShimmerButton } from "@/components/ui/shimmer-button"
import { Slider } from "@/components/ui/slider"
import { Switch } from "@/components/ui/switch"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { TextAnimate } from "@/components/ui/text-animate"
import { cn } from "@/lib/utils"
import { Findings, Page, Section, Variant } from "@/playground/kit"

/* ------------------------------------------------------------- controls */

function Controls({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn("flex w-full flex-wrap items-center justify-center gap-x-4 gap-y-2 text-sm", className)}>{children}</div>
}

function SliderControl({
  label,
  value,
  onChange,
  min,
  max,
  step = 1,
  unit = "",
}: {
  label: string
  value: number
  onChange: (n: number) => void
  min: number
  max: number
  step?: number
  unit?: string
}) {
  return (
    <div className="flex min-w-48 flex-1 items-center gap-3">
      <span className="w-28 shrink-0 text-xs text-muted-foreground">
        {label} {value}
        {unit}
      </span>
      <Slider className="flex-1" min={min} max={max} step={step} value={[value]} onValueChange={(x) => onChange(typeof x === "number" ? x : x[0])} />
    </div>
  )
}

function SwitchControl({ label, checked, onChange }: { label: ReactNode; checked: boolean; onChange: (b: boolean) => void }) {
  return (
    <label className="flex items-center gap-2 text-xs">
      <Switch size="sm" checked={checked} onCheckedChange={onChange} />
      {label}
    </label>
  )
}

function Segmented<T extends string>({ value, onChange, options }: { value: T; onChange: (v: T) => void; options: readonly T[] }) {
  return (
    <Tabs value={value} onValueChange={(x) => onChange(x as T)}>
      <TabsList>
        {options.map((o) => (
          <TabsTrigger key={o} value={o} className="text-xs">
            {o}
          </TabsTrigger>
        ))}
      </TabsList>
    </Tabs>
  )
}

function ReplayButton({ onClick }: { onClick: () => void }) {
  return (
    <Button variant="outline" size="sm" onClick={onClick}>
      <RotateCcwIcon data-icon="inline-start" />
      Replay
    </Button>
  )
}

/** A colour pair for the gradient/beam controls. */
const swatches = {
  Sunset: ["#ffaa40", "#9c40ff"],
  Lagoon: ["#10b981", "#0ea5e9"],
  Rose: ["#f43f5e", "#f59e0b"],
  Mono: ["#a1a1aa", "#52525b"],
} as const
type Swatch = keyof typeof swatches

function SwatchPicker({ value, onChange }: { value: Swatch; onChange: (s: Swatch) => void }) {
  return (
    <div className="flex items-center gap-1.5">
      {(Object.keys(swatches) as Swatch[]).map((k) => (
        <button
          key={k}
          type="button"
          aria-label={k}
          title={k}
          onClick={() => onChange(k)}
          className={cn("size-5 rounded-full ring-offset-2 ring-offset-card", value === k && "ring-2 ring-ring")}
          style={{ background: `linear-gradient(135deg, ${swatches[k][0]}, ${swatches[k][1]})` }}
        />
      ))}
    </div>
  )
}

/* ------------------------------------------------- 1. feeds, lists, people */

type FeedKind = "order" | "payment" | "stock" | "spike" | "return"
type FeedItem = { id: number; kind: FeedKind; title: string; body: string; at: string }

const feedKinds: Record<FeedKind, { icon: LucideIcon; tint: string }> = {
  order: { icon: ShoppingCartIcon, tint: "bg-sky-500/15 text-sky-600 dark:text-sky-400" },
  payment: { icon: BanknoteIcon, tint: "bg-emerald-500/15 text-emerald-600 dark:text-emerald-400" },
  stock: { icon: PackageIcon, tint: "bg-amber-500/15 text-amber-600 dark:text-amber-400" },
  spike: { icon: TrendingUpIcon, tint: "bg-violet-500/15 text-violet-600 dark:text-violet-400" },
  return: { icon: Undo2Icon, tint: "bg-rose-500/15 text-rose-600 dark:text-rose-400" },
}

const feedTemplates: Omit<FeedItem, "id" | "at">[] = [
  { kind: "order", title: "New order · RM 4,280", body: "Hypermart Mutiara Damansara · 112 cartons" },
  { kind: "payment", title: "Payment received · RM 12,940", body: "Kedai Borong Subang · invoice INV-30418" },
  { kind: "stock", title: "Low stock at KL DC", body: "Kopi Senja 3-in-1 · 120 cartons left" },
  { kind: "spike", title: "Order spike on e-commerce", body: "+38 orders in the last 10 minutes" },
  { kind: "order", title: "New order · RM 1,115", body: "Kedai Runcit Ah Seng, Ipoh · 29 cartons" },
  { kind: "return", title: "Return requested", body: "Pasar Raya Kota Kinabalu · 6 cartons damaged" },
  { kind: "payment", title: "Payment received · RM 3,602", body: "MiniMart Klang · invoice INV-30422" },
]

let feedSeq = 0
function makeFeedItem(): FeedItem {
  const t = feedTemplates[feedSeq % feedTemplates.length]
  feedSeq += 1
  return { ...t, id: feedSeq, at: new Date().toLocaleTimeString("en-MY", { hour: "numeric", minute: "2-digit", second: "2-digit" }) }
}

function FeedRow({ item }: { item: FeedItem }) {
  const { icon: Icon, tint } = feedKinds[item.kind]
  return (
    <div className="flex w-full items-center gap-3 rounded-xl border bg-background p-3 shadow-sm">
      <span className={cn("flex size-9 shrink-0 items-center justify-center rounded-lg", tint)}>
        <Icon className="size-4" />
      </span>
      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-medium">{item.title}</div>
        <div className="truncate text-xs text-muted-foreground">{item.body}</div>
      </div>
      <span className="shrink-0 text-[11px] text-muted-foreground tabular-nums">{item.at}</span>
    </div>
  )
}

function NotificationFeed() {
  const [items, setItems] = useState<FeedItem[]>(() => [makeFeedItem(), makeFeedItem()])
  const [running, setRunning] = useState(true)
  const [every, setEvery] = useState(1800)
  useEffect(() => {
    if (!running) return
    const id = setInterval(() => setItems((xs) => [...xs, makeFeedItem()].slice(-5)), every)
    return () => clearInterval(id)
  }, [running, every])
  return (
    <div className="flex w-full flex-col gap-3">
      <div className="relative h-80 overflow-hidden">
        <AnimatedList delay={every} className="gap-2">
          {items.map((item) => (
            <FeedRow key={item.id} item={item} />
          ))}
        </AnimatedList>
        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-20 bg-linear-to-t from-card" />
      </div>
      <Controls>
        <Button variant="ghost" size="icon-sm" onClick={() => setRunning((r) => !r)} aria-label={running ? "Pause feed" : "Resume feed"}>
          {running ? <PauseIcon /> : <PlayIcon />}
        </Button>
        <SliderControl label="New item every" value={every} onChange={setEvery} min={500} max={4000} step={100} unit=" ms" />
      </Controls>
    </div>
  )
}

const settingsCards = [
  { icon: StoreIcon, title: "Outlets", body: "1,284 active across 4 regions" },
  { icon: TruckIcon, title: "Delivery routes", body: "38 routes, next run 6:00 am" },
  { icon: BoxesIcon, title: "Price lists", body: "Modern trade, general trade, e-commerce" },
  { icon: UsersIcon, title: "Sales reps", body: "56 reps, 3 pending invites" },
]
const directions = ["up", "down", "left", "right"] as const

function BlurFadeList() {
  const [run, setRun] = useState(0)
  const [direction, setDirection] = useState<(typeof directions)[number]>("up")
  const [stagger, setStagger] = useState(80)
  return (
    <div className="flex w-full flex-col gap-3">
      <div key={run} className="grid gap-2">
        {settingsCards.map((c, i) => (
          <BlurFade key={c.title} delay={(i * stagger) / 1000} direction={direction} offset={10}>
            <div className="flex items-center gap-3 rounded-lg border bg-background p-3">
              <c.icon className="size-4 text-muted-foreground" />
              <div className="flex-1">
                <div className="text-sm font-medium">{c.title}</div>
                <div className="text-xs text-muted-foreground">{c.body}</div>
              </div>
            </div>
          </BlurFade>
        ))}
      </div>
      <Controls>
        <Segmented value={direction} onChange={setDirection} options={directions} />
        <SliderControl label="Stagger" value={stagger} onChange={setStagger} min={0} max={300} step={10} unit=" ms" />
        <ReplayButton onClick={() => setRun((r) => r + 1)} />
      </Controls>
    </div>
  )
}

const team = [
  { initials: "AL", name: "Aisyah Latif", role: "Sales ops lead", color: "bg-sky-600" },
  { initials: "KW", name: "Kevin Wong", role: "Key accounts", color: "bg-emerald-600" },
  { initials: "PR", name: "Priya Raman", role: "Trade marketing", color: "bg-violet-600" },
  { initials: "HZ", name: "Hafiz Zulkifli", role: "Logistics", color: "bg-amber-600" },
  { initials: "ML", name: "Mei Ling Tan", role: "Finance", color: "bg-rose-600" },
]

function TeamAvatars() {
  const [lift, setLift] = useState<"-15%" | "-30%" | "-50%">("-30%")
  const [invert, setInvert] = useState(true)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="flex items-center justify-between gap-4 rounded-xl border bg-background p-4">
        <div>
          <div className="text-sm font-medium">Hari Raya 2027 promo</div>
          <div className="text-xs text-muted-foreground">Launch plan · due 14 Jan</div>
        </div>
        <div className="flex items-center gap-2">
          <AvatarGroup translate={lift} invertOverlap={invert} className="h-10 -space-x-2.5">
            {team.map((p) => (
              <div
                key={p.initials}
                className={cn("flex size-9 items-center justify-center rounded-full border-2 border-background text-xs font-semibold text-white", p.color)}
              >
                {p.initials}
                <AvatarGroupTooltip>
                  <p className="font-medium">{p.name}</p>
                  <p className="opacity-70">{p.role}</p>
                </AvatarGroupTooltip>
              </div>
            ))}
          </AvatarGroup>
          <span className="text-xs text-muted-foreground">+3</span>
        </div>
      </div>
      <Controls>
        <Segmented value={lift} onChange={setLift} options={["-15%", "-30%", "-50%"] as const} />
        <SwitchControl label="invertOverlap" checked={invert} onChange={setInvert} />
      </Controls>
    </div>
  )
}

/* ------------------------------------------------- 2. buttons and accents */

const rippleVariants = ["default", "secondary", "outline", "destructive"] as const

function RippleButtons() {
  const [hoverScale, setHoverScale] = useState(true)
  const [approved, setApproved] = useState(0)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="flex flex-wrap items-center justify-center gap-2">
        {rippleVariants.map((v) => (
          <RippleButton
            key={v}
            variant={v}
            hoverScale={hoverScale ? 1.05 : 1}
            tapScale={hoverScale ? 0.95 : 1}
            onClick={() => v === "default" && setApproved((n) => n + 1)}
          >
            {v === "default" ? "Approve order" : v === "destructive" ? "Reject" : v === "outline" ? "Hold" : "Edit"}
            <RippleButtonRipples />
          </RippleButton>
        ))}
      </div>
      <div className="flex flex-wrap items-center justify-center gap-2 border-t pt-4">
        <span className="w-full text-center text-xs text-muted-foreground">Our shadcn Button, for comparison</span>
        <Button>Approve order</Button>
        <Button variant="secondary">Edit</Button>
        <Button variant="outline">Hold</Button>
        <Button variant="destructive">Reject</Button>
      </div>
      <Controls>
        <SwitchControl label="Scale on hover/tap" checked={hoverScale} onChange={setHoverScale} />
        <span className="text-xs text-muted-foreground">Approved {approved}×</span>
      </Controls>
    </div>
  )
}

const shimmerBackgrounds = {
  Black: "rgba(0,0,0,1)",
  Indigo: "linear-gradient(135deg,#4f46e5,#7c3aed)",
  Emerald: "linear-gradient(135deg,#047857,#0d9488)",
  "Theme primary": "var(--primary)",
} as const

function ShimmerButtons() {
  const [bg, setBg] = useState<keyof typeof shimmerBackgrounds>("Black")
  const [speed, setSpeed] = useState(3)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="grid w-full gap-3 sm:grid-cols-2">
        <div className="flex flex-col gap-2 rounded-xl border bg-background p-4">
          <div className="text-xs font-medium text-muted-foreground">In-app: sidebar upsell</div>
          <div className="text-sm">You've used 4 of 5 warehouses.</div>
          <ShimmerButton
            className="h-8 px-3 text-sm"
            borderRadius="8px"
            background={shimmerBackgrounds[bg]}
            shimmerDuration={`${speed}s`}
          >
            <SparklesIcon className="mr-1.5 size-3.5" />
            Upgrade to Growth
          </ShimmerButton>
        </div>
        <div className="flex flex-col items-center justify-center gap-2 rounded-xl border bg-background p-4">
          <div className="text-xs font-medium text-muted-foreground">Marketing: hero CTA</div>
          <ShimmerButton background={shimmerBackgrounds[bg]} shimmerDuration={`${speed}s`} className="text-base font-medium">
            Start free trial
          </ShimmerButton>
        </div>
      </div>
      <Controls>
        <Segmented value={bg} onChange={setBg} options={Object.keys(shimmerBackgrounds) as (keyof typeof shimmerBackgrounds)[]} />
        <SliderControl label="Shimmer" value={speed} onChange={setSpeed} min={1} max={8} step={0.5} unit=" s" />
      </Controls>
    </div>
  )
}

function BorderBeamCard() {
  const [duration, setDuration] = useState(6)
  const [size, setSize] = useState(80)
  const [swatch, setSwatch] = useState<Swatch>("Sunset")
  const [reverse, setReverse] = useState(false)
  const [twin, setTwin] = useState(false)
  const [from, to] = swatches[swatch]
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="relative overflow-hidden rounded-xl border bg-background p-5">
        <div className="flex items-center gap-2 text-sm font-medium">
          <SparklesIcon className="size-4" />
          Weekly summary is ready
        </div>
        <p className="mt-2 text-sm text-muted-foreground">
          Sell-out grew 18% in Klang Valley, led by Kopi Senja. Two outlets in Penang are below reorder point.
        </p>
        <div className="mt-3 flex gap-2">
          <Button size="sm">Read summary</Button>
          <Button size="sm" variant="ghost">
            Dismiss
          </Button>
        </div>
        <BorderBeam duration={duration} size={size} colorFrom={from} colorTo={to} reverse={reverse} />
        {twin && <BorderBeam duration={duration} size={size} colorFrom={from} colorTo={to} reverse={reverse} delay={duration / 2} />}
      </div>
      <Controls>
        <SwatchPicker value={swatch} onChange={setSwatch} />
        <SwitchControl label="reverse" checked={reverse} onChange={setReverse} />
        <SwitchControl label="Two beams" checked={twin} onChange={setTwin} />
      </Controls>
      <Controls>
        <SliderControl label="Lap" value={duration} onChange={setDuration} min={2} max={16} unit=" s" />
        <SliderControl label="Size" value={size} onChange={setSize} min={20} max={200} step={10} unit=" px" />
      </Controls>
    </div>
  )
}

const highlightColors = {
  Amber: "from-amber-200 to-amber-300 dark:from-amber-500/50 dark:to-amber-600/50",
  Emerald: "from-emerald-200 to-teal-200 dark:from-emerald-600/50 dark:to-teal-600/50",
  Violet: "from-indigo-200 to-violet-300 dark:from-indigo-500/60 dark:to-violet-500/60",
} as const

function HighlightSentence() {
  const [run, setRun] = useState(0)
  const [color, setColor] = useState<keyof typeof highlightColors>("Amber")
  const [duration, setDuration] = useState(1.2)
  return (
    <div className="flex w-full flex-col gap-4">
      <div key={run} className="rounded-xl border bg-background p-5 text-lg leading-relaxed">
        November sell-out grew{" "}
        <HighlightText
          text="18% in Klang Valley"
          transition={{ duration, ease: "easeInOut" }}
          className={cn("rounded-md bg-linear-to-r px-1 font-semibold", highlightColors[color])}
        />
        , driven by{" "}
        <HighlightText
          text="Kopi Senja 3-in-1"
          delay={duration * 1000}
          transition={{ duration, ease: "easeInOut" }}
          className={cn("rounded-md bg-linear-to-r px-1 font-semibold", highlightColors[color])}
        />
        .
      </div>
      <Controls>
        <Segmented value={color} onChange={setColor} options={Object.keys(highlightColors) as (keyof typeof highlightColors)[]} />
        <SliderControl label="Duration" value={duration} onChange={setDuration} min={0.3} max={3} step={0.1} unit=" s" />
        <ReplayButton onClick={() => setRun((r) => r + 1)} />
      </Controls>
    </div>
  )
}

/* ------------------------------------------------------------ 3. marketing */

const brands: { name: string; icon: LucideIcon; className: string }[] = [
  { name: "Kopi Senja", icon: CoffeeIcon, className: "font-serif italic" },
  { name: "TEH PUTERI", icon: LeafIcon, className: "tracking-[0.2em] text-sm font-semibold" },
  { name: "suria snacks", icon: CookieIcon, className: "lowercase font-bold" },
  { name: "Ombak", icon: WavesIcon, className: "font-black tracking-tight" },
  { name: "Kasih Baby", icon: DropletsIcon, className: "font-medium" },
  { name: "DAPUR MAK", icon: StoreIcon, className: "font-mono font-semibold" },
  { name: "Nanas & Co.", icon: SparklesIcon, className: "font-serif" },
]

function LogoMarquee() {
  const [duration, setDuration] = useState(30)
  const [reverse, setReverse] = useState(false)
  const [pause, setPause] = useState(true)
  const [fade, setFade] = useState(true)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="w-full text-center text-xs font-medium tracking-wide text-muted-foreground uppercase">Trusted by 140 consumer brands in Southeast Asia</div>
      <div className="relative w-full overflow-hidden">
        <Marquee reverse={reverse} pauseOnHover={pause} className="[--gap:3rem]" style={{ "--duration": `${duration}s` } as CSSProperties}>
          {brands.map((b) => (
            <div key={b.name} className="flex items-center gap-2 text-xl text-muted-foreground transition-colors hover:text-foreground">
              <b.icon className="size-5" />
              <span className={b.className}>{b.name}</span>
            </div>
          ))}
        </Marquee>
        {fade && (
          <>
            <div className="pointer-events-none absolute inset-y-0 left-0 w-24 bg-linear-to-r from-card" />
            <div className="pointer-events-none absolute inset-y-0 right-0 w-24 bg-linear-to-l from-card" />
          </>
        )}
      </div>
      <Controls>
        <SliderControl label="One lap" value={duration} onChange={setDuration} min={5} max={80} unit=" s" />
        <SwitchControl label="reverse" checked={reverse} onChange={setReverse} />
        <SwitchControl label="pauseOnHover" checked={pause} onChange={setPause} />
        <SwitchControl label="Edge fade" checked={fade} onChange={setFade} />
      </Controls>
    </div>
  )
}

const quotes = [
  { who: "Nurul, KA manager", where: "Kopi Senja", text: "We stopped chasing distributors on WhatsApp for stock counts." },
  { who: "Daniel, sales director", where: "Ombak", text: "Route plans used to take a day. Now the reps get them at 6 am." },
  { who: "Siew Ling, finance", where: "Kasih Baby", text: "Collections are finally in one place, by outlet and by rep." },
  { who: "Ravi, trade marketing", where: "Suria Snacks", text: "Promo compliance photos come in tagged by outlet. Huge." },
  { who: "Farah, ops", where: "Teh Puteri", text: "The low-stock alerts alone paid for it in the first month." },
  { who: "Jason, GM", where: "Dapur Mak", text: "East Malaysia finally shows up in the same dashboard as KL." },
]

function QuoteCard({ q }: { q: (typeof quotes)[number] }) {
  return (
    <figure className="w-64 rounded-xl border bg-background p-4">
      <blockquote className="text-sm">"{q.text}"</blockquote>
      <figcaption className="mt-2 text-xs text-muted-foreground">
        {q.who} · {q.where}
      </figcaption>
    </figure>
  )
}

function TestimonialWall() {
  const [duration, setDuration] = useState(25)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="relative flex h-72 w-full justify-center overflow-hidden">
        <Marquee vertical pauseOnHover repeat={3} style={{ "--duration": `${duration}s` } as CSSProperties}>
          {quotes.slice(0, 3).map((q) => (
            <QuoteCard key={q.who} q={q} />
          ))}
        </Marquee>
        <Marquee vertical reverse pauseOnHover repeat={3} className="max-sm:hidden" style={{ "--duration": `${duration}s` } as CSSProperties}>
          {quotes.slice(3).map((q) => (
            <QuoteCard key={q.who} q={q} />
          ))}
        </Marquee>
        <div className="pointer-events-none absolute inset-x-0 top-0 h-16 bg-linear-to-b from-card" />
        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-16 bg-linear-to-t from-card" />
      </div>
      <Controls>
        <SliderControl label="One lap" value={duration} onChange={setDuration} min={8} max={60} unit=" s" />
      </Controls>
    </div>
  )
}

function GradientHeadline() {
  const [swatch, setSwatch] = useState<Swatch>("Sunset")
  const [speed, setSpeed] = useState(1)
  const [from, to] = swatches[swatch]
  return (
    <div className="flex w-full flex-col items-center gap-5">
      <a
        href="#/motion"
        className="group inline-flex items-center gap-2 rounded-full border bg-background px-3 py-1 text-sm shadow-sm transition-shadow hover:shadow"
      >
        <SparklesIcon className="size-3.5" style={{ color: from }} />
        <span className="h-4 w-px bg-border" />
        <AnimatedGradientText colorFrom={from} colorTo={to} speed={speed} className="font-medium">
          Introducing Rantai Insights
        </AnimatedGradientText>
        <span className="text-muted-foreground transition-transform group-hover:translate-x-0.5">→</span>
      </a>
      <h3 className="max-w-md text-center text-3xl font-semibold tracking-tight">
        Know what sold,{" "}
        <AnimatedGradientText colorFrom={from} colorTo={to} speed={speed}>
          outlet by outlet
        </AnimatedGradientText>
      </h3>
      <Controls>
        <SwatchPicker value={swatch} onChange={setSwatch} />
        <SliderControl label="speed" value={speed} onChange={setSpeed} min={0.5} max={4} step={0.5} unit="×" />
      </Controls>
    </div>
  )
}

const textAnimations = ["fadeIn", "blurIn", "blurInUp", "slideUp", "slideLeft", "scaleUp"] as const
const textBy = ["word", "character", "line"] as const

function HeadlineEntrance() {
  const [run, setRun] = useState(0)
  const [animation, setAnimation] = useState<(typeof textAnimations)[number]>("blurInUp")
  const [by, setBy] = useState<(typeof textBy)[number]>("word")
  const [duration, setDuration] = useState(0.6)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="flex min-h-36 items-center justify-center">
        <TextAnimate
          key={`${run}-${animation}-${by}-${duration}`}
          as="h3"
          animation={animation}
          by={by}
          duration={duration}
          once
          className="max-w-md text-center text-3xl font-semibold tracking-tight"
        >
          {by === "line" ? "Route-to-market software\nfor brands that sell\nin every kedai" : "Route-to-market software for brands that sell in every kedai"}
        </TextAnimate>
      </div>
      <Controls>
        <Segmented value={animation} onChange={setAnimation} options={textAnimations} />
      </Controls>
      <Controls>
        <Segmented value={by} onChange={setBy} options={textBy} />
        <SliderControl label="Total" value={duration} onChange={setDuration} min={0.2} max={3} step={0.1} unit=" s" />
        <ReplayButton onClick={() => setRun((r) => r + 1)} />
      </Controls>
    </div>
  )
}

/* ----------------------------------------------- 4. navigation, backgrounds */

const dockItems: { label: string; icon: LucideIcon }[] = [
  { label: "Home", icon: HomeIcon },
  { label: "Search", icon: SearchIcon },
  { label: "Orders", icon: ShoppingCartIcon },
  { label: "Stock", icon: PackageIcon },
  { label: "Reports", icon: BarChart3Icon },
  { label: "Settings", icon: SettingsIcon },
]

function DockDemo() {
  const [magnification, setMagnification] = useState(64)
  const [distance, setDistance] = useState(140)
  const [off, setOff] = useState(false)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="flex h-28 items-end justify-center">
        <Dock className="mt-0" iconSize={40} iconMagnification={magnification} iconDistance={distance} disableMagnification={off} direction="bottom">
          {dockItems.map((d) => (
            <DockIcon key={d.label} className="bg-muted/60">
              <a href="#/motion" aria-label={d.label} title={d.label} className="flex items-center justify-center">
                <d.icon className="size-5" />
              </a>
            </DockIcon>
          ))}
        </Dock>
      </div>
      <Controls>
        <SliderControl label="Magnify to" value={magnification} onChange={setMagnification} min={40} max={100} unit=" px" />
        <SliderControl label="Reach" value={distance} onChange={setDistance} min={60} max={300} step={10} unit=" px" />
        <SwitchControl label="disableMagnification" checked={off} onChange={setOff} />
      </Controls>
    </div>
  )
}

function RippleState() {
  const [circles, setCircles] = useState(6)
  const [size, setSize] = useState(120)
  const [connected, setConnected] = useState(false)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="relative flex h-64 w-full flex-col items-center justify-center gap-3 overflow-hidden rounded-xl border bg-background">
        {!connected && <Ripple numCircles={circles} mainCircleSize={size} />}
        <span
          className={cn(
            "relative z-10 flex size-14 items-center justify-center rounded-2xl border bg-card shadow-sm",
            connected && "border-emerald-500/40 text-emerald-600 dark:text-emerald-400",
          )}
        >
          {connected ? <CheckIcon className="size-6" /> : <StoreIcon className="size-6" />}
        </span>
        <div className="relative z-10 text-center">
          <div className="text-sm font-medium">{connected ? "Store connected" : "Connecting your e-commerce store…"}</div>
          <div className="text-xs text-muted-foreground">{connected ? "Importing 312 SKUs" : "This usually takes under a minute"}</div>
        </div>
      </div>
      <Controls>
        <SliderControl label="Circles" value={circles} onChange={setCircles} min={2} max={10} />
        <SliderControl label="First circle" value={size} onChange={setSize} min={60} max={260} step={10} unit=" px" />
        <Button variant="outline" size="sm" onClick={() => setConnected((c) => !c)}>
          {connected ? "Reset" : "Finish"}
        </Button>
      </Controls>
    </div>
  )
}

/* -------------------------------------------------------------------- page */

export default function MotionPage() {
  const [reduced, setReduced] = useState(false)
  return (
    <Page
      title="Animated components"
      intro="Magic UI (in the Playbook) and Animate UI (a candidate), each placed where we'd actually use it: in-app feeds, people and buttons first, then marketing pieces. Most stages have controls for speed, direction and colour."
      libs={[
        { name: "Magic UI", status: "playbook", url: "https://magicui.design", install: "npx shadcn add @magicui/<name>" },
        { name: "Animate UI", status: "candidate", url: "https://animate-ui.com", install: "npx shadcn add @animate-ui/<name>" },
      ]}
    >
      <div className="flex flex-wrap items-center gap-3 rounded-xl border bg-muted/40 px-4 py-3 text-sm">
        <Switch checked={reduced} onCheckedChange={setReduced} />
        <span className="font-medium">Simulate reduced motion</span>
        <span className="text-xs text-muted-foreground">
          Wraps the page in motion's <code>&lt;MotionConfig reducedMotion="always"&gt;</code>. Anything still moving with this on ignores the
          setting.
        </span>
      </div>
      <MotionConfig reducedMotion={reduced ? "always" : "user"}>
        <Section title="In the app: feeds, lists, people" description="Where motion helps someone notice a change: a new order arriving, a list loading in, who is on a project.">
          <Variant label="Order notification feed" lib="Magic UI · AnimatedList" stageClassName="items-start" hint="We feed it a growing array (last 5). It springs each new child in at the top; the oldest leaves with a scale-out.">
            <NotificationFeed />
          </Variant>
          <Variant label="Settings cards loading in" lib="Magic UI · BlurFade" stageClassName="items-start" hint="Blur + offset + fade, staggered with delay. Good for first paint of a page; tiresome on every tab switch.">
            <BlurFadeList />
          </Variant>
          <Variant label="Team on a project" lib="Animate UI · AvatarGroup" className="md:col-span-2" hint="Hover an avatar: it lifts and one shared tooltip glides between people (layoutId). Needs @floating-ui/react; Escape closes the tooltip.">
            <TeamAvatars />
          </Variant>
        </Section>

        <Section title="In the app: buttons and accents" description="Small touches on controls and cards. These should be rare in an admin portal.">
          <Variant label="Ripple button" lib="Animate UI · RippleButton" hint="Ships its own button styles (h-9, rounded-md), so it doesn't match our base-nova Button (h-8, rounded-lg) without restyling.">
            <RippleButtons />
          </Variant>
          <Variant label="Shimmer button" lib="Magic UI · ShimmerButton" hint="Default background is pure black: fine on white, but on a dark card only its faint border separates it. Pass a background per theme, or var(--primary).">
            <ShimmerButtons />
          </Variant>
          <Variant label="Border beam on a card" lib="Magic UI · BorderBeam" hint="A light that runs round the border (CSS offset-path). Good for 'something new here' on one card at a time.">
            <BorderBeamCard />
          </Variant>
          <Variant label="Highlight in a sentence" lib="Animate UI · HighlightText" hint="Animates background-size, so colour comes from your own bg-linear-to-r classes. Takes text as a string prop only.">
            <HighlightSentence />
          </Variant>
        </Section>

        <Section title="Marketing: logos, headlines, social proof" description="Landing-page pieces. All of these loop or animate on entry; none belong inside the app.">
          <Variant label="Brand logo marquee" lib="Magic UI · Marquee" className="md:col-span-2" hint="Pure CSS (a keyframe and a --duration variable), so it is cheap. The edge fade is ours: two gradient overlays.">
            <LogoMarquee />
          </Variant>
          <Variant label="Testimonial wall" lib="Magic UI · Marquee (vertical)" hint="Two vertical marquees in opposite directions, pausing on hover. repeat={3} copies the content three times in the DOM.">
            <TestimonialWall />
          </Variant>
          <Variant label="Announcement pill and gradient headline" lib="Magic UI · AnimatedGradientText" hint="A moving background-clip:text gradient. Readable in both themes because both colours are mid-tone.">
            <GradientHeadline />
          </Variant>
          <Variant label="Headline entrance" lib="Magic UI · TextAnimate" className="md:col-span-2" hint={<>by="line" splits on \n; in word mode a \n is swallowed ("softwarefor"), so line breaks only work in line mode. It keeps an sr-only copy of the text for screen readers.</>}>
            <HeadlineEntrance />
          </Variant>
        </Section>

        <Section title="Navigation and ambient backgrounds" description="A macOS-style dock and a ripple for waiting states.">
          <Variant label="Dock" lib="Magic UI · Dock" hint="Magnification follows the mouse only. The icons are divs; put a link or button inside each one or keyboard users can't reach them.">
            <DockDemo />
          </Variant>
          <Variant label="Ripple behind a waiting state" lib="Magic UI · Ripple" hint="CSS keyframes on stacked circles, coloured from --foreground, so it themes itself.">
            <RippleState />
          </Variant>
        </Section>
      </MotionConfig>

      <Findings
        notes={[
          { tone: "good", text: <>Magic UI installs cleanly through the shadcn registry and drops plain files into components/ui. Most pieces are small and easy to read and edit. Marquee, Ripple, ShimmerButton and AnimatedGradientText are pure CSS keyframes, so they cost little while idle.</> },
          { tone: "good", text: <>The in-app keepers: AnimatedList for live feeds, BlurFade for first paint, BorderBeam to flag one new thing. They read as product polish, not decoration.</> },
          { tone: "bad", text: <>Reduced motion is mostly not handled. Flip the switch at the top: motion's MotionConfig stops transforms (BlurFade's slide, AnimatedList's scale, the avatar lift), but Marquee, ShimmerButton, gradient text, Ripple and BorderBeam (offset-path) keep running. With the real OS setting emulated in headless Chrome, this page still ran 22 CSS animations and ~170 ms/s of main-thread work (~160 without it). Wrap them in a <code>motion-safe:</code> class or a usePrefersReducedMotion check ourselves.</> },
          { tone: "bad", text: <>Theme gaps: ShimmerButton defaults to a black background whatever the theme. Dock's glass tint uses <code>supports-backdrop-blur:</code>, which Tailwind v4 compiles to <code>@supports (backdrop-blur: …)</code>, a test that is never true, so the tint never shows (checked in the built CSS). Pass theme colours in.</> },
          { tone: "note", text: <>Dock is mouse-only and its icons are divs. AnimatedList only reveals children one by one; it doesn't loop, so a live feed means managing the array yourself (as here).</> },
          { tone: "note", text: <>Animate UI: AvatarGroup (with its shared, gliding tooltip) and HighlightText are nice and worked once installed, but the set needed a fix to install, its Base UI tabs/switch/accordion failed, and RippleButton brings its own button styles that clash with base-nova. It's also a second motion-based component family alongside Magic UI.</> },
          { tone: "note", text: <>Recommendation: keep Magic UI in the Playbook for animated components, with a house rule that looping effects stay on marketing pages. Leave Animate UI as a candidate; take single pieces (AvatarGroup) by copying, rather than adopting the set.</> },
        ]}
      />
    </Page>
  )
}

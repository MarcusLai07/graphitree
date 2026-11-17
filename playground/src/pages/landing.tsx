import { createContext, useContext, useEffect, useState, type ReactNode } from "react"
import { ArrowRightIcon, RotateCcwIcon, RouteIcon } from "lucide-react"
import { MotionConfig, motion } from "motion/react"
import { CardBody, CardContainer, CardItem } from "@/components/ui/3d-card"
import { AuroraBackground } from "@/components/ui/aurora-background"
import { BackgroundBeams } from "@/components/ui/background-beams"
import { Button } from "@/components/ui/button"
import { HoverEffect } from "@/components/ui/card-hover-effect"
import { HeroHighlight, Highlight } from "@/components/ui/hero-highlight"
import { LampContainer } from "@/components/ui/lamp"
import { Button as MovingBorderButton } from "@/components/ui/moving-border"
import { Slider } from "@/components/ui/slider"
import { Spotlight } from "@/components/ui/spotlight-new"
import { Switch } from "@/components/ui/switch"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { TextGenerateEffect } from "@/components/ui/text-generate-effect"
import { cn } from "@/lib/utils"
import { Findings, Page, Section, Variant } from "@/playground/kit"

/* ------------------------------------------------------------- controls */

function Controls({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn("flex w-full flex-wrap items-center justify-center gap-x-4 gap-y-2 text-sm", className)}>{children}</div>
}

function SliderControl(props: { label: string; value: number; onChange: (n: number) => void; min: number; max: number; step?: number; unit?: string }) {
  const { label, value, onChange, min, max, step = 1, unit = "" } = props
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

function ReplayButton({ onClick }: { onClick: () => void }) {
  return (
    <Button variant="outline" size="sm" onClick={onClick}>
      <RotateCcwIcon data-icon="inline-start" />
      Replay
    </Button>
  )
}

/** Master switch for every effect on the page, so the idle meter can show a baseline. */
const EffectsOn = createContext(true)

/** A stage whose effect can be unmounted, so its idle cost shows up in the meter. */
function Runnable({ children, controls, className }: { children: ReactNode; controls?: ReactNode; className?: string }) {
  const master = useContext(EffectsOn)
  const [on, setOn] = useState(true)
  return (
    <div className="flex w-full flex-col gap-3">
      <div className={cn("relative h-80 w-full overflow-hidden rounded-lg border", className)}>
        {master && on ? (
          children
        ) : (
          <div className="flex h-full items-center justify-center bg-background text-xs text-muted-foreground">Unmounted</div>
        )}
      </div>
      <Controls>
        <SwitchControl label="Mounted" checked={on} onChange={setOn} />
        {controls}
      </Controls>
    </div>
  )
}

/**
 * Rough main-thread load: sums requestIdleCallback idle time each second.
 * 0% = nothing to do; ~100% = no idle time left. Counts script, style, layout and paint on the main thread,
 * not compositor-only work.
 */
function useMainThreadLoad() {
  const [load, setLoad] = useState<number | null>(null)
  const [animations, setAnimations] = useState(0)
  useEffect(() => {
    if (typeof requestIdleCallback === "undefined") return
    let idle = 0
    let handle = 0
    const loop = (d: IdleDeadline) => {
      idle += d.timeRemaining()
      handle = requestIdleCallback(loop)
    }
    handle = requestIdleCallback(loop)
    let last = performance.now()
    const id = setInterval(() => {
      const now = performance.now()
      setLoad(Math.max(0, Math.min(100, Math.round((1 - idle / (now - last)) * 100))))
      setAnimations(document.getAnimations().length)
      idle = 0
      last = now
    }, 1000)
    return () => {
      cancelIdleCallback(handle)
      clearInterval(id)
    }
  }, [])
  return { load, animations }
}

function PageBar({
  effects,
  setEffects,
  reduced,
  setReduced,
}: {
  effects: boolean
  setEffects: (b: boolean) => void
  reduced: boolean
  setReduced: (b: boolean) => void
}) {
  const { load, animations } = useMainThreadLoad()
  return (
    <div className="sticky top-2 z-40 flex flex-wrap items-center gap-x-6 gap-y-2 rounded-xl border bg-background/90 px-4 py-2.5 text-sm shadow-sm backdrop-blur">
      <label className="flex items-center gap-2">
        <Switch checked={effects} onCheckedChange={setEffects} />
        All effects mounted
      </label>
      <label className="flex items-center gap-2">
        <Switch checked={reduced} onCheckedChange={setReduced} />
        Simulate reduced motion
      </label>
      <div className="ml-auto flex items-center gap-4 text-xs text-muted-foreground tabular-nums">
        <span title="1 − idle time ÷ elapsed time, from requestIdleCallback">
          Main thread ≈{" "}
          <span className={cn("font-semibold text-foreground", load != null && load > 40 && "text-rose-600 dark:text-rose-400")}>
            {load == null ? "—" : `${load}%`}
          </span>
        </span>
        <span title="document.getAnimations(): running CSS and Web Animations">
          CSS/WAAPI animations <span className="font-semibold text-foreground">{animations}</span>
        </span>
      </div>
    </div>
  )
}

/* -------------------------------------------------- 1. composed landing */

const features = [
  { title: "Distributor orders", description: "Orders from every distributor and key account land in one queue, checked against credit limits.", link: "#orders" },
  { title: "Route plans by 6 am", description: "Van sales reps get the day's outlets on their phones, sequenced around KL traffic.", link: "#routes" },
  { title: "Stock at every DC", description: "Live stock in Shah Alam, Penang, Johor Bahru and Kota Kinabalu, with reorder alerts.", link: "#stock" },
  { title: "Sell-out by outlet", description: "See what sold through, not just what shipped, down to the kedai runcit.", link: "#sellout" },
  { title: "Promo compliance", description: "Merchandisers snap the shelf. Photos arrive tagged by outlet, SKU and promo.", link: "#promo" },
  { title: "Collections", description: "Invoices, payments and overdue accounts by outlet and by rep.", link: "#collections" },
]

function ProductCard({ depth = 1 }: { depth?: number }) {
  const bars = [42, 64, 51, 78, 69, 90, 84]
  return (
    <CardContainer containerClassName="py-4">
      <CardBody className="h-auto w-80 rounded-xl border bg-background p-5 shadow-sm sm:w-96">
        <CardItem translateZ={40 * depth} className="text-sm font-semibold">
          Sell-out by outlet · Klang Valley
        </CardItem>
        <CardItem translateZ={30 * depth} as="p" className="mt-1 text-xs text-muted-foreground">
          Kopi Senja 3-in-1 · last 7 days
        </CardItem>
        <CardItem translateZ={80 * depth} className="mt-4 flex h-28 w-full items-end gap-2">
          {bars.map((h, i) => (
            <div key={i} className="flex-1 rounded-t-sm bg-sky-500/80" style={{ height: `${h}%` }} />
          ))}
        </CardItem>
        <div className="mt-4 flex items-center justify-between">
          <CardItem translateZ={50 * depth} className="text-2xl font-semibold">
            RM 184,230
          </CardItem>
          <CardItem translateZ={60 * depth} as="span" className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-xs text-emerald-600 dark:text-emerald-400">
            +18.4%
          </CardItem>
        </div>
      </CardBody>
    </CardContainer>
  )
}

function MiniLanding() {
  return (
    <div className="w-full overflow-hidden rounded-b-xl">
      {/* Hero: dark in both themes, as most product landing pages are. */}
      <div className="relative overflow-hidden bg-neutral-950 text-white">
        <Spotlight />
        <nav className="relative z-10 flex items-center justify-between px-8 py-5">
          <div className="flex items-center gap-2 font-semibold">
            <span className="flex size-7 items-center justify-center rounded-lg bg-white text-neutral-950">
              <RouteIcon className="size-4" />
            </span>
            Rantai
          </div>
          <div className="hidden gap-6 text-sm text-neutral-400 md:flex">
            <span>Product</span>
            <span>Customers</span>
            <span>Pricing</span>
          </div>
          <span className="text-sm text-neutral-300">Sign in</span>
        </nav>
        <div className="relative z-10 mx-auto flex max-w-3xl flex-col items-center px-6 pt-14 pb-24 text-center">
          <span className="rounded-full border border-white/15 bg-white/5 px-3 py-1 text-xs text-neutral-300">New: Hari Raya demand forecasts</span>
          <h2 className="mt-6 text-4xl font-semibold tracking-tight text-balance md:text-6xl">
            Every outlet, every order,{" "}
            <Highlight className="from-indigo-500 to-purple-500 text-white">one view</Highlight>
          </h2>
          <p className="mt-6 max-w-xl text-neutral-400">
            Rantai gives consumer brands in Malaysia one place for distributor orders, route plans, stock at every DC and sell-out by outlet.
          </p>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
            <MovingBorderButton
              borderRadius="0.75rem"
              duration={3500}
              containerClassName="h-11 w-40"
              className="border-neutral-800 bg-neutral-950 text-sm font-medium text-white"
            >
              Book a demo
            </MovingBorderButton>
            <span className="inline-flex h-11 items-center gap-1.5 px-4 text-sm text-neutral-300">
              See how it works <ArrowRightIcon className="size-4" />
            </span>
          </div>
        </div>
      </div>

      {/* Features: follows the app theme. */}
      <div className="bg-background px-8 pt-14">
        <div className="mx-auto max-w-4xl text-center">
          <h3 className="text-2xl font-semibold tracking-tight">Built for route-to-market teams</h3>
          <p className="mt-2 text-muted-foreground">From the key account manager to the van sales rep.</p>
        </div>
        {/* Every card is an <a href={link}>; stop the clicks so the lab's hash router doesn't navigate away. */}
        <div onClickCapture={(e) => e.preventDefault()}>
          <HoverEffect items={features} className="mx-auto max-w-5xl py-6" />
        </div>
      </div>

      {/* Product shot. */}
      <div className="grid items-center gap-6 bg-muted/40 px-8 py-8 md:grid-cols-2">
        <div className="max-w-sm">
          <h3 className="text-2xl font-semibold tracking-tight">Sell-out, not just shipments</h3>
          <p className="mt-2 text-muted-foreground">
            Retailer and distributor data, matched by outlet, so trade spend goes where product actually moves.
          </p>
          <p className="mt-4 text-xs text-muted-foreground">Move the mouse over the card.</p>
        </div>
        <ProductCard />
      </div>

      {/* CTA. */}
      <LampContainer className="min-h-[36rem] rounded-none">
        <motion.h3
          initial={{ opacity: 0.5, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ delay: 0.3, duration: 0.8, ease: "easeInOut" }}
          className="bg-linear-to-br from-slate-200 to-slate-500 bg-clip-text py-4 text-center text-4xl font-medium tracking-tight text-transparent md:text-5xl"
        >
          Route plans on every phone <br /> by 6 am
        </motion.h3>
        <span className="mt-6 rounded-full bg-cyan-500 px-5 py-2 text-sm font-medium text-slate-950">Start a 30-day pilot</span>
      </LampContainer>
    </div>
  )
}

function ComposedLanding() {
  const master = useContext(EffectsOn)
  const [on, setOn] = useState(true)
  return (
    <div className="flex w-full flex-col">
      <div className="flex justify-end border-b px-4 py-2">
        <SwitchControl label="Mounted" checked={on} onChange={setOn} />
      </div>
      {master && on ? <MiniLanding /> : <div className="flex h-40 items-center justify-center text-xs text-muted-foreground">Unmounted</div>}
    </div>
  )
}

/* ---------------------------------------------------- 2. hero backgrounds */

function SpotlightDemo() {
  const [duration, setDuration] = useState(7)
  const [xOffset, setXOffset] = useState(100)
  const [light, setLight] = useState(false)
  return (
    <Runnable
      className={light ? "bg-white" : "bg-neutral-950"}
      controls={
        <>
          <SwitchControl label="White background" checked={light} onChange={setLight} />
          <SliderControl label="Drift" value={duration} onChange={setDuration} min={2} max={16} unit=" s" />
          <SliderControl label="xOffset" value={xOffset} onChange={setXOffset} min={0} max={300} step={10} unit=" px" />
        </>
      }
    >
      <Spotlight key={`${duration}-${xOffset}`} duration={duration} xOffset={xOffset} />
      <div className={cn("relative z-10 flex h-full flex-col items-center justify-center px-6 text-center", light ? "text-neutral-950" : "text-white")}>
        <h3 className="text-3xl font-semibold tracking-tight">Spotlight</h3>
        <p className="mt-2 max-w-xs text-sm text-neutral-500">Two soft beams drifting from the top corners.</p>
      </div>
    </Runnable>
  )
}

function BeamsDemo() {
  return (
    <Runnable className="bg-neutral-950">
      <div className="relative z-10 flex h-full flex-col items-center justify-center gap-4 px-6 text-center text-white">
        <h3 className="text-3xl font-semibold tracking-tight">Join the pilot waitlist</h3>
        <div className="flex w-full max-w-sm gap-2">
          <input
            aria-label="Work email"
            placeholder="you@brand.com.my"
            className="h-9 flex-1 rounded-lg border border-neutral-800 bg-neutral-900 px-3 text-sm outline-none placeholder:text-neutral-500 focus:border-neutral-600"
          />
          <span className="inline-flex h-9 items-center rounded-lg bg-white px-3 text-sm font-medium text-neutral-950">Join</span>
        </div>
      </div>
      <BackgroundBeams />
    </Runnable>
  )
}

function AuroraDemo() {
  const [radial, setRadial] = useState(true)
  return (
    <Runnable controls={<SwitchControl label="showRadialGradient" checked={radial} onChange={setRadial} />}>
      <AuroraBackground className="h-80" showRadialGradient={radial}>
        <div className="relative z-10 flex flex-col items-center gap-2 px-6 text-center">
          <h3 className="text-3xl font-semibold tracking-tight text-foreground">Aurora</h3>
          <p className="max-w-xs text-sm text-muted-foreground">A slow, blurred band of blues. Follows light and dark.</p>
        </div>
      </AuroraBackground>
    </Runnable>
  )
}

function LampDemo() {
  const [run, setRun] = useState(0)
  return (
    <Runnable className="h-[30rem] bg-slate-950" controls={<ReplayButton onClick={() => setRun((r) => r + 1)} />}>
      <LampContainer key={run} className="h-full min-h-full">
        <motion.h3
          initial={{ opacity: 0.5, y: 60 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3, duration: 0.8, ease: "easeInOut" }}
          className="bg-linear-to-br from-slate-200 to-slate-500 bg-clip-text py-4 text-center text-4xl font-medium tracking-tight text-transparent"
        >
          Lamp
        </motion.h3>
      </LampContainer>
    </Runnable>
  )
}

function HeroHighlightDemo() {
  const [run, setRun] = useState(0)
  return (
    <Runnable controls={<ReplayButton onClick={() => setRun((r) => r + 1)} />}>
      <HeroHighlight key={run} containerClassName="h-full">
        <h3 className="max-w-md px-6 text-center text-2xl leading-relaxed font-semibold tracking-tight text-neutral-800 dark:text-neutral-100">
          Trade spend that follows <Highlight className="whitespace-nowrap text-black dark:text-white">real sell-out</Highlight>
        </h3>
      </HeroHighlight>
    </Runnable>
  )
}

/* ---------------------------------------------------------- 3. text */

function TextGenerateDemo() {
  const [run, setRun] = useState(0)
  const [filter, setFilter] = useState(true)
  const [duration, setDuration] = useState(0.5)
  return (
    <Runnable
      className="flex h-56 items-center justify-center bg-background px-8"
      controls={
        <>
          <SwitchControl label="filter (blur)" checked={filter} onChange={setFilter} />
          <SliderControl label="Per word" value={duration} onChange={setDuration} min={0.1} max={2} step={0.1} unit=" s" />
          <ReplayButton onClick={() => setRun((r) => r + 1)} />
        </>
      }
    >
      <TextGenerateEffect
        key={`${run}-${filter}-${duration}`}
        filter={filter}
        duration={duration}
        className="text-center"
        words="Rantai matched 1,284 outlets to their distributors and found RM 2.1M of trade spend going to stores that never stocked the promo."
      />
    </Runnable>
  )
}

function HighlightDemo() {
  const [run, setRun] = useState(0)
  return (
    <Runnable className="flex h-56 items-center justify-center bg-background px-8" controls={<ReplayButton onClick={() => setRun((r) => r + 1)} />}>
      <p key={run} className="max-w-md text-center text-2xl leading-relaxed font-semibold tracking-tight">
        Stop guessing which outlets ran the promo. <Highlight className="text-black dark:text-white">See the shelf photos.</Highlight>
      </p>
    </Runnable>
  )
}

/* ------------------------------------------------- 4. cards and buttons */

function ThreeDCardDemo() {
  const [depth, setDepth] = useState(1)
  return (
    <Runnable className="flex h-96 items-center justify-center bg-muted/30" controls={<SliderControl label="Depth" value={depth} onChange={setDepth} min={0} max={2.5} step={0.25} unit="×" />}>
      <ProductCard depth={depth} />
    </Runnable>
  )
}

function HoverCardsDemo() {
  return (
    <Runnable className="h-auto bg-background">
      <div onClickCapture={(e) => e.preventDefault()}>
        <HoverEffect items={features} className="py-2" />
      </div>
    </Runnable>
  )
}

const radii = { Pill: "1.75rem", Rounded: "0.75rem", Square: "0.25rem" } as const

function MovingBorderDemo() {
  const [duration, setDuration] = useState(3000)
  const [radius, setRadius] = useState<keyof typeof radii>("Pill")
  return (
    <Runnable
      className="flex h-56 flex-wrap items-center justify-center gap-6 bg-background"
      controls={
        <>
          <SliderControl label="Lap" value={duration} onChange={setDuration} min={800} max={8000} step={100} unit=" ms" />
          <Tabs value={radius} onValueChange={(x) => setRadius(x as keyof typeof radii)}>
            <TabsList>
              {Object.keys(radii).map((r) => (
                <TabsTrigger key={r} value={r} className="text-xs">
                  {r}
                </TabsTrigger>
              ))}
            </TabsList>
          </Tabs>
        </>
      }
    >
      <MovingBorderButton borderRadius={radii[radius]} duration={duration}>
        As installed
      </MovingBorderButton>
      <MovingBorderButton
        borderRadius={radii[radius]}
        duration={duration}
        borderClassName="bg-[radial-gradient(#f59e0b_40%,transparent_60%)]"
        className="border-border bg-background font-medium text-foreground"
      >
        Themed
      </MovingBorderButton>
    </Runnable>
  )
}

/* ------------------------------------------------------- 5. measured cost */

/**
 * Main-thread work per second with only that effect mounted, after its entrance finished.
 * Headless Chrome for Testing 1248 via CDP Performance.getMetrics (TaskDuration), 1400×1000 @2x, Apple silicon, 16 Nov 2026.
 */
const measured: { effect: string; onScreen: number; offScreen: number; why: string }[] = [
  { effect: "Background beams", onScreen: 101, offScreen: 93, why: "50 SVG gradients, attributes animated in JS every frame" },
  { effect: "Moving border (2 buttons)", onScreen: 75, offScreen: 71, why: "useAnimationFrame + getPointAtLength every frame" },
  { effect: "Aurora", onScreen: 42, offScreen: 35, why: "CSS background-position on a blurred, blended layer: repaints" },
  { effect: "Spotlight", onScreen: 9, offScreen: 5, why: "two transforms, handed to the compositor" },
  { effect: "Lamp", onScreen: 2, offScreen: 5, why: "animates once on entry, then idle" },
  { effect: "Hero highlight", onScreen: 5, offScreen: 3, why: "only reacts to the mouse" },
  { effect: "3D card", onScreen: 3, offScreen: 2, why: "only reacts to the mouse" },
  { effect: "Hover effect cards", onScreen: 3, offScreen: 3, why: "only reacts to the mouse" },
  { effect: "Nothing mounted", onScreen: 3, offScreen: 3, why: "baseline: the lab itself" },
]

function MeasuredCost() {
  const max = Math.max(...measured.map((m) => m.onScreen))
  return (
    <div className="w-full overflow-x-auto">
      <table className="w-full text-sm">
        <thead className="text-left text-xs text-muted-foreground">
          <tr>
            <th className="py-2 pr-4 font-medium">Effect</th>
            <th className="py-2 pr-4 font-medium">On screen</th>
            <th className="py-2 pr-4 text-right font-medium">Off screen</th>
            <th className="py-2 font-medium">Why</th>
          </tr>
        </thead>
        <tbody>
          {measured.map((m) => (
            <tr key={m.effect} className="border-t">
              <td className="py-2 pr-4 font-medium whitespace-nowrap">{m.effect}</td>
              <td className="py-2 pr-4">
                <div className="flex items-center gap-2">
                  <div className="h-2 w-40 rounded-full bg-muted">
                    <div className="h-2 rounded-full bg-foreground/70" style={{ width: `${(m.onScreen / max) * 100}%` }} />
                  </div>
                  <span className="w-16 text-xs tabular-nums">{m.onScreen} ms/s</span>
                </div>
              </td>
              <td className="py-2 pr-4 text-right text-xs tabular-nums">{m.offScreen} ms/s</td>
              <td className="py-2 text-xs text-muted-foreground">{m.why}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

/* -------------------------------------------------------------------- page */

export default function LandingPage() {
  const [effects, setEffects] = useState(true)
  const [reduced, setReduced] = useState(false)
  return (
    <Page
      title="Landing page effects"
      intro="Aceternity UI, first composed into a small landing page for a made-up route-to-market product, then each effect on its own stage. Every stage can be unmounted, and the bar below estimates how busy the main thread is (only while this tab is visible), so you can see what each effect costs while nothing is happening."
      libs={[{ name: "Aceternity UI", status: "playbook", url: "https://ui.aceternity.com", install: "npx shadcn add @aceternity/<name>" }]}
    >
      <PageBar effects={effects} setEffects={setEffects} reduced={reduced} setReduced={setReduced} />
      <EffectsOn.Provider value={effects}>
        <MotionConfig reducedMotion={reduced ? "always" : "user"}>
          <Section title="A landing page, composed" description="Spotlight hero, Highlight, a moving-border CTA, hover cards, a 3D product card and a Lamp call to action.">
            <Variant
              label="Rantai · route-to-market for consumer brands"
              lib="Aceternity UI"
              className="md:col-span-2"
              stageClassName="block p-0"
              hint="The hero is dark in both themes on purpose; the feature and product sections follow the app theme."
            >
              <ComposedLanding />
            </Variant>
          </Section>

          <Section title="Hero backgrounds" description="Each one sized into a 20rem stage. Most assume a full screen by default and needed a height override.">
            <Variant label="Spotlight" lib="spotlight-new" hint="On white it fades to a faint blue wash: the beams are white-blue at 2–8% opacity. Dark heroes only.">
              <SpotlightDemo />
            </Variant>
            <Variant label="Background beams" lib="background-beams" hint="50 SVG gradients animated by motion, every frame, with random timings. The heaviest effect here.">
              <BeamsDemo />
            </Variant>
            <Variant label="Aurora" lib="aurora-background" hint="CSS only once its keyframes exist (the install left them out; fixed in the component). Blur + mix-blend on a large layer.">
              <AuroraDemo />
            </Variant>
            <Variant label="Lamp" lib="lamp" hint="Built for min-h-screen: content is pushed up with -translate-y-80, so in a shorter box it sits high. Always slate-950.">
              <LampDemo />
            </Variant>
            <Variant label="Hero highlight" lib="hero-highlight" className="md:col-span-2" hint="A dot grid that lights up under the mouse, plus Highlight, a marker sweep across a phrase. Has light and dark dot colours.">
              <HeroHighlightDemo />
            </Variant>
          </Section>

          <Section title="Text effects" description="One-shot entrances for a headline or a key claim.">
            <Variant label="Text generate" lib="text-generate-effect" hint="Words fade in from blur, staggered 0.2 s. It hard-codes text-2xl and black/white text, so it ignores the parent's type styles.">
              <TextGenerateDemo />
            </Variant>
            <Variant label="Highlight" lib="hero-highlight" hint="A gradient marker sweeping under a phrase, in light and dark versions. Runs on mount, not when scrolled into view.">
              <HighlightDemo />
            </Variant>
          </Section>

          <Section title="Cards and buttons" description="Interactive pieces that only move under the mouse, plus one that never stops.">
            <Variant label="3D card" lib="3d-card" hint="Tilts toward the mouse; layers lift by translateZ. Nothing moves until hovered, so it costs nothing while idle. Mouse only.">
              <ThreeDCardDemo />
            </Variant>
            <Variant label="Moving border" lib="moving-border" hint="A glow that runs round the button, positioned with getPointAtLength on every animation frame. Inner colours are fixed slate unless overridden.">
              <MovingBorderDemo />
            </Variant>
            <Variant label="Hover effect cards" lib="card-hover-effect" className="md:col-span-2" hint="A shared background slides between cards (layoutId). Cards are always bg-black, and each item's link doubles as its React key, so links must be unique.">
              <HoverCardsDemo />
            </Variant>
          </Section>
        </MotionConfig>
      </EffectsOn.Provider>

      <Section
        title="Idle cost, measured"
        description="Milliseconds of main-thread work per second with one effect mounted and nothing being touched (1,000 ms/s = one core flat out). Measured in headless Chrome with CDP Performance metrics, since a hidden preview tab doesn't render frames. The live meter in the bar above gives a rougher reading while you browse."
      >
        <Variant label="Main-thread time per second, one effect at a time" lib="Chrome 1248 · CDP" className="md:col-span-2" stageClassName="block">
          <MeasuredCost />
        </Variant>
      </Section>

      <Findings
        notes={[
          { tone: "good", text: <>The most striking effects of any library in the lab. A single Spotlight, Aurora or Lamp hero plus a 3D product card makes a credible marketing page in an afternoon.</> },
          { tone: "bad", text: <>Install friction is real. Aurora came without its keyframes (Tailwind v4 theme not updated) and wrapped itself in a second <code>&lt;main&gt;</code>; both fixed in the component file here. The code leans on <code>any</code>, unused parameters and <code>let</code>, so it only compiles because this project turns noUnused* off.</> },
          { tone: "bad", text: <>Mostly not theme-aware: Spotlight is a barely-there blue wash on light backgrounds, Lamp is always slate-950, HoverEffect cards are always black, MovingBorder's inside is slate-900, and TextGenerateEffect forces black/white text. Fine for a dark marketing site; needs edits for anything themed.</> },
          { tone: "bad", text: <>No prefers-reduced-motion handling anywhere. With the OS setting emulated (CDP), the whole page still cost ~200 ms/s of main thread, against ~180 ms/s without it: nothing switched off. Motion's MotionConfig only stops transform-based movement (Spotlight's drift, the hover-card slide); Beams, Aurora, Lamp, Highlight, the moving border and text generate carry on.</> },
          { tone: "bad", text: <>Idle cost (table above): BackgroundBeams ~100 ms/s and MovingBorder ~70 ms/s of main-thread work, the same when scrolled off-screen; Aurora ~40 ms/s of repaint. Spotlight is cheap (~5–9 ms/s, compositor transforms). Lamp, Highlight, 3D card and HoverEffect cost nothing once their entrance ends. The composed landing page alone costs ~120 ms/s even scrolled out of view, which matters on low-end Android phones.</> },
          { tone: "note", text: <>Most components assume they own the viewport (<code>h-screen</code>, <code>w-screen</code>, <code>min-h-screen</code>, <code>h-[40rem]</code>). Expect to override sizes before they sit inside a section.</> },
          { tone: "note", text: <>Recommendation: keep Aceternity in the Playbook for marketing sites only. One background effect per page, prefer the CSS-driven ones (Aurora, Spotlight), gate them behind prefers-reduced-motion ourselves, and never ship them into the admin portals or the chat workspace.</> },
        ]}
      />
    </Page>
  )
}

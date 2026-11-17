import { useEffect, useRef, useState, type ReactNode } from "react"
import NumberFlow, {
  NumberFlowGroup,
  continuous,
  useCanAnimate,
  usePrefersReducedMotion,
  type Format,
} from "@number-flow/react"
import { ArrowUpIcon, MinusIcon, PauseIcon, PlayIcon, PlusIcon, RefreshCwIcon, ShuffleIcon } from "lucide-react"
import { motion } from "motion/react"
import { SlidingNumber } from "@/components/animate-ui/primitives/texts/sliding-number"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { NumberTicker } from "@/components/ui/number-ticker"
import { Slider } from "@/components/ui/slider"
import { Switch } from "@/components/ui/switch"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { cn } from "@/lib/utils"
import { Findings, Page, Section, Variant } from "@/playground/kit"

/* ------------------------------------------------------------------ helpers */

const rand = (min: number, max: number) => min + Math.random() * (max - min)
const randInt = (min: number, max: number) => Math.round(rand(min, max))
const round = (n: number, dp = 2) => Math.round(n * 10 ** dp) / 10 ** dp

const MYR: Format = { style: "currency", currency: "MYR" }
const MYR0: Format = { style: "currency", currency: "MYR", maximumFractionDigits: 0 }
const MYR_COMPACT: Format = { style: "currency", currency: "MYR", notation: "compact", maximumFractionDigits: 1 }
const PCT_DELTA: Format = { style: "percent", maximumFractionDigits: 1, signDisplay: "always" }
const PCT: Format = { style: "percent", maximumFractionDigits: 1 }
const COMPACT: Format = { notation: "compact", maximumFractionDigits: 1 }

function Controls({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn("flex w-full flex-wrap items-center justify-center gap-2", className)}>{children}</div>
}

function Shuffle({ onClick, children = "Randomise" }: { onClick: () => void; children?: ReactNode }) {
  return (
    <Button variant="outline" size="sm" onClick={onClick}>
      <ShuffleIcon data-icon="inline-start" />
      {children}
    </Button>
  )
}

function Row({ label, children }: { label: ReactNode; children: ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-6 border-b border-dashed py-1.5 last:border-0">
      <span className="text-xs text-muted-foreground">{label}</span>
      <span className="text-right">{children}</span>
    </div>
  )
}

/** Up/down arrow + signed percentage, coloured by direction. */
function TrendDelta({ value, className }: { value: number; className?: string }) {
  const up = value >= 0
  return (
    <span
      className={cn(
        "inline-flex items-center gap-0.5 text-sm font-medium",
        up ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400",
        className,
      )}
    >
      <motion.span className="inline-flex" animate={{ rotate: up ? 0 : 180 }} transition={{ type: "spring", stiffness: 300, damping: 20 }}>
        <ArrowUpIcon className="size-3.5" aria-hidden />
      </motion.span>
      <NumberFlow value={value} format={PCT_DELTA} />
    </span>
  )
}

/* --------------------------------------------------------------- 1. KPI tiles */

function CurrencyTile() {
  const [v, setV] = useState(1_284_530.5)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="text-center">
        <div className="text-xs text-muted-foreground">Net sales, November</div>
        <NumberFlow className="text-4xl font-semibold tracking-tight" value={v} locales="en-MY" format={MYR0} />
      </div>
      <div className="rounded-lg border px-3">
        <Row label="Full, 2 decimals">
          <NumberFlow value={v} locales="en-MY" format={MYR} />
        </Row>
        <Row label="Compact">
          <NumberFlow value={v} locales="en-MY" format={MYR_COMPACT} />
        </Row>
        <Row label={<>Code instead of symbol</>}>
          <NumberFlow value={v} locales="en-MY" format={{ ...MYR0, currencyDisplay: "code" }} />
        </Row>
      </div>
      <Controls>
        <Shuffle onClick={() => setV(round(rand(80_000, 4_800_000)))} />
        <Button variant="ghost" size="sm" onClick={() => setV((x) => round(x + rand(50, 900)))}>
          <PlusIcon data-icon="inline-start" />
          Small sale
        </Button>
      </Controls>
    </div>
  )
}

function PercentTile() {
  const [margin, setMargin] = useState(0.384)
  const [delta, setDelta] = useState(0.032)
  const [sellThrough, setSellThrough] = useState(0.724)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="text-center">
        <div className="text-xs text-muted-foreground">Gross margin</div>
        <div className="flex items-baseline justify-center gap-2">
          <NumberFlow className="text-4xl font-semibold tracking-tight" value={margin} format={PCT} />
          <TrendDelta value={delta} />
        </div>
        <div className="text-xs text-muted-foreground">vs October</div>
      </div>
      <div className="rounded-lg border px-3">
        <Row label="Sell-through">
          <NumberFlow value={sellThrough} format={PCT} />
        </Row>
        <Row label="Change, as a badge">
          <Badge
            variant="outline"
            className={cn(
              "tabular-nums",
              delta >= 0
                ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-700 dark:text-emerald-300"
                : "border-rose-500/30 bg-rose-500/10 text-rose-700 dark:text-rose-300",
            )}
          >
            <NumberFlow value={delta} format={PCT_DELTA} />
          </Badge>
        </Row>
      </div>
      <Controls>
        <Shuffle
          onClick={() => {
            setMargin(round(rand(0.28, 0.46), 3))
            setDelta(round(rand(-0.06, 0.06), 3))
            setSellThrough(round(rand(0.5, 0.95), 3))
          }}
        />
        <Button variant="ghost" size="sm" onClick={() => setDelta((d) => -d)}>
          Flip the trend
        </Button>
      </Controls>
    </div>
  )
}

const compactSteps = [8_420, 84_200, 845_000, 1_240_000, 12_400_000]

function CompactTile() {
  const [i, setI] = useState(2)
  const [v, setV] = useState(compactSteps[2])
  const go = (next: number) => {
    const j = (next + compactSteps.length) % compactSteps.length
    setI(j)
    setV(Math.round(compactSteps[j] * rand(0.9, 1.1)))
  }
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="text-center">
        <div className="text-xs text-muted-foreground">Units shipped, YTD</div>
        <NumberFlow className="text-4xl font-semibold tracking-tight" value={v} locales="en-MY" format={COMPACT} />
      </div>
      <div className="rounded-lg border px-3">
        <Row label="Same value, full">
          <NumberFlow value={v} locales="en-MY" />
        </Row>
        <Row label="compactDisplay: long">
          <NumberFlow value={v} locales="en-MY" format={{ ...COMPACT, compactDisplay: "long" }} />
        </Row>
      </div>
      <Controls>
        <Button variant="outline" size="sm" onClick={() => go(i - 1)}>
          ÷ 10
        </Button>
        <Button variant="outline" size="sm" onClick={() => go(i + 1)}>
          × 10
        </Button>
      </Controls>
    </div>
  )
}

const locales = ["en-MY", "ms-MY", "zh-MY", "ta-MY", "en-US"] as const

function LocaleTile() {
  const [locale, setLocale] = useState<(typeof locales)[number]>("en-MY")
  const [v, setV] = useState(48_250.75)
  return (
    <div className="flex w-full flex-col items-center gap-4">
      <Tabs value={locale} onValueChange={(x) => setLocale(x as (typeof locales)[number])}>
        <TabsList>
          {locales.map((l) => (
            <TabsTrigger key={l} value={l}>
              {l}
            </TabsTrigger>
          ))}
        </TabsList>
      </Tabs>
      <NumberFlow className="text-4xl font-semibold tracking-tight" value={v} locales={locale} format={MYR} />
      <div className="flex gap-6 text-sm">
        <NumberFlow value={v / 1000} locales={locale} format={{ maximumFractionDigits: 2 }} suffix=" k" />
        <NumberFlow value={0.1834} locales={locale} format={PCT} />
        <NumberFlow value={v * 31} locales={locale} format={COMPACT} />
      </div>
      <Controls>
        <Shuffle onClick={() => setV(round(rand(900, 99_000)))} />
      </Controls>
    </div>
  )
}

/* ------------------------------------------------------ 2. Live & interactive */

function LiveCounter() {
  const [running, setRunning] = useState(true)
  const [orders, setOrders] = useState(1_284)
  const [revenue, setRevenue] = useState(214_380.4)
  const [lastAt, setLastAt] = useState<string>("—")
  useEffect(() => {
    if (!running) return
    const id = setInterval(() => {
      const n = randInt(1, 4)
      setOrders((o) => o + n)
      setRevenue((r) => round(r + n * rand(90, 420)))
      setLastAt(new Date().toLocaleTimeString("en-MY"))
    }, 1400)
    return () => clearInterval(id)
  }, [running])
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="flex items-center justify-between">
        <span className="inline-flex items-center gap-2 text-xs text-muted-foreground">
          <span className={cn("size-2 rounded-full", running ? "animate-pulse bg-emerald-500" : "bg-muted-foreground/40")} />
          {running ? "Live" : "Paused"} · last order {lastAt}
        </span>
        <Button variant="ghost" size="icon-sm" onClick={() => setRunning((r) => !r)} aria-label={running ? "Pause" : "Resume"}>
          {running ? <PauseIcon /> : <PlayIcon />}
        </Button>
      </div>
      <NumberFlowGroup>
        <div className="grid grid-cols-2 gap-3">
          <div className="rounded-lg border p-3">
            <div className="text-xs text-muted-foreground">Orders today</div>
            <NumberFlow className="text-3xl font-semibold" value={orders} locales="en-MY" />
          </div>
          <div className="rounded-lg border p-3">
            <div className="text-xs text-muted-foreground">Revenue today</div>
            <NumberFlow className="text-3xl font-semibold" value={revenue} locales="en-MY" format={MYR_COMPACT} />
          </div>
        </div>
      </NumberFlowGroup>
    </div>
  )
}

const plans = [
  { name: "Starter", monthly: 49, blurb: "1 warehouse" },
  { name: "Growth", monthly: 129, blurb: "5 warehouses" },
  { name: "Scale", monthly: 349, blurb: "Unlimited" },
]
const currencies = {
  MYR: { rate: 1, locale: "en-MY" },
  SGD: { rate: 0.3, locale: "en-SG" },
  USD: { rate: 0.23, locale: "en-US" },
} as const

function PlanPrice() {
  const [yearly, setYearly] = useState(false)
  const [cur, setCur] = useState<keyof typeof currencies>("MYR")
  const { rate, locale } = currencies[cur]
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <label className="flex items-center gap-2 text-sm">
          <Switch checked={yearly} onCheckedChange={setYearly} />
          Bill yearly <span className="text-xs text-emerald-600 dark:text-emerald-400">save 20%</span>
        </label>
        <Tabs value={cur} onValueChange={(x) => setCur(x as keyof typeof currencies)}>
          <TabsList>
            {Object.keys(currencies).map((c) => (
              <TabsTrigger key={c} value={c}>
                {c}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
      </div>
      <NumberFlowGroup>
        <div className="grid grid-cols-3 gap-2">
          {plans.map((p) => {
            const perMonth = Math.round(p.monthly * rate * (yearly ? 0.8 : 1))
            return (
              <div key={p.name} className={cn("rounded-lg border p-3", p.name === "Growth" && "border-primary/40 bg-muted/40")}>
                <div className="text-sm font-medium">{p.name}</div>
                <div className="text-xs text-muted-foreground">{p.blurb}</div>
                <NumberFlow
                  className="mt-2 text-2xl font-semibold"
                  value={perMonth}
                  locales={locale}
                  format={{ style: "currency", currency: cur, maximumFractionDigits: 0 }}
                  suffix="/mo"
                />
                <div className="h-4 text-[11px] text-muted-foreground">
                  {yearly && (
                    <NumberFlow
                      value={perMonth * 12}
                      locales={locale}
                      format={{ style: "currency", currency: cur, maximumFractionDigits: 0 }}
                      suffix=" billed yearly"
                    />
                  )}
                </div>
              </div>
            )
          })}
        </div>
      </NumberFlowGroup>
    </div>
  )
}

function CartStepper() {
  const unit = 38.9
  const [qty, setQty] = useState(6)
  const subtotal = qty * unit
  const discount = qty >= 10 ? subtotal * 0.05 : 0
  const total = subtotal - discount
  return (
    <div className="flex w-full flex-col gap-3">
      <div className="flex items-center justify-between gap-3">
        <div>
          <div className="text-sm font-medium">Kopi Senja 3-in-1, carton of 24</div>
          <div className="text-xs text-muted-foreground">RM 38.90 / carton · 5% off from 10 cartons</div>
        </div>
        <div className="flex items-center gap-1 rounded-lg border p-0.5">
          <Button variant="ghost" size="icon-sm" onClick={() => setQty((q) => Math.max(1, q - 1))} aria-label="One fewer">
            <MinusIcon />
          </Button>
          <NumberFlow className="w-8 text-center font-medium" value={qty} />
          <Button variant="ghost" size="icon-sm" onClick={() => setQty((q) => Math.min(99, q + 1))} aria-label="One more">
            <PlusIcon />
          </Button>
        </div>
      </div>
      <NumberFlowGroup>
        <div className="rounded-lg border px-3">
          <Row label="Subtotal">
            <NumberFlow value={subtotal} locales="en-MY" format={MYR} />
          </Row>
          <Row label="Volume discount">
            <NumberFlow
              className={cn(discount > 0 && "text-emerald-600 dark:text-emerald-400")}
              value={discount > 0 ? -discount : 0}
              locales="en-MY"
              format={MYR}
            />
          </Row>
          <Row label={<span className="font-medium text-foreground">Total</span>}>
            <NumberFlow className="text-lg font-semibold" value={total} locales="en-MY" format={MYR} />
          </Row>
        </div>
      </NumberFlowGroup>
      <Controls>
        <Button variant="outline" size="sm" onClick={() => setQty((q) => (q >= 10 ? 6 : 12))}>
          Jump across the discount tier
        </Button>
      </Controls>
    </div>
  )
}

/* -------------------------------------------------------------- 3. Options */

function TrendDemo() {
  const [v, setV] = useState(482)
  const rows: { label: string; trend?: number }[] = [
    { label: "default (direction of change)" },
    { label: "trend={1} always rolls up" },
    { label: "trend={-1} always rolls down" },
    { label: "trend={0} each digit on its own" },
  ]
  return (
    <div className="flex w-full flex-col gap-3">
      <div className="rounded-lg border px-3">
        {rows.map((r) => (
          <Row key={r.label} label={<code>{r.label}</code>}>
            <NumberFlow className="text-xl font-semibold" value={v} trend={r.trend} />
          </Row>
        ))}
      </div>
      <Controls>
        <Button variant="outline" size="sm" onClick={() => setV((x) => x + 19)}>
          +19
        </Button>
        <Button variant="outline" size="sm" onClick={() => setV((x) => x - 19)}>
          −19
        </Button>
        <Shuffle onClick={() => setV(randInt(100, 999))} />
      </Controls>
    </div>
  )
}

function ContinuousDemo() {
  const [v, setV] = useState(120)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="grid grid-cols-2 gap-3 text-center">
        <div className="rounded-lg border p-3">
          <div className="text-xs text-muted-foreground">default</div>
          <NumberFlow className="text-4xl font-semibold" value={v} />
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-muted-foreground">
            <code>plugins={"{[continuous]}"}</code>
          </div>
          <NumberFlow className="text-4xl font-semibold" value={v} plugins={[continuous]} />
        </div>
      </div>
      <Controls>
        <Button variant="outline" size="sm" onClick={() => setV((x) => (x === 120 ? 199 : 120))}>
          120 ↔ 199
        </Button>
        <Button variant="outline" size="sm" onClick={() => setV((x) => (x === 120 ? 1020 : 120))}>
          120 ↔ 1,020
        </Button>
        <Shuffle onClick={() => setV(randInt(0, 2000))} />
      </Controls>
    </div>
  )
}

function PriceRange({ lo, hi }: { lo: number; hi: number }) {
  return (
    <div className="flex items-baseline gap-1.5 text-2xl font-semibold">
      <NumberFlow value={lo} locales="en-MY" format={MYR} />
      <span className="text-muted-foreground">–</span>
      <NumberFlow value={hi} locales="en-MY" format={MYR} />
      <span className="text-sm font-normal text-muted-foreground">per carton</span>
    </div>
  )
}

function GroupDemo() {
  const [range, setRange] = useState({ lo: 9.9, hi: 49.9 })
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="flex flex-col gap-3 rounded-lg border p-3">
        <div className="text-xs text-muted-foreground">Two separate NumberFlows</div>
        <PriceRange {...range} />
      </div>
      <div className="flex flex-col gap-3 rounded-lg border p-3">
        <div className="text-xs text-muted-foreground">
          Same two, wrapped in <code>&lt;NumberFlowGroup&gt;</code>
        </div>
        <NumberFlowGroup>
          <PriceRange {...range} />
        </NumberFlowGroup>
      </div>
      <Controls>
        <Button
          variant="outline"
          size="sm"
          onClick={() => setRange((r) => (r.hi < 100 ? { lo: 129, hi: 1249 } : { lo: 9.9, hi: 49.9 }))}
        >
          Change width of both
        </Button>
        <Shuffle onClick={() => setRange({ lo: round(rand(1, 120)), hi: round(rand(150, 2500)) })} />
      </Controls>
    </div>
  )
}

const easings = {
  library: { label: "Library default", value: undefined },
  "ease-out": { label: "ease-out", value: "ease-out" },
  linear: { label: "linear", value: "linear" },
  overshoot: { label: "Overshoot", value: "cubic-bezier(0.34, 1.56, 0.64, 1)" },
} as const

function TimingDemo() {
  const [v, setV] = useState(2_480)
  const [duration, setDuration] = useState(900)
  const [easing, setEasing] = useState<keyof typeof easings>("library")
  const [animated, setAnimated] = useState(true)
  const reduced = usePrefersReducedMotion()
  const canAnimate = useCanAnimate()
  const e = easings[easing].value
  const timing = e ? { transformTiming: { duration, easing: e }, spinTiming: { duration, easing: e } } : {}
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="text-center">
        <NumberFlow className="text-5xl font-semibold" value={v} locales="en-MY" animated={animated} {...timing} />
      </div>
      <div className="flex flex-col gap-3 text-sm">
        <Tabs value={easing} onValueChange={(x) => setEasing(x as keyof typeof easings)}>
          <TabsList className="w-full">
            {Object.entries(easings).map(([k, o]) => (
              <TabsTrigger key={k} value={k}>
                {o.label}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
        <div className={cn("flex items-center gap-3", !e && "opacity-50")}>
          <span className="w-28 shrink-0 text-xs text-muted-foreground">Duration {duration} ms</span>
          <Slider
            min={150}
            max={2500}
            step={50}
            className="flex-1"
            value={[duration]}
            disabled={!e}
            onValueChange={(x) => setDuration(typeof x === "number" ? x : x[0])}
          />
        </div>
        <label className="flex items-center gap-2">
          <Switch checked={animated} onCheckedChange={setAnimated} />
          <code>animated</code>
          <span className="ml-auto text-xs text-muted-foreground">
            reduced motion: {reduced ? "on" : "off"} · useCanAnimate(): {String(canAnimate)}
          </span>
        </label>
      </div>
      <Controls>
        <Shuffle onClick={() => setV(randInt(100, 99_999))} />
      </Controls>
    </div>
  )
}

/* --------------------------------------------------- 4. Three libraries */

type Shared = { units: number; basket: number; delta: number }

function useSharedNumbers() {
  const [s, setS] = useState<Shared>({ units: 12_480, basket: 42.35, delta: 3.2 })
  return {
    s,
    small: () =>
      setS((x) => ({
        units: x.units + randInt(3, 60),
        basket: round(x.basket + rand(-0.6, 0.6)),
        delta: round(x.delta + rand(-0.4, 0.4), 1),
      })),
    big: () =>
      setS({
        units: randInt(800, 2_400_000),
        basket: round(rand(9, 480)),
        delta: round(rand(-12, 12), 1),
      }),
    flip: () => setS((x) => ({ ...x, delta: -x.delta })),
  }
}

/** Polls an element's textContent once a second: roughly what a screen reader gets when there is no ARIA. */
function useDomText() {
  const ref = useRef<HTMLDivElement>(null)
  const [text, setText] = useState("")
  useEffect(() => {
    const id = setInterval(() => setText(ref.current?.textContent?.replace(/\s+/g, " ").trim() ?? ""), 1000)
    return () => clearInterval(id)
  }, [])
  return { ref, text }
}

function DomReadout({ text }: { text: string }) {
  return (
    <div className="w-full truncate rounded-md bg-muted px-2 py-1 font-mono text-[11px] text-muted-foreground" title={text}>
      textContent: {text || "…"}
    </div>
  )
}

function CompareTile({ lib, s }: { lib: "flow" | "ticker" | "sliding"; s: Shared }) {
  const { ref, text } = useDomText()
  let body: ReactNode
  if (lib === "flow") {
    body = (
      <>
        <Row label="Units">
          <NumberFlow className="text-2xl font-semibold" value={s.units} locales="en-MY" />
        </Row>
        <Row label="Avg basket">
          <NumberFlow className="text-2xl font-semibold" value={s.basket} locales="en-MY" format={MYR} />
        </Row>
        <Row label="Change">
          <NumberFlow className="text-2xl font-semibold" value={s.delta / 100} format={PCT_DELTA} />
        </Row>
      </>
    )
  } else if (lib === "ticker") {
    body = (
      <>
        <Row label="Units">
          <NumberTicker className="text-2xl font-semibold tracking-normal" value={s.units} />
        </Row>
        <Row label="Avg basket">
          <span className="text-2xl font-semibold">
            RM&nbsp;
            <NumberTicker className="tracking-normal" value={s.basket} decimalPlaces={2} />
          </span>
        </Row>
        <Row label="Change">
          <span className="text-2xl font-semibold">
            <NumberTicker className="tracking-normal" value={s.delta} decimalPlaces={1} />%
          </span>
        </Row>
      </>
    )
  } else {
    body = (
      <>
        <Row label="Units">
          <SlidingNumber className="text-2xl font-semibold" number={s.units} thousandSeparator="," />
        </Row>
        <Row label="Avg basket">
          <span className="inline-flex items-center text-2xl font-semibold">
            RM&nbsp;
            <SlidingNumber number={s.basket} decimalPlaces={2} thousandSeparator="," />
          </span>
        </Row>
        <Row label="Change">
          <span className="inline-flex items-center text-2xl font-semibold">
            <SlidingNumber number={s.delta} decimalPlaces={1} />%
          </span>
        </Row>
      </>
    )
  }
  return (
    <div className="flex w-full flex-col gap-3">
      <div ref={ref} className="rounded-lg border px-3">
        {body}
      </div>
      <DomReadout text={text} />
    </div>
  )
}

function ThreeLibraries() {
  const { s, small, big, flip } = useSharedNumbers()
  return (
    <>
      <Variant label="One set of numbers, three renderers" className="md:col-span-3" stageClassName="min-h-0 py-4">
        <Controls>
          <Button variant="outline" size="sm" onClick={small}>
            <RefreshCwIcon data-icon="inline-start" />
            Small change
          </Button>
          <Shuffle onClick={big}>Big jump</Shuffle>
          <Button variant="outline" size="sm" onClick={flip}>
            Flip the sign
          </Button>
        </Controls>
      </Variant>
      <Variant
        label="NumberFlow"
        lib="@number-flow/react"
        stageClassName="items-start"
        hint="Intl does the formatting: RM, the + sign and % come out of format. Screen readers get one aria-label, not digits."
      >
        <CompareTile lib="flow" s={s} />
      </Variant>
      <Variant
        label="NumberTicker"
        lib="Magic UI"
        stageClassName="items-start"
        hint="Counts through every value on a spring. en-US formatting is hard-coded; RM and % are hand-placed. No + sign."
      >
        <CompareTile lib="ticker" s={s} />
      </Variant>
      <Variant
        label="SlidingNumber"
        lib="Animate UI"
        stageClassName="items-start"
        hint="Odometer rollers per digit. Each position keeps all ten digits in the DOM, so plain text reads as noise."
      >
        <CompareTile lib="sliding" s={s} />
      </Variant>
    </>
  )
}

/* ------------------------------------------------------- 5. Dashboard row */

const periods = {
  today: { label: "Today", sales: 214_380, orders: 1_284, fill: 0.962, d: [0.042, 0.018, 0.024, -0.004] },
  mtd: { label: "Month to date", sales: 4_812_640, orders: 27_910, fill: 0.948, d: [0.081, 0.052, 0.027, 0.011] },
  ytd: { label: "Year to date", sales: 51_406_200, orders: 311_455, fill: 0.931, d: [0.124, 0.097, 0.025, -0.012] },
} as const
type Period = keyof typeof periods

function KpiCard({ title, delta, children }: { title: string; delta: number; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-1 rounded-xl border bg-background p-4">
      <div className="flex items-center justify-between gap-2">
        <span className="text-sm text-muted-foreground">{title}</span>
        <TrendDelta value={delta} className="text-xs" />
      </div>
      {children}
    </div>
  )
}

function DashboardRow() {
  const [period, setPeriod] = useState<Period>("mtd")
  const [jitter, setJitter] = useState(1)
  const p = periods[period]
  const sales = Math.round(p.sales * jitter)
  const orders = Math.round(p.orders * jitter)
  return (
    <div className="flex w-full flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="font-medium">Peninsular Malaysia · all channels</div>
          <div className="text-xs text-muted-foreground">Compared with the same period last year</div>
        </div>
        <div className="flex items-center gap-2">
          <Tabs value={period} onValueChange={(x) => setPeriod(x as Period)}>
            <TabsList>
              {Object.entries(periods).map(([k, o]) => (
                <TabsTrigger key={k} value={k}>
                  {o.label}
                </TabsTrigger>
              ))}
            </TabsList>
          </Tabs>
          <Button variant="outline" size="icon-sm" aria-label="Refresh" onClick={() => setJitter(rand(0.97, 1.03))}>
            <RefreshCwIcon />
          </Button>
        </div>
      </div>
      <NumberFlowGroup>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <KpiCard title="Net sales" delta={p.d[0]}>
            <NumberFlow className="text-3xl font-semibold tracking-tight" value={sales} locales="en-MY" format={MYR0} />
          </KpiCard>
          <KpiCard title="Orders" delta={p.d[1]}>
            <NumberFlow className="text-3xl font-semibold tracking-tight" value={orders} locales="en-MY" />
          </KpiCard>
          <KpiCard title="Avg order value" delta={p.d[2]}>
            <NumberFlow className="text-3xl font-semibold tracking-tight" value={sales / orders} locales="en-MY" format={MYR} />
          </KpiCard>
          <KpiCard title="Fill rate" delta={p.d[3]}>
            <NumberFlow className="text-3xl font-semibold tracking-tight" value={p.fill} format={PCT} />
          </KpiCard>
        </div>
      </NumberFlowGroup>
    </div>
  )
}

/* -------------------------------------------------------------------- page */

export default function NumbersPage() {
  return (
    <Page
      title="Animated numbers"
      intro="NumberFlow against the two other ways we already have to animate a number: Magic UI's NumberTicker and Animate UI's SlidingNumber. Every tile has a button that changes the value, because the animation only shows on change."
      libs={[
        { name: "NumberFlow", status: "playbook", url: "https://number-flow.barvian.me", install: "npm i @number-flow/react" },
        { name: "Magic UI NumberTicker", status: "playbook", url: "https://magicui.design/docs/components/number-ticker", install: "shadcn add @magicui/number-ticker" },
        { name: "Animate UI SlidingNumber", status: "candidate", url: "https://animate-ui.com/docs/primitives/texts/sliding-number", install: "shadcn add @animate-ui/primitives-texts-sliding-number" },
      ]}
    >
      <Section
        title="KPI tiles"
        description="The formats a sales dashboard needs: ringgit, percentages with a direction, compact counts. All formatting is Intl.NumberFormat passed through the format and locales props."
      >
        <Variant label="Ringgit" lib="NumberFlow" hint={<>locales="en-MY" + currency MYR gives "RM 1,284,531". Compact gives "RM 1.3M".</>}>
          <CurrencyTile />
        </Variant>
        <Variant label="Percent with a trend" lib="NumberFlow" hint="signDisplay: always adds the + sign. The arrow is a separate motion.span; NumberFlow has no trend icon of its own.">
          <PercentTile />
        </Variant>
        <Variant label="Compact notation" lib="NumberFlow" hint="Watch K turn into M: the suffix fades while digits roll. scientific and engineering notation are not supported.">
          <CompactTile />
        </Variant>
        <Variant label="Malaysian locales" lib="NumberFlow" hint={<>Switching locale animates too. Watch compact: ms-MY says "1.5J" (juta), zh-MY says "149.6万" and writes MYR instead of RM. Pin locales="en-MY" in apps.</>}>
          <LocaleTile />
        </Variant>
      </Section>

      <Section title="Live and interactive" description="Values that change on their own or follow a control, which is where animated numbers earn their keep in an app.">
        <Variant label="Live counter" lib="NumberFlow" hint="Ticks every 1.4 s. Both tiles sit in one NumberFlowGroup so their animations stay in step.">
          <LiveCounter />
        </Variant>
        <Variant label="Price follows a plan toggle" lib="NumberFlow" hint="suffix=&quot;/mo&quot; is part of the animated string. Changing currency swaps the symbol with a fade.">
          <PlanPrice />
        </Variant>
        <Variant label="Cart stepper" lib="NumberFlow" className="md:col-span-2" hint="Quantity, subtotal, discount and total in one group: when the discount tier kicks in, all four move together.">
          <CartStepper />
        </Variant>
      </Section>

      <Section title="Options worth knowing" description="trend, the continuous plugin, NumberFlowGroup and the timing props. Try each with the buttons under it.">
        <Variant label="trend" lib="NumberFlow">
          <TrendDemo />
        </Variant>
        <Variant label="continuous plugin" lib="NumberFlow" hint="With continuous, 120 → 199 passes through 130, 140… instead of each digit spinning on its own.">
          <ContinuousDemo />
        </Variant>
        <Variant label="NumberFlowGroup" lib="NumberFlow" hint="Without the group, the second number jumps sideways when the first one grows. With it, both slide together.">
          <GroupDemo />
        </Variant>
        <Variant label="Timing" lib="NumberFlow" hint="transformTiming and spinTiming take Web Animations timing objects. animated={false} snaps.">
          <TimingDemo />
        </Variant>
      </Section>

      <Section
        title="Same numbers, three libraries"
        description="One state drives all three. The grey line under each is the element's textContent, read once a second: what assistive tech falls back to when there is no aria-label."
        className="md:grid-cols-3"
      >
        <ThreeLibraries />
      </Section>

      <Section title="A dashboard row" description="Four KPI cards with period tabs, as they would sit at the top of a sales portal. One NumberFlowGroup wraps the row.">
        <Variant label="Sales overview" lib="NumberFlow" className="md:col-span-2" stageClassName="bg-muted/30">
          <DashboardRow />
        </Variant>
      </Section>

      <Findings
        notes={[
          { tone: "good", text: <>NumberFlow formats through Intl.NumberFormat, so RM, percentages with a sign, compact "1.2M" and Malaysian locales come from props, with no string building. <code>prefix</code>/<code>suffix</code> cover "/mo".</> },
          { tone: "good", text: <>Accessible by default: the element exposes one aria-label with the final value (role img), and it honours prefers-reduced-motion unless you set <code>respectMotionPreference={"{false}"}</code>. <code>useCanAnimate()</code> tells you which case you are in. Checked in headless Chrome with reduced motion emulated: this page's main-thread work fell from ~157 to ~18 ms/s because every NumberFlow snapped instead of animating.</> },
          { tone: "good", text: <><code>NumberFlowGroup</code> is the feature the others lack: numbers that sit side by side (price ranges, totals, KPI rows) move together instead of shoving each other.</> },
          { tone: "note", text: <>It is a web component with a shadow root. Tailwind classes on it set font, size and colour; inner parts need <code>::part()</code> or its CSS variables. Fine for us, but not "just a span".</> },
          { tone: "note", text: <>No scientific/engineering notation and no bigint. The trend arrow, colours and badge are ours to build; NumberFlow only does the number.</> },
          { tone: "bad", text: <>Magic UI NumberTicker hard-codes en-US formatting with no currency, percent, sign or compact options, so RM and % get hand-placed outside it. Its spring (damping 60) is heavily overdamped: after a big jump it was still ~2,000 short four seconds later. It writes textContent on every frame, starts from 0 only once it scrolls into view, and ignores prefers-reduced-motion (motion's useSpring). OK for a marketing "stats" band; not for app KPIs.</> },
          { tone: "bad", text: <>Animate UI SlidingNumber keeps all ten digits of every position in the DOM, so the plain text reads as a run of digits (see the grey line) and it sets no aria-label. It has no Intl support (separator and decimals only), renders negatives as "- 0.3" with a gap, and has no reduced-motion handling.</> },
          { tone: "note", text: <>Recommendation: keep NumberFlow as the one Playbook pick for animated numbers in apps and dashboards. Use NumberTicker only for count-up stats on landing pages. Don't add SlidingNumber.</> },
        ]}
      />
    </Page>
  )
}

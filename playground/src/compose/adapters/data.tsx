// Data components: KPI number, chart, activity feed.
import { useCallback, useEffect, useId, useRef, useState, type ReactNode } from "react"
import NumberFlow, { NumberFlowGroup, type Format } from "@number-flow/react"
import {
  ArrowUpIcon,
  BanknoteIcon,
  PackageIcon,
  PauseIcon,
  PlayIcon,
  PlusIcon,
  ShoppingCartIcon,
  Undo2Icon,
  type LucideIcon,
} from "lucide-react"
import { Area, AreaChart, Bar, BarChart, CartesianGrid, Line, LineChart, XAxis, YAxis } from "recharts"
import { SlidingNumber } from "@/components/animate-ui/primitives/texts/sliding-number"
import Stats05 from "@/components/stats-05"
import { AnimatedList } from "@/components/ui/animated-list"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  ChartContainer,
  ChartLegend,
  ChartLegendContent,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart"
import { NumberTicker } from "@/components/ui/number-ticker"
import { customers, rm, skus, warehouses } from "@/demos/app/data"
import { cn } from "@/lib/utils"
import type { Adapter, BlockProps, Option } from "../types"

/* ------------------------------------------------------------------------------------------------
 * KPI number
 * ---------------------------------------------------------------------------------------------- */

const TARGET = 250_000
/** Net sales at the same time yesterday: the trend compares against it. */
const YESTERDAY = 212_000

const round = (n: number, dp = 2) => Math.round(n * 10 ** dp) / 10 ** dp

type KpiFormat = "currency" | "percent" | "compact"

const MYR: Format = { style: "currency", currency: "MYR" }
const MYR_COMPACT: Format = { style: "currency", currency: "MYR", notation: "compact", maximumFractionDigits: 1 }
const PCT: Format = { style: "percent", maximumFractionDigits: 1 }
const PCT_DELTA: Format = { ...PCT, signDisplay: "always" }
const formats: Record<KpiFormat, Format> = { currency: MYR, percent: PCT, compact: MYR_COMPACT }

const kpiTitle: Record<KpiFormat, string> = {
  currency: "Net sales today",
  percent: "Net sales vs daily target (RM 250,000)",
  compact: "Net sales today",
}

type Last = { order: string | null; customer: string; amount: number }

type Kpi = {
  sales: number
  orders: number
  /** Change against the same time yesterday, as a fraction. */
  delta: number
  /** Share of the daily target, as a fraction. */
  attainment: number
  last: Last
  newOrder: () => void
  addReturn: () => void
}

/** One day's sales for a Shah Alam DC dashboard. "New order" adds, "Return" takes a credit note off. */
function useKpi(auto: boolean): Kpi {
  const [s, setS] = useState({
    sales: 214_380.4,
    orders: 1_284,
    seq: 4821,
    last: { order: "#4821", customer: "Mydin Subang Jaya", amount: 2_665.2 } as Last,
  })
  const add = useCallback((sign: 1 | -1) => {
    const amount = round(sign > 0 ? 180 + Math.random() * 4_000 : 1_500 + Math.random() * 3_500)
    setS((x) => {
      const seq = sign > 0 ? x.seq + 1 : x.seq
      return {
        sales: round(x.sales + sign * amount),
        orders: x.orders + (sign > 0 ? 1 : 0),
        seq,
        last: {
          order: sign > 0 ? `#${seq}` : null,
          customer: customers[(seq + (sign > 0 ? 0 : 3)) % customers.length].name,
          amount: sign * amount,
        },
      }
    })
  }, [])
  useEffect(() => {
    if (!auto) return
    const t = setInterval(() => add(1), 1600)
    return () => clearInterval(t)
  }, [auto, add])
  return {
    ...s,
    delta: s.sales / YESTERDAY - 1,
    attainment: s.sales / TARGET,
    newOrder: () => add(1),
    addReturn: () => add(-1),
  }
}

/** The same tile for every library, so only the number differs. */
function KpiTile({ kpi, title, auto, children }: { kpi: Kpi; title: string; auto: boolean; children: ReactNode }) {
  const up = kpi.last.amount >= 0
  return (
    <div className="flex flex-col gap-4 rounded-lg border bg-card p-4 sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0">
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          {title}
          {auto && (
            <span className="inline-flex items-center gap-1 text-xs">
              <span className="size-1.5 rounded-full bg-emerald-500 motion-safe:animate-pulse" />
              Live
            </span>
          )}
        </div>
        <div className="mt-1 flex flex-wrap items-baseline gap-x-3 gap-y-1">{children}</div>
        <div className="mt-2 truncate text-xs text-muted-foreground">
          {kpi.last.order ? `Order ${kpi.last.order}` : "Credit note"} · {kpi.last.customer} ·{" "}
          <span className={up ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}>
            {up ? "+" : "−"}
            {rm(Math.abs(kpi.last.amount))}
          </span>
        </div>
      </div>
      <div className="flex shrink-0 gap-2">
        <Button variant="outline" size="sm" onClick={kpi.addReturn}>
          <Undo2Icon data-icon="inline-start" />
          Return
        </Button>
        <Button size="sm" onClick={kpi.newOrder}>
          <PlusIcon data-icon="inline-start" />
          New order
        </Button>
      </div>
    </div>
  )
}

/** Arrow and colour by direction. CSS only, so it adds no Motion dependency to any adapter. */
function Trend({ up, children }: { up: boolean; children: ReactNode }) {
  return (
    <span className="inline-flex items-baseline gap-1.5">
      <span
        className={cn(
          "inline-flex items-center gap-0.5 text-sm font-medium tabular-nums",
          up ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400",
        )}
      >
        <ArrowUpIcon
          aria-hidden
          className={cn("size-3.5 self-center transition-transform duration-300 motion-reduce:transition-none", !up && "rotate-180")}
        />
        {children}
      </span>
      <span className="text-xs text-muted-foreground">vs yesterday</span>
    </span>
  )
}

const formatOption = (withCompact: boolean): Option => ({
  id: "format",
  label: "Format",
  type: "select",
  default: "currency",
  choices: [
    { value: "currency", label: "RM" },
    { value: "percent", label: "% of target" },
    ...(withCompact ? [{ value: "compact", label: "Compact (RM 214K)" }] : []),
  ],
})
const trendOption: Option = { id: "trend", label: "Trend vs yesterday", type: "switch", default: true }
const autoOption: Option = { id: "auto", label: "Orders arrive on their own", type: "switch", default: false }

function NumberFlowKpi({ options: o }: BlockProps) {
  const auto = o.auto as boolean
  const kpi = useKpi(auto)
  const format = o.format as KpiFormat
  return (
    <KpiTile kpi={kpi} title={kpiTitle[format]} auto={auto}>
      <NumberFlowGroup>
        <NumberFlow
          className="text-4xl font-semibold tracking-tight"
          value={format === "percent" ? kpi.attainment : kpi.sales}
          locales="en-MY"
          format={formats[format]}
        />
        {o.orders && <NumberFlow className="text-sm text-muted-foreground" value={kpi.orders} locales="en-MY" suffix=" orders" />}
        {o.trend && (
          <Trend up={kpi.delta >= 0}>
            <NumberFlow value={kpi.delta} locales="en-MY" format={PCT_DELTA} />
          </Trend>
        )}
      </NumberFlowGroup>
    </KpiTile>
  )
}

function TickerKpi({ options: o }: BlockProps) {
  const auto = o.auto as boolean
  const kpi = useKpi(auto)
  const pct = o.format === "percent"
  const up = kpi.delta >= 0
  return (
    <KpiTile kpi={kpi} title={kpiTitle[pct ? "percent" : "currency"]} auto={auto}>
      <span className="text-4xl font-semibold tracking-tight">
        {!pct && "RM "}
        {/* Keyed on format: decimalPlaces only takes effect on the next change, so remount instead. */}
        <NumberTicker
          key={String(o.format)}
          className="tracking-tight"
          value={pct ? round(kpi.attainment * 100, 1) : kpi.sales}
          decimalPlaces={pct ? 1 : 2}
        />
        {pct && "%"}
      </span>
      {o.trend && (
        <Trend up={up}>
          <span>
            {up ? "+" : "−"}
            <NumberTicker className="tracking-normal text-current dark:text-current" value={Math.abs(round(kpi.delta * 100, 1))} decimalPlaces={1} />%
          </span>
        </Trend>
      )}
    </KpiTile>
  )
}

function SlidingKpi({ options: o }: BlockProps) {
  const auto = o.auto as boolean
  const kpi = useKpi(auto)
  const pct = o.format === "percent"
  const up = kpi.delta >= 0
  const value = pct ? round(kpi.attainment * 100, 1) : kpi.sales
  const change = Math.abs(round(kpi.delta * 100, 1))
  // SlidingNumber sets no label and keeps ten digits per position in the DOM: label each wrapper ourselves.
  return (
    <KpiTile kpi={kpi} title={kpiTitle[pct ? "percent" : "currency"]} auto={auto}>
      <span
        role="img"
        aria-label={pct ? `${value}% of target` : rm(value)}
        className="inline-flex items-center text-4xl font-semibold tracking-tight"
      >
        {!pct && "RM\u00a0"}
        <SlidingNumber key={String(o.format)} number={value} decimalPlaces={pct ? 1 : 2} thousandSeparator="," />
        {pct && "%"}
      </span>
      {o.trend && (
        <Trend up={up}>
          <span role="img" aria-label={`${up ? "up" : "down"} ${change}%`} className="inline-flex items-center">
            {up ? "+" : "−"}
            <SlidingNumber number={Math.abs(round(kpi.delta * 100, 1))} decimalPlaces={1} />%
          </span>
        </Trend>
      )}
    </KpiTile>
  )
}

const intl = Object.fromEntries(
  Object.entries(formats).map(([k, f]) => [k, new Intl.NumberFormat("en-MY", f)]),
) as Record<KpiFormat, Intl.NumberFormat>
const intlDelta = new Intl.NumberFormat("en-MY", PCT_DELTA)

function PlainKpi({ options: o }: BlockProps) {
  const auto = o.auto as boolean
  const kpi = useKpi(auto)
  const format = o.format as KpiFormat
  const up = kpi.delta >= 0
  return (
    <KpiTile kpi={kpi} title={kpiTitle[format]} auto={auto}>
      <span className="text-4xl font-semibold tracking-tight tabular-nums">
        {intl[format].format(format === "percent" ? kpi.attainment : kpi.sales)}
      </span>
      {o.trend && (
        <span className="inline-flex items-center gap-1.5">
          <Badge
            variant="outline"
            className={cn(
              "tabular-nums",
              up
                ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-700 dark:text-emerald-300"
                : "border-rose-500/30 bg-rose-500/10 text-rose-700 dark:text-rose-300",
            )}
          >
            <ArrowUpIcon aria-hidden className={cn(!up && "rotate-180")} />
            {intlDelta.format(kpi.delta)}
          </Badge>
          <span className="text-xs text-muted-foreground">vs yesterday</span>
        </span>
      )}
    </KpiTile>
  )
}

const valueFor = (o: Record<string, unknown>) => (o.format === "percent" ? "attainment" : "netSales")

/* ------------------------------------------------------------------------------------------------
 * Chart
 * ---------------------------------------------------------------------------------------------- */

/** Slots 1–3 of the lab's validated palette (see the Charts page), with separate light and dark steps. */
const S = {
  blue: { light: "#2a78d6", dark: "#3987e5" },
  orange: { light: "#eb6834", dark: "#d95926" },
  aqua: { light: "#1baf7a", dark: "#199e70" },
}

const channelConfig = {
  mt: { label: "Modern trade", theme: S.blue },
  gt: { label: "General trade", theme: S.orange },
  ecom: { label: "E-commerce", theme: S.aqua },
} satisfies ChartConfig

/** What base-nova ships: --chart-1…5 are greys. */
const greyConfig = {
  mt: { label: "Modern trade", color: "var(--chart-1)" },
  gt: { label: "General trade", color: "var(--chart-2)" },
  ecom: { label: "E-commerce", color: "var(--chart-3)" },
} satisfies ChartConfig

const channels = ["mt", "gt", "ecom"] as const

// Rolling 12 months of net sales in RM thousands. Nov has 11.11; Feb–Mar 2026 has CNY, Ramadan and Hari Raya.
const months = ["2025-11", "2025-12", "2026-01", "2026-02", "2026-03", "2026-04", "2026-05", "2026-06", "2026-07", "2026-08", "2026-09", "2026-10"]
const totals = [5780, 4860, 4760, 5890, 6820, 4700, 4830, 4980, 5100, 5180, 5050, 5210]
const ecomShare = [0.26, 0.18, 0.16, 0.18, 0.19, 0.17, 0.18, 0.18, 0.19, 0.2, 0.2, 0.21]
const gtShare = [0.3, 0.35, 0.35, 0.36, 0.37, 0.35, 0.34, 0.34, 0.33, 0.33, 0.33, 0.32]

const monthly = months.map((month, i) => {
  const total = totals[i]
  const ecom = Math.round(total * ecomShare[i])
  const gt = Math.round(total * gtShare[i])
  return { month, total, mt: total - ecom - gt, gt, ecom }
})

const rm0 = new Intl.NumberFormat("en-MY", { style: "currency", currency: "MYR", maximumFractionDigits: 0 })
const rmCompact = new Intl.NumberFormat("en-MY", { style: "currency", currency: "MYR", notation: "compact", maximumFractionDigits: 1 })
const fmtK = (k: number) => rm0.format(k * 1000)
const fmtKCompact = (k: number) => rmCompact.format(k * 1000)
const monthShort = (m: string) => new Date(`${m}-01T00:00:00`).toLocaleDateString("en-MY", { month: "short" })
const monthLong = (m: unknown) =>
  typeof m === "string" && /^\d{4}-\d{2}$/.test(m)
    ? new Date(`${m}-01T00:00:00`).toLocaleDateString("en-MY", { month: "long", year: "numeric" })
    : String(m ?? "")

/** ChartTooltipContent prints raw numbers; its formatter replaces the whole row, so rebuild it with ringgit. */
function MoneyRow({ name, value, color, config }: { name: unknown; value: unknown; color?: string; config: ChartConfig }) {
  const key = String(name)
  return (
    <div className="flex w-full items-center gap-2">
      <span className="size-2.5 shrink-0 rounded-[2px]" style={{ background: color }} />
      <span className="text-muted-foreground">{config[key]?.label ?? key}</span>
      <span className="ml-auto pl-3 font-mono font-medium text-foreground tabular-nums">{fmtK(Number(value))}</span>
    </div>
  )
}

const axisProps = { tickLine: false, axisLine: false, tickMargin: 8 } as const
const margin = { left: 4, right: 12, top: 8 }

type ChartType = "bar" | "area" | "line"

function ShadcnChart({ options: o }: BlockProps) {
  const type = o.type as ChartType
  const stacked = o.stacked as boolean
  const config: ChartConfig = o.palette === "theme" ? greyConfig : channelConfig
  const data = monthly.slice(-Number(o.months))
  const latest = data[data.length - 1]
  // Gradient ids are global to the page, so two chart blocks need their own.
  const uid = useId().replace(/[^a-zA-Z0-9]/g, "")

  const common = [
    <CartesianGrid key="grid" vertical={false} />,
    <XAxis key="x" dataKey="month" {...axisProps} tickFormatter={monthShort} />,
    <YAxis key="y" {...axisProps} width="auto" tickFormatter={fmtKCompact} />,
    <ChartTooltip
      key="tooltip"
      cursor={type === "bar" ? { fillOpacity: 0.5 } : true}
      content={
        <ChartTooltipContent
          labelFormatter={monthLong}
          formatter={(value, name, item) => <MoneyRow name={name} value={value} color={item.color ?? item.payload?.fill} config={config} />}
        />
      }
    />,
    <ChartLegend key="legend" itemSorter={null} content={<ChartLegendContent />} />,
  ]

  let chart
  if (type === "bar") {
    chart = (
      <BarChart accessibilityLayer data={data} barGap={2} barCategoryGap={stacked ? "30%" : "18%"} margin={margin}>
        {common}
        {channels.map((c, i) => (
          <Bar
            key={c}
            dataKey={c}
            stackId={stacked ? "a" : undefined}
            fill={`var(--color-${c})`}
            stroke="var(--card)"
            strokeWidth={stacked ? 2 : 0}
            radius={stacked ? (i === channels.length - 1 ? [4, 4, 0, 0] : 0) : [4, 4, 0, 0]}
          />
        ))}
      </BarChart>
    )
  } else if (type === "area" || stacked) {
    // Recharts' Line has no stackId, so a stacked line chart is an Area with no fill.
    const line = type === "line"
    chart = (
      <AreaChart accessibilityLayer data={data} margin={margin}>
        <defs>
          {channels.map((c) => (
            <linearGradient key={c} id={`${uid}-${c}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor={`var(--color-${c})`} stopOpacity={stacked ? 0.55 : 0.35} />
              <stop offset="95%" stopColor={`var(--color-${c})`} stopOpacity={0.05} />
            </linearGradient>
          ))}
        </defs>
        {common}
        {channels.map((c) => (
          <Area
            key={c}
            dataKey={c}
            type="monotone"
            stackId={stacked ? "a" : undefined}
            stroke={`var(--color-${c})`}
            strokeWidth={2}
            fill={line ? "none" : `url(#${uid}-${c})`}
            dot={false}
            activeDot={{ r: 4, strokeWidth: 2, stroke: "var(--card)" }}
          />
        ))}
      </AreaChart>
    )
  } else {
    chart = (
      <LineChart accessibilityLayer data={data} margin={margin}>
        {common}
        {channels.map((c) => (
          <Line
            key={c}
            dataKey={c}
            type="monotone"
            stroke={`var(--color-${c})`}
            strokeWidth={2}
            dot={false}
            activeDot={{ r: 4, strokeWidth: 2, stroke: "var(--card)" }}
          />
        ))}
      </LineChart>
    )
  }

  return (
    <div className="flex flex-col gap-3 rounded-lg border bg-card p-4">
      <div className="flex items-start justify-between gap-4">
        <div>
          <div className="text-sm font-medium">Net sales by channel</div>
          <div className="text-xs text-muted-foreground">
            {monthLong(data[0].month)} – {monthLong(latest.month)}
            {stacked ? " · stacked" : ""}
          </div>
        </div>
        <div className="text-right">
          <div className="text-xs text-muted-foreground">{monthLong(latest.month)}</div>
          <div className="text-sm font-semibold tabular-nums">{fmtK(latest.total)}</div>
        </div>
      </div>
      <ChartContainer config={config} className="aspect-auto h-52 w-full">
        {chart}
      </ChartContainer>
    </div>
  )
}

function chartCode(o: Record<string, unknown>) {
  const type = o.type as ChartType
  const stacked = o.stacked as boolean
  const asArea = type === "area" || (type === "line" && stacked)
  const Chart = type === "bar" ? "BarChart" : asArea ? "AreaChart" : "LineChart"
  const Series = type === "bar" ? "Bar" : asArea ? "Area" : "Line"
  const stack = stacked ? ` stackId="a"` : ""
  const series = channels
    .map((c) => {
      if (type === "bar") return `    <Bar dataKey="${c}"${stack} fill="var(--color-${c})" radius={${stacked ? (c === "ecom" ? "[4, 4, 0, 0]" : "0") : "[4, 4, 0, 0]"}} />`
      if (asArea)
        return `    <Area dataKey="${c}" type="monotone"${stack} stroke="var(--color-${c})" fill=${type === "line" ? `"none"` : `"var(--color-${c})" fillOpacity={0.3}`} />`
      return `    <Line dataKey="${c}" type="monotone" stroke="var(--color-${c})" strokeWidth={2} dot={false} />`
    })
    .join("\n")
  const config =
    o.palette === "theme"
      ? `// base-nova's --chart-1…5 are greys: three series look alike.
const config = {
  mt: { label: "Modern trade", color: "var(--chart-1)" },
  gt: { label: "General trade", color: "var(--chart-2)" },
  ecom: { label: "E-commerce", color: "var(--chart-3)" },
} satisfies ChartConfig`
      : `// A light and a dark colour per series; they switch with the .dark class.
const config = {
  mt: { label: "Modern trade", theme: { light: "#2a78d6", dark: "#3987e5" } },
  gt: { label: "General trade", theme: { light: "#eb6834", dark: "#d95926" } },
  ecom: { label: "E-commerce", theme: { light: "#1baf7a", dark: "#199e70" } },
} satisfies ChartConfig`
  return `import { ${Series}, ${Chart}, CartesianGrid, XAxis, YAxis } from "recharts"
import {
  ChartContainer,
  ChartLegend,
  ChartLegendContent,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart"

${config}

// monthly = [{ month: "2026-10", mt: 2449, gt: 1667, ecom: 1094 }, …] (last ${o.months} months)
<ChartContainer config={config} className="aspect-auto h-52 w-full">
  <${Chart} accessibilityLayer data={monthly}>
    <CartesianGrid vertical={false} />
    <XAxis dataKey="month" tickLine={false} axisLine={false} tickFormatter={monthShort} />
    <YAxis tickLine={false} axisLine={false} width="auto" tickFormatter={ringgitCompact} />
    {/* Its default row prints raw numbers: pass formatter to show RM */}
    <ChartTooltip content={<ChartTooltipContent />} />
${type === "line" && stacked ? "    {/* Line has no stackId: an unfilled Area stacks instead */}\n" : ""}${series}
    {/* Legends sort A–Z unless itemSorter is null */}
    <ChartLegend itemSorter={null} content={<ChartLegendContent />} />
  </${Chart}>
</ChartContainer>`
}

/* ------------------------------------------------------------------------------------------------
 * Activity feed
 * ---------------------------------------------------------------------------------------------- */

type FeedKind = "order" | "payment" | "stock" | "return"
type FeedEvent = { id: number; kind: FeedKind; title: string; body: string; at: string }

const kindStyle: Record<FeedKind, { icon: LucideIcon; tint: string }> = {
  order: { icon: ShoppingCartIcon, tint: "bg-sky-500/15 text-sky-600 dark:text-sky-400" },
  payment: { icon: BanknoteIcon, tint: "bg-emerald-500/15 text-emerald-600 dark:text-emerald-400" },
  stock: { icon: PackageIcon, tint: "bg-amber-500/15 text-amber-600 dark:text-amber-400" },
  return: { icon: Undo2Icon, tint: "bg-rose-500/15 text-rose-600 dark:text-rose-400" },
}

const cycle: FeedKind[] = ["order", "payment", "order", "stock", "order", "return"]
const lowStock = skus.filter((s) => s.onHand < 200)

function makeEvent(n: number, ordersOnly: boolean): FeedEvent {
  const kind = ordersOnly ? "order" : cycle[n % cycle.length]
  const c = customers[(n * 3) % customers.length]
  const at = new Date().toLocaleTimeString("en-MY", { hour: "numeric", minute: "2-digit", second: "2-digit" })
  const amount = 180 + ((n * 7_919) % 9_000) + ((n * 37) % 100) / 100
  switch (kind) {
    case "order":
      return { id: n, kind, at, title: `New order #${4821 + n} · ${rm(amount)}`, body: `${c.name} · ${c.terms}` }
    case "payment":
      return { id: n, kind, at, title: `Payment received · ${rm(amount * 3)}`, body: `${c.name} · INV-${30_400 + n}` }
    case "stock": {
      const s = lowStock[n % lowStock.length]
      const w = warehouses[n % warehouses.length]
      return { id: n, kind, at, title: `${s.onHand === 0 ? "Out of stock" : "Low stock"} · ${s.name}`, body: `${w.name} · ${s.onHand} left` }
    }
    case "return":
      return { id: n, kind, at, title: `Return requested · ${rm(amount / 4)}`, body: `${c.name} · ${2 + (n % 6)} cartons damaged` }
  }
}

function useFeed(every: string, ordersOnly: boolean, keep: number) {
  const seq = useRef(0)
  const [events, setEvents] = useState<FeedEvent[]>(() => [1, 2, 3].map(() => makeEvent(++seq.current, ordersOnly)))
  const [running, setRunning] = useState(true)
  const push = useCallback(() => {
    const e = makeEvent(++seq.current, ordersOnly)
    setEvents((xs) => [...xs, e].slice(-keep))
  }, [ordersOnly, keep])
  const manual = every === "manual"
  useEffect(() => {
    if (manual || !running) return
    const t = setInterval(push, Number(every))
    return () => clearInterval(t)
  }, [manual, running, every, push])
  return { events, push, running, setRunning, manual }
}

type Feed = ReturnType<typeof useFeed>

function FeedHeader({ feed }: { feed: Feed }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <div>
        <div className="flex items-center gap-2 text-sm font-medium">
          Live activity
          {!feed.manual && (
            <span className={cn("size-1.5 rounded-full", feed.running ? "bg-emerald-500 motion-safe:animate-pulse" : "bg-muted-foreground/40")} />
          )}
        </div>
        <div className="text-xs text-muted-foreground">Shah Alam DC · today</div>
      </div>
      <div className="flex items-center gap-1">
        {!feed.manual && (
          <Button variant="ghost" size="icon-sm" aria-label={feed.running ? "Pause feed" : "Resume feed"} onClick={() => feed.setRunning((r) => !r)}>
            {feed.running ? <PauseIcon /> : <PlayIcon />}
          </Button>
        )}
        <Button variant="outline" size="sm" onClick={feed.push}>
          <PlusIcon data-icon="inline-start" />
          Add event
        </Button>
      </div>
    </div>
  )
}

function FeedRow({ e, time, badge, className }: { e: FeedEvent; time: boolean; badge?: ReactNode; className?: string }) {
  const { icon: Icon, tint } = kindStyle[e.kind]
  return (
    <div className={cn("flex w-full items-center gap-3", className)}>
      <span className={cn("flex size-8 shrink-0 items-center justify-center rounded-lg", tint)}>
        <Icon className="size-4" />
      </span>
      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-medium">{e.title}</div>
        <div className="truncate text-xs text-muted-foreground">{e.body}</div>
      </div>
      {badge}
      {time && <time className="shrink-0 text-[11px] text-muted-foreground tabular-nums">{e.at}</time>}
    </div>
  )
}

/** Keyed on the event filter, so switching it starts a fresh feed. */
function MagicFeed({ options }: BlockProps) {
  return <MagicFeedInner key={String(options.kinds)} options={options} />
}

function MagicFeedInner({ options: o }: BlockProps) {
  const feed = useFeed(o.every as string, o.kinds === "orders", 5)
  return (
    <div className="flex flex-col gap-3 rounded-lg border bg-card p-4">
      <FeedHeader feed={feed} />
      <div role="log" aria-label="Live activity" className="relative h-52 overflow-hidden">
        <AnimatedList delay={400} className="gap-2">
          {feed.events.map((e) => (
            <FeedRow key={e.id} e={e} time={o.time as boolean} className="rounded-lg border bg-background p-2.5 shadow-xs" />
          ))}
        </AnimatedList>
        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-12 bg-linear-to-t from-card" />
      </div>
    </div>
  )
}

function PlainFeed({ options }: BlockProps) {
  return <PlainFeedInner key={String(options.kinds)} options={options} />
}

function PlainFeedInner({ options: o }: BlockProps) {
  const feed = useFeed(o.every as string, o.kinds === "orders", 4)
  const newestFirst = [...feed.events].reverse()
  return (
    <div className="flex flex-col gap-3 rounded-lg border bg-card p-4">
      <FeedHeader feed={feed} />
      <ul role="log" aria-label="Live activity" className="divide-y rounded-lg border">
        {newestFirst.map((e, i) => {
          const fresh = i === 0 && (o.highlight as boolean)
          return (
            <li key={e.id} className={cn("px-3 py-2", fresh && "bg-muted/50")}>
              <FeedRow e={e} time={o.time as boolean} badge={fresh ? <Badge variant="secondary">New</Badge> : null} />
            </li>
          )
        })}
      </ul>
    </div>
  )
}

const feedOptions: Option[] = [
  {
    id: "every",
    label: "Events arrive",
    type: "select",
    default: "3000",
    choices: [
      { value: "1500", label: "Every 1.5 s" },
      { value: "3000", label: "Every 3 s" },
      { value: "manual", label: "Only on Add event" },
    ],
  },
  {
    id: "kinds",
    label: "Events",
    type: "select",
    default: "all",
    choices: [
      { value: "all", label: "Orders, payments, stock, returns" },
      { value: "orders", label: "Orders only" },
    ],
  },
  { id: "time", label: "Timestamps", type: "switch", default: true },
]

function feedState(o: Record<string, unknown>) {
  const filter = o.kinds === "orders" ? `\n    if (e.kind !== "order") return` : ""
  return o.every === "manual"
    ? `const [events, setEvents] = useState<OpsEvent[]>([])
const add = (e: OpsEvent) => setEvents((xs) => [...xs, e].slice(-5))`
    : `const [events, setEvents] = useState<OpsEvent[]>([])
useEffect(
  () =>
    subscribeToOps((e) => {${filter}
      setEvents((xs) => [...xs, e].slice(-5))
    }),
  [],
)`
}

/* ------------------------------------------------------------------------------------------------
 * Adapters
 * ---------------------------------------------------------------------------------------------- */

/** blocks.so's stats-05, untouched. Its "View more" links point at "#"; the lab ignores them. */
function StatsCards({ options }: BlockProps) {
  return (
    <div
      className={cn("[&_a]:pointer-events-none", !options.padding && "[&>div]:p-0")}
      onClickCapture={(e) => (e.target as HTMLElement).closest("a") && e.preventDefault()}
    >
      <Stats05 />
    </div>
  )
}

export const adapters: Adapter[] = [
  /* ---------------------------------------------------------------------------------- number */
  {
    id: "number-numberflow",
    slot: "number",
    library: "numberflow",
    label: "NumberFlow",
    note: "Rolls digits with Intl formatting, one aria-label, and snaps under reduced motion",
    options: [
      formatOption(true),
      trendOption,
      { id: "orders", label: "Order count, grouped", type: "switch", default: false },
      autoOption,
    ],
    install: ["npm i @number-flow/react"],
    code: (o) => {
      const format = o.format as KpiFormat
      const fmt =
        format === "percent"
          ? `{ style: "percent", maximumFractionDigits: 1 }`
          : format === "compact"
            ? `{ style: "currency", currency: "MYR", notation: "compact", maximumFractionDigits: 1 }`
            : `{ style: "currency", currency: "MYR" }`
      const grouped = Boolean(o.orders || o.trend)
      const pad = grouped ? "  " : ""
      const lines = [
        `${pad}<NumberFlow`,
        `${pad}  className="text-4xl font-semibold tracking-tight"`,
        `${pad}  value={${valueFor(o)}}`,
        `${pad}  locales="en-MY"`,
        `${pad}  format={${fmt}}`,
        `${pad}/>`,
      ]
      if (o.orders) lines.push(`${pad}<NumberFlow value={orders} locales="en-MY" suffix=" orders" />`)
      if (o.trend)
        lines.push(
          `${pad}{/* NumberFlow has no arrow: the icon and colour are yours */}`,
          `${pad}<NumberFlow value={vsYesterday} locales="en-MY" format={{ style: "percent", maximumFractionDigits: 1, signDisplay: "always" }} />`,
        )
      const body = grouped ? `{/* One group: when one number grows, the others slide with it */}\n<NumberFlowGroup>\n${lines.join("\n")}\n</NumberFlowGroup>` : lines.join("\n")
      return `import NumberFlow${grouped ? ", { NumberFlowGroup }" : ""} from "@number-flow/react"

// Pin the locale: ms-MY writes "RM 1.5J" and zh-MY writes "MYR".${o.auto ? "\n// Each new value animates; nothing to call." : ""}
${body}`
    },
    render: NumberFlowKpi,
  },
  {
    id: "number-magicui",
    slot: "number",
    library: "magicui",
    label: "NumberTicker",
    note: "Counts on a slow spring; en-US only, so RM and % sit outside it",
    options: [formatOption(false), trendOption, autoOption],
    traits: { pageKind: "marketing", ignoresReducedMotion: true },
    install: ["npx shadcn@latest add @magicui/number-ticker"],
    code: (o) => {
      const pct = o.format === "percent"
      return `import { NumberTicker } from "@/components/ui/number-ticker"

// en-US formatting only: no currency, percent, sign or compact. Counts up from 0 when scrolled into view.
<span className="text-4xl font-semibold tracking-tight">
  ${pct ? `<NumberTicker value={attainmentPct} decimalPlaces={1} />%` : `RM <NumberTicker value={netSales} decimalPlaces={2} />`}
</span>${
        o.trend
          ? `
{/* No sign either: place it yourself */}
<span className={up ? "text-emerald-600" : "text-rose-600"}>
  {up ? "+" : "−"}
  <NumberTicker value={Math.abs(vsYesterdayPct)} decimalPlaces={1} className="text-current dark:text-current" />%
</span>`
          : ""
      }`
    },
    render: TickerKpi,
  },
  {
    id: "number-animate-ui",
    slot: "number",
    library: "animate-ui",
    label: "SlidingNumber",
    note: "Odometer rollers per digit; no aria-label, so screen readers get every roller",
    options: [formatOption(false), trendOption, autoOption],
    traits: { ignoresReducedMotion: true, a11y: "poor" },
    install: ["npx shadcn@latest add @animate-ui/primitives-texts-sliding-number"],
    code: (o) => {
      const pct = o.format === "percent"
      return `import { SlidingNumber } from "@/components/animate-ui/primitives/texts/sliding-number"
import Stats05 from "@/components/stats-05"

// Separator and decimals only, no Intl. Every position keeps all ten digits in the DOM,
// so label the wrapper (role="img" hides the rollers) or screen readers read noise.
<span role="img" aria-label={${pct ? "`${attainmentPct}% of target`" : "rm(netSales)"}} className="inline-flex items-center text-4xl font-semibold">
  ${pct ? `<SlidingNumber number={attainmentPct} decimalPlaces={1} />%` : `RM&nbsp;<SlidingNumber number={netSales} decimalPlaces={2} thousandSeparator="," />`}
</span>${
        o.trend
          ? `
<span role="img" aria-label={\`\${up ? "up" : "down"} \${Math.abs(vsYesterdayPct)}% vs yesterday\`} className="inline-flex items-center">
  {up ? "+" : "−"}
  <SlidingNumber number={Math.abs(vsYesterdayPct)} decimalPlaces={1} />%
</span>`
          : ""
      }`
    },
    render: SlidingKpi,
  },
  {
    id: "number-shadcn",
    slot: "number",
    library: "shadcn",
    label: "Plain number",
    note: "Intl-formatted text that swaps instantly: the no-animation baseline",
    options: [formatOption(true), trendOption, autoOption],
    install: ["npx shadcn@latest add card badge"],
    code: (o) => {
      const format = o.format as KpiFormat
      const fmt =
        format === "percent"
          ? `{ style: "percent", maximumFractionDigits: 1 }`
          : format === "compact"
            ? `{ style: "currency", currency: "MYR", notation: "compact", maximumFractionDigits: 1 }`
            : `{ style: "currency", currency: "MYR" }`
      return `import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardDescription, CardHeader } from "@/components/ui/card"

const kpi = new Intl.NumberFormat("en-MY", ${fmt})${o.trend ? `\nconst change = new Intl.NumberFormat("en-MY", { style: "percent", maximumFractionDigits: 1, signDisplay: "always" })` : ""}

<Card>
  <CardHeader>
    <CardDescription>${kpiTitle[format]}</CardDescription>
  </CardHeader>
  <CardContent className="flex items-baseline gap-3">
    <span className="text-4xl font-semibold tracking-tight tabular-nums">{kpi.format(${valueFor(o)})}</span>${
      o.trend ? `\n    <Badge variant="outline">{change.format(vsYesterday)}</Badge>` : ""
    }
  </CardContent>
</Card>`
    },
    render: PlainKpi,
  },
  {
    id: "number-21st-stats",
    slot: "number",
    library: "21st",
    label: "Stats cards",
    note: "blocks.so's stats-05, found on 21st.dev and installed from blocks.so with no account",
    options: [{ id: "padding", label: "Keep its built-in p-10", type: "switch", default: true }],
    install: ["npx shadcn@latest add https://blocks.so/r/stats-05.json"],
    code: (o) => `import Stats05 from "@/components/stats-05"

// The file arrives with fixed sample data${o.padding ? " and p-10 on its wrapper" : ""}: edit it to take props.
<Stats05 />`,
    render: StatsCards,
  },

  /* ----------------------------------------------------------------------------------- chart */
  {
    id: "chart-shadcn-charts",
    slot: "chart",
    library: "shadcn-charts",
    label: "shadcn charts",
    note: "Recharts 3 with per-chart light/dark colours, a themed tooltip and keyboard access",
    options: [
      {
        id: "type",
        label: "Chart",
        type: "select",
        default: "bar",
        choices: [
          { value: "bar", label: "Bar" },
          { value: "area", label: "Area" },
          { value: "line", label: "Line" },
        ],
      },
      { id: "stacked", label: "Stacked", type: "switch", default: true },
      {
        id: "palette",
        label: "Colours",
        type: "select",
        default: "lab",
        choices: [
          { value: "lab", label: "Validated palette" },
          { value: "theme", label: "Theme --chart vars (greys)" },
        ],
      },
      {
        id: "months",
        label: "Range",
        type: "select",
        default: "12",
        choices: [
          { value: "6", label: "6 months" },
          { value: "12", label: "12 months" },
        ],
      },
    ],
    install: ["npx shadcn@latest add chart"],
    code: chartCode,
    render: ShadcnChart,
  },

  /* ------------------------------------------------------------------------------------ feed */
  {
    id: "feed-magicui",
    slot: "feed",
    library: "magicui",
    label: "AnimatedList",
    note: "Each new event springs in at the top; you keep the array yourself",
    options: feedOptions,
    install: ["npx shadcn@latest add @magicui/animated-list"],
    code: (o) => `import { AnimatedList } from "@/components/ui/animated-list"

// AnimatedList reveals its children one at a time and never loops.
// For a live feed, keep the newest few events in state; each new key springs in at the top.
${feedState(o)}

<AnimatedList delay={400} className="gap-2">
  {events.map((e) => (
    <div key={e.id} className="flex items-center gap-3 rounded-lg border bg-background p-2.5">
      <EventIcon kind={e.kind} />
      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-medium">{e.title}</div>
        <div className="truncate text-xs text-muted-foreground">{e.body}</div>
      </div>${o.time ? `\n      <time className="text-[11px] text-muted-foreground">{e.at}</time>` : ""}
    </div>
  ))}
</AnimatedList>`,
    render: MagicFeed,
  },
  {
    id: "feed-shadcn",
    slot: "feed",
    library: "shadcn",
    label: "Plain list",
    note: "A divided list where new events appear instantly, newest first",
    options: [...feedOptions, { id: "highlight", label: "Mark the newest", type: "switch", default: true }],
    install: ["npx shadcn@latest add badge"],
    code: (o) => `import { Badge } from "@/components/ui/badge"

${feedState(o)}

<ul role="log" aria-label="Live activity" className="divide-y rounded-lg border">
  {[...events].reverse().map((e, i) => (
    <li key={e.id} className="flex items-center gap-3 px-3 py-2${o.highlight ? ` data-[new]:bg-muted/50` : ""}"${o.highlight ? ` data-new={i === 0 || undefined}` : ""}>
      <EventIcon kind={e.kind} />
      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-medium">{e.title}</div>
        <div className="truncate text-xs text-muted-foreground">{e.body}</div>
      </div>${o.highlight ? `\n      {i === 0 && <Badge variant="secondary">New</Badge>}` : ""}${
        o.time ? `\n      <time className="text-[11px] text-muted-foreground">{e.at}</time>` : ""
      }
    </li>
  ))}
</ul>`,
    render: PlainFeed,
  },
]

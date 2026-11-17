import { useState, type ReactNode } from "react"
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Label,
  LabelList,
  Line,
  LineChart,
  Pie,
  PieChart,
  PolarAngleAxis,
  PolarGrid,
  PolarRadiusAxis,
  RadialBar,
  RadialBarChart,
  ReferenceLine,
  Sector,
  XAxis,
  YAxis,
  type PieSectorDataItem,
} from "recharts"
import {
  ChartContainer,
  ChartLegend,
  ChartLegendContent,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart"
import { Switch } from "@/components/ui/switch"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { cn } from "@/lib/utils"
import { Findings, Page, Section, Variant } from "@/playground/kit"

/* --------------------------------------------------------------- palette */

/**
 * Categorical slots 1–4 from the dataviz reference palette, with separate light and dark steps.
 * Validated (validate_palette.js): light on #fff and dark on #171717 pass lightness, chroma,
 * CVD (worst adjacent ΔE 9.1 light / 8.4 dark) and normal-vision checks. Light aqua and yellow sit
 * under 3:1 on white, so every multi-series chart keeps a legend and the bar chart has a table view.
 */
const S = {
  blue: { light: "#2a78d6", dark: "#3987e5" },
  orange: { light: "#eb6834", dark: "#d95926" },
  aqua: { light: "#1baf7a", dark: "#199e70" },
  yellow: { light: "#eda100", dark: "#c98500" },
  red: { light: "#e34948", dark: "#e66767" },
}

const brandConfig = {
  kopi: { label: "Kopi Senja", theme: S.blue },
  teh: { label: "Teh Puteri", theme: S.orange },
  suria: { label: "Suria Snacks", theme: S.aqua },
  ombak: { label: "Ombak", theme: S.yellow },
} satisfies ChartConfig
type Brand = keyof typeof brandConfig
const brands = Object.keys(brandConfig) as Brand[]

const channelConfig = {
  mt: { label: "Modern trade", theme: S.blue },
  gt: { label: "General trade", theme: S.orange },
  ecom: { label: "E-commerce", theme: S.aqua },
} satisfies ChartConfig
type Channel = keyof typeof channelConfig
const channels = Object.keys(channelConfig) as Channel[]

/** What the base-nova neutral theme gives you out of the box: five greys. */
const themeVarConfig = {
  mt: { label: "Modern trade", color: "var(--chart-1)" },
  gt: { label: "General trade", color: "var(--chart-2)" },
  ecom: { label: "E-commerce", color: "var(--chart-3)" },
} satisfies ChartConfig

/* ------------------------------------------------------------------ data */

// Rolling 12 complete months, net sales in RM thousands. Nov has 11.11; Feb–Mar 2026 has CNY, Ramadan and Hari Raya.
const months = ["2025-11", "2025-12", "2026-01", "2026-02", "2026-03", "2026-04", "2026-05", "2026-06", "2026-07", "2026-08", "2026-09", "2026-10"]
const brandSales: Record<Brand, number[]> = {
  kopi: [2150, 1820, 1760, 2140, 2480, 1690, 1740, 1780, 1810, 1860, 1830, 1900],
  teh: [1580, 1340, 1290, 1610, 1920, 1250, 1270, 1300, 1330, 1360, 1350, 1410],
  suria: [1250, 980, 1010, 1380, 1520, 940, 960, 990, 1020, 1080, 1050, 1110],
  ombak: [800, 720, 700, 760, 900, 820, 860, 910, 940, 880, 820, 790],
}
const ecomShare = [0.26, 0.18, 0.16, 0.18, 0.19, 0.17, 0.18, 0.18, 0.19, 0.2, 0.2, 0.21]
const gtShare = [0.3, 0.35, 0.35, 0.36, 0.37, 0.35, 0.34, 0.34, 0.33, 0.33, 0.33, 0.32]
const targets = [5600, 4800, 4900, 5600, 6500, 4900, 4900, 5000, 5100, 5300, 5200, 5300]
const lastYearFactor = [0.9, 0.91, 0.92, 0.9, 0.93, 0.92, 0.91, 0.9, 0.92, 0.93, 0.91, 0.9]

const monthly = months.map((month, i) => {
  const total = brands.reduce((s, b) => s + brandSales[b][i], 0)
  const ecom = Math.round(total * ecomShare[i])
  const gt = Math.round(total * gtShare[i])
  return {
    month,
    kopi: brandSales.kopi[i],
    teh: brandSales.teh[i],
    suria: brandSales.suria[i],
    ombak: brandSales.ombak[i],
    total,
    mt: total - ecom - gt,
    gt,
    ecom,
    target: targets[i],
    lastYear: Math.round(total * lastYearFactor[i]),
  }
})
const latest = monthly[monthly.length - 1]

const topOutlets = [
  { outlet: "Hypermart Mutiara Damansara", sales: 412 },
  { outlet: "MegaMart Mid Valley", sales: 388 },
  { outlet: "FreshCo Kepong", sales: 341 },
  { outlet: "Pasar Raya Shah Alam", sales: 318 },
  { outlet: "Kedai Borong Subang", sales: 296 },
  { outlet: "Grocer & Co. Bangsar", sales: 254 },
  { outlet: "Runcit Ah Seng, Ipoh", sales: 198 },
  { outlet: "Kedai Pak Mat, Kota Bharu", sales: 151 },
]

const regionGrowth = [
  { region: "Central", growth: 12.4 },
  { region: "Northern", growth: 6.1 },
  { region: "Southern", growth: -3.2 },
  { region: "East Coast", growth: 2.0 },
  { region: "Sabah", growth: -5.4 },
  { region: "Sarawak", growth: 4.3 },
]

const brandTargetsOct: Record<Brand, number> = { kopi: 1950, teh: 1400, suria: 1200, ombak: 900 }

/* ------------------------------------------------------------ formatting */

const rm = new Intl.NumberFormat("en-MY", { style: "currency", currency: "MYR", maximumFractionDigits: 0 })
const rmCompact = new Intl.NumberFormat("en-MY", { style: "currency", currency: "MYR", notation: "compact", maximumFractionDigits: 1 })
/** Values are RM thousands. */
const fmtK = (k: number) => rm.format(k * 1000)
const fmtKCompact = (k: number) => rmCompact.format(k * 1000)
const monthShort = (m: string) => new Date(`${m}-01T00:00:00`).toLocaleDateString("en-MY", { month: "short" })
const monthLong = (m: unknown) =>
  typeof m === "string" && /^\d{4}-\d{2}$/.test(m)
    ? new Date(`${m}-01T00:00:00`).toLocaleDateString("en-MY", { month: "long", year: "numeric" })
    : String(m ?? "")

/**
 * ChartTooltipContent prints raw numbers ("1,820"). Passing `formatter` replaces the whole row,
 * indicator included, so we rebuild it here with ringgit.
 */
function MoneyRow({ name, value, color, config, format = fmtK }: { name: unknown; value: unknown; color?: string; config: ChartConfig; format?: (n: number) => string }) {
  const key = String(name)
  return (
    <div className="flex w-full items-center gap-2">
      <span className="size-2.5 shrink-0 rounded-[2px]" style={{ background: color }} />
      <span className="text-muted-foreground">{config[key]?.label ?? key}</span>
      <span className="ml-auto pl-3 font-mono font-medium text-foreground tabular-nums">{format(Number(value))}</span>
    </div>
  )
}

/* ------------------------------------------------------------- controls */

function Controls({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn("flex w-full flex-wrap items-center justify-between gap-x-4 gap-y-2 text-sm", className)}>{children}</div>
}

function Segmented<T extends string>({ value, onChange, options, labels }: { value: T; onChange: (v: T) => void; options: readonly T[]; labels?: Partial<Record<T, string>> }) {
  return (
    <Tabs value={value} onValueChange={(x) => onChange(x as T)}>
      <TabsList>
        {options.map((o) => (
          <TabsTrigger key={o} value={o} className="text-xs">
            {labels?.[o] ?? o}
          </TabsTrigger>
        ))}
      </TabsList>
    </Tabs>
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

function ChartTitle({ title, sub }: { title: string; sub?: ReactNode }) {
  return (
    <div>
      <div className="text-sm font-medium">{title}</div>
      {sub && <div className="text-xs text-muted-foreground">{sub}</div>}
    </div>
  )
}

const axisProps = { tickLine: false, axisLine: false, tickMargin: 8 } as const

/* ----------------------------------------------------------------- areas */

const curves = ["monotone", "linear", "step"] as const
const ranges = ["6", "12"] as const

function TotalArea() {
  const [curve, setCurve] = useState<(typeof curves)[number]>("monotone")
  const [range, setRange] = useState<(typeof ranges)[number]>("12")
  const [showTarget, setShowTarget] = useState(true)
  const data = monthly.slice(-Number(range))
  const config = { total: { label: "Net sales", theme: S.blue }, target: { label: "Target" } } satisfies ChartConfig
  return (
    <div className="flex w-full flex-col gap-3">
      <ChartTitle title="Net sales, all brands" sub={`${monthLong(data[0].month)} – ${monthLong(latest.month)}`} />
      <ChartContainer config={config} className="aspect-auto h-60 w-full">
        <AreaChart accessibilityLayer data={data} margin={{ left: 4, right: 12, top: 8 }}>
          <defs>
            <linearGradient id="fill-total" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="var(--color-total)" stopOpacity={0.4} />
              <stop offset="95%" stopColor="var(--color-total)" stopOpacity={0.02} />
            </linearGradient>
          </defs>
          <CartesianGrid vertical={false} />
          <XAxis dataKey="month" {...axisProps} tickFormatter={monthShort} />
          <YAxis {...axisProps} width="auto" tickFormatter={fmtKCompact} domain={[0, "auto"]} />
          <ChartTooltip
            cursor
            content={
              <ChartTooltipContent
                labelFormatter={monthLong}
                formatter={(value, name, item) => <MoneyRow name={name} value={value} color={item.color} config={config} />}
              />
            }
          />
          {showTarget && (
            <ReferenceLine y={5300} stroke="var(--muted-foreground)" strokeDasharray="4 4">
              <Label value="Monthly target RM 5.3M" position="insideTopRight" className="fill-muted-foreground text-[11px]" />
            </ReferenceLine>
          )}
          <Area dataKey="total" type={curve} stroke="var(--color-total)" strokeWidth={2} fill="url(#fill-total)" activeDot={{ r: 4, strokeWidth: 2, stroke: "var(--card)" }} />
        </AreaChart>
      </ChartContainer>
      <Controls>
        <Segmented value={curve} onChange={setCurve} options={curves} />
        <Segmented value={range} onChange={setRange} options={ranges} labels={{ "6": "6 months", "12": "12 months" }} />
        <SwitchControl label="Target line" checked={showTarget} onChange={setShowTarget} />
      </Controls>
    </div>
  )
}

function ChannelArea() {
  const [expand, setExpand] = useState(false)
  return (
    <div className="flex w-full flex-col gap-3">
      <ChartTitle title={expand ? "Channel share of net sales" : "Net sales by channel"} sub="Stacked; e-commerce jumps every 11.11" />
      <ChartContainer config={channelConfig} className="aspect-auto h-60 w-full">
        <AreaChart accessibilityLayer data={monthly} stackOffset={expand ? "expand" : "none"} margin={{ left: 4, right: 12, top: 8 }}>
          <defs>
            {channels.map((c) => (
              <linearGradient key={c} id={`fill-ch-${c}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor={`var(--color-${c})`} stopOpacity={0.55} />
                <stop offset="95%" stopColor={`var(--color-${c})`} stopOpacity={0.12} />
              </linearGradient>
            ))}
          </defs>
          <CartesianGrid vertical={false} />
          <XAxis dataKey="month" {...axisProps} tickFormatter={monthShort} />
          <YAxis {...axisProps} width="auto" tickFormatter={(v: number) => (expand ? `${Math.round(v * 100)}%` : fmtKCompact(v))} />
          <ChartTooltip
            content={
              <ChartTooltipContent
                labelFormatter={monthLong}
                formatter={(value, name, item) => <MoneyRow name={name} value={value} color={item.color} config={channelConfig} />}
              />
            }
          />
          {channels.map((c) => (
            <Area key={c} dataKey={c} type="monotone" stackId="a" stroke={`var(--color-${c})`} strokeWidth={2} fill={`url(#fill-ch-${c})`} />
          ))}
          <ChartLegend itemSorter={null} content={<ChartLegendContent />} />
        </AreaChart>
      </ChartContainer>
      <Controls>
        <SwitchControl label={<>Show as share (<code>stackOffset="expand"</code>)</>} checked={expand} onChange={setExpand} />
        <span className="text-xs text-muted-foreground">Tooltip still shows ringgit</span>
      </Controls>
    </div>
  )
}

/* ------------------------------------------------------------------ bars */

const barModes = ["grouped", "stacked"] as const

function BrandBars() {
  const [mode, setMode] = useState<(typeof barModes)[number]>("grouped")
  const [table, setTable] = useState(false)
  const data = monthly.slice(-6)
  const stacked = mode === "stacked"
  return (
    <div className="flex w-full flex-col gap-3">
      <ChartTitle title="Net sales by brand" sub="Last 6 months" />
      {table ? (
        <div className="h-64 w-full overflow-auto rounded-lg border">
          <table className="w-full text-xs">
            <thead className="sticky top-0 bg-muted text-left">
              <tr>
                <th className="px-2 py-1.5 font-medium">Month</th>
                {brands.map((b) => (
                  <th key={b} className="px-2 py-1.5 text-right font-medium">
                    {brandConfig[b].label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {data.map((d) => (
                <tr key={d.month} className="border-t">
                  <td className="px-2 py-1.5">{monthLong(d.month)}</td>
                  {brands.map((b) => (
                    <td key={b} className="px-2 py-1.5 text-right tabular-nums">
                      {fmtK(d[b])}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <ChartContainer config={brandConfig} className="aspect-auto h-64 w-full">
          <BarChart accessibilityLayer data={data} barGap={2} barCategoryGap={stacked ? "30%" : "18%"} margin={{ left: 4, right: 12, top: 8 }}>
            <CartesianGrid vertical={false} />
            <XAxis dataKey="month" {...axisProps} tickFormatter={monthShort} />
            <YAxis {...axisProps} width="auto" tickFormatter={fmtKCompact} />
            <ChartTooltip
              cursor={{ fillOpacity: 0.5 }}
              content={
                <ChartTooltipContent
                  labelFormatter={monthLong}
                  formatter={(value, name, item) => <MoneyRow name={name} value={value} color={item.color ?? item.payload?.fill} config={brandConfig} />}
                />
              }
            />
            {brands.map((b, i) => (
              <Bar
                key={b}
                dataKey={b}
                stackId={stacked ? "a" : undefined}
                fill={`var(--color-${b})`}
                stroke="var(--card)"
                strokeWidth={stacked ? 2 : 0}
                radius={stacked ? (i === brands.length - 1 ? [4, 4, 0, 0] : 0) : [4, 4, 0, 0]}
              />
            ))}
            <ChartLegend itemSorter={null} content={<ChartLegendContent />} />
          </BarChart>
        </ChartContainer>
      )}
      <Controls>
        <Segmented value={mode} onChange={setMode} options={barModes} />
        <SwitchControl label="Table view" checked={table} onChange={setTable} />
      </Controls>
    </div>
  )
}

function OutletBars() {
  const config = { sales: { label: "Net sales", theme: S.blue } } satisfies ChartConfig
  return (
    <div className="flex w-full flex-col gap-3">
      <ChartTitle title="Top outlets" sub={`${monthLong(latest.month)} · all brands`} />
      <ChartContainer config={config} className="aspect-auto h-72 w-full">
        <BarChart accessibilityLayer data={topOutlets} layout="vertical" margin={{ left: 0, right: 64 }} barCategoryGap="22%">
          <XAxis type="number" dataKey="sales" hide />
          <YAxis type="category" dataKey="outlet" {...axisProps} width={170} tick={{ fontSize: 11 }} />
          <ChartTooltip
            cursor={false}
            content={<ChartTooltipContent hideLabel formatter={(value, name, item) => <MoneyRow name={item.payload?.outlet} value={value} color={item.color} config={config} />} />}
          />
          <Bar dataKey="sales" fill="var(--color-sales)" radius={[0, 4, 4, 0]}>
            <LabelList dataKey="sales" position="right" offset={8} className="fill-foreground" fontSize={11} formatter={(v: unknown) => fmtKCompact(Number(v))} />
          </Bar>
        </BarChart>
      </ChartContainer>
    </div>
  )
}

function GrowthBars() {
  const config = { growth: { label: "vs last year" }, up: { label: "Growth", theme: S.blue }, down: { label: "Decline", theme: S.red } } satisfies ChartConfig
  return (
    <div className="flex w-full flex-col gap-3">
      <ChartTitle title="Growth vs last year, by region" sub="Year to date · diverging pair: blue up, red down" />
      <ChartContainer config={config} className="aspect-auto h-64 w-full">
        <BarChart accessibilityLayer data={regionGrowth} margin={{ top: 20, left: 4, right: 12 }}>
          <CartesianGrid vertical={false} />
          <XAxis dataKey="region" {...axisProps} />
          <YAxis {...axisProps} width="auto" tickFormatter={(v: number) => `${v}%`} />
          <ReferenceLine y={0} stroke="var(--border)" />
          <ChartTooltip
            cursor={false}
            content={
              <ChartTooltipContent
                hideIndicator
                formatter={(value) => (
                  <span className="font-mono font-medium tabular-nums">
                    {Number(value) > 0 ? "+" : ""}
                    {Number(value).toFixed(1)}% vs last year
                  </span>
                )}
              />
            }
          />
          <Bar dataKey="growth" radius={4}>
            {regionGrowth.map((r) => (
              <Cell key={r.region} fill={r.growth >= 0 ? "var(--color-up)" : "var(--color-down)"} />
            ))}
            <LabelList
              dataKey="growth"
              position="top"
              className="fill-foreground"
              fontSize={11}
              formatter={(v: unknown) => `${Number(v) > 0 ? "+" : ""}${Number(v).toFixed(1)}%`}
            />
          </Bar>
        </BarChart>
      </ChartContainer>
    </div>
  )
}

/* ----------------------------------------------------------------- lines */

function BrandLines() {
  const [hidden, setHidden] = useState<Set<Brand>>(new Set())
  const toggle = (b: Brand) =>
    setHidden((h) => {
      const n = new Set(h)
      if (n.has(b)) n.delete(b)
      else n.add(b)
      return n
    })
  return (
    <div className="flex w-full flex-col gap-3">
      <ChartTitle title="Monthly net sales by brand" sub="Click a brand to hide it; colours stay with the brand" />
      <ChartContainer id="brand-lines" config={brandConfig} className="aspect-auto h-64 w-full">
        <LineChart accessibilityLayer data={monthly} margin={{ left: 4, right: 12, top: 8 }}>
          <CartesianGrid vertical={false} />
          <XAxis dataKey="month" {...axisProps} tickFormatter={monthShort} />
          <YAxis {...axisProps} width="auto" tickFormatter={fmtKCompact} />
          <ChartTooltip
            content={
              <ChartTooltipContent
                labelFormatter={monthLong}
                formatter={(value, name, item) => <MoneyRow name={name} value={value} color={item.color} config={brandConfig} />}
              />
            }
          />
          {brands.map((b) => (
            <Line
              key={b}
              dataKey={b}
              type="monotone"
              stroke={`var(--color-${b})`}
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 4, strokeWidth: 2, stroke: "var(--card)" }}
              hide={hidden.has(b)}
            />
          ))}
        </LineChart>
      </ChartContainer>
      {/* Outside ChartContainer the --color-* variables don't exist; reusing its data-chart id brings them in scope. */}
      <div data-chart="chart-brand-lines" className="flex flex-wrap justify-center gap-1.5">
        {brands.map((b) => (
          <button
            key={b}
            type="button"
            aria-pressed={!hidden.has(b)}
            onClick={() => toggle(b)}
            className={cn(
              "flex items-center gap-1.5 rounded-md border px-2 py-1 text-xs transition-opacity",
              hidden.has(b) && "opacity-40",
            )}
          >
            <span className="size-2 rounded-[2px]" style={{ background: `var(--color-${b})` }} />
            {brandConfig[b].label}
          </button>
        ))}
      </div>
    </div>
  )
}

function TargetLines() {
  const config = {
    total: { label: "Actual", theme: S.blue },
    target: { label: "Target", theme: { light: "#52514e", dark: "#c3c2b7" } },
    lastYear: { label: "Last year", theme: { light: "#a3a29c", dark: "#6f6e68" } },
  } satisfies ChartConfig
  return (
    <div className="flex w-full flex-col gap-3">
      <ChartTitle title="Actual vs target vs last year" sub="Same unit, so one axis" />
      <ChartContainer config={config} className="aspect-auto h-64 w-full">
        <LineChart accessibilityLayer data={monthly} margin={{ left: 4, right: 12, top: 8 }}>
          <CartesianGrid vertical={false} />
          <XAxis dataKey="month" {...axisProps} tickFormatter={monthShort} />
          <YAxis {...axisProps} width="auto" tickFormatter={fmtKCompact} domain={["dataMin - 400", "dataMax + 200"]} />
          <ChartTooltip
            content={
              <ChartTooltipContent
                labelFormatter={monthLong}
                formatter={(value, name, item) => <MoneyRow name={name} value={value} color={item.color} config={config} />}
              />
            }
          />
          <Line dataKey="lastYear" type="monotone" stroke="var(--color-lastYear)" strokeWidth={2} dot={false} />
          <Line dataKey="target" type="stepAfter" stroke="var(--color-target)" strokeWidth={1.5} strokeDasharray="5 4" dot={false} />
          <Line dataKey="total" type="monotone" stroke="var(--color-total)" strokeWidth={2} dot={{ r: 3, strokeWidth: 0, fill: "var(--color-total)" }} activeDot={{ r: 5, strokeWidth: 2, stroke: "var(--card)" }} />
          <ChartLegend itemSorter={null} content={<ChartLegendContent />} />
        </LineChart>
      </ChartContainer>
    </div>
  )
}

/* -------------------------------------------------------- donut, radial */

function ChannelDonut() {
  const [month, setMonth] = useState(latest.month)
  const row = monthly.find((m) => m.month === month) ?? latest
  const data = channels.map((c) => ({ channel: c, value: row[c], fill: `var(--color-${c})` }))
  return (
    <div className="flex w-full flex-col gap-3">
      <ChartTitle title="Channel mix" sub={monthLong(month)} />
      <ChartContainer config={channelConfig} className="mx-auto aspect-square h-64">
        <PieChart accessibilityLayer>
          <ChartTooltip
            cursor={false}
            content={<ChartTooltipContent hideLabel formatter={(value, name, item) => <MoneyRow name={name} value={value} color={item.payload?.fill} config={channelConfig} />} />}
          />
          <Pie
            data={data}
            dataKey="value"
            nameKey="channel"
            innerRadius={68}
            outerRadius={96}
            paddingAngle={1}
            stroke="var(--card)"
            strokeWidth={2}
            activeShape={({ outerRadius = 0, ...props }: PieSectorDataItem) => <Sector {...props} outerRadius={outerRadius + 6} />}
          >
            <Label
              content={({ viewBox }) => {
                if (!viewBox || !("cx" in viewBox) || !("cy" in viewBox)) return null
                const cx = Number(viewBox.cx)
                const cy = Number(viewBox.cy)
                return (
                  <text x={cx} y={cy} textAnchor="middle" dominantBaseline="middle">
                    <tspan x={cx} y={cy - 6} className="fill-foreground text-xl font-semibold">
                      {fmtKCompact(row.total)}
                    </tspan>
                    <tspan x={cx} y={cy + 16} className="fill-muted-foreground text-xs">
                      net sales
                    </tspan>
                  </text>
                )
              }}
            />
          </Pie>
          <ChartLegend itemSorter={null} content={<ChartLegendContent nameKey="channel" className="flex-wrap gap-x-3 gap-y-1 *:whitespace-nowrap" />} />
        </PieChart>
      </ChartContainer>
      <Controls className="justify-center">
        <Segmented value={month} onChange={setMonth} options={["2025-11", "2026-03", "2026-10"] as const} labels={{ "2025-11": "Nov (11.11)", "2026-03": "Mar (Raya)", "2026-10": "Oct" }} />
      </Controls>
    </div>
  )
}

function AttainmentGauge() {
  const pct = latest.total / latest.target
  const config = { attainment: { label: "Attainment", theme: S.blue } } satisfies ChartConfig
  const data = [{ name: "attainment", value: pct * 100, fill: "var(--color-attainment)" }]
  return (
    <div className="flex w-full flex-col gap-3">
      <ChartTitle title="October vs target" sub={`${fmtK(latest.total)} of ${fmtK(latest.target)}`} />
      <ChartContainer config={config} className="mx-auto aspect-square h-56">
        <RadialBarChart data={data} startAngle={90} endAngle={90 - 360 * Math.min(pct, 1)} innerRadius={72} outerRadius={100}>
          <PolarGrid gridType="circle" radialLines={false} stroke="none" className="first:fill-muted last:fill-card" polarRadius={[78, 66]} />
          <RadialBar dataKey="value" background cornerRadius={8} />
          <PolarRadiusAxis tick={false} tickLine={false} axisLine={false}>
            <Label
              content={({ viewBox }) => {
                if (!viewBox || !("cx" in viewBox) || !("cy" in viewBox)) return null
                const cx = Number(viewBox.cx)
                const cy = Number(viewBox.cy)
                return (
                  <text x={cx} y={cy} textAnchor="middle" dominantBaseline="middle">
                    <tspan x={cx} y={cy - 4} className="fill-foreground text-3xl font-semibold">
                      {Math.round(pct * 1000) / 10}%
                    </tspan>
                    <tspan x={cx} y={cy + 20} className="fill-muted-foreground text-xs">
                      of target
                    </tspan>
                  </text>
                )
              }}
            />
          </PolarRadiusAxis>
        </RadialBarChart>
      </ChartContainer>
    </div>
  )
}

function BrandRings() {
  const data = brands
    .map((b) => {
      const real = Math.round((latest[b] / brandTargetsOct[b]) * 1000) / 10
      // A full ring is 100% of target; anything above is capped on the ring and shown in the legend/tooltip.
      return { brand: b, real, value: Math.min(real, 100), fill: `var(--color-${b})` }
    })
    .reverse()
  return (
    <div className="flex w-full flex-col gap-3">
      <ChartTitle title="Target attainment by brand" sub={monthLong(latest.month)} />
      <ChartContainer id="brand-rings" config={brandConfig} className="mx-auto aspect-square h-60">
        <RadialBarChart data={data} innerRadius={36} outerRadius={110} startAngle={90} endAngle={-270} barSize={14}>
          <PolarAngleAxis type="number" domain={[0, 100]} tick={false} axisLine={false} />
          <PolarRadiusAxis type="category" dataKey="brand" tick={false} axisLine={false} />
          <ChartTooltip
            cursor={false}
            content={
              <ChartTooltipContent
                hideLabel
                nameKey="brand"
                formatter={(value, name, item) => (
                  <MoneyRow name={item.payload?.brand} value={item.payload?.real ?? value} color={item.payload?.fill} config={brandConfig} format={(n) => `${n}% of target`} />
                )}
              />
            }
          />
          <RadialBar dataKey="value" background cornerRadius={7} />
        </RadialBarChart>
      </ChartContainer>
      <div data-chart="chart-brand-rings" className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
        {[...data].reverse().map((d) => (
          <div key={d.brand} className="flex items-center gap-1.5">
            <span className="size-2 rounded-[2px]" style={{ background: `var(--color-${d.brand})` }} />
            <span className="text-muted-foreground">{brandConfig[d.brand].label}</span>
            <span className="ml-auto font-medium tabular-nums">{d.real}%</span>
          </div>
        ))}
      </div>
    </div>
  )
}

/* ---------------------------------------------------------------- theming */

function StackedChannels({ config }: { config: ChartConfig }) {
  const data = monthly.slice(-6)
  return (
    <ChartContainer config={config} className="aspect-auto h-56 w-full">
      <BarChart accessibilityLayer data={data} barCategoryGap="30%" margin={{ left: 4, right: 12, top: 8 }}>
        <CartesianGrid vertical={false} />
        <XAxis dataKey="month" {...axisProps} tickFormatter={monthShort} />
        <YAxis {...axisProps} width="auto" tickFormatter={fmtKCompact} />
        <ChartTooltip
          content={
            <ChartTooltipContent
              labelFormatter={monthLong}
              formatter={(value, name, item) => <MoneyRow name={name} value={value} color={item.color} config={config} />}
            />
          }
        />
        {channels.map((c, i) => (
          <Bar key={c} dataKey={c} stackId="a" fill={`var(--color-${c})`} stroke="var(--card)" strokeWidth={2} radius={i === channels.length - 1 ? [4, 4, 0, 0] : 0} />
        ))}
        <ChartLegend itemSorter={null} content={<ChartLegendContent />} />
      </BarChart>
    </ChartContainer>
  )
}

/* -------------------------------------------------------------------- page */

export default function ChartsPage() {
  return (
    <Page
      title="Charts"
      intro="shadcn's Chart component, which wraps Recharts 3 with theme-aware colours, a tooltip and a legend. Not in the Playbook yet: the sales dashboards use chart.js today. Data is a made-up year of net sales for four brands across three channels, in ringgit."
      libs={[
        { name: "shadcn charts", status: "candidate", url: "https://ui.shadcn.com/charts", install: "npx shadcn add chart" },
        { name: "Recharts 3", status: "candidate", url: "https://recharts.github.io", install: "npm i recharts" },
      ]}
    >
      <Section title="Area" description="Trend over time. A gradient fill under one series, and a stacked version by channel that can switch to share of total.">
        <Variant label="Gradient area with a target line" lib="AreaChart">
          <TotalArea />
        </Variant>
        <Variant label="Stacked area by channel" lib="AreaChart">
          <ChannelArea />
        </Variant>
      </Section>

      <Section title="Bar" description="Comparison. Grouped and stacked by brand, a ranked horizontal list, and a diverging growth chart.">
        <Variant label="Grouped / stacked by brand" lib="BarChart" hint="Stacked segments get a 2px gap in the card colour (stroke) and only the top segment is rounded.">
          <BrandBars />
        </Variant>
        <Variant label="Ranked outlets, horizontal" lib="BarChart layout=vertical" hint="One series, so no legend: the title names it. Values are direct labels at the bar ends.">
          <OutletBars />
        </Variant>
        <Variant label="Diverging: growth by region" lib="BarChart + Cell" className="md:col-span-2" hint="Colour per bar via Cell, from the palette's diverging pair. The value labels carry the sign, so colour is never the only cue.">
          <GrowthBars />
        </Variant>
      </Section>

      <Section title="Line" description="Several series over time, and actual against plan.">
        <Variant label="Multi-series with a toggle legend" lib="LineChart">
          <BrandLines />
        </Variant>
        <Variant label="Actual vs target vs last year" lib="LineChart" hint="Target is a dashed step line; last year is a muted grey so Actual stays the hero.">
          <TargetLines />
        </Variant>
      </Section>

      <Section title="Donut and radial" description="Part-to-whole and progress. Centre labels are SVG text drawn through Recharts' Label content prop." className="md:grid-cols-3">
        <Variant label="Donut with centre total" lib="PieChart">
          <ChannelDonut />
        </Variant>
        <Variant label="Progress gauge" lib="RadialBarChart">
          <AttainmentGauge />
        </Variant>
        <Variant label="Rings by brand" lib="RadialBarChart">
          <BrandRings />
        </Variant>
      </Section>

      <Section
        title="Theming"
        description="Same stacked chart twice. Colours are CSS variables per chart (--color-<key>), set from ChartConfig: either one colour, or a light and a dark value that switch with the .dark class."
      >
        <Variant label="Theme defaults: --chart-1, -2, -3" lib="ChartConfig color" hint="The base-nova neutral theme ships five greys, so out of the box every series is grey. Fine for one series, unreadable for three.">
          <StackedChannels config={themeVarConfig} />
        </Variant>
        <Variant label="Validated palette, light and dark steps" lib="ChartConfig theme" hint="Slots 1–3 of our reference palette, each with its own dark-mode step. Flip the theme: the colours change, the chart doesn't re-render.">
          <StackedChannels config={channelConfig} />
        </Variant>
      </Section>

      <Findings
        notes={[
          { tone: "good", text: <>The shadcn wrapper is thin and readable: ChartContainer + ChartConfig turn colours into CSS variables per chart, with separate light/dark values that follow our class-based dark mode with no re-render. Tooltip and legend match the rest of shadcn.</> },
          { tone: "good", text: <>Recharts is plain React components, so composing a target line, a diverging Cell fill, direct labels or a centre total is JSX, not a config object as in chart.js. Every chart type our dashboards use (area, grouped/stacked bar, multi-line, donut, gauge) was straightforward.</> },
          { tone: "good", text: <>Recharts 3 has keyboard access built in (<code>accessibilityLayer</code>): tab to a chart, then arrow keys move the tooltip point by point.</> },
          { tone: "bad", text: <>Number formatting is DIY. ChartTooltipContent prints <code>value.toLocaleString()</code>; passing <code>formatter</code> replaces the whole row, colour swatch included, so each chart needs a small row component (MoneyRow here) to show RM.</> },
          { tone: "bad", text: <>The base-nova theme's <code>--chart-1…5</code> are greys. We need our own validated palette in ChartConfig (or new --chart-* values in index.css) before charts are usable for more than one series. Light aqua/yellow sit under 3:1 on white, so keep legends and a table view.</> },
          { tone: "note", text: <>Quirks: Recharts 3's Legend sorts items alphabetically by default, so legends don't match series order until you pass <code>itemSorter={"{null}"}</code>; gradient <code>&lt;defs&gt;</code> ids are global to the page, so two charts reusing "fillTotal" clash; Recharts 3 dropped Pie's <code>activeIndex</code> (hover state now comes from the tooltip); ChartContainer defaults to aspect-video, so set <code>aspect-auto h-…</code> for fixed-height dashboard cards; the <code>--color-*</code> variables only exist inside ChartContainer, so a custom legend outside it shows blank swatches until you give it the same <code>data-chart</code> id.</> },
          { tone: "note", text: <>Against chart.js: no canvas, so charts are crisp, themeable with CSS and inspectable, but very large series (tens of thousands of points) will be slower as SVG. For sales dashboards with monthly or daily points that doesn't bite.</> },
          { tone: "note", text: <>Recommendation: promote shadcn charts (Recharts) into the Playbook for new React dashboards, together with a shared palette ChartConfig and a money tooltip row. Leave existing chart.js dashboards alone until they're rebuilt.</> },
        ]}
      />
    </Page>
  )
}

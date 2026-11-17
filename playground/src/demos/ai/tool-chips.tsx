/**
 * Tool Chips — copied from Beautiful UI (MIT, (c) 2026 Shane Levine).
 * https://www.beautifului.dev/#tool-chips
 *
 * Changes from the original: `shown` prop to drive how many tool calls have
 * arrived (the original reveals one every 700 ms on its own, which still
 * happens when `shown` is left out), colours mapped to shadcn tokens, and
 * focus rings added. The diff preview still opens in a body portal on
 * hover/focus of a file chip.
 */
import { useEffect, useState, type ReactNode, type SyntheticEvent } from "react"
import { createPortal } from "react-dom"
import { cn } from "@/lib/utils"
import "./bui.css"

const STEP_MS = 700
const focusRing = "outline-none focus-visible:ring-2 focus-visible:ring-ring/60"

const Icons: Record<string, ReactNode> = {
  think: <path d="M12 2l2.4 7.2L22 12l-7.6 2.8L12 22l-2.4-7.2L2 12l7.6-2.8z" />,
  write: (
    <g fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 3a2.8 2.8 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5z" />
    </g>
  ),
  run: (
    <g fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 17l6-5-6-5M12 19h8" />
    </g>
  ),
  read: (
    <g fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6" />
    </g>
  ),
  search: (
    <g fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
      <circle cx="11" cy="11" r="7" />
      <path d="M21 21l-4.3-4.3" />
    </g>
  ),
}

export type ToolDetailLine = { text: string; tone?: "add" }
export type ToolStep = { icon: keyof typeof Icons | string; label: string; chip: string; mono: boolean; detailMono: boolean; detail: ToolDetailLine[] }
export type ToolDiff = { file: string; add: number; del: number }
export type ToolDiffLine = { text: string; tone: "add" | "del" | "ctx" }

const DEFAULT_STEPS: ToolStep[] = [
  {
    icon: "search",
    label: "Query graph",
    chip: 'graphify query "vaul"',
    mono: true,
    detailMono: true,
    detail: [{ text: "odyssey/src/components/ui/drawer.tsx" }, { text: "depot/apps/web/src/PickListDrawer.tsx" }],
  },
  {
    icon: "read",
    label: "Read",
    chip: "drawer.tsx",
    mono: true,
    detailMono: false,
    detail: [{ text: "Vaul Drawer.Root with snapPoints and a handle." }, { text: "Used by MobileComposer and SettingsSheet." }],
  },
  {
    icon: "write",
    label: "Write 42 lines",
    chip: "MobileComposer.tsx",
    mono: true,
    detailMono: true,
    detail: [
      { text: '+ import { Drawer } from "@base-ui/react/drawer"', tone: "add" },
      { text: "+ <Drawer.Root snapPoints={[0.5, 1]}>", tone: "add" },
    ],
  },
  {
    icon: "run",
    label: "Type-check",
    chip: "npm run typecheck",
    mono: true,
    detailMono: true,
    detail: [{ text: "✓ 0 errors in 1.8s" }],
  },
]

const DEFAULT_DIFFS: ToolDiff[] = [
  { file: "drawer.tsx", add: 18, del: 31 },
  { file: "MobileComposer.tsx", add: 42, del: 61 },
  { file: "package.json", add: 1, del: 1 },
]

const DEFAULT_DIFF_LINES: Record<string, ToolDiffLine[]> = {
  "drawer.tsx": [
    { text: 'import { Drawer as Vaul } from "vaul"', tone: "del" },
    { text: 'import { Drawer } from "@base-ui/react/drawer"', tone: "add" },
    { text: "export function Sheet(props) {", tone: "ctx" },
  ],
  "MobileComposer.tsx": [
    { text: "<Vaul.Root shouldScaleBackground>", tone: "del" },
    { text: "<Drawer.Root snapPoints={[0.5, 1]}>", tone: "add" },
    { text: "  <Composer />", tone: "ctx" },
  ],
  "package.json": [
    { text: '"vaul": "^1.1.2",', tone: "del" },
    { text: '"@base-ui/react": "^1.9.0",', tone: "add" },
  ],
}

export function ToolChips({
  steps = DEFAULT_STEPS,
  diffs = DEFAULT_DIFFS,
  diffLines = DEFAULT_DIFF_LINES,
  header,
  more = "+2 more",
  shown,
  defaultOpenRows = [],
  className,
}: {
  steps?: ToolStep[]
  diffs?: ToolDiff[]
  diffLines?: Record<string, ToolDiffLine[]>
  header?: string
  more?: string | null
  /** Controlled: number of tool calls that have arrived; steps.length + 1 shows the diff chips. */
  shown?: number
  defaultOpenRows?: string[]
  className?: string
}) {
  const [internal, setInternal] = useState(0)
  const [open, setOpen] = useState(true)
  const [openRows, setOpenRows] = useState<Set<string>>(new Set(defaultOpenRows))
  const [preview, setPreview] = useState<{ file: string; x: number; top?: number; bottom?: number } | null>(null)
  const total = steps.length + (diffs.length ? 1 : 0)
  const step = shown ?? internal

  useEffect(() => {
    if (shown !== undefined || internal >= total) return
    const t = setTimeout(() => setInternal((s) => s + 1), STEP_MS)
    return () => clearTimeout(t)
  }, [internal, total, shown])

  const openPreview = (file: string) => (event: SyntheticEvent) => {
    const rect = (event.currentTarget as Element).closest("[data-diffchip]")!.getBoundingClientRect()
    const previewHeight = 38 + (diffLines[file]?.length ?? 0) * 19
    const fitsBelow = rect.bottom + 6 + previewHeight <= window.innerHeight - 12
    setPreview({
      file,
      x: Math.max(12, Math.min(rect.left, window.innerWidth - 300)),
      ...(fitsBelow ? { top: rect.bottom + 6 } : { bottom: window.innerHeight - rect.top + 6 }),
    })
  }
  const closePreview = (file: string) => () => setPreview((current) => (current?.file === file ? null : current))

  const toggleRow = (label: string) =>
    setOpenRows((current) => {
      const next = new Set(current)
      if (next.has(label)) next.delete(label)
      else next.add(label)
      return next
    })

  const previewDiff = preview ? diffs.find((d) => d.file === preview.file) : undefined
  const headerText = header ?? `${Math.min(step, steps.length)} tool call${Math.min(step, steps.length) === 1 ? "" : "s"}`

  return (
    <div data-bui className={cn("w-full max-w-80 pb-1", className)}>
      <button
        type="button"
        aria-expanded={open}
        onClick={() => setOpen((current) => !current)}
        className={cn("-mx-1.5 flex w-fit items-center gap-1.5 rounded-md px-1.5 py-1 text-[12.5px] text-muted-foreground transition-colors hover:bg-muted", focusRing)}
      >
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden className="transition-transform duration-200" style={{ transform: open ? "rotate(0deg)" : "rotate(-90deg)" }}>
          <path d="M6 9l6 6 6-6" />
        </svg>
        <span className="tabular-nums">{headerText}</span>
      </button>

      <div className="grid transition-[grid-template-rows,opacity] duration-300" style={{ gridTemplateRows: open ? "1fr" : "0fr", opacity: open ? 1 : 0 }}>
        <div className="-mx-1 overflow-hidden px-1.5 pb-1" inert={!open}>
          <div className="mt-1.5 flex flex-col gap-1">
            {steps.slice(0, step).map((row) => {
              const rowOpen = openRows.has(row.label)
              return (
                <div key={row.label} style={{ animation: "bui-fade-up 300ms cubic-bezier(0.23,1,0.32,1) both" }}>
                  <button
                    type="button"
                    aria-expanded={rowOpen}
                    onClick={() => toggleRow(row.label)}
                    className={cn(
                      "group/row -mx-[3px] flex h-7 w-[calc(100%+6px)] min-w-0 items-center gap-2 rounded-lg px-[3px] text-left transition-colors hover:bg-muted",
                      focusRing,
                    )}
                  >
                    <span className="relative flex size-4 shrink-0 items-center justify-center text-muted-foreground">
                      <svg
                        width="13"
                        height="13"
                        viewBox="0 0 24 24"
                        fill={row.icon === "think" ? "currentColor" : "none"}
                        stroke="currentColor"
                        aria-hidden
                        className={cn("transition-opacity duration-100 group-hover/row:opacity-0", rowOpen && "opacity-0")}
                      >
                        {Icons[row.icon]}
                      </svg>
                      <svg
                        width="12"
                        height="12"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2.2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden
                        className={cn("absolute transition-[opacity,transform] duration-150 group-hover/row:opacity-100", rowOpen ? "opacity-100" : "opacity-0")}
                        style={{ transform: rowOpen ? "rotate(0deg)" : "rotate(-90deg)" }}
                      >
                        <path d="M6 9l6 6 6-6" />
                      </svg>
                    </span>
                    <span className="shrink-0 text-[12.5px] font-medium text-foreground">{row.label}</span>
                    <span
                      className={cn(
                        "inline-flex h-5.5 min-w-0 flex-1 items-center truncate rounded-md bg-muted px-1.5 text-[11.5px] text-muted-foreground ring-1 ring-border",
                        row.mono && "font-mono",
                      )}
                    >
                      {row.chip}
                    </span>
                  </button>

                  <div
                    className="grid transition-[grid-template-rows,opacity] duration-300"
                    style={{ gridTemplateRows: rowOpen ? "1fr" : "0fr", opacity: rowOpen ? 1 : 0, transitionTimingFunction: "cubic-bezier(0.23, 1, 0.32, 1)" }}
                  >
                    <div className="min-h-0 overflow-hidden">
                      <div className="mt-0.5 mb-1 ml-2 flex flex-col gap-0.5 border-l py-0.5 pl-3.5">
                        {row.detail.map((line) => (
                          <span
                            key={line.text}
                            className={cn(
                              "truncate text-[11.5px] leading-[1.6]",
                              row.detailMono && "font-mono",
                              line.tone === "add" ? "text-emerald-700 dark:text-emerald-400" : "text-muted-foreground",
                            )}
                          >
                            {line.text}
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>

          {diffs.length > 0 && step >= total && (
            <div className="mt-2.5 flex max-w-full flex-wrap gap-1.5 border-t pt-2.5">
              {diffs.map((d, i) => (
                <span key={d.file} data-diffchip className="relative" onMouseEnter={openPreview(d.file)} onMouseLeave={closePreview(d.file)}>
                  <button
                    type="button"
                    aria-expanded={preview?.file === d.file}
                    aria-label={`Show diff for ${d.file}`}
                    onFocus={openPreview(d.file)}
                    onBlur={closePreview(d.file)}
                    className={cn(
                      "inline-flex h-7 max-w-full items-center gap-2 rounded-md bg-card px-2 font-mono text-[11.5px] text-foreground shadow-xs ring-1 ring-border transition-colors hover:bg-muted",
                      focusRing,
                    )}
                    style={{ animation: `bui-pop-in 250ms cubic-bezier(0.23,1,0.32,1) ${i * 80}ms both` }}
                  >
                    <span className="min-w-0 truncate">{d.file}</span>
                    <span className="shrink-0 text-emerald-700 tabular-nums dark:text-emerald-400">+{d.add}</span>
                    {d.del > 0 && <span className="shrink-0 text-red-700 tabular-nums dark:text-red-400">−{d.del}</span>}
                  </button>
                </span>
              ))}
              {more && (
                <span className="inline-flex h-7 items-center px-1.5 font-mono text-[11.5px] text-muted-foreground" style={{ animation: `bui-fade-in 300ms ease-out ${diffs.length * 80}ms both` }}>
                  {more}
                </span>
              )}
            </div>
          )}
        </div>
      </div>

      {preview &&
        createPortal(
          <div
            data-bui
            className="fixed z-50 w-72 overflow-hidden rounded-[10px] bg-popover text-popover-foreground shadow-lg ring-1 ring-foreground/10"
            style={{
              left: preview.x,
              top: preview.top,
              bottom: preview.bottom,
              animation: "bui-pop-in 160ms cubic-bezier(0.23,1,0.32,1) both",
              transformOrigin: preview.top === undefined ? "bottom left" : "top left",
            }}
          >
            <div className="flex items-center justify-between border-b px-2.5 py-1.5 font-mono text-[11px]">
              <span className="min-w-0 truncate text-muted-foreground">{preview.file}</span>
              <span className="shrink-0 tabular-nums">
                <span className="text-emerald-700 dark:text-emerald-400">+{previewDiff?.add}</span>
                {(previewDiff?.del ?? 0) > 0 && <span className="text-red-700 dark:text-red-400"> −{previewDiff?.del}</span>}
              </span>
            </div>
            <div className="py-1 font-mono text-[11px] leading-[1.8]">
              {(diffLines[preview.file] ?? []).map((line, index) => (
                <div
                  key={index}
                  className={cn(
                    "flex gap-2 px-2.5 whitespace-pre",
                    line.tone === "add"
                      ? "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300"
                      : line.tone === "del"
                        ? "bg-red-500/10 text-red-700 dark:text-red-300"
                        : "text-muted-foreground",
                  )}
                >
                  <span className="w-3 shrink-0 select-none">{line.tone === "add" ? "+" : line.tone === "del" ? "−" : " "}</span>
                  <span className="min-w-0 truncate">{line.text}</span>
                </div>
              ))}
            </div>
          </div>,
          document.body,
        )}
    </div>
  )
}

/**
 * Task Rows — copied from Beautiful UI (MIT, (c) 2026 Shane Levine).
 * https://www.beautifului.dev/#task-rows
 *
 * The original hard-codes a "sequence" status that flips pending → failed →
 * completed on a timer, and auto-opens the row whose key is "index". This copy
 * takes plain statuses (done / running / failed / pending) so the parent owns
 * the state; `useTaskTimeline` in the page replays the original demo.
 * Colours mapped to shadcn tokens; focus ring added.
 */
import { useState, type ReactNode } from "react"
import { cn } from "@/lib/utils"
import "./bui.css"

export type TaskStatus = "done" | "running" | "failed" | "pending"
export type TaskDetail = { label: string; meta: string }
export type TaskRow = { key: string; label: string; amount: string; status: TaskStatus; step?: number; details: TaskDetail[] }

function SpinnerRing({ active, children }: { active?: boolean; children?: ReactNode }) {
  const size = 24
  const stroke = 2
  const r = (size - stroke) / 2
  const c = 2 * Math.PI * r
  return (
    <span className="relative inline-flex shrink-0 items-center justify-center" style={{ width: size, height: size }}>
      <svg width={size} height={size} aria-hidden className="absolute inset-0" style={active ? { animation: "bui-spin 1.1s linear infinite" } : undefined}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--border)" strokeWidth={stroke} />
        {active && (
          <circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke="var(--muted-foreground)"
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={`${c * 0.28} ${c * 0.72}`}
          />
        )}
      </svg>
      <span className="relative text-[10.5px] font-semibold text-foreground tabular-nums">{children}</span>
    </span>
  )
}

function StatusBadge({ tone, children }: { tone: "red" | "green"; children: ReactNode }) {
  return (
    <span
      className={cn("flex size-5.5 shrink-0 items-center justify-center rounded-full text-white", tone === "red" ? "bg-red-600" : "bg-emerald-600")}
      style={{ animation: "bui-pop-in 300ms cubic-bezier(0.23,1,0.32,1) both" }}
    >
      {children}
    </span>
  )
}

const XIcon = (
  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" aria-hidden>
    <path d="M18 6L6 18M6 6l12 12" />
  </svg>
)
const CheckIcon = (
  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
    <path d="M20 6L9 17l-5-5" />
  </svg>
)
const RetryIcon = (
  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
    <path d="M21 12a9 9 0 1 1-2.64-6.36M21 3v6h-6" />
  </svg>
)

const pillBase = "inline-flex h-5.5 items-center gap-1.5 rounded-full px-2 text-[11.5px] font-medium"
const greenPill = "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300"
const redPill = "bg-red-500/10 text-red-700 dark:text-red-300"

export function TaskRows({
  rows,
  variant = "Capsules",
  labels = { completed: "Completed", failed: "Failed" },
  openKey,
  className,
}: {
  rows: TaskRow[]
  variant?: "Capsules" | "List"
  labels?: { completed: string; failed: string }
  /** Row the parent wants open (e.g. the running one); the user can still toggle. */
  openKey?: string
  className?: string
}) {
  const [manualOpen, setManualOpen] = useState<Record<string, boolean>>({})

  const badgeFor = (row: TaskRow) => {
    if (row.status === "done") return <StatusBadge tone="green">{CheckIcon}</StatusBadge>
    if (row.status === "failed") return <StatusBadge tone="red">{XIcon}</StatusBadge>
    return <SpinnerRing active={row.status === "running"}>{row.step}</SpinnerRing>
  }

  const pillFor = (row: TaskRow) => {
    if (row.status === "done")
      return (
        <span className={cn(pillBase, greenPill)} style={{ animation: "bui-fade-in 200ms ease-out both" }}>
          {labels.completed}
        </span>
      )
    if (row.status === "failed")
      return (
        <span className={cn(pillBase, redPill)} style={{ animation: "bui-fade-in 200ms ease-out both" }}>
          {labels.failed}
          {/* the original spins this while the agent retries; it is not a button */}
          <span className="flex" style={{ animation: "bui-spin 1.2s linear infinite" }}>
            {RetryIcon}
          </span>
        </span>
      )
    return null
  }

  const list = variant === "List"
  return (
    <div
      data-bui
      className={cn(
        "flex w-full max-w-110 flex-col",
        list ? "gap-0 self-start overflow-hidden rounded-xl bg-card ring-1 ring-foreground/10" : "gap-2",
        className,
      )}
    >
      {rows.map((row, i) => {
        const open = manualOpen[row.key] ?? openKey === row.key
        return (
          <div
            key={row.key}
            className={cn(
              "self-stretch overflow-hidden transition-[border-radius,background-color] duration-300 hover:bg-muted/40",
              list ? "border-b last:border-0" : "bg-card shadow-xs ring-1 ring-foreground/10",
            )}
            style={{
              borderRadius: list ? 0 : open ? 14 : 22,
              animation: `bui-fade-up 450ms cubic-bezier(0.23,1,0.32,1) ${i * 80}ms both`,
            }}
          >
            <button
              type="button"
              aria-expanded={open}
              onClick={() => setManualOpen((current) => ({ ...current, [row.key]: !open }))}
              className="flex h-11 w-full items-center gap-2.5 rounded-[inherit] px-2.5 text-left outline-none focus-visible:ring-2 focus-visible:ring-ring/60 focus-visible:ring-inset"
            >
              <span className="flex size-6 shrink-0 items-center justify-center">{badgeFor(row)}</span>
              <span className="min-w-0 flex-1 truncate text-[13px] font-medium text-foreground">{row.label}</span>
              <span className="text-[12.5px] text-muted-foreground tabular-nums">{row.amount}</span>
              {pillFor(row)}
              <span aria-hidden="true" className="-ml-2 flex size-7 shrink-0 items-center justify-center rounded-full text-muted-foreground">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" className="transition-transform duration-300" style={{ transform: open ? "rotate(180deg)" : "rotate(0)" }}>
                  <path d="M6 9l6 6 6-6" />
                </svg>
              </span>
            </button>

            <div
              className="grid transition-[grid-template-rows,opacity] duration-300"
              style={{ gridTemplateRows: open ? "1fr" : "0fr", opacity: open ? 1 : 0, transitionTimingFunction: "cubic-bezier(0.23, 1, 0.32, 1)" }}
            >
              <div className="overflow-hidden">
                <div className="mb-2.5 grid grid-cols-[24px_1fr] gap-2.5 px-2.5">
                  <span aria-hidden className="mx-auto h-full w-px bg-border" />
                  <div className="flex flex-col gap-1.5">
                    {row.details.map((d, j) => (
                      <div
                        key={d.label}
                        className="flex items-center justify-between"
                        style={open ? { animation: `bui-fade-up 300ms cubic-bezier(0.23,1,0.32,1) ${120 + j * 100}ms both` } : undefined}
                      >
                        <span className="text-xs text-muted-foreground">{d.label}</span>
                        <span className="font-mono text-[11.5px] text-muted-foreground tabular-nums">{d.meta}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )
      })}
    </div>
  )
}

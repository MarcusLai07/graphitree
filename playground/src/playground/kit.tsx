import type { ReactNode } from "react"
import { Badge } from "@/components/ui/badge"
import { cn } from "@/lib/utils"

import type { LibStatus } from "@/playground/catalog"

export type { LibStatus }

export type Lib = {
  name: string
  status: LibStatus
  url?: string
  install?: string
}

const statusLabel: Record<LibStatus, string> = {
  playbook: "In playbook",
  avoid: "Avoid for new work",
  candidate: "Candidate",
  "built-in": "Comes with shadcn/ui",
}

const statusClass: Record<LibStatus, string> = {
  playbook: "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 border-emerald-500/30",
  avoid: "bg-rose-500/10 text-rose-700 dark:text-rose-300 border-rose-500/30",
  candidate: "bg-sky-500/10 text-sky-700 dark:text-sky-300 border-sky-500/30",
  "built-in": "bg-muted text-muted-foreground border-border",
}

export function StatusBadge({ status }: { status: LibStatus }) {
  return (
    <Badge variant="outline" className={cn("font-normal", statusClass[status])}>
      {statusLabel[status]}
    </Badge>
  )
}

/** A whole page: title, one-paragraph intro, and the libraries it compares. */
export function Page({
  title,
  intro,
  libs,
  children,
}: {
  title: string
  intro: ReactNode
  libs: Lib[]
  children: ReactNode
}) {
  return (
    <div className="mx-auto flex max-w-6xl flex-col gap-10 px-8 py-10">
      <header className="flex flex-col gap-4">
        <h1 className="text-3xl font-semibold tracking-tight">{title}</h1>
        <p className="max-w-3xl text-muted-foreground">{intro}</p>
        <div className="flex flex-wrap gap-3">
          {libs.map((lib) => (
            <div key={lib.name} className="flex items-center gap-2 rounded-lg border px-3 py-2 text-sm">
              {lib.url ? (
                <a href={lib.url} target="_blank" rel="noreferrer" className="font-medium hover:underline">
                  {lib.name}
                </a>
              ) : (
                <span className="font-medium">{lib.name}</span>
              )}
              <StatusBadge status={lib.status} />
              {lib.install && <code className="text-xs text-muted-foreground">{lib.install}</code>}
            </div>
          ))}
        </div>
      </header>
      {children}
    </div>
  )
}

/** A group of variants that answer one question, e.g. "Toast types". */
export function Section({
  title,
  description,
  children,
  className,
}: {
  title: string
  description?: ReactNode
  children: ReactNode
  className?: string
}) {
  return (
    <section className="flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <h2 className="text-xl font-semibold tracking-tight">{title}</h2>
        {description && <p className="max-w-3xl text-sm text-muted-foreground">{description}</p>}
      </div>
      <div className={cn("grid gap-4 md:grid-cols-2", className)}>{children}</div>
    </section>
  )
}

/** One thing to try: a labelled stage with the live component in it. */
export function Variant({
  label,
  lib,
  hint,
  children,
  className,
  stageClassName,
}: {
  label: string
  lib?: string
  hint?: ReactNode
  children: ReactNode
  className?: string
  stageClassName?: string
}) {
  return (
    <div className={cn("flex flex-col overflow-hidden rounded-xl border bg-card", className)}>
      <div className="flex items-center justify-between gap-3 border-b px-4 py-2.5">
        <span className="text-sm font-medium">{label}</span>
        {lib && <span className="text-xs text-muted-foreground">{lib}</span>}
      </div>
      <div className={cn("flex min-h-40 flex-1 flex-wrap items-center justify-center gap-3 p-6", stageClassName)}>
        {children}
      </div>
      {hint && <div className="border-t bg-muted/40 px-4 py-2.5 text-xs text-muted-foreground">{hint}</div>}
    </div>
  )
}

export type Note = { tone: "good" | "bad" | "note"; text: ReactNode }

const toneMark: Record<Note["tone"], string> = { good: "+", bad: "−", note: "•" }
const toneClass: Record<Note["tone"], string> = {
  good: "text-emerald-600 dark:text-emerald-400",
  bad: "text-rose-600 dark:text-rose-400",
  note: "text-muted-foreground",
}

/** What we learned on this page, to feed back into the Playbook. */
export function Findings({ title = "What we found", notes }: { title?: string; notes: Note[] }) {
  return (
    <aside className="rounded-xl border border-dashed p-5">
      <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted-foreground">{title}</h2>
      <ul className="flex flex-col gap-2 text-sm">
        {notes.map((note, i) => (
          <li key={i} className="flex gap-2">
            <span className={cn("w-3 shrink-0 font-semibold", toneClass[note.tone])}>{toneMark[note.tone]}</span>
            <span>{note.text}</span>
          </li>
        ))}
      </ul>
    </aside>
  )
}

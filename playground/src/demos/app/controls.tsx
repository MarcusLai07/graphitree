import { useId, type ReactNode } from "react"
import { Switch } from "@/components/ui/switch"
import { cn } from "@/lib/utils"

/** A full-width strip of knobs that sits at the top of a Section grid. */
export function ControlBar({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div
      className={cn(
        "flex flex-wrap items-center gap-x-6 gap-y-3 rounded-xl border bg-muted/30 px-4 py-3 text-sm md:col-span-2",
        className,
      )}
    >
      {children}
    </div>
  )
}

export function Toggle({
  label,
  checked,
  onCheckedChange,
}: {
  label: ReactNode
  checked: boolean
  onCheckedChange: (checked: boolean) => void
}) {
  // Base UI's Switch (a <span role="switch">) would also pick up the wrapping <label>; naming it by the text is just tidier.
  const id = useId()
  return (
    <label className="flex cursor-pointer items-center gap-2 select-none">
      <Switch checked={checked} onCheckedChange={(next) => onCheckedChange(next)} aria-labelledby={id} />
      <span id={id}>{label}</span>
    </label>
  )
}

export function Segmented<T extends string>({
  label,
  value,
  options,
  onChange,
}: {
  label?: ReactNode
  value: T
  options: readonly { value: T; label: ReactNode }[]
  onChange: (value: T) => void
}) {
  return (
    <div className="flex items-center gap-2">
      {label && <span className="text-muted-foreground">{label}</span>}
      <div className="inline-flex flex-wrap rounded-lg border bg-background p-0.5 dark:bg-input/30">
        {options.map((option) => (
          <button
            key={option.value}
            type="button"
            aria-pressed={value === option.value}
            onClick={() => onChange(option.value)}
            className={cn(
              "rounded-md px-2 py-1 text-xs font-medium transition-colors outline-none focus-visible:ring-3 focus-visible:ring-ring/50",
              value === option.value ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  )
}

/** A small "what just happened" readout under a demo. */
export function Readout({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn("w-full rounded-md bg-muted/60 px-3 py-2 font-mono text-xs text-muted-foreground", className)}>
      {children}
    </div>
  )
}

import type { Verdict } from "@/playground/catalog"

export const verdictLabel: Record<Verdict, string> = {
  keep: "Keep",
  narrow: "Keep, narrower",
  drop: "Drop",
  promote: "Add to playbook",
  wait: "Leave as candidate",
}

export const verdictClass: Record<Verdict, string> = {
  keep: "text-emerald-700 dark:text-emerald-300",
  narrow: "text-amber-700 dark:text-amber-300",
  drop: "text-rose-700 dark:text-rose-300",
  promote: "text-sky-700 dark:text-sky-300",
  wait: "text-muted-foreground",
}

/** Catalog text with `backtick` spans shown as code. */
export function Rich({ text }: { text: string }) {
  return (
    <>
      {text.split(/(`[^`]+`)/).map((part, i) =>
        part.startsWith("`") ? (
          <code key={i} className="text-xs">
            {part.slice(1, -1)}
          </code>
        ) : (
          part
        ),
      )}
    </>
  )
}

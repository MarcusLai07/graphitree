import type { ReactNode } from "react"
import { Toast } from "@base-ui/react/toast"
import { CircleCheckIcon, InfoIcon, Loader2Icon, OctagonXIcon, TriangleAlertIcon, XIcon } from "lucide-react"
import { cn } from "@/lib/utils"

/**
 * A complete Base UI toast setup, styled to sit next to Sonner. Base UI ships behaviour only
 * (queue, timers, swipe, stacking CSS variables, a11y); the stack layout below is ours.
 */

export type StockAlert = { kind: "stock"; sku: string; name: string; onHand: number; reorderPoint: number }
export type BaseToastData = StockAlert

/** A global manager so any handler can fire a toast, like Sonner's `toast()`. */
export const baseToasts = Toast.createToastManager<BaseToastData>()

export type BaseToastPosition = "top-right" | "top-center" | "bottom-right" | "bottom-center"

export function BaseToastLab({
  position,
  alwaysExpanded,
  rich,
  limit,
  children,
}: {
  position: BaseToastPosition
  alwaysExpanded: boolean
  rich: boolean
  limit: number
  children: ReactNode
}) {
  return (
    <Toast.Provider toastManager={baseToasts} limit={limit}>
      {children}
      <style>{stackCss}</style>
      <Toast.Portal>
        <Toast.Viewport
          className="bt-viewport"
          data-pos={position}
          data-always-expanded={alwaysExpanded ? "" : undefined}
          data-rich={rich ? "" : undefined}
        >
          <ToastList position={position} />
        </Toast.Viewport>
      </Toast.Portal>
    </Toast.Provider>
  )
}

const typeIcon: Record<string, ReactNode> = {
  success: <CircleCheckIcon className="text-emerald-600 dark:text-emerald-400" />,
  error: <OctagonXIcon className="text-rose-600 dark:text-rose-400" />,
  info: <InfoIcon className="text-sky-600 dark:text-sky-400" />,
  warning: <TriangleAlertIcon className="text-amber-600 dark:text-amber-400" />,
  loading: <Loader2Icon className="animate-spin text-muted-foreground" />,
}

function ToastList({ position }: { position: BaseToastPosition }) {
  const { toasts } = Toast.useToastManager<BaseToastData>()
  const swipe: ("up" | "down" | "right")[] = position.startsWith("top") ? ["up", "right"] : ["down", "right"]
  return toasts.map((t) => (
    <Toast.Root
      key={t.id}
      toast={t}
      swipeDirection={swipe}
      className="bt-toast rounded-xl border bg-popover text-popover-foreground shadow-lg outline-none select-none focus-visible:ring-3 focus-visible:ring-ring/50"
    >
      <Toast.Content className="bt-content flex items-start gap-3 py-3 pr-9 pl-3.5">
        {t.type && typeIcon[t.type] && <span className="mt-0.5 shrink-0 [&_svg]:size-4">{typeIcon[t.type]}</span>}
        <div className="grid min-w-0 flex-1 gap-0.5">
          <Toast.Title className="text-sm font-medium" />
          <Toast.Description className="bt-desc text-[13px] text-muted-foreground" />
          {t.data?.kind === "stock" && <StockBody id={t.id} data={t.data} />}
        </div>
        <Toast.Action className="shrink-0 self-center rounded-md bg-primary px-2 py-1 text-xs font-medium text-primary-foreground hover:bg-primary/85" />
        <Toast.Close
          aria-label="Dismiss"
          className="absolute top-2 right-2 rounded-md p-1 text-muted-foreground opacity-60 hover:bg-muted hover:opacity-100"
        >
          <XIcon className="size-3.5" />
        </Toast.Close>
      </Toast.Content>
    </Toast.Root>
  ))
}

function StockBody({ id, data }: { id: string; data: StockAlert }) {
  const pct = Math.min(100, Math.round((data.onHand / data.reorderPoint) * 100))
  return (
    <div className="mt-2 grid gap-2">
      <div className="flex items-center justify-between text-xs text-muted-foreground">
        <span className="font-mono">{data.sku}</span>
        <span className="tabular-nums">
          {data.onHand} / {data.reorderPoint} reorder point
        </span>
      </div>
      <div className="h-1.5 overflow-hidden rounded-full bg-muted">
        <div className={cn("h-full rounded-full", pct < 50 ? "bg-rose-500" : "bg-amber-500")} style={{ width: `${pct}%` }} />
      </div>
      <div className="flex gap-2">
        <button
          type="button"
          className="rounded-md bg-primary px-2 py-1 text-xs font-medium text-primary-foreground hover:bg-primary/85"
          onClick={() =>
            baseToasts.update(id, {
              type: "success",
              title: `PO raised for ${data.name}`,
              description: "PO-20931 · 240 units from Shah Alam DC supplier",
              data: undefined,
              timeout: 4000,
            })
          }
        >
          Reorder 240
        </button>
        <button
          type="button"
          className="rounded-md border px-2 py-1 text-xs font-medium hover:bg-muted"
          onClick={() => baseToasts.close(id)}
        >
          Snooze 1 day
        </button>
      </div>
    </div>
  )
}

/* Stacking & position: Base UI exposes the numbers (--toast-index, --toast-offset-y, swipe movement,
 * data-expanded / data-behind / data-starting-style…), the layout is up to us. Adapted from the Base UI
 * docs and extended to handle top and bottom positions. */
const stackCss = `
.bt-viewport { position: fixed; z-index: 60; width: 22rem; max-width: calc(100vw - 2rem); }
.bt-viewport[data-pos="bottom-right"] { bottom: 1.5rem; right: 1.5rem; }
.bt-viewport[data-pos="bottom-center"] { bottom: 1.5rem; left: 0; right: 0; margin: 0 auto; }
.bt-viewport[data-pos="top-right"] { top: 1.5rem; right: 1.5rem; }
.bt-viewport[data-pos="top-center"] { top: 1.5rem; left: 0; right: 0; margin: 0 auto; }

.bt-toast {
  --gap: 0.75rem;
  --peek: 0.75rem;
  --scale: calc(max(0, 1 - (var(--toast-index) * 0.1)));
  --shrink: calc(1 - var(--scale));
  --height: var(--toast-frontmost-height, var(--toast-height));
  position: absolute; left: 0; right: 0; width: 100%; box-sizing: border-box;
  z-index: calc(1000 - var(--toast-index));
  height: var(--height);
  transition: transform 0.5s cubic-bezier(0.22, 1, 0.36, 1), opacity 0.5s, height 0.15s;
}
.bt-toast::after { content: ""; position: absolute; left: 0; width: 100%; height: calc(var(--gap) + 1px); }

[data-pos^="bottom"] .bt-toast {
  bottom: 0; transform-origin: bottom center;
  --offset-y: calc(var(--toast-offset-y) * -1 + var(--toast-index) * var(--gap) * -1 + var(--toast-swipe-movement-y));
  transform: translateX(var(--toast-swipe-movement-x))
    translateY(calc(var(--toast-swipe-movement-y) - var(--toast-index) * var(--peek) - var(--shrink) * var(--height)))
    scale(var(--scale));
}
[data-pos^="bottom"] .bt-toast::after { top: 100%; }

[data-pos^="top"] .bt-toast {
  top: 0; transform-origin: top center;
  --offset-y: calc(var(--toast-offset-y) + var(--toast-index) * var(--gap) + var(--toast-swipe-movement-y));
  transform: translateX(var(--toast-swipe-movement-x))
    translateY(calc(var(--toast-swipe-movement-y) + var(--toast-index) * var(--peek) + var(--shrink) * var(--height)))
    scale(var(--scale));
}
[data-pos^="top"] .bt-toast::after { bottom: 100%; }

.bt-viewport .bt-toast[data-expanded],
.bt-viewport[data-always-expanded] .bt-toast {
  transform: translateX(var(--toast-swipe-movement-x)) translateY(var(--offset-y));
  height: var(--toast-height);
}

[data-pos^="bottom"] .bt-toast[data-starting-style],
[data-pos^="bottom"] .bt-toast[data-ending-style]:not([data-limited]):not([data-swipe-direction]) { transform: translateY(150%); }
[data-pos^="top"] .bt-toast[data-starting-style],
[data-pos^="top"] .bt-toast[data-ending-style]:not([data-limited]):not([data-swipe-direction]) { transform: translateY(-150%); }

.bt-toast[data-ending-style], .bt-toast[data-limited] { opacity: 0; }
.bt-viewport .bt-toast[data-ending-style][data-swipe-direction="down"] { transform: translateY(calc(var(--toast-swipe-movement-y) + 150%)); }
.bt-viewport .bt-toast[data-ending-style][data-swipe-direction="up"] { transform: translateY(calc(var(--toast-swipe-movement-y) - 150%)); }
.bt-viewport .bt-toast[data-ending-style][data-swipe-direction="left"] { transform: translateX(calc(var(--toast-swipe-movement-x) - 150%)) translateY(var(--offset-y)); }
.bt-viewport .bt-toast[data-ending-style][data-swipe-direction="right"] { transform: translateX(calc(var(--toast-swipe-movement-x) + 150%)) translateY(var(--offset-y)); }

.bt-content { position: relative; height: 100%; overflow: hidden; transition: opacity 0.25s cubic-bezier(0.22, 1, 0.36, 1); }
.bt-content[data-behind] { opacity: 0; }
.bt-content[data-expanded], .bt-viewport[data-always-expanded] .bt-content { opacity: 1; }

/* "Rich colors", Sonner-style tints by type. */
.bt-viewport[data-rich] .bt-toast[data-type="success"] { background: hsl(143 85% 96%); border-color: hsl(145 92% 87%); color: hsl(140 100% 27%); }
.bt-viewport[data-rich] .bt-toast[data-type="error"] { background: hsl(359 100% 97%); border-color: hsl(359 100% 94%); color: hsl(360 100% 45%); }
.bt-viewport[data-rich] .bt-toast[data-type="info"] { background: hsl(208 100% 97%); border-color: hsl(221 91% 93%); color: hsl(210 92% 45%); }
.bt-viewport[data-rich] .bt-toast[data-type="warning"] { background: hsl(49 100% 97%); border-color: hsl(49 91% 84%); color: hsl(31 92% 45%); }
.dark .bt-viewport[data-rich] .bt-toast[data-type="success"] { background: hsl(150 100% 6%); border-color: hsl(147 100% 12%); color: hsl(150 86% 65%); }
.dark .bt-viewport[data-rich] .bt-toast[data-type="error"] { background: hsl(358 76% 10%); border-color: hsl(357 89% 16%); color: hsl(358 100% 81%); }
.dark .bt-viewport[data-rich] .bt-toast[data-type="info"] { background: hsl(215 100% 6%); border-color: hsl(223 43% 17%); color: hsl(216 87% 65%); }
.dark .bt-viewport[data-rich] .bt-toast[data-type="warning"] { background: hsl(64 100% 6%); border-color: hsl(60 100% 9%); color: hsl(46 87% 65%); }
.bt-viewport[data-rich] .bt-toast[data-type] .bt-desc { color: inherit; opacity: 0.85; }
.bt-viewport[data-rich] .bt-toast[data-type] svg { color: inherit; }
`

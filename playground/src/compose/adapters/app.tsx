// App components: button, toast, drawer, command menu, tabs.
import { useId, useState, type FormEvent, type ReactNode } from "react"
import { toast, type ToasterProps } from "sonner"
import { Toast } from "@base-ui/react/toast"
import { Dialog as RDialog, Tabs as RTabs } from "radix-ui"
import { Drawer as Vaul } from "vaul"
import {
  CheckIcon,
  CircleCheckIcon,
  FileTextIcon,
  HistoryIcon,
  InfoIcon,
  LayoutDashboardIcon,
  ListIcon,
  Loader2Icon,
  OctagonXIcon,
  PackageCheckIcon,
  PackageIcon,
  PauseIcon,
  PencilIcon,
  PlusIcon,
  SearchIcon,
  ShoppingCartIcon,
  SkipForwardIcon,
  SparklesIcon,
  StoreIcon,
  TriangleAlertIcon,
  TruckIcon,
  UsersIcon,
  XIcon,
  type LucideIcon,
} from "lucide-react"

import { Button } from "@/components/ui/button"
import { Toaster } from "@/components/ui/sonner"
import { ShimmerButton } from "@/components/ui/shimmer-button"
import { Button as MovingBorderButton } from "@/components/ui/moving-border"
import { RippleButton, RippleButtonRipples } from "@/components/animate-ui/components/buttons/ripple"
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from "@/components/ui/drawer"
import {
  Sheet,
  SheetClose,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"
import {
  Command,
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
  CommandShortcut,
} from "@/components/ui/command"
import {
  Combobox,
  ComboboxChip,
  ComboboxChips,
  ComboboxChipsInput,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxInput,
  ComboboxItem,
  ComboboxList,
  ComboboxValue,
  useComboboxAnchor,
} from "@/components/ui/combobox"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Kbd, KbdGroup } from "@/components/ui/kbd"
import { cn } from "@/lib/utils"
import { OrderSummary, PickList } from "@/demos/app/order-panel"
import { AnimatedTabsPatched } from "@/demos/community/animated-tabs-patched"
import type { Tab } from "@/demos/community/animated-tabs"
import { customers, order4821, rm, skus, wait, type Customer, type Sku } from "@/demos/app/data"
import type { Adapter, BlockProps } from "../types"

/* ------------------------------------------------------------------------------------------------
 * Shared bits
 * ---------------------------------------------------------------------------------------------- */

const ORDER_LINE = "Mydin Subang Jaya · 4 lines · RM 2,665.20"

/** The small card most blocks sit in: what it's about on the left, the control on the right. */
function BlockRow({ title, sub, children }: { title: ReactNode; sub: ReactNode; children: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-lg border p-4">
      <div className="min-w-0">
        <div className="text-sm font-medium">{title}</div>
        <div className="truncate text-xs text-muted-foreground">{sub}</div>
      </div>
      {children}
    </div>
  )
}

/** Turns `{ a: "x", b: true, c: false }` into ` a="x" b` for code snippets. */
const props = (p: Record<string, string | boolean | undefined>) =>
  Object.entries(p)
    .map(([k, v]) => (v === true ? ` ${k}` : typeof v === "string" ? ` ${k}=${v.startsWith("{") ? v : `"${v}"`}` : ""))
    .join("")

/* ------------------------------------------------------------------------------------------------
 * Button
 * ---------------------------------------------------------------------------------------------- */

type ButtonVariant = "default" | "secondary" | "outline" | "ghost" | "destructive"

/** One job per variant, so switching the variant also shows what it's for. */
const buttonJobs: Record<ButtonVariant, { label: string; icon: LucideIcon; iconName: string; done: string }> = {
  default: { label: "Confirm order", icon: CheckIcon, iconName: "CheckIcon", done: "Confirmed · stock reserved at Shah Alam DC" },
  secondary: { label: "Edit lines", icon: PencilIcon, iconName: "PencilIcon", done: "Editing · 4 lines unlocked" },
  outline: { label: "Hold order", icon: PauseIcon, iconName: "PauseIcon", done: "On hold · Mydin Subang Jaya notified" },
  ghost: { label: "Skip for now", icon: SkipForwardIcon, iconName: "SkipForwardIcon", done: "Skipped · back in the picking queue" },
  destructive: { label: "Cancel order", icon: XIcon, iconName: "XIcon", done: "Cancelled · 264 units released" },
}

function ShadcnButtonBlock({ options }: BlockProps) {
  const variant = options.variant as ButtonVariant
  const job = buttonJobs[variant]
  const [doneFor, setDoneFor] = useState<string | null>(null)
  const loading = options.loading as boolean
  return (
    <BlockRow title="Order #4821" sub={doneFor === variant ? job.done : ORDER_LINE}>
      <Button
        variant={variant}
        size={options.size as "sm" | "default" | "lg"}
        disabled={loading}
        onClick={() => setDoneFor(variant)}
      >
        {loading ? (
          <Loader2Icon data-icon="inline-start" className="motion-safe:animate-spin" />
        ) : (
          options.icon && <job.icon data-icon="inline-start" />
        )}
        {loading ? "Saving…" : job.label}
      </Button>
    </BlockRow>
  )
}

const shimmerBackgrounds: Record<string, string> = {
  primary: "var(--primary)",
  black: "rgba(0, 0, 0, 1)",
  indigo: "linear-gradient(135deg, #4f46e5, #7c3aed)",
  emerald: "linear-gradient(135deg, #047857, #0d9488)",
}

/** "Theme primary" also swaps the text and the shimmer to primary-foreground, so it reads in both themes. */
const shimmerProps = (o: BlockProps["options"]) => {
  const themed = o.background === "primary"
  const hero = o.size === "hero"
  return {
    background: shimmerBackgrounds[o.background as string],
    shimmerColor: themed ? "var(--primary-foreground)" : undefined,
    shimmerDuration: o.speed as string,
    borderRadius: o.shape === "pill" ? "100px" : "8px",
    className: cn(hero ? "text-base font-medium" : "h-8 px-3 text-sm", themed && "text-primary-foreground"),
  }
}

function ShimmerBlock({ options }: BlockProps) {
  const [done, setDone] = useState(false)
  return (
    <BlockRow title="You've used 4 of 5 warehouses" sub={done ? "Growth trial started · 14 days free" : "Growth adds the Kuching and KK depots"}>
      <ShimmerButton {...shimmerProps(options)} onClick={() => setDone(true)}>
        <SparklesIcon className="mr-1.5 size-3.5" />
        Upgrade to Growth
      </ShimmerButton>
    </BlockRow>
  )
}

const borderRadii: Record<string, string> = { pill: "1.75rem", rounded: "0.75rem", square: "0.25rem" }
const AMBER_GLOW = "bg-[radial-gradient(#f59e0b_40%,transparent_60%)]"
const THEMED_INSIDE = "border-border bg-background text-sm font-medium text-foreground"

function MovingBorderBlock({ options }: BlockProps) {
  const themed = options.look === "themed"
  const [done, setDone] = useState(false)
  return (
    <BlockRow
      title="Rantai for distributors"
      sub={done ? "Demo request sent · we'll call within 1 working day" : "Orders, routes and stock at every DC in one view"}
    >
      <MovingBorderButton
        borderRadius={borderRadii[options.shape as string]}
        duration={Number(options.lap)}
        containerClassName="h-10 w-36 shrink-0"
        borderClassName={themed ? AMBER_GLOW : undefined}
        className={themed ? THEMED_INSIDE : "text-sm font-medium"}
        onClick={() => setDone(true)}
      >
        Book a demo
      </MovingBorderButton>
    </BlockRow>
  )
}

type RippleVariant = "default" | "secondary" | "outline" | "ghost"

function RippleBlock({ options }: BlockProps) {
  const variant = options.variant as RippleVariant
  const job = buttonJobs[variant]
  const scale = options.scale as boolean
  const [doneFor, setDoneFor] = useState<string | null>(null)
  return (
    <BlockRow title="Order #4821" sub={doneFor === variant ? job.done : ORDER_LINE}>
      <RippleButton
        variant={variant}
        size={options.size as "sm" | "default" | "lg"}
        hoverScale={scale ? 1.05 : 1}
        tapScale={scale ? 0.95 : 1}
        onClick={() => setDoneFor(variant)}
      >
        {job.label}
        <RippleButtonRipples />
      </RippleButton>
    </BlockRow>
  )
}

const buttonVariantChoices = [
  { value: "default", label: "Default" },
  { value: "secondary", label: "Secondary" },
  { value: "outline", label: "Outline" },
  { value: "ghost", label: "Ghost" },
]

const buttonSizeChoices = [
  { value: "sm", label: "Small" },
  { value: "default", label: "Default" },
  { value: "lg", label: "Large" },
]

/* ------------------------------------------------------------------------------------------------
 * Toast
 * ---------------------------------------------------------------------------------------------- */

/** Each Sonner block has its own Toaster, so its position option doesn't move anyone else's. */
function SonnerToast({ options }: BlockProps) {
  const id = useId()
  const kind = options.kind as string
  const to = { toasterId: id, description: options.description ? "4 lines · RM 2,665.20 · ships Tue from Shah Alam DC" : undefined }
  const fire = () => {
    if (kind === "success") toast.success("Order #4821 saved", to)
    else if (kind === "error") toast.error("Couldn't sync stock levels", to)
    else if (kind === "action")
      toast("Order #4816 archived", { ...to, action: { label: "Undo", onClick: () => toast.success("Order #4816 restored", { toasterId: id }) } })
    else if (kind === "promise")
      toast.promise(new Promise((r) => setTimeout(r, 1500)), { toasterId: id, loading: "Saving order…", success: "Order #4821 saved", error: "Couldn't save" })
    else toast("Order #4821 saved", to)
  }
  return (
    <>
      <div className="flex items-center justify-between gap-4 rounded-lg border p-4">
        <div>
          <div className="text-sm font-medium">Order #4821</div>
          <div className="text-xs text-muted-foreground">Jaya Grocer Bangsar · 4 lines</div>
        </div>
        <Button onClick={fire}>Save order</Button>
      </div>
      {/* Outside the row: Sonner renders an inline <section>, which would push the button to the middle. */}
      <Toaster id={id} position={options.position as ToasterProps["position"]} richColors={options.rich as boolean} />
    </>
  )
}

type BaseToastPosition = "top-right" | "top-center" | "bottom-right" | "bottom-center"

const baseToastIcon: Record<string, ReactNode> = {
  success: <CircleCheckIcon className="text-emerald-600 dark:text-emerald-400" />,
  error: <OctagonXIcon className="text-rose-600 dark:text-rose-400" />,
  info: <InfoIcon className="text-sky-600 dark:text-sky-400" />,
  warning: <TriangleAlertIcon className="text-amber-600 dark:text-amber-400" />,
  loading: <Loader2Icon className="text-muted-foreground motion-safe:animate-spin" />,
}

/**
 * The card list from src/demos/app/base-toast.tsx. That file's list and CSS are wired to one global
 * manager; here each block has its own Provider and manager, so blocks don't show each other's toasts.
 */
function BaseToastList({ position }: { position: BaseToastPosition }) {
  const { toasts } = Toast.useToastManager()
  const swipe: ("up" | "down" | "right")[] = position.startsWith("top") ? ["up", "right"] : ["down", "right"]
  return toasts.map((t) => (
    <Toast.Root
      key={t.id}
      toast={t}
      swipeDirection={swipe}
      className="cbt-toast rounded-xl border bg-popover text-popover-foreground shadow-lg outline-none select-none focus-visible:ring-3 focus-visible:ring-ring/50"
    >
      <Toast.Content className="cbt-content flex items-start gap-3 py-3 pr-9 pl-3.5">
        {t.type && baseToastIcon[t.type] && <span className="mt-0.5 shrink-0 [&_svg]:size-4">{baseToastIcon[t.type]}</span>}
        <div className="grid min-w-0 flex-1 gap-0.5">
          <Toast.Title className="text-sm font-medium" />
          <Toast.Description className="cbt-desc text-[13px] text-muted-foreground" />
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

function BaseUiToast({ options }: BlockProps) {
  const [manager] = useState(() => Toast.createToastManager())
  const position = options.position as BaseToastPosition
  const kind = options.kind as string
  const description = "4 lines · RM 2,665.20 · ships Tue from Shah Alam DC"
  const fire = () => {
    if (kind === "success") manager.add({ type: "success", title: "Order #4821 saved", description })
    else if (kind === "error")
      manager.add({ type: "error", title: "Couldn't sync stock levels", description: "Johor Bahru DC didn't respond after 30 s." })
    else if (kind === "action") {
      const id = manager.add({
        title: "Order #4816 archived",
        description: "Penang Fresh Market · RM 640.80",
        actionProps: {
          children: "Undo",
          onClick: () => {
            manager.close(id)
            manager.add({ type: "success", title: "Order #4816 restored" })
          },
        },
      })
    } else if (kind === "promise")
      manager
        .promise(wait(1500), {
          loading: { title: "Saving order #4821…", description: "Reserving stock at Shah Alam DC" },
          success: { title: "Order #4821 saved", description },
          error: { title: "Couldn't save order #4821" },
        })
        // Unlike Sonner, the returned promise rejects: catch it or you get an unhandled rejection.
        .catch(() => {})
    else manager.add({ title: "Order #4821 saved", description })
  }
  return (
    <Toast.Provider toastManager={manager}>
      <BlockRow title="Order #4821" sub="Jaya Grocer Bangsar · 4 lines">
        <Button onClick={fire}>Save order</Button>
      </BlockRow>
      <style>{baseToastCss}</style>
      <Toast.Portal>
        <Toast.Viewport
          className="cbt-viewport"
          data-pos={position}
          data-always-expanded={options.expanded ? "" : undefined}
          data-rich={options.rich ? "" : undefined}
        >
          <BaseToastList position={position} />
        </Toast.Viewport>
      </Toast.Portal>
    </Toast.Provider>
  )
}

/* Stacking and position, copied from src/demos/app/base-toast.tsx with a `cbt-` prefix. Base UI
 * exposes the numbers (--toast-index, --toast-offset-y, swipe movement, data-expanded…); the layout is ours. */
const baseToastCss = `
.cbt-viewport { position: fixed; z-index: 60; width: 22rem; max-width: calc(100vw - 2rem); }
.cbt-viewport[data-pos="bottom-right"] { bottom: 1.5rem; right: 1.5rem; }
.cbt-viewport[data-pos="bottom-center"] { bottom: 1.5rem; left: 0; right: 0; margin: 0 auto; }
.cbt-viewport[data-pos="top-right"] { top: 1.5rem; right: 1.5rem; }
.cbt-viewport[data-pos="top-center"] { top: 1.5rem; left: 0; right: 0; margin: 0 auto; }

.cbt-toast {
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
.cbt-toast::after { content: ""; position: absolute; left: 0; width: 100%; height: calc(var(--gap) + 1px); }

[data-pos^="bottom"] .cbt-toast {
  bottom: 0; transform-origin: bottom center;
  --offset-y: calc(var(--toast-offset-y) * -1 + var(--toast-index) * var(--gap) * -1 + var(--toast-swipe-movement-y));
  transform: translateX(var(--toast-swipe-movement-x))
    translateY(calc(var(--toast-swipe-movement-y) - var(--toast-index) * var(--peek) - var(--shrink) * var(--height)))
    scale(var(--scale));
}
[data-pos^="bottom"] .cbt-toast::after { top: 100%; }

[data-pos^="top"] .cbt-toast {
  top: 0; transform-origin: top center;
  --offset-y: calc(var(--toast-offset-y) + var(--toast-index) * var(--gap) + var(--toast-swipe-movement-y));
  transform: translateX(var(--toast-swipe-movement-x))
    translateY(calc(var(--toast-swipe-movement-y) + var(--toast-index) * var(--peek) + var(--shrink) * var(--height)))
    scale(var(--scale));
}
[data-pos^="top"] .cbt-toast::after { bottom: 100%; }

.cbt-viewport .cbt-toast[data-expanded],
.cbt-viewport[data-always-expanded] .cbt-toast {
  transform: translateX(var(--toast-swipe-movement-x)) translateY(var(--offset-y));
  height: var(--toast-height);
}

[data-pos^="bottom"] .cbt-toast[data-starting-style],
[data-pos^="bottom"] .cbt-toast[data-ending-style]:not([data-limited]):not([data-swipe-direction]) { transform: translateY(150%); }
[data-pos^="top"] .cbt-toast[data-starting-style],
[data-pos^="top"] .cbt-toast[data-ending-style]:not([data-limited]):not([data-swipe-direction]) { transform: translateY(-150%); }

.cbt-toast[data-ending-style], .cbt-toast[data-limited] { opacity: 0; }
.cbt-viewport .cbt-toast[data-ending-style][data-swipe-direction="down"] { transform: translateY(calc(var(--toast-swipe-movement-y) + 150%)); }
.cbt-viewport .cbt-toast[data-ending-style][data-swipe-direction="up"] { transform: translateY(calc(var(--toast-swipe-movement-y) - 150%)); }
.cbt-viewport .cbt-toast[data-ending-style][data-swipe-direction="right"] { transform: translateX(calc(var(--toast-swipe-movement-x) + 150%)) translateY(var(--offset-y)); }

.cbt-content { position: relative; height: 100%; overflow: hidden; transition: opacity 0.25s cubic-bezier(0.22, 1, 0.36, 1); }
.cbt-content[data-behind] { opacity: 0; }
.cbt-content[data-expanded], .cbt-viewport[data-always-expanded] .cbt-content { opacity: 1; }

/* "Rich colours", Sonner-style tints by type. */
.cbt-viewport[data-rich] .cbt-toast[data-type="success"] { background: hsl(143 85% 96%); border-color: hsl(145 92% 87%); color: hsl(140 100% 27%); }
.cbt-viewport[data-rich] .cbt-toast[data-type="error"] { background: hsl(359 100% 97%); border-color: hsl(359 100% 94%); color: hsl(360 100% 45%); }
.dark .cbt-viewport[data-rich] .cbt-toast[data-type="success"] { background: hsl(150 100% 6%); border-color: hsl(147 100% 12%); color: hsl(150 86% 65%); }
.dark .cbt-viewport[data-rich] .cbt-toast[data-type="error"] { background: hsl(358 76% 10%); border-color: hsl(357 89% 16%); color: hsl(358 100% 81%); }
.cbt-viewport[data-rich] .cbt-toast[data-type] .cbt-desc { color: inherit; opacity: 0.85; }
.cbt-viewport[data-rich] .cbt-toast[data-type] svg { color: inherit; }
`

const toastPositionChoices = [
  { value: "top-center", label: "Top" },
  { value: "top-right", label: "Top right" },
  { value: "bottom-center", label: "Bottom" },
  { value: "bottom-right", label: "Bottom right" },
]

const toastKindChoices = [
  { value: "default", label: "Plain" },
  { value: "success", label: "Success" },
  { value: "error", label: "Error" },
  { value: "action", label: "With Undo" },
  { value: "promise", label: "Promise" },
]

/* ------------------------------------------------------------------------------------------------
 * Drawer
 * ---------------------------------------------------------------------------------------------- */

type Side = "bottom" | "right" | "left" | "top"
const toSwipe = { bottom: "down", top: "up", right: "right", left: "left" } as const
const sideChoices = [
  { value: "bottom", label: "Bottom" },
  { value: "right", label: "Right" },
  { value: "left", label: "Left" },
  { value: "top", label: "Top" },
]

const snapPoints: (number | string)[] = ["180px", 0.55, 1]
const snapLabel = (s: number | string | null) => (s === "180px" ? "peek" : s === 0.55 ? "half" : s === 1 ? "full" : "closed")

function SnapButtons({ value, onChange }: { value: number | string | null; onChange: (s: number | string) => void }) {
  return (
    <div className="flex gap-1">
      {snapPoints.map((s) => (
        <Button key={String(s)} size="xs" variant={value === s ? "default" : "outline"} onClick={() => onChange(s)}>
          {snapLabel(s)}
        </Button>
      ))}
    </div>
  )
}

const PACKED = "Packed · 264 units ready at Shah Alam DC"
const isPanel = (side: Side) => side === "left" || side === "right"

/** Body and footer shared by every drawer, so the comparison is about the container. */
function OrderBody({ side }: { side: Side }) {
  return (
    <div className="min-h-0 flex-1 overflow-y-auto px-4 pt-4">
      <OrderSummary timeline={isPanel(side)} />
    </div>
  )
}

function OrderFooter({ close, pack }: { close: ReactNode; pack: ReactNode }) {
  return (
    <div className="flex gap-2 p-4">
      {close}
      <div className="flex-1" />
      {pack}
    </div>
  )
}

function BaseDrawerBlock({ options }: BlockProps) {
  const useSnap = options.snap as boolean
  const side: Side = useSnap ? "bottom" : (options.side as Side)
  const [packed, setPacked] = useState(false)
  const [snap, setSnap] = useState<number | string | null>(snapPoints[0])
  if (useSnap)
    return (
      <Drawer
        key="snap"
        snapPoints={snapPoints}
        snapPoint={snap}
        onSnapPointChange={setSnap}
        showSwipeHandle={options.handle as boolean}
        onOpenChangeComplete={(open) => !open && setSnap(snapPoints[0])}
      >
        <BlockRow title="Wave 3 · Shah Alam DC" sub={`24 picks across 12 orders · opens at ${snapLabel(snapPoints[0])}`}>
          <DrawerTrigger render={<Button variant="outline" />}>Open pick list</DrawerTrigger>
        </BlockRow>
        <DrawerContent>
          <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
            <div className="flex items-start justify-between gap-3 px-4 pt-3 pb-3">
              <div className="grid gap-0.5">
                <DrawerTitle>Wave 3 · Shah Alam DC</DrawerTitle>
                <DrawerDescription>24 picks across 12 orders · {snapLabel(snap)}</DrawerDescription>
              </div>
              <SnapButtons value={snap} onChange={setSnap} />
            </div>
            <div className="min-h-0 flex-1 overflow-y-auto px-4 pb-4">
              <PickList />
            </div>
          </div>
        </DrawerContent>
      </Drawer>
    )
  return (
    <Drawer key={side} swipeDirection={toSwipe[side]} showSwipeHandle={options.handle as boolean}>
      <BlockRow title="Order #4821" sub={packed ? PACKED : ORDER_LINE}>
        <DrawerTrigger render={<Button variant="outline" />}>Open order</DrawerTrigger>
      </BlockRow>
      <DrawerContent>
        <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
          <DrawerHeader>
            <DrawerTitle>Order #4821</DrawerTitle>
            <DrawerDescription>{ORDER_LINE}</DrawerDescription>
          </DrawerHeader>
          <OrderBody side={side} />
          <OrderFooter
            close={<DrawerClose render={<Button variant="outline" />}>Close</DrawerClose>}
            pack={
              <DrawerClose render={<Button />} onClick={() => setPacked(true)}>
                <PackageCheckIcon /> Mark as packed
              </DrawerClose>
            }
          />
        </div>
      </DrawerContent>
    </Drawer>
  )
}

function SheetBlock({ options }: BlockProps) {
  const side = options.side as Side
  const [packed, setPacked] = useState(false)
  return (
    <Sheet>
      <BlockRow title="Order #4821" sub={packed ? PACKED : ORDER_LINE}>
        <SheetTrigger render={<Button variant="outline" />}>Open order</SheetTrigger>
      </BlockRow>
      <SheetContent
        side={side}
        showCloseButton={options.closeButton as boolean}
        className={cn("gap-0", !isPanel(side) && "max-h-[85vh]")}
      >
        <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
          <SheetHeader className="pb-0">
            <SheetTitle>Order #4821</SheetTitle>
            <SheetDescription>{ORDER_LINE}</SheetDescription>
          </SheetHeader>
          <div className="min-h-0 flex-1 overflow-y-auto px-4 pt-4">
            <OrderSummary timeline={options.timeline as boolean} />
          </div>
          <OrderFooter
            close={<SheetClose render={<Button variant="outline" />}>Close</SheetClose>}
            pack={
              <SheetClose render={<Button />} onClick={() => setPacked(true)}>
                <PackageCheckIcon /> Mark as packed
              </SheetClose>
            }
          />
        </div>
      </SheetContent>
    </Sheet>
  )
}

// Vaul is unstyled: these mirror what the old (Vaul-based) shadcn Drawer shipped.
const vaulOverlay = "fixed inset-0 z-50 bg-black/30 supports-backdrop-filter:backdrop-blur-xs"
const vaulContent = cn(
  "group/vaul fixed z-50 flex flex-col bg-popover text-sm text-popover-foreground outline-none",
  "data-[vaul-drawer-direction=bottom]:inset-x-0 data-[vaul-drawer-direction=bottom]:bottom-0 data-[vaul-drawer-direction=bottom]:mt-24 data-[vaul-drawer-direction=bottom]:max-h-[85vh] data-[vaul-drawer-direction=bottom]:rounded-t-xl data-[vaul-drawer-direction=bottom]:border-t",
  "data-[vaul-drawer-direction=top]:inset-x-0 data-[vaul-drawer-direction=top]:top-0 data-[vaul-drawer-direction=top]:mb-24 data-[vaul-drawer-direction=top]:max-h-[85vh] data-[vaul-drawer-direction=top]:rounded-b-xl data-[vaul-drawer-direction=top]:border-b",
  "data-[vaul-drawer-direction=right]:inset-y-0 data-[vaul-drawer-direction=right]:right-0 data-[vaul-drawer-direction=right]:w-3/4 data-[vaul-drawer-direction=right]:border-l data-[vaul-drawer-direction=right]:sm:max-w-sm",
  "data-[vaul-drawer-direction=left]:inset-y-0 data-[vaul-drawer-direction=left]:left-0 data-[vaul-drawer-direction=left]:w-3/4 data-[vaul-drawer-direction=left]:border-r data-[vaul-drawer-direction=left]:sm:max-w-sm",
)
const vaulHandle =
  "mx-auto mt-3 hidden h-1.5 w-12 shrink-0 rounded-full bg-muted group-data-[vaul-drawer-direction=bottom]/vaul:block"
const vaulTitle = "text-base font-medium text-foreground"
const vaulDesc = "text-sm text-muted-foreground"

function VaulBlock({ options }: BlockProps) {
  const useSnap = options.snap as boolean
  const side: Side = useSnap ? "bottom" : (options.side as Side)
  const [packed, setPacked] = useState(false)
  const [snap, setSnap] = useState<number | string | null>(snapPoints[0])
  if (useSnap)
    return (
      <Vaul.Root key="snap" snapPoints={snapPoints} activeSnapPoint={snap} setActiveSnapPoint={setSnap}>
        <BlockRow title="Wave 3 · Shah Alam DC" sub={`24 picks across 12 orders · opens at ${snapLabel(snapPoints[0])}`}>
          <Vaul.Trigger asChild>
            <Button variant="outline">Open pick list</Button>
          </Vaul.Trigger>
        </BlockRow>
        <Vaul.Portal>
          <Vaul.Overlay className={vaulOverlay} />
          <Vaul.Content className="fixed inset-x-0 bottom-0 z-50 flex h-full max-h-[97%] flex-col rounded-t-xl border-t bg-popover text-sm text-popover-foreground outline-none">
            <div className="mx-auto mt-3 h-1.5 w-12 shrink-0 rounded-full bg-muted" />
            <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
              <div className="flex items-start justify-between gap-3 px-4 pt-3 pb-3">
                <div className="grid gap-0.5">
                  <Vaul.Title className={vaulTitle}>Wave 3 · Shah Alam DC</Vaul.Title>
                  <Vaul.Description className={vaulDesc}>24 picks across 12 orders · {snapLabel(snap)}</Vaul.Description>
                </div>
                <SnapButtons value={snap} onChange={setSnap} />
              </div>
              <div className={cn("min-h-0 flex-1 px-4 pb-4", snap === 1 ? "overflow-y-auto" : "overflow-hidden")}>
                <PickList />
              </div>
            </div>
          </Vaul.Content>
        </Vaul.Portal>
      </Vaul.Root>
    )
  return (
    <Vaul.Root key={side} direction={side}>
      <BlockRow title="Order #4821" sub={packed ? PACKED : ORDER_LINE}>
        <Vaul.Trigger asChild>
          <Button variant="outline">Open order</Button>
        </Vaul.Trigger>
      </BlockRow>
      <Vaul.Portal>
        <Vaul.Overlay className={vaulOverlay} />
        <Vaul.Content className={vaulContent}>
          <div className={vaulHandle} />
          <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
            <div className="grid gap-0.5 px-4 pt-4">
              <Vaul.Title className={vaulTitle}>Order #4821</Vaul.Title>
              <Vaul.Description className={vaulDesc}>{ORDER_LINE}</Vaul.Description>
            </div>
            <OrderBody side={side} />
            <OrderFooter
              close={
                <Vaul.Close asChild>
                  <Button variant="outline">Close</Button>
                </Vaul.Close>
              }
              pack={
                <Vaul.Close asChild>
                  <Button onClick={() => setPacked(true)}>
                    <PackageCheckIcon /> Mark as packed
                  </Button>
                </Vaul.Close>
              }
            />
          </div>
        </Vaul.Content>
      </Vaul.Portal>
    </Vaul.Root>
  )
}

// Radix exposes data-state="open|closed", so the tw-animate classes key off that, not data-open.
const radixOverlay =
  "fixed inset-0 z-50 bg-black/30 duration-150 supports-backdrop-filter:backdrop-blur-xs data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=closed]:animate-out data-[state=closed]:fade-out-0"
const radixPanel =
  "fixed inset-y-0 z-50 flex h-full w-3/4 flex-col bg-popover text-sm text-popover-foreground shadow-lg outline-none duration-200 data-[state=open]:animate-in data-[state=closed]:animate-out"
const radixPanelSide = {
  right: "right-0 border-l data-[state=open]:slide-in-from-right data-[state=closed]:slide-out-to-right",
  left: "left-0 border-r data-[state=open]:slide-in-from-left data-[state=closed]:slide-out-to-left",
}
const radixPanelWidth: Record<string, string> = { narrow: "sm:max-w-sm", wide: "sm:max-w-lg" }

function RadixPanelBlock({ options }: BlockProps) {
  const side = options.side as "right" | "left"
  const modal = options.modal as boolean
  const [packed, setPacked] = useState(false)
  return (
    <RDialog.Root key={String(modal)} modal={modal}>
      <BlockRow title="Order #4821" sub={packed ? PACKED : ORDER_LINE}>
        {/* Composition: Radix uses `asChild`. */}
        <RDialog.Trigger asChild>
          <Button variant="outline">Open order</Button>
        </RDialog.Trigger>
      </BlockRow>
      <RDialog.Portal>
        {/* Radix renders the overlay only when modal. */}
        <RDialog.Overlay className={radixOverlay} />
        <RDialog.Content
          className={cn(radixPanel, radixPanelSide[side], radixPanelWidth[options.width as string])}
          // Non-modal: an inspector that stays open while you work on the page behind it.
          onInteractOutside={(e) => !modal && e.preventDefault()}
        >
          <div className="flex items-start justify-between gap-3 px-4 pt-4">
            <div className="grid gap-0.5">
              <RDialog.Title className="text-base font-medium text-foreground">Order #4821</RDialog.Title>
              <RDialog.Description className="text-sm text-muted-foreground">{ORDER_LINE}</RDialog.Description>
            </div>
            <RDialog.Close asChild>
              <Button variant="ghost" size="icon-sm" aria-label="Close">
                <XIcon />
              </Button>
            </RDialog.Close>
          </div>
          <OrderBody side={side} />
          <OrderFooter
            close={
              <RDialog.Close asChild>
                <Button variant="outline">Close</Button>
              </RDialog.Close>
            }
            pack={
              <RDialog.Close asChild>
                <Button onClick={() => setPacked(true)}>
                  <PackageCheckIcon /> Mark as packed
                </Button>
              </RDialog.Close>
            }
          />
        </RDialog.Content>
      </RDialog.Portal>
    </RDialog.Root>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Command menu
 * ---------------------------------------------------------------------------------------------- */

/** cmdk's default is a fuzzy scorer ("mss" finds "Mydin Subang Jaya"); this is the plain alternative. */
const containsFilter = (value: string, search: string, keywords?: string[]) =>
  [value, ...(keywords ?? [])].join(" ").toLowerCase().includes(search.toLowerCase()) ? 1 : 0

const containsSnippet = `/** Plain substring match instead of cmdk's fuzzy scorer. */
const contains = (value: string, search: string, keywords?: string[]) =>
  [value, ...(keywords ?? [])].join(" ").toLowerCase().includes(search.toLowerCase()) ? 1 : 0

`

const navItems = [
  { icon: LayoutDashboardIcon, label: "Dashboard", keys: "G D" },
  { icon: ShoppingCartIcon, label: "Orders", keys: "G O" },
  { icon: PackageIcon, label: "Stock levels", keys: "G S" },
  { icon: UsersIcon, label: "Customers", keys: "G C" },
  { icon: FileTextIcon, label: "Reports", keys: "G R" },
]

function CmdkPaletteBlock({ options }: BlockProps) {
  const [open, setOpen] = useState(false)
  const [last, setLast] = useState<string | null>(null)
  const hints = options.hints as boolean
  const run = (what: string) => {
    setOpen(false)
    setLast(what)
  }
  return (
    <>
      <BlockRow title="Command menu" sub={last ? `Ran: ${last}` : "Jump to a page, an order or a customer"}>
        {/* Opens on click only: several palettes can share a canvas, so no global ⌘K listener here. */}
        <Button variant="outline" className="w-60 justify-between text-muted-foreground" onClick={() => setOpen(true)}>
          <span className="flex items-center gap-2">
            <SearchIcon /> Search or jump to…
          </span>
          {hints && (
            <KbdGroup>
              <Kbd>⌘</Kbd>
              <Kbd>K</Kbd>
            </KbdGroup>
          )}
        </Button>
      </BlockRow>
      <CommandDialog open={open} onOpenChange={setOpen} className="sm:max-w-lg">
        <Command filter={options.matching === "contains" ? containsFilter : undefined}>
          <CommandInput placeholder="Type a command or search…" />
          <CommandList className="max-h-80">
            <CommandEmpty>No results. Try “order”, “stock” or a customer name.</CommandEmpty>
            <CommandGroup heading="Suggestions">
              <CommandItem onSelect={() => run("New order")}>
                <PlusIcon /> New order {hints && <CommandShortcut>⌘N</CommandShortcut>}
              </CommandItem>
              <CommandItem value="Open order #4821" keywords={["Mydin", "picking"]} onSelect={() => run("Open order #4821")}>
                <ShoppingCartIcon /> <span className="flex-1">Open order #4821</span>
                <span className="text-xs text-muted-foreground tabular-nums">{rm(2665.2)}</span>
              </CommandItem>
            </CommandGroup>
            <CommandSeparator />
            <CommandGroup heading="Navigate">
              {navItems.map(({ icon: Icon, label, keys }) => (
                <CommandItem key={label} onSelect={() => run(`Go to ${label}`)}>
                  <Icon /> {label} {hints && <CommandShortcut>{keys}</CommandShortcut>}
                </CommandItem>
              ))}
            </CommandGroup>
            {options.customers && (
              <>
                <CommandSeparator />
                <CommandGroup heading="Customers">
                  {customers.slice(0, 6).map((c) => (
                    <CommandItem
                      key={c.id}
                      value={`${c.name} ${c.id}`}
                      keywords={[c.area, c.channel]}
                      onSelect={() => run(`Open ${c.name}`)}
                    >
                      <StoreIcon /> <span className="flex-1 truncate">{c.name}</span>
                      <span className="text-xs text-muted-foreground">{c.area}</span>
                    </CommandItem>
                  ))}
                </CommandGroup>
              </>
            )}
          </CommandList>
          {hints && (
            <div className="flex items-center gap-3 border-t px-3 py-2 text-xs text-muted-foreground">
              <span className="flex items-center gap-1">
                <Kbd>↑</Kbd>
                <Kbd>↓</Kbd> move
              </span>
              <span className="flex items-center gap-1">
                <Kbd>↵</Kbd> run
              </span>
              <span className="flex items-center gap-1">
                <Kbd>esc</Kbd> close
              </span>
            </div>
          )}
        </Command>
      </CommandDialog>
    </>
  )
}

const skuGroups = Object.entries(
  skus.reduce<Record<string, Sku[]>>((acc, s) => {
    ;(acc[s.category] ??= []).push(s)
    return acc
  }, {}),
)

function stockBadge(s: Sku) {
  return (
    <span
      className={cn(
        "rounded px-1.5 py-0.5 text-xs tabular-nums",
        s.onHand === 0
          ? "bg-muted text-muted-foreground"
          : s.onHand < 100
            ? "bg-amber-500/15 text-amber-700 dark:text-amber-300"
            : "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300",
      )}
    >
      {s.onHand === 0 ? "out" : s.onHand.toLocaleString()}
    </span>
  )
}

function CmdkInlineBlock({ options }: BlockProps) {
  const [picked, setPicked] = useState<Sku | null>(null)
  const item = (s: Sku) => (
    <CommandItem
      key={s.sku}
      value={s.sku}
      keywords={[s.name, s.category]}
      disabled={s.onHand === 0}
      data-checked={picked?.sku === s.sku}
      onSelect={() => setPicked(s)}
    >
      {/* flex-1: CommandItem appends its own ml-auto check icon, which would split the free space. */}
      <span className="min-w-0 flex-1 truncate">{s.name}</span>
      <span className="font-mono text-xs text-muted-foreground">{s.sku}</span>
      {options.stock && stockBadge(s)}
    </CommandItem>
  )
  return (
    <div className="grid gap-2">
      <Command filter={options.matching === "contains" ? containsFilter : undefined} className="border">
        <CommandInput placeholder="Filter by name, SKU code or category…" />
        <CommandList className="max-h-44">
          <CommandEmpty>No SKU matches.</CommandEmpty>
          {options.grouped ? (
            skuGroups.map(([category, items]) => (
              <CommandGroup key={category} heading={category}>
                {items.map(item)}
              </CommandGroup>
            ))
          ) : (
            <CommandGroup>{skus.map(item)}</CommandGroup>
          )}
        </CommandList>
      </Command>
      <div className="px-1 text-xs text-muted-foreground">
        {picked
          ? `Added ${picked.sku} to #4821 · ${rm(picked.price)} · ${picked.onHand.toLocaleString()} on hand`
          : "Pick a SKU to add to order #4821"}
      </div>
    </div>
  )
}

function CustomerOption({ c, details }: { c: Customer; details: boolean }) {
  return (
    <ComboboxItem value={c}>
      {details ? (
        <>
          <div className="grid min-w-0">
            <span className="truncate">{c.name}</span>
            <span className="text-xs text-muted-foreground">
              {c.area} · {c.channel}
            </span>
          </div>
          <span className="ml-auto text-xs text-muted-foreground">{c.terms}</span>
        </>
      ) : (
        <>
          <StoreIcon className="text-muted-foreground" />
          <span className="truncate">{c.name}</span>
        </>
      )}
    </ComboboxItem>
  )
}

const customerFns = {
  itemToStringLabel: (c: Customer) => c.name,
  itemToStringValue: (c: Customer) => c.id,
  isItemEqualToValue: (a: Customer, b: Customer) => a.id === b.id,
}

/** What the form would post: every field, with repeated names joined. */
function formSummary(form: HTMLFormElement) {
  const data = new FormData(form)
  return [...new Set(data.keys())].map((k) => `${k}=${data.getAll(k).join(",")}`).join(" · ") || "empty"
}

function ComboSingle({ details, autoHighlight }: { details: boolean; autoHighlight: boolean }) {
  const id = useId()
  const [value, setValue] = useState<Customer | null>(null)
  const [posted, setPosted] = useState<string | null>(null)
  const onSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setPosted(formSummary(e.currentTarget))
  }
  return (
    <form onSubmit={onSubmit} className="grid gap-2 rounded-lg border p-4">
      <label htmlFor={id} className="text-sm font-medium">
        Bill to <span className="text-muted-foreground">(required)</span>
      </label>
      <div className="flex gap-2">
        <Combobox items={customers} value={value} onValueChange={setValue} {...customerFns} name="billTo" required autoHighlight={autoHighlight}>
          <ComboboxInput id={id} placeholder="Search customers…" showClear className="flex-1" />
          <ComboboxContent>
            <ComboboxEmpty>No customer matches.</ComboboxEmpty>
            <ComboboxList>{(c: Customer) => <CustomerOption key={c.id} c={c} details={details} />}</ComboboxList>
          </ComboboxContent>
        </Combobox>
        <Button type="submit" variant="outline">
          Save
        </Button>
      </div>
      <div className="text-xs text-muted-foreground">
        {posted
          ? `Posted ${posted}`
          : value
            ? `${value.channel} · ${value.area} · payment terms ${value.terms}`
            : "Pick a customer to fill in payment terms."}
      </div>
    </form>
  )
}

function ComboMulti({ details, autoHighlight }: { details: boolean; autoHighlight: boolean }) {
  const id = useId()
  const anchor = useComboboxAnchor()
  const [value, setValue] = useState<Customer[]>([customers[1], customers[2]])
  const [posted, setPosted] = useState<string | null>(null)
  const onSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setPosted(formSummary(e.currentTarget))
  }
  return (
    <form onSubmit={onSubmit} className="grid gap-2 rounded-lg border p-4">
      <label htmlFor={id} className="text-sm font-medium">
        Send the Raya promo to
      </label>
      <div className="flex items-start gap-2">
        <Combobox multiple items={customers} value={value} onValueChange={setValue} {...customerFns} name="customers" autoHighlight={autoHighlight}>
          <ComboboxChips ref={anchor} className="flex-1">
            <ComboboxValue>
              {(values: Customer[]) => (
                <>
                  {values.map((c) => (
                    <ComboboxChip key={c.id}>{c.name}</ComboboxChip>
                  ))}
                  <ComboboxChipsInput id={id} placeholder={values.length ? "" : "Add a customer…"} />
                </>
              )}
            </ComboboxValue>
          </ComboboxChips>
          <ComboboxContent anchor={anchor}>
            <ComboboxEmpty>No customer matches.</ComboboxEmpty>
            <ComboboxList>{(c: Customer) => <CustomerOption key={c.id} c={c} details={details} />}</ComboboxList>
          </ComboboxContent>
        </Combobox>
        <Button type="submit" variant="outline">
          Save
        </Button>
      </div>
      <div className="text-xs text-muted-foreground">
        {posted ? `Posted ${posted}` : `${value.length} customer${value.length === 1 ? "" : "s"} · each posts as its own hidden input`}
      </div>
    </form>
  )
}

function ComboboxBlock({ options }: BlockProps) {
  const details = options.details as boolean
  const autoHighlight = options.autoHighlight as boolean
  return options.mode === "multiple" ? (
    <ComboMulti details={details} autoHighlight={autoHighlight} />
  ) : (
    <ComboSingle details={details} autoHighlight={autoHighlight} />
  )
}

const matchingOption = {
  id: "matching",
  label: "Matching",
  type: "select" as const,
  default: "fuzzy",
  choices: [
    { value: "fuzzy", label: "Fuzzy (cmdk)" },
    { value: "contains", label: "Contains" },
  ],
}

/* ------------------------------------------------------------------------------------------------
 * Tabs
 * ---------------------------------------------------------------------------------------------- */

const orderTabs = [
  { id: "lines", label: "Lines", icon: ListIcon, iconName: "ListIcon" },
  { id: "delivery", label: "Delivery", icon: TruckIcon, iconName: "TruckIcon" },
  { id: "activity", label: "Activity", icon: HistoryIcon, iconName: "HistoryIcon" },
]

/** The same three views of order #4821 behind every tabs adapter. */
function OrderTabPanel({ tab }: { tab: string }) {
  if (tab === "lines")
    return (
      <ul className="divide-y rounded-lg border text-sm">
        {order4821.lines.map((l) => (
          <li key={l.sku} className="flex items-center gap-3 px-3 py-1.5">
            <span className="min-w-0 flex-1 truncate">{l.name}</span>
            <span className="text-xs text-muted-foreground tabular-nums">
              {l.qty} × {rm(l.price)}
            </span>
            <span className="w-24 text-right tabular-nums">{rm(l.qty * l.price)}</span>
          </li>
        ))}
      </ul>
    )
  if (tab === "delivery")
    return (
      <dl className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
        <div>
          <dt className="text-xs text-muted-foreground">Ship from</dt>
          <dd className="font-medium">{order4821.warehouse}</dd>
        </div>
        <div>
          <dt className="text-xs text-muted-foreground">ETA</dt>
          <dd className="font-medium">{order4821.eta}</dd>
        </div>
        <div>
          <dt className="text-xs text-muted-foreground">Deliver to</dt>
          <dd className="font-medium">Lot 12, Jalan Subang 3, 47610 Subang Jaya</dd>
        </div>
        <div>
          <dt className="text-xs text-muted-foreground">Receiving hours</dt>
          <dd className="font-medium">Mon–Sat, 8:00–16:00 (bay B)</dd>
        </div>
      </dl>
    )
  return (
    <ol className="grid gap-2 border-l pl-4 text-xs">
      {[
        ["Picking started, wave 3", "Sat 15 Nov, 08:40 · Hafiz Ismail"],
        ["Stock reserved at Shah Alam DC", "Fri 14 Nov, 10:05 · system"],
        ["Order confirmed", "Fri 14 Nov, 10:02 · Aisyah Rahman"],
      ].map(([what, when], i) => (
        <li key={what} className="relative">
          <span
            className={cn(
              "absolute top-1 -left-[21px] size-2.5 rounded-full border-2 border-background",
              i === 0 ? "bg-amber-500" : "bg-muted-foreground/40",
            )}
          />
          <div className="font-medium">{what}</div>
          <div className="text-muted-foreground">{when}</div>
        </li>
      ))}
    </ol>
  )
}

function TabsHeader() {
  return (
    <div className="mb-3 flex items-baseline justify-between gap-3">
      <span className="text-sm font-medium">Order #4821</span>
      <span className="text-xs text-muted-foreground">{ORDER_LINE}</span>
    </div>
  )
}

function ShadcnTabsBlock({ options }: BlockProps) {
  const vertical = options.orientation === "vertical"
  return (
    <div className="rounded-lg border p-4">
      <TabsHeader />
      <Tabs defaultValue="lines" orientation={vertical ? "vertical" : "horizontal"} className={cn(vertical && "gap-4")}>
        <TabsList variant={options.variant as "default" | "line"}>
          {orderTabs.map((t) => (
            <TabsTrigger key={t.id} value={t.id}>
              {options.icons && <t.icon />}
              {t.label}
            </TabsTrigger>
          ))}
        </TabsList>
        {orderTabs.map((t) => (
          <TabsContent key={t.id} value={t.id} className="pt-1">
            <OrderTabPanel tab={t.id} />
          </TabsContent>
        ))}
      </Tabs>
    </div>
  )
}

/* base-nova's tabs look, re-keyed from Base UI's data-active/data-orientation to Radix's data-state.
 * Orientation is read from the Root (group/rtabs) so it doesn't depend on which parts Radix stamps. */
const rTabsRoot = "group/rtabs flex gap-2 data-[orientation=horizontal]:flex-col data-[orientation=vertical]:gap-4"
const rTabsList = {
  pill: "inline-flex w-fit items-center justify-center rounded-lg bg-muted p-[3px] text-muted-foreground group-data-[orientation=horizontal]/rtabs:h-8 group-data-[orientation=vertical]/rtabs:h-fit group-data-[orientation=vertical]/rtabs:flex-col",
  line: "inline-flex w-fit items-center justify-center gap-1 p-[3px] text-muted-foreground group-data-[orientation=horizontal]/rtabs:h-8 group-data-[orientation=vertical]/rtabs:h-fit group-data-[orientation=vertical]/rtabs:flex-col",
}
const rTabsTriggerBase =
  "relative inline-flex h-[calc(100%-1px)] flex-1 items-center justify-center gap-1.5 rounded-md border border-transparent px-1.5 py-0.5 text-sm font-medium whitespace-nowrap text-foreground/60 transition-all outline-none hover:text-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 group-data-[orientation=vertical]/rtabs:w-full group-data-[orientation=vertical]/rtabs:justify-start dark:text-muted-foreground dark:hover:text-foreground [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0 data-[state=active]:text-foreground dark:data-[state=active]:text-foreground"
const rTabsTrigger = {
  pill: cn(rTabsTriggerBase, "data-[state=active]:bg-background data-[state=active]:shadow-sm dark:data-[state=active]:border-input dark:data-[state=active]:bg-input/30"),
  line: cn(
    rTabsTriggerBase,
    "after:absolute after:bg-foreground after:opacity-0 after:transition-opacity group-data-[orientation=horizontal]/rtabs:after:inset-x-0 group-data-[orientation=horizontal]/rtabs:after:bottom-[-5px] group-data-[orientation=horizontal]/rtabs:after:h-0.5 group-data-[orientation=vertical]/rtabs:after:inset-y-0 group-data-[orientation=vertical]/rtabs:after:-right-1 group-data-[orientation=vertical]/rtabs:after:w-0.5 data-[state=active]:after:opacity-100",
  ),
}

function RadixTabsBlock({ options }: BlockProps) {
  const look = options.variant as "pill" | "line"
  return (
    <div className="rounded-lg border p-4">
      <TabsHeader />
      <RTabs.Root defaultValue="lines" orientation={options.orientation as "horizontal" | "vertical"} className={rTabsRoot}>
        <RTabs.List className={rTabsList[look]} aria-label="Order #4821">
          {orderTabs.map((t) => (
            <RTabs.Trigger key={t.id} value={t.id} className={rTabsTrigger[look]}>
              {options.icons && <t.icon />}
              {t.label}
            </RTabs.Trigger>
          ))}
        </RTabs.List>
        {orderTabs.map((t) => (
          <RTabs.Content key={t.id} value={t.id} className="flex-1 pt-1 text-sm outline-none">
            <OrderTabPanel tab={t.id} />
          </RTabs.Content>
        ))}
      </RTabs.Root>
    </div>
  )
}

const rangeTabs: Tab[] = [
  { id: "today", label: "Today" },
  { id: "7d", label: "7 days" },
  { id: "30d", label: "30 days" },
  { id: "qtd", label: "Quarter" },
]
const rangeSales: Record<string, { sales: number; orders: number; top: string }> = {
  today: { sales: 8412.6, orders: 23, top: "Mydin Subang Jaya" },
  "7d": { sales: 48210.4, orders: 128, top: "Borneo Mart Kuching" },
  "30d": { sales: 196540.0, orders: 541, top: "KK Wholesale Centre" },
  qtd: { sales: 512880.75, orders: 1406, top: "KK Wholesale Centre" },
}

function RareTabsBlock({ options }: BlockProps) {
  const ranges = options.set === "range"
  const tabs: Tab[] = ranges ? rangeTabs : orderTabs.map(({ id, label }) => ({ id, label }))
  const [picked, setPicked] = useState<string | null>(null)
  const active = picked && tabs.some((t) => t.id === picked) ? picked : tabs[0].id
  const r = rangeSales[active]
  return (
    <div className="flex flex-col items-center gap-4 rounded-lg border p-4">
      <AnimatedTabsPatched label={ranges ? "Sales period" : "Order #4821"} tabs={tabs} activeTab={active} onChange={setPicked} />
      {options.panel && (
        <div role="tabpanel" className="w-full max-w-md">
          {ranges ? (
            <div className="grid grid-cols-3 gap-3 text-center">
              <div>
                <div className="text-xs text-muted-foreground">Sales</div>
                <div className="font-medium tabular-nums">{rm(r.sales)}</div>
              </div>
              <div>
                <div className="text-xs text-muted-foreground">Orders</div>
                <div className="font-medium tabular-nums">{r.orders.toLocaleString()}</div>
              </div>
              <div>
                <div className="text-xs text-muted-foreground">Top customer</div>
                <div className="truncate font-medium">{r.top}</div>
              </div>
            </div>
          ) : (
            <OrderTabPanel tab={active} />
          )}
        </div>
      )}
    </div>
  )
}

const orientationOption = {
  id: "orientation",
  label: "Orientation",
  type: "select" as const,
  default: "horizontal",
  choices: [
    { value: "horizontal", label: "Horizontal" },
    { value: "vertical", label: "Vertical" },
  ],
}

/* ------------------------------------------------------------------------------------------------
 * Adapters
 * ---------------------------------------------------------------------------------------------- */

export const adapters: Adapter[] = [
  /* -------------------------------------------------------------------------------- Button */
  {
    id: "button-shadcn",
    slot: "button",
    library: "shadcn",
    label: "Button",
    note: "base-nova's Button on Base UI: plain, quiet, every variant themed",
    options: [
      {
        id: "variant",
        label: "Variant",
        type: "select",
        default: "default",
        choices: [...buttonVariantChoices, { value: "destructive", label: "Destructive" }],
      },
      { id: "size", label: "Size", type: "select", default: "default", choices: buttonSizeChoices },
      { id: "icon", label: "Icon", type: "switch", default: true },
      { id: "loading", label: "Loading", type: "switch", default: false },
    ],
    install: ["npx shadcn@latest add button"],
    code: (o) => {
      const job = buttonJobs[o.variant as ButtonVariant]
      const icon = o.loading ? "Loader2Icon" : o.icon ? job.iconName : null
      const attrs = props({
        variant: o.variant !== "default" ? (o.variant as string) : undefined,
        size: o.size !== "default" ? (o.size as string) : undefined,
        disabled: o.loading as boolean,
      })
      const iconLine = o.loading
        ? `  <Loader2Icon data-icon="inline-start" className="motion-safe:animate-spin" />\n`
        : icon
          ? `  <${icon} data-icon="inline-start" />\n`
          : ""
      return `${icon ? `import { ${icon} } from "lucide-react"\n` : ""}import { Button } from "@/components/ui/button"

<Button${attrs}${o.loading ? "" : " onClick={confirmOrder}"}>
${iconLine}  ${o.loading ? "Saving…" : job.label}
</Button>`
    },
    render: ShadcnButtonBlock,
  },
  {
    id: "button-shimmer",
    slot: "button",
    library: "magicui",
    label: "Shimmer button",
    note: "A light that runs round the edge on a CSS loop, forever",
    options: [
      {
        id: "background",
        label: "Background",
        type: "select",
        default: "primary",
        choices: [
          { value: "primary", label: "Theme primary" },
          { value: "black", label: "Black (as installed)" },
          { value: "indigo", label: "Indigo" },
          { value: "emerald", label: "Emerald" },
        ],
      },
      {
        id: "speed",
        label: "Shimmer",
        type: "select",
        default: "3s",
        choices: [
          { value: "1.5s", label: "Fast (1.5 s)" },
          { value: "3s", label: "Default (3 s)" },
          { value: "6s", label: "Slow (6 s)" },
        ],
      },
      {
        id: "shape",
        label: "Shape",
        type: "select",
        default: "rounded",
        choices: [
          { value: "rounded", label: "Rounded" },
          { value: "pill", label: "Pill" },
        ],
      },
      {
        id: "size",
        label: "Size",
        type: "select",
        default: "app",
        choices: [
          { value: "app", label: "In-app (h-8)" },
          { value: "hero", label: "Hero CTA" },
        ],
      },
    ],
    traits: { needsMotion: false, ignoresReducedMotion: true, pageKind: "marketing" },
    install: ["npx shadcn@latest add @magicui/shimmer-button"],
    code: (o) => {
      const p = shimmerProps(o)
      return `import { SparklesIcon } from "lucide-react"
import { ShimmerButton } from "@/components/ui/shimmer-button"

<ShimmerButton
  background="${p.background}"${p.shimmerColor ? `\n  shimmerColor="${p.shimmerColor}"` : ""}
  shimmerDuration="${p.shimmerDuration}"
  borderRadius="${p.borderRadius}"
  className="${p.className}"
>
  <SparklesIcon className="mr-1.5 size-3.5" />
  Upgrade to Growth
</ShimmerButton>`
    },
    render: ShimmerBlock,
  },
  {
    id: "button-moving-border",
    slot: "button",
    library: "aceternity",
    label: "Moving border",
    note: "A glow that laps the border, moved by JS on every frame",
    options: [
      {
        id: "look",
        label: "Look",
        type: "select",
        default: "installed",
        choices: [
          { value: "installed", label: "As installed (slate)" },
          { value: "themed", label: "Themed (our tokens)" },
        ],
      },
      {
        id: "shape",
        label: "Shape",
        type: "select",
        default: "pill",
        choices: [
          { value: "pill", label: "Pill" },
          { value: "rounded", label: "Rounded" },
          { value: "square", label: "Square" },
        ],
      },
      {
        id: "lap",
        label: "Lap time",
        type: "select",
        default: "3000",
        choices: [
          { value: "1500", label: "Fast (1.5 s)" },
          { value: "3000", label: "Default (3 s)" },
          { value: "6000", label: "Slow (6 s)" },
        ],
      },
    ],
    traits: { effect: false },
    install: ["npx shadcn@latest add @aceternity/moving-border"],
    code: (o) => {
      const themed = o.look === "themed"
      return `import { Button as MovingBorderButton } from "@/components/ui/moving-border"

<MovingBorderButton
  borderRadius="${borderRadii[o.shape as string]}"
  duration={${o.lap}}
  containerClassName="h-10 w-36"${themed ? `\n  borderClassName="${AMBER_GLOW}"` : ""}
  className="${themed ? THEMED_INSIDE : "text-sm font-medium"}"${themed ? "" : " // inside stays slate-900 with white text"}
>
  Book a demo
</MovingBorderButton>`
    },
    render: MovingBorderBlock,
  },
  {
    id: "button-ripple",
    slot: "button",
    library: "animate-ui",
    label: "Ripple button",
    note: "Ink ripple from the click point, plus hover and tap scale",
    options: [
      { id: "variant", label: "Variant", type: "select", default: "default", choices: buttonVariantChoices },
      { id: "size", label: "Size", type: "select", default: "default", choices: buttonSizeChoices },
      { id: "scale", label: "Scale on hover/tap", type: "switch", default: true },
    ],
    install: ["npx shadcn@latest add @animate-ui/components-buttons-ripple"],
    code: (o) => {
      const attrs = props({
        variant: o.variant !== "default" ? (o.variant as string) : undefined,
        size: o.size !== "default" ? (o.size as string) : undefined,
        hoverScale: o.scale ? undefined : "{1}",
        tapScale: o.scale ? undefined : "{1}",
      })
      return `import { RippleButton, RippleButtonRipples } from "@/components/animate-ui/components/buttons/ripple"

// Brings its own button styles (h-9, rounded-md), not base-nova's.
<RippleButton${attrs} onClick={confirmOrder}>
  ${buttonJobs[o.variant as ButtonVariant].label}
  <RippleButtonRipples />
</RippleButton>`
    },
    render: RippleBlock,
  },

  /* -------------------------------------------------------------------------------- Toast */
  {
    id: "toast-sonner",
    slot: "toast",
    library: "sonner",
    label: "Sonner",
    note: "Stacked cards with swipe, actions and promises",
    options: [
      {
        id: "kind",
        label: "Kind",
        type: "select",
        default: "success",
        choices: [
          { value: "default", label: "Plain" },
          { value: "success", label: "Success" },
          { value: "error", label: "Error" },
          { value: "action", label: "With Undo" },
          { value: "promise", label: "Promise" },
        ],
      },
      {
        id: "position",
        label: "Position",
        type: "select",
        default: "bottom-right",
        choices: [
          { value: "top-center", label: "Top" },
          { value: "top-right", label: "Top right" },
          { value: "bottom-center", label: "Bottom" },
          { value: "bottom-right", label: "Bottom right" },
        ],
      },
      { id: "description", label: "Description line", type: "switch", default: true },
      { id: "rich", label: "Rich colours", type: "switch", default: false },
    ],
    install: ["npx shadcn@latest add sonner"],
    code: (o) => `import { toast } from "sonner"
import { Toaster } from "@/components/ui/sonner"

// once, near the root
<Toaster position="${o.position}"${o.rich ? " richColors" : ""} />

// anywhere
toast.${o.kind === "default" || o.kind === "action" ? "message" : o.kind === "promise" ? "promise" : o.kind}(${
      o.kind === "promise" ? `saveOrder(), { loading: "Saving order…", success: "Order #4821 saved", error: "Couldn't save" }` : `"Order #4821 saved"`
    }${o.description && o.kind !== "promise" ? `, { description: "4 lines · RM 2,665.20" }` : ""})`,
    render: SonnerToast,
  },
  {
    id: "toast-base-ui",
    slot: "toast",
    library: "base-ui",
    label: "Base UI Toast",
    note: "Queue, timers and swipe only: the card and stacking CSS are yours",
    options: [
      { id: "kind", label: "Kind", type: "select", default: "success", choices: toastKindChoices },
      { id: "position", label: "Position", type: "select", default: "bottom-right", choices: toastPositionChoices },
      { id: "expanded", label: "Always expanded", type: "switch", default: false },
      { id: "rich", label: "Rich colours", type: "switch", default: false },
    ],
    install: ["npm i @base-ui/react"],
    code: (o) => {
      const call =
        o.kind === "promise"
          ? `toasts
  .promise(saveOrder(), {
    loading: { title: "Saving order #4821…" },
    success: { title: "Order #4821 saved" },
    error: { title: "Couldn't save order #4821" },
  })
  .catch(() => {}) // unlike Sonner, this rejects`
          : o.kind === "action"
            ? `const id = toasts.add({
  title: "Order #4816 archived",
  actionProps: { children: "Undo", onClick: () => { toasts.close(id); restoreOrder() } },
})`
            : o.kind === "error"
              ? `toasts.add({ type: "error", title: "Couldn't sync stock levels", description: "Johor Bahru DC didn't respond." })`
              : `toasts.add({${o.kind === "success" ? ` type: "success",` : ""} title: "Order #4821 saved", description: "4 lines · RM 2,665.20" })`
      return `import { Toast } from "@base-ui/react/toast"

export const toasts = Toast.createToastManager()

// once, near the root: Base UI ships behaviour, the look is yours
<Toast.Provider toastManager={toasts}>
  <App />
  <Toast.Portal>
    <Toast.Viewport className="toast-viewport" data-pos="${o.position}"${o.expanded ? " data-always-expanded" : ""}${o.rich ? " data-rich" : ""}>
      <ToastList /> {/* useToastManager().toasts → <Toast.Root><Toast.Title />… */}
    </Toast.Viewport>
  </Toast.Portal>
</Toast.Provider>
// + ~60 lines of stacking CSS on --toast-index / --toast-offset-y (see base-toast.tsx)

// anywhere
${call}`
    },
    render: BaseUiToast,
  },

  /* -------------------------------------------------------------------------------- Drawer */
  {
    id: "drawer-shadcn",
    slot: "drawer",
    library: "shadcn",
    label: "Drawer",
    note: "Base UI Drawer: swipe to dismiss from any edge, snap points, nesting",
    options: [
      { id: "side", label: "Side", type: "select", default: "bottom", choices: sideChoices },
      { id: "snap", label: "Snap points (bottom)", type: "switch", default: false },
      { id: "handle", label: "Swipe handle", type: "switch", default: true },
    ],
    install: ["npx shadcn@latest add drawer"],
    code: (o) => {
      const head = `import { Button } from "@/components/ui/button"
import { Drawer, DrawerClose, DrawerContent, DrawerDescription, DrawerHeader, DrawerTitle, DrawerTrigger } from "@/components/ui/drawer"
`
      if (o.snap)
        return `${head}
const snapPoints = ["180px", 0.55, 1]
const [snap, setSnap] = useState<number | string | null>(snapPoints[0])

<Drawer snapPoints={snapPoints} snapPoint={snap} onSnapPointChange={setSnap}${o.handle ? " showSwipeHandle" : ""}>
  <DrawerTrigger render={<Button variant="outline" />}>Open pick list</DrawerTrigger>
  <DrawerContent>
    <DrawerHeader>
      <DrawerTitle>Wave 3 · Shah Alam DC</DrawerTitle>
      <DrawerDescription>24 picks across 12 orders</DrawerDescription>
    </DrawerHeader>
    <PickList />
  </DrawerContent>
</Drawer>`
      const side = o.side as Side
      return `${head}
<Drawer${side !== "bottom" ? ` swipeDirection="${toSwipe[side]}"` : ""}${o.handle ? " showSwipeHandle" : ""}>
  <DrawerTrigger render={<Button variant="outline" />}>Open order</DrawerTrigger>
  <DrawerContent>
    <DrawerHeader>
      <DrawerTitle>Order #4821</DrawerTitle>
      <DrawerDescription>${ORDER_LINE}</DrawerDescription>
    </DrawerHeader>
    <OrderSummary />
    <DrawerClose render={<Button />} onClick={markPacked}>Mark as packed</DrawerClose>
  </DrawerContent>
</Drawer>`
    },
    render: BaseDrawerBlock,
  },
  {
    id: "drawer-sheet",
    slot: "drawer",
    library: "shadcn",
    label: "Sheet",
    note: "A Base UI Dialog that slides in from an edge; no swipe, no snap",
    options: [
      {
        id: "side",
        label: "Side",
        type: "select",
        default: "right",
        choices: [
          { value: "right", label: "Right" },
          { value: "left", label: "Left" },
          { value: "bottom", label: "Bottom" },
          { value: "top", label: "Top" },
        ],
      },
      { id: "closeButton", label: "Close button (×)", type: "switch", default: true },
      { id: "timeline", label: "Activity timeline", type: "switch", default: true },
    ],
    install: ["npx shadcn@latest add sheet"],
    code: (o) => `import { Button } from "@/components/ui/button"
import { Sheet, SheetClose, SheetContent, SheetDescription, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet"

<Sheet>
  <SheetTrigger render={<Button variant="outline" />}>Open order</SheetTrigger>
  <SheetContent${o.side !== "right" ? ` side="${o.side}"` : ""}${o.closeButton ? "" : " showCloseButton={false}"}>
    <SheetHeader>
      <SheetTitle>Order #4821</SheetTitle>
      <SheetDescription>${ORDER_LINE}</SheetDescription>
    </SheetHeader>
    <OrderSummary${o.timeline ? " timeline" : ""} />
    <SheetClose render={<Button />} onClick={markPacked}>Mark as packed</SheetClose>
  </SheetContent>
</Sheet>`,
    render: SheetBlock,
  },
  {
    id: "drawer-vaul",
    slot: "drawer",
    library: "vaul",
    label: "Vaul",
    note: "The original swipe drawer, on Radix Dialog, unstyled and unmaintained",
    options: [
      { id: "side", label: "Direction", type: "select", default: "bottom", choices: sideChoices },
      { id: "snap", label: "Snap points (bottom)", type: "switch", default: false },
    ],
    install: ["npm i vaul"],
    code: (o) => {
      const head = `import { Drawer } from "vaul"
import { Button } from "@/components/ui/button"
`
      if (o.snap)
        return `${head}
const snapPoints = ["180px", 0.55, 1]
const [snap, setSnap] = useState<number | string | null>(snapPoints[0])

<Drawer.Root snapPoints={snapPoints} activeSnapPoint={snap} setActiveSnapPoint={setSnap}>
  <Drawer.Trigger asChild>
    <Button variant="outline">Open pick list</Button>
  </Drawer.Trigger>
  <Drawer.Portal>
    <Drawer.Overlay className="fixed inset-0 z-50 bg-black/30" />
    <Drawer.Content className="fixed inset-x-0 bottom-0 z-50 flex h-full max-h-[97%] flex-col rounded-t-xl border-t bg-popover">
      <Drawer.Title>Wave 3 · Shah Alam DC</Drawer.Title>
      <Drawer.Description>24 picks across 12 orders</Drawer.Description>
      <PickList />
    </Drawer.Content>
  </Drawer.Portal>
</Drawer.Root>`
      return `${head}
// Unstyled: the classes are yours (direction comes back as data-vaul-drawer-direction).
<Drawer.Root${o.side !== "bottom" ? ` direction="${o.side}"` : ""}>
  <Drawer.Trigger asChild>
    <Button variant="outline">Open order</Button>
  </Drawer.Trigger>
  <Drawer.Portal>
    <Drawer.Overlay className="fixed inset-0 z-50 bg-black/30" />
    <Drawer.Content className="fixed z-50 flex flex-col bg-popover ${isPanel(o.side as Side) ? `inset-y-0 ${o.side}-0 w-3/4 sm:max-w-sm` : `inset-x-0 ${o.side}-0 max-h-[85vh]`}">
      <Drawer.Title>Order #4821</Drawer.Title>
      <Drawer.Description>${ORDER_LINE}</Drawer.Description>
      <OrderSummary />
      <Drawer.Close asChild>
        <Button onClick={markPacked}>Mark as packed</Button>
      </Drawer.Close>
    </Drawer.Content>
  </Drawer.Portal>
</Drawer.Root>`
    },
    render: VaulBlock,
  },
  {
    id: "drawer-radix",
    slot: "drawer",
    library: "radix",
    label: "Radix Dialog panel",
    note: "A side panel hand-built on Radix Dialog, animated off data-state",
    options: [
      {
        id: "side",
        label: "Side",
        type: "select",
        default: "right",
        choices: [
          { value: "right", label: "Right" },
          { value: "left", label: "Left" },
        ],
      },
      { id: "modal", label: "Modal (overlay, focus trap)", type: "switch", default: true },
      {
        id: "width",
        label: "Width",
        type: "select",
        default: "narrow",
        choices: [
          { value: "narrow", label: "Narrow (24rem)" },
          { value: "wide", label: "Wide (32rem)" },
        ],
      },
    ],
    install: ["npm i radix-ui"],
    code: (o) => {
      const side = o.side as "right" | "left"
      return `import { Dialog } from "radix-ui"
import { Button } from "@/components/ui/button"

<Dialog.Root${o.modal ? "" : " modal={false}"}>
  <Dialog.Trigger asChild>
    <Button variant="outline">Open order</Button>
  </Dialog.Trigger>
  <Dialog.Portal>
    <Dialog.Overlay className="fixed inset-0 z-50 bg-black/30 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=closed]:animate-out data-[state=closed]:fade-out-0" />
    <Dialog.Content
      className="fixed inset-y-0 ${radixPanelSide[side]} z-50 flex w-3/4 flex-col bg-popover ${radixPanelWidth[o.width as string]} data-[state=open]:animate-in data-[state=closed]:animate-out"${
        o.modal ? "" : `\n      onInteractOutside={(e) => e.preventDefault()} // stays open while you work behind it`
      }
    >
      <Dialog.Title>Order #4821</Dialog.Title>
      <Dialog.Description>${ORDER_LINE}</Dialog.Description>
      <OrderSummary timeline />
      <Dialog.Close asChild>
        <Button onClick={markPacked}>Mark as packed</Button>
      </Dialog.Close>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>`
    },
    render: RadixPanelBlock,
  },

  /* -------------------------------------------------------------------------------- Command menu */
  {
    id: "picker-cmdk-palette",
    slot: "picker",
    library: "cmdk",
    label: "⌘K palette",
    note: "cmdk in shadcn's CommandDialog: runs an action, keeps nothing",
    options: [
      matchingOption,
      { id: "hints", label: "Shortcut hints", type: "switch", default: true },
      { id: "customers", label: "Customers group", type: "switch", default: true },
    ],
    // shadcn's CommandDialog puts cmdk inside a Base UI Dialog.
    traits: { primitives: "base-ui" },
    install: ["npx shadcn@latest add command"],
    code: (o) => {
      const contains = o.matching === "contains"
      return `import { useEffect, useState } from "react"
import { Button } from "@/components/ui/button"
import { Command, CommandDialog, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList${o.hints ? ", CommandShortcut" : ""} } from "@/components/ui/command"

${contains ? containsSnippet : ""}export function CommandMenu() {
  const [open, setOpen] = useState(false)

  // ⌘K / Ctrl+K anywhere. (The composer's block opens on click only.)
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key.toLowerCase() === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        setOpen((o) => !o)
      }
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [])

  const run = (go: () => void) => {
    setOpen(false)
    go()
  }

  return (
    <>
      <Button variant="outline" onClick={() => setOpen(true)}>Search or jump to…</Button>
      <CommandDialog open={open} onOpenChange={setOpen}>
        <Command${contains ? " filter={contains}" : ""}>
          <CommandInput placeholder="Type a command or search…" />
          <CommandList>
            <CommandEmpty>No results.</CommandEmpty>
            <CommandGroup heading="Navigate">
              <CommandItem onSelect={() => run(() => navigate("/orders"))}>
                <ShoppingCartIcon /> Orders${o.hints ? " <CommandShortcut>G O</CommandShortcut>" : ""}
              </CommandItem>
            </CommandGroup>${
              o.customers
                ? `
            <CommandGroup heading="Customers">
              {customers.map((c) => (
                <CommandItem key={c.id} value={\`\${c.name} \${c.id}\`} keywords={[c.area, c.channel]} onSelect={() => run(() => openCustomer(c))}>
                  <StoreIcon /> {c.name}
                </CommandItem>
              ))}
            </CommandGroup>`
                : ""
            }
          </CommandList>
        </Command>
      </CommandDialog>
    </>
  )
}`
    },
    render: CmdkPaletteBlock,
  },
  {
    id: "picker-cmdk-inline",
    slot: "picker",
    library: "cmdk",
    label: "Inline command list",
    note: "cmdk with no dialog: a filterable list that stays on the page",
    options: [
      matchingOption,
      { id: "grouped", label: "Group by category", type: "switch", default: true },
      { id: "stock", label: "Stock badges", type: "switch", default: true },
    ],
    install: ["npx shadcn@latest add command"],
    code: (o) => {
      const contains = o.matching === "contains"
      const item = `<CommandItem key={s.sku} value={s.sku} keywords={[s.name, s.category]} disabled={s.onHand === 0} onSelect={() => addLine(s)}>
          {s.name}${o.stock ? `\n          <StockBadge onHand={s.onHand} />` : ""}
        </CommandItem>`
      return `import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command"

${contains ? containsSnippet : ""}<Command${contains ? " filter={contains}" : ""} className="border">
  <CommandInput placeholder="Filter by name, SKU code or category…" />
  <CommandList className="max-h-44">
    <CommandEmpty>No SKU matches.</CommandEmpty>
${
  o.grouped
    ? `    {skusByCategory.map(([category, items]) => (
      <CommandGroup key={category} heading={category}>
        {items.map((s) => (
        ${item}
        ))}
      </CommandGroup>
    ))}`
    : `    <CommandGroup>
      {skus.map((s) => (
        ${item}
      ))}
    </CommandGroup>`
}
  </CommandList>
</Command>`
    },
    render: CmdkInlineBlock,
  },
  {
    id: "picker-combobox",
    slot: "picker",
    library: "base-ui",
    label: "Combobox",
    note: "A form field, not a palette: keeps a value and posts it by name",
    options: [
      {
        id: "mode",
        label: "Mode",
        type: "select",
        default: "single",
        choices: [
          { value: "single", label: "Single (Bill to)" },
          { value: "multiple", label: "Multiple (chips)" },
        ],
      },
      { id: "details", label: "Detail line", type: "switch", default: true },
      { id: "autoHighlight", label: "Highlight first match", type: "switch", default: true },
    ],
    install: ["npx shadcn@latest add combobox"],
    code: (o) => {
      const multiple = o.mode === "multiple"
      const item = o.details
        ? `<ComboboxItem key={c.id} value={c}>
          <div className="grid">
            <span>{c.name}</span>
            <span className="text-xs text-muted-foreground">{c.area} · {c.channel}</span>
          </div>
        </ComboboxItem>`
        : `<ComboboxItem key={c.id} value={c}>{c.name}</ComboboxItem>`
      const shared = `  items={customers}
  itemToStringLabel={(c) => c.name}
  itemToStringValue={(c) => c.id}
  isItemEqualToValue={(a, b) => a.id === b.id}${o.autoHighlight ? "\n  autoHighlight" : ""}`
      if (multiple)
        return `import { Combobox, ComboboxChip, ComboboxChips, ComboboxChipsInput, ComboboxContent, ComboboxEmpty, ComboboxItem, ComboboxList, ComboboxValue, useComboboxAnchor } from "@/components/ui/combobox"

const anchor = useComboboxAnchor()
const [value, setValue] = useState<Customer[]>([])

<Combobox
  multiple
  name="customers" // one hidden input per chip
  value={value}
  onValueChange={setValue}
${shared}
>
  <ComboboxChips ref={anchor}>
    <ComboboxValue>
      {(values: Customer[]) => (
        <>
          {values.map((c) => <ComboboxChip key={c.id}>{c.name}</ComboboxChip>)}
          <ComboboxChipsInput placeholder="Add a customer…" />
        </>
      )}
    </ComboboxValue>
  </ComboboxChips>
  <ComboboxContent anchor={anchor}>
    <ComboboxEmpty>No customer matches.</ComboboxEmpty>
    <ComboboxList>
      {(c: Customer) => (
        ${item}
      )}
    </ComboboxList>
  </ComboboxContent>
</Combobox>`
      return `import { Combobox, ComboboxContent, ComboboxEmpty, ComboboxInput, ComboboxItem, ComboboxList } from "@/components/ui/combobox"

const [value, setValue] = useState<Customer | null>(null)

<Combobox
  name="billTo"
  required
  value={value}
  onValueChange={setValue}
${shared}
>
  <ComboboxInput placeholder="Search customers…" showClear />
  <ComboboxContent>
    <ComboboxEmpty>No customer matches.</ComboboxEmpty>
    <ComboboxList>
      {(c: Customer) => (
        ${item}
      )}
    </ComboboxList>
  </ComboboxContent>
</Combobox>`
    },
    render: ComboboxBlock,
  },

  /* -------------------------------------------------------------------------------- Tabs */
  {
    id: "tabs-shadcn",
    slot: "tabs",
    library: "shadcn",
    label: "Tabs",
    note: "Base UI Tabs with base-nova's pill or underline list",
    options: [
      {
        id: "variant",
        label: "Style",
        type: "select",
        default: "default",
        choices: [
          { value: "default", label: "Pill" },
          { value: "line", label: "Underline" },
        ],
      },
      orientationOption,
      { id: "icons", label: "Icons", type: "switch", default: true },
    ],
    install: ["npx shadcn@latest add tabs"],
    code: (o) => `${o.icons ? `import { HistoryIcon, ListIcon, TruckIcon } from "lucide-react"\n` : ""}import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

<Tabs defaultValue="lines"${o.orientation === "vertical" ? ` orientation="vertical"` : ""}>
  <TabsList${o.variant === "line" ? ` variant="line"` : ""}>
${orderTabs.map((t) => `    <TabsTrigger value="${t.id}">${o.icons ? `<${t.iconName} /> ` : ""}${t.label}</TabsTrigger>`).join("\n")}
  </TabsList>
  <TabsContent value="lines"><OrderLines /></TabsContent>
  <TabsContent value="delivery"><Delivery /></TabsContent>
  <TabsContent value="activity"><Activity /></TabsContent>
</Tabs>`,
    render: ShadcnTabsBlock,
  },
  {
    id: "tabs-radix",
    slot: "tabs",
    library: "radix",
    label: "Radix Tabs",
    note: "Same look on radix-ui Tabs: styled by data-state, arrow keys switch tabs",
    options: [
      {
        id: "variant",
        label: "Style",
        type: "select",
        default: "pill",
        choices: [
          { value: "pill", label: "Pill" },
          { value: "line", label: "Underline" },
        ],
      },
      orientationOption,
      { id: "icons", label: "Icons", type: "switch", default: true },
    ],
    install: ["npm i radix-ui"],
    code: (o) => {
      const look = o.variant as "pill" | "line"
      const active =
        look === "pill"
          ? "data-[state=active]:bg-background data-[state=active]:text-foreground data-[state=active]:shadow-sm"
          : "after:absolute after:inset-x-0 after:-bottom-1 after:h-0.5 after:bg-foreground after:opacity-0 data-[state=active]:after:opacity-100"
      return `${o.icons ? `import { HistoryIcon, ListIcon, TruckIcon } from "lucide-react"\n` : ""}import { Tabs } from "radix-ui"

// Radix marks the active tab with data-state="active" (Base UI uses data-active).
// Arrow keys switch tabs by default (activationMode="automatic"); Base UI's default only moves focus.
<Tabs.Root defaultValue="lines"${o.orientation === "vertical" ? ` orientation="vertical"` : ""} className="group flex gap-2${o.orientation === "vertical" ? "" : " flex-col"}">
  <Tabs.List aria-label="Order #4821" className="inline-flex w-fit rounded-lg${look === "pill" ? " bg-muted" : ""} p-[3px] group-data-[orientation=vertical]:flex-col">
${orderTabs.map((t) => `    <Tabs.Trigger value="${t.id}" className="rounded-md px-1.5 text-sm ${active}">${o.icons ? `<${t.iconName} /> ` : ""}${t.label}</Tabs.Trigger>`).join("\n")}
  </Tabs.List>
  <Tabs.Content value="lines"><OrderLines /></Tabs.Content>
  <Tabs.Content value="delivery"><Delivery /></Tabs.Content>
  <Tabs.Content value="activity"><Activity /></Tabs.Content>
</Tabs.Root>`
    },
    render: RadixTabsBlock,
  },
  {
    id: "tabs-rareui",
    slot: "tabs",
    library: "rareui",
    label: "Animated tabs",
    note: "A glass pill that springs between tabs (our a11y-patched copy)",
    options: [
      {
        id: "set",
        label: "Tabs",
        type: "select",
        default: "order",
        choices: [
          { value: "order", label: "Order views (3)" },
          { value: "range", label: "Sales period (4)" },
        ],
      },
      { id: "panel", label: "Panel below", type: "switch", default: true },
    ],
    install: ["npm i motion", "Copy from github.com/Codewithswappy/ShitUI"],
    code: (o) => {
      const tabs = o.set === "range" ? rangeTabs : orderTabs
      return `import { useState } from "react"
import { AnimatedTabsPatched } from "@/demos/community/animated-tabs-patched"

// Upstream hard-codes layoutId="active-pill": two bars on a page fight over one pill.
// The patched copy scopes it with useId and adds role="tab", aria-selected and arrow keys.
const tabs = [
${tabs.map((t) => `  { id: "${t.id}", label: "${t.label}" },`).join("\n")}
]
const [tab, setTab] = useState("${tabs[0].id}")

<AnimatedTabsPatched label="${o.set === "range" ? "Sales period" : "Order #4821"}" tabs={tabs} activeTab={tab} onChange={setTab} />${
        o.panel ? `\n<div role="tabpanel">{panels[tab]}</div>` : ""
      }`
    },
    render: RareTabsBlock,
  },
]

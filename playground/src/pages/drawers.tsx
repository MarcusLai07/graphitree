import { useState, type ReactNode } from "react"
import { Drawer as Vaul } from "vaul"
import { toast } from "sonner"
import { MapPinIcon, PackageCheckIcon, PrinterIcon } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from "@/components/ui/drawer"
import {
  Sheet,
  SheetClose,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"
import { cn } from "@/lib/utils"
import { Findings, Page, Section, Variant } from "@/playground/kit"
import { ControlBar, Readout, Segmented, Toggle } from "@/demos/app/controls"
import { OrderSummary, PickList } from "@/demos/app/order-panel"

/* ------------------------------------------------------------------------------------------------
 * Shared bits
 * ---------------------------------------------------------------------------------------------- */

type Side = "bottom" | "right" | "left" | "top"
const toSwipe = { bottom: "down", top: "up", right: "right", left: "left" } as const

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

const packed = () => toast.success("Order #4821 marked as packed", { description: "Picking list closed · 264 units" })

/** Same body and footer in every component, so the comparison is about the container. */
function OrderBody({ timeline }: { timeline?: boolean }) {
  return (
    <div className="min-h-0 flex-1 overflow-y-auto px-4 pt-4">
      <OrderSummary timeline={timeline} />
    </div>
  )
}

function FooterButtons({ close }: { close: ReactNode }) {
  return (
    <div className="flex gap-2 p-4">
      <Button variant="outline" size="icon" aria-label="Print picking list" onClick={() => toast("Picking list sent to Shah Alam DC printer")}>
        <PrinterIcon />
      </Button>
      {close}
      <div className="flex-1" />
      <Button onClick={packed}>
        <PackageCheckIcon /> Mark as packed
      </Button>
    </div>
  )
}

/* ------------------------------------------------------------------------------------------------
 * 1. Bottom sheet / 5. directions: one order, three containers
 * ---------------------------------------------------------------------------------------------- */

function VaulOrder({ side = "bottom" }: { side?: Side }) {
  return (
    <Vaul.Root direction={side}>
      <Vaul.Trigger asChild>
        <Button variant="outline">Open order #4821</Button>
      </Vaul.Trigger>
      <Vaul.Portal>
        <Vaul.Overlay className={vaulOverlay} />
        <Vaul.Content className={vaulContent}>
          <div className={vaulHandle} />
          <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
            <div className="grid gap-0.5 px-4 pt-4">
              <Vaul.Title className={vaulTitle}>Order #4821</Vaul.Title>
              <Vaul.Description className={vaulDesc}>Mydin Subang Jaya · 4 lines · RM 2,665.20</Vaul.Description>
            </div>
            <OrderBody timeline={side === "right" || side === "left"} />
            <FooterButtons
              close={
                <Vaul.Close asChild>
                  <Button variant="outline">Close</Button>
                </Vaul.Close>
              }
            />
          </div>
        </Vaul.Content>
      </Vaul.Portal>
    </Vaul.Root>
  )
}

function BaseOrder({ side = "bottom" }: { side?: Side }) {
  return (
    <Drawer swipeDirection={toSwipe[side]} showSwipeHandle>
      <DrawerTrigger render={<Button variant="outline" />}>Open order #4821</DrawerTrigger>
      <DrawerContent>
        <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
          <DrawerHeader>
            <DrawerTitle>Order #4821</DrawerTitle>
            <DrawerDescription>Mydin Subang Jaya · 4 lines · RM 2,665.20</DrawerDescription>
          </DrawerHeader>
          <OrderBody timeline={side === "right" || side === "left"} />
          <FooterButtons close={<DrawerClose render={<Button variant="outline" />}>Close</DrawerClose>} />
        </div>
      </DrawerContent>
    </Drawer>
  )
}

function SheetOrder({ side = "right" }: { side?: Side }) {
  return (
    <Sheet>
      <SheetTrigger render={<Button variant="outline" />}>Open order #4821</SheetTrigger>
      <SheetContent side={side} className={cn("gap-0", (side === "bottom" || side === "top") && "max-h-[85vh]")}>
        <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
          <SheetHeader className="pb-0">
            <SheetTitle>Order #4821</SheetTitle>
            <SheetDescription>Mydin Subang Jaya · 4 lines · RM 2,665.20</SheetDescription>
          </SheetHeader>
          <OrderBody timeline={side === "right" || side === "left"} />
          <FooterButtons close={<SheetClose render={<Button variant="outline" />}>Close</SheetClose>} />
        </div>
      </SheetContent>
    </Sheet>
  )
}

/* ------------------------------------------------------------------------------------------------
 * 2. Snap points
 * ---------------------------------------------------------------------------------------------- */

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

function PickHeader({ title, description, snap, setSnap }: { title: ReactNode; description: ReactNode; snap: number | string | null; setSnap: (s: number | string) => void }) {
  return (
    <div className="flex items-start justify-between gap-3 px-4 pt-3 pb-3">
      <div className="grid gap-0.5">
        {title}
        {description}
      </div>
      <SnapButtons value={snap} onChange={setSnap} />
    </div>
  )
}

function VaulSnap({ sequential }: { sequential: boolean }) {
  const [snap, setSnap] = useState<number | string | null>(snapPoints[0])
  return (
    <div className="flex flex-col items-center gap-3">
      <Vaul.Root snapPoints={snapPoints} activeSnapPoint={snap} setActiveSnapPoint={setSnap} snapToSequentialPoint={sequential}>
        <Vaul.Trigger asChild>
          <Button variant="outline">Open wave 3 pick list</Button>
        </Vaul.Trigger>
        <Vaul.Portal>
          <Vaul.Overlay className={vaulOverlay} />
          <Vaul.Content className="fixed inset-x-0 bottom-0 z-50 flex h-full max-h-[97%] flex-col rounded-t-xl border-t bg-popover text-sm text-popover-foreground outline-none">
            <div className="mx-auto mt-3 h-1.5 w-12 shrink-0 rounded-full bg-muted" />
            <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
              <PickHeader
                title={<Vaul.Title className={vaulTitle}>Wave 3 · Shah Alam DC</Vaul.Title>}
                description={<Vaul.Description className={vaulDesc}>24 picks across 12 orders</Vaul.Description>}
                snap={snap}
                setSnap={setSnap}
              />
              <div className={cn("min-h-0 flex-1 px-4 pb-4", snap === 1 ? "overflow-y-auto" : "overflow-hidden")}>
                <PickList />
              </div>
            </div>
          </Vaul.Content>
        </Vaul.Portal>
      </Vaul.Root>
      <Readout className="w-auto">active snap: {snapLabel(snap)}</Readout>
    </div>
  )
}

function BaseSnap({ sequential }: { sequential: boolean }) {
  const [snap, setSnap] = useState<number | string | null>(snapPoints[0])
  return (
    <div className="flex flex-col items-center gap-3">
      <Drawer
        snapPoints={snapPoints}
        snapPoint={snap}
        onSnapPointChange={setSnap}
        snapToSequentialPoints={sequential}
        showSwipeHandle
        onOpenChangeComplete={(open) => !open && setSnap(snapPoints[0])}
      >
        <DrawerTrigger render={<Button variant="outline" />}>Open wave 3 pick list</DrawerTrigger>
        <DrawerContent>
          <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
            <PickHeader
              title={<DrawerTitle>Wave 3 · Shah Alam DC</DrawerTitle>}
              description={<DrawerDescription>24 picks across 12 orders</DrawerDescription>}
              snap={snap}
              setSnap={setSnap}
            />
            <div className="min-h-0 flex-1 overflow-y-auto px-4 pb-4">
              <PickList />
            </div>
          </div>
        </DrawerContent>
      </Drawer>
      <Readout className="w-auto">active snap: {snapLabel(snap)}</Readout>
    </div>
  )
}

/* ------------------------------------------------------------------------------------------------
 * 3. Nested
 * ---------------------------------------------------------------------------------------------- */

function AddressFields() {
  return (
    <div className="grid gap-3 px-4 pt-4">
      <label className="grid gap-1.5 text-sm font-medium">
        Delivery address
        <textarea
          rows={3}
          defaultValue={"Lot 12, Jalan Subang 3\nTaman Perindustrian Subang\n47610 Subang Jaya, Selangor"}
          className="rounded-lg border bg-transparent px-2.5 py-1.5 text-sm outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 dark:bg-input/30"
        />
      </label>
      <label className="grid gap-1.5 text-sm font-medium">
        Receiving hours
        <input
          defaultValue="Mon–Sat, 8:00–16:00 (bay B)"
          className="h-8 rounded-lg border bg-transparent px-2.5 text-sm outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 dark:bg-input/30"
        />
      </label>
    </div>
  )
}

const savedAddress = () => toast.success("Delivery address updated for #4821")

function VaulNested() {
  return (
    <Vaul.Root>
      <Vaul.Trigger asChild>
        <Button variant="outline">Open order #4821</Button>
      </Vaul.Trigger>
      <Vaul.Portal>
        <Vaul.Overlay className={vaulOverlay} />
        <Vaul.Content className={vaulContent}>
          <div className={vaulHandle} />
          <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
            <div className="grid gap-0.5 px-4 pt-4">
              <Vaul.Title className={vaulTitle}>Order #4821</Vaul.Title>
              <Vaul.Description className={vaulDesc}>Mydin Subang Jaya · ships Tue, 18 Nov</Vaul.Description>
            </div>
            <OrderBody />
            <div className="flex gap-2 p-4">
              <Vaul.NestedRoot>
                <Vaul.Trigger asChild>
                  <Button variant="outline">
                    <MapPinIcon /> Change delivery address
                  </Button>
                </Vaul.Trigger>
                <Vaul.Portal>
                  <Vaul.Overlay className={vaulOverlay} />
                  <Vaul.Content className={cn(vaulContent, "data-[vaul-drawer-direction=bottom]:max-h-[70vh]")}>
                    <div className={vaulHandle} />
                    <div className="mx-auto w-full max-w-lg">
                      <div className="grid gap-0.5 px-4 pt-4">
                        <Vaul.Title className={vaulTitle}>Delivery address</Vaul.Title>
                        <Vaul.Description className={vaulDesc}>Only changes this order, not the customer record.</Vaul.Description>
                      </div>
                      <AddressFields />
                      <div className="flex justify-end gap-2 p-4">
                        <Vaul.Close asChild>
                          <Button variant="outline">Cancel</Button>
                        </Vaul.Close>
                        <Vaul.Close asChild>
                          <Button onClick={savedAddress}>Save address</Button>
                        </Vaul.Close>
                      </div>
                    </div>
                  </Vaul.Content>
                </Vaul.Portal>
              </Vaul.NestedRoot>
              <div className="flex-1" />
              <Vaul.Close asChild>
                <Button variant="outline">Close</Button>
              </Vaul.Close>
            </div>
          </div>
        </Vaul.Content>
      </Vaul.Portal>
    </Vaul.Root>
  )
}

function BaseNested() {
  return (
    <Drawer showSwipeHandle>
      <DrawerTrigger render={<Button variant="outline" />}>Open order #4821</DrawerTrigger>
      <DrawerContent>
        <div className="mx-auto flex min-h-0 w-full max-w-lg flex-1 flex-col">
          <DrawerHeader>
            <DrawerTitle>Order #4821</DrawerTitle>
            <DrawerDescription>Mydin Subang Jaya · ships Tue, 18 Nov</DrawerDescription>
          </DrawerHeader>
          <OrderBody />
          <div className="flex gap-2 p-4">
            {/* A nested drawer is just another Drawer inside the content. */}
            <Drawer showSwipeHandle>
              <DrawerTrigger render={<Button variant="outline" />}>
                <MapPinIcon /> Change delivery address
              </DrawerTrigger>
              <DrawerContent>
                <div className="mx-auto w-full max-w-lg">
                  <DrawerHeader>
                    <DrawerTitle>Delivery address</DrawerTitle>
                    <DrawerDescription>Only changes this order, not the customer record.</DrawerDescription>
                  </DrawerHeader>
                  <AddressFields />
                  <DrawerFooter className="flex-row justify-end pt-4">
                    <DrawerClose render={<Button variant="outline" />}>Cancel</DrawerClose>
                    <DrawerClose render={<Button />} onClick={savedAddress}>
                      Save address
                    </DrawerClose>
                  </DrawerFooter>
                </div>
              </DrawerContent>
            </Drawer>
            <div className="flex-1" />
            <DrawerClose render={<Button variant="outline" />}>Close</DrawerClose>
          </div>
        </div>
      </DrawerContent>
    </Drawer>
  )
}

/* ------------------------------------------------------------------------------------------------
 * 4. Non-dismissible
 * ---------------------------------------------------------------------------------------------- */

const variance = [
  { name: "Kopi O Kaw 500g", system: 86, counted: 80 },
  { name: "Kaya Pandan 400g", system: 75, counted: 75 },
  { name: "Coconut Milk 1L", system: 960, counted: 972 },
]

function CountBody() {
  return (
    <div className="px-4 pt-4">
      <table className="w-full text-sm">
        <thead className="text-xs text-muted-foreground">
          <tr className="border-b">
            <th className="py-1.5 text-left font-medium">SKU</th>
            <th className="py-1.5 text-right font-medium">System</th>
            <th className="py-1.5 text-right font-medium">Counted</th>
            <th className="py-1.5 text-right font-medium">Δ</th>
          </tr>
        </thead>
        <tbody className="tabular-nums">
          {variance.map((v) => {
            const d = v.counted - v.system
            return (
              <tr key={v.name} className="border-b last:border-0">
                <td className="py-1.5">{v.name}</td>
                <td className="py-1.5 text-right">{v.system}</td>
                <td className="py-1.5 text-right">{v.counted}</td>
                <td
                  className={cn(
                    "py-1.5 text-right font-medium",
                    d < 0 ? "text-rose-600 dark:text-rose-400" : d > 0 ? "text-emerald-600 dark:text-emerald-400" : "text-muted-foreground",
                  )}
                >
                  {d > 0 ? `+${d}` : d}
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

const confirmed = () => toast.success("Shift closed", { description: "Stock count posted · 2 variances sent to the DC manager" })
const recount = () => toast("Recount requested for 2 SKUs")
const countTitle = "Confirm the stock count"
const countDesc = "You can't close the shift at Shah Alam DC until this count is confirmed or sent back."

function VaulLocked() {
  const [open, setOpen] = useState(false)
  return (
    <Vaul.Root open={open} onOpenChange={setOpen} dismissible={false}>
      <Vaul.Trigger asChild>
        <Button variant="outline">Close shift</Button>
      </Vaul.Trigger>
      <Vaul.Portal>
        <Vaul.Overlay className={vaulOverlay} />
        <Vaul.Content className={vaulContent}>
          <div className="mx-auto w-full max-w-lg">
            <div className="grid gap-0.5 px-4 pt-5">
              <Vaul.Title className={vaulTitle}>{countTitle}</Vaul.Title>
              <Vaul.Description className={vaulDesc}>{countDesc}</Vaul.Description>
            </div>
            <CountBody />
            <div className="flex justify-end gap-2 p-4">
              <Button
                variant="outline"
                onClick={() => {
                  setOpen(false)
                  recount()
                }}
              >
                Send for recount
              </Button>
              <Button
                onClick={() => {
                  setOpen(false)
                  confirmed()
                }}
              >
                Confirm count
              </Button>
            </div>
          </div>
        </Vaul.Content>
      </Vaul.Portal>
    </Vaul.Root>
  )
}

function BaseLocked() {
  const [open, setOpen] = useState(false)
  const [blocked, setBlocked] = useState<string | null>(null)
  return (
    <div className="flex flex-col items-center gap-3">
      <Drawer
        open={open}
        disablePointerDismissal
        onOpenChange={(next, details) => {
          // Only our buttons may close it: cancel Esc, swipe, etc.
          if (!next && details.reason !== "close-press") {
            details.cancel()
            setBlocked(details.reason)
            return
          }
          setOpen(next)
        }}
      >
        <DrawerTrigger render={<Button variant="outline" />}>Close shift</DrawerTrigger>
        <DrawerContent>
          <div className="mx-auto w-full max-w-lg">
            <DrawerHeader className="pt-5">
              <DrawerTitle>{countTitle}</DrawerTitle>
              <DrawerDescription>{countDesc}</DrawerDescription>
            </DrawerHeader>
            <CountBody />
            <DrawerFooter className="flex-row justify-end pt-4">
              <DrawerClose render={<Button variant="outline" />} onClick={recount}>
                Send for recount
              </DrawerClose>
              <DrawerClose render={<Button />} onClick={confirmed}>
                Confirm count
              </DrawerClose>
            </DrawerFooter>
          </div>
        </DrawerContent>
      </Drawer>
      <Readout className="w-auto">last blocked close: {blocked ?? "none"}</Readout>
    </div>
  )
}

function SheetLocked() {
  const [open, setOpen] = useState(false)
  return (
    <Sheet
      open={open}
      disablePointerDismissal
      onOpenChange={(next, details) => {
        if (!next && details.reason !== "close-press") {
          details.cancel()
          return
        }
        setOpen(next)
      }}
    >
      <SheetTrigger render={<Button variant="outline" />}>Close shift</SheetTrigger>
      <SheetContent side="right" showCloseButton={false}>
        <SheetHeader className="pb-0">
          <SheetTitle>{countTitle}</SheetTitle>
          <SheetDescription>{countDesc}</SheetDescription>
        </SheetHeader>
        <CountBody />
        <SheetFooter className="flex-row justify-end">
          <SheetClose render={<Button variant="outline" />} onClick={recount}>
            Send for recount
          </SheetClose>
          <SheetClose render={<Button />} onClick={confirmed}>
            Confirm count
          </SheetClose>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

/* ------------------------------------------------------------------------------------------------ */

export default function DrawersPage() {
  const [sequential, setSequential] = useState(false)
  const [side, setSide] = useState<Side>("right")

  return (
    <Page
      title="Drawers & sheets"
      intro="Vaul is the drawer most shadcn apps have, but it's unmaintained. shadcn's base-nova Drawer is now Base UI's Drawer, and Sheet is a positioned Base UI Dialog. Same order content in each, so the question is simple: does Base UI's Drawer replace Vaul?"
      libs={[
        { name: "Vaul", status: "avoid", url: "https://vaul.emilkowal.ski", install: "npm i vaul" },
        { name: "Base UI Drawer", status: "built-in", url: "https://base-ui.com/react/components/drawer", install: "npx shadcn add drawer" },
        { name: "shadcn Sheet", status: "built-in", url: "https://ui.shadcn.com/docs/components/sheet", install: "npx shadcn add sheet" },
      ]}
    >
      <Section
        title="Bottom sheet: one order, three containers"
        description="Drag the handle (or the header) down to dismiss the drawers; the Sheet only closes via backdrop, Esc or the buttons. Try scrolling the lines, then dragging."
        className="md:grid-cols-3"
      >
        <Variant label="Bottom drawer" lib="Vaul" hint="Radix Dialog under the hood. Styling via data-vaul-drawer-direction; drag and animation CSS is injected at runtime.">
          <VaulOrder side="bottom" />
        </Variant>
        <Variant label="Bottom drawer" lib="Base UI (shadcn Drawer)" hint="Swipe, momentum and the open/close animation are driven by CSS variables (--drawer-swipe-movement-y…) in shadcn's classes.">
          <BaseOrder side="bottom" />
        </Variant>
        <Variant label="Bottom sheet" lib="shadcn Sheet (Base UI Dialog)" hint="No gestures: a Dialog positioned at the edge with a slide/fade transition.">
          <SheetOrder side="bottom" />
        </Variant>
      </Section>

      <Section
        title="Snap points"
        description="Peek at 180 px, half the screen, or full height. Drag between them, or use the buttons inside (the snap point is controlled state)."
      >
        <ControlBar>
          <Toggle label="Sequential snapping (no skipping with a fast flick)" checked={sequential} onCheckedChange={setSequential} />
          <span className="text-xs text-muted-foreground">
            Vaul: <code>snapToSequentialPoint</code> · Base UI: <code>snapToSequentialPoints</code>
          </span>
        </ControlBar>
        <Variant
          label="Snap points"
          lib="Vaul"
          hint={
            <>
              <code>snapPoints</code> + <code>activeSnapPoint</code>/<code>setActiveSnapPoint</code>. Content must be full height;
              you toggle the list's <code>overflow</code> yourself so it only scrolls at full.
            </>
          }
        >
          <VaulSnap sequential={sequential} />
        </Variant>
        <Variant
          label="Snap points"
          lib="Base UI"
          hint={
            <>
              <code>snapPoints</code> + <code>snapPoint</code>/<code>onSnapPointChange</code> (px/rem strings or 0–1 fractions).
              shadcn's classes apply the <code>--drawer-snap-point-offset</code>.
            </>
          }
        >
          <BaseSnap sequential={sequential} />
        </Variant>
      </Section>

      <Section
        title="Nested drawer"
        description="Edit the delivery address from inside the order. The parent should step back while the child is open and come back when it closes."
      >
        <Variant label="NestedRoot" lib="Vaul" hint={<>A special <code>Drawer.NestedRoot</code>; the parent scales via injected styles.</>}>
          <VaulNested />
        </Variant>
        <Variant
          label="Drawer in a Drawer"
          lib="Base UI"
          hint={
            <>
              Just nest another <code>&lt;Drawer&gt;</code>. Parent gets <code>data-nested-drawer-open</code> and{" "}
              <code>--nested-drawers</code>; shadcn's classes do the stacked look.
            </>
          }
        >
          <BaseNested />
        </Variant>
      </Section>

      <Section
        title="Non-dismissible"
        description="End-of-shift stock count: Esc, backdrop clicks and swipes must not close it. Only the two buttons can."
        className="md:grid-cols-3"
      >
        <Variant
          label="dismissible={false}"
          lib="Vaul"
          hint={
            <>
              One prop, but then you must control <code>open</code> and close it yourself (a <code>Drawer.Close</code> no longer
              works).
            </>
          }
        >
          <VaulLocked />
        </Variant>
        <Variant
          label="Cancel in onOpenChange"
          lib="Base UI"
          hint={
            <>
              <code>onOpenChange(open, details)</code> → <code>details.cancel()</code> unless{" "}
              <code>reason === "close-press"</code>, plus <code>disablePointerDismissal</code>. More code, but you see why it tried
              to close.
            </>
          }
        >
          <BaseLocked />
        </Variant>
        <Variant label="Same, as a Sheet" lib="shadcn Sheet" hint="Identical API (it's a Base UI Dialog). showCloseButton={false} hides the corner ×.">
          <SheetLocked />
        </Variant>
      </Section>

      <Section
        title="Side panels & other directions"
        description="Order detail as a side panel, the most common use in an admin portal. Switch the edge and compare."
        className="md:grid-cols-3"
      >
        <ControlBar className="md:col-span-3">
          <Segmented
            label="Edge"
            value={side}
            onChange={setSide}
            options={[
              { value: "right", label: "Right" },
              { value: "left", label: "Left" },
              { value: "top", label: "Top" },
              { value: "bottom", label: "Bottom" },
            ]}
          />
          <span className="text-xs text-muted-foreground">
            Vaul <code>direction</code> · Base UI <code>swipeDirection</code> (down/up/left/right) · Sheet <code>side</code>
          </span>
        </ControlBar>
        <Variant label={`Drawer, ${side}`} lib="Vaul">
          <VaulOrder side={side} />
        </Variant>
        <Variant label={`Drawer, ${side}`} lib="Base UI">
          <BaseOrder side={side} />
        </Variant>
        <Variant label={`Sheet, ${side}`} lib="shadcn Sheet">
          <SheetOrder side={side} />
        </Variant>
      </Section>

      <Findings
        notes={[
          {
            tone: "good",
            text: "Base UI's Drawer covers every Vaul case we use: bottom sheet with swipe-to-dismiss, snap points (controlled, sequential option), nested drawers, non-dismissible, all four edges. It also adds things Vaul never had: a reason on every close attempt, swipe-to-open areas, a virtual-keyboard provider and an indent (scale-background) effect via Drawer.Provider.",
          },
          {
            tone: "good",
            text: "With shadcn's base-nova Drawer the styling is done for you (handle, stacking, snap offsets, nested look), and the API matches Dialog/Sheet, so one mental model for all overlays.",
          },
          {
            tone: "note",
            text: (
              <>
                API mapping when porting from Vaul: <code>direction</code> → <code>swipeDirection</code> (bottom = <code>"down"</code>),{" "}
                <code>activeSnapPoint/setActiveSnapPoint</code> → <code>snapPoint/onSnapPointChange</code>, <code>NestedRoot</code> → a
                plain nested Drawer, <code>dismissible={"{false}"}</code> → cancel in <code>onOpenChange</code>,{" "}
                <code>asChild</code> → <code>render</code>.
              </>
            ),
          },
          {
            tone: "bad",
            text: "Base UI's drawer motion lives in a wall of CSS-variable classes (see components/ui/drawer.tsx). Fine while you use shadcn's file, painful to restyle from scratch; Vaul's runtime-injected CSS was simpler to theme.",
          },
          {
            tone: "bad",
            text: (
              <>
                Vaul: unmaintained, Radix-only (pulls in <code>@radix-ui/react-dialog</code> even in a Base UI app),{" "}
                <code>dismissible={"{false}"}</code> also disables <code>Drawer.Close</code>, and background scaling needs a{" "}
                <code>[vaul-drawer-wrapper]</code> element in your app shell.
              </>
            ),
          },
          {
            tone: "note",
            text: "Recommendation: drop Vaul for new work. Use shadcn Drawer (Base UI) for anything touch-first or gesture-driven (mobile web, bottom sheets, snap points); use Sheet for desktop side panels like an order detail, where gestures don't matter and Dialog semantics are enough.",
          },
        ]}
      />
    </Page>
  )
}

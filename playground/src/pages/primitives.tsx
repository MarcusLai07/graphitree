import { useId, useState } from "react"
import { toast } from "sonner"
import {
  CheckIcon,
  ChevronDownIcon,
  ChevronRightIcon,
  ChevronsUpDownIcon,
  CircleIcon,
  CopyIcon,
  DownloadIcon,
  MinusIcon,
  MoveHorizontalIcon,
  PencilIcon,
  PlusIcon,
  PrinterIcon,
  RefreshCwIcon,
  TrashIcon,
  TruckIcon,
} from "lucide-react"

// Base UI: one import per component.
import { Dialog as BDialog } from "@base-ui/react/dialog"
import { Menu as BMenu } from "@base-ui/react/menu"
import { Select as BSelect } from "@base-ui/react/select"
import { Popover as BPopover } from "@base-ui/react/popover"
import { Tooltip as BTooltip } from "@base-ui/react/tooltip"
import { Switch as BSwitch } from "@base-ui/react/switch"
import { Slider as BSlider } from "@base-ui/react/slider"
import { NumberField } from "@base-ui/react/number-field"
import { Meter } from "@base-ui/react/meter"
import { OTPField } from "@base-ui/react/otp-field"
import { Autocomplete } from "@base-ui/react/autocomplete"

// Radix: the unified package.
import {
  Dialog as RDialog,
  DropdownMenu as RMenu,
  Popover as RPopover,
  Select as RSelect,
  Slider as RSlider,
  Switch as RSwitch,
  Tooltip as RTooltip,
} from "radix-ui"

import { Button } from "@/components/ui/button"
import { Kbd } from "@/components/ui/kbd"
import { cn } from "@/lib/utils"
import { Findings, Page, Section, Variant } from "@/playground/kit"
import { ControlBar, Readout, Segmented, Toggle } from "@/demos/app/controls"
import { orderStatuses, skus, warehouses, type Sku } from "@/demos/app/data"

/* ------------------------------------------------------------------------------------------------
 * Shared look. Both libraries get exactly these classes; only the *state selectors* differ, because
 * Base UI exposes `data-open` / `data-closed` / `data-checked` / `data-popup-open`, while Radix
 * exposes `data-state="open|closed|checked|…"`. That difference is part of what we're comparing.
 * ---------------------------------------------------------------------------------------------- */

const btn =
  "inline-flex h-8 items-center justify-center gap-1.5 rounded-lg border bg-background px-3 text-sm font-medium whitespace-nowrap outline-none select-none transition-colors hover:bg-muted focus-visible:ring-3 focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 dark:bg-input/30 dark:hover:bg-input/50 [&_svg]:size-4 [&_svg]:shrink-0"
const btnPrimary =
  "inline-flex h-8 items-center justify-center gap-1.5 rounded-lg bg-primary px-3 text-sm font-medium text-primary-foreground outline-none hover:bg-primary/85 focus-visible:ring-3 focus-visible:ring-ring/50"
const iconBtn =
  "inline-flex size-8 items-center justify-center rounded-lg border bg-background outline-none hover:bg-muted focus-visible:ring-3 focus-visible:ring-ring/50 dark:bg-input/30 dark:hover:bg-input/50 [&_svg]:size-4"
const field =
  "h-8 w-full rounded-lg border bg-transparent px-2.5 text-sm outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 dark:bg-input/30"
const surface = "rounded-xl border bg-popover text-popover-foreground shadow-lg outline-none"
const overlay = "fixed inset-0 z-50 bg-black/30 supports-backdrop-filter:backdrop-blur-xs"
const dialogBox =
  "fixed top-1/2 left-1/2 z-50 grid w-[calc(100%-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 gap-4 p-5"
const menuItem =
  "relative flex cursor-default items-center gap-2 rounded-md px-2 py-1.5 text-sm outline-none select-none data-highlighted:bg-accent data-highlighted:text-accent-foreground data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
const menuLabel = "px-2 py-1.5 text-xs font-medium text-muted-foreground"
const menuSep = "-mx-1 my-1 h-px bg-border"
const shortcut = "ml-auto pl-4 text-xs tracking-widest text-muted-foreground"
const danger = "text-destructive data-highlighted:bg-destructive/10 data-highlighted:text-destructive"
const tooltipBox = "z-50 rounded-md bg-foreground px-2 py-1 text-xs text-background shadow-md"
const switchRoot =
  "relative inline-flex h-5 w-9 shrink-0 items-center rounded-full border border-transparent p-0.5 transition-colors outline-none focus-visible:ring-3 focus-visible:ring-ring/50"
const switchThumb = "block size-4 rounded-full bg-background shadow-sm transition-transform"
const sliderThumb =
  "block size-4 rounded-full border-2 border-primary bg-background shadow-sm outline-none transition-[box-shadow] hover:ring-4 hover:ring-ring/30 focus-visible:ring-4 focus-visible:ring-ring/50 has-[:focus-visible]:ring-4 has-[:focus-visible]:ring-ring/50"

// State selectors, per library.
const anim = {
  base: "duration-150 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95",
  radix:
    "duration-150 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95",
}
const fade = {
  base: "duration-150 data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0",
  radix:
    "duration-150 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=closed]:animate-out data-[state=closed]:fade-out-0",
}
const tooltipAnim = {
  base: "duration-100 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95",
  radix:
    "duration-100 animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95",
}

const libs = [
  { name: "Base UI", status: "playbook", url: "https://base-ui.com", install: "npm i @base-ui/react" },
  { name: "Radix", status: "playbook", url: "https://www.radix-ui.com/primitives", install: "npm i radix-ui" },
] as const

/* ------------------------------------------------------------------------------------------------
 * 1. Dialog & Popover
 * ---------------------------------------------------------------------------------------------- */

type OverlayOpts = { modal: boolean; blockOutside: boolean }

function DeliveryFields({ idPrefix }: { idPrefix: string }) {
  return (
    <div className="grid gap-3">
      <label className="grid gap-1.5 text-sm font-medium" htmlFor={`${idPrefix}-date`}>
        New delivery date
        <input id={`${idPrefix}-date`} type="date" defaultValue="2026-11-20" className={field} />
      </label>
      <label className="grid gap-1.5 text-sm font-medium" htmlFor={`${idPrefix}-notes`}>
        Note for the driver
        <textarea
          id={`${idPrefix}-notes`}
          rows={2}
          defaultValue="Loading bay B, call Encik Rahim 15 min before."
          className={cn(field, "h-auto py-1.5")}
        />
      </label>
    </div>
  )
}

const savedSlot = () => toast.success("Delivery slot for #4821 moved to Thu, 20 Nov")

function BaseDialogDemo({ modal, blockOutside }: OverlayOpts) {
  const [open, setOpen] = useState(false)
  const id = useId()
  return (
    <BDialog.Root open={open} onOpenChange={setOpen} modal={modal} disablePointerDismissal={blockOutside}>
      {/* Composition: Base UI uses a `render` prop. */}
      <BDialog.Trigger render={<Button variant="outline" />}>
        <TruckIcon /> Edit delivery slot
      </BDialog.Trigger>
      <BDialog.Portal>
        {modal && <BDialog.Backdrop className={cn(overlay, fade.base)} />}
        <BDialog.Popup className={cn(surface, dialogBox, anim.base)}>
          <div className="grid gap-1">
            <BDialog.Title className="text-base font-semibold">Edit delivery slot · #4821</BDialog.Title>
            <BDialog.Description className="text-sm text-muted-foreground">
              Mydin Subang Jaya is expecting this on Tue, 18 Nov. Moving it re-plans the Shah Alam route.
            </BDialog.Description>
          </div>
          <DeliveryFields idPrefix={id} />
          <div className="flex justify-end gap-2">
            <BDialog.Close render={<Button variant="outline" />}>Cancel</BDialog.Close>
            <Button
              onClick={() => {
                setOpen(false)
                savedSlot()
              }}
            >
              Save slot
            </Button>
          </div>
        </BDialog.Popup>
      </BDialog.Portal>
    </BDialog.Root>
  )
}

function RadixDialogDemo({ modal, blockOutside }: OverlayOpts) {
  const [open, setOpen] = useState(false)
  const id = useId()
  const block = (e: Event) => blockOutside && e.preventDefault()
  return (
    <RDialog.Root open={open} onOpenChange={setOpen} modal={modal}>
      {/* Composition: Radix uses `asChild`. */}
      <RDialog.Trigger asChild>
        <Button variant="outline">
          <TruckIcon /> Edit delivery slot
        </Button>
      </RDialog.Trigger>
      <RDialog.Portal>
        <RDialog.Overlay className={cn(overlay, fade.radix)} />
        <RDialog.Content
          className={cn(surface, dialogBox, anim.radix)}
          onPointerDownOutside={block}
          onInteractOutside={block}
        >
          <div className="grid gap-1">
            <RDialog.Title className="text-base font-semibold">Edit delivery slot · #4821</RDialog.Title>
            <RDialog.Description className="text-sm text-muted-foreground">
              Mydin Subang Jaya is expecting this on Tue, 18 Nov. Moving it re-plans the Shah Alam route.
            </RDialog.Description>
          </div>
          <DeliveryFields idPrefix={id} />
          <div className="flex justify-end gap-2">
            <RDialog.Close asChild>
              <Button variant="outline">Cancel</Button>
            </RDialog.Close>
            <Button
              onClick={() => {
                setOpen(false)
                savedSlot()
              }}
            >
              Save slot
            </Button>
          </div>
        </RDialog.Content>
      </RDialog.Portal>
    </RDialog.Root>
  )
}

function StockAdjustFields({ id }: { id: string }) {
  return (
    <div className="grid grid-cols-[1fr_auto] items-end gap-2">
      <label className="grid gap-1.5 text-sm font-medium" htmlFor={id}>
        Adjust by (units)
        <input id={id} type="number" defaultValue={-6} className={field} />
      </label>
      <select aria-label="Reason" defaultValue="damaged" className={cn(field, "w-auto")}>
        <option value="damaged">Damaged</option>
        <option value="count">Cycle count</option>
        <option value="expired">Expired</option>
      </select>
    </div>
  )
}

const adjusted = () => toast("Stock adjusted", { description: "Kopi O Kaw 500g · −6 units (damaged) at Shah Alam DC" })

function BasePopoverDemo({ hover }: { hover: boolean }) {
  const id = useId()
  return (
    <BPopover.Root>
      <BPopover.Trigger openOnHover={hover} delay={200} className={cn(btn, "data-popup-open:bg-muted")}>
        Adjust stock <ChevronDownIcon />
      </BPopover.Trigger>
      <BPopover.Portal>
        <BPopover.Positioner sideOffset={8} className="z-50">
          <BPopover.Popup className={cn(surface, "grid w-80 origin-(--transform-origin) gap-3 p-4", anim.base)}>
            <div className="grid gap-0.5">
              <BPopover.Title className="text-sm font-semibold">Kopi O Kaw 500g</BPopover.Title>
              <BPopover.Description className="text-xs text-muted-foreground">
                86 on hand at Shah Alam DC · reorder point 120
              </BPopover.Description>
            </div>
            <StockAdjustFields id={id} />
            <div className="flex justify-end gap-2">
              <BPopover.Close className={btn}>Cancel</BPopover.Close>
              <BPopover.Close className={btnPrimary} onClick={adjusted}>
                Apply
              </BPopover.Close>
            </div>
          </BPopover.Popup>
        </BPopover.Positioner>
      </BPopover.Portal>
    </BPopover.Root>
  )
}

function RadixPopoverDemo() {
  const id = useId()
  return (
    <RPopover.Root>
      <RPopover.Trigger className={cn(btn, "data-[state=open]:bg-muted")}>
        Adjust stock <ChevronDownIcon />
      </RPopover.Trigger>
      <RPopover.Portal>
        <RPopover.Content
          sideOffset={8}
          className={cn(
            surface,
            "z-50 grid w-80 origin-(--radix-popover-content-transform-origin) gap-3 p-4",
            anim.radix,
          )}
        >
          {/* No Title/Description parts in Radix Popover: plain elements, no aria wiring. */}
          <div className="grid gap-0.5">
            <h3 className="text-sm font-semibold">Kopi O Kaw 500g</h3>
            <p className="text-xs text-muted-foreground">86 on hand at Shah Alam DC · reorder point 120</p>
          </div>
          <StockAdjustFields id={id} />
          <div className="flex justify-end gap-2">
            <RPopover.Close className={btn}>Cancel</RPopover.Close>
            <RPopover.Close className={btnPrimary} onClick={adjusted}>
              Apply
            </RPopover.Close>
          </div>
        </RPopover.Content>
      </RPopover.Portal>
    </RPopover.Root>
  )
}

function OverlaysSection() {
  const [modal, setModal] = useState(true)
  const [blockOutside, setBlockOutside] = useState(false)
  const [hover, setHover] = useState(false)
  return (
    <Section
      title="Dialog & Popover"
      description="The same delivery-slot dialog and stock-adjust popover, built twice. Flip the knobs and compare how each library expresses them."
    >
      <ControlBar>
        <Toggle label="Modal" checked={modal} onCheckedChange={setModal} />
        <Toggle label="Ignore outside clicks" checked={blockOutside} onCheckedChange={setBlockOutside} />
        <Toggle label="Popover opens on hover (Base UI only)" checked={hover} onCheckedChange={setHover} />
      </ControlBar>
      <Variant
        label="Dialog"
        lib="Base UI"
        hint={
          <>
            <code>modal</code> takes <code>true | false | "trap-focus"</code>. Outside clicks:{" "}
            <code>disablePointerDismissal</code>. Composition via <code>render={"{<Button/>}"}</code>.
          </>
        }
      >
        <BaseDialogDemo modal={modal} blockOutside={blockOutside} />
      </Variant>
      <Variant
        label="Dialog"
        lib="Radix"
        hint={
          <>
            <code>modal</code> is boolean (Overlay hides itself when false). Outside clicks:{" "}
            <code>onPointerDownOutside={"{e => e.preventDefault()}"}</code>. Composition via <code>asChild</code>.
          </>
        }
      >
        <RadixDialogDemo modal={modal} blockOutside={blockOutside} />
      </Variant>
      <Variant
        label="Popover"
        lib="Base UI"
        hint={
          <>
            Has <code>Title</code>/<code>Description</code> parts (wired to aria-labelledby/-describedby) and{" "}
            <code>openOnHover</code> on the trigger. Needs Portal → Positioner → Popup.
          </>
        }
      >
        <BasePopoverDemo hover={hover} />
      </Variant>
      <Variant
        label="Popover"
        lib="Radix"
        hint={
          <>
            Portal → Content, one fewer layer. No Title/Description parts, no hover mode (that's a separate{" "}
            <code>HoverCard</code> component).
          </>
        }
      >
        <RadixPopoverDemo />
      </Variant>
    </Section>
  )
}

/* ------------------------------------------------------------------------------------------------
 * 2. Menu & Select
 * ---------------------------------------------------------------------------------------------- */

const ran = (what: string) => () => toast(`${what} · #4821`)

function BaseMenuDemo() {
  const [notify, setNotify] = useState(true)
  const [priority, setPriority] = useState("standard")
  return (
    <BMenu.Root>
      <BMenu.Trigger className={cn(btn, "data-popup-open:bg-muted")}>
        Order actions <ChevronDownIcon />
      </BMenu.Trigger>
      <BMenu.Portal>
        <BMenu.Positioner sideOffset={6} align="start" className="z-50 outline-none">
          <BMenu.Popup className={cn(surface, "min-w-60 origin-(--transform-origin) p-1", anim.base)}>
            <BMenu.Group>
              <BMenu.GroupLabel className={menuLabel}>Order #4821</BMenu.GroupLabel>
              <BMenu.Item className={menuItem} onClick={ran("Editing")}>
                <PencilIcon /> Edit order <span className={shortcut}>⌘E</span>
              </BMenu.Item>
              <BMenu.Item className={menuItem} onClick={ran("Duplicated")}>
                <CopyIcon /> Duplicate <span className={shortcut}>⌘D</span>
              </BMenu.Item>
              <BMenu.SubmenuRoot>
                <BMenu.SubmenuTrigger className={cn(menuItem, "data-popup-open:bg-accent")}>
                  <TruckIcon /> Ship from… <ChevronRightIcon className="ml-auto" />
                </BMenu.SubmenuTrigger>
                <BMenu.Portal>
                  <BMenu.Positioner sideOffset={4} alignOffset={-4} className="z-50 outline-none">
                    <BMenu.Popup className={cn(surface, "min-w-48 origin-(--transform-origin) p-1", anim.base)}>
                      {warehouses.map((w) => (
                        <BMenu.Item key={w.id} className={menuItem} onClick={ran(`Moved to ${w.name}`)}>
                          {w.name}
                        </BMenu.Item>
                      ))}
                    </BMenu.Popup>
                  </BMenu.Positioner>
                </BMenu.Portal>
              </BMenu.SubmenuRoot>
            </BMenu.Group>
            <BMenu.Separator className={menuSep} />
            <BMenu.CheckboxItem checked={notify} onCheckedChange={setNotify} className={cn(menuItem, "pl-8")}>
              <BMenu.CheckboxItemIndicator className="absolute left-2 inline-flex">
                <CheckIcon />
              </BMenu.CheckboxItemIndicator>
              Email the customer on changes
            </BMenu.CheckboxItem>
            <BMenu.RadioGroup value={priority} onValueChange={setPriority}>
              <BMenu.GroupLabel className={menuLabel}>Priority</BMenu.GroupLabel>
              {["standard", "express", "same-day"].map((p) => (
                <BMenu.RadioItem key={p} value={p} className={cn(menuItem, "pl-8 capitalize")}>
                  <BMenu.RadioItemIndicator className="absolute left-2.5 inline-flex">
                    <CircleIcon className="size-2 fill-current" />
                  </BMenu.RadioItemIndicator>
                  {p}
                </BMenu.RadioItem>
              ))}
            </BMenu.RadioGroup>
            <BMenu.Separator className={menuSep} />
            <BMenu.Item className={menuItem} disabled>
              <PrinterIcon /> Print invoice <span className={shortcut}>not packed</span>
            </BMenu.Item>
            <BMenu.Item className={cn(menuItem, danger)} onClick={ran("Cancelled")}>
              <TrashIcon /> Cancel order
            </BMenu.Item>
          </BMenu.Popup>
        </BMenu.Positioner>
      </BMenu.Portal>
    </BMenu.Root>
  )
}

function RadixMenuDemo() {
  const [notify, setNotify] = useState(true)
  const [priority, setPriority] = useState("standard")
  return (
    <RMenu.Root>
      <RMenu.Trigger className={cn(btn, "data-[state=open]:bg-muted")}>
        Order actions <ChevronDownIcon />
      </RMenu.Trigger>
      <RMenu.Portal>
        <RMenu.Content
          sideOffset={6}
          align="start"
          className={cn(surface, "z-50 min-w-60 origin-(--radix-dropdown-menu-content-transform-origin) p-1", anim.radix)}
        >
          <RMenu.Group>
            <RMenu.Label className={menuLabel}>Order #4821</RMenu.Label>
            <RMenu.Item className={menuItem} onSelect={ran("Editing")}>
              <PencilIcon /> Edit order <span className={shortcut}>⌘E</span>
            </RMenu.Item>
            <RMenu.Item className={menuItem} onSelect={ran("Duplicated")}>
              <CopyIcon /> Duplicate <span className={shortcut}>⌘D</span>
            </RMenu.Item>
            <RMenu.Sub>
              <RMenu.SubTrigger className={cn(menuItem, "data-[state=open]:bg-accent")}>
                <TruckIcon /> Ship from… <ChevronRightIcon className="ml-auto" />
              </RMenu.SubTrigger>
              <RMenu.Portal>
                <RMenu.SubContent
                  sideOffset={4}
                  alignOffset={-4}
                  className={cn(
                    surface,
                    "z-50 min-w-48 origin-(--radix-dropdown-menu-content-transform-origin) p-1",
                    anim.radix,
                  )}
                >
                  {warehouses.map((w) => (
                    <RMenu.Item key={w.id} className={menuItem} onSelect={ran(`Moved to ${w.name}`)}>
                      {w.name}
                    </RMenu.Item>
                  ))}
                </RMenu.SubContent>
              </RMenu.Portal>
            </RMenu.Sub>
          </RMenu.Group>
          <RMenu.Separator className={menuSep} />
          {/* Radix closes the menu on toggle unless you preventDefault in onSelect. */}
          <RMenu.CheckboxItem
            checked={notify}
            onCheckedChange={setNotify}
            onSelect={(e) => e.preventDefault()}
            className={cn(menuItem, "pl-8")}
          >
            <RMenu.ItemIndicator className="absolute left-2 inline-flex">
              <CheckIcon />
            </RMenu.ItemIndicator>
            Email the customer on changes
          </RMenu.CheckboxItem>
          <RMenu.Label className={menuLabel}>Priority</RMenu.Label>
          <RMenu.RadioGroup value={priority} onValueChange={setPriority}>
            {["standard", "express", "same-day"].map((p) => (
              <RMenu.RadioItem
                key={p}
                value={p}
                onSelect={(e) => e.preventDefault()}
                className={cn(menuItem, "pl-8 capitalize")}
              >
                <RMenu.ItemIndicator className="absolute left-2.5 inline-flex">
                  <CircleIcon className="size-2 fill-current" />
                </RMenu.ItemIndicator>
                {p}
              </RMenu.RadioItem>
            ))}
          </RMenu.RadioGroup>
          <RMenu.Separator className={menuSep} />
          <RMenu.Item className={menuItem} disabled>
            <PrinterIcon /> Print invoice <span className={shortcut}>not packed</span>
          </RMenu.Item>
          <RMenu.Item className={cn(menuItem, danger)} onSelect={ran("Cancelled")}>
            <TrashIcon /> Cancel order
          </RMenu.Item>
        </RMenu.Content>
      </RMenu.Portal>
    </RMenu.Root>
  )
}

const warehouseItems = warehouses.map((w) => ({ value: w.id, label: w.name }))
const selectTrigger =
  "inline-flex h-8 w-56 items-center gap-2 rounded-lg border bg-background pr-2 pl-2.5 text-sm outline-none select-none hover:bg-muted focus-visible:ring-3 focus-visible:ring-ring/50 dark:bg-input/30 dark:hover:bg-input/50 [&_svg]:size-4 [&_svg]:text-muted-foreground"

function BaseSelectDemo({ aligned }: { aligned: boolean }) {
  return (
    <BSelect.Root items={warehouseItems} defaultValue="SA">
      <div className="grid gap-1.5">
        <BSelect.Label className="text-sm font-medium">Ship from</BSelect.Label>
        <BSelect.Trigger className={cn(selectTrigger, "data-popup-open:bg-muted")}>
          <BSelect.Value className="flex-1 text-left data-placeholder:text-muted-foreground" placeholder="Pick a warehouse" />
          <BSelect.Icon>
            <ChevronsUpDownIcon />
          </BSelect.Icon>
        </BSelect.Trigger>
      </div>
      <BSelect.Portal>
        <BSelect.Positioner alignItemWithTrigger={aligned} sideOffset={6} className="z-50 outline-none select-none">
          <BSelect.Popup
            className={cn(surface, "min-w-(--anchor-width) origin-(--transform-origin) p-1", fade.base)}
          >
            <BSelect.List className="max-h-(--available-height) overflow-y-auto">
              {warehouses.map((w) => (
                <BSelect.Item key={w.id} value={w.id} className={cn(menuItem, "pr-3 pl-8")}>
                  <BSelect.ItemIndicator className="absolute left-2 inline-flex">
                    <CheckIcon />
                  </BSelect.ItemIndicator>
                  <BSelect.ItemText>{w.name}</BSelect.ItemText>
                  <span className="ml-auto text-xs text-muted-foreground">{w.region}</span>
                </BSelect.Item>
              ))}
            </BSelect.List>
          </BSelect.Popup>
        </BSelect.Positioner>
      </BSelect.Portal>
    </BSelect.Root>
  )
}

function RadixSelectDemo({ aligned }: { aligned: boolean }) {
  const id = useId()
  return (
    <RSelect.Root defaultValue="SA">
      <div className="grid gap-1.5">
        <label htmlFor={id} className="text-sm font-medium">
          Ship from
        </label>
        <RSelect.Trigger id={id} className={cn(selectTrigger, "data-[state=open]:bg-muted")}>
          <span className="flex-1 truncate text-left">
            <RSelect.Value placeholder="Pick a warehouse" />
          </span>
          <RSelect.Icon>
            <ChevronsUpDownIcon />
          </RSelect.Icon>
        </RSelect.Trigger>
      </div>
      <RSelect.Portal>
        <RSelect.Content
          position={aligned ? "item-aligned" : "popper"}
          sideOffset={6}
          className={cn(
            surface,
            "z-50 min-w-(--radix-select-trigger-width) p-1 select-none",
            !aligned && "max-h-(--radix-select-content-available-height)",
            fade.radix,
          )}
        >
          <RSelect.Viewport>
            {warehouses.map((w) => (
              <RSelect.Item key={w.id} value={w.id} className={cn(menuItem, "pr-3 pl-8")}>
                <RSelect.ItemIndicator className="absolute left-2 inline-flex">
                  <CheckIcon />
                </RSelect.ItemIndicator>
                <RSelect.ItemText>{w.name}</RSelect.ItemText>
                <span className="ml-auto text-xs text-muted-foreground">{w.region}</span>
              </RSelect.Item>
            ))}
          </RSelect.Viewport>
        </RSelect.Content>
      </RSelect.Portal>
    </RSelect.Root>
  )
}

function MenuSelectSection() {
  const [aligned, setAligned] = useState(true)
  return (
    <Section
      title="Menu & Select"
      description="An order-actions menu (submenu, checkbox, radio group, disabled and destructive items) and a warehouse select. Use the keyboard: arrows, type-ahead, → to open the submenu, Esc."
    >
      <ControlBar>
        <Toggle
          label="Select overlaps the trigger (macOS style)"
          checked={aligned}
          onCheckedChange={setAligned}
        />
        <span className="text-xs text-muted-foreground">
          Base UI: <code>alignItemWithTrigger</code> · Radix: <code>position="item-aligned" | "popper"</code>
        </span>
      </ControlBar>
      <Variant
        label="Menu"
        lib="Base UI"
        hint={
          <>
            Items use <code>onClick</code>. Checkbox and radio items stay open by default (
            <code>closeOnClick</code> to change). Submenu = <code>SubmenuRoot</code> + its own Portal/Positioner.
          </>
        }
      >
        <BaseMenuDemo />
      </Variant>
      <Variant
        label="DropdownMenu"
        lib="Radix"
        hint={
          <>
            Items use <code>onSelect</code>. Checkbox/radio items close the menu unless you call{" "}
            <code>e.preventDefault()</code> in <code>onSelect</code>. One shared <code>ItemIndicator</code>.
          </>
        }
      >
        <RadixMenuDemo />
      </Variant>
      <Variant
        label="Select"
        lib="Base UI"
        hint={
          <>
            Pass <code>items</code> to Root or the trigger shows the raw value (“SA”). Has a <code>Label</code> part and{" "}
            <code>multiple</code> (see below).
          </>
        }
      >
        <BaseSelectDemo aligned={aligned} />
      </Variant>
      <Variant
        label="Select"
        lib="Radix"
        hint={
          <>
            Trigger shows the selected <code>ItemText</code> automatically. Label it yourself with{" "}
            <code>&lt;label htmlFor&gt;</code>. Single value only.
          </>
        }
      >
        <RadixSelectDemo aligned={aligned} />
      </Variant>
    </Section>
  )
}

/* ------------------------------------------------------------------------------------------------
 * 3. Tooltip, Switch & Slider
 * ---------------------------------------------------------------------------------------------- */

const tools = [
  { icon: PrinterIcon, label: "Print picking list", keys: "⌘P" },
  { icon: DownloadIcon, label: "Export lines to CSV", keys: "⌘E" },
  { icon: RefreshCwIcon, label: "Refresh stock levels", keys: "R" },
]

function BaseTooltips({ delay }: { delay: number }) {
  return (
    <BTooltip.Provider delay={delay}>
      <div className="flex gap-1.5">
        {tools.map(({ icon: Icon, label, keys }) => (
          <BTooltip.Root key={label}>
            <BTooltip.Trigger className={iconBtn} aria-label={label}>
              <Icon />
            </BTooltip.Trigger>
            <BTooltip.Portal>
              <BTooltip.Positioner sideOffset={6} className="z-50">
                <BTooltip.Popup className={cn(tooltipBox, "origin-(--transform-origin)", tooltipAnim.base)}>
                  {label} <Kbd className="ml-1">{keys}</Kbd>
                </BTooltip.Popup>
              </BTooltip.Positioner>
            </BTooltip.Portal>
          </BTooltip.Root>
        ))}
      </div>
    </BTooltip.Provider>
  )
}

function RadixTooltips({ delay }: { delay: number }) {
  return (
    <RTooltip.Provider delayDuration={delay}>
      <div className="flex gap-1.5">
        {tools.map(({ icon: Icon, label, keys }) => (
          <RTooltip.Root key={label}>
            <RTooltip.Trigger className={iconBtn} aria-label={label}>
              <Icon />
            </RTooltip.Trigger>
            <RTooltip.Portal>
              <RTooltip.Content
                sideOffset={6}
                className={cn(tooltipBox, "origin-(--radix-tooltip-content-transform-origin)", tooltipAnim.radix)}
              >
                {label} <Kbd className="ml-1">{keys}</Kbd>
              </RTooltip.Content>
            </RTooltip.Portal>
          </RTooltip.Root>
        ))}
      </div>
    </RTooltip.Provider>
  )
}

const priceFormat: Intl.NumberFormatOptions = { style: "currency", currency: "MYR", maximumFractionDigits: 0 }

function BaseSwitchSlider() {
  return (
    <div className="flex w-full max-w-xs flex-col gap-5">
      <label className="flex items-center justify-between gap-4 text-sm">
        <span className="grid">
          <span className="font-medium">Low-stock alerts</span>
          <span className="text-xs text-muted-foreground">Email ops when a SKU drops below reorder point</span>
        </span>
        <BSwitch.Root defaultChecked className={cn(switchRoot, "data-checked:bg-primary data-unchecked:bg-input")}>
          <BSwitch.Thumb className={cn(switchThumb, "data-checked:translate-x-4")} />
        </BSwitch.Root>
      </label>
      <BSlider.Root
        defaultValue={[15, 40]}
        min={0}
        max={100}
        format={priceFormat}
        locale="en-MY"
        thumbAlignment="edge"
        className="grid gap-2"
      >
        <div className="flex items-center justify-between text-sm">
          <BSlider.Label className="font-medium">Promo price band</BSlider.Label>
          <BSlider.Value className="text-xs text-muted-foreground tabular-nums">
            {(formatted) => formatted.join(" – ")}
          </BSlider.Value>
        </div>
        <BSlider.Control className="flex w-full touch-none items-center py-1.5 select-none">
          <BSlider.Track className="relative h-1.5 w-full rounded-full bg-muted">
            <BSlider.Indicator className="rounded-full bg-primary" />
            <BSlider.Thumb index={0} aria-label="Minimum price" className={sliderThumb} />
            <BSlider.Thumb index={1} aria-label="Maximum price" className={sliderThumb} />
          </BSlider.Track>
        </BSlider.Control>
      </BSlider.Root>
    </div>
  )
}

function RadixSwitchSlider() {
  const [band, setBand] = useState([15, 40])
  const f = new Intl.NumberFormat("en-MY", priceFormat)
  const labelId = useId()
  return (
    <div className="flex w-full max-w-xs flex-col gap-5">
      <label className="flex items-center justify-between gap-4 text-sm">
        <span className="grid">
          <span className="font-medium">Low-stock alerts</span>
          <span className="text-xs text-muted-foreground">Email ops when a SKU drops below reorder point</span>
        </span>
        <RSwitch.Root
          defaultChecked
          className={cn(switchRoot, "data-[state=checked]:bg-primary data-[state=unchecked]:bg-input")}
        >
          <RSwitch.Thumb className={cn(switchThumb, "data-[state=checked]:translate-x-4")} />
        </RSwitch.Root>
      </label>
      <div className="grid gap-2">
        <div className="flex items-center justify-between text-sm">
          <span id={labelId} className="font-medium">
            Promo price band
          </span>
          {/* No Value part: format it yourself. */}
          <span className="text-xs text-muted-foreground tabular-nums">{band.map((v) => f.format(v)).join(" – ")}</span>
        </div>
        <RSlider.Root
          value={band}
          onValueChange={setBand}
          min={0}
          max={100}
          aria-labelledby={labelId}
          className="relative flex w-full touch-none items-center py-1.5 select-none"
        >
          <RSlider.Track className="relative h-1.5 w-full grow rounded-full bg-muted">
            <RSlider.Range className="absolute h-full rounded-full bg-primary" />
          </RSlider.Track>
          <RSlider.Thumb aria-label="Minimum price" className={sliderThumb} />
          <RSlider.Thumb aria-label="Maximum price" className={sliderThumb} />
        </RSlider.Root>
      </div>
    </div>
  )
}

function SmallControlsSection() {
  const [delay, setDelay] = useState("300")
  return (
    <Section
      title="Tooltip, Switch & Slider"
      description="Small controls. Hover across the toolbar quickly: once one tooltip is open, the next opens instantly in both libraries (shared provider)."
    >
      <ControlBar>
        <Segmented
          label="Tooltip delay"
          value={delay}
          onChange={setDelay}
          options={[
            { value: "0", label: "0 ms" },
            { value: "300", label: "300 ms" },
            { value: "700", label: "700 ms" },
          ]}
        />
      </ControlBar>
      <Variant
        label="Tooltip"
        lib="Base UI"
        hint={
          <>
            <code>Tooltip.Provider delay</code> (or per-trigger <code>delay</code>). Popup gets <code>data-instant</code>{" "}
            when it skips the delay.
          </>
        }
      >
        <BaseTooltips delay={Number(delay)} />
      </Variant>
      <Variant
        label="Tooltip"
        lib="Radix"
        hint={
          <>
            <code>Tooltip.Provider</code> is required (throws without it). <code>delayDuration</code> /{" "}
            <code>skipDelayDuration</code>; state is <code>delayed-open | instant-open | closed</code>.
          </>
        }
      >
        <RadixTooltips delay={Number(delay)} />
      </Variant>
      <Variant
        label="Switch + range slider"
        lib="Base UI"
        hint={
          <>
            Switch renders a <code>span</code> + hidden input (a wrapping <code>&lt;label&gt;</code> still names it: Base UI wires{" "}
            <code>aria-labelledby</code>). Slider has <code>Label</code> and <code>Value</code> parts
            and an Intl <code>format</code>. Thumb focus sits on an inner <code>&lt;input type=range&gt;</code>, so the
            ring needs <code>has-[:focus-visible]</code>.
          </>
        }
      >
        <BaseSwitchSlider />
      </Variant>
      <Variant
        label="Switch + range slider"
        lib="Radix"
        hint={
          <>
            Switch is a <code>button</code>. Slider has no label/value parts: wire <code>aria-labelledby</code> and format
            the readout yourself. Thumb itself takes focus.
          </>
        }
      >
        <RadixSwitchSlider />
      </Variant>
    </Section>
  )
}

/* ------------------------------------------------------------------------------------------------
 * 4. Only in Base UI: inputs
 * ---------------------------------------------------------------------------------------------- */

const stepBtn =
  "flex h-full w-8 items-center justify-center text-muted-foreground outline-none select-none hover:bg-muted hover:text-foreground data-disabled:opacity-40 [&_svg]:size-3.5"

function NumberFields() {
  const qtyId = useId()
  const priceId = useId()
  const [committed, setCommitted] = useState<string>("—")
  return (
    <div className="flex w-full max-w-xs flex-col gap-4">
      <NumberField.Root
        id={qtyId}
        defaultValue={24}
        min={0}
        max={480}
        step={6}
        onValueCommitted={(v) => setCommitted(`${v ?? "empty"} cartons`)}
        className="grid gap-1.5"
      >
        <NumberField.ScrubArea className="w-fit cursor-ew-resize">
          <label htmlFor={qtyId} className="cursor-ew-resize text-sm font-medium">
            Cartons to pick <span className="text-xs font-normal text-muted-foreground">(drag the label)</span>
          </label>
          <NumberField.ScrubAreaCursor className="drop-shadow">
            <MoveHorizontalIcon className="size-4" />
          </NumberField.ScrubAreaCursor>
        </NumberField.ScrubArea>
        <NumberField.Group className="flex h-8 w-fit overflow-hidden rounded-lg border focus-within:ring-3 focus-within:ring-ring/50 dark:bg-input/30">
          <NumberField.Decrement className={cn(stepBtn, "border-r")}>
            <MinusIcon />
          </NumberField.Decrement>
          <NumberField.Input className="w-20 bg-transparent text-center text-sm tabular-nums outline-none" />
          <NumberField.Increment className={cn(stepBtn, "border-l")}>
            <PlusIcon />
          </NumberField.Increment>
        </NumberField.Group>
      </NumberField.Root>
      <NumberField.Root
        id={priceId}
        defaultValue={18.9}
        min={0}
        step={0.1}
        locale="en-MY"
        format={{ style: "currency", currency: "MYR" }}
        className="grid gap-1.5"
      >
        <label htmlFor={priceId} className="text-sm font-medium">
          Unit price
        </label>
        <NumberField.Group className="flex h-8 w-fit overflow-hidden rounded-lg border focus-within:ring-3 focus-within:ring-ring/50 dark:bg-input/30">
          <NumberField.Input className="w-28 bg-transparent px-2.5 text-sm tabular-nums outline-none" />
          <NumberField.Decrement className={cn(stepBtn, "border-l")}>
            <MinusIcon />
          </NumberField.Decrement>
          <NumberField.Increment className={cn(stepBtn, "border-l")}>
            <PlusIcon />
          </NumberField.Increment>
        </NumberField.Group>
      </NumberField.Root>
      <Readout>committed: {committed}</Readout>
    </div>
  )
}

function OtpDemo() {
  const id = useId()
  const [state, setState] = useState<"idle" | "ok" | "bad">("idle")
  return (
    <div className="flex flex-col items-start gap-2">
      <label htmlFor={id} className="text-sm font-medium">
        Approve credit override
      </label>
      <OTPField.Root
        id={id}
        length={6}
        validationType="numeric"
        onValueChange={() => setState("idle")}
        onValueComplete={(value) => setState(value === "482100" ? "ok" : "bad")}
        className="flex gap-1.5"
      >
        {Array.from({ length: 6 }, (_, i) => (
          <OTPField.Input
            key={i}
            aria-label={i === 0 ? undefined : `Digit ${i + 1} of 6`}
            className={cn(
              "size-10 rounded-lg border bg-transparent text-center text-lg tabular-nums outline-none focus:border-ring focus:ring-3 focus:ring-ring/50 dark:bg-input/30",
              i === 3 && "ml-2",
              state === "bad" && "border-destructive",
              state === "ok" && "border-emerald-500",
            )}
          />
        ))}
      </OTPField.Root>
      <p className="text-xs text-muted-foreground">
        {state === "ok"
          ? "Approved: credit limit raised for Kedai Runcit Ahmad."
          : state === "bad"
            ? "That code didn't match. Try 482100."
            : "Enter the code sent to the finance manager (try 482100). Paste works."}
      </p>
    </div>
  )
}

function AutocompleteDemo() {
  const [query, setQuery] = useState("")
  return (
    <div className="flex w-full max-w-xs flex-col gap-2">
      <Autocomplete.Root items={skus} itemToStringValue={(s: Sku) => s.name} value={query} onValueChange={setQuery}>
        <label className="grid gap-1.5 text-sm font-medium">
          Search SKUs
          <Autocomplete.Input placeholder="e.g. noodle, sambal…" className={field} />
        </label>
        <Autocomplete.Portal>
          <Autocomplete.Positioner sideOffset={6} className="z-50 outline-none">
            <Autocomplete.Popup className={cn(surface, "w-(--anchor-width) origin-(--transform-origin) p-1", fade.base)}>
              {/* Empty is always mounted (it's a live region); only its children toggle, so pad the child. */}
              <Autocomplete.Empty>
                <div className="px-2 py-3 text-center text-sm text-muted-foreground">No SKU matches “{query}”.</div>
              </Autocomplete.Empty>
              <Autocomplete.List className="max-h-64 overflow-y-auto">
                {(s: Sku) => (
                  <Autocomplete.Item key={s.sku} value={s} className={cn(menuItem, "justify-between")}>
                    <span className="truncate">{s.name}</span>
                    <span className="font-mono text-xs text-muted-foreground">{s.sku}</span>
                  </Autocomplete.Item>
                )}
              </Autocomplete.List>
            </Autocomplete.Popup>
          </Autocomplete.Positioner>
        </Autocomplete.Portal>
      </Autocomplete.Root>
      <Readout>input value: “{query}”</Readout>
    </div>
  )
}

function BaseOnlyInputsSection() {
  return (
    <Section
      title="Only in Base UI: inputs"
      description={
        <>
          Radix (1.8) has no number field, meter, combobox or autocomplete; its OTP field is still exported as{" "}
          <code>unstable_OneTimePasswordField</code>. Base UI's Combobox gets its own deep-dive on the{" "}
          <a href="#/command" className="underline underline-offset-3">
            Command menu & pickers
          </a>{" "}
          page.
        </>
      }
    >
      <Variant
        label="NumberField"
        lib="Base UI"
        hint="Arrow keys step, Shift ×10, Alt ×0.1, scrub by dragging the label, Intl currency formatting, clamped to min/max. onValueCommitted fires on blur / pointer-up."
      >
        <NumberFields />
      </Variant>
      <Variant
        label="OTPField"
        lib="Base UI"
        hint="Stable here, unstable in Radix. Handles paste, backspace across slots, numeric validation, onValueComplete."
      >
        <OtpDemo />
      </Variant>
      <Variant
        label="Autocomplete"
        lib="Base UI"
        hint="Free text with suggestions: the value is whatever is typed. Use Combobox instead when the value must be one of the items."
        className="md:col-span-2"
      >
        <AutocompleteDemo />
      </Variant>
    </Section>
  )
}

/* ------------------------------------------------------------------------------------------------
 * 5. Only in Base UI: more
 * ---------------------------------------------------------------------------------------------- */

function MeterDemo() {
  return (
    <div className="flex w-full max-w-xs flex-col gap-3">
      {warehouses.map((w) => (
        <Meter.Root key={w.id} value={w.capacity} className="grid grid-cols-2 gap-y-1">
          <Meter.Label className="text-sm">{w.name}</Meter.Label>
          <Meter.Value className="text-right text-xs text-muted-foreground tabular-nums" />
          <Meter.Track className="col-span-2 h-1.5 overflow-hidden rounded-full bg-muted">
            <Meter.Indicator
              className={cn(
                "rounded-full transition-[width] duration-500",
                w.capacity >= 85 ? "bg-rose-500" : w.capacity >= 70 ? "bg-amber-500" : "bg-emerald-500",
              )}
            />
          </Meter.Track>
        </Meter.Root>
      ))}
    </div>
  )
}

const pickers = [
  "Aisyah Rahman",
  "Benjamin Tan",
  "Chandran Pillai",
  "Daniel Lim",
  "Farah Hassan",
  "Goh Wei Ling",
  "Hafiz Ismail",
  "Jason Wong",
  "Kavitha Raj",
  "Nurul Huda",
]

function FilterMenuDemo() {
  return (
    <BMenu.FilterProvider>
      <BMenu.Root>
        <BMenu.Trigger className={cn(btn, "data-popup-open:bg-muted")}>
          Assign picker <ChevronDownIcon />
        </BMenu.Trigger>
        <BMenu.Portal>
          <BMenu.Positioner sideOffset={6} align="start" className="z-50 outline-none">
            <BMenu.Popup className={cn(surface, "w-64 origin-(--transform-origin) p-1", anim.base)}>
              <BMenu.Input aria-label="Filter pickers" placeholder="Filter pickers…" className={cn(field, "mb-1 h-7")} />
              <BMenu.Empty className="px-2 py-3 text-center text-sm text-muted-foreground">No picker matches.</BMenu.Empty>
              <BMenu.List className="max-h-56 overflow-y-auto">
                {pickers.map((p) => (
                  <BMenu.Item key={p} className={menuItem} onClick={() => toast(`${p} is picking #4821`)}>
                    {p}
                  </BMenu.Item>
                ))}
              </BMenu.List>
            </BMenu.Popup>
          </BMenu.Positioner>
        </BMenu.Portal>
      </BMenu.Root>
    </BMenu.FilterProvider>
  )
}

const statusItems = orderStatuses.map((s) => ({ value: s, label: s }))

function MultiSelectDemo() {
  const [value, setValue] = useState<string[]>(["Picking", "Packed"])
  return (
    <BSelect.Root items={statusItems} multiple value={value} onValueChange={setValue}>
      <div className="grid gap-1.5">
        <BSelect.Label className="text-sm font-medium">Show orders that are</BSelect.Label>
        <BSelect.Trigger className={cn(selectTrigger, "w-64 data-popup-open:bg-muted")}>
          <BSelect.Value className="flex-1 truncate text-left">
            {(v: string[]) => (v.length === 0 ? "Any status" : v.length <= 2 ? v.join(", ") : `${v.length} statuses`)}
          </BSelect.Value>
          <BSelect.Icon>
            <ChevronsUpDownIcon />
          </BSelect.Icon>
        </BSelect.Trigger>
      </div>
      <BSelect.Portal>
        <BSelect.Positioner alignItemWithTrigger={false} sideOffset={6} className="z-50 outline-none select-none">
          <BSelect.Popup className={cn(surface, "min-w-(--anchor-width) origin-(--transform-origin) p-1", fade.base)}>
            <BSelect.List>
              {orderStatuses.map((s) => (
                <BSelect.Item key={s} value={s} className={cn(menuItem, "pl-8")}>
                  <BSelect.ItemIndicator className="absolute left-2 inline-flex">
                    <CheckIcon />
                  </BSelect.ItemIndicator>
                  <BSelect.ItemText>{s}</BSelect.ItemText>
                </BSelect.Item>
              ))}
            </BSelect.List>
          </BSelect.Popup>
        </BSelect.Positioner>
      </BSelect.Portal>
    </BSelect.Root>
  )
}

function BaseOnlyMoreSection() {
  return (
    <Section
      title="Only in Base UI: menus & feedback"
      description="Smaller things that would otherwise mean a second library or hand-rolled ARIA."
      className="md:grid-cols-3"
    >
      <Variant
        label="Meter"
        lib="Base UI"
        hint={
          <>
            <code>role="meter"</code> with formatted value. Radix only has Progress (<code>role="progressbar"</code>), which
            is for task progress, not a level.
          </>
        }
      >
        <MeterDemo />
      </Variant>
      <Variant
        label="Filterable menu (preview)"
        lib="Base UI"
        hint={
          <>
            <code>Menu.FilterProvider</code> + <code>Menu.Input</code> + <code>Menu.List</code>. Marked [Preview] in 1.9
            docs. With Radix you'd reach for cmdk inside a Popover.
          </>
        }
      >
        <FilterMenuDemo />
      </Variant>
      <Variant
        label="Select multiple"
        lib="Base UI"
        hint={
          <>
            <code>multiple</code> on Select.Root; <code>Value</code> takes a render function for the summary. Radix Select
            is single-value only.
          </>
        }
      >
        <MultiSelectDemo />
      </Variant>
    </Section>
  )
}

/* ------------------------------------------------------------------------------------------------ */

export default function PrimitivesPage() {
  return (
    <Page
      title="Base UI vs Radix"
      intro="The same components built on each headless library, styled with identical Tailwind classes, so what differs is behaviour and API. shadcn/ui's base-nova style (this playground) is built on Base UI; the classic shadcn style is built on Radix."
      libs={[...libs]}
    >
      <OverlaysSection />
      <MenuSelectSection />
      <SmallControlsSection />
      <BaseOnlyInputsSection />
      <BaseOnlyMoreSection />
      <Findings
        notes={[
          {
            tone: "good",
            text: "Behaviour is near-identical for the shared set: focus trap and return, Esc, outside-click, type-ahead, arrow keys, submenus with safe-triangle hover. Either is a safe foundation; pick by which shadcn style you start from.",
          },
          {
            tone: "good",
            text: "Base UI covers more ground in one package: NumberField, Meter, OTP (stable), Combobox, Autocomplete, multi-Select, Drawer, filterable Menu. With Radix those are separate libraries (cmdk, Vaul, input-otp…).",
          },
          {
            tone: "note",
            text: (
              <>
                API shape: Base UI is one layer deeper (Portal → Positioner → Popup) and composes with{" "}
                <code>render</code>; Radix is Portal → Content with <code>asChild</code>. Base UI's{" "}
                <code>render</code> also takes a function <code>(props, state) =&gt; …</code>, which is handy for state-aware
                children.
              </>
            ),
          },
          {
            tone: "note",
            text: (
              <>
                Styling hooks differ: Base UI uses <code>data-open</code>/<code>data-checked</code>/<code>data-popup-open</code>{" "}
                and one generic <code>--transform-origin</code>; Radix uses <code>data-state=…</code> and per-component vars like{" "}
                <code>--radix-dropdown-menu-content-transform-origin</code>. Copying classes between the two styles never
                works as-is.
              </>
            ),
          },
          {
            tone: "bad",
            text: (
              <>
                Base UI Select shows the raw value (“SA”) in the trigger unless you pass <code>items</code> to Root or a render
                function to <code>Value</code>. Easy to miss; Radix just shows the selected item's text.
              </>
            ),
          },
          {
            tone: "bad",
            text: (
              <>
                Radix menu checkbox/radio items close the menu on every toggle; you need{" "}
                <code>onSelect={"{e => e.preventDefault()}"}</code> on each. Base UI keeps them open by default, which is what you
                usually want for view options.
              </>
            ),
          },
          {
            tone: "note",
            text: "Recommendation: Base UI for new Graphitree / Vite work (matches base-nova shadcn, fewer extra deps). Keep Radix where an existing app already uses classic shadcn; don't mix both in one app.",
          },
        ]}
      />
    </Page>
  )
}

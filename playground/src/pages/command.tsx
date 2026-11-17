import { useEffect, useId, useMemo, useRef, useState, type FormEvent } from "react"
import { Command as CommandPrimitive } from "cmdk"
import { Combobox as ComboboxPrimitive } from "@base-ui/react/combobox"
import { useTheme } from "next-themes"
import { toast } from "sonner"
import {
  ArrowLeftIcon,
  CircleDotIcon,
  FileTextIcon,
  KeyboardIcon,
  LayoutDashboardIcon,
  Loader2Icon,
  PackageIcon,
  PlusIcon,
  SearchIcon,
  ShoppingCartIcon,
  StoreIcon,
  SunMoonIcon,
  UsersIcon,
} from "lucide-react"

import { Button } from "@/components/ui/button"
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
  ComboboxCollection,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxGroup,
  ComboboxInput,
  ComboboxItem,
  ComboboxLabel,
  ComboboxList,
  ComboboxValue,
  useComboboxAnchor,
} from "@/components/ui/combobox"
import { Kbd, KbdGroup } from "@/components/ui/kbd"
import { cn } from "@/lib/utils"
import { Findings, Page, Section, Variant } from "@/playground/kit"
import { ControlBar, Readout, Segmented, Toggle } from "@/demos/app/controls"
import {
  customers,
  orderStatuses,
  recentOrders,
  rm,
  salesChannels,
  skus,
  wait,
  type Customer,
  type Sku,
} from "@/demos/app/data"

type Knobs = { loop: boolean; latency: number; contains: boolean }

/** cmdk's default is a fuzzy scorer ("mss" finds "Mydin Subang Jaya"); this is the plain alternative. */
const containsFilter = (value: string, search: string, keywords?: string[]) =>
  [value, ...(keywords ?? [])].join(" ").toLowerCase().includes(search.toLowerCase()) ? 1 : 0

async function searchOrders(q: string, latency: number) {
  await wait(latency)
  const s = q.toLowerCase().replace("#", "")
  return recentOrders.filter((o) => o.id.includes(s) || o.customer.toLowerCase().includes(s))
}

async function searchCustomers(q: string, latency: number) {
  await wait(latency)
  const s = q.toLowerCase()
  return customers.filter((c) => c.name.toLowerCase().includes(s) || c.id.toLowerCase().includes(s) || c.area.toLowerCase().includes(s))
}

/* ------------------------------------------------------------------------------------------------
 * 1. Palette vs picker
 * ---------------------------------------------------------------------------------------------- */

function PaletteJob({ knobs }: { knobs: Knobs }) {
  const [last, setLast] = useState("nothing yet")
  const [search, setSearch] = useState("")
  return (
    <div className="flex w-full flex-col gap-3">
      <Command
        loop={knobs.loop}
        filter={knobs.contains ? containsFilter : undefined}
        className="rounded-xl! border shadow-sm"
      >
        <CommandInput value={search} onValueChange={setSearch} placeholder="Type a customer or a command…" />
        <CommandList className="max-h-56">
          <CommandEmpty>No command or customer matches “{search}”.</CommandEmpty>
          <CommandGroup heading="Actions">
            <CommandItem
              onSelect={() => {
                setLast("create order (draft)")
                toast("New draft order created")
                setSearch("")
              }}
            >
              <PlusIcon /> New order <CommandShortcut>⌘N</CommandShortcut>
            </CommandItem>
          </CommandGroup>
          <CommandGroup heading="Go to customer">
            {customers.slice(0, 6).map((c) => (
              <CommandItem
                key={c.id}
                value={`${c.name} ${c.id}`}
                keywords={[c.area, c.channel]}
                onSelect={() => {
                  setLast(`navigate → /customers/${c.id}`)
                  toast(`Opening ${c.name}…`)
                  setSearch("")
                }}
              >
                <StoreIcon /> {c.name}
                <span className="ml-auto text-xs text-muted-foreground">{c.area}</span>
              </CommandItem>
            ))}
          </CommandGroup>
        </CommandList>
      </Command>
      <Readout>last command: {last} · nothing is kept, the input clears</Readout>
    </div>
  )
}

function PickerJob() {
  const id = useId()
  const [value, setValue] = useState<Customer | null>(null)
  const [submitted, setSubmitted] = useState("not submitted")
  function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setSubmitted(JSON.stringify(Object.fromEntries(new FormData(e.currentTarget))))
  }
  return (
    <form onSubmit={onSubmit} className="flex w-full flex-col gap-3">
      <div className="grid gap-1.5">
        <label htmlFor={id} className="text-sm font-medium">
          Bill to <span className="text-muted-foreground">(required)</span>
        </label>
        <Combobox
          items={customers}
          value={value}
          onValueChange={setValue}
          itemToStringLabel={(c: Customer) => c.name}
          itemToStringValue={(c: Customer) => c.id}
          isItemEqualToValue={(a: Customer, b: Customer) => a.id === b.id}
          name="billTo"
          required
        >
          <ComboboxInput id={id} placeholder="Search customers…" showClear className="w-full" />
          <ComboboxContent>
            <ComboboxEmpty>No customer matches.</ComboboxEmpty>
            <ComboboxList>
              {(c: Customer) => (
                <ComboboxItem key={c.id} value={c}>
                  <StoreIcon className="text-muted-foreground" />
                  <span className="truncate">{c.name}</span>
                  <span className="ml-auto text-xs text-muted-foreground">{c.terms}</span>
                </ComboboxItem>
              )}
            </ComboboxList>
          </ComboboxContent>
        </Combobox>
      </div>
      <div className="text-xs text-muted-foreground">
        {value ? `${value.channel} · ${value.area} · payment terms ${value.terms}` : "Pick a customer to fill in terms."}
      </div>
      <div className="flex items-center gap-2">
        <Button type="submit" size="sm">
          Submit form
        </Button>
        <Readout className="flex-1">FormData: {submitted}</Readout>
      </div>
    </form>
  )
}

function RuleOfThumb() {
  const rows = [
    ["What it holds", "Nothing. It runs something and closes.", "A value, kept and shown in the field."],
    ["Items are", "Verbs and places: New order, Go to…, Toggle theme", "Nouns of one kind: customers, warehouses, SKUs"],
    ["Opened by", "⌘K from anywhere, or a search button", "Focusing / clicking a form field"],
    ["Lives in", "A dialog over the app (or a sidebar list)", "A form, a filter bar, a table cell"],
    ["Form support", "None (no name, no validation)", "name, required, hidden input, Field/Form"],
    ["Use", "cmdk via shadcn Command", "Base UI Combobox via shadcn Combobox"],
  ]
  return (
    <table className="w-full text-left text-sm">
      <thead className="text-xs text-muted-foreground">
        <tr className="border-b">
          <th className="py-2 pr-4 font-medium" />
          <th className="py-2 pr-4 font-medium">Command palette</th>
          <th className="py-2 font-medium">Combobox picker</th>
        </tr>
      </thead>
      <tbody>
        {rows.map(([k, a, b]) => (
          <tr key={k} className="border-b last:border-0">
            <td className="py-2 pr-4 align-top text-muted-foreground">{k}</td>
            <td className="py-2 pr-4 align-top">{a}</td>
            <td className="py-2 align-top">{b}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}

/* ------------------------------------------------------------------------------------------------
 * 2. cmdk palette
 * ---------------------------------------------------------------------------------------------- */

type PaletteView = "customers" | "orders" | "status"
const viewLabel: Record<PaletteView, string> = {
  customers: "Customers",
  orders: "Search orders",
  status: "Status of #4821",
}

function CommandPalette({ knobs }: { knobs: Knobs }) {
  const [open, setOpen] = useState(false)
  const [stack, setStack] = useState<PaletteView[]>([])
  const [search, setSearch] = useState("")
  const [status, setStatus] = useState<string>("Picking")
  const [orders, setOrders] = useState<typeof recentOrders>(recentOrders.slice(0, 5))
  const [loading, setLoading] = useState(false)
  const req = useRef(0)
  const { resolvedTheme, setTheme } = useTheme()
  const view = stack.at(-1)

  // ⌘K / Ctrl+K anywhere on this page.
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

  // Server-side search for the "orders" view: cmdk filtering is off there. Stale responses are dropped.
  const searchServer = (q: string) => {
    const id = ++req.current
    setLoading(true)
    searchOrders(q, knobs.latency).then((r) => {
      if (id !== req.current) return
      setOrders(r)
      setLoading(false)
    })
  }
  const onSearch = (q: string) => {
    setSearch(q)
    if (view === "orders") searchServer(q)
  }

  const push = (v: PaletteView) => {
    setStack((s) => [...s, v])
    setSearch("")
    if (v === "orders") searchServer("")
  }
  const pop = () => {
    setStack((s) => s.slice(0, -1))
    setSearch("")
  }
  const run = (message: string) => {
    setOpen(false)
    toast(message)
  }

  return (
    <>
      <Button variant="outline" className="w-72 justify-between text-muted-foreground" onClick={() => setOpen(true)}>
        <span className="flex items-center gap-2">
          <SearchIcon /> Search or jump to…
        </span>
        <KbdGroup>
          <Kbd>⌘</Kbd>
          <Kbd>K</Kbd>
        </KbdGroup>
      </Button>
      <CommandDialog
        open={open}
        onOpenChange={(next, details) => {
          // Esc inside a nested view goes back a level instead of closing the dialog.
          if (!next && details.reason === "escape-key" && stack.length > 0) {
            details.cancel()
            pop()
            return
          }
          setOpen(next)
        }}
        onOpenChangeComplete={(isOpen) => {
          if (!isOpen) {
            setStack([])
            setSearch("")
          }
        }}
        className="sm:max-w-lg"
      >
        <Command
          loop={knobs.loop}
          shouldFilter={view !== "orders"}
          filter={knobs.contains ? containsFilter : undefined}
          onKeyDown={(e) => {
            if (e.key === "Backspace" && search === "" && stack.length > 0) {
              e.preventDefault()
              pop()
            }
          }}
        >
          {stack.length > 0 && (
            <div className="flex items-center gap-1.5 px-2 pt-2 text-xs text-muted-foreground">
              <button type="button" onClick={pop} className="rounded-md p-1 hover:bg-muted" aria-label="Back">
                <ArrowLeftIcon className="size-3.5" />
              </button>
              <span>Home</span>
              {stack.map((v) => (
                <span key={v} className="flex items-center gap-1.5">
                  / <span className="rounded bg-muted px-1.5 py-0.5 text-foreground">{viewLabel[v]}</span>
                </span>
              ))}
            </div>
          )}
          <CommandInput
            value={search}
            onValueChange={onSearch}
            placeholder={
              view === "customers"
                ? "Find a customer…"
                : view === "orders"
                  ? "Order number or customer…"
                  : view === "status"
                    ? "Set status…"
                    : "Type a command or search…"
            }
          />
          <CommandList className="max-h-80">
            {view === "orders" && loading && (
              <CommandPrimitive.Loading>
                <div className="flex items-center gap-2 px-3 py-2 text-sm text-muted-foreground">
                  <Loader2Icon className="size-4 animate-spin" /> Searching orders…
                </div>
              </CommandPrimitive.Loading>
            )}
            {!(view === "orders" && loading) && (
              <CommandEmpty>
                <div className="grid gap-1">
                  <span>No results for “{search}”.</span>
                  <span className="text-xs text-muted-foreground">
                    {view === "orders"
                      ? "Try an order number like 4821, or a customer name."
                      : view === "customers"
                        ? "Try a name, a customer ID or a state."
                        : "Try “order”, “stock” or “theme”."}
                  </span>
                </div>
              </CommandEmpty>
            )}

            {!view && (
              <>
                <CommandGroup heading="Suggestions">
                  <CommandItem onSelect={() => run("New draft order created")}>
                    <PlusIcon /> New order <CommandShortcut>⌘N</CommandShortcut>
                  </CommandItem>
                  <CommandItem onSelect={() => push("orders")} keywords={["find", "lookup"]}>
                    <SearchIcon /> Search orders…
                  </CommandItem>
                  <CommandItem onSelect={() => push("customers")} keywords={["account", "outlet"]}>
                    <UsersIcon /> Go to customer…
                  </CommandItem>
                  <CommandItem onSelect={() => push("status")}>
                    <CircleDotIcon /> Change status of #4821…
                  </CommandItem>
                </CommandGroup>
                <CommandSeparator />
                <CommandGroup heading="Navigate">
                  {[
                    { icon: LayoutDashboardIcon, label: "Dashboard", keys: "G D" },
                    { icon: ShoppingCartIcon, label: "Orders", keys: "G O" },
                    { icon: PackageIcon, label: "Stock levels", keys: "G S" },
                    { icon: UsersIcon, label: "Customers", keys: "G C" },
                    { icon: FileTextIcon, label: "Reports", keys: "G R" },
                  ].map(({ icon: Icon, label, keys }) => (
                    <CommandItem key={label} onSelect={() => run(`Go to ${label}`)}>
                      <Icon /> {label} <CommandShortcut>{keys}</CommandShortcut>
                    </CommandItem>
                  ))}
                </CommandGroup>
                <CommandSeparator />
                <CommandGroup heading="Preferences">
                  <CommandItem
                    keywords={["dark", "light", "appearance"]}
                    onSelect={() => {
                      setTheme(resolvedTheme === "dark" ? "light" : "dark")
                      setOpen(false)
                    }}
                  >
                    <SunMoonIcon /> Switch to {resolvedTheme === "dark" ? "light" : "dark"} theme
                  </CommandItem>
                  <CommandItem onSelect={() => run("Shortcuts: ⌘K palette · G then a letter to navigate")}>
                    <KeyboardIcon /> Keyboard shortcuts <CommandShortcut>?</CommandShortcut>
                  </CommandItem>
                </CommandGroup>
              </>
            )}

            {view === "customers" && (
              <CommandGroup heading="Customers">
                {customers.map((c) => (
                  <CommandItem
                    key={c.id}
                    value={`${c.name} ${c.id}`}
                    keywords={[c.area, c.channel]}
                    onSelect={() => run(`Opening ${c.name}…`)}
                  >
                    <StoreIcon /> {c.name}
                    <span className="ml-auto font-mono text-xs text-muted-foreground">{c.id}</span>
                  </CommandItem>
                ))}
              </CommandGroup>
            )}

            {view === "orders" && !loading && orders.length > 0 && (
              <CommandGroup heading={search ? `Matches for “${search}”` : "Recent orders"}>
                {orders.map((o) => (
                  <CommandItem key={o.id} value={o.id} onSelect={() => run(`Opening order ${o.id}…`)}>
                    <ShoppingCartIcon />
                    <span className="font-mono">{o.id}</span>
                    <span className="truncate text-muted-foreground">{o.customer}</span>
                    <span className="ml-auto text-xs tabular-nums text-muted-foreground">{rm(o.total)}</span>
                  </CommandItem>
                ))}
              </CommandGroup>
            )}

            {view === "status" && (
              <CommandGroup heading="Order #4821">
                {orderStatuses.map((s) => (
                  <CommandItem
                    key={s}
                    value={s}
                    data-checked={s === status}
                    disabled={s === "Delivered"}
                    onSelect={() => {
                      setStatus(s)
                      run(`#4821 moved to ${s}`)
                    }}
                  >
                    <CircleDotIcon /> {s}
                    {s === "Delivered" && <span className="text-xs text-muted-foreground">needs a POD first</span>}
                  </CommandItem>
                ))}
              </CommandGroup>
            )}
          </CommandList>
          <div className="flex items-center gap-3 border-t px-3 py-2 text-xs text-muted-foreground">
            <span className="flex items-center gap-1">
              <Kbd>↑</Kbd>
              <Kbd>↓</Kbd> move
            </span>
            <span className="flex items-center gap-1">
              <Kbd>↵</Kbd> run
            </span>
            <span className="flex items-center gap-1">
              <Kbd>esc</Kbd> {stack.length ? "back" : "close"}
            </span>
            {stack.length > 0 && (
              <span className="flex items-center gap-1">
                <Kbd>⌫</Kbd> back
              </span>
            )}
          </div>
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

function InlineList({ knobs }: { knobs: Knobs }) {
  const [picked, setPicked] = useState<Sku | null>(null)
  return (
    <div className="flex w-full flex-col gap-3">
      <Command loop={knobs.loop} filter={knobs.contains ? containsFilter : undefined} className="rounded-xl! border">
        <CommandInput placeholder="Filter by name, SKU code or category…" />
        <CommandList className="max-h-64">
          <CommandEmpty>No SKU matches.</CommandEmpty>
          {skuGroups.map(([category, items]) => (
            <CommandGroup key={category} heading={category}>
              {items.map((s) => (
                <CommandItem
                  key={s.sku}
                  value={s.sku}
                  keywords={[s.name, category]}
                  disabled={s.onHand === 0}
                  data-checked={picked?.sku === s.sku}
                  onSelect={() => setPicked(s)}
                >
                  <span className="truncate">{s.name}</span>
                  <span className="font-mono text-xs text-muted-foreground">{s.sku}</span>
                  <span
                    className={cn(
                      "ml-auto rounded px-1.5 py-0.5 text-xs tabular-nums",
                      s.onHand === 0
                        ? "bg-muted text-muted-foreground"
                        : s.onHand < 100
                          ? "bg-amber-500/15 text-amber-700 dark:text-amber-300"
                          : "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300",
                    )}
                  >
                    {s.onHand === 0 ? "out" : s.onHand.toLocaleString()}
                  </span>
                </CommandItem>
              ))}
            </CommandGroup>
          ))}
        </CommandList>
      </Command>
      <Readout>{picked ? `selected ${picked.sku} · ${rm(picked.price)} · ${picked.onHand} on hand` : "nothing selected"}</Readout>
    </div>
  )
}

/* ------------------------------------------------------------------------------------------------
 * 3. Base UI Combobox
 * ---------------------------------------------------------------------------------------------- */

type EscDetails = { reason: string; cancel: () => void; allowPropagation: () => void }

/**
 * The change details reach onValueChange before Base UI checks `isCanceled`, so a controlled value
 * has to skip canceled changes itself.
 */
const unlessCanceled =
  <T,>(set: (value: T) => void) =>
  (value: T, details: { isCanceled: boolean }) => {
    if (!details.isCanceled) set(value)
  }

/**
 * Base UI clears the whole selection when Esc is pressed while the popup is closed (and swallows the
 * Esc, so a surrounding dialog stays open). Cancelling that change keeps the value and lets Esc bubble.
 * The input-change event fires first and shares its details with the value change, so cancel it here.
 */
const guardEsc =(escClears: boolean) => (next: string, details: EscDetails) => {
  if (!escClears && details.reason === "escape-key" && next === "") {
    details.cancel()
    details.allowPropagation()
  }
}

function SingleCombobox({ escClears }: { escClears: boolean }) {
  const id = useId()
  const [value, setValue] = useState<Customer | null>(customers[0])
  return (
    <div className="flex w-full max-w-xs flex-col gap-2">
      <label htmlFor={id} className="text-sm font-medium">
        Customer
      </label>
      <Combobox
        items={customers}
        value={value}
        onValueChange={unlessCanceled(setValue)}
        itemToStringLabel={(c: Customer) => c.name}
        isItemEqualToValue={(a: Customer, b: Customer) => a.id === b.id}
        onInputValueChange={guardEsc(escClears)}
        autoHighlight
      >
        <ComboboxInput id={id} placeholder="Search customers…" showClear />
        <ComboboxContent>
          <ComboboxEmpty>No customer matches.</ComboboxEmpty>
          <ComboboxList>
            {(c: Customer) => (
              <ComboboxItem key={c.id} value={c}>
                <div className="grid min-w-0">
                  <span className="truncate">{c.name}</span>
                  <span className="text-xs text-muted-foreground">
                    {c.area} · {c.channel}
                  </span>
                </div>
              </ComboboxItem>
            )}
          </ComboboxList>
        </ComboboxContent>
      </Combobox>
      <Readout>value: {value ? `${value.id} (${value.name})` : "null"}</Readout>
    </div>
  )
}

function MultiCombobox({ escClears }: { escClears: boolean }) {
  const anchor = useComboboxAnchor()
  const id = useId()
  const [value, setValue] = useState<string[]>(["Modern trade", "Shopee"])
  return (
    <div className="flex w-full max-w-sm flex-col gap-2">
      <label htmlFor={id} className="text-sm font-medium">
        Sales channels for this promo
      </label>
      <Combobox
        multiple
        items={salesChannels}
        value={value}
        onValueChange={unlessCanceled(setValue)}
        onInputValueChange={guardEsc(escClears)}
        autoHighlight
      >
        <ComboboxChips ref={anchor}>
          <ComboboxValue>
            {(values: string[]) => (
              <>
                {values.map((v) => (
                  <ComboboxChip key={v}>{v}</ComboboxChip>
                ))}
                <ComboboxChipsInput id={id} placeholder={values.length ? "" : "Add a channel…"} />
              </>
            )}
          </ComboboxValue>
        </ComboboxChips>
        <ComboboxContent anchor={anchor}>
          <ComboboxEmpty>No channel found.</ComboboxEmpty>
          <ComboboxList>
            {(item: string) => (
              <ComboboxItem key={item} value={item}>
                {item}
              </ComboboxItem>
            )}
          </ComboboxList>
        </ComboboxContent>
      </Combobox>
      <Readout>value: [{value.map((v) => `"${v}"`).join(", ")}]</Readout>
    </div>
  )
}

function AsyncCombobox({ latency, escClears }: { latency: number; escClears: boolean }) {
  const id = useId()
  const [selected, setSelected] = useState<Customer | null>(null)
  const [results, setResults] = useState<Customer[]>([])
  const [query, setQuery] = useState("")
  const [loading, setLoading] = useState(false)
  const req = useRef(0)

  // Keep the selected item in `items` so the input can still show its label while results change.
  const items = useMemo(
    () => (selected && !results.some((c) => c.id === selected.id) ? [...results, selected] : results),
    [results, selected],
  )

  const trimmed = query.trim()
  const status = loading
    ? "Searching…"
    : trimmed.length < 2
      ? selected
        ? null
        : "Type at least 2 letters (try “ma” or “sabah”)."
      : results.length === 0
        ? `No customers match “${trimmed}”.`
        : `${results.length} found`

  return (
    <div className="flex w-full max-w-xs flex-col gap-2">
      <label htmlFor={id} className="text-sm font-medium">
        Assign to customer (server search)
      </label>
      <Combobox
        items={items}
        filter={null}
        value={selected}
        onValueChange={unlessCanceled(setSelected)}
        itemToStringLabel={(c: Customer) => c.name}
        isItemEqualToValue={(a: Customer, b: Customer) => a.id === b.id}
        onInputValueChange={(next, details) => {
          guardEsc(escClears)(next, details)
          if (details.isCanceled) return
          setQuery(next)
          if (details.reason === "item-press") return
          if (next.trim().length < 2) {
            req.current++
            setResults([])
            setLoading(false)
            return
          }
          const reqId = ++req.current
          setLoading(true)
          searchCustomers(next, latency).then((r) => {
            if (reqId !== req.current) return
            setResults(r)
            setLoading(false)
          })
        }}
      >
        <ComboboxInput id={id} placeholder="Search by name, ID or state…" showClear />
        <ComboboxContent aria-busy={loading || undefined}>
          <ComboboxPrimitive.Status className="flex items-center gap-2 px-3 pt-2 text-xs text-muted-foreground empty:hidden">
            {status && (
              <>
                {loading && <Loader2Icon className="size-3.5 animate-spin" />}
                {status}
              </>
            )}
          </ComboboxPrimitive.Status>
          <ComboboxList>
            {(c: Customer) => (
              <ComboboxItem key={c.id} value={c}>
                <span className="truncate">{c.name}</span>
                <span className="ml-auto font-mono text-xs text-muted-foreground">{c.id}</span>
              </ComboboxItem>
            )}
          </ComboboxList>
        </ComboboxContent>
      </Combobox>
      <Readout>value: {selected ? selected.id : "null"}</Readout>
    </div>
  )
}

const skuComboGroups = skuGroups.map(([value, items]) => ({ value, items }))

function GroupedCombobox({ escClears }: { escClears: boolean }) {
  const id = useId()
  const [value, setValue] = useState<Sku | null>(null)
  return (
    <div className="flex w-full max-w-xs flex-col gap-2">
      <label htmlFor={id} className="text-sm font-medium">
        Add SKU to order
      </label>
      <Combobox
        items={skuComboGroups}
        value={value}
        onValueChange={unlessCanceled(setValue)}
        itemToStringLabel={(s: Sku) => s.name}
        isItemEqualToValue={(a: Sku, b: Sku) => a.sku === b.sku}
        onInputValueChange={guardEsc(escClears)}
      >
        <ComboboxInput id={id} placeholder="Search SKUs…" />
        <ComboboxContent>
          <ComboboxEmpty>No SKU found.</ComboboxEmpty>
          <ComboboxList>
            {(group: { value: string; items: Sku[] }) => (
              <ComboboxGroup key={group.value} items={group.items}>
                <ComboboxLabel>{group.value}</ComboboxLabel>
                <ComboboxCollection>
                  {(s: Sku) => (
                    <ComboboxItem key={s.sku} value={s} disabled={s.onHand === 0}>
                      <span className="truncate">{s.name}</span>
                      <span className="ml-auto text-xs text-muted-foreground tabular-nums">
                        {s.onHand === 0 ? "out of stock" : rm(s.price)}
                      </span>
                    </ComboboxItem>
                  )}
                </ComboboxCollection>
              </ComboboxGroup>
            )}
          </ComboboxList>
        </ComboboxContent>
      </Combobox>
      <Readout>value: {value ? `${value.sku} · ${rm(value.price)}` : "null"}</Readout>
    </div>
  )
}

/* ------------------------------------------------------------------------------------------------ */

export default function CommandPage() {
  const [loop, setLoop] = useState(true)
  const [contains, setContains] = useState(false)
  const [latency, setLatency] = useState("600")
  const [escClears, setEscClears] = useState(true)
  const knobs: Knobs = { loop, contains, latency: Number(latency) }

  return (
    <Page
      title="Command menu & pickers"
      intro="Two jobs that look alike. A command palette (cmdk) runs an action and forgets; a combobox (Base UI) picks a value for a form and keeps it. Same list of customers below, built both ways, then each one in depth."
      libs={[
        { name: "cmdk", status: "playbook", url: "https://cmdk.paco.me", install: "npx shadcn add command" },
        { name: "Base UI Combobox", status: "playbook", url: "https://base-ui.com/react/components/combobox", install: "npx shadcn add combobox" },
        { name: "shadcn/ui", status: "playbook", url: "https://ui.shadcn.com" },
      ]}
    >
      <Section
        title="Palette vs picker: same customers, two jobs"
        description="Pick “Mydin Subang Jaya” in both. The palette fires a navigation and resets; the combobox fills a required form field and submits an ID."
      >
        <Variant label="Command palette: runs an action" lib="cmdk (shadcn Command)">
          <PaletteJob knobs={knobs} />
        </Variant>
        <Variant label="Combobox: picks a value" lib="Base UI (shadcn Combobox)">
          <PickerJob />
        </Variant>
        <Variant label="Rule of thumb" className="md:col-span-2" stageClassName="block p-4">
          <RuleOfThumb />
        </Variant>
      </Section>

      <Section
        title="cmdk: the ⌘K palette"
        description="Press ⌘K (Ctrl+K) anywhere on this page. Try “Go to customer…” then Backspace or Esc to come back, “Search orders…” for a loading state, and a nonsense query for the empty state."
      >
        <ControlBar>
          <Toggle label="Loop at the ends" checked={loop} onCheckedChange={setLoop} />
          <Toggle label="Plain “contains” matching (default is fuzzy)" checked={contains} onCheckedChange={setContains} />
          <Segmented
            label="Search latency"
            value={latency}
            onChange={setLatency}
            options={[
              { value: "150", label: "150 ms" },
              { value: "600", label: "600 ms" },
              { value: "1500", label: "1.5 s" },
            ]}
          />
        </ControlBar>
        <Variant
          label="Palette in a dialog"
          lib="cmdk + Base UI Dialog"
          hint={
            <>
              Nested pages are just state (a stack) plus conditional groups. Esc-to-go-back uses the Base UI dialog's{" "}
              <code>onOpenChange(open, details)</code> + <code>details.cancel()</code>. Orders view sets{" "}
              <code>shouldFilter={"{false}"}</code> and shows <code>Command.Loading</code>.
            </>
          }
        >
          <CommandPalette knobs={knobs} />
        </Variant>
        <Variant
          label="Inline filterable list"
          lib="cmdk"
          hint={
            <>
              No dialog: a list with a filter box, e.g. a side panel. <code>value</code> is the SKU, <code>keywords</code> add the
              name and category; out-of-stock rows are <code>disabled</code> and skipped by the arrows.
            </>
          }
        >
          <InlineList knobs={knobs} />
        </Variant>
      </Section>

      <Section
        title="Base UI Combobox: form pickers"
        description="The value-holding side. All four are shadcn's Combobox (Base UI) with object items, so the value is a Customer/SKU, not a string."
      >
        <ControlBar>
          <Toggle
            label="Esc on a closed combobox clears the value (Base UI default)"
            checked={escClears}
            onCheckedChange={setEscClears}
          />
          <span className="text-xs text-muted-foreground">
            Off = <code>details.cancel()</code> in <code>onInputValueChange</code> for <code>"escape-key"</code>, and ignore canceled
            changes in <code>onValueChange</code>.
          </span>
        </ControlBar>
        <Variant
          label="Single, with clear"
          lib="Base UI"
          hint={
            <>
              <code>itemToStringLabel</code> for the input text and filtering, <code>isItemEqualToValue</code> for object values.
              Type to filter, ↓ to open, Esc restores the selected label.
            </>
          }
        >
          <SingleCombobox escClears={escClears} />
        </Variant>
        <Variant
          label="Multiple, with chips"
          lib="Base UI"
          hint={
            <>
              <code>multiple</code> + <code>Chips</code>. Backspace in the empty input removes the last chip; ←/→ move between
              chips.
            </>
          }
        >
          <MultiCombobox escClears={escClears} />
        </Variant>
        <Variant
          label="Async search"
          lib="Base UI"
          hint={
            <>
              <code>filter={"{null}"}</code> + <code>onInputValueChange</code> → fetch, stale responses dropped.{" "}
              <code>Combobox.Status</code> is an aria-live region for “Searching…”. Uses the latency knob above.
            </>
          }
        >
          <AsyncCombobox latency={knobs.latency} escClears={escClears} />
        </Variant>
        <Variant
          label="Grouped, custom rows"
          lib="Base UI"
          hint={
            <>
              Groups are <code>{"{ value, items }"}</code> objects rendered with <code>Group</code> + <code>Collection</code>.
              Disabled rows (out of stock) can't be picked.
            </>
          }
        >
          <GroupedCombobox escClears={escClears} />
        </Variant>
      </Section>

      <Findings
        notes={[
          {
            tone: "good",
            text: "cmdk is still the best palette: fast fuzzy ranking out of the box, keywords, groups that hide when empty, Loading/Empty parts, disabled items skipped by arrows. shadcn's CommandDialog puts it in a Base UI dialog with no extra work.",
          },
          {
            tone: "note",
            text: "cmdk has no concept of pages, breadcrumbs or async: you build them with a view stack, shouldFilter={false} and your own fetch. About 40 lines here; copy this page's pattern rather than reinventing it.",
          },
          {
            tone: "bad",
            text: (
              <>
                cmdk quirks: <code>value</code> doubles as the item's id and its search text, so duplicate labels collide (use{" "}
                <code>value={"{`${name} ${id}`}"}</code>); it never holds a selection, so “checked” has to be passed as{" "}
                <code>data-checked</code> by hand; filtering runs client-side over mounted items only. The default fuzzy score
                is loose (“sab” for Sabah also returns Borneo Mart Kuching and Mydin Subang Jaya); pass a <code>filter</code>{" "}
                for stricter matching on long lists.
              </>
            ),
          },
          {
            tone: "good",
            text: "Base UI Combobox is a proper form control: object values, name/required with a hidden input (FormData shows the ID), chips for multi-select, groups, Status live region for async, autoHighlight. shadcn's wrapper makes the common cases short.",
          },
          {
            tone: "bad",
            text: (
              <>
                Base UI Combobox needs three helpers for object items (<code>itemToStringLabel</code>,{" "}
                <code>itemToStringValue</code> for forms, <code>isItemEqualToValue</code>); forget one and you get “[object Object]”
                or a selection that doesn't stick. Async needs the selected item kept in <code>items</code> by hand.
              </>
            ),
          },
          {
            tone: "bad",
            text: (
              <>
                Gotcha: Esc while the popup is closed wipes the field (all chips in multi mode, no undo) and stops the Esc from
                reaching a surrounding dialog. Fine for a search box, surprising in a form. Guarding it takes two steps (toggle
                above): <code>details.cancel()</code> in <code>onInputValueChange</code>, and skip{" "}
                <code>details.isCanceled</code> in a controlled <code>onValueChange</code>, because Base UI calls it before
                checking.
              </>
            ),
          },
          {
            tone: "note",
            text: "Recommendation: cmdk for ⌘K palettes and quick-jump lists (admin portals, the chat workspace's command bar); Base UI Combobox for every form field and filter that picks from a list. Don't build pickers with cmdk in a Popover any more.",
          },
        ]}
      />
    </Page>
  )
}

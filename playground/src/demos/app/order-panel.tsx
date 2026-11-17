import { Badge } from "@/components/ui/badge"
import { cn } from "@/lib/utils"
import { customers, order4821, rm, type Order } from "@/demos/app/data"

const DELIVERY = 37.2

/** The order content every drawer/sheet on the Drawers page shows, so they're comparable. */
export function OrderSummary({ order = order4821, timeline = false, className }: { order?: Order; timeline?: boolean; className?: string }) {
  const customer = customers.find((c) => c.name === order.customer)
  const subtotal = order.lines.reduce((sum, l) => sum + l.qty * l.price, 0)
  return (
    <div className={cn("grid gap-4 text-sm", className)}>
      <div className="flex flex-wrap items-center gap-2">
        <Badge variant="secondary" className="bg-amber-500/15 text-amber-700 dark:text-amber-300">
          {order.status}
        </Badge>
        <span className="text-muted-foreground">
          Ship from {order.warehouse} · ETA {order.eta}
        </span>
      </div>
      <dl className="grid grid-cols-2 gap-x-4 gap-y-2">
        <div>
          <dt className="text-xs text-muted-foreground">Customer</dt>
          <dd className="font-medium">{order.customer}</dd>
        </div>
        <div>
          <dt className="text-xs text-muted-foreground">Payment terms</dt>
          <dd className="font-medium">{customer?.terms ?? "30 days"}</dd>
        </div>
        <div>
          <dt className="text-xs text-muted-foreground">Channel</dt>
          <dd className="font-medium">{customer?.channel ?? "Modern trade"}</dd>
        </div>
        <div>
          <dt className="text-xs text-muted-foreground">Customer PO</dt>
          <dd className="font-mono text-xs leading-5">MYD-PO-118204</dd>
        </div>
      </dl>
      <ul className="divide-y rounded-lg border">
        {order.lines.map((l) => (
          <li key={l.sku} className="flex items-center gap-3 px-3 py-2">
            <div className="grid min-w-0 flex-1">
              <span className="truncate font-medium">{l.name}</span>
              <span className="font-mono text-xs text-muted-foreground">{l.sku}</span>
            </div>
            <span className="text-xs text-muted-foreground tabular-nums">
              {l.qty} × {rm(l.price)}
            </span>
            <span className="w-24 text-right tabular-nums">{rm(l.qty * l.price)}</span>
          </li>
        ))}
      </ul>
      <div className="grid gap-1 tabular-nums">
        <div className="flex justify-between text-muted-foreground">
          <span>Subtotal</span>
          <span>{rm(subtotal)}</span>
        </div>
        <div className="flex justify-between text-muted-foreground">
          <span>Delivery (Klang Valley)</span>
          <span>{rm(DELIVERY)}</span>
        </div>
        <div className="flex justify-between font-semibold">
          <span>Total</span>
          <span>{rm(subtotal + DELIVERY)}</span>
        </div>
      </div>
      {timeline && (
        <ol className="grid gap-3 border-l pl-4 text-xs">
          {[
            ["Picking started, wave 3", "Sat 15 Nov, 08:40 · Hafiz Ismail"],
            ["Stock reserved at Shah Alam DC", "Fri 14 Nov, 10:05 · system"],
            ["Order confirmed", "Fri 14 Nov, 10:02 · Aisyah Rahman"],
            ["Received via B2B portal", "Fri 14 Nov, 09:47"],
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
      )}
    </div>
  )
}

/** Lines for a long, scrollable pick list (snap-point demos). */
const pickList = Array.from({ length: 24 }, (_, i) => {
  const bins = ["A", "B", "C", "D"]
  const names = [
    "Teh Tarik 3-in-1 (30 sticks)",
    "Instant Noodle Kari 5-pack",
    "Sambal Belacan 200g",
    "Coconut Milk 1L",
    "Kaya Pandan 400g",
    "Chilli Sauce 340ml",
  ]
  return {
    bin: `${bins[i % 4]}-${String(10 + i).padStart(2, "0")}-${(i % 3) + 1}`,
    name: names[i % names.length],
    qty: ((i * 7) % 40) + 6,
    order: `#48${String(10 + (i % 12)).padStart(2, "0")}`,
  }
})

export function PickList() {
  return (
    <ul className="divide-y rounded-lg border text-sm">
      {pickList.map((p) => (
        <li key={p.bin} className="flex items-center gap-3 px-3 py-2">
          <span className="w-16 font-mono text-xs text-muted-foreground">{p.bin}</span>
          <span className="flex-1 truncate">{p.name}</span>
          <span className="text-xs text-muted-foreground">{p.order}</span>
          <span className="w-10 text-right tabular-nums">×{p.qty}</span>
        </li>
      ))}
    </ul>
  )
}

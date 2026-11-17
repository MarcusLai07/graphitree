import { useState } from "react"
import { toast, type ToasterProps } from "sonner"
import { PackageIcon, RotateCcwIcon } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Toaster } from "@/components/ui/sonner"
import { Findings, Page, Section, Variant } from "@/playground/kit"
import { ControlBar, Segmented, Toggle } from "@/demos/app/controls"
import { BaseToastLab, baseToasts, type BaseToastPosition } from "@/demos/app/base-toast"
import { wait } from "@/demos/app/data"

/* Every Sonner toast on this page goes to a local <Toaster id="lab">, so the knobs below don't
 * change the app-wide <Toaster /> mounted in main.tsx. */
const LAB = "lab"
const L = { toasterId: LAB } as const

type Position = NonNullable<ToasterProps["position"]>

const positions: { value: Position; label: string }[] = [
  { value: "top-left", label: "↖" },
  { value: "top-center", label: "↑" },
  { value: "top-right", label: "↗" },
  { value: "bottom-left", label: "↙" },
  { value: "bottom-center", label: "↓" },
  { value: "bottom-right", label: "↘" },
]

/** Pretend API call for the promise demos. */
async function saveOrder(fail: boolean) {
  await wait(1800)
  if (fail) throw new Error("Stock for Sambal Belacan 200g changed while you were editing.")
  return { id: "#4821", total: "RM 2,665.20" }
}

/* ------------------------------------------------------------------------------------------------
 * Sonner
 * ---------------------------------------------------------------------------------------------- */

function SonnerTypes() {
  return (
    <div className="flex flex-wrap justify-center gap-2">
      <Button variant="outline" onClick={() => toast("Order #4821 saved", L)}>
        Default
      </Button>
      <Button variant="outline" onClick={() => toast.success("Payment received from Jaya Grocer Bangsar", L)}>
        Success
      </Button>
      <Button variant="outline" onClick={() => toast.error("Couldn't sync stock levels", L)}>
        Error
      </Button>
      <Button variant="outline" onClick={() => toast.info("Penang Hub closes early on Friday (Deepavali)", L)}>
        Info
      </Button>
      <Button variant="outline" onClick={() => toast.warning("Kopi O Kaw 500g is below reorder point", L)}>
        Warning
      </Button>
      <Button variant="outline" onClick={() => toast.loading("Generating picking list…", { ...L, duration: 2500 })}>
        Loading
      </Button>
    </div>
  )
}

function SonnerDescription() {
  return (
    <div className="flex flex-wrap justify-center gap-2">
      <Button
        variant="outline"
        onClick={() =>
          toast.success("Order #4821 saved", { ...L, description: "4 lines · RM 2,665.20 · ships Tue, 18 Nov from Shah Alam DC" })
        }
      >
        Saved, with details
      </Button>
      <Button
        variant="outline"
        onClick={() =>
          toast.error("Couldn't sync stock levels", {
            ...L,
            description: "Johor Bahru DC didn't respond after 30 s. Figures may be up to 2 hours old.",
          })
        }
      >
        Error, with reason
      </Button>
    </div>
  )
}

function SonnerActions() {
  return (
    <div className="flex flex-wrap justify-center gap-2">
      <Button
        variant="outline"
        onClick={() =>
          toast("Order #4816 archived", {
            ...L,
            description: "Penang Fresh Market · RM 640.80",
            action: { label: "Undo", onClick: () => toast.success("Order #4816 restored", L) },
          })
        }
      >
        Archive with undo
      </Button>
      <Button
        variant="outline"
        onClick={() =>
          toast.warning("Discard draft order #4822?", {
            ...L,
            description: "12 lines for Borneo Mart Kuching haven't been submitted.",
            duration: Infinity,
            action: { label: "Discard", onClick: () => toast("Draft #4822 discarded", L) },
            cancel: { label: "Keep", onClick: () => {} },
          })
        }
      >
        Confirm (action + cancel)
      </Button>
    </div>
  )
}

function SonnerPromise() {
  const [fail, setFail] = useState(false)
  return (
    <div className="flex flex-col items-center gap-3">
      <Button
        onClick={() =>
          toast.promise(saveOrder(fail), {
            ...L,
            loading: "Saving order #4821…",
            success: (o) => ({
              message: `Order ${o.id} saved`,
              description: `${o.total} · Mydin Subang Jaya`,
            }),
            error: (e: Error) => ({
              message: "Couldn't save order #4821",
              description: e.message,
              action: { label: "Retry", onClick: () => toast.success("Order #4821 saved", L) },
            }),
          })
        }
      >
        Save order
      </Button>
      <Toggle label="Make the save fail" checked={fail} onCheckedChange={setFail} />
    </div>
  )
}

function SonnerRich() {
  const rich = { ...L, richColors: true }
  return (
    <div className="flex flex-wrap justify-center gap-2">
      <Button variant="outline" onClick={() => toast.success("Delivery confirmed by driver", rich)}>
        Success
      </Button>
      <Button
        variant="outline"
        onClick={() => toast.error("Couldn't sync stock levels", { ...rich, description: "Johor Bahru DC timed out." })}
      >
        Error
      </Button>
      <Button variant="outline" onClick={() => toast.info("3 new orders from Shopee", rich)}>
        Info
      </Button>
      <Button variant="outline" onClick={() => toast.warning("Credit limit 92% used: Kedai Runcit Ahmad", rich)}>
        Warning
      </Button>
    </div>
  )
}

function SonnerCustom() {
  return (
    <Button
      variant="outline"
      onClick={() =>
        toast.custom(
          (id) => (
            <div className="w-[356px] rounded-xl border bg-popover p-4 text-popover-foreground shadow-lg">
              <div className="flex gap-3">
                <div className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-amber-500/15 text-amber-600 dark:text-amber-400">
                  <PackageIcon className="size-4" />
                </div>
                <div className="grid flex-1 gap-1">
                  <div className="text-sm font-medium">Low stock: Kopi O Kaw 500g</div>
                  <div className="flex justify-between text-xs text-muted-foreground">
                    <span className="font-mono">BEV-KOK5</span>
                    <span>86 / 120 reorder point</span>
                  </div>
                  <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-muted">
                    <div className="h-full w-[72%] rounded-full bg-amber-500" />
                  </div>
                  <div className="mt-2 flex gap-2">
                    <Button
                      size="xs"
                      onClick={() => {
                        // Re-using `id` here would keep the custom JSX (it sticks on update), so swap toasts.
                        toast.dismiss(id)
                        toast.success("PO-20931 raised for 240 units", { ...L, description: "Kopi O Kaw 500g · due Fri, 21 Nov" })
                      }}
                    >
                      Reorder 240
                    </Button>
                    <Button size="xs" variant="outline" onClick={() => toast.dismiss(id)}>
                      Snooze 1 day
                    </Button>
                  </div>
                </div>
              </div>
            </div>
          ),
          { ...L, duration: 10000 },
        )
      }
    >
      Stock alert card
    </Button>
  )
}

function SonnerUpdate() {
  async function sync() {
    const id = "stock-sync"
    toast.loading("Syncing stock levels…", { ...L, id, description: "0 of 5 warehouses" })
    for (const n of [1, 2, 3, 4]) {
      await wait(500)
      toast.loading("Syncing stock levels…", { ...L, id, description: `${n} of 5 warehouses` })
    }
    await wait(500)
    toast.error("Couldn't sync stock levels", {
      ...L,
      id,
      description: "4 of 5 synced. Kota Kinabalu Depot is offline.",
      duration: Infinity,
      action: { label: "Retry", onClick: () => toast.success("Kota Kinabalu Depot synced", L) },
    })
  }
  return (
    <div className="flex flex-wrap justify-center gap-2">
      <Button variant="outline" onClick={sync}>
        <RotateCcwIcon /> Sync 5 warehouses
      </Button>
      <Button
        variant="outline"
        onClick={() => {
          const lines = [
            "Order #4815 delivered",
            "Order #4817 packed",
            "Order #4819 shipped",
            "Order #4820 confirmed",
            "Order #4821 picking started",
          ]
          lines.forEach((msg, i) => setTimeout(() => toast(msg, L), i * 150))
        }}
      >
        Burst of 5
      </Button>
      <Button variant="ghost" onClick={() => toast.dismiss()}>
        Dismiss all
      </Button>
    </div>
  )
}

/* ------------------------------------------------------------------------------------------------
 * Base UI Toast
 * ---------------------------------------------------------------------------------------------- */

function BaseTypes() {
  const add = (type: string | undefined, title: string, description?: string) =>
    baseToasts.add({ type, title, description })
  return (
    <div className="flex flex-wrap justify-center gap-2">
      <Button variant="outline" onClick={() => add(undefined, "Order #4821 saved")}>
        Default
      </Button>
      <Button variant="outline" onClick={() => add("success", "Payment received from Jaya Grocer Bangsar")}>
        Success
      </Button>
      <Button
        variant="outline"
        onClick={() =>
          add("error", "Couldn't sync stock levels", "Johor Bahru DC didn't respond after 30 s. Figures may be up to 2 hours old.")
        }
      >
        Error + description
      </Button>
      <Button variant="outline" onClick={() => add("info", "Penang Hub closes early on Friday (Deepavali)")}>
        Info
      </Button>
      <Button variant="outline" onClick={() => add("warning", "Kopi O Kaw 500g is below reorder point")}>
        Warning
      </Button>
    </div>
  )
}

function BaseActions() {
  return (
    <div className="flex flex-wrap justify-center gap-2">
      <Button
        variant="outline"
        onClick={() =>
          baseToasts.add({
            title: "Order #4816 archived",
            description: "Penang Fresh Market · RM 640.80",
            actionProps: {
              children: "Undo",
              onClick: () => baseToasts.add({ type: "success", title: "Order #4816 restored" }),
            },
          })
        }
      >
        Archive with undo
      </Button>
      <Button
        variant="outline"
        onClick={() =>
          baseToasts.add({
            type: "warning",
            title: "Discard draft order #4822?",
            description: "12 lines for Borneo Mart Kuching haven't been submitted.",
            timeout: 0,
            priority: "high",
            actionProps: { children: "Discard", onClick: () => baseToasts.add({ title: "Draft #4822 discarded" }) },
          })
        }
      >
        Confirm (no auto-dismiss)
      </Button>
    </div>
  )
}

function BasePromise() {
  const [fail, setFail] = useState(false)
  return (
    <div className="flex flex-col items-center gap-3">
      <Button
        onClick={() =>
          baseToasts
            .promise(saveOrder(fail), {
              loading: { title: "Saving order #4821…", description: "Reserving stock at Shah Alam DC" },
              success: (o) => ({ title: `Order ${o.id} saved`, description: `${o.total} · Mydin Subang Jaya` }),
              error: (e: Error) => ({
                title: "Couldn't save order #4821",
                description: e.message,
                actionProps: {
                  children: "Retry",
                  onClick: () => baseToasts.add({ type: "success", title: "Order #4821 saved" }),
                },
              }),
            })
            // Unlike Sonner, the returned promise rejects: catch it or you get an unhandled rejection.
            .catch(() => {})
        }
      >
        Save order
      </Button>
      <Toggle label="Make the save fail" checked={fail} onCheckedChange={setFail} />
    </div>
  )
}

function BaseCustom() {
  async function sync() {
    const id = baseToasts.add({ type: "loading", title: "Syncing stock levels…", description: "0 of 5 warehouses", timeout: 0 })
    for (const n of [1, 2, 3, 4]) {
      await wait(500)
      baseToasts.update(id, { description: `${n} of 5 warehouses` })
    }
    await wait(500)
    baseToasts.update(id, {
      type: "error",
      title: "Couldn't sync stock levels",
      description: "4 of 5 synced. Kota Kinabalu Depot is offline.",
      actionProps: {
        children: "Retry",
        onClick: () => baseToasts.add({ type: "success", title: "Kota Kinabalu Depot synced" }),
      },
    })
  }
  return (
    <div className="flex flex-wrap justify-center gap-2">
      <Button
        variant="outline"
        onClick={() =>
          baseToasts.add({
            type: "warning",
            title: "Low stock: Kopi O Kaw 500g",
            timeout: 10000,
            data: { kind: "stock", sku: "BEV-KOK5", name: "Kopi O Kaw 500g", onHand: 86, reorderPoint: 120 },
          })
        }
      >
        <PackageIcon /> Stock alert (typed data)
      </Button>
      <Button variant="outline" onClick={sync}>
        <RotateCcwIcon /> Sync 5 warehouses
      </Button>
      <Button
        variant="outline"
        onClick={() =>
          ["Order #4815 delivered", "Order #4817 packed", "Order #4819 shipped", "Order #4820 confirmed", "Order #4821 picking started"].forEach(
            (title, i) => setTimeout(() => baseToasts.add({ title }), i * 150),
          )
        }
      >
        Burst of 5
      </Button>
      <Button variant="ghost" onClick={() => baseToasts.close()}>
        Dismiss all
      </Button>
    </div>
  )
}

/* ------------------------------------------------------------------------------------------------ */

export default function ToastsPage() {
  // Sonner <Toaster> options
  const [position, setPosition] = useState<Position>("bottom-right")
  const [expand, setExpand] = useState(false)
  const [richColors, setRichColors] = useState(false)
  const [closeButton, setCloseButton] = useState(false)
  const [visible, setVisible] = useState("3")
  const [duration, setDuration] = useState("4000")

  // Base UI options
  const [bPosition, setBPosition] = useState<BaseToastPosition>("top-right")
  const [bExpanded, setBExpanded] = useState(false)
  const [bRich, setBRich] = useState(false)
  const [bLimit, setBLimit] = useState("3")

  return (
    <Page
      title="Toasts"
      intro="Sonner is the Playbook's toast library and what shadcn/ui ships. Base UI has its own Toast primitive, so here are the same cases in both: types, descriptions, undo, a promise-driven save, custom content, updating in place and stacking."
      libs={[
        { name: "Sonner", status: "playbook", url: "https://sonner.emilkowal.ski", install: "npx shadcn add sonner" },
        { name: "Base UI Toast", status: "built-in", url: "https://base-ui.com/react/components/toast", install: "@base-ui/react/toast" },
      ]}
    >
      <Toaster
        id={LAB}
        position={position}
        expand={expand}
        richColors={richColors}
        closeButton={closeButton}
        visibleToasts={Number(visible)}
        duration={Number(duration)}
      />

      <Section
        title="Sonner: types, content and actions"
        description="These knobs are props on <Toaster>, so they apply to every Sonner toast on this page. Hover the stack to fan it out; swipe or drag a toast to dismiss; Alt+T jumps into the toast region."
      >
        <ControlBar>
          <Segmented label="Position" value={position} onChange={setPosition} options={positions} />
          <Toggle label="Expand" checked={expand} onCheckedChange={setExpand} />
          <Toggle label="Rich colors" checked={richColors} onCheckedChange={setRichColors} />
          <Toggle label="Close button" checked={closeButton} onCheckedChange={setCloseButton} />
          <Segmented
            label="Visible"
            value={visible}
            onChange={setVisible}
            options={[
              { value: "1", label: "1" },
              { value: "3", label: "3" },
              { value: "5", label: "5" },
            ]}
          />
          <Segmented
            label="Duration"
            value={duration}
            onChange={setDuration}
            options={[
              { value: "2000", label: "2 s" },
              { value: "4000", label: "4 s" },
              { value: "8000", label: "8 s" },
            ]}
          />
        </ControlBar>
        <Variant label="Types" lib="Sonner" hint={<code>toast(), toast.success/error/info/warning/loading()</code>}>
          <SonnerTypes />
        </Variant>
        <Variant label="With description" lib="Sonner" hint={<code>{"{ description }"}</code>}>
          <SonnerDescription />
        </Variant>
        <Variant
          label="Action & cancel"
          lib="Sonner"
          hint={
            <>
              <code>{"{ action: { label, onClick }, cancel }"}</code>. Use <code>duration: Infinity</code> when a decision is
              required.
            </>
          }
        >
          <SonnerActions />
        </Variant>
        <Variant
          label="Promise (simulated save)"
          lib="Sonner"
          hint={
            <>
              <code>toast.promise(p, {"{ loading, success, error }"})</code>. success/error can return a full toast (description,
              action).
            </>
          }
        >
          <SonnerPromise />
        </Variant>
      </Section>

      <Section
        title="Sonner: rich colors, custom JSX, updates"
        description="Things you reach for in ops screens: colour by severity, a richer card, and one toast that reports progress instead of five."
      >
        <Variant label="Rich colors (per toast)" lib="Sonner" hint={<code>{"{ richColors: true }"}</code>}>
          <SonnerRich />
        </Variant>
        <Variant
          label="Custom JSX"
          lib="Sonner"
          hint={
            <>
              <code>toast.custom(id =&gt; &lt;Card/&gt;)</code> renders unstyled: you own the whole card, but keep stacking, swipe
              and timers.
            </>
          }
        >
          <SonnerCustom />
        </Variant>
        <Variant
          label="Update in place, stacking"
          lib="Sonner"
          hint={
            <>
              Re-use an <code>id</code> to update a toast (loading → error with Retry). Burst shows the stack;{" "}
              <code>visibleToasts</code> caps it.
            </>
          }
          className="md:col-span-2"
        >
          <SonnerUpdate />
        </Variant>
      </Section>

      <BaseToastLab position={bPosition} alwaysExpanded={bExpanded} rich={bRich} limit={Number(bLimit)}>
        <Section
          title="Base UI Toast: the same cases"
          description="Base UI gives you a toast manager (add / update / close / promise), timers, swipe-to-dismiss, F6 focus, screen-reader announcements and stacking CSS variables. The card and the whole stack layout are your CSS (about 60 lines here)."
        >
          <ControlBar>
            <Segmented
              label="Position"
              value={bPosition}
              onChange={setBPosition}
              options={[
                { value: "top-center", label: "↑" },
                { value: "top-right", label: "↗" },
                { value: "bottom-center", label: "↓" },
                { value: "bottom-right", label: "↘" },
              ]}
            />
            <Toggle label="Always expanded" checked={bExpanded} onCheckedChange={setBExpanded} />
            <Toggle label="Tint by type" checked={bRich} onCheckedChange={setBRich} />
            <Segmented
              label="Limit"
              value={bLimit}
              onChange={setBLimit}
              options={[
                { value: "1", label: "1" },
                { value: "3", label: "3" },
                { value: "5", label: "5" },
              ]}
            />
          </ControlBar>
          <Variant
            label="Types & description"
            lib="Base UI"
            hint={
              <>
                <code>manager.add({"{ type, title, description }"})</code>. <code>type</code> is just a string you style via{" "}
                <code>data-type</code>.
              </>
            }
          >
            <BaseTypes />
          </Variant>
          <Variant
            label="Action / undo"
            lib="Base UI"
            hint={
              <>
                <code>{"actionProps: { children, onClick }"}</code> feeds a <code>&lt;Toast.Action/&gt;</code> you place. No
                built-in cancel; <code>timeout: 0</code> = sticky; <code>priority: "high"</code> = assertive.
              </>
            }
          >
            <BaseActions />
          </Variant>
          <Variant
            label="Promise (simulated save)"
            lib="Base UI"
            hint={
              <>
                <code>manager.promise(p, {"{ loading, success, error }"})</code>, same shape as Sonner, but the returned promise
                rejects.
              </>
            }
          >
            <BasePromise />
          </Variant>
          <Variant
            label="Custom data, update in place, stacking"
            lib="Base UI"
            hint={
              <>
                <code>data</code> is typed (<code>createToastManager&lt;StockAlert&gt;()</code>) and rendered by your own list.{" "}
                <code>update(id, …)</code> for progress.
              </>
            }
          >
            <BaseCustom />
          </Variant>
        </Section>
      </BaseToastLab>

      <Findings
        notes={[
          {
            tone: "good",
            text: "Sonner is done out of the box: one <Toaster/>, a global toast() you can call from anywhere (including non-React code like fetch wrappers), polished stacking, swipe, hover-to-expand and dark mode via shadcn's wrapper. Keep it as the default.",
          },
          {
            tone: "good",
            text: "Sonner's API covers every ops case we tried: severity types, description, action + cancel, promise with rich success/error, update by id (progress → final state), custom JSX, per-toast richColors.",
          },
          {
            tone: "note",
            text: (
              <>
                Multiple Sonner toasters work (<code>&lt;Toaster id&gt;</code> + <code>toasterId</code> on each toast); a toast
                without <code>toasterId</code> only goes to the toaster without an id. Handy for a scoped area like this page, but
                easy to get wrong.
              </>
            ),
          },
          {
            tone: "bad",
            text: (
              <>
                Sonner quirk: a <code>toast.custom()</code> card can't be turned into a normal toast by re-using its{" "}
                <code>id</code>; the custom JSX sticks and the success icon is drawn next to it. Dismiss it and fire a new toast
                instead (Base UI's <code>update(id, {"{ data: undefined }"})</code> handles this cleanly).
              </>
            ),
          },
          {
            tone: "note",
            text: "Base UI Toast is behaviour-only: you write the toast card and roughly 60 lines of stacking/position CSS (top vs bottom needs different transforms). In return you get full control, typed custom data, limit with graceful 'limited' state, and F6 to reach the region.",
          },
          {
            tone: "bad",
            text: (
              <>
                Base UI quirks: <code>manager.promise()</code> re-throws, so every call needs a <code>.catch</code>; there's no
                cancel button, no rich colors, no icons and no position prop; positions are pure CSS you maintain.
              </>
            ),
          },
          {
            tone: "note",
            text: "Recommendation: Sonner for every app (admin portals, the chat workspace). Consider Base UI Toast only for anchored toasts next to a control (it supports Toast.Positioner anchoring, Sonner doesn't) or when a design needs a layout Sonner can't do.",
          },
        ]}
      />
    </Page>
  )
}

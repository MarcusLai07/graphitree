// Every adapter the composer can place, grouped by file. Each file exports `adapters`.
import type { Adapter, LibraryId, SlotId } from "../types"
import { adapters as ai } from "./ai"
import { adapters as app } from "./app"
import { adapters as data } from "./data"
import { adapters as marketing } from "./marketing"
import { adapters as motion } from "./motion"

export const adapters: Adapter[] = [...app, ...data, ...motion, ...marketing, ...ai]

export const adapterById = Object.fromEntries(adapters.map((a) => [a.id, a])) as Record<string, Adapter>

if (Object.keys(adapterById).length !== adapters.length) {
  const seen = new Set<string>()
  const dupes = adapters.filter((a) => (seen.has(a.id) ? true : (seen.add(a.id), false))).map((a) => a.id)
  throw new Error(`Duplicate adapter ids: ${dupes.join(", ")}`)
}

export const adaptersFor = (slot: SlotId) => adapters.filter((a) => a.slot === slot)

export const adaptersOf = (library: LibraryId) => adapters.filter((a) => a.library === library)

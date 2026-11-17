// What the compatibility rules know about each library. Status, verdict and the suggested rule
// come from the catalog (the Verdicts page), so there's one place to change them.
import { catalog, type CatalogRow } from "@/playground/catalog"
import type { LibraryId, Traits } from "./types"

export type Library = {
  id: LibraryId
  url: string
  traits: Traits
  row: CatalogRow
}

const facts: Record<LibraryId, { url: string; traits: Traits }> = {
  shadcn: { url: "https://ui.shadcn.com", traits: { framework: "react", primitives: "base-ui" } },
  "base-ui": { url: "https://base-ui.com", traits: { framework: "react", primitives: "base-ui" } },
  radix: { url: "https://www.radix-ui.com/primitives", traits: { framework: "react", primitives: "radix" } },
  sonner: { url: "https://sonner.emilkowal.ski", traits: { framework: "react" } },
  // Vaul is built on Radix Dialog.
  vaul: { url: "https://vaul.emilkowal.ski", traits: { framework: "react", primitives: "radix" } },
  cmdk: { url: "https://cmdk.paco.me", traits: { framework: "react" } },
  numberflow: { url: "https://number-flow.barvian.me", traits: { framework: "react" } },
  magicui: { url: "https://magicui.design", traits: { framework: "react", needsMotion: true } },
  aceternity: {
    url: "https://ui.aceternity.com",
    traits: { framework: "react", needsMotion: true, pageKind: "marketing", ignoresReducedMotion: true, darkMode: "partial", effect: true },
  },
  "beautiful-ui": { url: "https://beautifului.dev", traits: { framework: "react" } },
  "21st": { url: "https://21st.dev", traits: { framework: "react" } },
  rareui: { url: "https://github.com/Codewithswappy/ShitUI", traits: { framework: "react", needsMotion: true, pageKind: "marketing" } },
  "shadcn-charts": { url: "https://ui.shadcn.com/charts", traits: { framework: "react" } },
  "animate-ui": { url: "https://animate-ui.com", traits: { framework: "react", needsMotion: true } },
  // Written for Radix: its animations don't fire on Base UI.
  "ai-elements": { url: "https://ai-sdk.dev/elements", traits: { framework: "react", primitives: "radix" } },
}

export const libraries = Object.fromEntries(
  (Object.keys(facts) as LibraryId[]).map((id) => {
    const row = catalog.find((r) => r.id === id)
    if (!row) throw new Error(`No catalog row for library ${id}`)
    return [id, { id, ...facts[id], row }]
  }),
) as Record<LibraryId, Library>

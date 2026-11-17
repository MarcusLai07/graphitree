/** What 21st.dev gave us without an account, recorded on 2026-11-16. */
import { ExternalLinkIcon, LockIcon } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { cn } from "@/lib/utils"

export function CliTranscript() {
  return (
    <pre className="w-full overflow-x-auto rounded-lg bg-zinc-950 p-4 font-mono text-[11.5px] leading-relaxed text-zinc-300 ring-1 ring-white/10">
      <span className="text-zinc-500">$ </span>
      npx shadcn@latest add "https://21st.dev/r/designali-in/liquid-glass-button" -y{"\n"}
      <span className="text-red-400">Something went wrong. Please check the error below for more details.</span>
      {"\n"}Error:{"\n"}
      You are not authorized to access the item at{"\n"}https://21st.dev/r/designali-in/liquid-glass-button.{"\n"}
      If this is a remote registry, you may need to authenticate.{"\n\n"}
      <span className="text-zinc-500">$ </span>curl -s https://21st.dev/r/shadcn/button{"\n"}
      {`{"error":"Authentication required","reason":"authentication_required", …}`}
    </pre>
  )
}

type Pick = {
  kind: string
  name: string
  author: string
  /** popularity count shown on the card */
  copies: string
  deps: string[]
  licence: string
  source?: { label: string; href: string }
  verdict: { tone: "good" | "bad" | "note"; text: string }
  href: string
}

const PICKS: Pick[] = [
  {
    kind: "Hero",
    name: "Scroll media expansion hero",
    author: "arunachalam",
    copies: "11.1K",
    deps: ["next", "framer-motion"],
    licence: "MIT (listed)",
    verdict: { tone: "bad", text: "Lists next as a dependency, so expect Next.js-only imports. It won't drop into Vite." },
    href: "https://21st.dev/@arunachalam/components/scroll-expansion-hero",
  },
  {
    kind: "Pricing",
    name: "Pricing",
    author: "Codehagen (Prism UI)",
    copies: "4K",
    deps: ["framer-motion", "canvas-confetti", "@number-flow/react", "lucide-react"],
    licence: "MIT (listed)",
    source: { label: "upstream repo is AGPL-3.0", href: "https://github.com/Codehagen/Prismui" },
    verdict: { tone: "bad", text: "Licence on 21st.dev doesn't match the upstream repo. Don't copy it." },
    href: "https://21st.dev/@Codehagen/components/pricing",
  },
  {
    kind: "Animated button",
    name: "Liquid Glass Button",
    author: "designali-in",
    copies: "7K",
    deps: ["@radix-ui/react-slot", "class-variance-authority"],
    licence: "none listed",
    verdict: { tone: "bad", text: "No licence, no public source, and it uses Radix Slot (asChild) where we use Base UI's render" },
    href: "https://21st.dev/@designali-in/components/liquid-glass-button",
  },
  {
    kind: "Stat cards",
    name: "Stats cards with links",
    author: "ephraimduncan (blocks.so)",
    copies: "95",
    deps: ["clsx", "tailwind-merge"],
    licence: "none listed",
    source: { label: "upstream blocks.so is MIT, open registry", href: "https://github.com/ephraimduncan/blocks" },
    verdict: { tone: "good", text: "Installed from blocks.so's own registry instead; see below" },
    href: "https://21st.dev/@ephraimduncan/components/stats-cards-with-links",
  },
]

const toneClass = {
  good: "text-emerald-700 dark:text-emerald-400",
  bad: "text-rose-700 dark:text-rose-400",
  note: "text-muted-foreground",
}

export function PicksTable() {
  return (
    <div className="w-full overflow-x-auto">
      <table className="w-full text-left text-xs">
        <thead className="text-muted-foreground">
          <tr className="border-b">
            <th className="py-2 pr-3 font-medium">Pick</th>
            <th className="py-2 pr-3 font-medium">Dependencies (from the page)</th>
            <th className="py-2 font-medium">Licence and verdict</th>
          </tr>
        </thead>
        <tbody>
          {PICKS.map((p) => (
            <tr key={p.name} className="border-b align-top last:border-0">
              <td className="py-2.5 pr-3">
                <div className="text-[11px] text-muted-foreground">{p.kind}</div>
                <a href={p.href} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 font-medium hover:underline">
                  {p.name}
                  <ExternalLinkIcon className="size-3 text-muted-foreground" />
                </a>
                <div className="text-muted-foreground">
                  @{p.author} · {p.copies}
                </div>
              </td>
              <td className="py-2.5 pr-3">
                <div className="flex flex-wrap gap-1">
                  {p.deps.map((d) => (
                    <Badge key={d} variant="outline" className={cn("font-mono font-normal", (d === "next" || d.startsWith("@radix-ui")) && "border-rose-500/40 text-rose-700 dark:text-rose-300")}>
                      {d}
                    </Badge>
                  ))}
                </div>
              </td>
              <td className="py-2.5">
                <div className="flex items-center gap-1.5">
                  <LockIcon className="size-3 text-muted-foreground" aria-label="Source needs an account" />
                  <span>{p.licence}</span>
                </div>
                {p.source && (
                  <a href={p.source.href} target="_blank" rel="noreferrer" className="text-muted-foreground underline-offset-2 hover:underline">
                    {p.source.label}
                  </a>
                )}
                <div className={cn("mt-1", toneClass[p.verdict.tone])}>{p.verdict.text}</div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

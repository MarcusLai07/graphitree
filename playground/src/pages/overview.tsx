import { catalog as rows } from "@/playground/catalog"
import { Rich, verdictClass, verdictLabel } from "@/playground/verdicts"
import { Findings, Page, StatusBadge } from "@/playground/kit"

export default function OverviewPage() {
  return (
    <Page
      title="Verdicts"
      intro="Every library in Graphitree's Playbook, plus a few candidates, and what trying them in the composer suggested. These are suggestions, not decisions yet. Try opens a library in the composer; Notes has its side-by-side variants and findings."
      libs={[]}
    >
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full text-sm">
          <thead className="bg-muted/50 text-left text-xs uppercase tracking-wide text-muted-foreground">
            <tr>
              <th className="px-4 py-3 font-medium">Library</th>
              <th className="px-4 py-3 font-medium">Job</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Used in your repos</th>
              <th className="px-4 py-3 font-medium">Verdict</th>
              <th className="px-4 py-3 font-medium">Suggested rule</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.name} className="border-t align-top">
                <td className="px-4 py-3">
                  <div className="font-medium">{row.name}</div>
                  {row.page && (
                    <div className="mt-1 flex gap-3 text-xs">
                      <a href={`#/try/${row.id}`} className="text-primary hover:underline">
                        Try
                      </a>
                      <a href={`#/${row.page}`} className="text-muted-foreground hover:underline">
                        Notes
                      </a>
                    </div>
                  )}
                </td>
                <td className="px-4 py-3 text-muted-foreground">{row.job}</td>
                <td className="px-4 py-3">
                  <StatusBadge status={row.status} />
                </td>
                <td className="px-4 py-3 text-muted-foreground">{row.usedIn}</td>
                <td className={`px-4 py-3 font-medium whitespace-nowrap ${verdictClass[row.verdict]}`}>{verdictLabel[row.verdict]}</td>
                <td className="px-4 py-3 text-muted-foreground">
                  <Rich text={row.why} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <Findings
        title="Found while setting up"
        notes={[
          { tone: "good", text: "shadcn's Drawer in the Base UI styles is built on Base UI's own Drawer, not Vaul. Base UI may already be Vaul's replacement — compare them on the Drawers page." },
          { tone: "note", text: <>shadcn now installs its own <code className="text-xs">cn</code> package (a faster clsx + tailwind-merge). <code className="text-xs">@/lib/utils</code> just re-exports it.</> },
          { tone: "bad", text: "Animate UI's Base UI components (tabs, switch, accordion) wouldn't install: they ask for a Base UI version that isn't on npm." },
          { tone: "bad", text: <>In a Base UI project, the shadcn CLI rewrites <code className="text-xs">asChild</code> to <code className="text-xs">render</code> in third-party code. That broke Animate UI's avatar group, which uses its own Radix-style tooltip. It needed a hand fix.</> },
          { tone: "bad", text: <>Aceternity's moving border didn't pass React 19's types (<code className="text-xs">useRef()</code> with no argument). Aceternity and Animate UI code also fails a strict tsconfig (unused imports, non-type imports), so the lab relaxes those flags.</> },
        ]}
      />
    </Page>
  )
}

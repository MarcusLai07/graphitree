import { useEffect, useState } from "react"
import { ChevronDownIcon, FlaskConicalIcon, MoonIcon, SunIcon } from "lucide-react"
import { useTheme } from "next-themes"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { cn } from "@/lib/utils"
import Composer from "@/compose/Composer"
import { pages, type PageEntry } from "@/pages"

/**
 * Routes, all in the hash so the lab works from a file URL:
 * #/compose (or nothing) is the composer, #/try/<library> opens a library in it,
 * #/overview is the Verdicts table, and #/<page> is a library's notes page.
 */
type Route = { kind: "compose"; library?: string; request?: number } | { kind: "page"; page: PageEntry }

let requests = 0

function readRoute(): Route {
  const path = window.location.hash.replace(/^#\/?/, "")
  if (path.startsWith("try/")) return { kind: "compose", library: path.slice(4), request: ++requests }
  const page = pages.find((p) => p.id === path)
  return page ? { kind: "page", page } : { kind: "compose" }
}

function useRoute(): Route {
  const [route, setRoute] = useState(readRoute)
  useEffect(() => {
    const onChange = () => {
      const next = readRoute()
      // The composer steps #/try/x back to #/compose itself; don't drop the request it handled.
      setRoute((current) => (next.kind === "compose" && !next.library && current.kind === "compose" ? current : next))
      document.getElementById("stage")?.scrollTo({ top: 0 })
    }
    window.addEventListener("hashchange", onChange)
    return () => window.removeEventListener("hashchange", onChange)
  }, [])
  return route
}

function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme()
  const dark = resolvedTheme === "dark"
  return (
    <Button variant="ghost" size="icon-sm" onClick={() => setTheme(dark ? "light" : "dark")} aria-label="Toggle dark mode">
      {dark ? <SunIcon /> : <MoonIcon />}
    </Button>
  )
}

const tab = (active: boolean) =>
  cn(
    "flex h-7 items-center gap-1 rounded-md px-2.5 text-sm outline-none focus-visible:ring-3 focus-visible:ring-ring/50",
    active ? "bg-sidebar-accent font-medium" : "text-muted-foreground hover:text-foreground",
  )

const notes = pages.filter((p) => p.id !== "overview")
const noteGroups = [...new Set(notes.map((p) => p.group))]

export default function App() {
  const route = useRoute()
  const onNotes = route.kind === "page" && route.page.id !== "overview"

  return (
    <div className="flex h-svh flex-col bg-background text-foreground">
      <header className="flex h-12 shrink-0 items-center gap-4 border-b bg-sidebar px-4">
        <div className="flex items-center gap-2 text-sm font-semibold">
          <FlaskConicalIcon className="size-4" aria-hidden />
          Playbook lab
        </div>
        <nav className="flex items-center gap-1" aria-label="Lab">
          <a href="#/compose" className={tab(route.kind === "compose")}>
            Compose
          </a>
          <a href="#/overview" className={tab(route.kind === "page" && route.page.id === "overview")}>
            Verdicts
          </a>
          <DropdownMenu>
            <DropdownMenuTrigger className={tab(onNotes)}>
              {onNotes ? `Notes: ${route.page.title}` : "Notes"}
              <ChevronDownIcon className="size-3.5" aria-hidden />
            </DropdownMenuTrigger>
            <DropdownMenuContent className="w-64">
              {noteGroups.map((group) => (
                <DropdownMenuGroup key={group}>
                  <DropdownMenuLabel>{group}</DropdownMenuLabel>
                  {notes
                    .filter((p) => p.group === group)
                    .map((p) => (
                      <DropdownMenuItem key={p.id} onClick={() => (window.location.hash = `#/${p.id}`)}>
                        <span className="flex flex-col">
                          {p.title}
                          <span className="text-xs text-muted-foreground">{p.job}</span>
                        </span>
                      </DropdownMenuItem>
                    ))}
                </DropdownMenuGroup>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        </nav>
        <div className="ml-auto flex items-center gap-2">
          <Tooltip>
            <TooltipTrigger className="rounded-full border px-2.5 py-0.5 text-xs text-muted-foreground">React · web</TooltipTrigger>
            <TooltipContent>This canvas renders React. In Graphitree, the lab window's toolbar switches to the SwiftUI canvas.</TooltipContent>
          </Tooltip>
          <ThemeToggle />
        </div>
      </header>
      <main className="min-h-0 flex-1">
        {route.kind === "compose" ? (
          <Composer tryLibrary={route.library} tryRequest={route.request} />
        ) : (
          <div id="stage" className="h-full overflow-y-auto">
            <route.page.component key={route.page.id} />
          </div>
        )}
      </main>
    </div>
  )
}

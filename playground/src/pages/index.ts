import type { ComponentType } from "react"
import AIPage from "./ai"
import ChartsPage from "./charts"
import CommandPage from "./command"
import CommunityPage from "./community"
import DrawersPage from "./drawers"
import LandingPage from "./landing"
import MotionPage from "./motion"
import NumbersPage from "./numbers"
import OverviewPage from "./overview"
import PrimitivesPage from "./primitives"
import ToastsPage from "./toasts"

export type PageEntry = {
  id: string
  title: string
  /** The job, as the Playbook names it. */
  job: string
  group: "Start" | "App components" | "Motion & marketing" | "Candidates"
  component: ComponentType
}

export const pages: PageEntry[] = [
  { id: "overview", title: "Verdicts", job: "All libraries", group: "Start", component: OverviewPage },
  { id: "primitives", title: "Base UI vs Radix", job: "Headless UI primitives", group: "App components", component: PrimitivesPage },
  { id: "toasts", title: "Toasts", job: "Toasts", group: "App components", component: ToastsPage },
  { id: "command", title: "Command menu & pickers", job: "Command menu", group: "App components", component: CommandPage },
  { id: "drawers", title: "Drawers & sheets", job: "Drawers", group: "App components", component: DrawersPage },
  { id: "numbers", title: "Animated numbers", job: "Animated numbers", group: "Motion & marketing", component: NumbersPage },
  { id: "motion", title: "Animated components", job: "Animated UI components", group: "Motion & marketing", component: MotionPage },
  { id: "landing", title: "Landing page effects", job: "Landing page components", group: "Motion & marketing", component: LandingPage },
  { id: "ai", title: "AI interface", job: "AI interface components", group: "Motion & marketing", component: AIPage },
  { id: "community", title: "21st.dev & RareUI", job: "UI components registry", group: "Motion & marketing", component: CommunityPage },
  { id: "charts", title: "Charts", job: "Charts (not in playbook)", group: "Candidates", component: ChartsPage },
]

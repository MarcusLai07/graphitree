import type { LucideIcon } from "lucide-react"
import {
  BellIcon,
  BotIcon,
  ChartColumnIcon,
  CommandIcon,
  CreditCardIcon,
  HashIcon,
  ListIcon,
  MessagesSquareIcon,
  MousePointerClickIcon,
  NavigationIcon,
  PanelRightIcon,
  PanelsTopLeftIcon,
  SparklesIcon,
  TypeIcon,
  UsersIcon,
} from "lucide-react"
import type { SlotId } from "./types"

export type SlotGroup = "App" | "Data" | "Motion" | "Marketing" | "AI"

export type Slot = {
  id: SlotId
  name: string
  group: SlotGroup
  icon: LucideIcon
  /** What a block of this kind shows on the canvas. */
  hint: string
}

export const slots: Slot[] = [
  { id: "button", name: "Button", group: "App", icon: MousePointerClickIcon, hint: "A call to action" },
  { id: "toast", name: "Toast", group: "App", icon: BellIcon, hint: "A button that raises a toast" },
  { id: "drawer", name: "Drawer", group: "App", icon: PanelRightIcon, hint: "A panel that slides in" },
  { id: "picker", name: "Command menu", group: "App", icon: CommandIcon, hint: "Search and pick" },
  { id: "tabs", name: "Tabs", group: "App", icon: PanelsTopLeftIcon, hint: "Switch between views" },
  { id: "number", name: "KPI number", group: "Data", icon: HashIcon, hint: "A number that changes" },
  { id: "chart", name: "Chart", group: "Data", icon: ChartColumnIcon, hint: "Sales by month" },
  { id: "feed", name: "Activity feed", group: "Data", icon: ListIcon, hint: "Events arriving" },
  { id: "card", name: "Card effect", group: "Motion", icon: CreditCardIcon, hint: "A card that reacts" },
  { id: "text", name: "Text effect", group: "Motion", icon: TypeIcon, hint: "A headline that animates" },
  { id: "avatars", name: "Avatar group", group: "Motion", icon: UsersIcon, hint: "Who's on it" },
  { id: "hero", name: "Hero", group: "Marketing", icon: SparklesIcon, hint: "A page's opening section" },
  { id: "nav", name: "Navigation", group: "Marketing", icon: NavigationIcon, hint: "Site or app nav" },
  { id: "chat", name: "Chat message", group: "AI", icon: MessagesSquareIcon, hint: "An answer streaming in" },
  { id: "agent", name: "Agent step", group: "AI", icon: BotIcon, hint: "Thinking, tools, approval" },
]

export const slotById = Object.fromEntries(slots.map((s) => [s.id, s])) as Record<SlotId, Slot>

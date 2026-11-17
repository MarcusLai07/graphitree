/**
 * RareUI's AnimatedTabs, plus what we'd need to change before shipping it.
 * The look and the spring are unchanged. The fixes:
 * - layoutId is scoped with useId, so two instances on one page don't share
 *   a single "active-pill" (upstream hard-codes the id)
 * - role="tablist"/"tab", aria-selected and roving tabindex with arrow keys
 * - a visible focus ring (upstream sets outline-none and nothing else)
 * - inactive text in dark mode zinc-500 → zinc-400 (zinc-500 on the dark
 *   glass is under 4.5:1)
 */
import { useId, useRef, useState, type KeyboardEvent } from "react"
import { motion } from "motion/react"
import { cn } from "@/lib/utils"
import type { Tab } from "./animated-tabs"

export function AnimatedTabsPatched({
  tabs,
  activeTab,
  onChange,
  className,
  label,
}: {
  tabs: Tab[]
  activeTab: string
  onChange: (id: string) => void
  className?: string
  label: string
}) {
  const scope = useId()
  const [hoveredTab, setHoveredTab] = useState<string | null>(null)
  const refs = useRef<(HTMLButtonElement | null)[]>([])

  const onKeyDown = (e: KeyboardEvent, index: number) => {
    const delta = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0
    if (!delta) return
    e.preventDefault()
    const next = (index + delta + tabs.length) % tabs.length
    onChange(tabs[next].id)
    refs.current[next]?.focus()
  }

  return (
    <div
      role="tablist"
      aria-label={label}
      className={cn(
        "flex max-w-full flex-row flex-nowrap items-center justify-center gap-1 rounded-full p-1 sm:gap-0 sm:p-1.5",
        "border border-black/5 bg-white/60 shadow-2xl backdrop-blur-xl dark:border-white/10 dark:bg-zinc-900/60",
        className,
      )}
    >
      {tabs.map((tab, index) => {
        const isActive = activeTab === tab.id
        const isHovered = hoveredTab === tab.id
        return (
          <motion.button
            key={tab.id}
            ref={(el) => {
              refs.current[index] = el
            }}
            type="button"
            role="tab"
            aria-selected={isActive}
            tabIndex={isActive ? 0 : -1}
            onKeyDown={(e) => onKeyDown(e, index)}
            onClick={() => {
              onChange(tab.id)
              setHoveredTab(null)
            }}
            onMouseEnter={() => setHoveredTab(tab.id)}
            onMouseLeave={() => setHoveredTab(null)}
            whileTap={{ scale: 0.95 }}
            className={cn(
              "relative z-10 cursor-pointer rounded-full px-3 py-2 text-xs font-semibold whitespace-nowrap transition-colors duration-200 outline-none sm:px-4 sm:py-2.5 sm:text-sm md:px-6",
              "focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background",
              isActive ? "text-white dark:text-black" : "text-zinc-600 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-200",
            )}
          >
            {isActive && (
              <motion.div
                layoutId={`${scope}-active`}
                className="absolute inset-0 z-[-1] rounded-full bg-black shadow-xl dark:bg-white dark:shadow-[0_0_20px_rgba(255,255,255,0.3)]"
                transition={{ type: "spring", stiffness: 320, damping: 32, mass: 0.9 }}
              />
            )}
            {isHovered && !isActive && (
              <motion.div
                layoutId={`${scope}-hover`}
                className="absolute inset-0 z-[-1] rounded-full bg-black/5 dark:bg-white/5"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.15 }}
              />
            )}
            <span className="relative z-10">{tab.label}</span>
          </motion.button>
        )
      })}
    </div>
  )
}

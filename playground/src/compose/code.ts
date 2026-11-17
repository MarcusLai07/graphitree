import { adapterById } from "./adapters"
import { libraries } from "./libraries"
import { slotById } from "./slots"
import type { Block } from "./types"

/** Install commands for the whole canvas, in order, each once. */
export function installsFor(blocks: Block[]): string[] {
  const seen = new Set<string>()
  for (const block of blocks) for (const command of adapterById[block.adapter]?.install ?? []) seen.add(command)
  return [...seen]
}

/** Everything needed to rebuild the canvas: install commands, then each block's code. */
export function canvasCode(blocks: Block[]): string {
  const parts = blocks.flatMap((block) => {
    const adapter = adapterById[block.adapter]
    if (!adapter) return []
    return [`// ${slotById[block.slot].name}: ${adapter.label} (${libraries[adapter.library].row.name})\n${adapter.code(block.options)}`]
  })
  const install = installsFor(blocks)
  return [install.length ? `# Install\n${install.join("\n")}` : "", ...parts].filter(Boolean).join("\n\n")
}

/** Copies text, falling back to a hidden textarea where the async clipboard isn't allowed. */
export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text)
    return true
  } catch {
    const area = document.createElement("textarea")
    area.value = text
    area.style.position = "fixed"
    area.style.opacity = "0"
    document.body.appendChild(area)
    area.select()
    const ok = document.execCommand("copy")
    area.remove()
    return ok
  }
}

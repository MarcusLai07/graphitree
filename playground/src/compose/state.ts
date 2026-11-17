// The composer's state: the blocks on the canvas, the canvas settings and the selection. It is
// saved in localStorage so reopening the lab brings the canvas back.
import { useEffect, useReducer } from "react"
import { adapterById } from "./adapters"
import { defaultOptions } from "./rules"
import type { Adapter, Block, OptionValues, Settings } from "./types"

export type ComposerState = {
  blocks: Block[]
  settings: Settings
  selected: string | null
}

export const defaultSettings: Settings = {
  framework: "react",
  pageKind: "app",
  primitives: "base-ui",
  motion: true,
  entrance: "rise",
  reduceMotion: false,
}

export type Action =
  | { type: "add"; block: Block; after?: string | null }
  | { type: "remove"; key: string }
  | { type: "move"; key: string; by: -1 | 1 }
  | { type: "duplicate"; key: string; newKey: string }
  | { type: "adapter"; key: string; adapter: string }
  | { type: "option"; key: string; id: string; value: string | boolean }
  | { type: "settings"; settings: Partial<Settings> }
  | { type: "select"; key: string | null }
  | { type: "load"; state: ComposerState }

/**
 * Options for a block switching to another library. Adapters in one slot share option ids where
 * they mean the same thing (format, size, position…), so values that fit the new adapter stay.
 */
function carryOver(adapter: Adapter, previous: OptionValues): OptionValues {
  const options = defaultOptions(adapter)
  for (const option of adapter.options ?? []) {
    const value = previous[option.id]
    if (value === undefined || typeof value !== typeof option.default) continue
    if (option.type === "select" && !option.choices.some((c) => c.value === value)) continue
    options[option.id] = value
  }
  return options
}

function reducer(state: ComposerState, action: Action): ComposerState {
  const { blocks } = state
  switch (action.type) {
    case "add": {
      const after = action.after ? blocks.findIndex((b) => b.key === action.after) : -1
      const at = after >= 0 ? after + 1 : blocks.length
      const next = [...blocks.slice(0, at), action.block, ...blocks.slice(at)]
      return { ...state, blocks: next, selected: action.block.key }
    }
    case "remove": {
      const next = blocks.filter((b) => b.key !== action.key)
      return { ...state, blocks: next, selected: state.selected === action.key ? null : state.selected }
    }
    case "move": {
      const i = blocks.findIndex((b) => b.key === action.key)
      const j = i + action.by
      if (i < 0 || j < 0 || j >= blocks.length) return state
      const next = [...blocks]
      ;[next[i], next[j]] = [next[j], next[i]]
      return { ...state, blocks: next }
    }
    case "duplicate": {
      const i = blocks.findIndex((b) => b.key === action.key)
      if (i < 0) return state
      const copy = { ...blocks[i], key: action.newKey, options: { ...blocks[i].options } }
      return { ...state, blocks: [...blocks.slice(0, i + 1), copy, ...blocks.slice(i + 1)], selected: copy.key }
    }
    case "adapter": {
      const adapter = adapterById[action.adapter]
      if (!adapter) return state
      return {
        ...state,
        blocks: blocks.map((b) => (b.key === action.key ? { ...b, adapter: adapter.id, options: carryOver(adapter, b.options) } : b)),
      }
    }
    case "option":
      return {
        ...state,
        blocks: blocks.map((b) => (b.key === action.key ? { ...b, options: { ...b.options, [action.id]: action.value } } : b)),
      }
    case "settings":
      return { ...state, settings: { ...state.settings, ...action.settings } }
    case "select":
      return { ...state, selected: action.key }
    case "load":
      return action.state
  }
}

const STORAGE_KEY = "playbook-lab.composer.v1"

/** Drops blocks whose adapter no longer exists, and fills options added since they were saved. */
function restore(): ComposerState {
  const empty: ComposerState = { blocks: [], settings: defaultSettings, selected: null }
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "null") as Partial<ComposerState> | null
    if (!saved || !Array.isArray(saved.blocks)) return empty
    const blocks = saved.blocks
      .filter((b) => adapterById[b.adapter])
      .map((b) => ({ ...b, options: { ...defaultOptions(adapterById[b.adapter]), ...b.options } }))
    return { blocks, settings: { ...defaultSettings, ...saved.settings, framework: "react" }, selected: null }
  } catch {
    return empty
  }
}

export function useComposer() {
  const [state, dispatch] = useReducer(reducer, undefined, restore)
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ blocks: state.blocks, settings: state.settings }))
    } catch {
      // Storage can be unavailable for file URLs; the canvas just won't survive a reload.
    }
  }, [state.blocks, state.settings])
  return [state, dispatch] as const
}

/** Token and source shapes for StreamingAnswer, kept apart so the .tsx files only export components. */
export type StreamingToken = { text: string; cite?: boolean; source?: number }
export type StreamingSource = { name: string; domain: string; href: string; image?: string; tone?: string }

/** Split a sentence into word tokens. */
export const words = (text: string): StreamingToken[] => text.split(" ").map((t) => ({ text: t }))

# Playbook lab

A composer for trying the UI libraries in Graphitree's Playbook (and a few candidates) before deciding what goes on the list. It starts empty:

- Add components, pick which library draws each one, and turn on extras like Motion entrances or reduced motion.
- Choices that don't fit the canvas, or that break a Playbook rule, say why.

```bash
npm install
npm run dev         # http://localhost:5199
npm run build:app   # rebuilds the copy in Graphitree's Lab window (../App/Resources)
```

Vite + React 19 + Tailwind v4 + shadcn/ui (base-nova style, Base UI primitives). Third-party components come from the registries in `components.json` (Magic UI, Aceternity UI, Animate UI) or were copied by hand into `src/demos/` (Beautiful UI, RareUI).

- `src/compose/` — the composer.
  - `types.ts` — the model: a canvas of blocks; each block is a slot (toast, drawer…) drawn by an adapter (one library's take on it).
  - `adapters/` — the adapters, one file per slot group. Each has options, traits, install commands and code.
  - `libraries.ts` — each library's traits: framework, the primitives it's built on, whether it needs Motion, whether it's marketing-only, reduced-motion and dark-mode behaviour.
  - `rules.ts` — turns traits plus the canvas settings into "can't run here" and "against the Playbook" notes.
- `src/playground/catalog.ts` — every library, its status, and the suggested verdict.
  - The Verdicts page and the composer read it.
  - `build:app` turns it into `lab-manifest.json`, so Playbook cards can open a library in the composer (`#/try/<id>`).
- `src/pages/` — the Verdicts table and the older side-by-side notes pages, one per job.
- `tsconfig.app.json` turns off `noUnusedLocals`, `noUnusedParameters` and `verbatimModuleSyntax`, because registry code from Aceternity and Animate UI doesn't pass them.

To add a library: add its row to `catalog.ts` with an `id`, its traits to `libraries.ts`, and at least one adapter in `src/compose/adapters/`.

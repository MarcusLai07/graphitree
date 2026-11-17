// Builds the lab for Graphitree's Lab window: one classic script and one stylesheet, no
// module scripts and no network, so it loads from the app bundle the way graph.html does.
// `npm run build:app` builds into dist-app/ and copies the files into ../App/Resources.
import path from "node:path"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig, type Plugin } from "vite"
import { aliases, catalog } from "./src/playground/catalog.ts"

/**
 * lab-manifest.json: the libraries the composer can place and the route that opens each one,
 * so Playbook cards can offer Try It. Tests/LabChecks.swift checks each id has an adapter.
 */
function labManifest(): Plugin {
  return {
    name: "lab-manifest",
    generateBundle() {
      const libraries = catalog
        .filter((row) => row.id)
        .map((row) => ({ name: row.name, aliases: aliases[row.name] ?? [], route: `try/${row.id}`, job: row.job }))
      this.emitFile({ type: "asset", fileName: "lab-manifest.json", source: JSON.stringify({ libraries }, null, 2) + "\n" })
    },
  }
}

export default defineConfig({
  plugins: [react(), tailwindcss(), labManifest()],
  resolve: { alias: { "@": path.resolve(import.meta.dirname, "./src") } },
  // Library mode leaves process.env alone; React needs it replaced.
  define: { "process.env.NODE_ENV": JSON.stringify("production") },
  build: {
    outDir: "dist-app",
    emptyOutDir: true,
    copyPublicDir: false,
    lib: {
      entry: path.resolve(import.meta.dirname, "src/main.tsx"),
      formats: ["iife"],
      name: "PlaybookLab",
      fileName: () => "lab.bundle.js",
      cssFileName: "lab",
    },
  },
})

import Foundation

// Checks for the Playbook lab: the manifest the lab build writes into App/Resources, how a
// Playbook card's name finds its route into the composer, and that every library it names has
// something the composer can place.
// Called from main.swift; Scripts/test.sh runs from the repo root.

func labChecks() throws {
    let resources = URL(fileURLWithPath: "App/Resources")
    let manifest = try Data(contentsOf: resources.appendingPathComponent("lab-manifest.json"))
    let catalog = try LabCatalog(data: manifest)
    check(!catalog.entries.isEmpty, "the bundled lab manifest lists libraries")

    expectEqual(catalog.route(for: "Sonner"), "try/sonner", "a library finds its composer route by name")
    expectEqual(catalog.route(for: "shadcn ui"), "try/shadcn", "matching ignores case and punctuation")
    expectEqual(catalog.route(for: "Radix UI"), "try/radix", "an alias finds the route")
    expectEqual(catalog.route(for: "ShitUI"), "try/rareui", "RareUI's new name finds its route")
    expectEqual(catalog.route(for: "pick-ui-library skill"), nil, "a library with nothing to render has no route")
    expectEqual(catalog.route(for: "Left Pad"), nil, "a library the lab doesn't cover has no route")
    expectEqual(catalog.route(for: "  "), nil, "a blank name has no route")

    // A library with no adapter would open an empty canvas. Adapters name their library as
    // `library:"<id>"`, and the minifier may quote with ", ' or `.
    let bundle = try String(contentsOf: resources.appendingPathComponent("lab.bundle.js"), encoding: .utf8)
    let ids = catalog.entries.compactMap { entry in entry.route.hasPrefix("try/") ? String(entry.route.dropFirst(4)) : nil }
    expectEqual(ids.count, catalog.entries.count, "every manifest route opens the composer")
    let missing = ids.filter { id in
        !["\"", "'", "`"].contains { quote in bundle.contains("library:\(quote)\(id)\(quote)") }
    }.sorted()
    expectEqual(missing, [], "every library in the manifest has an adapter in lab.bundle.js")

    let html = try String(contentsOf: resources.appendingPathComponent("lab.html"), encoding: .utf8)
    check(html.contains("src=\"lab.bundle.js\"") && !html.contains("type=\"module\""), "lab.html loads the bundle as a classic script, which works from a file URL")
    check(html.contains("default-src 'none'"), "lab.html allows no network access")

    expectEqual(LabCatalog.safeRoute("try/sonner"), "try/sonner", "a plain route passes through")
    expectEqual(LabCatalog.safeRoute("toasts"), "toasts", "a notes page id passes through")
    expectEqual(LabCatalog.safeRoute("x'; alert(1); '"), "xalert1", "quotes and code are dropped from a route")
    expectEqual(LabCatalog.safeRoute("try/ünï"), "try/n", "only ASCII letters reach the script")
}

import Foundation

// Finding the owner's pick for a job. Graph search matches names, so "toast" never finds Sonner;
// this matches jobs and their everyday synonyms against the playbook instead. The command line
// and the MCP server both answer with it.

struct PickMatch: Equatable, Sendable {
    let library: PlaybookLibrary
    let score: Int
}

enum PlaybookPicks {
    /// Words people use for the same job. A query naming any of them finds libraries described by any other.
    static let synonyms: [[String]] = [
        ["toast", "toasts", "notification", "notifications", "snackbar", "snackbars", "flash message", "alert"],
        ["drawer", "drawers", "sheet", "bottom sheet", "side panel", "slide over", "slide-over"],
        ["command menu", "command palette", "cmdk", "spotlight", "kbar", "quick open", "launcher"],
        ["form", "forms", "form validation", "validation", "inputs"],
        ["schema", "schemas", "zod", "parsing"],
        ["state", "store", "state management", "global state"],
        ["chart", "charts", "plot", "plots", "visualisation", "visualization", "dashboard"],
        ["table", "tables", "data table", "data grid", "grid"],
        ["date", "dates", "date picker", "calendar", "datetime"],
        ["animation", "animations", "animated", "motion", "transition", "transitions"],
        ["number", "numbers", "counter", "animated numbers", "ticker"],
        ["icon", "icons"],
        ["component", "components", "ui components", "ui kit", "design system", "primitives", "headless"],
        ["landing", "landing page", "marketing", "hero"],
        ["drag", "drag and drop", "dnd", "sortable", "reorder"],
        ["auth", "sign in", "sign-in", "login", "authentication"],
        ["ai", "chat", "chat ui", "llm", "agent", "assistant"],
        ["modal", "modals", "dialog", "dialogs", "popover", "dropdown", "tooltip"],
    ]

    private static func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// The query's own words, plus every synonym of a job it names.
    static func terms(for query: String) -> Set<String> {
        let text = " " + words(query).joined(separator: " ") + " "
        var terms = Set(words(query).filter { $0.count >= 2 && !["a", "an", "the", "for", "to", "of", "and", "or", "use", "what", "which", "library", "libraries", "i", "should", "do", "we", "in", "with"].contains($0) })
        for group in synonyms where group.contains(where: { text.contains(" " + words($0).joined(separator: " ") + " ") }) {
            for phrase in group { terms.insert(words(phrase).joined(separator: " ")) }
        }
        return terms
    }

    /// Libraries for the job, best first. A library to avoid still shows, ranked lower and marked.
    static func find(_ query: String, in playbook: Playbook) -> [PickMatch] {
        let terms = terms(for: query)
        guard !terms.isEmpty else { return [] }
        func contains(_ text: String, _ term: String) -> Bool {
            (" " + words(text).joined(separator: " ") + " ").contains(" " + term + " ")
        }
        let matches = playbook.libraries.compactMap { library -> PickMatch? in
            var score = 0
            for term in terms {
                if contains(library.task, term) { score += 10 }
                if contains(library.name, term) { score += 8 }
                if contains(library.purpose, term) { score += 3 }
                if contains(library.useWhen, term) { score += 2 }
            }
            guard score > 0 else { return nil }
            if library.isAvoided { score -= 6 }
            switch library.status {
            case .default: score += 2
            case .legacy: score -= 3
            case .candidate: score -= 4
            case .narrow, .avoid, nil: break
            }
            if library.verified { score += 1 }
            return PickMatch(library: library, score: max(score, 1))
        }
        return matches.sorted { $0.score == $1.score ? $0.library.name < $1.library.name : $0.score > $1.score }
    }

    // MARK: Text for tools

    static func describe(_ library: PlaybookLibrary) -> String {
        var marks: [String] = []
        if library.isAvoided {
            marks.append("avoid for new work")
        } else if let status = library.status {
            switch status {
            case .default: marks.append("the owner's pick")
            case .narrow: marks.append("only for what its notes say")
            case .legacy: marks.append("keep where it's already used, not for new work")
            case .candidate: marks.append("candidate, ask the owner before using it")
            case .avoid: break
            }
        }
        if !library.verified { marks.append(library.isDescribed ? "AI draft, not checked by the owner" : "not described yet") }
        var lines = ["\(library.name)\(library.task.isEmpty ? "" : " (\(library.task))")\(marks.isEmpty ? "" : ": " + marks.joined(separator: ", "))"]
        if !library.url.isEmpty { lines.append("  \(library.url)") }
        if !library.purpose.isEmpty { lines.append("  \(library.purpose)") }
        if !library.useWhen.isEmpty { lines.append("  Use when: \(library.useWhen)") }
        if !library.avoidWhen.isEmpty { lines.append("  Avoid when: \(library.avoidWhen)") }
        if !library.useInstead.isEmpty { lines.append("  Use instead: \(library.useInstead)") }
        if !library.install.isEmpty { lines.append("  Install: \(library.install)") }
        if !library.health.isEmpty { lines.append("  Health: \(library.health)") }
        if !library.notes.isEmpty { lines.append("  Owner's note: \(library.notes)") }
        return lines.joined(separator: "\n")
    }

    static func answer(_ query: String, in playbook: Playbook) -> String {
        let matches = find(query, in: playbook)
        guard !matches.isEmpty else {
            let jobs = Set(playbook.libraries.map(\.task).filter { !$0.isEmpty }).sorted()
            return "The owner's playbook has no pick for \"\(query)\". Ask before adding a library for it." + (jobs.isEmpty ? "" : " Jobs it covers: \(jobs.joined(separator: ", ")).")
        }
        let best = matches.prefix(4)
        var text = best.map { describe($0.library) }.joined(separator: "\n\n")
        if best.allSatisfy({ $0.library.isAvoided }) {
            let instead = best.map(\.library.useInstead).filter { !$0.isEmpty }
            text += instead.isEmpty
                ? "\n\nThe owner marks this to avoid for new work, and the playbook has nothing else for the job. Ask the owner before picking a replacement."
                : "\n\nThe owner marks this to avoid for new work. Use what it names instead: \(instead.joined(separator: "; "))."
        }
        // The rules for the area these picks belong to, such as one animation engine per app.
        let categories = PlaybookCategories.sorted(best.map { PlaybookCategories.canonical($0.library.category) }).filter { !$0.isEmpty }
        let rules = categories.flatMap { playbook.rules(for: $0) }
        if !rules.isEmpty {
            text += "\n\nThe owner's rules for \(categories.joined(separator: " and ")):\n" + rules.map { "- \($0.text)" }.joined(separator: "\n")
        }
        if best.contains(where: { !$0.library.verified }) {
            text += "\n\nDrafts were written by AI. Confirm details in the library's docs before relying on them."
        }
        return text
    }

    static func stackText(_ playbook: Playbook, folder: String? = nil) -> String {
        let stack = playbook.stack(for: folder)
        let own = folder.flatMap { playbook.folderStacks?[$0] } ?? [:]
        let answered = PlaybookQuestions.stack.compactMap { question -> String? in
            guard let answer = stack[question.id], !answer.isEmpty else { return nil }
            var line = "- \(question.title): \(answer.choices.isEmpty ? "no default" : answer.choices.joined(separator: ", "))"
            if !answer.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { line += ". \(answer.notes)" }
            if !(own[question.id]?.isEmpty ?? true) { line += " (for \(folder!)/)" }
            return line
        }
        guard !answered.isEmpty else { return "The owner hasn't set a default stack yet. Ask before choosing one." }
        let heading = folder.map { "Defaults for new work in \($0)/. Existing projects keep what they use." } ?? "Defaults for new work. Existing projects keep what they use."
        return heading + "\n" + answered.joined(separator: "\n")
    }

    static func habitsText(_ playbook: Playbook) -> String {
        let written = PlaybookQuestions.habits.compactMap { prompt -> String? in
            let text = (playbook.habits[prompt.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : "\(prompt.title):\n\(text)"
        }
        return written.isEmpty ? "The owner hasn't written how they work yet." : written.joined(separator: "\n\n")
    }
}

// MARK: - Which graph

/// Finds the graph a command or the MCP server should use, and the folder slice for where it runs.
enum GraphLocator {
    static let graphitreeDefaults = "com.marcuslai.Graphitree"

    /// Graphitree's saved settings. Inside Graphitree.app they're the standard defaults; a tool elsewhere
    /// reads them as a suite.
    static var graphitreeSettings: UserDefaults? {
        Bundle.main.bundleIdentifier == graphitreeDefaults ? .standard : UserDefaults(suiteName: graphitreeDefaults)
    }

    /// An explicit folder first, then the nearest `graphify-out` above the working folder,
    /// then the graph open in Graphitree, then `~/Documents/GitHub/graphify-out`.
    static func outDirectory(explicit: String? = nil, cwd: String = FileManager.default.currentDirectoryPath, home: String = NSHomeDirectory()) -> URL? {
        let fileManager = FileManager.default
        func hasGraph(_ out: String) -> Bool { fileManager.fileExists(atPath: (out as NSString).appendingPathComponent("graph.json")) }
        if let explicit {
            let out = (explicit as NSString).lastPathComponent == "graphify-out" ? explicit : (explicit as NSString).appendingPathComponent("graphify-out")
            return hasGraph(out) ? URL(fileURLWithPath: out) : (hasGraph(explicit) ? URL(fileURLWithPath: explicit) : nil)
        }
        var folder = URL(fileURLWithPath: cwd).standardizedFileURL.path
        while folder != "/" && !folder.isEmpty {
            let out = (folder as NSString).appendingPathComponent("graphify-out")
            if hasGraph(out) { return URL(fileURLWithPath: out) }
            folder = (folder as NSString).deletingLastPathComponent
        }
        if let saved = graphitreeSettings?.string(forKey: "graphOutDirectory"), hasGraph(saved) {
            return URL(fileURLWithPath: saved)
        }
        let fallback = home + "/Documents/GitHub/graphify-out"
        return hasGraph(fallback) ? URL(fileURLWithPath: fallback) : nil
    }

    /// The labelled main folder `cwd` sits in, when it has its own slice of the graph.
    static func slice(for cwd: String, source: GraphSource) -> (folder: String, path: String)? {
        let root = URL(fileURLWithPath: source.rootPath).standardizedFileURL.path + "/"
        let here = URL(fileURLWithPath: cwd).standardizedFileURL.path + "/"
        guard here.hasPrefix(root), let map = FolderFile.load(from: source.outDirectory) else { return nil }
        let top = here.dropFirst(root.count).split(separator: "/").first.map(String.init) ?? ""
        guard let label = map.label(top), label.isIncluded else { return nil }
        let slice = FolderSlices.url(for: top, outDirectory: source.outDirectory).path
        return FileManager.default.fileExists(atPath: slice) ? (top, slice) : nil
    }
}

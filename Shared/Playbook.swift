import Foundation

// The playbook: what AI tools should reach for when they build. Libraries you trust, the stack
// you default to, and how you work. Graphitree keeps it as `playbook.json` and writes `PLAYBOOK.md`
// beside the agent guide, which links to it.

struct PlaybookLibrary: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var url: String = ""
    /// The job it does, such as "Toasts". Libraries are grouped by it.
    var task: String = ""
    var purpose: String = ""
    var useWhen: String = ""
    var avoidWhen: String = ""
    var install: String = ""
    var platforms: String = ""
    /// Whether it's maintained, in a sentence.
    var health: String = ""
    /// The person checked it. Until then, AI tools are told to treat it as a draft.
    var verified = false
    /// Written by Claude rather than the person.
    var drafted = false
    var notes: String = ""

    var isDescribed: Bool { !purpose.isEmpty }
    /// Health text that says the library shouldn't be picked for new work.
    var looksAbandoned: Bool {
        // "isn't archived" and "no deprecation notice" are good news, so negated words don't count.
        let text = health.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(
                of: #"(\bnot|n't|\bno|\bnever|\bwithout)\s+(been\s+|a\s+|any\s+|formally\s+|officially\s+)?(archived|deprecated|unmaintained|abandoned)"#,
                with: "",
                options: .regularExpression
            )
        return ["unmaintained", "deprecated", "archived", "no longer maintained", "abandoned"].contains { text.contains($0) }
    }
}

struct StackAnswer: Codable, Hashable, Sendable {
    var choices: [String] = []
    var notes: String = ""

    var isEmpty: Bool { choices.isEmpty && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct Playbook: Codable, Equatable, Sendable {
    var version = 1
    var libraries: [PlaybookLibrary] = []
    /// Keyed by `StackQuestion.id`.
    var stack: [String: StackAnswer] = [:]
    /// Keyed by `HabitPrompt.id`.
    var habits: [String: String] = [:]
    var updatedAt: Date?
    /// Stack answers that differ in one main folder, such as `work`, keyed by folder then
    /// question. Optional so playbooks saved before folders still load.
    var folderStacks: [String: [String: StackAnswer]]?

    /// The stack for new work in a folder: its own answers where it has them, the rest from everywhere.
    func stack(for folder: String?) -> [String: StackAnswer] {
        guard let folder, let own = folderStacks?[folder] else { return stack }
        return stack.merging(own.filter { !$0.value.isEmpty }) { _, mine in mine }
    }

    /// The playbook as it applies inside one folder.
    func effective(for folder: String?) -> Playbook {
        var result = self
        result.stack = stack(for: folder)
        return result
    }

    /// Folders with answers of their own, in order.
    var foldersWithOwnStack: [String] {
        (folderStacks ?? [:]).filter { !$0.value.values.allSatisfy(\.isEmpty) }.keys.sorted()
    }

    var isEmpty: Bool {
        libraries.isEmpty && stack.values.allSatisfy(\.isEmpty)
            && habits.values.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Libraries grouped by task, tasks in alphabetical order with untitled ones last.
    var librariesByTask: [(task: String, libraries: [PlaybookLibrary])] {
        let groups = Dictionary(grouping: libraries) { $0.task.trimmingCharacters(in: .whitespaces).isEmpty ? "" : $0.task }
        return groups.keys.sorted { a, b in
            if a.isEmpty != b.isEmpty { return !a.isEmpty }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }.map { (task: $0, libraries: groups[$0]!.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
    }
}

// MARK: - Reading playbook.json forgivingly

// A field that's missing or the wrong type takes its default, and a library that can't be read is
// skipped, so one bad spot doesn't lose the whole playbook. That covers a file from an older or
// newer Graphitree, and one an AI tool or the person edited by hand.

extension KeyedDecodingContainer {
    fileprivate func value<T: Decodable>(_ key: Key, or fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

/// Reads any JSON value and keeps nothing, to step over a list item that can't be read.
private struct SkippedValue: Decodable {
    init(from decoder: Decoder) throws {}
}

extension PlaybookLibrary {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = values.value(.id, or: UUID())
        name = values.value(.name, or: "")
        url = values.value(.url, or: "")
        task = values.value(.task, or: "")
        purpose = values.value(.purpose, or: "")
        useWhen = values.value(.useWhen, or: "")
        avoidWhen = values.value(.avoidWhen, or: "")
        install = values.value(.install, or: "")
        platforms = values.value(.platforms, or: "")
        health = values.value(.health, or: "")
        verified = values.value(.verified, or: false)
        drafted = values.value(.drafted, or: false)
        notes = values.value(.notes, or: "")
    }
}

extension StackAnswer {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        choices = values.value(.choices, or: [])
        notes = values.value(.notes, or: "")
    }
}

extension Playbook {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = values.value(.version, or: 1)
        var libraries: [PlaybookLibrary] = []
        if var list = try? values.nestedUnkeyedContainer(forKey: .libraries) {
            while !list.isAtEnd {
                if let library = try? list.decode(PlaybookLibrary.self) {
                    libraries.append(library)
                } else if (try? list.decode(SkippedValue.self)) == nil {
                    break
                }
            }
        }
        self.libraries = libraries
        stack = values.value(.stack, or: [:])
        habits = values.value(.habits, or: [:])
        updatedAt = values.value(.updatedAt, or: nil)
        folderStacks = values.value(.folderStacks, or: nil)
    }
}

// MARK: - Questions

struct StackOption: Hashable, Sendable {
    let name: String
    let bestFor: String
}

struct StackQuestion: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let prompt: String
    let options: [StackOption]
}

struct HabitPrompt: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let example: String
}

enum PlaybookQuestions {
    static let stack: [StackQuestion] = [
        StackQuestion(id: "platforms", title: "What you build", prompt: "Which kinds of app do you make?", options: [
            .init(name: "Web apps", bestFor: "Reaching anyone with a browser"),
            .init(name: "iOS apps", bestFor: "iPhone and iPad"),
            .init(name: "Mac apps", bestFor: "Native desktop tools on macOS"),
            .init(name: "Android apps", bestFor: "Android phones"),
            .init(name: "Desktop apps", bestFor: "One app for Mac, Windows and Linux"),
            .init(name: "Browser extensions", bestFor: "Adding to sites people already use"),
            .init(name: "Command-line tools", bestFor: "Scripts and developer tools"),
            .init(name: "APIs and services", bestFor: "Back ends other apps call"),
            .init(name: "Games", bestFor: "Real-time graphics and play"),
        ]),
        StackQuestion(id: "languages", title: "Languages", prompt: "Which languages do you reach for?", options: [
            .init(name: "TypeScript", bestFor: "Web front and back ends"),
            .init(name: "Swift", bestFor: "Apple platforms"),
            .init(name: "Python", bestFor: "AI, data and scripts"),
            .init(name: "Go", bestFor: "Small, fast services"),
            .init(name: "Rust", bestFor: "Performance and systems code"),
            .init(name: "Kotlin", bestFor: "Android"),
            .init(name: "C++", bestFor: "Engines and native code"),
            .init(name: "C#", bestFor: ".NET and Unity"),
        ]),
        StackQuestion(id: "web", title: "Web framework", prompt: "What do new web apps start from?", options: [
            .init(name: "Next.js", bestFor: "Full-stack React with server rendering"),
            .init(name: "Vite + React", bestFor: "Single-page apps and dashboards"),
            .init(name: "React Router", bestFor: "Data-heavy apps, formerly Remix"),
            .init(name: "Astro", bestFor: "Content sites and docs"),
            .init(name: "SvelteKit", bestFor: "Small, fast apps"),
            .init(name: "Nuxt", bestFor: "Vue teams"),
        ]),
        StackQuestion(id: "ui", title: "UI components", prompt: "Where do buttons, dialogs and menus come from?", options: [
            .init(name: "shadcn/ui", bestFor: "Copy-in components you own"),
            .init(name: "Radix UI", bestFor: "Accessible unstyled primitives"),
            .init(name: "Base UI", bestFor: "Unstyled primitives from the MUI and Radix teams"),
            .init(name: "MUI", bestFor: "A complete design system"),
            .init(name: "Mantine", bestFor: "Many components, quick to start"),
            .init(name: "SwiftUI", bestFor: "Native Apple interfaces"),
        ]),
        StackQuestion(id: "styling", title: "Styling", prompt: "How do you style things?", options: [
            .init(name: "Tailwind CSS", bestFor: "Utility classes next to the markup"),
            .init(name: "CSS Modules", bestFor: "Plain CSS scoped per component"),
            .init(name: "styled-components", bestFor: "CSS in JavaScript"),
            .init(name: "Sass", bestFor: "Larger hand-written stylesheets"),
        ]),
        StackQuestion(id: "backend", title: "Back end", prompt: "What runs the server side?", options: [
            .init(name: "Next.js route handlers", bestFor: "APIs that live with the web app"),
            .init(name: "NestJS", bestFor: "Structured Node services"),
            .init(name: "Express", bestFor: "Small Node servers"),
            .init(name: "Fastify", bestFor: "Fast Node servers"),
            .init(name: "Hono", bestFor: "Edge and serverless"),
            .init(name: "FastAPI", bestFor: "Python APIs"),
            .init(name: "Django", bestFor: "Python apps with an admin"),
            .init(name: "Supabase", bestFor: "Hosted Postgres, auth and storage"),
            .init(name: "Firebase", bestFor: "Hosted realtime data and auth"),
        ]),
        StackQuestion(id: "data", title: "Data", prompt: "Where does data live?", options: [
            .init(name: "PostgreSQL", bestFor: "Most apps"),
            .init(name: "SQLite", bestFor: "Local and single-user apps"),
            .init(name: "MySQL", bestFor: "Existing MySQL setups"),
            .init(name: "MongoDB", bestFor: "Document data"),
            .init(name: "Redis", bestFor: "Caches and queues"),
            .init(name: "Prisma", bestFor: "A typed ORM with migrations"),
            .init(name: "Drizzle", bestFor: "A light, SQL-like ORM"),
        ]),
        StackQuestion(id: "auth", title: "Sign-in", prompt: "How do people sign in?", options: [
            .init(name: "Clerk", bestFor: "Hosted sign-in with ready-made screens"),
            .init(name: "Auth.js", bestFor: "Self-hosted sign-in for Next.js"),
            .init(name: "Better Auth", bestFor: "Self-hosted, framework-agnostic"),
            .init(name: "Supabase Auth", bestFor: "Apps already on Supabase"),
            .init(name: "Firebase Auth", bestFor: "Apps already on Firebase"),
            .init(name: "Sign in with Apple", bestFor: "Apple platforms"),
        ]),
        StackQuestion(id: "hosting", title: "Hosting", prompt: "Where do apps run?", options: [
            .init(name: "Vercel", bestFor: "Next.js and front ends"),
            .init(name: "Netlify", bestFor: "Static sites and functions"),
            .init(name: "Cloudflare", bestFor: "Edge workers and pages"),
            .init(name: "Fly.io", bestFor: "Containers near users"),
            .init(name: "Railway", bestFor: "Quick servers and databases"),
            .init(name: "Your own server", bestFor: "Full control, such as a VPS"),
            .init(name: "App Store", bestFor: "Apple apps, through TestFlight"),
        ]),
        StackQuestion(id: "testing", title: "Testing", prompt: "How do you test?", options: [
            .init(name: "Vitest", bestFor: "Unit tests for Vite projects"),
            .init(name: "Jest", bestFor: "Unit tests in older Node projects"),
            .init(name: "Playwright", bestFor: "End-to-end browser tests"),
            .init(name: "Testing Library", bestFor: "Component tests that act like a user"),
            .init(name: "Swift Testing", bestFor: "Swift and XCTest"),
            .init(name: "pytest", bestFor: "Python"),
        ]),
        StackQuestion(id: "ai", title: "AI in your apps", prompt: "How do your apps call AI models?", options: [
            .init(name: "Claude API", bestFor: "Anthropic's SDK"),
            .init(name: "OpenAI API", bestFor: "OpenAI's SDK"),
            .init(name: "Vercel AI SDK", bestFor: "Streaming chat UIs across providers"),
            .init(name: "LangChain", bestFor: "Chains and agents across providers"),
            .init(name: "Ollama", bestFor: "Models on your own machine"),
        ]),
    ]

    static let habits: [HabitPrompt] = [
        HabitPrompt(id: "build", title: "What you build most", example: "Internal tools for a small team, and Mac utilities for myself."),
        HabitPrompt(id: "users", title: "Who uses your apps, and how", example: "Warehouse staff on tablets, in short bursts, often offline."),
        HabitPrompt(id: "always", title: "Always do", example: "Explain changes in plain language. Add tests for anything that handles money."),
        HabitPrompt(id: "never", title: "Never do", example: "Don't add a dependency without saying why. Don't rewrite files I didn't ask about."),
        HabitPrompt(id: "design", title: "Design taste", example: "Dark, quiet interfaces. Motion only where it explains something."),
        HabitPrompt(id: "workflow", title: "Working with AI", example: "Plan first for big changes. Small commits with clear messages."),
        HabitPrompt(id: "other", title: "Anything else", example: "Anything else AI tools should know before they start."),
    ]
}

// MARK: - Adding libraries from pasted text

enum PlaybookImport {
    /// Reads "Name – https://link", "Name: link", a bare link or a bare name, one per line.
    static func libraries(from text: String) -> [PlaybookLibrary] {
        var result: [PlaybookLibrary] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-*•").union(.whitespaces))
            guard !line.isEmpty else { continue }
            var url = ""
            var name = line
            if let range = line.range(of: #"https?://\S+"#, options: .regularExpression) {
                url = String(line[range]).trimmingCharacters(in: CharacterSet(charactersIn: ").,;"))
                name = String(line[..<range.lowerBound])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "–—-:|(").union(.whitespaces))
            }
            if name.isEmpty, let host = URL(string: url)?.host {
                name = host.replacingOccurrences(of: "www.", with: "")
            }
            guard !name.isEmpty else { continue }
            result.append(PlaybookLibrary(name: name, url: url))
        }
        return result
    }

    /// Whether the playbook already has a known library, by name ("Radix" for "Radix UI") or by site.
    static func contains(_ known: KnownLibrary, in libraries: [PlaybookLibrary]) -> Bool {
        func key(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
        func host(_ url: String) -> String? { URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "") }
        let knownKey = key(known.name)
        return libraries.contains { library in
            let name = key(library.name)
            if !name.isEmpty && (name == knownKey || knownKey.hasPrefix(name) || name.hasPrefix(knownKey)) { return true }
            if let mine = host(library.url), let theirs = host(known.url), mine == theirs { return true }
            return false
        }
    }

    /// Adds libraries whose name isn't already there, ignoring case.
    static func merging(_ new: [PlaybookLibrary], into existing: [PlaybookLibrary]) -> [PlaybookLibrary] {
        var names = Set(existing.map { $0.name.lowercased() })
        var result = existing
        for library in new where names.insert(library.name.lowercased()).inserted {
            result.append(library)
        }
        return result
    }
}

// MARK: - Files

enum PlaybookFile {
    static let jsonName = "playbook.json"
    static let markdownName = "PLAYBOOK.md"

    static func load(from directory: URL) -> Playbook {
        (try? read(from: directory)) ?? Playbook()
    }

    /// The playbook, an empty one when there's no file, or an error when the file can't be read.
    private static func read(from directory: URL) throws -> Playbook {
        let url = directory.appendingPathComponent(jsonName)
        guard FileManager.default.fileExists(atPath: url.path) else { return Playbook() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Playbook.self, from: Data(contentsOf: url))
    }

    /// Whether playbook.json is there but can't be read, such as when a hand edit broke its JSON.
    static func isUnreadable(in directory: URL) -> Bool {
        (try? read(from: directory)) == nil
    }

    /// Copies playbook.json to playbook.<label>-<time>.json beside it, before it's replaced.
    /// Returns the copy's name, or nil when there's no file to keep.
    @discardableResult
    static func keepAside(in directory: URL, as label: String, now: Date = .now) throws -> String? {
        let json = directory.appendingPathComponent(jsonName)
        guard FileManager.default.fileExists(atPath: json.path) else { return nil }
        let stamp = ISO8601DateFormatter.string(from: now, timeZone: .current, formatOptions: [.withFullDate, .withTime])
        var name = "playbook.\(label)-\(stamp).json"
        var count = 1
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
            count += 1
            name = "playbook.\(label)-\(stamp)-\(count).json"
        }
        try FileManager.default.copyItem(at: json, to: directory.appendingPathComponent(name))
        return name
    }

    /// Writes the JSON Graphitree reads back and the markdown AI tools read. A playbook.json that
    /// can't be read is kept as playbook.unreadable-<time>.json first, never written over.
    static func save(_ playbook: Playbook, to directory: URL, now: Date = .now) throws {
        var stamped = playbook
        stamped.updatedAt = now
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = directory.appendingPathComponent(jsonName)
        if isUnreadable(in: directory) { try keepAside(in: directory, as: "unreadable", now: now) }
        try encoder.encode(stamped).write(to: json, options: .atomic)
        try markdown(stamped).write(to: directory.appendingPathComponent(markdownName), atomically: true, encoding: .utf8)
    }

    static func markdown(_ playbook: Playbook) -> String {
        var lines: [String] = []
        lines.append("<!-- Written by Graphitree from playbook.json. Edit it in Graphitree's Playbook panel: changes made here are overwritten. -->")
        lines.append("# Playbook")
        lines.append("")
        lines.append("How the owner of these repos builds software. Read it before starting new work, adding a dependency or writing a component.")
        lines.append("")
        lines.append("## Rules for AI tools")
        lines.append("")
        lines.append("- Before writing a component or helper yourself, look under Libraries. If one there does the job, use it.")
        lines.append("- Prefer what the project already depends on. Don't replace it with a library from this list without asking.")
        lines.append("- Entries marked *draft* were written by AI and not checked yet. Confirm details in their docs before relying on them.")
        lines.append("- Don't pick a library marked *avoid for new work*, even if it's listed.")
        lines.append("- For a new project, start from Stack, and ask before going against it.")

        if !playbook.libraries.isEmpty {
            lines.append("")
            lines.append("## Libraries")
            for group in playbook.librariesByTask {
                lines.append("")
                lines.append("### \(group.task.isEmpty ? "Other" : group.task)")
                lines.append("")
                for library in group.libraries {
                    var head = "- **\(library.name)**"
                    if !library.url.isEmpty { head += " (\(library.url))" }
                    var marks: [String] = []
                    if library.looksAbandoned { marks.append("avoid for new work") }
                    if !library.verified { marks.append(library.isDescribed ? "draft" : "not described yet") }
                    if !marks.isEmpty { head += " *\(marks.joined(separator: ", "))*" }
                    lines.append(head)
                    if !library.purpose.isEmpty { lines.append("  \(oneLine(library.purpose))") }
                    if !library.useWhen.isEmpty { lines.append("  Use when: \(oneLine(library.useWhen))") }
                    if !library.avoidWhen.isEmpty { lines.append("  Avoid when: \(oneLine(library.avoidWhen))") }
                    var facts: [String] = []
                    if !library.install.isEmpty { facts.append("Install: " + installText(library.install)) }
                    if !library.platforms.isEmpty { facts.append(sentence("Works with: \(oneLine(library.platforms))")) }
                    if !facts.isEmpty { lines.append("  " + facts.joined(separator: " ")) }
                    if !library.health.isEmpty { lines.append("  Health: \(oneLine(library.health))") }
                    if !library.notes.isEmpty { lines.append("  Owner's note: \(oneLine(library.notes))") }
                }
            }
        }

        let answered = PlaybookQuestions.stack.filter { !(playbook.stack[$0.id]?.isEmpty ?? true) }
        if !answered.isEmpty {
            lines.append("")
            lines.append("## Stack")
            lines.append("")
            lines.append("Defaults for new work. Existing projects keep what they use.")
            lines.append("")
            for question in answered {
                let answer = playbook.stack[question.id]!
                var line = "- **\(question.title):** \(answer.choices.isEmpty ? "no default" : answer.choices.joined(separator: ", "))"
                if !answer.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    line += ". \(oneLine(answer.notes))"
                }
                lines.append(line)
            }
        }

        for folder in playbook.foldersWithOwnStack {
            let own = PlaybookQuestions.stack.filter { !(playbook.folderStacks?[folder]?[$0.id]?.isEmpty ?? true) }
            lines.append("")
            lines.append("### In `\(folder)/`")
            lines.append("")
            lines.append("These replace the defaults above for work in this folder.")
            lines.append("")
            for question in own {
                let answer = playbook.folderStacks![folder]![question.id]!
                var line = "- **\(question.title):** \(answer.choices.isEmpty ? "no default" : answer.choices.joined(separator: ", "))"
                if !answer.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { line += ". \(oneLine(answer.notes))" }
                lines.append(line)
            }
        }

        let habits = PlaybookQuestions.habits.compactMap { prompt -> (String, String)? in
            let text = (playbook.habits[prompt.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : (prompt.title, text)
        }
        if !habits.isEmpty {
            lines.append("")
            lines.append("## How the owner works")
            for (title, text) in habits {
                lines.append("")
                lines.append("### \(title)")
                lines.append("")
                lines.append(text)
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: The copy graphify reads

    /// graphify skips graphify-out, so a copy goes in a folder of its own under the graph's root,
    /// where the docs pass turns it into nodes like any other doc.
    static let graphFolder = "playbook"
    static let graphCopyDefaultsKey = "playbookInGraph"

    static func graphCopyURL(root: String) -> URL {
        URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent(graphFolder, isDirectory: true)
            .appendingPathComponent(markdownName)
    }

    /// On unless the root is itself a git repo, so Graphitree never adds a folder to someone's repo unasked.
    static func addsToGraphByDefault(root: String) -> Bool {
        !FileManager.default.fileExists(atPath: (root as NSString).appendingPathComponent(".git"))
    }

    static func addsToGraph(root: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: graphCopyDefaultsKey) as? Bool ?? addsToGraphByDefault(root: root)
    }

    static func graphCopy(_ playbook: Playbook) -> String {
        let body = markdown(playbook).components(separatedBy: "\n").dropFirst().joined(separator: "\n")
        return "<!-- A copy of graphify-out/\(markdownName) that Graphitree keeps here so graphify adds it to the knowledge graph. Edit it in Graphitree's Playbook panel: changes made here are overwritten. -->\n" + body
    }

    /// Writes the copy only when it changed, so its date says when the playbook last changed.
    /// Returns true when the file was written.
    @discardableResult
    static func writeGraphCopy(_ playbook: Playbook, root: String) throws -> Bool {
        let url = graphCopyURL(root: root)
        let text = graphCopy(playbook)
        if (try? String(contentsOf: url, encoding: .utf8)) == text { return false }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    /// Takes the copy out, and its folder when nothing else is in it.
    static func removeGraphCopy(root: String) {
        let url = graphCopyURL(root: root)
        try? FileManager.default.removeItem(at: url)
        let folder = url.deletingLastPathComponent()
        if let rest = try? FileManager.default.contentsOfDirectory(atPath: folder.path), rest.allSatisfy({ $0 == ".DS_Store" }) {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    /// When the copy changed after the graph was built, the graph still has the old playbook.
    static func graphCopyIsNewer(than builtAt: Date, root: String) -> Bool {
        guard let changed = (try? FileManager.default.attributesOfItem(atPath: graphCopyURL(root: root).path))?[.modificationDate] as? Date else { return false }
        return changed > builtAt
    }

    // MARK: The short version for the guide

    /// The picks every AI tool should see without opening the playbook: one line per job and per
    /// stack answer. Empty when there's nothing to say.
    static func guideSummary(_ playbook: Playbook) -> [String] {
        var lines: [String] = []
        if !playbook.libraries.isEmpty {
            lines.append("Libraries, by the job they do:")
            lines.append("")
            for group in playbook.librariesByTask {
                let use = group.libraries.filter { !$0.looksAbandoned }.map(\.name)
                let avoid = group.libraries.filter(\.looksAbandoned).map(\.name)
                var parts: [String] = []
                if !use.isEmpty { parts.append(use.joined(separator: ", ")) }
                if !avoid.isEmpty { parts.append("avoid \(avoid.joined(separator: ", ")) for new work") }
                lines.append("- \(group.task.isEmpty ? "Other" : group.task): \(parts.joined(separator: "; "))")
            }
        }
        let answered = PlaybookQuestions.stack.compactMap { question -> String? in
            guard let answer = playbook.stack[question.id], !answer.choices.isEmpty else { return nil }
            return "- \(question.title): \(answer.choices.joined(separator: ", "))"
        }
        if !answered.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("Stack for new work:")
            lines.append("")
            lines.append(contentsOf: answered)
        }
        for folder in playbook.foldersWithOwnStack {
            let own = PlaybookQuestions.stack.compactMap { question -> String? in
                guard let answer = playbook.folderStacks?[folder]?[question.id], !answer.choices.isEmpty else { return nil }
                return "\(question.title): \(answer.choices.joined(separator: ", "))"
            }
            guard !own.isEmpty else { continue }
            lines.append("- In `\(folder)/`, instead: " + own.joined(separator: "; "))
        }
        let drafts = playbook.libraries.filter { !$0.verified }.count
        if drafts > 0 {
            lines.append("")
            let total = playbook.libraries.count
            let subject = drafts < total
                ? "\(drafts) of the \(total) libraries above \(drafts == 1 ? "was" : "were")"
                : total == 1 ? "The library above was" : "All \(total) libraries above were"
            lines.append("\(subject) described by AI and not checked by the owner yet. Confirm details in the playbook before relying on them.")
        }
        return lines
    }

    /// A command goes in backticks; prose such as "Copy it from the site" doesn't.
    static func installText(_ text: String) -> String {
        let line = oneLine(text)
        let commands = ["npm ", "npx ", "pnpm ", "yarn ", "bun ", "bunx ", "pip ", "uv ", "brew ", "cargo ", "go ", "swift ", "gem ", "composer ", "dotnet ", "deno "]
        guard commands.contains(where: { line.hasPrefix($0) }) else { return sentence(line) }
        // Keep the command itself in code and any explanation after it in prose.
        if let split = line.range(of: " (") ?? line.range(of: ", then ") {
            return "`\(line[..<split.lowerBound])` " + sentence(String(line[split.lowerBound...]))
        }
        return "`\(line)`."
    }

    private static func sentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let last = trimmed.last else { return trimmed }
        return ".!?)".contains(last) && last != ")" ? trimmed : trimmed + "."
    }

    private static func oneLine(_ text: String) -> String {
        text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

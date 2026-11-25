import Foundation

// The playbook: what AI tools should reach for when they build. Libraries you trust, the stack
// you default to, and how you work. Graphitree keeps it as `playbook.json` and writes `PLAYBOOK.md`
// beside the agent guide, which links to it.

/// Where a library stands for new work. Unset means the owner hasn't said, and only its health
/// note can warn AI tools off it.
enum LibraryStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    /// The pick for its job.
    case `default`
    /// Kept, but only for the job or the place its notes describe.
    case narrow
    /// Stays in projects that already use it; new work picks something else.
    case legacy
    /// Being considered. AI tools ask before using it.
    case candidate
    /// Not for new work. `useInstead` names what to pick.
    case avoid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default: return "Default"
        case .narrow: return "Narrow"
        case .legacy: return "Legacy"
        case .candidate: return "Candidate"
        case .avoid: return "Avoid"
        }
    }

    /// What it means, for the editor and for AI tools.
    var meaning: String {
        switch self {
        case .default: return "The pick for its job"
        case .narrow: return "Only for what its notes say"
        case .legacy: return "Keep where it's used; not for new work"
        case .candidate: return "Not adopted yet; ask first"
        case .avoid: return "Don't use in new work"
        }
    }

    /// The order libraries take within a job: the pick first, what to avoid last.
    var rank: Int {
        switch self {
        case .default: return 0
        case .narrow: return 1
        case .legacy: return 3
        case .candidate: return 4
        case .avoid: return 5
        }
    }
}

/// The broad areas libraries are filed under, so a long playbook reads as a few sections
/// instead of one list of jobs. A library can name another category; it's kept as written.
enum PlaybookCategories {
    static let all: [(name: String, covers: String)] = [
        ("Components", "UI kits, headless primitives, icons, theming"),
        ("Interaction", "Toasts, menus, pickers, drag and drop, tours"),
        ("Animation", "UI motion, scene animation, animated numbers, effects"),
        ("3D and graphics", "3D engines, WebGL, shaders"),
        ("Charts and maps", "Charts, node graphs, diagrams, maps"),
        ("Forms and data", "Forms, validation, state, data fetching, routing"),
        ("Content and documents", "Editors, markdown, sanitising HTML, PDFs, spreadsheets"),
        ("AI", "Model SDKs and chat interfaces"),
        ("Server and storage", "Back ends, databases, ORMs, sign-in, jobs"),
        ("Testing and tooling", "Tests, linting, build tools"),
    ]

    static var names: [String] { all.map(\.name) }

    /// The category's own spelling for a name in any case, or the name as written.
    static func canonical(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return names.first { $0.caseInsensitiveCompare(trimmed) == .orderedSame } ?? trimmed
    }

    /// Known categories in their fixed order, then others by name, then none.
    static func sorted(_ categories: some Sequence<String>) -> [String] {
        Array(Set(categories)).sorted { a, b in
            let ia = names.firstIndex(of: a) ?? (a.isEmpty ? Int.max : names.count)
            let ib = names.firstIndex(of: b) ?? (b.isEmpty ? Int.max : names.count)
            if ia != ib { return ia < ib }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    /// A category for a job the stack scan knows, so a suggested library arrives filed.
    static func guess(task: String) -> String {
        let jobs: [String: String] = [
            "toasts": "Interaction", "drawers": "Interaction", "command menu": "Interaction", "carousels": "Interaction",
            "date pickers": "Interaction", "drag and drop": "Interaction", "dashboard grids": "Interaction",
            "emoji pickers": "Interaction", "image cropping": "Interaction", "product tours": "Interaction",
            "popover positioning": "Components", "one-time codes": "Interaction",
            "ui primitives": "Components", "icons": "Components", "styling variants": "Components",
            "class names": "Components", "dark mode": "Components",
            "animation": "Animation", "animated numbers": "Animation",
            "3d graphics": "3D and graphics",
            "charts": "Charts and maps", "data visualization": "Charts and maps", "diagrams": "Charts and maps",
            "node graphs": "Charts and maps", "network graphs": "Charts and maps", "maps": "Charts and maps",
            "routing": "Forms and data", "state": "Forms and data", "data fetching": "Forms and data",
            "tables": "Forms and data", "forms": "Forms and data", "validation": "Forms and data",
            "dates": "Forms and data", "long lists": "Forms and data",
            "rich text editing": "Content and documents", "markdown": "Content and documents",
            "pdf documents": "Content and documents", "code highlighting": "Content and documents",
        ]
        return jobs[task.lowercased().trimmingCharacters(in: .whitespaces)] ?? ""
    }
}

/// A rule AI tools follow that isn't about one library, such as "One primitive system per app".
struct PlaybookRule: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var text: String
    /// The category it belongs to, or empty for a rule that applies everywhere.
    var category: String = ""
}

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
    /// Where it stands for new work. Nil until the owner sets it.
    var status: LibraryStatus?
    /// The broad area it's filed under, such as "Animation". Jobs are grouped inside it.
    var category: String = ""
    /// What to pick instead, for a library to avoid or one kept only where it's used.
    var useInstead: String = ""
    /// When the health note was last written, by hand or from research.
    var checkedOn: Date?
    /// The name of another library in the playbook this one is used with, such as react-markdown
    /// for remark-gfm. It's listed under that library instead of as a job of its own.
    var pairsWith: String = ""

    var isDescribed: Bool { !purpose.isEmpty }

    /// Its name as names are compared: lowercased, letters and digits only.
    var nameKey: String { Self.key(name) }

    static func key(_ name: String) -> String { name.lowercased().filter { $0.isLetter || $0.isNumber } }

    /// Not for new work: marked avoid, or, with no status set, a health note that says it's abandoned.
    var isAvoided: Bool { status == .avoid || (status == nil && looksAbandoned) }

    /// Where it sorts within its job: the pick first, an unset status after the narrow ones.
    var statusRank: Int { isAvoided ? LibraryStatus.avoid.rank : status?.rank ?? 2 }
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

/// A skill the playbook gives new repos, in the Agent Skills format most AI tools read:
/// `.agents/skills/<name>/SKILL.md`, with only the standard's `name` and `description` up top.
struct PlaybookSkill: Codable, Identifiable, Hashable, Sendable {
    /// Which seeded repos get it.
    enum Reach: String, Codable, CaseIterable, Identifiable, Sendable {
        case everywhere, personal, repos

        var id: String { rawValue }
        var title: String {
            switch self {
            case .everywhere: return "Every new repo"
            case .personal: return "Personal repos only"
            case .repos: return "Only the repos named"
            }
        }
    }

    var id = UUID()
    /// The folder name too: lowercase letters, digits and single hyphens, at most 64 characters.
    var name: String
    /// When to use it. Tools read this to decide whether to load the skill, so it says both what and when.
    var description: String = ""
    /// SKILL.md after the frontmatter.
    var body: String = ""
    /// Other files the skill needs, by their path inside its folder, such as `scripts/check.sh`.
    var files: [SkillFile] = []
    var reach: Reach = .everywhere
    /// The projects it goes to when reach is .repos, such as `personal/kiln`.
    var repos: [String] = []
    /// Written for Claude Code alone: it goes in `.claude/skills/`, where other tools don't look.
    var claudeOnly = false
    /// Written by AI and not checked yet. Drafts aren't put in repos.
    var drafted = false
    /// The repo it was adopted from, such as `personal/kiln`, if any.
    var source = ""

    static let maxNameLength = 64
    static let maxDescriptionLength = 1024
    static let fileName = "SKILL.md"

    /// The standard's rule for names: `pdf-tools`, not `PDF Tools`, `-pdf` or `pdf--tools`.
    static func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= maxNameLength, !name.hasPrefix("-"), !name.hasSuffix("-"), !name.contains("--") else { return false }
        return name.allSatisfy { ($0.isASCII && $0.isLowercase && $0.isLetter) || ($0.isASCII && $0.isNumber) || $0 == "-" }
    }

    /// A name typed as words, made into one: "Release Notes" becomes `release-notes`.
    static func suggestedName(_ text: String) -> String {
        let words = text.lowercased().map { ($0.isASCII && ($0.isLetter || $0.isNumber)) ? $0 : " " }
        return String(String(words).split(separator: " ").joined(separator: "-").prefix(maxNameLength)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// A path inside the skill's folder that's safe to write: relative, with no `..`, and not SKILL.md itself.
    static func isValidFilePath(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.hasPrefix("/"), path != fileName else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    /// What's stopping it from going into repos, in words. Empty when it's ready.
    var problems: [String] {
        var found: [String] = []
        if !Self.isValidName(name) { found.append("The name needs lowercase letters, digits and single hyphens, at most \(Self.maxNameLength) characters, such as release-notes.") }
        let about = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if about.isEmpty { found.append("It needs a description: what it does and when to use it.") }
        if about.count > Self.maxDescriptionLength { found.append("The description is over \(Self.maxDescriptionLength) characters.") }
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { found.append("It needs instructions.") }
        if files.contains(where: { !Self.isValidFilePath($0.path) }) { found.append("Each extra file needs a path inside the skill's folder, such as scripts/check.sh.") }
        return found
    }

    var isReady: Bool { problems.isEmpty && !drafted }

    /// SKILL.md as a repo gets it.
    var skillText: String {
        let about = description.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        let quoted = "\"" + about.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return "---\nname: \(name)\ndescription: \(quoted)\n---\n\n\(text)\n"
    }

    /// Whether a repo gets it, by its path and its main folder's label.
    func reaches(_ project: String, purpose: FolderPurpose?) -> Bool {
        switch reach {
        case .everywhere: return true
        case .personal: return purpose?.id == FolderPurpose.personal.id
        case .repos: return repos.contains(project)
        }
    }
}

struct SkillFile: Codable, Hashable, Sendable {
    var path: String
    var text: String
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
    /// Rules that aren't about one library, in the owner's order.
    var rules: [PlaybookRule] = []
    /// Skills new repos get, in the owner's order.
    var skills: [PlaybookSkill] = []

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
            && rules.isEmpty && skills.isEmpty
    }

    /// Libraries grouped by task, tasks in alphabetical order with untitled ones last. Within a
    /// task, the pick comes first and what to avoid last.
    var librariesByTask: [(task: String, libraries: [PlaybookLibrary])] {
        Self.byTask(libraries)
    }

    /// Libraries grouped by category, then by task inside each one. Known categories keep their
    /// fixed order; libraries with none come last.
    var librariesByCategory: [(category: String, tasks: [(task: String, libraries: [PlaybookLibrary])])] {
        let groups = Dictionary(grouping: libraries) { PlaybookCategories.canonical($0.category) }
        return PlaybookCategories.sorted(groups.keys).map { (category: $0, tasks: Self.byTask(groups[$0]!)) }
    }

    /// The library this one is listed under: the one its pairsWith names. Nil when that isn't in
    /// the playbook, when either of them is to be avoided, or when pairing would go round in a loop.
    func partner(of library: PlaybookLibrary) -> PlaybookLibrary? {
        func named(_ name: String, besides id: UUID) -> PlaybookLibrary? {
            let key = PlaybookLibrary.key(name)
            guard !key.isEmpty else { return nil }
            return libraries.first { $0.id != id && $0.nameKey == key && !$0.isAvoided }
        }
        guard !library.isAvoided, let partner = named(library.pairsWith, besides: library.id) else { return nil }
        // Follow the chain up: it has to end at a library that pairs with nothing.
        var seen: Set<UUID> = [library.id]
        var current = partner
        while seen.insert(current.id).inserted {
            guard let next = named(current.pairsWith, besides: current.id) else { return partner }
            current = next
        }
        return nil
    }

    /// The libraries listed directly under this one, by name.
    func companions(of library: PlaybookLibrary) -> [PlaybookLibrary] {
        libraries.filter { partner(of: $0)?.id == library.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// This library's companions, theirs after each of them, with how deep each one sits (1 for a direct one).
    func companionTree(of library: PlaybookLibrary) -> [(library: PlaybookLibrary, depth: Int)] {
        var result: [(library: PlaybookLibrary, depth: Int)] = []
        func walk(_ parent: PlaybookLibrary, _ depth: Int) {
            for child in companions(of: parent) {
                result.append((child, depth))
                walk(child, depth + 1)
            }
        }
        walk(library, 1)
        return result
    }

    /// Like librariesByCategory, but a library that pairs with another isn't in a job of its own:
    /// it's listed under that library (see companionTree).
    var leadsByCategory: [(category: String, tasks: [(task: String, libraries: [PlaybookLibrary])])] {
        var leads = self
        leads.libraries = libraries.filter { partner(of: $0) == nil }
        return leads.librariesByCategory
    }

    /// Every library in reading order: categories, jobs inside them, the pick first, and each
    /// library followed by the ones that pair with it (depth 1 and deeper).
    var outline: [(category: String, tasks: [(task: String, entries: [(library: PlaybookLibrary, depth: Int)])])] {
        leadsByCategory.map { group in
            (category: group.category, tasks: group.tasks.map { job in
                (task: job.task, entries: job.libraries.flatMap { [(library: $0, depth: 0)] + companionTree(of: $0) })
            })
        }
    }

    /// The rules for one category, or the ones that apply everywhere for "".
    func rules(for category: String) -> [PlaybookRule] {
        rules.filter { PlaybookCategories.canonical($0.category) == category && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func byTask(_ libraries: [PlaybookLibrary]) -> [(task: String, libraries: [PlaybookLibrary])] {
        let groups = Dictionary(grouping: libraries) { $0.task.trimmingCharacters(in: .whitespaces).isEmpty ? "" : $0.task }
        return groups.keys.sorted { a, b in
            if a.isEmpty != b.isEmpty { return !a.isEmpty }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }.map { task in
            (task: task, libraries: groups[task]!.sorted { a, b in
                if a.statusRank != b.statusRank { return a.statusRank < b.statusRank }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            })
        }
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
        // A status a newer Graphitree invented reads as unset rather than losing the library.
        status = LibraryStatus(rawValue: values.value(.status, or: ""))
        category = values.value(.category, or: "")
        useInstead = values.value(.useInstead, or: "")
        checkedOn = values.value(.checkedOn, or: nil)
        pairsWith = values.value(.pairsWith, or: "")
    }
}

extension PlaybookRule {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = values.value(.id, or: UUID())
        text = values.value(.text, or: "")
        category = values.value(.category, or: "")
    }
}

extension PlaybookSkill {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = values.value(.id, or: UUID())
        name = values.value(.name, or: "")
        description = values.value(.description, or: "")
        body = values.value(.body, or: "")
        files = values.value(.files, or: [])
        reach = values.value(.reach, or: .everywhere)
        repos = values.value(.repos, or: [])
        claudeOnly = values.value(.claudeOnly, or: false)
        drafted = values.value(.drafted, or: false)
        source = values.value(.source, or: "")
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
        var rules: [PlaybookRule] = []
        if var list = try? values.nestedUnkeyedContainer(forKey: .rules) {
            while !list.isAtEnd {
                if let rule = try? list.decode(PlaybookRule.self) {
                    if !rule.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { rules.append(rule) }
                } else if (try? list.decode(SkippedValue.self)) == nil {
                    break
                }
            }
        }
        self.rules = rules
        var skills: [PlaybookSkill] = []
        if var list = try? values.nestedUnkeyedContainer(forKey: .skills) {
            while !list.isAtEnd {
                if let skill = try? list.decode(PlaybookSkill.self) {
                    skills.append(skill)
                } else if (try? list.decode(SkippedValue.self)) == nil {
                    break
                }
            }
        }
        self.skills = skills
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
        if playbook.libraries.contains(where: { $0.status != nil }) {
            lines.append("- Each job lists its *default* first: that's the pick. Use a *narrow* one only for what its notes say. Keep a *legacy* one in projects that already use it, but don't add it to new ones. Ask before using a *candidate*.")
        }
        lines.append("- Entries marked *draft* were written by AI and not checked yet. Confirm details in their docs before relying on them.")
        lines.append("- Don't pick a library marked *avoid for new work*, even if it's listed. Use what it says to use instead.")

        let kept = playbook.libraries.filter { !$0.isAvoided }
        var listed = Playbook()
        listed.libraries = kept
        if kept.contains(where: { listed.partner(of: $0) != nil }) {
            lines.append("- A library listed under another one *pairs with* it, such as a plugin or a binding: use them together.")
        }
        lines.append("- For a new project, start from Stack, and ask before going against it.")
        let categories = listed.leadsByCategory
        // Without categories, jobs are the sections, as before categories existed.
        let flat = categories.count == 1 && categories[0].category.isEmpty
        let shown = flat ? [] : categories.map(\.category).filter { !$0.isEmpty }

        // Rules for everything, then rules for categories that have no section of their own.
        var ownRules = playbook.rules(for: "").map { "- \(oneLine($0.text))" }
        let otherCategories = PlaybookCategories.sorted(playbook.rules.map { PlaybookCategories.canonical($0.category) }).filter { !$0.isEmpty && !shown.contains($0) }
        for category in otherCategories {
            ownRules += playbook.rules(for: category).map { "- \(category): \(oneLine($0.text))" }
        }
        if !ownRules.isEmpty {
            lines.append("")
            lines.append("## The owner's rules")
            lines.append("")
            lines.append(contentsOf: ownRules)
        }

        let skills = playbook.skills.filter { !$0.name.isEmpty }
        if !skills.isEmpty {
            lines.append("")
            lines.append("## Skills")
            lines.append("")
            lines.append("Graphitree puts these in new repos that have no setup of their own, in `.agents/skills/<name>/SKILL.md`. Each repo owns its copy after that, so it may differ from this list.")
            lines.append("")
            for skill in skills {
                var head = "- **\(skill.name)**"
                var marks: [String] = []
                if skill.drafted { marks.append("draft") }
                if skill.claudeOnly { marks.append("Claude Code only") }
                switch skill.reach {
                case .everywhere: break
                case .personal: marks.append("personal repos only")
                case .repos: marks.append(skill.repos.isEmpty ? "no repos named yet" : "only in " + skill.repos.map { "`\($0)`" }.joined(separator: ", "))
                }
                if !marks.isEmpty { head += " *\(marks.joined(separator: ", "))*" }
                let about = oneLine(skill.description)
                lines.append(about.isEmpty ? head : "\(head): \(about)")
            }
        }

        if !kept.isEmpty {
            lines.append("")
            lines.append("## Libraries")
            for group in categories {
                if !flat {
                    lines.append("")
                    lines.append("### \(group.category.isEmpty ? "Other" : group.category)")
                    let rules = playbook.rules(for: group.category)
                    if !group.category.isEmpty, !rules.isEmpty {
                        lines.append("")
                        for rule in rules { lines.append("- \(oneLine(rule.text))") }
                    }
                }
                for job in group.tasks {
                    lines.append("")
                    lines.append("\(flat ? "###" : "####") \(job.task.isEmpty ? "Other" : job.task)")
                    lines.append("")
                    for library in job.libraries {
                        lines.append(contentsOf: entry(library))
                        for (companion, depth) in listed.companionTree(of: library) {
                            let partner = listed.partner(of: companion)
                            lines.append(contentsOf: entry(companion, depth: depth, pairsWith: partner?.name ?? "", partnerTask: partner?.task ?? ""))
                        }
                    }
                }
            }
        }

        let avoided = playbook.libraries.filter(\.isAvoided)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if !avoided.isEmpty {
            lines.append("")
            lines.append("## Don't use")
            lines.append("")
            lines.append("Not for new work. Existing projects can keep them until that code is next changed.")
            lines.append("")
            for library in avoided {
                var head = "- **\(library.name)**"
                if !library.task.isEmpty { head += " (\(library.task))" }
                if !library.verified { head += " *\(library.isDescribed ? "draft" : "not described yet")*" }
                let instead = oneLine(library.useInstead)
                head += instead.isEmpty ? "" : ": use \(instead) instead."
                lines.append(head)
                let why = [library.avoidWhen, library.health].map(oneLine).first { !$0.isEmpty }
                if let why { lines.append("  Why: \(why)") }
                if !library.notes.isEmpty { lines.append("  Owner's note: \(oneLine(library.notes))") }
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

    /// One library under its job: name and marks, then what AI tools need to use it well. A library
    /// that pairs with another is nested under it, `depth` levels in.
    private static func entry(_ library: PlaybookLibrary, depth: Int = 0, pairsWith partner: String = "", partnerTask: String = "") -> [String] {
        let indent = String(repeating: "  ", count: depth)
        var lines: [String] = []
        var head = "- **\(library.name)**"
        if !library.url.isEmpty { head += " (\(library.url))" }
        var marks: [String] = []
        switch library.status {
        case .default: marks.append("default")
        case .narrow: marks.append("narrow")
        case .legacy: marks.append("legacy, not for new work")
        case .candidate: marks.append("candidate, ask first")
        case .avoid, nil: break
        }
        if !library.verified { marks.append(library.isDescribed ? "draft" : "not described yet") }
        if !marks.isEmpty { head += " *\(marks.joined(separator: ", "))*" }
        lines.append(head)
        if !partner.isEmpty {
            let task = oneLine(library.task)
            let job = task.isEmpty || task.caseInsensitiveCompare(oneLine(partnerTask)) == .orderedSame ? "" : " Job: \(sentence(task))"
            lines.append("  Pairs with: \(partner).\(job)")
        }
        if !library.purpose.isEmpty { lines.append("  \(oneLine(library.purpose))") }
        if !library.useWhen.isEmpty { lines.append("  Use when: \(oneLine(library.useWhen))") }
        if !library.avoidWhen.isEmpty { lines.append("  Avoid when: \(oneLine(library.avoidWhen))") }
        if !library.useInstead.isEmpty { lines.append("  For new work, use instead: \(oneLine(library.useInstead))") }
        var facts: [String] = []
        if !library.install.isEmpty { facts.append("Install: " + installText(library.install)) }
        if !library.platforms.isEmpty { facts.append(sentence("Works with: \(oneLine(library.platforms))")) }
        if !facts.isEmpty { lines.append("  " + facts.joined(separator: " ")) }
        if !library.health.isEmpty {
            let checked = library.checkedOn.map { " (checked \(day($0)))" } ?? ""
            lines.append("  Health\(checked): \(oneLine(library.health))")
        }
        if !library.notes.isEmpty { lines.append("  Owner's note: \(oneLine(library.notes))") }
        return lines.map { indent + $0 }
    }

    /// A date as 2026-11-23, in the Mac's time zone.
    static func day(_ date: Date) -> String {
        ISO8601DateFormatter.string(from: date, timeZone: .current, formatOptions: [.withFullDate])
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
        var jobs: [String] = []
        // Jobs in category order, so related ones sit together. Candidates aren't picks yet. A
        // library that pairs with another follows it, as "react-markdown + remark-gfm".
        for group in playbook.leadsByCategory.flatMap(\.tasks) {
            var use: [String] = []
            var keep: [String] = []
            var avoid: [String] = []
            for library in group.libraries where library.status != .candidate {
                let pairs = playbook.companionTree(of: library).map(\.library).filter { $0.status != .candidate }.map(\.name)
                let together = pairs.isEmpty ? "" : " + " + pairs.joined(separator: " + ")
                if library.isAvoided {
                    let instead = oneLine(library.useInstead)
                    avoid.append(instead.isEmpty ? library.name : "\(library.name) (use \(instead))")
                } else if library.status == .legacy {
                    keep.append(library.name + together)
                } else {
                    use.append((library.status == .narrow ? "\(library.name) (narrow)" : library.name) + together)
                }
            }
            var parts: [String] = []
            if !use.isEmpty { parts.append(use.joined(separator: ", ")) }
            if !keep.isEmpty { parts.append("keep \(keep.joined(separator: ", ")) only where it's already used") }
            if !avoid.isEmpty { parts.append("avoid \(avoid.joined(separator: ", ")) for new work") }
            guard !parts.isEmpty else { continue }
            jobs.append("- \(group.task.isEmpty ? "Other" : group.task): \(parts.joined(separator: "; "))")
        }
        if !jobs.isEmpty {
            lines.append("Libraries, by the job they do:")
            lines.append("")
            lines.append(contentsOf: jobs)
        }
        let rules = playbook.rules.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !rules.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("The owner's rules:")
            lines.append("")
            for rule in rules {
                let category = PlaybookCategories.canonical(rule.category)
                lines.append("- \(category.isEmpty ? "" : category + ": ")\(oneLine(rule.text))")
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

    static func oneLine(_ text: String) -> String {
        text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

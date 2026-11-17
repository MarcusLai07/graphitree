import Foundation
import GRDB

// The setup wizard's logic: which noise to leave out, how big graphify's answers are, and the
// files those choices are written to. Views stay in App; everything here is testable.

/// A group of `.graphifyignore` lines for one common kind of noise.
struct IgnorePreset: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let lines: [String]
    let isOnByDefault: Bool
}

enum SetupPresets {
    static let ignore: [IgnorePreset] = [
        IgnorePreset(
            id: "build", title: "Build output",
            detail: "Files your build tools make from your code, such as dist and .next.",
            lines: ["dist/", "build/", ".next/", ".nuxt/", "coverage/"], isOnByDefault: true
        ),
        IgnorePreset(
            id: "packages", title: "Installed packages",
            detail: "Code you didn't write, such as node_modules. Usually already left out by .gitignore.",
            lines: ["node_modules/", "vendor/", "Pods/", ".venv/"], isOnByDefault: true
        ),
        IgnorePreset(
            id: "generated", title: "Generated code",
            detail: "Files a tool writes for you, such as Prisma clients and protobuf stubs.",
            lines: ["generated/", "*.gen.ts", "*.generated.*", "*.pb.go", "*_pb2.py"], isOnByDefault: true
        ),
        IgnorePreset(
            id: "minified", title: "Minified and bundled files",
            detail: "One-line copies of code that's already in the graph in readable form.",
            lines: ["*.min.js", "*.min.css", "*.bundle.js"], isOnByDefault: true
        ),
        IgnorePreset(
            id: "vendored", title: "Copied-in libraries",
            detail: "Other people's code kept inside your repo, such as third_party.",
            lines: ["third_party/", "static/lib/"], isOnByDefault: true
        ),
        IgnorePreset(
            id: "tests", title: "Tests",
            detail: "A smaller graph, but AI tools won't see your tests. Keep them if you ask about test coverage.",
            lines: ["__tests__/", "*.test.ts", "*.test.tsx", "*.test.js", "*.spec.ts", "test_*.py"], isOnByDefault: false
        ),
        IgnorePreset(
            id: "data", title: "Data files",
            detail: "Spreadsheets, dumps and logs that aren't code.",
            lines: ["*.csv", "*.log", "*.parquet", "*.sql.gz"], isOnByDefault: false
        ),
    ]
}

/// `.graphifyignore`: one pattern per line, `#` comments.
enum IgnoreFile {
    static func patterns(in text: String) -> Set<String> {
        Set(text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("#") })
    }

    static func isApplied(_ preset: IgnorePreset, in text: String) -> Bool {
        let present = patterns(in: text)
        return preset.lines.allSatisfy(present.contains)
    }

    /// The lines that aren't in the file yet, in order, without repeats.
    static func additions(_ lines: [String], to text: String) -> [String] {
        var present = patterns(in: text)
        var result: [String] = []
        for line in lines.map({ $0.trimmingCharacters(in: .whitespaces) }) where !line.isEmpty && !line.hasPrefix("#") {
            if present.insert(line).inserted { result.append(line) }
        }
        return result
    }

    /// Adds lines under one dated comment. Everything already in the file stays as it was.
    static func adding(_ lines: [String], to text: String, note: String) -> String {
        let new = additions(lines, to: text)
        guard !new.isEmpty else { return text }
        var result = text
        if !result.isEmpty && !result.hasSuffix("\n") { result += "\n" }
        if !result.isEmpty { result += "\n" }
        return result + "# \(note)\n" + new.joined(separator: "\n") + "\n"
    }
}

/// `.graphifyrc`: `key=value` lines graphify reads from the graph's root folder.
enum RCFile {
    static let budgetKey = "query_budget"
    static let depthKey = "query_depth"

    static func value(_ key: String, in text: String) -> String? {
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let equals = trimmed.firstIndex(of: "=") else { continue }
            if trimmed[..<equals].trimmingCharacters(in: .whitespaces) == key {
                return trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Replaces each key's line where it is, or adds it at the end. Other lines stay.
    static func setting(_ values: [(key: String, value: String)], in text: String) -> String {
        var lines = text.isEmpty ? [] : text.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        for (key, value) in values {
            let index = lines.firstIndex { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("#"), let equals = trimmed.firstIndex(of: "=") else { return false }
                return trimmed[..<equals].trimmingCharacters(in: .whitespaces) == key
            }
            if let index { lines[index] = "\(key)=\(value)" } else { lines.append("\(key)=\(value)") }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// How much graphify returns for one question. Bigger answers cost the AI tool more tokens.
enum AnswerSize: Int, CaseIterable, Identifiable, Sendable {
    case small = 1000
    case medium = 2000
    case large = 4000

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .small: return "Short"
        case .medium: return "Medium"
        case .large: return "Long"
        }
    }
    var detail: String {
        switch self {
        case .small: return "About 1,000 tokens. Cheapest; enough for a focused question."
        case .medium: return "About 2,000 tokens. graphify's default."
        case .large: return "About 4,000 tokens. For broad questions across a big project."
        }
    }

    static func from(budget: Int?) -> AnswerSize {
        guard let budget else { return .medium }
        return allCases.min { abs($0.rawValue - budget) < abs($1.rawValue - budget) } ?? .medium
    }
}

/// How far graphify walks from the matching nodes.
enum AnswerReach: Int, CaseIterable, Identifiable, Sendable {
    case close = 1
    case usual = 2
    case wide = 3

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .close: return "Close"
        case .usual: return "Usual"
        case .wide: return "Wide"
        }
    }
    var detail: String {
        switch self {
        case .close: return "Only what the question names and its direct links."
        case .usual: return "One step further. graphify's default."
        case .wide: return "Two steps further. Finds more, and more that's off topic."
        }
    }
}

/// Whether a graph has a saved setup, so Build can rebuild straight away instead of asking again.
struct SetupRecord: @unchecked Sendable {
    static let defaultsKey = "setupApplied"
    let defaults: UserDefaults

    static let standard = SetupRecord(defaults: .standard)

    private static func key(_ root: String) -> String { URL(fileURLWithPath: root).standardizedFileURL.path }

    private var all: [String: Double] { defaults.dictionary(forKey: Self.defaultsKey) as? [String: Double] ?? [:] }

    func appliedAt(root: String) -> Date? {
        all[Self.key(root)].map { Date(timeIntervalSince1970: $0) }
    }

    func markApplied(root: String, at date: Date = .now) {
        var updated = all
        updated[Self.key(root)] = date.timeIntervalSince1970
        defaults.set(updated, forKey: Self.defaultsKey)
    }

    /// Set up means Graphitree saved a setup for this folder, or an earlier version wrote its `.graphifyrc`.
    func isSetUp(root: String) -> Bool {
        appliedAt(root: root) != nil
            || FileManager.default.fileExists(atPath: (root as NSString).appendingPathComponent(".graphifyrc"))
    }
}

/// What decides the graph's contents, read from the files graphify reads. Build shows it so the
/// person can see every setting at once, not just the cleanup rules Graphitree keeps.
struct GraphSettings: Equatable, Sendable {
    /// Patterns in the root's `.graphifyignore`. Each repo's `.gitignore` applies on top.
    var ignorePatterns = 0
    var ignoreChangedAt: Date?
    /// Nil when `.graphifyrc` doesn't set it, so graphify's default applies.
    var answerSize: AnswerSize?
    var reach: AnswerReach?

    static func read(root: String) -> GraphSettings {
        let folder = root as NSString
        let ignorePath = folder.appendingPathComponent(".graphifyignore")
        var settings = GraphSettings()
        if let text = try? String(contentsOfFile: ignorePath, encoding: .utf8) {
            settings.ignorePatterns = IgnoreFile.patterns(in: text).count
            settings.ignoreChangedAt = (try? FileManager.default.attributesOfItem(atPath: ignorePath))?[.modificationDate] as? Date
        }
        let rc = (try? String(contentsOfFile: folder.appendingPathComponent(".graphifyrc"), encoding: .utf8)) ?? ""
        settings.answerSize = RCFile.value(RCFile.budgetKey, in: rc).flatMap(Int.init).map { AnswerSize.from(budget: $0) }
        settings.reach = RCFile.value(RCFile.depthKey, in: rc).flatMap(Int.init).flatMap { AnswerReach(rawValue: min(max($0, 1), 3)) }
        return settings
    }

    /// "Medium answers, usual reach", or graphify's defaults when nothing is set.
    var answersSummary: String {
        guard answerSize != nil || reach != nil else { return "graphify's defaults" }
        return "\((answerSize ?? .medium).title) answers, \((reach ?? .usual).title.lowercased()) reach"
    }
}

extension GraphIndex {
    /// Every project with its node count, largest first.
    func projectSizes() throws -> [(project: String, nodes: Int)] {
        try queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT project, COUNT(*) FROM nodes WHERE project != ? GROUP BY project ORDER BY COUNT(*) DESC, project
                """, arguments: [SourcePath.noProject]).map { (project: $0[0] as String, nodes: $0[1] as Int) }
        }
    }

    func nodeCount(inProject project: String) throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM nodes WHERE project = ?", arguments: [project]) ?? 0
        }
    }
}

extension BuildChoice {
    /// The stored value when the person hasn't chosen: use the first model that's set up.
    static let automatic = "auto"
    /// The stored value for "code only".
    static let codeOnly = "none"

    /// What a stored choice means right now. Nil means code only.
    static func resolve(_ stored: String, options: [String]) -> String? {
        if stored == codeOnly { return nil }
        if stored.isEmpty || stored == automatic { return options.first }
        return options.contains(stored) ? stored : nil
    }
}

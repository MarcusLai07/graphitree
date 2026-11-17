import Foundation

/// `*` matches within one path segment and `**` matches any number of segments. Brackets are
/// literal because Next.js routes put them in real paths, such as `app/[id]/page.tsx`.
struct PathGlob {
    let pattern: String
    private let parts: [String]

    init(_ pattern: String) {
        self.pattern = pattern
        var expanded = pattern
        if expanded.hasSuffix("/") { expanded += "**" }
        if !expanded.contains("/") { expanded = "**/" + expanded }
        parts = expanded.split(separator: "/").map(String.init)
    }

    var isExactPath: Bool { !pattern.contains("*") && !pattern.hasSuffix("/") && pattern.contains("/") }

    func matches(_ path: String) -> Bool {
        let segments = path.split(separator: "/").map(String.init)
        return Self.match(parts[...], segments[...])
    }

    private static func match(_ pattern: ArraySlice<String>, _ path: ArraySlice<String>) -> Bool {
        guard let head = pattern.first else { return path.isEmpty }
        if head == "**" {
            let rest = pattern.dropFirst()
            if rest.isEmpty { return true }
            for start in path.startIndex...path.endIndex where match(rest, path[start...]) {
                return true
            }
            return false
        }
        guard let segment = path.first, matchSegment(Array(head.utf8), Array(segment.utf8)) else { return false }
        return match(pattern.dropFirst(), path.dropFirst())
    }

    private static func matchSegment(_ pattern: [UInt8], _ text: [UInt8]) -> Bool {
        let star = UInt8(ascii: "*")
        var p = 0, t = 0, lastStar = -1, retry = 0
        while t < text.count {
            if p < pattern.count, pattern[p] == star {
                lastStar = p
                retry = t
                p += 1
            } else if p < pattern.count, pattern[p] == text[t] {
                p += 1
                t += 1
            } else if lastStar >= 0 {
                retry += 1
                t = retry
                p = lastStar + 1
            } else {
                return false
            }
        }
        while p < pattern.count, pattern[p] == star { p += 1 }
        return p == pattern.count
    }
}

/// One line of `curation.jsonl`. Unknown ops still decode, so a newer log isn't damaged by an older app.
struct CurationEntry: Codable, Equatable, Sendable {
    var id: String
    var at: String
    var batch: String?
    var op: String
    var glob: String?
    var node: String?
    var target: String?
    var source: String?
    var relation: String?
    var scope: String?
    var label: String?
    var finding: String?
    var rule: String?
    var note: String?

    enum Op {
        static let hidePath = "hide_path"
        static let hideNode = "hide_node"
        static let hideConfigLabel = "hide_config_label"
        static let rejectEdges = "reject_edges"
        static let rejectEdge = "reject_edge"
        static let keep = "keep"
        static let revoke = "revoke"
    }
}

/// A cleanup decision, before it becomes a log entry.
enum CurationAction: Hashable, Sendable {
    case hidePath(glob: String, note: String)
    case hideNode(id: String, label: String)
    case hideConfigLabel(key: String)
    case rejectCrossLinks(node: String, label: String)
    case rejectLink(source: String, target: String, relation: String, note: String)
    case keep(findingID: String, note: String)
}

/// The append-only decision log. Existing lines are never rewritten: undo appends a `revoke`.
struct CurationLog {
    let url: URL
    private(set) var entries: [CurationEntry] = []
    private(set) var unreadableLines = 0

    init(url: URL) throws {
        self.url = url
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let text = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if let entry = try? decoder.decode(CurationEntry.self, from: Data(line.utf8)) {
                entries.append(entry)
            } else {
                unreadableLines += 1
            }
        }
    }

    private var nextNumber: Int {
        (entries.compactMap { Int($0.id.dropFirst()) }.max() ?? 0) + 1
    }

    /// Writes the whole batch in one append. Adds a newline first if a previous write was cut off.
    mutating func append(_ newEntries: [CurationEntry]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        var payload = Data()
        if let handle = try? FileHandle(forReadingFrom: url) {
            defer { try? handle.close() }
            let end = try handle.seekToEnd()
            if end > 0 {
                try handle.seek(toOffset: end - 1)
                if handle.readData(ofLength: 1) != Data([0x0A]) { payload.append(0x0A) }
            }
        }
        for entry in newEntries {
            payload.append(try encoder.encode(entry))
            payload.append(0x0A)
        }

        if !FileManager.default.fileExists(atPath: url.path) {
            try Data().write(to: url)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: payload)
        entries.append(contentsOf: newEntries)
    }

    /// Turns actions into entries that share one batch, so they undo together.
    func entries(for actions: [CurationAction], at date: Date = Date()) -> [CurationEntry] {
        let batch = UUID().uuidString.prefix(8).lowercased()
        let timestamp = ISO8601DateFormatter().string(from: date)
        var number = nextNumber
        return actions.map { action in
            defer { number += 1 }
            var entry = CurationEntry(id: "r\(number)", at: timestamp, batch: batch, op: "")
            switch action {
            case .hidePath(let glob, let note):
                entry.op = CurationEntry.Op.hidePath
                entry.glob = glob
                entry.note = note
            case .hideNode(let id, let label):
                entry.op = CurationEntry.Op.hideNode
                entry.node = id
                entry.note = label
            case .hideConfigLabel(let key):
                entry.op = CurationEntry.Op.hideConfigLabel
                entry.label = key
            case .rejectCrossLinks(let node, let label):
                entry.op = CurationEntry.Op.rejectEdges
                entry.target = node
                entry.scope = "cross_project"
                entry.note = label
            case .rejectLink(let source, let target, let relation, let note):
                entry.op = CurationEntry.Op.rejectEdge
                entry.source = source
                entry.target = target
                entry.relation = relation
                entry.note = note
            case .keep(let findingID, let note):
                entry.op = CurationEntry.Op.keep
                entry.finding = findingID
                entry.note = note
            }
            return entry
        }
    }

    func revocations(of ruleIDs: [String], at date: Date = Date()) -> [CurationEntry] {
        let timestamp = ISO8601DateFormatter().string(from: date)
        var number = nextNumber
        return ruleIDs.map { ruleID in
            defer { number += 1 }
            var entry = CurationEntry(id: "r\(number)", at: timestamp, op: CurationEntry.Op.revoke)
            entry.rule = ruleID
            return entry
        }
    }
}

struct NodeFacts {
    let id: String
    let path: String
    let project: String
    let labelKey: String
    let fileType: String?

    var isConfigKey: Bool { SourcePath.isConfigKey(labelKey: labelKey, path: path) }
}

/// The rules in force after revocations, compiled for fast matching.
/// Both the SQLite index and the clean-graph writer use this, so preview and output can't disagree.
final class RuleSet {
    let active: [CurationEntry]
    private(set) var keptFindings: Set<String> = []

    private var exactPaths: [String: String] = [:]
    private var globs: [(glob: PathGlob, rule: String)] = []
    private var nodes: [String: String] = [:]
    private var configLabels: [String: String] = [:]
    private var hubs: [String: String] = [:]
    private var pairs: [String: String] = [:]
    private var pathCache: [String: String?] = [:]

    init(entries: [CurationEntry]) {
        let revoked = Set(entries.filter { $0.op == CurationEntry.Op.revoke }.compactMap(\.rule))
        var live: [CurationEntry] = []
        for entry in entries where !revoked.contains(entry.id) {
            switch entry.op {
            case CurationEntry.Op.hidePath:
                guard let pattern = entry.glob else { continue }
                let glob = PathGlob(pattern)
                if glob.isExactPath { exactPaths[pattern] = entry.id } else { globs.append((glob, entry.id)) }
            case CurationEntry.Op.hideNode:
                guard let node = entry.node else { continue }
                nodes[node] = entry.id
            case CurationEntry.Op.hideConfigLabel:
                guard let label = entry.label else { continue }
                configLabels[label] = entry.id
            case CurationEntry.Op.rejectEdges:
                guard let target = entry.target else { continue }
                hubs[target] = entry.id
            case CurationEntry.Op.rejectEdge:
                guard let source = entry.source, let target = entry.target, let relation = entry.relation else { continue }
                pairs[Self.pairKey(source, target, relation)] = entry.id
            case CurationEntry.Op.keep:
                guard let finding = entry.finding else { continue }
                keptFindings.insert(finding)
            default:
                continue
            }
            live.append(entry)
        }
        active = live
    }

    /// Graphs are undirected and a rebuild can swap endpoints, so the key ignores direction.
    private static func pairKey(_ a: String, _ b: String, _ relation: String) -> String {
        (a < b ? "\(a)\u{1F}\(b)" : "\(b)\u{1F}\(a)") + "\u{1F}\(relation)"
    }

    private func pathRule(_ path: String) -> String? {
        if let cached = pathCache[path] { return cached }
        let rule = exactPaths[path] ?? globs.first(where: { $0.glob.matches(path) })?.rule
        pathCache[path] = .some(rule)
        return rule
    }

    /// The rule hiding this node, if any.
    func hidingRule(for node: NodeFacts) -> String? {
        if let rule = nodes[node.id] { return rule }
        if !node.path.isEmpty, let rule = pathRule(node.path) { return rule }
        if node.isConfigKey { return configLabels[node.labelKey] }
        return nil
    }

    /// The rule rejecting this edge, if any. Hub rejection only touches suspect links, so
    /// semantic links between projects survive it.
    func rejectingRule(source: String, target: String, relation: String, isSuspect: Bool) -> String? {
        if let rule = pairs[Self.pairKey(source, target, relation)] { return rule }
        guard isSuspect else { return nil }
        return hubs[source] ?? hubs[target]
    }
}

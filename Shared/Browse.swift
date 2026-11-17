import Foundation
import GRDB

/// One row of the project, community, file, symbol outline.
struct OutlineItem: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case project(String)
        case community(project: String, id: Int?)
        case file(project: String, community: Int?, path: String)
        case symbol(id: String, path: String, location: String?)
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let count: Int
    let hiddenCount: Int

    var id: String {
        switch kind {
        case .project(let project): return "p|\(project)"
        case .community(let project, let id): return "c|\(project)|\(id.map(String.init) ?? "-")"
        case .file(let project, let community, let path): return "f|\(project)|\(community.map(String.init) ?? "-")|\(path)"
        case .symbol(let id, _, _): return "s|\(id)"
        }
    }

    var isExpandable: Bool {
        if case .symbol = kind { return false }
        return true
    }

    var isHidden: Bool { count > 0 && hiddenCount >= count }
}

struct NeighbourRow: Identifiable, Hashable, Sendable {
    let id: String
    let nodeID: String
    let label: String
    let project: String
    let relation: String
    let confidence: String
    let isRemoved: Bool
}

struct NodeDetail: Sendable {
    let id: String
    let label: String
    let path: String
    let location: String?
    let project: String
    let fileType: String?
    let communityLabel: String?
    let isHidden: Bool
    let hidingRuleID: String?
    let hidingRuleSummary: String?
    /// Where the source file is on disk, or nil if it's gone.
    let absolutePath: String?
    let neighbours: [NeighbourRow]
    let neighbourTotal: Int
}

enum EditorLink {
    /// `L153` is line 153.
    static func line(from location: String?) -> Int? {
        guard let location, location.hasPrefix("L") else { return nil }
        return Int(location.dropFirst().prefix { $0.isNumber })
    }

    static func vscodeURL(path: String, line: Int?) -> URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: ":?#[]")
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "vscode://file\(encoded)" + (line.map { ":\($0)" } ?? ""))
    }
}

extension GraphIndex {
    // MARK: - Search

    /// Finds nodes by label or path, best matches first. Hidden nodes are included.
    func search(_ text: String, limit: Int = 200) throws -> [OutlineItem] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)

        return try queue.read { db in
            // The trigram index can't see terms under three characters.
            let filter: String
            var arguments: [DatabaseValueConvertible] = []
            if terms.allSatisfy({ $0.count >= 3 }) {
                let match = terms.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: " AND ")
                filter = "n.id IN (SELECT id FROM nodes_fts WHERE nodes_fts MATCH ?)"
                arguments.append(match)
            } else {
                filter = terms.map { _ in "(n.label LIKE ? ESCAPE '\\' OR n.source_file LIKE ? ESCAPE '\\')" }.joined(separator: " AND ")
                for term in terms {
                    let escaped = term
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "%", with: "\\%")
                        .replacingOccurrences(of: "_", with: "\\_")
                    arguments.append("%\(escaped)%")
                    arguments.append("%\(escaped)%")
                }
            }
            let lowered = query.lowercased()
            arguments.append(lowered)
            arguments.append(lowered + "%")
            arguments.append(limit)

            return try Row.fetchAll(db, sql: """
                SELECT n.id, n.label, n.source_file, n.source_location, n.degree, n.hidden FROM nodes n
                WHERE \(filter)
                ORDER BY lower(n.label) = ? DESC, lower(n.label) LIKE ? DESC, n.degree DESC
                LIMIT ?
                """, arguments: StatementArguments(arguments)).map(Self.symbolItem)
        }
    }

    private static func symbolItem(_ row: Row) -> OutlineItem {
        let path: String = row[2]
        let location: String? = row[3]
        return OutlineItem(
            kind: .symbol(id: row[0], path: path, location: location),
            title: row[1],
            subtitle: path.isEmpty ? "No source file" : path + (location.map { " " + $0 } ?? ""),
            count: row[4],
            hiddenCount: (row[5] as Int) != 0 ? max(row[4], 1) : 0
        )
    }

    // MARK: - Outline

    /// Children of an outline row, or the top level when `parent` is nil.
    func outlineChildren(of parent: OutlineItem?) throws -> [OutlineItem] {
        try queue.read { db in
            guard let parent else { return try Self.topLevel(db) }
            switch parent.kind {
            case .project(let project):
                return try Self.communities(db, project: project)
            case .community(let project, let community):
                return try Self.files(db, project: project, community: community)
            case .file(let project, let community, let path):
                return try Row.fetchAll(db, sql: """
                    SELECT id, label, source_file, source_location, degree, hidden FROM nodes
                    WHERE project = ? AND community IS ? AND source_file = ?
                    ORDER BY degree DESC, label
                    """, arguments: [project, community, path]).map(Self.symbolItem)
            case .symbol:
                return []
            }
        }
    }

    /// A single-project graph opens straight onto its communities.
    private static func topLevel(_ db: Database) throws -> [OutlineItem] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT project, COUNT(*), SUM(hidden) FROM nodes GROUP BY project ORDER BY 2 DESC
            """)
        let real = rows.filter { ($0[0] as String) != SourcePath.noProject }
        if real.count == 1, rows.count == 1 {
            return try communities(db, project: real[0][0])
        }
        return rows.map { row in
            let project: String = row[0]
            return OutlineItem(
                kind: .project(project),
                title: project,
                subtitle: "",
                count: row[1],
                hiddenCount: row[2] ?? 0
            )
        }
    }

    private static func communities(_ db: Database, project: String) throws -> [OutlineItem] {
        try Row.fetchAll(db, sql: """
            SELECT n.community, COUNT(*), SUM(n.hidden), c.label FROM nodes n
            LEFT JOIN communities c ON c.id = n.community
            WHERE n.project = ? GROUP BY n.community ORDER BY 2 DESC
            """, arguments: [project]).map { row in
            let community: Int? = row[0]
            let label: String? = row[3]
            return OutlineItem(
                kind: .community(project: project, id: community),
                title: label ?? community.map { "Community \($0)" } ?? "No community",
                subtitle: "",
                count: row[1],
                hiddenCount: row[2] ?? 0
            )
        }
    }

    private static func files(_ db: Database, project: String, community: Int?) throws -> [OutlineItem] {
        try Row.fetchAll(db, sql: """
            SELECT source_file, COUNT(*), SUM(hidden) FROM nodes
            WHERE project = ? AND community IS ? GROUP BY source_file ORDER BY 2 DESC, 1
            """, arguments: [project, community]).map { row in
            let path: String = row[0]
            return OutlineItem(
                kind: .file(project: project, community: community, path: path),
                title: path.isEmpty ? "No source file" : (path as NSString).lastPathComponent,
                subtitle: path,
                count: row[1],
                hiddenCount: row[2] ?? 0
            )
        }
    }

    // MARK: - Node detail

    func nodeRow(id: String) throws -> (facts: NodeFacts, label: String, location: String?, communityLabel: String?, hidden: Bool)? {
        try queue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT n.id, n.source_file, n.project, n.label_key, n.file_type, n.label, n.source_location,
                       COALESCE(c.label, 'Community ' || n.community), n.hidden
                FROM nodes n LEFT JOIN communities c ON c.id = n.community WHERE n.id = ?
                """, arguments: [id]) else { return nil }
            let facts = NodeFacts(id: row[0], path: row[1], project: row[2], labelKey: row[3], fileType: row[4])
            return (facts, row[5], row[6], row[7], (row[8] as Int) != 0)
        }
    }

    func neighbours(of id: String, limit: Int = 300) throws -> (rows: [NeighbourRow], total: Int) {
        try queue.read { db in
            let total = try Int.fetchOne(db, sql: """
                SELECT (SELECT COUNT(*) FROM edges WHERE source = :id) + (SELECT COUNT(*) FROM edges WHERE target = :id AND source != :id)
                """, arguments: ["id": id]) ?? 0
            let rows = try Row.fetchAll(db, sql: """
                SELECT n.id, n.label, n.project, e.relation, e.confidence, e.removed, e.rowid
                FROM edges e JOIN nodes n ON n.id = CASE WHEN e.source = :id THEN e.target ELSE e.source END
                WHERE e.source = :id OR e.target = :id
                ORDER BY e.removed, n.degree DESC LIMIT :limit
                """, arguments: ["id": id, "limit": limit]).map { row in
                NeighbourRow(
                    id: String(row[6] as Int64),
                    nodeID: row[0],
                    label: row[1],
                    project: row[2],
                    relation: row[3] ?? "",
                    confidence: row[4] ?? "",
                    isRemoved: (row[5] as Int) != 0
                )
            }
            return (rows, total)
        }
    }
}

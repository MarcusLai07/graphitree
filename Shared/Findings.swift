import Foundation
import GRDB

enum Detector: String, CaseIterable, Identifiable, Hashable, Sendable {
    case generated, crossProject, duplicates, missing, configLabels, isolated, noSource

    var id: String { rawValue }

    var title: String {
        switch self {
        case .generated: return "Generated Code"
        case .crossProject: return "Cross-Project Links"
        case .duplicates: return "Indexed Twice"
        case .missing: return "Missing Files"
        case .configLabels: return "Config Keys"
        case .isolated: return "Isolated Nodes"
        case .noSource: return "No Source File"
        }
    }

    var symbol: String {
        switch self {
        case .generated: return "gearshape.2"
        case .crossProject: return "link"
        case .duplicates: return "square.on.square"
        case .missing: return "doc.badge.ellipsis"
        case .configLabels: return "curlybraces"
        case .isolated: return "circle.dotted"
        case .noSource: return "questionmark.folder"
        }
    }

    var removeTitle: String { self == .crossProject ? "Reject Links" : "Hide" }

    var explanation: String {
        switch self {
        case .generated:
            return "Build output and third-party code. Add it to .graphifyignore to stop extracting it at all."
        case .crossProject:
            return "Code resolved to a symbol in a different project, usually because the names match. Semantic links between projects aren't listed."
        case .duplicates:
            return "The same files appear under two project paths, usually because a project moved."
        case .missing:
            return "These nodes point at files that have moved or been deleted."
        case .configLabels:
            return "Keys from files like package.json that repeat across projects and carry little meaning."
        case .isolated:
            return "Nothing links to these nodes."
        case .noSource:
            return "External or unresolved symbols, such as standard library types. They can connect unrelated code."
        }
    }
}

struct Finding: Identifiable, Hashable, Sendable {
    /// Stable across rebuilds where possible, because "keep" decisions refer to it.
    let id: String
    let detector: Detector
    /// What the details query looks up: a node, a folder, a project or a label.
    let anchor: String
    let title: String
    let location: String
    let project: String
    let count: Int
    let unit: String
    let note: String
    let removal: CurationAction
    /// Set when this can also be excluded from future graphify builds.
    let ignoreLine: String?

    var affects: String { "\(count.formatted()) \(unit)" }
}

struct FindingDetail: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let trailing: String
    /// Present when this one item can be rejected on its own.
    let rejection: CurationAction?
}

extension GraphIndex {
    func findings(rules: RuleSet) throws -> [Detector: [Finding]] {
        let kept = rules.keptFindings
        let root = source.rootPath
        let isSingleRepo = source.scheme.singleRepoName != nil
        return try queue.read { db in
            let all: [Detector: [Finding]] = [
                .generated: try Self.generated(db),
                .crossProject: try Self.crossProject(db, kept: kept),
                .duplicates: try Self.duplicates(db, root: root),
                .missing: try Self.missing(db, root: root, isSingleRepo: isSingleRepo),
                .configLabels: try Self.configLabels(db),
                .isolated: try Self.isolated(db),
                .noSource: try Self.noSource(db),
            ]
            return all.mapValues { $0.filter { !kept.contains($0.id) } }
        }
    }

    private static func plural(_ count: Int, _ singular: String) -> String {
        count == 1 ? singular : singular + "s"
    }

    private static func generated(_ db: Database) throws -> [Finding] {
        try Row.fetchAll(db, sql: """
            SELECT noise_group, MIN(project), COUNT(*), COUNT(DISTINCT source_file)
            FROM nodes WHERE hidden = 0 AND noise_group IS NOT NULL GROUP BY noise_group
            """).map { row in
            let group: String = row[0]
            let nodes: Int = row[2]
            let files: Int = row[3]
            let isFolder = group.hasSuffix("/")
            return Finding(
                id: "generated:\(group)",
                detector: .generated,
                anchor: group,
                title: (group as NSString).lastPathComponent + (isFolder ? "/" : ""),
                location: group,
                project: row[1],
                count: nodes,
                unit: plural(nodes, "node"),
                note: "\(files.formatted()) \(plural(files, "file"))",
                removal: .hidePath(glob: isFolder ? group + "**" : group, note: group),
                ignoreLine: SourcePath.ignoreLine(for: group)
            )
        }
    }

    /// Each suspect edge is listed under whichever endpoint has more of them, so a hub like
    /// `Json` gets one row instead of one row per caller.
    private static func crossProject(_ db: Database, kept: Set<String>) throws -> [Finding] {
        let keptNodes = Set(kept.filter { $0.hasPrefix("cross:") }.map { String($0.dropFirst(6)) })
        let edges = try Row.fetchAll(db, sql: "SELECT source, target FROM edges WHERE removed = 0 AND suspect_cross = 1")
            .map { (source: $0[0] as String, target: $0[1] as String) }
            .filter { !keptNodes.contains($0.source) && !keptNodes.contains($0.target) }

        var touches: [String: Int] = [:]
        for edge in edges {
            touches[edge.source, default: 0] += 1
            touches[edge.target, default: 0] += 1
        }

        var hubs = Set<String>()
        var otherProjects: [String: Set<String>] = [:]
        var nodeInfo: [String: (label: String, project: String, path: String)] = [:]
        let rows = try Row.fetchCursor(db, sql: """
            SELECT id, label, project, source_file FROM nodes WHERE id IN (
                SELECT source FROM edges WHERE removed = 0 AND suspect_cross = 1
                UNION SELECT target FROM edges WHERE removed = 0 AND suspect_cross = 1
            )
            """)
        while let row = try rows.next() {
            nodeInfo[row[0]] = (row[1], row[2], row[3])
        }
        for edge in edges {
            let sourceCount = touches[edge.source] ?? 0
            let targetCount = touches[edge.target] ?? 0
            hubs.insert(sourceCount > targetCount ? edge.source : edge.target)
            if let project = nodeInfo[edge.target]?.project { otherProjects[edge.source, default: []].insert(project) }
            if let project = nodeInfo[edge.source]?.project { otherProjects[edge.target, default: []].insert(project) }
        }

        return hubs.compactMap { hub -> Finding? in
            guard let info = nodeInfo[hub] else { return nil }
            let count = touches[hub] ?? 0
            let projects = otherProjects[hub]?.count ?? 0
            return Finding(
                id: "cross:\(hub)",
                detector: .crossProject,
                anchor: hub,
                title: info.label,
                location: info.path,
                project: info.project,
                count: count,
                unit: plural(count, "link"),
                note: "From \(projects) other \(plural(projects, "project"))",
                removal: .rejectCrossLinks(node: hub, label: info.label),
                ignoreLine: nil
            )
        }
    }

    private static func duplicates(_ db: Database, root: String) throws -> [Finding] {
        var suffixes: [String: Set<String>] = [:]
        var nodeCounts: [String: Int] = [:]
        let rows = try Row.fetchCursor(db, sql: """
            SELECT project, source_file, COUNT(*) FROM nodes
            WHERE hidden = 0 AND source_file != '' GROUP BY project, source_file
            """)
        while let row = try rows.next() {
            let project: String = row[0]
            let path: String = row[1]
            suffixes[project, default: []].insert(String(path.dropFirst(project.count + 1)))
            nodeCounts[project, default: 0] += row[2] as Int
        }

        let fileManager = FileManager.default
        func exists(_ project: String) -> Bool {
            fileManager.fileExists(atPath: SourcePath.absolute(project, root: root))
        }

        var results: [Finding] = []
        let projects = suffixes.keys.sorted()
        for (offset, first) in projects.enumerated() {
            for second in projects[(offset + 1)...] {
                guard let a = suffixes[first], let b = suffixes[second] else { continue }
                let shared = a.intersection(b).count
                guard shared >= 20, Double(shared) / Double(min(a.count, b.count)) >= 0.5 else { continue }

                // Hide whichever copy is gone from disk, otherwise the smaller one.
                let stale: String
                if !exists(first) && exists(second) {
                    stale = first
                } else if exists(first) && !exists(second) {
                    stale = second
                } else {
                    stale = a.count <= b.count ? first : second
                }
                let other = stale == first ? second : first
                let nodes = nodeCounts[stale] ?? 0
                results.append(Finding(
                    id: "duplicate:\(stale)",
                    detector: .duplicates,
                    anchor: stale,
                    title: stale,
                    location: "Also indexed as \(other)",
                    project: stale,
                    count: nodes,
                    unit: plural(nodes, "node"),
                    note: "\(shared.formatted()) shared files",
                    removal: .hidePath(glob: stale + "/**", note: "Duplicate of \(other)"),
                    ignoreLine: nil
                ))
            }
        }
        return results
    }

    /// A project that is gone entirely gets one row. Otherwise each missing file gets its own.
    private static func missing(_ db: Database, root: String, isSingleRepo: Bool) throws -> [Finding] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT f.path, f.project, COUNT(n.id) FROM files f JOIN nodes n ON n.source_file = f.path
            WHERE f.is_missing = 1 AND n.hidden = 0 GROUP BY f.path
            """)

        let fileManager = FileManager.default
        var goneProjects: [String: (files: Int, nodes: Int)] = [:]
        var results: [Finding] = []
        for row in rows {
            let path: String = row[0]
            let project: String = row[1]
            let nodes: Int = row[2]
            if !isSingleRepo, !fileManager.fileExists(atPath: SourcePath.absolute(project, root: root)) {
                goneProjects[project, default: (0, 0)].files += 1
                goneProjects[project, default: (0, 0)].nodes += nodes
                continue
            }
            results.append(Finding(
                id: "missing:\(path)",
                detector: .missing,
                anchor: path,
                title: (path as NSString).lastPathComponent,
                location: path,
                project: project,
                count: nodes,
                unit: plural(nodes, "node"),
                note: "File is gone",
                removal: .hidePath(glob: path, note: "Missing file"),
                ignoreLine: nil
            ))
        }
        for (project, totals) in goneProjects {
            results.append(Finding(
                id: "missing:\(project)",
                detector: .missing,
                anchor: project,
                title: project,
                location: "Project folder is gone",
                project: project,
                count: totals.nodes,
                unit: plural(totals.nodes, "node"),
                note: "\(totals.files.formatted()) \(plural(totals.files, "file"))",
                removal: .hidePath(glob: project + "/**", note: "Missing project"),
                ignoreLine: nil
            ))
        }
        return results
    }

    private static func configLabels(_ db: Database) throws -> [Finding] {
        try Row.fetchAll(db, sql: """
            SELECT label_key, MIN(label), COUNT(*), COUNT(DISTINCT project) FROM nodes
            WHERE hidden = 0 AND config_key = 1 GROUP BY label_key HAVING COUNT(DISTINCT project) > 1
            """).map { row in
            let key: String = row[0]
            let nodes: Int = row[2]
            let projects: Int = row[3]
            return Finding(
                id: "label:\(key)",
                detector: .configLabels,
                anchor: key,
                title: row[1],
                location: "In config files only",
                project: "\(projects) projects",
                count: nodes,
                unit: plural(nodes, "node"),
                note: "",
                removal: .hideConfigLabel(key: key),
                ignoreLine: nil
            )
        }
    }

    private static func isolated(_ db: Database) throws -> [Finding] {
        try Row.fetchAll(db, sql: """
            SELECT n.id, n.label, n.project, n.source_file, n.file_type FROM nodes n WHERE n.hidden = 0
            AND NOT EXISTS (SELECT 1 FROM edges e WHERE e.source = n.id AND e.removed = 0)
            AND NOT EXISTS (SELECT 1 FROM edges e WHERE e.target = n.id AND e.removed = 0)
            """).map { row in
            let id: String = row[0]
            let label: String = row[1]
            return Finding(
                id: "isolated:\(id)",
                detector: .isolated,
                anchor: id,
                title: label,
                location: row[3],
                project: row[2],
                count: 1,
                unit: "node",
                note: row[4] ?? "",
                removal: .hideNode(id: id, label: label),
                ignoreLine: nil
            )
        }
    }

    private static func noSource(_ db: Database) throws -> [Finding] {
        try Row.fetchAll(db, sql: """
            SELECT n.id, n.label, (
                SELECT COUNT(*) FROM edges e WHERE e.removed = 0 AND e.source = n.id
            ) + (
                SELECT COUNT(*) FROM edges e WHERE e.removed = 0 AND e.target = n.id
            ) FROM nodes n WHERE n.hidden = 0 AND n.source_file = ''
            """).map { row in
            let id: String = row[0]
            let label: String = row[1]
            let links: Int = row[2]
            return Finding(
                id: "nosource:\(id)",
                detector: .noSource,
                anchor: id,
                title: label,
                location: "No source file",
                project: SourcePath.noProject,
                count: links,
                unit: plural(links, "link"),
                note: "",
                removal: .hideNode(id: id, label: label),
                ignoreLine: nil
            )
        }
    }

    // MARK: - Details

    /// What a finding covers, for review before acting on it. Capped so a huge hub stays responsive.
    func details(for finding: Finding, limit: Int = 300) throws -> [FindingDetail] {
        try queue.read { db in
            switch finding.detector {
            case .generated:
                return try Self.fileDetails(db, whereClause: "noise_group = ?", anchor: finding.anchor, limit: limit)
            case .duplicates:
                return try Self.fileDetails(db, whereClause: "project = ?", anchor: finding.anchor, limit: limit)
            case .missing:
                let column = finding.anchor == finding.project ? "project" : "source_file"
                return try Self.fileDetails(db, whereClause: "\(column) = ?", anchor: finding.anchor, limit: limit)
            case .configLabels:
                return try Row.fetchAll(db, sql: """
                    SELECT id, label, source_file, project FROM nodes
                    WHERE hidden = 0 AND config_key = 1 AND label_key = ? ORDER BY project LIMIT ?
                    """, arguments: [finding.anchor, limit]).map {
                    FindingDetail(id: $0[0], title: $0[1], subtitle: $0[2], trailing: $0[3], rejection: nil)
                }
            case .crossProject:
                return try Self.linkDetails(db, node: finding.anchor, suspectOnly: true, limit: limit)
            case .isolated, .noSource:
                return try Self.linkDetails(db, node: finding.anchor, suspectOnly: false, limit: limit)
            }
        }
    }

    private static func fileDetails(_ db: Database, whereClause: String, anchor: String, limit: Int) throws -> [FindingDetail] {
        try Row.fetchAll(db, sql: """
            SELECT source_file, COUNT(*) FROM nodes WHERE hidden = 0 AND \(whereClause)
            GROUP BY source_file ORDER BY 2 DESC LIMIT ?
            """, arguments: [anchor, limit]).map { row in
            let path: String = row[0]
            let nodes: Int = row[1]
            return FindingDetail(
                id: path,
                title: (path as NSString).lastPathComponent,
                subtitle: path,
                trailing: nodes.formatted(),
                rejection: nil
            )
        }
    }

    private static func linkDetails(_ db: Database, node: String, suspectOnly: Bool, limit: Int) throws -> [FindingDetail] {
        let hubLabel = try String.fetchOne(db, sql: "SELECT label FROM nodes WHERE id = ?", arguments: [node]) ?? node
        return try Row.fetchAll(db, sql: """
            SELECT e.source, e.target, e.relation, n.label, n.project, n.source_file
            FROM edges e JOIN nodes n ON n.id = CASE WHEN e.source = :node THEN e.target ELSE e.source END
            WHERE e.removed = 0 AND (e.source = :node OR e.target = :node)
            AND (:all = 1 OR e.suspect_cross = 1)
            ORDER BY n.project, n.label LIMIT :limit
            """, arguments: ["node": node, "all": !suspectOnly, "limit": limit]).map { row in
            let source: String = row[0]
            let target: String = row[1]
            let relation: String = row[2] ?? ""
            let label: String = row[3]
            return FindingDetail(
                id: "\(source)\u{1F}\(target)\u{1F}\(relation)",
                title: label,
                subtitle: row[5],
                trailing: relation,
                rejection: suspectOnly
                    ? .rejectLink(source: source, target: target, relation: relation, note: "\(label) to \(hubLabel)")
                    : nil
            )
        }
    }
}

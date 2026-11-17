import CryptoKit
import Foundation
import GRDB

enum IndexPhase: String, Sendable {
    case reading = "Reading graph.json…"
    case parsing = "Parsing the graph…"
    case indexing = "Building the index…"
    case checkingFiles = "Checking source files…"
    case summarising = "Summarising…"
    case mapping = "Mapping this folder's code. A big folder takes a few minutes…"
}

enum GraphIndexError: LocalizedError, Equatable {
    case graphNotFound(String)
    case accessDenied(String)

    var errorDescription: String? {
        switch self {
        case .graphNotFound(let path):
            return "No graph.json found in \(path)."
        case .accessDenied(let path):
            return "macOS blocked access to \(path). Allow Graphitree under System Settings > Privacy & Security > Files & Folders."
        }
    }
}

/// A disposable SQLite copy of `graph.json`. Rebuilt whenever the graph file changes.
/// Never writes to the graphify output folder.
final class GraphIndex {
    /// Bump when the schema or the classification rules change, so old indexes get rebuilt.
    static let schemaVersion = 4

    let source: GraphSource
    let graphModifiedAt: Date
    /// True when this open had to parse `graph.json`, false when the cached index was reused.
    let didImport: Bool

    let queue: DatabaseQueue

    private init(source: GraphSource, graphModifiedAt: Date, didImport: Bool, queue: DatabaseQueue) {
        self.source = source
        self.graphModifiedAt = graphModifiedAt
        self.didImport = didImport
        self.queue = queue
    }

    static func defaultCacheDirectory() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Graphitree/Indexes", isDirectory: true)
    }

    /// Opens the index for `source`, importing first if needed. This does seconds of work on a
    /// 74 MB graph, so it must not run on the main thread.
    static func open(
        source: GraphSource,
        cacheDirectory: URL,
        progress: @Sendable (IndexPhase) -> Void = { _ in }
    ) throws -> GraphIndex {
        dispatchPrecondition(condition: .notOnQueue(.main))

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.attributesOfItem(atPath: source.graphURL.path)
        } catch {
            throw translate(error, path: source.outDirectory.path)
        }
        let modifiedAt = attributes[.modificationDate] as? Date ?? .distantPast
        let size = attributes[.size] as? Int ?? 0
        // Community names live in their own file and can change without the graph changing.
        let labels = try? fileManager.attributesOfItem(atPath: source.labelsURL.path)
        let labelStamp = (labels?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        // Which folders hold projects changes every node's project, so it's part of the signature.
        let groups = source.scheme.groups.sorted().joined(separator: ",")
        let signature = "\(schemaVersion):\(size):\(modifiedAt.timeIntervalSince1970):\(labelStamp):\(source.scheme.singleRepoName ?? ""):\(groups)"

        let indexPath = cacheDirectory.appendingPathComponent(cacheName(for: source)).path
        let isCurrent = storedSignature(at: indexPath) == signature
        if !isCurrent {
            try buildIndex(source: source, signature: signature, destination: indexPath, progress: progress)
        }

        let index = GraphIndex(
            source: source,
            graphModifiedAt: modifiedAt,
            didImport: !isCurrent,
            queue: try DatabaseQueue(path: indexPath)
        )
        progress(.checkingFiles)
        try index.refreshMissingFiles()
        return index
    }

    private static func cacheName(for source: GraphSource) -> String {
        let digest = SHA256.hash(data: Data(source.outDirectory.standardizedFileURL.path.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined() + ".sqlite"
    }

    private static func storedSignature(at path: String) -> String? {
        guard FileManager.default.fileExists(atPath: path),
              let queue = try? DatabaseQueue(path: path) else { return nil }
        defer { try? queue.close() }
        return try? queue.read {
            try String.fetchOne($0, sql: "SELECT value FROM meta WHERE key = 'signature'")
        }
    }

    static func translate(_ error: Error, path: String) -> Error {
        let nsError = error as NSError
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileNoSuchFileError || nsError.code == NSFileReadNoSuchFileError {
            return GraphIndexError.graphNotFound(path)
        }
        if nsError.code == NSFileReadNoPermissionError
            || (underlying?.domain == NSPOSIXErrorDomain && [EPERM, EACCES].contains(Int32(underlying?.code ?? 0))) {
            return GraphIndexError.accessDenied(path)
        }
        return error
    }

    // MARK: - Import

    /// Builds in a temp file and renames it into place, so a failed import leaves any previous index intact.
    private static func buildIndex(
        source: GraphSource,
        signature: String,
        destination: String,
        progress: @Sendable (IndexPhase) -> Void
    ) throws {
        progress(.reading)
        let data: Data
        do {
            data = try Data(contentsOf: source.graphURL, options: .mappedIfSafe)
        } catch {
            throw translate(error, path: source.outDirectory.path)
        }

        progress(.parsing)
        let graph = try JSONDecoder().decode(RawGraph.self, from: data)

        progress(.indexing)
        let temporary = destination + ".\(UUID().uuidString).tmp"
        defer { try? FileManager.default.removeItem(atPath: temporary) }

        var configuration = Configuration()
        configuration.prepareDatabase { db in
            // The temp file is thrown away on failure, so durability costs time for nothing.
            try db.execute(sql: "PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF")
        }
        let queue = try DatabaseQueue(path: temporary, configuration: configuration)
        try queue.write { db in
            try createSchema(db)
            try insert(graph, scheme: source.scheme, labels: communityLabels(source), into: db)
            try db.execute(sql: "INSERT INTO meta(key, value) VALUES ('signature', ?)", arguments: [signature])
        }
        try queue.close()

        guard rename(temporary, destination) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }

    private static func communityLabels(_ source: GraphSource) -> [Int: String] {
        guard let data = try? Data(contentsOf: source.labelsURL),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in Int(key).map { ($0, value) } })
    }

    private static func createSchema(_ db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE nodes (
                id TEXT PRIMARY KEY,
                label TEXT NOT NULL,
                label_key TEXT NOT NULL,
                file_type TEXT,
                source_file TEXT NOT NULL,
                source_location TEXT,
                community INTEGER,
                project TEXT NOT NULL,
                noise_kind TEXT,
                noise_group TEXT,
                config_key INTEGER NOT NULL,
                degree INTEGER NOT NULL,
                hidden INTEGER NOT NULL DEFAULT 0
            ) WITHOUT ROWID;
            CREATE TABLE edges (
                source TEXT NOT NULL,
                target TEXT NOT NULL,
                relation TEXT,
                confidence TEXT,
                cross_project INTEGER NOT NULL,
                suspect_cross INTEGER NOT NULL,
                removed INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE communities (id INTEGER PRIMARY KEY, label TEXT NOT NULL);
            CREATE VIRTUAL TABLE nodes_fts USING fts5(id UNINDEXED, label, path, tokenize = 'trigram');
            CREATE TABLE files (
                path TEXT PRIMARY KEY,
                project TEXT NOT NULL,
                node_count INTEGER NOT NULL,
                is_missing INTEGER NOT NULL DEFAULT 0
            ) WITHOUT ROWID;
            """)
    }

    private static func insert(_ graph: RawGraph, scheme: ProjectScheme, labels: [Int: String], into db: Database) throws {
        var projectByNode: [String: String] = [:]
        projectByNode.reserveCapacity(graph.nodes.count)
        var codeNodes = Set<String>()
        var projectByPath: [String: String] = [:]
        var noiseByPath: [String: NoiseKind?] = [:]
        var groupByPath: [String: String?] = [:]
        var nodeCountByPath: [String: Int] = [:]

        for node in graph.nodes {
            let path = node.sourceFile ?? ""
            let project: String
            if let known = projectByPath[path] {
                project = known
            } else {
                project = scheme.project(of: path)
                projectByPath[path] = project
                noiseByPath[path] = SourcePath.noiseKind(of: path)
                groupByPath[path] = SourcePath.noiseGroup(of: path)
            }
            projectByNode[node.id] = project
            if node.fileType == "code" { codeNodes.insert(node.id) }
            if !path.isEmpty { nodeCountByPath[path, default: 0] += 1 }
        }

        var degree: [String: Int] = [:]
        degree.reserveCapacity(graph.nodes.count)
        let insertEdge = try db.makeStatement(sql: """
            INSERT INTO edges(source, target, relation, confidence, cross_project, suspect_cross)
            VALUES (?, ?, ?, ?, ?, ?)
            """)
        for edge in graph.edges {
            degree[edge.source, default: 0] += 1
            degree[edge.target, default: 0] += 1
            let sourceProject = projectByNode[edge.source]
            let targetProject = projectByNode[edge.target]
            try insertEdge.execute(arguments: [
                edge.source, edge.target, edge.relation, edge.confidence,
                EdgeKind.isCrossProject(sourceProject, targetProject),
                EdgeKind.isSuspect(
                    relation: edge.relation,
                    sourceProject: sourceProject,
                    targetProject: targetProject,
                    bothCode: codeNodes.contains(edge.source) && codeNodes.contains(edge.target)
                ),
            ])
        }

        let insertNode = try db.makeStatement(sql: """
            INSERT OR REPLACE INTO nodes(
                id, label, label_key, file_type, source_file, source_location,
                community, project, noise_kind, noise_group, config_key, degree
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """)
        for node in graph.nodes {
            let path = node.sourceFile ?? ""
            let labelKey = node.normLabel.flatMap { $0.isEmpty ? nil : $0 } ?? node.label
            try insertNode.execute(arguments: [
                node.id, node.label, labelKey, node.fileType, path, node.sourceLocation,
                node.community, projectByPath[path], noiseByPath[path]??.rawValue, groupByPath[path] ?? nil,
                SourcePath.isConfigKey(labelKey: labelKey, path: path), degree[node.id] ?? 0,
            ])
        }

        let insertFile = try db.makeStatement(sql: "INSERT INTO files(path, project, node_count) VALUES (?, ?, ?)")
        for (path, count) in nodeCountByPath {
            try insertFile.execute(arguments: [path, projectByPath[path], count])
        }

        let insertCommunity = try db.makeStatement(sql: "INSERT OR REPLACE INTO communities(id, label) VALUES (?, ?)")
        for (id, label) in labels {
            try insertCommunity.execute(arguments: [id, label])
        }

        try db.execute(sql: """
            INSERT INTO nodes_fts(id, label, path) SELECT id, label, source_file FROM nodes;
            CREATE INDEX nodes_project_community ON nodes(project, community);
            CREATE INDEX nodes_source_file ON nodes(source_file);
            CREATE INDEX edges_source ON edges(source);
            CREATE INDEX edges_target ON edges(target);
            """)
    }

    // MARK: - File state

    /// Files can vanish without `graph.json` changing, so this runs on every open.
    private func refreshMissingFiles() throws {
        let fileManager = FileManager.default
        let root = source.rootPath
        // If the root is unreadable every file would look missing, which is a false report. Fail instead.
        do {
            _ = try fileManager.contentsOfDirectory(atPath: root)
        } catch {
            throw Self.translate(error, path: root)
        }

        let paths = try queue.read { try String.fetchAll($0, sql: "SELECT path FROM files") }
        let missing = paths.filter { source.existingPath(for: $0) == nil }
        try queue.write { db in
            try db.execute(sql: "UPDATE files SET is_missing = 0")
            let mark = try db.makeStatement(sql: "UPDATE files SET is_missing = 1 WHERE path = ?")
            for path in missing {
                try mark.execute(arguments: [path])
            }
        }
    }

    // MARK: - Rules

    struct RuleEffect: Equatable, Sendable {
        var nodes = 0
        var edges = 0
    }

    /// Marks what the rules remove and reports how much each rule accounts for. When two rules
    /// could claim the same node, the first match gets the count.
    @discardableResult
    func apply(_ rules: RuleSet) throws -> [String: RuleEffect] {
        var effects: [String: RuleEffect] = [:]
        try queue.write { db in
            var hidden = Set<String>()
            let nodeRows = try Row.fetchCursor(db, sql: "SELECT id, source_file, project, label_key, file_type FROM nodes")
            while let row = try nodeRows.next() {
                let facts = NodeFacts(id: row[0], path: row[1], project: row[2], labelKey: row[3], fileType: row[4])
                if let rule = rules.hidingRule(for: facts) {
                    hidden.insert(facts.id)
                    effects[rule, default: RuleEffect()].nodes += 1
                }
            }

            var removedEdges: [(rowid: Int64, reason: Int)] = []
            let edgeRows = try Row.fetchCursor(db, sql: "SELECT rowid, source, target, relation, suspect_cross FROM edges")
            while let row = try edgeRows.next() {
                let source: String = row[1]
                let target: String = row[2]
                let relation: String = row[3] ?? ""
                if let rule = rules.rejectingRule(source: source, target: target, relation: relation, isSuspect: row[4]) {
                    removedEdges.append((row[0], 1))
                    effects[rule, default: RuleEffect()].edges += 1
                } else if hidden.contains(source) || hidden.contains(target) {
                    removedEdges.append((row[0], 2))
                }
            }

            try db.execute(sql: "UPDATE nodes SET hidden = 0 WHERE hidden != 0")
            let hide = try db.makeStatement(sql: "UPDATE nodes SET hidden = 1 WHERE id = ?")
            for id in hidden { try hide.execute(arguments: [id]) }

            try db.execute(sql: "UPDATE edges SET removed = 0 WHERE removed != 0")
            let remove = try db.makeStatement(sql: "UPDATE edges SET removed = ? WHERE rowid = ?")
            for edge in removedEdges { try remove.execute(arguments: [edge.reason, edge.rowid]) }
        }
        return effects
    }

    /// Rules that no longer point at anything, usually because a file moved or a rebuild changed IDs.
    func orphanedRules(_ rules: RuleSet) throws -> Set<String> {
        try queue.read { db in
            let nodes = Set(try String.fetchAll(db, sql: "SELECT id FROM nodes"))
            let paths = try String.fetchAll(db, sql: "SELECT path FROM files")
            let pathSet = Set(paths)
            let groups = Set(try String.fetchAll(db, sql: "SELECT DISTINCT noise_group FROM nodes WHERE noise_group IS NOT NULL"))
            let projects = Set(try String.fetchAll(db, sql: "SELECT DISTINCT project FROM nodes"))
            let configKeys = Set(try String.fetchAll(db, sql: "SELECT DISTINCT label_key FROM nodes WHERE config_key = 1"))

            func keepTargetExists(_ finding: String) -> Bool {
                guard let colon = finding.firstIndex(of: ":") else { return true }
                let anchor = String(finding[finding.index(after: colon)...])
                switch String(finding[..<colon]) {
                case "cross", "isolated", "nosource": return nodes.contains(anchor)
                case "generated": return groups.contains(anchor)
                case "label": return configKeys.contains(anchor)
                case "duplicate": return projects.contains(anchor)
                case "missing": return pathSet.contains(anchor) || projects.contains(anchor)
                default: return true
                }
            }

            var orphaned = Set<String>()
            for entry in rules.active {
                let isLive: Bool
                switch entry.op {
                case CurationEntry.Op.hidePath:
                    let glob = PathGlob(entry.glob ?? "")
                    isLive = glob.isExactPath ? pathSet.contains(entry.glob ?? "") : paths.contains(where: glob.matches)
                case CurationEntry.Op.hideNode:
                    isLive = nodes.contains(entry.node ?? "")
                case CurationEntry.Op.hideConfigLabel:
                    isLive = configKeys.contains(entry.label ?? "")
                case CurationEntry.Op.rejectEdges:
                    isLive = nodes.contains(entry.target ?? "")
                case CurationEntry.Op.rejectEdge:
                    isLive = nodes.contains(entry.source ?? "") && nodes.contains(entry.target ?? "")
                case CurationEntry.Op.keep:
                    isLive = keepTargetExists(entry.finding ?? "")
                default:
                    isLive = true
                }
                if !isLive { orphaned.insert(entry.id) }
            }
            return orphaned
        }
    }

    // MARK: - Overview

    func overview() throws -> OverviewData {
        try queue.read { db in
            func count(_ sql: String) throws -> Int { try Int.fetchOne(db, sql: sql) ?? 0 }

            return OverviewData(
                graphPath: source.outDirectory.path,
                builtAt: graphModifiedAt,
                nodes: try count("SELECT COUNT(*) FROM nodes"),
                edges: try count("SELECT COUNT(*) FROM edges"),
                communities: try count("SELECT COUNT(DISTINCT community) FROM nodes"),
                sourceFiles: try count("SELECT COUNT(*) FROM files"),
                hiddenNodes: try count("SELECT COUNT(*) FROM nodes WHERE hidden != 0"),
                removedEdges: try count("SELECT COUNT(*) FROM edges WHERE removed != 0"),
                noiseNodes: try count("""
                    SELECT COUNT(*) FROM nodes n LEFT JOIN files f ON f.path = n.source_file
                    WHERE n.hidden = 0 AND (n.noise_kind IS NOT NULL OR f.is_missing = 1)
                    """),
                generatedOrVendoredNodes: try count("SELECT COUNT(*) FROM nodes WHERE hidden = 0 AND noise_kind IS NOT NULL"),
                crossProjectEdges: try count("SELECT COUNT(*) FROM edges WHERE removed = 0 AND cross_project = 1"),
                suspectCrossEdges: try count("SELECT COUNT(*) FROM edges WHERE removed = 0 AND suspect_cross = 1"),
                missingFiles: try count("""
                    SELECT COUNT(DISTINCT f.path) FROM files f JOIN nodes n ON n.source_file = f.path
                    WHERE f.is_missing = 1 AND n.hidden = 0
                    """),
                staleNodes: try count("""
                    SELECT COUNT(*) FROM files f JOIN nodes n ON n.source_file = f.path
                    WHERE f.is_missing = 1 AND n.hidden = 0
                    """),
                repeatedLabels: try count("""
                    SELECT COUNT(*) FROM (
                        SELECT label_key FROM nodes WHERE hidden = 0
                        GROUP BY label_key HAVING COUNT(DISTINCT project) > 1
                    )
                    """),
                isolatedNodes: try count("""
                    SELECT COUNT(*) FROM nodes n WHERE n.hidden = 0
                    AND NOT EXISTS (SELECT 1 FROM edges e WHERE e.source = n.id AND e.removed = 0)
                    AND NOT EXISTS (SELECT 1 FROM edges e WHERE e.target = n.id AND e.removed = 0)
                    """),
                nodesWithoutSource: try count("SELECT COUNT(*) FROM nodes WHERE hidden = 0 AND source_file = ''")
            )
        }
    }
}

struct OverviewData: Sendable, Codable, Equatable {
    let graphPath: String
    let builtAt: Date
    let nodes: Int
    let edges: Int
    let communities: Int
    let sourceFiles: Int
    let hiddenNodes: Int
    let removedEdges: Int
    /// Remaining nodes that are generated, vendored, or from a missing file, each counted once.
    let noiseNodes: Int
    let generatedOrVendoredNodes: Int
    let crossProjectEdges: Int
    /// The subset of `crossProjectEdges` where code resolved to code in another project.
    let suspectCrossEdges: Int
    let missingFiles: Int
    let staleNodes: Int
    let repeatedLabels: Int
    let isolatedNodes: Int
    let nodesWithoutSource: Int

    var visibleNodes: Int { nodes - hiddenNodes }
    var visibleEdges: Int { edges - removedEdges }
    var noiseShare: Double { visibleNodes == 0 ? 0 : Double(noiseNodes) / Double(visibleNodes) }
}

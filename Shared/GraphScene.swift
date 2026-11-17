import Foundation
import GRDB

/// A place in the drill-down, from whole projects to individual symbols.
enum SceneLevel: Hashable, Sendable {
    case projects
    case communities(project: String)
    case files(project: String, community: Int?)
    case symbols(project: String, community: Int?, path: String?)
}

struct SceneNode: Codable, Sendable {
    let id: String
    let label: String
    let value: Int
    let group: Int
    let ghost: Bool
    /// Rings view only: 0 is the centre, 1 its children, 2 their children.
    var ring: Int? = nil
    /// Rings view only: the ring-one node a ring-two node belongs to.
    var parent: String? = nil
    /// Areas view: where this item lives, such as `work` or `src/lib`.
    var area: String? = nil
    /// How many of this item's nodes are generated or vendored. Equal to `value` for a noise symbol.
    var noise: Int? = nil
    /// What `value` counts, such as "links", when it isn't nodes.
    var unit: String? = nil
}

struct SceneEdge: Codable, Sendable {
    let source: String
    let target: String
    let weight: Int
    /// Rings view only: a parent-to-child line rather than a real link.
    var tree: Bool? = nil
    /// How many of the links merged into this edge are suspect links between projects.
    var suspect: Int? = nil
}

/// Where a node sits in the drill-down, for jumping straight to it.
struct NodeLocation: Equatable, Sendable {
    let levels: [SceneLevel]
    let isHidden: Bool
}

/// A legend entry. `slot` is a colour position, or -1 for the neutral colour.
struct SceneGroup: Codable, Identifiable, Sendable {
    let id: Int
    let label: String
    let count: Int
    let slot: Int
}

struct GraphScene: Codable, Sendable {
    /// Point marks stay colour-blind safe with three hues, so everything else is neutral.
    static let colourSlots = 3
    static let legendLimit = 12
    static let nodeLimit = 5_000
    /// Rings show this many children per item. A project with 500 communities would otherwise fill the view.
    static let ringChildLimit = 48
    /// Rings show this many items around the centre. Hundreds of communities would shrink to specks.
    static let ringItemLimit = 72

    var nodes: [SceneNode]
    var edges: [SceneEdge]
    var groups: [SceneGroup]
    /// Nodes left out to stay under the limit.
    var omittedNodes: Int

    static let ringCenterID = "ring:center"
    private static let ringChildPrefix = "ring2\u{1F}"

    static func ringChildID(parent: String, child: String) -> String {
        ringChildPrefix + parent + "\u{1F}" + child
    }

    /// Splits a ring-two ID back into its ring-one parent and its own ID one level down.
    static func ringChild(_ id: String) -> (parent: String, child: String)? {
        guard id.hasPrefix(ringChildPrefix) else { return nil }
        let rest = id.dropFirst(ringChildPrefix.count)
        guard let separator = rest.firstIndex(of: "\u{1F}") else { return nil }
        return (String(rest[..<separator]), String(rest[rest.index(after: separator)...]))
    }
}

extension GraphIndex {
    /// The top of the drill-down. A single-project graph starts at its communities.
    func rootLevel() throws -> SceneLevel {
        let projects = try queue.read { db in
            try String.fetchAll(db, sql: "SELECT DISTINCT project FROM nodes WHERE project != ?", arguments: [SourcePath.noProject])
        }
        return projects.count == 1 ? .communities(project: projects[0]) : .projects
    }

    /// The level reached by opening a node, or nil at the bottom.
    func childLevel(of level: SceneLevel, nodeID: String) -> SceneLevel? {
        switch level {
        case .projects:
            return .communities(project: nodeID)
        case .communities(let project):
            return .files(project: project, community: Int(nodeID))
        case .files(let project, let community):
            return .symbols(project: project, community: community, path: nodeID)
        case .symbols:
            return nil
        }
    }

    func title(of level: SceneLevel) throws -> String {
        switch level {
        case .projects:
            return "Projects"
        case .communities(let project):
            return project
        case .files(_, let community):
            guard let community else { return "No community" }
            return try queue.read { db in
                try String.fetchOne(db, sql: "SELECT label FROM communities WHERE id = ?", arguments: [community])
            } ?? "Community \(community)"
        case .symbols(_, _, let path):
            return path.map { ($0 as NSString).lastPathComponent } ?? "Symbols"
        }
    }

    func scene(at level: SceneLevel, showHidden: Bool, nodeLimit: Int = GraphScene.nodeLimit) throws -> GraphScene {
        try queue.read { db in
            switch level {
            case .projects:
                return try Self.projectScene(db, scheme: source.scheme, showHidden: showHidden, nodeLimit: nodeLimit)
            case .communities(let project):
                return try Self.communityScene(db, project: project, showHidden: showHidden, nodeLimit: nodeLimit)
            case .files(let project, let community):
                return try Self.fileScene(db, project: project, community: community, showHidden: showHidden, nodeLimit: nodeLimit)
            case .symbols(let project, let community, let path):
                return try Self.symbolScene(db, project: project, community: community, path: path, showHidden: showHidden, nodeLimit: nodeLimit)
            }
        }
    }

    private struct Entry {
        let id: String
        let label: String
        let groupKey: String
        let groupLabel: String
        let value: Int
        let ghost: Bool
        var area: String? = nil
        var noise = 0
    }

    /// Source, target, weight, and how many of the links are suspect.
    private typealias RawEdge = (String, String, Int, Int)

    /// The first two folders below the project, so `work/app/src/lib/a.ts` is `src/lib`.
    fileprivate static func folderArea(of path: String, project: String) -> String {
        let relative = path.hasPrefix(project + "/") ? String(path.dropFirst(project.count + 1)) : path
        let folders = relative.split(separator: "/").dropLast()
        return folders.isEmpty ? "Top level" : folders.prefix(2).joined(separator: "/")
    }

    /// Ranks groups by size, assigns legend positions, and applies the node limit.
    private static func compose(_ entries: [Entry], edges: [RawEdge], nodeLimit: Int) -> GraphScene {
        var totals: [String: (label: String, value: Int)] = [:]
        for entry in entries {
            totals[entry.groupKey, default: (entry.groupLabel, 0)].value += entry.value
        }
        let ranked = totals.sorted {
            $0.value.value != $1.value.value ? $0.value.value > $1.value.value : $0.key < $1.key
        }
        let otherGroup = GraphScene.legendLimit
        var rankByKey: [String: Int] = [:]
        for (rank, element) in ranked.enumerated() {
            rankByKey[element.key] = min(rank, otherGroup)
        }

        var groups = ranked.prefix(GraphScene.legendLimit).enumerated().map { rank, element in
            SceneGroup(
                id: rank,
                label: element.value.label,
                count: element.value.value,
                slot: rank < GraphScene.colourSlots ? rank : -1
            )
        }
        if ranked.count > GraphScene.legendLimit {
            let rest = ranked.dropFirst(GraphScene.legendLimit)
            groups.append(SceneGroup(
                id: otherGroup,
                label: "\(rest.count) more",
                count: rest.reduce(0) { $0 + $1.value.value },
                slot: -1
            ))
        }

        let sorted = entries.sorted { $0.value != $1.value ? $0.value > $1.value : $0.id < $1.id }
        let kept = sorted.prefix(nodeLimit)
        let keptIDs = Set(kept.map(\.id))
        let nodes = kept.map {
            SceneNode(
                id: $0.id,
                label: $0.label,
                value: $0.value,
                group: rankByKey[$0.groupKey] ?? otherGroup,
                ghost: $0.ghost,
                area: $0.area,
                noise: $0.noise > 0 ? $0.noise : nil
            )
        }

        // The stored graph is undirected, so merge each pair regardless of direction.
        var merged: [String: RawEdge] = [:]
        for (source, target, weight, suspect) in edges where source != target && keptIDs.contains(source) && keptIDs.contains(target) {
            let key = source < target ? "\(source)\u{1F}\(target)" : "\(target)\u{1F}\(source)"
            merged[key, default: (source, target, 0, 0)].2 += weight
            merged[key, default: (source, target, 0, 0)].3 += suspect
        }
        return GraphScene(
            nodes: nodes,
            edges: merged.values.map { SceneEdge(source: $0.0, target: $0.1, weight: $0.2, suspect: $0.3 > 0 ? $0.3 : nil) },
            groups: groups,
            omittedNodes: max(0, entries.count - nodes.count)
        )
    }

    private static func entryRows(
        _ db: Database,
        keySQL: String,
        whereSQL: String,
        arguments: StatementArguments,
        showHidden: Bool
    ) throws -> [(key: DatabaseValue, total: Int, visible: Int, noise: Int)] {
        try Row.fetchAll(db, sql: """
            SELECT \(keySQL), COUNT(*), SUM(hidden = 0), SUM(hidden = 0 AND noise_kind IS NOT NULL) FROM nodes WHERE \(whereSQL) GROUP BY 1
            """, arguments: arguments).compactMap { row in
            let visible: Int = row[2]
            guard showHidden || visible > 0 else { return nil }
            return (row[0] as DatabaseValue, row[1] as Int, visible, row[3] as Int)
        }
    }

    private static func projectScene(_ db: Database, scheme: ProjectScheme, showHidden: Bool, nodeLimit: Int) throws -> GraphScene {
        let rows = try entryRows(db, keySQL: "project", whereSQL: "project != ?", arguments: [SourcePath.noProject], showHidden: showHidden)
        // Colour by area (the person's folder labels, or group folders) when there are at least
        // two. Otherwise each project is its own group.
        let names = rows.map { String.fromDatabaseValue($0.key) ?? "" }
        let groupsByOwner = Set(names.map { scheme.area(ofProject: $0)?.name ?? "" }).count >= 2
        var purposes: [String: FolderPurpose] = [:]
        let entries = rows.map { row -> Entry in
            let project = String.fromDatabaseValue(row.key) ?? ""
            let area = scheme.area(ofProject: project)
            if let area { purposes[area.name] = area.purpose }
            return Entry(
                id: project,
                label: project,
                groupKey: groupsByOwner ? (area?.name ?? otherOwnerKey) : project,
                groupLabel: groupsByOwner ? (area?.name ?? "Other") : project,
                value: showHidden ? row.total : row.visible,
                ghost: row.visible == 0,
                area: area?.name ?? "Top level",
                noise: row.noise
            )
        }
        let edges = try Row.fetchAll(db, sql: """
            SELECT a.project, b.project, COUNT(*), SUM(e.suspect_cross) FROM edges e
            JOIN nodes a ON a.id = e.source JOIN nodes b ON b.id = e.target
            WHERE a.project != b.project AND (e.removed = 0 OR ?) GROUP BY 1, 2
            """, arguments: [showHidden]).map { ($0[0] as String, $0[1] as String, $0[2] as Int, $0[3] as Int) }
        var scene = compose(entries, edges: edges, nodeLimit: nodeLimit)
        if groupsByOwner { scene.groups = scene.groups.map { ownerColoured($0, purpose: purposes[$0.label]) } }
        return scene
    }

    private static let otherOwnerKey = "\u{1F}other"

    /// Each purpose keeps its colour whichever area is larger. Anything else is neutral.
    private static func ownerColoured(_ group: SceneGroup, purpose: FolderPurpose?) -> SceneGroup {
        SceneGroup(id: group.id, label: group.label, count: group.count, slot: purpose?.colorSlot ?? -1)
    }

    /// A community's node id on the communities level.
    static func communityKey(_ community: Int?) -> String {
        community.map(String.init) ?? "none"
    }

    private static func communityScene(_ db: Database, project: String, showHidden: Bool, nodeLimit: Int) throws -> GraphScene {
        let rows = try entryRows(db, keySQL: "community", whereSQL: "project = ?", arguments: [project], showHidden: showHidden)
        let labels = Dictionary(uniqueKeysWithValues: try Row.fetchAll(db, sql: "SELECT id, label FROM communities").map { ($0[0] as Int, $0[1] as String) })

        // A community's area is the folder holding most of its nodes.
        var folderWeights: [String: [String: Int]] = [:]
        for row in try Row.fetchAll(db, sql: """
            SELECT community, source_file, COUNT(*) FROM nodes
            WHERE project = ? AND (hidden = 0 OR ?) GROUP BY 1, 2
            """, arguments: [project, showHidden]) {
            let area = folderArea(of: row[1], project: project)
            folderWeights[communityKey(row[0]), default: [:]][area, default: 0] += row[2] as Int
        }
        func mainFolder(_ key: String) -> String? {
            folderWeights[key]?.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key
        }

        let entries = rows.map { row -> Entry in
            let community = Int.fromDatabaseValue(row.key)
            let label = community.flatMap { labels[$0] } ?? community.map { "Community \($0)" } ?? "No community"
            let key = communityKey(community)
            return Entry(
                id: key,
                label: label,
                groupKey: key,
                groupLabel: label,
                value: showHidden ? row.total : row.visible,
                ghost: row.visible == 0,
                area: mainFolder(key),
                noise: row.noise
            )
        }
        let edges = try Row.fetchAll(db, sql: """
            SELECT a.community, b.community, COUNT(*) FROM edges e
            JOIN nodes a ON a.id = e.source JOIN nodes b ON b.id = e.target
            WHERE a.project = :project AND b.project = :project AND a.community IS NOT b.community
            AND (e.removed = 0 OR :all) GROUP BY 1, 2
            """, arguments: ["project": project, "all": showHidden]).map {
            (communityKey($0[0]), communityKey($0[1]), $0[2] as Int, 0)
        }
        return compose(entries, edges: edges, nodeLimit: nodeLimit)
    }

    private static func fileScene(_ db: Database, project: String, community: Int?, showHidden: Bool, nodeLimit: Int) throws -> GraphScene {
        let rows = try entryRows(db, keySQL: "source_file", whereSQL: "project = ? AND community IS ?", arguments: [project, community], showHidden: showHidden)
        let entries = rows.map { row -> Entry in
            let path = String.fromDatabaseValue(row.key) ?? ""
            let folder = (path as NSString).deletingLastPathComponent
            return Entry(
                id: path,
                label: path.isEmpty ? "No source file" : (path as NSString).lastPathComponent,
                groupKey: folder,
                groupLabel: folder.isEmpty ? "Top level" : folder,
                value: showHidden ? row.total : row.visible,
                ghost: row.visible == 0,
                area: folderArea(of: path, project: project),
                noise: row.noise
            )
        }
        let edges = try Row.fetchAll(db, sql: """
            SELECT a.source_file, b.source_file, COUNT(*) FROM edges e
            JOIN nodes a ON a.id = e.source JOIN nodes b ON b.id = e.target
            WHERE a.project = :project AND b.project = :project AND a.community IS :community AND b.community IS :community
            AND a.source_file != b.source_file AND (e.removed = 0 OR :all) GROUP BY 1, 2
            """, arguments: ["project": project, "community": community, "all": showHidden]).map {
            ($0[0] as String, $0[1] as String, $0[2] as Int, 0)
        }
        return compose(entries, edges: edges, nodeLimit: nodeLimit)
    }

    private static func symbolScene(_ db: Database, project: String, community: Int?, path: String?, showHidden: Bool, nodeLimit: Int) throws -> GraphScene {
        let entries = try Row.fetchAll(db, sql: """
            SELECT id, label, source_file, degree, hidden, file_type, noise_kind FROM nodes
            WHERE project = :project AND community IS :community AND (:path IS NULL OR source_file = :path)
            AND (hidden = 0 OR :all)
            """, arguments: ["project": project, "community": community, "path": path, "all": showHidden]).map { row -> Entry in
            let type: String = row[5] ?? "other"
            let file: String = row[2]
            let value = max(row[3] as Int, 1)
            let noiseKind: String? = row[6]
            return Entry(
                id: row[0],
                label: row[1],
                groupKey: type,
                groupLabel: type.capitalized,
                value: value,
                ghost: (row[4] as Int) != 0,
                // A whole community splits by file; a single file by kind of node.
                area: path == nil ? (file.isEmpty ? "No source file" : (file as NSString).lastPathComponent) : type.capitalized,
                noise: noiseKind == nil ? 0 : value
            )
        }
        let edges = try Row.fetchAll(db, sql: """
            SELECT e.source, e.target, COUNT(*) FROM edges e
            JOIN nodes a ON a.id = e.source JOIN nodes b ON b.id = e.target
            WHERE a.project = :project AND b.project = :project AND a.community IS :community AND b.community IS :community
            AND (:path IS NULL OR (a.source_file = :path AND b.source_file = :path))
            AND (e.removed = 0 OR :all) GROUP BY 1, 2
            """, arguments: ["project": project, "community": community, "path": path, "all": showHidden]).map {
            ($0[0] as String, $0[1] as String, $0[2] as Int, 0)
        }
        return compose(entries, edges: edges, nodeLimit: nodeLimit)
    }
}

// MARK: - Rings

private struct RingChild {
    let parent: String
    let child: String
    let label: String
    let value: Int
    let ghost: Bool
}

extension GraphIndex {
    /// The current level's items around a centre, with each item's own children on an outer ring.
    func ringScene(at level: SceneLevel, showHidden: Bool, nodeLimit: Int = GraphScene.nodeLimit) throws -> GraphScene {
        var scene = try self.scene(at: level, showHidden: showHidden, nodeLimit: max(1, min(nodeLimit - 1, GraphScene.ringItemLimit)))
        let centreTitle = try title(of: level)
        let children = try queue.read { db in try Self.ringChildren(db, of: level, showHidden: showHidden) }

        let groupByParent = Dictionary(uniqueKeysWithValues: scene.nodes.map { ($0.id, $0.group) })
        let eligible = children
            .filter { groupByParent[$0.parent] != nil }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.child < $1.child }
        var shownPerParent: [String: Int] = [:]
        let largest = eligible.filter { child in
            shownPerParent[child.parent, default: 0] += 1
            return shownPerParent[child.parent, default: 0] <= GraphScene.ringChildLimit
        }
        let budget = max(0, nodeLimit - scene.nodes.count - 1)
        let kept = largest.prefix(budget)

        // The centre's group is outside the legend, so it draws in the neutral colour.
        var nodes = [SceneNode(
            id: GraphScene.ringCenterID,
            label: centreTitle,
            value: scene.nodes.reduce(0) { $0 + $1.value },
            group: -1,
            ghost: false,
            ring: 0,
            noise: { let total = scene.nodes.reduce(0) { $0 + ($1.noise ?? 0) }; return total > 0 ? total : nil }()
        )]
        nodes += scene.nodes.map { node in
            var ringed = node
            ringed.ring = 1
            return ringed
        }
        var edges = scene.edges
        edges += scene.nodes.map { SceneEdge(source: GraphScene.ringCenterID, target: $0.id, weight: 1, tree: true) }
        for child in kept {
            let id = GraphScene.ringChildID(parent: child.parent, child: child.child)
            nodes.append(SceneNode(
                id: id,
                label: child.label,
                value: child.value,
                group: groupByParent[child.parent] ?? -1,
                ghost: child.ghost,
                ring: 2,
                parent: child.parent
            ))
            edges.append(SceneEdge(source: child.parent, target: id, weight: 1, tree: true))
        }

        scene.nodes = nodes
        scene.edges = edges
        scene.omittedNodes += eligible.count - kept.count
        return scene
    }

    private static func ringChildren(_ db: Database, of level: SceneLevel, showHidden: Bool) throws -> [RingChild] {
        func aggregate(parent: String, child: String, label: String, total: Int, visible: Int) -> RingChild? {
            guard showHidden || visible > 0 else { return nil }
            return RingChild(parent: parent, child: child, label: label, value: showHidden ? total : visible, ghost: visible == 0)
        }

        switch level {
        case .projects:
            return try Row.fetchAll(db, sql: """
                SELECT n.project, n.community, COUNT(*), SUM(n.hidden = 0), c.label FROM nodes n
                LEFT JOIN communities c ON c.id = n.community
                WHERE n.project != ? GROUP BY n.project, n.community
                """, arguments: [SourcePath.noProject]).compactMap { row in
                let community: Int? = row[1]
                let label: String? = row[4]
                return aggregate(
                    parent: row[0],
                    child: communityKey(community),
                    label: label ?? community.map { "Community \($0)" } ?? "No community",
                    total: row[2],
                    visible: row[3]
                )
            }
        case .communities(let project):
            return try Row.fetchAll(db, sql: """
                SELECT community, source_file, COUNT(*), SUM(hidden = 0) FROM nodes
                WHERE project = ? GROUP BY community, source_file
                """, arguments: [project]).compactMap { row in
                let path: String = row[1]
                return aggregate(
                    parent: communityKey(row[0]),
                    child: path,
                    label: path.isEmpty ? "No source file" : (path as NSString).lastPathComponent,
                    total: row[2],
                    visible: row[3]
                )
            }
        case .files(let project, let community):
            return try Row.fetchAll(db, sql: """
                SELECT source_file, id, label, degree, hidden FROM nodes
                WHERE project = ? AND community IS ? AND (hidden = 0 OR ?)
                """, arguments: [project, community, showHidden]).map { row in
                RingChild(parent: row[0], child: row[1], label: row[2], value: max(row[3] as Int, 1), ghost: (row[4] as Int) != 0)
            }
        case .symbols:
            return []
        }
    }

    /// The levels from the top of the drill-down to a symbol, or nil for a node outside any project.
    func location(ofNode id: String) throws -> NodeLocation? {
        guard let row = try queue.read({ db in
            try Row.fetchOne(db, sql: "SELECT project, community, source_file, hidden FROM nodes WHERE id = ?", arguments: [id])
        }) else { return nil }
        let project: String = row[0]
        guard project != SourcePath.noProject else { return nil }
        let community: Int? = row[1]
        let path: String = row[2]
        var levels: [SceneLevel] = []
        if try rootLevel() == .projects { levels.append(.projects) }
        levels += [
            .communities(project: project),
            .files(project: project, community: community),
            .symbols(project: project, community: community, path: path),
        ]
        return NodeLocation(levels: levels, isHidden: (row[3] as Int) != 0)
    }
}


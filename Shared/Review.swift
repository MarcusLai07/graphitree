import Foundation
import GRDB

/// The order review mode walks a detector's findings: biggest decision first, like the list.
enum ReviewQueue {
    static func ordered(_ findings: [Finding]) -> [Finding] {
        findings.sorted { $0.count != $1.count ? $0.count > $1.count : $0.id < $1.id }
    }

    /// What to show once `id` leaves the queue: the next finding, or the previous one at the end.
    static func neighbour(of id: String, in queue: [Finding]) -> Finding? {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return queue.first }
        if index + 1 < queue.count { return queue[index + 1] }
        return index > 0 ? queue[index - 1] : nil
    }
}

/// Ranks commands and names against what was typed, so "rv gen" finds "Review Generated Code".
enum FuzzyMatch {
    /// Higher is better. Nil when the typed letters don't all appear in order.
    static func score(_ query: String, in text: String) -> Int? {
        let wanted = Array(query.lowercased().filter { !$0.isWhitespace })
        guard !wanted.isEmpty else { return 0 }
        let letters = Array(text.lowercased())
        var score = 0
        var matched = 0
        var previous = -2
        for (index, letter) in letters.enumerated() where matched < wanted.count {
            guard letter == wanted[matched] else { continue }
            var points = 1
            if index == previous + 1 { points += 4 }
            if index == 0 || !(letters[index - 1].isLetter || letters[index - 1].isNumber) { points += 6 }
            score += points
            previous = index
            matched += 1
        }
        guard matched == wanted.count else { return nil }
        // Letters scattered through unrelated words aren't a match worth showing.
        guard score >= wanted.count * 3 else { return nil }
        if letters.starts(with: wanted) { score += 10 }
        // Among equal matches, the shorter name is the closer one.
        return score * 100 - letters.count
    }
}

/// One item placed around a constellation's centre.
struct ConstellationItem {
    let id: String
    let label: String
    let project: String
    let value: Int
    var isNoise = false
    var isHidden = false
}

/// Builds a constellation: one thing at the centre, what it covers or reaches around it.
struct ConstellationBuilder {
    private(set) var nodes: [SceneNode]
    private(set) var edges: [SceneEdge] = []
    private(set) var omitted = 0
    private var usedGroups = Set<Int>()
    private let membersPerProject: Int
    private let scheme: ProjectScheme

    init(centre: SceneNode, membersPerProject: Int = 12, scheme: ProjectScheme = ProjectScheme(singleRepoName: nil)) {
        nodes = [centre]
        self.membersPerProject = membersPerProject
        self.scheme = scheme
    }

    init(finding: Finding, scheme: ProjectScheme = ProjectScheme(singleRepoName: nil)) {
        self.init(centre: SceneNode(
            id: GraphScene.ringCenterID,
            label: finding.title,
            value: max(finding.count, 1),
            group: -1,
            ghost: false,
            ring: 0,
            noise: finding.detector == .generated ? finding.count : nil,
            unit: finding.unit
        ), scheme: scheme)
    }

    /// Personal, work, or anything else, with the same colours as the projects view.
    private mutating func ownerGroup(_ project: String) -> Int {
        let group: Int
        switch scheme.area(ofProject: project)?.purpose {
        case .personal: group = 0
        case .work: group = 1
        default: group = 2
        }
        usedGroups.insert(group)
        return group
    }

    mutating func addRing(_ items: [ConstellationItem]) {
        for item in items {
            let id = "review\u{1F}" + item.id
            nodes.append(SceneNode(id: id, label: item.label, value: max(item.value, 1), group: ownerGroup(item.project), ghost: false, ring: 1))
            edges.append(SceneEdge(source: GraphScene.ringCenterID, target: id, weight: 1, tree: true))
        }
    }

    /// Projects on the first ring and their members behind them. Suspect lines run to the projects.
    mutating func addByProject(_ items: [ConstellationItem], suspect: Bool) {
        let byProject = Dictionary(grouping: items, by: \.project)
        let ranked = byProject.map { (project: $0.key, members: $0.value, total: $0.value.reduce(0) { $0 + $1.value }) }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.project < $1.project }
        for entry in ranked {
            let group = ownerGroup(entry.project)
            let projectID = "project\u{1F}" + entry.project
            let label = entry.project == SourcePath.noProject ? "No project" : entry.project
            nodes.append(SceneNode(id: projectID, label: label, value: entry.total, group: group, ghost: false, ring: 1))
            edges.append(SceneEdge(
                source: GraphScene.ringCenterID,
                target: projectID,
                weight: entry.total,
                tree: suspect ? nil : true,
                suspect: suspect ? entry.total : nil
            ))
            let members = entry.members.sorted { $0.value != $1.value ? $0.value > $1.value : $0.label < $1.label }
            for member in members.prefix(membersPerProject) {
                let id = "review\u{1F}" + member.id
                let value = max(member.value, 1)
                nodes.append(SceneNode(
                    id: id,
                    label: member.label,
                    value: value,
                    group: group,
                    ghost: member.isHidden,
                    ring: 2,
                    parent: projectID,
                    noise: member.isNoise ? value : nil
                ))
                edges.append(SceneEdge(source: projectID, target: id, weight: 1, tree: true))
            }
            omitted += max(0, members.count - membersPerProject)
        }
    }

    var scene: GraphScene {
        let labels = [0: "Personal", 1: "Work", 2: "Other"]
        let groups = usedGroups.sorted().map { group in
            SceneGroup(
                id: group,
                label: labels[group] ?? "Other",
                count: nodes.filter { $0.group == group }.count,
                slot: group == 2 ? -1 : group
            )
        }
        return GraphScene(nodes: nodes, edges: edges, groups: groups, omittedNodes: omitted)
    }
}

extension GraphIndex {
    /// One finding drawn as a constellation, for review mode.
    /// `limit` caps a ring of files or symbols. Links are grouped by project, so all of them are read.
    func reviewScene(for finding: Finding, limit: Int = 160, linkLimit: Int = 5_000) throws -> GraphScene {
        try queue.read { db in
            var builder = ConstellationBuilder(finding: finding, scheme: source.scheme)
            switch finding.detector {
            case .crossProject:
                let rows = try Row.fetchAll(db, sql: """
                    SELECT n.id, n.label, n.project, COUNT(*) FROM edges e
                    JOIN nodes n ON n.id = CASE WHEN e.source = :hub THEN e.target ELSE e.source END
                    WHERE e.removed = 0 AND e.suspect_cross = 1 AND (e.source = :hub OR e.target = :hub)
                    GROUP BY n.id ORDER BY 4 DESC LIMIT :limit
                    """, arguments: ["hub": finding.anchor, "limit": linkLimit])
                builder.addByProject(rows.map { ConstellationItem(id: $0[0], label: $0[1], project: $0[2], value: $0[3]) }, suspect: true)

            case .generated, .duplicates, .missing:
                let column: String
                switch finding.detector {
                case .generated: column = "noise_group"
                case .duplicates: column = "project"
                default: column = finding.anchor == finding.project ? "project" : "source_file"
                }
                let files = try Row.fetchAll(db, sql: """
                    SELECT source_file, COUNT(*) FROM nodes WHERE hidden = 0 AND \(column) = ?
                    GROUP BY 1 ORDER BY 2 DESC LIMIT ?
                    """, arguments: [finding.anchor, limit])
                if files.count > 1 {
                    builder.addRing(files.map { row in
                        let path: String = row[0]
                        return ConstellationItem(id: "file\u{1F}" + path, label: (path as NSString).lastPathComponent, project: finding.project, value: row[1])
                    })
                } else {
                    // A single file says little, so show what's inside it instead.
                    let symbols = try Row.fetchAll(db, sql: """
                        SELECT id, label, project, degree FROM nodes WHERE hidden = 0 AND \(column) = ?
                        ORDER BY degree DESC LIMIT ?
                        """, arguments: [finding.anchor, limit])
                    builder.addRing(symbols.map { ConstellationItem(id: $0[0], label: $0[1], project: $0[2], value: $0[3]) })
                }

            case .configLabels:
                let rows = try Row.fetchAll(db, sql: """
                    SELECT id, source_file, project FROM nodes
                    WHERE hidden = 0 AND config_key = 1 AND label_key = ? LIMIT ?
                    """, arguments: [finding.anchor, linkLimit])
                builder.addByProject(rows.map { row in
                    let path: String = row[1]
                    return ConstellationItem(id: row[0], label: (path as NSString).lastPathComponent, project: row[2], value: 1)
                }, suspect: false)

            case .noSource:
                let rows = try Row.fetchAll(db, sql: """
                    SELECT n.id, n.label, n.project, COUNT(*) FROM edges e
                    JOIN nodes n ON n.id = CASE WHEN e.source = :node THEN e.target ELSE e.source END
                    WHERE e.removed = 0 AND (e.source = :node OR e.target = :node)
                    GROUP BY n.id ORDER BY 4 DESC LIMIT :limit
                    """, arguments: ["node": finding.anchor, "limit": linkLimit])
                builder.addByProject(rows.map { ConstellationItem(id: $0[0], label: $0[1], project: $0[2], value: $0[3]) }, suspect: false)

            case .isolated:
                // Nothing links to it, so the centre stands alone.
                break
            }
            return builder.scene
        }
    }
}

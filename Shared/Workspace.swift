import Foundation

enum CleanStatus: Equatable, Sendable {
    case notWritten
    case upToDate(Date)
    case outOfDate(Date)
}

struct RuleRow: Identifiable, Hashable, Sendable {
    let id: String
    let batch: String?
    let at: Date
    let summary: String
    let affects: String
    let isKeep: Bool
    /// True when nothing in the current graph matches this rule any more.
    let isOrphaned: Bool
}

struct WorkspaceSnapshot: Sendable {
    let overview: OverviewData
    let findings: [Detector: [Finding]]
    let rules: [RuleRow]
    let clean: CleanStatus
    let unreadableLogLines: Int
    let canUndo: Bool

    func count(_ detector: Detector) -> Int { findings[detector]?.count ?? 0 }
}

struct CleanGraphResult: Equatable, Sendable {
    let nodes: Int
    let edges: Int
    let hyperedges: Int
}

/// One open graph plus its decisions. Not thread-safe: callers must serialise access.
final class Workspace: @unchecked Sendable {
    let source: GraphSource
    private let index: GraphIndex
    private var log: CurationLog
    private var rules: RuleSet
    private var effects: [String: GraphIndex.RuleEffect] = [:]

    var logURL: URL { source.outDirectory.appendingPathComponent("curation.jsonl") }
    var cleanURL: URL { source.outDirectory.appendingPathComponent("graph.clean.json") }

    init(source: GraphSource, cacheDirectory: URL, progress: @Sendable (IndexPhase) -> Void = { _ in }) throws {
        self.source = source
        index = try GraphIndex.open(source: source, cacheDirectory: cacheDirectory, progress: progress)
        log = try CurationLog(url: source.outDirectory.appendingPathComponent("curation.jsonl"))
        rules = RuleSet(entries: log.entries)
        rules.seedNodes = seedTextNodes()
        progress(.summarising)
        effects = try index.apply(rules)
    }

    // MARK: - Decisions

    func perform(_ actions: [CurationAction]) throws -> WorkspaceSnapshot {
        guard !actions.isEmpty else { return try snapshot() }
        try log.append(log.entries(for: actions))
        return try refreshRules()
    }

    func undo(ruleIDs: [String]) throws -> WorkspaceSnapshot {
        guard !ruleIDs.isEmpty else { return try snapshot() }
        try log.append(log.revocations(of: ruleIDs))
        return try refreshRules()
    }

    /// Reverses the most recent batch that still has live rules.
    func undoLastBatch() throws -> WorkspaceSnapshot {
        guard let last = rules.active.last else { return try snapshot() }
        let ids = rules.active.filter { $0.batch != nil && $0.batch == last.batch }.map(\.id)
        return try undo(ruleIDs: ids.isEmpty ? [last.id] : ids)
    }

    private func refreshRules() throws -> WorkspaceSnapshot {
        rules = RuleSet(entries: log.entries)
        rules.seedNodes = seedTextNodes()
        effects = try index.apply(rules)
        return try snapshot()
    }

    /// Starter text seeded repos haven't changed, which the clean graph leaves out.
    private func seedTextNodes() -> Set<String> {
        let unchanged = Seeds.unchangedText(root: source.rootPath, outDirectory: source.outDirectory)
        guard !unchanged.isEmpty else { return [] }
        let root = source.rootPath.hasSuffix("/") ? source.rootPath : source.rootPath + "/"
        let paths = Set(unchanged.keys.flatMap { [$0, root + $0] })
        let nodes = (try? index.nodeLines(inFiles: paths)) ?? []
        return Seeds.hiddenNodes(nodes, unchanged: unchanged, root: source.rootPath)
    }

    /// Adds lines to `.graphifyignore`, skipping any already there. Only takes effect on the next build.
    func addToIgnoreFile(_ lines: [String]) throws {
        let url = URL(fileURLWithPath: source.rootPath).appendingPathComponent(".graphifyignore")
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let present = Set(existing.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
        let additions = lines.filter { !present.contains($0) }
        guard !additions.isEmpty else { return }

        var text = existing
        if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }
        if !text.isEmpty { text += "\n" }
        text += "# Added by Graphitree\n" + additions.joined(separator: "\n") + "\n"
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func projectSizes() throws -> [(project: String, nodes: Int)] { try index.projectSizes() }

    func nodeCount(inProject project: String) throws -> Int { try index.nodeCount(inProject: project) }

    // MARK: - Reading

    func snapshot() throws -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            overview: try index.overview(),
            findings: try index.findings(rules: rules),
            rules: ruleRows(),
            clean: cleanStatus(),
            unreadableLogLines: log.unreadableLines,
            canUndo: !rules.active.isEmpty
        )
    }

    func details(for finding: Finding) throws -> [FindingDetail] {
        try index.details(for: finding)
    }

    func search(_ text: String) throws -> [OutlineItem] {
        try index.search(text)
    }

    func outlineChildren(of parent: OutlineItem?) throws -> [OutlineItem] {
        try index.outlineChildren(of: parent)
    }

    func rootLevel() throws -> SceneLevel { try index.rootLevel() }

    func childLevel(of level: SceneLevel, nodeID: String) -> SceneLevel? {
        index.childLevel(of: level, nodeID: nodeID)
    }

    func title(of level: SceneLevel) throws -> String { try index.title(of: level) }

    func scene(at level: SceneLevel, showHidden: Bool, nodeLimit: Int = GraphScene.nodeLimit) throws -> GraphScene {
        try index.scene(at: level, showHidden: showHidden, nodeLimit: nodeLimit)
    }

    func ringScene(at level: SceneLevel, showHidden: Bool, nodeLimit: Int = GraphScene.nodeLimit) throws -> GraphScene {
        try index.ringScene(at: level, showHidden: showHidden, nodeLimit: nodeLimit)
    }

    var guideURL: URL { source.outDirectory.appendingPathComponent(AgentGuide.fileName) }
    var playbookMarkdownPath: String { source.outDirectory.appendingPathComponent(PlaybookFile.markdownName).path }

    /// The agent guide for this graph. It points agents at the clean graph once that's up to date.
    func agentGuideText(findings: [Detector: [Finding]], overview: OverviewData, clean: CleanStatus, now: Date = .now) throws -> String {
        let hubs = Set((findings[.crossProject] ?? []).map(\.anchor))
        var (projects, others) = try index.guideProjects(excluding: hubs)
        for index in projects.indices {
            projects[index].purpose = readmePurpose(of: projects[index].name)
        }
        var isClean = false
        if case .upToDate = clean { isClean = true }

        var traps: [String] = []
        for finding in ReviewQueue.ordered(findings[.crossProject] ?? []).prefix(6) {
            traps.append("`\(finding.title)` in \(finding.project): \(finding.affects) \(finding.note.lowercased()), only because a name matches. Don't follow them across projects.")
        }
        for finding in ReviewQueue.ordered(findings[.generated] ?? []).prefix(4) where finding.count >= 100 {
            traps.append("`\(finding.location)` is generated code (\(finding.affects)). Read what it's generated from instead.")
        }
        let rc = (try? String(contentsOfFile: (source.rootPath as NSString).appendingPathComponent(".graphifyrc"), encoding: .utf8)) ?? ""
        let budget = RCFile.value(RCFile.budgetKey, in: rc).flatMap(Int.init) ?? AgentGuide.defaultBudget
        if overview.nodesWithoutSource > 0 {
            traps.append("Nodes with no source file, such as `ref_react`, stand for libraries. They join unrelated projects, so don't follow them from one project to another.")
        }
        let hasPlaybook = FileManager.default.fileExists(atPath: playbookMarkdownPath)
        let playbookNodes = hasPlaybook ? ((try? index.nodeCount(inProject: PlaybookFile.graphFolder)) ?? 0) : 0
        let memoryNodes = (try? index.nodeCount(inProject: MemoryCopy.graphFolder)) ?? 0
        return AgentGuide.text(AgentGuide.Inputs(
            root: source.rootPath,
            graphPath: isClean ? cleanURL.path : source.graphURL.path,
            isCleanGraph: isClean,
            builtAt: overview.builtAt,
            visibleNodes: overview.visibleNodes,
            projects: projects,
            otherProjects: others,
            traps: traps,
            generatedAt: now,
            queryBudget: budget,
            playbookPath: hasPlaybook ? playbookMarkdownPath : nil,
            playbookSummary: hasPlaybook ? PlaybookFile.guideSummary(PlaybookFile.load(from: source.outDirectory)) : [],
            playbookProject: playbookNodes > 0 ? PlaybookFile.graphFolder : nil,
            memoryProject: memoryNodes > 0 ? MemoryCopy.graphFolder : nil,
            folders: guideFolders(),
            graphs: GraphCuts.load(from: source.outDirectory).compactMap { cut in
                let url = GraphCuts.url(of: cut, outDirectory: source.outDirectory)
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                return GuideGraph(name: cut.name, path: url.path, projects: cut.projects, nodes: cut.nodes)
            },
            hasCommand: CommandLineTool.isInstalled(home: NSHomeDirectory())
        ))
    }

    /// The person's folder labels, with each folder's slice when it exists.
    private func guideFolders() -> [GuideFolder] {
        guard source.scheme.singleRepoName == nil, let map = FolderFile.load(from: source.outDirectory) else { return [] }
        return map.folders.map { label in
            let slice = FolderSlices.url(for: label.path, outDirectory: source.outDirectory)
            return GuideFolder(
                path: label.path,
                purpose: label.purpose,
                note: label.note,
                holdsProjects: label.holdsProjects,
                isIncluded: label.isIncluded,
                slicePath: FileManager.default.fileExists(atPath: slice.path) ? slice.path : nil
            )
        }
    }

    /// The first sentence of a project's README, if it has one.
    private func readmePurpose(of project: String) -> String? {
        let folder = source.scheme.singleRepoName != nil ? source.rootPath : SourcePath.absolute(project, root: source.rootPath)
        for name in ["README.md", "readme.md", "Readme.md", "README"] {
            let path = (folder as NSString).appendingPathComponent(name)
            guard let handle = FileHandle(forReadingAtPath: path) else { continue }
            defer { try? handle.close() }
            let data = (try? handle.read(upToCount: 8_192)) ?? Data()
            return AgentGuide.purpose(fromReadme: String(decoding: data, as: UTF8.self))
        }
        return nil
    }

    func writeAgentGuide(_ text: String) throws {
        try AgentSetup.write(text, to: guideURL.path)
    }

    func resolve(_ answer: QueryAnswer) throws -> [AnswerItem] {
        try index.resolve(answer)
    }

    func reviewScene(for finding: Finding) throws -> GraphScene {
        try index.reviewScene(for: finding)
    }

    func location(ofNode id: String) throws -> NodeLocation? {
        try index.location(ofNode: id)
    }

    func nodeDetail(id: String) throws -> NodeDetail? {
        guard let node = try index.nodeRow(id: id) else { return nil }
        let (neighbours, total) = try index.neighbours(of: id)
        let ruleID = rules.hidingRule(for: node.facts)
        let rule = ruleID.flatMap { id in rules.active.first { $0.id == id } }
        return NodeDetail(
            id: id,
            label: node.label,
            path: node.facts.path,
            location: node.location,
            project: node.facts.project,
            fileType: node.facts.fileType,
            communityLabel: node.communityLabel,
            isHidden: node.hidden,
            hidingRuleID: ruleID,
            hidingRuleSummary: ruleID == RuleSet.seedTextRule ? "Starter text, unchanged since Graphitree seeded this repo" : rule.map(Self.summary),
            absolutePath: node.facts.path.isEmpty ? nil : source.existingPath(for: node.facts.path),
            neighbours: neighbours,
            neighbourTotal: total
        )
    }

    private func ruleRows() -> [RuleRow] {
        let parser = ISO8601DateFormatter()
        let orphaned = (try? index.orphanedRules(rules)) ?? []
        return rules.active.reversed().map { entry in
            let effect = effects[entry.id] ?? GraphIndex.RuleEffect()
            return RuleRow(
                id: entry.id,
                batch: entry.batch,
                at: parser.date(from: entry.at) ?? .distantPast,
                summary: Self.summary(of: entry),
                affects: orphaned.contains(entry.id) ? "Matches nothing" : Self.affects(entry, effect: effect),
                isKeep: entry.op == CurationEntry.Op.keep,
                isOrphaned: orphaned.contains(entry.id)
            )
        }
    }

    private static func summary(of entry: CurationEntry) -> String {
        switch entry.op {
        case CurationEntry.Op.hidePath: return "Hide \(entry.glob ?? "")"
        case CurationEntry.Op.hideNode: return "Hide node \(entry.note ?? entry.node ?? "")"
        case CurationEntry.Op.hideConfigLabel: return "Hide config key \(entry.label ?? "")"
        case CurationEntry.Op.rejectEdges: return "Reject cross-project code links on \(entry.note ?? entry.target ?? "")"
        case CurationEntry.Op.rejectEdge: return "Reject link \(entry.note ?? "")"
        case CurationEntry.Op.keep: return "Keep \(entry.note ?? entry.finding ?? "")"
        default: return entry.op
        }
    }

    private static func affects(_ entry: CurationEntry, effect: GraphIndex.RuleEffect) -> String {
        switch entry.op {
        case CurationEntry.Op.keep: return "Stays out of the queue"
        case CurationEntry.Op.rejectEdges, CurationEntry.Op.rejectEdge:
            return "\(effect.edges.formatted()) \(effect.edges == 1 ? "link" : "links")"
        default:
            return "\(effect.nodes.formatted()) \(effect.nodes == 1 ? "node" : "nodes")"
        }
    }

    private func cleanStatus() -> CleanStatus {
        func modified(_ url: URL) -> Date? {
            (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        }
        guard let written = modified(cleanURL) else { return .notWritten }
        let newestInput = [modified(logURL), modified(source.graphURL)].compactMap { $0 }.max() ?? .distantPast
        return written >= newestInput ? .upToDate(written) : .outOfDate(written)
    }

    // MARK: - Clean output

    /// Writes `graph.clean.json` beside `graph.json` without touching it. Temp file then rename,
    /// so `graphify query` never sees a partial file.
    @discardableResult
    func writeCleanGraph() throws -> CleanGraphResult {
        let data = try Data(contentsOf: source.graphURL, options: .mappedIfSafe)
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawNodes = root["nodes"] as? [[String: Any]] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        let edgeKey = root["links"] != nil ? "links" : "edges"
        let rawEdges = root[edgeKey] as? [[String: Any]] ?? []

        var facts: [String: NodeFacts] = [:]
        facts.reserveCapacity(rawNodes.count)
        var hidden = Set<String>()
        let keptNodes = rawNodes.filter { node in
            guard let id = node["id"] as? String else { return true }
            let path = node["source_file"] as? String ?? ""
            let label = node["label"] as? String ?? id
            let normLabel = node["norm_label"] as? String
            let fact = NodeFacts(
                id: id,
                path: path,
                project: source.scheme.project(of: path),
                labelKey: (normLabel?.isEmpty == false ? normLabel : nil) ?? label,
                fileType: node["file_type"] as? String
            )
            facts[id] = fact
            guard rules.hidingRule(for: fact) == nil else {
                hidden.insert(id)
                return false
            }
            return true
        }

        let keptEdges = rawEdges.filter { edge in
            guard let source = edge["source"] as? String, let target = edge["target"] as? String else { return true }
            if hidden.contains(source) || hidden.contains(target) { return false }
            let relation = edge["relation"] as? String
            let isSuspect = EdgeKind.isSuspect(
                relation: relation,
                sourceProject: facts[source]?.project,
                targetProject: facts[target]?.project,
                bothCode: facts[source]?.fileType == "code" && facts[target]?.fileType == "code"
            )
            return rules.rejectingRule(source: source, target: target, relation: relation ?? "", isSuspect: isSuspect) == nil
        }

        root["nodes"] = keptNodes
        root[edgeKey] = keptEdges
        var hyperedgeCount = 0
        if let hyperedges = root["hyperedges"] as? [[String: Any]] {
            let trimmed = Self.trim(hyperedges, hidden: hidden)
            root["hyperedges"] = trimmed
            hyperedgeCount = trimmed.count
        }
        if var graph = root["graph"] as? [String: Any], let hyperedges = graph["hyperedges"] as? [[String: Any]] {
            graph["hyperedges"] = Self.trim(hyperedges, hidden: hidden)
            root["graph"] = graph
        }

        let output = try JSONSerialization.data(withJSONObject: root, options: [.withoutEscapingSlashes])
        let temporary = cleanURL.path + ".\(UUID().uuidString).tmp"
        defer { try? FileManager.default.removeItem(atPath: temporary) }
        try output.write(to: URL(fileURLWithPath: temporary))
        try ignoreCleanGraphInGit()
        guard rename(temporary, cleanURL.path) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        return CleanGraphResult(nodes: keptNodes.count, edges: keptEdges.count, hyperedges: hyperedgeCount)
    }

    /// A group needs at least two members left to still mean anything.
    private static func trim(_ hyperedges: [[String: Any]], hidden: Set<String>) -> [[String: Any]] {
        hyperedges.compactMap { hyperedge in
            guard let members = hyperedge["nodes"] as? [String] else { return hyperedge }
            let remaining = members.filter { !hidden.contains($0) }
            guard remaining.count >= 2 else { return nil }
            var trimmed = hyperedge
            trimmed["nodes"] = remaining
            return trimmed
        }
    }

    /// The clean graph is derived and about 50 MB, so it stays out of the graph's backup repo.
    private func ignoreCleanGraphInGit() throws {
        let directory = source.outDirectory
        guard FileManager.default.fileExists(atPath: directory.appendingPathComponent(".git").path) else { return }
        let url = directory.appendingPathComponent(".gitignore")
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        guard !existing.split(separator: "\n").contains("graph.clean.json") else { return }
        let separator = existing.isEmpty || existing.hasSuffix("\n") ? "" : "\n"
        try (existing + separator + "graph.clean.json\n").write(to: url, atomically: true, encoding: .utf8)
    }
}

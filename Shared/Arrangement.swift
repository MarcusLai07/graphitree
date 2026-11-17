import Foundation

// Arrange: which area each project sits in, which projects are left out of the graph, and how areas
// group into graphs, each with its own backup. Everything starts from the main-folder labels, so
// nothing changes until the person moves something.
//
// Saved in two files. `folders.json` keeps the labels, areas made in Arrange and per-project
// placements, because the map reads them. `graphs.json` keeps the graphs and their backups.

/// An area the person made in Arrange. Areas that come from labels are never saved here.
struct ArrangedArea: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var purpose: FolderPurpose
}

/// Where one project goes, when it isn't where its main folder's label puts it.
enum Placement: Hashable, Sendable {
    case area(String)
    case leftOut(reason: String)

    var areaID: String? {
        if case .area(let id) = self { return id }
        return nil
    }

    var isLeftOut: Bool { areaID == nil }
}

extension Placement: Codable {
    /// Saved as one string: an area id, or `left-out:` and the reason.
    private static let leftOutPrefix = "left-out:"

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        self = text.hasPrefix(Self.leftOutPrefix) ? .leftOut(reason: String(text.dropFirst(Self.leftOutPrefix.count))) : .area(text)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .area(let id): try container.encode(id)
        case .leftOut(let reason): try container.encode(Self.leftOutPrefix + reason)
        }
    }
}

/// An area as Arrange shows it: from labels, or made by the person.
struct AreaInfo: Hashable, Identifiable, Sendable {
    let id: String
    var name: String
    var purpose: FolderPurpose
    /// The main folders whose label gives this area. Empty for an area made in Arrange.
    var labelPaths: [String]

    var isMade: Bool { labelPaths.isEmpty }
}

// MARK: - Graphs and their backups

/// How one graph is backed up.
struct BackupPlan: Codable, Hashable, Sendable {
    enum Destination: String, Codable, CaseIterable, Sendable {
        case github, local, none
    }

    enum When: String, Codable, CaseIterable, Sendable {
        case rebuild, daily, manual
    }

    var destination: Destination = .none
    /// The GitHub login it pushes as.
    var login: String?
    /// The repo's name under that login.
    var repo = ""
    var when: When = .manual
    /// Save the meaning AI extracted (`cache/semantic`).
    var semantic = true
    /// Save the map page and report, readable on GitHub without the app.
    var map = true

    init(destination: Destination = .none, login: String? = nil, repo: String = "", when: When = .manual, semantic: Bool = true, map: Bool = true) {
        self.destination = destination
        self.login = login
        self.repo = repo
        self.when = when
        self.semantic = semantic
        self.map = map
    }

    private enum CodingKeys: String, CodingKey {
        case destination, login, repo, when, semantic, map
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        destination = try container.decodeIfPresent(Destination.self, forKey: .destination) ?? .none
        login = try container.decodeIfPresent(String.self, forKey: .login)
        repo = try container.decodeIfPresent(String.self, forKey: .repo) ?? ""
        when = try container.decodeIfPresent(When.self, forKey: .when) ?? .manual
        semantic = try container.decodeIfPresent(Bool.self, forKey: .semantic) ?? true
        map = try container.decodeIfPresent(Bool.self, forKey: .map) ?? true
    }
}

/// One graph: the areas it holds and where its backup goes. Separate graphs are cut from the one
/// build, so splitting costs no extra build or tokens.
struct GraphPlan: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var areaIDs: [String]
    var backup = BackupPlan()
    /// The backup that also carries the playbook. Exactly one graph is home.
    var isHome = false

    init(id: String, name: String, areaIDs: [String], backup: BackupPlan = BackupPlan(), isHome: Bool = false) {
        self.id = id
        self.name = name
        self.areaIDs = areaIDs
        self.backup = backup
        self.isHome = isHome
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, areaIDs, backup, isHome
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        areaIDs = try container.decodeIfPresent([String].self, forKey: .areaIDs) ?? []
        backup = try container.decodeIfPresent(BackupPlan.self, forKey: .backup) ?? BackupPlan()
        isHome = try container.decodeIfPresent(Bool.self, forKey: .isHome) ?? false
    }

    /// `personal` for "Personal", `machine-wide` for "Machine-wide".
    var slug: String { Self.slug(name) }

    static func slug(_ name: String) -> String {
        let lowered = name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let joined = String(lowered).split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
        return joined.isEmpty ? "graph" : joined
    }

    /// A backup repo name for a graph, such as `personal-kb`.
    static func suggestedRepo(for name: String) -> String { slug(name) + "-kb" }
}

/// `graphs.json`, next to `folders.json`.
enum GraphPlans {
    static let fileName = "graphs.json"
    static let defaultName = "Machine-wide"

    private struct File: Codable {
        var version = 1
        var graphs: [GraphPlan]
    }

    static func load(from outDirectory: URL) -> [GraphPlan]? {
        guard let data = try? Data(contentsOf: outDirectory.appendingPathComponent(fileName)) else { return nil }
        return (try? JSONDecoder().decode(File.self, from: data))?.graphs
    }

    static func save(_ graphs: [GraphPlan], to outDirectory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)
        try encoder.encode(File(graphs: graphs)).write(to: outDirectory.appendingPathComponent(fileName), options: .atomic)
    }

    /// Every area in exactly one graph, no empty graphs (but always one), names unique, one home.
    /// New areas join the first graph.
    static func resolved(_ graphs: [GraphPlan], areaIDs: [String]) -> [GraphPlan] {
        let known = Set(areaIDs)
        var seen = Set<String>()
        var result: [GraphPlan] = graphs.map { graph in
            var graph = graph
            graph.areaIDs = graph.areaIDs.filter { known.contains($0) && seen.insert($0).inserted }
            return graph
        }
        let missing = areaIDs.filter { !seen.contains($0) }
        if result.isEmpty {
            result = [GraphPlan(id: "machine-wide", name: defaultName, areaIDs: [])]
        }
        result[0].areaIDs += missing
        if result.count > 1 { result.removeAll { $0.areaIDs.isEmpty } }
        if result.isEmpty { result = [GraphPlan(id: "machine-wide", name: defaultName, areaIDs: [])] }
        var names = Set<String>()
        for index in result.indices {
            let base = result[index].name.trimmingCharacters(in: .whitespaces).isEmpty ? "Graph" : result[index].name
            var name = base
            var counter = 2
            while names.contains(name.lowercased()) {
                name = "\(base) \(counter)"
                counter += 1
            }
            names.insert(name.lowercased())
            result[index].name = name
        }
        if result.filter(\.isHome).count != 1 {
            let home = result.firstIndex(where: \.isHome) ?? 0
            for index in result.indices { result[index].isHome = index == home }
        }
        return result
    }
}

// MARK: - The arrangement

/// One project as Arrange shows it.
struct ArrangeProject: Hashable, Identifiable, Sendable {
    /// Relative to the root, such as `personal/odyssey` or `demo-app`.
    let path: String
    var nodes = 0
    var remote: String?
    /// Nil when there's no git identity to check against, or it isn't a repo.
    var hasOwnCommits: Bool?
    /// The main repo, when this is a git worktree of it.
    var worktreeOf: String?
    var isRepo = false

    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
    var mainFolder: String { String(path.split(separator: "/").first ?? Substring(path)) }
}

/// The whole arrangement, as saved plus what's on disk. Value type, so a draft can be undone by
/// keeping copies.
struct Arrangement: Equatable, Sendable {
    var labels: [FolderLabel]
    /// The person's labels. Compared field by field, so renaming one counts as a change.
    var kinds: [FolderPurpose] {
        get { kindList.all }
        set { kindList.all = newValue }
    }
    private var kindList = KindList(all: FolderPurpose.defaults)

    private struct KindList: Equatable, Sendable {
        var all: [FolderPurpose]
        static func == (lhs: KindList, rhs: KindList) -> Bool { lhs.all.isSame(as: rhs.all) }
    }
    var arrangedAreas: [ArrangedArea] = []
    var placement: [String: Placement] = [:]
    var graphs: [GraphPlan] = []
    /// What's on disk now. Not saved.
    var projects: [ArrangeProject] = []
    /// Lines already in `.graphifyignore`, so projects left out by hand show as left out. Not saved.
    var ignoredLines: Set<String> = []

    init(labels: [FolderLabel], arrangedAreas: [ArrangedArea] = [], placement: [String: Placement] = [:], graphs: [GraphPlan] = [], projects: [ArrangeProject] = [], ignoredLines: Set<String> = []) {
        self.labels = labels
        self.arrangedAreas = arrangedAreas
        self.placement = placement
        self.graphs = graphs
        self.projects = projects
        self.ignoredLines = ignoredLines
        normalise()
    }

    init(map: FolderMap, labels: [FolderLabel]? = nil, graphs: [GraphPlan]?, projects: [ArrangeProject] = [], ignoredLines: Set<String> = []) {
        self.init(labels: labels ?? map.folders, arrangedAreas: map.arrangedAreas, placement: map.placement, graphs: graphs ?? [], projects: projects, ignoredLines: ignoredLines)
        kinds = map.kinds
    }

    /// What `folders.json` holds.
    var folderMap: FolderMap { FolderMap(folders: labels, arrangedAreas: arrangedAreas, placement: placement, kinds: kinds) }

    // MARK: Areas

    /// Areas that come from labels. Included folders whose labels give the same area name share
    /// one area, named after the first, the way the map has always grouped them.
    var labelAreas: [AreaInfo] {
        var order: [String] = []
        var byName: [String: AreaInfo] = [:]
        for label in labels where label.isIncluded {
            let key = label.areaName.lowercased()
            if byName[key] != nil {
                byName[key]?.labelPaths.append(label.path)
            } else {
                byName[key] = AreaInfo(id: label.path, name: label.areaName, purpose: label.purpose, labelPaths: [label.path])
                order.append(key)
            }
        }
        return order.compactMap { byName[$0] }
    }

    var allAreas: [AreaInfo] {
        labelAreas + arrangedAreas.map { AreaInfo(id: $0.id, name: $0.name, purpose: $0.purpose, labelPaths: []) }
    }

    /// Areas worth showing: those holding a project, plus areas made in Arrange even when empty.
    var areas: [AreaInfo] {
        let used = Set(projects.compactMap { placement(of: $0.path).areaID })
        return allAreas.filter { used.contains($0.id) || $0.isMade }
    }

    func area(_ id: String) -> AreaInfo? { allAreas.first { $0.id == id } }

    func project(_ path: String) -> ArrangeProject? { projects.first { $0.path == path } }

    // MARK: Placement

    private func label(of project: String) -> FolderLabel? {
        let top = String(project.split(separator: "/").first ?? Substring(project))
        return labels.first { $0.path == top }
    }

    /// Where a project goes when nothing has been dragged: its main folder's area, or left out when
    /// that folder is, when it's listed in `.graphifyignore`, or when it's a worktree of another repo.
    func defaultPlacement(of path: String) -> Placement {
        guard let label = label(of: path) else { return .leftOut(reason: "Not labelled") }
        guard label.isIncluded else { return .leftOut(reason: label.purpose.title) }
        if path != label.path, ignoredLines.contains(FolderIgnore.line(for: path)) { return .leftOut(reason: "Left out") }
        if project(path)?.worktreeOf != nil { return .leftOut(reason: "Worktree") }
        guard let area = labelAreas.first(where: { $0.labelPaths.contains(label.path) }) else { return .leftOut(reason: "Not labelled") }
        return .area(area.id)
    }

    func placement(of path: String) -> Placement {
        if let saved = placement[path] {
            if let id = saved.areaID, area(id) == nil { return defaultPlacement(of: path) }
            return saved
        }
        return defaultPlacement(of: path)
    }

    func projects(in areaID: String) -> [ArrangeProject] {
        projects.filter { placement(of: $0.path).areaID == areaID }.sorted { $0.nodes != $1.nodes ? $0.nodes > $1.nodes : $0.path < $1.path }
    }

    var leftOut: [ArrangeProject] {
        projects.filter { placement(of: $0.path).isLeftOut }.sorted { $0.path < $1.path }
    }

    func leftOutReason(_ path: String) -> String? {
        if case .leftOut(let reason) = placement(of: path) { return reason }
        return nil
    }

    func graph(ofArea areaID: String) -> GraphPlan? { graphs.first { $0.areaIDs.contains(areaID) } }

    func graph(ofProject path: String) -> GraphPlan? { placement(of: path).areaID.flatMap(graph(ofArea:)) }

    func projects(inGraph graphID: String) -> [ArrangeProject] {
        guard let graph = graphs.first(where: { $0.id == graphID }) else { return [] }
        return graph.areaIDs.flatMap { projects(in: $0) }
    }

    func nodes(inGraph graphID: String) -> Int { projects(inGraph: graphID).reduce(0) { $0 + $1.nodes } }

    func nodes(inArea areaID: String) -> Int { projects(in: areaID).reduce(0) { $0 + $1.nodes } }

    /// Why a project would be left out if the person drags it there: a worktree, someone else's
    /// code, or simply left out.
    func reasonToLeaveOut(_ path: String) -> String {
        guard let project = project(path) else { return "Left out" }
        if project.worktreeOf != nil { return "Worktree" }
        if project.hasOwnCommits == false { return "Reference" }
        return "Left out"
    }

    // MARK: Changes

    enum Target: Hashable, Sendable {
        case area(String)
        case graph(String)
        case newGraph
        case leftOut
    }

    /// Puts projects somewhere. Returns why it couldn't, or nil.
    @discardableResult
    mutating func put(_ paths: [String], in target: Target) -> String? {
        switch target {
        case .leftOut:
            for path in paths { set(path, .leftOut(reason: reasonToLeaveOut(path))) }
        case .area(let id):
            guard area(id) != nil else { return "That area isn't there any more." }
            for path in paths {
                if let refusal = include(path) { return refusal }
                set(path, .area(id))
            }
        case .graph(let graphID):
            guard let graphIndex = graphs.firstIndex(where: { $0.id == graphID }) else { return "That graph isn't there any more." }
            for path in paths {
                if let refusal = include(path) { return refusal }
                let purpose = purposeFor(path)
                let existing = graphs[graphIndex].areaIDs.compactMap(area).first { $0.purpose == purpose }
                let id = existing?.id ?? addArea(purpose: purpose, toGraph: graphID)
                set(path, .area(id))
            }
        case .newGraph:
            for path in paths {
                if let refusal = include(path) { return refusal }
            }
            let purposes = paths.map(purposeFor)
            let purpose = purposes.max { a, b in purposes.filter { $0 == a }.count < purposes.filter { $0 == b }.count } ?? .other
            let graphID = newGraph(named: purpose.title)
            let id = addArea(purpose: purpose, toGraph: graphID)
            for path in paths { set(path, .area(id)) }
        }
        normalise()
        return nil
    }

    /// Moves a whole area to another graph, a graph of its own, or out of the graph altogether.
    mutating func moveArea(_ id: String, to target: Target) {
        switch target {
        case .leftOut:
            for project in projects(in: id) { set(project.path, .leftOut(reason: reasonToLeaveOut(project.path))) }
            arrangedAreas.removeAll { $0.id == id }
        case .graph(let graphID):
            for index in graphs.indices { graphs[index].areaIDs.removeAll { $0 == id } }
            if let index = graphs.firstIndex(where: { $0.id == graphID }) { graphs[index].areaIDs.append(id) }
        case .newGraph:
            let name = area(id)?.name ?? "Graph"
            for index in graphs.indices { graphs[index].areaIDs.removeAll { $0 == id } }
            let graphID = newGraph(named: name)
            if let index = graphs.firstIndex(where: { $0.id == graphID }) { graphs[index].areaIDs.append(id) }
        case .area(let other):
            // Merging two areas: the projects move, and an area made in Arrange goes away.
            guard other != id, area(other) != nil else { return }
            for project in projects(in: id) { set(project.path, .area(other)) }
            arrangedAreas.removeAll { $0.id == id }
        }
        normalise()
    }

    /// One graph per area, the first keeping the current graph's backup.
    mutating func split() {
        guard graphs.count == 1, let first = graphs.first else { return }
        let ids = first.areaIDs.filter { !projects(in: $0).isEmpty || area($0)?.isMade == true }
        guard ids.count > 1 else { return }
        graphs = ids.enumerated().map { index, id in
            let name = area(id)?.name ?? "Graph"
            return index == 0
                ? GraphPlan(id: first.id, name: name, areaIDs: [id], backup: first.backup, isHome: true)
                : GraphPlan(id: "graph-" + Self.shortID(), name: name, areaIDs: [id])
        }
        normalise()
    }

    /// Everything back into one graph, which keeps the home graph's backup.
    mutating func merge() {
        guard graphs.count > 1 else { return }
        let home = graphs.first(where: \.isHome) ?? graphs[0]
        graphs = [GraphPlan(id: home.id, name: GraphPlans.defaultName, areaIDs: graphs.flatMap(\.areaIDs), backup: home.backup, isHome: true)]
        normalise()
    }

    /// Splits a graph so each GitHub account the git rules give its projects gets a graph of its
    /// own. Areas that are all one account move whole; mixed areas split by project. The graph keeps
    /// the projects of the account it backs up to (or the most common one). Returns the new graphs.
    @discardableResult
    mutating func splitByAccount(_ graphID: String, login: (String) -> String?) -> [String] {
        guard let graph = graphs.first(where: { $0.id == graphID }) else { return [] }
        let byLogin = Dictionary(grouping: projects(inGraph: graphID)) { login($0.path) ?? "" }
        guard byLogin.count > 1 else { return [] }
        let keep = graph.backup.login.flatMap { byLogin[$0] != nil ? $0 : nil }
            ?? byLogin.max { $0.value.count != $1.value.count ? $0.value.count < $1.value.count : $0.key > $1.key }!.key
        var graphFor: [String: String] = [keep: graphID]
        var created: [String] = []
        func target(for account: String) -> Target { graphFor[account].map(Target.graph) ?? .newGraph }
        func remember(_ account: String, before: Set<String>) {
            guard graphFor[account] == nil, let made = graphs.first(where: { !before.contains($0.id) }) else { return }
            graphFor[account] = made.id
            created.append(made.id)
        }
        for areaID in graph.areaIDs {
            let accounts = Dictionary(grouping: projects(in: areaID)) { login($0.path) ?? "" }
            if accounts.count == 1, let account = accounts.keys.first, account != keep {
                let before = Set(graphs.map(\.id))
                moveArea(areaID, to: target(for: account))
                remember(account, before: before)
            } else if accounts.count > 1 {
                for (account, members) in accounts.sorted(by: { $0.key < $1.key }) where account != keep {
                    let before = Set(graphs.map(\.id))
                    put(members.map(\.path), in: target(for: account))
                    remember(account, before: before)
                }
            }
        }
        for (account, id) in graphFor where id != graphID && !account.isEmpty {
            guard let index = graphs.firstIndex(where: { $0.id == id }) else { continue }
            graphs[index].backup = BackupPlan(destination: .github, login: account, repo: GraphPlan.suggestedRepo(for: graphs[index].name), when: graph.backup.when)
        }
        normalise()
        return created
    }

    @discardableResult
    mutating func addArea(purpose: FolderPurpose, toGraph graphID: String? = nil, name: String? = nil) -> String {
        let base = name ?? purpose.title
        var title = base
        var counter = 2
        while allAreas.contains(where: { $0.name.lowercased() == title.lowercased() }) {
            title = "\(base) \(counter)"
            counter += 1
        }
        let id = "area-" + Self.shortID()
        arrangedAreas.append(ArrangedArea(id: id, name: title, purpose: purpose))
        let target = graphID.flatMap { id in graphs.firstIndex { $0.id == id } } ?? 0
        if graphs.isEmpty { graphs = [GraphPlan(id: "machine-wide", name: GraphPlans.defaultName, areaIDs: [])] }
        graphs[min(target, graphs.count - 1)].areaIDs.append(id)
        return id
    }

    /// Renames an area. One from labels gets the name on its labels, so the map shows it too.
    mutating func renameArea(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let index = arrangedAreas.firstIndex(where: { $0.id == id }) {
            arrangedAreas[index].name = trimmed
        } else if let info = area(id) {
            for index in labels.indices where info.labelPaths.contains(labels[index].path) { labels[index].name = trimmed }
        }
        normalise()
    }

    /// Changes an area's purpose. For an area from labels, its labels change, so there's one place
    /// purpose lives. The name is kept, so the area stays the same area.
    mutating func setPurpose(_ purpose: FolderPurpose, ofArea id: String) {
        if let index = arrangedAreas.firstIndex(where: { $0.id == id }) {
            arrangedAreas[index].purpose = purpose
        } else if let info = area(id) {
            for index in labels.indices where info.labelPaths.contains(labels[index].path) {
                if labels[index].name.trimmingCharacters(in: .whitespaces).isEmpty { labels[index].name = info.name }
                labels[index].purpose = purpose
            }
        }
        normalise()
    }

    /// Replaces the list of labels. Folders and areas take their label's new name and colour, and
    /// those whose label was removed become Other.
    mutating func setKinds(_ list: [FolderPurpose]) {
        kinds = list.contains { $0.id == FolderPurpose.other.id } ? list : list + [.other]
        for index in labels.indices { labels[index].purpose = kinds.resolve(labels[index].purpose) }
        for index in arrangedAreas.indices { arrangedAreas[index].purpose = kinds.resolve(arrangedAreas[index].purpose) }
        normalise()
    }

    /// What one main folder's label tells AI tools, in the person's words.
    mutating func setNote(_ note: String, forFolder path: String) {
        guard let index = labels.firstIndex(where: { $0.path == path }) else { return }
        labels[index].note = note
    }

    /// Whether each subfolder of a main folder is a project of its own. Projects follow on save.
    mutating func setHoldsProjects(_ holds: Bool, forFolder path: String) {
        guard let index = labels.firstIndex(where: { $0.path == path }) else { return }
        labels[index].holdsProjects = holds
    }

    /// How many main folders and made areas use a label.
    func uses(of kind: FolderPurpose) -> Int {
        labels.filter { $0.purpose == kind }.count + arrangedAreas.filter { $0.purpose == kind }.count
    }

    /// Removes an empty area made in Arrange.
    mutating func removeArea(_ id: String) {
        guard projects(in: id).isEmpty else { return }
        arrangedAreas.removeAll { $0.id == id }
        normalise()
    }

    mutating func renameGraph(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let index = graphs.firstIndex(where: { $0.id == id }) else { return }
        graphs[index].name = trimmed
        normalise()
    }

    mutating func setBackup(_ backup: BackupPlan, forGraph id: String) {
        guard let index = graphs.firstIndex(where: { $0.id == id }) else { return }
        graphs[index].backup = backup
    }

    mutating func makeHome(_ id: String) {
        for index in graphs.indices { graphs[index].isHome = graphs[index].id == id }
    }

    // MARK: Helpers

    /// The purpose a project's own main folder gives it.
    private func purposeFor(_ path: String) -> FolderPurpose { label(of: path)?.purpose ?? .other }

    /// Brings a project back into the graph. A main folder that is itself the project gets its
    /// label switched back on; a project inside a left-out group can't come back on its own.
    private mutating func include(_ path: String) -> String? {
        guard let label = label(of: path), !label.isIncluded else { return nil }
        guard path == label.path, let index = labels.firstIndex(where: { $0.path == label.path }) else {
            return "\(label.path)/ is left out as a whole. Turn it on in Main Folder Labels first."
        }
        labels[index].isIncluded = true
        return nil
    }

    /// Saves a placement only when it differs from where the labels would put the project.
    private mutating func set(_ path: String, _ value: Placement) {
        placement[path] = defaultPlacement(of: path) == value ? nil : value
    }

    private mutating func newGraph(named name: String) -> String {
        let id = "graph-" + Self.shortID()
        graphs.append(GraphPlan(id: id, name: name, areaIDs: []))
        return id
    }

    /// Keeps graphs consistent: every shown area in one graph, no empty graphs, unique names, and
    /// "Machine-wide" only while there's one graph.
    private mutating func normalise() {
        // Placements pointing at areas that no longer exist fall back to the labels.
        placement = placement.filter { _, value in value.areaID.map { area($0) != nil } ?? true }
        let shown = areas.map(\.id)
        let wasSplit = graphs.count > 1
        graphs = GraphPlans.resolved(graphs, areaIDs: shown)
        if graphs.count > 1 {
            for index in graphs.indices where graphs[index].name == GraphPlans.defaultName {
                let biggest = graphs[index].areaIDs.max { nodes(inArea: $0) < nodes(inArea: $1) }
                graphs[index].name = biggest.flatMap(area)?.name ?? "Graph"
            }
            graphs = GraphPlans.resolved(graphs, areaIDs: shown)
        } else if wasSplit, graphs.count == 1 {
            graphs[0].name = GraphPlans.defaultName
        }
    }

    static func shortID() -> String { String(UUID().uuidString.prefix(8)).lowercased() }

    // MARK: Effects

    /// `.graphifyignore` lines to add and take away so the next build follows the arrangement.
    /// Whole main folders follow their labels; single projects follow their placement.
    var ignoreChanges: (add: [String], remove: [String]) {
        var add = FolderIgnore.changes(for: labels).add
        var remove = FolderIgnore.changes(for: labels).remove
        for project in projects {
            guard let label = label(of: project.path), label.isIncluded else { continue }
            let line = FolderIgnore.line(for: project.path)
            // A main folder that is itself the project and was dragged to Left out keeps its label
            // switched on, so its own line is what leaves it out.
            if placement(of: project.path).isLeftOut { add.append(line) } else if project.path != label.path { remove.append(line) }
        }
        return (Array(Set(add)).sorted(), Array(Set(remove).subtracting(add)).sorted())
    }

    /// Areas by project, for the map, where a project sits somewhere its main folder doesn't put it.
    var projectAreas: [String: FolderArea] {
        var result: [String: FolderArea] = [:]
        for (path, value) in placement {
            guard let id = value.areaID, let info = area(id) else { continue }
            result[path] = FolderArea(name: info.name, purpose: info.purpose)
        }
        return result
    }

    /// One line per thing that differs from another arrangement, for the "Changes" list.
    func changes(from before: Arrangement) -> [String] {
        var lines: [String] = []
        if graphs.count != before.graphs.count {
            lines.append(graphs.count == 1 ? "One graph instead of \(before.graphs.count)" : "\(graphs.count) graphs instead of \(before.graphs.count)")
        }
        func where_(_ arrangement: Arrangement, _ path: String) -> String {
            switch arrangement.placement(of: path) {
            case .leftOut: return "Left out"
            case .area(let id):
                let name = arrangement.area(id)?.name ?? "?"
                guard arrangement.graphs.count > 1, let graph = arrangement.graph(ofArea: id), graph.name != name else { return name }
                return "\(graph.name) › \(name)"
            }
        }
        for project in projects {
            let old = where_(before, project.path)
            let new = where_(self, project.path)
            if old != new { lines.append("\(project.name): \(old) → \(new)") }
        }
        return lines
    }
}

// MARK: - What's on disk

enum ArrangeProjects {
    /// Every project the next build would see: each subfolder of a group, and every other main
    /// folder. Node counts come from the current graph.
    static func list(root: String, scan: FolderScanResult, labels: [FolderLabel], nodes: [String: Int]) -> [ArrangeProject] {
        let fileManager = FileManager.default
        var repos: [String: RepoInfo] = [:]
        for folder in scan.folders {
            if let repo = folder.repo { repos[repo.path] = repo }
            for child in folder.children { repos[child.path] = child }
        }
        func project(_ path: String) -> ArrangeProject {
            let repo = repos[path]
            return ArrangeProject(path: path, nodes: nodes[path] ?? 0, remote: repo?.remote, hasOwnCommits: repo?.hasOwnCommits, worktreeOf: repo?.worktreeOf, isRepo: repo != nil)
        }
        var result: [ArrangeProject] = []
        for folder in scan.folders {
            let label = labels.first { $0.path == folder.path }
            if label?.holdsProjects == true {
                let directory = (root as NSString).appendingPathComponent(folder.path)
                let names = ((try? fileManager.contentsOfDirectory(atPath: directory)) ?? []).filter { name in
                    guard !name.hasPrefix("."), !FolderScan.skipped.contains(name) else { return false }
                    var isDirectory: ObjCBool = false
                    return fileManager.fileExists(atPath: (directory as NSString).appendingPathComponent(name), isDirectory: &isDirectory) && isDirectory.boolValue
                }
                for name in names.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
                    result.append(project(folder.path + "/" + name))
                }
            } else {
                result.append(project(folder.path))
            }
        }
        return result
    }
}

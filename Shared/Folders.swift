import Foundation

// Folders: the person points Graphitree at a root and says what each main folder in it is for. Labels
// decide which folders hold projects, the map's areas and colours, what's left out of the graph,
// what the guide tells AI tools, and a graph slice per folder. Tidy-up tips suggest labels and
// moves; nothing moves until the person confirms that one move.

/// A label for main folders: what a folder is for, and how Graphitree treats it. Everyone starts
/// with the defaults below. The person can rename and change any of them and add their own, and
/// the list is kept in `folders.json`. Each folder's label saves only the id.
struct FolderPurpose: Hashable, Identifiable, Sendable {
    /// Stable across renames. The defaults' ids are the names they've always been saved under.
    let id: String
    var title: String
    /// What it's for, in a sentence.
    var detail: String
    var symbol: String
    /// Its colour on the map: 0 green, 1 purple, 2 orange, anything else grey.
    var colorSlot: Int
    /// Folders with it stay out of the graph until the person turns them on.
    var isLeftOutByDefault: Bool
    /// Other people can read what's in it, such as a job's or a client's repos.
    var isShared: Bool
    /// Notes and docs rather than code, so the stack scan passes over it.
    var isDocs: Bool
    /// What the guide tells AI tools about folders with this label, beside each folder's own note.
    var guideText: String

    /// Two labels are the same label when their ids match, even after one is renamed or recoloured.
    static func == (lhs: FolderPurpose, rhs: FolderPurpose) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Whether every field matches, for telling an edited label from the saved one.
    func isSame(as other: FolderPurpose) -> Bool { Definition(self) == Definition(other) }

    var guideNote: String? {
        let text = guideText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    var isDefault: Bool { Self.defaults.contains { $0.id == id } }

    static let work = FolderPurpose(id: "work", title: "Work", detail: "Your job's code and docs.", symbol: "briefcase", colorSlot: 1, isShared: true)
    static let personal = FolderPurpose(id: "personal", title: "Personal", detail: "Your own projects.", symbol: "person", colorSlot: 0)
    static let client = FolderPurpose(id: "client", title: "Client", detail: "Work for one client, kept apart.", symbol: "building.2", colorSlot: 2, isShared: true)
    static let notes = FolderPurpose(id: "notes", title: "Notes and docs", detail: "Notes, docs and papers rather than code.", symbol: "doc.text", colorSlot: 3, isDocs: true)
    static let reference = FolderPurpose(
        id: "reference", title: "Reference", detail: "Someone else's code you keep to read. Left out of the graph by default.", symbol: "books.vertical", colorSlot: -1, isLeftOutByDefault: true,
        guideText: "Someone else's code. Read it for reference only, and don't treat its style as the owner's."
    )
    static let archive = FolderPurpose(
        id: "archive", title: "Archive", detail: "Old work you don't touch any more. Left out of the graph by default.", symbol: "archivebox", colorSlot: -1, isLeftOutByDefault: true,
        guideText: "Old work the owner doesn't touch any more."
    )
    static let other = FolderPurpose(id: "other", title: "Other", detail: "Anything else.", symbol: "folder", colorSlot: -1)

    /// The labels everyone starts with. Other is always kept: it's where a folder goes when its
    /// label is removed.
    static let defaults: [FolderPurpose] = [.work, .personal, .client, .notes, .reference, .archive, .other]

    init(id: String, title: String, detail: String = "", symbol: String = "folder", colorSlot: Int = -1, isLeftOutByDefault: Bool = false, isShared: Bool = false, isDocs: Bool = false, guideText: String = "") {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.colorSlot = colorSlot
        self.isLeftOutByDefault = isLeftOutByDefault
        self.isShared = isShared
        self.isDocs = isDocs
        self.guideText = guideText
    }

    /// The default with this id, or a stand-in until the person's list says what it is.
    static func standard(_ id: String) -> FolderPurpose {
        defaults.first { $0.id == id } ?? FolderPurpose(id: id, title: id.capitalized)
    }

    /// A new label of the person's own, with an id that won't clash.
    static func custom(title: String) -> FolderPurpose {
        FolderPurpose(id: "label-" + UUID().uuidString.prefix(8).lowercased(), title: title, symbol: "tag")
    }

    /// Every field, as the list in `folders.json` keeps it.
    struct Definition: Codable, Equatable, Sendable {
        var id: String
        var title: String
        var detail: String
        var symbol: String
        var colorSlot: Int
        var isLeftOutByDefault: Bool
        var isShared: Bool
        var isDocs: Bool
        var guideText: String

        init(_ purpose: FolderPurpose) {
            id = purpose.id
            title = purpose.title
            detail = purpose.detail
            symbol = purpose.symbol
            colorSlot = purpose.colorSlot
            isLeftOutByDefault = purpose.isLeftOutByDefault
            isShared = purpose.isShared
            isDocs = purpose.isDocs
            guideText = purpose.guideText
        }

        var purpose: FolderPurpose {
            FolderPurpose(id: id, title: title, detail: detail, symbol: symbol, colorSlot: colorSlot, isLeftOutByDefault: isLeftOutByDefault, isShared: isShared, isDocs: isDocs, guideText: guideText)
        }
    }
}

/// A folder's label is saved as its id, the way it always has been. The list says what it means.
extension FolderPurpose: Codable {
    init(from decoder: Decoder) throws {
        self = .standard(try decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

extension Array where Element == FolderPurpose {
    /// This list's version of a label, so a folder shows its label's current name and colour. A
    /// label that's no longer in the list becomes Other.
    func resolve(_ purpose: FolderPurpose) -> FolderPurpose {
        first { $0.id == purpose.id } ?? first { $0.id == FolderPurpose.other.id } ?? .other
    }

    /// Same labels, same order, every field the same.
    func isSame(as other: [FolderPurpose]) -> Bool {
        count == other.count && zip(self, other).allSatisfy { $0.isSame(as: $1) }
    }
}

/// What one main folder under the root is for.
struct FolderLabel: Codable, Hashable, Identifiable, Sendable {
    /// Relative to the root, such as `work` or `demo-app`.
    var path: String
    var purpose: FolderPurpose
    /// A name for the map. Empty uses the purpose, or the folder's own name.
    var name = ""
    /// What it's for, in the person's words. AI tools read it in the guide.
    var note = ""
    /// A group, like `work/`: each subfolder is a project.
    var holdsProjects = false
    var isIncluded = true

    var id: String { path }

    /// The area it shows in on the map. Work and personal folders share their purpose's area.
    var areaName: String {
        let given = name.trimmingCharacters(in: .whitespaces)
        if !given.isEmpty { return given }
        switch purpose {
        case .client, .other: return path
        default: return purpose.title
        }
    }
}

struct FolderMap: Codable, Equatable, Sendable {
    var version = 1
    var folders: [FolderLabel] = []
    /// Areas made in Arrange, beyond the ones labels give.
    var arrangedAreas: [ArrangedArea] = []
    /// Projects placed somewhere other than their main folder's area, or left out on their own.
    var placement: [String: Placement] = [:]
    /// The person's labels: the defaults, edited, plus their own.
    var kinds: [FolderPurpose] = FolderPurpose.defaults

    init(folders: [FolderLabel] = [], arrangedAreas: [ArrangedArea] = [], placement: [String: Placement] = [:], kinds: [FolderPurpose] = FolderPurpose.defaults) {
        self.kinds = Self.keepingOther(kinds)
        self.folders = folders
        self.arrangedAreas = arrangedAreas
        self.placement = placement
        resolveLabels()
    }

    private enum CodingKeys: String, CodingKey {
        case version, folders, arrangedAreas, placement, labelKinds
    }

    // Older files have only labels, so the Arrange keys are optional, and empty ones aren't written.
    // The list of labels is written only once it differs from the defaults.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        folders = try container.decodeIfPresent([FolderLabel].self, forKey: .folders) ?? []
        arrangedAreas = try container.decodeIfPresent([ArrangedArea].self, forKey: .arrangedAreas) ?? []
        placement = try container.decodeIfPresent([String: Placement].self, forKey: .placement) ?? [:]
        let saved = try container.decodeIfPresent([FolderPurpose.Definition].self, forKey: .labelKinds)
        kinds = Self.keepingOther(saved?.map(\.purpose) ?? FolderPurpose.defaults)
        resolveLabels()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(folders, forKey: .folders)
        if !arrangedAreas.isEmpty { try container.encode(arrangedAreas, forKey: .arrangedAreas) }
        if !placement.isEmpty { try container.encode(placement, forKey: .placement) }
        if !kinds.isSame(as: FolderPurpose.defaults) { try container.encode(kinds.map(FolderPurpose.Definition.init), forKey: .labelKinds) }
    }

    /// Other stays in every list, so a folder whose label is removed has somewhere to go.
    private static func keepingOther(_ kinds: [FolderPurpose]) -> [FolderPurpose] {
        kinds.contains { $0.id == FolderPurpose.other.id } ? kinds : kinds + [.other]
    }

    /// Folders and areas carry their label's current name, colour and traits.
    private mutating func resolveLabels() {
        for index in folders.indices { folders[index].purpose = kinds.resolve(folders[index].purpose) }
        for index in arrangedAreas.indices { arrangedAreas[index].purpose = kinds.resolve(arrangedAreas[index].purpose) }
    }

    func label(_ path: String) -> FolderLabel? { folders.first { $0.path == path } }

    var groups: Set<String> { Set(folders.filter(\.holdsProjects).map(\.path)) }

    /// Each main folder's area on the map, from its label.
    var areasByFolder: [String: FolderArea] {
        Dictionary(folders.map { ($0.path, FolderArea(name: $0.areaName, purpose: $0.purpose)) }, uniquingKeysWith: { first, _ in first })
    }

    /// Projects whose area differs from their main folder's, from Arrange.
    var areasByProject: [String: FolderArea] {
        placement.isEmpty ? [:] : Arrangement(labels: folders, arrangedAreas: arrangedAreas, placement: placement).projectAreas
    }
}

/// Where a project sits on the map.
struct FolderArea: Equatable, Sendable {
    let name: String
    let purpose: FolderPurpose
}

/// `folders.json`, next to the guide.
enum FolderFile {
    static let fileName = "folders.json"

    static func load(from outDirectory: URL) -> FolderMap? {
        guard let data = try? Data(contentsOf: outDirectory.appendingPathComponent(fileName)) else { return nil }
        return try? JSONDecoder().decode(FolderMap.self, from: data)
    }

    static func save(_ map: FolderMap, to outDirectory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)
        try encoder.encode(map).write(to: outDirectory.appendingPathComponent(fileName), options: .atomic)
    }
}

// MARK: - Looking at the folders

/// A git repo: where it came from, when it was last used, and whether the person has committed to it.
struct RepoInfo: Hashable, Sendable {
    let path: String
    let remote: String?
    let lastActive: Date?
    /// Nil when there's no git identity to check against.
    let hasOwnCommits: Bool?
    /// The main repo, relative to the root, when this is a git worktree of it.
    var worktreeOf: String? = nil

    /// `acme` from `https://github.com/acme/demo-app.git` or `git@github.com:a/b.git`.
    var remoteOwner: String? {
        guard let remote else { return nil }
        let trimmed = remote.replacingOccurrences(of: "git@github.com:", with: "github.com/")
        let parts = trimmed.split(separator: "/").map(String.init)
        guard let host = parts.firstIndex(where: { $0.contains(".") && !$0.hasSuffix(".git") }), host + 1 < parts.count else { return nil }
        return parts[host + 1]
    }
}

struct FolderInfo: Identifiable, Hashable, Sendable {
    let path: String
    /// Set when the folder is itself a repo.
    let repo: RepoInfo?
    /// Repos directly inside, for a folder that groups them.
    let children: [RepoInfo]
    let lastActive: Date?

    var id: String { path }
    var looksLikeGroup: Bool { repo == nil && !children.isEmpty }
}

struct FolderScanResult: Equatable, Sendable {
    var folders: [FolderInfo] = []
    /// Files lying at the top of the root.
    var looseFiles: [String] = []
}

enum FolderScan {
    /// Never main folders: graphify's own output and installed packages.
    static let skipped: Set<String> = ["graphify-out", "node_modules"]

    static func scan(root: String, identity: [String] = gitIdentity()) -> FolderScanResult {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: root, isDirectory: true)
        guard let entries = try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return FolderScanResult()
        }
        var result = FolderScanResult()
        for entry in entries.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            let name = entry.lastPathComponent
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            guard isDirectory else {
                result.looseFiles.append(name)
                continue
            }
            guard !skipped.contains(name) else { continue }
            if isRepo(entry.path) {
                let info = repoInfo(entry.path, relative: name, identity: identity)
                result.folders.append(FolderInfo(path: name, repo: info, children: [], lastActive: info.lastActive))
            } else {
                let children = ((try? fileManager.contentsOfDirectory(at: entry, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? [])
                    .filter { isRepo($0.path) }
                    .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                    .map { repoInfo($0.path, relative: name + "/" + $0.lastPathComponent, identity: identity) }
                let active = children.compactMap(\.lastActive).max() ?? newestChange(in: entry)
                result.folders.append(FolderInfo(path: name, repo: nil, children: children, lastActive: active))
            }
        }
        return result
    }

    static func isRepo(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent(".git"))
    }

    private static let groupCache = NSCache<NSString, NSArray>()

    /// Folders that hold repos without being one, like `work/` and `personal/`. Used until the
    /// person saves labels. Cached, because every graph source asks.
    static func detectedGroups(root: String) -> Set<String> {
        if let cached = groupCache.object(forKey: root as NSString) as? [String] { return Set(cached) }
        let fileManager = FileManager.default
        var groups: [String] = []
        for name in (try? fileManager.contentsOfDirectory(atPath: root)) ?? [] where !name.hasPrefix(".") && !skipped.contains(name) {
            let path = (root as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue, !isRepo(path) else { continue }
            let children = (try? fileManager.contentsOfDirectory(atPath: path)) ?? []
            if children.contains(where: { !$0.hasPrefix(".") && isRepo((path as NSString).appendingPathComponent($0)) }) {
                groups.append(name)
            }
        }
        groupCache.setObject(groups as NSArray, forKey: root as NSString)
        return Set(groups)
    }

    static func forgetDetectedGroups(root: String) {
        groupCache.removeObject(forKey: root as NSString)
    }

    /// The person's name and email from git, to recognise their own commits.
    static func gitIdentity() -> [String] {
        ["user.name", "user.email"].compactMap { key in
            guard let result = try? ProcessRunner.run("/usr/bin/git", ["config", "--global", key], timeout: 10), result.status == 0 else { return nil }
            let value = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }

    static func repoInfo(_ path: String, relative: String, identity: [String]) -> RepoInfo {
        let dirs = gitDirectories(repo: path)
        let config = (try? String(contentsOfFile: (dirs.common as NSString).appendingPathComponent("config"), encoding: .utf8)) ?? ""
        var worktreeOf: String?
        if dirs.git != dirs.common {
            // A worktree: its main repo is the folder holding the shared `.git`.
            let main = (dirs.common as NSString).deletingLastPathComponent
            let root = String(path.dropLast(relative.count))
            worktreeOf = main.hasPrefix(root) ? String(main.dropFirst(root.count)) : main
        }
        return RepoInfo(path: relative, remote: originURL(inConfig: config), lastActive: lastActive(gitDirectories: dirs), hasOwnCommits: ownCommits(repo: path, identity: identity + effectiveIdentity(repo: path)), worktreeOf: worktreeOf)
    }

    /// A repo's git folder, and the folder it shares with its main repo when it's a worktree. A
    /// worktree's `.git` is a file that says `gitdir: <main>/.git/worktrees/<name>`.
    static func gitDirectories(repo: String) -> (git: String, common: String) {
        let dotGit = (repo as NSString).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dotGit, isDirectory: &isDirectory), !isDirectory.boolValue,
              let text = try? String(contentsOfFile: dotGit, encoding: .utf8),
              let line = text.split(separator: "\n").first(where: { $0.hasPrefix("gitdir:") }) else { return (dotGit, dotGit) }
        var git = line.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
        if !git.hasPrefix("/") { git = ((repo as NSString).appendingPathComponent(git) as NSString).standardizingPath }
        let commonFile = (git as NSString).appendingPathComponent("commondir")
        if let common = try? String(contentsOfFile: commonFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !common.isEmpty {
            let resolved = common.hasPrefix("/") ? common : ((git as NSString).appendingPathComponent(common) as NSString).standardizingPath
            return (git, resolved)
        }
        return (git, git)
    }

    /// The `url` under `[remote "origin"]` in a git config file.
    static func originURL(inConfig config: String) -> String? {
        var inOrigin = false
        for line in config.split(separator: "\n").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            if line.hasPrefix("[") { inOrigin = line == "[remote \"origin\"]"; continue }
            if inOrigin, line.hasPrefix("url"), let equals = line.firstIndex(of: "=") {
                return line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// The name and email git uses inside this repo. People with a work and a personal identity
    /// often switch by folder (`includeIf`), so the global ones alone miss their own commits.
    private static func effectiveIdentity(repo: String) -> [String] {
        guard let result = try? ProcessRunner.run("/usr/bin/git", ["-C", repo, "config", "--get-regexp", "^user\\.(name|email)$"], timeout: 10), result.status == 0 else { return [] }
        return result.output.split(separator: "\n").compactMap { line in
            guard let space = line.firstIndex(of: " ") else { return nil }
            let value = line[line.index(after: space)...].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
    }

    /// When the repo was last used: its newest git activity.
    private static func lastActive(gitDirectories dirs: (git: String, common: String)) -> Date? {
        let fileManager = FileManager.default
        let paths = ["logs/HEAD", "index", "HEAD"].map { (dirs.git as NSString).appendingPathComponent($0) } + [(dirs.common as NSString).appendingPathComponent("FETCH_HEAD")]
        return paths.compactMap { (try? fileManager.attributesOfItem(atPath: $0))?[.modificationDate] as? Date }.max()
    }

    private static func newestChange(in folder: URL) -> Date? {
        let entries = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        return entries.compactMap { (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate }.max()
    }

    /// Whether any commit, on any branch, has the person as its author.
    private static func ownCommits(repo: String, identity: [String]) -> Bool? {
        let names = Array(Set(identity)).filter { !$0.isEmpty }
        guard !names.isEmpty else { return nil }
        let authors = names.flatMap { ["--author", NSRegularExpression.escapedPattern(for: $0)] }
        guard let result = try? ProcessRunner.run("/usr/bin/git", ["-C", repo, "log", "--all", "--max-count=1", "--format=%H"] + authors, timeout: 20),
              result.status == 0 else { return nil }
        return !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Suggestions

    /// A first guess at what a folder is for, from its name and history. The person can change it.
    static func suggestedLabel(for folder: FolderInfo) -> FolderLabel {
        let name = folder.path.lowercased()
        if folder.path == PlaybookFile.graphFolder, folder.repo == nil, folder.children.isEmpty {
            return FolderLabel(path: folder.path, purpose: .notes, name: "Playbook", note: "Graphitree's copy of the owner's playbook, so graph questions find their library picks and stack")
        }
        let purpose: FolderPurpose
        if ["work", "job", "company", "office", "employer"].contains(name) {
            purpose = .work
        } else if ["personal", "projects", "side-projects", "sideprojects", "hobby", "me", "mine"].contains(name) {
            purpose = .personal
        } else if name.contains("client") {
            purpose = .client
        } else if ["notes", "docs", "documents", "papers", "writing", "research"].contains(name) {
            purpose = .notes
        } else if name.contains("archive") || name == "old" {
            purpose = .archive
        } else if folder.repo?.hasOwnCommits == false {
            purpose = .reference
        } else {
            purpose = .other
        }
        return FolderLabel(path: folder.path, purpose: purpose, holdsProjects: folder.looksLikeGroup, isIncluded: !purpose.isLeftOutByDefault)
    }

    /// Saved labels for folders that still exist, and suggestions for new ones. Groups first.
    static func labels(saved: FolderMap?, scan: FolderScanResult) -> [FolderLabel] {
        let kinds = saved?.kinds ?? FolderPurpose.defaults
        let labels = scan.folders.map { folder -> FolderLabel in
            if let label = saved?.label(folder.path) { return label }
            var label = suggestedLabel(for: folder)
            label.purpose = kinds.resolve(label.purpose)
            return label
        }
        return labels.sorted { a, b in
            if a.holdsProjects != b.holdsProjects { return a.holdsProjects }
            return a.path.localizedStandardCompare(b.path) == .orderedAscending
        }
    }
}

// MARK: - What labels change

enum FolderIgnore {
    /// The `.graphifyignore` line that leaves a folder out.
    static func line(for path: String) -> String { SourcePath.ignoreLine(for: path.hasSuffix("/") ? path : path + "/") }

    /// Lines to add for folders left out, and lines to take away for folders included again.
    static func changes(for labels: [FolderLabel]) -> (add: [String], remove: [String]) {
        (labels.filter { !$0.isIncluded }.map { line(for: $0.path) }, labels.filter(\.isIncluded).map { line(for: $0.path) })
    }
}

extension IgnoreFile {
    /// Takes out exact lines. Comments and everything else stay.
    static func removing(_ lines: [String], from text: String) -> String {
        let unwanted = Set(lines.map { $0.trimmingCharacters(in: .whitespaces) })
        guard !unwanted.isEmpty else { return text }
        let kept = text.components(separatedBy: "\n").filter { !unwanted.contains($0.trimmingCharacters(in: .whitespaces)) }
        return kept.joined(separator: "\n")
    }
}

// MARK: - Tidy-up tips

struct TidyTip: Identifiable, Hashable, Sendable {
    enum Action: Hashable, Sendable {
        case label(path: String, purpose: FolderPurpose)
        /// Move these top-level items into one of these folders, after the person picks and confirms.
        case move(paths: [String], destinations: [String])
        /// Leave these repos out of the graph through `.graphifyignore`.
        case leaveOut(paths: [String])
        /// Show these top-level items in Finder, for the person to deal with.
        case reveal(paths: [String])
    }

    /// What a tip is about, so Tidy Up can check each repo or file and say what to keep.
    enum Subject: Hashable, Sendable {
        case plain
        /// Loose files at the top level, each with its copy inside a project, from the root.
        case copies([String: String])
        /// Clones of one repo.
        case clones(paths: [String], remote: String)
        /// Repos the person has never committed to.
        case notYours(paths: [String])
        /// Folders or repos untouched for a year. `topLevel` ones are main folders with a label.
        case stale(paths: [String], topLevel: Bool)
    }

    let id: String
    let symbol: String
    let title: String
    let detail: String
    let action: Action?
    var subject: Subject = .plain

    /// The repos or files it asks about, or nil when it asks about none in particular.
    var subjectPaths: [String]? {
        switch subject {
        case .plain: return nil
        case .copies(let map): return map.keys.sorted()
        case .clones(let paths, _): return paths
        case .notYours(let paths), .stale(let paths, _): return paths
        }
    }

    /// Of those, the ones the person hasn't said to keep (`keep:<path>` in `dismissed`). Clones
    /// are one choice, kept by dismissing the whole tip.
    func openPaths(dismissed: Set<String>) -> [String] {
        let all = subjectPaths ?? []
        if case .clones = subject { return all }
        return all.filter { !dismissed.contains("keep:" + $0) }
    }

    /// Still worth showing: not dismissed, and not every repo in it kept.
    func isOpen(dismissed: Set<String>) -> Bool {
        !dismissed.contains(id) && (subjectPaths == nil || !openPaths(dismissed: dismissed).isEmpty)
    }
}

enum TidyTips {
    static let staleAfter: TimeInterval = 365 * 24 * 3600

    /// `root` lets a tip check the destination for a file that's already there.
    static func tips(scan: FolderScanResult, labels: [FolderLabel], ignored: Set<String>, root: String? = nil, now: Date = .now) -> [TidyTip] {
        var tips: [TidyTip] = []
        let byPath = Dictionary(labels.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        let groups = labels.filter(\.holdsProjects).map(\.path)
        // Somewhere to put things: groups and plain folders, never someone's repo or Graphitree's playbook copy.
        let mainFolders = scan.folders.filter { $0.repo == nil && $0.path != PlaybookFile.graphFolder }.map(\.path)
        let projects = scan.folders.flatMap { $0.children.map(\.path) }
        func isIgnored(_ path: String) -> Bool { ignored.contains(FolderIgnore.line(for: path)) }
        func when(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated).year()) }

        // Loose files, grouped by the project their name points at.
        var byDestination: [String: [String]] = [:]
        for file in scan.looseFiles {
            byDestination[likelyHome(of: file, projects: projects) ?? "", default: []].append(file)
        }
        for (destination, files) in byDestination.sorted(by: { $0.key < $1.key }) {
            let count = files.count == 1 ? files[0] : "\(files.count) loose files"
            if destination.isEmpty {
                tips.append(TidyTip(
                    id: "loose", symbol: "doc.badge.ellipsis",
                    title: "\(count) at the top level",
                    detail: "\(files.joined(separator: ", ")). Files outside any folder show up as projects of their own. Move them into the folder they belong to.",
                    action: .move(paths: files, destinations: mainFolders)
                ))
            } else {
                let copies = files.compactMap { file in root.flatMap { existingCopy(of: file, in: ($0 as NSString).appendingPathComponent(destination)) } }
                if !copies.isEmpty && copies.count == files.count {
                    let places = Set(copies.map { destination + "/" + ($0 as NSString).deletingLastPathComponent })
                    tips.append(TidyTip(
                        id: "copies:\(destination)", symbol: "doc.on.doc",
                        title: files.count == 1 ? "\(files[0]) is a copy of one in \(places.sorted().joined(separator: ", "))" : "\(files.count) loose files are copies of ones in \(places.sorted().joined(separator: ", "))",
                        detail: "\(files.joined(separator: ", ")). The graph reads both copies.",
                        action: .reveal(paths: files),
                        subject: .copies(Dictionary(uniqueKeysWithValues: zip(files, copies.map { destination + "/" + $0 })))
                    ))
                    continue
                }
                let note = copies.isEmpty ? "" : " Some are already in \(destination), so check for duplicates first."
                tips.append(TidyTip(
                    id: "loose:\(destination)", symbol: "doc.badge.arrow.up",
                    title: "\(count) look\(files.count == 1 ? "s" : "") like \(files.count == 1 ? "it belongs" : "they belong") in \(destination)",
                    detail: "\(files.joined(separator: ", ")) sit\(files.count == 1 ? "s" : "") at the top level. Moving \(files.count == 1 ? "it" : "them") puts \(files.count == 1 ? "it" : "them") with the project in the graph.\(note)",
                    action: .move(paths: files, destinations: [destination] + mainFolders)
                ))
            }
        }

        for folder in scan.folders {
            let label = byPath[folder.path]
            // Someone else's repo at the top level.
            if let repo = folder.repo, repo.hasOwnCommits == false, label?.purpose != .reference, label?.isIncluded != false {
                let owner = repo.remoteOwner.map { " Its remote belongs to \($0)." } ?? ""
                tips.append(TidyTip(
                    id: "others:\(folder.path)", symbol: "person.2",
                    title: "\(folder.path) isn't yours",
                    detail: "You've never committed to it.\(owner) Labelling it Reference leaves it out of the graph, so AI tools don't mistake it for your code.",
                    action: .label(path: folder.path, purpose: .reference),
                    subject: .notYours(paths: [folder.path])
                ))
            }
            // Untouched for a year.
            if let active = folder.lastActive, now.timeIntervalSince(active) > staleAfter, label?.purpose != .archive, label?.isIncluded != false {
                tips.append(TidyTip(
                    id: "stale:\(folder.path)", symbol: "clock.arrow.circlepath",
                    title: "\(folder.path) hasn't changed since \(when(active))",
                    detail: "Labelling it Archive leaves it out of the graph. Its files stay where they are.",
                    action: .label(path: folder.path, purpose: .archive),
                    subject: .stale(paths: [folder.path], topLevel: true)
                ))
            }
            // Repos inside a group that aren't the person's, or haven't moved in a year.
            let others = folder.children.filter { $0.hasOwnCommits == false && !isIgnored($0.path) }.map(\.path)
            if !others.isEmpty, label?.isIncluded != false {
                tips.append(TidyTip(
                    id: "others-in:\(folder.path)", symbol: "person.2",
                    title: "\(others.count) repo\(others.count == 1 ? "" : "s") in \(folder.path)/ \(others.count == 1 ? "has" : "have") no commits from you",
                    detail: "\(others.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")). If \(others.count == 1 ? "it's" : "they're") someone else's code, leaving \(others.count == 1 ? "it" : "them") out keeps the graph to your own work.",
                    action: .leaveOut(paths: others),
                    subject: .notYours(paths: others)
                ))
            }
            let stale = folder.children.filter { child in
                guard let active = child.lastActive, child.hasOwnCommits != false else { return false }
                return now.timeIntervalSince(active) > staleAfter && !isIgnored(child.path)
            }.map(\.path)
            if !stale.isEmpty, label?.isIncluded != false {
                tips.append(TidyTip(
                    id: "stale-in:\(folder.path)", symbol: "clock.arrow.circlepath",
                    title: "\(stale.count) project\(stale.count == 1 ? "" : "s") in \(folder.path)/ \(stale.count == 1 ? "hasn't" : "haven't") changed in a year",
                    detail: "\(stale.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")). Leaving \(stale.count == 1 ? "it" : "them") out makes answers about your current work sharper.",
                    action: .leaveOut(paths: stale),
                    subject: .stale(paths: stale, topLevel: false)
                ))
            }
            // A repo outside the groups, when there are groups.
            if folder.repo != nil, !groups.isEmpty, let label, label.isIncluded, label.purpose != .reference {
                tips.append(TidyTip(
                    id: "outside:\(folder.path)", symbol: "folder.badge.questionmark",
                    title: "\(folder.path) sits outside \(groups.map { $0 + "/" }.joined(separator: " and "))",
                    detail: "Moving it into a group puts it with the projects it belongs to. Its label already decides its area, so this is only tidier.",
                    action: .move(paths: [folder.path], destinations: groups)
                ))
            }
        }

        // The same repo cloned twice.
        let repos = scan.folders.flatMap { folder in (folder.repo.map { [$0] } ?? []) + folder.children }
        let byRemote = Dictionary(grouping: repos.filter { $0.remote != nil }) { normalisedRemote($0.remote!) }
        for (remote, clones) in byRemote.sorted(by: { $0.key < $1.key }) where clones.count > 1 {
            tips.append(TidyTip(
                id: "twice:\(remote)", symbol: "doc.on.doc",
                title: "\(clones.map(\.path).joined(separator: " and ")) are the same repo",
                detail: "Both are clones of \(remote). The graph reads both, so AI tools see every file twice.",
                action: .leaveOut(paths: Array(clones.dropFirst().map(\.path))),
                subject: .clones(paths: clones.map(\.path), remote: remote)
            ))
        }
        return tips
    }

    /// Where a file with the same name already sits inside a folder, a few levels down at most.
    static func existingCopy(of file: String, in folder: String, depth: Int = 3) -> String? {
        let fileManager = FileManager.default
        func search(_ directory: String, _ relative: String, _ level: Int) -> String? {
            guard level <= depth, let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { return nil }
            if entries.contains(file) { return relative.isEmpty ? file : relative + "/" + file }
            for entry in entries.sorted() where !entry.hasPrefix(".") && entry != "node_modules" {
                var isDirectory: ObjCBool = false
                let path = (directory as NSString).appendingPathComponent(entry)
                guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
                if let found = search(path, relative.isEmpty ? entry : relative + "/" + entry, level + 1) { return found }
            }
            return nil
        }
        return search(folder, "", 1)
    }

    /// `github.com/owner/name` from any form of a git URL.
    static func normalisedRemote(_ remote: String) -> String {
        var text = remote.lowercased()
        for prefix in ["https://", "http://", "ssh://", "git@"] where text.hasPrefix(prefix) { text.removeFirst(prefix.count) }
        text = text.replacingOccurrences(of: "github.com:", with: "github.com/")
        if text.hasSuffix(".git") { text.removeLast(4) }
        if let at = text.firstIndex(of: "@") { text = String(text[text.index(after: at)...]) }
        return text
    }

    /// The project a loose file's name points at, such as `personal/shop-oms` for `oms-erd-draft.pdf`.
    static func likelyHome(of file: String, projects: [String]) -> String? {
        let stem = (file as NSString).deletingPathExtension.lowercased()
        let words = stem.split(whereSeparator: { "-_ .".contains($0) }).map(String.init).filter { $0.count >= 3 }
        guard let first = words.first else { return nil }
        let matches = projects.filter { project in
            let name = (project as NSString).lastPathComponent.lowercased()
            return name.split(whereSeparator: { "-_ .".contains($0) }).map(String.init).contains(first)
        }
        return matches.count == 1 ? matches[0] : nil
    }
}

// MARK: - A graph per folder

/// Slices of the root's graph, one per main folder, so an AI tool working in one folder can ask
/// just that part. They're cut from `graph.json` after each build and cost nothing extra.
enum FolderSlices {
    static let folderName = "folders"

    static func fileName(for path: String) -> String {
        path.replacingOccurrences(of: "/", with: "-") + ".json"
    }

    static func url(for path: String, outDirectory: URL) -> URL {
        outDirectory.appendingPathComponent(folderName, isDirectory: true).appendingPathComponent(fileName(for: path))
    }

    /// Writes a slice for each folder, removes slices for folders no longer listed, and returns node counts.
    @discardableResult
    static func write(graph: URL, outDirectory: URL, folders: [String]) throws -> [String: Int] {
        try write(try GraphPartition.read(graph), outDirectory: outDirectory, folders: folders)
    }

    /// The same, from graph.json already read, so graph cuts can share the read.
    @discardableResult
    static func write(_ root: [String: Any], outDirectory: URL, folders: [String]) throws -> [String: Int] {
        guard let nodes = root["nodes"] as? [[String: Any]] else { throw CocoaError(.propertyListReadCorrupt) }
        let edgeKey = root["links"] != nil ? "links" : "edges"
        let edges = root[edgeKey] as? [[String: Any]] ?? []
        let directory = outDirectory.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var counts: [String: Int] = [:]
        for folder in folders {
            let prefix = folder + "/"
            let kept = nodes.filter { ($0["source_file"] as? String ?? "").hasPrefix(prefix) }
            let ids = Set(kept.compactMap { $0["id"] as? String })
            var slice = root
            slice["nodes"] = kept
            slice[edgeKey] = edges.filter { edge in
                guard let source = edge["source"] as? String, let target = edge["target"] as? String else { return false }
                return ids.contains(source) && ids.contains(target)
            }
            // graphify keeps hyperedges twice, at the top and inside `graph`. Both are trimmed, or the
            // slice would carry every other folder's hyperedges.
            if let hyperedges = root["hyperedges"] as? [[String: Any]] {
                slice["hyperedges"] = GraphPartition.trim(hyperedges, to: ids)
            }
            if var attributes = root["graph"] as? [String: Any], let hyperedges = attributes["hyperedges"] as? [[String: Any]] {
                attributes["hyperedges"] = GraphPartition.trim(hyperedges, to: ids)
                slice["graph"] = attributes
            }
            let output = try JSONSerialization.data(withJSONObject: slice, options: [.withoutEscapingSlashes, .sortedKeys])
            let target = url(for: folder, outDirectory: outDirectory)
            let temporary = target.path + ".\(UUID().uuidString).tmp"
            try output.write(to: URL(fileURLWithPath: temporary))
            guard rename(temporary, target.path) == 0 else {
                try? FileManager.default.removeItem(atPath: temporary)
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
            counts[folder] = kept.count
        }
        let wanted = Set(folders.map(fileName(for:)))
        for name in (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [] where name.hasSuffix(".json") && !wanted.contains(name) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
        try ignoreInGit(outDirectory: outDirectory)
        return counts
    }

    /// Slices and cuts are derived and large, so they stay out of a git repo kept in graphify-out.
    private static func ignoreInGit(outDirectory: URL) throws {
        guard FileManager.default.fileExists(atPath: outDirectory.appendingPathComponent(".git").path) else { return }
        let url = outDirectory.appendingPathComponent(".gitignore")
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let missing = ["\(folderName)/", "\(GraphCuts.folderName)/"].filter { !existing.split(separator: "\n").contains(Substring($0)) }
        guard !missing.isEmpty else { return }
        let separator = existing.isEmpty || existing.hasSuffix("\n") ? "" : "\n"
        try (existing + separator + missing.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}

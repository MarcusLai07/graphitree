import Foundation

/// Starters: a repo with no setup of its own gets one, once, from the playbook. The instructions
/// file most AI tools read (`AGENTS.md`), a `CLAUDE.md` that imports it, and the playbook's skills.
/// After that the repo owns them: Graphitree never changes, syncs or removes those files. It only
/// keeps a copy of what it wrote, so it can tell later what the repo added.
enum Seeds {
    static let recordName = "seeds.json"
    /// Under graphify-out, which graphify skips: `seeds/<project>/<file>`.
    static let copiesFolder = "seeds"
    static let agentsFile = "AGENTS.md"
    static let claudeFile = "CLAUDE.md"
    static let geminiFile = "GEMINI.md"
    static let skillsFolder = ".agents/skills"
    static let claudeSkillsFolder = ".claude/skills"
    /// The coding tools that get files of their own. Every other tool reads `AGENTS.md`.
    static let claudeCode = "claude-code"
    static let geminiCLI = "gemini"

    // MARK: The record

    /// What Graphitree wrote into one repo, and when.
    struct Record: Codable, Equatable, Sendable {
        var seededAt: Date
        /// The main folder it was in, such as `personal`.
        var folder: String
        /// The coding tools it was written for, by id.
        var tools: [String] = []
        /// Files written, relative to the repo.
        var files: [String] = []
        /// Links made for Claude Code, relative to the repo.
        var links: [String] = []
    }

    struct Book: Codable, Equatable, Sendable {
        var version = 1
        /// By project path, relative to the root, such as `personal/kiln`.
        var repos: [String: Record] = [:]
        /// Projects the person said no to.
        var skipped: [String] = []

        init() {}

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            version = (try? values.decodeIfPresent(Int.self, forKey: .version)) ?? 1
            repos = (try? values.decodeIfPresent([String: Record].self, forKey: .repos)) ?? [:]
            skipped = (try? values.decodeIfPresent([String].self, forKey: .skipped)) ?? []
        }
    }

    static func load(from outDirectory: URL) -> Book {
        let url = outDirectory.appendingPathComponent(recordName)
        guard let data = try? Data(contentsOf: url) else { return Book() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Book.self, from: data)) ?? Book()
    }

    static func save(_ book: Book, to outDirectory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)
        try encoder.encode(book).write(to: outDirectory.appendingPathComponent(recordName), options: .atomic)
    }

    /// The record for a project, following the projects Graphitree moved since it was seeded.
    static func record(for project: String, in book: Book, moves: [FolderMove]) -> (key: String, record: Record)? {
        if let record = book.repos[project] { return (project, record) }
        for (key, record) in book.repos where following(key, through: moves) == project { return (key, record) }
        return nil
    }

    /// Where a project went through Graphitree's moves, oldest first. Nil when it never moved.
    static func following(_ project: String, through moves: [FolderMove]) -> String? {
        var current = project
        var moved = false
        for move in moves.sorted(by: { $0.at < $1.at }) where current == move.from || current.hasPrefix(move.from + "/") {
            current = move.to + current.dropFirst(move.from.count)
            moved = true
        }
        return moved ? current : nil
    }

    // MARK: Which repos

    enum State: Equatable, Sendable {
        case seeded(Record)
        /// Has instructions, skills or workflows Graphitree didn't write: these paths.
        case ownSetup([String])
        case notSetUp
        case skipped
    }

    struct Repo: Identifiable, Equatable, Sendable {
        /// Relative to the root, such as `personal/kiln`.
        let path: String
        /// The main folder, such as `personal`.
        let folder: String
        let purpose: FolderPurpose?
        let state: State
        /// Made in the last two weeks, so most likely one the person just started.
        let isNew: Bool
        var id: String { path }
    }

    struct Survey: Equatable, Sendable {
        /// Repos in folders that can get a starter, in path order.
        var repos: [Repo] = []
        /// Repos in shared folders (Work, Client), in path order. Kept apart from the others: a
        /// starter there would be committed where colleagues see it, so they're never counted
        /// as offers or marked new, and the person previews one only if they mean to.
        var shared: [Repo] = []
        /// Repos whose main folder has no label yet, so it can't be told whether they're shared.
        var unlabelled: [String] = []

        var offers: [Repo] { repos.filter { $0.state == .notSetUp } }
        var sharedOffers: [Repo] { shared.filter { $0.state == .notSetUp } }
    }

    /// Files and folders that mean a repo already has a setup of its own: instructions files any
    /// tool reads, skill folders, and saved prompts or agents.
    static let setupMarkers = [
        "AGENTS.md", "AGENTS.override.md", "AGENT.md", "CLAUDE.md", "CLAUDE.local.md", ".claude/CLAUDE.md", "GEMINI.md",
        ".github/copilot-instructions.md", ".github/instructions", ".github/prompts", ".github/skills",
        ".cursorrules", ".cursor/rules", ".cursor/skills", ".rules", ".windsurfrules", ".windsurf/rules",
        ".clinerules", ".junie", ".claude/skills", ".claude/commands", ".claude/agents", ".agents/skills", ".codex/skills",
    ]

    /// The markers a repo has, in the order above.
    static func ownSetup(in repoPath: String) -> [String] {
        setupMarkers.filter { marker in
            let path = (repoPath as NSString).appendingPathComponent(marker)
            return exists(path) && !isEmptyFolder(path)
        }
    }

    /// Whether a label's repos can get a starter at all: not notes, not someone else's code or the
    /// archive. Shared folders' repos can, but are listed apart (see `Survey.shared`).
    static func canSeed(_ purpose: FolderPurpose) -> Bool {
        !purpose.isDocs && purpose.id != FolderPurpose.reference.id && purpose.id != FolderPurpose.archive.id
    }

    /// Every git repo among the graph's projects, with its state. Only a root that holds several
    /// projects has any: a single repo's own graph is that repo, and it has no folder labels.
    static let newFor: TimeInterval = 14 * 24 * 3600

    static func survey(root: String, map: FolderMap?, book: Book, moves: [FolderMove], now: Date = .now) -> Survey {
        var survey = Survey()
        guard let map else { return survey }
        let projectAreas = map.areasByProject
        for project in MemoryCopy.projects(root: root, map: map) {
            let full = (root as NSString).appendingPathComponent(project)
            guard FolderScan.isRepo(full) else { continue }
            let folder = String(project.split(separator: "/").first ?? "")
            guard let purpose = projectAreas[project]?.purpose ?? map.label(folder)?.purpose else {
                survey.unlabelled.append(project)
                continue
            }
            guard canSeed(purpose) else { continue }
            let state: State
            if let found = record(for: project, in: book, moves: moves) {
                state = .seeded(found.record)
            } else if book.skipped.contains(project) {
                state = .skipped
            } else {
                let own = ownSetup(in: full)
                state = own.isEmpty ? .notSetUp : .ownSetup(own)
            }
            let made = (try? FileManager.default.attributesOfItem(atPath: (full as NSString).appendingPathComponent(".git")))?[.creationDate] as? Date
            let isNew = !purpose.isShared && state == .notSetUp && made.map { now.timeIntervalSince($0) < newFor } == true
            let repo = Repo(path: project, folder: folder, purpose: purpose, state: state, isNew: isNew)
            if purpose.isShared { survey.shared.append(repo) } else { survey.repos.append(repo) }
        }
        return survey
    }

    // MARK: What a starter holds

    struct Item: Identifiable, Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case file(String)
            /// A relative link, for Claude Code's skills.
            case link(String)
        }

        /// Relative to the repo.
        let path: String
        let kind: Kind
        /// Something is already at this path, so it's left alone.
        var isTaken = false
        var id: String { path }
    }

    /// What a repo gets. `tools` are the coding tools with files of their own (Claude Code,
    /// Gemini CLI). Nothing that's already there is in the list as something to write.
    static func starter(for project: String, root: String, purpose: FolderPurpose?, playbook: Playbook, tools: [String], date: Date = .now) -> [Item] {
        let folder = String(project.split(separator: "/").first ?? "")
        var items: [Item] = [Item(path: agentsFile, kind: .file(agentsText(playbook: playbook, folder: folder, date: date)))]
        if tools.contains(claudeCode) { items.append(Item(path: claudeFile, kind: .file(importText))) }
        if tools.contains(geminiCLI) { items.append(Item(path: geminiFile, kind: .file(importText))) }
        for skill in playbook.skills where skill.isReady && skill.reaches(project, purpose: purpose) {
            if skill.claudeOnly {
                guard tools.contains(claudeCode) else { continue }
                items += skillItems(skill, in: claudeSkillsFolder)
            } else {
                items += skillItems(skill, in: skillsFolder)
                if tools.contains(claudeCode) {
                    items.append(Item(path: "\(claudeSkillsFolder)/\(skill.name)", kind: .link("../../\(skillsFolder)/\(skill.name)")))
                }
            }
        }
        // A skill whose folder is already there is left alone whole, and so is Claude Code's
        // link to it: Graphitree never adds files to a folder it didn't make.
        let repo = (root as NSString).appendingPathComponent(project)
        let full = { (repo as NSString).appendingPathComponent($0) }
        let takenSkills = Set(items.compactMap { item -> String? in
            guard case .file = item.kind, isSkillPath(item.path), exists(full(skillFolder(of: item.path))) else { return nil }
            return (item.path as NSString).pathComponents[2]
        })
        return items.map { item in
            var item = item
            let skill = isSkillPath(item.path) ? (item.path as NSString).pathComponents[2] : nil
            item.isTaken = exists(full(item.path)) || skill.map(takenSkills.contains) == true
            return item
        }
    }

    private static func isSkillPath(_ path: String) -> Bool {
        (path.hasPrefix(skillsFolder + "/") || path.hasPrefix(claudeSkillsFolder + "/")) && (path as NSString).pathComponents.count >= 3
    }

    /// `.agents/skills/release-notes` for any path inside that skill.
    static func skillFolder(of path: String) -> String {
        let parts = path.split(separator: "/")
        return parts.prefix(3).joined(separator: "/")
    }

    private static func skillItems(_ skill: PlaybookSkill, in folder: String) -> [Item] {
        let base = "\(folder)/\(skill.name)"
        return [Item(path: "\(base)/\(PlaybookSkill.fileName)", kind: .file(skill.skillText))]
            + skill.files.filter { PlaybookSkill.isValidFilePath($0.path) }.map { Item(path: "\(base)/\($0.path)", kind: .file($0.text.hasSuffix("\n") ? $0.text : $0.text + "\n")) }
    }

    /// `CLAUDE.md` and `GEMINI.md`: both read `AGENTS.md` through an import, so there's one text to change.
    static let importText = "@AGENTS.md\n"

    /// The instructions file: the playbook's rules and stack as they apply in the repo's main
    /// folder, how to ask the knowledge base before researching, and a heading for the repo's own notes.
    static func agentsText(playbook: Playbook, folder: String, date: Date = .now) -> String {
        let book = playbook.effective(for: folder)
        var lines: [String] = []
        lines.append("# AGENTS.md")
        lines.append("")
        lines.append("Instructions for AI coding tools in this repo. Started on \(PlaybookFile.day(date)) from the owner's Graphitree Playbook. The repo owns this file now: change it as the project needs.")
        lines.append("")
        lines.append("## Before you research")
        lines.append("")
        lines.append("Another of the owner's repos may have solved this already. Before searching the web or exploring widely, ask the owner's knowledge base, then read only the files it names:")
        lines.append("")
        lines.append("- `graphitree ask \"<the problem>\" --all` in a terminal, or the `ask_graph` tool from the `graphitree` MCP server.")
        lines.append("- `graphitree guide` explains the rest.")
        lines.append("")
        lines.append("Skip this where the `graphitree` command isn't installed, such as in a cloud session.")
        lines.append("")
        lines.append("## Libraries")
        lines.append("")
        lines.append("Before adding a dependency or writing a component or helper yourself, look up the owner's pick for the job: `graphitree pick \"<job>\"`, or the `find_pick` tool. Prefer what this repo already uses, and ask before replacing it.")

        var rules = book.rules(for: "").map { "- \(PlaybookFile.oneLine($0.text))" }
        for category in PlaybookCategories.sorted(book.rules.map { PlaybookCategories.canonical($0.category) }).filter({ !$0.isEmpty }) {
            rules += book.rules(for: category).map { "- \(category): \(PlaybookFile.oneLine($0.text))" }
        }
        if !rules.isEmpty {
            lines.append("")
            lines.append("## Rules")
            lines.append("")
            lines.append(contentsOf: rules)
        }

        let answered = PlaybookQuestions.stack.compactMap { question -> String? in
            guard let answer = book.stack[question.id], !answer.choices.isEmpty else { return nil }
            let notes = PlaybookFile.oneLine(answer.notes)
            return "- **\(question.title):** \(answer.choices.joined(separator: ", "))" + (notes.isEmpty ? "" : ". \(notes)")
        }
        if !answered.isEmpty {
            lines.append("")
            lines.append("## Stack for new work")
            lines.append("")
            lines.append("Defaults for new code. What this repo already uses stays.")
            lines.append("")
            lines.append(contentsOf: answered)
        }

        lines.append("")
        lines.append("## This repo")
        lines.append("")
        lines.append("<!-- How to run and test it, where things live, and what's different here. -->")
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: Writing

    struct WriteResult: Equatable, Sendable {
        var written: [String] = []
        var linked: [String] = []
        /// Already there, so left alone.
        var left: [String] = []
    }

    /// Writes what isn't there yet, records it, and keeps a copy of each file for later. Never
    /// overwrites, never removes, never commits.
    static func write(_ items: [Item], project: String, folder: String, tools: [String], root: String, outDirectory: URL, now: Date = .now) throws -> WriteResult {
        let manager = FileManager.default
        let repo = (root as NSString).appendingPathComponent(project)
        guard FolderScan.isRepo(repo) else { throw SeedError(message: "\(project) isn't a git repo any more.") }
        var result = WriteResult()
        let copies = copiesURL(for: project, outDirectory: outDirectory)
        // What was written before a failure is still recorded, so it's never mistaken for the repo's own.
        defer {
            var book = load(from: outDirectory)
            if !result.written.isEmpty || !result.linked.isEmpty {
                book.repos[project] = Record(seededAt: now, folder: folder, tools: tools, files: result.written, links: result.linked)
            }
            book.skipped.removeAll { $0 == project }
            try? save(book, to: outDirectory)
        }
        for item in items {
            let path = (repo as NSString).appendingPathComponent(item.path)
            if item.isTaken || exists(path) {
                result.left.append(item.path)
                continue
            }
            try manager.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            switch item.kind {
            case .file(let text):
                // withoutOverwriting: if something appeared since the check, it stays.
                try Data(text.utf8).write(to: URL(fileURLWithPath: path), options: .withoutOverwriting)
                let copy = copies.appendingPathComponent(item.path)
                try manager.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(text.utf8).write(to: copy, options: .atomic)
                result.written.append(item.path)
            case .link(let target):
                try manager.createSymbolicLink(atPath: path, withDestinationPath: target)
                result.linked.append(item.path)
            }
        }
        return result
    }

    /// Says no to a project's starter, or takes the no back.
    static func setSkipped(_ project: String, _ skipped: Bool, in outDirectory: URL) throws {
        var book = load(from: outDirectory)
        book.skipped.removeAll { $0 == project }
        if skipped { book.skipped.append(project) }
        book.skipped.sort()
        try save(book, to: outDirectory)
    }

    static func copiesURL(for project: String, outDirectory: URL) -> URL {
        outDirectory.appendingPathComponent(copiesFolder, isDirectory: true).appendingPathComponent(project, isDirectory: true)
    }

    // MARK: Helpers

    /// True for a file, a folder, or a link, even one whose target is gone.
    static func exists(_ path: String) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: path)) != nil
    }

    private static func isEmptyFolder(_ path: String) -> Bool {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder), isFolder.boolValue else { return false }
        return ((try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []).allSatisfy { $0 == ".DS_Store" }
    }
}

struct SeedError: Error, LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - What each repo did with its starter

extension Seeds {
    /// One seeded file or link, compared with what Graphitree wrote.
    struct FileStatus: Identifiable, Equatable, Sendable {
        enum State: Equatable, Sendable {
            case unchanged
            case changed
            /// Deleted, or for a link, removed or replaced.
            case gone
        }

        /// Relative to the repo.
        let path: String
        let state: State
        let isLink: Bool
        /// Lines the repo added or reworded, in order. Blank lines aren't counted.
        var added: [String] = []
        /// How many of the starter's lines aren't there any more.
        var removed = 0
        /// 1-based line ranges still exactly as written, in the file as it is now.
        var unchangedLines: [ClosedRange<Int>] = []
        var id: String { path }
    }

    /// Every file and link in a repo's record, compared with the copies kept at seeding. `key` is
    /// where the record is filed, which differs from `project` after a move.
    static func status(of project: String, key: String, record: Record, root: String, outDirectory: URL) -> [FileStatus] {
        let repo = (root as NSString).appendingPathComponent(project)
        let copies = copiesURL(for: key, outDirectory: outDirectory)
        var result: [FileStatus] = []
        for file in record.files {
            let path = (repo as NSString).appendingPathComponent(file)
            guard let now = try? String(contentsOfFile: path, encoding: .utf8) else {
                result.append(FileStatus(path: file, state: .gone, isLink: false))
                continue
            }
            let then = (try? String(contentsOf: copies.appendingPathComponent(file), encoding: .utf8)) ?? ""
            result.append(compare(file, now: now, then: then))
        }
        for link in record.links {
            let path = (repo as NSString).appendingPathComponent(link)
            let target = try? FileManager.default.destinationOfSymbolicLink(atPath: path)
            let expected = "../../\(skillsFolder)/\((link as NSString).lastPathComponent)"
            result.append(FileStatus(path: link, state: target == expected ? .unchanged : .gone, isLink: true))
        }
        return result
    }

    static func compare(_ file: String, now: String, then: String) -> FileStatus {
        if now == then {
            let count = now.components(separatedBy: "\n").count - (now.hasSuffix("\n") ? 1 : 0)
            return FileStatus(path: file, state: .unchanged, isLink: false, unchangedLines: count > 0 ? [1...count] : [])
        }
        var pool: [String: Int] = [:]
        for line in then.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            pool[line, default: 0] += 1
        }
        var added: [String] = []
        for line in now.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            if let left = pool[line], left > 0 { pool[line] = left - 1 } else { added.append(line) }
        }
        let kept = Set(sections(of: then).map(\.text))
        let unchanged = sections(of: now).filter { kept.contains($0.text) }.map { $0.start...$0.end }
        return FileStatus(path: file, state: .changed, isLink: false, added: added, removed: pool.values.reduce(0, +), unchangedLines: unchanged)
    }

    /// A markdown file in parts, the way graphify gives it nodes: what comes before the first
    /// heading, then each heading with the text under it up to the next heading of any level.
    /// Headings inside fenced code don't count. Lines are 1-based.
    struct Section: Equatable, Sendable {
        let start: Int
        let end: Int
        /// The part's lines with trailing spaces and blank lines at the end taken off, so moving it whole still matches.
        let text: String
    }

    static func sections(of text: String) -> [Section] {
        var lines = text.components(separatedBy: "\n")
        if text.hasSuffix("\n") { lines.removeLast() }
        guard !lines.isEmpty else { return [] }
        var starts = [0]
        var fence: String?
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                if trimmed.hasPrefix(open) { fence = nil }
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                fence = String(trimmed.prefix(3))
                continue
            }
            if index > 0, isHeading(line) { starts.append(index) }
        }
        return starts.enumerated().compactMap { offset, start in
            let end = offset + 1 < starts.count ? starts[offset + 1] - 1 : lines.count - 1
            var body = lines[start...end].map { String($0.reversed().drop { $0 == " " || $0 == "\t" }.reversed()) }
            while body.last?.isEmpty == true { body.removeLast() }
            guard !body.isEmpty else { return nil }
            return Section(start: start + 1, end: end + 1, text: body.joined(separator: "\n"))
        }
    }

    /// An ATX heading: up to three spaces, one to six `#`, then a space or the end of the line.
    static func isHeading(_ line: String) -> Bool {
        let indent = line.prefix { $0 == " " }.count
        guard indent <= 3 else { return false }
        let rest = line.dropFirst(indent)
        let hashes = rest.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes) else { return false }
        let after = rest.dropFirst(hashes)
        return after.isEmpty || after.first == " " || after.first == "\t"
    }

    // MARK: Hiding it in the graph

    /// Starter text that a seeded repo hasn't changed, by its path in the graph (relative to the
    /// root). The playbook already says it, so ten repos with the same starter would only repeat it.
    struct Unchanged: Equatable, Sendable {
        /// The whole file is as Graphitree wrote it.
        var whole: Bool
        /// Otherwise, the line ranges still as written.
        var lines: [ClosedRange<Int>]

        /// Whether a node starting at this line is starter text. The file's own node, and
        /// anything at line 1, stay while the file has anything of the repo's own.
        func covers(line: Int?) -> Bool {
            if whole { return true }
            guard let line, line > 1 else { return false }
            return lines.contains { $0.contains(line) }
        }
    }

    static func unchangedText(root: String, outDirectory: URL) -> [String: Unchanged] {
        let book = load(from: outDirectory)
        guard !book.repos.isEmpty else { return [:] }
        let moves = FolderMoves.load(from: outDirectory)
        var result: [String: Unchanged] = [:]
        for (key, record) in book.repos {
            let project = following(key, through: moves) ?? key
            let statuses = status(of: project, key: key, record: record, root: root, outDirectory: outDirectory)
            // graphify files a linked skill's nodes under the link's path, so both paths count.
            let linked = Set(statuses.filter { $0.isLink && $0.state == .unchanged }.map { ($0.path as NSString).lastPathComponent })
            for file in statuses where !file.isLink && file.state != .gone {
                let unchanged = Unchanged(whole: file.state == .unchanged, lines: file.unchangedLines)
                guard unchanged.whole || !unchanged.lines.isEmpty else { continue }
                result[project + "/" + file.path] = unchanged
                if file.path.hasPrefix(skillsFolder + "/") {
                    let name = (file.path as NSString).pathComponents[2]
                    if linked.contains(name) {
                        result[project + "/" + claudeSkillsFolder + file.path.dropFirst(skillsFolder.count)] = unchanged
                    }
                }
            }
        }
        return result
    }

    /// The nodes to hide, from each node's file and the line it starts at (`L12`).
    static func hiddenNodes(_ nodes: [(id: String, path: String, location: String?)], unchanged: [String: Unchanged], root: String) -> Set<String> {
        guard !unchanged.isEmpty else { return [] }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        var hidden = Set<String>()
        for node in nodes {
            let path = node.path.hasPrefix(prefix) ? String(node.path.dropFirst(prefix.count)) : node.path
            guard let text = unchanged[path] else { continue }
            if text.covers(line: line(of: node.location)) { hidden.insert(node.id) }
        }
        return hidden
    }

    /// `L12` or `L12-L20` as 12.
    static func line(of location: String?) -> Int? {
        guard let location, location.hasPrefix("L") else { return nil }
        return Int(location.dropFirst().prefix { $0.isNumber })
    }
}

// MARK: - Skills the repos already have

extension Seeds {
    /// A skill a repo wrote for itself, which the playbook could adopt.
    struct FoundSkill: Identifiable, Equatable, Sendable {
        let project: String
        let name: String
        let description: String
        let body: String
        /// From a shared folder (Work, Client): only offered in a review of the whole graph, and
        /// only its name comes over, so no text from that repo reaches a starter.
        let isShared: Bool
        var id: String { project + "/" + name }
    }

    static let foundSkillFolders = [skillsFolder, claudeSkillsFolder, ".github/skills", ".cursor/skills"]

    /// Skills in the graph's repos that Graphitree didn't put there, by project then name. A skill
    /// linked into two folders counts once.
    static func foundSkills(root: String, map: FolderMap?, book: Book, moves: [FolderMove]) -> [FoundSkill] {
        guard let map else { return [] }
        let areas = map.areasByProject
        var found: [FoundSkill] = []
        for project in MemoryCopy.projects(root: root, map: map) {
            let folder = String(project.split(separator: "/").first ?? "")
            guard let purpose = areas[project]?.purpose ?? map.label(folder)?.purpose,
                  !purpose.isDocs, purpose.id != FolderPurpose.reference.id, purpose.id != FolderPurpose.archive.id else { continue }
            let seeded = record(for: project, in: book, moves: moves)?.record
            let ours = Set((seeded?.files ?? []).map(skillFolder(of:)) + (seeded?.links ?? []))
            let repo = (root as NSString).appendingPathComponent(project)
            var names = Set<String>()
            for base in foundSkillFolders {
                let folderPath = (repo as NSString).appendingPathComponent(base)
                for name in ((try? FileManager.default.contentsOfDirectory(atPath: folderPath)) ?? []).sorted() where !name.hasPrefix(".") {
                    guard !ours.contains(base + "/" + name), !names.contains(name),
                          let text = try? String(contentsOfFile: (folderPath as NSString).appendingPathComponent("\(name)/\(PlaybookSkill.fileName)"), encoding: .utf8) else { continue }
                    names.insert(name)
                    let parsed = parseSkill(text)
                    found.append(FoundSkill(project: project, name: parsed.name.isEmpty ? name : parsed.name, description: parsed.description, body: parsed.body, isShared: purpose.isShared))
                }
            }
        }
        return found
    }

    /// A SKILL.md's name, description and the text after its frontmatter.
    static func parseSkill(_ text: String) -> (name: String, description: String, body: String) {
        var lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let close = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return ("", "", text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        var fields: [String: String] = [:]
        for line in lines[1..<close] {
            guard let colon = line.firstIndex(of: ":"), !line.hasPrefix(" ") else { continue }
            var value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, let first = value.first, first == "\"" || first == "'", value.last == first {
                value = String(value.dropFirst().dropLast())
                if first == "\"" { value = value.replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\") }
            }
            fields[String(line[..<colon]).trimmingCharacters(in: .whitespaces)] = value
        }
        lines = Array(lines[(close + 1)...])
        return (fields["name"] ?? "", fields["description"] ?? "", lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// A found skill as a playbook draft. One from a shared folder brings only its name: the
    /// owner, or the chat, writes a generic version before it can go anywhere.
    static func adopt(_ found: FoundSkill) -> PlaybookSkill {
        var skill = PlaybookSkill(name: PlaybookSkill.isValidName(found.name) ? found.name : PlaybookSkill.suggestedName(found.name))
        skill.drafted = true
        skill.source = found.isShared ? "a shared folder" : found.project
        if !found.isShared {
            skill.description = found.description
            skill.body = found.body
        }
        return skill
    }
}

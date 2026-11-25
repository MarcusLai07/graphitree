import Darwin
import Foundation

// Moving and renaming folders on disk. Graphitree checks first (what stops the move, and what else
// it touches), moves the folder, then fixes what pointed at the old path: the arrangement,
// `.graphifyignore`, worktree links, a repo's own graph root and, when asked, its remote. Each move
// is logged with what it fixed, so undo puts all of it back.

// MARK: - The log

/// One move, so it can be undone.
struct FolderMove: Codable, Hashable, Sendable {
    /// Both relative to the root.
    let from: String
    let to: String
    let at: Date
    /// What else the move changed. Moves logged before Phase 3 have none.
    var fixups: MoveFixups? = nil
}

/// What a move changed besides the folder, for the result and for undo.
struct MoveFixups: Codable, Hashable, Sendable {
    /// The label taken away when a main folder moved into a group. Undo puts it back.
    var removedLabel: FolderLabel?
    /// An area made in Arrange to keep the project where it was, when its label went away.
    var madeArea: String?
    /// The remote before and after Graphitree pointed it at another account.
    var remoteBefore: String?
    var remoteAfter: String?
    /// Linked worktrees whose links were repaired, absolute.
    var worktrees: [String] = []
    var rootFile = false
    var ignoreLines = 0
    var arrangement = false
    var folderStack = false
    /// What couldn't be fixed, in words.
    var problems: [String] = []

    /// One line per thing fixed, for the result.
    var summary: [String] {
        var lines: [String] = []
        if arrangement { lines.append("the arrangement") }
        if ignoreLines > 0 { lines.append(ignoreLines == 1 ? "a .graphifyignore line" : "\(ignoreLines) .graphifyignore lines") }
        if !worktrees.isEmpty { lines.append(worktrees.count == 1 ? "a worktree link" : "\(worktrees.count) worktree links") }
        if rootFile { lines.append("its graph's root file") }
        if folderStack { lines.append("its stack in the playbook") }
        if remoteAfter != nil { lines.append("its remote") }
        return lines
    }
}

/// A move or a rename: the folder, the folder it goes into, and its name there.
struct MoveRequest: Hashable, Sendable {
    /// Relative to the root, such as `personal/odyssey`.
    var item: String
    /// Relative to the root; empty for the root itself.
    var newParent: String
    var newName: String

    init(item: String, newParent: String, newName: String? = nil) {
        self.item = item
        self.newParent = newParent
        self.newName = newName ?? (item as NSString).lastPathComponent
    }

    static func rename(_ item: String, to name: String) -> MoveRequest {
        MoveRequest(item: item, newParent: parent(of: item), newName: name)
    }

    static func parent(of path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return "" }
        return String(path[..<slash])
    }

    var name: String { (item as NSString).lastPathComponent }
    var oldParent: String { Self.parent(of: item) }
    var target: String { newParent.isEmpty ? newName : newParent + "/" + newName }
    var isRename: Bool { newParent == oldParent }
    var changesNothing: Bool { target == item }
}

/// What Graphitree found before a move: what stops it, what it also updates, what changes for git,
/// and what's up to the person.
struct MoveCheck: Sendable {
    /// Pointing the remote at the account the new folder's git rule goes with.
    struct RemoteChoice: Hashable, Sendable {
        let current: String
        let suggested: String
        let currentOwner: String
        let newLogin: String
    }

    let request: MoveRequest
    var blockers: [String] = []
    /// What Graphitree also updates.
    var updates: [String] = []
    /// What changes for commits and pushes.
    var rules: [String] = []
    var remoteChoice: RemoteChoice?
    /// What the person has to do.
    var yours: [String] = []
    /// The docs graphify reads again, because its cache is keyed by path.
    var docs = DocsEstimate()

    var canMove: Bool { blockers.isEmpty && !request.changesNothing }
}

enum FolderMoves {
    static let fileName = "folder-moves.json"

    static func load(from outDirectory: URL) -> [FolderMove] {
        guard let data = try? Data(contentsOf: outDirectory.appendingPathComponent(fileName)) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([FolderMove].self, from: data)) ?? []
    }

    private static func save(_ moves: [FolderMove], to outDirectory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)
        try encoder.encode(moves).write(to: outDirectory.appendingPathComponent(fileName), options: .atomic)
    }

    // MARK: Checking

    /// Names Graphitree won't give a folder.
    static func nameProblem(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Type a name." }
        if trimmed != name { return "Names can't start or end with a space." }
        if name.contains("/") || name.contains(":") { return "Names can't contain / or :." }
        if name.hasPrefix(".") { return "A name starting with a dot hides the folder." }
        if FolderScan.skipped.contains(name) { return "\(name) is a name graphify keeps for itself." }
        return nil
    }

    /// What stops a move before anything is read: the name, the destination, the folder itself.
    static func blockers(_ request: MoveRequest, root: String, labels: [FolderLabel] = []) -> [String] {
        let fileManager = FileManager.default
        let source = absolute(request.item, root: root)
        let parent = absolute(request.newParent, root: root)
        var found: [String] = []
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source, isDirectory: &isDirectory) else { return ["\(request.item) isn't there any more."] }
        if let problem = nameProblem(request.newName) { found.append(problem) }
        if request.newParent == request.item || request.newParent.hasPrefix(request.item + "/") {
            found.append("A folder can't go inside itself.")
        }
        if labels.contains(where: { $0.path == request.item && $0.holdsProjects }) {
            found.append("\(request.item)/ holds projects. Graphitree moves one project at a time.")
        }
        if request.item == PlaybookFile.graphFolder { found.append("This is Graphitree's copy of your playbook.") }
        if request.item == MemoryCopy.graphFolder { found.append("This is Graphitree's copy of Claude Code's memory.") }
        guard fileManager.fileExists(atPath: parent, isDirectory: &isDirectory), isDirectory.boolValue else {
            return found + ["\(request.newParent.isEmpty ? "The root" : request.newParent + "/") isn't there."]
        }
        // APFS usually ignores case, so `Foo` and `foo` are the same name, except for the folder itself.
        let existing = (try? fileManager.contentsOfDirectory(atPath: parent)) ?? []
        if existing.contains(where: { $0.lowercased() == request.newName.lowercased() && !(request.isRename && $0 == request.name) }) {
            found.append("Something called \(request.newName) is already in \(request.newParent.isEmpty ? "the root" : request.newParent + "/").")
        }
        if let from = volume(of: source), let to = volume(of: parent), !from.isEqual(to) {
            found.append("It's on another disk from \(request.newParent)/, so moving it would copy everything. Move it in Finder instead.")
        }
        if fileManager.fileExists(atPath: (FolderScan.gitDirectories(repo: source).git as NSString).appendingPathComponent("index.lock")) {
            found.append("git is in the middle of something in it (index.lock). Try again when it finishes.")
        }
        return found
    }

    /// Everything the sheet shows before a move. Runs git and lsof, so call it off the main thread.
    /// `busy` says graphify or a rebuild is working; `accounts` gives the logins for the remote check.
    static func check(_ request: MoveRequest, root: String, outDirectory: URL, arrangement: Arrangement?, rules: GitRules, accounts: GitAccounts?, busy: String?, playbook: Playbook? = nil) -> MoveCheck {
        var check = MoveCheck(request: request)
        check.blockers = blockers(request, root: root, labels: arrangement?.labels ?? [])
        if let busy { check.blockers.append(busy) }
        let source = absolute(request.item, root: root)
        guard FileManager.default.fileExists(atPath: source) else { return check }
        let destination = absolute(request.target, root: root)
        let oldMain = String(request.item.split(separator: "/").first ?? "")
        let newMain = String(request.target.split(separator: "/").first ?? "")

        // What Graphitree updates.
        if let arrangement {
            let placement = arrangement.placement(of: request.item)
            let carried = arrangement.carried(from: request.item, to: request.target).arrangement
            let after = carried.placement(of: request.target)
            switch (placement, after) {
            case (.area(let id), .area):
                let name = arrangement.area(id)?.name ?? "its area"
                check.updates.append("The arrangement: it stays in \(name), and the next rebuild reads its files under the new path.")
            case (.leftOut, .leftOut):
                check.updates.append("The arrangement: it stays left out.")
            case (.area, .leftOut):
                let reason = carried.leftOutReason(request.target) ?? "Left out"
                check.updates.append("The arrangement: \(newMain)/ is left out as a whole (\(reason)), so it leaves the graph there.")
            case (.leftOut, .area):
                check.updates.append("The arrangement: it joins the graph in \(newMain)/.")
            }
            let isMain = !request.item.contains("/")
            let toMain = !request.target.contains("/")
            if isMain, let label = arrangement.labels.first(where: { $0.path == request.item }) {
                if toMain {
                    check.updates.append("Its label, renamed to \(request.newName).")
                } else {
                    check.updates.append("Its label (\(label.purpose.title)) goes away: inside \(request.newParent)/ it's one of that folder's projects. Undo brings the label back.")
                }
            } else if toMain {
                check.updates.append("A label for it, so it stays a project of its own at the top level.")
            }
            if isMain, toMain, playbook?.folderStacks?[request.item] != nil {
                check.updates.append("Its own stack in the playbook, kept under the new name.")
            }
        }
        let ignoreText = (try? String(contentsOfFile: ignorePath(root: root), encoding: .utf8)) ?? ""
        let lines = rebasedIgnore(ignoreText, from: request.item, to: request.target).changed
        if lines > 0 { check.updates.append(lines == 1 ? "Its line in .graphifyignore." : "Its \(lines) lines in .graphifyignore.") }
        let links = worktreeLinks(of: source)
        if let main = links.main {
            check.updates.append("Its worktree link to \(relative(main, root: root)), with git worktree repair.")
        } else if !links.linked.isEmpty {
            let names = links.linked.map { relative($0, root: root) }
            check.updates.append("Its worktree link\(names.count == 1 ? "" : "s") to \(names.joined(separator: ", ")), with git worktree repair.")
        }
        if rootFileNamesFolder(source) {
            check.updates.append("Its own graph's root file, graphify-out/.graphify_root, which names the folder.")
        }
        let rulesHere = curationRulesNaming(request.item, outDirectory: outDirectory)
        if rulesHere > 0 {
            check.updates.append("\(rulesHere) cleanup rule\(rulesHere == 1 ? "" : "s") for its files, carried over after the rebuild.")
        }

        // What changes for git.
        let ruleBefore = rules.rule(for: source)
        let ruleAfter = rules.rule(for: destination)
        if ruleBefore?.folder != ruleAfter?.folder {
            let before = rules.identity(for: source)
            let after = rules.identity(for: destination)
            let whereNow = request.oldParent.isEmpty ? "the root" : request.oldParent + "/"
            let whereNext = request.newParent.isEmpty ? "the root" : request.newParent + "/"
            let viaRule = ruleAfter == nil ? ", your global identity, since no git rule covers \(whereNext)" : ""
            if before == after {
                check.rules.append("Commits keep signing as \(after?.display ?? "your global identity")\(viaRule).")
            } else {
                check.rules.append("Commits sign as \(before?.display ?? "your global identity") in \(whereNow). In \(whereNext) they'll sign as \(after?.display ?? "no one: git has no identity set there")\(viaRule).")
            }
            if let accounts, let remote = originURL(repo: source), let owner = GitAccounts.owner(ofRemote: remote) {
                let oldLogin = accounts.login(for: source)
                let newLogin = accounts.login(for: destination)
                if let newLogin, let oldLogin, newLogin != oldLogin, owner.caseInsensitiveCompare(oldLogin) == .orderedSame {
                    // Remotes of repos under the same git rule as the destination show how its account is reached.
                    let territory = (arrangement?.projects ?? []).filter { project in
                        project.path != request.item && rules.rule(for: absolute(project.path, root: root))?.folder == ruleAfter?.folder
                    }.compactMap(\.remote)
                    let suggested = suggestedRemote(remote, login: newLogin, others: territory)
                    check.rules.append("Its remote still pushes to \(owner)/\(repoName(ofRemote: remote)).")
                    check.remoteChoice = MoveCheck.RemoteChoice(current: remote, suggested: suggested, currentOwner: owner, newLogin: newLogin)
                }
            }
        }

        // What's up to the person.
        let open = processes(inside: source)
        if !open.isEmpty {
            check.yours.append("Open in it now: \(open.joined(separator: ", ")). They'll need reopening in the new place.")
        }
        check.yours.append("Editor windows, terminals and dev servers open in the old path need reopening.")
        for environment in pythonEnvironments(in: source, oldPath: source) {
            check.yours.append("Its Python environment \(environment)/ has the old path written into its scripts. Make it again after the move.")
        }
        if request.isRename, let compose = composeFileWithoutName(in: source) {
            check.yours.append("docker compose names containers and volumes after the folder, and \(compose) doesn't set a name, so it won't find the old ones. Add name: \(request.name.lowercased()) to keep them.")
        }
        if FileManager.default.fileExists(atPath: (source as NSString).appendingPathComponent(".envrc")) {
            check.yours.append("direnv asks you to approve its .envrc again in the new place (direnv allow).")
        }
        if let sessions = claudeProjectFolder(for: source) {
            check.yours.append("Claude Code keeps its sessions and memory for it in \(AgentGuide.abbreviate(sessions)), named after the old path. Sessions in the new place start without them; Graphitree leaves that folder alone.")
        }
        if oldMain != newMain, RepoPointer.existingBlock(in: (try? String(contentsOfFile: RepoPointer.targetFile(repo: source), encoding: .utf8)) ?? "") != nil {
            check.yours.append("Its \((RepoPointer.targetFile(repo: source) as NSString).lastPathComponent) has Graphitree's pointer, written for \(oldMain)/. Update it from Pointers after the move; it's committed with the repo.")
        }
        check.docs = docsToReread(request.item, root: root, outDirectory: outDirectory)
        return check
    }

    // MARK: Moving

    /// Moves or renames a folder under the root, then fixes what pointed at the old path. Never
    /// replaces anything. `arrangement` is the saved one; nil leaves `folders.json` alone.
    @discardableResult
    static func perform(_ request: MoveRequest, root: String, outDirectory: URL, arrangement: Arrangement?, remote newRemote: String? = nil, now: Date = .now) throws -> FolderMove {
        let found = blockers(request, root: root, labels: arrangement?.labels ?? [])
        guard found.isEmpty else { throw PlaybookError(message: found.joined(separator: " ")) }
        guard !request.changesNothing else { throw PlaybookError(message: "That's where it already is.") }
        let fixups = try relocate(from: request.item, to: request.target, root: root, outDirectory: outDirectory, arrangement: arrangement, remote: newRemote, restoring: nil)
        let move = FolderMove(from: request.item, to: request.target, at: now, fixups: fixups)
        try save(load(from: outDirectory) + [move], to: outDirectory)
        return move
    }

    /// Moves a top-level item into a folder under the root. Tidy-up tips use it for loose files.
    @discardableResult
    static func move(_ item: String, into folder: String, root: String, log outDirectory: URL, arrangement: Arrangement? = nil, now: Date = .now) throws -> FolderMove {
        let source = absolute(item, root: root)
        guard FileManager.default.fileExists(atPath: source) else { throw PlaybookError(message: "\(item) isn't there any more.") }
        let target = folder + "/" + (item as NSString).lastPathComponent
        guard !FileManager.default.fileExists(atPath: absolute(target, root: root)) else {
            throw PlaybookError(message: "\(target) already exists, so \(item) wasn't moved.")
        }
        try FileManager.default.createDirectory(atPath: absolute(folder, root: root), withIntermediateDirectories: true)
        return try perform(MoveRequest(item: item, newParent: folder), root: root, outDirectory: outDirectory, arrangement: arrangement, now: now)
    }

    /// Puts the last move back, if nothing has taken its old place, and undoes its fix-ups.
    @discardableResult
    static func undoLast(root: String, log outDirectory: URL, arrangement: Arrangement? = nil) throws -> FolderMove? {
        var moves = load(from: outDirectory)
        guard let last = moves.popLast() else { return nil }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: absolute(last.to, root: root)) else { throw PlaybookError(message: "\(last.to) isn't there any more, so it can't be moved back.") }
        guard !fileManager.fileExists(atPath: absolute(last.from, root: root)) else { throw PlaybookError(message: "Something new is at \(last.from), so \(last.to) wasn't moved back.") }
        guard fileManager.fileExists(atPath: absolute(MoveRequest.parent(of: last.from), root: root)) else {
            throw PlaybookError(message: "\(MoveRequest.parent(of: last.from))/ isn't there any more, so \(last.to) can't go back into it.")
        }
        // The remote goes back only if nobody changed it since.
        var remote: String?
        if let before = last.fixups?.remoteBefore, let after = last.fixups?.remoteAfter, originURL(repo: absolute(last.to, root: root)) == after {
            remote = before
        }
        _ = try relocate(from: last.to, to: last.from, root: root, outDirectory: outDirectory, arrangement: last.fixups == nil ? nil : arrangement, remote: remote, restoring: last.fixups)
        try save(moves, to: outDirectory)
        return last
    }

    /// The move itself and every fix-up. Fix-ups that fail are noted, not thrown: the folder has
    /// already moved by then, and the note says what to do by hand.
    private static func relocate(from old: String, to new: String, root: String, outDirectory: URL, arrangement: Arrangement?, remote newRemote: String?, restoring: MoveFixups?) throws -> MoveFixups {
        let source = absolute(old, root: root)
        let destination = absolute(new, root: root)
        let links = worktreeLinks(of: source)
        let realSource = realPath(source)
        var fixups = MoveFixups()

        guard Darwin.rename(source, destination) == 0 else {
            let reason = String(cString: strerror(errno))
            throw PlaybookError(message: "Couldn't move \(old): \(reason).")
        }
        FolderScan.forgetDetectedGroups(root: root)

        // Worktree links, in both directions.
        let git = PlaybookBackup.git()
        if links.main != nil {
            if let result = try? ProcessRunner.run(git, ["-C", destination, "worktree", "repair"], timeout: 30), result.status == 0 {
                fixups.worktrees = [destination]
            } else {
                fixups.problems.append("Its link to its main repo couldn't be repaired. Run git worktree repair inside it.")
            }
        } else if !links.linked.isEmpty {
            let realDestination = realPath(destination)
            let paths = links.linked.map { path in
                path == realSource || path.hasPrefix(realSource + "/") ? realDestination + path.dropFirst(realSource.count) : path
            }.filter { FileManager.default.fileExists(atPath: $0) }
            if let result = try? ProcessRunner.run(git, ["-C", destination, "worktree", "repair"] + paths, timeout: 30), result.status == 0 {
                fixups.worktrees = paths
            } else {
                fixups.problems.append("Its worktree links couldn't be repaired. Run git worktree repair inside it.")
            }
        }

        // A repo's own graph names the folder it was built from.
        if let rewritten = rootFileNeedsRewrite(repo: destination, oldPath: source) {
            do {
                try rewritten.text.write(toFile: rewritten.file, atomically: true, encoding: .utf8)
                fixups.rootFile = true
            } catch {
                fixups.problems.append("Its graphify-out/.graphify_root still names the old folder: \(error.localizedDescription)")
            }
        }

        if let newRemote {
            let before = originURL(repo: destination)
            if let result = try? ProcessRunner.run(git, ["-C", destination, "remote", "set-url", "origin", newRemote], timeout: 15), result.status == 0 {
                fixups.remoteBefore = before
                fixups.remoteAfter = newRemote
            } else {
                fixups.problems.append("Its remote couldn't be changed. It still pushes to \(before ?? "where it did").")
            }
        }

        // The arrangement: labels, areas, placements and graphs follow the folder.
        var leftOutAfter: Bool?
        if let arrangement {
            let carried = arrangement.carried(from: old, to: new, restoring: restoring)
            do {
                try FolderFile.save(carried.arrangement.folderMap, to: outDirectory)
                try GraphPlans.save(carried.arrangement.graphs, to: outDirectory)
                fixups.arrangement = true
                fixups.removedLabel = carried.removedLabel
                fixups.madeArea = carried.madeArea
            } catch {
                fixups.problems.append("The arrangement couldn't be saved: \(error.localizedDescription)")
            }
            let main = String(new.split(separator: "/").first ?? "")
            if carried.arrangement.labels.first(where: { $0.path == main })?.isIncluded == true {
                leftOutAfter = carried.arrangement.placement(of: new).isLeftOut
            }
        }

        // `.graphifyignore`: lines about the old path follow it, and the project's own line matches
        // whether it's left out.
        let ignore = ignorePath(root: root)
        let text = (try? String(contentsOfFile: ignore, encoding: .utf8)) ?? ""
        var (updated, changed) = rebasedIgnore(text, from: old, to: new)
        if let leftOutAfter {
            let line = FolderIgnore.line(for: new)
            let present = IgnoreFile.patterns(in: updated).contains(line)
            if leftOutAfter, !present {
                updated = IgnoreFile.adding([line], to: updated, note: "Left out, kept so by a move in Graphitree, \(Date.now.formatted(date: .abbreviated, time: .omitted))")
                changed += 1
            } else if !leftOutAfter, present {
                updated = IgnoreFile.removing([line], from: updated)
                changed += 1
            }
        }
        if updated != text {
            do {
                try AgentSetup.backUp(ignore)
                try AgentSetup.write(updated, to: ignore)
                fixups.ignoreLines = changed
            } catch {
                fixups.problems.append(".graphifyignore couldn't be changed: \(error.localizedDescription)")
            }
        }

        // A main folder's own stack answers follow its new name.
        if !old.contains("/"), !new.contains("/") {
            var playbook = PlaybookFile.load(from: outDirectory)
            if let own = playbook.folderStacks?[old], playbook.folderStacks?[new] == nil {
                playbook.folderStacks?[old] = nil
                playbook.folderStacks?[new] = own
                do {
                    try PlaybookFile.save(playbook, to: outDirectory)
                    if FileManager.default.fileExists(atPath: absolute(PlaybookFile.graphFolder, root: root)) {
                        _ = try PlaybookFile.writeGraphCopy(playbook, root: root)
                    }
                    fixups.folderStack = true
                } catch {
                    fixups.problems.append("Its stack in the playbook still uses the old name: \(error.localizedDescription)")
                }
            }
        }
        return fixups
    }

    // MARK: New folders

    /// Makes an empty folder at the top of the root to move projects into.
    static func newFolder(_ name: String, root: String) throws {
        if let problem = nameProblem(name) { throw PlaybookError(message: problem) }
        let existing = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
        guard !existing.contains(where: { $0.lowercased() == name.lowercased() }) else {
            throw PlaybookError(message: "There's already something called \(name).")
        }
        try FileManager.default.createDirectory(atPath: absolute(name, root: root), withIntermediateDirectories: false)
        FolderScan.forgetDetectedGroups(root: root)
    }

    /// The lines that give a new folder the same commit identity as an existing rule, for the
    /// person to add to `~/.gitconfig`. Graphitree doesn't edit it.
    static func includeIfLines(folder: String, root: String, like rule: GitRule, home: String = NSHomeDirectory()) -> String {
        func tilde(_ path: String) -> String { path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path }
        return "[includeIf \"gitdir:\(tilde(absolute(folder, root: root)))/\"]\n\tpath = \(tilde(rule.configFile))"
    }

    // MARK: The pieces

    static func absolute(_ path: String, root: String) -> String {
        path.isEmpty ? root : (root as NSString).appendingPathComponent(path)
    }

    static func relative(_ path: String, root: String) -> String {
        for base in [root, realPath(root)] where path.hasPrefix(base + "/") { return String(path.dropFirst(base.count + 1)) }
        return AgentGuide.abbreviate(path)
    }

    static func ignorePath(root: String) -> String { absolute(".graphifyignore", root: root) }

    static func realPath(_ path: String) -> String {
        guard let resolved = Darwin.realpath(path, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    private static func volume(of path: String) -> NSObject? {
        (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier as? NSObject
    }

    /// A repo's worktree links: its main repo when it's a linked worktree, or the linked worktrees
    /// of a main repo, as absolute real paths.
    static func worktreeLinks(of repo: String) -> (main: String?, linked: [String]) {
        let dirs = FolderScan.gitDirectories(repo: repo)
        if dirs.git != dirs.common { return ((dirs.common as NSString).deletingLastPathComponent, []) }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dirs.git, isDirectory: &isDirectory), isDirectory.boolValue,
              FileManager.default.fileExists(atPath: (dirs.git as NSString).appendingPathComponent("worktrees")),
              let result = try? ProcessRunner.run(PlaybookBackup.git(), ["-C", repo, "worktree", "list", "--porcelain"], timeout: 15), result.status == 0 else { return (nil, []) }
        let paths = result.output.split(separator: "\n").filter { $0.hasPrefix("worktree ") }.map { String($0.dropFirst("worktree ".count)) }
        let me = realPath(repo)
        return (nil, paths.filter { $0 != me })
    }

    static func originURL(repo: String) -> String? {
        let config = (FolderScan.gitDirectories(repo: repo).common as NSString).appendingPathComponent("config")
        return FolderScan.originURL(inConfig: (try? String(contentsOfFile: config, encoding: .utf8)) ?? "")
    }

    static func repoName(ofRemote remote: String) -> String {
        var name = (remote as NSString).lastPathComponent
        if let colon = name.lastIndex(of: ":") { name = String(name[name.index(after: colon)...]) }
        return name.hasSuffix(".git") ? String(name.dropLast(4)) : name
    }

    /// The same repo under another login, written the way remotes in the new folder are. An https
    /// remote stays https. An SSH remote takes the host alias most used by `others` (the remotes
    /// of repos under the destination's git rule), preferring those the login owns, since the
    /// alias picks the SSH key and so the account.
    static func suggestedRemote(_ remote: String, login: String, others: [String]) -> String {
        let name = repoName(ofRemote: remote)
        guard remote.hasPrefix("git@") || remote.hasPrefix("ssh://") else { return "https://github.com/\(login)/\(name).git" }
        func host(_ other: String) -> String? {
            guard other.hasPrefix("git@"), let colon = other.firstIndex(of: ":") else { return nil }
            return String(other[other.index(other.startIndex, offsetBy: 4)..<colon])
        }
        func mostUsed(_ remotes: [String]) -> String? {
            Dictionary(grouping: remotes.compactMap(host), by: { $0 }).max { $0.value.count != $1.value.count ? $0.value.count < $1.value.count : $0.key > $1.key }?.key
        }
        let owned = others.filter { GitAccounts.owner(ofRemote: $0)?.caseInsensitiveCompare(login) == .orderedSame }
        let chosen = mostUsed(owned) ?? mostUsed(others) ?? "github.com"
        return "git@\(chosen):\(login)/\(name).git"
    }

    /// `.graphifyignore` with lines about `old` moved to `new`, and how many changed. Comments,
    /// negations and leading slashes are kept.
    static func rebasedIgnore(_ text: String, from old: String, to new: String) -> (text: String, changed: Int) {
        var changed = 0
        let lines = text.components(separatedBy: "\n").map { line -> String in
            let rebased = rebasedIgnoreLine(line, from: old, to: new)
            if rebased != line { changed += 1 }
            return rebased
        }
        return (lines.joined(separator: "\n"), changed)
    }

    static func rebasedIgnoreLine(_ line: String, from old: String, to new: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return line }
        var body = Substring(trimmed)
        var prefix = ""
        if body.hasPrefix("!") { prefix += "!"; body = body.dropFirst() }
        if body.hasPrefix("/") { prefix += "/"; body = body.dropFirst() }
        let escapedOld = old.replacingOccurrences(of: "[", with: "[[]")
        let escapedNew = new.replacingOccurrences(of: "[", with: "[[]")
        if body == escapedOld { return prefix + escapedNew }
        if body.hasPrefix(escapedOld + "/") { return prefix + escapedNew + body.dropFirst(escapedOld.count) }
        return line
    }

    /// Whether a repo has its own graph whose root file names the repo's folder.
    static func rootFileNamesFolder(_ repo: String) -> Bool {
        guard let text = try? String(contentsOfFile: (repo as NSString).appendingPathComponent("graphify-out/.graphify_root"), encoding: .utf8) else { return false }
        let named = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Set([repo, realPath(repo)]).contains { named == $0 || named.hasPrefix($0 + "/") }
    }

    /// The root file of a repo's own graph, when it names the folder's old path, with its new text.
    static func rootFileNeedsRewrite(repo: String, oldPath: String? = nil) -> (file: String, text: String)? {
        let file = (repo as NSString).appendingPathComponent("graphify-out/.graphify_root")
        guard let text = try? String(contentsOfFile: file, encoding: .utf8) else { return nil }
        let named = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let old = oldPath ?? repo
        for base in Set([old, realPath(old)]) where named == base || named.hasPrefix(base + "/") {
            let rewritten = repo + named.dropFirst(base.count)
            return rewritten == named ? nil : (file, rewritten + (text.hasSuffix("\n") ? "\n" : ""))
        }
        return nil
    }

    /// Programs whose working folder is inside `path`, such as `zsh (2), node`, from lsof.
    static func processes(inside path: String) -> [String] {
        guard let result = try? ProcessRunner.run("/usr/sbin/lsof", ["-d", "cwd", "-F", "pcn"], timeout: 15) else { return [] }
        let real = realPath(path)
        let me = ProcessInfo.processInfo.processIdentifier
        var pid: Int32 = 0
        var command = ""
        var counts: [String: Int] = [:]
        for line in result.output.split(separator: "\n") {
            guard let kind = line.first else { continue }
            let value = String(line.dropFirst())
            switch kind {
            case "p": pid = Int32(value) ?? 0
            case "c": command = value
            case "n":
                guard pid != me, command != "lsof", value == real || value.hasPrefix(real + "/") || value == path || value.hasPrefix(path + "/") else { continue }
                counts[command, default: 0] += 1
            default: break
            }
        }
        return counts.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }.map { $0.value > 1 ? "\($0.key) (\($0.value))" : $0.key }
    }

    /// Claude Code's folder for a project's sessions and memory, when there is one: the path with
    /// every character but letters and digits as `-`.
    static func claudeProjectFolder(for path: String, home: String = NSHomeDirectory()) -> String? {
        let name = String(path.map { $0.isLetter || $0.isNumber ? $0 : "-" })
        let folder = (home as NSString).appendingPathComponent(".claude/projects/" + name)
        return FileManager.default.fileExists(atPath: folder) ? folder : nil
    }

    /// Python environments directly inside a folder whose scripts name its current path.
    static func pythonEnvironments(in folder: String, oldPath: String) -> [String] {
        let fileManager = FileManager.default
        return ((try? fileManager.contentsOfDirectory(atPath: folder)) ?? []).sorted().filter { name in
            let environment = (folder as NSString).appendingPathComponent(name)
            guard fileManager.fileExists(atPath: (environment as NSString).appendingPathComponent("pyvenv.cfg")) else { return false }
            let activate = (try? String(contentsOfFile: (environment as NSString).appendingPathComponent("bin/activate"), encoding: .utf8)) ?? ""
            return activate.contains(oldPath) || activate.contains(realPath(oldPath))
        }
    }

    /// A compose file at the top of a folder that doesn't set the project's name.
    static func composeFileWithoutName(in folder: String) -> String? {
        let env = (try? String(contentsOfFile: (folder as NSString).appendingPathComponent(".env"), encoding: .utf8)) ?? ""
        guard !env.contains("COMPOSE_PROJECT_NAME") else { return nil }
        for name in ["compose.yaml", "compose.yml", "docker-compose.yml", "docker-compose.yaml"] {
            guard let text = try? String(contentsOfFile: (folder as NSString).appendingPathComponent(name), encoding: .utf8) else { continue }
            let setsName = text.split(separator: "\n").contains { $0.hasPrefix("name:") }
            return setsName ? nil : name
        }
        return nil
    }

    // MARK: What a move costs

    static let docExtensions: Set<String> = ["html", "j2", "jinja", "jinja2", "md", "mdx", "qmd", "rst", "skill", "txt", "pdf", "docx", "xlsx"]
    static let imageExtensions: Set<String> = ["gif", "jpeg", "jpg", "png", "svg", "webp"]

    /// The docs graphify read for this folder, which it reads again under a new path: its
    /// semantic cache is keyed by each file's path as well as its content. Token counts follow
    /// graphify's own estimate (characters / 4, capped per file; a flat amount per image).
    static func docsToReread(_ item: String, root: String, outDirectory: URL) -> DocsEstimate {
        guard let data = try? Data(contentsOf: outDirectory.appendingPathComponent("manifest.json")),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return DocsEstimate() }
        let prefix = item + "/"
        var files: [PendingDoc] = []
        for path in manifest.keys.sorted() where path.hasPrefix(prefix) {
            let ext = (path as NSString).pathExtension.lowercased()
            if imageExtensions.contains(ext) {
                files.append(PendingDoc(path: path, kind: "image", tokens: 1_600))
            } else if docExtensions.contains(ext) {
                let size = (try? FileManager.default.attributesOfItem(atPath: absolute(path, root: root))[.size] as? Int) ?? 0
                files.append(PendingDoc(path: path, kind: ext == "pdf" ? "paper" : "document", tokens: (min(size, 20_000) + 160) / 4))
            }
        }
        let tokens = files.reduce(0) { $0 + $1.tokens }
        return DocsEstimate(files: files, chunks: files.isEmpty ? 0 : max(1, Int((Double(tokens) / 60_000).rounded(.up))))
    }

    // MARK: Cleanup rules

    /// How many cleanup rules name a node or path inside this folder.
    static func curationRulesNaming(_ item: String, outDirectory: URL) -> Int {
        guard let log = try? CurationLog(url: outDirectory.appendingPathComponent("curation.jsonl")) else { return 0 }
        return carriedRules(log.entries, from: item, to: item + "-moved", nodeExists: { _ in true }).count
    }

    /// graphify's node ids start with the file's path in lower case, with everything but letters
    /// and digits as `_`: `personal/my-app` → `personal_my_app_`.
    static func idPrefix(for path: String) -> String {
        String(path.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "_" }) + "_"
    }

    /// The cleanup decisions still in force that named the old path, rewritten for the new one.
    /// A rule about a node comes along only when the node exists under its new id, so this runs
    /// after the rebuild.
    static func carriedRules(_ entries: [CurationEntry], from old: String, to new: String, nodeExists: (String) -> Bool) -> [CarriedRule] {
        let revoked = Set(entries.filter { $0.op == CurationEntry.Op.revoke }.compactMap(\.rule))
        let oldID = idPrefix(for: old)
        let newID = idPrefix(for: new)
        func rewritten(_ id: String?) -> String? {
            guard let id, id.hasPrefix(oldID) else { return nil }
            let moved = newID + id.dropFirst(oldID.count)
            return nodeExists(moved) ? moved : nil
        }
        var actions: [CarriedRule] = []
        for entry in entries where !revoked.contains(entry.id) {
            switch entry.op {
            case CurationEntry.Op.hidePath:
                guard let glob = entry.glob else { continue }
                let rebased = rebasedIgnoreLine(glob, from: old, to: new)
                if rebased != glob { actions.append(CarriedRule(id: entry.id, action: .hidePath(glob: rebased, note: entry.note ?? ""))) }
            case CurationEntry.Op.hideNode:
                if let node = rewritten(entry.node) { actions.append(CarriedRule(id: entry.id, action: .hideNode(id: node, label: entry.label ?? node))) }
            case CurationEntry.Op.rejectEdges:
                if let node = rewritten(entry.node) { actions.append(CarriedRule(id: entry.id, action: .rejectCrossLinks(node: node, label: entry.label ?? node))) }
            case CurationEntry.Op.rejectEdge:
                let source = rewritten(entry.source)
                let target = rewritten(entry.target)
                guard source != nil || target != nil else { continue }
                let from = source ?? entry.source ?? ""
                let to = target ?? entry.target ?? ""
                // Both ends must exist: an end that didn't move keeps its id.
                guard (source != nil || !(entry.source ?? "").hasPrefix(oldID)), (target != nil || !(entry.target ?? "").hasPrefix(oldID)) else { continue }
                actions.append(CarriedRule(id: entry.id, action: .rejectLink(source: from, target: to, relation: entry.relation ?? "", note: entry.note ?? "")))
            default:
                continue
            }
        }
        return actions
    }
}

/// A cleanup rule rewritten for a moved folder, with the id of the rule it replaces.
struct CarriedRule: Hashable, Sendable {
    let id: String
    let action: CurationAction
}

/// The rules one move can carry over.
struct RuleCarry: Hashable, Sendable {
    let move: FolderMove
    let rules: [CarriedRule]
}

// MARK: - The arrangement after a move

extension Arrangement {
    /// The arrangement after a folder moved on disk from `old` to `new`. Every project keeps its
    /// area or stays left out, and every graph keeps its areas. A main folder moved into a group
    /// loses its label; if that leaves its area with no label, the area becomes one made in Arrange.
    /// `restoring` is the move being undone: its label comes back, and the area made for it merges
    /// back into the label's area.
    func carried(from old: String, to new: String, restoring: MoveFixups? = nil) -> (arrangement: Arrangement, removedLabel: FolderLabel?, madeArea: String?) {
        func rebase(_ path: String) -> String {
            if path == old { return new }
            if path.hasPrefix(old + "/") { return new + path.dropFirst(old.count) }
            return path
        }
        let oldIsMain = !old.contains("/")
        let newIsMain = !new.contains("/")
        var labels = self.labels
        var labelPaths = Dictionary(uniqueKeysWithValues: labels.map { ($0.path, $0.path) })
        var removedLabel: FolderLabel?
        if oldIsMain, let index = labels.firstIndex(where: { $0.path == old }) {
            if newIsMain {
                labels[index].path = new
                labelPaths[old] = new
            } else {
                removedLabel = labels.remove(at: index)
                labelPaths[old] = nil
            }
        }
        let before = placement(of: old)
        if newIsMain, !labels.contains(where: { $0.path == new }) {
            if var label = restoring?.removedLabel {
                label.path = new
                labels.append(label)
            } else {
                // A project leaving its group for the top level gets a label with its area's purpose.
                let purpose = before.areaID.flatMap(area)?.purpose ?? labels.first { $0.path == String(old.split(separator: "/").first ?? "") }?.purpose ?? .other
                labels.append(FolderLabel(path: new, purpose: purpose))
            }
        }

        var next = self
        next.labels = labels
        next.projects = projects.map { project in
            ArrangeProject(path: rebase(project.path), nodes: project.nodes, remote: project.remote, hasOwnCommits: project.hasOwnCommits, worktreeOf: project.worktreeOf.map(rebase), isRepo: project.isRepo)
        }
        next.ignoredLines = Set(ignoredLines.map { FolderMoves.rebasedIgnoreLine($0, from: old, to: new) })

        // An area from labels follows its labels. One left with none becomes an area made in Arrange.
        var areaMap: [String: String] = [:]
        var madeArea: String?
        let labelAreasAfter = next.labelAreas
        for info in labelAreas {
            let followed = Set(info.labelPaths.compactMap { labelPaths[$0] })
            if let target = labelAreasAfter.first(where: { !followed.isDisjoint(with: $0.labelPaths) }) {
                areaMap[info.id] = target.id
            } else if !projects(in: info.id).isEmpty {
                let id = "area-" + Self.shortID()
                next.arrangedAreas.append(ArrangedArea(id: id, name: info.name, purpose: info.purpose))
                areaMap[info.id] = id
                madeArea = id
            }
        }
        // Undo: the area made for the move merges back into the restored label's area.
        if let made = restoring?.madeArea, let label = restoring?.removedLabel,
           let target = labelAreasAfter.first(where: { $0.labelPaths.contains(new) || $0.labelPaths.contains(label.path) }),
           projects(in: made).allSatisfy({ $0.path == old }) {
            areaMap[made] = target.id
            next.arrangedAreas.removeAll { $0.id == made }
        }
        func mapped(_ id: String) -> String { areaMap[id] ?? id }
        next.graphs = graphs.map { graph in
            var graph = graph
            var seen = Set<String>()
            graph.areaIDs = graph.areaIDs.map(mapped).filter { seen.insert($0).inserted }
            return graph
        }

        // Placements: each project where it was. Saved only where that isn't where labels put it.
        let known = Set(projects.map(\.path))
        var placements = placement.filter { !known.contains($0.key) && $0.key != old }.mapValues { value -> Placement in
            value.areaID.map { .area(mapped($0)) } ?? value
        }
        next.placement = [:]
        for project in projects {
            let path = rebase(project.path)
            let was = placement(of: project.path)
            // Left out only because its whole folder is: the person didn't choose that for this
            // project, so it takes whatever its new folder gives it.
            let oldMain = String(project.path.split(separator: "/").first ?? "")
            if placement[project.path] == nil, project.path != oldMain, self.labels.first(where: { $0.path == oldMain })?.isIncluded == false { continue }
            let value: Placement = was.areaID.map { .area(mapped($0)) } ?? was
            let fallback = next.defaultPlacement(of: path)
            let main = String(path.split(separator: "/").first ?? "")
            if value.areaID != nil, path != main, next.labels.first(where: { $0.path == main })?.isIncluded == false {
                continue // Inside a folder left out as a whole, it's left out with it.
            }
            if value.isLeftOut, fallback.isLeftOut { continue }
            if fallback != value { placements[path] = value }
        }
        next.placement = placements
        let result = Arrangement(labels: next.labels, arrangedAreas: next.arrangedAreas, placement: next.placement, graphs: next.graphs, projects: next.projects, ignoredLines: next.ignoredLines)
        return (result, removedLabel, madeArea.flatMap { id in result.arrangedAreas.contains { $0.id == id } ? id : nil })
    }
}

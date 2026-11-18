import Foundation

// The two things the playbook does outside Graphitree: Claude Code drafts library details, and git
// backs the playbook up to a private GitHub repo.

struct ProcessOutput: Sendable {
    let status: Int32
    let output: String
    let errors: String
    let timedOut: Bool
}

enum ProcessRunner {
    /// Runs a program and waits, draining both pipes so neither can fill up and stall it.
    static func run(
        _ executable: String,
        _ arguments: [String],
        in directory: URL? = nil,
        environment extra: [String: String] = [:],
        timeout: TimeInterval = 120,
        onStart: ((Process) -> Void)? = nil
    ) throws -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let directory { process.currentDirectoryURL = directory }
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        environment["PATH"] = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        environment.merge(extra) { _, new in new }
        process.environment = environment
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        onStart?(process)

        let timer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
        var errorData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            errorData = errors.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        group.wait()
        timer.cancel()
        return ProcessOutput(
            status: process.terminationStatus,
            output: String(decoding: data, as: UTF8.self),
            errors: String(decoding: errorData, as: UTF8.self),
            timedOut: process.terminationReason == .uncaughtSignal
        )
    }
}

struct PlaybookError: LocalizedError {
    let message: String
    /// Set when a backup stopped because GitHub has a playbook this Mac hasn't seen: that copy.
    var remoteCopy: Playbook? = nil
    var errorDescription: String? { message }
}

// MARK: - Claude drafts

/// What Claude Code writes about one library.
struct LibraryDraft: Codable, Equatable, Sendable {
    var name: String
    var url: String
    var task: String
    var purpose: String
    var useWhen: String
    var avoidWhen: String
    var install: String
    var platforms: String
    var health: String
}

enum PlaybookResearch {
    /// Libraries per Claude call. Each call carries Claude Code's own context, so batching saves plan usage.
    static let batchSize = 6

    static let schema = """
    {"type":"object","properties":{"libraries":{"type":"array","items":{"type":"object","properties":{\
    "name":{"type":"string"},"url":{"type":"string"},"task":{"type":"string"},"purpose":{"type":"string"},\
    "useWhen":{"type":"string"},"avoidWhen":{"type":"string"},"install":{"type":"string"},\
    "platforms":{"type":"string"},"health":{"type":"string"}},\
    "required":["name","url","task","purpose","useWhen","avoidWhen","install","platforms","health"]}}},\
    "required":["libraries"]}
    """

    static func prompt(for libraries: [PlaybookLibrary]) -> String {
        let list = libraries.map { $0.url.isEmpty ? $0.name : "\($0.name) (\($0.url))" }.joined(separator: "; ")
        return """
        Research these libraries and tools on the web for a developer's playbook, which tells AI coding tools what to use: \(list).
        For each one, return: name (as given), url (its home page), task (2 to 4 words for the job it does, such as "Toasts" or "UI components"), \
        purpose (one sentence), useWhen, avoidWhen, install (the command, or how to add it if there's no package), \
        platforms (such as "React" or "Any web stack"), and health (is it maintained: latest release and year, and any deprecation or "unmaintained" notice).
        Be factual and brief. Check the project's own site or repository. Write "unknown" for anything you can't confirm.
        """
    }

    /// `claude -p` with only the web tools, no user settings or MCP servers, and structured output.
    static func arguments(for libraries: [PlaybookLibrary]) -> [String] {
        [
            "-p", prompt(for: libraries),
            "--output-format", "json",
            "--json-schema", schema,
            "--tools", "WebSearch,WebFetch",
            "--allowedTools", "WebSearch,WebFetch",
            "--permission-mode", "dontAsk",
            "--setting-sources", "project",
            "--strict-mcp-config",
            "--no-session-persistence",
        ]
    }

    /// Reads Claude Code's JSON result: `structured_output`, or JSON in `result` as a fallback.
    static func parse(_ text: String) throws -> [LibraryDraft] {
        guard let data = text.data(using: .utf8),
              let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlaybookError(message: "Claude Code's reply wasn't JSON.")
        }
        if envelope["is_error"] as? Bool == true {
            throw PlaybookError(message: (envelope["result"] as? String) ?? "Claude Code reported an error.")
        }
        var payload: Any? = envelope["structured_output"]
        if payload == nil, let result = envelope["result"] as? String, let inner = result.data(using: .utf8) {
            payload = try? JSONSerialization.jsonObject(with: inner)
        }
        guard let object = payload as? [String: Any], let list = object["libraries"],
              let listData = try? JSONSerialization.data(withJSONObject: list),
              let drafts = try? JSONDecoder().decode([LibraryDraft].self, from: listData) else {
            throw PlaybookError(message: "Claude Code's reply didn't have the library details.")
        }
        return drafts
    }

    /// Fills a library from a draft. The person's own notes stay, and it's marked as a draft again.
    static func applying(_ draft: LibraryDraft, to library: PlaybookLibrary) -> PlaybookLibrary {
        var result = library
        func keep(_ text: String) -> String? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed.lowercased() == "unknown" ? nil : trimmed
        }
        if result.url.isEmpty, let url = keep(draft.url) { result.url = url }
        if result.task.isEmpty, let task = keep(draft.task) { result.task = task }
        result.purpose = keep(draft.purpose) ?? result.purpose
        result.useWhen = keep(draft.useWhen) ?? result.useWhen
        result.avoidWhen = keep(draft.avoidWhen) ?? result.avoidWhen
        result.install = keep(draft.install) ?? result.install
        result.platforms = keep(draft.platforms) ?? result.platforms
        result.health = keep(draft.health) ?? result.health
        result.verified = false
        result.drafted = true
        return result
    }

    /// Matches drafts back to libraries by name, ignoring case and punctuation.
    static func match(_ drafts: [LibraryDraft], to libraries: [PlaybookLibrary]) -> [UUID: LibraryDraft] {
        func key(_ name: String) -> String { name.lowercased().filter { $0.isLetter || $0.isNumber } }
        var byName: [String: LibraryDraft] = [:]
        for draft in drafts { byName[key(draft.name)] = draft }
        var result: [UUID: LibraryDraft] = [:]
        for (index, library) in libraries.enumerated() {
            if let draft = byName[key(library.name)] {
                result[library.id] = draft
            } else if drafts.count == libraries.count {
                result[library.id] = drafts[index] // Same count and order: Claude renamed it.
            }
        }
        return result
    }

    static func run(_ libraries: [PlaybookLibrary], claude: String) throws -> [LibraryDraft] {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-research-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let result = try ProcessRunner.run(claude, arguments(for: libraries), in: scratch, timeout: 420)
        if result.timedOut { throw PlaybookError(message: "Claude Code took longer than 7 minutes, so it was stopped.") }
        if result.status != 0 && result.output.isEmpty {
            throw PlaybookError(message: result.errors.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Claude Code stopped with exit \(result.status)." : result.errors)
        }
        return try parse(result.output)
    }
}

// MARK: - GitHub backup

/// Where one graph's playbook is backed up. Each graph has its own playbook, so each has its own
/// repo; one repo shared by two graphs would have each backup replace the other's.
struct PlaybookBackupSettings: Codable, Equatable, Sendable {
    var github = false
    var account = ""
    /// The repo name to create. Empty means the default for the graph.
    var repoName = ""
    var remote = ""
    var lastBackup: Date?
    /// Why the last backup didn't go through, such as GitHub having changes from another Mac.
    var problem: String?
}

enum PlaybookBackupStore {
    private static func key(_ outDirectory: URL) -> String { "playbookBackup:" + outDirectory.standardizedFileURL.path }
    static let legacyClaimedKey = "playbookBackupLegacyClaimed"

    /// This graph's settings. Versions before per-graph settings kept one set for every graph:
    /// the first graph to ask takes it over, and the check before each push catches a wrong guess.
    static func load(for outDirectory: URL, defaults: UserDefaults = .standard) -> PlaybookBackupSettings {
        if let data = defaults.data(forKey: key(outDirectory)),
           let settings = try? JSONDecoder().decode(PlaybookBackupSettings.self, from: data) {
            return settings
        }
        guard !defaults.bool(forKey: legacyClaimedKey) else { return PlaybookBackupSettings() }
        let remote = defaults.string(forKey: "playbookRemote") ?? ""
        let github = defaults.string(forKey: "playbookStorage") == "github"
        guard github || !remote.isEmpty else { return PlaybookBackupSettings() }
        let last = defaults.double(forKey: "playbookLastBackup")
        let settings = PlaybookBackupSettings(
            github: github, account: defaults.string(forKey: "playbookAccount") ?? "",
            repoName: defaults.string(forKey: "playbookRepoName") ?? "", remote: remote,
            lastBackup: last > 0 ? Date(timeIntervalSince1970: last) : nil
        )
        save(settings, for: outDirectory, defaults: defaults)
        defaults.set(true, forKey: legacyClaimedKey)
        return settings
    }

    static func save(_ settings: PlaybookBackupSettings, for outDirectory: URL, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: key(outDirectory)) }
    }

    static func update(for outDirectory: URL, defaults: UserDefaults = .standard, _ change: (inout PlaybookBackupSettings) -> Void) {
        var settings = load(for: outDirectory, defaults: defaults)
        change(&settings)
        save(settings, for: outDirectory, defaults: defaults)
    }
}

/// A copy of the playbook in its own git repo, pushed to a private GitHub repo. It's separate
/// from graphify-out, which has its own history and holds the large graph.
enum PlaybookBackup {
    static let files = [PlaybookFile.jsonName, PlaybookFile.markdownName]

    /// The repo name a graph starts with: the machine-wide graph's plain, a single repo's named after it.
    static func defaultRepoName(singleRepo: String?) -> String {
        guard let singleRepo else { return "graphitree-playbook" }
        let name = singleRepo.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? String($0) : "-" }.joined()
        return "graphitree-playbook-" + name
    }

    /// The local git copy for one remote. Older versions kept one copy for whichever repo they
    /// pushed to; it moves here when it's the copy of this remote.
    static func mirror(for remote: String, support: URL = applicationSupport) -> URL {
        let fileManager = FileManager.default
        let folder = mirrorFolder(for: remote, support: support)
        let legacy = support.appendingPathComponent("Graphitree/Playbook Backup", isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path),
           fileManager.fileExists(atPath: legacy.appendingPathComponent(".git").path),
           let origin = try? ProcessRunner.run(git(), ["remote", "get-url", "origin"], in: legacy, timeout: 20),
           origin.output.trimmingCharacters(in: .whitespacesAndNewlines) == remote {
            try? fileManager.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fileManager.moveItem(at: legacy, to: folder)
        }
        return folder
    }

    /// Where the copy for a remote lives, without moving anything.
    static func mirrorFolder(for remote: String, support: URL = applicationSupport) -> URL {
        let name = remote.map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        return support.appendingPathComponent("Graphitree/Playbook Backups/\(name)", isDirectory: true)
    }

    static var applicationSupport: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0] }

    static func gh() -> String? {
        ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", FileManager.default.homeDirectoryForCurrentUser.path + "/.local/bin/gh"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func git() -> String { FileManager.default.isExecutableFile(atPath: "/usr/bin/git") ? "/usr/bin/git" : "/opt/homebrew/bin/git" }

    /// The GitHub accounts `gh` is signed in to, from `gh auth status`.
    static func accounts(from status: String) -> [String] {
        status.components(separatedBy: .newlines).compactMap { line in
            guard let range = line.range(of: "Logged in to github.com account ") else { return nil }
            return line[range.upperBound...].split(separator: " ").first.map(String.init)
        }
    }

    static func accounts() -> [String] {
        guard let gh = gh(), let result = try? ProcessRunner.run(gh, ["auth", "status"], timeout: 20) else { return [] }
        return accounts(from: result.output + "\n" + result.errors)
    }

    static func token(for account: String) throws -> String {
        guard let gh = gh() else { throw PlaybookError(message: "The GitHub command (gh) isn't installed. Install it from cli.github.com and sign in.") }
        let result = try ProcessRunner.run(gh, ["auth", "token", "--user", account], timeout: 20)
        let token = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.status == 0, !token.isEmpty else { throw PlaybookError(message: "gh isn't signed in as \(account).") }
        return token
    }

    /// Creates the private repo on GitHub under the account. Returns its HTTPS URL.
    static func createRepo(named name: String, account: String) throws -> String {
        guard let gh = gh() else { throw PlaybookError(message: "The GitHub command (gh) isn't installed.") }
        let token = try token(for: account)
        let result = try ProcessRunner.run(gh, ["repo", "create", name, "--private", "--description", "Playbook written by Graphitree: libraries, stack and working notes for AI tools"], environment: ["GH_TOKEN": token], timeout: 60)
        guard result.status == 0 else {
            throw PlaybookError(message: result.errors.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gh couldn't create the repo." : result.errors.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return "https://github.com/\(account)/\(name).git"
    }

    /// Copies the playbook into the mirror, commits if anything changed, and pushes.
    /// `remote` is an HTTPS GitHub URL, or a local path (used by the checks).
    /// Returns false when there was nothing new to back up.
    /// `identity` signs the commit; without one, git's own identity is used.
    /// When the remote has a playbook this Mac hasn't seen, from another Mac or another graph, it
    /// stops with that copy in the error, unless `replacing` says to back up over it.
    @discardableResult
    static func backUp(from directory: URL, to mirror: URL? = nil, remote: String, account: String?, identity: GitIdentity? = nil, replacing: Bool = false, now: Date = .now) throws -> Bool {
        if PlaybookFile.isUnreadable(in: directory) {
            throw PlaybookError(message: "\(PlaybookFile.jsonName) can't be read, so nothing was backed up. The copy on GitHub is unchanged.")
        }
        let mine = PlaybookFile.load(from: directory)
        let mirror = mirror ?? Self.mirror(for: remote)
        let existed = FileManager.default.fileExists(atPath: mirror.appendingPathComponent(".git").path)
        let git = try GitMirror(directory: mirror, remote: remote, login: account)
        try git.prepare()
        let synced = syncedCommit(in: mirror, existed: existed, git: git)
        // Takes in anything pushed from another Mac first. History is never rewritten.
        try git.catchUp()
        if !replacing, let theirs = try unseenCopy(git: git, synced: synced), !sameContent(theirs, mine) {
            throw PlaybookError(message: "The repo has a playbook this Mac hasn't seen: \(summary(of: theirs)). Nothing was pushed.", remoteCopy: theirs)
        }
        // An empty playbook would replace the copy on GitHub with nothing.
        guard !mine.isEmpty else {
            throw PlaybookError(message: "The playbook is empty, so nothing was backed up. The copy on GitHub is unchanged.")
        }
        var contents: [String: Data] = [:]
        for name in files {
            if let data = try? Data(contentsOf: directory.appendingPathComponent(name)) { contents[name] = data }
        }
        // Only the playbook's files: anything else that crept into the copy goes.
        try git.replaceContents(with: contents)
        let stamp = ISO8601DateFormatter.string(from: now, timeZone: .current, formatOptions: [.withFullDate, .withTime, .withColonSeparatorInTime])
        let commit = try git.commit(message: "Playbook backup \(stamp)", identity: identity)
        if try git.unpushed() > 0 { try git.push() }
        if let head = git.commitID("HEAD") { markSynced(head, in: mirror) }
        return commit != nil
    }

    /// The remote's latest playbook and the commit it's from, with the mirror moved to match.
    /// The caller saves it as this Mac's playbook, then calls `markSynced`.
    static func takeRemoteCopy(remote: String, account: String?, mirror: URL? = nil) throws -> (playbook: Playbook, commit: String) {
        let mirror = mirror ?? Self.mirror(for: remote)
        let existed = FileManager.default.fileExists(atPath: mirror.appendingPathComponent(".git").path)
        let git = try GitMirror(directory: mirror, remote: remote, login: account)
        try git.prepare()
        _ = syncedCommit(in: mirror, existed: existed, git: git)
        let fetch = try git.git(["fetch", "--quiet", "origin"], timeout: 600, allowFailure: true)
        guard fetch.status == 0 else {
            throw PlaybookError(message: "Couldn't fetch \(remote): \((fetch.errors + fetch.output).trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        guard let head = git.commitID("refs/remotes/origin/main"), let theirs = playbook(at: "refs/remotes/origin/main", git: git), !theirs.isEmpty else {
            throw PlaybookError(message: "The repo has no playbook in it yet.")
        }
        try git.git(["checkout", "--quiet", "--force", "-B", "main", "refs/remotes/origin/main"])
        return (theirs, head)
    }

    /// Records the commit this Mac's playbook now matches, so a later push knows what it has seen.
    static func markSynced(_ commit: String, in mirror: URL) {
        try? commit.write(to: syncedURL(in: mirror), atomically: true, encoding: .utf8)
    }

    /// "12 libraries, 4 stack answers, saved 3 days ago": enough to tell two playbooks apart.
    static func summary(of playbook: Playbook, now: Date = .now) -> String {
        let answered = playbook.stack.values.filter { !$0.isEmpty }.count
        var parts = ["\(playbook.libraries.count) librar\(playbook.libraries.count == 1 ? "y" : "ies")", "\(answered) stack answer\(answered == 1 ? "" : "s")"]
        if let saved = playbook.updatedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            parts.append("saved \(formatter.localizedString(for: saved, relativeTo: now))")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: What this Mac has seen

    private static func syncedURL(in mirror: URL) -> URL { mirror.appendingPathComponent(".git/graphitree-synced") }

    /// The commit this Mac last pushed or took in, or nil when it never has. A mirror from before
    /// this was recorded counts its own last commit, which is what that version had pushed.
    private static func syncedCommit(in mirror: URL, existed: Bool, git: GitMirror) -> String? {
        if let text = try? String(contentsOf: syncedURL(in: mirror), encoding: .utf8) {
            let commit = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return commit.isEmpty ? nil : commit
        }
        let commit = existed ? git.commitID("HEAD") : nil
        // Written now, so a stop below still stops next time.
        markSynced(commit ?? "", in: mirror)
        return commit
    }

    /// The remote's playbook when it has commits this Mac hasn't seen and a playbook worth keeping.
    private static func unseenCopy(git: GitMirror, synced: String?) throws -> Playbook? {
        guard let head = git.commitID("refs/remotes/origin/main") else { return nil }
        if let synced, head == synced || git.isAncestor(head, of: synced) { return nil }
        guard let theirs = playbook(at: "refs/remotes/origin/main", git: git), !theirs.isEmpty else { return nil }
        return theirs
    }

    private static func playbook(at revision: String, git: GitMirror) -> Playbook? {
        guard let shown = try? git.git(["show", "\(revision):\(PlaybookFile.jsonName)"], allowFailure: true), shown.status == 0 else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Playbook.self, from: Data(shown.output.utf8))
    }

    /// The same playbook, whenever it was saved.
    private static func sameContent(_ a: Playbook, _ b: Playbook) -> Bool {
        var a = a, b = b
        a.updatedAt = nil
        b.updatedAt = nil
        return a == b
    }
}

extension GitMirror {
    func commitID(_ revision: String) -> String? {
        guard let result = try? git(["rev-parse", "--verify", "--quiet", revision + "^{commit}"], allowFailure: true), result.status == 0 else { return nil }
        let id = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? nil : id
    }

    func isAncestor(_ ancestor: String, of descendant: String) -> Bool {
        (try? git(["merge-base", "--is-ancestor", ancestor, descendant], allowFailure: true))?.status == 0
    }
}

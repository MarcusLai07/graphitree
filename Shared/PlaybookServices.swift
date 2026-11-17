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

/// A copy of the playbook in its own git repo, pushed to a private GitHub repo. It's separate
/// from graphify-out, which has its own history and holds the large graph.
enum PlaybookBackup {
    static let files = [PlaybookFile.jsonName, PlaybookFile.markdownName]

    static var mirror: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Graphitree/Playbook Backup", isDirectory: true)
    }

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
    @discardableResult
    static func backUp(from directory: URL, to mirror: URL = mirror, remote: String, account: String?, identity: GitIdentity? = nil, now: Date = .now) throws -> Bool {
        let git = try GitMirror(directory: mirror, remote: remote, login: account)
        try git.prepare()
        // Takes in anything pushed from another Mac first, and never overwrites it.
        try git.catchUp()
        var contents: [String: Data] = [:]
        for name in files {
            if let data = try? Data(contentsOf: directory.appendingPathComponent(name)) { contents[name] = data }
        }
        // Only the playbook's files: anything else that crept into the copy goes.
        try git.replaceContents(with: contents)
        let stamp = ISO8601DateFormatter.string(from: now, timeZone: .current, formatOptions: [.withFullDate, .withTime, .withColonSeparatorInTime])
        let commit = try git.commit(message: "Playbook backup \(stamp)", identity: identity)
        if try git.unpushed() > 0 { try git.push() }
        return commit != nil
    }
}

import Foundation

// Keeping the graph fresh without surprises: what a docs pass would cost before it runs, a log
// of what each pass really cost so the estimate improves, schedules for quiet rebuilds, which
// file changes matter, and a background job for when Graphitree is closed.

// MARK: - What a docs pass would read

/// One file a docs pass would send to the model.
struct PendingDoc: Codable, Hashable, Sendable {
    let path: String
    /// graphify's kind: document, paper or image.
    let kind: String
    /// graphify's own token estimate for the file.
    let tokens: Int
}

/// What `graphify extract` would send right now, worked out by graphify's own code.
struct DocsEstimate: Codable, Equatable, Sendable {
    var files: [PendingDoc] = []
    /// Changed docs graphify already has answers for in its cache, so they cost nothing.
    var cached = 0
    /// Changed code files, which graphify reads itself for free.
    var code = 0
    /// How many model calls graphify would make.
    var chunks = 0

    var contentTokens: Int { files.reduce(0) { $0 + $1.tokens } }
    var isEmpty: Bool { files.isEmpty }

    /// The most expensive folders first, such as `personal/odyssey: 120 files`.
    func byProject(root: String, scheme: ProjectScheme) -> [(project: String, files: Int, tokens: Int)] {
        let prefix = root.hasSuffix("/") ? root : root + "/"
        var totals: [String: (Int, Int)] = [:]
        for file in files {
            let relative = file.path.hasPrefix(prefix) ? String(file.path.dropFirst(prefix.count)) : file.path
            let project = scheme.project(of: relative)
            let current = totals[project] ?? (0, 0)
            totals[project] = (current.0 + 1, current.1 + file.tokens)
        }
        return totals.map { (project: $0.key, files: $0.value.0, tokens: $0.value.1) }
            .sorted { $0.tokens == $1.tokens ? $0.project < $1.project : $0.tokens > $1.tokens }
    }
}

enum DocsEstimator {
    /// Runs inside graphify's own Python, so the files, cache hits and chunks match what
    /// `graphify extract` would do. Read-only, apart from graphify's own stat cache.
    static let probe = """
    import json, os, sys, math
    from pathlib import Path
    root = Path(sys.argv[1]); out = Path(sys.argv[2])
    from graphify.detect import detect_incremental
    r = detect_incremental(root, str(out / "manifest.json"), kind="semantic")
    new = r.get("new_files", {})
    pending = [(k, p) for k in ("document", "paper", "image") for p in new.get(k, [])]
    paths = [p for _, p in pending]
    uncached = set(paths)
    if paths:
        try:
            from graphify.cache import check_semantic_cache
            try:
                from graphify.llm import _extraction_system
                prompt = _extraction_system(deep=False)
            except Exception:
                prompt = None
            uncached = set(check_semantic_cache(paths, root=root, cache_root=root, mode=None, prompt=prompt)[3])
        except Exception:
            pass
    def estimate(p):
        try:
            from graphify.llm import _estimate_file_tokens
            return int(_estimate_file_tokens(Path(p)))
        except Exception:
            try:
                return os.path.getsize(p) // 4
            except OSError:
                return 0
    files = [{"path": p, "kind": k, "tokens": estimate(p)} for k, p in pending if p in uncached]
    chunks = 0
    if files:
        try:
            from graphify.llm import _pack_chunks_by_tokens, expand_oversized_files, _FILE_CHAR_CAP
            units = expand_oversized_files([Path(f["path"]) for f in files], _FILE_CHAR_CAP)
            chunks = len(_pack_chunks_by_tokens(units, token_budget=60000))
        except Exception:
            chunks = max(1, math.ceil(sum(f["tokens"] for f in files) / 60000))
    print(json.dumps({"files": files, "cached": len(paths) - len(uncached), "code": len(new.get("code", [])), "chunks": chunks}))
    """

    static func run(python: String, root: String, outDirectory: URL) throws -> DocsEstimate {
        let result = try ProcessRunner.run(python, ["-I", "-c", probe, root, outDirectory.path], timeout: 300)
        guard result.status == 0, let line = result.output.split(separator: "\n").last(where: { $0.hasPrefix("{") }) else {
            let detail = result.errors.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").last.map(String.init) ?? "exit \(result.status)"
            throw PlaybookError(message: "Couldn't count the docs: \(detail)")
        }
        return try JSONDecoder().decode(DocsEstimate.self, from: Data(line.utf8))
    }
}

/// What a pass is likely to cost and take.
struct DocsCost: Equatable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let minutes: Int

    var totalTokens: Int { inputTokens + outputTokens }

    /// Claude Code brings its own context to every call. API backends send little besides the docs.
    static func overheadPerChunk(backend: String) -> Int {
        backend == "claude-cli" ? 45_000 : 3_000
    }

    /// graphify runs Claude Code calls one at a time, since parallel CLI sessions trip over each
    /// other. API backends run up to four at once.
    static func callsAtOnce(backend: String) -> Int {
        backend == "claude-cli" ? 1 : 4
    }

    /// Minutes per call until a pass has been timed. Claude Code runs the person's default model
    /// and opens each image with a tool call, so a call took over 10 minutes on 2026-11-18.
    static func minutesPerCall(backend: String) -> Int {
        backend == "claude-cli" ? 8 : 3
    }

    /// The estimate, scaled by how far past estimates were off for this backend.
    static func estimate(_ estimate: DocsEstimate, backend: String, history: [DocsRun] = []) -> DocsCost {
        guard !estimate.isEmpty else { return DocsCost(inputTokens: 0, outputTokens: 0, minutes: 0) }
        let rawInput = estimate.contentTokens + estimate.chunks * overheadPerChunk(backend: backend)
        let ratios = history.filter { $0.backend == backend && $0.estimatedInput > 0 }.compactMap { run in
            run.actualInput.map { Double($0) / Double(run.estimatedInput) }
        }.suffix(5)
        let scale = ratios.isEmpty ? 1 : min(max(ratios.sorted()[ratios.count / 2], 0.25), 4)
        let input = Int(Double(rawInput) * scale)
        // Replies run at about a quarter of what's read, going by the 2026-11-12 pass.
        let output = Int(Double(estimate.contentTokens) * 0.28 * scale)
        // Finished passes (graphify printed its token count) set the pace per file. Before any,
        // calls run in rounds of `callsAtOnce`, plus reading time.
        let paces = history.filter { $0.backend == backend && $0.actualInput != nil && $0.files > 0 && $0.seconds > 0 }
            .suffix(5).map { Double($0.seconds) / Double($0.files) }
        let minutes: Int
        if paces.isEmpty {
            let rounds = Int(ceil(Double(estimate.chunks) / Double(callsAtOnce(backend: backend))))
            minutes = max(1, rounds * minutesPerCall(backend: backend) + estimate.contentTokens / 20_000)
        } else {
            let secondsPerFile = paces.sorted()[paces.count / 2]
            minutes = max(1, Int(ceil(secondsPerFile * Double(estimate.files.count) / 60)))
        }
        return DocsCost(inputTokens: input, outputTokens: output, minutes: minutes)
    }

    /// "40 minutes", or "6.5 hours" once it's past an hour and a half.
    var duration: String {
        if minutes < 90 { return "\(minutes) minute\(minutes == 1 ? "" : "s")" }
        let hours = (Double(minutes) / 30).rounded() / 2
        return hours == hours.rounded() ? "\(Int(hours)) hours" : String(format: "%.1f hours", hours)
    }
}

// MARK: - What passes really cost

/// One docs pass: what Graphitree expected and what graphify reported.
struct DocsRun: Codable, Equatable, Sendable {
    let date: Date
    let backend: String
    let files: Int
    let estimatedInput: Int
    var actualInput: Int?
    var actualOutput: Int?
    var seconds: Int
}

enum DocsRunLog {
    static var url: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Graphitree/docs-runs.json")
    }

    static func load(from url: URL = url) -> [DocsRun] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([DocsRun].self, from: data)) ?? []
    }

    static func append(_ run: DocsRun, to url: URL = url) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(Array((load(from: url) + [run]).suffix(50))) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// graphify's own count, from a line like `[graphify extract] tokens: 917,683 in / 256,092 out`.
    static func reportedTokens(in log: String) -> (input: Int, output: Int)? {
        guard let range = log.range(of: #"tokens: ([\d,]+) in / ([\d,]+) out"#, options: [.regularExpression, .backwards]) else { return nil }
        let numbers = log[range].split(whereSeparator: { !$0.isNumber && $0 != "," }).map { Int($0.replacingOccurrences(of: ",", with: "")) ?? 0 }
        guard numbers.count >= 2 else { return nil }
        return (numbers[0], numbers[1])
    }
}

// MARK: - Schedules

enum DocsSchedule: String, Codable, CaseIterable, Identifiable, Sendable {
    case never, nightly, weekly

    var id: String { rawValue }
    var title: String {
        switch self {
        case .never: return "Only when I ask"
        case .nightly: return "Every night"
        case .weekly: return "Once a week"
        }
    }
}

/// How Graphitree keeps the graph fresh on its own. Saved in defaults.
struct FreshnessSettings: Codable, Equatable, Sendable {
    /// Rebuild code quietly when files change, while Graphitree is open. Free.
    var updatesCodeOnChange = false
    /// A background job that rebuilds code every few hours, even with Graphitree closed. Free.
    var updatesWhenClosed = false
    /// The root the background job rebuilds, set when it's switched on. It stays put when another
    /// graph is opened.
    var updateRoot: String?
    var docs: DocsSchedule = .never
    /// Hour of the day for scheduled docs passes, 0 to 23.
    var hour = 2
    /// For weekly passes: 1 is Sunday, as in `Calendar`.
    var weekday = 1
    /// A scheduled pass that would use more than this waits for the person instead.
    var askAboveTokens = 150_000
    var lastDocsPass: Date?
    /// Re-research the playbook's libraries once a month, while Graphitree is open.
    var checksLibrariesMonthly = false
    var lastLibraryCheck: Date?

    static let defaultsKey = "freshness"

    init(updatesCodeOnChange: Bool = false, updatesWhenClosed: Bool = false, docs: DocsSchedule = .never, hour: Int = 2, weekday: Int = 1,
         askAboveTokens: Int = 150_000, lastDocsPass: Date? = nil, checksLibrariesMonthly: Bool = false, lastLibraryCheck: Date? = nil) {
        self.updatesCodeOnChange = updatesCodeOnChange
        self.updatesWhenClosed = updatesWhenClosed
        self.docs = docs
        self.hour = hour
        self.weekday = weekday
        self.askAboveTokens = askAboveTokens
        self.lastDocsPass = lastDocsPass
        self.checksLibrariesMonthly = checksLibrariesMonthly
        self.lastLibraryCheck = lastLibraryCheck
    }

    /// Settings saved by an older version lack newer keys; those take their defaults.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        updatesCodeOnChange = try values.decodeIfPresent(Bool.self, forKey: .updatesCodeOnChange) ?? updatesCodeOnChange
        updatesWhenClosed = try values.decodeIfPresent(Bool.self, forKey: .updatesWhenClosed) ?? updatesWhenClosed
        updateRoot = try values.decodeIfPresent(String.self, forKey: .updateRoot)
        docs = try values.decodeIfPresent(DocsSchedule.self, forKey: .docs) ?? docs
        hour = try values.decodeIfPresent(Int.self, forKey: .hour) ?? hour
        weekday = try values.decodeIfPresent(Int.self, forKey: .weekday) ?? weekday
        askAboveTokens = try values.decodeIfPresent(Int.self, forKey: .askAboveTokens) ?? askAboveTokens
        lastDocsPass = try values.decodeIfPresent(Date.self, forKey: .lastDocsPass)
        checksLibrariesMonthly = try values.decodeIfPresent(Bool.self, forKey: .checksLibrariesMonthly) ?? checksLibrariesMonthly
        lastLibraryCheck = try values.decodeIfPresent(Date.self, forKey: .lastLibraryCheck)
    }

    /// The monthly library check is due a month after the last one.
    func isLibraryCheckDue(now: Date) -> Bool {
        checksLibrariesMonthly && now.timeIntervalSince(lastLibraryCheck ?? .distantPast) > 30 * 24 * 3600
    }

    static func load(_ defaults: UserDefaults = .standard) -> FreshnessSettings {
        guard let data = defaults.data(forKey: defaultsKey) else { return FreshnessSettings() }
        return (try? JSONDecoder().decode(FreshnessSettings.self, from: data)) ?? FreshnessSettings()
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.defaultsKey) }
    }

    /// The most recent time a scheduled pass should have started, at or before `now`.
    func lastSlot(before now: Date, calendar: Calendar = .current) -> Date? {
        guard docs != .never else { return nil }
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        if docs == .weekly { components.weekday = weekday }
        return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime, direction: .backward)
    }

    /// A scheduled pass is due when its last slot passed and no pass has run since. A slot missed
    /// while the Mac slept or Graphitree was closed runs at the next chance.
    func isDocsPassDue(now: Date, calendar: Calendar = .current) -> Bool {
        guard let slot = lastSlot(before: now, calendar: calendar) else { return false }
        return (lastDocsPass ?? .distantPast) < slot
    }
}

// MARK: - Which changes matter

enum ChangeFilter {
    /// Folders whose changes never change the graph: graphify's output, git, packages, builds.
    static let ignoredParts: Set<String> = [
        "graphify-out", ".git", "node_modules", "build", "dist", ".next", ".nuxt", "build.noindex",
        "DerivedData", ".build", ".venv", "venv", "__pycache__", "coverage", ".turbo", ".cache",
    ]

    /// Whether a changed path under the root could change the graph.
    static func matters(_ path: String, root: String) -> Bool {
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard path.hasPrefix(prefix) else { return false }
        let parts = path.dropFirst(prefix.count).split(separator: "/").map(String.init)
        guard let name = parts.last, !parts.isEmpty else { return false }
        if parts.contains(where: { ignoredParts.contains($0) }) { return false }
        if parts.dropLast().contains(where: { $0.hasPrefix(".") }) { return false }
        return !name.hasPrefix(".") && !name.hasSuffix("~") && !name.hasSuffix(".swp")
    }
}

// MARK: - When Graphitree is closed

/// A LaunchAgent that runs every few hours, even with Graphitree closed: `graphify update` when
/// "update when closed" is on, then any backups that are due. It skips a run while another graphify
/// is busy, so it never races Graphitree's own rebuild.
enum UpdateAgent {
    static let label = "com.marcuslai.Graphitree.update"
    static let interval = 4 * 3600

    static func plistURL(home: String) -> URL {
        URL(fileURLWithPath: home).appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func logPath(home: String) -> String { home + "/Library/Logs/Graphitree-update.log" }

    /// What the job runs. With Graphitree's command line it runs that directly, so macOS asks for
    /// Documents access for Graphitree's command rather than for the shell. `root` is set when it
    /// updates the graph. Without the command line it can only update, through the shell.
    static func arguments(cli: String?, graphify: String?, root: String?) -> [String]? {
        if let cli { return [cli, "background"] + (root.map { ["--update", $0] } ?? []) }
        guard let graphify, let root else { return nil }
        return ["/bin/sh", "-c", "pgrep -f 'graphify (update|extract|label)' >/dev/null || \(shellQuoted(graphify)) update \(shellQuoted(root))"]
    }

    static func plist(arguments: [String], home: String) -> String {
        func escaped(_ text: String) -> String {
            text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
        \(arguments.map { "        <string>\(escaped($0))</string>" }.joined(separator: "\n"))
            </array>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>\(escaped(home))/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
            </dict>
            <key>StartInterval</key>
            <integer>\(interval)</integer>
            <key>LowPriorityIO</key>
            <true/>
            <key>Nice</key>
            <integer>10</integer>
            <key>StandardOutPath</key>
            <string>\(escaped(logPath(home: home)))</string>
            <key>StandardErrorPath</key>
            <string>\(escaped(logPath(home: home)))</string>
        </dict>
        </plist>

        """
    }

    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func isInstalled(home: String) -> Bool {
        FileManager.default.fileExists(atPath: plistURL(home: home).path)
    }

    /// The root an installed job updates: for jobs written before the root was saved in settings.
    static func installedRoot(home: String) -> String? {
        guard let arguments = installedArguments(home: home) else { return nil }
        if let index = arguments.firstIndex(of: "--update"), index + 1 < arguments.count { return arguments[index + 1] }
        guard let command = arguments.last, let range = command.range(of: #" update '([^']*)'"#, options: .regularExpression) else { return nil }
        return String(command[range].dropFirst(" update '".count).dropLast())
    }

    /// What the installed job runs, or nil when there's no job.
    static func installedArguments(home: String) -> [String]? {
        guard let data = FileManager.default.contents(atPath: plistURL(home: home).path),
              let job = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return nil }
        return job["ProgramArguments"] as? [String]
    }

    /// Installs, updates or removes the job so it runs `arguments`. Leaves a job that already
    /// matches alone. Returns an error message or nil.
    @discardableResult
    static func sync(arguments: [String]?, home: String) -> String? {
        guard let arguments else {
            if isInstalled(home: home) { uninstall(home: home) }
            return nil
        }
        let url = plistURL(home: home)
        let text = plist(arguments: arguments, home: home)
        if (try? String(contentsOf: url, encoding: .utf8)) == text { return nil }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return error.localizedDescription
        }
        let domain = "gui/\(getuid())"
        _ = try? ProcessRunner.run("/bin/launchctl", ["bootout", "\(domain)/\(label)"], timeout: 20)
        guard let result = try? ProcessRunner.run("/bin/launchctl", ["bootstrap", domain, url.path], timeout: 20) else {
            return "launchctl couldn't be run."
        }
        return result.status == 0 ? nil : result.errors.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func uninstall(home: String) {
        _ = try? ProcessRunner.run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(label)"], timeout: 20)
        try? FileManager.default.removeItem(at: plistURL(home: home))
    }
}

import Foundation

/// What a scan of Codex's session logs found.
struct CodexScan {
    /// Every model call, as the Usage page counts Claude Code's.
    var samples: [TokenSample] = []
    /// Session id → its first prompt, which stands for its title: Codex doesn't name sessions.
    var titles: [String: String] = [:]
    /// Each reading of the plan's limits that Codex logged, oldest first.
    var limits: [UsageSample] = []
    /// The plan, as the latest reading names it ("Plus", "Pro").
    var plan: String?
    /// Logs Codex compressed (`.jsonl.zst`) that couldn't be read, because zstd isn't installed.
    var unreadCompressed = 0

    /// The latest reading as a snapshot of the two windows. Nil when Codex never logged one, as
    /// with an API key, which has no plan limits.
    var latest: UsageSnapshot? {
        guard let last = limits.last else { return nil }
        return UsageSnapshot(
            fetchedAt: last.ts,
            session: last.session.map { UsageWindow(utilization: $0, resetsAt: last.sessionReset) },
            weekly: last.weekly.map { UsageWindow(utilization: $0, resetsAt: last.weeklyReset) },
            weeklyOpus: nil, weeklySonnet: nil, extra: nil
        )
    }
}

/// Codex's session logs ("rollouts"): `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`, and
/// `archived_sessions`. Each line is `{"timestamp", "type", "payload"}`. The format is Codex's
/// own (openai/codex, `codex-rs/protocol` and `codex-rs/history`), read here without Codex:
///
/// - `session_meta`: the session's id, root session id (a subagent's differs), folder and which
///   app started it.
/// - `turn_context`: each turn's model and folder.
/// - `token_usage_record` (newer Codex): one per API response, with a unique response id.
/// - `event_msg` `token_count`: the session's running totals, the last response's usage, and the
///   plan's limits (`rate_limits.primary` and `.secondary`). Older Codex only writes these, and
///   sometimes twice for one response.
/// - `event_msg` `user_message`: a prompt.
///
/// Input counts include cached input, and output includes reasoning, as OpenAI reports them.
enum CodexSessions {
    /// Codex's folder: `~/.codex`, or `-codexHome <path>` at launch, for screenshots.
    static var home: URL {
        if let override = UserDefaults.standard.string(forKey: "codexHome"), !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    /// Whether Codex has left any sessions here.
    static func hasSessions(home: URL = home) -> Bool {
        ["sessions", "archived_sessions"].contains {
            FileManager.default.fileExists(atPath: home.appendingPathComponent($0).path)
        }
    }

    // MARK: Scanning

    /// Reads every log changed since `since`. Files are read oldest first and a call is counted
    /// once, where it first appears: a forked session repeats its parent's lines.
    static func scan(home: URL = home, since: Date) -> CodexScan {
        let roots = ["sessions", "archived_sessions"].map { home.appendingPathComponent($0) }
        var files = ClaudeTranscripts.files(under: roots, modifiedSince: since)
            .filter { $0.url.lastPathComponent.hasPrefix("rollout-") }
        files += compressedFiles(under: roots, modifiedSince: since)
        files.sort { $0.modified != $1.modified ? $0.modified < $1.modified : $0.url.path < $1.url.path }

        var scan = CodexScan()
        var seen = Set<String>()
        for file in files {
            let data: Data?
            if file.url.pathExtension == "zst" {
                data = decompress(file.url)
                if data == nil { scan.unreadCompressed += 1; continue }
            } else {
                data = try? Data(contentsOf: file.url, options: .mappedIfSafe)
            }
            guard let data else { continue }
            let parsed = parse(data, fileName: file.url.lastPathComponent, since: since)
            for sample in parsed.samples where seen.insert(sample.id).inserted {
                scan.samples.append(sample)
            }
            scan.limits += parsed.limits
            scan.titles.merge(parsed.titles) { first, _ in first }
            // Files go oldest first, so the plan ends up as the latest log names it.
            if let plan = parsed.plan { scan.plan = plan }
        }
        scan.samples.sort { $0.ts < $1.ts }
        scan.limits.sort { $0.ts < $1.ts }
        return scan
    }

    /// Whether Codex has written a log since `since`. Its limits change only when it runs, so the
    /// menu bar reads them again only then.
    static func hasChanges(home: URL = home, since: Date) -> Bool {
        let roots = ["sessions", "archived_sessions"].map { home.appendingPathComponent($0) }
        return ClaudeTranscripts.files(under: roots, modifiedSince: since).contains { $0.url.lastPathComponent.hasPrefix("rollout-") }
            || !compressedFiles(under: roots, modifiedSince: since).isEmpty
    }

    /// `.jsonl.zst` logs: Codex can compress logs a week old (an optional feature, off by default).
    private static func compressedFiles(under roots: [URL], modifiedSince since: Date) -> [ClaudeTranscripts.File] {
        var files: [ClaudeTranscripts.File] = []
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { continue }
            for case let url as URL in enumerator where url.lastPathComponent.hasPrefix("rollout-") && url.path.hasSuffix(".jsonl.zst") {
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                      let modified = values.contentModificationDate, modified >= since else { continue }
                files.append(ClaudeTranscripts.File(url: url, modified: modified, size: values.fileSize ?? 0))
            }
        }
        return files
    }

    /// macOS can't read zstd, so this uses the `zstd` command when it's installed (Homebrew).
    private static func decompress(_ url: URL) -> Data? {
        let candidates = ["/opt/homebrew/bin/zstd", "/usr/local/bin/zstd"]
        guard let tool = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = ["-dc", "--", url.path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }

    // MARK: Parsing one log

    struct Parsed {
        var samples: [TokenSample] = []
        var limits: [UsageSample] = []
        var titles: [String: String] = [:]
        var plan: String?
    }

    /// The calls, limit readings and title in one log's lines.
    static func parse(_ data: Data, fileName: String, since: Date) -> Parsed {
        var result = Parsed()
        let decoder = JSONDecoder()
        // Newer Codex writes one record per response; then `token_count` is only read for limits.
        let hasRecords = data.withUnsafeBytes { buffer in
            buffer.baseAddress.map { ClaudeTranscripts.contains($0, buffer.count, Tag.record) } ?? false
        }

        var session: String?
        var thread: String?
        var folder: String?
        var app = "codex"
        var isSubagent = false
        var model = ""
        var effort: String?
        var modelByTurn: [String: (model: String, effort: String?)] = [:]
        var lastPrompt: Date?
        var lastReply: Date?
        var lastTotal: Int?

        func add(key: String, at ts: Date, usage: Usage, model name: String, effort: String?) {
            guard ts >= since else { return }
            let input = max(0, (usage.input_tokens ?? 0) - (usage.cached_input_tokens ?? 0))
            let cached = max(0, usage.cached_input_tokens ?? 0)
            let output = max(0, usage.output_tokens ?? 0)
            guard input + cached + output > 0 else { return }
            var duration: Int?
            if let asked = [lastPrompt, lastReply].compactMap({ $0 }).max(), ts > asked {
                let ms = Int(ts.timeIntervalSince(asked) * 1000)
                if ms < 2 * 3600 * 1000 { duration = ms }
            }
            let display = name.isEmpty ? "" : displayName(for: name)
            let root = session ?? thread ?? fileName
            result.samples.append(TokenSample(
                id: key, ts: ts, model: display, input: input, output: output,
                cacheRead: cached, cacheWrite: 0, cacheWrite1h: 0,
                thinking: max(0, usage.reasoning_output_tokens ?? 0),
                sessionID: root, project: folder, app: app, effort: effort,
                isSidechain: isSubagent, agent: isSubagent ? thread : nil, error: nil,
                durationMs: duration,
                cost: ModelPricing.cost(model: display, input: input, output: output, cacheRead: cached,
                                        cacheWrite: 0, cacheWrite1h: 0)
            ))
            if lastReply.map({ ts > $0 }) ?? true { lastReply = ts }
        }

        ClaudeTranscripts.forEachLine(of: data) { line, length in
            guard ClaudeTranscripts.contains(line, length, Tag.meta) || ClaudeTranscripts.contains(line, length, Tag.turn)
                    || ClaudeTranscripts.contains(line, length, Tag.count) || ClaudeTranscripts.contains(line, length, Tag.record)
                    || ClaudeTranscripts.contains(line, length, Tag.prompt),
                  let entry = try? decoder.decode(Line.self, from: Data(bytes: line, count: length)),
                  let payload = entry.payload,
                  let stamp = entry.timestamp, let ts = date(stamp) else { return true }

            switch entry.type {
            case "session_meta":
                // A forked log can repeat its parent's; the first is this session's own.
                guard thread == nil else { return true }
                thread = payload.id
                session = payload.session_id ?? payload.id
                folder = payload.cwd
                isSubagent = (payload.session_id.map { $0 != payload.id } ?? false)
                    || payload.source?.value == "subagent" || payload.thread_source?.value == "subagent"
                app = appKey(originator: payload.originator, source: payload.source?.value)
            case "turn_context":
                if let name = payload.model, !name.isEmpty { model = name }
                effort = payload.effort?.value ?? effort
                if let cwd = payload.cwd, folder == nil { folder = cwd }
                if let turn = payload.turn_id { modelByTurn[turn] = (model, effort) }
            case "token_usage_record":
                guard let usage = payload.usage, let response = payload.response_id else { return true }
                let turn = payload.turn_id.flatMap { modelByTurn[$0] }
                add(key: "codex:" + response, at: ts, usage: usage, model: turn?.model ?? model, effort: turn?.effort ?? effort)
            case "event_msg":
                switch payload.type {
                case "user_message":
                    lastPrompt = ts
                    if let text = payload.message?.value, let title = title(from: text), let id = session ?? thread,
                       result.titles[id] == nil {
                        result.titles[id] = title
                    }
                case "token_count":
                    if let limits = payload.rate_limits, isMain(limits), ts >= since,
                       let reading = reading(limits, at: ts) {
                        result.limits.append(reading)
                        if let plan = limits.plan_type?.value { result.plan = planName(plan) }
                    }
                    // Older Codex: the last response's usage, once per new total. The same total
                    // again is the same response logged twice.
                    guard !hasRecords, let info = payload.info, let last = info.last_token_usage else { return true }
                    let total = info.total_token_usage?.total_tokens ?? -1
                    guard total != lastTotal else { return true }
                    lastTotal = total
                    add(key: "codex:\(stamp)|\(total)", at: ts, usage: last, model: model, effort: effort)
                default:
                    break
                }
            default:
                break
            }
            return true
        }
        return result
    }

    // MARK: Limits

    /// The plan's own limit: Codex names it "codex", or leaves it unnamed. Other ids are limits of
    /// single models, which the page doesn't show yet.
    private static func isMain(_ limits: Limits) -> Bool {
        guard let id = limits.limit_id?.value else { return true }
        return id.caseInsensitiveCompare("codex") == .orderedSame
    }

    /// One reading: the 5-hour window as the session limit and the weekly one as weekly. Windows are
    /// placed by their length, falling back to primary and secondary.
    private static func reading(_ limits: Limits, at ts: Date) -> UsageSample? {
        var session: (Double, Date?)?
        var weekly: (Double, Date?)?
        for (window, isSecondary) in [(limits.primary, false), (limits.secondary, true)] {
            guard let window, let used = window.used_percent else { continue }
            let reset = window.resets_at.map { Date(timeIntervalSince1970: $0) }
                ?? window.resets_in_seconds.map { ts.addingTimeInterval($0) }
            let minutes = window.window_minutes ?? (isSecondary ? 10080 : 300)
            if minutes >= 24 * 60 { weekly = (used, reset) } else { session = (used, reset) }
        }
        guard session != nil || weekly != nil else { return nil }
        return UsageSample(ts: ts, session: session?.0, weekly: weekly?.0, opus: nil, sonnet: nil, fable: nil,
                           sessionReset: session?.1, weeklyReset: weekly?.1, fableReset: nil, opusReset: nil, sonnetReset: nil)
    }

    /// "plus" → "Plus", "business" → "Business".
    static func planName(_ raw: String) -> String {
        raw.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    // MARK: Names

    /// Which app started a session, as the Usage page names apps: from Codex's `originator`
    /// ("codex_cli_rs", "codex_vscode"…), else its `source` ("cli", "vscode", "exec"…).
    static func appKey(originator: String?, source: String?) -> String {
        let name = (originator ?? "").lowercased()
        if name.contains("vscode") { return "codex-vscode" }
        if name.contains("exec") || source == "exec" { return "codex-exec" }
        if name.contains("cli") || source == "cli" { return "codex-cli" }
        if name.contains("desktop") || name.contains("app") { return "codex-app" }
        if source == "vscode" { return "codex-vscode" }
        if source == "mcp" { return "codex-mcp" }
        return "codex"
    }

    /// "gpt-6.1-sol" → "GPT-6.1 Sol", "gpt-5.3-codex" → "GPT-5.3 Codex", "gpt-5.5" → "GPT-5.5".
    static func displayName(for slug: String) -> String {
        var parts = slug.split(separator: "-").map(String.init)
        guard !parts.isEmpty else { return slug }
        var name = ""
        if parts[0].lowercased() == "gpt", parts.count > 1, parts[1].first?.isNumber == true {
            name = "GPT-" + parts[1]
            parts.removeFirst(2)
        }
        let words = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return ([name].filter { !$0.isEmpty } + words).joined(separator: " ")
    }

    /// A prompt's first line, short enough for a list, standing in for the session's title.
    private static func title(from text: String) -> String? {
        let line = text.split(whereSeparator: \.isNewline).lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("<") }
        guard let line else { return nil }
        return line.count > 80 ? String(line.prefix(79)) + "…" : line
    }

    // MARK: Lines

    private enum Tag {
        static let meta = Array("\"session_meta\"".utf8)
        static let turn = Array("\"turn_context\"".utf8)
        static let count = Array("\"token_count\"".utf8)
        static let record = Array("\"token_usage_record\"".utf8)
        static let prompt = Array("\"user_message\"".utf8)
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let iso = ISO8601DateFormatter()

    private static func date(_ string: String) -> Date? {
        isoFractional.date(from: string) ?? iso.date(from: string)
    }

    /// A value that may arrive in another shape, such as `source`, which is a string for most
    /// sessions and an object (`{"subagent": …}`) for others. An object gives its first key.
    struct Loose: Decodable {
        let value: String?
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                value = string
            } else if let object = try? container.decode([String: AnyDecodable].self) {
                value = object.keys.sorted().first
            } else {
                value = nil
            }
        }
    }

    struct AnyDecodable: Decodable {
        init(from decoder: Decoder) throws {}
    }

    struct Usage: Decodable {
        let input_tokens: Int?
        let cached_input_tokens: Int?
        let output_tokens: Int?
        let reasoning_output_tokens: Int?
        let total_tokens: Int?
    }

    struct Window: Decodable {
        let used_percent: Double?
        let window_minutes: Int?
        let resets_at: Double?
        /// Older Codex gave the time left instead of the moment.
        let resets_in_seconds: Double?
    }

    struct Limits: Decodable {
        let limit_id: Loose?
        let primary: Window?
        let secondary: Window?
        let plan_type: Loose?
    }

    struct Info: Decodable {
        let total_token_usage: Usage?
        let last_token_usage: Usage?
    }

    /// Every field any of the line types read, all optional.
    struct Payload: Decodable {
        let type: String?
        let id: String?
        let session_id: String?
        let cwd: String?
        let originator: String?
        let source: Loose?
        let thread_source: Loose?
        let turn_id: String?
        let model: String?
        let effort: Loose?
        let info: Info?
        let rate_limits: Limits?
        let message: Loose?
        let response_id: String?
        let usage: Usage?
    }

    struct Line: Decodable {
        let timestamp: String?
        let type: String?
        let payload: Payload?
    }
}

import Foundation

/// GitHub Copilot's usage: its plan's premium requests or AI Credits, and Copilot CLI's calls from its session logs in `~/.copilot`.
///
/// **Calls.** Copilot CLI keeps each session in `~/.copilot/session-state/<session id>/events.jsonl`.
/// Each line is an event: `{"type", "id", "timestamp", "parentId", "agentId"?, "ephemeral"?, "data"}`.
/// The format is the Copilot SDK's session events (github/copilot-sdk, `session-events.ts`), read
/// here without Copilot:
///
/// - `session.start`: the session's id (`sessionId`), its model (`selectedModel`) and folder (`context.cwd`).
/// - `session.resume`: the model when a session is picked up again (`selectedModel`).
/// - `session.model_change`: a new model (`newModel`) and reasoning effort.
/// - `user.message`: a prompt (`content`).
/// - `assistant.message`: a reply, with its own `messageId`, the tokens it wrote (`outputTokens`) and,
///   in newer versions, its `model`. A subagent's events carry its `agentId`.
/// - `session.shutdown`: per-model totals (`modelMetrics`). Not read: the replies already count.
///
/// The per-call usage event (`assistant.usage`, with input and cache tokens) is never written to
/// disk, so a call here has its output tokens only, and no cost.
///
/// **Limits.** GitHub's `copilot_internal/user` endpoint, which Copilot's editor extensions read for
/// the plan's allowance. It isn't documented and may change, so every field is optional. The token
/// is the GitHub CLI's (`gh auth token`), which Copilot CLI itself falls back to. Copilot CLI's own
/// sign-in (its Keychain item and `config.json`) is never read.
enum CopilotUsage {
    /// What the Usage page says when the GitHub CLI isn't on this Mac or isn't signed in.
    static let signInHint = "Sign in to the GitHub CLI (gh auth login) to read Copilot's limits."

    static let endpoint = URL(string: "https://api.github.com/copilot_internal/user")!

    // MARK: Logs

    /// Whether the tool has left logs of its calls on this Mac: any session's `events.jsonl`.
    static func hasLogs(home: String) -> Bool {
        let root = sessionsFolder(home: home)
        guard let sessions = try? FileManager.default.contentsOfDirectory(atPath: root.path) else { return false }
        return sessions.contains { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).appendingPathComponent("events.jsonl").path) }
    }

    /// Every model call in the tool's logs since `since`, oldest first. A reply is counted once,
    /// where it first appears.
    static func scan(home: String, since: Date) -> TranscriptScan {
        let files = ClaudeTranscripts.files(under: [sessionsFolder(home: home)], modifiedSince: since)
            .filter { $0.url.lastPathComponent == "events.jsonl" }
            .sorted { $0.modified != $1.modified ? $0.modified < $1.modified : $0.url.path < $1.url.path }

        var scan = TranscriptScan()
        var seen = Set<String>()
        for file in files {
            guard let data = try? Data(contentsOf: file.url, options: .mappedIfSafe) else { continue }
            let folder = file.url.deletingLastPathComponent().lastPathComponent
            let parsed = parse(data, session: folder, since: since)
            for sample in parsed.samples where seen.insert(sample.id).inserted {
                scan.samples.append(sample)
            }
            scan.titles.merge(parsed.titles) { first, _ in first }
        }
        scan.samples.sort { $0.ts < $1.ts }
        return scan
    }

    /// `~/.copilot/session-state`. Copilot CLI's `COPILOT_HOME` isn't followed: an app opened
    /// from Finder doesn't get the shell's variables.
    static func sessionsFolder(home: String) -> URL {
        URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent(".copilot/session-state", isDirectory: true)
    }

    /// The calls and title in one session's `events.jsonl`. `session` is its folder's name, which
    /// is the session's id when the log doesn't say.
    static func parse(_ data: Data, session folder: String, since: Date) -> TranscriptScan {
        var result = TranscriptScan()
        let decoder = JSONDecoder()
        var session = folder
        var project: String?
        var model = ""
        var effort: String?
        var lastPrompt: Date?
        var lastReply: Date?

        ClaudeTranscripts.forEachLine(of: data) { line, length in
            guard Tag.all.contains(where: { ClaudeTranscripts.contains(line, length, $0) }),
                  let event = try? decoder.decode(Event.self, from: Data(bytes: line, count: length)),
                  event.ephemeral != true,
                  let payload = event.data,
                  let stamp = event.timestamp, let ts = date(stamp) else { return true }

            switch event.type {
            case "session.start":
                if let id = payload.sessionId, !id.isEmpty { session = id }
                if let name = payload.selectedModel, !name.isEmpty { model = name }
                if let cwd = payload.context?.cwd, !cwd.isEmpty { project = cwd }
                effort = payload.reasoningEffort?.value ?? effort
            case "session.resume":
                if let name = payload.selectedModel, !name.isEmpty { model = name }
                if let cwd = payload.context?.cwd, !cwd.isEmpty, project == nil { project = cwd }
                effort = payload.reasoningEffort?.value ?? effort
            case "session.model_change":
                if let name = payload.newModel, !name.isEmpty { model = name }
                effort = payload.reasoningEffort?.value
            case "user.message":
                lastPrompt = ts
                if result.titles[session] == nil, let text = payload.content?.value, let title = title(from: text) {
                    result.titles[session] = title
                }
            case "assistant.message":
                guard ts >= since, let key = payload.messageId ?? event.id else { return true }
                let name = payload.model.flatMap { $0.isEmpty ? nil : $0 } ?? model
                var duration: Int?
                if let asked = [lastPrompt, lastReply].compactMap({ $0 }).max(), ts > asked {
                    let ms = Int(ts.timeIntervalSince(asked) * 1000)
                    if ms < 2 * 3600 * 1000 { duration = ms }
                }
                result.samples.append(TokenSample(
                    id: "copilot:" + key, ts: ts, model: name.isEmpty ? "" : displayName(for: name),
                    input: 0, output: max(0, payload.outputTokens?.value ?? 0),
                    cacheRead: 0, cacheWrite: 0, cacheWrite1h: 0, thinking: 0,
                    sessionID: session, project: project, app: "copilot-cli", effort: effort,
                    isSidechain: event.agentId != nil, agent: event.agentId, error: nil,
                    durationMs: duration, cost: nil
                ))
                if lastReply.map({ ts > $0 }) ?? true { lastReply = ts }
            default:
                break
            }
            return true
        }
        return result
    }

    /// "claude-sonnet-4.5" → "Sonnet 4.5", "gpt-5.1-codex" → "GPT-5.1 Codex",
    /// "gemini-3-pro-preview" → "Gemini 3 Pro Preview". Copilot writes Claude's versions with a dot.
    static func displayName(for model: String) -> String {
        let id = model.lowercased()
        if id.hasPrefix("claude-") {
            return TranscriptStats.displayName(for: id.replacingOccurrences(of: ".", with: "-"))
        }
        return CodexSessions.displayName(for: id)
    }

    /// A prompt's first line, short enough for a list, standing in for the session's title.
    private static func title(from text: String) -> String? {
        let line = text.split(whereSeparator: \.isNewline).lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("<") }
        guard let line else { return nil }
        return line.count > 80 ? String(line.prefix(79)) + "…" : line
    }

    // MARK: Limits

    /// The plan's limits now. Never refreshes or rewrites the tool's own sign-in.
    static func limits(home: String) async -> Result<LimitReading, LimitProblem> {
        await limits(gh: ToolLocator.command(["gh"], home: home))
    }

    /// The same, with the GitHub CLI at `gh`, or nil when it isn't on this Mac.
    static func limits(gh: String?, timeout: TimeInterval = 10) async -> Result<LimitReading, LimitProblem> {
        guard let gh, let token = await signInToken(gh: gh, timeout: timeout) else {
            return .failure(.notSignedIn(signInHint))
        }
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        // `token`, the scheme the GitHub CLI itself sends (`gh api`); GitHub's API takes `Bearer`
        // too. No editor headers: Graphitree doesn't pose as VS Code.
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Graphitree", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await urlSession.data(for: request)
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            if let problem = problem(status: status, rateLimitRemaining: http?.value(forHTTPHeaderField: "X-RateLimit-Remaining")) {
                return .failure(problem)
            }
            return reading(from: data, at: Date())
        } catch {
            return .failure(LimitProblem.from(error))
        }
    }

    /// Nothing is cached or kept between readings, and nothing waits for a connection to appear.
    private static let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()

    /// What a failed answer means, or nil for a good one.
    static func problem(status: Int, rateLimitRemaining: String? = nil) -> LimitProblem? {
        switch status {
        case 200..<300:
            return nil
        case 401:
            return .notSignedIn("GitHub turned down the GitHub CLI's sign-in. Sign in again (gh auth login) to read Copilot's limits.")
        case 403 where rateLimitRemaining == "0":
            // GitHub answers a spent rate limit with 403 too.
            return .http(429)
        case 403:
            return .notSignedIn("The GitHub CLI's sign-in can't read Copilot's limits. Sign in again in the browser (gh auth login) to read them.")
        case 404:
            return .noLimits("This GitHub account has no Copilot plan.")
        default:
            return .http(status)
        }
    }

    /// The endpoint's answer as a reading. Each limited quota becomes a window: premium requests,
    /// or AI Credits once the plan is billed by tokens, and Copilot Free's chat and completions.
    /// Unlimited quotas are left out.
    static func reading(from data: Data, at now: Date) -> Result<LimitReading, LimitProblem> {
        guard let answer = try? JSONDecoder().decode(Answer.self, from: data) else { return .failure(.unreadable) }
        let plan = answer.copilot_plan?.value.flatMap { $0.isEmpty ? nil : planName($0) }
        if answer.access_type_sku?.value == "subscription_ended" {
            return .failure(.noLimits("This GitHub account's Copilot plan has ended."))
        }

        let resetsAt = [answer.quota_reset_date_utc, answer.quota_reset_date, answer.limited_user_reset_date]
            .lazy.compactMap { $0?.value.flatMap(resetDate) }.first
        let span = resetsAt.flatMap { reset in
            utcCalendar.date(byAdding: .month, value: -1, to: reset).map { reset.timeIntervalSince($0) }
        }
        let credits = answer.token_based_billing?.value == true

        var quotas: [String: Quota] = [:]
        for (key, value) in answer.quota_snapshots ?? [:] {
            if let quota = value.value { quotas[key] = quota }
        }
        // Copilot Free can send its chat and completions as two maps instead: the month's
        // allowance and what's left of it.
        for key in ["chat", "completions"] where quotas[key].map({ !$0.isUsable }) ?? true {
            guard let total = answer.monthly_quotas?[key]?.value, total > 0,
                  let left = answer.limited_user_quotas?[key]?.value else { continue }
            quotas[key] = Quota(entitlement: total, remaining: left)
        }

        let known = ["premium_interactions", "chat", "completions"]
        let order = known + quotas.keys.filter { !known.contains($0) }.sorted()
        let windows = order.compactMap { key -> LimitWindow? in
            guard let quota = quotas[key] else { return nil }
            return window(quota, key: key, credits: credits, resetsAt: resetsAt, span: span)
        }

        if windows.isEmpty {
            if quotas.isEmpty, plan == nil {
                return .failure(.noLimits("This GitHub account has no Copilot plan."))
            }
            if !quotas.isEmpty, quotas.values.allSatisfy({ $0.unlimited == true }) {
                return .failure(.noLimits("\(plan ?? "This Copilot plan") has no monthly limits."))
            }
            return .failure(.noLimits("GitHub doesn't share a monthly allowance for \(plan ?? "this Copilot plan")."))
        }
        return .success(LimitReading(fetchedAt: now, windows: windows, plan: plan))
    }

    /// One quota as a window, or nil when it's unlimited or empty. GitHub sends an allowance of 0
    /// with nothing left for plans billed elsewhere, such as some Business seats: that's no limit,
    /// not one used up, unless it counts the credits spent.
    private static func window(_ quota: Quota, key: String, credits: Bool, resetsAt: Date?, span: TimeInterval?) -> LimitWindow? {
        guard quota.unlimited != true else { return nil }
        let name = names(key, credits: credits)
        let total = quota.entitlement?.value ?? 0
        let left = quota.remaining?.value ?? quota.quota_remaining?.value
        let share = quota.percent_remaining?.value

        // A share with no counts is still a reading; an allowance of 0 is not.
        let shareAlone = share != nil && quota.entitlement == nil && left == nil
        if total <= 0, !shareAlone {
            guard let spent = quota.credits_used?.value else { return nil }
            return LimitWindow(id: name.id, title: name.title, utilization: nil, resetsAt: resetsAt, span: span,
                               detail: "\(number(spent)) used")
        }

        var utilization: Double?
        if let share {
            utilization = 100 - share
        } else if total > 0, let left {
            utilization = (total - left) / total * 100
        }
        guard let used = utilization else { return nil }
        // Past the allowance the share goes over 100; the bar stops at full and the count says how far.
        let detail = (total > 0 ? left : nil).map { "\(number(total - $0)) of \(number(total)) used" }
        return LimitWindow(id: name.id, title: name.title, utilization: min(100, max(0, used)), resetsAt: resetsAt,
                           span: span, detail: detail)
    }

    /// A quota's id and title on the page. Premium requests became AI Credits for plans billed by
    /// tokens (monthly Pro and Pro+ from June 2026); annual plans keep premium requests until they renew.
    private static func names(_ key: String, credits: Bool) -> (id: String, title: String) {
        switch key {
        case "premium_interactions": return ("premium", credits ? "AI Credits" : "Premium requests")
        case "chat": return ("chat", "Chat messages")
        case "completions": return ("completions", "Code completions")
        default: return (key, key.lowercased().contains("credit") ? "AI Credits" : words(key))
        }
    }

    /// "individual" → "Copilot Pro", "individual_pro" → "Copilot Pro+", "business" → "Copilot Business".
    static func planName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "free": return "Copilot Free"
        case "individual": return "Copilot Pro"
        case "individual_pro": return "Copilot Pro+"
        case "individual_max", "max": return "Copilot Max"
        case "business": return "Copilot Business"
        case "enterprise": return "Copilot Enterprise"
        default: return "Copilot " + words(raw)
        }
    }

    /// "premium_interactions" → "Premium interactions".
    private static func words(_ key: String) -> String {
        let text = key.replacingOccurrences(of: "_", with: " ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "238", "1,500", "43.5".
    private static func number(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = abs(value) < 100 ? 1 : 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// "2026-12-01" (midnight UTC), or a full ISO 8601 moment.
    static func resetDate(_ text: String) -> Date? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let moment = date(text) { return moment }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(identifier: "UTC")
        day.dateFormat = "yyyy-MM-dd"
        return day.date(from: text)
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    // MARK: The GitHub CLI's sign-in

    /// The GitHub CLI's token for github.com, from `gh auth token`, or nil when it isn't signed in
    /// or doesn't answer within `timeout`. The token is only ever put in the request.
    static func signInToken(gh: String, timeout: TimeInterval) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: readToken(gh: gh, timeout: timeout))
            }
        }
    }

    private static func readToken(gh: String, timeout: TimeInterval) -> String? {
        guard FileManager.default.isExecutableFile(atPath: gh) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gh)
        process.arguments = ["auth", "token", "--hostname", "github.com"]
        var environment = ProcessInfo.processInfo.environment
        environment["GH_PROMPT_DISABLED"] = "1"
        environment["GH_NO_UPDATE_NOTIFIER"] = "1"
        environment["NO_COLOR"] = "1"
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }

        let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        deadline.cancel()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else { return nil }

        let token = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        // One word of printable ASCII, as GitHub's tokens are; anything else isn't a token.
        guard !token.isEmpty, token.count < 512,
              token.unicodeScalars.allSatisfy({ $0.value > 0x20 && $0.value < 0x7F }) else { return nil }
        return token
    }

    // MARK: Lines and answers

    private enum Tag {
        static let all = [
            "\"session.start\"", "\"session.resume\"", "\"session.model_change\"",
            "\"user.message\"", "\"assistant.message\"",
        ].map { Array($0.utf8) }
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

    /// A string that is sometimes another shape (or null).
    struct LooseString: Decodable {
        let value: String?
        init(from decoder: Decoder) throws {
            value = try? decoder.singleValueContainer().decode(String.self)
        }
    }

    /// A count sent as a whole number, a fraction or a string of digits.
    struct LooseNumber: Decodable {
        let value: Double?
        init(_ value: Double?) { self.value = value }
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Double.self) {
                value = number.isFinite ? number : nil
            } else if let text = try? container.decode(String.self) {
                value = Double(text.trimmingCharacters(in: .whitespaces)).flatMap { $0.isFinite ? $0 : nil }
            } else {
                value = nil
            }
        }
    }

    /// A value in a shape this version doesn't expect is nil rather than a failed answer.
    struct Lenient<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    struct Context: Decodable {
        let cwd: String?
    }

    /// Every field the events read, all optional.
    struct EventData: Decodable {
        let sessionId: String?
        let selectedModel: String?
        let context: Context?
        let newModel: String?
        let reasoningEffort: LooseString?
        let content: LooseString?
        let messageId: String?
        let model: String?
        let outputTokens: LooseCount?
    }

    /// `outputTokens` as a whole number.
    struct LooseCount: Decodable {
        let value: Int?
        init(from decoder: Decoder) throws {
            value = try LooseNumber(from: decoder).value.map { Int($0.rounded()) }
        }
    }

    struct Event: Decodable {
        let type: String?
        let id: String?
        let timestamp: String?
        let agentId: String?
        let ephemeral: Bool?
        let data: EventData?
    }

    /// One of `quota_snapshots`.
    struct Quota: Decodable {
        var entitlement: LooseNumber?
        var remaining: LooseNumber?
        var quota_remaining: LooseNumber?
        var percent_remaining: LooseNumber?
        var unlimited: Bool?
        var credits_used: LooseNumber?

        init(entitlement: Double, remaining: Double) {
            self.entitlement = LooseNumber(entitlement)
            self.remaining = LooseNumber(remaining)
        }

        /// It has an allowance or a share to show.
        var isUsable: Bool {
            unlimited != true && ((entitlement?.value ?? 0) > 0 || percent_remaining?.value != nil)
        }
    }

    /// The parts of `copilot_internal/user` read here.
    struct Answer: Decodable {
        let copilot_plan: LooseString?
        let access_type_sku: LooseString?
        let token_based_billing: Lenient<Bool>?
        let quota_reset_date: LooseString?
        let quota_reset_date_utc: LooseString?
        let limited_user_reset_date: LooseString?
        let quota_snapshots: [String: Lenient<Quota>]?
        let monthly_quotas: [String: LooseNumber]?
        let limited_user_quotas: [String: LooseNumber]?
    }
}

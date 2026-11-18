import CryptoKit
import Foundation

/// Gemini CLI's usage: its calls from its chat logs in `~/.gemini/tmp`, and its plan's limits for
/// Code Assist accounts. The formats are Gemini CLI's own (google-gemini/gemini-cli,
/// `packages/core`), read here without Gemini CLI.
///
/// Its chat logs (`services/chatRecordingService.ts`):
///
/// - `tmp/<project>/chats/session-*.jsonl`: one session. The first line names it (`sessionId`), then
///   each message is a line. A message is written again, whole, each time it changes, so the last
///   copy of a message id is the one that counts. `$set` lines update the session (its `summary`);
///   `$patch` and `$rewindTo` lines edit the history, not what was used.
/// - `session-*.json`: older Gemini CLI's, the same record as one JSON document. Resuming one copies it
///   into a `.jsonl` beside it and leaves it there.
/// - `chats/<session id>/<subagent id>.jsonl`: a subagent's own conversation within that session.
/// - `<project>` is the folder's short name from `~/.gemini/projects.json`, or older Gemini CLI's
///   SHA-256 of the folder's path. Its `.project_root` file names the folder.
///
/// A `gemini` message's `tokens` are the API's usage as Gemini reports it: `input` includes `cached`,
/// and `thoughts` and `tool` are counted apart from `output` and `input`.
///
/// The limits come from Code Assist's endpoint, the one behind Gemini CLI's quota in `/model`, with
/// Gemini CLI's own sign-in in `~/.gemini/oauth_creds.json`.
enum GeminiUsage {
    /// Whether the tool has left logs of its calls on this Mac.
    static func hasLogs(home: String) -> Bool {
        let manager = FileManager.default
        for root in tempFolders(home: home) {
            guard let projects = try? manager.contentsOfDirectory(atPath: root.path) else { continue }
            for project in projects {
                let chats = root.appendingPathComponent(project).appendingPathComponent("chats").path
                if let names = try? manager.contentsOfDirectory(atPath: chats), names.contains(where: isSessionName) {
                    return true
                }
            }
        }
        return false
    }

    /// Every model call in the tool's logs since `since`, oldest first. Files are read oldest first
    /// and a call is counted once, where it first appears: an older session's `.json` and the `.jsonl`
    /// it was copied into hold the same calls.
    static func scan(home: String, since: Date) -> TranscriptScan {
        var files = chatFiles(home: home, modifiedSince: since)
        files.sort { $0.modified != $1.modified ? $0.modified < $1.modified : $0.url.path < $1.url.path }
        var scan = TranscriptScan()
        var seen = Set<String>()
        for file in files {
            guard let data = try? Data(contentsOf: file.url, options: .mappedIfSafe) else { continue }
            let parsed = parse(data, fileName: file.url.lastPathComponent, project: file.project,
                               parentSession: file.parentSession, since: since)
            for sample in parsed.samples where seen.insert(sample.id).inserted {
                scan.samples.append(sample)
            }
            scan.titles.merge(parsed.titles) { _, newer in newer }
        }
        scan.samples.sort { $0.ts < $1.ts }
        return scan
    }

    /// The plan's limits now. Never refreshes or rewrites the tool's own sign-in.
    ///
    /// Only Google sign-in has limits to read, and since Google stopped serving personal accounts in
    /// Gemini CLI (18 June 2026), only Code Assist Standard and Enterprise accounts have them. The
    /// sign-in is read, never renewed: its token lasts an hour, and Gemini CLI renews it when it runs.
    static func limits(home: String) async -> Result<LimitReading, LimitProblem> {
        let folder = geminiFolder(home)
        if let settings = FileManager.default.contents(atPath: folder + "/settings.json"),
           let problem = problem(authType: authType(settings: settings)) {
            return .failure(problem)
        }
        guard let credentials = FileManager.default.contents(atPath: folder + "/oauth_creds.json") else {
            return .failure(.notSignedIn(Says.notSignedIn))
        }
        let token: String
        switch accessToken(credentials: credentials, now: Date()) {
        case .success(let value): token = value
        case .failure(let problem): return .failure(problem)
        }
        do {
            let project = cloudProject(home: home)
            let (assist, assistStatus) = try await post("loadCodeAssist", body: loadBody(project: project), token: token)
            if let problem = problem(status: assistStatus) { return .failure(problem) }
            let account: Account
            switch self.account(loadCodeAssist: assist, project: project) {
            case .success(let value): account = value
            case .failure(let problem): return .failure(problem)
            }
            let (quota, quotaStatus) = try await post("retrieveUserQuota", body: ["project": account.project], token: token)
            if let problem = problem(status: quotaStatus) { return .failure(problem) }
            return reading(quota: quota, plan: account.plan, at: Date())
        } catch {
            return .failure(LimitProblem.from(error))
        }
    }

    // MARK: Where the logs are

    private static func geminiFolder(_ home: String) -> String { home + "/.gemini" }

    /// `~/.gemini/tmp`, and `~/.cache/.gemini/tmp`, where Gemini CLI keeps them when it runs in
    /// macOS's sandbox (`--sandbox`), which can't write to `~/.gemini`.
    static func tempFolders(home: String) -> [URL] {
        [home + "/.gemini/tmp", home + "/.cache/.gemini/tmp"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    private static func isSessionName(_ name: String) -> Bool {
        name.hasPrefix("session-") && isLogName(name)
    }

    private static func isLogName(_ name: String) -> Bool {
        name.hasSuffix(".jsonl") || name.hasSuffix(".json")
    }

    private struct ChatFile {
        let url: URL
        let modified: Date
        /// The folder Gemini CLI ran in, when it's known.
        let project: String?
        /// For a subagent's log, the session it ran in.
        let parentSession: String?
    }

    /// Every session's log, and every subagent's, changed at or after `since`.
    private static func chatFiles(home: String, modifiedSince since: Date) -> [ChatFile] {
        let manager = FileManager.default
        let registry = projectRegistry(home: home)
        var files: [ChatFile] = []
        func add(_ url: URL, project: String?, parent: String?) {
            guard let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                  modified >= since else { return }
            files.append(ChatFile(url: url, modified: modified, project: project, parentSession: parent))
        }
        for root in tempFolders(home: home) {
            guard let folders = try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for folder in folders {
                let chats = folder.appendingPathComponent("chats", isDirectory: true)
                guard let entries = try? manager.contentsOfDirectory(at: chats, includingPropertiesForKeys: [.isDirectoryKey]) else { continue }
                let project = projectFolder(folder, registry: registry)
                for entry in entries {
                    if (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                        let inner = (try? manager.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil)) ?? []
                        for file in inner where isLogName(file.lastPathComponent) {
                            add(file, project: project, parent: entry.lastPathComponent)
                        }
                    } else if isSessionName(entry.lastPathComponent) {
                        add(entry, project: project, parent: nil)
                    }
                }
            }
        }
        return files
    }

    private struct Registry: Decodable {
        let projects: [String: String]
    }

    /// Each project's short name, and older Gemini CLI's SHA-256 of its path, to its path, from the
    /// `projects.json` beside each `tmp`.
    static func projectRegistry(home: String) -> [String: String] {
        var registry: [String: String] = [:]
        for path in [home + "/.gemini/projects.json", home + "/.cache/.gemini/projects.json"] {
            guard let data = FileManager.default.contents(atPath: path),
                  let parsed = try? JSONDecoder().decode(Registry.self, from: data) else { continue }
            for (root, name) in parsed.projects {
                registry[name] = root
                registry[sha256(root)] = root
            }
        }
        return registry
    }

    private static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The folder a project's logs belong to: its `.project_root` file, else the registry's entry for
    /// its name.
    private static func projectFolder(_ folder: URL, registry: [String: String]) -> String? {
        if let marker = try? String(contentsOf: folder.appendingPathComponent(".project_root"), encoding: .utf8) {
            let path = marker.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty { return path }
        }
        return registry[folder.lastPathComponent]
    }

    // MARK: Parsing one log

    /// The calls and title in one chat log: JSON Lines, or older Gemini CLI's single document. A
    /// subagent's calls belong to `parentSession` and give it no title.
    static func parse(_ data: Data, fileName: String, project: String?, parentSession: String? = nil,
                      since: Date) -> TranscriptScan {
        let decoder = JSONDecoder()
        var session = (fileName as NSString).deletingPathExtension
        var summary: String?
        var prompt: String?
        var lastPrompt: Date?
        var lastReply: Date?
        var model = ""
        var result = TranscriptScan()
        var indexByKey: [String: Int] = [:]
        var durationByKey: [String: Int?] = [:]

        func record(_ message: Message) {
            guard let stamp = message.timestamp, let ts = date(stamp) else { return }
            switch message.type {
            case "user":
                // A prompt, or a tool's result sent back: either starts the next reply's time.
                if lastPrompt.map({ ts > $0 }) ?? true { lastPrompt = ts }
                if prompt == nil, let text = (message.displayContent ?? message.content)?.text {
                    prompt = title(from: text)
                }
            case "gemini":
                // A reply with no text records no model; it's the same model as the reply before.
                if let name = message.model, !name.isEmpty { model = name }
                guard let id = message.id, let tokens = message.tokens else { return }
                let key = "gemini:\(session)/\(id)"
                let duration: Int?
                if let known = durationByKey[key] {
                    duration = known
                } else {
                    var time: Int?
                    if let asked = [lastPrompt, lastReply].compactMap({ $0 }).max(), ts > asked {
                        let ms = Int(ts.timeIntervalSince(asked) * 1000)
                        if ms < 2 * 3600 * 1000 { time = ms }
                    }
                    durationByKey.updateValue(time, forKey: key)
                    duration = time
                }
                if lastReply.map({ ts > $0 }) ?? true { lastReply = ts }
                guard ts >= since else { return }
                let cached = max(0, tokens.cached ?? 0)
                let input = max(0, (tokens.input ?? 0) - cached) + max(0, tokens.tool ?? 0)
                let thinking = max(0, tokens.thoughts ?? 0)
                // Graphitree counts reasoning inside output, as Claude and OpenAI report it.
                let output = max(0, tokens.output ?? 0) + thinking
                guard input + cached + output > 0 else { return }
                let sample = TokenSample(
                    id: key, ts: ts, model: model.isEmpty ? "" : displayName(for: model),
                    input: input, output: output, cacheRead: cached, cacheWrite: 0, cacheWrite1h: 0,
                    thinking: thinking, sessionID: parentSession ?? session, project: project,
                    app: "gemini-cli", effort: nil, isSidechain: parentSession != nil,
                    agent: parentSession != nil ? session : nil, error: nil, durationMs: duration,
                    // ModelPricing has no Gemini prices yet.
                    cost: nil
                )
                if let index = indexByKey[key] {
                    result.samples[index] = sample
                } else {
                    indexByKey[key] = result.samples.count
                    result.samples.append(sample)
                }
            default:
                break
            }
        }

        func take(_ line: Line) {
            if let id = line.update?.sessionId ?? line.meta?.sessionId, !id.isEmpty { session = id }
            if let text = line.update?.summary ?? line.meta?.summary, !text.isEmpty { summary = text }
            for message in (line.meta?.messages ?? []) + (line.update?.messages ?? []) { record(message) }
            if let message = line.message { record(message) }
        }

        if fileName.hasSuffix(".json"), let document = try? decoder.decode(Line.self, from: data),
           document.meta?.sessionId != nil {
            take(document)
        } else {
            ClaudeTranscripts.forEachLine(of: data) { line, length in
                guard Tag.all.contains(where: { ClaudeTranscripts.contains(line, length, $0) }),
                      let entry = try? decoder.decode(Line.self, from: Data(bytes: line, count: length)) else { return true }
                take(entry)
                return true
            }
        }
        // Gemini CLI's own session list names a session by its summary, else its first prompt.
        if parentSession == nil, let name = summary.flatMap({ title(from: $0) }) ?? prompt {
            result.titles[session] = name
        }
        return result
    }

    /// A prompt's first line, short enough for a list, standing in for the session's title. Gemini CLI
    /// skips the same prompts in its session list: commands, and context it adds itself.
    static func title(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let skipped = ["/", "?", "<session_context>", "<hook_context>"]
        guard !skipped.contains(where: { trimmed.hasPrefix($0) }) else { return nil }
        let line = trimmed.split(whereSeparator: \.isNewline).lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("<") }
        guard let line else { return nil }
        return line.count > 80 ? String(line.prefix(79)) + "…" : line
    }

    /// "gemini-2.5-pro" → "Gemini 2.5 Pro", "gemini-2.5-flash-lite" → "Gemini 2.5 Flash Lite",
    /// "gemini-3-pro-preview" → "Gemini 3 Pro Preview". Dates and build numbers ("-05-20", "-002")
    /// are left out.
    static func displayName(for modelID: String) -> String {
        let id = modelID.split(separator: "/").last.map(String.init) ?? modelID
        let parts = id.split(separator: "-").map(String.init)
        guard !parts.isEmpty else { return modelID }
        let words = parts.enumerated().compactMap { index, part -> String? in
            if index > 1, part.allSatisfy(\.isNumber) { return nil }
            return part.prefix(1).uppercased() + part.dropFirst()
        }
        return words.joined(separator: " ")
    }

    // MARK: Lines

    private enum Tag {
        static let all = [
            Array("\"tokens\":{".utf8), Array("\"type\":\"user\"".utf8),
            Array("\"sessionId\"".utf8), Array("\"summary\"".utf8),
        ]
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

    /// A message's text: its content is a string, a part, or a list of either (`PartListUnion`). Only
    /// text parts count.
    struct Parts: Decodable {
        let text: String

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                text = string
            } else if let list = try? container.decode([Part].self) {
                text = list.compactMap(\.text).joined()
            } else {
                text = (try? container.decode(Part.self))?.text ?? ""
            }
        }
    }

    struct Part: Decodable {
        let text: String?

        private enum Keys: String, CodingKey { case text }

        init(from decoder: Decoder) throws {
            if let string = try? decoder.singleValueContainer().decode(String.self) {
                text = string
            } else {
                text = try? decoder.container(keyedBy: Keys.self).decode(String.self, forKey: .text)
            }
        }
    }

    struct Tokens: Decodable {
        let input: Int?
        let output: Int?
        let cached: Int?
        let thoughts: Int?
        let tool: Int?
    }

    /// One message. A field in a shape this version doesn't know is left out rather than the message.
    struct Message: Decodable {
        let id: String?
        let timestamp: String?
        let type: String?
        let model: String?
        let tokens: Tokens?
        let content: Parts?
        let displayContent: Parts?

        private enum Keys: String, CodingKey { case id, timestamp, type, model, tokens, content, displayContent }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            id = try? container.decodeIfPresent(String.self, forKey: .id)
            timestamp = try? container.decodeIfPresent(String.self, forKey: .timestamp)
            type = try? container.decodeIfPresent(String.self, forKey: .type)
            model = try? container.decodeIfPresent(String.self, forKey: .model)
            tokens = try? container.decodeIfPresent(Tokens.self, forKey: .tokens)
            content = try? container.decodeIfPresent(Parts.self, forKey: .content)
            displayContent = try? container.decodeIfPresent(Parts.self, forKey: .displayContent)
        }
    }

    /// The session's own fields: on its first line, in a `$set`, or in an older single document.
    struct Meta: Decodable {
        let sessionId: String?
        let summary: String?
        let messages: [Message]?

        private enum Keys: String, CodingKey { case sessionId, summary, messages }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            sessionId = try? container.decodeIfPresent(String.self, forKey: .sessionId)
            summary = try? container.decodeIfPresent(String.self, forKey: .summary)
            messages = try? container.decodeIfPresent([Message].self, forKey: .messages)
        }
    }

    /// One line, or an older log's whole document, read as each kind it might be.
    struct Line: Decodable {
        let meta: Meta?
        let update: Meta?
        let message: Message?

        private enum Keys: String, CodingKey { case update = "$set" }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            update = try? container.decodeIfPresent(Meta.self, forKey: .update)
            meta = try? Meta(from: decoder)
            message = try? Message(from: decoder)
        }
    }

    // MARK: Sign-in

    /// What the page says when a reading can't be had.
    enum Says {
        static let notSignedIn = "Gemini CLI isn't signed in with Google on this Mac. Run gemini and choose Sign in with Google."
        static let expired = "Gemini CLI's sign-in ran out. Open Gemini CLI to renew it."
        static let turnedDown = "Google turned down Gemini CLI's sign-in. Open Gemini CLI to sign in again."
        static let refused = "Google refused Gemini CLI's account. Since 18 June 2026 only Code Assist Standard and Enterprise accounts can use Gemini CLI's Google sign-in."
        static let personal = "Gemini CLI is signed in with a personal Google account. Google stopped serving those in Gemini CLI on 18 June 2026; only Code Assist Standard and Enterprise have limits to show."
        static let notSetUp = "Gemini CLI's Google account isn't set up for Code Assist yet. Open Gemini CLI to finish."
        static let noProject = "Gemini CLI's Google Cloud project isn't known. Add GOOGLE_CLOUD_PROJECT to ~/.gemini/.env, where Gemini CLI reads it too."
        static let apiKey = "Gemini CLI uses a Gemini API key, which is billed per call and has no plan limits."
        static let vertex = "Gemini CLI uses Vertex AI, which Google Cloud bills per call, so there are no plan limits."
        static let otherAuth = "Gemini CLI doesn't sign in with a Google account here, so there are no plan limits to read."
        static let noBuckets = "Google reports no limits for this Code Assist account."
    }

    private struct Settings: Decodable {
        struct Security: Decodable {
            struct Auth: Decodable { let selectedType: String? }
            let auth: Auth?
        }
        let security: Security?
        /// Older Gemini CLI's key, before settings were grouped.
        let selectedAuthType: String?
    }

    /// How Gemini CLI signs in, from its `settings.json` (`security.auth.selectedType`). Gemini CLI
    /// allows comments there.
    static func authType(settings: Data) -> String? {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        guard let parsed = try? decoder.decode(Settings.self, from: settings) else { return nil }
        return parsed.security?.auth?.selectedType ?? parsed.selectedAuthType
    }

    /// Why a way of signing in has no limits to read; nil for Google sign-in ("oauth-personal", which
    /// any Google account uses) and when none is chosen yet.
    static func problem(authType: String?) -> LimitProblem? {
        switch authType {
        case nil, "oauth-personal": return nil
        case "gemini-api-key": return .noLimits(Says.apiKey)
        case "vertex-ai": return .noLimits(Says.vertex)
        default: return .noLimits(Says.otherAuth)
        }
    }

    private struct Credentials: Decodable {
        let access_token: String?
        /// Milliseconds since 1970, as google-auth-library writes it.
        let expiry_date: Double?

        private enum Keys: String, CodingKey { case access_token, expiry_date }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            access_token = try? container.decodeIfPresent(String.self, forKey: .access_token)
            expiry_date = (try? container.decodeIfPresent(Double.self, forKey: .expiry_date))
                ?? (try? container.decodeIfPresent(String.self, forKey: .expiry_date)).flatMap { Double($0) }
        }
    }

    /// The access token in Gemini CLI's `oauth_creds.json`, while it lasts at least another minute.
    static func accessToken(credentials: Data, now: Date) -> Result<String, LimitProblem> {
        guard let parsed = try? JSONDecoder().decode(Credentials.self, from: credentials),
              let token = parsed.access_token, !token.isEmpty else { return .failure(.notSignedIn(Says.notSignedIn)) }
        if let expiry = parsed.expiry_date, Date(timeIntervalSince1970: expiry / 1000) <= now.addingTimeInterval(60) {
            return .failure(.expired(Says.expired))
        }
        return .success(token)
    }

    /// The Google Cloud project Gemini CLI sends, as it finds it: `GOOGLE_CLOUD_PROJECT` (or
    /// `GOOGLE_CLOUD_PROJECT_ID`) in the environment, else in `~/.gemini/.env`. Graphitree usually
    /// starts without the shell's environment, so the file is what it finds.
    static func cloudProject(home: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        for key in ["GOOGLE_CLOUD_PROJECT", "GOOGLE_CLOUD_PROJECT_ID"] {
            if let value = environment[key], !value.isEmpty { return value }
        }
        guard let text = try? String(contentsOfFile: geminiFolder(home) + "/.env", encoding: .utf8) else { return nil }
        return project(dotenv: text)
    }

    /// `GOOGLE_CLOUD_PROJECT`, else `GOOGLE_CLOUD_PROJECT_ID`, from a `.env` file's lines. Nothing else
    /// in the file is read.
    static func project(dotenv text: String) -> String? {
        var values: [String: String] = [:]
        for raw in text.split(whereSeparator: \.isNewline) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("export ") { line = String(line.dropFirst("export ".count)) }
            guard let equals = line.firstIndex(of: "=") else { continue }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            guard key == "GOOGLE_CLOUD_PROJECT" || key == "GOOGLE_CLOUD_PROJECT_ID" else { continue }
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !value.isEmpty { values[key] = value }
        }
        return values["GOOGLE_CLOUD_PROJECT"] ?? values["GOOGLE_CLOUD_PROJECT_ID"]
    }

    // MARK: Code Assist

    static let endpoint = "https://cloudcode-pa.googleapis.com/v1internal"

    /// Nothing from these requests is kept: no cookies, no cache.
    private static let network = URLSession(configuration: .ephemeral)

    private static func post(_ method: String, body: [String: Any], token: String) async throws -> (Data, Int) {
        guard let url = URL(string: "\(endpoint):\(method)") else { throw LimitProblem.unreadable }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await network.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    /// What Gemini CLI sends to `loadCodeAssist` (`code_assist/setup.ts`): its project when it has one,
    /// and the client's description.
    static func loadBody(project: String?) -> [String: Any] {
        var metadata: [String: Any] = ["ideType": "IDE_UNSPECIFIED", "platform": "PLATFORM_UNSPECIFIED", "pluginType": "GEMINI"]
        var body: [String: Any] = [:]
        if let project {
            body["cloudaicompanionProject"] = project
            metadata["duetProject"] = project
        }
        body["metadata"] = metadata
        return body
    }

    /// An answer's status as a problem; nil when it succeeded.
    static func problem(status: Int) -> LimitProblem? {
        switch status {
        case 200..<300: return nil
        case 401: return .expired(Says.turnedDown)
        case 403: return .notSignedIn(Says.refused)
        default: return .http(status)
        }
    }

    /// The Code Assist account a reading is for.
    struct Account: Equatable {
        var project: String
        /// "Code Assist Standard".
        var plan: String?
    }

    private struct LoadResponse: Decodable {
        struct Tier: Decodable {
            let id: String?
            let name: String?
        }
        /// Code Assist's project id, a string here; read as `{"id": …}` too, as `onboardUser` sends it.
        struct Project: Decodable {
            let id: String?
            private enum Keys: String, CodingKey { case id }
            init(from decoder: Decoder) throws {
                if let string = try? decoder.singleValueContainer().decode(String.self) {
                    id = string
                } else {
                    id = try? decoder.container(keyedBy: Keys.self).decode(String.self, forKey: .id)
                }
            }
        }
        let currentTier: Tier?
        let paidTier: Tier?
        let cloudaicompanionProject: Project?
    }

    /// The account in `loadCodeAssist`'s answer, as Gemini CLI reads it (`setupUser`): the paid tier
    /// over the current one, and the answer's project over the one it was sent. No current tier means
    /// Gemini CLI hasn't set the account up. The free tier is the personal one.
    static func account(loadCodeAssist data: Data, project: String?) -> Result<Account, LimitProblem> {
        guard let response = try? JSONDecoder().decode(LoadResponse.self, from: data) else { return .failure(.unreadable) }
        guard let current = response.currentTier else { return .failure(.notSignedIn(Says.notSetUp)) }
        let tierID = response.paidTier?.id ?? current.id
        if tierID == "free-tier" { return .failure(.noLimits(Says.personal)) }
        guard let project = response.cloudaicompanionProject?.id ?? project, !project.isEmpty else {
            return .failure(.notSignedIn(Says.noProject))
        }
        return .success(Account(project: project, plan: planName(tierID: tierID, tierName: response.paidTier?.name ?? current.name)))
    }

    /// The tier's own name without "Gemini" ("Gemini Code Assist Standard" → "Code Assist Standard"),
    /// else one from its id.
    static func planName(tierID: String?, tierName: String?) -> String? {
        if let name = tierName?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            return name.hasPrefix("Gemini ") ? String(name.dropFirst("Gemini ".count)) : name
        }
        switch tierID {
        case "standard-tier": return "Code Assist Standard"
        case "enterprise-tier": return "Code Assist Enterprise"
        default: return nil
        }
    }

    private struct QuotaResponse: Decodable {
        struct Bucket: Decodable {
            let remainingFraction: Double?
            let resetTime: String?
            let modelId: String?
        }
        let buckets: [Bucket]?
    }

    /// `retrieveUserQuota`'s buckets as windows, one per model. Gemini CLI's `/model` shows the same:
    /// how much of each model's daily requests is left, and when it resets. When a model has more
    /// than one bucket, the one with least left stands for it, as there.
    static func reading(quota: Data, plan: String?, at now: Date) -> Result<LimitReading, LimitProblem> {
        guard let response = try? JSONDecoder().decode(QuotaResponse.self, from: quota) else { return .failure(.unreadable) }
        var windows: [LimitWindow] = []
        var left: [String: Double] = [:]
        for bucket in response.buckets ?? [] {
            guard let model = bucket.modelId, !model.isEmpty, let remaining = bucket.remainingFraction else { continue }
            let window = LimitWindow(
                id: model, title: "\(displayName(for: model)) · daily",
                utilization: min(100, max(0, (1 - remaining) * 100)),
                resetsAt: bucket.resetTime.flatMap(date),
                // Code Assist's limits are requests per user per day.
                span: 86400
            )
            if let index = windows.firstIndex(where: { $0.id == model }) {
                if remaining < left[model] ?? 1 {
                    windows[index] = window
                    left[model] = remaining
                }
            } else {
                windows.append(window)
                left[model] = remaining
            }
        }
        guard !windows.isEmpty else { return .failure(.noLimits(Says.noBuckets)) }
        return .success(LimitReading(fetchedAt: now, windows: windows, plan: plan))
    }
}

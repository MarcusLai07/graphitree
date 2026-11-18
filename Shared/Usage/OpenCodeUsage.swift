import Foundation
import GRDB

/// OpenCode's usage: its calls, with the cost it recorded, from its database, and an OpenCode Go
/// plan's limits. Read without OpenCode, from its own formats (anomalyco/opencode, formerly
/// sst/opencode):
///
/// - Its data folder is `$XDG_DATA_HOME/opencode`, else `~/.local/share/opencode`
///   (`packages/util/src/global-roots.ts`). The database is `opencode.db` there, or `$OPENCODE_DB`:
///   a path of its own, or a name inside the folder (`packages/cli/src/database-path.ts`).
/// - OpenCode 2 keeps each model call as a `session_message` row of type `assistant`, or
///   `compaction` for the request that summarises a long session. Its `data` JSON has
///   `model {id, providerID, variant}`, `tokens {input, output, reasoning, cache {read, write}}`,
///   `cost` and `time {created, completed}`. Sessions are `session_v2` rows with `title`,
///   `directory` and `parent_id` (`packages/core/src/session/sql.ts`,
///   `packages/schema/src/session-message.ts`).
/// - OpenCode 1.2 to 1.18 kept them as `message` rows whose `data` has `role`, `modelID`,
///   `providerID`, `tokens`, `cost`, `path.cwd` and `time`, with sessions in `session` (migration
///   `20260127222353_familiar_lady_ursula`). OpenCode 2 copies those sessions into its own tables
///   under the same ids and leaves the old rows (`packages/core/src/database/v1-migration.bun.ts`),
///   so old rows are read only for sessions it hasn't copied yet.
/// - Before 1.2, one JSON file per message, `storage/message/<session>/<message>.json`, with the
///   same fields, and one per session in `storage/session/<project>/<session>.json`. 1.2 copied
///   them into the database and left the files, so a message the database has isn't counted again.
///
/// The database also keeps sign-ins: `credential`, `account`, `control_account` and
/// `session_share.secret`. Calls are read from the session and message tables only, a few fields
/// at a time, since message bodies hold whole tool outputs. Only `limits` reads a sign-in,
/// OpenCode Console's, and it never writes or renews it.
///
/// OpenCode records `input` without cached input and `output` without reasoning
/// (`packages/core/src/session/usage.ts`). Here output includes reasoning, as the other tools
/// report it, and `thinking` is the reasoning part. `cost` is what OpenCode recorded: what the
/// provider said it charged, else the catalog price, in dollars.
///
/// Calls through the `anthropic` or `openai` provider signed in with a Claude or ChatGPT plan also
/// count against that plan's limits, which show under Claude and Codex. They're kept here all the
/// same: they're OpenCode's calls, and Claude Code's and Codex's own logs don't have them.
enum OpenCodeUsage {
    /// Whether the tool has left logs of its calls on this Mac.
    static func hasLogs(home: String) -> Bool {
        hasLogs(home: home, environment: ProcessInfo.processInfo.environment)
    }

    /// Every model call in the tool's logs since `since`, oldest first.
    static func scan(home: String, since: Date) -> TranscriptScan {
        scan(home: home, since: since, environment: ProcessInfo.processInfo.environment)
    }

    /// The plan's limits now. Never refreshes or rewrites the tool's own sign-in.
    static func limits(home: String) async -> Result<LimitReading, LimitProblem> {
        await limits(home: home, environment: ProcessInfo.processInfo.environment)
    }

    // MARK: Where OpenCode keeps its data

    /// `$XDG_DATA_HOME/opencode`, else `~/.local/share/opencode`. An empty variable counts as unset,
    /// as it does for OpenCode.
    static func dataFolder(home: String, environment: [String: String]) -> URL {
        if let data = environment["XDG_DATA_HOME"], !data.isEmpty {
            return URL(fileURLWithPath: data, isDirectory: true).appendingPathComponent("opencode", isDirectory: true)
        }
        return URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent(".local/share/opencode", isDirectory: true)
    }

    /// `$OPENCODE_DB` when set, a path of its own or a name inside the data folder, else
    /// `opencode.db` there. Nil when OpenCode keeps its database in memory.
    static func databaseURL(home: String, environment: [String: String]) -> URL? {
        let folder = dataFolder(home: home, environment: environment)
        guard let name = environment["OPENCODE_DB"], !name.isEmpty else {
            return folder.appendingPathComponent("opencode.db")
        }
        if name == ":memory:" { return nil }
        return name.hasPrefix("/") ? URL(fileURLWithPath: name) : folder.appendingPathComponent(name)
    }

    /// The JSON message files from before OpenCode 1.2.
    private static func storedMessages(_ folder: URL) -> URL { folder.appendingPathComponent("storage/message", isDirectory: true) }
    private static func storedSessions(_ folder: URL) -> URL { folder.appendingPathComponent("storage/session", isDirectory: true) }

    static func hasLogs(home: String, environment: [String: String]) -> Bool {
        let files = FileManager.default
        if let database = databaseURL(home: home, environment: environment), files.fileExists(atPath: database.path) {
            return true
        }
        return files.fileExists(atPath: storedMessages(dataFolder(home: home, environment: environment)).path)
    }

    // MARK: Calls

    /// One call as OpenCode recorded it.
    private struct Call {
        var id: String
        var sessionID: String
        var created: Date
        var completed: Date?
        var model: String
        var variant: String?
        var input: Int
        var output: Int
        var reasoning: Int
        var cacheRead: Int
        var cacheWrite: Int
        var cost: Double?
        var cwd: String?
    }

    private struct Session {
        var parent: String?
        var title: String?
        var directory: String?
        /// The session's model, for a compaction that doesn't name its own.
        var model: String?
    }

    /// A call can start before `since` and finish after it; it counts by when it finished, so the
    /// database is asked for calls started a little earlier.
    private static let startSlack: TimeInterval = 2 * 3600

    static func scan(home: String, since: Date, environment: [String: String]) -> TranscriptScan {
        var calls: [Call] = []
        var sessions: [String: Session] = [:]
        var seen = Set<String>()
        if let database = databaseURL(home: home, environment: environment),
           let found = readDatabase(database, since: since) {
            for call in found.calls where seen.insert(call.id).inserted { calls.append(call) }
            sessions = found.sessions
        }
        let stored = readStorage(dataFolder(home: home, environment: environment), since: since, skipping: seen)
        calls += stored.calls
        sessions.merge(stored.sessions) { kept, _ in kept }
        return samples(calls, sessions: sessions, since: since)
    }

    private static func samples(_ calls: [Call], sessions: [String: Session], since: Date) -> TranscriptScan {
        var scan = TranscriptScan()
        var named = Set<String>()
        for call in calls {
            let ts = call.completed ?? call.created
            guard ts >= since else { continue }
            let tokens = call.input + call.output + call.reasoning + call.cacheRead + call.cacheWrite
            // A call stopped before the provider answered recorded nothing.
            guard tokens > 0 || (call.cost ?? 0) > 0 else { continue }
            let root = rootSession(of: call.sessionID, in: sessions)
            let session = sessions[call.sessionID]
            let model = call.model.isEmpty ? (session?.model ?? "") : call.model
            var duration: Int?
            if let completed = call.completed, completed > call.created {
                let ms = Int(completed.timeIntervalSince(call.created) * 1000)
                if ms < 2 * 3600 * 1000 { duration = ms }
            }
            let directory = [call.cwd, session?.directory, sessions[root]?.directory].compactMap { $0 }.first { !$0.isEmpty }
            let isSubagent = root != call.sessionID
            scan.samples.append(TokenSample(
                id: "opencode:" + call.id, ts: ts, model: model.isEmpty ? "" : displayName(for: model),
                input: call.input, output: call.output + call.reasoning,
                cacheRead: call.cacheRead, cacheWrite: call.cacheWrite, cacheWrite1h: 0,
                thinking: call.reasoning, sessionID: root, project: directory, app: "opencode",
                effort: call.variant.flatMap { $0.isEmpty || $0 == "default" ? nil : $0 },
                isSidechain: isSubagent, agent: isSubagent ? call.sessionID : nil, error: nil,
                durationMs: duration, cost: call.cost
            ))
            named.insert(root)
            named.insert(call.sessionID)
        }
        scan.samples.sort { $0.ts != $1.ts ? $0.ts < $1.ts : $0.id < $1.id }
        for id in named {
            if let title = sessions[id]?.title, !title.isEmpty { scan.titles[id] = title }
        }
        return scan
    }

    /// The session a subagent's session was started from, followed to the top. A subagent's calls
    /// count toward it, as the other tools' do.
    private static func rootSession(of id: String, in sessions: [String: Session]) -> String {
        var current = id
        var visited: Set<String> = [id]
        while let parent = sessions[current]?.parent, !parent.isEmpty, visited.insert(parent).inserted {
            current = parent
        }
        return current
    }

    // MARK: The database

    /// Opens OpenCode's database read-only. OpenCode keeps it in WAL mode and may be writing: a
    /// reader never blocks it, and waits briefly rather than fail on a lock.
    private static func openReadOnly(_ url: URL) -> DatabaseQueue? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        var configuration = Configuration()
        configuration.readonly = true
        configuration.busyMode = .timeout(2)
        return try? DatabaseQueue(path: url.path, configuration: configuration)
    }

    /// Whether `table` is there with every one of `columns`. Each schema is read only when its
    /// tables have the shape this reader knows.
    private static func has(_ db: Database, _ table: String, _ columns: [String]) -> Bool {
        guard (try? db.tableExists(table)) == true, let info = try? db.columns(in: table) else { return false }
        let present = Set(info.map(\.name))
        return columns.allSatisfy(present.contains)
    }

    private static func readDatabase(_ url: URL, since: Date) -> (calls: [Call], sessions: [String: Session])? {
        guard let queue = openReadOnly(url) else { return nil }
        defer { try? queue.close() }
        let floor = Int64((since.timeIntervalSince1970 - startSlack) * 1000)
        return try? queue.read { db in
            var calls: [Call] = []
            var sessions: [String: Session] = [:]
            let isV2 = has(db, "session_v2", ["id", "parent_id", "title", "directory"])

            // OpenCode 2's calls. A 1.x database can have `session_message` too, from an early
            // version of these tables, but its calls are in `message`: it's read only beside
            // `session_v2`.
            if isV2, has(db, "session_message", ["id", "session_id", "type", "time_created", "data"]) {
                calls += (try? fetchCalls(db, sql: """
                    SELECT id, session_id, time_created,
                           json_extract(data, '$.time.completed') AS completed,
                           json_extract(data, '$.model.id') AS model,
                           json_extract(data, '$.model.variant') AS variant,
                           json_extract(data, '$.tokens.input') AS input,
                           json_extract(data, '$.tokens.output') AS output,
                           json_extract(data, '$.tokens.reasoning') AS reasoning,
                           json_extract(data, '$.tokens.cache.read') AS cache_read,
                           json_extract(data, '$.tokens.cache.write') AS cache_write,
                           json_extract(data, '$.cost') AS cost,
                           NULL AS cwd
                    FROM session_message
                    WHERE time_created >= ? AND type IN ('assistant', 'compaction') AND json_valid(data)
                    """, floor: floor)) ?? []
            }

            // OpenCode 1.x's calls, in sessions OpenCode 2 hasn't copied into its own tables.
            if has(db, "message", ["id", "session_id", "time_created", "data"]) {
                let notCopied = isV2 ? "AND session_id NOT IN (SELECT id FROM session_v2)" : ""
                calls += (try? fetchCalls(db, sql: """
                    SELECT id, session_id, time_created,
                           json_extract(data, '$.time.completed') AS completed,
                           json_extract(data, '$.modelID') AS model,
                           json_extract(data, '$.variant') AS variant,
                           json_extract(data, '$.tokens.input') AS input,
                           json_extract(data, '$.tokens.output') AS output,
                           json_extract(data, '$.tokens.reasoning') AS reasoning,
                           json_extract(data, '$.tokens.cache.read') AS cache_read,
                           json_extract(data, '$.tokens.cache.write') AS cache_write,
                           json_extract(data, '$.cost') AS cost,
                           json_extract(data, '$.path.cwd') AS cwd
                    FROM message
                    WHERE time_created >= ? AND json_valid(data) AND json_extract(data, '$.role') = 'assistant'
                    \(notCopied)
                    """, floor: floor)) ?? []
            }

            // Sessions: OpenCode 2's first, then 1.x's for the ones it hasn't copied.
            if isV2 {
                let model = has(db, "session_v2", ["model"])
                    ? "CASE WHEN json_valid(model) THEN json_extract(model, '$.id') END" : "NULL"
                if let rows = try? Row.fetchAll(db, sql: "SELECT id, parent_id, title, directory, \(model) AS model FROM session_v2") {
                    for row in rows { if let id = text(row, "id") { sessions[id] = session(row) } }
                }
            }
            if has(db, "session", ["id", "parent_id", "title", "directory"]),
               let rows = try? Row.fetchAll(db, sql: "SELECT id, parent_id, title, directory, NULL AS model FROM session") {
                for row in rows {
                    if let id = text(row, "id"), sessions[id] == nil { sessions[id] = session(row) }
                }
            }
            return (calls, sessions)
        }
    }

    /// The calls a query finds. Every query names its columns the same way.
    private static func fetchCalls(_ db: Database, sql: String, floor: Int64) throws -> [Call] {
        var calls: [Call] = []
        let rows = try Row.fetchCursor(db, sql: sql, arguments: [floor])
        while let row = try rows.next() {
            guard let id = text(row, "id"), let sessionID = text(row, "session_id"),
                  let created = number(row, "time_created") else { continue }
            calls.append(Call(
                id: id, sessionID: sessionID,
                created: Date(timeIntervalSince1970: created / 1000),
                completed: number(row, "completed").map { Date(timeIntervalSince1970: $0 / 1000) },
                model: text(row, "model") ?? "", variant: text(row, "variant"),
                input: count(number(row, "input")), output: count(number(row, "output")),
                reasoning: count(number(row, "reasoning")),
                cacheRead: count(number(row, "cache_read")), cacheWrite: count(number(row, "cache_write")),
                cost: number(row, "cost").flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }, cwd: text(row, "cwd")
            ))
        }
        return calls
    }

    private static func session(_ row: Row) -> Session {
        Session(parent: text(row, "parent_id"), title: text(row, "title"), directory: text(row, "directory"),
                model: text(row, "model"))
    }

    /// A column as SQLite holds it: Int64, Double, String, Data or nil. Asking GRDB for a type
    /// instead stops the app when the value has another, and these come from JSON, which can
    /// hold anything.
    private static func value(_ row: Row, _ column: String) -> (any DatabaseValueConvertible)? { row[column] }

    private static func text(_ row: Row, _ column: String) -> String? { value(row, column) as? String }

    private static func number(_ row: Row, _ column: String) -> Double? {
        switch value(row, column) {
        case let number as Int64: return Double(number)
        case let number as Double: return number
        default: return nil
        }
    }

    /// A token count as OpenCode stores it: a JSON number, never below zero.
    private static func count(_ value: Double?) -> Int {
        guard let value, value.isFinite, value > 0 else { return 0 }
        return Int(value.rounded())
    }

    // MARK: JSON files from before OpenCode 1.2

    private struct StoredMessage: Decodable {
        struct Tokens: Decodable {
            struct Cache: Decodable {
                let read: Double?
                let write: Double?
            }
            let input: Double?
            let output: Double?
            let reasoning: Double?
            let cache: Cache?
        }
        struct Time: Decodable {
            let created: Double?
            let completed: Double?
        }
        struct Path: Decodable { let cwd: String? }
        let id: String?
        let sessionID: String?
        let role: String?
        let modelID: String?
        let variant: String?
        let tokens: Tokens?
        let cost: Double?
        let time: Time?
        let path: Path?
    }

    private struct StoredSession: Decodable {
        let parentID: String?
        let title: String?
        let directory: String?
    }

    /// Message files changed since `since`, and their sessions. A message file is written again
    /// when its reply finishes, so an older file can't hold a call in the window. A session's
    /// folder changes when a message is added to it, so a folder unchanged since well before
    /// `since` isn't opened: an old install can have tens of thousands of these files.
    private static func readStorage(_ folder: URL, since: Date, skipping seen: Set<String>) -> (calls: [Call], sessions: [String: Session]) {
        let files = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        func modified(_ url: URL) -> Date? { try? url.resourceValues(forKeys: Set(keys)).contentModificationDate }
        guard let folders = try? files.contentsOfDirectory(at: storedMessages(folder), includingPropertiesForKeys: keys) else {
            return ([], [:])
        }
        let decoder = JSONDecoder()
        var calls: [Call] = []
        var seen = seen
        for sessionFolder in folders {
            guard let changed = modified(sessionFolder), changed >= since.addingTimeInterval(-startSlack),
                  let messages = try? files.contentsOfDirectory(at: sessionFolder, includingPropertiesForKeys: keys) else { continue }
            for url in messages where url.pathExtension == "json" {
                guard let written = modified(url), written >= since,
                      let data = try? Data(contentsOf: url),
                      let message = try? decoder.decode(StoredMessage.self, from: data),
                      message.role == "assistant" else { continue }
                let id = message.id ?? url.deletingPathExtension().lastPathComponent
                guard seen.insert(id).inserted, let created = message.time?.created else { continue }
                let tokens = message.tokens
                calls.append(Call(
                    id: id, sessionID: message.sessionID ?? sessionFolder.lastPathComponent,
                    created: Date(timeIntervalSince1970: created / 1000),
                    completed: message.time?.completed.map { Date(timeIntervalSince1970: $0 / 1000) },
                    model: message.modelID ?? "", variant: message.variant,
                    input: count(tokens?.input), output: count(tokens?.output), reasoning: count(tokens?.reasoning),
                    cacheRead: count(tokens?.cache?.read), cacheWrite: count(tokens?.cache?.write),
                    cost: message.cost.flatMap { $0 >= 0 ? $0 : nil }, cwd: message.path?.cwd
                ))
            }
        }
        return (calls, readStoredSessions(folder, ids: Set(calls.map(\.sessionID))))
    }

    /// The sessions with these ids, and the ones they were started from. Each sits in its
    /// project's folder, which the message doesn't name, so every project folder is tried.
    private static func readStoredSessions(_ folder: URL, ids: Set<String>) -> [String: Session] {
        let root = storedSessions(folder)
        guard !ids.isEmpty, let projects = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return [:]
        }
        let decoder = JSONDecoder()
        var sessions: [String: Session] = [:]
        var wanted = ids
        var looked = Set<String>()
        while !wanted.isEmpty {
            looked.formUnion(wanted)
            var parents = Set<String>()
            for id in wanted {
                for project in projects {
                    let url = project.appendingPathComponent(id + ".json")
                    guard let data = try? Data(contentsOf: url),
                          let stored = try? decoder.decode(StoredSession.self, from: data) else { continue }
                    sessions[id] = Session(parent: stored.parentID, title: stored.title, directory: stored.directory)
                    if let parent = stored.parentID, !looked.contains(parent) { parents.insert(parent) }
                    break
                }
            }
            wanted = parents
        }
        return sessions
    }

    // MARK: Model names

    /// "claude-sonnet-4-5" → "Sonnet 4.5", "anthropic/claude-opus-4.1" → "Opus 4.1",
    /// "gpt-5.1-codex" → "GPT-5.1 Codex", "kimi-k2" → "Kimi K2", "qwen3-coder" → "Qwen3 Coder".
    /// Claude and GPT models are named as the Claude and Codex pages name them.
    static func displayName(for modelID: String) -> String {
        let id = modelID.split(separator: "/").last.map(String.init) ?? modelID
        if id.hasPrefix("claude-") {
            return TranscriptStats.displayName(for: id.replacingOccurrences(of: ".", with: "-"))
        }
        if id.hasPrefix("gpt-") { return CodexSessions.displayName(for: id) }
        return id.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    // MARK: OpenCode Go limits

    /// What the Usage page says when there are no Go limits to read.
    static let noGoPlan = "OpenCode's limits show with an OpenCode Go plan. Calls through other providers count against those providers' own limits."
    static let signInRanOut = "OpenCode's sign-in to OpenCode Console ran out. Open OpenCode to renew it."

    /// Where OpenCode signs in to OpenCode Console when the sign-in doesn't name a server
    /// (`packages/core/src/console-access.ts`).
    static let defaultConsole = "https://opencode.ai/console"

    /// What a request for the Go limits needs. Its description leaves the token out, so it can't
    /// end up in a log.
    struct GoSignIn: CustomStringConvertible {
        let url: URL
        let token: String
        /// The OpenCode Console workspace the sign-in chose, which Go reads its allowance for.
        let workspace: String

        var description: String { "OpenCode Go sign-in for \(url.host ?? "")" }
    }

    static func limits(home: String, environment: [String: String]) async -> Result<LimitReading, LimitProblem> {
        let signIn: GoSignIn
        switch goSignIn(home: home, environment: environment, now: Date()) {
        case .success(let found): signIn = found
        case .failure(let problem): return .failure(problem)
        }
        // As OpenCode asks (`packages/core/src/usage-limits.ts`): the sign-in's token, and the
        // workspace in `x-opencode-org-id`.
        var request = URLRequest(url: signIn.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(signIn.token)", forHTTPHeaderField: "Authorization")
        request.setValue(signIn.workspace, forHTTPHeaderField: "x-opencode-org-id")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let problem = goProblem(status: (response as? HTTPURLResponse)?.statusCode ?? 0) { return .failure(problem) }
            guard let reading = goReading(data, fetchedAt: Date()) else { return .failure(.unreadable) }
            return .success(reading)
        } catch {
            return .failure(.from(error))
        }
    }

    /// OpenCode Console's sign-in from OpenCode's database: its `credential` row for the `opencode`
    /// integration, the selected one first, then the newest, as OpenCode picks it
    /// (`packages/core/src/credential.ts`, `packages/core/src/integration.ts`). Read-only.
    static func goSignIn(home: String, environment: [String: String], now: Date) -> Result<GoSignIn, LimitProblem> {
        guard let database = databaseURL(home: home, environment: environment),
              let queue = openReadOnly(database) else { return .failure(.noLimits(noGoPlan)) }
        defer { try? queue.close() }
        let stored = try? queue.read { db -> String? in
            guard has(db, "credential", ["id", "integration_id", "value", "active", "time_created"]) else { return nil }
            let row = try Row.fetchOne(db, sql: """
                SELECT value FROM credential WHERE integration_id = 'opencode'
                ORDER BY active DESC, time_created DESC, id DESC LIMIT 1
                """)
            return row.flatMap { text($0, "value") }
        }
        guard let value = stored ?? nil else { return .failure(.noLimits(noGoPlan)) }
        return goSignIn(credential: Data(value.utf8), now: now)
    }

    private struct StoredCredential: Decodable {
        let type: String?
        let access: String?
        let key: String?
        /// Milliseconds; 0 when the sign-in gave no lifetime.
        let expires: Double?
        let metadata: [String: LooseString]?
    }

    /// A metadata value, which can be any JSON: only strings are read.
    private struct LooseString: Decodable {
        let value: String?
        init(from decoder: Decoder) throws {
            value = try? decoder.singleValueContainer().decode(String.self)
        }
    }

    /// A stored sign-in as a Go request. Go needs the workspace (`metadata.orgID`), which only an
    /// OpenCode Console account sign-in carries: OpenCode itself shows no Go limits without it. An
    /// access token at or within a minute of its end has run out: OpenCode renews it when it next
    /// runs, and Graphitree never does.
    static func goSignIn(credential: Data, now: Date) -> Result<GoSignIn, LimitProblem> {
        guard let stored = try? JSONDecoder().decode(StoredCredential.self, from: credential) else {
            return .failure(.noLimits(noGoPlan))
        }
        guard let workspace = stored.metadata?["orgID"]?.value, !workspace.isEmpty,
              let url = goUsageURL(console: stored.metadata?["server"]?.value ?? defaultConsole) else {
            return .failure(.noLimits(noGoPlan))
        }
        let token: String?
        switch stored.type {
        case "oauth":
            if let expires = stored.expires, expires > 0,
               Date(timeIntervalSince1970: expires / 1000) <= now.addingTimeInterval(60) {
                return .failure(.expired(signInRanOut))
            }
            token = stored.access
        case "key":
            token = stored.key
        default:
            // An external sign-in's secret is kept outside OpenCode.
            token = nil
        }
        guard let token, !token.isEmpty else { return .failure(.noLimits(noGoPlan)) }
        return .success(GoSignIn(url: url, token: token, workspace: workspace))
    }

    /// Go's usage address: `/zen/go/v1/usage` on the Console's own host. Sign-ins from before
    /// August 2026 name the retired console.opencode.ai, which OpenCode maps onto opencode.ai. Only
    /// https, so the token never travels in the clear.
    static func goUsageURL(console server: String) -> URL? {
        guard let parts = URLComponents(string: server), parts.scheme?.lowercased() == "https",
              let host = parts.host, !host.isEmpty else { return nil }
        var url = URLComponents()
        url.scheme = "https"
        url.host = host.lowercased() == "console.opencode.ai" ? "opencode.ai" : host
        url.port = parts.port
        url.path = "/zen/go/v1/usage"
        return url.url
    }

    /// What an answer's status means. Go turns down (403) a workspace without a Go subscription,
    /// which has no limits to show; 401 is a sign-in OpenCode Console no longer takes.
    static func goProblem(status: Int) -> LimitProblem? {
        switch status {
        case 200..<300: return nil
        case 401: return .expired(signInRanOut)
        case 403: return .noLimits(noGoPlan)
        default: return .http(status)
        }
    }

    private struct GoUsage: Decodable {
        struct Meter: Decodable {
            let status: String?
            let percent: Double?
            let resetsAt: String?
        }
        struct Usage: Decodable {
            let rolling: Meter?
            let weekly: Meter?
            let monthly: Meter?
        }
        let usage: Usage?
    }

    /// Go's answer, `{"usage": {"rolling", "weekly", "monthly"}}`, each with `percent`, `resetsAt`
    /// and `status` ("ok", or "rate-limited" while Go refuses requests). Rolling is the 5-hour
    /// limit, as OpenCode Console names it; monthly follows the subscription's month. Nil when
    /// none of the three can be read.
    static func goReading(_ data: Data, fetchedAt: Date) -> LimitReading? {
        guard let usage = (try? JSONDecoder().decode(GoUsage.self, from: data))?.usage else { return nil }
        let meters: [(id: String, title: String, span: TimeInterval, meter: GoUsage.Meter?)] = [
            ("rolling", "5-hour", 5 * 3600, usage.rolling),
            ("weekly", "Weekly", 7 * 86400, usage.weekly),
            ("monthly", "Monthly", 30 * 86400, usage.monthly),
        ]
        let windows = meters.compactMap { item -> LimitWindow? in
            guard let meter = item.meter, let percent = meter.percent, percent.isFinite else { return nil }
            return LimitWindow(
                id: item.id, title: item.title, utilization: min(max(percent, 0), 100),
                resetsAt: meter.resetsAt.flatMap(date), span: item.span,
                detail: meter.status == "rate-limited" ? "Limit reached: Go pauses requests until it resets" : nil
            )
        }
        guard !windows.isEmpty else { return nil }
        return LimitReading(fetchedAt: fetchedAt, windows: windows, plan: "OpenCode Go")
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
}

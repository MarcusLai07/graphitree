import Foundation
import GRDB

// Checks for reading OpenCode's usage. The database follows OpenCode's own schema
// (anomalyco/opencode, packages/core/src/session/sql.ts and its migrations): OpenCode 2's
// `session_v2` and `session_message`, 1.x's `session` and `message` beside them, and a
// `credential` row. The JSON files follow the layout from before OpenCode 1.2. Every session,
// folder, model call and sign-in here is made up. Nothing reads the real ~/.local/share/opencode
// or reaches the network. Called from main.swift.

func openCodeChecks() throws {
    let files = FileManager.default
    let home = files.temporaryDirectory.appendingPathComponent("graphitree-opencode-\(UUID().uuidString)")
    defer { try? files.removeItem(at: home) }
    // The checks pass no environment, so a variable set where they run can't send them elsewhere.
    let none: [String: String] = [:]
    let folder = OpenCodeUsage.dataFolder(home: home.path, environment: none)
    try files.createDirectory(at: folder, withIntermediateDirectories: true)

    // MARK: Where it looks

    expectEqual(folder.path, home.path + "/.local/share/opencode", "OpenCode's data folder is ~/.local/share/opencode")
    expectEqual(OpenCodeUsage.dataFolder(home: "/Users/t", environment: ["XDG_DATA_HOME": "/Volumes/data"]).path,
                "/Volumes/data/opencode", "or opencode inside XDG_DATA_HOME")
    expectEqual(OpenCodeUsage.dataFolder(home: "/Users/t", environment: ["XDG_DATA_HOME": ""]).path,
                "/Users/t/.local/share/opencode", "an empty XDG_DATA_HOME counts as unset")
    expectEqual(OpenCodeUsage.databaseURL(home: "/Users/t", environment: none)?.path,
                "/Users/t/.local/share/opencode/opencode.db", "the database is opencode.db in the data folder")
    expectEqual(OpenCodeUsage.databaseURL(home: "/Users/t", environment: ["OPENCODE_DB": "/Volumes/data/work.db"])?.path,
                "/Volumes/data/work.db", "OPENCODE_DB can name a database anywhere")
    expectEqual(OpenCodeUsage.databaseURL(home: "/Users/t", environment: ["OPENCODE_DB": "work.db"])?.path,
                "/Users/t/.local/share/opencode/work.db", "or a name inside the data folder")
    check(OpenCodeUsage.databaseURL(home: "/Users/t", environment: ["OPENCODE_DB": ":memory:"]) == nil,
          "a database kept in memory leaves nothing to read")
    check(!OpenCodeUsage.hasLogs(home: home.path, environment: none), "an empty data folder has no logs")
    expectEqual(OpenCodeUsage.scan(home: home.path, since: .distantPast, environment: none).samples.count, 0,
                "and nothing to read")

    // MARK: A database with both schemas

    func ms(_ text: String) -> Int64 { Int64(utc(text).timeIntervalSince1970 * 1000) }
    func json(_ object: [String: Any]) -> String {
        String(decoding: try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), as: UTF8.self)
    }
    func tokens(_ input: Int, _ output: Int, reasoning: Int = 0, read: Int = 0, write: Int = 0) -> [String: Any] {
        ["input": input, "output": output, "reasoning": reasoning, "cache": ["read": read, "write": write]]
    }

    // OpenCode keeps its database in WAL mode, and a pool writes it that way.
    let database = folder.appendingPathComponent("opencode.db")
    let pool = try DatabasePool(path: database.path)
    try pool.write { db in
        try db.execute(sql: """
            CREATE TABLE session_v2 (
              id text PRIMARY KEY, project_id text NOT NULL, workspace_id text, parent_id text,
              slug text NOT NULL, directory text NOT NULL, path text, title text, version text NOT NULL,
              cost real DEFAULT 0 NOT NULL, tokens_input integer DEFAULT 0 NOT NULL,
              tokens_output integer DEFAULT 0 NOT NULL, tokens_reasoning integer DEFAULT 0 NOT NULL,
              tokens_cache_read integer DEFAULT 0 NOT NULL, tokens_cache_write integer DEFAULT 0 NOT NULL,
              agent text, model text, time_created integer NOT NULL, time_updated integer NOT NULL,
              time_archived integer
            );
            CREATE TABLE session_message (
              id text PRIMARY KEY, session_id text NOT NULL, type text NOT NULL, seq integer NOT NULL,
              time_created integer NOT NULL, time_updated integer NOT NULL, data text NOT NULL
            );
            CREATE INDEX session_message_time_created_idx ON session_message (time_created);
            CREATE TABLE session (
              id text PRIMARY KEY, project_id text NOT NULL, parent_id text, slug text NOT NULL,
              directory text NOT NULL, title text NOT NULL, version text NOT NULL,
              time_created integer NOT NULL, time_updated integer NOT NULL
            );
            CREATE TABLE message (
              id text PRIMARY KEY, session_id text NOT NULL, time_created integer NOT NULL,
              time_updated integer NOT NULL, data text NOT NULL
            );
            CREATE TABLE credential (
              id text PRIMARY KEY, integration_id text, label text NOT NULL, value text NOT NULL,
              connector_id text, method_id text, active integer, time_created integer NOT NULL,
              time_updated integer NOT NULL
            );
            """)

        func session(_ table: String, _ id: String, parent: String? = nil, title: String, directory: String, model: String? = nil) throws {
            let at = ms("2026-11-16T08:00:00Z")
            if table == "session_v2" {
                try db.execute(sql: """
                    INSERT INTO session_v2 (id, project_id, parent_id, slug, directory, title, version, model, time_created, time_updated)
                    VALUES (?, 'prj_one', ?, ?, ?, ?, '2.3.2', ?, ?, ?)
                    """, arguments: [id, parent, id, directory, title, model, at, at])
            } else {
                try db.execute(sql: """
                    INSERT INTO session (id, project_id, parent_id, slug, directory, title, version, time_created, time_updated)
                    VALUES (?, 'prj_one', ?, ?, ?, ?, '1.18.5', ?, ?)
                    """, arguments: [id, parent, id, directory, title, at, at])
            }
        }
        var seq = 0
        func v2(_ id: String, session: String, type: String, at created: String, _ data: [String: Any]) throws {
            seq += 1
            try db.execute(sql: "INSERT INTO session_message VALUES (?, ?, ?, ?, ?, ?, ?)",
                           arguments: [id, session, type, seq, ms(created), ms(created), json(data)])
        }
        func v1(_ id: String, session: String, at created: String, _ data: String) throws {
            try db.execute(sql: "INSERT INTO message VALUES (?, ?, ?, ?, ?)",
                           arguments: [id, session, ms(created), ms(created), data])
        }
        func assistant(_ model: String, _ provider: String, variant: String = "default", tokens: [String: Any],
                       cost: Double, at created: String, completed: String?) -> [String: Any] {
            var time: [String: Any] = ["created": ms(created)]
            if let completed { time["completed"] = ms(completed) }
            return ["agent": "build", "model": ["id": model, "providerID": provider, "variant": variant],
                    "content": [["type": "text", "text": "Done."]], "finish": "stop",
                    "cost": cost, "tokens": tokens, "time": time]
        }

        // OpenCode 2: a session, a subagent's session started from it, and one copied from 1.x.
        try session("session_v2", "ses_v2main", title: "Tidy the release notes", directory: "/Users/t/app",
                    model: #"{"id":"claude-sonnet-4-5","providerID":"anthropic"}"#)
        try session("session_v2", "ses_v2child", parent: "ses_v2main", title: "Look through the tests", directory: "/Users/t/app")
        try session("session_v2", "ses_moved", title: "Fix the login form", directory: "/Users/t/site")

        try v2("msg_v2a1", session: "ses_v2main", type: "assistant", at: "2026-11-17T09:00:00Z",
               assistant("claude-sonnet-4-5", "anthropic", tokens: tokens(120, 300, reasoning: 50, read: 2000, write: 400),
                         cost: 0.0123, at: "2026-11-17T09:00:00Z", completed: "2026-11-17T09:00:08Z"))
        try v2("msg_v2u1", session: "ses_v2main", type: "user", at: "2026-11-17T09:00:00Z",
               ["text": "Tidy the release notes", "time": ["created": ms("2026-11-17T09:00:00Z")]])
        try v2("msg_v2a2", session: "ses_v2child", type: "assistant", at: "2026-11-17T10:00:00Z",
               assistant("gpt-5.1-codex", "openai", variant: "high", tokens: tokens(800, 200, reasoning: 100),
                         cost: 0.25, at: "2026-11-17T10:00:00Z", completed: "2026-11-17T10:00:30Z"))
        // Stopped before the provider answered: nothing recorded.
        try v2("msg_v2a3", session: "ses_v2main", type: "assistant", at: "2026-11-17T11:00:00Z",
               assistant("claude-sonnet-4-5", "anthropic", tokens: tokens(0, 0), cost: 0,
                         at: "2026-11-17T11:00:00Z", completed: "2026-11-17T11:00:01Z"))
        // A compaction that doesn't name its model: the session's.
        try v2("msg_v2c1", session: "ses_v2main", type: "compaction", at: "2026-11-17T12:00:00Z",
               ["status": "completed", "reason": "auto", "summary": "The notes are tidied.", "cost": 0.05,
                "tokens": tokens(5000, 700), "time": ["created": ms("2026-11-17T12:00:00Z")]])
        try v2("msg_v2old", session: "ses_v2main", type: "assistant", at: "2026-11-10T09:00:00Z",
               assistant("claude-sonnet-4-5", "anthropic", tokens: tokens(10, 10), cost: 0.001,
                         at: "2026-11-10T09:00:00Z", completed: "2026-11-10T09:00:02Z"))
        try v2("msg_moved1", session: "ses_moved", type: "assistant", at: "2026-11-17T08:00:00Z",
               assistant("claude-haiku-4-5", "anthropic", tokens: tokens(60, 40), cost: 0.0004,
                         at: "2026-11-17T08:00:00Z", completed: "2026-11-17T08:00:03Z"))

        // OpenCode 1.x: the session OpenCode 2 copied, still here, and one it hasn't copied yet.
        try session("session", "ses_moved", title: "Fix the login form", directory: "/Users/t/site")
        try session("session", "ses_v1only", title: "Write the changelog", directory: "/Users/t/notes")
        try v1("msg_moved1", session: "ses_moved", at: "2026-11-17T08:00:00Z", json([
            "role": "assistant", "modelID": "claude-haiku-4-5", "providerID": "anthropic", "cost": 0.0004,
            "tokens": tokens(60, 40), "time": ["created": ms("2026-11-17T08:00:00Z")]]))
        try v1("msg_v1a1", session: "ses_v1only", at: "2026-11-17T07:00:00Z", json([
            "role": "assistant", "parentID": "msg_v1u1", "modelID": "kimi-k2", "providerID": "opencode",
            "mode": "build", "agent": "build", "path": ["cwd": "/Users/t/notes/docs", "root": "/Users/t/notes"],
            "cost": 0.002, "tokens": tokens(1000, 50, read: 300),
            "time": ["created": ms("2026-11-17T07:00:00Z"), "completed": ms("2026-11-17T07:00:05Z")]]))
        try v1("msg_v1u1", session: "ses_v1only", at: "2026-11-17T06:59:59Z", json([
            "role": "user", "agent": "build", "time": ["created": ms("2026-11-17T06:59:59Z")]]))
        try v1("msg_v1bad", session: "ses_v1only", at: "2026-11-17T07:30:00Z", "not json")

        // An API key for OpenCode's own provider: it names no OpenCode Console workspace.
        try db.execute(sql: "INSERT INTO credential VALUES ('cred_one', 'opencode', 'API key', ?, NULL, NULL, 1, ?, ?)",
                       arguments: [#"{"type":"key","key":"test-not-a-real-key"}"#, ms("2026-11-01T00:00:00Z"), ms("2026-11-01T00:00:00Z")])
    }

    // JSON files from before OpenCode 1.2: one not in the database, one it already has, and one
    // too old for the window.
    let stored = folder.appendingPathComponent("storage")
    func write(_ path: String, _ object: [String: Any], modified: String) throws {
        let url = stored.appendingPathComponent(path)
        try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json(object).utf8).write(to: url)
        try files.setAttributes([.modificationDate: utc(modified)], ofItemAtPath: url.path)
    }
    try write("message/ses_json1/msg_json1.json", [
        "id": "msg_json1", "sessionID": "ses_json1", "role": "assistant", "modelID": "qwen3-coder",
        "providerID": "opencode", "path": ["cwd": "/Users/t/old", "root": "/Users/t/old"], "cost": 0.001,
        "tokens": tokens(400, 100, reasoning: 20),
        "time": ["created": ms("2026-11-17T06:00:00Z"), "completed": ms("2026-11-17T06:00:04Z")]],
              modified: "2026-11-17T06:00:04Z")
    try write("message/ses_v1only/msg_v1a1.json", [
        "id": "msg_v1a1", "sessionID": "ses_v1only", "role": "assistant", "modelID": "kimi-k2",
        "providerID": "opencode", "cost": 0.002, "tokens": tokens(1000, 50, read: 300),
        "time": ["created": ms("2026-11-17T07:00:00Z"), "completed": ms("2026-11-17T07:00:05Z")]],
              modified: "2026-11-17T07:00:05Z")
    try write("message/ses_json1/msg_jsonold.json", [
        "id": "msg_jsonold", "sessionID": "ses_json1", "role": "assistant", "modelID": "qwen3-coder",
        "providerID": "opencode", "cost": 0.001, "tokens": tokens(400, 100),
        "time": ["created": ms("2026-11-01T06:00:00Z"), "completed": ms("2026-11-01T06:00:04Z")]],
              modified: "2026-11-01T06:00:04Z")
    try write("session/prj_one/ses_json1.json", [
        "id": "ses_json1", "projectID": "prj_one", "title": "Port the parser", "directory": "/Users/t/old",
        "version": "0.15.0", "time": ["created": ms("2026-11-17T05:59:00Z"), "updated": ms("2026-11-17T06:00:04Z")]],
              modified: "2026-11-17T06:00:04Z")

    // MARK: Reading

    let since = utc("2026-11-17T00:00:00Z")
    check(OpenCodeUsage.hasLogs(home: home.path, environment: none), "a data folder with opencode.db has logs")
    // Read while OpenCode would still have it open, its newest rows only in the -wal file.
    let whileOpen = OpenCodeUsage.scan(home: home.path, since: since, environment: none)
    try pool.close()
    let scan = OpenCodeUsage.scan(home: home.path, since: since, environment: none)
    expectEqual(whileOpen.samples.map(\.id), scan.samples.map(\.id), "the database reads the same while OpenCode has it open")

    expectEqual(scan.samples.map(\.id), [
        "opencode:msg_json1", "opencode:msg_v1a1", "opencode:msg_moved1",
        "opencode:msg_v2a1", "opencode:msg_v2a2", "opencode:msg_v2c1",
    ], "every call in the window once, oldest first: a copied session's and an already-imported file's count once; prompts, an empty reply, bad JSON and older calls don't count")

    func sample(_ id: String) -> TokenSample? { scan.samples.first { $0.id == "opencode:" + id } }
    let main = sample("msg_v2a1")
    expectEqual(main?.input, 120, "input is OpenCode's, without cached input")
    expectEqual(main?.output, 350, "output includes reasoning, as the other tools count it")
    expectEqual(main?.thinking, 50, "and reasoning is kept as thinking")
    expectEqual(main?.cacheRead, 2000, "cache reads")
    expectEqual(main?.cacheWrite, 400, "cache writes")
    expectEqual(main?.cost, 0.0123, "the cost is the one OpenCode recorded")
    expectEqual(main?.model, "Sonnet 4.5", "Claude models are named as the Claude page names them")
    expectEqual(main?.ts, utc("2026-11-17T09:00:08Z"), "a call is dated when it finished")
    expectEqual(main?.durationMs, 8000, "and took from its start to then")
    expectEqual(main?.project, "/Users/t/app", "calls carry the session's folder")
    expectEqual(main?.app, "opencode", "OpenCode is the app")
    check(main?.effort == nil, "the default variant isn't an effort")
    check(main?.isSidechain == false && main?.agent == nil, "a session's own calls are the main conversation's")

    let child = sample("msg_v2a2")
    expectEqual(child?.sessionID, "ses_v2main", "a subagent's calls count toward the session it was started from")
    expectEqual(child?.agent, "ses_v2child", "under its own session")
    check(child?.isSidechain == true, "as a subagent's")
    expectEqual(child?.model, "GPT-5.1 Codex", "GPT models are named as the Codex page names them")
    expectEqual(child?.effort, "high", "a variant is the call's effort")

    let compaction = sample("msg_v2c1")
    expectEqual(compaction?.model, "Sonnet 4.5", "a compaction without a model of its own takes the session's")
    expectEqual(compaction?.cost, 0.05, "and its cost counts")
    check(compaction?.durationMs == nil, "with no finish time, no duration")

    let older = sample("msg_v1a1")
    expectEqual(older?.model, "Kimi K2", "other models get a readable name")
    expectEqual(older?.project, "/Users/t/notes/docs", "1.x calls carry their own folder")
    expectEqual(older?.cacheRead, 300, "1.x calls read the same fields")
    expectEqual(older?.cost, 0.002, "and their recorded cost")

    let file = sample("msg_json1")
    expectEqual(file?.model, "Qwen3 Coder", "calls from JSON files read too")
    expectEqual(file?.output, 120, "with the same counts")
    expectEqual(file?.project, "/Users/t/old", "and folder")

    expectEqual(scan.titles, [
        "ses_v2main": "Tidy the release notes", "ses_v2child": "Look through the tests",
        "ses_moved": "Fix the login form", "ses_v1only": "Write the changelog", "ses_json1": "Port the parser",
    ], "sessions are titled from their session rows and files")

    let later = OpenCodeUsage.scan(home: home.path, since: utc("2026-11-17T09:30:00Z"), environment: none)
    expectEqual(later.samples.map(\.id), ["opencode:msg_v2a2", "opencode:msg_v2c1"], "only calls finished since the start count")

    // The calls the Usage page makes read the same, when nothing in this environment points elsewhere.
    let environment = ProcessInfo.processInfo.environment
    if environment["XDG_DATA_HOME"] == nil, environment["OPENCODE_DB"] == nil {
        check(OpenCodeUsage.hasLogs(home: home.path), "hasLogs(home:) finds the database")
        expectEqual(OpenCodeUsage.scan(home: home.path, since: since).samples.count, 6, "scan(home:since:) reads it")
    }

    expectEqual(OpenCodeUsage.displayName(for: "anthropic/claude-opus-4.1"), "Opus 4.1", "a provider's prefix and dotted versions read too")

    // MARK: JSON files alone, and a 1.x database

    let jsonHome = files.temporaryDirectory.appendingPathComponent("graphitree-opencode-\(UUID().uuidString)")
    defer { try? files.removeItem(at: jsonHome) }
    let olderFolder = OpenCodeUsage.dataFolder(home: jsonHome.path, environment: none)
    try files.createDirectory(at: olderFolder.appendingPathComponent("storage/message/ses_json1"), withIntermediateDirectories: true)
    try files.copyItem(at: stored.appendingPathComponent("message/ses_json1/msg_json1.json"),
                       to: olderFolder.appendingPathComponent("storage/message/ses_json1/msg_json1.json"))
    check(OpenCodeUsage.hasLogs(home: jsonHome.path, environment: none), "JSON files from before 1.2 are logs")
    expectEqual(OpenCodeUsage.scan(home: jsonHome.path, since: .distantPast, environment: none).samples.map(\.id),
                ["opencode:msg_json1"], "and read without a database")

    // A 1.x database can have an early `session_message` table: its calls are the ones in `message`.
    let v1Home = files.temporaryDirectory.appendingPathComponent("graphitree-opencode-\(UUID().uuidString)")
    defer { try? files.removeItem(at: v1Home) }
    let v1Folder = OpenCodeUsage.dataFolder(home: v1Home.path, environment: none)
    try files.createDirectory(at: v1Folder, withIntermediateDirectories: true)
    let v1Queue = try DatabaseQueue(path: v1Folder.appendingPathComponent("opencode.db").path)
    try v1Queue.write { db in
        try db.execute(sql: """
            CREATE TABLE session (id text PRIMARY KEY, project_id text NOT NULL, parent_id text, slug text NOT NULL,
              directory text NOT NULL, title text NOT NULL, version text NOT NULL, time_created integer NOT NULL,
              time_updated integer NOT NULL);
            CREATE TABLE message (id text PRIMARY KEY, session_id text NOT NULL, time_created integer NOT NULL,
              time_updated integer NOT NULL, data text NOT NULL);
            CREATE TABLE session_message (id text PRIMARY KEY, session_id text NOT NULL, type text NOT NULL,
              time_created integer NOT NULL, time_updated integer NOT NULL, data text NOT NULL);
            """)
        let at = ms("2026-11-17T07:00:00Z")
        try db.execute(sql: "INSERT INTO session VALUES ('ses_a', 'prj_one', NULL, 'ses_a', '/Users/t/a', 'Rename the flags', '1.14.20', ?, ?)",
                       arguments: [at, at])
        try db.execute(sql: "INSERT INTO message VALUES ('msg_a1', 'ses_a', ?, ?, ?)", arguments: [at, at, json([
            "role": "assistant", "modelID": "glm-4.6", "providerID": "zai", "cost": 0.003, "tokens": tokens(900, 80),
            "time": ["created": at, "completed": at + 2000]])])
        try db.execute(sql: "INSERT INTO session_message VALUES ('msg_b1', 'ses_a', 'assistant', ?, ?, ?)", arguments: [at, at, json([
            "model": ["id": "glm-4.6", "providerID": "zai"], "cost": 0.003, "tokens": tokens(900, 80),
            "time": ["created": at, "completed": at + 2000]])])
    }
    try v1Queue.close()
    let v1Scan = OpenCodeUsage.scan(home: v1Home.path, since: since, environment: none)
    expectEqual(v1Scan.samples.map(\.id), ["opencode:msg_a1"], "a 1.x database's calls are its messages")
    expectEqual(v1Scan.titles, ["ses_a": "Rename the flags"], "titled from its sessions")

    // MARK: OpenCode Go limits

    let now = utc("2026-11-17T12:00:00Z")
    let answer = #"{"usage":{"rolling":{"status":"ok","percent":42.5,"resetsAt":"2026-11-17T14:00:00.000Z"},"weekly":{"status":"ok","percent":18,"resetsAt":"2026-11-20T00:00:00Z"},"monthly":{"status":"rate-limited","percent":100,"resetsAt":"2026-12-01T00:00:00.000Z"}}}"#
    let reading = OpenCodeUsage.goReading(Data(answer.utf8), fetchedAt: now)
    expectEqual(reading?.windows.map(\.id), ["rolling", "weekly", "monthly"], "Go's three limits are read")
    expectEqual(reading?.windows.map(\.title), ["5-hour", "Weekly", "Monthly"], "named by their length")
    expectEqual(reading?.windows.map(\.span), [5 * 3600, 7 * 86400, 30 * 86400], "rolling is 5 hours, then a week and a month")
    expectEqual(reading?.windows.map(\.utilization), [42.5, 18, 100], "each with its share used")
    expectEqual(reading?.windows.map(\.resetsAt), [utc("2026-11-17T14:00:00Z"), utc("2026-11-20T00:00:00Z"), utc("2026-12-01T00:00:00Z")],
                "and its reset, with or without fractions of a second")
    check(reading?.windows.last?.detail != nil && reading?.windows.first?.detail == nil, "a limit Go is refusing requests under says so")
    expectEqual(reading?.plan, "OpenCode Go", "the plan is OpenCode Go")
    expectEqual(reading?.fetchedAt, now, "read now")
    check(OpenCodeUsage.goReading(Data(#"{"type":"error","error":{"message":"no"}}"#.utf8), fetchedAt: now) == nil,
          "an answer without usage isn't a reading")

    func problem(_ result: Result<OpenCodeUsage.GoSignIn, LimitProblem>) -> LimitProblem? {
        if case .failure(let problem) = result { return problem }
        return nil
    }
    func credential(_ value: String) -> Result<OpenCodeUsage.GoSignIn, LimitProblem> {
        OpenCodeUsage.goSignIn(credential: Data(value.utf8), now: now)
    }
    let inAnHour = ms("2026-11-17T13:00:00Z")
    let consoleSignIn = #"{"type":"oauth","methodID":"device","access":"test-access","refresh":"test-refresh","expires":\#(inAnHour),"metadata":{"server":"https://console.opencode.ai","orgID":"wrk_testteam","orgName":"Test Team"}}"#
    if case .success(let signIn) = credential(consoleSignIn) {
        check(signIn.url.absoluteString == "https://opencode.ai/zen/go/v1/usage", "Go is asked on the Console's host; the retired console host maps onto opencode.ai")
        check(signIn.token == "test-access", "with the sign-in's access token")
        check(signIn.workspace == "wrk_testteam", "for the workspace the sign-in chose")
        check(!"\(signIn)".contains("test-access"), "a sign-in's description leaves its token out")
    } else {
        check(false, "an OpenCode Console sign-in with a workspace can ask Go")
    }
    if case .success(let signIn) = credential(#"{"type":"oauth","methodID":"device","access":"test-access","refresh":"test-refresh","expires":\#(inAnHour),"metadata":{"server":"https://console.example.test/console","orgID":"wrk_testteam"}}"#) {
        check(signIn.url.absoluteString == "https://console.example.test/zen/go/v1/usage", "another Console server is asked on its own host")
    } else {
        check(false, "a sign-in to another Console server can ask Go")
    }
    check((try? credential(#"{"type":"oauth","methodID":"device","access":"test-access","refresh":"test-refresh","expires":0,"metadata":{"orgID":"wrk_testteam"}}"#).get()) != nil,
          "a sign-in without a lifetime doesn't run out; the server defaults to opencode.ai")
    expectEqual(problem(credential(#"{"type":"oauth","methodID":"device","access":"test-access","refresh":"test-refresh","expires":\#(ms("2026-11-17T11:00:00Z")),"metadata":{"orgID":"wrk_testteam"}}"#)),
                .expired(OpenCodeUsage.signInRanOut), "a sign-in that ran out is left for OpenCode to renew")
    expectEqual(problem(credential(#"{"type":"key","key":"test-not-a-real-key"}"#)),
                .noLimits(OpenCodeUsage.noGoPlan), "an API key names no workspace, so no Go limits")
    expectEqual(problem(credential(#"{"type":"external","methodID":"cli","metadata":{"orgID":"wrk_testteam"}}"#)),
                .noLimits(OpenCodeUsage.noGoPlan), "a sign-in kept outside OpenCode has no token to read")
    expectEqual(problem(credential(#"{"type":"oauth","methodID":"device","access":"test-access","refresh":"test-refresh","expires":0,"metadata":{"server":"http://console.example.test","orgID":"wrk_testteam"}}"#)),
                .noLimits(OpenCodeUsage.noGoPlan), "a token is never sent over plain http")

    check(OpenCodeUsage.goProblem(status: 200) == nil, "200 is a reading")
    expectEqual(OpenCodeUsage.goProblem(status: 403), .noLimits(OpenCodeUsage.noGoPlan), "Go turns down a workspace without a Go plan")
    expectEqual(OpenCodeUsage.goProblem(status: 401), .expired(OpenCodeUsage.signInRanOut), "401 is a sign-in the Console no longer takes")
    expectEqual(OpenCodeUsage.goProblem(status: 429), .http(429), "429 is rate limited")

    // The sign-in OpenCode would pick: the selected one, before a newer one.
    let picked = files.temporaryDirectory.appendingPathComponent("graphitree-opencode-\(UUID().uuidString)")
    defer { try? files.removeItem(at: picked) }
    let pickedFolder = OpenCodeUsage.dataFolder(home: picked.path, environment: none)
    try files.createDirectory(at: pickedFolder, withIntermediateDirectories: true)
    let pickedQueue = try DatabaseQueue(path: pickedFolder.appendingPathComponent("opencode.db").path)
    try pickedQueue.write { db in
        try db.execute(sql: """
            CREATE TABLE credential (id text PRIMARY KEY, integration_id text, label text NOT NULL, value text NOT NULL,
              connector_id text, method_id text, active integer, time_created integer NOT NULL, time_updated integer NOT NULL);
            """)
        let selected = consoleSignIn.replacingOccurrences(of: "wrk_testteam", with: "wrk_selected")
        let newer = consoleSignIn.replacingOccurrences(of: "wrk_testteam", with: "wrk_newer")
        try db.execute(sql: "INSERT INTO credential VALUES ('cred_a', 'opencode', 'Test Team', ?, NULL, 'device', 1, 1, 1)", arguments: [selected])
        try db.execute(sql: "INSERT INTO credential VALUES ('cred_b', 'opencode', 'Test Team', ?, NULL, 'device', 0, 2, 2)", arguments: [newer])
        try db.execute(sql: "INSERT INTO credential VALUES ('cred_c', 'anthropic', 'OAuth', ?, NULL, 'oauth', 1, 3, 3)", arguments: [consoleSignIn])
    }
    try pickedQueue.close()
    if case .success(let signIn) = OpenCodeUsage.goSignIn(home: picked.path, environment: none, now: now) {
        check(signIn.workspace == "wrk_selected", "the selected OpenCode Console sign-in is the one asked")
    } else {
        check(false, "a stored OpenCode Console sign-in is found")
    }

    // No Go plan: an API key alone, or no OpenCode at all. Neither reaches the network.
    expectEqual(waitForOpenCode { await OpenCodeUsage.limits(home: home.path, environment: none) }, .failure(.noLimits(OpenCodeUsage.noGoPlan)),
                "with only an API key, OpenCode shows no limits and says why")
    let empty = files.temporaryDirectory.appendingPathComponent("graphitree-opencode-\(UUID().uuidString)")
    expectEqual(waitForOpenCode { await OpenCodeUsage.limits(home: empty.path, environment: none) }, .failure(.noLimits(OpenCodeUsage.noGoPlan)),
                "without OpenCode, the same")
}

/// A result handed from a task to the checks, which wait for it on their own thread.
private final class OpenCodeResult<T>: @unchecked Sendable {
    var value: T?
}

/// Waits for an async reading. The checks are synchronous; the reading runs off the main thread.
private func waitForOpenCode<T>(_ body: @escaping @Sendable () async -> T) -> T {
    let result = OpenCodeResult<T>()
    let done = DispatchSemaphore(value: 0)
    Task.detached {
        result.value = await body()
        done.signal()
    }
    done.wait()
    return result.value!
}

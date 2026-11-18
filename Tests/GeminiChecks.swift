import CryptoKit
import Foundation

// Checks for reading Gemini CLI's chat logs and Code Assist's limits. The files follow Gemini CLI's
// own format (google-gemini/gemini-cli, packages/core/src/services/chatRecordingService.ts): a JSON
// Lines session whose reply is written twice, a subagent's log in its session's folder, an older
// session as one JSON document beside the `.jsonl` it was copied into, and a session from the macOS
// sandbox. Every name, path, project and token is made up. Nothing here reads the real ~/.gemini or
// reaches the network. Called from main.swift.

func geminiChecks() throws {
    let manager = FileManager.default
    let home = manager.temporaryDirectory.appendingPathComponent("graphitree-gemini-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: home) }
    let gemini = home.appendingPathComponent(".gemini")

    check(!GeminiUsage.hasLogs(home: home.path), "without ~/.gemini, Gemini CLI has no logs")
    expectEqual(GeminiUsage.scan(home: home.path, since: .distantPast).samples.count, 0, "and no calls")

    func folder(_ path: String) throws -> URL {
        let url = home.appendingPathComponent(path, isDirectory: true)
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func write(_ url: URL, _ text: String, modified: String) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
        try manager.setAttributes([.modificationDate: utc(modified)], ofItemAtPath: url.path)
    }

    func tokens(_ input: Int, cached: Int, output: Int, thoughts: Int = 0, tool: Int = 0) -> String {
        #"{"input":\#(input),"output":\#(output),"cached":\#(cached),"thoughts":\#(thoughts),"tool":\#(tool),"total":\#(input + output + thoughts + tool)}"#
    }

    // Gemini CLI's own bin folder sits in tmp too, with no chats.
    _ = try folder(".gemini/tmp/bin")
    check(!GeminiUsage.hasLogs(home: home.path), "a folder in tmp without chats holds no logs")

    // A project under its short name, with its folder in `.project_root`.
    let app = try folder(".gemini/tmp/sample-app")
    try "/Users/test/sample-app\n".write(to: app.appendingPathComponent(".project_root"), atomically: true, encoding: .utf8)
    let appChats = try folder(".gemini/tmp/sample-app/chats")

    // A session: its reply written again when its tool call was added, a reply with no text and so
    // no model whose tokens came after it, a rewind, and the summary Gemini CLI names it by.
    try write(appChats.appendingPathComponent("session-2026-11-17T09-00-aaaa0001.jsonl"), [
        #"{"sessionId":"aaaa0001-0000-4000-8000-000000000001","projectHash":"0000","startTime":"2026-11-17T09:00:00.000Z","lastUpdated":"2026-11-17T09:00:00.000Z"}"#,
        #"{"id":"u1","timestamp":"2026-11-17T09:00:00.000Z","type":"user","content":[{"text":"Add a dark mode toggle\nto the settings screen"}]}"#,
        #"{"$set":{"lastUpdated":"2026-11-17T09:00:00.000Z"}}"#,
        #"{"id":"g1","timestamp":"2026-11-17T09:00:12.000Z","type":"gemini","content":"","thoughts":[],"tokens":\#(tokens(12000, cached: 8000, output: 300, thoughts: 150)),"model":"gemini-2.5-pro"}"#,
        #"{"id":"g1","timestamp":"2026-11-17T09:00:12.000Z","type":"gemini","content":"","toolCalls":[{"id":"call_1","name":"read_file","args":{},"status":"success","timestamp":"2026-11-17T09:00:12.000Z"}],"thoughts":[],"tokens":\#(tokens(12000, cached: 8000, output: 300, thoughts: 150)),"model":"gemini-2.5-pro"}"#,
        #"{"id":"u2","timestamp":"2026-11-17T09:00:15.000Z","type":"user","content":[{"functionResponse":{"id":"call_1","name":"read_file","response":{"output":"made-up file"}}}]}"#,
        #"{"id":"g2","timestamp":"2026-11-17T09:00:20.000Z","type":"gemini","content":"Done.","tokens":null}"#,
        #"{"id":"g2","timestamp":"2026-11-17T09:00:20.000Z","type":"gemini","content":"Done.","tokens":\#(tokens(13000, cached: 12000, output: 50))}"#,
        #"{"id":"i1","timestamp":"2026-11-17T09:00:21.000Z","type":"info","content":"Saved."}"#,
        #"{"$rewindTo":"g2"}"#,
        #"{"$set":{"summary":"Add a dark mode toggle to settings"}}"#,
        "not json",
    ].joined(separator: "\n") + "\n", modified: "2026-11-17T09:01:00Z")

    // A session named by its first real prompt, after a command, and its subagent's own log.
    try write(appChats.appendingPathComponent("session-2026-11-17T10-00-bbbb0002.jsonl"), [
        #"{"sessionId":"bbbb0002-0000-4000-8000-000000000002","projectHash":"0000","startTime":"2026-11-17T10:00:00.000Z","lastUpdated":"2026-11-17T10:00:00.000Z"}"#,
        #"{"id":"v1","timestamp":"2026-11-17T09:59:50.000Z","type":"user","content":"/stats"}"#,
        #"{"id":"v2","timestamp":"2026-11-17T10:00:00.000Z","type":"user","content":[{"text":"Why does the build fail on CI?"},{"text":"\nIt passes here."}]}"#,
        #"{"id":"w1","timestamp":"2026-11-17T10:00:05.000Z","type":"gemini","content":"Looking.","tokens":\#(tokens(500, cached: 0, output: 40, tool: 20)),"model":"gemini-3-flash-preview"}"#,
    ].joined(separator: "\n") + "\n", modified: "2026-11-17T10:00:05Z")
    let subagents = try folder(".gemini/tmp/sample-app/chats/bbbb0002-0000-4000-8000-000000000002")
    try write(subagents.appendingPathComponent("cccc0003-0000-4000-8000-000000000003.jsonl"), [
        #"{"sessionId":"cccc0003-0000-4000-8000-000000000003","projectHash":"0000","startTime":"2026-11-17T10:01:00.000Z","lastUpdated":"2026-11-17T10:01:00.000Z","kind":"subagent","directories":["/Users/test/sample-app"]}"#,
        #"{"id":"x1","timestamp":"2026-11-17T10:01:00.000Z","type":"user","content":"Look for the failing test"}"#,
        #"{"id":"x2","timestamp":"2026-11-17T10:01:04.000Z","type":"gemini","content":"Found it.","tokens":\#(tokens(2000, cached: 0, output: 40, thoughts: 10)),"model":"gemini-2.5-flash"}"#,
    ].joined(separator: "\n") + "\n", modified: "2026-11-17T10:01:04Z")

    // An older project, still in its folder named by the SHA-256 of its path, which projects.json
    // lists. Its session as one document, and the `.jsonl` Gemini CLI copied it into when resumed.
    let olderPath = "/Users/test/older-app"
    let olderHash = SHA256.hash(data: Data(olderPath.utf8)).map { String(format: "%02x", $0) }.joined()
    try #"{"projects":{"/Users/test/older-app":"older-app"}}"#.write(to: gemini.appendingPathComponent("projects.json"), atomically: true, encoding: .utf8)
    let olderChats = try folder(".gemini/tmp/\(olderHash)/chats")
    let olderMessages = [
        #"{"id":"o1","timestamp":"2026-11-16T08:00:00.000Z","type":"user","content":"Rename the helper"}"#,
        #"{"id":"o2","timestamp":"2026-11-16T08:00:09.000Z","type":"gemini","content":"Renamed.","thoughts":[],"tokens":\#(tokens(900, cached: 0, output: 60)),"model":"gemini-2.5-pro"}"#,
    ]
    try write(olderChats.appendingPathComponent("session-2026-11-16T08-00-dddd0004.json"), """
    {
      "sessionId": "dddd0004-0000-4000-8000-000000000004",
      "projectHash": "\(olderHash)",
      "startTime": "2026-11-16T08:00:00.000Z",
      "lastUpdated": "2026-11-16T08:00:09.000Z",
      "messages": [
        \(olderMessages.joined(separator: ",\n    "))
      ]
    }
    """, modified: "2026-11-16T08:00:09Z")
    try write(olderChats.appendingPathComponent("session-2026-11-16T08-00-dddd0004.jsonl"), ([
        #"{"sessionId":"dddd0004-0000-4000-8000-000000000004","projectHash":"\#(olderHash)","startTime":"2026-11-16T08:00:00.000Z","lastUpdated":"2026-11-16T08:00:09.000Z"}"#,
    ] + olderMessages + [
        #"{"$set":{"sessionId":"dddd0004-0000-4000-8000-000000000004"}}"#,
        #"{"id":"o3","timestamp":"2026-11-17T11:00:00.000Z","type":"user","content":"And its tests"}"#,
        #"{"id":"o4","timestamp":"2026-11-17T11:00:06.000Z","type":"gemini","content":"Done.","tokens":\#(tokens(1500, cached: 900, output: 80)),"model":"gemini-2.5-pro"}"#,
    ]).joined(separator: "\n") + "\n", modified: "2026-11-17T11:00:06Z")

    // A session from Gemini CLI's macOS sandbox, which keeps its logs in ~/.cache/.gemini.
    let sandboxChats = try folder(".cache/.gemini/tmp/sandboxed/chats")
    try write(sandboxChats.appendingPathComponent("session-2026-11-17T12-00-eeee0005.jsonl"), [
        #"{"sessionId":"eeee0005-0000-4000-8000-000000000005","projectHash":"0000","startTime":"2026-11-17T12:00:00.000Z","lastUpdated":"2026-11-17T12:00:00.000Z"}"#,
        #"{"id":"y1","timestamp":"2026-11-17T12:00:03.000Z","type":"gemini","content":"Hi.","tokens":\#(tokens(100, cached: 0, output: 5)),"model":"gemini-2.5-flash-lite"}"#,
    ].joined(separator: "\n") + "\n", modified: "2026-11-17T12:00:03Z")

    // MARK: Reading

    check(GeminiUsage.hasLogs(home: home.path), "a session's log in tmp/<project>/chats is a log")
    let scan = GeminiUsage.scan(home: home.path, since: .distantPast)
    expectEqual(scan.samples.map(\.id), [
        "gemini:dddd0004-0000-4000-8000-000000000004/o2",
        "gemini:aaaa0001-0000-4000-8000-000000000001/g1",
        "gemini:aaaa0001-0000-4000-8000-000000000001/g2",
        "gemini:bbbb0002-0000-4000-8000-000000000002/w1",
        "gemini:cccc0003-0000-4000-8000-000000000003/x2",
        "gemini:dddd0004-0000-4000-8000-000000000004/o4",
        "gemini:eeee0005-0000-4000-8000-000000000005/y1",
    ], "each reply with tokens counts once, oldest first: a reply written twice, or copied from an older session's document, is one call")

    let first = scan.samples.first { $0.id.hasSuffix("/g1") }
    expectEqual(first?.input, 4000, "fresh input is input less cached")
    expectEqual(first?.cacheRead, 8000, "cached input counts as cache reads")
    expectEqual(first?.output, 450, "output includes the reasoning, as Graphitree counts it")
    expectEqual(first?.thinking, 150, "and the reasoning is kept")
    expectEqual(first?.model, "Gemini 2.5 Pro", "a reply's model is named")
    expectEqual(first?.sessionID, "aaaa0001-0000-4000-8000-000000000001", "calls belong to the session the log names")
    expectEqual(first?.project, "/Users/test/sample-app", "and to the folder in the project's .project_root")
    expectEqual(first?.app, "gemini-cli", "Gemini CLI's calls are its own app")
    expectEqual(first?.durationMs, 12_000, "a reply's time runs from the prompt")
    check(first?.cost == nil, "Gemini's calls aren't priced yet")
    check(first?.isSidechain == false && first?.agent == nil, "a session's own calls aren't a subagent's")

    let second = scan.samples.first { $0.id.hasSuffix("/g2") }
    expectEqual(second?.model, "Gemini 2.5 Pro", "a reply with no model has the model of the reply before")
    expectEqual(second?.input, 1000, "its tokens are the copy that has them")
    expectEqual(second?.durationMs, 5000, "a reply after a tool's result runs from the result")

    let flash = scan.samples.first { $0.id.hasSuffix("/w1") }
    expectEqual(flash?.input, 520, "tool-use prompt tokens count as input")
    expectEqual(flash?.model, "Gemini 3 Flash Preview", "a preview model is named as one")

    let subagent = scan.samples.first { $0.id.hasSuffix("/x2") }
    expectEqual(subagent?.sessionID, "bbbb0002-0000-4000-8000-000000000002", "a subagent's calls belong to the session its folder names")
    expectEqual(subagent?.agent, "cccc0003-0000-4000-8000-000000000003", "and are marked as the subagent's")
    expectEqual(subagent?.isSidechain, true, "a subagent's calls are side calls")
    expectEqual(subagent?.output, 50, "with their reasoning in output")

    let older = scan.samples.filter { $0.sessionID == "dddd0004-0000-4000-8000-000000000004" }
    expectEqual(older.map(\.project), [olderPath, olderPath], "a folder named by its path's SHA-256 is found through projects.json")
    expectEqual(older.last?.cacheRead, 900, "the copied session's new reply counts too")
    expectEqual(scan.samples.last?.model, "Gemini 2.5 Flash Lite", "the sandbox's logs in ~/.cache/.gemini are read")

    expectEqual(scan.titles["aaaa0001-0000-4000-8000-000000000001"], "Add a dark mode toggle to settings", "a session's summary is its title, as in Gemini CLI's session list")
    expectEqual(scan.titles["bbbb0002-0000-4000-8000-000000000002"], "Why does the build fail on CI?", "without one, its first prompt's first line, after commands")
    expectEqual(scan.titles["dddd0004-0000-4000-8000-000000000004"], "Rename the helper", "an older session's title is read from its document")
    check(scan.titles["cccc0003-0000-4000-8000-000000000003"] == nil, "a subagent's prompt doesn't name a session")

    let later = GeminiUsage.scan(home: home.path, since: utc("2026-11-17T10:00:00Z"))
    expectEqual(later.samples.map(\.id).map { String($0.suffix(2)) }, ["w1", "x2", "o4", "y1"], "calls before the period are left out")

    let document = GeminiUsage.parse(Data(#"{"sessionId":"s","messages":[{"id":"m","timestamp":"2026-11-17T09:00:00.000Z","type":"gemini","tokens":{"input":10,"output":1,"cached":0}}]}"#.utf8),
                                     fileName: "session-x.json", project: nil, since: .distantPast)
    expectEqual(document.samples.first?.model, "", "a call with no model at all keeps an empty name")
    expectEqual(document.samples.first?.output, 1, "and a summary without thoughts or tool counts reads as zero")

    // MARK: Names

    expectEqual(GeminiUsage.displayName(for: "gemini-2.5-flash-lite"), "Gemini 2.5 Flash Lite", "a model's words are spelled out")
    expectEqual(GeminiUsage.displayName(for: "gemini-2.5-flash-preview-05-20"), "Gemini 2.5 Flash Preview", "dates are left out")
    expectEqual(GeminiUsage.displayName(for: "models/gemini-1.5-pro-002"), "Gemini 1.5 Pro", "and build numbers and the models/ prefix")
    expectEqual(GeminiUsage.title(from: "<session_context>\nThis is Gemini CLI."), nil, "context Gemini CLI adds doesn't name a session")
    expectEqual(GeminiUsage.title(from: String(repeating: "a", count: 100))?.count, 80, "a long prompt is cut short")

    // MARK: Limits

    let quota = Data("""
    {"buckets":[
      {"remainingAmount":"1125","remainingFraction":0.75,"resetTime":"2026-11-18T00:00:00Z","tokenType":"REQUESTS","modelId":"gemini-2.5-pro"},
      {"remainingFraction":0.5,"resetTime":"2026-11-18T00:00:00.123456789Z","tokenType":"REQUESTS","modelId":"gemini-2.5-flash"},
      {"remainingFraction":0.25,"resetTime":"2026-11-18T06:00:00Z","tokenType":"TOKENS","modelId":"gemini-2.5-flash"},
      {"remainingFraction":1,"modelId":""},
      {"resetTime":"2026-11-18T00:00:00Z","modelId":"gemini-2.5-flash-lite"}
    ]}
    """.utf8)
    let now = utc("2026-11-17T12:00:00Z")
    let reading = try GeminiUsage.reading(quota: quota, plan: "Code Assist Standard", at: now).get()
    expectEqual(reading.windows.map(\.id), ["gemini-2.5-pro", "gemini-2.5-flash"], "a window per model, in Google's order; buckets without a model or a fraction are left out")
    expectEqual(reading.windows.first, LimitWindow(id: "gemini-2.5-pro", title: "Gemini 2.5 Pro · daily", utilization: 25,
                                                   resetsAt: utc("2026-11-18T00:00:00Z"), span: 86400),
                "a bucket's used share is what's not left, as a daily window")
    expectEqual(reading.windows.last?.utilization, 75, "a model with two buckets shows the one with least left")
    expectEqual(reading.windows.last?.resetsAt, utc("2026-11-18T06:00:00Z"), "with its reset")
    expectEqual(reading.plan, "Code Assist Standard", "the reading carries the plan")
    expectEqual(reading.fetchedAt, now, "and when it was read")
    let nanos = try GeminiUsage.reading(quota: Data(#"{"buckets":[{"remainingFraction":0.5,"resetTime":"2026-11-18T00:00:00.123456789Z","modelId":"gemini-2.5-pro"}]}"#.utf8), plan: nil, at: now).get()
    let fraction = nanos.windows.first?.resetsAt?.timeIntervalSince(utc("2026-11-18T00:00:00Z")) ?? 0
    check(abs(fraction - 0.123) < 0.001, "a reset with nanoseconds is read")
    expectEqual(GeminiUsage.reading(quota: Data(#"{"buckets":[]}"#.utf8), plan: nil, at: now), .failure(.noLimits(GeminiUsage.Says.noBuckets)), "no buckets, no limits")
    expectEqual(GeminiUsage.reading(quota: Data("[1]".utf8), plan: nil, at: now), .failure(.unreadable), "an answer in another shape is unreadable")

    func account(_ json: String, project: String? = nil) -> Result<GeminiUsage.Account, LimitProblem> {
        GeminiUsage.account(loadCodeAssist: Data(json.utf8), project: project)
    }
    expectEqual(account(#"{"currentTier":{"id":"standard-tier","name":"Gemini Code Assist Standard"},"cloudaicompanionProject":"sample-project-123"}"#),
                .success(GeminiUsage.Account(project: "sample-project-123", plan: "Code Assist Standard")), "a Code Assist account's project and plan come from loadCodeAssist")
    expectEqual(account(#"{"currentTier":{"id":"standard-tier"},"paidTier":{"id":"enterprise-tier","name":"Gemini Code Assist Enterprise"}}"#, project: "sample-env-project"),
                .success(GeminiUsage.Account(project: "sample-env-project", plan: "Code Assist Enterprise")), "the paid tier names the plan, and the project Gemini CLI sent stands in when none comes back")
    expectEqual(account(#"{"currentTier":{"id":"standard-tier"}}"#), .failure(.notSignedIn(GeminiUsage.Says.noProject)), "without a project there's nothing to ask about")
    expectEqual(account(#"{"currentTier":{"id":"free-tier","name":"Gemini Code Assist for individuals"},"cloudaicompanionProject":"sample-managed"}"#),
                .failure(.noLimits(GeminiUsage.Says.personal)), "a personal account has no limits to read")
    expectEqual(account(#"{"allowedTiers":[{"id":"free-tier","isDefault":true}]}"#), .failure(.notSignedIn(GeminiUsage.Says.notSetUp)), "an account Gemini CLI hasn't set up isn't signed in")
    expectEqual(GeminiUsage.planName(tierID: "standard-tier", tierName: nil), "Code Assist Standard", "a tier with no name is named from its id")

    let body = GeminiUsage.loadBody(project: "sample-project-123")
    check(body["cloudaicompanionProject"] as? String == "sample-project-123"
            && (body["metadata"] as? [String: Any])?["duetProject"] as? String == "sample-project-123"
            && (body["metadata"] as? [String: Any])?["pluginType"] as? String == "GEMINI",
          "loadCodeAssist is asked as Gemini CLI asks it")
    check(GeminiUsage.loadBody(project: nil)["cloudaicompanionProject"] == nil, "with no project, none is sent")
    expectEqual(GeminiUsage.project(dotenv: "# made up\nexport GOOGLE_CLOUD_PROJECT=\"sample-project\"\nOTHER=1\n"), "sample-project", "the project is read from a .env line")
    expectEqual(GeminiUsage.project(dotenv: "GOOGLE_CLOUD_PROJECT_ID=sample-id\n"), "sample-id", "or from its other name")
    expectEqual(GeminiUsage.cloudProject(home: home.path, environment: [:]), nil, "no environment and no .env, no project")
    try "GOOGLE_CLOUD_PROJECT=sample-file-project\n".write(to: gemini.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    expectEqual(GeminiUsage.cloudProject(home: home.path, environment: [:]), "sample-file-project", "~/.gemini/.env names the project")
    expectEqual(GeminiUsage.cloudProject(home: home.path, environment: ["GOOGLE_CLOUD_PROJECT": "sample-env"]), "sample-env", "the environment comes first, as for Gemini CLI")

    expectEqual(GeminiUsage.problem(status: 200), nil, "a success is no problem")
    expectEqual(GeminiUsage.problem(status: 401), .expired(GeminiUsage.Says.turnedDown), "a turned-down token means signing in again")
    expectEqual(GeminiUsage.problem(status: 403), .notSignedIn(GeminiUsage.Says.refused), "a refused account says which accounts work")
    expectEqual(GeminiUsage.problem(status: 429), .http(429), "other statuses are the status")

    // MARK: Sign-in, without the network

    expectEqual(GeminiUsage.authType(settings: Data("{\n  // chosen in /auth\n  \"security\": { \"auth\": { \"selectedType\": \"gemini-api-key\" } },\n}".utf8)), "gemini-api-key", "the sign-in is read from settings.json, comments and all")
    expectEqual(GeminiUsage.authType(settings: Data(#"{"selectedAuthType":"oauth-personal"}"#.utf8)), "oauth-personal", "and from older Gemini CLI's key")
    expectEqual(GeminiUsage.problem(authType: "oauth-personal"), nil, "Google sign-in goes on to the limits")

    let farFuture = utc("2100-01-01T00:00:00Z").timeIntervalSince1970 * 1000
    let past = utc("2026-11-17T08:00:00Z").timeIntervalSince1970 * 1000
    func credentials(expiry: Double) -> Data {
        Data(#"{"access_token":"made-up-access-token","refresh_token":"made-up-refresh-token","scope":"openid","token_type":"Bearer","expiry_date":\#(Int(expiry))}"#.utf8)
    }
    let token = GeminiUsage.accessToken(credentials: credentials(expiry: farFuture), now: now)
    check((try? token.get()) == "made-up-access-token", "a token that lasts is used as it is")
    expectEqual(GeminiUsage.accessToken(credentials: credentials(expiry: past), now: now), .failure(.expired(GeminiUsage.Says.expired)), "a token past its expiry has run out")
    expectEqual(GeminiUsage.accessToken(credentials: Data("{}".utf8), now: now), .failure(.notSignedIn(GeminiUsage.Says.notSignedIn)), "credentials without a token aren't a sign-in")

    let settingsURL = gemini.appendingPathComponent("settings.json")
    let credentialsURL = gemini.appendingPathComponent("oauth_creds.json")
    expectEqual(awaitGemini { await GeminiUsage.limits(home: home.path) }, .failure(.notSignedIn(GeminiUsage.Says.notSignedIn)), "without oauth_creds.json, Gemini CLI isn't signed in")

    try #"{"security":{"auth":{"selectedType":"gemini-api-key"}}}"#.write(to: settingsURL, atomically: true, encoding: .utf8)
    try credentials(expiry: farFuture).write(to: credentialsURL)
    expectEqual(awaitGemini { await GeminiUsage.limits(home: home.path) }, .failure(.noLimits(GeminiUsage.Says.apiKey)), "an API key has no plan limits, whatever sign-in is left")

    try #"{"security":{"auth":{"selectedType":"vertex-ai"}}}"#.write(to: settingsURL, atomically: true, encoding: .utf8)
    expectEqual(awaitGemini { await GeminiUsage.limits(home: home.path) }, .failure(.noLimits(GeminiUsage.Says.vertex)), "nor does Vertex AI")

    try #"{"security":{"auth":{"selectedType":"oauth-personal"}}}"#.write(to: settingsURL, atomically: true, encoding: .utf8)
    try credentials(expiry: past).write(to: credentialsURL)
    let before = try Data(contentsOf: credentialsURL)
    expectEqual(awaitGemini { await GeminiUsage.limits(home: home.path) }, .failure(.expired("Gemini CLI's sign-in ran out. Open Gemini CLI to renew it.")), "an expired sign-in asks for Gemini CLI, not the network")
    check((try? Data(contentsOf: credentialsURL)) == before, "Gemini CLI's sign-in is left as it was")
}

private final class GeminiBox<T>: @unchecked Sendable { var value: T? }

/// Waits for an async call from the checks' synchronous code.
private func awaitGemini<T>(_ body: @escaping () async -> T) -> T {
    let box = GeminiBox<T>()
    let done = DispatchSemaphore(value: 0)
    Task.detached {
        box.value = await body()
        done.signal()
    }
    done.wait()
    return box.value!
}

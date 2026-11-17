import Foundation

// Checks for the Usage page's engine, ported from Claude Usage: reading Claude Code's sign-in,
// decoding the plan-limits answer, naming models, and counting calls in transcripts. Nothing here
// reads the keychain or goes to the network. Called from main.swift.

func usageChecks() throws {
    let now = utc("2026-11-17T12:00:00Z")

    // MARK: Claude Code's sign-in

    let credentials = #"{"claudeAiOauth": {"accessToken": "test-access-token", "refreshToken": "test-refresh-token", "expiresAt": 1795435200000, "scopes": ["user:inference"]}}"#
    if case .success(let token) = ClaudeCodeSignIn.decode(Data(credentials.utf8)) {
        expectEqual(token.accessToken, "test-access-token", "the borrowed token is Claude Code's access token")
        expectEqual(token.expiresAt, Date(timeIntervalSince1970: 1_795_435_200), "its end is read from milliseconds")
        check(!token.isExpired(now: now), "a token ending next year is good")
        check(token.isExpired(now: Date(timeIntervalSince1970: 1_795_435_200 - 30)), "a token half a minute from its end counts as run out")
    } else {
        check(false, "Claude Code's keychain item is read")
    }
    expectEqual(ClaudeCodeSignIn.decode(Data(#"{"mcpOAuth": {}}"#.utf8)), .failure(.notSignedIn), "an item without a Claude sign-in means signed out")
    expectEqual(ClaudeCodeSignIn.decode(Data("not json".utf8)), .failure(.unreadable), "an item in another shape is unreadable, not signed out")
    if case .success(let token) = ClaudeCodeSignIn.decode(Data(#"{"claudeAiOauth": {"accessToken": "x"}}"#.utf8)) {
        check(!token.isExpired(now: now), "a token with no end date is used")
    } else {
        check(false, "a token with no end date is read")
    }

    // MARK: The plan's limits

    let answer = #"""
    {"five_hour": {"utilization": 42.0, "resets_at": "2026-11-17T15:00:00.123+00:00"},
     "seven_day": {"utilization": 19, "resets_at": "2026-11-20T08:00:00+00:00"},
     "seven_day_opus": null,
     "seven_day_sonnet": {"utilization": 3, "resets_at": null},
     "extra_usage": {"is_enabled": true, "monthly_limit": 50, "used_credits": 12.5, "currency": "USD"},
     "limits": [
       {"kind": "session", "percent": 42},
       {"kind": "weekly_scoped", "percent": 7, "resets_at": "2026-11-20T08:00:00Z", "scope": {"model": {"display_name": "Fable 5.2"}}},
       {"kind": "weekly_scoped", "percent": 2, "scope": {"surface": {"display_name": "Claude Code"}}},
       {"kind": "something_new", "percent": "not a number"}
     ]}
    """#
    let reading = UsageAPI.decodeUsage(Data(answer.utf8), at: now)
    expectEqual(reading?.session?.utilization, 42, "the session limit is read")
    check(abs((reading?.session?.resetsAt ?? .distantPast).timeIntervalSince(utc("2026-11-17T15:00:00Z")) - 0.123) < 0.01, "its reset is read, fraction of a second and all")
    expectEqual(reading?.weekly?.utilization, 19, "the weekly limit is read")
    expectEqual(reading?.weeklyFable?.utilization, 7, "the Fable row of limits[] is the Fable weekly limit")
    check(reading?.weeklyOpus == nil, "a null window isn't shown")
    expectEqual(reading?.weeklySonnet?.utilization, 3, "a window without a reset is still read")
    expectEqual(reading?.extra?.utilization, 25, "extra usage is credits used over the monthly limit")
    expectEqual(reading?.fetchedAt, now, "the reading is stamped when it was read")

    let notStarted = UsageAPI.decodeUsage(Data(#"{"five_hour": null, "seven_day": {"utilization": 5}}"#.utf8))
    expectEqual(notStarted?.session?.utilization, 0, "a session that hasn't started reads 0%, not missing")
    check(notStarted?.session?.resetsAt == nil, "a session that hasn't started has no reset")
    check(UsageAPI.decodeUsage(Data("[]".utf8)) == nil, "an answer in another shape is turned down")
    check(UsageAPI.decodeUsage(Data("{}".utf8))?.session == nil, "an empty answer shows no limits")

    // MARK: Model names

    expectEqual(TranscriptStats.displayName(for: "claude-opus-5-5"), "Opus 5.5", "model ids get their family and version")
    expectEqual(TranscriptStats.displayName(for: "claude-sonnet-4-6-20250930"), "Sonnet 4.6", "a dated id drops the date")
    expectEqual(TranscriptStats.displayName(for: "claude-fable-5-2[1m]"), "Fable 5.2", "a context-window suffix is dropped")
    expectEqual(TranscriptStats.displayName(for: "claude-haiku"), "Haiku", "an id with no version keeps its family")

    // MARK: Counting calls in transcripts

    let root = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-usage-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let project = root.appendingPathComponent(".claude/projects/-Users-test-app")
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    TranscriptStats.cacheFolder = root
    defer { TranscriptStats.cacheFolder = nil }

    func reply(_ id: String, at time: String, output: Int, cacheRead: Int = 0, model: String = "claude-opus-5-5") -> String {
        #"{"type":"assistant","timestamp":"\#(time)","sessionId":"s1","cwd":"/Users/test/app","entrypoint":"claude-desktop","message":{"id":"\#(id)","model":"\#(model)","usage":{"input_tokens":10,"output_tokens":\#(output),"cache_read_input_tokens":\#(cacheRead),"cache_creation_input_tokens":100,"cache_creation":{"ephemeral_1h_input_tokens":100}}}}"#
    }
    let lines = [
        #"{"type":"user","message":{"role":"user","content":"hi"},"timestamp":"2026-11-17T10:00:00.000Z"}"#,
        // One reply in two content blocks: the usage repeats, and the last line has the final count.
        reply("m1", at: "2026-11-17T10:00:04.000Z", output: 5),
        reply("m1", at: "2026-11-17T10:00:08.000Z", output: 40, cacheRead: 1000),
        reply("m2", at: "2026-11-17T10:01:00.000Z", output: 7),
        #"{"type":"assistant","timestamp":"2026-11-17T10:02:00.000Z","sessionId":"s1","isApiErrorMessage":true,"error":"rate_limit","message":{"id":"e1","model":"<synthetic>"}}"#,
        #"{"type":"ai-title","sessionId":"s1","aiTitle":"Fix the build"}"#,
        "not json at all",
    ]
    try lines.joined(separator: "\n").write(to: project.appendingPathComponent("s1.jsonl"), atomically: true, encoding: .utf8)

    let scan = TranscriptStats.scan(claudeFolder: root.appendingPathComponent(".claude"), since: .distantPast)
    let calls = scan.samples.sorted { $0.ts < $1.ts }
    expectEqual(calls.count, 3, "two replies and a failed call; repeated lines of one reply count once")
    expectEqual(calls.first?.output, 40, "a reply's last line has its final count")
    expectEqual(calls.first?.cacheRead, 1000, "cache reads come from the same last line")
    expectEqual(calls.first?.durationMs, 8000, "a reply's time runs from the prompt to its last line")
    expectEqual(calls.first?.model, "Opus 5.5", "calls carry the model's name")
    expectEqual(calls.first?.app, "claude-desktop", "calls carry the app that sent them")
    check((calls.first?.cost ?? 0) > 0, "a known model's call is priced")
    expectEqual(calls.last?.error, "rate_limit", "an API error is a failed call")
    expectEqual(calls.last?.tokens, 0, "a failed call has no tokens")
    expectEqual(scan.titles["s1"], "Fix the build", "the session's title is read")

    let again = TranscriptStats.scan(claudeFolder: root.appendingPathComponent(".claude"), since: .distantPast)
    expectEqual(again.samples.count, 3, "a second scan from the cache finds the same calls")
    check(FileManager.default.fileExists(atPath: root.appendingPathComponent("transcript-cache-v5.json").path), "the checks' cache stays in their own folder")
    let later = TranscriptStats.scan(claudeFolder: root.appendingPathComponent(".claude"), since: utc("2026-11-17T10:00:30Z"))
    expectEqual(later.samples.count, 2, "calls before the start of the period are left out")
}

// Checks for what the Usage page works out from a reading and from calls: windows that have reset,
// connection failures, the sums and groupings it draws, and the run-out forecast.
func usageSummaryChecks() throws {
    let now = utc("2026-11-17T12:00:00Z")
    let hour: TimeInterval = 3600
    let day: TimeInterval = 86400

    // MARK: A stored reading, later

    let stored = UsageSnapshot(
        fetchedAt: now.addingTimeInterval(-6 * hour),
        session: UsageWindow(utilization: 85, resetsAt: now.addingTimeInterval(-hour)),
        weekly: UsageWindow(utilization: 40, resetsAt: now.addingTimeInterval(2 * day)),
        weeklyOpus: nil, weeklySonnet: nil,
        extra: ExtraUsage(isEnabled: true, monthlyLimit: 50, usedCredits: 10, currency: "USD"),
        weeklyFable: UsageWindow(utilization: 0, resetsAt: nil)
    )
    let current = stored.asOf(now)
    expectEqual(current.session, UsageWindow(utilization: 0, resetsAt: nil), "a session whose reset has passed reads 0% and not started")
    expectEqual(current.weekly, stored.weekly, "a window still running keeps its figure")
    expectEqual(current.weeklyFable, stored.weeklyFable, "a window with no reset is left as it is")
    expectEqual(current.extra, stored.extra, "extra usage has no window and is left as it is")
    expectEqual(current.fetchedAt, stored.fetchedAt, "the reading keeps when it was read")
    expectEqual(stored.session?.asOf(now.addingTimeInterval(-2 * hour)), stored.session, "before its reset a window is unchanged")

    // MARK: Connection failures

    expectEqual(UsageAPIError.from(URLError(.notConnectedToInternet)), .offline, "no internet is offline")
    expectEqual(UsageAPIError.from(URLError(.timedOut)), .offline, "a timeout reads as offline")
    expectEqual(UsageAPIError.from(URLError(.secureConnectionFailed)), .network(URLError.secureConnectionFailed.rawValue), "other connection failures keep their code")
    expectEqual(UsageAPIError.from(UsageAPIError.tokenExpired), .tokenExpired, "the page's own errors pass through")
    check(UsageAPIError.offline.errorDescription?.contains("HTTP") == false, "offline never says HTTP 0")
    check(AICatalog.codingTools.contains { $0.id == ClaudeCodeSignIn.connectionID }, "the sign-in notice reads Claude Code's own health check")

    // MARK: Sums and groupings

    func call(_ id: String, at: Date, session: String = "s1", cwd: String? = "/Users/t/app", app: String? = "claude-desktop",
              input: Int = 10, output: Int = 100, cacheRead: Int = 1000, error: String? = nil) -> TokenSample {
        TokenSample(id: id, ts: at, model: error == nil ? "Opus 5.5" : "", input: error == nil ? input : 0,
                    output: error == nil ? output : 0, cacheRead: error == nil ? cacheRead : 0, cacheWrite: 0, cacheWrite1h: 0, thinking: 0, sessionID: session,
                    project: cwd, app: app, effort: nil, isSidechain: false, agent: nil, error: error,
                    durationMs: 2000, cost: error == nil ? 0.5 : 0)
    }

    expectEqual(UsageSummary.projectPath("/Users/t/app/.claude/worktrees/fix-build"), "/Users/t/app", "a worktree counts toward its repository")
    expectEqual(UsageSummary.projectPath("/Users/t/Library/Application Support/Claude/local-agent-mode-sessions/a/b"), "/Users/t/Library/Application Support/Claude", "Claude Desktop's agent sessions count as one project")
    expectEqual(UsageSummary.projectName("/Users/t/Library/Application Support/Claude"), "Claude Desktop", "that project is called Claude Desktop")
    expectEqual(UsageSummary.appKey("sdk-cli"), "sdk", "every SDK entry point is one app")
    expectEqual(UsageSummary.appKey(nil), "other", "a call with no app is Other")

    let filed = UsageSummary.fileBySessionFolder([
        call("a", at: now.addingTimeInterval(-3 * hour), cwd: "/Users/t/app"),
        call("b", at: now.addingTimeInterval(-2 * hour), cwd: "/Users/t/app/packages/web"),
    ])
    expectEqual(filed.map(\.project), ["/Users/t/app", "/Users/t/app"], "a session's calls stay under the folder it started in")

    let calls = [
        call("old", at: now.addingTimeInterval(-10 * day)),
        call("a", at: now.addingTimeInterval(-3 * hour)),
        call("b", at: now.addingTimeInterval(-2 * hour), session: "s2", cwd: "/Users/t/app/.claude/worktrees/x", app: "sdk-cli"),
        call("c", at: now.addingTimeInterval(-hour), session: "s2", error: "overloaded"),
    ]
    let week = UsageSummary.summarize(calls, period: .week, now: now)
    expectEqual(week.totals.requests, 3, "a week's sums leave out calls before it")
    expectEqual(week.totals.failed, 1, "failed calls are counted")
    expectEqual(week.totals.sessions, 2, "sessions are counted once each")
    expectEqual(week.totals.output, 200, "output adds up")
    expectEqual(week.totals.cost, 1.0, "cost adds up, failures at nothing")
    expectEqual(Set(week.apps.map(\.id)), ["claude-desktop", "sdk"], "calls are split by app")
    expectEqual(week.projects.map(\.id), ["/Users/t/app"], "a worktree's calls join its repository's")
    expectEqual(week.models.map(\.id), ["Opus 5.5"], "a failed call isn't a model")
    expectEqual(week.barUnit, .hour, "calls within a few hours are charted by the hour, even over a week")
    expectEqual(week.bars.reduce(0) { $0 + $1.requests }, 2, "the chart leaves failed calls out")

    let projects = UsageSummary.groupSessions(calls, titles: ["s2": "Fix the build"], range: now.addingTimeInterval(-day)...now)
    let sessions = projects.flatMap(\.sessions)
    expectEqual(sessions.count, 2, "both sessions active in the day are listed")
    expectEqual(sessions.first { $0.id == "s2" }?.title, "Fix the build", "a session carries its title")
    expectEqual(sessions.first { $0.id == "s1" }?.requests, 2, "a session counts all its calls, even ones before the range")

    // MARK: Run-out forecast

    let reset = now.addingTimeInterval(3.5 * day)
    func line(_ lefts: [Double]) -> [TrendPoint] {
        lefts.enumerated().map { index, left in
            TrendPoint(at: now.addingTimeInterval(Double(index - lefts.count + 1) * day), left: left, reset: reset)
        }
    }
    let cycle = CurrentCycle(start: reset.addingTimeInterval(-7 * day), reset: reset)
    if case .runsOut(let date) = UsageTrends.forecast(points: line([100, 80, 60, 40]), cycle: cycle, now: now) {
        check(abs(date.timeIntervalSince(now.addingTimeInterval(2 * day))) < hour, "20% a day with 40% left runs out in two days")
    } else {
        check(false, "a fast week is forecast to run out")
    }
    expectEqual(UsageTrends.forecast(points: line([100, 98, 96, 94]), cycle: cycle, now: now), .lastsPastReset, "a slow week lasts past its reset")
    check(UsageTrends.forecast(points: line([90, 80]), cycle: cycle, now: now) == nil, "two readings are too few to forecast")
    expectEqual(UsageTrends.currentCycle(of: nil, window: UsageWindow(utilization: 40, resetsAt: reset), now: now), nil, "no line, no cycle")
}

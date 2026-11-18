import Foundation

// Checks for GitHub Copilot's usage. The event lines follow the Copilot SDK's session events
// (github/copilot-sdk, session-events.ts) as Copilot CLI writes them to
// ~/.copilot/session-state/<id>/events.jsonl. The quota answers are made up in the shape of
// GitHub's copilot_internal/user: an annual plan with premium requests, a monthly one on AI Credits,
// Copilot Free and an unlimited plan. Nothing here reads the real ~/.copilot, runs the real `gh` or
// reaches the network. Called from main.swift.

func copilotChecks() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-copilot-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: home) }
    let sessions = home.appendingPathComponent(".copilot/session-state")

    func write(_ session: String, _ lines: [String], modified: String) throws {
        let folder = sessions.appendingPathComponent(session)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("events.jsonl")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: utc(modified)], ofItemAtPath: url.path)
    }

    func event(_ type: String, _ id: String, _ time: String, _ data: String, agent: String? = nil, ephemeral: Bool = false) -> String {
        let extra = (agent.map { #","agentId":"\#($0)""# } ?? "") + (ephemeral ? #","ephemeral":true"# : "")
        return #"{"type":"\#(type)","data":\#(data),"id":"\#(id)","timestamp":"2026-11-17T\#(time).000Z","parentId":null\#(extra)}"#
    }

    // MARK: Logs

    check(!CopilotUsage.hasLogs(home: home.path), "no ~/.copilot, no logs")
    try FileManager.default.createDirectory(at: sessions.appendingPathComponent("empty-session"), withIntermediateDirectories: true)
    try "cwd: /Users/t/app\n".write(to: sessions.appendingPathComponent("empty-session/workspace.yaml"), atomically: true, encoding: .utf8)
    check(!CopilotUsage.hasLogs(home: home.path), "a session folder without events.jsonl isn't a log")

    let first = "0a1b2c3d-1111-4000-8000-000000000001"
    try write(first, [
        event("session.start", "e1", "09:00:00", #"{"sessionId":"\#(first)","version":1,"producer":"copilot-agent","copilotVersion":"1.0.20","startTime":"2026-11-17T09:00:00.000Z","selectedModel":"claude-sonnet-4.5","context":{"cwd":"/Users/t/app","gitRoot":"/Users/t/app","branch":"main"}}"#),
        event("user.message", "e2", "09:00:05", #"{"content":"Add a dark mode toggle\nKeep it small.","transformedContent":"<context>…</context>Add a dark mode toggle","attachments":[],"agentMode":"interactive"}"#),
        event("assistant.message", "e3", "09:00:12", #"{"messageId":"m1","content":"I'll look at the settings view first.","toolRequests":[{"toolCallId":"t1","name":"view","arguments":{"path":"Settings.swift"}}],"outputTokens":420}"#),
        event("tool.execution_complete", "e4", "09:00:13", #"{"toolCallId":"t1","success":true,"result":{"content":"a file that mentions \"assistant.message\""}}"#),
        // Ephemeral events aren't normally written; one that is isn't a call.
        event("assistant.message", "e5", "09:00:14", #"{"messageId":"m-ephemeral","content":"","outputTokens":999}"#, ephemeral: true),
        event("session.model_change", "e6", "09:01:00", #"{"previousModel":"claude-sonnet-4.5","newModel":"gpt-5.1-codex","reasoningEffort":"high"}"#),
        event("assistant.message", "e7", "09:01:30", #"{"messageId":"m2","content":"Done.","outputTokens":35}"#),
        // A subagent's reply, naming its own model.
        event("assistant.message", "e8", "09:02:00", #"{"messageId":"m3","content":"Found two call sites.","outputTokens":12.0,"model":"claude-haiku-4.5"}"#, agent: "explore-1"),
        // A reply without a count still is a call.
        event("assistant.message", "e9", "09:02:30", #"{"messageId":"m4","content":"All set."}"#),
        event("session.shutdown", "e10", "09:03:00", #"{"shutdownType":"routine","totalPremiumRequests":3,"totalApiDurationMs":21000,"sessionStartTime":1795424400000,"codeChanges":{"linesAdded":12,"linesRemoved":2,"filesModified":["Settings.swift"]},"modelMetrics":{"claude-sonnet-4.5":{"requests":{"count":1,"cost":1},"usage":{"inputTokens":9000,"outputTokens":420,"cacheReadTokens":8000,"cacheWriteTokens":0}}},"currentModel":"gpt-5.1-codex"}"#),
        "not json",
    ], modified: "2026-11-17T09:03:00Z")

    // A session picked up again later: no session.start, so its folder names it.
    let second = "0a1b2c3d-2222-4000-8000-000000000002"
    try write(second, [
        event("session.resume", "f1", "10:00:00", #"{"eventCount":40,"resumeTime":"2026-11-17T10:00:00.000Z","selectedModel":"gpt-5-mini"}"#),
        event("user.message", "f2", "10:00:10", #"{"content":"\n  Rename the toggle  \n"}"#),
        event("assistant.message", "f3", "10:00:20", #"{"messageId":"n1","content":"Renamed.","outputTokens":80}"#),
        // The same reply copied into another log counts once.
        event("assistant.message", "e7", "09:01:30", #"{"messageId":"m2","content":"Done.","outputTokens":35}"#),
    ], modified: "2026-11-17T10:00:20Z")

    check(CopilotUsage.hasLogs(home: home.path), "a session's events.jsonl is a log")

    let scan = CopilotUsage.scan(home: home.path, since: .distantPast)
    expectEqual(scan.samples.map(\.id), ["copilot:m1", "copilot:m2", "copilot:m3", "copilot:m4", "copilot:n1"],
                "one call per reply, oldest first; ephemeral, tool and shutdown lines aren't calls, and a copied reply counts once")
    let reply = scan.samples.first
    expectEqual(reply?.output, 420, "a reply's output tokens are its outputTokens")
    expectEqual(reply.map { [$0.input, $0.cacheRead, $0.cacheWrite, $0.thinking] }, [0, 0, 0, 0], "Copilot doesn't write the other counts")
    check(reply?.cost == nil, "so a call has no cost")
    expectEqual(reply?.model, "Sonnet 4.5", "the model comes from the session's start, with Claude's dotted version")
    expectEqual(reply?.sessionID, first, "calls belong to the session")
    expectEqual(reply?.project, "/Users/t/app", "and carry its folder")
    expectEqual(reply?.app, "copilot-cli", "Copilot CLI's sessions are its own app")
    expectEqual(reply?.durationMs, 7000, "a reply's time runs from the prompt")
    expectEqual(scan.samples[1].model, "GPT-5.1 Codex", "a model change applies to the replies after it")
    expectEqual(scan.samples[1].effort, "high", "with its reasoning effort")
    expectEqual(scan.samples[2].model, "Haiku 4.5", "a reply that names its model keeps it")
    expectEqual(scan.samples[2].output, 12, "a count written as a fraction is still read")
    check(scan.samples[2].isSidechain && scan.samples[2].agent == "explore-1", "a subagent's reply is marked as its")
    check(!scan.samples[1].isSidechain && scan.samples[1].agent == nil, "the main conversation's isn't")
    expectEqual(scan.samples[3].output, 0, "a reply without a count is a call with none")
    expectEqual(scan.samples[4].sessionID, second, "a resumed session without its start is named by its folder")
    expectEqual(scan.samples[4].model, "GPT-5 Mini", "and its model comes from the resume")
    expectEqual(scan.titles[first], "Add a dark mode toggle", "a session's first prompt stands for its title")
    expectEqual(scan.titles[second], "Rename the toggle", "trimmed to its first line")

    let later = CopilotUsage.scan(home: home.path, since: utc("2026-11-17T09:01:45Z"))
    expectEqual(later.samples.map(\.id), ["copilot:m3", "copilot:m4", "copilot:n1"], "calls before the period are left out")

    expectEqual(CopilotUsage.displayName(for: "claude-opus-4.6"), "Opus 4.6", "Claude's models are named as Claude Code's are")
    expectEqual(CopilotUsage.displayName(for: "gemini-3-pro-preview"), "Gemini 3 Pro Preview", "others word by word")

    // MARK: Limits

    let now = utc("2026-11-18T08:00:00Z")
    func reading(_ json: String) -> Result<LimitReading, LimitProblem> {
        CopilotUsage.reading(from: Data(json.utf8), at: now)
    }
    let unlimitedChat = #""chat":{"entitlement":0,"remaining":0,"percent_remaining":100.0,"quota_id":"chat","unlimited":true,"overage_count":0,"overage_permitted":false}"#
    let unlimitedCompletions = #""completions":{"entitlement":0,"remaining":0,"percent_remaining":100.0,"quota_id":"completions","unlimited":true,"overage_count":0,"overage_permitted":false}"#

    // An annual Pro plan, still on premium requests.
    let annual = reading(#"{"login":"sample-user","access_type_sku":"yearly_subscriber_quota","copilot_plan":"individual","chat_enabled":true,"token_based_billing":false,"quota_reset_date":"2026-12-01","quota_snapshots":{\#(unlimitedChat),\#(unlimitedCompletions),"premium_interactions":{"entitlement":300,"remaining":62,"quota_remaining":62.0,"percent_remaining":20.666666666666668,"quota_id":"premium_interactions","unlimited":false,"overage_count":0,"overage_permitted":true}}}"#)
    let premium = try? annual.get()
    expectEqual(premium?.plan, "Copilot Pro", "the plan is named from copilot_plan")
    expectEqual(premium?.windows.map(\.id), ["premium"], "unlimited chat and completions are left out")
    expectEqual(premium?.windows.first?.title, "Premium requests", "a plan not billed by tokens counts premium requests")
    check(abs((premium?.windows.first?.utilization ?? 0) - 79.333) < 0.001, "used is 100 less the share remaining")
    expectEqual(premium?.windows.first?.detail, "238 of 300 used", "with the count under the bar")
    expectEqual(premium?.windows.first?.resetsAt, utc("2026-12-01T00:00:00Z"), "a reset date is midnight UTC")
    expectEqual(premium?.windows.first?.span, 30 * 86400, "and a cycle is the month before it")
    expectEqual(premium?.fetchedAt, now, "a reading is as of the request")

    // A monthly Pro+ plan, on AI Credits.
    let monthly = reading(#"{"access_type_sku":"monthly_subscriber_quota","copilot_plan":"individual_pro","token_based_billing":true,"quota_reset_date":"2026-12-01","quota_reset_date_utc":"2026-12-01T00:00:00.000Z","quota_snapshots":{\#(unlimitedCompletions),"premium_interactions":{"entitlement":"7000","remaining":4550,"percent_remaining":65,"credits_used":2450,"unlimited":false}}}"#)
    let credits = try? monthly.get()
    expectEqual(credits?.plan, "Copilot Pro+", "individual_pro is Pro+")
    expectEqual(credits?.windows.first?.title, "AI Credits", "a plan billed by tokens counts AI Credits")
    expectEqual(credits?.windows.first?.id, "premium", "in the same place as premium requests")
    expectEqual(credits?.windows.first?.utilization, 35, "used is 100 less the share remaining")
    expectEqual(credits?.windows.first?.detail, "2,450 of 7,000 used", "counts may come as strings")
    expectEqual(credits?.windows.first?.resetsAt, utc("2026-12-01T00:00:00Z"), "a full reset moment is read too")

    // Over the allowance.
    let over = try? reading(#"{"copilot_plan":"individual","quota_reset_date":"2026-12-01","quota_snapshots":{"premium_interactions":{"entitlement":300,"remaining":-45,"percent_remaining":-15,"unlimited":false}}}"#).get()
    expectEqual(over?.windows.first?.utilization, 100, "past the allowance the bar is full")
    expectEqual(over?.windows.first?.detail, "345 of 300 used", "and the count says how far past")

    // A seat billed elsewhere: no allowance, only the credits spent.
    let seat = try? reading(#"{"copilot_plan":"business","token_based_billing":true,"quota_snapshots":{\#(unlimitedChat),"premium_interactions":{"entitlement":0,"remaining":0,"percent_remaining":100,"credits_used":31,"unlimited":false}}}"#).get()
    expectEqual(seat?.windows.count, 1, "an allowance of 0 that counts credits is shown")
    check(seat?.windows.first?.utilization == nil, "without a share, since there's nothing to be a share of")
    expectEqual(seat?.windows.first?.detail, "31 used", "only what was spent")
    check(seat?.windows.first?.span == nil, "and no reset date, no cycle")

    // Copilot Free: chat and completions are limited.
    let free = try? reading(#"{"access_type_sku":"free_limited_copilot","copilot_plan":"free","quota_reset_date":"2026-12-01","quota_snapshots":{"chat":{"entitlement":50,"remaining":20,"percent_remaining":40,"unlimited":false},"completions":{"entitlement":2000,"remaining":1500,"percent_remaining":75,"unlimited":false}}}"#).get()
    expectEqual(free?.plan, "Copilot Free", "free is Copilot Free")
    expectEqual(free?.windows.map(\.title), ["Chat messages", "Code completions"], "Copilot Free's chat and completions are limits")
    expectEqual(free?.windows.map(\.detail), ["30 of 50 used", "500 of 2,000 used"], "each with its count")

    let olderFree = try? reading(#"{"copilot_plan":"free","limited_user_reset_date":"2026-12-01","monthly_quotas":{"chat":50,"completions":"2000"},"limited_user_quotas":{"chat":10,"completions":1500}}"#).get()
    expectEqual(olderFree?.windows.map(\.utilization), [80, 25], "Copilot Free's monthly and remaining counts stand in for the quotas")
    expectEqual(olderFree?.windows.first?.resetsAt, utc("2026-12-01T00:00:00Z"), "with Copilot Free's own reset date")

    // Unlimited, ended and empty answers.
    expectEqual(reading(#"{"copilot_plan":"enterprise","quota_snapshots":{\#(unlimitedChat),\#(unlimitedCompletions),"premium_interactions":{"entitlement":0,"remaining":0,"percent_remaining":100,"unlimited":true}}}"#),
                .failure(.noLimits("Copilot Enterprise has no monthly limits.")), "a plan with every quota unlimited has no limits")
    expectEqual(reading(#"{"copilot_plan":"individual","access_type_sku":"subscription_ended","quota_snapshots":{}}"#),
                .failure(.noLimits("This GitHub account's Copilot plan has ended.")), "an ended plan says so")
    expectEqual(reading(#"{"login":"sample-user","can_signup_for_limited":true,"chat_enabled":false}"#),
                .failure(.noLimits("This GitHub account has no Copilot plan.")), "an account without Copilot says so")
    expectEqual(reading("<html>"), .failure(.unreadable), "an answer that isn't JSON is unreadable")

    expectEqual(CopilotUsage.problem(status: 200), nil, "a 200 is an answer")
    expectEqual(CopilotUsage.problem(status: 401), .notSignedIn("GitHub turned down the GitHub CLI's sign-in. Sign in again (gh auth login) to read Copilot's limits."), "a 401 asks for a new sign-in")
    var forbiddenAsksToSignIn = false
    if case .notSignedIn? = CopilotUsage.problem(status: 403) { forbiddenAsksToSignIn = true }
    check(forbiddenAsksToSignIn, "a 403 asks for a new sign-in too")
    expectEqual(CopilotUsage.problem(status: 403, rateLimitRemaining: "0"), .http(429), "unless the rate limit is spent")
    expectEqual(CopilotUsage.problem(status: 404), .noLimits("This GitHub account has no Copilot plan."), "a 404 is no Copilot plan")
    expectEqual(CopilotUsage.problem(status: 502), .http(502), "other failures keep their code")
    expectEqual(CopilotUsage.planName("enterprise"), "Copilot Enterprise", "plans are named as GitHub names them")
    expectEqual(CopilotUsage.planName("some_new_plan"), "Copilot Some new plan", "an unknown plan keeps its words")

    // MARK: The GitHub CLI

    let notSignedIn = Result<LimitReading, LimitProblem>.failure(.notSignedIn(CopilotUsage.signInHint))
    expectEqual(waitFor { await CopilotUsage.limits(gh: nil) }, notSignedIn, "without the GitHub CLI, it asks to sign in to it")
    expectEqual(waitFor { await CopilotUsage.limits(gh: home.appendingPathComponent("bin/gh").path) }, notSignedIn, "a gh that isn't there is no gh")

    let bin = home.appendingPathComponent("bin")
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    func fakeGH(_ name: String, _ script: String) throws -> String {
        let url = bin.appendingPathComponent(name)
        try ("#!/bin/sh\n" + script + "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url.path
    }
    let signedOut = try fakeGH("gh-signed-out", "echo 'no oauth token found for github.com' >&2; exit 1")
    expectEqual(waitFor { await CopilotUsage.limits(gh: signedOut) }, notSignedIn, "a GitHub CLI that isn't signed in asks to sign in")
    let blank = try fakeGH("gh-blank", "echo ''")
    expectEqual(waitFor { await CopilotUsage.limits(gh: blank) }, notSignedIn, "an empty answer is no sign-in")
    let stuck = try fakeGH("gh-stuck", "exec sleep 5")
    let started = Date()
    expectEqual(waitFor { await CopilotUsage.limits(gh: stuck, timeout: 0.3) }, notSignedIn, "a GitHub CLI that doesn't answer is stopped")
    check(Date().timeIntervalSince(started) < 3, "within its time limit")
}

/// Runs async work from the synchronous checks and waits for it.
private func waitFor<T>(_ work: @escaping @Sendable () async -> T) -> T {
    let box = CopilotCheckBox<T>()
    let done = DispatchSemaphore(value: 0)
    Task.detached {
        box.value = await work()
        done.signal()
    }
    done.wait()
    return box.value!
}

/// Carries an async result back to the waiting thread.
private final class CopilotCheckBox<T>: @unchecked Sendable {
    var value: T?
}

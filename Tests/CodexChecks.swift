import Foundation

// Checks for reading Codex's session logs. The lines follow Codex's own format (openai/codex,
// codex-rs/protocol and codex-rs/history): an older log with only `token_count` events, a newer
// one with a `token_usage_record` per response from a subagent, and a fork that repeats its
// parent's lines. Nothing here reads the real ~/.codex. Called from main.swift.

func codexChecks() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-codex-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: home) }
    let day = home.appendingPathComponent("sessions/2026/11/17")
    try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)

    func write(_ name: String, _ lines: [String], modified: String) throws -> URL {
        let url = day.appendingPathComponent(name)
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: utc(modified)], ofItemAtPath: url.path)
        return url
    }

    func usage(_ input: Int, cached: Int, output: Int, reasoning: Int = 0) -> String {
        #"{"input_tokens":\#(input),"cached_input_tokens":\#(cached),"output_tokens":\#(output),"reasoning_output_tokens":\#(reasoning),"total_tokens":\#(input + output)}"#
    }

    // An older Codex CLI session: tokens and limits only in `token_count`, resets in seconds.
    let olderLimits = #"{"primary":{"used_percent":12.5,"window_minutes":300,"resets_in_seconds":3600},"secondary":{"used_percent":40.0,"window_minutes":10080,"resets_in_seconds":86400},"plan_type":"plus"}"#
    _ = try write("rollout-2026-11-17T09-00-00-T1.jsonl", [
        #"{"timestamp":"2026-11-17T09:00:00.000Z","type":"session_meta","payload":{"id":"T1","timestamp":"2026-11-17T09:00:00.000Z","cwd":"/Users/t/app","originator":"codex_cli_rs","cli_version":"0.60.0","source":"cli","model_provider":"openai"}}"#,
        #"{"timestamp":"2026-11-17T09:00:01.000Z","type":"turn_context","payload":{"turn_id":"u1","cwd":"/Users/t/app","approval_policy":"on-request","model":"gpt-5.3-codex","effort":"high"}}"#,
        #"{"timestamp":"2026-11-17T09:00:02.000Z","type":"event_msg","payload":{"type":"user_message","message":"Fix the failing build\nIt broke after the merge.","images":[]}}"#,
        #"{"timestamp":"2026-11-17T09:00:10.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":\#(usage(1200, cached: 1000, output: 300, reasoning: 100)),"last_token_usage":\#(usage(1200, cached: 1000, output: 300, reasoning: 100)),"model_context_window":272000},"rate_limits":\#(olderLimits)}}"#,
        // The same response logged again: same total.
        #"{"timestamp":"2026-11-17T09:00:11.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":\#(usage(1200, cached: 1000, output: 300)),"last_token_usage":\#(usage(1200, cached: 1000, output: 300)),"model_context_window":272000},"rate_limits":\#(olderLimits)}}"#,
        // Limits alone.
        #"{"timestamp":"2026-11-17T09:00:12.000Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":\#(olderLimits)}}"#,
        // A reply that mentions the event's name is not an event.
        #"{"timestamp":"2026-11-17T09:00:30.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"see the \"token_count\" event"}]}}"#,
        #"{"timestamp":"2026-11-17T09:01:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":\#(usage(2600, cached: 2200, output: 400)),"last_token_usage":\#(usage(1400, cached: 1200, output: 100)),"model_context_window":272000},"rate_limits":null}}"#,
        "not json",
    ], modified: "2026-11-17T09:01:00Z")

    // A newer subagent session from VS Code: one record per response, resets as a moment.
    let newerLimits = #"{"limit_id":"codex","primary":{"used_percent":20.0,"window_minutes":300,"resets_at":1795431600},"secondary":{"used_percent":41.0,"window_minutes":10080,"resets_at":1795867200},"plan_type":"pro"}"#
    let record1 = #"{"timestamp":"2026-11-17T10:00:20.000Z","type":"token_usage_record","payload":{"thread_id":"T2","turn_id":"u9","session_id":"T1","root_turn_id":"u9","response_id":"resp_1","usage":\#(usage(300_000, cached: 0, output: 1000)),"turn_token_usage":\#(usage(300_000, cached: 0, output: 1000)),"thread_token_usage":\#(usage(300_000, cached: 0, output: 1000))}}"#
    let parentLines = [
        #"{"timestamp":"2026-11-17T10:00:00.000Z","type":"session_meta","payload":{"session_id":"T1","id":"T2","timestamp":"2026-11-17T10:00:00.000Z","cwd":"/Users/t/app","originator":"codex_vscode","cli_version":"0.80.0","source":{"subagent":{"thread_spawn":{"parent_thread_id":"T1","depth":1}}},"thread_source":"subagent","model_provider":"openai"}}"#,
        #"{"timestamp":"2026-11-17T10:00:01.000Z","type":"turn_context","payload":{"turn_id":"u9","cwd":"/Users/t/app","model":"gpt-6.1-sol","effort":"medium"}}"#,
        record1,
        #"{"timestamp":"2026-11-17T10:00:21.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":\#(usage(300_000, cached: 0, output: 1000)),"last_token_usage":\#(usage(300_000, cached: 0, output: 1000)),"model_context_window":400000},"rate_limits":\#(newerLimits)}}"#,
        // A single model's own limit isn't the plan's.
        #"{"timestamp":"2026-11-17T10:00:22.000Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"limit_id":"gpt-6-luna","limit_name":"gpt-6-luna","primary":{"used_percent":90.0,"window_minutes":300,"resets_at":1795431600}}}}"#,
        #"{"timestamp":"2026-11-17T10:00:40.000Z","type":"token_usage_record","payload":{"thread_id":"T2","turn_id":"u9","session_id":"T1","root_turn_id":"u9","response_id":"resp_2","usage":\#(usage(5000, cached: 4000, output: 50)),"turn_token_usage":\#(usage(305_000, cached: 4000, output: 1050)),"thread_token_usage":\#(usage(305_000, cached: 4000, output: 1050))}}"#,
    ]
    _ = try write("rollout-2026-11-17T10-00-00-T2.jsonl", parentLines, modified: "2026-11-17T10:00:40Z")

    // A fork of it, repeating its first response.
    let forkLines = [
        #"{"timestamp":"2026-11-17T11:00:00.000Z","type":"session_meta","payload":{"id":"T3","timestamp":"2026-11-17T11:00:00.000Z","cwd":"/Users/t/app","originator":"codex_vscode","cli_version":"0.80.0","source":"vscode","forked_from_id":"T2"}}"#,
        record1,
    ]
    let fork = try write("rollout-2026-11-17T11-00-00-T3.jsonl", forkLines, modified: "2026-11-17T11:00:00Z")

    // MARK: Reading

    let scan = CodexSessions.scan(home: home, since: .distantPast)
    expectEqual(scan.samples.count, 4, "two older responses and two records; a response logged twice or repeated by a fork counts once")
    let first = scan.samples.first
    expectEqual(first?.input, 200, "fresh input is input less cached input")
    expectEqual(first?.cacheRead, 1000, "cached input counts as cache reads")
    expectEqual(first?.output, 300, "output is read as Codex reports it")
    expectEqual(first?.thinking, 100, "reasoning is kept, inside output")
    expectEqual(first?.model, "GPT-5.3 Codex", "a call's model comes from its turn")
    expectEqual(first?.effort, "high", "and its reasoning effort")
    expectEqual(first?.app, "codex-cli", "Codex CLI's sessions are its own app")
    expectEqual(first?.project, "/Users/t/app", "calls carry the session's folder")
    expectEqual(first?.durationMs, 8000, "a reply's time runs from the prompt")
    expectEqual(scan.samples[1].input, 200, "the next response is the last usage, not the running total")
    expectEqual(scan.samples[1].durationMs, 50_000, "a reply that follows on runs from the one before")

    let records = scan.samples.filter { $0.id.hasPrefix("codex:resp_") }
    expectEqual(records.map(\.id), ["codex:resp_1", "codex:resp_2"], "newer Codex counts each response's record once")
    expectEqual(records.first?.model, "GPT-6.1 Sol", "a record's model comes from its turn")
    expectEqual(records.first?.sessionID, "T1", "a subagent's calls belong to its root session")
    expectEqual(records.first?.agent, "T2", "and are marked as the subagent's")
    expectEqual(records.first?.isSidechain, true, "a subagent's calls are side calls")
    expectEqual(records.first?.app, "codex-vscode", "VS Code's sessions are VS Code's")
    check(abs((records.first?.cost ?? 0) - 1.215) < 0.0001, "a prompt over 272K tokens is priced at the long-context rate")
    check(abs((records.last?.cost ?? 0) - (1000 * 2 + 4000 * 0.10 + 50 * 10) / 1_000_000) < 1e-9, "a short prompt is priced at the standard rate, cached input at its own")
    expectEqual(scan.titles["T1"], "Fix the failing build", "a session's first prompt stands for its title")

    // MARK: Limits

    expectEqual(scan.limits.count, 4, "every reading of the plan's limit is kept, and single models' limits are not")
    expectEqual(scan.limits.first?.session, 12.5, "the 5-hour window is the session limit")
    expectEqual(scan.limits.first?.weekly, 40, "the weekly window is weekly")
    expectEqual(scan.limits.first?.sessionReset, utc("2026-11-17T10:00:10Z"), "an older reset in seconds counts from the reading")
    let latest = scan.latest
    expectEqual(latest?.session, UsageWindow(utilization: 20, resetsAt: Date(timeIntervalSince1970: 1_795_431_600)), "the latest reading is the newest log's")
    expectEqual(latest?.weekly?.utilization, 41, "with its weekly figure")
    expectEqual(latest?.fetchedAt, utc("2026-11-17T10:00:21Z"), "a reading is as of Codex's reply")
    expectEqual(scan.plan, "Pro", "the plan is named as the latest reading names it")
    check(CodexScan().latest == nil, "no readings, no limits: as with an API key")

    let later = CodexSessions.scan(home: home, since: utc("2026-11-17T10:00:00Z"))
    expectEqual(later.samples.count, 2, "calls before the period are left out")
    expectEqual(later.limits.count, 1, "and so are older readings")

    // MARK: Compressed logs

    try FileManager.default.removeItem(at: fork)
    let compressed = day.appendingPathComponent("rollout-2026-11-17T11-00-00-T3.jsonl.zst")
    let zstd = ["/opt/homebrew/bin/zstd", "/usr/local/bin/zstd"].first { FileManager.default.isExecutableFile(atPath: $0) }
    if let zstd {
        let source = day.appendingPathComponent("fork.tmp")
        try (forkLines + [#"{"timestamp":"2026-11-17T11:00:30.000Z","type":"token_usage_record","payload":{"thread_id":"T3","turn_id":"u9","session_id":"T3","root_turn_id":"u9","response_id":"resp_3","usage":\#(usage(100, cached: 0, output: 10))}}"#])
            .joined(separator: "\n").write(to: source, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: zstd)
        process.arguments = ["-q", "-o", compressed.path, source.path]
        try process.run()
        process.waitUntilExit()
        try FileManager.default.removeItem(at: source)
        let withCompressed = CodexSessions.scan(home: home, since: .distantPast)
        check(withCompressed.samples.contains { $0.id == "codex:resp_3" }, "a compressed log is read with zstd")
        expectEqual(withCompressed.unreadCompressed, 0, "nothing is left unread")
    } else {
        try Data("not zstd".utf8).write(to: compressed)
        expectEqual(CodexSessions.scan(home: home, since: .distantPast).unreadCompressed, 1, "without zstd, a compressed log is counted as unread")
    }

    // MARK: Names

    expectEqual(CodexSessions.displayName(for: "gpt-5.5"), "GPT-5.5", "a bare model keeps its version")
    expectEqual(CodexSessions.displayName(for: "gpt-6-astra"), "GPT-6 Astra", "a model's variant is a word")
    expectEqual(CodexSessions.displayName(for: "codex-auto-review"), "Codex Auto Review", "names that aren't GPT are spelled out")
    expectEqual(CodexSessions.appKey(originator: "codex_exec", source: "exec"), "codex-exec", "codex exec runs are their own app")
    expectEqual(CodexSessions.appKey(originator: "Codex Desktop", source: "vscode"), "codex-app", "the Codex app is its own app")
    expectEqual(CodexSessions.appKey(originator: nil, source: "vscode"), "codex-vscode", "without an originator, the source decides")
    expectEqual(CodexSessions.planName("business"), "Business", "plans are named")
    expectEqual(UsageSummary.appName("codex-cli"), "Codex CLI", "the Usage page names Codex's apps")
    expectEqual(ModelPricing.price(for: "GPT-6.1 Sol"), ModelPricing.price(for: CodexSessions.displayName(for: "gpt-6.1-sol")), "prices are found by the name calls are stored under")
    check(AICatalog.codingTools.contains { $0.id == UsageProvider.codex.connectionID }, "the Codex switch shows AI Models' Codex logo")
}

import Foundation

/// GitHub Copilot's usage: its plan's premium requests or AI Credits, and Copilot CLI's calls from its session logs in `~/.copilot`.
/// Not written yet: these are the calls the Usage page makes.
enum CopilotUsage {
    /// Whether the tool has left logs of its calls on this Mac.
    static func hasLogs(home: String) -> Bool { false }

    /// Every model call in the tool's logs since `since`, oldest first.
    static func scan(home: String, since: Date) -> TranscriptScan { TranscriptScan() }

    /// The plan's limits now. Never refreshes or rewrites the tool's own sign-in.
    static func limits(home: String) async -> Result<LimitReading, LimitProblem> {
        .failure(.unreadable)
    }
}

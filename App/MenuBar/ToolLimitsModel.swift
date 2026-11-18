import Foundation

/// Gemini CLI's, Copilot's or OpenCode's plan limits, read every five minutes while the tool is
/// shown, for the Usage page, the menu bar, the widgets and alerts. Claude's come from
/// `UsageRefresher`, Codex's from `CodexLimits`.
@MainActor
final class ToolLimitsModel: ObservableObject {
    static let gemini = ToolLimitsModel(.gemini)
    static let copilot = ToolLimitsModel(.copilot)
    static let opencode = ToolLimitsModel(.opencode)

    /// Nil for Claude and Codex, which have their own.
    static func of(_ provider: UsageProvider) -> ToolLimitsModel? {
        switch provider {
        case .gemini: return gemini
        case .copilot: return copilot
        case .opencode: return opencode
        case .claude, .codex: return nil
        }
    }

    /// The screenshot tool turns this off: it never asks the network.
    static var readsLimits = true

    let provider: UsageProvider
    /// The last reading that worked.
    @Published private(set) var reading: LimitReading?
    /// Why the last reading failed. Cleared by the next one that works.
    @Published private(set) var problem: LimitProblem?
    @Published private(set) var isReading = false
    @Published private(set) var lastAttempt: Date?

    private init(_ provider: UsageProvider) {
        self.provider = provider
    }

    /// The last reading as it stands now: windows that have reset since read 0%.
    var current: LimitReading? { reading?.asOf(Date()) }

    /// The last reading failed and an older one is showing.
    var isStale: Bool { problem != nil && reading != nil }

    /// Reads the limits now, unless a reading was tried within the last minute and not `force`.
    /// Returns whether it read.
    @discardableResult
    func refresh(force: Bool = false) async -> Bool {
        guard Self.readsLimits, !isReading else { return false }
        if !force, let lastAttempt, Date().timeIntervalSince(lastAttempt) < 60 { return false }
        isReading = true
        defer {
            isReading = false
            lastAttempt = Date()
        }
        let home = NSHomeDirectory()
        let result: Result<LimitReading, LimitProblem>
        switch provider {
        case .gemini: result = await GeminiUsage.limits(home: home)
        case .copilot: result = await CopilotUsage.limits(home: home)
        case .opencode: result = await OpenCodeUsage.limits(home: home)
        case .claude, .codex: return false
        }
        switch result {
        case .success(let fresh):
            reading = fresh
            problem = nil
        case .failure(let failure):
            problem = failure
            // Signed out, or a plan without limits: an older reading no longer stands for anything.
            switch failure {
            case .notSignedIn, .noLimits: reading = nil
            case .expired, .offline, .http, .unreadable: break
            }
        }
        return true
    }
}

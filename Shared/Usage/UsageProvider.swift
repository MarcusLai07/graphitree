import Foundation

/// Whose usage the Usage page shows: the coding tools AI Models knows. Each has its plan's limits
/// and the calls it made on this Mac, read from different places:
///
/// - Claude: limits from Anthropic's endpoint behind `/usage` (Graphitree's own sign-in, or
///   Claude Code's borrowed), calls from Claude Code's transcripts.
/// - Codex: limits and calls both from Codex's own session logs in `~/.codex`, so nothing is asked
///   of the network or the keychain. The limits are as of Codex's last reply.
/// - Gemini CLI, GitHub Copilot and OpenCode: limits as `LimitReading`, calls from their own logs
///   (`GeminiUsage`, `CopilotUsage`, `OpenCodeUsage`).
///
/// Only the ones AI Models lists under Connected show (`UsageProvider.shown`).
enum UsageProvider: String, CaseIterable, Identifiable, Sendable {
    case claude, codex, gemini, copilot, opencode

    var id: String { rawValue }

    /// The plan's name, on the switch and the limits card.
    var name: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        case .copilot: return "Copilot"
        case .opencode: return "OpenCode"
        }
    }

    /// The coding tool whose calls are counted.
    var toolName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .gemini: return "Gemini CLI"
        case .copilot: return "Copilot CLI"
        case .opencode: return "OpenCode"
        }
    }

    /// The tool's id in AI Models, for its logo and whether it's connected.
    var connectionID: String {
        switch self {
        case .claude: return "claude-code"
        case .codex: return "codex"
        case .gemini: return "gemini"
        case .copilot: return "copilot"
        case .opencode: return "opencode"
        }
    }

    /// Where its calls are read from, as the page says it.
    var logsPath: String {
        switch self {
        case .claude: return "~/.claude/projects"
        case .codex: return "~/.codex/sessions"
        case .gemini: return "~/.gemini/tmp"
        case .copilot: return "~/.copilot/session-state"
        case .opencode: return "~/.local/share/opencode"
        }
    }

    /// The tool's brand in AI Models (`ModelBrand.of`): Gemini CLI has its own, apart from the
    /// Gemini API's.
    var brandID: String { self == .gemini ? "tool:gemini" : connectionID }

    /// Its logo's file, `ModelLogo-<name>.png`, as the widget bundles it.
    var logoName: String { self == .gemini ? "gemini-cli" : connectionID }

    /// Claude and Codex report their limits as `UsageSnapshot`, with the history behind the
    /// left-over-time charts. The others report a `LimitReading`.
    var readsSnapshot: Bool { self == .claude || self == .codex }
}

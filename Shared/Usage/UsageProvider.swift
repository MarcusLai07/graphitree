import Foundation

/// Whose usage the Usage page shows. Each has its plan's limits and the calls its coding tool made
/// on this Mac, read from different places:
///
/// - Claude: limits from Anthropic's endpoint behind `/usage` (borrowing Claude Code's sign-in),
///   calls from Claude Code's transcripts.
/// - Codex: limits and calls both from Codex's own session logs in `~/.codex`, so nothing is asked
///   of the network or the keychain. The limits are as of Codex's last reply.
enum UsageProvider: String, CaseIterable, Identifiable, Sendable {
    case claude, codex

    var id: String { rawValue }

    /// The plan's name, on the switch and the limits card.
    var name: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }

    /// The coding tool whose calls are counted.
    var toolName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        }
    }

    /// The tool's id in AI Models, for its logo.
    var connectionID: String {
        switch self {
        case .claude: return "claude-code"
        case .codex: return "codex"
        }
    }

    /// Where its calls are read from, as the page says it.
    var logsPath: String {
        switch self {
        case .claude: return "~/.claude/projects"
        case .codex: return "~/.codex/sessions"
        }
    }
}

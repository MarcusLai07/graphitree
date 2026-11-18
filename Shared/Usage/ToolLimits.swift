import Foundation

/// Why a tool's plan limits couldn't be read, as the Usage page, menu bar and widgets say it.
/// For the tools whose limits come as `LimitReading`: Gemini CLI, GitHub Copilot and OpenCode.
enum LimitProblem: Error, Equatable, Sendable {
    /// The tool isn't signed in, or its sign-in can't be found. The text says how to sign in.
    case notSignedIn(String)
    /// The tool's own sign-in ran out. Graphitree never renews another tool's sign-in, so the text
    /// names the tool to open.
    case expired(String)
    /// This plan has no limits to read, such as an API key or a personal Gemini account. The text
    /// says why.
    case noLimits(String)
    /// No connection.
    case offline
    case http(Int)
    /// An answer in a shape this version doesn't know.
    case unreadable

    var message: String {
        switch self {
        case .notSignedIn(let text), .expired(let text), .noLimits(let text): return text
        case .offline: return "This Mac can't reach the network right now. It tries again on the next refresh."
        case .http(429): return "Rate limited. It tries again on the next refresh."
        case .http(let code): return "The request failed (HTTP \(code))."
        case .unreadable: return "The answer wasn't in a shape Graphitree knows."
        }
    }

    /// A connection failure as one of these.
    static func from(_ error: Error) -> LimitProblem {
        if let problem = error as? LimitProblem { return problem }
        if error is URLError { return .offline }
        return .unreadable
    }
}

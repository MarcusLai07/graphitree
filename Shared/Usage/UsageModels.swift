import Foundation

enum MetricKind: String, CaseIterable, Codable, Identifiable {
    case session
    case weekly
    case weeklyFable
    case weeklyOpus
    case weeklySonnet
    case extraUsage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .session: return "Session"
        case .weekly: return "Weekly"
        case .weeklyFable: return "Fable · 7-day"
        case .weeklyOpus: return "Opus · 7-day"
        case .weeklySonnet: return "Sonnet · 7-day"
        case .extraUsage: return "Extra usage"
        }
    }

    /// How long one cycle of the window lasts; nil for extra usage, which
    /// has no rolling window. Pace is measured against this.
    var span: TimeInterval? {
        switch self {
        case .session: return 5 * 3600
        case .weekly, .weeklyFable, .weeklyOpus, .weeklySonnet: return 7 * 86400
        case .extraUsage: return nil
        }
    }
}

struct UsageWindow: Codable, Equatable {
    var utilization: Double?
    var resetsAt: Date?

    /// The window as it stands at `now`. Once its reset has passed, what was used is gone: it
    /// reads 0% and not started until the next reading says otherwise.
    func asOf(_ now: Date) -> UsageWindow {
        guard let resetsAt, resetsAt <= now else { return self }
        return UsageWindow(utilization: 0, resetsAt: nil)
    }
}

/// Who is signed in and on which plan, from the OAuth profile endpoint.
/// Shown in the Allowances card header; the email can be masked.
struct AccountProfile: Codable, Equatable {
    var email: String?
    /// "Max 20x", "Pro", "Team"… nil when the endpoint doesn't say.
    var plan: String?
    var fetchedAt: Date

    /// "m•••@g•••.com", for screenshots with *Hide account* on.
    static func masked(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2 else { return "•••" }
        let domain = parts[1]
        let tld = domain.split(separator: ".").last.map { ".\($0)" } ?? ""
        return "\(parts[0].prefix(1))•••@\(domain.prefix(1))•••\(tld)"
    }
}

struct ExtraUsage: Codable, Equatable {
    var isEnabled: Bool
    var monthlyLimit: Double?
    var usedCredits: Double?
    var currency: String?

    var utilization: Double? {
        guard let limit = monthlyLimit, limit > 0, let used = usedCredits else { return nil }
        return used / limit * 100
    }
}

struct UsageSnapshot: Codable, Equatable {
    var fetchedAt: Date
    var session: UsageWindow?
    var weekly: UsageWindow?
    var weeklyOpus: UsageWindow?
    var weeklySonnet: UsageWindow?
    var extra: ExtraUsage?
    /// The weekly allowance of the Fable models (the endpoint's
    /// `weekly_scoped` Fable row). Last, with a default, so older cached
    /// snapshots and existing initializers stay valid.
    var weeklyFable: UsageWindow? = nil

    /// The reading as it stands at `now`: every window whose reset has passed since it was read
    /// is back to 0%. A stored reading can be hours old when Graphitree opens, or when Claude
    /// Code's token has run out and no new one comes.
    func asOf(_ now: Date) -> UsageSnapshot {
        var current = self
        current.session = session?.asOf(now)
        current.weekly = weekly?.asOf(now)
        current.weeklyOpus = weeklyOpus?.asOf(now)
        current.weeklySonnet = weeklySonnet?.asOf(now)
        current.weeklyFable = weeklyFable?.asOf(now)
        return current
    }

    func window(for kind: MetricKind) -> UsageWindow? {
        switch kind {
        case .session: return session
        case .weekly: return weekly
        case .weeklyFable: return weeklyFable
        case .weeklyOpus: return weeklyOpus
        case .weeklySonnet: return weeklySonnet
        case .extraUsage:
            guard let extra, extra.isEnabled else { return nil }
            return UsageWindow(utilization: extra.utilization, resetsAt: nil)
        }
    }
}

/// One of a plan's limits as any tool reports it: how much of it is used, and when it resets.
/// Claude's and Codex's windows map into it (`UsageSnapshot.limitWindows`); Gemini CLI, Copilot
/// and OpenCode report only these.
struct LimitWindow: Codable, Equatable, Identifiable, Sendable {
    /// Stable within its tool: "session", "premium", "gemini-2.5-pro".
    var id: String
    /// "Premium requests", "Gemini 2.5 Pro · daily".
    var title: String
    /// Percent used, 0 to 100.
    var utilization: Double?
    var resetsAt: Date?
    /// How long one cycle lasts, for the pace. Nil when the tool doesn't say.
    var span: TimeInterval?
    /// "238 of 300 used", under the bar.
    var detail: String?

    /// The window as it stands at `now`: past its reset, what was used is gone.
    func asOf(_ now: Date) -> LimitWindow {
        guard let resetsAt, resetsAt <= now else { return self }
        var current = self
        current.utilization = 0
        current.resetsAt = nil
        current.detail = nil
        return current
    }
}

/// A tool's plan limits at one moment.
struct LimitReading: Codable, Equatable, Sendable {
    var fetchedAt: Date
    var windows: [LimitWindow]
    /// "Copilot Pro", "Code Assist Standard".
    var plan: String?

    func asOf(_ now: Date) -> LimitReading {
        var current = self
        current.windows = windows.map { $0.asOf(now) }
        return current
    }
}

extension UsageSnapshot {
    /// The windows of `kinds` this reading has, as provider-neutral windows. Extra usage, which is
    /// money rather than a share, is left out.
    func limitWindows(_ kinds: [MetricKind]) -> [LimitWindow] {
        kinds.filter { $0 != .extraUsage }.compactMap { kind in
            guard let window = window(for: kind) else { return nil }
            return LimitWindow(id: kind.rawValue, title: kind.title, utilization: window.utilization,
                               resetsAt: window.resetsAt, span: kind.span)
        }
    }
}

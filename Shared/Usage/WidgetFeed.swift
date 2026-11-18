import Foundation

/// What the desktop widgets draw. Widgets run in Apple's sandbox, where Claude Code's sign-in and
/// Codex's logs are out of reach, so Graphitree reads both and writes this file into the app group
/// it shares with them after each reading. The widgets only draw it, so they're as fresh as the
/// last time Graphitree ran: the menu bar keeps it running with the window closed.
struct WidgetFeed: Codable, Equatable {
    /// One plan's limits as Graphitree last read them.
    struct Plan: Codable, Equatable {
        var snapshot: UsageSnapshot?
        /// "Max 5x", "ChatGPT Plus".
        var name: String?
        /// Why there's no reading, in a few words, shown in place of the meters.
        var problem: String?
        /// The last reading failed, so `snapshot` is an older one.
        var isStale = false
        /// The weekly windows' left-over-time this cycle, for the large widget.
        var trend: Trend?
    }

    /// What was left of each weekly window this cycle, and when it runs out at this pace.
    struct Trend: Codable, Equatable {
        var start: Date
        var reset: Date
        var lines: [Line]
        /// Set when the week runs out before it resets at this pace.
        var runsOut: Date?
        /// The week lasts past its reset at this pace.
        var lastsPastReset = false
    }

    struct Line: Codable, Equatable {
        var kind: MetricKind
        var points: [Point]
    }

    struct Point: Codable, Equatable {
        var at: Date
        var left: Double
    }

    /// When Graphitree wrote it. Graphitree writes after each reading, every five minutes while
    /// it runs, so an old one means it isn't running.
    var written: Date
    /// Bars and figures show what's left rather than what's used, as on the Usage page.
    var showLeft: Bool
    /// The windows Claude's widgets show, in order. Codex has only Session and Weekly.
    var metrics: [MetricKind]
    /// Each shown provider's plan, by `UsageProvider.rawValue`. Only the tools AI Models lists
    /// under Connected are here, so the widget offers only those.
    var plans: [String: Plan]

    init(written: Date, showLeft: Bool, metrics: [MetricKind], plans: [UsageProvider: Plan]) {
        self.written = written
        self.showLeft = showLeft
        self.metrics = metrics
        self.plans = Dictionary(uniqueKeysWithValues: plans.map { ($0.key.rawValue, $0.value) })
    }

    func plan(_ provider: UsageProvider) -> Plan? { plans[provider.rawValue] }

    /// The providers with a plan here, in the switch's order.
    var providers: [UsageProvider] { UsageProvider.allCases.filter { plans[$0.rawValue] != nil } }

    private enum CodingKeys: String, CodingKey {
        case written, showLeft, metrics, plans
        /// 0.2.2 and before: one field per provider.
        case claude, codex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        written = try container.decode(Date.self, forKey: .written)
        showLeft = try container.decode(Bool.self, forKey: .showLeft)
        metrics = try container.decode([MetricKind].self, forKey: .metrics)
        if let plans = try container.decodeIfPresent([String: Plan].self, forKey: .plans) {
            self.plans = plans
        } else {
            // A feed an older Graphitree wrote, read by a newer widget before the app writes again.
            var plans: [String: Plan] = [:]
            plans[UsageProvider.claude.rawValue] = try container.decodeIfPresent(Plan.self, forKey: .claude)
            plans[UsageProvider.codex.rawValue] = try container.decodeIfPresent(Plan.self, forKey: .codex)
            self.plans = plans
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(written, forKey: .written)
        try container.encode(showLeft, forKey: .showLeft)
        try container.encode(metrics, forKey: .metrics)
        try container.encode(plans, forKey: .plans)
    }

    /// The windows a provider's widgets show.
    func kinds(_ provider: UsageProvider) -> [MetricKind] {
        provider == .claude ? metrics : [.session, .weekly]
    }

    /// Longer than this without a write, and Graphitree isn't running to keep it current.
    static let quietAfter: TimeInterval = 20 * 60

    func isQuiet(now: Date) -> Bool {
        now.timeIntervalSince(written) > Self.quietAfter
    }

    /// The same feed, ignoring when it was written: whether the widgets need redrawing.
    func sameContent(as other: WidgetFeed?) -> Bool {
        guard var other else { return false }
        other.written = written
        return self == other
    }
}

/// Where the feed lives: `widget-feed.json` in the app group Graphitree shares with its widget,
/// `~/Library/Group Containers/<team>.com.marcuslai.Graphitree`. Both bundles carry the group's
/// name in their Info.plist (`GraphitreeAppGroup`), so a build signed by another team uses its own.
enum WidgetFeedStore {
    static let infoKey = "GraphitreeAppGroup"
    static let fileName = "widget-feed.json"

    /// The group from this bundle's Info.plist, when it names one macOS lets this app use without
    /// asking: one starting with a team ID. A copy signed for this Mac only has no team, so it
    /// has no widget feed rather than a prompt about another app's data.
    static var groupID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String, isTeamPrefixed(id) else { return nil }
        return id
    }

    /// "ABCDE12345.com.example.App": ten capital letters or digits, then a dot.
    static func isTeamPrefixed(_ id: String) -> Bool {
        let parts = id.split(separator: ".", maxSplits: 1)
        guard parts.count == 2, parts[0].count == 10 else { return false }
        return parts[0].allSatisfy { ($0.isUppercase || $0.isNumber) && $0.isASCII }
    }

    static var fileURL: URL? {
        guard let groupID,
              let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return nil }
        return folder.appendingPathComponent(fileName)
    }

    static func read() -> WidgetFeed? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    /// Whether it was written. False without an app group, as in the command line and checks.
    @discardableResult
    static func write(_ feed: WidgetFeed) -> Bool {
        guard let url = fileURL, let data = encode(feed) else { return false }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    static func encode(_ feed: WidgetFeed) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(feed)
    }

    static func decode(_ data: Data) -> WidgetFeed? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetFeed.self, from: data)
    }
}

extension WidgetFeed.Trend {
    /// What was left of each weekly window this cycle, thinned for a small chart, and when the
    /// week runs out at this pace. Nil before the week has a reset or any readings.
    static func make(samples: [UsageSample], snapshot: UsageSnapshot, now: Date) -> WidgetFeed.Trend? {
        guard let reset = snapshot.weekly?.resetsAt, reset > now, let span = MetricKind.weekly.span else { return nil }
        let start = reset.addingTimeInterval(-span)
        let history = UsageTrends.lines(from: samples.filter { $0.ts >= start.addingTimeInterval(-3600) })
        var lines: [WidgetFeed.Line] = []
        for kind in [MetricKind.weekly, .weeklyFable, .weeklyOpus, .weeklySonnet] where snapshot.window(for: kind) != nil {
            guard let line = history.first(where: { $0.kind == kind }) else { continue }
            let points = UsageTrends.visiblePoints(line.points.filter { $0.at >= start }, in: start...reset, step: span / 120)
            if !points.isEmpty {
                lines.append(WidgetFeed.Line(kind: kind, points: points.map { WidgetFeed.Point(at: $0.at, left: $0.left) }))
            }
        }
        guard !lines.isEmpty else { return nil }
        var trend = WidgetFeed.Trend(start: start, reset: reset, lines: lines)
        let weekly = history.first { $0.kind == .weekly }
        switch weekly.flatMap({ UsageTrends.forecast(points: $0.points.filter { $0.at >= start },
                                                     cycle: CurrentCycle(start: start, reset: reset), now: now) }) {
        case .runsOut(let date)?: trend.runsOut = date
        case .lastsPastReset?: trend.lastsPastReset = true
        case nil: break
        }
        return trend
    }
}

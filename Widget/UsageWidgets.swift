import AppIntents
import Charts
import SwiftUI
import WidgetKit

// Graphitree's desktop widgets: a plan's limits as bars or rings, ported from Claude Usage's
// widgets. They draw the feed Graphitree writes after each reading (`WidgetFeed`) and never read
// anything themselves: the sandbox keeps Claude Code's sign-in and Codex's logs out of reach.

// MARK: - Configuration

enum WidgetPlan: String, AppEnum {
    case claude, codex

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Plan"
    static let caseDisplayRepresentations: [WidgetPlan: DisplayRepresentation] = [
        .claude: "Claude",
        .codex: "Codex",
    ]

    var provider: UsageProvider { UsageProvider(rawValue: rawValue) ?? .claude }
}

/// The plans to pick from: the ones Graphitree shows, which are the tools AI Models lists under
/// Connected. Every plan before Graphitree has written its first feed.
struct PlanOptions: DynamicOptionsProvider {
    func results() async throws -> [WidgetPlan] {
        guard let feed = WidgetFeedStore.read() else { return WidgetPlan.allCases }
        return feed.providers.compactMap { WidgetPlan(rawValue: $0.rawValue) }
    }

    func defaultResult() async -> WidgetPlan? {
        (try? await results())?.first
    }
}

struct PlanIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Plan"
    static let description = IntentDescription("Whose plan limits the widget shows.")

    @Parameter(title: "Plan", default: .claude, optionsProvider: PlanOptions())
    var plan: WidgetPlan

    init() {}

    init(plan: WidgetPlan) {
        self.plan = plan
    }
}

// MARK: - Timeline

struct UsageEntry: TimelineEntry {
    let date: Date
    let provider: UsageProvider
    let feed: WidgetFeed?

    var plan: WidgetFeed.Plan? { feed?.plan(provider) }

    /// The reading as it stands at the entry's date: windows that have reset since read 0%.
    var snapshot: UsageSnapshot? { plan?.snapshot?.asOf(date) }

    /// Pace is measured at the entry's date, so later entries move it along without a reading.
    var displays: [MetricDisplay] {
        guard let snapshot, let feed else { return [] }
        return MetricPresentation.displays(for: snapshot, kinds: feed.kinds(provider), showLeft: feed.showLeft, now: date)
    }

    /// Graphitree hasn't written for a while, so it isn't running to read the limits.
    var isQuiet: Bool { feed?.isQuiet(now: date) ?? true }

    /// The reading shown isn't current: the last one failed, or Claude's readings have stopped.
    /// Codex's limits are as of its last reply, so they age without going stale.
    var isStale: Bool { (plan?.isStale ?? false) || (provider == .claude && isQuiet) }

    var url: URL { URL(string: "graphitree://usage?plan=\(provider.rawValue)")! }
}

struct UsageTimeline: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        .sample(.claude)
    }

    func snapshot(for configuration: PlanIntent, in context: Context) async -> UsageEntry {
        let provider = configuration.plan.provider
        let feed = WidgetFeedStore.read()
        // The widget gallery shows sample figures until Graphitree has read something.
        if context.isPreview, feed?.plan(provider)?.snapshot == nil { return .sample(provider) }
        return UsageEntry(date: Date(), provider: provider, feed: feed)
    }

    func timeline(for configuration: PlanIntent, in context: Context) async -> Timeline<UsageEntry> {
        let feed = WidgetFeedStore.read()
        let now = Date()
        // Graphitree asks for a redraw after each new reading. Between them, an entry every five
        // minutes moves the pace and reset times along; the session's pace moves ~1.7 points.
        let entries = stride(from: 0, to: 30, by: 5).map { minutes in
            UsageEntry(date: now.addingTimeInterval(TimeInterval(minutes * 60)), provider: configuration.plan.provider, feed: feed)
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60)))
    }
}

extension UsageEntry {
    /// Figures for the widget gallery and placeholders.
    static func sample(_ provider: UsageProvider, date: Date = Date()) -> UsageEntry {
        let snapshot = UsageSnapshot(
            fetchedAt: date,
            session: UsageWindow(utilization: 42, resetsAt: date.addingTimeInterval(3 * 3600)),
            weekly: UsageWindow(utilization: 17, resetsAt: date.addingTimeInterval(4 * 86400)),
            weeklyOpus: nil, weeklySonnet: nil, extra: nil
        )
        let plan = WidgetFeed.Plan(snapshot: snapshot, name: provider == .claude ? "Max" : "ChatGPT Plus")
        let feed = WidgetFeed(written: date, showLeft: false, metrics: [.session, .weekly], plans: [provider: plan])
        return UsageEntry(date: date, provider: provider, feed: feed)
    }
}

// MARK: - Shared pieces

/// The provider's logo on its tile, as AI Models draws it.
struct ProviderMark: View {
    let provider: UsageProvider
    var size: CGFloat = 14

    /// Where the screenshot tool, which has no bundle, finds the logos.
    @MainActor static var folder: URL?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
        shape
            .fill(provider == .claude ? Color(hex: 0xF0EEE6) : Color.white)
            .overlay {
                if let image = Self.image(provider) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .padding(size * (provider == .claude ? 0.16 : 0.02))
                }
            }
            .frame(width: size, height: size)
    }

    @MainActor
    static func image(_ provider: UsageProvider) -> NSImage? {
        let name = "ModelLogo-\(provider.connectionID)"
        if let image = Bundle.main.image(forResource: name) { return image }
        return folder.flatMap { NSImage(contentsOf: $0.appendingPathComponent(name + ".png")) }
    }
}

/// The logo, the provider and its plan; the reading's age on the right.
struct WidgetHeader: View {
    let entry: UsageEntry
    var showAge = true

    var body: some View {
        HStack(spacing: 6) {
            ProviderMark(provider: entry.provider, size: 14)
            Text(entry.provider.name)
                .font(.system(size: 12.5, weight: .semibold))
            if let name = entry.plan?.name {
                Text(name)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if showAge, entry.provider == .claude, let fetchedAt = entry.snapshot?.fetchedAt {
                AgeBadge(since: fetchedAt, stale: entry.isStale)
            }
        }
    }
}

/// A small-caps label, as the Usage page heads its sections.
struct WidgetLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.7)
            .foregroundStyle(.secondary)
    }
}

/// How old the reading is, or that Graphitree has stopped reading.
struct WidgetFooter: View {
    let entry: UsageEntry

    var body: some View {
        HStack(spacing: 5) {
            if entry.provider == .claude, entry.isQuiet {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 9, weight: .medium))
                Text("Open Graphitree to update")
            } else if let fetchedAt = entry.snapshot?.fetchedAt {
                Image(systemName: entry.isStale ? "clock.badge.exclamationmark" : "arrow.clockwise")
                    .font(.system(size: 9, weight: .medium))
                ReadingAge(provider: entry.provider, since: fetchedAt, stale: entry.isStale).text
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(entry.isStale ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
        .lineLimit(1)
    }
}

/// No reading to draw: why, in a few words, and where to go.
struct NoReadingView: View {
    let entry: UsageEntry

    private var message: String {
        guard let feed = entry.feed else { return "Open Graphitree to see your plan's limits here." }
        if feed.plan(entry.provider) == nil {
            return "\(entry.provider.toolName) isn't connected in Graphitree's AI Models. Edit the widget to pick another plan."
        }
        if entry.snapshot != nil, feed.kinds(entry.provider).isEmpty {
            return "No windows picked. Choose them in Graphitree's Menu Bar & Alerts."
        }
        return entry.plan?.problem ?? "No reading yet."
    }

    var body: some View {
        VStack(spacing: 8) {
            ProviderMark(provider: entry.provider, size: 22)
            Text(message)
                .font(.system(size: 11.5, weight: .medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if entry.feed != nil {
                Text("Open Graphitree")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// What was left of each weekly window this cycle, the dashed even pace from full to empty,
/// now, and the forecast: the Usage page's chart, small.
struct WidgetTrendView: View {
    let trend: WidgetFeed.Trend
    let snapshot: UsageSnapshot
    let now: Date

    private var forecast: Forecast? {
        if let out = trend.runsOut { return .runsOut(out) }
        return trend.lastsPastReset ? .lastsPastReset : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                WidgetLabel("Left over time")
                Spacer(minLength: 4)
                if let forecast {
                    ForecastLine(forecast: forecast, font: .system(size: 10))
                        .lineLimit(1)
                }
            }
            Chart {
                LineMark(x: .value("Time", trend.start), y: .value("Left", 100), series: .value("Line", "even"))
                    .foregroundStyle(MetricKind.weekly.chartColor.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                LineMark(x: .value("Time", trend.reset), y: .value("Left", 0), series: .value("Line", "even"))
                    .foregroundStyle(MetricKind.weekly.chartColor.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                ForEach(trend.lines, id: \.kind) { line in
                    ForEach(Array(line.points.enumerated()), id: \.offset) { _, point in
                        LineMark(x: .value("Time", point.at), y: .value("Left", point.left),
                                 series: .value("Line", line.kind.rawValue))
                            .foregroundStyle(line.kind.chartColor)
                            .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    }
                }
                RuleMark(x: .value("Now", now))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            .chartXScale(domain: trend.start...trend.reset)
            .chartYScale(domain: -4...104)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 50, 100]) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                }
            }
            .chartPlotStyle { $0.clipped() }
            .frame(height: 54)
            HStack(spacing: 10) {
                ForEach(trend.lines, id: \.kind) { line in
                    HStack(spacing: 4) {
                        Circle().fill(line.kind.chartColor).frame(width: 6, height: 6)
                        Text(line.kind == .weekly ? "Weekly" : line.kind.title)
                            .foregroundStyle(.secondary)
                        Text("\(Int(max(0, 100 - (snapshot.window(for: line.kind)?.utilization ?? 0))))%")
                            .fontWeight(.semibold)
                    }
                }
                Spacer(minLength: 0)
                Text(trend.reset.formatted(.dateTime.weekday(.abbreviated)))
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 10))
        }
    }
}

// MARK: - Bars

struct BarsWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    let entry: UsageEntry
    /// The size to draw, for the screenshot tool, which has no widget host to say it.
    var drawnFamily: WidgetFamily? = nil

    private var family: WidgetFamily { drawnFamily ?? systemFamily }

    var body: some View {
        Group {
            if entry.displays.isEmpty {
                NoReadingView(entry: entry)
            } else {
                switch family {
                case .systemSmall: small
                case .systemMedium: medium
                default: large
                }
            }
        }
        .widgetURL(entry.url)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var small: some View {
        let metrics = entry.displays
        let hero = metrics[0]
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                ProviderMark(provider: entry.provider, size: 12)
                WidgetLabel(hero.name)
                Spacer(minLength: 2)
                if entry.provider == .claude, let fetchedAt = entry.snapshot?.fetchedAt {
                    AgeBadge(since: fetchedAt, stale: entry.isStale)
                }
            }
            (Text("\(Int(hero.shownPercent))")
                .font(.system(size: 40, weight: .medium).monospacedDigit())
                .foregroundStyle(hero.percent >= 70 ? hero.color : Color.primary)
             + Text("%")
                .font(.system(size: 20, weight: .medium))
             + Text(hero.unitText.map { " \($0)" } ?? "")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 4)
                .padding(.bottom, 6)
            UsageBar(percent: hero.shownPercent, height: 5, tint: hero.kind.meterColor(percentUsed: hero.percent))
                .opacity(entry.isStale ? 0.62 : 1)
            // No room for the pace here; medium and large show it.
            let caption = MetricCaption(metric: hero, font: .system(size: 10.5), pace: .hidden)
            if caption.hasContent {
                caption.padding(.top, 6)
            }
            Spacer(minLength: 4)
            if metrics.count > 1 {
                let second = metrics[1]
                HStack {
                    Text(second.name).foregroundStyle(.secondary)
                    Spacer()
                    Text(second.valueWithUnit).fontWeight(.semibold).monospacedDigit()
                }
                .font(.system(size: 11))
                .padding(.bottom, 5)
                UsageBar(percent: second.shownPercent, height: 4, tint: second.kind.meterColor(percentUsed: second.percent))
                    .opacity(entry.isStale ? 0.62 : 1)
            }
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(entry: entry)
            Spacer(minLength: 6)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(entry.displays.prefix(2)) { MetricBarRow(metric: $0) }
            }
            .opacity(entry.isStale ? 0.8 : 1)
            Spacer(minLength: 2)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(entry: entry, showAge: false)
            VStack(alignment: .leading, spacing: 12) {
                // With the curve below, three rows; without it, up to five.
                ForEach(entry.displays.prefix(entry.plan?.trend == nil ? 5 : 3)) { MetricBarRow(metric: $0) }
            }
            .opacity(entry.isStale ? 0.8 : 1)
            .padding(.top, 12)
            Spacer(minLength: 8)
            if let trend = entry.plan?.trend, let snapshot = entry.snapshot {
                WidgetTrendView(trend: trend, snapshot: snapshot, now: entry.date)
                    .opacity(entry.isStale ? 0.8 : 1)
                Spacer(minLength: 6)
            }
            WidgetFooter(entry: entry)
        }
    }
}

// MARK: - Rings

struct RingsWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    let entry: UsageEntry
    /// The size to draw, for the screenshot tool, which has no widget host to say it.
    var drawnFamily: WidgetFamily? = nil

    private var family: WidgetFamily { drawnFamily ?? systemFamily }

    var body: some View {
        Group {
            if entry.displays.isEmpty {
                NoReadingView(entry: entry)
            } else {
                switch family {
                case .systemSmall: small
                case .systemMedium: medium
                default: large
                }
            }
        }
        .widgetURL(entry.url)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var small: some View {
        let metrics = entry.displays
        let hero = metrics[0]
        return VStack(spacing: 0) {
            HStack {
                ProviderMark(provider: entry.provider, size: 14)
                Spacer()
                if entry.provider == .claude, let fetchedAt = entry.snapshot?.fetchedAt {
                    AgeBadge(since: fetchedAt, stale: entry.isStale)
                }
            }
            Spacer(minLength: 2)
            UsageRing(metric: hero, size: 78, stroke: 8)
                .opacity(entry.isStale ? 0.75 : 1)
            VStack(spacing: 1) {
                Text(hero.name)
                    .font(.system(size: 12, weight: .semibold))
                MetricCaption(metric: hero, font: .system(size: 10.5), pace: .hidden)
            }
            .padding(.top, 7)
            Spacer(minLength: 2)
            if metrics.count > 1 {
                let second = metrics[1]
                HStack(spacing: 6) {
                    Circle()
                        .fill(second.kind.meterColor(percentUsed: second.percent))
                        .frame(width: 7, height: 7)
                    Text("\(second.name) \(second.valueWithUnit)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var medium: some View {
        VStack(spacing: 0) {
            WidgetHeader(entry: entry)
            Spacer(minLength: 5)
            HStack(alignment: .top, spacing: 0) {
                ForEach(entry.displays.prefix(3)) { metric in
                    VStack(spacing: 5) {
                        UsageRing(metric: metric, size: 62, stroke: 6)
                            .opacity(entry.isStale ? 0.75 : 1)
                        Text(metric.name)
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        MetricCaption(metric: metric, font: .system(size: 9.5), pace: .below, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Spacer(minLength: 3)
        }
    }

    private var large: some View {
        let metrics = entry.displays
        let hero = metrics[0]
        return VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(entry: entry, showAge: false)
            HStack(spacing: 14) {
                UsageRing(metric: hero, size: 96, stroke: 9)
                    .opacity(entry.isStale ? 0.75 : 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(hero.name)
                        .font(.system(size: 14, weight: .semibold))
                    MetricCaption(metric: hero, font: .system(size: 11.5))
                    if hero.kind == .session {
                        Text("5-hour window")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 12)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                ForEach(metrics.dropFirst().prefix(4)) { MetricBarRow(metric: $0, showCaption: false) }
            }
            .opacity(entry.isStale ? 0.8 : 1)
            .padding(.top, 12)
            Spacer(minLength: 6)
            WidgetFooter(entry: entry)
        }
    }
}

// MARK: - Widgets

struct UsageBarsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "UsageBars", intent: PlanIntent.self, provider: UsageTimeline()) { entry in
            BarsWidgetView(entry: entry)
        }
        .configurationDisplayName("Plan Limits: Bars")
        .description("Claude's or Codex's limits as bars, with resets and pace. The large size adds the week's left-over-time curve.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct UsageRingsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "UsageRings", intent: PlanIntent.self, provider: UsageTimeline()) { entry in
            RingsWidgetView(entry: entry)
        }
        .configurationDisplayName("Plan Limits: Rings")
        .description("Claude's or Codex's limits as rings in each window's colour, with resets.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

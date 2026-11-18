import AppKit
import SwiftUI
import WidgetKit

// The menu bar's label and popover, and the desktop widgets, drawn offscreen:
//
//   GraphitreeShots widgets <dir>/ [-sample YES] [-plan codex] [-showLeft YES]
//
// They show Graphitree's last stored Claude reading and its history, the way the app's feed
// would; `-sample YES` uses made-up figures instead, for the README. Nothing is read from the
// keychain or the network, and nothing is written but the PNGs.

enum WidgetSize {
    static let small = CGSize(width: 170, height: 170)
    static let medium = CGSize(width: 364, height: 170)
    static let large = CGSize(width: 364, height: 382)
    static let cornerRadius: CGFloat = 22
}

@MainActor
func shootWidgets(folder: URL) async throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let defaults = UserDefaults.standard
    let now = Date()
    let provider = defaults.string(forKey: "plan").flatMap(UsageProvider.init(rawValue:)) ?? .claude
    let showLeft = defaults.bool(forKey: "showLeft")
    let feed = defaults.bool(forKey: "sample") ? sampleFeed(now: now, showLeft: showLeft) : storedFeed(now: now, showLeft: showLeft)

    func entry() -> UsageEntry { UsageEntry(date: now, provider: provider, feed: feed) }

    try await render(PopoverChrome { MenuBarView() }, size: nil, to: folder.appendingPathComponent("popover.png"))
    let figures = feed.plan(provider)?.limits.map { MenuBarIcon.figures($0.asOf(now).windows, showLeft: showLeft) }
        ?? MenuBarIcon.figures(feed.plan(provider)?.snapshot?.asOf(now), showLeft: showLeft)
    try await render(Image(nsImage: MenuBarIcon.label(figures)).renderingMode(.template).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(white: 0.16)),
                     size: nil, to: folder.appendingPathComponent("menubar.png"))
    for (name, family, size) in [("small", WidgetFamily.systemSmall, WidgetSize.small),
                                 ("medium", .systemMedium, WidgetSize.medium),
                                 ("large", .systemLarge, WidgetSize.large)] {
        try await render(WidgetChrome(size: size) { BarsWidgetView(entry: entry(), drawnFamily: family) },
                         size: size, to: folder.appendingPathComponent("widget-bars-\(name).png"))
        try await render(WidgetChrome(size: size) { RingsWidgetView(entry: entry(), drawnFamily: family) },
                         size: size, to: folder.appendingPathComponent("widget-rings-\(name).png"))
    }
    // Before Graphitree has written anything.
    try await render(WidgetChrome(size: WidgetSize.small) {
        BarsWidgetView(entry: UsageEntry(date: now, provider: provider, feed: nil), drawnFamily: .systemSmall)
    }, size: WidgetSize.small, to: folder.appendingPathComponent("widget-empty-small.png"))
    print("wrote \(folder.path)")
}

/// What the app's feed would hold now, from Graphitree's stored reading and history.
@MainActor
private func storedFeed(now: Date, showLeft: Bool) -> WidgetFeed {
    let refresher = UsageRefresher.shared
    var claude = WidgetFeed.Plan(snapshot: refresher.reading, name: refresher.profile?.plan)
    if let reading = refresher.reading {
        let samples = UsageHistory.load(since: now.addingTimeInterval(-8 * 86400))
        claude.trend = WidgetFeed.Trend.make(samples: samples, snapshot: reading.asOf(now), now: now)
    } else {
        claude.problem = UsageFeed.claudeProblem(refresher)
    }
    return WidgetFeed(written: now, showLeft: showLeft, metrics: MenuBarSettings.metrics,
                      plans: [.claude: claude, .codex: WidgetFeed.Plan(problem: "Codex hasn't run on this Mac.")])
}

/// Made-up figures: a week used steadily, for the README.
private func sampleFeed(now: Date, showLeft: Bool) -> WidgetFeed {
    let weeklyReset = now.addingTimeInterval(4 * 86400 + 5 * 3600)
    let start = weeklyReset.addingTimeInterval(-7 * 86400)
    let samples: [UsageSample] = stride(from: start, through: now, by: 1800).map { at in
        let day = at.timeIntervalSince(start) / 86400
        return UsageSample(ts: at, session: nil, weekly: min(100, day * 14), opus: nil, sonnet: nil, fable: min(100, day * 6),
                           sessionReset: nil, weeklyReset: weeklyReset, fableReset: weeklyReset, opusReset: nil, sonnetReset: nil)
    }
    let snapshot = UsageSnapshot(fetchedAt: now.addingTimeInterval(-90),
                                 session: UsageWindow(utilization: 74, resetsAt: now.addingTimeInterval(40 * 60)),
                                 weekly: UsageWindow(utilization: (samples.last?.weekly ?? 0).rounded(), resetsAt: weeklyReset),
                                 weeklyOpus: nil, weeklySonnet: nil, extra: nil,
                                 weeklyFable: UsageWindow(utilization: (samples.last?.fable ?? 0).rounded(), resetsAt: weeklyReset))
    let claude = WidgetFeed.Plan(snapshot: snapshot, name: "Max 5x",
                                 trend: WidgetFeed.Trend.make(samples: samples, snapshot: snapshot, now: now))
    let codex = WidgetFeed.Plan(snapshot: UsageSnapshot(fetchedAt: now.addingTimeInterval(-2 * 3600),
                                                        session: UsageWindow(utilization: 12, resetsAt: now.addingTimeInterval(3 * 3600)),
                                                        weekly: UsageWindow(utilization: 31, resetsAt: weeklyReset),
                                                        weeklyOpus: nil, weeklySonnet: nil, extra: nil),
                                name: "ChatGPT Plus")
    // Made-up readings for the tools that report LimitReading.
    let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now
    let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? now
    let copilot = WidgetFeed.Plan(limits: LimitReading(fetchedAt: now.addingTimeInterval(-90), windows: [
        LimitWindow(id: "premium", title: "Premium requests", utilization: 64, resetsAt: nextMonth,
                    span: nextMonth.timeIntervalSince(monthStart), detail: "192 of 300 used"),
    ], plan: "Copilot Pro"), name: "Copilot Pro")
    let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
    let gemini = WidgetFeed.Plan(limits: LimitReading(fetchedAt: now.addingTimeInterval(-120), windows: [
        LimitWindow(id: "gemini-2.5-pro", title: "Gemini 2.5 Pro · daily", utilization: 38, resetsAt: tomorrow, span: 86400),
        LimitWindow(id: "gemini-2.5-flash", title: "Gemini 2.5 Flash · daily", utilization: 12, resetsAt: tomorrow, span: 86400),
    ], plan: "Code Assist Standard"), name: "Code Assist Standard")
    return WidgetFeed(written: now, showLeft: showLeft, metrics: [.session, .weekly, .weeklyFable],
                      plans: [.claude: claude, .codex: codex, .copilot: copilot, .gemini: gemini])
}

// MARK: - Drawing

/// Draws `view` in a borderless window that's never put on screen and writes a 2x PNG,
/// transparent wherever the view draws nothing. `size` nil: the view's own size.
@MainActor
private func render(_ view: some View, size: CGSize?, to url: URL) async throws {
    let dark = NSAppearance(named: .darkAqua)
    let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .dark))
    hosting.appearance = dark
    hosting.frame = CGRect(origin: .zero, size: size ?? hosting.fittingSize)
    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.isOpaque = false
    window.backgroundColor = .clear
    window.appearance = dark
    window.contentView = hosting
    defer { window.contentView = nil; window.close() }
    try await Task.sleep(for: .seconds(0.6))
    if size == nil { hosting.setFrameSize(hosting.fittingSize) }
    hosting.layoutSubtreeIfNeeded()
    let points = hosting.bounds.size
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int((points.width * 2).rounded()),
                                        pixelsHigh: Int((points.height * 2).rounded()), bitsPerSample: 8, samplesPerPixel: 4,
                                        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { throw ShotError(message: "couldn't make a bitmap for \(url.lastPathComponent)") }
    bitmap.size = points
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw ShotError(message: "couldn't encode \(url.lastPathComponent)")
    }
    try png.write(to: url)
}

/// The menu bar's window: a rounded dark panel.
private struct PopoverChrome<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Color(red: 0.165, green: 0.165, blue: 0.175), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A desktop widget as macOS draws one: its size, margins, background and corners.
private struct WidgetChrome<Content: View>: View {
    let size: CGSize
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WidgetSize.cornerRadius, style: .continuous)
        content
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background {
                ZStack {
                    shape.fill(Color(red: 0.13, green: 0.13, blue: 0.14))
                    shape.fill(.fill.tertiary)
                }
            }
            .clipShape(shape)
    }
}

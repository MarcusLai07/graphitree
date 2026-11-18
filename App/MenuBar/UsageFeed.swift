import Combine
import Foundation
import WidgetKit

/// Codex's plan limits for the menu bar and widgets, from its own logs. They change only when
/// Codex runs, so the logs are read again only after Codex writes to them. The Usage page reads
/// all of Codex's history itself (`AnalyticsModel.codex`); this reads the last week.
@MainActor
final class CodexLimits: ObservableObject {
    static let shared = CodexLimits()

    /// The latest reading as Codex logged it.
    @Published private(set) var reading: UsageSnapshot?
    /// "Plus", "Pro".
    @Published private(set) var plan: String?
    /// Every reading this week, oldest first, for the pace and the large widget's curve.
    @Published private(set) var history: [UsageSample] = []
    @Published private(set) var hasSessions = false
    @Published private(set) var isReading = false
    @Published private(set) var lastRead: Date?

    /// The screenshot tool turns this off.
    static var readsLogs = true
    static let lookBack: TimeInterval = 8 * 86400

    /// The latest reading as it stands now: windows that have reset since read 0%.
    var snapshot: UsageSnapshot? { reading?.asOf(Date()) }

    private init() {}

    /// Reads the last week of Codex's logs, if they changed since the last read or `force`.
    /// Returns whether it read them.
    @discardableResult
    func refresh(force: Bool = false) async -> Bool {
        guard Self.readsLogs, !isReading else { return false }
        isReading = true
        defer { isReading = false }
        let home = CodexSessions.home
        let started = Date()
        let since = started.addingTimeInterval(-Self.lookBack)
        let changedSince = force ? nil : lastRead
        // Off the main thread: checking for changes walks every log Codex has kept.
        let outcome = await Task.detached(priority: .utility) { () -> (hasSessions: Bool, scan: CodexScan?) in
            guard CodexSessions.hasSessions(home: home) else { return (false, nil) }
            if let changedSince, !CodexSessions.hasChanges(home: home, since: changedSince) { return (true, nil) }
            return (true, CodexSessions.scan(home: home, since: since))
        }.value
        hasSessions = outcome.hasSessions
        guard hasSessions else {
            reading = nil
            plan = nil
            history = []
            lastRead = started
            return false
        }
        guard let scan = outcome.scan else { return false }
        reading = scan.latest
        plan = scan.plan
        history = scan.limits
        lastRead = started
        return true
    }
}

/// Keeps the plan's limits read while Graphitree runs, window or not, and passes each reading on:
/// to the desktop widgets through the app group's feed, and to notifications. Started at launch.
@MainActor
final class UsageFeed {
    static let shared = UsageFeed()

    /// The screenshot tool turns this off: it never reads, writes or notifies.
    static var isEnabled = true

    private var timer: Timer?
    private var observers: [AnyCancellable] = []
    private var written: WidgetFeed?
    private var pending: Task<Void, Never>?
    /// What the widgets show apart from the readings, to tell a change that matters from the
    /// rest of Graphitree's settings.
    private var shownSettings = ""
    private var claudeTrend: (key: Date?, trend: WidgetFeed.Trend?) = (nil, nil)
    private var codexTrend: (key: Date?, trend: WidgetFeed.Trend?) = (nil, nil)

    private init() {}

    func start() {
        guard Self.isEnabled, timer == nil else { return }
        let refresher = UsageRefresher.shared
        // Keeps the plan-limit history going once the Usage page has read it before, while AI
        // Models lists Claude Code.
        if ShownProviders.shared.contains(.claude) { refresher.startIfEnabled() }
        refresher.$lastAttempt
            .dropFirst()
            .sink { [weak self] _ in self?.claudeDidRead() }
            .store(in: &observers)
        shownSettings = Self.settingsKey()
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.settingsChanged() }
            .store(in: &observers)
        let timer = Timer(timeInterval: UsageRefresher.refreshInterval, repeats: true) { _ in
            Task { @MainActor in
                ShownProviders.shared.refresh()
                await UsageFeed.shared.readCodex()
                await UsageFeed.shared.readTools()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Task {
            await readCodex()
            await readTools()
        }
    }

    /// Stops reading, so nothing is written while Graphitree uninstalls itself.
    func stop() {
        timer?.invalidate()
        timer = nil
        observers.removeAll()
        pending?.cancel()
    }

    /// Every shown plan read again now, for the popover's refresh button. Claude only once its
    /// readings have started, so the button never raises the keychain prompt by surprise.
    func refreshAll() async {
        let refresher = UsageRefresher.shared
        if refresher.isRunning, ShownProviders.shared.contains(.claude) { await refresher.refresh(force: true) }
        await readCodex(force: true)
        await readTools(force: true)
    }

    /// AI Models now lists other tools: start reading the ones that joined, and redraw the
    /// widgets with only the shown ones.
    func shownChanged() {
        guard timer != nil else { return }
        if ShownProviders.shared.contains(.claude) { UsageRefresher.shared.startIfEnabled() }
        Task {
            await readCodex(force: true)
            await readTools(force: true)
        }
    }

    /// The shown tools whose limits come as `LimitReading`: Gemini CLI, Copilot and OpenCode.
    func readTools(force: Bool = false) async {
        for provider in ShownProviders.shared.providers {
            guard let model = ToolLimitsModel.of(provider) else { continue }
            await model.refresh(force: force)
            if let reading = model.current, model.problem == nil {
                UsageAlerts.check(provider, reading: reading)
            }
        }
        schedulePublish()
    }

    private func claudeDidRead() {
        let refresher = UsageRefresher.shared
        if refresher.lastError == nil, let snapshot = refresher.snapshot, ShownProviders.shared.contains(.claude) {
            UsageAlerts.check(.claude, snapshot: snapshot, samples: nil)
        }
        schedulePublish()
    }

    func readCodex(force: Bool = false) async {
        // Codex's logs are walked only while AI Models lists Codex.
        guard ShownProviders.shared.contains(.codex) else {
            schedulePublish()
            return
        }
        let codex = CodexLimits.shared
        await codex.refresh(force: force)
        // Every tick, new logs or not: the reset reminder is due by the clock, most often while
        // Codex sits unused. Each alert still fires once per cycle.
        if let snapshot = codex.snapshot {
            UsageAlerts.check(.codex, snapshot: snapshot, samples: codex.history)
        }
        schedulePublish()
    }

    private static func settingsKey() -> String {
        let defaults = UserDefaults.standard
        return [defaults.bool(forKey: ClaudeUsageStore.Key.showLeft) ? "left" : "used",
                defaults.string(forKey: MenuBarSettings.Key.metrics) ?? ""].joined(separator: "|")
    }

    private func settingsChanged() {
        let key = Self.settingsKey()
        guard key != shownSettings else { return }
        shownSettings = key
        schedulePublish()
    }

    /// Writes once things settle: a slider or a burst of readings makes one write.
    func schedulePublish() {
        pending?.cancel()
        pending = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.publish()
        }
    }

    /// Writes the feed and has the widgets redraw when what they show changed. An unchanged feed
    /// is still written every ten minutes, so the widgets can tell Graphitree is running.
    func publish() async {
        let now = Date()
        let feed = await makeFeed(now: now)
        let changed = !feed.sameContent(as: written)
        if !changed, let written, now.timeIntervalSince(written.written) < 10 * 60 { return }
        guard WidgetFeedStore.write(feed) else { return }
        written = feed
        if changed { WidgetCenter.shared.reloadAllTimelines() }
    }

    // MARK: The feed

    /// Only the shown providers' plans, so the widgets offer only those.
    private func makeFeed(now: Date) async -> WidgetFeed {
        var plans: [UsageProvider: WidgetFeed.Plan] = [:]
        for provider in ShownProviders.shared.providers {
            switch provider {
            case .claude: plans[provider] = await claudePlan(now: now)
            case .codex: plans[provider] = codexPlan(now: now)
            case .gemini, .copilot, .opencode: plans[provider] = toolPlan(provider)
            }
        }
        return WidgetFeed(written: now, showLeft: ClaudeUsageStore.showLeft, metrics: MenuBarSettings.metrics, plans: plans)
    }

    private func claudePlan(now: Date) async -> WidgetFeed.Plan {
        let refresher = UsageRefresher.shared
        var claude = WidgetFeed.Plan()
        claude.snapshot = refresher.reading
        claude.name = refresher.profile?.plan
        claude.isStale = refresher.isStale
        if refresher.reading == nil { claude.problem = Self.claudeProblem(refresher) }
        if let reading = refresher.reading {
            if claudeTrend.key != reading.fetchedAt {
                let snapshot = reading.asOf(now)
                let trend = await Task.detached(priority: .utility) { () -> WidgetFeed.Trend? in
                    let since = now.addingTimeInterval(-(MetricKind.weekly.span ?? 0) - 3600)
                    return WidgetFeed.Trend.make(samples: UsageHistory.load(since: since), snapshot: snapshot, now: now)
                }.value
                claudeTrend = (reading.fetchedAt, trend)
            }
            claude.trend = claudeTrend.trend
        }
        return claude
    }

    private func toolPlan(_ provider: UsageProvider) -> WidgetFeed.Plan {
        var plan = WidgetFeed.Plan()
        guard let model = ToolLimitsModel.of(provider) else { return plan }
        plan.limits = model.reading
        plan.name = model.reading?.plan
        plan.isStale = model.isStale
        if model.reading == nil {
            plan.problem = model.problem?.message ?? (model.lastAttempt == nil ? "Reading \(provider.name)'s limits…" : "No limits to show.")
        }
        return plan
    }

    private func codexPlan(now: Date) -> WidgetFeed.Plan {
        let codex = CodexLimits.shared
        var codexPlan = WidgetFeed.Plan()
        codexPlan.snapshot = codex.reading
        codexPlan.name = codex.plan.map { "ChatGPT \($0)" }
        if !codex.hasSessions {
            codexPlan.problem = "Codex hasn't run on this Mac."
        } else if codex.reading == nil {
            codexPlan.problem = codex.lastRead == nil ? "Reading Codex's logs…" : "No plan limits in Codex's logs this week."
        } else if let reading = codex.reading {
            if codexTrend.key != codex.lastRead {
                codexTrend = (codex.lastRead, WidgetFeed.Trend.make(samples: codex.history, snapshot: reading.asOf(now), now: now))
            }
            codexPlan.trend = codexTrend.trend
        }
        return codexPlan
    }

    /// Why there's no Claude reading, as the widget says it.
    static func claudeProblem(_ refresher: UsageRefresher) -> String {
        guard refresher.isRunning else { return "Open Usage in Graphitree to start reading Claude's limits." }
        switch refresher.lastError {
        case .none: return "Reading Claude's limits…"
        case .notSignedIn?: return "Claude Code isn't signed in on this Mac."
        case .keychainDenied?: return "Graphitree needs to read Claude Code's sign-in."
        case .tokenExpired?: return "Claude Code's sign-in ran out."
        case .signInExpired?: return "Graphitree's sign-in to Claude ran out."
        case .http(401)?: return refresher.hasOwnSignIn ? "Anthropic turned down Graphitree's sign-in." : "Anthropic turned down Claude Code's sign-in."
        case .offline?: return "Offline."
        default: return "Couldn't read the plan's limits."
        }
    }
}

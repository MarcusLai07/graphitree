import SwiftUI

enum UsageTab: String, CaseIterable, Identifiable {
    case overview, requests, sessions, context

    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .requests: return "Requests"
        case .sessions: return "Sessions"
        case .context: return "Context"
        }
    }
}

/// The Usage page: a plan's limits (always "now") and its coding tool's activity on this Mac, for
/// Claude or Codex, laid out as Claude Usage's window, which follows Magpie's. The provider switch
/// sits in the header, then one toolbar row (tabs, period, refresh, the period's cost), then the tab.
struct UsageView: View {
    @ObservedObject private var refresher = UsageRefresher.shared
    @ObservedObject private var claudeTrends = TrendModel.claude
    @ObservedObject private var codexTrends = TrendModel.codex
    @ObservedObject private var claudeAnalytics = AnalyticsModel.claude
    @ObservedObject private var codexAnalytics = AnalyticsModel.codex

    @AppStorage(ClaudeUsageStore.Key.provider) private var provider: UsageProvider = .claude
    @AppStorage(ClaudeUsageStore.Key.showLeft) private var showLeft = false
    @AppStorage(ClaudeUsageStore.Key.hideAccount) private var hideAccount = false
    @AppStorage(ClaudeUsageStore.Key.period) private var period: UsagePeriod = .week
    @AppStorage(ClaudeUsageStore.Key.trendRange) private var trendRange: TrendRange = .cycle
    @State private var tab: UsageTab = UsageView.startTab
    @State private var sessionFilter: String?
    @State private var editingRange = false
    /// Bumped when the custom range changes, to redraw what depends on it.
    @State private var rangeTick = 0

    let openModels: () -> Void

    /// `-usageTab requests` opens a tab at launch, for screenshots.
    private static var startTab: UsageTab {
        UserDefaults.standard.string(forKey: "usageTab").flatMap(UsageTab.init(rawValue:)) ?? .overview
    }

    private var analytics: AnalyticsModel { provider == .claude ? claudeAnalytics : codexAnalytics }
    private var trends: TrendModel { provider == .claude ? claudeTrends : codexTrends }

    /// The plan's limits as they stand now: Claude's last reading, or Codex's last logged one.
    private var limits: UsageSnapshot? {
        switch provider {
        case .claude: return refresher.snapshot
        case .codex: return codexAnalytics.limits?.asOf(Date())
        }
    }

    /// Context tunes Claude Code's own settings, so Codex has no such tab.
    private var tabs: [UsageTab] {
        provider == .claude ? UsageTab.allCases : UsageTab.allCases.filter { $0 != .context }
    }

    private var shownTab: UsageTab { tabs.contains(tab) ? tab : .overview }

    private var subtitle: String {
        switch provider {
        case .claude: return "Claude's plan limits, and what Claude Code used on this Mac"
        case .codex: return "Codex's plan limits and what it used on this Mac, from its own logs"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Usage", subtitle: subtitle) {
                providerSwitch
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            toolbar
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            Rectangle().fill(Palette.hairline).frame(height: 1)
            // A new provider starts its tabs afresh: a filter on one's sessions would hide the other's.
            content
                .id("\(provider.rawValue)-\(rangeTick)")
        }
        .environmentObject(refresher)
        // Claude's readings borrow Claude Code's sign-in, which can raise the keychain prompt, so
        // they start only once Claude is shown.
        .onAppear { if provider == .claude { refresher.start() } }
        .onChange(of: provider) { _, new in
            sessionFilter = nil
            if new == .claude { refresher.start() }
        }
        .task(id: reloadKey) { await keepCurrent() }
    }

    /// Claude: each reading may have added a history sample, and Claude Code new transcript lines.
    /// Codex: its logs change as it runs, so they're read again every minute while shown.
    private var reloadKey: String {
        provider == .claude ? "claude-\(refresher.snapshot?.fetchedAt.timeIntervalSince1970 ?? 0)" : "codex"
    }

    private func keepCurrent() async {
        switch provider {
        case .claude:
            await claudeTrends.reload()
            // Reopening the panel within a minute of a scan shows that scan as it is.
            await claudeAnalytics.reload(maxAge: 60)
        case .codex:
            while !Task.isCancelled {
                await codexAnalytics.reload(maxAge: 30)
                await codexTrends.reload(samples: codexAnalytics.limitHistory)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private var providerSwitch: some View {
        Picker("Provider", selection: $provider) {
            ForEach(UsageProvider.allCases) { Text($0.name).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("Whose plan and usage to show")
    }

    // MARK: Toolbar

    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                tabPicker
                periodControls
                Spacer(minLength: 8)
                trailing
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    tabPicker
                    Spacer(minLength: 8)
                    trailing
                }
                periodControls
            }
        }
    }

    private var tabPicker: some View {
        PillTabs(options: tabs.map { ($0, $0.title) }, selection: Binding(get: { shownTab }, set: { tab = $0 }))
    }

    private var periodControls: some View {
        HStack(spacing: 6) {
            PillTabs(options: UsagePeriod.allCases.map { ($0, $0.title) }, selection: $period)
            if period == .custom {
                Button {
                    editingRange = true
                } label: {
                    Label(rangeLabel, systemImage: "calendar")
                        .font(.system(size: 12))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.track, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $editingRange, arrowEdge: .bottom) {
                    CustomRangeEditor { rangeTick &+= 1 }
                }
            }
        }
    }

    private var rangeLabel: String {
        let range = UsagePeriod.customRange
        let style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(range.lowerBound.formatted(style)) – \(range.upperBound.formatted(style))"
    }

    private var trailing: some View {
        HStack(spacing: 10) {
            limitStatus
            switch provider {
            case .claude:
                if let fetchedAt = refresher.snapshot?.fetchedAt {
                    AgeIndicator(since: fetchedAt, stale: refresher.isStale)
                }
                RefreshButton(isRefreshing: refresher.isRefreshing, help: "Read the limits now") {
                    await refresher.refresh(force: true)
                }
            case .codex:
                if let fetchedAt = codexAnalytics.limits?.fetchedAt {
                    AgeIndicator(since: fetchedAt)
                        .help("The limits as of Codex's last reply. They change only when Codex runs.")
                }
                RefreshButton(isRefreshing: codexAnalytics.isLoading, help: "Read Codex's logs again") {
                    await codexAnalytics.reload()
                    await codexTrends.reload(samples: codexAnalytics.limitHistory)
                }
            }
            if analytics.hasLogs, analytics.lastLoaded != nil {
                let cost = analytics.overview(period).totals.cost
                (Text(costText(cost)).font(.system(size: 15, weight: .semibold).monospacedDigit())
                 + Text("  API prices").font(.system(size: 11)).foregroundStyle(.secondary))
                    .fixedSize()
                    .help("What \(period == .custom ? "this range" : period.title.lowercased())'s \(provider.toolName) calls would cost at \(provider == .claude ? "Anthropic" : "OpenAI") API list prices")
            }
        }
    }

    /// The session warning pill, or just its icon when the header is narrow.
    @ViewBuilder
    private var limitStatus: some View {
        let sessionPercent = limits?.session?.utilization ?? 0
        if sessionPercent >= 70 {
            let text = sessionPercent >= 100 ? "Session limit reached" : "Approaching session limit"
            let color: Color = sessionPercent >= 100 ? .red : .orange
            ViewThatFits(in: .horizontal) {
                UsageStatusPill(text: text, color: color)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                    .help(text)
            }
        }
    }

    // MARK: Tabs

    @ViewBuilder
    private var content: some View {
        switch shownTab {
        case .overview:
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if provider == .claude, let error = refresher.lastError {
                        SignInNotice(error: error, hasReading: refresher.snapshot != nil, openModels: openModels)
                    }
                    if provider == .codex, !codexAnalytics.hasLogs {
                        CodexMissing()
                    } else {
                        allowances
                        ClaudeCodeSection(analytics: analytics, period: period)
                    }
                }
                .padding(20)
            }
        case .requests:
            ScrollView {
                RequestsView(analytics: analytics, period: period, sessionFilter: $sessionFilter)
                    .padding(20)
            }
        case .sessions:
            ScrollView {
                SessionsView(analytics: analytics, period: period) { session in
                    sessionFilter = session
                    tab = .requests
                }
                .padding(20)
            }
        case .context:
            ScrollView {
                ContextView(analytics: analytics, period: period)
                    .padding(20)
            }
        }
    }

    private var allowances: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SectionLabel("Allowances")
                Spacer()
                Menu {
                    Picker("Trends", selection: $trendRange) {
                        ForEach(TrendRange.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Text("Trends: \(trendRange.title)")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .tint(.primary)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.track, in: RoundedRectangle(cornerRadius: 7))
                .help("What was left over time, under the limits")
                // Codex's logs carry no account name, so there's nothing to hide.
                if provider == .claude {
                    Button {
                        hideAccount.toggle()
                    } label: {
                        Label(hideAccount ? "Show account" : "Hide account",
                              systemImage: hideAccount ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Mask the account email, for screenshots")
                }
                PillTabs(options: [(false, "Used"), (true, "Left")], selection: $showLeft, size: 12)
            }
            switch provider {
            case .claude: claudeAllowances
            case .codex: codexAllowances
            }
        }
    }

    @ViewBuilder
    private var claudeAllowances: some View {
        if let snapshot = refresher.snapshot {
            AllowancesCard(snapshot: snapshot, profile: refresher.profile,
                           hideAccount: hideAccount, showLeft: $showLeft,
                           isStale: refresher.isStale, trends: claudeTrends)
        } else if refresher.lastError != nil {
            Text("No reading yet.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .designCard()
        } else {
            ProgressView("Loading usage…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .designCard()
        }
    }

    @ViewBuilder
    private var codexAllowances: some View {
        if let snapshot = codexAnalytics.limits {
            AllowancesCard(snapshot: snapshot.asOf(Date()),
                           profile: AccountProfile(email: nil, plan: codexAnalytics.plan.map { "ChatGPT \($0)" }, fetchedAt: snapshot.fetchedAt),
                           showLeft: $showLeft, trends: codexTrends, provider: .codex,
                           caption: "As of Codex's last reply, \(snapshot.fetchedAt.formatted(.relative(presentation: .named)))")
        } else if codexAnalytics.lastLoaded == nil {
            ProgressView("Reading Codex's logs…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .designCard()
        } else {
            EmptyStateView(icon: "gauge.with.dots.needle.0percent", title: "No plan limits in Codex's logs",
                           message: "Codex logs its plan's limits with each reply when it's signed in with ChatGPT. Signed in with an API key, it has no plan limits, only the calls below.")
                .designCard()
        }
    }
}

/// Codex hasn't left any session logs on this Mac.
struct CodexMissing: View {
    var body: some View {
        EmptyStateView(icon: "terminal", title: "Codex hasn't run on this Mac",
                       message: "Its plan's limits and every call appear here once Codex has run, from its session logs in \(UsageProvider.codex.logsPath). Codex CLI, its VS Code extension and the Codex app all write them.")
            .designCard()
    }
}

/// Picks the Custom period's first and last day.
struct CustomRangeEditor: View {
    var onChange: () -> Void
    @State private var start = UsagePeriod.customRange.lowerBound
    @State private var end = UsagePeriod.customRange.upperBound

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom range")
                .font(.system(size: 12.5, weight: .semibold))
            DatePicker("From", selection: $start, in: ...Date(), displayedComponents: .date)
            DatePicker("To", selection: $end, in: start...max(start, Date()), displayedComponents: .date)
        }
        .datePickerStyle(.field)
        .padding(14)
        .frame(width: 240)
        .onChange(of: start) { _, _ in save() }
        .onChange(of: end) { _, _ in save() }
    }

    private func save() {
        UsagePeriod.customRange = min(start, end)...max(start, end)
        onChange()
    }
}

/// Why the plan limits couldn't be read, and the way out: Claude Code's sign-in, the keychain
/// prompt, or a retry. The token activity below never depends on it.
///
/// When the trouble is Claude Code's sign-in, it says what AI Models' own check of Claude Code
/// found (`claude auth status`), so the two pages never disagree, and offers the same fix.
struct SignInNotice: View {
    @EnvironmentObject private var refresher: UsageRefresher
    @Environment(AppModel.self) private var model
    let error: UsageAPIError
    let hasReading: Bool
    let openModels: () -> Void

    /// What AI Models last found for Claude Code, when it found something wrong with its sign-in.
    private var claudeProblem: ConnectionHealth? {
        guard isSignInTrouble, let health = model.connectionHealth[ClaudeCodeSignIn.connectionID],
              health.level >= .warning, health.fix == .signIn else { return nil }
        return health
    }

    private var isSignInTrouble: Bool {
        switch error {
        case .notSignedIn, .tokenExpired, .http(401): return true
        default: return false
        }
    }

    private var isWarning: Bool {
        switch error {
        case .notSignedIn, .keychainDenied, .http(401): return true
        default: return false
        }
    }

    private var title: String {
        if let claudeProblem { return "Claude Code: \(claudeProblem.status)" }
        switch error {
        case .notSignedIn: return "Claude Code isn't signed in on this Mac"
        case .keychainDenied: return "Graphitree needs to read Claude Code's sign-in"
        case .tokenExpired: return "Claude Code's sign-in needs renewing"
        case .http(401): return "Anthropic turned down Claude Code's sign-in"
        case .offline: return "Offline"
        default: return "Couldn't read the plan's limits"
        }
    }

    private var detail: String {
        if let claudeProblem { return claudeProblem.detail + " The limits come from Claude Code's sign-in." }
        switch error {
        case .notSignedIn:
            return "The limits come from Claude Code's sign-in. Claude Code's activity below doesn't need it."
        case .keychainDenied:
            return "Claude Code keeps its sign-in in your keychain. Graphitree only reads it, to ask Anthropic for your plan's limits, and never changes it. Choose Always Allow when macOS asks."
        case .tokenExpired:
            return "Claude Code renews it the next time it runs. Graphitree never renews it itself, so it can't sign Claude Code out."
        case .http(401):
            return "Sign in to Claude Code again."
        default:
            return (error.errorDescription ?? "") + "."
        }
    }

    /// Signing in again needs Claude Code on this Mac; AI Models has it when it found it.
    private var canSignIn: Bool { model.connectionHealth[ClaudeCodeSignIn.connectionID] != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isWarning ? "key.horizontal" : (error == .offline ? "wifi.slash" : "clock.badge.exclamationmark"))
                .foregroundStyle(Palette.gold)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if hasReading, let fetchedAt = refresher.snapshot?.fetchedAt {
                    (Text("Showing the reading from ") + Text(fetchedAt, style: .relative) + Text(" ago."))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
            action
        }
        .modifier(RowCard())
    }

    @ViewBuilder
    private var action: some View {
        if claudeProblem != nil || ((error == .notSignedIn || error == .http(401)) && canSignIn) {
            Button("Sign In Again") { model.signInToClaudeCode() }
                .buttonStyle(GoldButtonStyle())
                .help("Opens Terminal with claude auth login. Sign-in happens in your browser.")
        } else {
            switch error {
            case .notSignedIn, .http(401):
                Button("Open AI Models", action: openModels).buttonStyle(SoftButtonStyle())
            case .keychainDenied:
                Button("Try Again") { Task { await refresher.retrySignIn() } }.buttonStyle(GoldButtonStyle())
            default:
                Button("Try Again") { Task { await refresher.refresh(force: true) } }.buttonStyle(SoftButtonStyle())
            }
        }
    }
}

import AppKit
import SwiftUI

/// The menu bar item: Graphitree's mark, with Session over Weekly beside it for the plan picked in
/// the Usage page's settings. It's the one view that's always there while the item is on, so it
/// also lends the rest of the app a way to open the main window.
struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var refresher = UsageRefresher.shared
    @ObservedObject private var codex = CodexLimits.shared
    @AppStorage(MenuBarSettings.Key.figures) private var savedFigures: MenuBarFigures = .claude
    @ObservedObject private var shown = ShownProviders.shared
    @AppStorage(ClaudeUsageStore.Key.showLeft) private var showLeft = false

    /// The saved choice, or the first shown provider when the saved one isn't shown any more.
    private var figures: MenuBarFigures { savedFigures.effective(shown: shown.providers) }

    var body: some View {
        Image(nsImage: MenuBarIcon.label(MenuBarIcon.figures(snapshot, showLeft: showLeft)))
            .accessibilityLabel(accessibilityText)
            .onAppear {
                MainWindow.open = { [openWindow] in openWindow(id: "main") }
            }
    }

    private var snapshot: UsageSnapshot? {
        switch figures.provider {
        case .claude?: return refresher.snapshot
        case .codex?: return codex.snapshot
        case nil: return nil
        }
    }

    private var accessibilityText: String {
        guard let provider = figures.provider, let snapshot else { return "Graphitree" }
        let parts = [("session", snapshot.session), ("weekly", snapshot.weekly)].compactMap { name, window -> String? in
            guard let window else { return nil }
            return "\(name) \(MenuBarIcon.figure(window, showLeft: showLeft))% \(showLeft ? "left" : "used")"
        }
        return "Graphitree, \(provider.name) " + parts.joined(separator: ", ")
    }
}

/// The menu bar's popover: each plan's limits as the Usage page shows them, then the way into
/// the window.
struct MenuBarView: View {
    @ObservedObject private var refresher = UsageRefresher.shared
    @ObservedObject private var codex = CodexLimits.shared
    @ObservedObject private var shown = ShownProviders.shared
    @AppStorage(ClaudeUsageStore.Key.showLeft) private var showLeft = false
    @AppStorage(MenuBarSettings.Key.metrics) private var metricsText = MenuBarSettings.defaultMetricsText
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            // The tools AI Models lists under Connected, in the Usage page's order.
            ForEach(shown.providers) { provider in
                Divider().padding(.horizontal, 12)
                PlanSection(provider: provider, metrics: provider == .claude ? MenuBarSettings.parse(metricsText) : [.session, .weekly],
                            showLeft: showLeft)
            }
            if shown.providers.isEmpty {
                Divider().padding(.horizontal, 12)
                Text("Connect an AI tool in Graphitree's AI Models to see its plan's limits here.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.init(top: 11, leading: 14, bottom: 12, trailing: 14))
            }
            Divider()
                .padding(.top, 2)
            footer
        }
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: MenuBarIcon.mark)
                .renderingMode(.template)
                .foregroundStyle(Palette.jade)
            Text("Graphitree")
                .font(.headline)
            Spacer()
            if isRefreshing || refresher.isRefreshing || codex.isReading {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task {
                        isRefreshing = true
                        await UsageFeed.shared.refreshAll()
                        isRefreshing = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Read the limits now")
            }
        }
        .padding(.init(top: 12, leading: 14, bottom: 10, trailing: 14))
    }

    private var footer: some View {
        VStack(spacing: 1) {
            Button { MainWindow.show(.usage(nil)) } label: {
                MenuRow(icon: "gauge.with.dots.needle.33percent", title: "Open Usage", shortcut: "⌘U")
            }
            .keyboardShortcut("u")
            Button { MainWindow.show(.window) } label: {
                MenuRow(icon: "macwindow", title: "Open Graphitree", shortcut: "⌘O")
            }
            .keyboardShortcut("o")
            Button { MainWindow.show(.usageSettings) } label: {
                MenuRow(icon: "gearshape", title: "Menu Bar & Alerts…", shortcut: "⌘,")
            }
            .keyboardShortcut(",")
            Button { NSApp.terminate(nil) } label: {
                MenuRow(icon: "power", title: "Quit Graphitree", shortcut: "⌘Q")
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.plain)
        .padding(.init(top: 5, leading: 6, bottom: 7, trailing: 6))
    }
}

/// One plan in the popover: its logo, name and plan, how old the reading is, then a bar per
/// window, or why there's no reading.
private struct PlanSection: View {
    @ObservedObject private var refresher = UsageRefresher.shared
    @ObservedObject private var codex = CodexLimits.shared
    let provider: UsageProvider
    let metrics: [MetricKind]
    let showLeft: Bool

    private var snapshot: UsageSnapshot? {
        provider == .claude ? refresher.snapshot : codex.snapshot
    }

    private var planName: String? {
        provider == .claude ? refresher.profile?.plan : codex.plan.map { "ChatGPT \($0)" }
    }

    private var isStale: Bool { provider == .claude && refresher.isStale }

    /// Claude's reading failed on the sign-in, which signing Graphitree in to Claude fixes.
    private var needsSignIn: Bool {
        guard provider == .claude else { return false }
        switch refresher.lastError {
        case .notSignedIn?, .tokenExpired?, .signInExpired?, .http(401)?: return true
        default: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                ModelLogo(id: provider.connectionID, size: 16)
                Text(provider.name)
                    .font(.system(size: 13, weight: .semibold))
                if let planName {
                    Text(planName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if provider == .claude, let fetchedAt = snapshot?.fetchedAt {
                    AgeBadge(since: fetchedAt, stale: isStale)
                }
            }
            content
        }
        .padding(.init(top: 11, leading: 14, bottom: 12, trailing: 14))
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot {
            let displays = MetricPresentation.displays(for: snapshot, kinds: metrics, showLeft: showLeft)
            VStack(spacing: 12) {
                ForEach(displays) { MetricBarRow(metric: $0) }
                if displays.isEmpty {
                    Text("No windows picked. Choose them in Menu Bar & Alerts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(isStale ? 0.75 : 1)
            if isStale || provider == .codex { footnote(snapshot) }
        } else if provider == .claude && !refresher.isRunning {
            VStack(alignment: .leading, spacing: 8) {
                Text("Graphitree reads Claude's limits with Claude Code's sign-in. macOS asks once to let it.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Read Claude's Limits") { refresher.start() }
                    .controlSize(.small)
            }
        } else if provider == .claude, let error = refresher.lastError {
            notice(UsageFeed.claudeProblem(refresher), detail: error.errorDescription)
            if needsSignIn { signInButton }
        } else if provider == .codex, codex.lastRead != nil, !codex.hasSessions {
            notice("Codex hasn't run on this Mac.", detail: "Its limits show here once it has replied.")
        } else if provider == .codex, codex.lastRead != nil {
            notice("No plan limits in Codex's logs this week.",
                   detail: "Codex logs them with each reply when it's signed in with ChatGPT.")
        } else {
            ProgressView("Reading…")
                .controlSize(.small)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func footnote(_ snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 6) {
            if isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Couldn't refresh. ").foregroundStyle(.orange)
                    + ReadingAge(provider: provider, since: snapshot.fetchedAt, stale: true).text
            } else if provider == .codex {
                ReadingAge(provider: provider, since: snapshot.fetchedAt).text
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        if isStale, needsSignIn {
            HStack(spacing: 8) {
                Text(UsageFeed.claudeProblem(refresher))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                signInButton
            }
        }
    }

    /// Opens Menu Bar & Alerts in the window, where Graphitree signs in to Claude.
    private var signInButton: some View {
        Button("Sign In…") { MainWindow.show(.usageSettings) }
            .controlSize(.small)
            .help("Sign Graphitree in to Claude, so it reads the limits whether or not Claude Code runs.")
    }

    private func notice(_ title: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One footer row: icon, label, shortcut, and a highlight under the pointer.
struct MenuRow: View {
    let icon: String
    let title: String
    let shortcut: String?
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 13))
            Spacer()
            if let shortcut {
                Text(shortcut)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.init(top: 7, leading: 9, bottom: 7, trailing: 9))
        .background(hovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

import SwiftUI

/// The Usage page's "Menu Bar & Alerts" sheet: Graphitree's sign-in to Claude, the menu bar item,
/// which limits it and the desktop widgets show, and notifications.
struct UsageSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(MenuBarSettings.Key.shows) private var showsMenuBar = true
    @AppStorage(MenuBarSettings.Key.figures) private var figures: MenuBarFigures = .claude
    @AppStorage(MenuBarSettings.Key.metrics) private var metricsText = MenuBarSettings.defaultMetricsText
    @AppStorage(UsageAlerts.Key.isOn) private var alertsOn = true
    @AppStorage(UsageAlerts.Key.sessionWarn) private var sessionWarn = 80.0
    @AppStorage(UsageAlerts.Key.weeklyWarn) private var weeklyWarn = 80.0
    @AppStorage(UsageAlerts.Key.limitReached) private var limitReached = true
    @AppStorage(UsageAlerts.Key.pace) private var pace = true
    @AppStorage(UsageAlerts.Key.resetReminder) private var resetReminder = true
    @AppStorage(UsageAlerts.Key.reminderHours) private var reminderHours = 12
    @AppStorage(UsageAlerts.Key.reminderMinLeft) private var reminderMinLeft = 40.0

    @State private var opensAtLogin = MenuBarSettings.opensAtLogin
    @State private var loginError: String?
    @State private var showsSignIn = false
    @ObservedObject private var refresher = UsageRefresher.shared
    @ObservedObject private var shownTools = ShownProviders.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu Bar & Alerts")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Your plans' limits outside the window: in the menu bar, on desktop widgets and as notifications.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(GoldButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)
            Rectangle().fill(Palette.hairline).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    claudeSignIn
                    menuBar
                    shown
                    alerts
                }
                .padding(18)
            }
        }
        .frame(width: 540, height: 640)
        .background(Palette.panel)
        .preferredColorScheme(.dark)
        .tint(Palette.gold)
    }

    // MARK: Claude sign-in

    private var claudeSignIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Claude sign-in")
            VStack(alignment: .leading, spacing: 14) {
                if refresher.hasOwnSignIn {
                    row("Graphitree's own sign-in", detail: signedInDetail) {
                        Button("Sign Out") { Task { await refresher.signOut() } }
                            .buttonStyle(SoftButtonStyle())
                    }
                } else {
                    row("Borrowing Claude Code's sign-in", detail: "Only Claude Code's terminal command renews it, not the Code tab in Claude's app, so Claude's limits stop about eight hours after it last ran. Sign in to Claude and Graphitree keeps a sign-in of its own.") {
                        Button("Sign In…") { showsSignIn = true }
                            .buttonStyle(GoldButtonStyle())
                    }
                }
            }
            .designCard()
        }
        .sheet(isPresented: $showsSignIn) { ClaudeSignInSheet() }
    }

    private var signedInDetail: String {
        let account = refresher.profile?.email.map { "Signed in as \($0). " } ?? ""
        return account + "Graphitree renews it itself, so Claude's limits stay current whether or not Claude Code runs. Signing out goes back to borrowing Claude Code's."
    }

    // MARK: Menu bar

    private var menuBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Menu bar")
            VStack(alignment: .leading, spacing: 14) {
                row("Show in the menu bar",
                    detail: "Graphitree keeps reading your limits with its window closed, and leaves the Dock until you open it again. The widgets need it running to stay current.") {
                    Toggle("", isOn: $showsMenuBar).labelsHidden()
                }
                .onChange(of: showsMenuBar) { _, on in
                    MenuBarItem.presence.settingChanged()
                    if !on, opensAtLogin { setLogin(false) }
                    DockPresence.update()
                }
                row("Beside the icon", detail: "Session over Weekly, as used or left like the Usage page.") {
                    Picker("", selection: Binding(get: { figures.effective(shown: shownTools.providers) }, set: { figures = $0 })) {
                        ForEach(MenuBarFigures.choices(shown: shownTools.providers)) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .disabled(!showsMenuBar)
                row("Open at login", detail: loginError ?? "Starts in the menu bar only, with the window closed.") {
                    Toggle("", isOn: Binding(get: { opensAtLogin }, set: setLogin)).labelsHidden()
                }
                .disabled(!showsMenuBar)
            }
            .designCard()
        }
    }

    private func setLogin(_ on: Bool) {
        loginError = MenuBarSettings.setOpensAtLogin(on)
        opensAtLogin = MenuBarSettings.opensAtLogin
    }

    // MARK: Shown

    private var shown: some View {
        let picked = Set(MenuBarSettings.parse(metricsText))
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Claude's limits in the menu and widgets")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(MetricKind.allCases) { kind in
                    Toggle(isOn: Binding(
                        get: { picked.contains(kind) },
                        set: { on in
                            var next = picked
                            if on { next.insert(kind) } else { next.remove(kind) }
                            metricsText = MenuBarSettings.text(next)
                        }
                    )) {
                        Text(kind.title).font(.system(size: 12.5))
                    }
                    .toggleStyle(.checkbox)
                }
                Text("The first two are what a small widget has room for. Codex's plan has only Session and Weekly, so its widgets show those.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .designCard()
        }
    }

    // MARK: Alerts

    private var alerts: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Notifications")
            VStack(alignment: .leading, spacing: 14) {
                row("Notify me about my limits", detail: "For Claude and Codex, once per cycle of each window. macOS asks to allow them the first time one is due.") {
                    Toggle("", isOn: $alertsOn).labelsHidden()
                }
                Group {
                    slider("Session passes", value: $sessionWarn)
                    slider("Weekly passes", value: $weeklyWarn)
                    row("A limit is reached", detail: nil) {
                        Toggle("", isOn: $limitReached).labelsHidden()
                    }
                    row("The week is on pace to run out early", detail: "When it would run out more than six hours before it resets.") {
                        Toggle("", isOn: $pace).labelsHidden()
                    }
                    row("The week resets with much of it unused", detail: nil) {
                        Toggle("", isOn: $resetReminder).labelsHidden()
                    }
                    HStack(spacing: 6) {
                        Text("Up to")
                        Picker("Hours before the reset", selection: $reminderHours) {
                            ForEach([3, 6, 12, 24], id: \.self) { Text("\($0) hours").tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Text("before it, with at least")
                        Picker("Least left", selection: $reminderMinLeft) {
                            ForEach([20.0, 30, 40, 50, 60], id: \.self) { Text("\(Int($0))%").tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Text("left")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .disabled(!resetReminder)
                }
                .disabled(!alertsOn)
            }
            .designCard()
        }
    }

    private func slider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12.5))
                Spacer()
                Text("\(Int(value.wrappedValue))%")
                    .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
            }
            Slider(value: value, in: 50...95, step: 5)
                .controlSize(.small)
        }
    }

    // MARK: Parts

    private func row<Control: View>(_ title: String, detail: String?, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12.5, weight: .medium))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

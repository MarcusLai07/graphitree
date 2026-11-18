import Foundation

/// Whose figures sit beside the menu bar icon.
enum MenuBarFigures: String, CaseIterable, Identifiable {
    case claude, codex, none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .none: return "Icon only"
        }
    }

    var provider: UsageProvider? {
        switch self {
        case .claude: return .claude
        case .codex: return .codex
        case .none: return nil
        }
    }
}

/// The menu bar item's settings, in Graphitree's defaults. Used and Left is the Usage page's own
/// switch (`ClaudeUsageStore.Key.showLeft`), and applies to the menu bar and widgets too.
enum MenuBarSettings {
    enum Key {
        /// Graphitree keeps an item in the menu bar, and stays running with its window closed.
        static let shows = "menuBar.shows"
        static let figures = "menuBar.figures"
        /// Claude's windows the menu and widgets show, comma-separated, in order.
        static let metrics = "menuBar.metrics"
    }

    static let defaultMetricsText = "session,weekly"

    static var defaults: UserDefaults { .standard }

    static var shows: Bool { defaults.object(forKey: Key.shows) as? Bool ?? true }

    static var metrics: [MetricKind] {
        parse(defaults.string(forKey: Key.metrics) ?? defaultMetricsText)
    }

    static func parse(_ text: String) -> [MetricKind] {
        text.split(separator: ",").compactMap { MetricKind(rawValue: String($0)) }
    }

    /// `kinds` in the card's order, as stored.
    static func text(_ kinds: Set<MetricKind>) -> String {
        MetricKind.allCases.filter(kinds.contains).map(\.rawValue).joined(separator: ",")
    }

    /// Started by the login job: the window stays closed and Graphitree waits in the menu bar.
    static var startsInMenuBar: Bool {
        shows && CommandLine.arguments.contains(MenuBarAgent.launchArgument)
    }

    // MARK: Open at login

    static var home: String { NSHomeDirectory() }

    static var opensAtLogin: Bool { MenuBarAgent.isInstalled(home: home) }

    /// Returns an error message or nil.
    @discardableResult
    static func setOpensAtLogin(_ on: Bool) -> String? {
        guard on else {
            MenuBarAgent.remove(home: home)
            return nil
        }
        guard let executable = Bundle.main.executablePath, let bundleID = Bundle.main.bundleIdentifier else {
            return "Graphitree couldn't find its own app."
        }
        return MenuBarAgent.install(executable: executable, bundleIdentifier: bundleID, home: home)
    }

    /// At launch: a login job whose app was moved or deleted points at this copy instead. A job
    /// that still finds its app is left alone, so a test build never takes it over.
    static func repairLoginJob() {
        guard let installed = MenuBarAgent.installedExecutable(home: home),
              !FileManager.default.isExecutableFile(atPath: installed) else { return }
        setOpensAtLogin(true)
    }
}

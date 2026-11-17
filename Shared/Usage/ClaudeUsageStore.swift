import Foundation

/// Where the Usage page keeps what it remembers: the last plan reading, the account's plan and the
/// reading history, in `~/Library/Application Support/Graphitree/ClaudeUsage/`, plus a few display
/// choices in the app's defaults. Ported from Claude Usage's app-group store, without the app group:
/// Graphitree has no widget yet, so nothing else needs to read it.
enum ClaudeUsageStore {
    /// Made the first time it's needed, then reused.
    static let folder: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent("Graphitree/ClaudeUsage", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    static var defaults: UserDefaults { .standard }

    enum Key {
        /// Whose usage the page shows: Claude or Codex.
        static let provider = "usage.provider"
        static let showLeft = "claudeUsage.showLeft"
        static let hideAccount = "claudeUsage.hideAccount"
        static let period = "claudeUsage.period"
        static let trendRange = "claudeUsage.trendRange"
        static let lastHistorySample = "claudeUsage.lastHistorySample"
        static let customStart = "claudeUsage.customStart"
        static let customEnd = "claudeUsage.customEnd"
        /// Set after the first plan reading works, so later launches keep the history going
        /// without asking for the keychain before the page is opened.
        static let isEnabled = "claudeUsage.isEnabled"
    }

    private static var snapshotURL: URL { folder.appendingPathComponent("snapshot.json") }
    private static var profileURL: URL { folder.appendingPathComponent("profile.json") }

    static var cachedSnapshot: UsageSnapshot? {
        get { read(snapshotURL) }
        set { write(newValue, to: snapshotURL) }
    }

    static var accountProfile: AccountProfile? {
        get { read(profileURL) }
        set { write(newValue, to: profileURL) }
    }

    /// Bars and figures show what's left rather than what's used.
    static var showLeft: Bool { defaults.bool(forKey: Key.showLeft) }

    static var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled) }
        set { defaults.set(newValue, forKey: Key.isEnabled) }
    }

    private static func read<T: Decodable>(_ url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T?, to url: URL) {
        guard let value else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

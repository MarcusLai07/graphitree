import Foundation

/// "Open at login": a LaunchAgent that starts Graphitree in the menu bar only when the person logs
/// in, so the plan's limits and the widgets stay current without the window opening. It runs the
/// app's own executable with `--menu-bar-only`, which Graphitree reads at launch to keep its
/// window closed. Running the executable, rather than `open`, lets macOS name the item after
/// Graphitree in Login Items, as `AssociatedBundleIdentifiers` asks.
///
/// Writing the file is all it takes: launchd reads it at the next login. It's never loaded now,
/// which would start a second Graphitree beside the running one, and never unloaded on removal,
/// which would quit a Graphitree that the job started.
enum MenuBarAgent {
    static let label = "com.marcuslai.Graphitree.menubar"
    static let launchArgument = "--menu-bar-only"

    static func plistURL(home: String) -> URL {
        URL(fileURLWithPath: home).appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func isInstalled(home: String) -> Bool {
        FileManager.default.fileExists(atPath: plistURL(home: home).path)
    }

    /// The executable the installed job starts, or nil when there's no job.
    static func installedExecutable(home: String) -> String? {
        guard let data = FileManager.default.contents(atPath: plistURL(home: home).path),
              let job = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
              let arguments = job["ProgramArguments"] as? [String] else { return nil }
        return arguments.first
    }

    static func plist(executable: String, bundleIdentifier: String, home: String) -> String {
        func escaped(_ text: String) -> String {
            text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(escaped(executable))</string>
                <string>\(launchArgument)</string>
            </array>
            <key>AssociatedBundleIdentifiers</key>
            <array>
                <string>\(escaped(bundleIdentifier))</string>
            </array>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>\(escaped(home))/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
            </dict>
            <key>RunAtLoad</key>
            <true/>
            <key>LimitLoadToSessionType</key>
            <string>Aqua</string>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>

        """
    }

    /// Writes the job for the app at `executable`, or leaves a job that already matches alone.
    /// Returns an error message or nil.
    @discardableResult
    static func install(executable: String, bundleIdentifier: String, home: String) -> String? {
        let url = plistURL(home: home)
        let text = plist(executable: executable, bundleIdentifier: bundleIdentifier, home: home)
        if (try? String(contentsOf: url, encoding: .utf8)) == text { return nil }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static func remove(home: String) {
        try? FileManager.default.removeItem(at: plistURL(home: home))
    }
}

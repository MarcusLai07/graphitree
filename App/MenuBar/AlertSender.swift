import Foundation
import UserNotifications

// Sending what `UsageAlerts.due` finds, from the app only: the command line and checks have no
// app bundle to post notifications from.

extension UsageAlerts {
    // MARK: Sending

    /// Only an app bundle can post notifications; the screenshot tool and checks can't.
    @MainActor
    static var canNotify: Bool { Bundle.main.bundleURL.pathExtension == "app" && UsageFeed.isEnabled }

    /// Works out what's due and sends it. Claude's readings are read from Graphitree's history
    /// (`samples` nil), off the main thread; Codex's come from its logs.
    @MainActor
    static func check(_ provider: UsageProvider, snapshot: UsageSnapshot, samples: [UsageSample]?) {
        guard canNotify else { return }
        let settings = Settings.current
        guard settings.isOn else { return }
        Task { @MainActor in
            let history: [UsageSample]
            if let samples {
                history = samples
            } else {
                let since = Date().addingTimeInterval(-(MetricKind.weekly.span ?? 0) - 3600)
                history = await Task.detached(priority: .utility) { UsageHistory.load(since: since) }.value
            }
            // What's due and what's already sent are settled on the main actor, one check at a
            // time, so two readings close together can't both send the same alert.
            let defaults = UserDefaults.standard
            var keys = defaults.stringArray(forKey: Key.notified) ?? []
            let alerts = due(provider, snapshot: snapshot, samples: history, settings: settings,
                             notified: keys, now: Date())
            guard !alerts.isEmpty else { return }
            // Marked before sending, so a turned-down permission doesn't ask again each reading.
            keys += alerts.map { notificationKey($0.name, resetsAt: $0.resetsAt) }
            defaults.set(Array(keys.suffix(80)), forKey: Key.notified)
            send(alerts)
        }
    }

    /// The same for a tool whose limits come as `LimitReading`.
    @MainActor
    static func check(_ provider: UsageProvider, reading: LimitReading) {
        guard canNotify else { return }
        let settings = Settings.current
        guard settings.isOn else { return }
        Task { @MainActor in
            let defaults = UserDefaults.standard
            var keys = defaults.stringArray(forKey: Key.notified) ?? []
            let alerts = due(provider, reading: reading.asOf(Date()), settings: settings, notified: keys, now: Date())
            guard !alerts.isEmpty else { return }
            keys += alerts.map { notificationKey($0.name, resetsAt: $0.resetsAt) }
            defaults.set(Array(keys.suffix(80)), forKey: Key.notified)
            send(alerts)
        }
    }

    private static func send(_ alerts: [Alert]) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { current in
            let post = {
                for alert in alerts {
                    let content = UNMutableNotificationContent()
                    content.title = alert.title
                    content.body = alert.body
                    content.sound = .default
                    content.userInfo = ["provider": alert.provider.rawValue]
                    center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
                }
            }
            if current.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { post() }
                }
            } else {
                post()
            }
        }
    }
}

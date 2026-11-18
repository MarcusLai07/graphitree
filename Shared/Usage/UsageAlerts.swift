import Foundation

/// Notifications about the plan's limits, ported from Claude Usage, for Claude and Codex alike:
/// a window passing the share set for it, a window reaching its limit, the week on pace to run out
/// well before it resets, and the week about to reset with much of it unused. Each fires once per
/// cycle of its window. macOS asks whether to allow them the first time one is due.
enum UsageAlerts {
    enum Key {
        static let isOn = "alerts.isOn"
        static let sessionWarn = "alerts.sessionWarn"
        static let weeklyWarn = "alerts.weeklyWarn"
        static let limitReached = "alerts.limitReached"
        static let pace = "alerts.pace"
        static let resetReminder = "alerts.resetReminder"
        static let reminderHours = "alerts.reminderHours"
        static let reminderMinLeft = "alerts.reminderMinLeft"
        /// What already fired: `<provider>-<alert>-<reset epoch>`, the last 80.
        static let notified = "alerts.notified"
    }

    struct Settings: Equatable {
        var isOn = true
        /// Warn once a window passes this share used.
        var sessionWarn: Double = 80
        var weeklyWarn: Double = 80
        var limitReached = true
        /// The week runs out more than `paceMargin` before it resets, at this cycle's pace.
        var pace = true
        var resetReminder = true
        /// How long before the weekly reset the reminder may come.
        var reminderHours = 12
        /// The least share left worth a reminder.
        var reminderMinLeft: Double = 40

        static var current: Settings {
            let defaults = UserDefaults.standard
            var settings = Settings()
            settings.isOn = defaults.object(forKey: Key.isOn) as? Bool ?? settings.isOn
            settings.sessionWarn = defaults.object(forKey: Key.sessionWarn) as? Double ?? settings.sessionWarn
            settings.weeklyWarn = defaults.object(forKey: Key.weeklyWarn) as? Double ?? settings.weeklyWarn
            settings.limitReached = defaults.object(forKey: Key.limitReached) as? Bool ?? settings.limitReached
            settings.pace = defaults.object(forKey: Key.pace) as? Bool ?? settings.pace
            settings.resetReminder = defaults.object(forKey: Key.resetReminder) as? Bool ?? settings.resetReminder
            settings.reminderHours = defaults.object(forKey: Key.reminderHours) as? Int ?? settings.reminderHours
            settings.reminderMinLeft = defaults.object(forKey: Key.reminderMinLeft) as? Double ?? settings.reminderMinLeft
            return settings
        }
    }

    struct Alert: Equatable {
        /// `<provider>-<alert>`, such as "claude-session-warn-80".
        let name: String
        let resetsAt: Date?
        let title: String
        let body: String
        let provider: UsageProvider
    }

    /// How early a run-out has to be to warn about it.
    static let paceMargin: TimeInterval = 6 * 3600

    // MARK: What's due

    /// The alerts due for a reading, leaving out those already sent this cycle. `samples` are
    /// this cycle's readings, for the pace; nil leaves the pace out.
    static func due(_ provider: UsageProvider, snapshot: UsageSnapshot, samples: [UsageSample]?,
                    settings: Settings, notified: [String], now: Date) -> [Alert] {
        guard settings.isOn else { return [] }
        var alerts: [Alert] = []
        func add(_ alert: String, resetsAt: Date?, title: String, body: String) {
            let name = "\(provider.rawValue)-\(alert)"
            guard !alreadyNotified(name, resetsAt: resetsAt, in: notified) else { return }
            alerts.append(Alert(name: name, resetsAt: resetsAt, title: title, body: body, provider: provider))
        }

        for (kind, threshold) in [(MetricKind.session, settings.sessionWarn), (.weekly, settings.weeklyWarn)] {
            guard let window = snapshot.window(for: kind), let used = window.utilization else { continue }
            let what = "\(provider.name) \(kind.title.lowercased())"
            if settings.limitReached, used >= 100 {
                add("\(kind.rawValue)-limit", resetsAt: window.resetsAt,
                    title: "\(what) limit reached",
                    body: resetText(window.resetsAt, prefix: "Usage is at 100%.", now: now))
            } else if used >= threshold {
                add("\(kind.rawValue)-warn-\(Int(threshold))", resetsAt: window.resetsAt,
                    title: "\(what) usage at \(Int(used))%",
                    body: resetText(window.resetsAt, prefix: "You set a warning at \(Int(threshold))%.", now: now))
            }
        }

        if settings.resetReminder, let window = snapshot.weekly, let used = window.utilization,
           let reset = window.resetsAt {
            let left = max(0, 100 - used)
            let untilReset = reset.timeIntervalSince(now)
            if untilReset > 0, untilReset <= TimeInterval(settings.reminderHours) * 3600, left >= settings.reminderMinLeft {
                add("weekly-reset-reminder", resetsAt: reset,
                    title: "\(possessive(provider)) weekly limit resets \(relative(reset, now: now))",
                    body: "\(Int(left.rounded()))% of it is still unused, and it doesn't carry over.")
            }
        }

        if settings.pace, let samples, let window = snapshot.weekly, let reset = window.resetsAt, reset > now,
           let span = MetricKind.weekly.span {
            let cycle = CurrentCycle(start: reset.addingTimeInterval(-span), reset: reset)
            let line = UsageTrends.lines(from: samples.filter { $0.ts >= cycle.start }).first { $0.kind == .weekly }
            if let line, case .runsOut(let out)? = UsageTrends.forecast(points: line.points, cycle: cycle, now: now),
               reset.timeIntervalSince(out) > paceMargin {
                add("weekly-pace", resetsAt: reset,
                    title: "\(provider.name) is on pace to run out early",
                    body: paceText(runsOut: out, reset: reset, now: now))
            }
        }
        return alerts
    }

    /// "At this pace your weekly limit runs out Sat 14:00, 1 day before it resets."
    static func paceText(runsOut out: Date, reset: Date, now: Date) -> String {
        let when = Calendar.current.isDate(out, inSameDayAs: now)
            ? "today at \(out.formatted(.dateTime.hour().minute()))"
            : out.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        let early = DateComponentsFormatter()
        early.unitsStyle = .full
        early.allowedUnits = [.day, .hour]
        early.maximumUnitCount = 1
        let gap = early.string(from: reset.timeIntervalSince(out)) ?? "well"
        return "At this pace your weekly limit runs out \(when), \(gap) before it resets."
    }

    private static func possessive(_ provider: UsageProvider) -> String { "\(provider.name)'s" }

    private static func relative(_ date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    private static func resetText(_ date: Date?, prefix: String, now: Date) -> String {
        guard let date else { return prefix }
        return "\(prefix) Resets \(relative(date, now: now))."
    }

    // MARK: Once per cycle

    /// `<name>-<reset epoch seconds>`, or `<name>-current` for a window without a reset.
    static func notificationKey(_ name: String, resetsAt: Date?) -> String {
        "\(name)-\(resetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "current")"
    }

    /// The same window's reset moves by a second or so between readings (09:59:59.6, then
    /// 10:00:00), so a recorded reset within `slack` of this one is the same cycle. Real cycles
    /// are hours apart.
    static func alreadyNotified(_ name: String, resetsAt: Date?, in keys: [String], slack: TimeInterval = 5 * 60) -> Bool {
        guard let resetsAt else { return keys.contains(notificationKey(name, resetsAt: nil)) }
        let prefix = "\(name)-"
        return keys.contains { key in
            guard key.hasPrefix(prefix), let epoch = TimeInterval(key.dropFirst(prefix.count)) else { return false }
            return abs(epoch - resetsAt.timeIntervalSince1970) <= slack
        }
    }
}

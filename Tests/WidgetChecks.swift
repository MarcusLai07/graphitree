import Foundation

// Checks for what the menu bar and widgets stand on: the feed the app writes for the widgets,
// the notifications' rules, the open-at-login job, and noticing Codex's new logs. Everything runs
// in a made-up home folder; nothing here reads the real app group or Graphitree's history. Called
// from main.swift.

func menuBarAndWidgetChecks() throws {
    let manager = FileManager.default
    let now = utc("2026-11-18T12:00:00Z")

    // MARK: The app group

    check(WidgetFeedStore.isTeamPrefixed("P7DV5ZUK9A.com.marcuslai.Graphitree"), "a group starting with a team ID is used")
    check(!WidgetFeedStore.isTeamPrefixed("com.marcuslai.Graphitree"), "a copy signed without a team has no group to use")
    check(!WidgetFeedStore.isTeamPrefixed("group.com.marcuslai.Graphitree"), "a group. id, which macOS asks about, isn't used")
    check(!WidgetFeedStore.isTeamPrefixed("p7dv5zuk9a.com.marcuslai.Graphitree"), "a team ID is capitals and digits")
    check(WidgetFeedStore.groupID == nil, "the checks, with no Info.plist, have no group, so they never write a feed")

    // MARK: The feed

    let weeklyReset = utc("2026-11-22T18:00:00Z")
    let snapshot = UsageSnapshot(fetchedAt: utc("2026-11-18T11:58:00Z"),
                                 session: UsageWindow(utilization: 74, resetsAt: utc("2026-11-18T12:40:00Z")),
                                 weekly: UsageWindow(utilization: 13, resetsAt: weeklyReset),
                                 weeklyOpus: nil, weeklySonnet: nil, extra: nil)
    var feed = WidgetFeed(written: now, showLeft: false, metrics: [.session, .weekly, .weeklyFable],
                          plans: [.claude: WidgetFeed.Plan(snapshot: snapshot, name: "Max 5x"),
                                  .codex: WidgetFeed.Plan(problem: "Codex hasn't run on this Mac.")])
    let encoded = WidgetFeedStore.encode(feed)
    expectEqual(encoded.flatMap(WidgetFeedStore.decode), feed, "the feed reads back as written")
    expectEqual(feed.kinds(.claude), [.session, .weekly, .weeklyFable], "Claude's widgets show the windows picked")
    expectEqual(feed.kinds(.codex), [.session, .weekly], "Codex's widgets show its two windows")
    check(!feed.isQuiet(now: now.addingTimeInterval(5 * 60)), "a feed written five minutes ago is current")
    check(feed.isQuiet(now: now.addingTimeInterval(25 * 60)), "one written 25 minutes ago means Graphitree isn't running")
    var later = feed
    later.written = now.addingTimeInterval(300)
    check(later.sameContent(as: feed), "a feed written again with the same readings doesn't redraw the widgets")
    later.showLeft = true
    check(!later.sameContent(as: feed), "switching to Left redraws them")
    check(!feed.sameContent(as: nil), "the first feed always draws")
    expectEqual(feed.providers, [.claude, .codex], "the feed lists its plans in the switch's order")
    let claudeOnly = WidgetFeed(written: now, showLeft: false, metrics: [.session], plans: [.claude: WidgetFeed.Plan(name: "Max 5x")])
    check(claudeOnly.plan(.codex) == nil && claudeOnly.providers == [.claude], "a tool that isn't shown has no plan in the feed, so the widget doesn't offer it")
    // A feed 0.2.2 wrote, read by the new widget before the new app writes again.
    let olderFeed = Data(#"{"claude":{"isStale":false,"name":"Max 5x"},"codex":{"isStale":false,"problem":"Codex hasn't run on this Mac."},"metrics":["session","weekly"],"showLeft":false,"written":"2026-11-18T12:00:00Z"}"#.utf8)
    let readOlder = WidgetFeedStore.decode(olderFeed)
    expectEqual(readOlder?.plan(.claude)?.name, "Max 5x", "an older feed's Claude plan still reads")
    expectEqual(readOlder?.providers, [.claude, .codex], "and so does its Codex plan")
    check(String(decoding: WidgetFeedStore.encode(claudeOnly) ?? Data(), as: UTF8.self).contains(#""plans":{"claude""#), "a new feed keeps plans by provider")

    // MARK: Which tools show

    let toolsHome = manager.temporaryDirectory.appendingPathComponent("graphitree-tools-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: toolsHome) }
    let toolsBin = toolsHome.appendingPathComponent(".local/bin")
    try manager.createDirectory(at: toolsBin, withIntermediateDirectories: true)
    func install(_ command: String) throws {
        let path = toolsBin.appendingPathComponent(command).path
        try "#!/bin/sh\n".write(toFile: path, atomically: true, encoding: .utf8)
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }
    try install("codex")
    check(!UsageProvider.shown(home: toolsHome.path).contains(.codex), "Codex installed without graphify's skill or Graphitree's pointer isn't listed under Connected, so its usage doesn't show")
    let codexSkill = toolsHome.appendingPathComponent(".codex/skills/graphify/SKILL.md")
    try manager.createDirectory(at: codexSkill.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "skill".write(to: codexSkill, atomically: true, encoding: .utf8)
    check(UsageProvider.shown(home: toolsHome.path).contains(.codex), "with graphify's skill in it, as AI Models lists it under Connected, it shows")
    let codexState = CodingToolState(isInstalled: true, builds: true, reads: false)
    check(codexState.isListed && !codexState.isConnected, "the skill alone lists a tool under Connected, though setup isn't finished")
    try install("claude")
    check(UsageProvider.shown(home: toolsHome.path).contains(.claude), "Claude Code shows once Graphitree can build with it, skill or not")
    expectEqual(UsageProvider.shown(home: toolsHome.path), [.claude, .codex], "shown tools keep the switch's order")

    // MARK: Beside the menu bar icon

    expectEqual(MenuBarFigures(rawValue: "codex"), .provider(.codex), "a saved provider reads back")
    expectEqual(MenuBarFigures(rawValue: "none"), MenuBarFigures.none, "and so does the icon alone")
    check(MenuBarFigures(rawValue: "cursor") == nil, "an unknown saved value falls back to the default")
    expectEqual(MenuBarFigures.choices(shown: [.claude]).map(\.rawValue), ["claude", "none"], "the picker offers the shown tools, then the icon alone")
    expectEqual(MenuBarFigures.provider(.codex).effective(shown: [.claude]), .claude, "a tool no longer shown gives way to the first shown one")
    expectEqual(MenuBarFigures.provider(.codex).effective(shown: []), MenuBarFigures.none, "with none shown, only the icon")
    expectEqual(MenuBarFigures.none.effective(shown: [.claude]), MenuBarFigures.none, "the icon alone stays the icon alone")

    // MARK: The week's curve

    let start = weeklyReset.addingTimeInterval(-7 * 86400)
    // 20% a day from the start of the week: empty after five days, two before the reset.
    let steady: [UsageSample] = stride(from: start, through: now, by: 1800).map { at in
        UsageSample(ts: at, session: nil, weekly: at.timeIntervalSince(start) / 86400 * 20, opus: nil, sonnet: nil, fable: nil,
                    sessionReset: nil, weeklyReset: weeklyReset, fableReset: nil, opusReset: nil, sonnetReset: nil)
    }
    var steadySnapshot = snapshot
    steadySnapshot.weekly = UsageWindow(utilization: steady.last?.weekly, resetsAt: weeklyReset)
    let trend = WidgetFeed.Trend.make(samples: steady, snapshot: steadySnapshot, now: now)
    expectEqual(trend?.lines.map(\.kind), [.weekly], "the curve has a line for each weekly window read")
    expectEqual(trend?.start, start, "the curve starts a week before the reset")
    check(trend?.runsOut.map { abs($0.timeIntervalSince(start.addingTimeInterval(5 * 86400))) < 3600 } == true, "at 20% a day the week runs out on day five")
    var noReset = steadySnapshot
    noReset.weekly?.resetsAt = nil
    check(WidgetFeed.Trend.make(samples: steady, snapshot: noReset, now: now) == nil, "a week without a reset has no curve")

    // MARK: Notifications

    let settings = UsageAlerts.Settings()
    expectEqual(UsageAlerts.due(.claude, snapshot: snapshot, samples: nil, settings: settings, notified: [], now: now), [],
                "a session at 74% and a week at 13% are under the 80% warnings")
    let lowered = UsageAlerts.Settings(sessionWarn: 70)
    let warn = UsageAlerts.due(.claude, snapshot: snapshot, samples: nil, settings: lowered, notified: [], now: now)
    expectEqual(warn.map(\.name), ["claude-session-warn-70"], "a session past the share set for it warns")
    expectEqual(warn.first?.title, "Claude session usage at 74%", "the warning names the plan, the window and the share")
    expectEqual(warn.first?.body, "You set a warning at 70%. Resets in 40 minutes.", "and says when the window resets")
    let sent = warn.map { UsageAlerts.notificationKey($0.name, resetsAt: $0.resetsAt?.addingTimeInterval(1)) }
    check(UsageAlerts.due(.claude, snapshot: snapshot, samples: nil, settings: lowered, notified: sent, now: now).isEmpty,
          "it comes once per cycle, though the reset moves by a second between readings")
    var full = snapshot
    full.session?.utilization = 100
    expectEqual(UsageAlerts.due(.codex, snapshot: full, samples: nil, settings: settings, notified: [], now: now).map(\.title),
                ["Codex session limit reached"], "a window at 100% says the limit is reached, not that it passed 80%")
    check(UsageAlerts.due(.claude, snapshot: full, samples: nil, settings: UsageAlerts.Settings(isOn: false), notified: [], now: now).isEmpty,
          "with notifications off, nothing is due")

    var unused = snapshot
    unused.session = nil
    unused.weekly = UsageWindow(utilization: 30, resetsAt: now.addingTimeInterval(6 * 3600))
    let reminder = UsageAlerts.due(.claude, snapshot: unused, samples: nil, settings: settings, notified: [], now: now)
    expectEqual(reminder.map(\.name), ["claude-weekly-reset-reminder"], "a week resetting in six hours with 70% left is a reminder")
    expectEqual(reminder.first?.body, "70% of it is still unused, and it doesn't carry over.", "the reminder says how much is unused")
    check(UsageAlerts.due(.claude, snapshot: unused, samples: nil, settings: UsageAlerts.Settings(reminderHours: 3), notified: [], now: now).isEmpty,
          "not before the hours set")

    var steadyReading = steadySnapshot
    steadyReading.session = nil
    steadyReading.weekly?.utilization = 50
    let pace = UsageAlerts.due(.codex, snapshot: steadyReading, samples: steady, settings: settings, notified: [], now: now)
    expectEqual(pace.map(\.name), ["codex-weekly-pace"], "a week running out two days early warns once")
    check(pace.first?.body.hasPrefix("At this pace your weekly limit runs out ") == true && pace.first?.body.hasSuffix("2 days before it resets.") == true,
          "the warning says when it runs out and how early")
    expectEqual(UsageAlerts.due(.codex, snapshot: steadyReading, samples: nil, settings: settings, notified: [], now: now), [],
                "without readings there's no pace")

    // MARK: The menu bar item's place

    var presence = MenuBarPresence()
    check(presence.isInserted(setting: true), "with the setting on, the item is in the menu bar")
    check(!presence.isInserted(setting: false), "with it off, it isn't")
    // Graphitree's own placing is reported back the same way. Reported again and again, as
    // SwiftUI does, it changes nothing, so it can't feed itself (0.2.0 hung on that).
    var settled = presence
    for _ in 0..<3 { settled.report(visible: true, setting: true) }
    expectEqual(settled, presence, "the item reported where Graphitree put it changes nothing")
    presence.report(visible: false, setting: true)
    check(!presence.isInserted(setting: true), "hidden from outside with the setting on, it isn't put back")
    let hidden = presence
    for _ in 0..<3 { presence.report(visible: false, setting: true) }
    expectEqual(presence, hidden, "the same hide reported again changes nothing")
    presence.report(visible: true, setting: true)
    check(presence.isInserted(setting: true), "shown again from outside, it's back")
    presence.report(visible: false, setting: true)
    presence.report(visible: false, setting: false)
    check(presence.isInserted(setting: true), "removed because the setting went off, it's back when the setting is on")
    presence.report(visible: false, setting: true)
    presence.settingChanged()
    check(presence.isInserted(setting: true), "changing the setting brings back an item hidden from outside")
    check(!presence.isInserted(setting: false), "unless it's now off")

    // MARK: Open at login

    let home = manager.temporaryDirectory.appendingPathComponent("graphitree-menubar-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: home) }
    let executable = "/Applications/Graphitree & Co.app/Contents/MacOS/Graphitree"
    let text = MenuBarAgent.plist(executable: executable, bundleIdentifier: "com.marcuslai.Graphitree", home: home.path)
    let job = (try? PropertyListSerialization.propertyList(from: Data(text.utf8), format: nil)) as? [String: Any]
    expectEqual(job?["ProgramArguments"] as? [String], [executable, MenuBarAgent.launchArgument], "the login job starts the app itself, in the menu bar only")
    expectEqual(job?["AssociatedBundleIdentifiers"] as? [String], ["com.marcuslai.Graphitree"], "macOS names it after Graphitree in Login Items")
    expectEqual(job?["RunAtLoad"] as? Bool, true, "it runs when the person logs in")
    check(job?["KeepAlive"] == nil, "it doesn't start Graphitree again after it's quit")
    check(!MenuBarAgent.isInstalled(home: home.path), "there's no login job to start with")
    expectEqual(MenuBarAgent.install(executable: executable, bundleIdentifier: "com.marcuslai.Graphitree", home: home.path), nil, "the login job is written")
    expectEqual(MenuBarAgent.installedExecutable(home: home.path), executable, "and names the app it starts")
    MenuBarAgent.remove(home: home.path)
    check(!MenuBarAgent.isInstalled(home: home.path), "turning it off removes it")

    // MARK: Codex's new logs

    let codexHome = home.appendingPathComponent(".codex")
    let day = codexHome.appendingPathComponent("sessions/2026/11/18")
    try manager.createDirectory(at: day, withIntermediateDirectories: true)
    try "{}\n".write(to: day.appendingPathComponent("notes.jsonl"), atomically: true, encoding: .utf8)
    let written = Date()
    check(!CodexSessions.hasChanges(home: codexHome, since: written.addingTimeInterval(-60)), "a file that isn't a session log isn't a change")
    try "{}\n".write(to: day.appendingPathComponent("rollout-2026-11-18T10-00-00-abc.jsonl"), atomically: true, encoding: .utf8)
    check(CodexSessions.hasChanges(home: codexHome, since: written.addingTimeInterval(-60)), "a session log written since the last read is a change")
    check(!CodexSessions.hasChanges(home: codexHome, since: Date().addingTimeInterval(60)), "nothing newer, nothing to read")
}

import Foundation

// Checks for uninstalling: the plan, and the uninstall itself run against a made-up home folder,
// with the Trash, launchctl, tccutil, the Keychain and defaults swapped out. Nothing here touches
// the real Mac. Called from main.swift.

func uninstallChecks() throws {
    let manager = FileManager.default
    let home = manager.temporaryDirectory.appendingPathComponent("graphitree-uninstall-\(UUID().uuidString)")
    let fakeTrash = manager.temporaryDirectory.appendingPathComponent("graphitree-trash-\(UUID().uuidString)")
    defer {
        try? manager.removeItem(at: home)
        try? manager.removeItem(at: fakeTrash)
    }
    try manager.createDirectory(at: fakeTrash, withIntermediateDirectories: true)

    @discardableResult
    func write(_ relative: String, _ text: String) throws -> String {
        let url = home.appendingPathComponent(relative)
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }
    func read(_ path: String) -> String? { try? String(contentsOfFile: path, encoding: .utf8) }
    func exists(_ path: String) -> Bool { (try? manager.attributesOfItem(atPath: path)) != nil }
    func servers(_ path: String, _ key: String) -> [String] {
        let object = (try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)))) as? [String: Any]
        return ((object?[key] as? [String: Any]) ?? [:]).keys.sorted()
    }

    // Other tools' files, with and without Graphitree's lines.
    let block = AgentSetup.block(guidePath: "/g/graphify-out/AGENT_GUIDE.md", root: "/g")
    let claudeText = "# Mine\nKeep this.\n\n" + block + "\n"
    let claude = try write(".claude/CLAUDE.md", claudeText)
    let codexText = "# Codex\nNothing of Graphitree's.\n"
    let codex = try write(".codex/AGENTS.md", codexText)
    let gemini = try write(".gemini/GEMINI.md", block + "\n")
    let custom = try write("work/notes/AGENTS.md", "Top\n\n\(AgentSetup.startMarker)\nGraphitree's pointer\n\(AgentSetup.endMarker)\n")
    let cursor = try write(".cursor/mcp.json", #"{"mcpServers":{"graphitree":{"command":"/Applications/Graphitree.app/Contents/MacOS/graphitree-cli","args":["mcp"]},"other":{"command":"x"}}}"#)
    let windsurf = try write(".codeium/windsurf/mcp_config.json", #"{"mcpServers":{"graphitree":{"command":"/Applications/Graphitree.app/Contents/MacOS/graphitree-cli","args":["mcp"]}}}"#)
    let desktopText = #"{"mcpServers":{}}"#
    let desktop = try write("Library/Application Support/Claude/claude_desktop_config.json", desktopText)
    let vscode = try write("Library/Application Support/Code/User/mcp.json", #"{"servers":{"graphitree":{"type":"stdio","command":"c","args":[]}}}"#)
    try write(".claude/CLAUDE.md.graphitree-backup-2026-11-15", "old")
    try write(".claude/CLAUDE.md.graphitree-backup-2026-11-11", "older")
    let notABackup = try write(".claude/CLAUDE.md.keep", "someone else's")

    // The command, the background job, settings and data.
    let bin = home.appendingPathComponent(".local/bin")
    try manager.createDirectory(at: bin, withIntermediateDirectories: true)
    let link = bin.appendingPathComponent("graphitree").path
    try manager.createSymbolicLink(atPath: link, withDestinationPath: "/Applications/Graphitree.app/Contents/MacOS/graphitree-cli")
    let graphify = try write(".local/bin/graphify", "#!/bin/sh\n")
    let job = try write("Library/LaunchAgents/\(UpdateAgent.label).plist", "<plist/>")
    let loginJob = try write("Library/LaunchAgents/\(MenuBarAgent.label).plist", "<plist/>")
    let widgetFolder = (try write("Library/Group Containers/ABCDE12345.com.marcuslai.Graphitree/widget-feed.json", "{}") as NSString).deletingLastPathComponent
    let otherGroup = (try write("Library/Group Containers/ABCDE12345.com.marcuslai.ClaudeUsage/usage-history.jsonl", "") as NSString).deletingLastPathComponent
    let widgetContainer = (try write("Library/Containers/com.marcuslai.Graphitree.Widget/.com.apple.containermanagerd.metadata.plist", "") as NSString)
        .deletingLastPathComponent
    let log = try write("Library/Logs/Graphitree-update.log", "ran")
    let prefs = try write("Library/Preferences/com.marcuslai.Graphitree.plist", "settings")
    try write("Library/Application Support/Graphitree/Chats/chat.json", "{}")
    try write("Library/Caches/com.marcuslai.Graphitree/cache", "x")
    // Where Sparkle keeps update downloads and its installer, inside the app's caches.
    let sparkleCache = try write("Library/Caches/com.marcuslai.Graphitree/org.sparkle-project.Sparkle/Installation/update.dmg", "x")
    try write("Applications/Graphitree.app/Contents/Info.plist", "app")
    let app = home.appendingPathComponent("Applications/Graphitree.app")
    let support = home.appendingPathComponent("Library/Application Support/Graphitree")
    let caches = home.appendingPathComponent("Library/Caches/com.marcuslai.Graphitree")
    let graphFolder = home.appendingPathComponent("Documents/GitHub/graphify-out").path
    try write("Documents/GitHub/graphify-out/playbook.json", "{}")

    let plan = UninstallPlan.make(appURL: app, bundleIdentifier: "com.marcuslai.Graphitree", home: home.path, graphFolder: graphFolder, customFiles: [custom], keyCount: 0)
    expectEqual(plan.edits.map(\.file), [claude, gemini, custom, cursor, windsurf, vscode], "uninstalling takes Graphitree's lines out of each file that has them, and no other")
    expectEqual(plan.edits.map(\.tool), ["Claude Code", "Gemini CLI", "notes/AGENTS.md", "Cursor", "Windsurf", "VS Code (Copilot Chat)"], "each change names its tool")
    expectEqual(plan.commandLinks, [link], "the graphitree link is removed even when the app it points into is gone")
    expectEqual(plan.jobLabels, [UpdateAgent.label], "the background job is stopped")
    expectEqual(plan.preferenceDomains, ["com.marcuslai.Graphitree"], "only Graphitree's settings are emptied")
    let trashed = Set(plan.trash.map(\.path))
    check([job, log, prefs, support.path, caches.path, app.path].allSatisfy(trashed.contains), "the app, its job, log, settings, support folder and caches go to the Trash")
    check(trashed.contains(loginJob), "the open-at-login job goes to the Trash")
    check(trashed.contains(widgetFolder), "the folder shared with the widget goes, whichever team signed it")
    check(!trashed.contains(otherGroup), "another app's group folder stays")
    check(trashed.contains(widgetContainer), "the widget's sandbox folder goes too")
    expectEqual(plan.trash.last, app, "the app goes last")
    check(!trashed.contains(graphFolder) && !trashed.contains(graphify), "the graph folder and graphify stay")
    expectEqual(plan.backupCopies.map(\.lastPathComponent), ["CLAUDE.md.graphitree-backup-2026-11-11", "CLAUDE.md.graphitree-backup-2026-11-15"], "the copies Graphitree left beside a file go too, and nothing else there")
    check(!plan.summary.contains { $0.contains("Keychain") }, "with no keys, the Keychain isn't mentioned")
    check(plan.summary.contains("Take Graphitree's MCP server out of Cursor (\(cursor))"), "an MCP change says so")
    check(plan.summary.last?.hasSuffix("with 2 backup copies it made of other tools' files") == true, "the backup copies are counted")
    check(plan.kept.first?.hasSuffix(", with your Playbook") == true, "the graph folder is kept, Playbook and all")
    expectEqual(Translocation.originalURL(of: app), app, "an app opened where it is, not from a downloaded stand-in, is its own copy")
    let withKeys = UninstallPlan.make(appURL: app, bundleIdentifier: "com.marcuslai.Graphitree", home: home.path, graphFolder: graphFolder, customFiles: [], keyCount: 2)
    check(withKeys.summary.contains("Delete 2 AI keys from the Keychain. Keys can't be put back from the Trash."), "keys are counted and said to be gone for good")

    // The uninstall itself.
    var ran: [[String]] = []
    var deletedKeyServices: [String] = []
    var emptied: [String] = []
    var trashOrder: [String] = []
    let effects = Uninstaller.Effects(
        trash: { url in
            try manager.moveItem(at: url, to: fakeTrash.appendingPathComponent(url.lastPathComponent))
            trashOrder.append(url.lastPathComponent)
        },
        run: { ran.append([$0] + $1) },
        deleteKeys: { deletedKeyServices += $0 },
        removeDefaults: { emptied.append($0) }
    )
    let problems = Uninstaller.perform(plan, effects: effects)
    expectEqual(problems, [], "the uninstall has no problems")
    expectEqual(read(claude), AgentSetup.removing(from: claudeText), "Claude Code's file loses Graphitree's block")
    check(read(claude)?.contains("Keep this.") == true, "and keeps the person's own lines")
    check(!exists(gemini), "a file that held only Graphitree's block is removed")
    check(read(custom).map { !$0.contains("graphitree:knowledge-base") && $0.hasPrefix("Top") } == true, "an added file loses Graphitree's block")
    expectEqual(read(codex), codexText, "a file without Graphitree's lines is left alone")
    expectEqual(servers(cursor, "mcpServers"), ["other"], "Cursor keeps its other server")
    expectEqual(servers(windsurf, "mcpServers"), [], "Windsurf's Graphitree server goes")
    expectEqual(servers(vscode, "servers"), [], "VS Code's format is handled")
    expectEqual(read(desktop), desktopText, "settings without Graphitree's server aren't rewritten")
    check(!exists(link) && exists(graphify), "the graphitree link goes and graphify stays")
    check(![job, log, prefs, support.path, caches.path, app.path].contains(where: exists), "everything in the plan left its place")
    check(!exists(sparkleCache), "Sparkle's update downloads go with the caches")
    check(exists(graphFolder) && exists(notABackup), "the graph folder and unrelated files stay")
    let copies = fakeTrash.appendingPathComponent(Uninstaller.copiesFolderName)
    let copyNames = ((try? manager.contentsOfDirectory(atPath: copies.path)) ?? []).sorted()
    expectEqual(copyNames.count, 6, "a copy of each changed file goes to the Trash")
    expectEqual(read(copies.appendingPathComponent("Claude Code – CLAUDE.md").path), claudeText, "the copy is the file as it was")
    check(copyNames.contains("notes-AGENTS.md – AGENTS.md"), "a tool name with a slash still makes a file name")
    expectEqual(trashOrder.first, Uninstaller.copiesFolderName, "the copies go to the Trash first")
    expectEqual(trashOrder.last, "Graphitree.app", "the app goes to the Trash last")
    check(ran.contains(["/bin/launchctl", "bootout", "gui/\(getuid())/\(UpdateAgent.label)"]), "the background job is booted out")
    check(!ran.contains { $0.contains { $0.hasSuffix(MenuBarAgent.label) } }, "the login job isn't booted out, which would quit the Graphitree it started mid-uninstall")
    check(!exists(loginJob) && !exists(widgetFolder) && exists(otherGroup), "the login job and the widget's folder left their places, and another app's folder stayed")
    expectEqual(ran.filter { $0.first == "/usr/bin/tccutil" }, [["/usr/bin/tccutil", "reset", "All", "com.marcuslai.Graphitree"]], "the app's permissions are reset")
    expectEqual(deletedKeyServices, [], "no keys, no Keychain change")
    expectEqual(emptied, ["com.marcuslai.Graphitree"], "Graphitree's settings are emptied")

    // A Mac with nothing of Graphitree's, and someone else's `graphitree` file.
    let bare = manager.temporaryDirectory.appendingPathComponent("graphitree-bare-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: bare) }
    try manager.createDirectory(at: bare.appendingPathComponent(".local/bin"), withIntermediateDirectories: true)
    try "#!/bin/sh\n".write(to: bare.appendingPathComponent(".local/bin/graphitree"), atomically: true, encoding: .utf8)
    try manager.createDirectory(at: bare.appendingPathComponent(".cursor"), withIntermediateDirectories: true)
    try #"{"theme":"dark"}"#.write(to: bare.appendingPathComponent(".cursor/mcp.json"), atomically: true, encoding: .utf8)
    let empty = UninstallPlan.make(appURL: bare.appendingPathComponent("Graphitree.app"), bundleIdentifier: "com.marcuslai.Graphitree", home: bare.path, graphFolder: bare.appendingPathComponent("graphify-out").path, customFiles: [], keyCount: 0)
    check(empty.edits.isEmpty && empty.commandLinks.isEmpty && empty.jobLabels.isEmpty && empty.trash.isEmpty && empty.backupCopies.isEmpty, "a Mac with nothing of Graphitree's has nothing to remove, and someone else's graphitree file stays")
    expectEqual(empty.kept, ["graphify, and the skills it added to your AI tools"], "without a graph folder, only graphify is listed as kept")
    var installedForThem = empty
    installedForThem.installedGraphify = true
    check(installedForThem.kept.first?.contains("which Graphitree installed") == true && installedForThem.kept.first?.hasSuffix("run uv tool uninstall graphifyy in Terminal.") == true, "graphify that Graphitree installed stays, and the list says how to remove it")
    check(!installedForThem.summary.contains { $0.contains("graphify") }, "and it isn't in what's removed")

    // Graphitree's own sign-in to Claude, without any AI keys.
    var signedIn = empty
    signedIn.hasClaudeSignIn = true
    check(signedIn.summary.contains("Delete Graphitree's own sign-in to Claude from the Keychain. Claude Code's sign-in stays."),
          "its own sign-in to Claude is listed, and Claude Code's is said to stay")
    check(UninstallPlan.keychainServices.contains(ClaudeSignInStore.standard.keychain.service), "the sign-in's Keychain service is one uninstalling empties")
    check(!UninstallPlan.keychainServices.contains(ClaudeCodeSignIn.service), "Claude Code's own Keychain item never is")
    var signInDeletes: [String] = []
    let signInEffects = Uninstaller.Effects(trash: { _ in }, run: { _, _ in }, deleteKeys: { signInDeletes += $0 }, removeDefaults: { _ in })
    _ = Uninstaller.perform(signedIn, effects: signInEffects)
    check(signInDeletes.contains(ClaudeSignInStore.standard.keychain.service), "with only the sign-in, the Keychain is still emptied of it")
}

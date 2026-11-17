import Foundation
import Security

// Uninstalling Graphitree. The plan is worked out first, so
// it's shown before anything happens and can be checked without uninstalling, and what's removed
// goes to the Trash, so it can be put back until the Trash is emptied. Graphitree's own lines come
// out of other tools' files, and a copy of each file as it was goes to the Trash with the rest.
// The graph folder and graphify stay: they're the person's, and other tools read them.
//
// The app runs it from Graphitree › Uninstall Graphitree…, and `graphitree uninstall` from a
// terminal when the app won't open.

/// What uninstalling Graphitree removes, and what it leaves.
struct UninstallPlan: Equatable, Sendable {
    /// Another tool's file that holds Graphitree's lines.
    struct Edit: Equatable, Sendable {
        let tool: String
        let file: String
        /// The MCP settings' format, or nil for an instructions file with Graphitree's block.
        let format: ChatApp.Format?
    }

    var appURL: URL
    var bundleIdentifier: String
    var edits: [Edit]
    /// `~/.local/bin/graphitree`, when it's the app's own link.
    var commandLinks: [String]
    /// Background jobs to stop. Their settings files are in `trash`.
    var jobLabels: [String]
    var keychainServices: [String]
    /// Graphitree's AI keys in the Keychain, under any of `keychainServices`.
    var keyCount: Int
    /// Preference domains emptied. Their files are in `trash`.
    var preferenceDomains: [String]
    /// Moved to the Trash. Only what exists, the app last.
    var trash: [URL]
    /// Copies Graphitree made of other tools' files before changing them. Moved to the Trash too.
    var backupCopies: [URL]
    var graphFolder: String
    var hasGraphFolder: Bool
    var hasPlaybook: Bool
    /// First run installed graphify. It stays, but the confirmation says how to remove it.
    var installedGraphify = false

    static let keychainServices = [AIKeychain.standard.service]
    /// The same keys the app saves under (`AppModel`, `AgentsView`).
    static let graphFolderKey = "graphOutDirectory"
    static let customAgentFilesKey = "customAgentFiles"

    /// The plan for an app at `appURL`. `home` is the home folder, so the checks can use a made-up one.
    static func make(appURL: URL, bundleIdentifier: String, home: String, graphFolder: String, customFiles: [String], keyCount: Int, installedGraphify: Bool = false) -> UninstallPlan {
        let manager = FileManager.default
        // Not `fileExists`, which follows links: a link into a deleted app still counts.
        func exists(_ path: String) -> Bool { (try? manager.attributesOfItem(atPath: path)) != nil }
        let library = URL(fileURLWithPath: home).appendingPathComponent("Library")

        // Every file Graphitree may have changed, to find its lines and the copies it left beside them.
        var files: [String] = []
        var edits: [Edit] = []
        let instructionFiles = AICatalog.codingTools.map { ($0.name, $0.instructionsFile(home: home)) }
            + customFiles.map(AgentSetup.customTarget).map { ($0.name, $0.file) }
        for (tool, file) in instructionFiles where !files.contains(file) {
            files.append(file)
            if let text = try? String(contentsOfFile: file, encoding: .utf8), AgentSetup.isConnected(text) {
                edits.append(Edit(tool: tool, file: file, format: nil))
            }
        }
        for app in AICatalog.chatApps {
            let file = app.configFile(home: home)
            files.append(file)
            if let data = manager.contents(atPath: file), AgentSetup.holdsOwnServer(data, format: app.format) {
                edits.append(Edit(tool: app.name, file: file, format: app.format))
            }
        }

        var links: [String] = []
        if let target = CommandLineTool.linkTarget(home: home), target.hasSuffix("/" + CommandLineTool.executableName) {
            links.append(CommandLineTool.linkPath(home: home))
        }

        var labels: [String] = []
        var trash: [URL] = []
        for label in [UpdateAgent.label] {
            let plist = library.appendingPathComponent("LaunchAgents/\(label).plist")
            if exists(plist.path) {
                labels.append(label)
                trash.append(plist)
            }
        }
        func preferences(_ domain: String) -> URL { library.appendingPathComponent("Preferences/\(domain).plist") }
        let domains = [bundleIdentifier]
        trash += domains.map(preferences)
        trash += [
            "Application Support/\(AppSupport.folderName)",
            "Caches/\(bundleIdentifier)",
            "HTTPStorages/\(bundleIdentifier)",
            "HTTPStorages/\(bundleIdentifier).binarycookies",
            "WebKit/\(bundleIdentifier)",
            "Saved Application State/\(bundleIdentifier).savedState",
        ].map { library.appendingPathComponent($0) }
        trash.append(URL(fileURLWithPath: UpdateAgent.logPath(home: home)))
        trash.append(appURL)
        trash = trash.filter { exists($0.path) }

        var copies: [URL] = []
        for file in files {
            let folder = (file as NSString).deletingLastPathComponent
            let name = (file as NSString).lastPathComponent
            for entry in (try? manager.contentsOfDirectory(atPath: folder)) ?? []
            where entry.hasPrefix(name + ".graphitree-backup-") {
                copies.append(URL(fileURLWithPath: folder).appendingPathComponent(entry))
            }
        }

        return UninstallPlan(
            appURL: appURL,
            bundleIdentifier: bundleIdentifier,
            edits: edits,
            commandLinks: links,
            jobLabels: labels,
            keychainServices: keychainServices,
            keyCount: keyCount,
            preferenceDomains: domains,
            trash: trash,
            backupCopies: copies.sorted { $0.path < $1.path },
            graphFolder: graphFolder,
            hasGraphFolder: exists(graphFolder),
            hasPlaybook: exists((graphFolder as NSString).appendingPathComponent(PlaybookFile.jsonName)),
            installedGraphify: installedGraphify
        )
    }

    /// The plan for this Mac, from Graphitree's saved settings. A downloaded copy opened where it
    /// was unzipped runs from a stand-in, so the copy removed is the one in the download folder.
    static func current(appURL: URL, bundleIdentifier: String = GraphLocator.graphitreeDefaults, settings: UserDefaults?) -> UninstallPlan {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let graphFolder = settings?.string(forKey: graphFolderKey) ?? home + "/Documents/GitHub/graphify-out"
        let customFiles = (settings?.string(forKey: customAgentFilesKey) ?? "").split(separator: "\n").map(String.init)
        return make(
            appURL: Translocation.originalURL(of: appURL), bundleIdentifier: bundleIdentifier, home: home, graphFolder: graphFolder,
            customFiles: customFiles, keyCount: Uninstaller.keyAccounts(services: keychainServices).count,
            installedGraphify: settings?.bool(forKey: GraphifySetup.installedKey) ?? false
        )
    }

    /// What happens, one line each, for the confirmation.
    var summary: [String] {
        var lines: [String] = []
        if !jobLabels.isEmpty { lines.append("Stop the background job that updates the graph and runs backups") }
        if !commandLinks.isEmpty { lines.append("Remove the graphitree command from ~/.local/bin") }
        for edit in edits {
            lines.append("Take Graphitree's \(edit.format == nil ? "lines" : "MCP server") out of \(edit.tool) (\(AgentGuide.abbreviate(edit.file)))")
        }
        if keyCount > 0 {
            lines.append("Delete \(keyCount) AI key\(keyCount == 1 ? "" : "s") from the Keychain. Keys can't be put back from the Trash.")
        }
        lines.append("Reset its Privacy & Security permissions")
        var trashLine = "Move the app, its settings, caches and logs to the Trash"
        if !backupCopies.isEmpty {
            trashLine += ", with \(backupCopies.count) backup cop\(backupCopies.count == 1 ? "y" : "ies") it made of other tools' files"
        }
        lines.append(trashLine)
        return lines
    }

    /// What stays, for the confirmation.
    var kept: [String] {
        var lines: [String] = []
        if hasGraphFolder {
            lines.append("Your graph folder, \(AgentGuide.abbreviate(graphFolder))" + (hasPlaybook ? ", with your Playbook" : ""))
        }
        if installedGraphify {
            lines.append("graphify, which Graphitree installed, and the skills it added to your AI tools. Other tools can use it too. To remove it, run \(GraphifySetup.removeCommand) in Terminal.")
        } else {
            lines.append("graphify, and the skills it added to your AI tools")
        }
        if hasPlaybook { lines.append("Playbook lines in your repos' AGENTS.md or CLAUDE.md, which are part of each repo") }
        return lines
    }

    /// The whole plan as text, for the terminal.
    var text: String {
        (["Uninstalling Graphitree will:"] + summary.map { "  • " + $0 }
            + ["", "It keeps:"] + kept.map { "  • " + $0 }
            + ["", Uninstaller.trashNote]).joined(separator: "\n")
    }
}

extension AgentSetup {
    /// Whether a chat app's MCP settings hold Graphitree's server, or one that removing it also takes out.
    static func holdsOwnServer(_ data: Data, format: ChatApp.Format) -> Bool {
        let key = format == .vscode ? "servers" : "mcpServers"
        guard let removed = try? mcpConfigRemovingServer(data, format: format),
              let before = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let after = try? JSONSerialization.jsonObject(with: removed) as? [String: Any] else { return false }
        return (before[key] as? [String: Any] ?? [:]).count != (after[key] as? [String: Any] ?? [:]).count
    }
}

/// A downloaded app that's opened before it's moved out of its download folder runs from a
/// read-only stand-in at a random path (App Translocation), which goes when the app quits.
enum Translocation {
    private typealias IsTranslocated = @convention(c) (CFURL, UnsafeMutablePointer<Bool>, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> DarwinBoolean
    private typealias OriginalPath = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?

    /// The person's own copy of the app or file at `url`, or `url` when it isn't a stand-in.
    /// Security exports these two functions without a header, so they're looked up by name
    /// (checked against a real stand-in on macOS 27.2).
    static func originalURL(of url: URL) -> URL {
        let anyImage = UnsafeMutableRawPointer(bitPattern: -2)  // RTLD_DEFAULT, which Swift doesn't import
        guard let isSymbol = dlsym(anyImage, "SecTranslocateIsTranslocatedURL"),
              let originalSymbol = dlsym(anyImage, "SecTranslocateCreateOriginalPathForURL") else { return url }
        var translocated = false
        guard unsafeBitCast(isSymbol, to: IsTranslocated.self)(url as CFURL, &translocated, nil).boolValue, translocated,
              let original = unsafeBitCast(originalSymbol, to: OriginalPath.self)(url as CFURL, nil)?.takeRetainedValue() else { return url }
        return original as URL
    }
}

/// Runs an uninstall plan.
enum Uninstaller {
    static let trashNote = "Everything removed goes to the Trash, with a copy of each changed file as it was, so it can be put back until you empty it."
    /// The folder in the Trash that holds the changed files as they were.
    static let copiesFolderName = "Files before uninstalling Graphitree"

    /// What the uninstall does to the Mac. The checks swap these out, so they run it without
    /// touching anything real.
    struct Effects {
        var trash: (URL) throws -> Void
        var run: (String, [String]) -> Void
        var deleteKeys: ([String]) -> Void
        var removeDefaults: (String) -> Void

        static let live = Effects(
            trash: { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) },
            run: { _ = try? ProcessRunner.run($0, $1, timeout: 20) },
            deleteKeys: { Uninstaller.deleteKeys(services: $0) },
            removeDefaults: { domain in
                UserDefaults.standard.removePersistentDomain(forName: domain)
                CFPreferencesAppSynchronize(domain as CFString)
            }
        )
    }

    /// Runs the plan and returns what couldn't be done. Only after the person confirmed it.
    static func perform(_ plan: UninstallPlan, effects: Effects = .live) -> [String] {
        let manager = FileManager.default
        var problems: [String] = []
        let abbreviate = AgentGuide.abbreviate

        for label in plan.jobLabels {
            effects.run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(label)"])
        }
        for link in plan.commandLinks {
            do { try manager.removeItem(atPath: link) } catch { problems.append("Couldn't remove \(abbreviate(link)): \(error.localizedDescription)") }
        }

        // Each file is copied as it was into one folder, which goes to the Trash with the rest.
        var trash = plan.trash
        if !plan.edits.isEmpty {
            let copies = manager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
                .appendingPathComponent(copiesFolderName, isDirectory: true)
            var edits = plan.edits
            do {
                try manager.createDirectory(at: copies, withIntermediateDirectories: true)
                trash.insert(copies, at: 0)
            } catch {
                problems.append("Couldn't make a folder for copies of the changed files, so none were changed: \(error.localizedDescription)")
                edits = []
            }
            for edit in edits {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: edit.file))
                    var name = "\(edit.tool) – \((edit.file as NSString).lastPathComponent)".replacingOccurrences(of: "/", with: "-")
                    while manager.fileExists(atPath: copies.appendingPathComponent(name).path) { name = "Another " + name }
                    try data.write(to: copies.appendingPathComponent(name))
                    if let format = edit.format {
                        try AgentSetup.write(AgentSetup.mcpConfigRemovingServer(data, format: format), to: edit.file)
                    } else {
                        let updated = AgentSetup.removing(from: String(decoding: data, as: UTF8.self))
                        // A file that held nothing but Graphitree's block goes; its copy is kept.
                        if updated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            try manager.removeItem(atPath: edit.file)
                        } else {
                            try AgentSetup.write(updated, to: edit.file)
                        }
                    }
                } catch {
                    problems.append("Couldn't take Graphitree's lines out of \(edit.tool) (\(abbreviate(edit.file))): \(error.localizedDescription)")
                }
            }
        }

        if plan.keyCount > 0 { effects.deleteKeys(plan.keychainServices) }
        for domain in plan.preferenceDomains { effects.removeDefaults(domain) }

        for url in trash + plan.backupCopies.filter({ !trash.contains($0) }) {
            // The app goes last, below, so the rest is gone before it is.
            guard url != plan.appURL else { continue }
            do { try effects.trash(url) } catch { problems.append("Couldn't move \(abbreviate(url.path)) to the Trash: \(error.localizedDescription)") }
        }
        if trash.contains(plan.appURL) {
            do { try effects.trash(plan.appURL) } catch { problems.append("Couldn't move \(abbreviate(plan.appURL.path)) to the Trash: \(error.localizedDescription)") }
        }

        // Works with the app in the Trash, where macOS still knows its identifier. The command
        // line's own Documents access can't be reset this way: tccutil only takes registered
        // bundle identifiers, and the command has none (checked on macOS 27.2).
        effects.run("/usr/bin/tccutil", ["reset", "All", plan.bundleIdentifier])
        return problems
    }

    // MARK: - Keychain

    /// The accounts saved under each service, such as `anthropic.ANTHROPIC_API_KEY`.
    static func keyAccounts(services: [String]) -> [(service: String, account: String)] {
        services.flatMap { service -> [(service: String, account: String)] in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecReturnAttributes as String: true,
                kSecMatchLimit as String: kSecMatchLimitAll,
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let items = result as? [[String: Any]] else { return [] }
            return items.compactMap { ($0[kSecAttrAccount as String] as? String).map { (service, $0) } }
        }
    }

    /// One at a time, by account, since a delete by service alone may stop at the first match.
    static func deleteKeys(services: [String]) {
        for (service, account) in keyAccounts(services: services) {
            let match: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(match as CFDictionary)
        }
    }
}

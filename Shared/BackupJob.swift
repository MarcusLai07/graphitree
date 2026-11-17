import Foundation

// Backups that run on their own, and putting a backup back. Graphitree and its command line share
// all of it: the background job runs `graphitree backup --scheduled` while Graphitree is closed,
// and the app runs the same due check after a rebuild.

// MARK: - When a backup is due

enum BackupSchedule {
    /// "After each rebuild" waits at least this long between backups.
    static let rebuildGap: TimeInterval = 3600
    /// A failed backup waits this long before trying again on its own.
    static let retryGap: TimeInterval = 3600
    /// "Daily" runs once the last backup is older than this. The background job looks every four hours.
    static let dailyGap: TimeInterval = 20 * 3600

    /// Whether a backup should run on its own now. A backup never runs on its own until the person
    /// has pressed Back Up Now once for where it goes now, so the first push, and any new repo, is
    /// always theirs.
    static func isDue(_ plan: BackupPlan, record: BackupStore.Record?, graphDate: Date?, now: Date = .now) -> Bool {
        guard plan.destination != .none, plan.when != .manual, let record, let lastSuccess = record.lastSuccess else { return false }
        guard record.target == (BackupStore.remote(for: plan) ?? "this Mac") else { return false }
        if record.lastError != nil, let attempt = record.lastAttempt, now.timeIntervalSince(attempt) < retryGap { return false }
        let sinceSuccess = now.timeIntervalSince(lastSuccess)
        switch plan.when {
        case .manual:
            return false
        case .rebuild:
            guard sinceSuccess >= rebuildGap, let graphDate else { return false }
            // Saved dates keep whole seconds, so a second's difference is the same graph.
            return graphDate.timeIntervalSince(record.graphDate ?? .distantPast) >= 1
        case .daily:
            return sinceSuccess >= dailyGap
        }
    }

    /// Why a backup isn't running on its own, for the setup card. Nil when it will.
    static func waitingReason(_ plan: BackupPlan, record: BackupStore.Record?) -> String? {
        guard plan.destination != .none, plan.when != .manual else { return nil }
        guard record?.lastSuccess != nil else { return "Runs on its own once you've backed it up yourself." }
        guard record?.target == (BackupStore.remote(for: plan) ?? "this Mac") else { return "Where it goes changed, so back it up yourself once before it runs on its own." }
        return nil
    }
}

/// The knowledge bases with backups that run on their own, so the background job knows where to look.
enum ScheduledBackups {
    static func url(in folder: URL = BackupStore.folder) -> URL { folder.appendingPathComponent("scheduled.json") }

    static func load(in folder: URL = BackupStore.folder) -> [String] {
        guard let data = try? Data(contentsOf: url(in: folder)) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    /// Lists or unlists one knowledge base, going by whether any of its graphs back up on their own.
    /// Returns whether any knowledge base is listed afterwards.
    @discardableResult
    static func update(outDirectory: URL, plans: [GraphPlan], in folder: URL = BackupStore.folder) -> Bool {
        let path = outDirectory.standardizedFileURL.path
        var paths = load(in: folder)
        let wanted = plans.contains { $0.backup.destination != .none && $0.backup.when != .manual }
        if wanted, !paths.contains(path) { paths.append(path) }
        if !wanted { paths.removeAll { $0 == path } }
        guard paths != load(in: folder) else { return !paths.isEmpty }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        try? encoder.encode(paths.sorted()).write(to: url(in: folder), options: .atomic)
        return !paths.isEmpty
    }
}

// MARK: - Running backups without the app

enum BackupJob {
    /// Graphitree saves which login goes with each git rule under this key.
    static let confirmedLoginsKey = "gitRuleLogins"

    static func confirmedLogins(_ defaults: UserDefaults? = GraphLocator.graphitreeSettings) -> [String: String] {
        defaults?.dictionary(forKey: confirmedLoginsKey) as? [String: String] ?? [:]
    }

    /// Nodes per project, counted from graph.json.
    static func nodeCounts(_ graph: [String: Any], labels: [FolderLabel]) -> [String: Int] {
        let groups = Set(labels.filter(\.holdsProjects).map(\.path))
        var sizes: [String: Int] = [:]
        for node in graph["nodes"] as? [[String: Any]] ?? [] {
            guard let file = node["source_file"] as? String, !file.isEmpty else { continue }
            sizes[SourcePath.project(of: file, groups: groups), default: 0] += 1
        }
        return sizes
    }

    /// The arrangement as saved, with the projects on disk now. Reads no index, so it works while
    /// Graphitree is closed. `nodes` defaults to counting graph.json.
    static func arrangement(outDirectory: URL, graph: [String: Any]?, scan givenScan: FolderScanResult? = nil, nodes givenNodes: [String: Int]? = nil) -> Arrangement {
        let source = GraphSource(outDirectory: outDirectory)
        let scan = givenScan ?? FolderScan.scan(root: source.rootPath)
        let map = FolderFile.load(from: outDirectory)
        let labels = FolderScan.labels(saved: map, scan: scan)
        let nodes = givenNodes ?? graph.map { nodeCounts($0, labels: labels) } ?? [:]
        let ignore = IgnoreFile.patterns(in: (try? String(contentsOfFile: (source.rootPath as NSString).appendingPathComponent(".graphifyignore"), encoding: .utf8)) ?? "")
        let projects = ArrangeProjects.list(root: source.rootPath, scan: scan, labels: labels, nodes: nodes)
        return Arrangement(map: map ?? FolderMap(folders: labels), labels: labels, graphs: GraphPlans.load(from: outDirectory), projects: projects, ignoredLines: ignore)
    }

    /// The owner's git rules and gh logins, with each rule's login: confirmed ones, else a guess
    /// from the remotes of repos under it.
    static func accounts(for arrangement: Arrangement, root: String, confirmed: [String: String]) -> GitAccounts {
        var remotes: [String: String] = [:]
        for project in arrangement.projects {
            if let remote = project.remote { remotes[(root as NSString).appendingPathComponent(project.path)] = remote }
        }
        let rules = GitRules.read()
        let logins = PlaybookBackup.accounts()
        return GitAccounts(rules: rules, logins: logins, loginByFolder: GitAccounts.guess(rules: rules, logins: logins, remotesByPath: remotes, confirmed: confirmed))
    }

    /// Who a graph's backup is signed as: the git rule its login goes with, else the global identity.
    static func identity(for graph: GraphPlan, accounts: GitAccounts) -> GitIdentity? {
        graph.backup.login.flatMap(accounts.identity(forLogin:)) ?? accounts.rules.global
    }

    /// Whether graphify is building now, in which case scheduled backups wait for the next run.
    static func graphifyIsBusy() -> Bool {
        guard let result = try? ProcessRunner.run("/usr/bin/pgrep", ["-f", "graphify (update|extract|label)"], timeout: 5) else { return false }
        return result.status == 0
    }

    struct Options {
        /// One graph, by name, slug or id. Nil for every graph that backs up.
        var only: String?
        /// Only backups whose schedule says they're due.
        var ifDue = false
        /// Say what would be saved, and write nothing.
        var dryRun = false
        var ranFrom = "command line"
        var waitsForGraphify = true
    }

    struct Line: Equatable {
        let graph: String
        let message: String
        var failed = false
    }

    /// Backs up one knowledge base's graphs. Throws only when nothing could start; each graph's own
    /// failure is a line in the result.
    static func run(outDirectory: URL, options: Options, store: URL = BackupStore.folder, now: Date = .now, confirmed: [String: String], log: (String) -> Void = { _ in }) throws -> [Line] {
        guard let saved = GraphPlans.load(from: outDirectory) else {
            if options.ifDue { return [] }
            throw PlaybookError(message: "No backups are set up for \(AgentGuide.abbreviate(outDirectory.path)). Set them up in Graphitree: Folders › Back Up.")
        }
        var plans = saved.filter { $0.backup.destination != .none }
        if let only = options.only {
            let wanted = only.lowercased()
            plans = saved.filter { $0.name.lowercased() == wanted || $0.slug == wanted || $0.id == only }
            guard let plan = plans.first else {
                throw PlaybookError(message: "There's no graph called \(only). Graphs here: \(saved.map(\.name).joined(separator: ", ")).")
            }
            guard plan.backup.destination != .none else { throw PlaybookError(message: "\(plan.name) is set to Don't Back Up.") }
        }
        let graphURL = outDirectory.appendingPathComponent("graph.json")
        let graphDate = (try? FileManager.default.attributesOfItem(atPath: graphURL.path)[.modificationDate]) as? Date
        if options.ifDue {
            let records = BackupStore.records(in: store)
            plans = plans.filter { BackupSchedule.isDue($0.backup, record: records[$0.id], graphDate: graphDate, now: now) }
            guard !plans.isEmpty else { return [] }
            if options.waitsForGraphify, graphifyIsBusy() {
                log("graphify is building, so backups wait for the next run.")
                return []
            }
        }
        guard !plans.isEmpty else { throw PlaybookError(message: "None of this graph's backups are switched on.") }

        let graph = try GraphPartition.read(graphURL)
        let arrangement = arrangement(outDirectory: outDirectory, graph: graph)
        let root = GraphSource(outDirectory: outDirectory).rootPath
        let accounts = accounts(for: arrangement, root: root, confirmed: confirmed)
        var lines: [Line] = []
        for plan in plans {
            guard let current = arrangement.graphs.first(where: { $0.id == plan.id }) else { continue }
            do {
                log("\(current.name): gathering files")
                let bundle = try BackupContents.build(graphID: current.id, arrangement: arrangement, outDirectory: outDirectory, graph: graph, now: now)
                if options.dryRun {
                    let size = { (bytes: Int) in ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) }
                    let target = BackupStore.remote(for: current.backup) ?? "this Mac"
                    var text = "\(bundle.files.count.formatted()) files, \(size(bundle.savedBytes)), to \(target)"
                    if let largest = bundle.largest { text += "; largest \(largest.path) at \(size(largest.bytes))" }
                    text += "; signs as \(identity(for: current, accounts: accounts)?.display ?? "git's own identity")"
                    lines.append(Line(graph: current.name, message: text))
                    for warning in BackupWarnings.warnings(graph: current, arrangement: arrangement, accounts: accounts, root: root, largestBytes: bundle.largest?.bytes, repoHasOtherHistory: nil, dismissed: []) {
                        lines.append(Line(graph: current.name, message: "\(warning.title). \(warning.detail)"))
                    }
                    continue
                }
                let outcome = try BackupRunner.run(
                    bundle: bundle, graph: current, identity: identity(for: current, accounts: accounts),
                    message: BackupMessages.defaultMessage(graph: current, nodes: bundle.summary.nodes, now: now),
                    store: store, createRepo: !options.ifDue, ranFrom: options.ranFrom, log: { log("  " + $0) }
                )
                lines.append(Line(graph: current.name, message: outcome.message))
            } catch is BackupBusy {
                lines.append(Line(graph: current.name, message: "Skipped: another backup is running."))
            } catch {
                lines.append(Line(graph: current.name, message: error.localizedDescription, failed: true))
            }
        }
        return lines
    }

    /// What the background job runs: every listed knowledge base's due backups.
    static func runScheduled(store: URL = BackupStore.folder, now: Date = .now, confirmed: [String: String], waitsForGraphify: Bool = true, log: (String) -> Void = { _ in }) -> [Line] {
        var lines: [Line] = []
        for path in ScheduledBackups.load(in: store) {
            let out = URL(fileURLWithPath: path, isDirectory: true)
            guard FileManager.default.fileExists(atPath: out.appendingPathComponent("graph.json").path) else {
                log("\(AgentGuide.abbreviate(path)) has no graph.json any more, so it was skipped.")
                continue
            }
            do {
                let options = Options(ifDue: true, ranFrom: "background", waitsForGraphify: waitsForGraphify)
                lines += try run(outDirectory: out, options: options, store: store, now: now, confirmed: confirmed, log: log)
            } catch {
                lines.append(Line(graph: AgentGuide.abbreviate(path), message: error.localizedDescription, failed: true))
            }
        }
        return lines
    }
}

// MARK: - Putting a backup back

/// Restores one or more backups into a new graphify-out folder. It never writes over a graph in
/// use: the result goes to a folder of its own, and moving it into place is a separate step.
enum BackupRestore {
    struct Source: Hashable, Identifiable, Sendable {
        /// "MarcusLai07/personal-kb", or a graph's name for a copy on this Mac.
        var name: String
        /// An HTTPS GitHub URL or a local repo path.
        var remote: String
        var login: String?
        var id: String { remote }

        /// A GitHub repo by owner and name, read as `login`.
        static func github(login: String, repo: String) -> Source {
            Source(name: "\(login)/\(repo)", remote: "https://github.com/\(login)/\(repo).git", login: login)
        }
    }

    /// The backups set up for this knowledge base: each one's GitHub repo, or its copy on this Mac.
    static func sources(plans: [GraphPlan], store: URL = BackupStore.folder) -> [Source] {
        plans.compactMap { plan in
            switch plan.backup.destination {
            case .github:
                guard let login = plan.backup.login, !plan.backup.repo.isEmpty else { return nil }
                return .github(login: login, repo: plan.backup.repo)
            case .local:
                let mirror = BackupStore.mirror(for: plan.backup, graph: plan, in: store)
                guard FileManager.default.fileExists(atPath: mirror.appendingPathComponent(".git").path) else { return nil }
                return Source(name: "\(plan.name) (this Mac)", remote: mirror.path, login: nil)
            case .none:
                return nil
            }
        }
    }

    /// Where a restore goes: beside the root, never inside it, so the next rebuild doesn't read it.
    /// graphify only reads graphs inside a folder called graphify-out, so that's the last part.
    static func destination(root: String, now: Date = .now) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let parent = (root as NSString).deletingLastPathComponent
        return URL(fileURLWithPath: parent, isDirectory: true)
            .appendingPathComponent("Graphitree restores/\(formatter.string(from: now))/graphify-out", isDirectory: true)
    }

    /// Clones one backup's latest version into `folder` and checks it's one Graphitree wrote.
    static func fetch(_ source: Source, into folder: URL) throws {
        let parent = folder.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let isLocal = source.remote.hasPrefix("/")
        let git = try GitMirror(directory: folder, remote: source.remote, login: source.login)
        try git.git(["clone", "--quiet"] + (isLocal ? [] : ["--depth", "1"]) + [source.remote, folder.path], in: parent, timeout: 900)
        guard FileManager.default.fileExists(atPath: folder.appendingPathComponent("graph/\(GraphPartition.fileName(for: GraphPartition.index))").path) else {
            throw PlaybookError(message: "\(source.name) isn't a backup Graphitree wrote: it has no graph/_index.json.")
        }
    }

    struct Restored: Sendable {
        let folder: URL
        let nodes: Int
        let edges: Int
        let backups: Int
        let notes: [String]
    }

    /// Joins backups (cloned folders) into one graphify-out at `destination`, which must not exist.
    /// The first backup's graph-wide settings win. Each backup's parts must add back up to what it
    /// recorded, or nothing is written.
    static func combine(_ folders: [URL], into destination: URL, root: String) throws -> Restored {
        let fileManager = FileManager.default
        guard !folders.isEmpty else { throw PlaybookError(message: "Pick at least one backup to restore.") }
        guard !fileManager.fileExists(atPath: destination.path) else { throw PlaybookError(message: "\(destination.path) already exists.") }

        var merged: [String: Any]?
        var key = "links"
        var seenNodes = Set<String>()
        var seenEdges = Set<String>()
        var seenTop = Set<String>()
        var seenInner = Set<String>()
        var manifest: [String: Any] = [:]
        var labels: [String: [String: Any]] = [:]
        var maps: [FolderMap] = []
        var plans: [GraphPlan] = []
        var rules: [(at: String, order: Int, line: String)] = []
        var seenRules = Set<String>()
        var copies: [String: URL] = [:]
        var notes: [String] = []

        func canonical(_ object: Any) -> String {
            (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])).map { String(decoding: $0, as: UTF8.self) } ?? ""
        }
        /// Adds what's new in `list` to `existing`, by content.
        func add(_ list: [[String: Any]]?, to existing: [[String: Any]]?, seen: inout Set<String>) -> [[String: Any]] {
            var result = existing ?? []
            for item in list ?? [] where seen.insert(canonical(item)).inserted { result.append(item) }
            return result
        }

        for folder in folders {
            // The graph: its parts must join back to what the backup recorded.
            let graphFolder = folder.appendingPathComponent("graph", isDirectory: true)
            var parts: [String: Data] = [:]
            let base = graphFolder.standardizedFileURL.path + "/"
            if let enumerator = fileManager.enumerator(at: graphFolder, includingPropertiesForKeys: [.isRegularFileKey]) {
                for case let url as URL in enumerator where url.pathExtension == "json" {
                    parts[String(url.standardizedFileURL.path.dropFirst(base.count))] = try Data(contentsOf: url)
                }
            }
            _ = try GraphPartition.verify(parts)
            let graph = try GraphPartition.join(parts)
            let inner = graph["graph"] as? [String: Any]
            if var current = merged {
                var nodes = current["nodes"] as? [[String: Any]] ?? []
                for node in graph["nodes"] as? [[String: Any]] ?? [] {
                    guard let id = node["id"] as? String, seenNodes.insert(id).inserted else { continue }
                    nodes.append(node)
                }
                current["nodes"] = nodes
                current[key] = add(graph[GraphPartition.edgeKey(of: graph)] as? [[String: Any]], to: current[key] as? [[String: Any]], seen: &seenEdges)
                if current["hyperedges"] != nil || graph["hyperedges"] != nil {
                    current["hyperedges"] = add(graph["hyperedges"] as? [[String: Any]], to: current["hyperedges"] as? [[String: Any]], seen: &seenTop)
                }
                if var currentInner = current["graph"] as? [String: Any], currentInner["hyperedges"] != nil || inner?["hyperedges"] != nil {
                    currentInner["hyperedges"] = add(inner?["hyperedges"] as? [[String: Any]], to: currentInner["hyperedges"] as? [[String: Any]], seen: &seenInner)
                    current["graph"] = currentInner
                }
                merged = current
            } else {
                key = GraphPartition.edgeKey(of: graph)
                seenNodes = Set((graph["nodes"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
                seenEdges = Set((graph[key] as? [[String: Any]] ?? []).map(canonical))
                seenTop = Set((graph["hyperedges"] as? [[String: Any]] ?? []).map(canonical))
                seenInner = Set((inner?["hyperedges"] as? [[String: Any]] ?? []).map(canonical))
                merged = graph
            }

            // The rebuild index and community names: one entry per file or community.
            if let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                manifest.merge(object) { first, _ in first }
            }
            for name in [".graphify_labels.json", ".graphify_labels.json.sig"] {
                guard let data = try? Data(contentsOf: folder.appendingPathComponent(name)),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                labels[name, default: [:]].merge(object) { first, _ in first }
            }
            // The owner's decisions.
            if let data = try? Data(contentsOf: folder.appendingPathComponent(FolderFile.fileName)),
               let map = try? JSONDecoder().decode(FolderMap.self, from: data) {
                maps.append(map)
            }
            if let loaded = GraphPlans.load(from: folder) {
                for plan in loaded where !plans.contains(where: { $0.id == plan.id }) { plans.append(plan) }
            }
            if let text = try? String(contentsOf: folder.appendingPathComponent("curation.jsonl"), encoding: .utf8) {
                for line in text.split(separator: "\n", omittingEmptySubsequences: true) where seenRules.insert(String(line)).inserted {
                    let object = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
                    rules.append((object?["at"] as? String ?? "", rules.count, String(line)))
                }
            }
            // Files copied as they are: the semantic cache, the playbook and the whole-graph pages.
            let semantic = folder.appendingPathComponent("cache/semantic", isDirectory: true)
            let semanticBase = semantic.standardizedFileURL.path + "/"
            if let enumerator = fileManager.enumerator(at: semantic, includingPropertiesForKeys: [.isRegularFileKey]) {
                for case let url as URL in enumerator where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                    let relative = "cache/semantic/" + String(url.standardizedFileURL.path.dropFirst(semanticBase.count))
                    if copies[relative] == nil { copies[relative] = url }
                }
            }
            for name in [PlaybookFile.markdownName, PlaybookFile.jsonName, AgentGuide.fileName, "graph.html", "GRAPH_REPORT.md"] {
                let url = folder.appendingPathComponent(name)
                if copies[name] == nil, fileManager.fileExists(atPath: url.path) { copies[name] = url }
            }
        }
        guard let graph = merged else { throw PlaybookError(message: "Nothing to restore.") }
        if folders.count > 1 {
            notes.append("Links between these graphs weren't in their backups, so the restored graph doesn't have them. graphify adds a file's links back when it next reads that file, after it changes.")
            for name in [AgentGuide.fileName, "graph.html", "GRAPH_REPORT.md"] { copies[name] = nil }
        }

        // Written to a folder beside the destination, then moved into place in one step.
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".restoring-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            let graphData = try JSONSerialization.data(withJSONObject: graph, options: [.withoutEscapingSlashes])
            try graphData.write(to: staging.appendingPathComponent("graph.json"))
            if !manifest.isEmpty {
                try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: staging.appendingPathComponent("manifest.json"))
            }
            for (name, object) in labels where !object.isEmpty {
                try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: staging.appendingPathComponent(name))
            }
            if let map = mergedMap(maps) { try FolderFile.save(map, to: staging) }
            if !plans.isEmpty { try GraphPlans.save(plans, to: staging) }
            if !rules.isEmpty {
                let text = rules.sorted { $0.at != $1.at ? $0.at < $1.at : $0.order < $1.order }.map(\.line).joined(separator: "\n") + "\n"
                try Data(text.utf8).write(to: staging.appendingPathComponent("curation.jsonl"))
            }
            for (relative, url) in copies {
                let target = staging.appendingPathComponent(relative)
                try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.copyItem(at: url, to: target)
            }
            try Data(root.utf8).write(to: staging.appendingPathComponent(".graphify_root"))

            // Read back what was written, as graphify will.
            let check = try GraphPartition.summary(of: GraphPartition.read(staging.appendingPathComponent("graph.json")))
            try fileManager.moveItem(at: staging, to: destination)
            return Restored(folder: destination, nodes: check.nodes, edges: check.edges, backups: folders.count, notes: notes)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    /// Folder labels, made areas and placements from every backup, the first one winning.
    static func mergedMap(_ maps: [FolderMap]) -> FolderMap? {
        guard var result = maps.first else { return nil }
        for map in maps.dropFirst() {
            for folder in map.folders where !result.folders.contains(where: { $0.path == folder.path }) { result.folders.append(folder) }
            for area in map.arrangedAreas where !result.arrangedAreas.contains(where: { $0.id == area.id }) { result.arrangedAreas.append(area) }
            result.placement.merge(map.placement) { first, _ in first }
        }
        return result
    }

    /// Asks the restored graph a question with graphify itself, which proves graphify can read it.
    /// Returns nil when it answered, or what went wrong.
    static func checkWithGraphify(_ outDirectory: URL, graphify: String?) -> String? {
        guard let graphify else { return "graphify isn't installed, so the restored graph wasn't checked with it." }
        let graph = outDirectory.appendingPathComponent("graph.json")
        // Ask about a node that's there, so an answer proves graphify read the graph.
        let nodes = (try? GraphPartition.read(graph))?["nodes"] as? [[String: Any]] ?? []
        guard let label = nodes.lazy.compactMap({ $0["label"] as? String }).first(where: { $0.count >= 3 }) else { return "The restored graph has no nodes to ask about." }
        guard let result = try? ProcessRunner.run(graphify, ["query", label, "--graph", graph.path, "--budget", "300"],
                                                  in: outDirectory.deletingLastPathComponent(), environment: ["GRAPHIFY_QUERY_LOG_DISABLE": "1"], timeout: 180) else {
            return "graphify couldn't be run."
        }
        guard result.status == 0, !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let detail = (result.errors + result.output).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").last.map(String.init)
            return "graphify couldn't read it: \(detail ?? "exit \(result.status)")"
        }
        return nil
    }

    /// Moves a restored graph to `<root>/graphify-out`. Only when no graph is there: one in use is
    /// never replaced.
    static func putInPlace(_ restored: URL, root: String) throws -> URL {
        let target = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("graphify-out", isDirectory: true)
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: target.path) else {
            throw PlaybookError(message: "\(AgentGuide.abbreviate(target.path)) already exists, so the restored graph stays where it is.")
        }
        try fileManager.createDirectory(atPath: root, withIntermediateDirectories: true)
        try fileManager.moveItem(at: restored, to: target)
        let parent = restored.deletingLastPathComponent()
        if ((try? fileManager.contentsOfDirectory(atPath: parent.path)) ?? ["x"]).isEmpty { try? fileManager.removeItem(at: parent) }
        return target
    }
}

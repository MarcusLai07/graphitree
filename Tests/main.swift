// Run with Scripts/test.sh, which covers the fixture checks below.
// `GraphitreeChecks --real <graphify-out>` prints the overview of a real graph as JSON.
import Foundation

/// `DispatchQueue.sync` would stay on the main thread and trip the importer's main-thread guard.
func onBackgroundQueue<T>(_ body: @escaping () throws -> T) throws -> T {
    var result: Result<T, Error>?
    let done = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
        result = Result(catching: body)
        done.signal()
    }
    done.wait()
    return try result!.get()
}

setbuf(stdout, nil)

func openRealWorkspace(_ path: String, cache: URL) throws -> Workspace {
    let source = GraphSource(outDirectory: URL(fileURLWithPath: path))
    return try onBackgroundQueue { try Workspace(source: source, cacheDirectory: cache) }
}

func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    print(String(decoding: try encoder.encode(value), as: UTF8.self))
}

// `--rebuild <graphify-out> [--force]` runs the same rebuild flow as the app.
if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--rebuild" {
    let source = GraphSource(outDirectory: URL(fileURLWithPath: CommandLine.arguments[2]))
    let force = CommandLine.arguments.contains("--force")
    // `--docs <backend>` adds the `graphify extract` pass with that backend.
    let docs = CommandLine.arguments.firstIndex(of: "--docs").flatMap { index -> DocsPass? in
        guard index + 1 < CommandLine.arguments.count else { return nil }
        let backend = CommandLine.arguments[index + 1]
        return DocsPass(name: backend, backend: backend, model: nil, environment: [:], billing: .thisMac, module: nil)
    }
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: cache) }
    let before = try onBackgroundQueue { try Workspace(source: source, cacheDirectory: cache).snapshot().overview }
    let run = try onBackgroundQueue {
        try GraphRebuilder().run(source: source, force: force, docs: docs) { FileHandle.standardError.write(Data($0.utf8)) }
    }
    print("exit \(run.status), refusedToShrink \(run.refusedToShrink)")
    guard run.status == 0, !run.refusedToShrink else { exit(2) }
    let reopened = try onBackgroundQueue {
        try Workspace.reopenAfterRebuild(source: source, cacheDirectory: cache, nodesBefore: before.nodes, edgesBefore: before.edges)
    }
    print(reopened.report)
    for rule in reopened.snapshot.rules { print("rule", rule.id, rule.affects, rule.isOrphaned ? "ORPHANED" : "live", "|", rule.summary) }
    exit(0)
}

// `--stack <root>` prints what the stack scan finds, read-only.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--stack" {
    let root = CommandLine.arguments[2]
    var projects: [String] = []
    for owner in (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? [] where !owner.hasPrefix(".") {
        for name in (try? FileManager.default.contentsOfDirectory(atPath: (root as NSString).appendingPathComponent(owner))) ?? [] where !name.hasPrefix(".") {
            projects.append("\(owner)/\(name)")
        }
    }
    let started = Date()
    let result = StackScan.scan(root: root, projects: projects)
    print("scanned \(result.projectsScanned) projects in \(Int(Date().timeIntervalSince(started) * 1000)) ms")
    for question in PlaybookQuestions.stack {
        let found = (result.stack[question.id] ?? [:]).map { "\($0.key) \($0.value.count)" }.sorted()
        print(question.title + ": " + found.joined(separator: ", "))
    }
    print("Libraries: " + result.libraries.map { "\($0.key) \($0.value.count)" }.sorted().joined(separator: ", "))
    print("Other packages: " + result.otherPackages.filter { $0.value.count > 1 }.map { "\($0.key) \($0.value.count)" }.sorted().joined(separator: ", "))
    exit(0)
}

// `--scene <graphify-out>` prints each drill-down level of the largest branch, for renderer tests.
if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--scene" {
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: cache) }
    let workspace = try openRealWorkspace(CommandLine.arguments[2], cache: cache)
    let directory = URL(fileURLWithPath: CommandLine.arguments[3])
    var level: SceneLevel? = try workspace.rootLevel()
    var depth = 0
    while let current = level {
        let started = Date()
        let scene = try workspace.scene(at: current, showHidden: false)
        print("level \(depth): \(scene.nodes.count) nodes, \(scene.edges.count) edges, \(scene.groups.count) groups, omitted \(scene.omittedNodes), \(Int(Date().timeIntervalSince(started) * 1000)) ms")
        try JSONEncoder().encode(scene).write(to: directory.appendingPathComponent("scene\(depth).json"))
        try JSONEncoder().encode(workspace.ringScene(at: current, showHidden: false)).write(to: directory.appendingPathComponent("rings\(depth).json"))
        // Go into the largest node that has anything below it.
        level = scene.nodes.first.flatMap { workspace.childLevel(of: current, nodeID: $0.id) }
        depth += 1
    }
    exit(0)
}

// `--guide <graphify-out>` prints the agent guide for a real graph.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--guide" {
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: cache) }
    let workspace = try openRealWorkspace(CommandLine.arguments[2], cache: cache)
    let snapshot = try workspace.snapshot()
    print(try workspace.agentGuideText(findings: snapshot.findings, overview: snapshot.overview, clean: snapshot.clean))
    exit(0)
}

// `--apply-playbook <from-folder> <graphify-out>` saves a playbook into a graph, writes its copy
// for graphify where the app would, and rewrites the guide, the same way the app does on save.
if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--apply-playbook" {
    let playbook = PlaybookFile.load(from: URL(fileURLWithPath: CommandLine.arguments[2]))
    guard !playbook.isEmpty else { print("no playbook in \(CommandLine.arguments[2])"); exit(2) }
    let target = URL(fileURLWithPath: CommandLine.arguments[3])
    try PlaybookFile.save(playbook, to: target)
    let root = GraphSource(outDirectory: target).rootPath
    if PlaybookFile.addsToGraphByDefault(root: root), try PlaybookFile.writeGraphCopy(playbook, root: root) {
        print("wrote \(PlaybookFile.graphCopyURL(root: root).path)")
    }
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: cache) }
    let workspace = try openRealWorkspace(CommandLine.arguments[3], cache: cache)
    let snapshot = try workspace.snapshot()
    try workspace.writeAgentGuide(try workspace.agentGuideText(findings: snapshot.findings, overview: snapshot.overview, clean: snapshot.clean))
    print("saved \(playbook.libraries.count) libraries and rewrote \(AgentGuide.fileName)")
    exit(0)
}

// `--chat-claude <graphify-out> <message>` and `--chat-openai <url> <model> <graphify-out> <message>`
// send one chat message about a real playbook and print the reply. Nothing is saved.
if CommandLine.arguments.count >= 4, ["--chat-claude", "--chat-openai"].contains(CommandLine.arguments[1]) {
    let arguments = CommandLine.arguments
    let engine: ChatEngine
    let outDirectory: String
    let message: String
    if arguments[1] == "--chat-claude" {
        guard let claude = ToolLocator.command(["claude"], home: FileManager.default.homeDirectoryForCurrentUser.path) else { print("no claude command"); exit(2) }
        engine = ChatEngine(id: "claude-code", name: "Claude Code", backend: .claudeCode(command: claude), searchesWeb: true, billing: .plan)
        outDirectory = arguments[2]
        message = arguments[3]
    } else {
        guard arguments.count == 6 else { print("usage: --chat-openai <url> <model> <graphify-out> <message>"); exit(2) }
        engine = ChatEngine(id: "openai-compatible", name: "Test server", backend: .openAI(url: arguments[2], headers: [:], model: arguments[3]), searchesWeb: false, billing: .thisMac)
        outDirectory = arguments[4]
        message = arguments[5]
    }
    let playbook = PlaybookFile.load(from: URL(fileURLWithPath: outDirectory))
    let root = GraphSource(outDirectory: URL(fileURLWithPath: outDirectory)).rootPath
    let started = Date()
    let reply = try await PlaybookChat.send([ChatTurn(role: .user, text: message)], playbook: playbook, scan: StackScan.scan(root: root, projects: []), engine: engine)
    print("--- reply (\(Int(Date().timeIntervalSince(started))) s) ---")
    print(reply.text)
    print("--- changes ---")
    for change in reply.changes {
        print("\(PlaybookChat.label(change, in: playbook)) | \(change.reason)")
    }
    exit(0)
}

// `--folders <graphify-out>` prints the suggested folder labels and tidy-up tips, read-only.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--folders" {
    let source = GraphSource(outDirectory: URL(fileURLWithPath: CommandLine.arguments[2]))
    let started = Date()
    let scan = FolderScan.scan(root: source.rootPath)
    let labels = FolderScan.labels(saved: FolderFile.load(from: source.outDirectory), scan: scan)
    print("scanned in \(String(format: "%.1f", Date().timeIntervalSince(started)))s; groups now: \(source.scheme.groups.sorted())")
    for label in labels {
        let info = scan.folders.first { $0.path == label.path }
        print("- \(label.path)/ \(label.purpose.title)\(label.holdsProjects ? " (group of \(info?.children.count ?? 0))" : "")\(label.isIncluded ? "" : " LEFT OUT")")
    }
    let ignore = IgnoreFile.patterns(in: (try? String(contentsOfFile: (source.rootPath as NSString).appendingPathComponent(".graphifyignore"), encoding: .utf8)) ?? "")
    print("tips:")
    for tip in TidyTips.tips(scan: scan, labels: labels, ignored: ignore, root: source.rootPath) {
        print("- \(tip.title) | \(tip.detail)")
    }
    exit(0)
}

// `--restore-trial <graphify-out> <scratch folder>` backs each graph up to a this-Mac repo inside the
// scratch folder, restores them all into one graph there, and checks it with graphify. It writes
// nothing outside the scratch folder.
if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--restore-trial" {
    let out = URL(fileURLWithPath: CommandLine.arguments[2])
    let scratch = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
    let started = Date()
    let whole = try GraphPartition.read(out.appendingPathComponent("graph.json"))
    var arrangement = BackupJob.arrangement(outDirectory: out, graph: whole)
    for graph in arrangement.graphs { arrangement.setBackup(BackupPlan(destination: .local), forGraph: graph.id) }
    let store = scratch.appendingPathComponent("store", isDirectory: true)
    var summaries: [GraphPartition.Summary] = []
    for graph in arrangement.graphs {
        let bundle = try BackupContents.build(graphID: graph.id, arrangement: arrangement, outDirectory: out, graph: whole)
        let outcome = try BackupRunner.run(bundle: bundle, graph: graph, identity: GitIdentity(name: "Trial", email: "trial@localhost"), message: "Trial", store: store, ranFrom: "trial")
        summaries.append(bundle.summary)
        print("\(graph.name): \(bundle.summary.nodes) nodes, \(bundle.summary.edges) edges backed up; \(outcome.message) (\(Int(Date().timeIntervalSince(started))) s)")
    }
    var folders: [URL] = []
    for (offset, source) in BackupRestore.sources(plans: arrangement.graphs, store: store).enumerated() {
        let folder = scratch.appendingPathComponent("fetched-\(offset)", isDirectory: true)
        try BackupRestore.fetch(source, into: folder)
        folders.append(folder)
    }
    let destination = scratch.appendingPathComponent("restored/graphify-out", isDirectory: true)
    let restored = try BackupRestore.combine(folders, into: destination, root: GraphSource(outDirectory: out).rootPath)
    print("restored \(restored.nodes) nodes and \(restored.edges) edges from \(restored.backups) backup(s) (\(Int(Date().timeIntervalSince(started))) s)")
    if summaries.count == 1 {
        let same = try GraphPartition.summary(of: GraphPartition.read(destination.appendingPathComponent("graph.json"))) == summaries[0]
        print(same ? "matches the backup exactly" : "DOES NOT match the backup")
    }
    for note in restored.notes { print("note: \(note)") }
    print(BackupRestore.checkWithGraphify(destination, graphify: GraphRebuilder.locateGraphify()) ?? "graphify reads it (\(Int(Date().timeIntervalSince(started))) s)")
    exit(0)
}

// `--backup-plan <graphify-out> [split]` prints what each graph's backup would hold, read-only:
// files, sizes, the largest file, the git rules and the login each graph would push as. With
// `split`, it first splits the arrangement by account, as "Split by Account" would.
// What the move sheet would say for a real folder. Reads only: git, lsof and files.
// Usage: GraphitreeChecks --move-check <graphify-out> <item> <new parent, or "" for the top> [new name]
if CommandLine.arguments.count >= 5, CommandLine.arguments[1] == "--move-check" {
    let out = URL(fileURLWithPath: CommandLine.arguments[2])
    let source = GraphSource(outDirectory: out)
    let started = Date()
    let request = MoveRequest(item: CommandLine.arguments[3], newParent: CommandLine.arguments[4], newName: CommandLine.arguments.count >= 6 ? CommandLine.arguments[5] : nil)
    let arrangement = BackupJob.arrangement(outDirectory: out, graph: nil)
    let accounts = BackupJob.accounts(for: arrangement, root: source.rootPath, confirmed: BackupJob.confirmedLogins())
    let found = FolderMoves.check(request, root: source.rootPath, outDirectory: out, arrangement: arrangement, rules: accounts.rules, accounts: accounts, busy: nil, playbook: PlaybookFile.load(from: out))
    print("\(request.item) → \(request.target)\(found.canMove ? "" : " (can't move)")")
    for line in found.blockers { print("  stop: \(line)") }
    for line in found.updates { print("  updates: \(line)") }
    for line in found.rules { print("  git: \(line)") }
    if let choice = found.remoteChoice { print("  remote: could point at \(choice.suggested)") }
    print("  docs to read again: \(found.docs.files.count), about \(found.docs.contentTokens) tokens of content")
    for line in found.yours { print("  yours: \(line)") }
    print("took \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
    exit(0)
}

// Graph cuts from a real graph, written into a scratch copy's graphify-out.
// Usage: GraphitreeChecks --cuts-trial <graphify-out with graphs.json> <scratch graphify-out>
if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--cuts-trial" {
    let out = URL(fileURLWithPath: CommandLine.arguments[2])
    let scratch = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
    let started = Date()
    let whole = try GraphPartition.read(out.appendingPathComponent("graph.json"))
    let arrangement = BackupJob.arrangement(outDirectory: out, graph: whole)
    print("read and arranged in \(String(format: "%.1f", Date().timeIntervalSince(started)))s: \(arrangement.graphs.count) graphs")
    let entries = try GraphCuts.write(whole, arrangement: arrangement, outDirectory: scratch)
    for entry in entries {
        let size = (try? FileManager.default.attributesOfItem(atPath: GraphCuts.url(of: entry, outDirectory: scratch).path)[.size] as? Int) ?? 0
        print("\(entry.name): \(entry.nodes) nodes, \(entry.projects.count) projects, \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)) at \(entry.file)")
    }
    let total = (whole["nodes"] as? [Any])?.count ?? 0
    print("whole graph: \(total) nodes; cuts hold \(entries.reduce(0) { $0 + $1.nodes }) (library nodes can be in more than one)")
    print("took \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
    exit(0)
}

if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--backup-plan" {
    let out = URL(fileURLWithPath: CommandLine.arguments[2])
    let source = GraphSource(outDirectory: out)
    let started = Date()
    let whole = try GraphPartition.read(source.graphURL)
    var arrangement = BackupJob.arrangement(outDirectory: out, graph: whole)
    let accounts = BackupJob.accounts(for: arrangement, root: source.rootPath, confirmed: BackupJob.confirmedLogins())
    let rules = accounts.rules
    let logins = accounts.logins
    print("git rules: global \(rules.global?.display ?? "none")")
    for rule in rules.rules { print("  \(rule.folder) → \(rule.identity?.display ?? "?") via \(rule.configFile)") }
    print("logins: \(logins.joined(separator: ", ")); guessed: \(accounts.loginByFolder.map { "\($0.key.isEmpty ? "everything else" : $0.key) → \($0.value)" }.sorted().joined(separator: "; "))")
    print("left out: \(arrangement.leftOut.map { "\($0.path) (\(arrangement.leftOutReason($0.path) ?? ""))" }.joined(separator: ", "))")
    if CommandLine.arguments.count >= 4, CommandLine.arguments[3] == "split", let first = arrangement.graphs.first {
        arrangement.splitByAccount(first.id) { accounts.login(for: (source.rootPath as NSString).appendingPathComponent($0)) }
    }
    for graph in arrangement.graphs {
        var plan = graph
        if plan.backup.login == nil { plan.backup.login = BackupWarnings.suggestedLogin(graph: graph, arrangement: arrangement, accounts: accounts, root: source.rootPath) }
        print("\n\(graph.name)\(graph.isHome ? " (home)" : ""): \(arrangement.projects(inGraph: graph.id).count) projects, \(arrangement.nodes(inGraph: graph.id).formatted()) nodes → \(plan.backup.login ?? "?"), signs as \(plan.backup.login.flatMap(accounts.identity(forLogin:))?.display ?? "?")")
        print("  areas: \(graph.areaIDs.compactMap { arrangement.area($0)?.name }.joined(separator: ", "))")
        let bundle = try BackupContents.build(graphID: graph.id, arrangement: arrangement, outDirectory: out, graph: whole)
        for item in bundle.items {
            print("  \(item.isSaved ? "save" : "stay") \(item.title): \(ByteCountFormatter.string(fromByteCount: Int64(item.bytes), countStyle: .file)), \(item.files) file\(item.files == 1 ? "" : "s") · \(item.detail)")
        }
        if let largest = bundle.largest { print("  largest: \(largest.path) \(ByteCountFormatter.string(fromByteCount: Int64(largest.bytes), countStyle: .file)); total \(ByteCountFormatter.string(fromByteCount: Int64(bundle.savedBytes), countStyle: .file)) in \(bundle.files.count) files; graph \(bundle.summary.nodes) nodes, \(bundle.summary.edges) edges") }
        for warning in BackupWarnings.warnings(graph: plan, arrangement: arrangement, accounts: accounts, root: source.rootPath, largestBytes: bundle.largest?.bytes, repoHasOtherHistory: nil, dismissed: []) {
            print("  ! \(warning.title). \(warning.detail)")
        }
    }
    print("\ntook \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
    exit(0)
}

// `--sessions <graphify-out> [days]` prints what the last days of Claude Code sessions show,
// read-only: counts, graph questions and packages, never the person's messages.
if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--sessions" {
    let source = GraphSource(outDirectory: URL(fileURLWithPath: CommandLine.arguments[2]))
    let days = CommandLine.arguments.count > 3 ? Double(CommandLine.arguments[3]) ?? 30 : 30
    let started = Date()
    let scan = SessionReader.scan(since: Date().addingTimeInterval(-days * 24 * 3600))
    print("read \(scan.files) session files in \(String(format: "%.1f", Date().timeIntervalSince(started)))s: \(scan.messages.count) typed messages, \(scan.questions.count) graph questions, \(scan.installs.count) installs")
    let insights = UsageInsights.build(events: UsageLog.load(since: Date().addingTimeInterval(-days * 24 * 3600)), sessions: scan, playbook: PlaybookFile.load(from: source.outDirectory), root: source.rootPath, scheme: source.scheme)
    print("questions \(insights.questions), picks asked \(insights.picksAsked)")
    print("empty:", insights.emptyQuestions.prefix(5))
    print("projects:", insights.projects.map { "\($0.name) \($0.count)" })
    print("unlisted packages:", insights.unlistedPackages.map { "\($0.name) \($0.count)" })
    print("digest characters:", SessionDigest.make(scan, root: source.rootPath, scheme: source.scheme).count)
    exit(0)
}

// `--review <graphify-out> <dir>` writes the review scene of each detector's biggest finding.
if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--review" {
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: cache) }
    let workspace = try openRealWorkspace(CommandLine.arguments[2], cache: cache)
    let directory = URL(fileURLWithPath: CommandLine.arguments[3])
    let findings = try workspace.snapshot().findings
    for detector in Detector.allCases {
        guard let finding = ReviewQueue.ordered(findings[detector] ?? []).first else { continue }
        let scene = try workspace.reviewScene(for: finding)
        print("\(detector.rawValue): \(finding.title), \(scene.nodes.count) nodes, omitted \(scene.omittedNodes)")
        try JSONEncoder().encode(scene).write(to: directory.appendingPathComponent("review-\(detector.rawValue).json"))
    }
    exit(0)
}

if CommandLine.arguments.count == 3, ["--findings", "--apply"].contains(CommandLine.arguments[1]) {
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: cache) }
    let workspace = try openRealWorkspace(CommandLine.arguments[2], cache: cache)
    if CommandLine.arguments[1] == "--findings" {
        let snapshot = try workspace.snapshot()
        var counts = Dictionary(uniqueKeysWithValues: Detector.allCases.map { ($0.rawValue, snapshot.count($0)) })
        counts["activeRules"] = snapshot.rules.count
        counts["visibleNodes"] = snapshot.overview.visibleNodes
        counts["visibleEdges"] = snapshot.overview.visibleEdges
        counts["suspectCrossEdges"] = snapshot.overview.suspectCrossEdges
        try printJSON(counts)
    } else {
        let started = Date()
        let result = try workspace.writeCleanGraph()
        FileHandle.standardError.write(Data("wrote in \(String(format: "%.1f", Date().timeIntervalSince(started)))s\n".utf8))
        try printJSON(["nodes": result.nodes, "edges": result.edges, "hyperedges": result.hyperedges])
    }
    exit(0)
}

if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--real" {
    let source = GraphSource(outDirectory: URL(fileURLWithPath: CommandLine.arguments[2]))
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: cache) }
    let started = Date()
    let overview = try onBackgroundQueue {
        try GraphIndex.open(source: source, cacheDirectory: cache).overview()
    }
    FileHandle.standardError.write(Data("indexed in \(String(format: "%.1f", Date().timeIntervalSince(started)))s\n".utf8))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    print(String(decoding: try encoder.encode(overview), as: UTF8.self))
    exit(0)
}

var failures = 0

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        print("ok    \(name)")
    } else {
        failures += 1
        print("FAIL  \(name)")
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) {
    check(actual == expected, "\(name): got \(actual), expected \(expected)")
}

/// Every defaults suite the checks make. They're removed at the end, so they don't pile up in
/// ~/Library/Preferences.
var checkSuites: [String] = []

func checkSuiteName(_ kind: String) -> String {
    let name = "graphitree-\(kind)-\(UUID().uuidString)"
    checkSuites.append(name)
    return name
}

func checkSuite(_ kind: String) -> UserDefaults {
    UserDefaults(suiteName: checkSuiteName(kind))!
}

/// Emptying a domain still leaves an empty plist, which cfprefsd writes a few seconds later. A file
/// removed before that write comes back, so this waits for it, then removes the files. Returns any
/// suite whose file is still there.
func removeCheckSuites() -> [String] {
    let preferences = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences")
    func file(_ name: String) -> String { preferences.appendingPathComponent(name + ".plist").path }
    func isEmptied(_ name: String) -> Bool {
        guard let data = FileManager.default.contents(atPath: file(name)) else { return true }
        return ((try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any])?.isEmpty == true
    }
    for name in checkSuites { UserDefaults.standard.removePersistentDomain(forName: name) }
    let deadline = Date.now.addingTimeInterval(20)
    while !checkSuites.allSatisfy(isEmptied), Date.now < deadline { Thread.sleep(forTimeInterval: 0.2) }
    for name in checkSuites { try? FileManager.default.removeItem(atPath: file(name)) }
    return checkSuites.filter { FileManager.default.fileExists(atPath: file($0)) }
}

// MARK: - Path rules

expectEqual(SourcePath.project(of: "work/foo/src/a.ts"), "work/foo", "work project")
expectEqual(SourcePath.project(of: "personal/bar/a.ts"), "personal/bar", "personal project")
expectEqual(SourcePath.project(of: "demo-app/a.md"), "demo-app", "top-level project")
expectEqual(SourcePath.project(of: ""), SourcePath.noProject, "empty path has no project")

expectEqual(SourcePath.noiseKind(of: "work/a/src/generated/prisma/User.ts"), .generated, "prisma output")
expectEqual(SourcePath.noiseKind(of: "work/a/src/routeTree.gen.ts"), .generated, "gen file")
expectEqual(SourcePath.noiseKind(of: "work/a/types/x.d.ts"), .generated, "declaration file")
expectEqual(SourcePath.noiseKind(of: "personal/o/static/lib/docx.js"), .vendored, "static lib")
expectEqual(SourcePath.noiseKind(of: "personal/o/js/a.min.js"), .vendored, "minified js")
expectEqual(SourcePath.noiseKind(of: "work/a/src/components/ui/button.tsx"), nil, "components/ui is kept")
expectEqual(SourcePath.noiseKind(of: "work/a/src/generated.ts"), nil, "file merely named generated")

// MARK: - Fixture import

let fileManager = FileManager.default
let sandbox = fileManager.temporaryDirectory.appendingPathComponent("gstudio-\(UUID().uuidString)")
let root = sandbox.appendingPathComponent("repos")
let out = root.appendingPathComponent("graphify-out")
let cache = sandbox.appendingPathComponent("cache")
try fileManager.createDirectory(at: out, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: sandbox) }

func writeSource(_ relative: String) throws {
    let url = root.appendingPathComponent(relative)
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: url)
}

for path in ["work/one/src/a.ts", "personal/two/src/b.ts", "work/one/src/generated/prisma/User.ts", "personal/two/static/lib/lib.min.js"] {
    try writeSource(path)
}

func node(_ id: String, _ key: String, _ path: String, community: Int) -> String {
    #"{"id":"\#(id)","label":"\#(id)","norm_label":"\#(key)","file_type":"code","source_file":"\#(path)","source_location":null,"community":\#(community),"metadata":{"x":1}}"#
}

let nodes = [
    node("a", "a", "work/one/src/a.ts", community: 0),
    node("b", "json", "personal/two/src/b.ts", community: 1),
    node("c", "user", "work/one/src/generated/prisma/User.ts", community: 0),
    node("d", "lib", "personal/two/static/lib/lib.min.js", community: 1),
    node("e", "json", "Legacy/gone.ts", community: 2),
    node("f", "f", "", community: 3),
].joined(separator: ",")

let links = """
{"source":"a","target":"b","relation":"references","confidence":"EXTRACTED","weight":1.0},
{"source":"a","target":"c","relation":"imports","confidence":"EXTRACTED","weight":1.0},
{"source":"b","target":"d","relation":"calls","confidence":"INFERRED","weight":0.5}
"""

let graphURL = out.appendingPathComponent("graph.json")
try #"{"directed":false,"nodes":[\#(nodes)],"links":[\#(links)]}"#.write(to: graphURL, atomically: true, encoding: .utf8)
let source = GraphSource(outDirectory: out)

let first = try onBackgroundQueue { try GraphIndex.open(source: source, cacheDirectory: cache) }
let overview = try first.overview()
check(first.didImport, "first open imports")
expectEqual(overview.nodes, 6, "nodes")
expectEqual(overview.edges, 3, "edges")
expectEqual(overview.communities, 4, "communities")
expectEqual(overview.sourceFiles, 5, "source files")
expectEqual(overview.generatedOrVendoredNodes, 2, "generated or vendored")
expectEqual(overview.crossProjectEdges, 1, "cross-project edges")
expectEqual(overview.missingFiles, 1, "missing files")
expectEqual(overview.staleNodes, 1, "stale nodes")
expectEqual(overview.noiseNodes, 3, "noise counts each node once")
expectEqual(overview.repeatedLabels, 1, "repeated labels")
expectEqual(overview.isolatedNodes, 2, "isolated nodes")
expectEqual(overview.nodesWithoutSource, 1, "nodes without source")

// MARK: - Cache behaviour

let second = try onBackgroundQueue { try GraphIndex.open(source: source, cacheDirectory: cache) }
check(!second.didImport, "unchanged graph reuses the index")

try fileManager.removeItem(at: root.appendingPathComponent("work/one/src/a.ts"))
let afterDelete = try onBackgroundQueue { try GraphIndex.open(source: source, cacheDirectory: cache) }
check(!afterDelete.didImport, "deleting a source file does not reimport")
expectEqual(try afterDelete.overview().missingFiles, 2, "deleted source file is noticed")

try #"{"nodes":[\#(node("z", "z", "work/one/z.ts", community: 0))],"edges":[]}"#.write(to: graphURL, atomically: true, encoding: .utf8)
let changed = try onBackgroundQueue { try GraphIndex.open(source: source, cacheDirectory: cache) }
check(changed.didImport, "changed graph reimports")
expectEqual(try changed.overview().nodes, 1, "reimport replaces old data")

// MARK: - Failure handling

try "{ not json".write(to: graphURL, atomically: true, encoding: .utf8)
do {
    _ = try onBackgroundQueue { try GraphIndex.open(source: source, cacheDirectory: cache) }
    check(false, "corrupt graph throws")
} catch {
    check(true, "corrupt graph throws")
}
let leftovers = try fileManager.contentsOfDirectory(atPath: cache.path).filter { $0.hasSuffix(".tmp") }
expectEqual(leftovers.count, 0, "failed import leaves no temp file")

try fileManager.removeItem(at: graphURL)
do {
    _ = try onBackgroundQueue { try GraphIndex.open(source: source, cacheDirectory: cache) }
    check(false, "missing graph throws")
} catch let error as GraphIndexError {
    expectEqual(error, .graphNotFound(out.path), "missing graph has a clear error")
}

// MARK: - Globs

check(PathGlob("**/generated/**").matches("work/a/src/generated/prisma/User.ts"), "glob: double star on both sides")
check(PathGlob("work/a/src/generated/**").matches("work/a/src/generated/x.ts"), "glob: anchored folder")
check(!PathGlob("work/a/src/generated/**").matches("work/ab/src/generated/x.ts"), "glob: anchored folder doesn't match a sibling")
check(PathGlob("*.min.js").matches("a/b/lib.min.js"), "glob: bare name matches at any depth")
check(!PathGlob("a/*.ts").matches("a/b/c.ts"), "glob: single star stays in one segment")
check(PathGlob("app/[id]/page.tsx").matches("app/[id]/page.tsx"), "glob: brackets are literal")
check(!PathGlob("app/[id]/page.tsx").matches("app/i/page.tsx"), "glob: brackets aren't a character class")
check(PathGlob("app/[id]/page.tsx").isExactPath, "glob: path without stars is exact")
expectEqual(SourcePath.ignoreLine(for: "work/a/src/generated/"), "/work/a/src/generated/", "ignore line is anchored")
expectEqual(SourcePath.ignoreLine(for: "app/[id]/x.gen.ts"), "/app/[[]id]/x.gen.ts", "ignore line escapes brackets")
expectEqual(SourcePath.noiseGroup(of: "work/a/src/generated/prisma/User.ts"), "work/a/src/generated/", "noise group is the folder")
expectEqual(SourcePath.noiseGroup(of: "work/a/src/routeTree.gen.ts"), "work/a/src/routeTree.gen.ts", "one-off noise groups by file")
check(SourcePath.isConfigKey(labelKey: "scripts", path: "a/package.json"), "config key inside package.json")
check(!SourcePath.isConfigKey(labelKey: "package.json", path: "a/package.json"), "the file's own node isn't a config key")
check(!SourcePath.isConfigKey(labelKey: "main()", path: "a/main.ts"), "code isn't a config key")

// MARK: - Curation

let curationSandbox = fileManager.temporaryDirectory.appendingPathComponent("gstudio-\(UUID().uuidString)")
let curationRoot = curationSandbox.appendingPathComponent("repos")
let curationOut = curationRoot.appendingPathComponent("graphify-out")
let curationCache = curationSandbox.appendingPathComponent("cache")
try fileManager.createDirectory(at: curationOut.appendingPathComponent(".git"), withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: curationSandbox) }

func writeCurationSource(_ relative: String) throws {
    let url = curationRoot.appendingPathComponent(relative)
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: url)
}

func curationNode(_ id: String, _ key: String, _ path: String, type: String = "code") -> String {
    #"{"id":"\#(id)","label":"\#(id)","norm_label":"\#(key)","file_type":"\#(type)","source_file":"\#(path)","source_location":"L1","community":0,"rationale":"keep me"}"#
}

func curationEdge(_ source: String, _ target: String, _ relation: String) -> String {
    #"{"source":"\#(source)","target":"\#(target)","relation":"\#(relation)","confidence":"EXTRACTED","weight":1.0,"confidence_score":1.0}"#
}

let curationPaths = [
    "work/one/src/a.ts", "work/one/src/b.ts", "personal/two/src/json.ts", "personal/two/src/other.ts",
    "work/one/src/generated/User.ts", "work/one/package.json", "personal/two/package.json",
]
for path in curationPaths { try writeCurationSource(path) }

let curationNodes = [
    curationNode("a", "a", "work/one/src/a.ts"),
    curationNode("b", "b", "work/one/src/b.ts"),
    curationNode("c", "c", "work/one/src/b.ts"),
    curationNode("json", "json", "personal/two/src/json.ts"),
    curationNode("other", "other", "personal/two/src/other.ts"),
    curationNode("user", "user", "work/one/src/generated/User.ts"),
    curationNode("gone", "gone", "work/one/src/deleted.ts"),
    curationNode("pkg1", "package.json", "work/one/package.json"),
    curationNode("scripts1", "scripts", "work/one/package.json"),
    curationNode("pkg2", "package.json", "personal/two/package.json"),
    curationNode("scripts2", "scripts", "personal/two/package.json"),
    curationNode("doc1", "doc1", "work/one/src/a.ts", type: "document"),
    curationNode("doc2", "doc2", "personal/two/src/json.ts", type: "document"),
    curationNode("loner", "loner", "work/one/src/b.ts"),
    curationNode("datetime", "datetime", ""),
].joined(separator: ",")

let curationEdges = [
    curationEdge("a", "json", "references"),
    curationEdge("b", "json", "references"),
    curationEdge("c", "json", "references"),
    curationEdge("other", "json", "calls"),
    curationEdge("doc1", "doc2", "semantically_similar_to"),
    curationEdge("a", "b", "calls"),
    curationEdge("a", "user", "imports"),
    curationEdge("gone", "a", "calls"),
    curationEdge("pkg1", "scripts1", "contains"),
    curationEdge("pkg2", "scripts2", "contains"),
    curationEdge("a", "datetime", "references"),
].joined(separator: ",")

let curationHyper = #"[{"id":"h1","label":"H1","nodes":["a","b","user"]},{"id":"h2","label":"H2","nodes":["user","gone"]}]"#
let curationGraph = #"{"directed":false,"graph":{"hyperedges":\#(curationHyper)},"nodes":[\#(curationNodes)],"links":[\#(curationEdges)],"hyperedges":\#(curationHyper)}"#
let curationGraphURL = curationOut.appendingPathComponent("graph.json")
try curationGraph.write(to: curationGraphURL, atomically: true, encoding: .utf8)

func openCuration() throws -> Workspace {
    let source = GraphSource(outDirectory: curationOut)
    return try onBackgroundQueue { try Workspace(source: source, cacheDirectory: curationCache) }
}

func decodeClean() throws -> [String: Any] {
    let data = try Data(contentsOf: curationOut.appendingPathComponent("graph.clean.json"))
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
}

func ids(_ graph: [String: Any]) -> Set<String> {
    Set((graph["nodes"] as! [[String: Any]]).map { $0["id"] as! String })
}

func linkCount(_ graph: [String: Any]) -> Int {
    (graph["links"] as! [[String: Any]]).count
}

let workspace = try openCuration()
var snapshot = try workspace.snapshot()
expectEqual(snapshot.clean, .notWritten, "no clean graph at first")
check(!snapshot.canUndo, "nothing to undo at first")

expectEqual(snapshot.count(.generated), 1, "one generated group")
expectEqual(snapshot.findings[.generated]?.first?.location, "work/one/src/generated/", "generated group location")
expectEqual(snapshot.overview.crossProjectEdges, 4, "all cross-project edges counted")
expectEqual(snapshot.overview.suspectCrossEdges, 3, "semantic link isn't suspect")
expectEqual(snapshot.count(.configLabels), 1, "only the config key is listed, not the file node")
expectEqual(snapshot.findings[.configLabels]?.first?.title, "scripts1", "config key finding")
expectEqual(snapshot.count(.missing), 1, "missing file listed")
expectEqual(snapshot.count(.noSource), 1, "no-source node listed")
expectEqual(snapshot.findings[.noSource]?.first?.count, 1, "no-source shows its links")
expectEqual(snapshot.count(.isolated), 1, "isolated node listed")

let hub = snapshot.findings[.crossProject]?.max { $0.count < $1.count }
expectEqual(hub?.anchor, "json", "busiest endpoint is the hub")
expectEqual(hub?.count, 3, "hub counts every suspect link touching it")
expectEqual(snapshot.count(.crossProject), 1, "each hub is one row")

let hubLinks = try workspace.details(for: hub!)
expectEqual(hubLinks.count, 3, "hub details list its links")
check(hubLinks.allSatisfy { $0.rejection != nil }, "hub links can be rejected one at a time")

// Rejecting a hub leaves the semantic link and the same-project call.
snapshot = try workspace.perform([hub!.removal])
expectEqual(snapshot.overview.suspectCrossEdges, 0, "hub rejection clears suspect links")
expectEqual(snapshot.overview.crossProjectEdges, 1, "semantic cross-project link survives")
expectEqual(snapshot.count(.crossProject), 0, "rejected hub leaves the queue")
expectEqual(snapshot.overview.removedEdges, 3, "only suspect links removed")
expectEqual(snapshot.rules.first?.affects, "3 links", "rule reports its effect")
check(snapshot.canUndo, "can undo after a decision")

// Hide a generated folder through the path rule.
let generatedFinding = snapshot.findings[.generated]![0]
snapshot = try workspace.perform([generatedFinding.removal])
expectEqual(snapshot.overview.hiddenNodes, 1, "generated node hidden")
expectEqual(snapshot.overview.generatedOrVendoredNodes, 0, "hidden noise stops counting")
expectEqual(snapshot.count(.generated), 0, "hidden group leaves the queue")

// Keep is remembered across a reopen.
let keepFinding = snapshot.findings[.missing]![0]
snapshot = try workspace.perform([.keep(findingID: keepFinding.id, note: keepFinding.title)])
expectEqual(snapshot.count(.missing), 0, "kept finding leaves the queue")
expectEqual(snapshot.overview.missingFiles, 1, "keeping doesn't hide the node")

let reopened = try openCuration()
var reopenedSnapshot = try reopened.snapshot()
expectEqual(reopenedSnapshot.count(.missing), 0, "keep survives reopening")
expectEqual(reopenedSnapshot.overview.hiddenNodes, 1, "hide survives reopening")
expectEqual(reopenedSnapshot.rules.count, 3, "rules survive reopening")

// Clean output.
let graphBefore = try Data(contentsOf: curationGraphURL)
var result = try reopened.writeCleanGraph()
expectEqual(try Data(contentsOf: curationGraphURL), graphBefore, "graph.json is untouched")
var clean = try decodeClean()
expectEqual(ids(clean).contains("user"), false, "hidden node left out")
expectEqual(ids(clean).count, 14, "other nodes kept")
expectEqual(linkCount(clean), 7, "rejected links and links to hidden nodes left out")
expectEqual(result.nodes, reopenedSnapshot.overview.visibleNodes, "written nodes match the preview")
expectEqual(result.edges, reopenedSnapshot.overview.visibleEdges, "written edges match the preview")
let keptA = (clean["nodes"] as! [[String: Any]]).first { $0["id"] as? String == "a" }
expectEqual(keptA?["rationale"] as? String, "keep me", "unknown node fields are preserved")
let hyper = clean["hyperedges"] as! [[String: Any]]
expectEqual(hyper.count, 1, "group with one member left is dropped")
expectEqual(hyper.first?["nodes"] as? [String], ["a", "b"], "hidden members removed from group")
let nestedHyper = (clean["graph"] as! [String: Any])["hyperedges"] as! [[String: Any]]
expectEqual(nestedHyper.count, 1, "nested hyperedges are trimmed too")
let gitignore = try String(contentsOf: curationOut.appendingPathComponent(".gitignore"), encoding: .utf8)
check(gitignore.contains("graph.clean.json"), "clean graph kept out of git")
reopenedSnapshot = try reopened.snapshot()
if case .upToDate = reopenedSnapshot.clean { check(true, "clean graph is current") } else { check(false, "clean graph is current") }

// Undo restores nodes and links.
reopenedSnapshot = try reopened.undoLastBatch()
expectEqual(reopenedSnapshot.rules.count, 2, "undo removes the last batch")
if case .outOfDate = reopenedSnapshot.clean { check(true, "clean graph goes stale after a change") } else { check(false, "clean graph goes stale after a change") }
reopenedSnapshot = try reopened.undoLastBatch()
reopenedSnapshot = try reopened.undoLastBatch()
expectEqual(reopenedSnapshot.rules.count, 0, "everything undone")
expectEqual(reopenedSnapshot.overview.hiddenNodes, 0, "undo restores nodes")
expectEqual(reopenedSnapshot.overview.removedEdges, 0, "undo restores links")
check(!reopenedSnapshot.canUndo, "nothing left to undo")
result = try reopened.writeCleanGraph()
clean = try decodeClean()
expectEqual(ids(clean).count, 15, "clean graph is whole again after undo")
expectEqual(linkCount(clean), 11, "all links back after undo")

// The log only grows.
let logText = try String(contentsOf: curationOut.appendingPathComponent("curation.jsonl"), encoding: .utf8)
expectEqual(logText.split(separator: "\n").count, 6, "undo appends instead of rewriting")

// Damage tolerance.
let logURL = curationOut.appendingPathComponent("curation.jsonl")
try (logText + "{ this is torn").write(to: logURL, atomically: true, encoding: .utf8)
var damaged = try CurationLog(url: logURL)
expectEqual(damaged.unreadableLines, 1, "torn line is reported")
expectEqual(damaged.entries.count, 6, "good lines still load")
try damaged.append(damaged.entries(for: [.hideNode(id: "loner", label: "loner")]))
let reread = try CurationLog(url: logURL)
expectEqual(reread.entries.count, 7, "append after a torn line stays on its own line")
var future = reread.entries[0]
future.op = "merge_nodes"
future.id = "r99"
check(RuleSet(entries: [future]).active.isEmpty, "unknown ops are ignored, not applied")

// Promotion to the ignore file.
let ignoreURL = curationRoot.appendingPathComponent(".graphifyignore")
try "node_modules/".write(to: ignoreURL, atomically: true, encoding: .utf8)
try reopened.addToIgnoreFile(["/work/one/src/generated/"])
try reopened.addToIgnoreFile(["/work/one/src/generated/"])
let ignoreText = try String(contentsOf: ignoreURL, encoding: .utf8)
expectEqual(ignoreText.components(separatedBy: "/work/one/src/generated/").count - 1, 1, "ignore line added once")
check(ignoreText.hasPrefix("node_modules/\n"), "existing ignore lines kept")

// MARK: - Search and outline

let browseWorkspace = try openCuration()
expectEqual(try browseWorkspace.search("datetime").first?.title, "datetime", "search finds a label")
expectEqual(try browseWorkspace.search("jso").first?.title, "json", "search matches part of a label")
let pathHits = try browseWorkspace.search("src/generated")
check(pathHits.contains { $0.title == "user" }, "search finds a path")
let shortHits = try browseWorkspace.search("a")
check(shortHits.contains { $0.title == "a" }, "search handles very short terms")
expectEqual(try browseWorkspace.search("zzzz nothing").count, 0, "unmatched search is empty")
check((try? browseWorkspace.search("quo\"te")) != nil, "quotes in a search don't break it")
let projectsOutline = try browseWorkspace.outlineChildren(of: nil)
check(projectsOutline.contains { $0.title == "work/one" }, "outline starts with projects")
let workOne = projectsOutline.first { $0.title == "work/one" }!
let communityRows = try browseWorkspace.outlineChildren(of: workOne)
expectEqual(communityRows.count, 1, "project expands to communities")
let fileRows = try browseWorkspace.outlineChildren(of: communityRows[0])
check(fileRows.contains { $0.subtitle == "work/one/src/a.ts" }, "community expands to files")
let aFile = fileRows.first { $0.subtitle == "work/one/src/a.ts" }!
let symbolRows = try browseWorkspace.outlineChildren(of: aFile)
check(symbolRows.contains { $0.title == "a" }, "file expands to symbols")
let aDetail = try browseWorkspace.nodeDetail(id: "a")
check(aDetail?.neighbours.contains { $0.nodeID == "json" } == true, "inspector lists neighbours")
expectEqual(aDetail?.absolutePath, curationRoot.appendingPathComponent("work/one/src/a.ts").path, "inspector resolves the file")
expectEqual(try browseWorkspace.nodeDetail(id: "gone")?.absolutePath, nil, "a missing file has no path to open")
expectEqual(EditorLink.line(from: "L153"), 153, "location parses to a line")
expectEqual(EditorLink.line(from: nil), nil, "no location, no line")
expectEqual(EditorLink.vscodeURL(path: "/a/[id]/b c.ts", line: 3)?.absoluteString, "vscode://file/a/%5Bid%5D/b%20c.ts:3", "editor link encodes the path")

// MARK: - Graph scenes

let sceneWorkspace = try openCuration()
expectEqual(try sceneWorkspace.rootLevel(), .projects, "machine-wide graph starts at projects")
let projectScene = try sceneWorkspace.scene(at: .projects, showHidden: false)
expectEqual(Set(projectScene.nodes.map(\.id)), ["work/one", "personal/two"], "scene shows projects, not the no-project bucket")
expectEqual(projectScene.edges.count, 1, "links between two projects merge into one line")
expectEqual(projectScene.groups.first { $0.label == "Personal" }?.slot, 0, "personal projects keep the first colour")
expectEqual(projectScene.groups.first { $0.label == "Work" }?.slot, 1, "work projects keep the second colour")
expectEqual(projectScene.nodes.first { $0.id == "work/one" }?.noise, 1, "projects report their generated nodes")
expectEqual(projectScene.nodes.first { $0.id == "personal/two" }?.noise, nil, "projects without generated nodes report none")
expectEqual(projectScene.edges.first?.weight, 4, "the merged line counts every link between two projects")
expectEqual(projectScene.edges.first?.suspect, 3, "the merged line counts its suspect links, but not semantic ones")
let communityScene = try sceneWorkspace.scene(at: .communities(project: "work/one"), showHidden: false)
expectEqual(communityScene.nodes.count, 1, "project opens to communities")
expectEqual(sceneWorkspace.childLevel(of: .projects, nodeID: "work/one"), .communities(project: "work/one"), "opening a project")
expectEqual(sceneWorkspace.childLevel(of: .communities(project: "work/one"), nodeID: "0"), .files(project: "work/one", community: 0), "opening a community")
expectEqual(sceneWorkspace.childLevel(of: .files(project: "work/one", community: 0), nodeID: "work/one/src/a.ts"), .symbols(project: "work/one", community: 0, path: "work/one/src/a.ts"), "opening a file")
expectEqual(sceneWorkspace.childLevel(of: .symbols(project: "work/one", community: 0, path: nil), nodeID: "a"), nil, "symbols are the bottom")
let fileScene = try sceneWorkspace.scene(at: .files(project: "work/one", community: 0), showHidden: false)
check(fileScene.nodes.contains { $0.id == "work/one/src/a.ts" }, "community opens to files")
let symbolScene = try sceneWorkspace.scene(at: .symbols(project: "work/one", community: 0, path: nil), showHidden: false)
check(symbolScene.nodes.contains { $0.id == "a" }, "file opens to symbols")
expectEqual(symbolScene.nodes.first { $0.id == "a" }?.noise, nil, "ordinary symbols aren't noise")
let generatedSymbol = symbolScene.nodes.first { $0.id == "user" }
expectEqual(generatedSymbol?.noise, generatedSymbol?.value, "a generated symbol is all noise")
let limited = try sceneWorkspace.scene(at: .symbols(project: "work/one", community: 0, path: nil), showHidden: false, nodeLimit: 2)
expectEqual(limited.nodes.count, 2, "scene respects the node limit")
expectEqual(limited.omittedNodes, symbolScene.nodes.count - 2, "scene reports what it left out")
_ = try sceneWorkspace.perform([.hideNode(id: "a", label: "a")])
let withoutHidden = try sceneWorkspace.scene(at: .symbols(project: "work/one", community: 0, path: nil), showHidden: false)
check(!withoutHidden.nodes.contains { $0.id == "a" }, "hidden nodes aren't drawn by default")
let withHidden = try sceneWorkspace.scene(at: .symbols(project: "work/one", community: 0, path: nil), showHidden: true)
expectEqual(withHidden.nodes.first { $0.id == "a" }?.ghost, true, "hidden nodes can be shown ghosted")
_ = try sceneWorkspace.undoLastBatch()

// Review mode: one finding at a time, drawn as a constellation.
let reviewFindings = try sceneWorkspace.snapshot().findings
let reviewHub = reviewFindings[.crossProject]?.first { $0.anchor == "json" }
check(reviewHub != nil, "the cross-project fixture has a hub to review")
if let reviewHub {
    let reviewScene = try sceneWorkspace.reviewScene(for: reviewHub)
    let reviewCentre = reviewScene.nodes.first { $0.ring == 0 }
    expectEqual(reviewCentre?.value, reviewHub.count, "the review centre is the finding")
    expectEqual(reviewCentre?.unit, "links", "the review centre counts links")
    expectEqual(reviewScene.nodes.filter { $0.ring == 1 }.map(\.label), ["work/one"], "ring one holds the projects that link in")
    expectEqual(reviewScene.nodes.filter { $0.ring == 2 }.count, 3, "ring two holds the linking symbols")
    expectEqual(reviewScene.edges.first { $0.tree == nil }?.suspect, 3, "the line to a project carries its suspect links")
    expectEqual(reviewScene.groups.first { $0.label == "Work" }?.slot, 1, "review scenes keep owner colours")
}
if let generatedFinding = reviewFindings[.generated]?.first {
    let generatedScene = try sceneWorkspace.reviewScene(for: generatedFinding)
    expectEqual(generatedScene.nodes.first { $0.ring == 0 }?.noise, generatedFinding.count, "a generated finding is all noise")
    check(generatedScene.nodes.contains { $0.ring == 1 }, "a generated finding shows what it covers")
} else {
    check(false, "the fixture has a generated finding to review")
}

let queueFindings = (reviewFindings[.configLabels] ?? []) + (reviewFindings[.isolated] ?? [])
let ordered = ReviewQueue.ordered(queueFindings)
check(zip(ordered, ordered.dropFirst()).allSatisfy { $0.count >= $1.count }, "review starts with the biggest finding")
if let last = ordered.last, ordered.count >= 2 {
    expectEqual(ReviewQueue.neighbour(of: last.id, in: ordered)?.id, ordered[ordered.count - 2].id, "after the last finding, review steps back")
    expectEqual(ReviewQueue.neighbour(of: ordered[0].id, in: ordered)?.id, ordered[1].id, "otherwise review moves forward")
}
expectEqual(ReviewQueue.neighbour(of: "only", in: []), nil, "an empty queue has nothing next")

check(FuzzyMatch.score("rv gen", in: "Review Generated Code") != nil, "fuzzy match skips letters")
expectEqual(FuzzyMatch.score("xyz", in: "Rules"), nil, "fuzzy match needs every letter in order")
expectEqual(FuzzyMatch.score("odys", in: "work/rawdata-sync-starter"), nil, "letters scattered across words don't match")
check((FuzzyMatch.score("odys", in: "personal/odyssey") ?? 0) > (FuzzyMatch.score("odys", in: "Switch to personal/odyssey") ?? 0), "the shorter name wins an equal match")
check((FuzzyMatch.score("rul", in: "Rules") ?? 0) > (FuzzyMatch.score("rul", in: "Undo Last Rule") ?? 0), "a prefix match ranks first")
check((FuzzyMatch.score("gc", in: "Generated Code") ?? 0) > (FuzzyMatch.score("gc", in: "Config Keys Changes") ?? 0), "word starts rank higher")

// Ask the graph: reading graphify query output back into nodes.
let sampleAnswer = """
Traversal: BFS depth=2 | Start: ['a', 'json'] | 9 nodes found

NODE a [src=work/one/src/a.ts loc= community=0]
NODE user [src=work/one/src/generated/User.ts loc= community=0]
NODE Weird [label] name [src=personal/two/src/json.ts loc=L4 community=7]
NODE ghost [src=work/one/src/nowhere.ts loc=L1 community=]
... (truncated — 5 more nodes cut by ~2000-token budget. Narrow with context_filter=['call'])
"""
let parsedAnswer = QueryAnswer.parse(sampleAnswer)
expectEqual(parsedAnswer.found, 9, "the answer says how many nodes were found")
expectEqual(parsedAnswer.cut, 5, "the answer says how many the budget cut")
expectEqual(parsedAnswer.nodes.count, 4, "every NODE line is read")
expectEqual(parsedAnswer.nodes[2].label, "Weird [label] name", "labels with brackets survive")
expectEqual(parsedAnswer.nodes[2].location, "L4", "the line number is read")
expectEqual(parsedAnswer.nodes[2].community, 7, "the community is read")
expectEqual(QueryAnswer.parse("No matching nodes found.").nodes.count, 0, "an empty answer has no nodes")
let newerAnswer = QueryAnswer.parse("""
Graph: graphify-out/graph.json (48110 nodes) | Traversal: BFS depth=2 | Start: ['Platform']

[!] TRUNCATED: showing 41 of 1460 nodes (~1500-token budget). The answer may be among the 1419 cut nodes

NODE handle() [src=work/shop-platform/src/app/api/payments/gateway/cancel/route.ts loc=L22 community=gateway/cancel/route.ts]
""")
expectEqual(newerAnswer.found, 1460, "graphify 0.9.105 answers say how many were found")
expectEqual(newerAnswer.cut, 1419, "graphify 0.9.105 answers say how many the budget cut")
expectEqual(newerAnswer.nodes.first?.path, "work/shop-platform/src/app/api/payments/gateway/cancel/route.ts", "graphify 0.9.105 node lines are read")
expectEqual(newerAnswer.nodes.first?.community, nil, "a named community is fine to drop")

let answerItems = try sceneWorkspace.resolve(parsedAnswer)
expectEqual(answerItems.first?.nodeID, "a", "returned nodes match the index")
expectEqual(answerItems.first { $0.label == "user" }?.isGenerated, true, "generated nodes in an answer are flagged")
expectEqual(answerItems.first { $0.label == "ghost" }?.nodeID, nil, "unknown nodes stay unmatched")
expectEqual(answerItems.first { $0.label == "ghost" }?.project, "work/one", "unmatched nodes still get a project")
let answerScene = GraphScene.answer(question: "where is json used", found: parsedAnswer.found, items: answerItems)
expectEqual(answerScene.nodes.first { $0.ring == 0 }?.unit, "nodes found", "the answer centre counts what was found")
expectEqual(Set(answerScene.nodes.filter { $0.ring == 1 }.map(\.label)), ["work/one", "personal/two"], "ring one holds the projects the answer reached")
expectEqual(answerScene.nodes.first { $0.label == "user" }?.noise, 1, "generated nodes in an answer are drawn as noise")

// The agent guide, and the pointers that lead each tool to it.
let guideSnapshot = try sceneWorkspace.snapshot()
let guide = try sceneWorkspace.agentGuideText(findings: guideSnapshot.findings, overview: guideSnapshot.overview, clean: .notWritten)
check(guide.contains("## Before you read or change code"), "the guide starts with the steps")
check(guide.contains("graphify query \"<the task>\" --graph"), "the guide shows the query command")
check(guide.contains("graph.json"), "without a clean graph, the guide queries graph.json")
check(guide.contains("**work/one**"), "the guide lists projects")
check(guide.contains("`src/a.ts`") || guide.contains("`src/b.ts`"), "the guide names entry files inside the project")
check(!guide.contains("`src/generated/User.ts`"), "generated files are never entry points")
check(guide.contains("`json` in personal/two: 3 links from 1 other project"), "suspect hubs are listed as traps")
let cleanGuide = try sceneWorkspace.agentGuideText(findings: guideSnapshot.findings, overview: guideSnapshot.overview, clean: .upToDate(.now))
check(cleanGuide.contains("graph.clean.json"), "with an up-to-date clean graph, the guide queries it")
check(guide.contains("--budget 1500`"), "without .graphifyrc, the guide asks for 1,500 tokens")
let sceneRC = (sceneWorkspace.source.rootPath as NSString).appendingPathComponent(".graphifyrc")
try "query_budget=1000\n".write(toFile: sceneRC, atomically: true, encoding: .utf8)
let rcGuide = try sceneWorkspace.agentGuideText(findings: guideSnapshot.findings, overview: guideSnapshot.overview, clean: .notWritten)
check(rcGuide.contains("--budget 1000`"), "the guide asks for the answer size saved in .graphifyrc")
try? FileManager.default.removeItem(atPath: sceneRC)

expectEqual(AgentGuide.purpose(fromReadme: "# Title\n\n[![badge](x)](y)\n\nA **fast** tool for [planning](https://x) your week ahead.\n"), "A fast tool for planning your week ahead.", "README purpose skips headings and badges")
expectEqual(AgentGuide.purpose(fromReadme: "# Only a title\n"), nil, "a README without a sentence has no purpose")
expectEqual(AgentGuide.purpose(fromReadme: "Branch note: dev is the default branch and may be unstable.\n\nA private assistant that runs your own models locally.\n"), "A private assistant that runs your own models locally.", "README notes are skipped")
expectEqual(SourcePath.noiseKind(of: "personal/app/Resources/graph.bundle.js"), .generated, "bundled output is generated")
expectEqual(SourcePath.noiseKind(of: "personal/engine/third_party/stb/stb_image.h"), .vendored, "third_party is vendored")

let pointer = AgentSetup.block(guidePath: "/g/graphify-out/AGENT_GUIDE.md", root: "/g")
let mine = "# My notes\nKeep this.\n"
let connected = AgentSetup.applying(pointer, to: mine)
check(connected.hasPrefix(mine), "connecting keeps the file's own text first")
check(AgentSetup.isConnected(connected), "a connected file is recognised")
expectEqual(AgentSetup.applying(pointer, to: connected), connected, "connecting twice changes nothing")
expectEqual(AgentSetup.removing(from: connected), "# My notes\nKeep this.\n", "disconnecting restores the original text")
expectEqual(AgentSetup.applying(pointer, to: ""), pointer + "\n", "an empty file gets only the pointer")
let claudeLine = "run `graphify query \"<question>\"` from `~/Documents/GitHub`."
expectEqual(AgentSetup.pointingQueriesAtCleanGraph(claudeLine, cleanGraph: "graphify-out/graph.clean.json"), "run `graphify query \"<question>\" --graph graphify-out/graph.clean.json` from `~/Documents/GitHub`.", "Claude Code's query line can point at the clean graph")
expectEqual(AgentSetup.pointingQueriesAtCleanGraph("nothing here", cleanGraph: "x"), nil, "no query line, no change")
let customFolder = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-custom-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: customFolder, withIntermediateDirectories: true)
expectEqual((AgentSetup.customTarget(path: customFolder.path).file as NSString).lastPathComponent, "AGENTS.md", "picking a folder means its AGENTS.md")
check(!AgentSetup.pastableBlock(guidePath: "/g/AGENT_GUIDE.md", root: "/g").contains("graphitree:"), "the pasteable pointer has no markers")
let testLaunch = MCPLaunch.graphitree(cli: "/Applications/Graphitree.app/Contents/MacOS/graphitree-cli", outDirectory: "/g/graphify-out")
check(AgentSetup.mcpSnippet(testLaunch).contains("\"mcp\"") && AgentSetup.mcpSnippet(testLaunch).contains("\"--graph\""), "the MCP snippet runs Graphitree's server for one graph")

// MCP settings files, in both formats.
let desktop = try AgentSetup.mcpConfig(Data(#"{"theme":"dark","mcpServers":{"other":{"command":"x"},"graphify":{"command":"/py","args":["-m","graphify.serve","/g.json"]}}}"#.utf8), format: .mcpServers, launch: testLaunch)
check(AgentSetup.mcpHasServer(desktop, format: .mcpServers), "a chat app gets Graphitree's server")
let desktopJSON = try JSONSerialization.jsonObject(with: desktop) as? [String: Any]
expectEqual(desktopJSON?["theme"] as? String, "dark", "other settings are kept")
expectEqual(((desktopJSON?["mcpServers"] as? [String: Any])?.keys.sorted()) ?? [], ["graphitree", "other"], "other MCP servers are kept, and graphify's old server is replaced")
check(!String(decoding: desktop, as: UTF8.self).contains("\\/"), "paths are written without escaped slashes")
let someoneElsesGraphify = try AgentSetup.mcpConfig(Data(#"{"mcpServers":{"graphify":{"command":"my-own-thing"}}}"#.utf8), format: .mcpServers, launch: testLaunch)
expectEqual(((try JSONSerialization.jsonObject(with: someoneElsesGraphify) as? [String: Any])?["mcpServers"] as? [String: Any])?.keys.sorted() ?? [], ["graphify", "graphitree"], "a server called graphify that isn't graphify's own is left alone")
let desktopWithout = try AgentSetup.mcpConfigRemovingServer(desktop, format: .mcpServers)
check(!AgentSetup.mcpHasServer(desktopWithout, format: .mcpServers), "Graphitree's server can be removed again")
let vscode = try AgentSetup.mcpConfig(nil, format: .vscode, launch: testLaunch)
let vscodeServer = ((try JSONSerialization.jsonObject(with: vscode) as? [String: Any])?["servers"] as? [String: Any])?["graphitree"] as? [String: Any]
expectEqual(vscodeServer?["type"] as? String, "stdio", "VS Code's entry says it runs over stdio")
expectEqual(vscodeServer?["args"] as? [String], ["mcp", "--graph", "/g/graphify-out"], "the server is told which graph to use")
check(AgentSetup.mcpHasServer(vscode, format: .vscode) && !AgentSetup.mcpHasServer(vscode, format: .mcpServers), "VS Code uses its own servers key")
let fromBlank = try AgentSetup.mcpConfig(Data("  \n".utf8), format: .mcpServers, launch: testLaunch)
check(AgentSetup.mcpHasServer(fromBlank, format: .mcpServers), "an empty settings file is treated as empty settings")
check((try? AgentSetup.mcpConfig(Data("[1]".utf8), format: .mcpServers, launch: testLaunch)) == nil, "a settings file that isn't an object is left alone")
check(AgentSetup.mcpPreview(.mcpServers, launch: testLaunch).contains("\"mcpServers\""), "the preview shows the entry as it will be written")

// The catalog: every coding tool has both sides, every provider maps to a graphify backend.
let graphifyBackends: Set<String> = ["claude", "kimi", "ollama", "gemini", "openai", "deepseek", "azure", "bedrock", "claude-cli"]
check(AICatalog.providers.allSatisfy { graphifyBackends.contains($0.backend) }, "every provider is a graphify backend")
check(AICatalog.codingTools.allSatisfy { !$0.skillPath.isEmpty && !$0.instructionsPath.isEmpty }, "every coding tool can both build and read")
expectEqual(Set(AICatalog.codingTools.map(\.id)).count, AICatalog.codingTools.count, "coding tool ids are unique")
expectEqual(Set(AICatalog.providers.map(\.id)).count, AICatalog.providers.count, "provider ids are unique")
expectEqual(AICatalog.codingTools.compactMap(\.graphitreeBackend), ["claude-cli"], "only Claude Code's sign-in can be driven by Graphitree")

// Tool state in a fake home: the skill means it builds, the pointer means it reads.
let fakeHome = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-home-\(UUID().uuidString)").path
let codex = AICatalog.codingTools.first { $0.id == "codex" }!
try FileManager.default.createDirectory(atPath: fakeHome + "/.local/bin", withIntermediateDirectories: true)
expectEqual(CodingToolState.read(codex, home: fakeHome), CodingToolState(isInstalled: false, builds: false, reads: false), "nothing set up in an empty home")
FileManager.default.createFile(atPath: fakeHome + "/.local/bin/codex", contents: Data("#!/bin/sh\n".utf8), attributes: [.posixPermissions: 0o755])
expectEqual(ToolLocator.command(["codex"], home: fakeHome), fakeHome + "/.local/bin/codex", "a tool's command is found in ~/.local/bin")
try AgentSetup.write(AgentSetup.applying(pointer, to: ""), to: codex.instructionsFile(home: fakeHome))
let readsOnly = CodingToolState.read(codex, home: fakeHome)
check(readsOnly.isInstalled && readsOnly.reads && !readsOnly.builds && readsOnly.isPartial, "a pointer without the skill is half set up")

// The models graphify calls itself: settings, keys and the docs pass they make.
let testDefaults = checkSuite("checks")
let testKeychain = AIKeychain(service: "Graphitree checks \(UUID().uuidString)")
let store = AIProviderStore(defaults: testDefaults, keychain: testKeychain)
let anthropic = AICatalog.providers.first { $0.id == "anthropic" }!
let lmStudio = AICatalog.providers.first { $0.id == "openai-compatible" }!
let ollama = AICatalog.providers.first { $0.id == "ollama" }!
check(!store.isConfigured(anthropic) && !store.isConfigured(ollama), "nothing is set up at first")
try store.save(["ANTHROPIC_API_KEY": "sk-test-1", "model": "claude-haiku-test"], for: anthropic)
check(store.isConfigured(anthropic), "a saved key sets the provider up")
expectEqual(testKeychain.read("anthropic.ANTHROPIC_API_KEY"), "sk-test-1", "the key goes to the Keychain")
check((testDefaults.dictionary(forKey: "aiProviderSettings")?.description ?? "").contains("sk-test") == false, "the key never goes to defaults")
try store.save(["ANTHROPIC_API_KEY": "", "model": "claude-haiku-test"], for: anthropic)
expectEqual(testKeychain.read("anthropic.ANTHROPIC_API_KEY"), "sk-test-1", "leaving the key blank keeps the saved one")
let anthropicPass = BuildChoice.docsPass(for: "anthropic", home: fakeHome, store: store)
expectEqual(anthropicPass?.steps(root: "/r"), [["extract", "/r", "--backend", "claude", "--model", "claude-haiku-test"], ["label", "/r", "--missing-only", "--backend=claude", "--model=claude-haiku-test"]], "the docs pass reads docs, then names new groups, with the same model")
expectEqual(anthropicPass?.environment["ANTHROPIC_API_KEY"], "sk-test-1", "the docs pass hands graphify the key")
expectEqual(anthropicPass?.billing, .apiAccount, "an API key is billed to its account")
try store.save(["OPENAI_BASE_URL": "http://localhost:1234/v1"], for: lmStudio)
check(!store.isConfigured(lmStudio), "a local server needs its model named")
try store.save(["OPENAI_BASE_URL": "http://localhost:1234/v1", "model": "qwen3-8b"], for: lmStudio)
let localPass = BuildChoice.docsPass(for: "openai-compatible", home: fakeHome, store: store)
expectEqual(localPass?.environment, ["OPENAI_BASE_URL": "http://localhost:1234/v1", "OPENAI_API_KEY": "local"], "a local server gets its address and a stand-in key")
expectEqual(localPass?.billing, .thisMac, "a local model runs on this Mac")
try store.save([:], for: ollama)
check(store.isConfigured(ollama), "Ollama needs nothing filled in once it's saved")
expectEqual(BuildChoice.docsPass(for: "ollama", home: fakeHome, store: store)?.steps(root: "/r").first, ["extract", "/r", "--backend", "ollama"], "without a model, graphify picks its default")
expectEqual(BuildChoice.options(home: fakeHome, store: store).map(\.id), ["anthropic", "ollama", "openai-compatible"], "only set-up models can be chosen")
check(BuildChoice.docsPass(for: "claude-code", home: fakeHome, store: store) == nil, "Claude Code can't build without its command")
FileManager.default.createFile(atPath: fakeHome + "/.local/bin/claude", contents: Data("#!/bin/sh\n".utf8), attributes: [.posixPermissions: 0o755])
let planPass = BuildChoice.docsPass(for: "claude-code", home: fakeHome, store: store)
expectEqual(planPass?.backend, "claude-cli", "Claude Code builds through the claude command")
expectEqual(planPass?.billing, .plan, "Claude Code builds on the plan")
store.remove(anthropic)
check(!store.isConfigured(anthropic) && testKeychain.read("anthropic.ANTHROPIC_API_KEY") == nil, "removing a provider deletes its key")
store.remove(lmStudio)
store.remove(ollama)
check(BuildChoice.docsPass(for: "nobody", home: fakeHome, store: store) == nil, "an unknown choice builds nothing")

expectEqual(GraphifyModules.installCommand(modules: ["openai"], python: "/u/.local/share/uv/tools/graphifyy/bin/python", home: "/u"), "uv pip install --python /u/.local/share/uv/tools/graphifyy/bin/python openai", "a uv install gets uv pip")
expectEqual(GraphifyModules.installCommand(modules: ["mcp"], python: "/u/.local/pipx/venvs/graphifyy/bin/python", home: "/u"), "pipx inject graphifyy mcp", "a pipx install gets pipx inject")

// The setup wizard's files and choices.
let existingIgnore = "# mine\nnode_modules/\nvendor/\n"
let packages = SetupPresets.ignore.first { $0.id == "packages" }!
check(!IgnoreFile.isApplied(packages, in: existingIgnore), "a preset with lines missing isn't applied")
expectEqual(IgnoreFile.additions(packages.lines + ["vendor/", "  ", "# note"], to: existingIgnore), ["Pods/", ".venv/"], "only missing lines are added, once, without blanks or comments")
let withPackages = IgnoreFile.adding(packages.lines, to: existingIgnore, note: "Added by Graphitree")
check(withPackages.hasPrefix(existingIgnore) && withPackages.contains("# Added by Graphitree\nPods/\n.venv/\n"), "new lines go under one comment after the existing ones")
check(IgnoreFile.isApplied(packages, in: withPackages), "after adding, the preset is applied")
expectEqual(IgnoreFile.adding(packages.lines, to: withPackages, note: "x"), withPackages, "adding again changes nothing")
expectEqual(IgnoreFile.adding(["dist/"], to: "", note: "n"), "# n\ndist/\n", "an empty file gets just the new lines")
expectEqual(SourcePath.ignoreLine(for: "work/client-a/"), "/work/client-a/", "a left-out project is anchored to the root")
check(SetupPresets.ignore.filter(\.isOnByDefault).map(\.id).contains("generated") && !SetupPresets.ignore.first { $0.id == "tests" }!.isOnByDefault, "tests stay in unless chosen")

let rc = "# mine\nlanguage.inc=php\nquery_budget = 1500\n"
expectEqual(RCFile.value("query_budget", in: rc), "1500", "rc values are read with spaces around =")
expectEqual(RCFile.value("query_depth", in: rc), nil, "a missing rc key reads as nil")
let rcUpdated = RCFile.setting([("query_budget", "1000"), ("query_depth", "1")], in: rc)
expectEqual(rcUpdated, "# mine\nlanguage.inc=php\nquery_budget=1000\nquery_depth=1\n", "rc keys are replaced in place or added, and other lines stay")
expectEqual(RCFile.setting([("query_budget", "2000")], in: ""), "query_budget=2000\n", "an empty rc gets the key")
expectEqual(AnswerSize.from(budget: 1500), .small, "a saved budget maps to the nearest size")
expectEqual(AnswerSize.from(budget: nil), .medium, "no saved budget is graphify's default")

expectEqual(BuildChoice.resolve(BuildChoice.automatic, options: ["claude-code", "anthropic"]), "claude-code", "until someone chooses, the first set-up model builds")
expectEqual(BuildChoice.resolve("", options: ["claude-code"]), "claude-code", "an old empty choice also means automatic")
expectEqual(BuildChoice.resolve(BuildChoice.automatic, options: []), nil, "with nothing set up, rebuilds read code only")
expectEqual(BuildChoice.resolve(BuildChoice.codeOnly, options: ["claude-code"]), nil, "choosing code only sticks")
expectEqual(BuildChoice.resolve("anthropic", options: ["claude-code", "anthropic"]), "anthropic", "a chosen model is used")
expectEqual(BuildChoice.resolve("anthropic", options: ["claude-code"]), nil, "a chosen model that's gone means code only")

let sizes = try sceneWorkspace.projectSizes()
let sizeCounts: [Int] = sizes.map { $0.nodes }
check(!sizes.isEmpty && sizeCounts == sizeCounts.sorted(by: >), "projects come largest first")
check(!sizes.contains { $0.project == SourcePath.noProject }, "loose files aren't a project")

// The playbook: pasted libraries, its markdown, the guide link, the stack scan, Claude drafts and backups.
let pasted = PlaybookImport.libraries(from: """
shadcn/ui – https://ui.shadcn.com
Sonner - https://sonner.emilkowal.ski
pick-ui-library skill – https://github.com/emilkowalski/skills
https://21st.dev
  • Motion
""")
expectEqual(pasted.map(\.name), ["shadcn/ui", "Sonner", "pick-ui-library skill", "21st.dev", "Motion"], "pasted lines give names, with a bare link named after its host")
expectEqual(pasted.map(\.url), ["https://ui.shadcn.com", "https://sonner.emilkowal.ski", "https://github.com/emilkowalski/skills", "https://21st.dev", ""], "pasted lines keep their links")
let radixKnown = StackScan.knownLibraries.first { $0.package == "radix-ui" }!
check(PlaybookImport.contains(radixKnown, in: [PlaybookLibrary(name: "Radix", url: "https://www.radix-ui.com")]), "a known library matches a shorter name or the same site")
check(!PlaybookImport.contains(radixKnown, in: [PlaybookLibrary(name: "Sonner")]), "an unrelated library doesn't match")
let shelf = PlaybookImport.merging(PlaybookImport.libraries(from: "sonner\nVaul"), into: pasted)
expectEqual(shelf.count, 6, "adding a library that's already there, in any case, is skipped")

var book = Playbook()
book.libraries = [
    PlaybookLibrary(name: "Sonner", url: "https://sonner.emilkowal.ski", task: "Toasts", purpose: "Toasts for React.", useWhen: "Non-blocking feedback.", avoidWhen: "Blocking messages.", install: "npm install sonner", platforms: "React", health: "Maintained, 2026.", verified: true),
    PlaybookLibrary(name: "Vaul", task: "Drawers", purpose: "Drawers for React.", health: "Unmaintained since 2024.", drafted: true),
    PlaybookLibrary(name: "21st.dev"),
]
book.stack["web"] = StackAnswer(choices: ["Next.js"], notes: "Vite for internal dashboards.")
book.stack["ui"] = StackAnswer()
book.habits["always"] = "Explain changes in plain language."
check(!PlaybookLibrary(name: "a", health: "Active. The repo isn't archived and has no deprecation notice.").looksAbandoned, "\"isn't archived\" isn't a warning")
check(!PlaybookLibrary(name: "a", health: "Maintained, not deprecated.").looksAbandoned, "\"not deprecated\" isn't a warning")
check(PlaybookLibrary(name: "a", health: "Unmaintained: the README says so.").looksAbandoned, "unmaintained is a warning")
check(PlaybookLibrary(name: "a", health: "The repo has been archived.").looksAbandoned, "archived is a warning")
check(PlaybookLibrary(name: "a", health: "No longer maintained since 2024.").looksAbandoned, "no longer maintained is a warning")
let bookText = PlaybookFile.markdown(book)
check(bookText.contains("## Rules for AI tools") && bookText.contains("look under Libraries"), "the playbook starts with rules for AI tools")
check(bookText.contains("### Drawers") && bookText.contains("### Toasts") && bookText.contains("### Other"), "libraries are grouped by task, untitled ones last")
check(bookText.range(of: "### Drawers")!.lowerBound < bookText.range(of: "### Toasts")!.lowerBound && bookText.range(of: "### Toasts")!.lowerBound < bookText.range(of: "### Other")!.lowerBound, "task groups are in order")
check(bookText.contains("- **Sonner** (https://sonner.emilkowal.ski)\n"), "a verified library has no draft mark")
check(bookText.contains("- **Vaul** *avoid for new work, draft*"), "an unmaintained draft says both")
check(bookText.contains("- **21st.dev** *not described yet*"), "an empty entry says it isn't described")
check(bookText.contains("Install: `npm install sonner`. Works with: React."), "install and platforms share a line")
expectEqual(PlaybookFile.installText("No package. Copy each component from the site."), "No package. Copy each component from the site.", "prose install notes aren't code")
expectEqual(PlaybookFile.installText("npm i @number-flow/react (also vue)"), "`npm i @number-flow/react` (also vue).", "a command keeps its explanation outside the code")
check(bookText.contains("- **Web framework:** Next.js. Vite for internal dashboards."), "stack answers list choices and notes")
check(!bookText.contains("UI components"), "unanswered questions are left out")
check(bookText.contains("### Always do\n\nExplain changes in plain language."), "habits are written under their prompt")
check(!PlaybookFile.markdown(Playbook()).contains("## Libraries"), "an empty playbook has only the rules")

let bookFolder = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-playbook-\(UUID().uuidString)")
try PlaybookFile.save(book, to: bookFolder, now: Date(timeIntervalSince1970: 1_800_000_000))
let reloaded = PlaybookFile.load(from: bookFolder)
expectEqual(reloaded.libraries, book.libraries, "the playbook reloads its libraries")
expectEqual(reloaded.stack, book.stack, "the playbook reloads its stack")
expectEqual(reloaded.updatedAt, Date(timeIntervalSince1970: 1_800_000_000), "saving stamps the time")
check(PlaybookFile.load(from: bookFolder.appendingPathComponent("none")).isEmpty, "no file means an empty playbook")

let playbookInGraph = (sceneWorkspace.source.outDirectory.path as NSString).appendingPathComponent(PlaybookFile.markdownName)
check(!guide.contains("Before you build something new"), "without a playbook, the guide doesn't mention one")
try "x".write(toFile: playbookInGraph, atomically: true, encoding: .utf8)
let guideWithPlaybook = try sceneWorkspace.agentGuideText(findings: guideSnapshot.findings, overview: guideSnapshot.overview, clean: .notWritten)
check(guideWithPlaybook.contains("## Before you build something new") && guideWithPlaybook.contains(PlaybookFile.markdownName), "with a playbook, the guide sends tools to it")
try? FileManager.default.removeItem(atPath: playbookInGraph)

let scanRoot = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-scan-\(UUID().uuidString)").path
func put(_ path: String, _ text: String) throws {
    let full = (scanRoot as NSString).appendingPathComponent(path)
    try FileManager.default.createDirectory(atPath: (full as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try text.write(toFile: full, atomically: true, encoding: .utf8)
}
try put("personal/web/package.json", #"{"dependencies":{"next":"15","react":"19","sonner":"2","@radix-ui/react-dialog":"1","some-widget":"1","@me/admin":"*"},"devDependencies":{"typescript":"5","tailwindcss":"4","vitest":"3","@types/node":"22"}}"#)
try put("personal/web/components.json", "{}")
try put("personal/web/vercel.json", "{}")
try put("personal/web/node_modules/nuxt/package.json", #"{"dependencies":{"nuxt":"3"}}"#)
try put("personal/web/apps/admin/package.json", #"{"name":"@me/admin","dependencies":{"vite":"6","react":"19","sonner":"2"}}"#)
try put("graphify-out.before-fresh/2026-11-11/package.json", #"{"dependencies":{"astro":"5"}}"#)
try put("personal/mac/project.yml", "targets:\n  App:\n    platform: macOS\n")
try put("personal/mac/Package.swift", ".package(url: \"https://github.com/groue/GRDB.swift\", from: \"7.0.0\")")
try put("work/api/requirements.txt", "fastapi>=0.110\npsycopg2-binary==2.9\n# comment\n")
try put("work/py/pyproject.toml", "[project]\nname = \"tool\"\ndependencies = [\n  \"anthropic>=0.40\",\n  \"pytest\",\n]\n")
let scanned = StackScan.scan(root: scanRoot, projects: ["personal/web", "personal/mac", "work/api", "work/py"])
expectEqual(scanned.projectsScanned, 4, "a monorepo's inner app counts toward its project")
expectEqual(scanned.projects(using: "Next.js", for: "web"), 1, "Next.js is found")
expectEqual(scanned.projects(using: "Vite + React", for: "web"), 1, "Vite and React together mean Vite + React")
expectEqual(scanned.projects(using: "Nuxt", for: "web"), 0, "node_modules is never read")
expectEqual(scanned.projects(using: "shadcn/ui", for: "ui"), 1, "components.json means shadcn/ui")
expectEqual(scanned.projects(using: "Radix UI", for: "ui"), 1, "@radix-ui packages mean Radix")
expectEqual(scanned.projects(using: "Vercel", for: "hosting"), 1, "vercel.json means Vercel")
expectEqual(scanned.projects(using: "Mac apps", for: "platforms"), 1, "a macOS target means Mac apps")
expectEqual(scanned.projects(using: "SQLite", for: "data"), 1, "GRDB means SQLite")
expectEqual(scanned.projects(using: "FastAPI", for: "backend"), 1, "requirements.txt is read")
expectEqual(scanned.projects(using: "PostgreSQL", for: "data"), 1, "psycopg2 means Postgres")
expectEqual(scanned.projects(using: "Claude API", for: "ai"), 1, "pyproject dependencies are read")
expectEqual(scanned.projects(using: "pytest", for: "testing"), 1, "dev tools in pyproject are found")
expectEqual(scanned.projects(using: "TypeScript", for: "languages"), 1, "TypeScript is found")
expectEqual(scanned.libraries["Sonner"], ["personal/web"], "known libraries are found and credited once per project")
check(!StackScan.packageNames(in: (scanRoot as NSString).appendingPathComponent("work/py")).contains("name"), "pyproject keys aren't read as packages")
expectEqual(scanned.projects(using: "Astro", for: "web"), 0, "a copy of graphify-out isn't read")
expectEqual(scanned.otherPackages["some-widget"], ["personal/web"], "a dependency no list knows is still reported")
check(scanned.otherPackages["sonner"] == nil && scanned.otherPackages["react"] == nil && scanned.otherPackages["next"] == nil, "recognised dependencies aren't reported again")
check(scanned.otherPackages["@types/node"] == nil, "type packages aren't reported")
check(scanned.otherPackages["@me/admin"] == nil, "a monorepo's own packages aren't reported")
check(PlaybookChat.scanText(scanned)?.contains("some-widget (1)") == true, "the chat is told about dependencies the scan doesn't recognise")
try? FileManager.default.removeItem(atPath: scanRoot)

// A hidden file such as .DS_Store sitting beside project folders mustn't hide any of them.
let dotRoot = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-scan-dots-\(UUID().uuidString)").path
for index in 0..<16 {
    let folder = (dotRoot as NSString).appendingPathComponent("app\(index)")
    try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
    try #"{"dependencies":{"animejs":"4"}}"#.write(toFile: (folder as NSString).appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
    try "x".write(toFile: (dotRoot as NSString).appendingPathComponent(".hidden\(index)"), atomically: true, encoding: .utf8)
}
let dotScan = StackScan.scan(root: dotRoot, projects: [])
expectEqual(dotScan.projectsScanned, 16, "hidden files beside projects don't make the scan skip a project")
expectEqual(dotScan.libraries["Anime.js"]?.count, 16, "anime.js is a known library")
try? FileManager.default.removeItem(atPath: dotRoot)

let envelope = #"{"type":"result","is_error":false,"result":"done","structured_output":{"libraries":[{"name":"Sonner","url":"https://sonner.emilkowal.ski","task":"Toasts","purpose":"Toasts.","useWhen":"Feedback.","avoidWhen":"unknown","install":"npm install sonner","platforms":"React","health":"Maintained."}]}}"#
let drafts = try PlaybookResearch.parse(envelope)
expectEqual(drafts.map(\.name), ["Sonner"], "Claude Code's structured output is read")
let fallback = #"{"is_error":false,"result":"{\"libraries\":[{\"name\":\"Vaul\",\"url\":\"\",\"task\":\"Drawers\",\"purpose\":\"p\",\"useWhen\":\"u\",\"avoidWhen\":\"a\",\"install\":\"i\",\"platforms\":\"React\",\"health\":\"h\"}]}"}"#
expectEqual(try PlaybookResearch.parse(fallback).first?.task, "Drawers", "JSON in the result text is read when there's no structured output")
check((try? PlaybookResearch.parse(#"{"is_error":true,"result":"API Error"}"#)) == nil, "an error reply throws")
var myLibrary = PlaybookLibrary(name: "sonner", avoidWhen: "My own words.", verified: true, notes: "Use the rich colours.")
myLibrary = PlaybookResearch.applying(drafts[0], to: myLibrary)
check(myLibrary.drafted && !myLibrary.verified && myLibrary.task == "Toasts" && myLibrary.url == "https://sonner.emilkowal.ski", "a draft fills the library and marks it unverified")
expectEqual(myLibrary.avoidWhen, "My own words.", "\"unknown\" never replaces what's there")
expectEqual(myLibrary.notes, "Use the rich colours.", "the person's notes stay")
expectEqual(PlaybookResearch.match(drafts, to: [myLibrary]).count, 1, "drafts match libraries by name, ignoring case")
check(PlaybookResearch.arguments(for: [myLibrary]).contains("WebSearch,WebFetch") && PlaybookResearch.arguments(for: [myLibrary]).contains("--json-schema"), "Claude Code gets only the web tools and the schema")

expectEqual(PlaybookBackup.accounts(from: "github.com\n  ✓ Logged in to github.com account work-me (keyring)\n  - Active account: true\n  ✓ Logged in to github.com account home-me (keyring)\n"), ["work-me", "home-me"], "every gh account is listed")
let bare = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-remote-\(UUID().uuidString).git")
let mirrorFolder = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-mirror-\(UUID().uuidString)")
_ = try ProcessRunner.run("/usr/bin/git", ["init", "--bare", "-b", "main", bare.path])
let firstBackup = try PlaybookBackup.backUp(from: bookFolder, to: mirrorFolder, remote: bare.path, account: nil)
check(firstBackup, "the first backup commits and pushes")
let repeatBackup = try PlaybookBackup.backUp(from: bookFolder, to: mirrorFolder, remote: bare.path, account: nil)
check(!repeatBackup, "backing up again with no changes commits nothing")
book.habits["never"] = "Don't add dependencies silently."
try PlaybookFile.save(book, to: bookFolder)
let changeBackup = try PlaybookBackup.backUp(from: bookFolder, to: mirrorFolder, remote: bare.path, account: nil)
check(changeBackup, "a change is backed up")
let pushed = try ProcessRunner.run("/usr/bin/git", ["--git-dir", bare.path, "log", "--oneline", "main"])
expectEqual(pushed.output.split(separator: "\n").count, 2, "the remote has one commit per change")
let pushedFiles = try ProcessRunner.run("/usr/bin/git", ["--git-dir", bare.path, "ls-tree", "--name-only", "main"])
expectEqual(Set(pushedFiles.output.split(separator: "\n").map(String.init)), ["PLAYBOOK.md", "playbook.json"], "only the playbook files are pushed")
for folder in [bookFolder, bare, mirrorFolder] { try? FileManager.default.removeItem(at: folder) }

// MARK: - Playbook in the guide and the graph

let summary = PlaybookFile.guideSummary(book)
check(summary.contains("- Toasts: Sonner"), "the guide summary lists a pick under its job")
check(summary.contains("- Drawers: avoid Vaul for new work"), "an abandoned library is listed as one to avoid")
check(summary.contains("- Other: 21st.dev"), "a library with no job goes under Other")
check(summary.contains("- Web framework: Next.js") && summary.contains("Stack for new work:"), "stack answers are in the summary")
check(summary.last?.hasPrefix("2 of the 3 libraries above were described by AI") == true, "the summary says how many picks are unchecked drafts")
expectEqual(PlaybookFile.guideSummary(Playbook()), [], "an empty playbook adds nothing to the guide")

let sceneOut = sceneWorkspace.source.outDirectory
try PlaybookFile.save(book, to: sceneOut)
let guideWithPicks = try sceneWorkspace.agentGuideText(findings: guideSnapshot.findings, overview: guideSnapshot.overview, clean: .notWritten)
check(guideWithPicks.contains("Use the owner's picks") && guideWithPicks.contains("- Toasts: Sonner"), "the guide carries the playbook's picks")
check(!guideWithPicks.contains("The playbook is also in the graph"), "the guide doesn't claim the playbook is in a graph that lacks it")
for name in [PlaybookFile.markdownName, PlaybookFile.jsonName] { try? FileManager.default.removeItem(at: sceneOut.appendingPathComponent(name)) }

let copyRoot = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-copy-\(UUID().uuidString)").path
try FileManager.default.createDirectory(atPath: copyRoot, withIntermediateDirectories: true)
check(PlaybookFile.addsToGraphByDefault(root: copyRoot), "a folder of repos gets the graph copy by default")
let copyWritten = try PlaybookFile.writeGraphCopy(book, root: copyRoot)
check(copyWritten, "the graph copy is written")
let copyAgain = try PlaybookFile.writeGraphCopy(book, root: copyRoot)
check(!copyAgain, "an unchanged playbook leaves the copy and its date alone")
let copyText = try String(contentsOf: PlaybookFile.graphCopyURL(root: copyRoot), encoding: .utf8)
check(copyText.hasPrefix("<!-- A copy of graphify-out/PLAYBOOK.md") && copyText.contains("# Playbook") && copyText.contains("**Sonner**"), "the copy says what it is and holds the playbook")
check(PlaybookFile.graphCopyIsNewer(than: .distantPast, root: copyRoot) && !PlaybookFile.graphCopyIsNewer(than: .distantFuture, root: copyRoot), "the copy's date is compared with the build")
PlaybookFile.removeGraphCopy(root: copyRoot)
check(!FileManager.default.fileExists(atPath: (copyRoot as NSString).appendingPathComponent(PlaybookFile.graphFolder)), "removing the copy removes its empty folder")
try FileManager.default.createDirectory(atPath: (copyRoot as NSString).appendingPathComponent(".git"), withIntermediateDirectories: true)
check(!PlaybookFile.addsToGraphByDefault(root: copyRoot), "a single repo doesn't get a playbook folder unless asked")
let checkDefaults = checkSuite("checks")
checkDefaults.set(true, forKey: PlaybookFile.graphCopyDefaultsKey)
check(PlaybookFile.addsToGraph(root: copyRoot, defaults: checkDefaults), "the person's choice beats the default")

// MARK: - Saved setup and what shapes the graph

let record = SetupRecord(defaults: checkDefaults)
check(!record.isSetUp(root: copyRoot), "a graph starts without a saved setup")
record.markApplied(root: copyRoot + "/", at: Date(timeIntervalSince1970: 1_800_000_000))
expectEqual(record.appliedAt(root: copyRoot), Date(timeIntervalSince1970: 1_800_000_000), "a saved setup is found by its folder, with or without a trailing slash")
check(record.isSetUp(root: copyRoot), "after saving, the graph is set up")
let rcOnly = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-rc-\(UUID().uuidString)").path
try FileManager.default.createDirectory(atPath: rcOnly, withIntermediateDirectories: true)
check(GraphSettings.read(root: rcOnly).answersSummary == "graphify's defaults", "no .graphifyrc means graphify's defaults")
try "query_budget=3900\nquery_depth=1\n".write(toFile: (rcOnly as NSString).appendingPathComponent(".graphifyrc"), atomically: true, encoding: .utf8)
try "# comment\nnode_modules/\n\ndist/\n*.min.js\n".write(toFile: (rcOnly as NSString).appendingPathComponent(".graphifyignore"), atomically: true, encoding: .utf8)
check(record.isSetUp(root: rcOnly), "a .graphifyrc from an earlier setup counts as set up")
let readSettings = GraphSettings.read(root: rcOnly)
expectEqual(readSettings.ignorePatterns, 3, "comments and blank lines aren't patterns")
check(readSettings.ignoreChangedAt != nil, "the ignore file's date is read")
expectEqual(readSettings.answersSummary, "Long answers, close reach", "answer settings are read from .graphifyrc")
for folder in [copyRoot, rcOnly] { try? FileManager.default.removeItem(atPath: folder) }

// MARK: - Playbook chat

check((try? JSONSerialization.jsonObject(with: Data(PlaybookChat.schema.utf8))) != nil && PlaybookChat.schema.contains("\"additionalProperties\":false"), "the chat schema is valid JSON with closed objects")
let replyObject: [String: Any] = [
    "reply": "Use **Sonner**.",
    "libraries": [["name": "React Hook Form", "url": "https://react-hook-form.com", "task": "Forms", "purpose": "Forms.", "useWhen": "u", "avoidWhen": "unknown", "install": "npm i react-hook-form", "platforms": "React", "health": "Maintained.", "reason": "You use it."]],
    "stack": [["question": "ui", "choices": ["shadcn/ui", "radix ui", "Base UI", "SwiftUI"], "notes": "", "reason": "For web."], ["question": "nope", "choices": ["x"], "notes": "", "reason": ""]],
    "habits": [["prompt": "never", "text": "Don't add dependencies silently.", "reason": "You said so."]],
]
let parsedReply = PlaybookChat.reply(from: replyObject)
expectEqual(parsedReply.text, "Use **Sonner**.", "the reply text is read")
expectEqual(parsedReply.changes.map(\.kind), [.library, .stack, .habit], "each kind of change is read, unknown questions dropped")
let fenced = PlaybookChat.parseLoose("Sure.\n```json\n{\"reply\":\"Hi\",\"libraries\":[],\"stack\":[],\"habits\":[]}\n```")
expectEqual(fenced.text, "Hi", "JSON inside a code fence is found")
expectEqual(PlaybookChat.parseLoose("Just text, no JSON.").text, "Just text, no JSON.", "a plain reply still shows")
let cliEnvelope = #"{"is_error":false,"result":"","structured_output":{"reply":"Done","libraries":[],"stack":[],"habits":[{"prompt":"design","text":"Dark and quiet.","reason":"r"}]}}"#
expectEqual(try PlaybookChat.parseCLI(cliEnvelope).changes.first?.habit, "design", "Claude Code's structured reply is read")
check((try? PlaybookChat.parseCLI(#"{"is_error":true,"result":"Out of usage"}"#)) == nil, "an error from Claude Code throws")

var chatBook = book
for change in parsedReply.changes { chatBook = PlaybookChat.applying(change, to: chatBook) }
let addedForm = chatBook.libraries.first { $0.name == "React Hook Form" }
check(addedForm?.drafted == true && addedForm?.verified == false && addedForm?.task == "Forms", "a library from the chat is added as an unchecked draft")
expectEqual(chatBook.stack["ui"]?.choices, ["shadcn/ui", "Radix UI", "Base UI", "SwiftUI"], "stack choices keep the options' own spelling")
expectEqual(chatBook.habits["never"], "Don't add dependencies silently.", "a habit change replaces the text")
let sonnerUpdate = PlaybookChange(kind: .library, library: LibraryDraft(name: "sonner", url: "", task: "Notifications", purpose: "Better toasts.", useWhen: "", avoidWhen: "", install: "", platforms: "", health: "unknown"))
let updatedBook = PlaybookChat.applying(sonnerUpdate, to: chatBook)
expectEqual(updatedBook.libraries.count, chatBook.libraries.count, "a change to an existing library doesn't add another")
let updatedSonner = updatedBook.libraries.first { $0.name == "Sonner" }
check(updatedSonner?.purpose == "Better toasts." && updatedSonner?.task == "Toasts" && updatedSonner?.health == "Maintained, 2026.", "an update keeps the task and never writes \"unknown\" over facts")
expectEqual(PlaybookChat.label(sonnerUpdate, in: chatBook), "Update sonner", "a change to a library already there is an update")
expectEqual(PlaybookChat.label(parsedReply.changes[1]), "UI components: shadcn/ui, radix ui, Base UI, SwiftUI", "a stack change is labelled by its question")

let chatTurns = [
    ChatTurn(role: .assistant, text: "Leftover"),
    ChatTurn(role: .user, text: "Which toast library?"),
    ChatTurn(role: .assistant, text: "Sonner.", changes: [PlaybookChange(kind: .habit, habit: "never", text: "x", state: .applied)]),
    ChatTurn(role: .assistant, text: "Timed out", isError: true),
    ChatTurn(role: .user, text: "And drawers?"),
    ChatTurn(role: .user, text: "For React."),
]
let sent = PlaybookChat.history(chatTurns)
expectEqual(sent.map(\.role), [.user, .assistant, .user], "errors are dropped, turns alternate and start with the person")
check(sent[1].text.contains("[Suggested changes: Never do (applied)]"), "the model is told which of its changes were applied")
expectEqual(sent[2].text, "And drawers?\n\nFor React.", "two messages in a row are joined")
check(PlaybookChat.cliPrompt(chatTurns).hasSuffix("The owner's new message:\nAnd drawers?\n\nFor React."), "Claude Code gets the earlier turns, then the new one")
expectEqual(PlaybookChat.cliPrompt([ChatTurn(role: .user, text: "Hi")]), "Hi", "a first message goes as it is")
let chatArguments = PlaybookChat.cliArguments(prompt: "p", instructions: "i")
check(chatArguments.contains("--system-prompt") && chatArguments.contains("--json-schema") && chatArguments.contains("WebSearch,WebFetch"), "the chat runs with its own instructions, the schema and only web tools")
let chatInstructions = PlaybookChat.instructions(playbook: book, scan: scanned, searchesWeb: true, asksForJSON: false)
check(chatInstructions.contains("- ui: UI components.") && chatInstructions.contains("- never: Never do"), "the model sees the question and prompt ids")
check(chatInstructions.contains("- Sonner (Toasts) [verified]") && chatInstructions.contains("- Vaul (Drawers) [draft, avoid for new work]"), "the model sees the playbook as it is")
check(chatInstructions.contains("- Libraries found: Radix UI (1), Sonner (1)") && chatInstructions.contains("- UI components: Radix UI (1), SwiftUI (1), shadcn/ui (1)"), "the model sees what the projects use")
check(!chatInstructions.contains("one JSON object"), "structured output needs no JSON instructions")

let structuredBody = PlaybookChat.anthropicBody(chatTurns, playbook: book, scan: nil, model: "claude-opus-5-5", structured: true)
check(structuredBody["output_config"] != nil && structuredBody["fallbacks"] as? String == "default", "the API request asks for the schema and refusal fallbacks")
let plainBody = PlaybookChat.anthropicBody(chatTurns, playbook: book, scan: nil, model: "claude-sonnet-4-6", structured: false)
check(plainBody["output_config"] == nil && plainBody["fallbacks"] == nil && (plainBody["system"] as? String)?.contains("one JSON object") == true, "the plain request asks for JSON in words")

let chatStore = AIProviderStore(defaults: checkDefaults, keychain: AIKeychain(service: "Graphitree checks \(UUID().uuidString)"))
let ollamaProvider = AICatalog.providers.first { $0.id == "ollama" }!
try chatStore.save(["model": "llama3.3"], for: ollamaProvider)
if case .success(let engine) = ChatEngine.engine(for: "ollama", home: fakeHome, store: chatStore) {
    expectEqual(engine.backend, .openAI(url: "http://localhost:11434/v1/chat/completions", headers: [:], model: "llama3.3"), "Ollama chats through its OpenAI-style server")
} else {
    check(false, "Ollama has a chat engine")
}
let compatible = AICatalog.providers.first { $0.id == "openai-compatible" }!
try chatStore.save(["OPENAI_BASE_URL": "http://localhost:1234/v1/", "model": "qwen"], for: compatible)
if case .success(let engine) = ChatEngine.engine(for: "openai-compatible", home: fakeHome, store: chatStore) {
    expectEqual(engine.backend, .openAI(url: "http://localhost:1234/v1/chat/completions", headers: [:], model: "qwen"), "a trailing slash on the server is handled")
} else {
    check(false, "an OpenAI-compatible server has a chat engine")
}
let bedrock = AICatalog.providers.first { $0.id == "bedrock" }!
try chatStore.save(["AWS_PROFILE": "default", "AWS_REGION": "us-east-1"], for: bedrock)
check((try? ChatEngine.engine(for: "bedrock", home: fakeHome, store: chatStore).get()) == nil, "Bedrock says chat isn't available rather than failing later")
if case .success(let engine) = ChatEngine.resolve(stored: "ollama", home: fakeHome, store: chatStore) {
    expectEqual(engine.id, "ollama", "the chat uses the model Build uses")
} else {
    check(false, "the build model resolves for chat")
}
check((try? ChatEngine.resolve(stored: BuildChoice.codeOnly, home: fakeHome, store: chatStore).get()) != nil, "code only still chats with the first model that's set up")
check((try? ChatEngine.resolve(stored: BuildChoice.automatic, home: fakeHome, store: AIProviderStore(defaults: checkSuite("empty"), keychain: chatStore.keychain)).get()) == nil || ToolLocator.command(["claude"], home: fakeHome) != nil, "with no model set up, chat asks for one")

// MARK: - Folders

expectEqual(SourcePath.project(of: "clients/acme/src/a.ts", groups: ["clients"]), "clients/acme", "any labelled group holds projects")
expectEqual(SourcePath.project(of: "work/notes.md"), "work", "a file loose in a group belongs to the group")
expectEqual(ProjectScheme(singleRepoName: nil).area(ofProject: "work/one"), FolderArea(name: "Work", purpose: .work), "without labels, group folders are areas")
check(ProjectScheme(singleRepoName: nil).area(ofProject: "AI-Interview") == nil, "without labels, a top-level project is Other")
let labelledScheme = ProjectScheme(singleRepoName: nil, groups: ["work"], areas: FolderMap(folders: [
    FolderLabel(path: "work", purpose: .work, holdsProjects: true),
    FolderLabel(path: "AI-Interview", purpose: .work),
    FolderLabel(path: "acme", purpose: .client, name: "Acme Ltd"),
]).areasByFolder)
expectEqual(labelledScheme.area(ofProject: "AI-Interview")?.name, "Work", "a work repo outside the group joins the Work area")
expectEqual(labelledScheme.area(ofProject: "acme")?.name, "Acme Ltd", "a client keeps its own name")
check(labelledScheme.area(ofProject: "personal/x") == nil, "with labels, unlabelled folders are Other")
expectEqual(FolderPurpose.personal.colorSlot, 0, "personal keeps its colour")
expectEqual(FolderPurpose.work.colorSlot, 1, "work keeps its colour")
expectEqual(RepoInfo(path: "a", remote: "https://github.com/acme/demo-app.git", lastActive: nil, hasOwnCommits: nil).remoteOwner, "acme", "the owner is read from an https remote")
expectEqual(RepoInfo(path: "a", remote: "git@github.com:someone/thing.git", lastActive: nil, hasOwnCommits: nil).remoteOwner, "someone", "the owner is read from an ssh remote")
expectEqual(TidyTips.normalisedRemote("git@github.com:A/B.git"), TidyTips.normalisedRemote("https://github.com/a/b"), "ssh and https clones of one repo match")
expectEqual(TidyTips.likelyHome(of: "oms-erd-draft.pdf", projects: ["personal/shop-oms", "work/omni"]), "personal/shop-oms", "a loose file's name points at its project")
check(TidyTips.likelyHome(of: "notes.txt", projects: ["personal/shop-oms"]) == nil, "a file with no matching project has no home")

let folderRoot = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-folders-\(UUID().uuidString)").path
func folderGit(_ path: String, _ arguments: [String], author: String = "Tester") throws {
    let full = (folderRoot as NSString).appendingPathComponent(path)
    try FileManager.default.createDirectory(atPath: full, withIntermediateDirectories: true)
    _ = try ProcessRunner.run("/usr/bin/git", ["-C", full, "-c", "user.name=\(author)", "-c", "user.email=\(author.lowercased())@example.com", "-c", "commit.gpgsign=false"] + arguments)
}
func makeRepo(_ path: String, author: String = "Tester", remote: String? = nil) throws {
    try folderGit(path, ["init", "-q"], author: author)
    try "x".write(toFile: (folderRoot as NSString).appendingPathComponent(path + "/a.txt"), atomically: true, encoding: .utf8)
    try folderGit(path, ["add", "."], author: author)
    try folderGit(path, ["commit", "-q", "-m", "first"], author: author)
    if let remote { try folderGit(path, ["remote", "add", "origin", remote], author: author) }
}
try makeRepo("work/shop", remote: "https://github.com/me/shop.git")
try makeRepo("work/shop-copy", remote: "git@github.com:me/shop.git")
try makeRepo("personal/shop-oms")
try makeRepo("personal/old-game")
try makeRepo("demo", author: "Somebody", remote: "https://github.com/someone/demo.git")
try makeRepo("AI-Interview")
try FileManager.default.createDirectory(atPath: (folderRoot as NSString).appendingPathComponent("graphify-out"), withIntermediateDirectories: true)
try "pdf".write(toFile: (folderRoot as NSString).appendingPathComponent("oms-erd-draft.pdf"), atomically: true, encoding: .utf8)
try "txt".write(toFile: (folderRoot as NSString).appendingPathComponent("random.txt"), atomically: true, encoding: .utf8)
let longAgo = Date().addingTimeInterval(-400 * 24 * 3600)
for file in [".git/logs/HEAD", ".git/index", ".git/HEAD"] {
    try? FileManager.default.setAttributes([.modificationDate: longAgo], ofItemAtPath: (folderRoot as NSString).appendingPathComponent("personal/old-game/" + file))
}
let folderScan = FolderScan.scan(root: folderRoot, identity: ["Tester", "tester@example.com"])
expectEqual(folderScan.folders.map(\.path), ["AI-Interview", "demo", "personal", "work"], "main folders are found, graphify-out isn't one")
expectEqual(folderScan.looseFiles.sorted(), ["oms-erd-draft.pdf", "random.txt"], "loose files at the top are found")
expectEqual(folderScan.folders.first { $0.path == "work" }?.children.map(\.path), ["work/shop", "work/shop-copy"], "a group's repos are found")
expectEqual(folderScan.folders.first { $0.path == "demo" }?.repo?.hasOwnCommits, false, "a repo with no commits from the person is noticed")
expectEqual(folderScan.folders.first { $0.path == "AI-Interview" }?.repo?.hasOwnCommits, true, "the person's own repo is theirs")
expectEqual(FolderScan.detectedGroups(root: folderRoot), ["personal", "work"], "folders holding repos are groups")

let suggested = FolderScan.labels(saved: nil, scan: folderScan)
expectEqual(suggested.map(\.path), ["personal", "work", "AI-Interview", "demo"], "groups come first, then the rest by name")
let workLabel = suggested.first { $0.path == "work" }
check(workLabel?.purpose == .work && workLabel?.holdsProjects == true && workLabel?.isIncluded == true, "work/ is suggested as a Work group")
let demoLabel = suggested.first { $0.path == "demo" }
check(demoLabel?.purpose == .reference && demoLabel?.isIncluded == false, "someone else's repo is suggested as Reference, left out")
var savedFolders = FolderMap(folders: suggested)
savedFolders.folders[savedFolders.folders.firstIndex { $0.path == "AI-Interview" }!].note = "HR interviews for work"
expectEqual(FolderScan.labels(saved: savedFolders, scan: folderScan).first { $0.path == "AI-Interview" }?.note, "HR interviews for work", "saved labels win over suggestions")

let folderTips = TidyTips.tips(scan: folderScan, labels: suggested.map { label in var l = label; if l.path == "demo" { l.purpose = .other; l.isIncluded = true }; return l }, ignored: [])
let tipIDs = Set(folderTips.map(\.id))
check(tipIDs.contains("loose:personal/shop-oms") && tipIDs.contains("loose"), "loose files are grouped by where they belong")
check(folderTips.contains { $0.id == "loose:personal/shop-oms" && $0.action == .move(paths: ["oms-erd-draft.pdf"], destinations: ["personal/shop-oms", "personal", "work"]) }, "a loose file's tip offers its project first, and never someone's repo")
try "copy".write(toFile: (folderRoot as NSString).appendingPathComponent("personal/shop-oms/oms-erd-draft.pdf"), atomically: true, encoding: .utf8)
check(TidyTips.tips(scan: folderScan, labels: suggested, ignored: [], root: folderRoot).first { $0.id == "copies:personal/shop-oms" }?.action == .reveal(paths: ["oms-erd-draft.pdf"]), "a loose file that's already in its project is shown as a copy, never moved or deleted")
try FileManager.default.removeItem(atPath: (folderRoot as NSString).appendingPathComponent("personal/shop-oms/oms-erd-draft.pdf"))
expectEqual(FolderScan.suggestedLabel(for: FolderInfo(path: "playbook", repo: nil, children: [], lastActive: nil)).name, "Playbook", "Graphitree's playbook copy is recognised")
check(folderTips.contains { $0.id == "others:demo" && $0.action == .label(path: "demo", purpose: .reference) }, "someone else's repo gets a Reference tip")
check(folderTips.contains { $0.id == "stale-in:personal" && $0.action == .leaveOut(paths: ["personal/old-game"]) }, "a project untouched for a year can be left out")
check(folderTips.contains { $0.id.hasPrefix("twice:") && $0.action == .leaveOut(paths: ["work/shop-copy"]) }, "the same repo cloned twice is noticed")
check(folderTips.contains { $0.id == "outside:AI-Interview" }, "a repo outside the groups gets a move tip")
let quietTips = TidyTips.tips(scan: folderScan, labels: suggested, ignored: [FolderIgnore.line(for: "personal/old-game"), FolderIgnore.line(for: "work/shop-copy")])
check(!quietTips.contains { $0.id == "others:demo" } && !quietTips.contains { $0.id == "stale-in:personal" }, "labelled and left-out folders get no more tips")

let ignoreChanges = FolderIgnore.changes(for: [FolderLabel(path: "demo", purpose: .reference, isIncluded: false), FolderLabel(path: "work", purpose: .work)])
expectEqual(ignoreChanges.add, ["/demo/"], "a left-out folder gets an ignore line")
expectEqual(ignoreChanges.remove, ["/work/"], "an included folder loses its ignore line")
expectEqual(IgnoreFile.removing(["/work/"], from: "# note\n/work/\ndist/\n"), "# note\ndist/\n", "removing a line keeps the rest")

let folderOut = URL(fileURLWithPath: (folderRoot as NSString).appendingPathComponent("graphify-out"))
let moved = try FolderMoves.move("oms-erd-draft.pdf", into: "personal/shop-oms", root: folderRoot, log: folderOut)
expectEqual(moved.to, "personal/shop-oms/oms-erd-draft.pdf", "a move is recorded with its new place")
check(FileManager.default.fileExists(atPath: (folderRoot as NSString).appendingPathComponent("personal/shop-oms/oms-erd-draft.pdf")), "the file moved")
try "again".write(toFile: (folderRoot as NSString).appendingPathComponent("oms-erd-draft.pdf"), atomically: true, encoding: .utf8)
check((try? FolderMoves.move("oms-erd-draft.pdf", into: "personal/shop-oms", root: folderRoot, log: folderOut)) == nil, "a move never replaces a file")
try FileManager.default.removeItem(atPath: (folderRoot as NSString).appendingPathComponent("oms-erd-draft.pdf"))
let undone = try FolderMoves.undoLast(root: folderRoot, log: folderOut)
check(undone?.from == moved.from && undone?.to == moved.to && FileManager.default.fileExists(atPath: (folderRoot as NSString).appendingPathComponent("oms-erd-draft.pdf")), "the last move can be undone")
expectEqual(FolderMoves.load(from: folderOut), [], "an undone move leaves the log")

try FolderFile.save(FolderMap(folders: suggested), to: folderOut)
expectEqual(FolderFile.load(from: folderOut)?.folders, suggested, "labels save and reload")
let labelledSource = GraphSource(outDirectory: folderOut)
expectEqual(labelledSource.scheme.groups, ["personal", "work"], "saved labels decide the groups")
expectEqual(labelledSource.scheme.area(ofProject: "demo")?.purpose, .reference, "saved labels decide the areas")

let sliceGraph = folderOut.appendingPathComponent("graph.json")
try #"{"directed":false,"nodes":[{"id":"a","source_file":"work/shop/a.ts"},{"id":"b","source_file":"work/shop/b.ts"},{"id":"c","source_file":"personal/shop-oms/c.ts"},{"id":"d","source_file":"workshop/d.ts"}],"links":[{"source":"a","target":"b"},{"source":"a","target":"c"}],"hyperedges":[{"nodes":["a","b","c"]},{"nodes":["a","c"]}]}"#.write(to: sliceGraph, atomically: true, encoding: .utf8)
try FileManager.default.createDirectory(at: folderOut.appendingPathComponent(FolderSlices.folderName), withIntermediateDirectories: true)
try "{}".write(to: folderOut.appendingPathComponent("folders/old-folder.json"), atomically: true, encoding: .utf8)
let sliceCounts = try FolderSlices.write(graph: sliceGraph, outDirectory: folderOut, folders: ["work", "personal"])
expectEqual(sliceCounts, ["work": 2, "personal": 1], "each folder's slice holds only its own nodes, not a lookalike folder's")
let workSlice = try JSONSerialization.jsonObject(with: Data(contentsOf: FolderSlices.url(for: "work", outDirectory: folderOut))) as? [String: Any]
expectEqual((workSlice?["links"] as? [[String: Any]])?.count, 1, "links leaving the folder are dropped")
expectEqual((workSlice?["hyperedges"] as? [[String: Any]])?.count, 1, "groups keep only members inside the folder")
check(!FileManager.default.fileExists(atPath: folderOut.appendingPathComponent("folders/old-folder.json").path), "slices for folders no longer kept are removed")
check(GraphCatalog.mapped([folderRoot], excluding: []).first?.name == (folderRoot as NSString).lastPathComponent, "a mapped folder shows in the graph list by its name")
check(GraphCatalog.mapped([folderRoot], excluding: [folderOut.standardizedFileURL.path]).isEmpty, "a graph already listed isn't listed twice")
try? FileManager.default.removeItem(atPath: folderRoot)

let guideOut = sceneWorkspace.source.outDirectory
try FolderFile.save(FolderMap(folders: [
    FolderLabel(path: "work", purpose: .work, note: "Client work for a shop", holdsProjects: true),
    FolderLabel(path: "personal", purpose: .personal, holdsProjects: true),
    FolderLabel(path: "demo", purpose: .reference, isIncluded: false),
]), to: guideOut)
try FolderSlices.write(graph: sceneWorkspace.source.graphURL, outDirectory: guideOut, folders: ["work", "personal"])
let guideWithFolders = try sceneWorkspace.agentGuideText(findings: guideSnapshot.findings, overview: guideSnapshot.overview, clean: .notWritten)
check(guideWithFolders.contains("## Folders"), "labelled folders get a section in the guide")
check(guideWithFolders.contains("- `work/` (Work): Client work for a shop. Each subfolder is a project. Graph: `"), "a folder's note, groups and slice are in the guide")
check(guideWithFolders.contains("- `demo/` (Reference): Someone else's code. Read it for reference only") && guideWithFolders.contains("Left out of the graph."), "reference folders are explained and marked left out")
for name in [FolderFile.fileName, FolderSlices.folderName] { try? FileManager.default.removeItem(at: guideOut.appendingPathComponent(name)) }
// MARK: - Keeping fresh

let pendingDocs = DocsEstimate(files: [
    PendingDoc(path: "/r/personal/a/README.md", kind: "document", tokens: 30_000),
    PendingDoc(path: "/r/personal/a/docs/b.md", kind: "document", tokens: 10_000),
    PendingDoc(path: "/r/work/c/spec.pdf", kind: "paper", tokens: 20_000),
], cached: 2, code: 40, chunks: 2)
expectEqual(pendingDocs.contentTokens, 60_000, "an estimate adds up graphify's own per-file counts")
expectEqual(pendingDocs.byProject(root: "/r", scheme: ProjectScheme(singleRepoName: nil)).map(\.project), ["personal/a", "work/c"], "the most expensive projects come first")
let plainCost = DocsCost.estimate(pendingDocs, backend: "claude-cli")
expectEqual(plainCost.inputTokens, 60_000 + 2 * 45_000, "Claude Code's own context is counted once per call")
check(DocsCost.estimate(pendingDocs, backend: "openai").inputTokens < plainCost.inputTokens, "API backends cost less per call")
expectEqual(DocsCost.estimate(DocsEstimate(), backend: "claude-cli"), DocsCost(inputTokens: 0, outputTokens: 0, minutes: 0), "nothing to read costs nothing")
let pastRun = DocsRun(date: .now, backend: "claude-cli", files: 3, estimatedInput: 100_000, actualInput: 200_000, actualOutput: 50_000, seconds: 600)
expectEqual(DocsCost.estimate(pendingDocs, backend: "claude-cli", history: [pastRun]).inputTokens, 2 * plainCost.inputTokens, "past passes that cost double make the next estimate double")
expectEqual(DocsCost.estimate(pendingDocs, backend: "openai", history: [pastRun]).inputTokens, DocsCost.estimate(pendingDocs, backend: "openai").inputTokens, "another backend's history doesn't count")
expectEqual(plainCost.minutes, 2 * 8 + 3, "Claude Code's calls run one after another")
expectEqual(DocsCost.estimate(pendingDocs, backend: "openai").minutes, 1 * 3 + 3, "API calls run up to four at once")
expectEqual(DocsCost.estimate(pendingDocs, backend: "claude-cli", history: [pastRun]).minutes, 10, "a finished pass's pace per file sets the time: 200 s a file, 3 files")
let cancelledRun = DocsRun(date: .now, backend: "claude-cli", files: 300, estimatedInput: 100_000, actualInput: nil, actualOutput: nil, seconds: 60)
expectEqual(DocsCost.estimate(pendingDocs, backend: "claude-cli", history: [cancelledRun]).minutes, plainCost.minutes, "a pass that never finished doesn't set the pace")
expectEqual(DocsCost(inputTokens: 0, outputTokens: 0, minutes: 75).duration, "75 minutes", "under an hour and a half reads in minutes")
expectEqual(DocsCost(inputTokens: 0, outputTokens: 0, minutes: 436).duration, "7.5 hours", "longer reads in half hours")
expectEqual(DocsCost(inputTokens: 0, outputTokens: 0, minutes: 400).duration, "6.5 hours", "400 minutes rounds to the nearest half hour")
expectEqual(DocsCost(inputTokens: 0, outputTokens: 0, minutes: 120).duration, "2 hours", "whole hours drop the decimal")
let quietStart = Date(timeIntervalSince1970: 0)
let quiet = GraphRebuilder.QuietClock(start: quietStart)
check(quiet.minutesToReport(at: quietStart.addingTimeInterval(150)) == nil, "two quiet minutes say nothing")
expectEqual(quiet.minutesToReport(at: quietStart.addingTimeInterval(190)), 3, "three quiet minutes are reported")
check(quiet.minutesToReport(at: quietStart.addingTimeInterval(250)) == nil, "the same quiet stretch isn't reported every minute")
expectEqual(quiet.minutesToReport(at: quietStart.addingTimeInterval(370)), 6, "it reports again three minutes later")
quiet.heard(at: quietStart.addingTimeInterval(400))
check(quiet.minutesToReport(at: quietStart.addingTimeInterval(500)) == nil, "graphify's output starts the clock again")
expectEqual(BuildChoice.environment(forCodingBackend: "claude-cli")["GRAPHIFY_API_TIMEOUT"], "1800", "Claude Code calls get 30 minutes before graphify gives up on them")
check(BuildChoice.environment(forCodingBackend: "codex").isEmpty, "other coding tools keep graphify's defaults")
check(DocsRunLog.reportedTokens(in: "chunk 4/4 done\n[graphify extract] tokens: 917,683 in / 256,092 out, est. cost") ?? (0, 0) == (917_683, 256_092), "graphify's reported tokens are read from its log")
check(DocsRunLog.reportedTokens(in: "no tokens here") == nil, "a log without a count has none")
let runLogURL = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-runs-\(UUID().uuidString).json")
for _ in 0..<55 { DocsRunLog.append(pastRun, to: runLogURL) }
expectEqual(DocsRunLog.load(from: runLogURL).count, 50, "the run log keeps the last fifty passes")
try? FileManager.default.removeItem(at: runLogURL)

var gmt = Calendar(identifier: .gregorian)
gmt.timeZone = TimeZone(identifier: "UTC")!
func utc(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
var nightly = FreshnessSettings(docs: .nightly, hour: 2)
check(nightly.isDocsPassDue(now: utc("2026-11-13T10:00:00Z"), calendar: gmt), "a nightly pass that never ran is due")
nightly.lastDocsPass = utc("2026-11-13T02:05:00Z")
check(!nightly.isDocsPassDue(now: utc("2026-11-13T10:00:00Z"), calendar: gmt), "after tonight's pass, nothing is due until tomorrow")
check(nightly.isDocsPassDue(now: utc("2026-11-14T02:00:30Z"), calendar: gmt), "the next night's slot makes it due again")
nightly.lastDocsPass = utc("2026-11-10T02:00:00Z")
expectEqual(nightly.lastSlot(before: utc("2026-11-13T01:00:00Z"), calendar: gmt), utc("2026-11-12T02:00:00Z"), "a slot missed while the Mac slept is caught up")
let weekly = FreshnessSettings(docs: .weekly, hour: 9, weekday: 2, lastDocsPass: utc("2026-11-09T09:30:00Z"))
check(!weekly.isDocsPassDue(now: utc("2026-11-13T10:00:00Z"), calendar: gmt), "a weekly pass waits a week")
check(weekly.isDocsPassDue(now: utc("2026-11-16T09:01:00Z"), calendar: gmt), "the next Monday it's due")
check(!FreshnessSettings().isDocsPassDue(now: .now), "with no schedule, nothing is ever due")
let freshDefaults = checkSuite("fresh")
var savedFreshness = FreshnessSettings(updatesCodeOnChange: true, docs: .weekly, askAboveTokens: 500_000)
savedFreshness.save(freshDefaults)
expectEqual(FreshnessSettings.load(freshDefaults), savedFreshness, "freshness settings save and reload")

check(ChangeFilter.matters("/r/personal/a/src/x.ts", root: "/r"), "a code change matters")
check(!ChangeFilter.matters("/r/graphify-out/graph.json", root: "/r"), "graphify's own output doesn't")
check(!ChangeFilter.matters("/r/personal/a/node_modules/y/index.js", root: "/r"), "installed packages don't")
check(!ChangeFilter.matters("/r/personal/a/.git/index", root: "/r") && !ChangeFilter.matters("/r/.DS_Store", root: "/r"), "git and hidden files don't")
check(!ChangeFilter.matters("/elsewhere/a.ts", root: "/r"), "changes outside the root don't")

let agentArguments = UpdateAgent.arguments(cli: "/Applications/Graphitree.app/Contents/MacOS/graphitree-cli", graphify: "/Users/a b/.local/bin/graphify", root: "/Users/a b/Documents/GitHub")!
let agentText = UpdateAgent.plist(arguments: agentArguments, home: "/Users/a b")
let agentPlist = try PropertyListSerialization.propertyList(from: Data(agentText.utf8), format: nil) as? [String: Any]
expectEqual(agentPlist?["Label"] as? String, UpdateAgent.label, "the background job is a valid property list")
expectEqual(agentPlist?["ProgramArguments"] as? [String], ["/Applications/Graphitree.app/Contents/MacOS/graphitree-cli", "background", "--update", "/Users/a b/Documents/GitHub"], "the job runs Graphitree's command itself, so macOS asks about Documents for it and not for the shell")
expectEqual(UpdateAgent.arguments(cli: "/x/graphitree-cli", graphify: nil, root: nil), ["/x/graphitree-cli", "background"], "backups alone run without an update")
let shellOnly = UpdateAgent.arguments(cli: nil, graphify: "/Users/a b/.local/bin/graphify", root: "/Users/a b/Documents/GitHub")
check(shellOnly?.last?.hasPrefix("pgrep -f 'graphify (update|extract|label)' >/dev/null ||") == true && shellOnly?.last?.hasSuffix("update '/Users/a b/Documents/GitHub'") == true, "without the command line, the job updates through the shell, waiting for a busy graphify and quoting paths with spaces")
check(UpdateAgent.arguments(cli: nil, graphify: nil, root: nil) == nil, "with nothing to do there's no job")
expectEqual(agentPlist?["StartInterval"] as? Int, UpdateAgent.interval, "the job runs every few hours")
let jobHome = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-agent-\(UUID().uuidString)").path
try FileManager.default.createDirectory(atPath: jobHome + "/Library/LaunchAgents", withIntermediateDirectories: true)
try agentText.write(to: UpdateAgent.plistURL(home: jobHome), atomically: true, encoding: .utf8)
expectEqual(UpdateAgent.installedArguments(home: jobHome), agentArguments, "the installed job's arguments read back")
expectEqual(UpdateAgent.installedRoot(home: jobHome), "/Users/a b/Documents/GitHub", "and so does the root it updates")
try UpdateAgent.plist(arguments: shellOnly!, home: jobHome).write(to: UpdateAgent.plistURL(home: jobHome), atomically: true, encoding: .utf8)
expectEqual(UpdateAgent.installedRoot(home: jobHome), "/Users/a b/Documents/GitHub", "an older shell job's root reads back from its command")
try? FileManager.default.removeItem(atPath: jobHome)

// The watcher reports real file changes.
let watchedRoot = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-watch-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: watchedRoot.appendingPathComponent("personal/app"), withIntermediateDirectories: true)
let sawChange = DispatchSemaphore(value: 0)
let changeLock = NSLock()
var changedPaths: [String] = []
let watcher = FolderWatcher(root: watchedRoot.path, latency: 0.5) { paths in
    changeLock.lock()
    changedPaths += paths
    changeLock.unlock()
    if paths.contains(where: { ChangeFilter.matters($0, root: watchedRoot.path) }) { sawChange.signal() }
}
Thread.sleep(forTimeInterval: 1)
try "export const b = 2\n".write(to: watchedRoot.appendingPathComponent("personal/app/b.ts"), atomically: true, encoding: .utf8)
let watchResult = sawChange.wait(timeout: .now() + 15)
if watchResult != .success { changeLock.lock(); print("watcher saw:", changedPaths.prefix(5), "root:", watchedRoot.path); changeLock.unlock() }
check(watchResult == .success, "the watcher notices a code change")
watcher.stop()
try? FileManager.default.removeItem(at: watchedRoot)

// The probe runs graphify's own code, so it's checked against the installed graphify.
let graphifyLauncher = FileManager.default.homeDirectoryForCurrentUser.path + "/.local/bin/graphify"
if let head = try? String(contentsOfFile: graphifyLauncher, encoding: .utf8).split(separator: "\n").first, head.hasPrefix("#!") {
    let python = String(head.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    let probeRoot = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-probe-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: probeRoot.appendingPathComponent("notes"), withIntermediateDirectories: true)
    try String(repeating: "A design note about toasts and drawers. ", count: 200).write(to: probeRoot.appendingPathComponent("notes/design.md"), atomically: true, encoding: .utf8)
    try "export const a = 1\n".write(to: probeRoot.appendingPathComponent("notes/a.ts"), atomically: true, encoding: .utf8)
    do {
        let probed = try DocsEstimator.run(python: python, root: probeRoot.path, outDirectory: probeRoot.appendingPathComponent("graphify-out"))
        expectEqual(probed.files.map { ($0.path as NSString).lastPathComponent }, ["design.md"], "graphify's own rules pick the doc, not the code")
        check(probed.code == 1 && probed.chunks == 1 && probed.contentTokens > 1_000, "the probe counts code, chunks and tokens")
    } catch {
        check(false, "the docs probe runs on the installed graphify: \(error.localizedDescription)")
    }
    try? FileManager.default.removeItem(at: probeRoot)
}

// MARK: - Picks, the command line and MCP

var pickBook = Playbook()
pickBook.libraries = [
    PlaybookLibrary(name: "Sonner", task: "Toasts", purpose: "An opinionated toast component for React.", verified: true),
    PlaybookLibrary(name: "Vaul", task: "Drawers", purpose: "A drawer for React, mainly mobile bottom sheets.", health: "Unmaintained."),
    PlaybookLibrary(name: "cmdk", task: "Command menu", purpose: "A command palette for React."),
    PlaybookLibrary(name: "React Hook Form", task: "Forms", purpose: "Performant forms with easy validation."),
]
pickBook.stack["web"] = StackAnswer(choices: ["Vite + React"])
pickBook.habits["never"] = "Don't add dependencies silently."
check(PlaybookPicks.terms(for: "toast notifications").contains("snackbar"), "a job's synonyms are searched too")
expectEqual(PlaybookPicks.find("notifications", in: pickBook).first?.library.name, "Sonner", "\"notifications\" finds the toast library")
expectEqual(PlaybookPicks.find("command palette", in: pickBook).first?.library.name, "cmdk", "\"command palette\" finds the command menu")
expectEqual(PlaybookPicks.find("form validation", in: pickBook).first?.library.name, "React Hook Form", "\"form validation\" finds the forms library")
expectEqual(PlaybookPicks.find("bottom sheet", in: pickBook).first?.library.name, "Vaul", "a library to avoid is still found")
check(PlaybookPicks.answer("bottom sheet", in: pickBook).contains("avoid for new work") && PlaybookPicks.answer("bottom sheet", in: pickBook).contains("Ask the owner before picking a replacement"), "a pick to avoid says so, and to ask first")
check(PlaybookPicks.find("payments", in: pickBook).isEmpty && PlaybookPicks.answer("payments", in: pickBook).contains("no pick for \"payments\""), "a job with no pick says so and lists what's covered")
check(PlaybookPicks.answer("toasts", in: pickBook).hasPrefix("Sonner (Toasts)\n"), "a verified pick has no draft mark")
check(PlaybookPicks.stackText(pickBook).contains("- Web framework: Vite + React"), "the stack reads as a list")
check(PlaybookPicks.habitsText(pickBook).contains("Never do:\nDon't add dependencies silently."), "how the owner works reads under each prompt")

let toolsOut = sceneWorkspace.source.outDirectory
try PlaybookFile.save(pickBook, to: toolsOut)
let graphitreeTools = GraphitreeTools(source: sceneWorkspace.source, cwd: "/")
let server = MCPServer(tools: graphitreeTools)
let initReply = server.handle(line: #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{}}}"#)
check(initReply?.contains(#""protocolVersion":"2025-03-26""#) == true && initReply?.contains(#""name":"graphitree""#) == true, "the server agrees the client's protocol version")
check(server.handle(line: #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil, "notifications get no answer")
check(server.handle(line: #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)?.contains(#""name":"find_pick""#) == true, "tools are listed")
let pickReply = server.handle(["jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": ["name": "find_pick", "arguments": ["job": "snackbar"]]])
let pickContent = ((pickReply?["result"] as? [String: Any])?["content"] as? [[String: Any]])?.first?["text"] as? String
check(pickContent?.hasPrefix("Sonner") == true && (pickReply?["result"] as? [String: Any])?["isError"] as? Bool == false, "find_pick answers through MCP")
let missingArgument = server.handle(["jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": ["name": "find_pick", "arguments": [:]]])
expectEqual((missingArgument?["result"] as? [String: Any])?["isError"] as? Bool, true, "a missing argument is a tool error, not a crash")
expectEqual((server.handle(["jsonrpc": "2.0", "id": 5, "method": "nope"])?["error"] as? [String: Any])?["code"] as? Int, -32601, "unknown methods are refused")
check(server.handle(line: "not json")?.contains("-32700") == true, "bad JSON gets a parse error")
check((try? graphitreeTools.graphPath(folder: "nowhere", wholeGraph: false)) == nil, "asking a folder with no graph explains itself")
let wholeGraph = try graphitreeTools.graphPath(folder: nil, wholeGraph: true)
check(wholeGraph == sceneWorkspace.source.graphURL.path || wholeGraph == sceneWorkspace.cleanURL.path, "without a folder, questions go to the whole graph, clean when it's current")
for name in [PlaybookFile.markdownName, PlaybookFile.jsonName] { try? FileManager.default.removeItem(at: toolsOut.appendingPathComponent(name)) }

let locatorRoot = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-locate-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: locatorRoot.appendingPathComponent("graphify-out"), withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: locatorRoot.appendingPathComponent("work/app/src"), withIntermediateDirectories: true)
try "{}".write(to: locatorRoot.appendingPathComponent("graphify-out/graph.json"), atomically: true, encoding: .utf8)
expectEqual(GraphLocator.outDirectory(cwd: locatorRoot.appendingPathComponent("work/app/src").path)?.standardizedFileURL, locatorRoot.appendingPathComponent("graphify-out").standardizedFileURL, "the nearest graph above the working folder is used")
expectEqual(GraphLocator.outDirectory(explicit: locatorRoot.path)?.standardizedFileURL, locatorRoot.appendingPathComponent("graphify-out").standardizedFileURL, "--graph accepts the folder that holds graphify-out")
try FolderFile.save(FolderMap(folders: [FolderLabel(path: "work", purpose: .work, holdsProjects: true)]), to: locatorRoot.appendingPathComponent("graphify-out"))
try FileManager.default.createDirectory(at: locatorRoot.appendingPathComponent("graphify-out/folders"), withIntermediateDirectories: true)
try "{}".write(to: locatorRoot.appendingPathComponent("graphify-out/folders/work.json"), atomically: true, encoding: .utf8)
let locatedSource = GraphSource(outDirectory: locatorRoot.appendingPathComponent("graphify-out"))
expectEqual(GraphLocator.slice(for: locatorRoot.appendingPathComponent("work/app").path, source: locatedSource)?.folder, "work", "inside a labelled folder, its slice is used")
check(GraphLocator.slice(for: locatorRoot.path, source: locatedSource) == nil, "at the root, the whole graph is used")
try? FileManager.default.removeItem(at: locatorRoot)

let commandHome = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-cmd-\(UUID().uuidString)").path
try CommandLineTool.link(to: "/Applications/Graphitree.app/Contents/MacOS/graphitree-cli", home: commandHome)
expectEqual(CommandLineTool.linkTarget(home: commandHome), "/Applications/Graphitree.app/Contents/MacOS/graphitree-cli", "the command is linked into ~/.local/bin")
try CommandLineTool.link(to: "/elsewhere/graphitree-cli", home: commandHome)
expectEqual(CommandLineTool.linkTarget(home: commandHome), "/elsewhere/graphitree-cli", "linking again points at the new copy")
CommandLineTool.unlink(home: commandHome)
check(CommandLineTool.linkTarget(home: commandHome) == nil, "the link can be removed")
try "#!/bin/sh\n".write(toFile: CommandLineTool.linkPath(home: commandHome), atomically: true, encoding: .utf8)
check((try? CommandLineTool.link(to: "/x/graphitree-cli", home: commandHome)) == nil, "someone else's graphitree command is never replaced")
try? FileManager.default.removeItem(atPath: commandHome)

var commandGuide = AgentGuide.Inputs(root: "/r", graphPath: "/r/graphify-out/graph.json", isCleanGraph: false, builtAt: .now, visibleNodes: 1, projects: [], otherProjects: 0, traps: [], generatedAt: .now)
commandGuide.playbookPath = "/r/graphify-out/PLAYBOOK.md"
commandGuide.playbookSummary = ["- Toasts: Sonner"]
check(!AgentGuide.text(commandGuide).contains("graphitree pick"), "without the command, the guide doesn't mention it")
commandGuide.hasCommand = true
check(AgentGuide.text(commandGuide).contains("`graphitree pick <job>`") && AgentGuide.text(commandGuide).contains("`graphitree ask \"<the task>\"`"), "with the command, the guide offers it")
check(AgentGuide.text(commandGuide).contains("Graphitree's MCP tools"), "the guide names Graphitree's MCP tools")

// MARK: - Pointers in repos

let pointerRepo = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-pointer-\(UUID().uuidString)").path
try FileManager.default.createDirectory(atPath: pointerRepo, withIntermediateDirectories: true)
let pointerBlock = RepoPointer.block(playbook: pickBook, folder: FolderLabel(path: "work", purpose: .work, note: "Client work for a shop"), hasCommand: true)
check(pointerBlock.hasPrefix(RepoPointer.startMarker) && pointerBlock.hasSuffix(RepoPointer.endMarker), "the pointer is marked so it can be found again")
check(pointerBlock.contains("This repo is in the owner's Work folder: Client work for a shop.") && pointerBlock.contains("- Toasts: Sonner") && pointerBlock.contains("`graphitree pick <job>`"), "the pointer carries the folder's purpose, the picks and the command")
expectEqual(RepoPointer.targetFile(repo: pointerRepo), pointerRepo + "/AGENTS.md", "a repo without instructions gets AGENTS.md")
try "# Claude\nRules.\n".write(toFile: pointerRepo + "/CLAUDE.md", atomically: true, encoding: .utf8)
expectEqual(RepoPointer.targetFile(repo: pointerRepo), pointerRepo + "/CLAUDE.md", "a repo with only CLAUDE.md gets it there")
try "# Agents\nOur rules.\n".write(toFile: pointerRepo + "/AGENTS.md", atomically: true, encoding: .utf8)
expectEqual(RepoPointer.targetFile(repo: pointerRepo), pointerRepo + "/AGENTS.md", "AGENTS.md wins when both exist")
expectEqual(RepoPointer.status(repo: pointerRepo, block: pointerBlock), .none, "no pointer at first")
try RepoPointer.write(pointerBlock, repo: pointerRepo)
let withPointer = try String(contentsOfFile: pointerRepo + "/AGENTS.md", encoding: .utf8)
check(withPointer.hasPrefix("# Agents\nOur rules.\n\n" + RepoPointer.startMarker), "the pointer goes after what's there")
expectEqual(RepoPointer.status(repo: pointerRepo, block: pointerBlock), .current, "a fresh pointer is current")
let laterBlock = RepoPointer.block(playbook: Playbook(), folder: nil, hasCommand: false)
expectEqual(RepoPointer.status(repo: pointerRepo, block: laterBlock), .outdated, "a changed playbook makes the pointer out of date")
try RepoPointer.write(laterBlock, repo: pointerRepo)
let updatedPointer = try String(contentsOfFile: pointerRepo + "/AGENTS.md", encoding: .utf8)
check(updatedPointer.components(separatedBy: RepoPointer.startMarker).count == 2 && !updatedPointer.contains("Sonner"), "updating replaces the block instead of adding another")
try RepoPointer.remove(repo: pointerRepo)
expectEqual(try String(contentsOfFile: pointerRepo + "/AGENTS.md", encoding: .utf8), "# Agents\nOur rules.\n", "removing leaves the file as it was")
expectEqual(try String(contentsOfFile: pointerRepo + "/CLAUDE.md", encoding: .utf8), "# Claude\nRules.\n", "the other file is never touched")
try FileManager.default.removeItem(atPath: pointerRepo + "/AGENTS.md")
try FileManager.default.removeItem(atPath: pointerRepo + "/CLAUDE.md")
try RepoPointer.write(pointerBlock, repo: pointerRepo)
try RepoPointer.remove(repo: pointerRepo)
check(!FileManager.default.fileExists(atPath: pointerRepo + "/AGENTS.md"), "an AGENTS.md Graphitree created is removed with its pointer")
try? FileManager.default.removeItem(atPath: pointerRepo)

// MARK: - Sessions, insights and learning

let sessionFolder = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-sessions-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: sessionFolder.appendingPathComponent("-Users-a-GitHub"), withIntermediateDirectories: true)
let sessionLines: [[String: Any]] = [
    ["type": "user", "timestamp": "2026-11-10T10:00:00.000Z", "cwd": "/r/personal/shop", "message": ["role": "user", "content": "Please explain changes in plain language, not jargon."]],
    ["type": "user", "timestamp": "2026-11-10T10:01:00.000Z", "cwd": "/r/personal/shop", "message": ["role": "user", "content": "<task-notification>done</task-notification>"]],
    ["type": "user", "timestamp": "2026-11-10T10:02:00.000Z", "cwd": "/r/work/portal", "message": ["role": "user", "content": [["type": "text", "text": "Use Supabase for this one."]]]],
    ["type": "assistant", "timestamp": "2026-11-10T10:03:00.000Z", "cwd": "/r/work/portal", "message": ["role": "assistant", "content": [
        ["type": "tool_use", "id": "t1", "name": "Bash", "input": ["command": "cd /r && graphify query \"where are payments handled\" --graph graphify-out/graph.json"]],
    ]]],
    ["type": "user", "timestamp": "2026-11-10T10:03:05.000Z", "cwd": "/r/work/portal", "message": ["role": "user", "content": [["type": "tool_result", "tool_use_id": "t1", "content": "Graph: x (10 nodes) | 0 nodes found"]]]],
    ["type": "assistant", "timestamp": "2026-11-10T10:04:00.000Z", "cwd": "/r/personal/shop", "message": ["role": "assistant", "content": [
        ["type": "tool_use", "id": "t2", "name": "Bash", "input": ["command": "graphitree pick date picker"]],
        ["type": "tool_use", "id": "t3", "name": "Bash", "input": ["command": "npm i sonner zod@3 -D @types/node\nnpm run dev"]],
        ["type": "tool_use", "id": "t4", "name": "Bash", "input": ["command": "npm i -g @openai/codex && pip install -r requirements.txt"]],
    ]]],
    ["type": "user", "timestamp": "2026-11-10T10:04:05.000Z", "cwd": "/r/personal/shop", "message": ["role": "user", "content": [["type": "tool_result", "tool_use_id": "t2", "content": [["type": "text", "text": "The owner's playbook has no pick for \"date picker\"."]]]]]],
    ["type": "user", "timestamp": "2025-01-01T10:00:00.000Z", "cwd": "/r", "message": ["role": "user", "content": "An old message that's out of range."]],
]
let sessionText = try sessionLines.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }.joined(separator: "\n") + "\n"
try sessionText.write(to: sessionFolder.appendingPathComponent("-Users-a-GitHub/s1.jsonl"), atomically: true, encoding: .utf8)
let sessions = SessionReader.scan(folder: sessionFolder, since: utc("2026-11-01T00:00:00Z"))
expectEqual(sessions.messages.map(\.text).sorted(), ["Please explain changes in plain language, not jargon.", "Use Supabase for this one."], "only the person's own typed messages are kept, in range")
expectEqual(sessions.questions.map(\.kind), ["pick", "query"], "graph questions from graphify and graphitree are found, newest first")
expectEqual(sessions.questions.first { $0.kind == "query" }?.found, 0, "an empty graph answer is noticed")
expectEqual(sessions.questions.first { $0.kind == "pick" }?.found, 0, "a missing pick is noticed")
expectEqual(Set(sessions.installs.map(\.name)), ["sonner", "zod", "@types/node"], "packages are read without versions, flags, the next line or global installs")
expectEqual(SessionReader.question(in: "graphitree ask \"render a map\" --all")?.question, "render a map", "a graphitree question drops its options")
expectEqual(SessionReader.packages(in: "uv add httpx[http2] 'pydantic>=2'"), ["httpx", "pydantic"], "Python extras and versions are dropped")
expectEqual(SessionReader.foundCount(in: "Graph: x | 191 nodes found"), 191, "graphify's node count is read")

let usageURL = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-usage-\(UUID().uuidString).jsonl")
var loggingTools = GraphitreeTools(source: sceneWorkspace.source, cwd: "/r/personal/shop")
loggingTools.usageLog = usageURL
loggingTools.via = "mcp"
_ = loggingTools.pick("payments")
let logged = UsageLog.load(since: .distantPast, from: usageURL)
check(logged.count == 1 && logged[0].tool == "pick" && logged[0].found == 0 && logged[0].via == "mcp", "a pick is logged with what it found")
UsageLog.clear(usageURL)
expectEqual(UsageLog.load(since: .distantPast, from: usageURL), [], "the log can be cleared")

var insightBook = Playbook()
insightBook.libraries = [PlaybookLibrary(name: "Sonner", install: "npm i sonner")]
let events = [
    UsageEvent(date: utc("2026-11-11T00:00:00Z"), via: "cli", tool: "pick", query: "Date Picker", found: 0, cwd: "/r/work/portal"),
    UsageEvent(date: utc("2026-11-12T00:00:00Z"), via: "mcp", tool: "ask", query: "where are payments handled", found: 0, cwd: "/r/work/portal"),
]
let insights = UsageInsights.build(events: events, sessions: sessions, playbook: insightBook, root: "/r", scheme: ProjectScheme(singleRepoName: nil))
expectEqual(insights.questions, 2, "graph questions count both sessions and Graphitree's log")
expectEqual(insights.emptyQuestions, ["where are payments handled"], "an empty question is listed once")
expectEqual(insights.missingPicks.first, UsageInsights.Count(name: "date picker", count: 2), "missing picks are counted across both sources")
expectEqual(insights.projects.first?.name, "work/portal", "questions are counted per project")
expectEqual(insights.unlistedPackages.map(\.name), ["zod"], "packages already in the playbook, and types, aren't suggested")

let digest = SessionDigest.make(sessions, root: "/r", scheme: ProjectScheme(singleRepoName: nil))
check(digest.contains("- [personal/shop] Please explain changes in plain language") && digest.contains("Packages installed in those sessions"), "the digest groups the person's words by project, with installs")
check(SessionDigest.make(sessions, root: "/r", scheme: ProjectScheme(singleRepoName: nil), maxCharacters: 60).components(separatedBy: "\n- [").count <= 2, "the digest stays within its size")
check(PlaybookChat.instructions(playbook: insightBook, scan: nil, searchesWeb: false, asksForJSON: false, extraContext: "EXTRA").hasSuffix("EXTRA"), "the chat can be given the digest for one message")
try? FileManager.default.removeItem(at: sessionFolder)

let checkedLibrary = PlaybookLibrary(name: "Vaul", install: "npm i vaul", health: "Maintained.")
let quietLibrary = PlaybookLibrary(name: "Sonner", install: "npm i sonner", health: "Maintained, 2026.")
let checkDrafts: [UUID: LibraryDraft] = [
    checkedLibrary.id: LibraryDraft(name: "Vaul", url: "", task: "", purpose: "", useWhen: "", avoidWhen: "", install: "npm i vaul", platforms: "", health: "Unmaintained since 2025."),
    quietLibrary.id: LibraryDraft(name: "Sonner", url: "", task: "", purpose: "", useWhen: "", avoidWhen: "", install: "npm i sonner", platforms: "", health: "Maintained, v2.1, 2026."),
]
let checkChanges = PlaybookCheck.changes(for: [checkedLibrary, quietLibrary], drafts: checkDrafts)
expectEqual(checkChanges.map { $0.library?.name }, ["Vaul"], "only libraries whose status changed are flagged")
check(checkChanges.first?.reason.contains("now looks unmaintained") == true, "the check says why")

var layered = Playbook()
layered.stack["backend"] = StackAnswer(choices: ["NestJS"])
layered.stack["web"] = StackAnswer(choices: ["Vite + React"])
layered.folderStacks = ["work": ["backend": StackAnswer(choices: ["Supabase"])]]
expectEqual(layered.stack(for: "work")["backend"]?.choices, ["Supabase"], "a folder's own answer replaces the default inside it")
expectEqual(layered.stack(for: "work")["web"]?.choices, ["Vite + React"], "a folder follows the defaults it doesn't change")
expectEqual(layered.stack(for: "personal")["backend"]?.choices, ["NestJS"], "other folders keep the defaults")
check(PlaybookFile.markdown(layered).contains("### In `work/`\n\nThese replace the defaults above for work in this folder.\n\n- **Back end:** Supabase"), "the playbook lists a folder's own answers")
check(PlaybookFile.guideSummary(layered).contains("- In `work/`, instead: Back end: Supabase"), "the guide mentions a folder's own answers")
check(PlaybookPicks.stackText(layered, folder: "work").contains("- Back end: Supabase (for work/)"), "the stack for a folder marks its own answers")
check(RepoPointer.block(playbook: layered, folder: FolderLabel(path: "work", purpose: .work), hasCommand: false).contains("- Back end: Supabase") && !RepoPointer.block(playbook: layered, folder: FolderLabel(path: "work", purpose: .work), hasCommand: false).contains("NestJS"), "a repo's pointer uses its folder's stack")
let oldPlaybookFolder = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-oldbook-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: oldPlaybookFolder, withIntermediateDirectories: true)
try #"{"version":1,"libraries":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Sonner","url":"","task":"","purpose":"","useWhen":"","avoidWhen":"","install":"","platforms":"","health":"","verified":false,"drafted":false,"notes":""}],"stack":{},"habits":{}}"#.write(to: oldPlaybookFolder.appendingPathComponent(PlaybookFile.jsonName), atomically: true, encoding: .utf8)
expectEqual(PlaybookFile.load(from: oldPlaybookFolder).libraries.map(\.name), ["Sonner"], "a playbook saved before folder stacks still loads")
try? FileManager.default.removeItem(at: oldPlaybookFolder)
let oldFreshness = checkSuite("oldfresh")
oldFreshness.set(Data(#"{"docs":"nightly","hour":3}"#.utf8), forKey: FreshnessSettings.defaultsKey)
let loadedFreshness = FreshnessSettings.load(oldFreshness)
check(loadedFreshness.docs == .nightly && loadedFreshness.hour == 3 && !loadedFreshness.checksLibrariesMonthly && loadedFreshness.askAboveTokens == 150_000, "settings saved by an older version keep their values and gain defaults")
check(FreshnessSettings(checksLibrariesMonthly: true).isLibraryCheckDue(now: .now) && !FreshnessSettings(checksLibrariesMonthly: true, lastLibraryCheck: .now).isLibraryCheckDue(now: .now), "the library check is due a month after the last one")

// Connecting a coding tool runs graphify's own installer, here into the fake home only.
let realCodexSkill = FileManager.default.homeDirectoryForCurrentUser.path + "/.codex/skills/graphify"
let realCodexSkillBefore = FileManager.default.fileExists(atPath: realCodexSkill)
do {
    try GraphifyCommand.installSkill(codex, home: fakeHome)
    let both = CodingToolState.read(codex, home: fakeHome)
    check(both.builds && both.reads && both.isConnected, "after installing the skill, the tool does both")
    check(!FileManager.default.fileExists(atPath: fakeHome + "/AGENTS.md"), "graphify's per-project files stay out of the home folder")
} catch {
    check(false, "graphify installs its skill into a fake home: \(error.localizedDescription)")
}
expectEqual(FileManager.default.fileExists(atPath: realCodexSkill), realCodexSkillBefore, "the real home is untouched")
try? FileManager.default.removeItem(atPath: fakeHome)

// Areas group by where things live, independently of colour groups.
expectEqual(projectScene.nodes.first { $0.id == "work/one" }?.area, "Work", "projects sit in their owner's area")
expectEqual(communityScene.nodes.first?.area, "src", "a community's area is its main folder")
expectEqual(fileScene.nodes.first { $0.id == "work/one/src/a.ts" }?.area, "src", "files sit in their folder's area")
let symbolsInFile = try sceneWorkspace.scene(at: .symbols(project: "work/one", community: 0, path: "work/one/src/a.ts"), showHidden: false)
expectEqual(symbolsInFile.nodes.first { $0.id == "a" }?.area, "Code", "symbols in one file split by kind")
expectEqual(symbolScene.nodes.first { $0.id == "a" }?.area, "a.ts", "symbols across a community split by file")

// Rings view data.
let ringProjects = try sceneWorkspace.ringScene(at: .projects, showHidden: false)
let centre = ringProjects.nodes.first { $0.id == GraphScene.ringCenterID }
expectEqual(centre?.ring, 0, "rings have a centre")
expectEqual(centre?.label, "Projects", "the centre is the current level")
expectEqual(ringProjects.nodes.filter { $0.ring == 1 }.map(\.id).sorted(), ["personal/two", "work/one"], "ring one is the current level's items")
let ringTwo = ringProjects.nodes.filter { $0.ring == 2 }
check(!ringTwo.isEmpty, "ring two holds their children")
check(ringTwo.allSatisfy { node in ringProjects.nodes.first { $0.id == node.parent }?.group == node.group }, "children share their parent's colour group")
expectEqual(GraphScene.ringChild(ringTwo[0].id)?.parent, ringTwo[0].parent, "ring-two IDs carry their parent")
expectEqual(ringProjects.edges.filter { $0.tree == true }.count, ringProjects.nodes.count - 1, "every ring node has one tree line inward")
expectEqual(ringProjects.edges.filter { $0.tree != true }.count, projectScene.edges.count, "real links are kept alongside tree lines")
let ringLimited = try sceneWorkspace.ringScene(at: .projects, showHidden: false, nodeLimit: 4)
expectEqual(ringLimited.nodes.count, 4, "rings respect the node limit")
expectEqual(ringLimited.omittedNodes, ringProjects.nodes.count - 4, "rings report what they left out")
let ringCounts = Dictionary(grouping: ringProjects.nodes.filter { $0.ring == 2 }, by: \.parent).mapValues(\.count)
check(ringCounts.values.allSatisfy { $0 <= GraphScene.ringChildLimit }, "no item shows more than the ring child limit")
check(ringProjects.nodes.filter { $0.ring == 1 }.count <= GraphScene.ringItemLimit, "the first ring stays under its limit")
let ringFiles = try sceneWorkspace.ringScene(at: .files(project: "work/one", community: 0), showHidden: false)
let symbolChild = ringFiles.nodes.first { $0.ring == 2 && GraphScene.ringChild($0.id)?.child == "a" }
expectEqual(symbolChild.flatMap { GraphScene.ringChild($0.id)?.parent }, "work/one/src/a.ts", "file rings hold symbols under their file")
let ringBottom = try sceneWorkspace.ringScene(at: .symbols(project: "work/one", community: 0, path: "work/one/src/a.ts"), showHidden: false)
expectEqual(ringBottom.nodes.filter { $0.ring == 2 }.count, 0, "the bottom level has no outer ring")
let oddID = GraphScene.ringChildID(parent: "work/one/src/[id]/a.ts", child: "x:y")
expectEqual(GraphScene.ringChild(oddID)?.child, "x:y", "ring IDs survive paths with odd characters")
check(GraphScene.ringChild("work/one") == nil, "ordinary IDs aren't ring children")

// Jumping straight to a node.
expectEqual(try sceneWorkspace.location(ofNode: "a"), NodeLocation(levels: [
    .projects,
    .communities(project: "work/one"),
    .files(project: "work/one", community: 0),
    .symbols(project: "work/one", community: 0, path: "work/one/src/a.ts"),
], isHidden: false), "location walks from projects to the symbol")
expectEqual(try sceneWorkspace.location(ofNode: "datetime"), nil, "a node outside any project has no location")
expectEqual(try sceneWorkspace.location(ofNode: "no_such_node"), nil, "an unknown node has no location")

// MARK: - Orphaned rules and rebuild safety

let orphanWorkspace = try openCuration()
var orphanSnapshot = try orphanWorkspace.perform([
    .hideNode(id: "no_such_node", label: "ghost"),
    .hidePath(glob: "work/nowhere/**", note: "gone"),
    .hideConfigLabel(key: "not_a_key"),
    .rejectCrossLinks(node: "no_such_node", label: "ghost"),
    .keep(findingID: "cross:no_such_node", note: "ghost"),
    .hideNode(id: "loner", label: "loner"),
])
expectEqual(orphanSnapshot.rules.filter(\.isOrphaned).count, 5, "rules pointing at nothing are orphaned")
expectEqual(orphanSnapshot.rules.first { $0.summary.contains("loner") }?.isOrphaned, false, "a live rule isn't orphaned")
expectEqual(orphanSnapshot.rules.first { $0.isOrphaned }?.affects, "Matches nothing", "orphaned rules say so")
orphanSnapshot = try orphanWorkspace.undo(ruleIDs: orphanSnapshot.rules.filter(\.isOrphaned).map(\.id))
expectEqual(orphanSnapshot.rules.filter(\.isOrphaned).count, 0, "orphaned rules can be cleared")

let mismatchedSandbox = fileManager.temporaryDirectory.appendingPathComponent("gstudio-\(UUID().uuidString)")
let copiedOut = mismatchedSandbox.appendingPathComponent("copy/graphify-out")
try fileManager.createDirectory(at: copiedOut, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: mismatchedSandbox) }
try "/somewhere/else\n".write(to: copiedOut.appendingPathComponent(".graphify_root"), atomically: true, encoding: .utf8)
do {
    try GraphRebuilder.validate(GraphSource(outDirectory: copiedOut))
    check(false, "a copy pointing at another root can't be rebuilt")
} catch let error as RebuildError {
    expectEqual(error, .buildFolderMismatch(root: "/somewhere/else"), "a copy pointing at another root can't be rebuilt")
}
var validated = true
do { try GraphRebuilder.validate(GraphSource(outDirectory: curationOut)) } catch { validated = false }
check(validated, "a graph in its own root can be rebuilt")

// MARK: - Per-repo graphs

let repoSandbox = fileManager.temporaryDirectory.appendingPathComponent("gstudio-\(UUID().uuidString)")
let repoRoot = repoSandbox.appendingPathComponent("personal/repo")
let repoOut = repoRoot.appendingPathComponent("graphify-out")
try fileManager.createDirectory(at: repoOut, withIntermediateDirectories: true)
try fileManager.createDirectory(at: repoRoot.appendingPathComponent(".git"), withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: repoSandbox) }
for path in ["src/a.ts", "app/b.ts", "generated/c.ts", "docs/x.md"] {
    let url = repoRoot.appendingPathComponent(path)
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: url)
}
try "\"\(repoRoot.path)\"\n".write(to: repoOut.appendingPathComponent(".graphify_root"), atomically: true, encoding: .utf8)
let repoNodes = [
    curationNode("a", "a", "src/a.ts"),
    curationNode("b", "b", "app/b.ts"),
    curationNode("c", "c", "generated/c.ts"),
    curationNode("up", "up", "personal/repo/docs/x.md"),
    curationNode("gone", "gone", "src/deleted.ts"),
].joined(separator: ",")
try #"{"nodes":[\#(repoNodes)],"links":[\#(curationEdge("a", "b", "calls"))],"hyperedges":[]}"#
    .write(to: repoOut.appendingPathComponent("graph.json"), atomically: true, encoding: .utf8)
let repoSource = GraphSource(outDirectory: repoOut)
expectEqual(repoSource.rootPath, repoRoot.path, "quoted root file is understood")
expectEqual(repoSource.scheme.singleRepoName, "repo", "a git root is one project")
let repoWorkspace = try onBackgroundQueue { try Workspace(source: repoSource, cacheDirectory: curationCache) }
let repoSnapshot = try repoWorkspace.snapshot()
expectEqual(repoSnapshot.overview.crossProjectEdges, 0, "folders in one repo aren't separate projects")
expectEqual(repoSnapshot.count(.crossProject), 0, "no cross-project findings in one repo")
expectEqual(repoSnapshot.count(.generated), 1, "folder at the top of a repo counts as generated")
expectEqual(repoSnapshot.findings[.generated]?.first?.location, "generated/", "top-level group path")
expectEqual(repoSnapshot.overview.missingFiles, 1, "path written from a parent folder isn't reported missing")
expectEqual(repoSnapshot.findings[.missing]?.first?.location, "src/deleted.ts", "single missing file gets its own row")
_ = try repoWorkspace.perform([.hideNode(id: "b", label: "b")])
check(fileManager.fileExists(atPath: repoOut.appendingPathComponent("curation.jsonl").path), "each graph has its own rules")
let machineRules = try CurationLog(url: curationOut.appendingPathComponent("curation.jsonl"))
check(!machineRules.entries.contains { $0.node == "b" && $0.op == "hide_node" }, "rules don't leak between graphs")
try repoWorkspace.writeCleanGraph()
expectEqual(try repoWorkspace.rootLevel(), .communities(project: "repo"), "single repo starts at communities")
expectEqual(try repoWorkspace.location(ofNode: "a")?.levels.first, .communities(project: "repo"), "single repo locations start at communities")
let repoEntries = GraphCatalog.discover(under: repoSandbox)
expectEqual(repoEntries.map(\.name), ["personal/repo"], "catalog finds per-repo graphs")
let rootEntries = GraphCatalog.discover(under: curationRoot)
expectEqual(rootEntries.first?.name, "Machine-wide", "graph at the root is the machine-wide one")

// MARK: - Application Support

let supportFolder = AppSupport.root.appendingPathComponent(AppSupport.folderName).path + "/"
let keptInSupport = [UsageLog.url, DocsRunLog.url, PlaybookBackup.mirror, ChatStore.url(for: URL(fileURLWithPath: "/g/graphify-out")), try GraphIndex.defaultCacheDirectory()]
check(keptInSupport.allSatisfy { $0.path.hasPrefix(supportFolder) }, "everything the app keeps in Application Support is in Graphitree's folder there")

// MARK: - Arrange and back up

try arrangeAndBackupChecks()
try backgroundAndRestoreChecks()
try moveChecks()

// MARK: - AI connections

try connectionChecks()
try usageChecks()
try usageSummaryChecks()
try codexChecks()
try geminiChecks()
try copilotChecks()
try menuBarAndWidgetChecks()

// MARK: - Uninstall

try uninstallChecks()

// MARK: - Getting graphify

try graphifySetupChecks()

// MARK: - Playbook lab

try labChecks()
try swiftLabChecks()

expectEqual(removeCheckSuites(), [], "the checks leave no defaults suites behind")

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)

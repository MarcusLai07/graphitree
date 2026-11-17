import Foundation

// Checks for backups that run on their own and for Restore: when a backup is due, the background
// job's list, `graphitree backup` end to end on a knowledge base on disk, and restoring one or
// several backups. Called from main.swift.

private func rcTemp(_ name: String) -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func rcWrite(_ text: String, _ url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: url, atomically: true, encoding: .utf8)
}

private let rcGraph = #"""
{"directed":false,"multigraph":false,"built_at_commit":"abc",
 "graph":{"schema_version":2,"hyperedges":[{"id":"h1","nodes":["a1","a2","x1"]},{"id":"h2","nodes":["a1","a2"]}]},
 "hyperedges":[{"id":"h1","nodes":["a1","a2","x1"]},{"id":"h2","nodes":["a1","a2"]}],
 "nodes":[
  {"id":"a1","label":"A one","source_file":"personal/a/one.ts","community":1},
  {"id":"a2","label":"A two","source_file":"personal/a/two.ts","community":1},
  {"id":"x1","label":"X one","source_file":"work/x/one.ts","community":2},
  {"id":"x2","label":"X two","source_file":"work/x/two.ts","community":2},
  {"id":"lib","label":"react","source_file":"","community":3}
 ],
 "links":[
  {"source":"a1","target":"a2","relation":"calls"},
  {"source":"a1","target":"x1","relation":"references"},
  {"source":"x1","target":"x2","relation":"calls"},
  {"source":"a2","target":"lib","relation":"imports"},
  {"source":"x2","target":"lib","relation":"imports"}
 ]}
"""#

func backgroundAndRestoreChecks() throws {
    let fileManager = FileManager.default

    // MARK: When a backup is due

    let now = Date()
    let local = BackupPlan(destination: .local, when: .rebuild)
    var record = BackupStore.Record(lastAttempt: now.addingTimeInterval(-7200), lastSuccess: now.addingTimeInterval(-7200), target: "this Mac", graphDate: now.addingTimeInterval(-9000))
    check(!BackupSchedule.isDue(BackupPlan(destination: .local, when: .manual), record: record, graphDate: now, now: now), "When I Ask never runs on its own")
    check(!BackupSchedule.isDue(local, record: nil, graphDate: now, now: now), "a backup never pushed by hand doesn't run on its own: the first one is the person's")
    check(BackupSchedule.isDue(local, record: record, graphDate: now.addingTimeInterval(-60), now: now), "after a rebuild, a backup an hour old runs")
    check(!BackupSchedule.isDue(local, record: record, graphDate: record.graphDate, now: now), "with no new graph since, it doesn't")
    var recent = record
    recent.lastSuccess = now.addingTimeInterval(-600)
    check(!BackupSchedule.isDue(local, record: recent, graphDate: now, now: now), "a backup from ten minutes ago waits out the hour")
    var failed = record
    failed.lastError = "offline"
    failed.lastAttempt = now.addingTimeInterval(-300)
    check(!BackupSchedule.isDue(local, record: failed, graphDate: now, now: now), "a failed try waits an hour before the next")
    failed.lastAttempt = now.addingTimeInterval(-4000)
    check(BackupSchedule.isDue(local, record: failed, graphDate: now, now: now), "then tries again")
    let daily = BackupPlan(destination: .local, when: .daily)
    record.lastSuccess = now.addingTimeInterval(-21 * 3600)
    check(BackupSchedule.isDue(daily, record: record, graphDate: nil, now: now), "Daily runs once the last backup is most of a day old")
    record.lastSuccess = now.addingTimeInterval(-5 * 3600)
    check(!BackupSchedule.isDue(daily, record: record, graphDate: nil, now: now), "and not sooner")
    let moved = BackupPlan(destination: .github, login: "home-me", repo: "new-kb", when: .daily)
    record.lastSuccess = now.addingTimeInterval(-30 * 3600)
    check(!BackupSchedule.isDue(moved, record: record, graphDate: nil, now: now), "a backup pointed somewhere new waits for the person to push there once")
    check(BackupSchedule.waitingReason(moved, record: record) != nil && BackupSchedule.waitingReason(daily, record: record) == nil, "and the setup card says why")

    // MARK: The background job's list

    let listStore = rcTemp("scheduled")
    let kbOne = URL(fileURLWithPath: "/tmp/one/graphify-out")
    let automatic = [GraphPlan(id: "g", name: "Machine-wide", areaIDs: [], backup: daily, isHome: true)]
    check(ScheduledBackups.update(outDirectory: kbOne, plans: automatic, in: listStore), "a graph that backs up on its own is listed")
    ScheduledBackups.update(outDirectory: URL(fileURLWithPath: "/tmp/two/graphify-out"), plans: automatic, in: listStore)
    expectEqual(ScheduledBackups.load(in: listStore), ["/tmp/one/graphify-out", "/tmp/two/graphify-out"], "each knowledge base is listed once")
    ScheduledBackups.update(outDirectory: kbOne, plans: automatic, in: listStore)
    expectEqual(ScheduledBackups.load(in: listStore).count, 2, "listing again changes nothing")
    var manualOnly = automatic
    manualOnly[0].backup.when = .manual
    ScheduledBackups.update(outDirectory: kbOne, plans: manualOnly, in: listStore)
    expectEqual(ScheduledBackups.load(in: listStore), ["/tmp/two/graphify-out"], "switching to When I Ask unlists it")

    // MARK: `graphitree backup` on a knowledge base on disk

    let root = rcTemp("kb-root")
    for file in ["personal/a/one.ts", "personal/a/two.ts", "work/x/one.ts", "work/x/two.ts"] {
        try rcWrite("export {}\n", root.appendingPathComponent(file))
    }
    let out = root.appendingPathComponent("graphify-out", isDirectory: true)
    try rcWrite(rcGraph, out.appendingPathComponent("graph.json"))
    try rcWrite(root.path, out.appendingPathComponent(".graphify_root"))
    try rcWrite(#"{"personal/a/one.ts":{"h":"1"},"work/x/one.ts":{"h":"2"}}"#, out.appendingPathComponent("manifest.json"))
    try rcWrite(#"{"nodes":[{"id":"a1","source_file":"personal/a/one.ts"}]}"#, out.appendingPathComponent("cache/semantic/v1/aaa.json"))
    try rcWrite(#"{"nodes":[{"id":"x1","source_file":"work/x/one.ts"}]}"#, out.appendingPathComponent("cache/semantic/v1/xxx.json"))
    try rcWrite(#"{"1":"Personal A","2":"Work X","3":"Libraries"}"#, out.appendingPathComponent(".graphify_labels.json"))
    try rcWrite(#"{"1":"sigA","2":"sigX","3":"sigL"}"#, out.appendingPathComponent(".graphify_labels.json.sig"))
    try rcWrite("""
    {"id":"r2","at":"2026-11-02T00:00:00Z","op":"hide_node","node":"x2"}
    {"id":"r1","at":"2026-11-01T00:00:00Z","op":"hide_node","node":"a2"}
    """, out.appendingPathComponent("curation.jsonl"))
    try rcWrite("# Playbook\n", out.appendingPathComponent(PlaybookFile.markdownName))
    let labels = [FolderLabel(path: "personal", purpose: .personal, holdsProjects: true), FolderLabel(path: "work", purpose: .work, holdsProjects: true)]
    try FolderFile.save(FolderMap(folders: labels), to: out)

    let onDisk = BackupJob.arrangement(outDirectory: out, graph: try GraphPartition.read(out.appendingPathComponent("graph.json")))
    expectEqual(Set(onDisk.projects.map(\.path)), ["personal/a", "work/x"], "the command line finds the projects on disk")
    expectEqual(onDisk.nodes(inGraph: onDisk.graphs[0].id), 4, "and counts their nodes from graph.json")
    var arranged = onDisk
    arranged.setBackup(BackupPlan(destination: .local, when: .rebuild), forGraph: arranged.graphs[0].id)
    try GraphPlans.save(arranged.graphs, to: out)
    let graphID = arranged.graphs[0].id

    let store = rcTemp("job-store")
    let quiet = BackupJob.Options(ifDue: true, waitsForGraphify: false)
    expectEqual(try BackupJob.run(outDirectory: out, options: quiet, store: store, confirmed: [:]), [], "a scheduled run doesn't make the first backup")
    let dry = try BackupJob.run(outDirectory: out, options: BackupJob.Options(dryRun: true), store: store, confirmed: [:])
    check(dry.count == 1 && dry[0].message.contains("files") && !fileManager.fileExists(atPath: store.appendingPathComponent("local-machine-wide").path), "a dry run says what would be saved and writes nothing")
    let firstRun = try BackupJob.run(outDirectory: out, options: BackupJob.Options(), store: store, confirmed: [:])
    check(firstRun.count == 1 && !firstRun[0].failed, "backing up by hand runs every graph that backs up")
    let firstRecord = BackupStore.records(in: store)[graphID]
    check(firstRecord?.graphDate != nil && firstRecord?.ranFrom == "command line", "the record notes which graph.json it covered and what ran it")
    expectEqual(try BackupJob.run(outDirectory: out, options: quiet, store: store, now: now.addingTimeInterval(7200), confirmed: [:]), [], "with no rebuild since, nothing is due")
    check((try? BackupJob.run(outDirectory: out, options: BackupJob.Options(only: "Nope"), store: store, confirmed: [:])) == nil, "asking for a graph that isn't there fails")

    // A rebuild writes a new graph.json: the next scheduled run backs it up.
    try rcWrite(rcGraph.replacingOccurrences(of: #"{"id":"lib","#, with: #"{"id":"a3","label":"A three","source_file":"personal/a/one.ts","community":1},{"id":"lib","#), out.appendingPathComponent("graph.json"))
    try fileManager.setAttributes([.modificationDate: now.addingTimeInterval(120)], ofItemAtPath: out.appendingPathComponent("graph.json").path)
    ScheduledBackups.update(outDirectory: out, plans: arranged.graphs, in: store)
    let scheduled = BackupJob.runScheduled(store: store, now: now.addingTimeInterval(7200), confirmed: [:], waitsForGraphify: false)
    check(scheduled.count == 1 && !scheduled[0].failed && scheduled[0].message.contains("committed"), "the background job backs up a rebuilt graph")
    expectEqual(BackupStore.records(in: store)[graphID]?.ranFrom, "background", "and the record says it ran in the background")
    expectEqual(BackupJob.runScheduled(store: store, now: now.addingTimeInterval(14400), confirmed: [:], waitsForGraphify: false), [], "running again finds nothing due")

    // MARK: Restoring one backup

    let mirror = BackupStore.mirror(for: arranged.graphs[0].backup, graph: arranged.graphs[0], in: store)
    let sources = BackupRestore.sources(plans: arranged.graphs, store: store)
    expectEqual(sources.map(\.remote), [mirror.path], "a this-Mac backup is offered for restore")
    let work = rcTemp("restore-work")
    try BackupRestore.fetch(sources[0], into: work.appendingPathComponent("0"))
    let destination = BackupRestore.destination(root: root.path, now: now)
    check(destination.lastPathComponent == "graphify-out" && !destination.path.hasPrefix(root.path + "/"), "a restore goes outside the root, in a folder graphify will read")
    let restored = try BackupRestore.combine([work.appendingPathComponent("0")], into: destination, root: root.path)
    let bundle = try BackupContents.build(graphID: graphID, arrangement: BackupJob.arrangement(outDirectory: out, graph: nil), outDirectory: out)
    expectEqual(try GraphPartition.summary(of: GraphPartition.read(destination.appendingPathComponent("graph.json"))), bundle.summary, "the restored graph matches what was backed up exactly")
    expectEqual(restored.nodes, 6, "every node comes back")
    expectEqual(try String(contentsOf: destination.appendingPathComponent(".graphify_root"), encoding: .utf8), root.path, "the restored graph knows its root")
    check(fileManager.fileExists(atPath: destination.appendingPathComponent("cache/semantic/v1/aaa.json").path) && fileManager.fileExists(atPath: destination.appendingPathComponent(PlaybookFile.markdownName).path), "the AI-extracted meaning and the playbook come back")
    check(FolderFile.load(from: destination)?.folders.count == 2 && GraphPlans.load(from: destination)?.first?.id == graphID, "so do the folder labels and graphs")
    let restoredRules = try String(contentsOf: destination.appendingPathComponent("curation.jsonl"), encoding: .utf8)
    check(restoredRules.contains("r1") && restoredRules.contains("r2"), "and the cleanup rules")
    check(String(decoding: (try? Data(contentsOf: destination.appendingPathComponent("manifest.json"))) ?? Data(), as: UTF8.self).contains("personal/a/one.ts"), "and the rebuild index")
    check((try? BackupRestore.combine([work.appendingPathComponent("0")], into: destination, root: root.path)) == nil, "a restore never writes over an existing folder")
    if let graphify = GraphRebuilder.locateGraphify() {
        let problem = BackupRestore.checkWithGraphify(destination, graphify: graphify)
        check(problem == nil, "graphify reads the restored graph\(problem.map { ": \($0)" } ?? "")")
    }

    // A backup whose parts were changed is refused, and nothing is written.
    let tampered = work.appendingPathComponent("0/graph/personal/a.json")
    try rcWrite(#"{"nodes":[],"links":[]}"#, tampered)
    let tamperedDestination = rcTemp("restore-tampered").appendingPathComponent("graphify-out")
    check((try? BackupRestore.combine([work.appendingPathComponent("0")], into: tamperedDestination, root: root.path)) == nil, "a backup whose parts don't add up isn't restored")
    check(!fileManager.fileExists(atPath: tamperedDestination.path), "and nothing is left behind")

    // A repo Graphitree didn't write isn't treated as a backup.
    let foreign = rcTemp("foreign")
    _ = try ProcessRunner.run("/usr/bin/git", ["init", "--quiet", "-b", "main"], in: foreign)
    try rcWrite("hello\n", foreign.appendingPathComponent("README.md"))
    _ = try ProcessRunner.run("/usr/bin/git", ["add", "-A"], in: foreign)
    _ = try ProcessRunner.run("/usr/bin/git", ["-c", "user.name=Checks", "-c", "user.email=checks@example.com", "commit", "--quiet", "-m", "x"], in: foreign)
    check((try? BackupRestore.fetch(BackupRestore.Source(name: "foreign", remote: foreign.path), into: work.appendingPathComponent("foreign"))) == nil, "a repo without Graphitree's graph files is refused")

    // MARK: Restoring separate graphs into one

    var split = BackupJob.arrangement(outDirectory: out, graph: nil)
    split.splitByAccount(split.graphs[0].id) { $0.hasPrefix("personal/") ? "home-me" : "work-me" }
    for graph in split.graphs { split.setBackup(BackupPlan(destination: .local), forGraph: graph.id) }
    try GraphPlans.save(split.graphs, to: out)
    try FolderFile.save(split.folderMap, to: out)
    let splitStore = rcTemp("split-store")
    let splitRun = try BackupJob.run(outDirectory: out, options: BackupJob.Options(), store: splitStore, confirmed: [:])
    check(splitRun.count == 2 && splitRun.allSatisfy { !$0.failed }, "each separate graph backs up")
    let splitSources = BackupRestore.sources(plans: split.graphs, store: splitStore)
    var splitFolders: [URL] = []
    for (offset, source) in splitSources.enumerated() {
        let folder = work.appendingPathComponent("split-\(offset)")
        try BackupRestore.fetch(source, into: folder)
        splitFolders.append(folder)
    }
    let joinedDestination = rcTemp("restore-joined").appendingPathComponent("graphify-out")
    let joined = try BackupRestore.combine(splitFolders, into: joinedDestination, root: root.path)
    let joinedGraph = try GraphPartition.read(joinedDestination.appendingPathComponent("graph.json"))
    let joinedIDs = Set((joinedGraph["nodes"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
    expectEqual(joinedIDs, ["a1", "a2", "a3", "x1", "x2", "lib"], "every node from both backups comes back once, a library both use included")
    let joinedEdges = (joinedGraph["links"] as? [[String: Any]] ?? []).map { "\($0["source"] ?? "")>\($0["target"] ?? "")" }
    check(!joinedEdges.contains("a1>x1") && joinedEdges.contains("a2>lib") && joinedEdges.contains("x2>lib"), "links inside each graph come back; the link between them was never saved")
    expectEqual(joinedEdges.count, Set(joinedEdges).count, "no link is doubled")
    check(!joined.notes.isEmpty, "the restore says links between graphs need a rebuild")
    expectEqual(GraphPlans.load(from: joinedDestination)?.count, 2, "both graphs' settings come back")
    let joinedRules = try String(contentsOf: joinedDestination.appendingPathComponent("curation.jsonl"), encoding: .utf8).split(separator: "\n")
    check(joinedRules.count == 2 && joinedRules[0].contains("r1"), "rules from both come back in the order they were made")
    let hyperedges = (joinedGraph["graph"] as? [String: Any])?["hyperedges"] as? [[String: Any]] ?? []
    expectEqual(hyperedges.count, 2, "each group comes back once")
    expectEqual(hyperedges.first { $0["id"] as? String == "h1" }?["nodes"] as? [String], ["a1", "a2"], "a group across both graphs comes back as the part one graph held")

    // MARK: Putting a restore in place

    let freshRoot = rcTemp("fresh-root")
    let placed = try BackupRestore.putInPlace(joinedDestination, root: freshRoot.path)
    check(placed.path == freshRoot.appendingPathComponent("graphify-out").path && fileManager.fileExists(atPath: placed.appendingPathComponent("graph.json").path), "with no graph at the root, a restore moves into place")
    check((try? BackupRestore.putInPlace(destination, root: root.path)) == nil && fileManager.fileExists(atPath: out.appendingPathComponent("graph.json").path), "a graph in use is never replaced")

    for folder in [listStore, root, store, work, foreign, splitStore, freshRoot, joinedDestination.deletingLastPathComponent(), tamperedDestination.deletingLastPathComponent(), destination.deletingLastPathComponent().deletingLastPathComponent()] {
        try? fileManager.removeItem(at: folder)
    }
}

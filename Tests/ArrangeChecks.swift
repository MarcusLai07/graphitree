import Foundation

// Checks for Arrange and Back up: the arrangement model, the exact graph split, git rules, what
// each backup holds, and real backups to a local repo. Called from main.swift.

private func abTemp(_ name: String) -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@discardableResult
private func abGit(_ arguments: [String], in folder: URL, environment: [String: String] = [:]) throws -> ProcessOutput {
    try ProcessRunner.run("/usr/bin/git", ["-c", "user.name=Checks", "-c", "user.email=checks@example.com", "-c", "commit.gpgsign=false"] + arguments, in: folder, environment: environment)
}

private func abWrite(_ text: String, _ url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: url, atomically: true, encoding: .utf8)
}

private func abFixtureLabels() -> [FolderLabel] {
    [
        FolderLabel(path: "personal", purpose: .personal, holdsProjects: true),
        FolderLabel(path: "work", purpose: .work, holdsProjects: true),
        FolderLabel(path: "demo-app", purpose: .reference, isIncluded: false),
        FolderLabel(path: "playbook", purpose: .notes, name: "Playbook"),
    ]
}

private func abFixtureProjects() -> [ArrangeProject] {
    [
        ArrangeProject(path: "personal/a", nodes: 30, remote: "git@github-personal:home-me/a.git", hasOwnCommits: true, isRepo: true),
        ArrangeProject(path: "personal/b", nodes: 20, remote: "https://github.com/home-me/b.git", hasOwnCommits: true, isRepo: true),
        ArrangeProject(path: "personal/b-fix", nodes: 0, remote: "https://github.com/home-me/b.git", hasOwnCommits: true, worktreeOf: "personal/b", isRepo: true),
        ArrangeProject(path: "work/x", nodes: 40, remote: "git@github-work:some-org/x.git", hasOwnCommits: true, isRepo: true),
        ArrangeProject(path: "demo-app", nodes: 10, remote: "https://github.com/acme/demo-app.git", hasOwnCommits: false, isRepo: true),
        ArrangeProject(path: "playbook", nodes: 5),
    ]
}

func arrangeAndBackupChecks() throws {
    // MARK: The person's labels

    let oldFile = #"{"version":1,"folders":[{"path":"personal","purpose":"personal","holdsProjects":true,"isIncluded":true,"name":"","note":""}]}"#
    let oldMap = try JSONDecoder().decode(FolderMap.self, from: Data(oldFile.utf8))
    check(oldMap.kinds.isSame(as: FolderPurpose.defaults), "a file from before the label list gets the default labels")
    expectEqual(oldMap.folders.first?.purpose.title, "Personal", "an old label reads as its default")
    let plainData = try JSONEncoder().encode(oldMap)
    check(!String(decoding: plainData, as: UTF8.self).contains("labelKinds"), "default labels aren't written to folders.json")

    var mine = FolderPurpose.personal
    mine.title = "Mine"
    mine.colorSlot = 2
    let side = FolderPurpose(id: "label-side", title: "Side bets", symbol: "flask", colorSlot: 0)
    let edited = FolderMap(
        folders: [FolderLabel(path: "personal", purpose: .personal), FolderLabel(path: "bets", purpose: side)],
        kinds: FolderPurpose.defaults.map { $0.id == "personal" ? mine : $0 } + [side]
    )
    let reread = try JSONDecoder().decode(FolderMap.self, from: try JSONEncoder().encode(edited))
    expectEqual(reread.folders.first?.purpose.title, "Mine", "a renamed default is what its folders show")
    expectEqual(reread.label("bets")?.purpose.symbol, "flask", "a label of the person's own keeps its icon")
    check(reread.kinds.isSame(as: edited.kinds), "the list survives being saved and read")
    check(reread.folders.first?.purpose == .personal, "a renamed label is still the same label")

    var labelled = Arrangement(map: edited, graphs: nil)
    let unedited = labelled
    labelled.setKinds(labelled.kinds.filter { $0.id != side.id })
    expectEqual(labelled.labels.first { $0.path == "bets" }?.purpose.id, "other", "removing a label moves its folders to Other")
    check(labelled != unedited, "editing the list counts as a change to save")
    var renamed = unedited
    renamed.setKinds(unedited.kinds.map { var kind = $0; if kind.id == side.id { kind.title = "Bets" }; return kind })
    check(renamed != unedited, "renaming a label counts as a change to save")
    expectEqual(renamed.labels.first { $0.path == "bets" }?.purpose.title, "Bets", "a renamed label renames its folders' label")
    var withoutOther = unedited
    withoutOther.setKinds([side])
    check(withoutOther.kinds.contains { $0.id == "other" }, "Other is always kept")

    // MARK: Tidy Up's advice

    check(RepoCheck(hasRemote: true).canDelete, "a repo with everything pushed can go")
    check(!RepoCheck(uncommitted: 2, hasRemote: true).canDelete, "uncommitted changes keep a repo")
    check(!RepoCheck(unpushed: 1, hasRemote: true).canDelete, "unpushed commits keep a repo")
    check(!RepoCheck().canDelete, "a repo with no remote is the only copy, so it stays")
    check(RepoCheck(unpushed: 3, isWorktree: true).canDelete, "a worktree's commits live in its main repo, so it can go")
    check(!RepoCheck(uncommitted: 1, isWorktree: true).canDelete, "a worktree with uncommitted work stays")
    expectEqual(TidyAdvice.repoName(fromRemote: "git@github-personal:me/weather-widget.git"), "weather-widget", "a repo's name comes from its remote")
    let older = Date(timeIntervalSince1970: 1_700_000_000)
    let main = CloneFacts(path: "personal/weather-widget", check: RepoCheck(hasRemote: true, lastCommit: older), remoteName: "weather-widget", isInGraph: true)
    let fix = CloneFacts(path: "personal/weather-widget-widget-fix", check: RepoCheck(hasRemote: true, lastCommit: older.addingTimeInterval(86_400), isWorktree: true), remoteName: "weather-widget", isInGraph: false)
    let kept = TidyAdvice.keeper(of: [fix, main])
    expectEqual(kept?.path, main.path, "the main checkout is kept over a newer worktree")
    check(kept?.reasons.contains("the main checkout") == true, "the reasons say why it's the one")
    let copyA = CloneFacts(path: "personal/app", check: RepoCheck(hasRemote: true, lastCommit: older), remoteName: "app", isInGraph: true)
    let copyB = CloneFacts(path: "personal/app-old", check: RepoCheck(hasRemote: true, lastCommit: older.addingTimeInterval(60)), remoteName: "app", isInGraph: true)
    expectEqual(TidyAdvice.keeper(of: [copyB, copyA])?.path, "personal/app", "between two checkouts, the one named like the repo is kept")

    let tidyFolder = abTemp("tidy")
    try abWrite("same", tidyFolder.appendingPathComponent("a.md"))
    try abWrite("same", tidyFolder.appendingPathComponent("docs/a.md"))
    try abWrite("newer", tidyFolder.appendingPathComponent("b.md"))
    try abWrite("older", tidyFolder.appendingPathComponent("docs/b.md"))
    try FileManager.default.setAttributes([.modificationDate: older], ofItemAtPath: tidyFolder.appendingPathComponent("docs/b.md").path)
    expectEqual(TidyAdvice.compare(loose: tidyFolder.appendingPathComponent("a.md").path, copy: tidyFolder.appendingPathComponent("docs/a.md").path), .identical, "a byte-for-byte copy is identical")
    expectEqual(TidyAdvice.compare(loose: tidyFolder.appendingPathComponent("b.md").path, copy: tidyFolder.appendingPathComponent("docs/b.md").path), .differs(looseIsNewer: true), "a changed copy says which is newer")

    let lonely = tidyFolder.appendingPathComponent("lonely")
    try abWrite("one", lonely.appendingPathComponent("file.txt"))
    try abGit(["init", "-q", "-b", "main"], in: lonely)
    try abGit(["add", "."], in: lonely)
    try abGit(["commit", "-q", "-m", "first"], in: lonely)
    check(RepoCheck.run(lonely.path).losses.contains("no remote: this is the only copy"), "git: a repo without a remote is the only copy")
    let tidyRemote = tidyFolder.appendingPathComponent("remote.git")
    try abGit(["init", "-q", "--bare", tidyRemote.path], in: tidyFolder)
    try abGit(["remote", "add", "origin", tidyRemote.path], in: lonely)
    try abGit(["push", "-q", "origin", "main"], in: lonely)
    check(RepoCheck.run(lonely.path).canDelete, "git: once everything is pushed, it can go")
    try abWrite("two", lonely.appendingPathComponent("file.txt"))
    expectEqual(RepoCheck.run(lonely.path).uncommitted, 1, "git: a changed file counts as uncommitted")
    try abGit(["commit", "-q", "-am", "second"], in: lonely)
    expectEqual(RepoCheck.run(lonely.path).unpushed, 1, "git: a commit not pushed counts")
    try? FileManager.default.removeItem(at: tidyFolder)

    // MARK: Arrangement defaults and changes

    var arrangement = Arrangement(labels: abFixtureLabels(), projects: abFixtureProjects())
    expectEqual(arrangement.graphs.count, 1, "without graphs.json there's one graph")
    expectEqual(arrangement.graphs.first?.name, GraphPlans.defaultName, "the one graph is Machine-wide")
    expectEqual(arrangement.placement(of: "personal/a"), .area("personal"), "a project starts in its main folder's area")
    expectEqual(arrangement.placement(of: "personal/b-fix"), .leftOut(reason: "Worktree"), "a worktree starts left out")
    expectEqual(arrangement.placement(of: "demo-app"), .leftOut(reason: "Reference"), "a left-out label leaves its folder out")
    expectEqual(Set(arrangement.areas.map(\.id)), ["personal", "work", "playbook"], "areas come from included labels with projects")
    check(arrangement.placement.isEmpty, "defaults save nothing")
    expectEqual(arrangement.ignoreChanges.add, ["/demo-app/", "/personal/b-fix/"], "left-out folders and projects get ignore lines")

    let ignoredByHand = Arrangement(labels: abFixtureLabels(), projects: abFixtureProjects(), ignoredLines: ["/work/x/"])
    check(ignoredByHand.placement(of: "work/x").isLeftOut, "a project already in .graphifyignore shows as left out")

    let before = arrangement
    check(arrangement.put(["personal/a"], in: .leftOut) == nil, "a project can be left out")
    expectEqual(arrangement.placement["personal/a"], .leftOut(reason: "Left out"), "leaving one out saves a placement")
    check(arrangement.ignoreChanges.add.contains("/personal/a/"), "a project left out gets its own ignore line")
    check(arrangement.changes(from: before).contains("a: Personal → Left out"), "the change is listed")
    check(arrangement.put(["personal/a"], in: .area("personal")) == nil && arrangement.placement["personal/a"] == nil, "putting it back where its label puts it saves nothing")
    check(arrangement.ignoreChanges.remove.contains("/personal/a/"), "putting it back takes its ignore line away")

    check(arrangement.put(["demo-app"], in: .area("personal")) == nil, "a left-out main folder can be brought into an area")
    check(arrangement.labels.first { $0.path == "demo-app" }?.isIncluded == true, "bringing it in switches its label on")
    expectEqual(arrangement.placement(of: "demo-app"), .area("personal"), "and it sits where it was dropped")
    expectEqual(arrangement.projectAreas["demo-app"], FolderArea(name: "Personal", purpose: .personal), "the map puts it in that area")

    var grouped = Arrangement(labels: abFixtureLabels() + [FolderLabel(path: "archive", purpose: .archive, holdsProjects: true, isIncluded: false)], projects: abFixtureProjects() + [ArrangeProject(path: "archive/old")])
    check(grouped.put(["archive/old"], in: .area("personal")) != nil, "a project inside a left-out group can't come back on its own")

    let notesID = arrangement.addArea(purpose: .notes, name: "Writing")
    check(arrangement.area(notesID)?.isMade == true, "an area can be made")
    arrangement.renameArea(notesID, to: "Docs")
    expectEqual(arrangement.area(notesID)?.name, "Docs", "a made area can be renamed")
    arrangement.renameArea("work", to: "Job")
    expectEqual(arrangement.labels.first { $0.path == "work" }?.name, "Job", "renaming a label's area renames the label")
    arrangement.setPurpose(.client, ofArea: "work")
    check(arrangement.labels.first { $0.path == "work" }?.purpose == .client && arrangement.area("work") != nil, "changing an area's purpose changes its label and keeps the area")
    arrangement.removeArea(notesID)
    check(arrangement.area(notesID) == nil, "an empty made area can be removed")

    // Saving and loading.
    let map = arrangement.folderMap
    let mapData = try JSONEncoder().encode(map)
    let decoded = try JSONDecoder().decode(FolderMap.self, from: mapData)
    expectEqual(decoded, map, "folders.json keeps placements and made areas")
    let olderMap = try JSONDecoder().decode(FolderMap.self, from: Data(#"{"version":1,"folders":[{"path":"work","purpose":"work","name":"","note":"","holdsProjects":true,"isIncluded":true}]}"#.utf8))
    check(olderMap.placement.isEmpty && olderMap.arrangedAreas.isEmpty && olderMap.folders.count == 1, "an older folders.json still loads")
    let plainText = String(decoding: try JSONEncoder().encode(FolderMap(folders: abFixtureLabels())), as: UTF8.self)
    check(!plainText.contains("placement") && !plainText.contains("arrangedAreas"), "labels alone are saved as before")
    let planFolder = abTemp("plans")
    try GraphPlans.save(arrangement.graphs, to: planFolder)
    expectEqual(GraphPlans.load(from: planFolder), arrangement.graphs, "graphs.json round-trips")
    try? FileManager.default.removeItem(at: planFolder)

    // One graph, separate graphs, and back.
    var splitting = Arrangement(labels: abFixtureLabels(), projects: abFixtureProjects())
    splitting.split()
    expectEqual(splitting.graphs.count, 3, "separate graphs give each area its own")
    expectEqual(splitting.graphs.filter(\.isHome).count, 1, "exactly one graph is home")
    check(!splitting.graphs.contains { $0.name == GraphPlans.defaultName }, "Machine-wide is only a name while there's one graph")
    splitting.merge()
    expectEqual(splitting.graphs.count, 1, "one graph again")
    expectEqual(splitting.graphs.first?.name, GraphPlans.defaultName, "and it's Machine-wide again")
    var dropping = Arrangement(labels: abFixtureLabels(), projects: abFixtureProjects())
    dropping.put(["work/x"], in: .newGraph)
    expectEqual(dropping.graphs.count, 2, "dropping a project on New graph makes a graph")
    expectEqual(dropping.graph(ofProject: "work/x")?.name, "Work", "the new graph is named after the project's purpose")

    // Split by account.
    var byAccount = Arrangement(labels: abFixtureLabels(), projects: abFixtureProjects())
    let made = byAccount.splitByAccount(byAccount.graphs[0].id) { $0.hasPrefix("personal/") ? "home-me" : "work-me" }
    expectEqual(made.count, 1, "one new graph for the second account")
    expectEqual(byAccount.graphs.count, 2, "two graphs after splitting by account")
    let workGraph = byAccount.graph(ofProject: "work/x")
    check(workGraph != nil && workGraph?.id != byAccount.graph(ofProject: "personal/a")?.id, "each account's projects sit in their own graph")
    expectEqual(workGraph?.backup.login, "work-me", "the new graph backs up to its account")
    check(byAccount.graph(ofProject: "playbook")?.id == workGraph?.id, "a whole area of one account moves as one")

    // MARK: The graph split

    let graphJSON = #"""
    {"directed":false,"multigraph":false,"built_at_commit":"abc",
     "graph":{"schema_version":2,"hyperedges":[{"id":"h1","nodes":["a1","a2","x1"]},{"id":"h2","nodes":["a1","x1"]}]},
     "hyperedges":[{"id":"h1","nodes":["a1","a2","x1"]},{"id":"h2","nodes":["a1","x1"]}],
     "nodes":[
      {"id":"a1","label":"A one","source_file":"personal/a/one.ts","community":1,"weight":0.1},
      {"id":"a2","label":"A two","source_file":"personal/a/two.ts","community":1},
      {"id":"x1","label":"X one","source_file":"work/x/one.ts","community":2},
      {"id":"lib","label":"react","source_file":"","community":3},
      {"id":"far","label":"unlinked lib","community":3}
     ],
     "links":[
      {"source":"a1","target":"a2","relation":"calls"},
      {"source":"a1","target":"x1","relation":"references"},
      {"source":"a2","target":"lib","relation":"imports"},
      {"source":"x1","target":"x1","relation":"calls","source_file":"personal/a/one.ts"}
     ]}
    """#
    let root = try JSONSerialization.jsonObject(with: Data(graphJSON.utf8)) as! [String: Any]
    let groups: Set<String> = ["personal", "work"]
    let parts = try GraphPartition.split(root) { SourcePath.project(of: $0, groups: groups) }
    expectEqual(Set(parts.keys), ["personal/a.json", "work/x.json", "_links.json", "_unattributed.json", "_index.json"], "the graph splits into a file per project plus links, libraries and the rest")
    let summary = try GraphPartition.verify(parts)
    expectEqual(summary, try GraphPartition.summary(of: root), "the parts join back into exactly the graph")
    let joined = try GraphPartition.join(parts)
    expectEqual((joined["hyperedges"] as? [[String: Any]])?.count, 2, "hyperedges are kept")
    expectEqual(((joined["graph"] as? [String: Any])?["hyperedges"] as? [[String: Any]])?.count, 2, "hyperedges inside graph are kept too")
    expectEqual(joined["built_at_commit"] as? String, "abc", "graph-level fields are kept")
    let linksText = String(decoding: parts["_links.json"]!, as: UTF8.self)
    check(linksText.contains("\"target\":\"x1\"") && linksText.contains("\"target\":\"lib\""), "links between projects and to libraries go in _links.json")
    check(String(decoding: parts["work/x.json"]!, as: UTF8.self).contains("\"source\":\"x1\",\"source_file\":\"personal/a/one.ts\""), "an edge goes by its nodes, not its source_file")
    let again = try GraphPartition.split(root) { SourcePath.project(of: $0, groups: groups) }
    check(again == parts, "splitting twice gives byte-identical files")
    var tampered = parts
    tampered["work/x.json"] = Data(#"{"nodes":[],"links":[]}"#.utf8)
    check((try? GraphPartition.verify(tampered)) == nil, "a part that lost a node fails the check")
    check(GraphPartition.fileName(for: "../../etc") == "etc.json", "a part's name can't climb out of graph/")

    let personalCut = BackupContents.cut(root) { $0.hasPrefix("personal/") }
    let cutIDs = Set((personalCut["nodes"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
    expectEqual(cutIDs, ["a1", "a2", "lib"], "a cut keeps its projects and the libraries they link to")
    expectEqual((personalCut["hyperedges"] as? [[String: Any]])?.count, 1, "a cut trims top-level hyperedges")
    expectEqual(((personalCut["graph"] as? [String: Any])?["hyperedges"] as? [[String: Any]])?.count, 1, "a cut trims hyperedges inside graph too")

    // The existing folder slices trim both copies of hyperedges now.
    let sliceOut = abTemp("slices")
    try abWrite(graphJSON, sliceOut.appendingPathComponent("graph.json"))
    try FolderSlices.write(graph: sliceOut.appendingPathComponent("graph.json"), outDirectory: sliceOut, folders: ["work"])
    let workSlice = try JSONSerialization.jsonObject(with: Data(contentsOf: FolderSlices.url(for: "work", outDirectory: sliceOut))) as? [String: Any]
    expectEqual(((workSlice?["graph"] as? [String: Any])?["hyperedges"] as? [[String: Any]])?.count, 0, "a folder slice no longer carries other folders' hyperedges")
    try? FileManager.default.removeItem(at: sliceOut)

    // MARK: Git rules

    let home = abTemp("home")
    try abWrite("""
    [user]
    \tname = Work Me
    \temail = work@example.com
    [includeIf "gitdir:~/code/personal/"]
    \tpath = ~/.gitconfig-home
    [includeIf "onbranch:main"]
    \tpath = ~/.gitconfig-branch
    """, home.appendingPathComponent(".gitconfig"))
    try abWrite("[user]\n\tname = Home Me\n\temail = home@example.com\n", home.appendingPathComponent(".gitconfig-home"))
    let rules = GitRules.read(home: home.path, environment: ["HOME": home.path, "XDG_CONFIG_HOME": home.appendingPathComponent(".config").path, "GIT_CONFIG_NOSYSTEM": "1"])
    expectEqual(rules.global, GitIdentity(name: "Work Me", email: "work@example.com"), "the global identity is read")
    expectEqual(rules.rules.map(\.folder), [home.path + "/code/personal/"], "includeIf gitdir rules are read, others skipped")
    expectEqual(rules.rules.first?.identity, GitIdentity(name: "Home Me", email: "home@example.com"), "a rule's identity comes from its included file")
    expectEqual(rules.identity(for: home.path + "/code/personal/app")?.email, "home@example.com", "a path under a rule gets its identity")
    expectEqual(rules.identity(for: home.path + "/code/work/app")?.email, "work@example.com", "any other path gets the global identity")
    expectEqual(GitRules.folder(fromKey: "includeif.gitdir/i:~/A/**.path", home: "/h"), "/h/A/", "gitdir/i and a trailing ** are understood")
    try? FileManager.default.removeItem(at: home)

    expectEqual(GitAccounts.owner(ofRemote: "git@github-personal:MarcusLai07/lumen.git"), "MarcusLai07", "the owner is read through an SSH alias")
    expectEqual(GitAccounts.owner(ofRemote: "https://github.com/CTG-Business/project-scm.git"), "CTG-Business", "the owner is read from HTTPS")
    expectEqual(GitAccounts.owner(ofRemote: "ssh://git@github.com/a/b.git"), "a", "the owner is read from an ssh:// URL")
    let fakeRules = GitRules(global: GitIdentity(name: "Work Me", email: "work@example.com"), rules: [GitRule(folder: "/r/personal/", configFile: "/h/.gitconfig-home", identity: GitIdentity(name: "Home Me", email: "home@example.com"))])
    let remotes = ["/r/personal/a": "git@github-personal:home-me/a.git", "/r/personal/b": "https://github.com/home-me/b.git", "/r/work/x": "git@github-work:some-org/x.git", "/r/work/y": "https://github.com/work-me/y.git"]
    let guessed = GitAccounts.guess(rules: fakeRules, logins: ["work-me", "home-me"], remotesByPath: remotes, confirmed: [:])
    expectEqual(guessed, ["/r/personal/": "home-me", "": "work-me"], "each rule's login is guessed from the remotes it owns")
    expectEqual(GitAccounts.guess(rules: fakeRules, logins: ["work-me", "home-me"], remotesByPath: remotes, confirmed: ["": "home-me"])[""], "home-me", "a confirmed login wins over the guess")
    let accounts = GitAccounts(rules: fakeRules, logins: ["work-me", "home-me"], loginByFolder: guessed)
    expectEqual(accounts.identity(forLogin: "home-me")?.email, "home@example.com", "a backup to the personal login signs as the personal identity")
    expectEqual(accounts.identity(forLogin: "work-me")?.email, "work@example.com", "a backup to the other login signs with the global identity")
    expectEqual(accounts.login(for: "/r/personal/a"), "home-me", "a path's login follows its rule")

    // MARK: What a backup holds

    let out = abTemp("graphify-out")
    try abWrite(graphJSON, out.appendingPathComponent("graph.json"))
    try abWrite(#"{"personal/a/one.ts":{"ast_hash":"1"},"work/x/one.ts":{"ast_hash":"2"},".claude/settings.json":{"ast_hash":"3"}}"#, out.appendingPathComponent("manifest.json"))
    try abWrite(#"{"nodes":[{"id":"a1","source_file":"personal/a/one.ts"}]}"#, out.appendingPathComponent("cache/semantic/v1/aaa.json"))
    try abWrite(#"{"nodes":[{"id":"x1","source_file":"work/x/one.ts"}]}"#, out.appendingPathComponent("cache/semantic/v1/xxx.json"))
    try abWrite(#"{"1":"Personal A","2":"Work X","3":"Libraries"}"#, out.appendingPathComponent(".graphify_labels.json"))
    try abWrite(#"{"1":"sigA","2":"sigX","3":"sigL"}"#, out.appendingPathComponent(".graphify_labels.json.sig"))
    try abWrite("""
    {"id":"r1","op":"hide_node","node":"x1"}
    {"id":"r2","op":"hide_path","glob":"personal/a/generated/**"}
    {"id":"r3","op":"hide_path","glob":"**/dist/**"}
    {"id":"r4","op":"revoke","rule":"r1"}
    """, out.appendingPathComponent("curation.jsonl"))
    try abWrite("# Guide listing work/x\n", out.appendingPathComponent(AgentGuide.fileName))
    try abWrite("# Playbook\n", out.appendingPathComponent(PlaybookFile.markdownName))
    try abWrite("{}", out.appendingPathComponent(PlaybookFile.jsonName))
    try abWrite("<html></html>", out.appendingPathComponent("graph.html"))
    try abWrite("# Report\n", out.appendingPathComponent("GRAPH_REPORT.md"))
    try abWrite("{}", out.appendingPathComponent("2026-11-12/graph.json"))
    try abWrite("{}", out.appendingPathComponent("cache/ast/v1/a.json"))
    let backupLabels = [FolderLabel(path: "personal", purpose: .personal, holdsProjects: true), FolderLabel(path: "work", purpose: .work, holdsProjects: true)]
    let backupProjects = [ArrangeProject(path: "personal/a", nodes: 2), ArrangeProject(path: "work/x", nodes: 1)]
    var single = Arrangement(labels: backupLabels, projects: backupProjects)
    let whole = try BackupContents.build(graphID: single.graphs[0].id, arrangement: single, outDirectory: out)
    check(whole.files.keys.contains("graph/personal/a.json") && whole.files.keys.contains("graph/work/x.json"), "one graph's backup holds every project")
    check(whole.files.keys.contains(AgentGuide.fileName) && whole.files.keys.contains("graph.html") && whole.files.keys.contains(PlaybookFile.markdownName), "one graph's backup holds the guide, the map and the playbook")
    check(!whole.files.keys.contains { $0.hasPrefix("2026-") || $0.hasPrefix("cache/ast") || $0 == "graph.json" }, "dated copies, the parse cache and the raw graph stay on this Mac")
    check(whole.items.contains { $0.id == "stays-dated" && $0.files == 1 }, "dated copies are listed under Stays")
    expectEqual(whole.files.keys.filter { $0.hasPrefix("cache/semantic/") }.count, 2, "AI-extracted meaning is saved")

    single.put(["work/x"], in: .leftOut)
    let withoutWork = try BackupContents.build(graphID: single.graphs[0].id, arrangement: single, outDirectory: out)
    check(!withoutWork.files.keys.contains("graph/work/x.json"), "a left-out project isn't in the backup")
    check(!String(decoding: withoutWork.files["manifest.json"] ?? Data(), as: UTF8.self).contains("work/x"), "nor in its rebuild index")

    var split = Arrangement(labels: backupLabels, projects: backupProjects)
    split.splitByAccount(split.graphs[0].id) { $0.hasPrefix("personal/") ? "home-me" : "work-me" }
    guard let personal = split.graph(ofProject: "personal/a"), let work = split.graph(ofProject: "work/x") else {
        check(false, "splitting by account gives two graphs")
        return
    }
    let personalBundle = try BackupContents.build(graphID: personal.id, arrangement: split, outDirectory: out)
    let workBundle = try BackupContents.build(graphID: work.id, arrangement: split, outDirectory: out)
    let personalText = personalBundle.files.filter { $0.key != BackupContents.joinScriptName }.values.map { String(decoding: $0, as: UTF8.self) }.joined(separator: "\n")
    check(!personalText.contains("work/x") && !personalText.contains("Work X") && !personalText.contains("sigX"), "nothing from the work graph is in the personal backup")
    check(!personalBundle.files.keys.contains("cache/semantic/v1/xxx.json") && personalBundle.files.keys.contains("cache/semantic/v1/aaa.json"), "each backup carries only its own AI-extracted meaning")
    check(String(decoding: personalBundle.files["curation.jsonl"] ?? Data(), as: UTF8.self).contains("r2") && String(decoding: personalBundle.files["curation.jsonl"] ?? Data(), as: UTF8.self).contains("r3"), "rules for its paths and rules for everywhere come along")
    check(!String(decoding: personalBundle.files["curation.jsonl"] ?? Data(), as: UTF8.self).contains("r4"), "a revoke follows the rule it undoes")
    check(String(decoding: workBundle.files["curation.jsonl"] ?? Data(), as: UTF8.self).contains("r4"), "and goes with that rule's graph")
    check(!personalBundle.files.keys.contains(AgentGuide.fileName) && !personalBundle.files.keys.contains("graph.html"), "whole-graph pages stay out of separate backups")
    let homeBundle = split.graphs.first(where: \.isHome)?.id == personal.id ? personalBundle : workBundle
    let otherBundle = homeBundle.graphID == personal.id ? workBundle : personalBundle
    check(homeBundle.files.keys.contains(PlaybookFile.markdownName) && !otherBundle.files.keys.contains(PlaybookFile.markdownName), "only the home backup carries the playbook")
    check(String(decoding: personalBundle.files[".graphify_labels.json"] ?? Data(), as: UTF8.self).contains("Libraries"), "a library community both graphs use is named in both")

    // MARK: Backing up to a repo

    let store = abTemp("backups")
    let bare = abTemp("remote").appendingPathComponent("kb.git")
    try abGit(["init", "--quiet", "--bare", "-b", "main", bare.path], in: store)
    var target = Arrangement(labels: backupLabels, projects: backupProjects)
    target.setBackup(BackupPlan(destination: .github, login: "home-me", repo: "machine-wide-kb", when: .manual), forGraph: target.graphs[0].id)
    let graph = target.graphs[0]
    let me = GitIdentity(name: "Home Me", email: "home@example.com")
    let first = try BackupRunner.run(bundle: try BackupContents.build(graphID: graph.id, arrangement: target, outDirectory: out), graph: graph, identity: me, message: "First backup", store: store, remote: bare.path, createRepo: false)
    check(first.commit != nil && first.pushed, "the first backup commits and pushes")
    expectEqual(try abGit(["--git-dir", bare.path, "log", "-1", "--format=%an <%ae>", "main"], in: store).output.trimmingCharacters(in: .whitespacesAndNewlines), "Home Me <home@example.com>", "the commit is signed as the account's identity")
    let tree = Set(try abGit(["--git-dir", bare.path, "ls-tree", "-r", "--name-only", "main"], in: store).output.split(separator: "\n").map(String.init))
    check(tree.contains("graph/_index.json") && tree.contains(BackupContents.readmeName) && !tree.contains("graph.json"), "the remote holds the parts and the README, not the raw graph")
    let mirrorAfterFirst = BackupStore.mirror(for: graph.backup, graph: graph, in: store)
    let unchangedLines = BackupDiff.lines(bundle: try BackupContents.build(graphID: graph.id, arrangement: target, outDirectory: out), mirror: mirrorAfterFirst)
    check(unchangedLines.isEmpty, "Review shows nothing to change right after a backup")
    var preview = target
    preview.put(["work/x"], in: .leftOut)
    let previewLines = BackupDiff.lines(bundle: try BackupContents.build(graphID: graph.id, arrangement: preview, outDirectory: out), mirror: mirrorAfterFirst)
    check(previewLines.contains { $0.path == "graph/" && $0.detail.contains("removed") }, "Review shows a left-out project's files being removed")
    let repeated = try BackupRunner.run(bundle: try BackupContents.build(graphID: graph.id, arrangement: target, outDirectory: out), graph: graph, identity: me, message: "Again", store: store, remote: bare.path, createRepo: false)
    check(repeated.commit == nil && !repeated.pushed, "backing up again with no changes commits nothing")
    target.put(["work/x"], in: .leftOut)
    _ = try BackupRunner.run(bundle: try BackupContents.build(graphID: graph.id, arrangement: target, outDirectory: out), graph: target.graphs[0], identity: me, message: "Without work", store: store, remote: bare.path, createRepo: false)
    let treeAfter = try abGit(["--git-dir", bare.path, "ls-tree", "-r", "--name-only", "main"], in: store).output
    check(!treeAfter.contains("graph/work/x.json"), "a project left out disappears from the backup")
    check(BackupStore.records(in: store)[graph.id]?.lastSuccess != nil, "the last backup is recorded")

    // A commit pushed from elsewhere is taken in; split histories stop the backup.
    let elsewhere = abTemp("elsewhere")
    try abGit(["clone", "--quiet", bare.path, elsewhere.appendingPathComponent("kb").path], in: elsewhere)
    try abWrite("note\n", elsewhere.appendingPathComponent("kb/NOTE.md"))
    try abGit(["add", "-A"], in: elsewhere.appendingPathComponent("kb"))
    try abGit(["commit", "--quiet", "-m", "From another Mac"], in: elsewhere.appendingPathComponent("kb"))
    try abGit(["push", "--quiet", "origin", "main"], in: elsewhere.appendingPathComponent("kb"))
    target.put(["work/x"], in: .area("work"))
    let caughtUp = try BackupRunner.run(bundle: try BackupContents.build(graphID: graph.id, arrangement: target, outDirectory: out), graph: target.graphs[0], identity: me, message: "After another Mac", store: store, remote: bare.path, createRepo: false)
    check(caughtUp.pushed, "a commit pushed from elsewhere is taken in first, then the backup goes on top")
    let mirror = BackupStore.mirror(for: target.graphs[0].backup, graph: target.graphs[0], in: store)
    try abWrite("local\n", mirror.appendingPathComponent("LOCAL.md"))
    try abGit(["add", "-A"], in: mirror)
    try abGit(["commit", "--quiet", "-m", "Only on this Mac"], in: mirror)
    try abWrite("other\n", elsewhere.appendingPathComponent("kb/OTHER.md"))
    try abGit(["pull", "--quiet", "--ff-only"], in: elsewhere.appendingPathComponent("kb"))
    try abGit(["add", "-A"], in: elsewhere.appendingPathComponent("kb"))
    try abGit(["commit", "--quiet", "-m", "Split from this Mac"], in: elsewhere.appendingPathComponent("kb"))
    try abGit(["push", "--quiet", "origin", "main"], in: elsewhere.appendingPathComponent("kb"))
    let remoteHead = try abGit(["--git-dir", bare.path, "rev-parse", "main"], in: store).output
    check((try? BackupRunner.run(bundle: try BackupContents.build(graphID: graph.id, arrangement: target, outDirectory: out), graph: target.graphs[0], identity: me, message: "Diverged", store: store, remote: bare.path, createRepo: false)) == nil, "split histories stop the backup")
    expectEqual(try abGit(["--git-dir", bare.path, "rev-parse", "main"], in: store).output, remoteHead, "and nothing is pushed over the other Mac's work")
    check(BackupStore.records(in: store)[graph.id]?.lastError != nil, "the failure is recorded")

    // A bundle whose graph parts don't join up is never committed.
    let freshStore = abTemp("backups-fresh")
    let freshBare = abTemp("remote-fresh").appendingPathComponent("kb.git")
    try abGit(["init", "--quiet", "--bare", "-b", "main", freshBare.path], in: freshStore)
    let good = try BackupContents.build(graphID: graph.id, arrangement: target, outDirectory: out)
    var broken = good.files
    broken["graph/personal/a.json"] = Data(#"{"nodes":[],"links":[]}"#.utf8)
    let brokenBundle = BackupBundle(graphID: good.graphID, files: broken, items: good.items, summary: good.summary, projects: good.projects)
    check((try? BackupRunner.run(bundle: brokenBundle, graph: target.graphs[0], identity: me, message: "Broken", store: freshStore, remote: freshBare.path, createRepo: false)) == nil, "a failed join check blocks the commit")
    let freshHead = try abGit(["--git-dir", freshBare.path, "rev-parse", "--verify", "--quiet", "main"], in: freshStore)
    check(freshHead.status != 0, "nothing reached the remote")

    var local = Arrangement(labels: backupLabels, projects: backupProjects)
    local.setBackup(BackupPlan(destination: .local), forGraph: local.graphs[0].id)
    let localOutcome = try BackupRunner.run(bundle: try BackupContents.build(graphID: local.graphs[0].id, arrangement: local, outDirectory: out), graph: local.graphs[0], identity: me, message: "Local", store: freshStore)
    check(localOutcome.commit != nil && !localOutcome.pushed, "a this-Mac-only backup commits without pushing")

    for folder in [out, store, bare.deletingLastPathComponent(), elsewhere, freshStore, freshBare.deletingLastPathComponent()] {
        try? FileManager.default.removeItem(at: folder)
    }
}

import Foundation

// Checks for moving and renaming folders on disk, and for graph cuts. Everything runs in a
// throwaway root with real git repos, linked worktrees, git rules and remotes. Called from main.swift.

private func mvTemp(_ name: String) -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@discardableResult
private func mvGit(_ arguments: [String], in folder: String) throws -> ProcessOutput {
    try ProcessRunner.run("/usr/bin/git", ["-c", "user.name=Checks", "-c", "user.email=checks@example.com", "-c", "commit.gpgsign=false"] + arguments, in: URL(fileURLWithPath: folder))
}

private func mvWrite(_ text: String, _ path: String) throws {
    try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try text.write(toFile: path, atomically: true, encoding: .utf8)
}

private func mvRepo(_ path: String, remote: String? = nil) throws {
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    try mvGit(["init", "-q", "-b", "main"], in: path)
    try mvWrite("hello\n", (path as NSString).appendingPathComponent("README.txt"))
    try mvGit(["add", "-A"], in: path)
    try mvGit(["commit", "-q", "-m", "First"], in: path)
    if let remote { try mvGit(["remote", "add", "origin", remote], in: path) }
}

private func mvRead(_ path: String) -> String { (try? String(contentsOfFile: path, encoding: .utf8)) ?? "" }

func moveChecks() throws {
    let fileManager = FileManager.default
    // The real path, so git's own paths (under /private/var) and ours agree.
    let root = FolderMoves.realPath(mvTemp("moves").path)
    func at(_ path: String) -> String { (root as NSString).appendingPathComponent(path) }
    let out = URL(fileURLWithPath: at("graphify-out"))

    // MARK: A root with real repos

    try mvRepo(at("personal/app"), remote: "git@github-personal:MePersonal/app.git")
    try mvRepo(at("personal/tool"), remote: "git@github-personal:MePersonal/tool.git")
    try mvRepo(at("work/svc"), remote: "git@github-work:MeWork/svc.git")
    try mvRepo(at("work/org"), remote: "git@github-work:SomeOrg/org.git")
    try mvRepo(at("Solo"))
    try mvRepo(at("archive/old"))
    // A linked worktree beside the repo, and one inside it, as Claude Code makes them.
    try mvGit(["worktree", "add", "-q", at("personal/app-wt"), "-b", "feature"], in: at("personal/app"))
    try mvGit(["worktree", "add", "-q", ".claude/worktrees/x", "-b", "x"], in: at("personal/app"))
    try mvWrite(at("personal/app"), at("personal/app/graphify-out/.graphify_root"))
    try mvWrite("export A=1\n", at("personal/app/.envrc"))
    try mvWrite("services:\n  web:\n    image: nginx\n", at("personal/app/docker-compose.yml"))
    try mvWrite("home = /usr/bin\n", at("personal/app/.venv/pyvenv.cfg"))
    try mvWrite("VIRTUAL_ENV=\"\(at("personal/app/.venv"))\"\n", at("personal/app/.venv/bin/activate"))
    try mvWrite(String(repeating: "docs ", count: 800), at("personal/app/README.md"))
    try mvWrite("# Solo\n", at("Solo/NOTES.md"))

    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let labels = [
        FolderLabel(path: "personal", purpose: .personal, holdsProjects: true),
        FolderLabel(path: "work", purpose: .work, holdsProjects: true),
        FolderLabel(path: "Solo", purpose: .other, note: "A side thing on its own"),
        FolderLabel(path: "archive", purpose: .archive, holdsProjects: true, isIncluded: false),
    ]
    try FolderFile.save(FolderMap(folders: labels), to: out)
    try GraphPlans.save([
        GraphPlan(id: "g-personal", name: "Personal", areaIDs: ["personal", "Solo"], isHome: true),
        GraphPlan(id: "g-work", name: "Work", areaIDs: ["work"]),
    ], to: out)
    try mvWrite("# Left out\n/archive/\n/personal/tool/\npersonal/app/dist/\n", at(".graphifyignore"))
    try mvWrite(#"{"personal/app/README.md": {"mtime": 1}, "personal/app/main.py": {"mtime": 1}, "personal/apple/README.md": {"mtime": 1}, "Solo/NOTES.md": {"mtime": 1}}"#, out.appendingPathComponent("manifest.json").path)
    try mvWrite("""
    {"at":"2026-11-01T00:00:00Z","id":"r1","node":"personal_app_main_run","op":"hide_node","label":"run"}
    {"at":"2026-11-01T00:00:00Z","glob":"personal/app/generated/**","id":"r2","op":"hide_path","note":"generated"}
    {"at":"2026-11-01T00:00:00Z","id":"r3","node":"work_svc_api","op":"hide_node","label":"api"}

    """, out.appendingPathComponent("curation.jsonl").path)
    var book = Playbook()
    book.folderStacks = ["Solo": ["language": StackAnswer(choices: ["Swift"])]]
    try PlaybookFile.save(book, to: out)
    try mvWrite(#"""
    {"directed":false,"multigraph":false,"graph":{},"hyperedges":[],
     "nodes":[
      {"id":"personal_app_main_run","label":"run","source_file":"personal/app/main.py"},
      {"id":"solo_notes","label":"Solo notes","source_file":"Solo/NOTES.md"},
      {"id":"work_svc_api","label":"api","source_file":"work/svc/api.py"},
      {"id":"loose","label":"top file","source_file":"setup.sh"},
      {"id":"lib","label":"requests","source_file":""}
     ],
     "links":[
      {"source":"personal_app_main_run","target":"solo_notes","relation":"references"},
      {"source":"personal_app_main_run","target":"work_svc_api","relation":"calls"},
      {"source":"work_svc_api","target":"lib","relation":"imports"}
     ]}
    """#, out.appendingPathComponent("graph.json").path)

    func arrangement() -> Arrangement {
        BackupJob.arrangement(outDirectory: out, graph: nil, scan: FolderScan.scan(root: root, identity: []), nodes: [:])
    }
    let start = arrangement()
    expectEqual(start.leftOutReason("personal/app-wt"), "Worktree", "the fixture's worktree is left out, as Arrange does")
    check(start.placement(of: "personal/tool").isLeftOut, "a project with its own ignore line is left out")
    expectEqual(start.placement(of: "personal/app"), .area("personal"), "the fixture's app sits in Personal")

    // MARK: What stops a move

    func blockers(_ request: MoveRequest) -> [String] { FolderMoves.blockers(request, root: root, labels: labels) }
    check(blockers(.rename("personal/app", to: "tool")).contains { $0.contains("already in personal/") }, "a name that's taken stops a rename")
    check(blockers(.rename("personal/app", to: "TOOL")).contains { $0.contains("already in personal/") }, "names are compared ignoring case, as APFS does")
    check(blockers(.rename("personal/app", to: "App")).isEmpty, "a rename that only changes case is allowed")
    check(blockers(.rename("personal/app", to: "a/b")).contains("Names can't contain / or :."), "a slash in a name stops a rename")
    check(blockers(.rename("personal/app", to: ".app")).contains { $0.contains("dot") }, "a hidden name stops a rename")
    check(blockers(MoveRequest(item: "personal/app", newParent: "personal/app")).contains("A folder can't go inside itself."), "a folder can't move inside itself")
    check(blockers(MoveRequest(item: "personal", newParent: "work")).contains { $0.contains("holds projects") }, "a whole group isn't moved")
    check(blockers(MoveRequest(item: "personal/app", newParent: "nowhere")).contains { $0.contains("isn't there") }, "a missing destination stops a move")
    try mvWrite("", at("personal/tool/.git/index.lock"))
    check(blockers(MoveRequest(item: "personal/tool", newParent: "work")).contains { $0.contains("index.lock") }, "git in the middle of something stops a move")
    try fileManager.removeItem(atPath: at("personal/tool/.git/index.lock"))
    check(blockers(MoveRequest(item: "personal/app", newParent: "work")).isEmpty, "a move into another group is fine")

    // MARK: What the sheet shows

    let rules = GitRules(global: GitIdentity(name: "Me", email: "me@work.example"), rules: [
        GitRule(folder: at("personal") + "/", configFile: "/tmp/personal.gitconfig", identity: GitIdentity(name: "Me", email: "me@home.example")),
    ])
    let accounts = GitAccounts(rules: rules, logins: ["MePersonal", "MeWork"], loginByFolder: [at("personal") + "/": "MePersonal", "": "MeWork"])
    let sleeper = Process()
    sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep")
    sleeper.arguments = ["30"]
    sleeper.currentDirectoryURL = URL(fileURLWithPath: at("personal/app"))
    try sleeper.run()
    let toWork = MoveRequest(item: "personal/app", newParent: "work")
    let sheet = FolderMoves.check(toWork, root: root, outDirectory: out, arrangement: start, rules: rules, accounts: accounts, busy: nil, playbook: book)
    sleeper.terminate()
    check(sheet.canMove, "the move can go ahead")
    check(sheet.updates.contains { $0.contains("stays in Personal") }, "the sheet says where it stays in the arrangement")
    check(sheet.updates.contains { $0.contains("worktree links to personal/app-wt") && $0.contains(".claude/worktrees/x") }, "both linked worktrees are named")
    check(sheet.updates.contains { $0.contains(".graphify_root") }, "the repo's own graph root is mentioned")
    check(sheet.updates.contains { $0.contains("1 line in .graphifyignore") || $0.contains("Its line in .graphifyignore") }, "its ignore line is mentioned")
    check(sheet.updates.contains { $0.contains("2 cleanup rules") }, "cleanup rules naming it are counted, and not ones for other folders")
    check(sheet.rules.first?.contains("Commits sign as Me <me@home.example> in personal/. In work/ they'll sign as Me <me@work.example>, your global identity, since no git rule covers work/.") == true, "the identity change across git rules is spelled out")
    expectEqual(sheet.remoteChoice?.suggested, "git@github-work:MeWork/app.git", "the new remote uses the host alias the other account's repos use")
    expectEqual(sheet.remoteChoice?.currentOwner, "MePersonal", "the current owner is named")
    check(sheet.yours.contains { $0.contains("sleep") }, "a program working inside the folder is named, from lsof")
    check(sheet.yours.contains { $0.contains(".venv/") }, "a Python environment with the old path baked in is flagged")
    check(sheet.yours.contains { $0.contains("direnv") }, "direnv's approval is flagged")
    check(!sheet.yours.contains { $0.contains("docker compose") }, "a move keeps the folder's name, so compose is fine")
    expectEqual(sheet.docs.files.map(\.path), ["personal/app/README.md"], "only its own docs are counted, not personal/apple's or its code")
    expectEqual(sheet.docs.contentTokens, (4_000 + 160) / 4, "doc tokens follow graphify's estimate")
    let rename = FolderMoves.check(.rename("personal/app", to: "app2"), root: root, outDirectory: out, arrangement: start, rules: rules, accounts: accounts, busy: "graphify is building.", playbook: book)
    check(rename.yours.contains { $0.contains("docker compose") }, "renaming a folder with an unnamed compose project warns about its containers")
    check(rename.rules.isEmpty && rename.remoteChoice == nil, "a rename in the same folder changes nothing for git")
    check(!rename.canMove && rename.blockers.contains("graphify is building."), "a busy graphify stops the move")
    let orgMove = FolderMoves.check(MoveRequest(item: "work/org", newParent: "personal"), root: root, outDirectory: out, arrangement: start, rules: rules, accounts: accounts, busy: nil)
    check(orgMove.remoteChoice == nil && !orgMove.rules.isEmpty, "a repo owned by an organisation gets no remote change, only the identity note")

    // MARK: Moving, with every fix-up

    let move = try FolderMoves.perform(toWork, root: root, outDirectory: out, arrangement: start, remote: sheet.remoteChoice?.suggested)
    check(fileManager.fileExists(atPath: at("work/app/README.txt")) && !fileManager.fileExists(atPath: at("personal/app")), "the folder moved")
    expectEqual(move.fixups?.worktrees.count, 2, "both worktree links were repaired")
    let linked = try mvGit(["rev-parse", "--git-common-dir"], in: at("personal/app-wt"))
    check(linked.status == 0 && linked.output.contains("work/app/.git"), "the worktree beside it finds its main repo in the new place")
    let innerAfter = try mvGit(["status", "--short"], in: at("work/app/.claude/worktrees/x"))
    check(innerAfter.status == 0, "the worktree inside it works after the move")
    let listed = try mvGit(["worktree", "list", "--porcelain"], in: at("work/app")).output
    check(listed.contains(at("personal/app-wt")) && listed.contains(at("work/app/.claude/worktrees/x")), "the main repo lists both worktrees where they are now")
    expectEqual(mvRead(at("work/app/graphify-out/.graphify_root")), at("work/app"), "the repo's own graph names its new folder")
    expectEqual(FolderMoves.originURL(repo: at("work/app")), "git@github-work:MeWork/app.git", "the remote points at the other account when asked")
    let afterMove = arrangement()
    expectEqual(afterMove.placement(of: "work/app"), .area("personal"), "the arrangement keeps it in Personal")
    expectEqual(afterMove.graph(ofProject: "work/app")?.name, "Personal", "and in the Personal graph")
    check(mvRead(at(".graphifyignore")).contains("\nwork/app/dist/\n") && !mvRead(at(".graphifyignore")).contains("personal/app/dist"), "its ignore line follows it")
    expectEqual(GraphPlans.load(from: out)?.map(\.areaIDs), [["personal", "Solo"], ["work"]], "graphs keep their areas")
    expectEqual(FolderMoves.load(from: out).count, 1, "the move is logged")
    let moved = FolderMoves.carriedRules(try CurationLog(url: out.appendingPathComponent("curation.jsonl")).entries, from: "personal/app", to: "work/app", nodeExists: { $0 == "work_app_main_run" })
    expectEqual(moved.map(\.id), ["r1", "r2"], "the rules naming the old path carry over once the node exists")
    check(moved.contains { $0.action == .hideNode(id: "work_app_main_run", label: "run") } && moved.contains { $0.action == .hidePath(glob: "work/app/generated/**", note: "generated") }, "carried rules name the new path")
    expectEqual(FolderMoves.carriedRules(try CurationLog(url: out.appendingPathComponent("curation.jsonl")).entries, from: "personal/app", to: "work/app", nodeExists: { _ in false }).map(\.id), ["r2"], "a node rule waits until the rebuild has made the node")

    // MARK: Undo puts everything back

    let undone = try FolderMoves.undoLast(root: root, log: out, arrangement: afterMove)
    expectEqual(undone?.to, "work/app", "undo takes the last move")
    check(fileManager.fileExists(atPath: at("personal/app/README.txt")) && !fileManager.fileExists(atPath: at("work/app")), "the folder is back")
    let linkedBack = try mvGit(["rev-parse", "--git-common-dir"], in: at("personal/app-wt"))
    check(linkedBack.output.contains("personal/app/.git"), "the worktree link is repaired again")
    let innerBack = try mvGit(["status", "--short"], in: at("personal/app/.claude/worktrees/x"))
    check(innerBack.status == 0, "the inner worktree still works")
    expectEqual(mvRead(at("personal/app/graphify-out/.graphify_root")), at("personal/app"), "the root file is back")
    expectEqual(FolderMoves.originURL(repo: at("personal/app")), "git@github-personal:MePersonal/app.git", "the remote is back")
    let afterUndo = arrangement()
    check(FolderFile.load(from: out)?.placement["personal/app"] == nil && afterUndo.placement(of: "personal/app") == .area("personal"), "no placement is left behind")
    check(mvRead(at(".graphifyignore")).contains("\npersonal/app/dist/\n"), "the ignore line is back")
    expectEqual(FolderMoves.load(from: out), [], "the log is empty again")

    // MARK: Renaming a main folder

    try FolderMoves.perform(.rename("Solo", to: "Solo2"), root: root, outDirectory: out, arrangement: afterUndo)
    let renamed = arrangement()
    check(renamed.labels.contains { $0.path == "Solo2" && $0.note == "A side thing on its own" } && !renamed.labels.contains { $0.path == "Solo" }, "the label follows the rename with its note")
    expectEqual(GraphPlans.load(from: out)?.first?.areaIDs, ["personal", "Solo2"], "its area, named after the folder, stays in its graph under the new name")
    expectEqual(renamed.graph(ofProject: "Solo2")?.name, "Personal", "the project stays in its graph")
    check(PlaybookFile.load(from: out).folderStacks?["Solo2"] != nil && PlaybookFile.load(from: out).folderStacks?["Solo"] == nil, "its own stack follows the new name")
    try FolderMoves.undoLast(root: root, log: out, arrangement: renamed)
    check(arrangement().labels.contains { $0.path == "Solo" } && PlaybookFile.load(from: out).folderStacks?["Solo"] != nil, "undo renames the label and stack back")
    expectEqual(GraphPlans.load(from: out)?.first?.areaIDs, ["personal", "Solo"], "and the area")

    // MARK: A main folder into a group, and back

    let soloIn = try FolderMoves.perform(MoveRequest(item: "Solo", newParent: "personal"), root: root, outDirectory: out, arrangement: arrangement())
    let grouped = arrangement()
    let made = soloIn.fixups?.madeArea
    check(!grouped.labels.contains { $0.path == "Solo" } && soloIn.fixups?.removedLabel?.note == "A side thing on its own", "inside a group it loses its label, kept for undo")
    check(made != nil && grouped.placement(of: "personal/Solo") == .area(made!) && grouped.area(made!)?.name == "Solo", "it keeps an area of its own, now made in Arrange")
    expectEqual(GraphPlans.load(from: out)?.first?.areaIDs, ["personal", made ?? "?"], "that area stays in its graph")
    try FolderMoves.undoLast(root: root, log: out, arrangement: grouped)
    let ungrouped = arrangement()
    check(ungrouped.labels.contains { $0.path == "Solo" && $0.note == "A side thing on its own" }, "undo brings the label back with its note")
    check(ungrouped.arrangedAreas.isEmpty && FolderFile.load(from: out)?.placement.isEmpty ?? true, "and the made area merges back")
    expectEqual(GraphPlans.load(from: out)?.first?.areaIDs, ["personal", "Solo"], "the graph holds the label's area again")

    // MARK: Left out stays left out

    try FolderMoves.perform(MoveRequest(item: "personal/tool", newParent: "work"), root: root, outDirectory: out, arrangement: ungrouped)
    check(mvRead(at(".graphifyignore")).contains("\n/work/tool/\n") && arrangement().placement(of: "work/tool").isLeftOut, "a left-out project's line follows it, so it stays out")
    try FolderMoves.undoLast(root: root, log: out, arrangement: arrangement())
    try FolderMoves.perform(MoveRequest(item: "archive/old", newParent: "personal"), root: root, outDirectory: out, arrangement: arrangement())
    check(!mvRead(at(".graphifyignore")).contains("/personal/old/") && arrangement().placement(of: "personal/old") == .area("personal"), "a project left out only because its folder is joins the graph in its new folder")
    try FolderMoves.undoLast(root: root, log: out, arrangement: arrangement())
    try FolderMoves.perform(MoveRequest(item: "personal/app", newParent: "archive"), root: root, outDirectory: out, arrangement: arrangement())
    let archived = arrangement()
    check(archived.placement(of: "archive/app").isLeftOut && FolderFile.load(from: out)?.placement["archive/app"] == nil, "moved into a folder left out as a whole, it's left out with it")
    try FolderMoves.undoLast(root: root, log: out, arrangement: archived)
    expectEqual(arrangement().placement(of: "personal/app"), .area("personal"), "and comes back in")

    // MARK: Out of a group to the top level

    try FolderMoves.perform(MoveRequest(item: "personal/app", newParent: ""), root: root, outDirectory: out, arrangement: arrangement())
    let topped = arrangement()
    check(topped.labels.contains { $0.path == "app" && $0.purpose == .personal }, "at the top level it gets a label with its area's purpose")
    expectEqual(topped.placement(of: "app"), .area("personal"), "and stays in Personal")
    try FolderMoves.undoLast(root: root, log: out, arrangement: topped)
    check(!arrangement().labels.contains { $0.path == "app" }, "undo takes the label away again")

    // MARK: The pieces

    expectEqual(FolderMoves.rebasedIgnoreLine("!/personal/app/keep.md", from: "personal/app", to: "work/app"), "!/work/app/keep.md", "negations and slashes are kept")
    expectEqual(FolderMoves.rebasedIgnoreLine("personal/apple/", from: "personal/app", to: "work/app"), "personal/apple/", "a folder whose name only starts the same is left alone")
    expectEqual(FolderMoves.rebasedIgnoreLine("# personal/app/", from: "personal/app", to: "work/app"), "# personal/app/", "comments are left alone")
    expectEqual(FolderMoves.suggestedRemote("https://github.com/MePersonal/app.git", login: "MeWork", others: []), "https://github.com/MeWork/app.git", "an https remote stays https")
    expectEqual(FolderMoves.suggestedRemote("git@github-personal:MePersonal/app.git", login: "MeWork", others: ["git@github-work:SomeOrg/a.git", "git@github-work:Other/b.git", "https://github.com/MeWork/c.git"]),
                "git@github-work:MeWork/app.git", "when the login owns no SSH remote there, the alias the folder's repos use is taken, never the old one")
    expectEqual(FolderMoves.idPrefix(for: "personal/my-app"), "personal_my_app_", "node ids start with the path, as graphify writes them")
    let fakeHome = mvTemp("home").path
    try fileManager.createDirectory(atPath: fakeHome + "/.claude/projects/-Users-me-Documents-GitHub-personal-my-app", withIntermediateDirectories: true)
    expectEqual(FolderMoves.claudeProjectFolder(for: "/Users/me/Documents/GitHub/personal/my.app", home: fakeHome), fakeHome + "/.claude/projects/-Users-me-Documents-GitHub-personal-my-app", "Claude Code's folder for a project is found by its path")
    try? fileManager.removeItem(atPath: fakeHome)
    try FolderMoves.newFolder("clients", root: root)
    check(fileManager.fileExists(atPath: at("clients")), "a new folder is made")
    check((try? FolderMoves.newFolder("Clients", root: root)) == nil, "a new folder's name can't clash, ignoring case")
    expectEqual(FolderMoves.includeIfLines(folder: "clients", root: "/Users/me/Documents/GitHub", like: GitRule(folder: "/Users/me/Documents/GitHub/personal/", configFile: "/Users/me/.gitconfig-personal", identity: nil), home: "/Users/me"),
                "[includeIf \"gitdir:~/Documents/GitHub/clients/\"]\n\tpath = ~/.gitconfig-personal", "the includeIf lines to copy")

    // A main folder that is itself the project, dragged to Left out, gets its own ignore line.
    var outSolo = arrangement()
    outSolo.put(["Solo"], in: .leftOut)
    check(outSolo.ignoreChanges.add.contains("/Solo/"), "a top-level project left out by dragging is left out of the build too")

    // MARK: Graph cuts

    let whole = try GraphPartition.read(out.appendingPathComponent("graph.json"))
    let cuts = try GraphCuts.write(whole, arrangement: arrangement(), outDirectory: out)
    expectEqual(cuts.map(\.file), ["graphs/personal.json", "graphs/work.json"], "a cut per graph")
    let personalCut = try GraphPartition.read(out.appendingPathComponent("graphs/personal.json"))
    let personalIDs = Set((personalCut["nodes"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
    expectEqual(personalIDs, ["personal_app_main_run", "solo_notes", "loose"], "the Personal cut has its projects and loose files, which go with the home graph")
    let workCut = try GraphPartition.read(out.appendingPathComponent("graphs/work.json"))
    let workIDs = Set((workCut["nodes"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
    expectEqual(workIDs, ["work_svc_api", "lib"], "the Work cut has its code and the library it uses")
    check(!(personalCut["links"] as? [[String: Any]] ?? []).contains { ($0["target"] as? String) == "work_svc_api" }, "no link crosses from one cut to another")
    expectEqual(GraphCuts.entry(forPath: "work/svc/src/api.py", outDirectory: out)?.name, "Work", "a path finds its project's cut")
    expectEqual(GraphCuts.entry(forPath: "Solo", outDirectory: out)?.name, "Personal", "a top-level project finds its cut")
    expectEqual(GraphCuts.entry(named: "work", outDirectory: out)?.name, "Work", "a cut is found by name, ignoring case")
    let source = GraphSource(outDirectory: out)
    let inWork = GraphitreeTools(source: source, cwd: at("work/svc"))
    expectEqual(try inWork.graphPath(folder: nil, wholeGraph: false), out.appendingPathComponent("graphs/work.json").path, "a question asked inside a project goes to its graph")
    expectEqual(try inWork.graphPath(folder: nil, wholeGraph: true), out.appendingPathComponent("graphs/work.json").path, "the MCP server keeps to the project's graph too")
    let wholePath = try inWork.graphPath(folder: nil, wholeGraph: true, ignoresCuts: true)
    check(wholePath != out.appendingPathComponent("graphs/work.json").path, "--all asks the whole graph")
    expectEqual(try inWork.graphPath(folder: nil, wholeGraph: false, graph: "Personal"), out.appendingPathComponent("graphs/personal.json").path, "--in picks a graph by name")
    check((try? inWork.graphPath(folder: nil, wholeGraph: false, graph: "Nope")) == nil, "an unknown graph name is refused")
    check(inWork.folders().contains("2 separate graphs"), "list_folders names the separate graphs")
    let pointer = RepoPointer.block(playbook: Playbook(), folder: nil, hasCommand: true, graph: "Work")
    check(pointer.contains("a graph of its own, Work") && pointer.contains("this repo's graph only"), "a repo pointer names its separate graph")
    var oneGraph = arrangement()
    oneGraph.merge()
    try GraphCuts.write(whole, arrangement: oneGraph, outDirectory: out)
    check(!fileManager.fileExists(atPath: out.appendingPathComponent("graphs").path) && GraphCuts.load(from: out).isEmpty, "with one graph the cuts are removed")

    try? fileManager.removeItem(atPath: root)
}

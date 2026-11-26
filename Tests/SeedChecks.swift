import Foundation

// Checks for starters: which repos get one, what's in it, writing it without overwriting
// anything, Claude Code's skill links, and what a repo changed since. A made-up root only.
// Called from main.swift.

func seedChecks() throws {
    let manager = FileManager.default
    let base = manager.temporaryDirectory.appendingPathComponent("graphitree-seeds-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: base) }
    let root = base.appendingPathComponent("code").path
    let out = URL(fileURLWithPath: root).appendingPathComponent("graphify-out")

    @discardableResult
    func write(_ relative: String, _ text: String) throws -> String {
        let path = (root as NSString).appendingPathComponent(relative)
        try manager.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }
    func repo(_ relative: String) throws {
        try manager.createDirectory(atPath: (root as NSString).appendingPathComponent(relative + "/.git"), withIntermediateDirectories: true)
    }
    func read(_ relative: String) -> String? {
        try? String(contentsOfFile: (root as NSString).appendingPathComponent(relative), encoding: .utf8)
    }

    // The made-up root: kiln has nothing, ledger has its own CLAUDE.md, sketch isn't a repo,
    // depot and quarry are in a folder whose purpose is shared (depot with skills of its own), and
    // studio's main folder has no label.
    for name in ["personal/kiln", "personal/ledger", "work/depot", "work/quarry", "studio"] { try repo(name) }
    try manager.createDirectory(atPath: root + "/personal/sketch", withIntermediateDirectories: true)
    try write("personal/ledger/CLAUDE.md", "# ledger\n")
    try write("personal/ledger/.claude/skills/deploy/SKILL.md", "---\nname: deploy\ndescription: \"Ships ledger to the \\\"staging\\\" box\"\n---\n\nRun the deploy script.\n")
    try write("work/depot/.agents/skills/ship/SKILL.md", "---\nname: ship\ndescription: Ships depot\n---\n\nDepot's own steps.\n")
    try manager.createDirectory(atPath: root + "/personal/kiln/.claude/skills", withIntermediateDirectories: true)
    var map = FolderMap()
    map.folders = [
        FolderLabel(path: "personal", purpose: .personal, holdsProjects: true),
        FolderLabel(path: "work", purpose: .work, holdsProjects: true),
    ]

    var survey = Seeds.survey(root: root, map: map, book: Seeds.Book(), moves: [])
    expectEqual(survey.repos.map(\.path), ["personal/kiln", "personal/ledger"], "starters: only git repos in folders that can get one are listed")
    expectEqual(survey.offers.map(\.path), ["personal/kiln"], "starters: a repo with nothing of its own is offered one, even with an empty skills folder")
    expectEqual(survey.repos.last?.state, .ownSetup(["CLAUDE.md", ".claude/skills"]), "starters: a CLAUDE.md or skills Graphitree didn't write mean the repo's own setup")
    expectEqual(survey.shared.map(\.path), ["work/depot", "work/quarry"], "starters: repos with a shared purpose are listed apart from the others")
    expectEqual(survey.shared.first?.state, .ownSetup([".agents/skills"]), "starters: a shared repo with its own setup is left alone")
    expectEqual(survey.sharedOffers.map(\.path), ["work/quarry"], "starters: a shared repo with nothing of its own can get one, but isn't counted as an offer")
    check(survey.sharedOffers.first?.isNew == false, "starters: a shared repo is never marked new")
    expectEqual(survey.unlabelled, ["studio"], "starters: a main folder with no label isn't offered one")
    expectEqual(Seeds.survey(root: root, map: nil, book: Seeds.Book(), moves: []).repos, [], "starters: nothing is offered before folders are labelled")

    // The playbook: rules, a stack with a different answer in personal, a habit that must stay
    // out, and skills that reach different repos.
    var playbook = Playbook()
    playbook.rules = [PlaybookRule(text: "One library per job."), PlaybookRule(text: "Toasts come from the design system.", category: "UI")]
    playbook.stack = ["web": StackAnswer(choices: ["Vue"])]
    playbook.folderStacks = ["personal": ["web": StackAnswer(choices: ["SwiftUI"], notes: "Mac first")]]
    playbook.habits = ["design": "A private habit about how the owner works."]
    var notes = PlaybookSkill(name: "release-notes", description: "Writes \"release notes\" from commits. Use when tagging.", body: "Read the commits since the last tag.")
    notes.files = [SkillFile(path: "scripts/tag.sh", text: "git describe --tags")]
    var personalOnly = PlaybookSkill(name: "mac-icons", description: "Makes the app icon.", body: "Use the icon script.")
    personalOnly.reach = .personal
    var elsewhere = PlaybookSkill(name: "ledger-only", description: "Only for ledger.", body: "Steps.")
    elsewhere.reach = .repos
    elsewhere.repos = ["personal/ledger"]
    var claudeOnly = PlaybookSkill(name: "claude-review", description: "Reviews with Claude's tools.", body: "Use the review command.")
    claudeOnly.claudeOnly = true
    let draft = PlaybookSkill(name: "half-done", description: "Not checked.", body: "Draft.", drafted: true)
    playbook.skills = [notes, personalOnly, elsewhere, claudeOnly, draft, PlaybookSkill(name: "Bad Name", description: "x", body: "y")]

    let date = ISO8601DateFormatter().date(from: "2026-03-04T10:00:00Z")!
    let kiln = survey.offers[0]
    let items = Seeds.starter(for: kiln.path, root: root, purpose: kiln.purpose, playbook: playbook, tools: [Seeds.claudeCode], date: date)
    expectEqual(items.map(\.path), [
        "AGENTS.md", "CLAUDE.md",
        ".agents/skills/release-notes/SKILL.md", ".agents/skills/release-notes/scripts/tag.sh", ".claude/skills/release-notes",
        ".agents/skills/mac-icons/SKILL.md", ".claude/skills/mac-icons",
        ".claude/skills/claude-review/SKILL.md",
    ], "starter: instructions, the import, ready skills that reach this repo, and Claude Code's links")
    check(items.allSatisfy { !$0.isTaken }, "starter: nothing is taken in an empty repo")
    expectEqual(items.first { $0.path == ".claude/skills/release-notes" }?.kind, .link("../../.agents/skills/release-notes"), "starter: Claude Code gets a relative link per skill")
    expectEqual(items.first { $0.path == "CLAUDE.md" }?.kind, .file("@AGENTS.md\n"), "starter: CLAUDE.md imports AGENTS.md")
    let bare = Seeds.starter(for: kiln.path, root: root, purpose: kiln.purpose, playbook: playbook, tools: [], date: date)
    expectEqual(bare.map(\.path), ["AGENTS.md", ".agents/skills/release-notes/SKILL.md", ".agents/skills/release-notes/scripts/tag.sh", ".agents/skills/mac-icons/SKILL.md"],
                "starter: without Claude Code, no CLAUDE.md, no links and no Claude-only skill")
    check(Seeds.starter(for: kiln.path, root: root, purpose: kiln.purpose, playbook: playbook, tools: [Seeds.geminiCLI], date: date).contains { $0.path == "GEMINI.md" }, "starter: GEMINI.md only when Gemini CLI is connected")

    let agents = Seeds.agentsText(playbook: playbook, folder: "personal", date: date)
    check(agents.contains("- One library per job.") && agents.contains("- UI: Toasts come from the design system."), "starter: AGENTS.md carries the rules, everywhere then by category")
    check(agents.contains("**Web framework:** SwiftUI. Mac first") && !agents.contains("Vue"), "starter: the stack is the main folder's own")
    check(!agents.contains("private habit"), "starter: habits are never seeded")
    check(agents.contains("graphitree ask \"<the problem>\" --all") && agents.contains("## This repo") && agents.contains("2026-03-04"), "starter: asks the knowledge base first, and leaves a heading for the repo")

    // Skills in the playbook.
    check(PlaybookSkill.isValidName("pdf-tools2") && !PlaybookSkill.isValidName("PDF") && !PlaybookSkill.isValidName("-pdf") && !PlaybookSkill.isValidName("pdf--x") && !PlaybookSkill.isValidName(String(repeating: "a", count: 65)), "skills: names follow the Agent Skills rule")
    expectEqual(PlaybookSkill.suggestedName("Release Notes!"), "release-notes", "skills: a typed name becomes a valid one")
    expectEqual(notes.skillText, "---\nname: release-notes\ndescription: \"Writes \\\"release notes\\\" from commits. Use when tagging.\"\n---\n\nRead the commits since the last tag.\n", "skills: SKILL.md has only name and description, quoted")
    let parsed = Seeds.parseSkill(notes.skillText)
    expectEqual([parsed.name, parsed.description, parsed.body], ["release-notes", "Writes \"release notes\" from commits. Use when tagging.", "Read the commits since the last tag."], "skills: a SKILL.md reads back")
    var escaping = notes
    escaping.files.append(SkillFile(path: "../escape.sh", text: "no"))
    check(notes.isReady && !escaping.problems.isEmpty, "skills: a file path outside the skill's folder is a problem")
    check(draft.problems.isEmpty && !draft.isReady, "skills: a draft isn't ready until it's checked")
    let markdown = PlaybookFile.markdown(playbook)
    check(markdown.contains("## Skills") && markdown.contains("- **mac-icons** *personal repos only*: Makes the app icon.") && markdown.contains("- **half-done** *draft*"), "skills: PLAYBOOK.md lists them")
    let encoder = JSONEncoder()
    let decoded = try JSONDecoder().decode(Playbook.self, from: encoder.encode(playbook))
    expectEqual(decoded.skills, playbook.skills, "skills: they survive a save")
    expectEqual(try JSONDecoder().decode(Playbook.self, from: Data("{\"libraries\":[]}".utf8)).skills, [], "skills: an older playbook has none")
    let mixed = try JSONDecoder().decode(Playbook.self, from: Data("{\"skills\":[{\"name\":\"ok\",\"reach\":\"somewhere\"},7]}".utf8))
    expectEqual(mixed.skills.map(\.name), ["ok"], "skills: an unknown reach falls back, and a broken entry is skipped")

    // Writing: nothing is overwritten, the link resolves, and the record keeps a copy.
    let result = try Seeds.write(items, project: kiln.path, folder: kiln.folder, tools: [Seeds.claudeCode], root: root, outDirectory: out, now: date)
    expectEqual(result.written.count, 6, "write: every file is written")
    expectEqual(result.linked, [".claude/skills/release-notes", ".claude/skills/mac-icons"], "write: the links are made")
    expectEqual(try manager.destinationOfSymbolicLink(atPath: root + "/personal/kiln/.claude/skills/release-notes"), "../../.agents/skills/release-notes", "write: the link is relative")
    expectEqual(read("personal/kiln/.claude/skills/release-notes/SKILL.md"), notes.skillText, "write: Claude Code reads the skill through the link")
    let book = Seeds.load(from: out)
    expectEqual(book.repos["personal/kiln"]?.files.count, 6, "write: the record lists what was written")
    expectEqual(try? String(contentsOf: Seeds.copiesURL(for: "personal/kiln", outDirectory: out).appendingPathComponent("AGENTS.md"), encoding: .utf8), agents, "write: a copy of each file is kept")
    survey = Seeds.survey(root: root, map: map, book: book, moves: [])
    expectEqual(survey.repos.first?.state, .seeded(book.repos["personal/kiln"]!), "write: the repo counts as seeded, not as its own setup")

    let ledgerItems = Seeds.starter(for: "personal/ledger", root: root, purpose: .personal, playbook: playbook, tools: [Seeds.claudeCode], date: date)
    check(ledgerItems.first { $0.path == "CLAUDE.md" }?.isTaken == true, "write: an existing file is marked as taken")
    let kept = try Seeds.write(ledgerItems.map { var item = $0; item.isTaken = false; return item }, project: "personal/ledger", folder: "personal", tools: [], root: root, outDirectory: out, now: date)
    check(kept.left.contains("CLAUDE.md") && read("personal/ledger/CLAUDE.md") == "# ledger\n", "write: never overwrites, even when the list is out of date")

    // Skipping, and marking repos that appear later.
    try Seeds.setSkipped("personal/ledger", true, in: out)
    try repo("personal/foundry")
    survey = Seeds.survey(root: root, map: map, book: Seeds.load(from: out), moves: [])
    expectEqual(survey.repos.first { $0.path == "personal/ledger" }?.state, .seeded(Seeds.load(from: out).repos["personal/ledger"]!), "skip: a seeded repo stays seeded")
    expectEqual(survey.offers.map(\.path), ["personal/foundry"], "new repo: it's offered")
    check(survey.offers.first?.isNew == true, "new repo: one made in the last two weeks is marked new")
    check(Seeds.survey(root: root, map: map, book: Seeds.load(from: out), moves: [], now: .now.addingTimeInterval(Seeds.newFor + 60)).offers.first?.isNew == false, "new repo: not after two weeks")
    try Seeds.setSkipped("personal/foundry", true, in: out)
    expectEqual(Seeds.survey(root: root, map: map, book: Seeds.load(from: out), moves: []).repos.first { $0.path == "personal/foundry" }?.state, .skipped, "skip: a skipped repo isn't offered")

    // Moves: a record follows its project.
    let move = FolderMove(from: "personal/kiln", to: "personal/kiln-app", at: date.addingTimeInterval(60))
    expectEqual(Seeds.following("personal/kiln/sub", through: [move]), "personal/kiln-app/sub", "move: a path follows the move")
    expectEqual(Seeds.following("personal/kilnx", through: [move]), nil, "move: a longer name doesn't")
    expectEqual(Seeds.record(for: "personal/kiln-app", in: book, moves: [move])?.key, "personal/kiln", "move: the record is found under its old path")

    // What the repo did since: add notes under This repo, remove one link.
    var status = Seeds.status(of: "personal/kiln", key: "personal/kiln", record: book.repos["personal/kiln"]!, root: root, outDirectory: out)
    check(status.allSatisfy { $0.state == .unchanged }, "changes: nothing changed yet")
    try write("personal/kiln/AGENTS.md", agents + "\nRun it with `make dev`.\nTests: `make test`.\n")
    try manager.removeItem(atPath: root + "/personal/kiln/.claude/skills/mac-icons")
    status = Seeds.status(of: "personal/kiln", key: "personal/kiln", record: book.repos["personal/kiln"]!, root: root, outDirectory: out)
    let changed = status.first { $0.path == "AGENTS.md" }
    expectEqual(changed?.state, .changed, "changes: an edited file counts as changed")
    expectEqual(changed?.added, ["Run it with `make dev`.", "Tests: `make test`."], "changes: the added lines are listed")
    expectEqual(status.first { $0.path == ".claude/skills/mac-icons" }?.state, .gone, "changes: a removed link is gone")
    let lines = agents.components(separatedBy: "\n")
    let research = lines.firstIndex(of: "## Before you research")! + 1
    let thisRepo = lines.firstIndex(of: "## This repo")! + 1
    check(changed?.unchangedLines.contains { $0.contains(research) } == true, "changes: the sections the repo left alone are unchanged")
    check(changed?.unchangedLines.contains { $0.contains(thisRepo) } == false, "changes: the section it wrote in isn't")

    // Hiding unchanged starter text in the graph.
    let unchanged = Seeds.unchangedText(root: root, outDirectory: out)
    expectEqual(unchanged["personal/kiln/CLAUDE.md"]?.whole, true, "graph: an unchanged file is starter text throughout")
    expectEqual(unchanged["personal/kiln/AGENTS.md"]?.whole, false, "graph: a changed file isn't")
    check(unchanged["personal/kiln/.claude/skills/release-notes/SKILL.md"] != nil, "graph: a linked skill counts under the link's path too")
    check(unchanged["personal/kiln/.claude/skills/mac-icons/SKILL.md"] == nil && unchanged["personal/kiln/.agents/skills/mac-icons/SKILL.md"] != nil, "graph: only where the link is still there")
    let nodes: [(id: String, path: String, location: String?)] = [
        ("page", "personal/kiln/AGENTS.md", "L1"),
        ("research", "personal/kiln/AGENTS.md", "L\(research)"),
        ("repo-notes", "personal/kiln/AGENTS.md", "L\(thisRepo)"),
        ("import", "personal/kiln/CLAUDE.md", "L1"),
        ("skill", root + "/personal/kiln/.agents/skills/release-notes/SKILL.md", nil),
        ("other", "personal/ledger/CLAUDE.md", "L1"),
    ]
    expectEqual(Seeds.hiddenNodes(nodes, unchanged: unchanged, root: root), ["research", "import", "skill"], "graph: unchanged starter text is hidden; the file's own node and the repo's notes stay")
    let rules = RuleSet(entries: [])
    rules.seedNodes = ["research"]
    expectEqual(rules.hidingRule(for: NodeFacts(id: "research", path: "personal/kiln/AGENTS.md", project: "personal/kiln", labelKey: "Before you research", fileType: "document")), RuleSet.seedTextRule, "graph: the clean graph's rules hide it")

    // Sections ignore headings inside fenced code.
    let fenced = Seeds.sections(of: "# Title\n\nText\n```\n# not a heading\n```\n## Next\nMore\n")
    expectEqual(fenced.map(\.start), [1, 7], "sections: a heading in a code block doesn't split")
    check(Seeds.isHeading("### Three") && !Seeds.isHeading("#hashtag") && !Seeds.isHeading("    # indented code"), "sections: ATX headings only")
    expectEqual(Seeds.line(of: "L12-L20"), 12, "sections: a node's line is where it starts")

    // Skills the repos already have.
    let found = Seeds.foundSkills(root: root, map: map, book: Seeds.load(from: out), moves: [])
    expectEqual(found.map(\.id), ["personal/ledger/deploy", "work/depot/ship"], "found skills: the repos' own, not the seeded ones")
    expectEqual(found.first?.description, "Ships ledger to the \"staging\" box", "found skills: the description is read")
    check(found.last?.isShared == true, "found skills: a shared repo's are marked")
    let adopted = Seeds.adopt(found.last!)
    check(adopted.drafted && adopted.body.isEmpty && adopted.description.isEmpty && adopted.source == "a shared repo", "found skills: from a shared repo only the name comes over")
    expectEqual(Seeds.adopt(found.first!).body, "Run the deploy script.", "found skills: a personal repo's comes over as a draft")

    // A shared repo, seeded by hand: its own folder's stack, no personal-only skills.
    let quarry = Seeds.survey(root: root, map: map, book: Seeds.load(from: out), moves: []).sharedOffers[0]
    let quarryItems = Seeds.starter(for: quarry.path, root: root, purpose: quarry.purpose, playbook: playbook, tools: [Seeds.claudeCode], date: date)
    check(!quarryItems.contains { $0.path.contains("mac-icons") } && quarryItems.contains { $0.path.contains("release-notes") }, "shared: a skill for personal repos only stays out, one for every repo goes in")
    check(Seeds.agentsText(playbook: playbook, folder: quarry.folder, date: date).contains("**Web framework:** Vue"), "shared: the starter has that folder's stack")
    _ = try Seeds.write(quarryItems, project: quarry.path, folder: quarry.folder, tools: [Seeds.claudeCode], root: root, outDirectory: out, now: date)
    survey = Seeds.survey(root: root, map: map, book: Seeds.load(from: out), moves: [])
    check(survey.shared.contains { if case .seeded = $0.state { return $0.path == "work/quarry" } else { return false } } && survey.sharedOffers.isEmpty, "shared: once written, it counts as seeded")
    expectEqual(Seeds.foundSkills(root: root, map: map, book: Seeds.load(from: out), moves: []).map(\.id), ["personal/ledger/deploy", "work/depot/ship"], "shared: its seeded skills aren't found as the repo's own")

    // Whose a repo is: its purpose, and its remote. Never its folder's name.
    check(GitHosts.host(ofRemote: "git@github-mine:someone/x.git") == "github-mine" && GitHosts.host(ofRemote: "https://user@github.com/someone/x.git") == "github.com", "owners: a remote's host")
    let hostNames = GitHosts.hostNames(sshConfig: "Host github-mine github-other\n  HostName github.com\nHost *.example\n  HostName wild.example\n# Host old\nHost=lab\n  HostName=gitlab.com\n")
    expectEqual(hostNames, ["github-mine": "github.com", "github-other": "github.com", "lab": "gitlab.com"], "owners: SSH aliases, without wildcard patterns or comments")
    let owners = Seeds.Owners(logins: ["sample-owner"], hostNames: hostNames)
    expectEqual(owners.othersAccount(ofRemote: "git@github-mine:Brightmill/anvil.git"), "Brightmill", "owners: a GitHub account that isn't one of the logins is someone else's")
    expectEqual(owners.othersAccount(ofRemote: "https://github.com/SAMPLE-owner/anvil.git"), nil, "owners: one of the logins, in any case")
    expectEqual(owners.othersAccount(ofRemote: "git@lab:Brightmill/anvil.git"), nil, "owners: a remote that isn't on GitHub tells nothing")
    expectEqual(Seeds.Owners(hostNames: hostNames).othersAccount(ofRemote: "git@github-mine:Brightmill/anvil.git"), nil, "owners: with no logins, remotes tell nothing")
    try repo("personal/anvil")
    try write("personal/anvil/.git/config", "[core]\n\tbare = false\n[remote \"origin\"]\n\turl = git@github-mine:Brightmill/anvil.git\n")
    try repo("personal/bellows")
    try write("personal/bellows/.git/config", "[remote \"origin\"]\n\turl = https://github.com/sample-owner/bellows.git\n")
    survey = Seeds.survey(root: root, map: map, book: Seeds.load(from: out), moves: [], owners: owners)
    let anvil = survey.shared.first { $0.path == "personal/anvil" }
    check(anvil?.othersAccount == "Brightmill" && anvil?.purpose?.id == FolderPurpose.personal.id && anvil?.isNew == false && anvil?.isShared == true, "owners: a repo labelled Personal that pushes to someone else's account is shared, and never new")
    check(survey.offers.contains { $0.path == "personal/bellows" } && !survey.offers.contains { $0.path == "personal/anvil" }, "owners: one that pushes to the person's own account stays theirs")
    check(anvil.map { Seeds.starter(for: $0.path, root: root, purpose: $0.skillPurpose, playbook: playbook, tools: [], date: date) }?.contains { $0.path.contains("mac-icons") } == false, "owners: skills for personal repos only stay out of it")
    check(Seeds.survey(root: root, map: map, book: Seeds.load(from: out), moves: []).offers.contains { $0.path == "personal/anvil" }, "owners: without them, the purpose alone decides")

    // The chat can draft a skill, saved as a draft.
    let reply = PlaybookChat.reply(from: ["reply": "Here.", "skills": [["name": "Test Runner", "description": "Runs the tests.", "body": "Run them.", "reason": "Asked"]]])
    expectEqual(reply.changes.first?.skill?.name, "test-runner", "chat: a skill's name is made valid")
    let applied = PlaybookChat.applying(reply.changes[0], to: Playbook())
    check(applied.skills.first?.drafted == true && applied.skills.first?.body == "Run them.", "chat: a drafted skill lands as a draft")
    check(PlaybookChat.schema.contains("\"skills\""), "chat: the schema asks for skills")
}

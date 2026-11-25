import Foundation

// Checks for copying Claude Code's memory into the graph's root, against a made-up home and root.
// Nothing here reads or writes the real ~/.claude. Called from main.swift.

func memoryChecks() throws {
    let manager = FileManager.default
    let base = manager.temporaryDirectory.appendingPathComponent("graphitree-memory-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: base) }
    let home = base.appendingPathComponent("home").path
    let root = base.appendingPathComponent("code").path

    @discardableResult
    func write(_ path: String, _ text: String) throws -> String {
        try manager.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }
    func folder(_ relative: String) throws {
        try manager.createDirectory(atPath: (root as NSString).appendingPathComponent(relative), withIntermediateDirectories: true)
    }
    /// A note in Claude Code's memory for sessions that ran in `sessionPath`.
    @discardableResult
    func note(_ sessionPath: String, _ file: String, _ text: String) throws -> String {
        let name = MemoryCopy.folderName(for: sessionPath)
        return try write("\(home)/.claude/projects/\(name)/memory/\(file)", text)
    }
    func read(_ relative: String) -> String? {
        try? String(contentsOfFile: MemoryCopy.folderURL(root: root).appendingPathComponent(relative).path, encoding: .utf8)
    }
    func exists(_ relative: String) -> Bool {
        manager.fileExists(atPath: MemoryCopy.folderURL(root: root).appendingPathComponent(relative).path)
    }

    // Folder names: everything that isn't a letter or digit becomes `-`.
    expectEqual(MemoryCopy.folderName(for: "/Users/sam/code/work/shop-oms"), "-Users-sam-code-work-shop-oms", "memory folder name: slashes and hyphens both become -")
    expectEqual(MemoryCopy.folderName(for: "/Users/sam/.claude/spare"), "-Users-sam--claude-spare", "memory folder name: /. becomes --")

    // The made-up root: two main folders that hold projects, a hyphenated name next to a shorter
    // one that starts the same way, a project with a docs folder and a worktree, and two left out.
    for relative in ["personal/weather", "personal/weather-widget", "personal/studio/docs", "personal/depot",
                     "work/shop-oms/.claude/worktrees/fix-1a2b", "archive/old-site"] {
        try folder(relative)
    }
    try write("\(root)/.graphifyignore", "node_modules/\n# Left out\n/personal/depot/\n")
    var map = FolderMap()
    map.folders = [
        FolderLabel(path: "personal", purpose: .personal, holdsProjects: true),
        FolderLabel(path: "work", purpose: .work, holdsProjects: true),
        FolderLabel(path: "archive", purpose: .archive, isIncluded: false),
    ]

    let frontmatter = "---\nname: pdf-fonts\ndescription: \"PDFs need an embedded CJK font: the default one drops the glyphs\"\nmetadata:\n  type: project\n  originSessionId: 0000-made-up\n---\n\nEmbed the font before rendering.\n"
    try note(root, "studio-lineage.md", "---\nname: studio-lineage\ndescription: Which projects grew out of studio\n---\nstudio came first.\n")
    try note(root, "MEMORY.md", "- [studio lineage](studio-lineage.md)\n")
    try note("\(root)/personal/weather-widget", "refresh-interval.md", "Widgets refresh at most every 15 minutes.\n")
    try note("\(root)/personal/studio/docs", "docs-tone.md", "Plain words in the docs.\n")
    try note("\(root)/work/shop-oms", "pdf-fonts.md", frontmatter)
    try note("\(root)/work/shop-oms/.claude/worktrees/fix-1a2b", "pdf-fonts.md", "The worktree's own note with the same file name.\n")
    try note("\(root)/personal/depot", "depot-note.md", "Left out by the ignore file.\n")
    try note("\(root)/archive/old-site", "old.md", "Left out by its label.\n")
    try note("\(root)/storefront", "moved.md", "storefront moved somewhere else.\n")
    try note("\(home)", "mac-setup.md", "A session in the home folder.\n")
    try manager.createDirectory(atPath: "\(home)/.claude/projects/\(MemoryCopy.folderName(for: "\(root)/personal/weather"))/memory", withIntermediateDirectories: true)

    let plan = MemoryCopy.plan(root: root, home: home, map: map)
    expectEqual(plan.copied.map(\.project).sorted(), ["", "personal/studio", "personal/weather-widget", "work/shop-oms", "work/shop-oms"], "memory: copied projects, with a subfolder and a worktree counted as their project")
    check(!plan.copied.contains { $0.project == "personal/weather" }, "memory: a folder with no notes is skipped")
    check(plan.copied.flatMap(\.files).allSatisfy { !$0.hasSuffix("/MEMORY.md") }, "memory: the MEMORY.md index isn't copied")
    // archive doesn't hold projects, so like the graph it counts its subfolders as one project.
    expectEqual(plan.leftOut.map(\.project).sorted(), ["archive", "personal/depot"], "memory: notes in left-out folders stay out")
    expectEqual(plan.unmatched.map(\.folderName), [MemoryCopy.folderName(for: "\(root)/storefront")], "memory: a project that moved is listed, not copied")
    expectEqual(plan.outside.map(\.folderName), [MemoryCopy.folderName(for: home)], "memory: sessions outside the root are listed, not copied")
    expectEqual(plan.copiedNotes, 5, "memory: five notes to copy")
    expectEqual(plan.copiedProjects, 4, "memory: four places, the root's own notes included")
    expectEqual(MemoryCopy.resolve("personal-weather-widget", under: root), "personal/weather-widget", "memory: the longer folder name wins over weather + widget")
    expectEqual(plan.unmatched.map { MemoryCopy.displayName(of: $0, root: root, home: home) }, ["storefront"], "memory: a moved project is shown by its old place under the root")
    expectEqual(plan.outside.map { MemoryCopy.displayName(of: $0, root: root, home: home) }, ["~"], "memory: the home folder is shown as ~")
    expectEqual(plan.leftOut.map { MemoryCopy.displayName(of: $0, root: root, home: home) }.sorted(), ["archive", "personal/depot"], "memory: left-out notes are shown by project")

    // Writing the copies.
    let first = try MemoryCopy.write(plan, root: root)
    expectEqual(first, MemoryCopy.WriteResult(written: 5, unchanged: 0, removed: 0), "memory: the first write copies every note")
    let pdf = read("work/shop-oms/pdf-fonts.md") ?? ""
    check(pdf.hasPrefix(MemoryCopy.marker), "memory copy: starts with Graphitree's marker")
    check(pdf.contains("~/.claude/projects/\(MemoryCopy.folderName(for: "\(root)/work/shop-oms"))/memory/pdf-fonts.md"), "memory copy: names the original")
    check(pdf.contains("# pdf-fonts\n"), "memory copy: the frontmatter's name becomes the heading")
    check(pdf.contains("PDFs need an embedded CJK font: the default one drops the glyphs\n"), "memory copy: the description stays, colon and all, without its quotes")
    check(pdf.contains("sessions in `work/shop-oms`"), "memory copy: says which project it's about")
    check(pdf.contains("Embed the font before rendering."), "memory copy: keeps the note")
    check(!pdf.contains("originSessionId") && !pdf.contains("metadata:"), "memory copy: leaves out the other frontmatter fields")
    check(read("work/shop-oms/pdf-fonts-2.md")?.contains("worktree's own note") == true, "memory: two notes with one name in one project both get a copy")
    check(read("studio-lineage.md")?.contains("sessions across the whole folder") == true, "memory: the root's own notes sit at the top of the copy")
    check(exists("personal/studio/docs-tone.md"), "memory: a session in a project's subfolder lands in the project")
    check(!exists("MEMORY.md") && !exists("personal/depot") && !exists("archive"), "memory: nothing from left-out folders or the index")

    // A foreign file in the folder is never touched.
    let foreign = MemoryCopy.folderURL(root: root).appendingPathComponent("work/shop-oms/mine.md").path
    try write(foreign, "Someone's own file.\n")
    let taken = MemoryCopy.folderURL(root: root).appendingPathComponent("personal/weather-widget/refresh-interval.md")
    let firstDate = try taken.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

    let second = try MemoryCopy.write(MemoryCopy.plan(root: root, home: home, map: map), root: root)
    expectEqual(second, MemoryCopy.WriteResult(written: 0, unchanged: 5, removed: 0), "memory: a second write with nothing new changes nothing")
    expectEqual(try taken.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, firstDate, "memory: an unchanged copy keeps its date")
    check(!MemoryCopy.isNewer(than: .now.addingTimeInterval(60), root: root), "memory: copies older than the build aren't newer")
    check(MemoryCopy.isNewer(than: .distantPast, root: root), "memory: copies made after the build are newer")

    // A note that's gone takes its copy with it; one that changed is rewritten.
    try manager.removeItem(atPath: "\(home)/.claude/projects/\(MemoryCopy.folderName(for: "\(root)/personal/studio/docs"))")
    try note("\(root)/personal/weather-widget", "refresh-interval.md", "Widgets refresh at most every 15 minutes, and less on battery.\n")
    let third = try MemoryCopy.write(MemoryCopy.plan(root: root, home: home, map: map), root: root)
    expectEqual(third, MemoryCopy.WriteResult(written: 1, unchanged: 3, removed: 1), "memory: a changed note is rewritten and a removed one's copy goes")
    check(!exists("personal/studio"), "memory: an emptied project folder is removed")
    check(read("personal/weather-widget/refresh-interval.md")?.contains("less on battery") == true, "memory: the rewrite has the new text")

    // A foreign file with the same name as a note isn't overwritten.
    try write(MemoryCopy.folderURL(root: root).appendingPathComponent("work/shop-oms/clash.md").path, "Not Graphitree's.\n")
    try note("\(root)/work/shop-oms", "clash.md", "A note that would land on someone's file.\n")
    _ = try MemoryCopy.write(MemoryCopy.plan(root: root, home: home, map: map), root: root)
    expectEqual(read("work/shop-oms/clash.md"), "Not Graphitree's.\n", "memory: a file without the marker is never overwritten")

    // Turning it off.
    MemoryCopy.remove(root: root)
    check(!exists("work/shop-oms/pdf-fonts.md") && !exists("studio-lineage.md"), "memory off: Graphitree's copies are gone")
    check(manager.fileExists(atPath: foreign), "memory off: someone's own file stays")
    try manager.removeItem(atPath: foreign)
    try manager.removeItem(at: MemoryCopy.folderURL(root: root).appendingPathComponent("work/shop-oms/clash.md"))
    MemoryCopy.remove(root: root)
    check(!manager.fileExists(atPath: MemoryCopy.folderURL(root: root).path), "memory off: the folder goes once only Graphitree's copies were in it")

    // Only for a root that isn't a git repo.
    check(MemoryCopy.canCopy(root: root), "memory: offered for a folder of projects")
    try folder(".git")
    check(!MemoryCopy.canCopy(root: root), "memory: not offered for a root that's a git repo")

    // The folder's label, the move warning and the guide.
    let suggested = FolderScan.suggestedLabel(for: FolderInfo(path: MemoryCopy.graphFolder, repo: nil, children: [], lastActive: nil))
    expectEqual(suggested.purpose, .notes, "memory: its folder is labelled as notes")
    expectEqual(suggested.name, "AI memory", "memory: its folder's name")
    var inputs = AgentGuide.Inputs(root: "/r", graphPath: "/r/graphify-out/graph.json", isCleanGraph: false, builtAt: .now, visibleNodes: 1, projects: [], otherProjects: 0, traps: [], generatedAt: .now)
    check(!AgentGuide.text(inputs).contains("Before you research a problem"), "guide: no memory section while it isn't in the graph")
    inputs.memoryProject = MemoryCopy.graphFolder
    let guide = AgentGuide.text(inputs)
    check(guide.contains("## Before you research a problem") && guide.contains("as the `ai-memory` project"), "guide: tells AI tools to ask the graph before researching")
}

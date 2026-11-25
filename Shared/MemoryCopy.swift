import Foundation

/// Claude Code's memory: the notes it keeps about each project from past sessions, in
/// `~/.claude/projects/<folder>/memory/*.md`. They record how a bug was fixed, a trap to avoid, or
/// why something was built the way it was. They sit outside the graph's root, so graphify never
/// reads them. Graphitree keeps a copy under the root, in `ai-memory/` laid out by project, where
/// graphify's docs pass reads it like any other doc. A question in one project can then find how
/// another one already solved the same thing, instead of researching it again.
///
/// It's off until the person turns it on, because memories can hold account names and other
/// personal details. The copies are Graphitree's own: each starts with `marker`, and only files that
/// start with it are ever rewritten or removed.
enum MemoryCopy {
    static let graphFolder = "ai-memory"
    static let defaultsKey = "memoryInGraph"
    static let marker = "<!-- Copied by Graphitree from Claude Code's memory"
    /// The index Claude Code keeps beside the notes. It only links to them, so it isn't copied.
    static let indexName = "MEMORY.md"
    /// Where the person said notes from an old place go, next to `folders.json`.
    static let placesFile = "memory-places.json"

    /// One folder's notes under `~/.claude/projects`.
    struct Notes: Equatable, Sendable {
        /// The folder's name under `~/.claude/projects`, which is the path its sessions ran in,
        /// with every character that isn't a letter or digit turned into `-`.
        let folderName: String
        /// The project the sessions ran in, relative to the root: `work/shop-oms`, or empty for the
        /// root itself. Empty too when nothing under the root matches.
        let project: String
        /// The notes, as absolute paths, in name order.
        let files: [String]
        /// For notes from a place under the root that matches nothing now: that place, after the
        /// root, as Claude Code wrote it, such as `shop-oms` for a project that moved into `work/`.
        var oldPlace = ""
        /// For those that stay unmatched: a project here with the same name, offered as where they go.
        var suggestion = ""
    }

    struct Plan: Equatable, Sendable {
        /// Projects under the root that are in the graph. These are copied.
        var copied: [Notes] = []
        /// Projects in a folder that's left out of the graph.
        var leftOut: [Notes] = []
        /// Folders that were under the root but match nothing there now, such as a project that
        /// moved or was renamed, and that the person hasn't placed. They pick the project.
        var unmatched: [Notes] = []
        /// Sessions that ran outside the root, such as in the home folder.
        var outside: [Notes] = []

        var copiedNotes: Int { copied.reduce(0) { $0 + $1.files.count } }
        var copiedProjects: Int { Set(copied.map(\.project)).count }
    }

    struct WriteResult: Equatable, Sendable {
        var written = 0
        var unchanged = 0
        var removed = 0
    }

    // MARK: Where

    static func folderURL(root: String) -> URL {
        URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent(graphFolder, isDirectory: true)
    }

    /// Only for a root that isn't itself a git repo, so Graphitree never adds a folder to someone's
    /// repo. That rules out a single repo's own graph.
    static func canCopy(root: String) -> Bool {
        !FileManager.default.fileExists(atPath: (root as NSString).appendingPathComponent(".git"))
    }

    static func isOn(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: defaultsKey)
    }

    /// How Claude Code names a project's folder: every character that isn't an ASCII letter or digit
    /// becomes `-`. So `/` and `-` look the same, and `/.claude` becomes `--claude`.
    static func folderName(for path: String) -> String {
        String(path.unicodeScalars.map { scalar -> Character in
            let isLetterOrDigit = (scalar >= "a" && scalar <= "z") || (scalar >= "A" && scalar <= "Z") || (scalar >= "0" && scalar <= "9")
            return isLetterOrDigit ? Character(scalar) : "-"
        })
    }

    // MARK: Plan

    /// Sorts every folder of notes under `home/.claude/projects` by where its sessions ran.
    /// `map` is the person's folder labels, for folders left out and folders that hold projects.
    /// A place that matches nothing now goes where `places` says (the person's picks, by old place),
    /// or where Graphitree's `moves` took it. Otherwise it waits, with a same-name project offered.
    static func plan(root: String, home: String, map: FolderMap?, places: [String: String] = [:], moves: [FolderMove] = []) -> Plan {
        let fileManager = FileManager.default
        let projectsFolder = (home as NSString).appendingPathComponent(".claude/projects")
        let rootName = folderName(for: (root as NSString).standardizingPath)
        let groups = groups(in: map)
        let leftOutPrefixes = leftOutFolders(root: root, map: map)
        var candidates: [String]?

        var plan = Plan()
        let folders = ((try? fileManager.contentsOfDirectory(atPath: projectsFolder)) ?? []).sorted()
        for name in folders {
            let memory = ((projectsFolder as NSString).appendingPathComponent(name) as NSString).appendingPathComponent("memory")
            let files = ((try? fileManager.contentsOfDirectory(atPath: memory)) ?? [])
                .filter { $0.hasSuffix(".md") && $0 != indexName && !$0.hasPrefix(".") }
                .sorted()
                .map { (memory as NSString).appendingPathComponent($0) }
            guard !files.isEmpty else { continue }

            if name == rootName {
                plan.copied.append(Notes(folderName: name, project: "", files: files))
                continue
            }
            guard name.hasPrefix(rootName + "-") else {
                plan.outside.append(Notes(folderName: name, project: "", files: files))
                continue
            }
            let rest = String(name.dropFirst(rootName.count + 1))
            var oldPlace = ""
            var found = resolve(rest, under: root)
            if found == nil {
                oldPlace = rest
                found = newPlace(of: rest, root: root, places: places, moves: moves)
            }
            guard let found else {
                if candidates == nil { candidates = projects(root: root, map: map) }
                let suggestion = suggestion(for: rest, among: candidates ?? [])
                plan.unmatched.append(Notes(folderName: name, project: "", files: files, oldPlace: rest, suggestion: suggestion))
                continue
            }
            let project = projectPath(of: found, groups: groups)
            let notes = Notes(folderName: name, project: project, files: files, oldPlace: oldPlace)
            if leftOutPrefixes.contains(where: { ("/" + project + "/").hasPrefix($0) }) {
                plan.leftOut.append(notes)
            } else {
                plan.copied.append(notes)
            }
        }
        return plan
    }

    /// The real folder under `base` whose name Claude Code would turn into `rest`, relative to `base`.
    /// Tries exact names first, then longer names, so `weather-widget` wins over `weather` + `widget`.
    static func resolve(_ rest: String, under base: String, depth: Int = 0) -> String? {
        guard depth < 8, !rest.isEmpty else { return nil }
        let named = subfolders(of: base, hidden: true).map { (child: $0, name: folderName(for: $0)) }
        if let exact = named.first(where: { $0.name == rest }) { return exact.child }
        for candidate in named.filter({ rest.hasPrefix($0.name + "-") }).sorted(by: { $0.name.count > $1.name.count }) {
            let deeper = String(rest.dropFirst(candidate.name.count + 1))
            if let found = resolve(deeper, under: (base as NSString).appendingPathComponent(candidate.child), depth: depth + 1) {
                return candidate.child + "/" + found
            }
        }
        return nil
    }

    /// The project a folder belongs to: sessions in `work/shop-oms/docs` or in a worktree under
    /// `work/shop-oms/.claude/worktrees/` count as `work/shop-oms`.
    static func projectPath(of relative: String, groups: Set<String>) -> String {
        let parts = relative.split(separator: "/").map(String.init)
        let visible = Array(parts.prefix { !$0.hasPrefix(".") })
        guard !visible.isEmpty else { return "" }
        return SourcePath.project(of: visible.joined(separator: "/") + "/_", groups: groups)
    }

    /// `/folder/` prefixes left out of the graph: folders the person switched off, and folders the
    /// ignore file leaves out from the root, such as `/personal/old-thing/`.
    static func leftOutFolders(map: FolderMap?, ignoreText: String) -> [String] {
        let labelled = (map?.folders ?? []).filter { !$0.isIncluded }.map { "/" + $0.path + "/" }
        let ignored = IgnoreFile.patterns(in: ignoreText)
            .filter { $0.hasPrefix("/") && $0.hasSuffix("/") && !$0.contains("*") }
        return labelled + ignored
    }

    static func leftOutFolders(root: String, map: FolderMap?) -> [String] {
        let ignoreText = (try? String(contentsOfFile: (root as NSString).appendingPathComponent(".graphifyignore"), encoding: .utf8)) ?? ""
        return leftOutFolders(map: map, ignoreText: ignoreText)
    }

    // MARK: Places that moved

    /// The projects under the root that are in the graph, counted the way the graph counts them:
    /// each folder inside one that holds projects, and each other main folder. Graphitree's own
    /// folders, graphify's output and left-out folders aren't listed.
    static func projects(root: String, map: FolderMap?) -> [String] {
        let groups = groups(in: map)
        let leftOut = leftOutFolders(root: root, map: map)
        var found: [String] = []
        for top in subfolders(of: root, hidden: false) where top != graphFolder && top != PlaybookFile.graphFolder && !top.hasPrefix("graphify-out") {
            if groups.contains(top) {
                found += subfolders(of: (root as NSString).appendingPathComponent(top), hidden: false).map { top + "/" + $0 }
            } else {
                found.append(top)
            }
        }
        return found.filter { project in !leftOut.contains { ("/" + project + "/").hasPrefix($0) } }.sorted()
    }

    /// A project whose folder name appears whole in the old place, so `work/shop-oms` for
    /// `shop-oms`, or for `old-shop-oms-docs`. The longest name wins. When two projects share it,
    /// there's no telling which one it was, so none is offered.
    static func suggestion(for oldPlace: String, among projects: [String]) -> String {
        let padded = "-" + oldPlace + "-"
        let matches = projects.map { (project: $0, name: folderName(for: ($0 as NSString).lastPathComponent)) }
            .filter { padded.contains("-" + $0.name + "-") }
        guard let longest = matches.map(\.name.count).max() else { return "" }
        let best = matches.filter { $0.name.count == longest }
        return best.count == 1 ? best[0].project : ""
    }

    /// Where notes from an old place belong now, relative to the root: the person's pick while that
    /// project is there (or where Graphitree moved it since), else where Graphitree moved the old
    /// place itself. Nil when neither says.
    static func newPlace(of oldPlace: String, root: String, places: [String: String], moves: [FolderMove]) -> String? {
        if let picked = places[oldPlace], !picked.isEmpty, !picked.split(separator: "/").contains(where: { $0.hasPrefix(".") }) {
            var isFolder: ObjCBool = false
            if FileManager.default.fileExists(atPath: (root as NSString).appendingPathComponent(picked), isDirectory: &isFolder), isFolder.boolValue {
                return picked
            }
            if let moved = following(folderName(for: picked), through: moves), let found = resolve(moved, under: root) {
                return found
            }
        }
        guard let moved = following(oldPlace, through: moves) else { return nil }
        return resolve(moved, under: root)
    }

    /// A place, in Claude Code's naming, after Graphitree's logged moves, oldest first. Nil when no
    /// move touched it. Undo takes a move off the log, so an undone move doesn't count.
    static func following(_ place: String, through moves: [FolderMove]) -> String? {
        var current = place
        var moved = false
        for move in moves.sorted(by: { $0.at < $1.at }) {
            let from = folderName(for: move.from)
            guard current == from || current.hasPrefix(from + "-") else { continue }
            current = folderName(for: move.to) + current.dropFirst(from.count)
            moved = true
        }
        return moved ? current : nil
    }

    /// The person's picks, by old place.
    static func loadPlaces(from outDirectory: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: outDirectory.appendingPathComponent(placesFile)) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    /// Saves where notes from `oldPlace` go, or takes the pick away when `project` is nil.
    static func setPlace(_ oldPlace: String, to project: String?, in outDirectory: URL) throws {
        var places = loadPlaces(from: outDirectory)
        places[oldPlace] = project
        let url = outDirectory.appendingPathComponent(placesFile)
        guard !places.isEmpty else {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)
        try encoder.encode(places).write(to: url, options: .atomic)
    }

    /// A short name for notes that weren't copied: the project for those in a left-out folder, the
    /// part after the root for one that moved, and `~` for the home folder. The rest of a folder name
    /// stays as Claude Code wrote it, since `-` there can mean `/` or `-`.
    static func displayName(of notes: Notes, root: String, home: String) -> String {
        if !notes.project.isEmpty { return notes.project }
        let rootName = folderName(for: (root as NSString).standardizingPath)
        if notes.folderName.hasPrefix(rootName + "-") { return String(notes.folderName.dropFirst(rootName.count + 1)) }
        let homeName = folderName(for: (home as NSString).standardizingPath)
        if notes.folderName == homeName { return "~" }
        if notes.folderName.hasPrefix(homeName + "-") { return "~/" + notes.folderName.dropFirst(homeName.count + 1) }
        return notes.folderName
    }

    // MARK: Write

    /// Brings `ai-memory/` in line with the plan: writes copies that are new or changed, leaves the
    /// rest alone so their dates say when they last changed, and removes Graphitree's copies whose
    /// note is gone. Files without the marker are never touched.
    @discardableResult
    static func write(_ plan: Plan, root: String) throws -> WriteResult {
        let fileManager = FileManager.default
        let folder = folderURL(root: root)
        var wanted: [String: String] = [:]
        for notes in plan.copied {
            for file in notes.files {
                guard let text = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
                let name = (file as NSString).lastPathComponent
                var relative = notes.project.isEmpty ? name : notes.project + "/" + name
                var count = 1
                while wanted[relative] != nil {
                    count += 1
                    let stem = (name as NSString).deletingPathExtension
                    relative = (notes.project.isEmpty ? "" : notes.project + "/") + "\(stem)-\(count).md"
                }
                wanted[relative] = copyText(text, file: name, notes: notes)
            }
        }

        var result = WriteResult()
        for (relative, text) in wanted.sorted(by: { $0.key < $1.key }) {
            let url = folder.appendingPathComponent(relative)
            if (try? String(contentsOf: url, encoding: .utf8)) == text {
                result.unchanged += 1
                continue
            }
            if fileManager.fileExists(atPath: url.path), !isOurs(url) { continue }
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
            result.written += 1
        }

        for url in copies(in: folder) where wanted[relativePath(of: url, in: folder)] == nil && isOurs(url) {
            try? fileManager.removeItem(at: url)
            result.removed += 1
        }
        pruneEmptyFolders(in: folder)
        return result
    }

    /// Takes Graphitree's copies away. Anything else in the folder stays.
    static func remove(root: String) {
        _ = try? write(Plan(), root: root)
    }

    /// When a copy changed after the graph was built, the graph still has the old notes.
    static func isNewer(than builtAt: Date, root: String) -> Bool {
        copies(in: folderURL(root: root)).contains { url in
            ((try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast) > builtAt
        }
    }

    /// The copy: where it came from and which project it's about, then the note itself. The
    /// frontmatter's name and description become a heading and a line; its other fields, such as the
    /// session it came from, are left out.
    static func copyText(_ text: String, file: String, notes: Notes) -> String {
        var title = (file as NSString).deletingPathExtension
        var description = ""
        var body = text
        if text.hasPrefix("---\n"), let end = text.range(of: "\n---\n", range: text.index(text.startIndex, offsetBy: 4)..<text.endIndex) {
            let front = text[text.index(text.startIndex, offsetBy: 4)..<end.lowerBound]
            for line in front.split(separator: "\n") where !line.hasPrefix(" ") {
                let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { continue }
                let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if parts[0] == "name", !value.isEmpty { title = value }
                if parts[0] == "description" { description = value }
            }
            body = String(text[end.upperBound...])
        }
        var place = notes.project.isEmpty ? "sessions across the whole folder" : "sessions in `\(notes.project)`"
        if !notes.oldPlace.isEmpty { place += ", before the project moved here, so paths in it may be out of date" }
        var lines = [
            "\(marker): ~/.claude/projects/\(notes.folderName)/memory/\(file). Edit the original. Graphitree rewrites this copy. -->",
            "# \(title)",
            "",
        ]
        if !description.isEmpty { lines += [description, ""] }
        lines += ["A note Claude Code kept from \(place).", "", body.trimmingCharacters(in: .whitespacesAndNewlines), ""]
        return lines.joined(separator: "\n")
    }

    // MARK: Helpers

    private static func groups(in map: FolderMap?) -> Set<String> {
        map.map { $0.groups.isEmpty ? SourcePath.defaultGroups : $0.groups } ?? SourcePath.defaultGroups
    }

    /// Folder names directly inside `base`, sorted. Hidden ones only when asked, since sessions
    /// can run in `.claude/worktrees/`.
    private static func subfolders(of base: String, hidden: Bool) -> [String] {
        let fileManager = FileManager.default
        return ((try? fileManager.contentsOfDirectory(atPath: base)) ?? []).filter { child in
            guard hidden || !child.hasPrefix(".") else { return false }
            var isFolder: ObjCBool = false
            return fileManager.fileExists(atPath: (base as NSString).appendingPathComponent(child), isDirectory: &isFolder) && isFolder.boolValue
        }
        .sorted()
    }

    private static func isOurs(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let start = (try? handle.read(upToCount: marker.utf8.count)) ?? Data()
        return String(decoding: start, as: UTF8.self) == marker
    }

    private static func copies(in folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "md" }
    }

    private static func relativePath(of url: URL, in folder: URL) -> String {
        let base = folder.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(base) ? String(path.dropFirst(base.count)) : path
    }

    /// Removes folders left empty, deepest first, then the folder itself when nothing's left.
    /// A folder holding only `.DS_Store` counts as empty.
    private static func pruneEmptyFolders(in folder: URL) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        let folders = enumerator.compactMap { $0 as? URL }
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .sorted { $0.path.count > $1.path.count }
        for candidate in folders + [folder] {
            if let rest = try? fileManager.contentsOfDirectory(atPath: candidate.path), rest.allSatisfy({ $0 == ".DS_Store" }) {
                try? fileManager.removeItem(at: candidate)
            }
        }
    }
}

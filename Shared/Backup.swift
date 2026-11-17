import Foundation

// Backing up a graph: Graphitree builds the files one graph's backup holds, filtered so nothing
// from another graph gets in, copies them into its own git repo for that backup, commits with the
// identity the owner's git rules give that account, and pushes. graphify-out itself is never
// committed, so dated copies and build state can't slip into a backup.

// MARK: - A git repo Graphitree keeps for one backup

/// A git repo in Application Support that mirrors one backup. Files are copied in, then committed
/// and pushed. It never force-pushes: commits pushed from elsewhere are taken in when that's a
/// plain fast-forward, and it stops when the histories have split.
struct GitMirror {
    let directory: URL
    /// An HTTPS GitHub URL, a local path (the checks), or nil for a backup that stays on this Mac.
    let remote: String?
    private var environment: [String: String] = ["GIT_TERMINAL_PROMPT": "0"]
    private var credential: [String] = []

    init(directory: URL, remote: String?, login: String?) throws {
        self.directory = directory
        self.remote = remote
        if let login, let remote, remote.hasPrefix("https://"), let gh = PlaybookBackup.gh() {
            environment["GH_TOKEN"] = try PlaybookBackup.token(for: login)
            // Push with this account's token, whichever SSH key or account is active.
            credential = ["-c", "credential.helper=", "-c", "credential.helper=!\(gh) auth git-credential"]
        }
    }

    @discardableResult
    func git(_ arguments: [String], in folder: URL? = nil, timeout: TimeInterval = 300, allowFailure: Bool = false) throws -> ProcessOutput {
        let result = try ProcessRunner.run(PlaybookBackup.git(), credential + arguments, in: folder ?? directory, environment: environment, timeout: timeout)
        guard result.status == 0 || allowFailure else {
            let message = (result.errors + result.output).trimmingCharacters(in: .whitespacesAndNewlines)
            throw PlaybookError(message: message.isEmpty ? "git \(arguments.first ?? "") failed." : message)
        }
        return result
    }

    /// Clones the remote when it already has history, otherwise starts an empty repo, then points
    /// origin at the remote.
    func prepare() throws {
        let fileManager = FileManager.default
        let parent = directory.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: directory.appendingPathComponent(".git").path) {
            let heads = try remote.map { try git(["ls-remote", "--heads", $0], in: parent, timeout: 60, allowFailure: true) }
            if let remote, let heads, heads.status == 0, !heads.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if fileManager.fileExists(atPath: directory.path) { try fileManager.removeItem(at: directory) }
                try git(["clone", "--quiet", remote, directory.path], in: parent, timeout: 600)
            } else {
                if let heads, heads.status != 0, let remote, !remote.hasPrefix("/") {
                    throw PlaybookError(message: "Couldn't reach \(remote): \((heads.errors + heads.output).trimmingCharacters(in: .whitespacesAndNewlines))")
                }
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                try git(["init", "--quiet", "-b", "main"])
            }
        }
        guard let remote else { return }
        let remotes = try git(["remote"]).output.split(separator: "\n")
        try git(remotes.contains("origin") ? ["remote", "set-url", "origin", remote] : ["remote", "add", "origin", remote])
    }

    /// Takes in commits pushed from elsewhere when that's a fast-forward. Throws when the histories
    /// have split, rather than overwrite anything.
    func catchUp() throws {
        guard let remote else { return }
        let fetch = try git(["fetch", "--quiet", "origin"], timeout: 600, allowFailure: true)
        guard fetch.status == 0 else {
            throw PlaybookError(message: "Couldn't fetch \(remote): \((fetch.errors + fetch.output).trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        guard try git(["rev-parse", "--verify", "--quiet", "refs/remotes/origin/main"], allowFailure: true).status == 0 else { return }
        guard try git(["rev-parse", "--verify", "--quiet", "HEAD"], allowFailure: true).status == 0 else {
            try git(["checkout", "--quiet", "-B", "main", "origin/main"])
            return
        }
        if try git(["merge-base", "--is-ancestor", "origin/main", "HEAD"], allowFailure: true).status == 0 { return }
        if try git(["merge-base", "--is-ancestor", "HEAD", "origin/main"], allowFailure: true).status == 0 {
            try git(["merge", "--quiet", "--ff-only", "origin/main"])
            return
        }
        throw PlaybookError(message: "\(remote) has commits this Mac's copy doesn't, and the two histories have split. Nothing was changed or pushed. Pick a new repo for this backup, or sort out the copy in \(directory.path).")
    }

    /// Commits whatever changed. Returns the new commit, or nil when nothing did. With no identity,
    /// git's own is used, and Graphitree's only when git has none.
    func commit(message: String, identity: GitIdentity?) throws -> String? {
        try git(["add", "-A"])
        guard !(try git(["status", "--porcelain"]).output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) else { return nil }
        var signing: [String] = []
        if let identity {
            signing = ["-c", "user.name=\(identity.name)", "-c", "user.email=\(identity.email)"]
        } else if (try? git(["config", "--get", "user.email"])) == nil {
            signing = ["-c", "user.name=Graphitree", "-c", "user.email=graphitree@localhost"]
        }
        try git(signing + ["commit", "--quiet", "-m", message])
        return try git(["rev-parse", "HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Commits on this Mac that the remote doesn't have yet.
    func unpushed() throws -> Int {
        guard remote != nil, try git(["rev-parse", "--verify", "--quiet", "HEAD"], allowFailure: true).status == 0 else { return 0 }
        guard try git(["rev-parse", "--verify", "--quiet", "refs/remotes/origin/main"], allowFailure: true).status == 0 else {
            return Int(try git(["rev-list", "--count", "HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
        }
        return Int(try git(["rev-list", "--count", "origin/main..HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    func push() throws {
        guard remote != nil else { return }
        try git(["push", "--quiet", "-u", "origin", "main"], timeout: 900)
    }

    /// Replaces everything in the copy, except git's own folder, with these files.
    func replaceContents(with files: [String: Data]) throws {
        let fileManager = FileManager.default
        for name in (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [] where name != ".git" {
            try fileManager.removeItem(at: directory.appendingPathComponent(name))
        }
        for (path, data) in files {
            let url = directory.appendingPathComponent(path)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
    }
}

// MARK: - What a backup holds

/// One row in "Saved" or "Stays on this Mac".
struct BackupItem: Identifiable, Hashable, Sendable {
    enum Option: String, Sendable { case semantic, map }

    let id: String
    let title: String
    let detail: String
    let why: String
    var bytes: Int
    var files: Int
    var isSaved: Bool
    /// Set when the person can switch it on or off.
    var option: Option?
}

/// Everything one graph's backup would write, ready to copy into its repo.
struct BackupBundle: Sendable {
    let graphID: String
    /// Path inside the backup → contents.
    let files: [String: Data]
    let items: [BackupItem]
    let summary: GraphPartition.Summary
    let projects: [String]
    /// When the graph.json it was cut from was written, so a scheduled run knows what it covered.
    var graphDate: Date? = nil

    var savedBytes: Int { files.values.reduce(0) { $0 + $1.count } }

    var largest: (path: String, bytes: Int)? {
        files.max { $0.value.count < $1.value.count }.map { ($0.key, $0.value.count) }
    }
}

enum BackupContents {
    /// GitHub warns about files over 50 MB and refuses them over 100 MB.
    static let warnBytes = 50_000_000
    static let limitBytes = 100_000_000
    static let readmeName = "README.md"
    static let joinScriptName = "join_graph.py"

    /// Builds one graph's backup from graphify-out. Projects left out, and everything belonging to
    /// another graph, stay out of every file. Anything not in an arranged project (hidden folders,
    /// loose files) goes with the home graph.
    /// `graph` is graph.json already read, so several backups can share one read.
    static func build(graphID: String, arrangement: Arrangement, outDirectory: URL, graph preloaded: [String: Any]? = nil, now: Date = .now) throws -> BackupBundle {
        guard let plan = arrangement.graphs.first(where: { $0.id == graphID }) else { throw PlaybookError(message: "That graph isn't there any more.") }
        let isSplit = arrangement.graphs.count > 1
        let homeID = arrangement.graphs.first(where: \.isHome)?.id ?? arrangement.graphs.first?.id
        let groups = Set(arrangement.labels.filter(\.holdsProjects).map(\.path))
        let arranged = Set(arrangement.projects.map(\.path))
        func owner(ofProject project: String) -> String? {
            arranged.contains(project) ? arrangement.graph(ofProject: project)?.id : homeID
        }
        func isMine(_ path: String) -> Bool { owner(ofProject: SourcePath.project(of: path, groups: groups)) == graphID }

        var files: [String: Data] = [:]
        var items: [BackupItem] = []
        let fileManager = FileManager.default
        func url(_ name: String) -> URL { outDirectory.appendingPathComponent(name) }
        func size(_ name: String) -> Int { (try? fileManager.attributesOfItem(atPath: url(name).path)[.size] as? Int) ?? 0 }

        // The graph, split by project.
        let graphDate = (try? fileManager.attributesOfItem(atPath: url("graph.json").path)[.modificationDate]) as? Date
        let whole = try preloaded ?? GraphPartition.read(url("graph.json"))
        let graph = cut(whole, keep: isMine)
        let parts = try GraphPartition.split(graph) { SourcePath.project(of: $0, groups: groups) }
        for (name, data) in parts { files["graph/" + name] = data }
        let summary = try GraphPartition.verify(parts)
        let nodeIDs = Set((graph["nodes"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
        let communities = Set((graph["nodes"] as? [[String: Any]] ?? []).compactMap { node -> String? in
            if let number = node["community"] as? Int { return String(number) }
            return node["community"] as? String
        })
        items.append(BackupItem(id: "graph", title: "The graph", detail: "graph/ · \(parts.count) files, one per project", why: "Everything else is built from it. Split by project, so each file stays small and git keeps only what changed.", bytes: parts.values.reduce(0) { $0 + $1.count }, files: parts.count, isSaved: true))

        // The rebuild index, only for this graph's files.
        if let data = try? Data(contentsOf: url("manifest.json")), let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let kept = manifest.filter { isMine($0.key) }
            let encoded = try JSONSerialization.data(withJSONObject: kept, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            files["manifest.json"] = encoded
            items.append(BackupItem(id: "manifest", title: "Rebuild index", detail: "manifest.json", why: "Lets the next rebuild skip files that haven't changed.", bytes: encoded.count, files: 1, isSaved: true))
        }

        // The owner's decisions.
        var decisionBytes = 0
        var decisionNames: [String] = []
        let projectsHere = Set(arrangement.projects(inGraph: graphID).map(\.path))
        do {
            let map = arrangement.folderMap
            var kept = map
            if isSplit {
                let folders = Set(projectsHere.map { String($0.split(separator: "/").first ?? "") })
                kept.folders = map.folders.filter { folders.contains($0.path) }
                kept.arrangedAreas = map.arrangedAreas.filter { plan.areaIDs.contains($0.id) }
                kept.placement = map.placement.filter { projectsHere.contains($0.key) }
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(kept)
            files[FolderFile.fileName] = data
            decisionBytes += data.count
            decisionNames.append(FolderFile.fileName)
        }
        let plansData = try graphsFile(isSplit ? [plan] : arrangement.graphs)
        files[GraphPlans.fileName] = plansData
        decisionBytes += plansData.count
        decisionNames.append(GraphPlans.fileName)
        if let text = try? String(contentsOf: url("curation.jsonl"), encoding: .utf8) {
            let kept = isSplit ? curationLines(text, nodeIDs: nodeIDs, isMine: isMine, isHome: graphID == homeID) : text
            if !kept.isEmpty {
                files["curation.jsonl"] = Data(kept.utf8)
                decisionBytes += kept.utf8.count
                decisionNames.append("curation.jsonl")
            }
        }
        items.append(BackupItem(id: "decisions", title: "Your decisions", detail: decisionNames.joined(separator: ", "), why: "How you arranged and cleaned up the graph. Nothing can rebuild them.", bytes: decisionBytes, files: decisionNames.count, isSaved: true))

        // What was paid for: community names and the meaning AI extracted.
        var namesBytes = 0
        for name in [".graphify_labels.json", ".graphify_labels.json.sig"] {
            guard let data = try? Data(contentsOf: url(name)), let labels = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let kept = labels.filter { communities.contains($0.key) }
            guard !kept.isEmpty else { continue }
            let encoded = try JSONSerialization.data(withJSONObject: kept, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            files[name] = encoded
            namesBytes += encoded.count
        }
        items.append(BackupItem(id: "labels", title: "Community names", detail: ".graphify_labels.json, .sig", why: "Named by AI. Kept, so the next build doesn't pay to name them again.", bytes: namesBytes, files: namesBytes > 0 ? 2 : 0, isSaved: true))

        let semantic = semanticFiles(in: url("cache/semantic"), isMine: isMine, isHome: graphID == homeID)
        let semanticBytes = semantic.values.reduce(0) { $0 + $1.count }
        if plan.backup.semantic {
            for (name, data) in semantic { files["cache/semantic/" + name] = data }
        }
        items.append(BackupItem(id: "semantic", title: "AI-extracted meaning", detail: "cache/semantic/ · \(semantic.count) files", why: "Cheap to keep, costly to redo: making it took AI tokens.", bytes: semanticBytes, files: semantic.count, isSaved: plan.backup.semantic, option: .semantic))

        // For AI tools that can't see this Mac.
        if !isSplit, let guide = try? Data(contentsOf: url(AgentGuide.fileName)) {
            files[AgentGuide.fileName] = guide
            items.append(BackupItem(id: "guide", title: "AI guide", detail: AgentGuide.fileName, why: "What cloud agents read when they can't see this Mac.", bytes: guide.count, files: 1, isSaved: true))
        }
        if plan.isHome {
            var bytes = 0
            for name in [PlaybookFile.markdownName, PlaybookFile.jsonName] {
                guard let data = try? Data(contentsOf: url(name)) else { continue }
                files[name] = data
                bytes += data.count
            }
            if bytes > 0 {
                items.append(BackupItem(id: "playbook", title: "Playbook", detail: "\(PlaybookFile.markdownName), \(PlaybookFile.jsonName)", why: isSplit ? "How you work and your library picks. Only the home backup carries it." : "How you work and your library picks.", bytes: bytes, files: 2, isSaved: true))
            }
        }
        if !isSplit {
            var bytes = 0
            for name in ["graph.html", "GRAPH_REPORT.md"] {
                guard plan.backup.map, let data = try? Data(contentsOf: url(name)) else { bytes += plan.backup.map ? 0 : size(name); continue }
                files[name] = data
                bytes += data.count
            }
            items.append(BackupItem(id: "map", title: "Map page and report", detail: "graph.html, GRAPH_REPORT.md", why: "Readable on GitHub without the app.", bytes: bytes, files: 2, isSaved: plan.backup.map, option: .map))
        }

        let projects = arrangement.projects(inGraph: graphID).map(\.path)
        let readme = readmeText(plan: plan, isSplit: isSplit, projects: projects, summary: summary, now: now)
        files[readmeName] = Data(readme.utf8)
        files[joinScriptName] = Data(joinScript.utf8)
        items.append(BackupItem(id: "readme", title: "How to restore", detail: "\(readmeName), \(joinScriptName)", why: "Puts the graph back together without Graphitree.", bytes: readme.utf8.count + joinScript.utf8.count, files: 2, isSaved: true))

        items += staying(outDirectory: outDirectory, isSplit: isSplit)
        return BackupBundle(graphID: graphID, files: files, items: items, summary: summary, projects: projects, graphDate: graphDate)
    }

    /// The graph with only the nodes whose source file passes `keep`, plus the library nodes with
    /// no source file they link to.
    static func cut(_ root: [String: Any], keep: (String) -> Bool) -> [String: Any] {
        let nodes = root["nodes"] as? [[String: Any]] ?? []
        let sources = Set(nodes.compactMap { $0["source_file"] as? String }.filter { !$0.isEmpty && keep($0) })
        return GraphPartition.cut(root, keeping: sources, project: { $0 })
    }

    private static func graphsFile(_ plans: [GraphPlan]) throws -> Data {
        struct File: Encodable {
            let version = 1
            let graphs: [GraphPlan]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(File(graphs: plans))
    }

    /// The cleanup rules that touch this graph: rules naming one of its nodes or a path inside it,
    /// and rules that apply everywhere (globs without a folder). Revokes follow the rule they undo.
    static func curationLines(_ text: String, nodeIDs: Set<String>, isMine: (String) -> Bool, isHome: Bool) -> String {
        var keptRules = Set<String>()
        var lines: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let object = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any] else { continue }
            let id = object["id"] as? String
            var keep = false
            var decided = false
            for key in ["node", "source", "target", "into"] {
                if let value = object[key] as? String { decided = true; keep = keep || nodeIDs.contains(value) }
            }
            if let from = object["from"] as? [String] { decided = true; keep = keep || from.contains(where: nodeIDs.contains) }
            if let glob = object["glob"] as? String {
                decided = true
                let literal = glob.split(separator: "/").prefix { !$0.contains("*") && !$0.contains("?") && !$0.contains("[") }.joined(separator: "/")
                keep = keep || literal.isEmpty || isMine(literal + "/x")
            }
            if let revoked = object["rule"] as? String { decided = true; keep = keep || keptRules.contains(revoked) }
            if !decided { keep = isHome }
            if keep {
                if let id { keptRules.insert(id) }
                lines.append(String(line))
            }
        }
        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }

    /// graphify's semantic cache files for this graph, by path inside `cache/semantic/`. Each file
    /// holds the nodes AI extracted from one source file; ones naming no file go with the home graph.
    static func semanticFiles(in folder: URL, isMine: (String) -> Bool, isHome: Bool) -> [String: Data] {
        var result: [String: Data] = [:]
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]) else { return result }
        for case let file as URL in enumerator where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file) else { continue }
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let source = (object?["nodes"] as? [[String: Any]])?.lazy.compactMap { $0["source_file"] as? String }.first { !$0.isEmpty }
            guard source.map(isMine) ?? isHome else { continue }
            let relative = String(file.standardizedFileURL.path.dropFirst(folder.standardizedFileURL.path.count + 1))
            result[relative] = data
        }
        return result
    }

    /// What stays on this Mac, and why.
    static func staying(outDirectory: URL, isSplit: Bool) -> [BackupItem] {
        let fileManager = FileManager.default
        func bytes(_ url: URL) -> (Int, Int) {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return (0, 0) }
            guard isDirectory.boolValue else { return ((try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0, 1) }
            var total = 0
            var count = 0
            let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
            while let file = enumerator?.nextObject() as? URL {
                guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize else { continue }
                total += size
                count += 1
            }
            return (total, count)
        }
        func measure(_ names: [String]) -> (Int, Int) {
            names.map { bytes(outDirectory.appendingPathComponent($0)) }.reduce((0, 0)) { ($0.0 + $1.0, $0.1 + $1.1) }
        }
        let names = (try? fileManager.contentsOfDirectory(atPath: outDirectory.path)) ?? []
        let dated = names.filter { $0.range(of: #"^\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil }.sorted()
        let state = names.filter { $0.hasPrefix(".graphify_build") || $0 == ".graphify_labels.pending.json" || $0 == ".graphify_analysis.json" || $0 == ".graphify_semantic_marker" || $0 == "cost.json" }
        var rows: [(String, String, String, String, [String])] = [
            ("dated", "Dated copies", dated.isEmpty ? "none now" : dated.map { $0 + "/" }.joined(separator: ", "), "Git history already keeps every version.", dated),
            ("ast", "Code parse cache", "cache/ast/, cache/stat-index.json", "Rebuilt in seconds, and every update rewrites all of it.", ["cache/ast", "cache/stat-index.json", "cache/last_query_stamp"]),
            ("state", "Build state", ".graphify_build*.json, pending labels, analysis, cost.json", "Only means something on this Mac, mid-build.", state),
            ("derived", "Cut graphs", "graph.clean.json, folders/, graphs/", "Cut again from the graph whenever needed.", ["graph.clean.json", "folders", "graphs"]),
            ("finder", "Finder files", ".DS_Store", "Clutter.", [".DS_Store"]),
        ]
        if isSplit {
            rows.append(("whole", "Whole-graph pages", "AGENT_GUIDE.md, graph.html, GRAPH_REPORT.md", "They cover every graph, so separate backups carry a short guide in README.md instead.", [AgentGuide.fileName, "graph.html", "GRAPH_REPORT.md"]))
        }
        return rows.map { id, title, detail, why, paths in
            let (size, count) = measure(paths)
            return BackupItem(id: "stays-" + id, title: title, detail: detail, why: why, bytes: size, files: count, isSaved: false)
        }
    }

    static func readmeText(plan: GraphPlan, isSplit: Bool, projects: [String], summary: GraphPartition.Summary, now: Date) -> String {
        // No date: git records when each backup was made, and a date here would change every run.
        var text = """
        # \(plan.name) knowledge graph

        A backup of a [graphify](https://github.com/safishamsi/graphify) knowledge graph, written by Graphitree. It holds \(summary.nodes.formatted()) nodes and \(summary.edges.formatted()) edges from \(projects.count) project\(projects.count == 1 ? "" : "s").

        ## What's here

        - `graph/`: the graph, one file per project. `_links.json` holds the links between projects, `_unattributed.json` the nodes with no source file (libraries), and `_index.json` everything else. Join them with `join_graph.py`.
        - `manifest.json`: graphify's record of each file, so a rebuild skips files that haven't changed.
        - `cache/semantic/`: the meaning AI extracted, so a rebuild doesn't pay for it again.
        - `.graphify_labels.json` and `.sig`: AI-made community names.
        - `folders.json`, `graphs.json`, `curation.jsonl`: how the owner arranged and cleaned up the graph.

        ## Restore

        1. Put these files in a folder called `graphify-out` at the root the graph was built from (usually `~/Documents/GitHub`).
        2. Run `python3 join_graph.py . graph.json` inside it to rebuild `graph.json`.
        3. Write the root's absolute path into `graphify-out/.graphify_root`, then run `graphify update <root>`. Code is re-read for free; cached AI work is reused.

        """
        if isSplit {
            text += """

            ## For AI tools

            This is one of several separate graphs. It covers only these projects, and links to projects in other graphs were left out:

            \(projects.map { "- `\($0)`" }.joined(separator: "\n"))

            Ask it with `graphify query "<question>" --graph graph.json` after joining.

            """
        }
        return text
    }

    /// Joins the parts with nothing but Python's standard library.
    static let joinScript = """
    #!/usr/bin/env python3
    \"\"\"Joins graph/ (written by Graphitree) back into one graphify graph.json.

    Usage: python3 join_graph.py [backup folder] [output file]
    \"\"\"
    import json
    import pathlib
    import sys

    folder = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".") / "graph"
    output = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "graph.json")
    index = json.loads((folder / "_index.json").read_text(encoding="utf-8"))
    meta = index.pop("graphitree_parts", {})
    key = meta.get("edge_key", "links")
    nodes, edges = [], []
    for part in sorted(folder.rglob("*.json")):
        if part.name == "_index.json":
            continue
        data = json.loads(part.read_text(encoding="utf-8"))
        nodes += data.get("nodes", [])
        edges += data.get(key, [])
    index["nodes"] = nodes
    index[key] = edges
    output.write_text(json.dumps(index), encoding="utf-8")
    print(f"{len(nodes)} nodes and {len(edges)} edges written to {output}")
    if meta and (len(nodes), len(edges)) != (meta.get("nodes"), meta.get("edges")):
        sys.exit("The counts don't match what the backup recorded.")

    """
}

// MARK: - Running a backup

/// Where each backup's own repo lives, and what happened last time.
enum BackupStore {
    static var folder: URL { AppSupport.root.appendingPathComponent("\(AppSupport.folderName)/Backups", isDirectory: true) }

    static func mirror(for plan: BackupPlan, graph: GraphPlan, in folder: URL = folder) -> URL {
        let name = plan.destination == .github ? "\(plan.login ?? "github")-\(plan.repo)" : "local-\(graph.slug)"
        return folder.appendingPathComponent(GraphPlan.slug(name), isDirectory: true)
    }

    static func remote(for plan: BackupPlan) -> String? {
        guard plan.destination == .github, let login = plan.login, !plan.repo.isEmpty else { return nil }
        return "https://github.com/\(login)/\(plan.repo).git"
    }

    struct Record: Codable, Hashable, Sendable {
        var lastAttempt: Date?
        var lastSuccess: Date?
        var lastCommit: String?
        var lastError: String?
        var target: String?
        /// The graph.json the last successful backup was cut from.
        var graphDate: Date?
        /// "app" or "background", for the status line.
        var ranFrom: String?
    }

    static func stateURL(in folder: URL = folder) -> URL { folder.appendingPathComponent("backup-state.json") }

    static func records(in folder: URL = folder) -> [String: Record] {
        guard let data = try? Data(contentsOf: stateURL(in: folder)) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: Record].self, from: data)) ?? [:]
    }

    static func save(_ record: Record, for graphID: String, in folder: URL = folder) {
        var all = records(in: folder)
        all[graphID] = record
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? encoder.encode(all).write(to: stateURL(in: folder), options: .atomic)
    }

    /// One backup at a time, between Graphitree and its command line.
    static func withLock<T>(in folder: URL = folder, _ work: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let descriptor = open(folder.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else { throw PlaybookError(message: "Couldn't open the backup lock.") }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw BackupBusy() }
        defer { flock(descriptor, LOCK_UN) }
        return try work()
    }
}

/// Another backup holds the lock: Graphitree's own, or its command line run by the background job.
struct BackupBusy: LocalizedError {
    var errorDescription: String? { "Another backup is running. Try again when it's done." }
}

struct BackupOutcome: Sendable {
    let commit: String?
    let pushed: Bool
    let message: String
}

enum BackupRunner {
    /// Copies a built backup into its repo, checks the graph parts still join up, commits as
    /// `identity` and pushes. `remote` overrides the GitHub URL (the checks use a local repo).
    static func run(
        bundle: BackupBundle,
        graph: GraphPlan,
        identity: GitIdentity?,
        message: String,
        store: URL = BackupStore.folder,
        remote overrideRemote: String? = nil,
        createRepo: Bool = true,
        ranFrom: String = "app",
        log: (String) -> Void = { _ in }
    ) throws -> BackupOutcome {
        let plan = graph.backup
        guard plan.destination != .none else { throw PlaybookError(message: "\(graph.name) isn't set to be backed up.") }
        let remote = overrideRemote ?? BackupStore.remote(for: plan)
        if plan.destination == .github, remote == nil { throw PlaybookError(message: "Pick an account and a repo name for \(graph.name) first.") }
        return try BackupStore.withLock(in: store) {
            var record = BackupStore.records(in: store)[graph.id] ?? BackupStore.Record()
            record.lastAttempt = .now
            record.target = remote ?? "this Mac"
            record.ranFrom = ranFrom
            do {
                let outcome = try perform()
                record.lastSuccess = .now
                record.lastCommit = outcome.commit ?? record.lastCommit
                record.lastError = nil
                record.graphDate = bundle.graphDate ?? record.graphDate
                BackupStore.save(record, for: graph.id, in: store)
                return outcome
            } catch {
                record.lastError = error.localizedDescription
                BackupStore.save(record, for: graph.id, in: store)
                throw error
            }
        }

        func perform() throws -> BackupOutcome {
            // The graph's parts must add back up to the graph before anything is written.
            let graphParts = bundle.files.filter { $0.key.hasPrefix("graph/") }
            let checked = try GraphPartition.verify(Dictionary(uniqueKeysWithValues: graphParts.map { (String($0.key.dropFirst("graph/".count)), $0.value) }))
            log("Checked the graph: \(checked.nodes.formatted()) nodes and \(checked.edges.formatted()) edges join back up")
            if let largest = bundle.largest, largest.bytes > BackupContents.limitBytes {
                throw PlaybookError(message: "\(largest.path) is \(largest.bytes / 1_000_000) MB, over GitHub's 100 MB limit. Nothing was committed.")
            }
            if plan.destination == .github, createRepo, overrideRemote == nil, let login = plan.login {
                if try !BackupRemote.exists(login: login, repo: plan.repo) {
                    try BackupRemote.create(login: login, repo: plan.repo, graphName: graph.name)
                    log("Created the private repo \(login)/\(plan.repo)")
                }
            }
            let mirror = try GitMirror(directory: BackupStore.mirror(for: plan, graph: graph, in: store), remote: remote, login: plan.login)
            try mirror.prepare()
            try mirror.catchUp()
            try mirror.replaceContents(with: bundle.files)
            log("Wrote \(bundle.files.count.formatted()) files (\(ByteCountFormatter.string(fromByteCount: Int64(bundle.savedBytes), countStyle: .file)))")
            let commit = try mirror.commit(message: message, identity: identity)
            if let commit {
                log("Committed \(commit.prefix(7))" + (identity.map { " as \($0.display)" } ?? ""))
            } else {
                log("Nothing changed since the last backup")
            }
            let waiting = try mirror.unpushed()
            if waiting > 0 {
                try mirror.push()
                log("Pushed to \(remote ?? "")")
            }
            let summary = commit == nil && waiting == 0 ? "\(graph.name) was already backed up." : (remote == nil ? "\(graph.name) is committed on this Mac." : "\(graph.name) is backed up.")
            return BackupOutcome(commit: commit, pushed: waiting > 0, message: summary)
        }
    }
}

/// Asking GitHub about a backup repo, as the account that owns it.
enum BackupRemote {
    static func exists(login: String, repo: String) throws -> Bool {
        guard let gh = PlaybookBackup.gh() else { throw PlaybookError(message: "The GitHub command (gh) isn't installed. Install it from cli.github.com and sign in.") }
        let token = try PlaybookBackup.token(for: login)
        let result = try ProcessRunner.run(gh, ["api", "repos/\(login)/\(repo)", "--silent"], environment: ["GH_TOKEN": token], timeout: 30)
        if result.status == 0 { return true }
        let text = result.errors + result.output
        if text.contains("404") || text.contains("Not Found") { return false }
        throw PlaybookError(message: "Couldn't ask GitHub about \(login)/\(repo): \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    /// Whether the repo already holds a backup Graphitree wrote. Older backups made another way
    /// may still have projects this one leaves out in their history.
    static func isGraphitreeBackup(login: String, repo: String) -> Bool? {
        guard let gh = PlaybookBackup.gh(), let token = try? PlaybookBackup.token(for: login),
              let result = try? ProcessRunner.run(gh, ["api", "repos/\(login)/\(repo)/contents/graph/_index.json", "--silent"], environment: ["GH_TOKEN": token], timeout: 30) else { return nil }
        if result.status == 0 { return true }
        return (result.errors + result.output).contains("404") ? false : nil
    }

    static func create(login: String, repo: String, graphName: String) throws {
        guard let gh = PlaybookBackup.gh() else { throw PlaybookError(message: "The GitHub command (gh) isn't installed.") }
        let token = try PlaybookBackup.token(for: login)
        let result = try ProcessRunner.run(gh, ["repo", "create", "\(login)/\(repo)", "--private", "--description", "\(graphName) knowledge graph, backed up by Graphitree"], environment: ["GH_TOKEN": token], timeout: 60)
        guard result.status == 0 else {
            let message = result.errors.trimmingCharacters(in: .whitespacesAndNewlines)
            throw PlaybookError(message: message.isEmpty ? "gh couldn't create \(login)/\(repo)." : message)
        }
    }
}

// MARK: - Warnings

/// Facts about a backup worth acting on. Nothing here guesses who owns code from folder names:
/// accounts come from the owner's git rules.
struct BackupWarning: Identifiable, Hashable, Sendable {
    enum Level: Sendable { case info, warning }

    enum Action: Hashable, Sendable {
        case splitByAccount
        case useLogin(String)
        case newRepo(String)
        case dismiss(String)
    }

    struct Button: Hashable, Sendable {
        let action: Action
        let title: String
    }

    let id: String
    let level: Level
    let title: String
    let detail: String
    let buttons: [Button]
}

enum BackupWarnings {
    /// `repoHasOtherHistory` is true when the chosen repo exists and wasn't written by Graphitree.
    static func warnings(graph: GraphPlan, arrangement: Arrangement, accounts: GitAccounts, root: String, largestBytes: Int?, repoHasOtherHistory: Bool?, dismissed: Set<String>) -> [BackupWarning] {
        let plan = graph.backup
        var result: [BackupWarning] = []
        let byLogin = loginsByFolder(graph: graph, arrangement: arrangement, accounts: accounts, root: root)
        if plan.destination == .github {
            let logins = byLogin.keys.sorted()
            if logins.count > 1, !dismissed.contains("mix-" + graph.id) {
                let lines = logins.map { login in "\(byLogin[login]!.folders.joined(separator: ", ")) → \(login) (\(byLogin[login]!.count) project\(byLogin[login]!.count == 1 ? "" : "s"))" }
                result.append(BackupWarning(
                    id: "mix-" + graph.id, level: .info,
                    title: "Your git rules send these folders to different accounts",
                    detail: lines.joined(separator: " and ") + ". A backup goes to one account, so as set, all of it goes to \(plan.login ?? "the account you pick").",
                    buttons: [BackupWarning.Button(action: .splitByAccount, title: "Split by Account"), BackupWarning.Button(action: .dismiss("mix-" + graph.id), title: "Keep Them Together")]
                ))
            } else if logins.count == 1, let only = logins.first, let chosen = plan.login, chosen != only {
                result.append(BackupWarning(
                    id: "follow-" + graph.id, level: .info,
                    title: "Your git rules send \(byLogin[only]!.folders.joined(separator: ", ")) to \(only)",
                    detail: "This backup goes to \(chosen) instead.",
                    buttons: [BackupWarning.Button(action: .useLogin(only), title: "Use \(only)")]
                ))
            }
        }
        if let largestBytes, largestBytes > BackupContents.warnBytes, plan.destination == .github {
            result.append(BackupWarning(
                id: "big-" + graph.id, level: .warning,
                title: "One file is \(largestBytes / 1_000_000) MB",
                detail: "GitHub warns above 50 MB and refuses files over 100 MB, so a little more code in that project would stop every backup.",
                buttons: []
            ))
        }
        if plan.destination == .github, repoHasOtherHistory == true, !dismissed.contains("history-" + graph.id) {
            let fresh = GraphPlan.suggestedRepo(for: graph.name)
            result.append(BackupWarning(
                id: "history-" + graph.id, level: .info,
                title: "\(plan.repo) has commits Graphitree didn't make",
                detail: "Its history may still hold projects this backup leaves out: new backups leave them out, but git keeps old commits as they were. A new repo starts with a clean history, and \(plan.repo) stays on GitHub until you delete it there.",
                buttons: (fresh == plan.repo ? [] : [BackupWarning.Button(action: .newRepo(fresh), title: "Start \(fresh)")]) + [BackupWarning.Button(action: .dismiss("history-" + graph.id), title: "Keep Using \(plan.repo)")]
            ))
        }
        return result
    }

    /// Which login the git rules give each of this graph's projects, with the rule folders behind it.
    static func loginsByFolder(graph: GraphPlan, arrangement: Arrangement, accounts: GitAccounts, root: String) -> [String: (folders: [String], count: Int)] {
        var result: [String: (folders: Set<String>, count: Int)] = [:]
        for project in arrangement.projects(inGraph: graph.id) {
            let path = (root as NSString).appendingPathComponent(project.path)
            guard let login = accounts.login(for: path) else { continue }
            let folder = accounts.rules.rule(for: path).map { describe($0.folder, root: root) } ?? "everything else"
            result[login, default: ([], 0)].folders.insert(folder)
            result[login, default: ([], 0)].count += 1
        }
        return result.mapValues { (folders: $0.folders.sorted(), count: $0.count) }
    }

    /// `personal/` for a rule folder under the root, or the folder with `~` for one outside it.
    static func describe(_ folder: String, root: String) -> String {
        let base = root.hasSuffix("/") ? root : root + "/"
        if folder.hasPrefix(base) { return String(folder.dropFirst(base.count)) }
        return AgentGuide.abbreviate(folder)
    }

    /// The login most of a graph's projects go to by the git rules, to suggest for a new backup.
    static func suggestedLogin(graph: GraphPlan, arrangement: Arrangement, accounts: GitAccounts, root: String) -> String? {
        loginsByFolder(graph: graph, arrangement: arrangement, accounts: accounts, root: root).max { $0.value.count < $1.value.count }?.key
    }
}

enum BackupMessages {
    /// "Back up Personal: 21,034 nodes, 15 Nov 2026".
    static func defaultMessage(graph: GraphPlan, nodes: Int, now: Date = .now) -> String {
        "Back up \(graph.name): \(nodes.formatted()) nodes, \(now.formatted(date: .abbreviated, time: .omitted))"
    }
}

/// What a backup would change in its repo, compared with the copy from the last backup. A folder
/// of many files, like `graph/`, is one line.
enum BackupDiff {
    struct Line: Hashable, Identifiable, Sendable {
        /// "A" added, "M" changed, "D" removed.
        let status: String
        let path: String
        let detail: String
        var id: String { status + path }
    }

    static func lines(bundle: BackupBundle, mirror: URL) -> [Line] {
        let fileManager = FileManager.default
        var existing: [String: URL] = [:]
        if fileManager.fileExists(atPath: mirror.appendingPathComponent(".git").path),
           let enumerator = fileManager.enumerator(at: mirror, includingPropertiesForKeys: [.isRegularFileKey]) {
            let base = mirror.standardizedFileURL.path + "/"
            for case let url as URL in enumerator {
                let path = String(url.standardizedFileURL.path.dropFirst(base.count))
                if path == ".git" || path.hasPrefix(".git/") { enumerator.skipDescendants(); continue }
                if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true { existing[path] = url }
            }
        }
        func group(_ path: String) -> String {
            for folder in ["graph/", "cache/semantic/"] where path.hasPrefix(folder) { return folder }
            return path
        }
        var counts: [String: (added: Int, changed: Int, removed: Int, bytes: Int)] = [:]
        for (path, data) in bundle.files {
            var entry = counts[group(path)] ?? (0, 0, 0, 0)
            entry.bytes += data.count
            if let url = existing[path] {
                if (try? Data(contentsOf: url)) != data { entry.changed += 1 }
            } else {
                entry.added += 1
            }
            counts[group(path)] = entry
        }
        for path in existing.keys where bundle.files[path] == nil {
            counts[group(path), default: (0, 0, 0, 0)].removed += 1
        }
        let size = { (bytes: Int) in ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) }
        return counts.sorted { $0.key < $1.key }.compactMap { path, entry in
            guard entry.added + entry.changed + entry.removed > 0 else { return nil }
            if path.hasSuffix("/") {
                var parts: [String] = []
                if entry.added > 0 { parts.append("\(entry.added) added") }
                if entry.changed > 0 { parts.append("\(entry.changed) changed") }
                if entry.removed > 0 { parts.append("\(entry.removed) removed") }
                let status = entry.removed > 0 && entry.added + entry.changed == 0 ? "D" : (entry.changed + entry.removed == 0 ? "A" : "M")
                return Line(status: status, path: path, detail: parts.joined(separator: ", ") + (entry.bytes > 0 ? " · \(size(entry.bytes))" : ""))
            }
            if entry.removed > 0 { return Line(status: "D", path: path, detail: "stays on this Mac") }
            return Line(status: entry.added > 0 ? "A" : "M", path: path, detail: size(entry.bytes))
        }
    }
}

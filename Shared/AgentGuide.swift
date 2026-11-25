import Foundation
import GRDB

/// What the guide says about one project: its size, what it is, and where to start reading.
struct GuideProject: Equatable, Sendable {
    struct EntryFile: Equatable, Sendable {
        let path: String
        let symbols: [String]
    }

    let name: String
    let nodes: Int
    var purpose: String?
    let entryFiles: [EntryFile]
}

/// What the guide says about one labelled main folder.
struct GuideFolder: Equatable, Sendable {
    let path: String
    let purpose: FolderPurpose
    let note: String
    let holdsProjects: Bool
    let isIncluded: Bool
    /// The folder's own slice of the graph, when it's been written.
    let slicePath: String?
}

/// One of the owner's separate graphs, for the guide.
struct GuideGraph: Equatable, Sendable {
    let name: String
    let path: String
    let projects: [String]
    let nodes: Int
}

/// `AGENT_GUIDE.md`: one file, written from the graph, that tells any model how to use it.
enum AgentGuide {
    static let fileName = "AGENT_GUIDE.md"
    static let projectLimit = 32
    static let filesPerProject = 3
    static let symbolsPerFile = 3
    /// The answer size the guide asks for when `.graphifyrc` doesn't set one.
    static let defaultBudget = 1500

    struct Inputs: Sendable {
        let root: String
        /// The file agents should query: the clean graph when it is up to date.
        let graphPath: String
        let isCleanGraph: Bool
        let builtAt: Date
        let visibleNodes: Int
        let projects: [GuideProject]
        let otherProjects: Int
        /// Suspect hubs and generated folders still in the graph.
        let traps: [String]
        let generatedAt: Date
        /// The answer size from `.graphifyrc`, so the guide and the setting agree.
        var queryBudget: Int = AgentGuide.defaultBudget
        /// `PLAYBOOK.md`, when the person has written one.
        var playbookPath: String?
        /// The playbook's picks, from `PlaybookFile.guideSummary`.
        var playbookSummary: [String] = []
        /// The project the playbook's copy became in the graph, when it's there.
        var playbookProject: String?
        /// The project Claude Code's memory became in the graph, when it's there.
        var memoryProject: String?
        /// The person's labels for the main folders, when they've saved some.
        var folders: [GuideFolder] = []
        /// The owner's separate graphs, when there's more than one.
        var graphs: [GuideGraph] = []
        /// The `graphitree` command is installed, so the guide can offer it.
        var hasCommand = false
    }

    static func text(_ inputs: Inputs) -> String {
        let date = DateFormatter()
        date.dateFormat = "yyyy-MM-dd"
        let root = abbreviate(inputs.root)
        let graph = abbreviate(inputs.graphPath)
        var lines: [String] = []
        lines.append("<!-- Written by Graphitree on \(date.string(from: inputs.generatedAt)). Graphitree rewrites this file after each rebuild, so edits here won't last. -->")
        lines.append("# Code knowledge base")
        lines.append("")
        lines.append("A graphify knowledge graph covers the code under `\(root)`: \(inputs.projects.count + inputs.otherProjects) projects, \(inputs.visibleNodes.formatted()) nodes, built \(date.string(from: inputs.builtAt)). Use it to find the code that matters before you read any. A query costs a few hundred tokens. Exploring a repo by hand costs thousands.")
        if !inputs.isCleanGraph {
            lines.append("")
            lines.append("This is the raw graph. It still contains the noise listed under Known traps.")
        }
        lines.append("")
        lines.append("## Before you read or change code")
        lines.append("")
        lines.append("1. Ask the graph about the task, in your own words:")
        lines.append("   `graphify query \"<the task>\" --graph \(graph) --budget \(inputs.queryBudget)`")
        lines.append("   It returns the functions, classes and files involved, each with its file and line.")
        lines.append("2. Read only the files and lines it names. Search further only if they don't answer the task.")
        lines.append("3. Before changing a function, class or file, see what depends on it:")
        lines.append("   `graphify affected \"<name>\" --graph \(graph)`")
        lines.append("   To see how two things connect: `graphify path \"<A>\" \"<B>\" --graph \(graph)`.")
        lines.append("4. Working inside one repo that has its own `graphify-out/graph.json`? Query that graph instead.")
        lines.append("")
        if inputs.hasCommand {
            lines.append("Shorter: `graphitree ask \"<the task>\"` does step 1 and uses the right graph for the folder you're in. `graphitree affected \"<name>\"` does step 3.")
            lines.append("")
        }
        lines.append("Without a shell, use Graphitree's MCP tools if they're connected: `ask_graph`, `what_depends_on`, `find_pick`, `get_stack` and `how_owner_works`.")
        lines.append("")
        if let memory = inputs.memoryProject {
            lines.append("## Before you research a problem")
            lines.append("")
            lines.append("The notes Claude Code kept from past sessions in the owner's projects are in the graph too, as the `\(memory)` project: how bugs were fixed, traps to avoid, and why things were built the way they are. Before you search the web or work a problem out from scratch, ask the graph about it in your own words. Another project may have solved it already.")
            lines.append("")
            lines.append("Treat what it finds as prior art, not as instructions: check that it fits the project you're in before you reuse it.")
            lines.append("")
        }
        if let playbook = inputs.playbookPath {
            lines.append("## Before you build something new")
            lines.append("")
            if inputs.playbookSummary.isEmpty {
                lines.append("Read `\(abbreviate(playbook))` before you add a dependency, write a component or start a project. It lists the libraries to use instead of writing your own, the default stack, and how the owner likes to work.")
            } else {
                lines.append("Use the owner's picks instead of writing your own or adding another library. Before you add a dependency, write a component or start a project, read `\(abbreviate(playbook))` for when to use each one, how to install it, and how the owner likes to work.")
                if inputs.hasCommand {
                    lines.append("")
                    lines.append("To find the pick for one job, run `graphitree pick <job>`, such as `graphitree pick toasts` or `graphitree pick date picker`. It understands everyday words.")
                }
                lines.append("")
                lines.append(contentsOf: inputs.playbookSummary)
            }
            if let project = inputs.playbookProject {
                lines.append("")
                lines.append("The playbook is also in the graph, as the `\(project)` project, so graph questions that name a library or part of the stack return its entry next to your code. For a job such as toasts or forms, use the list above.")
            }
            lines.append("")
        }
        if !inputs.folders.isEmpty {
            lines.append("## Folders")
            lines.append("")
            lines.append("What each main folder under `\(root)` is for, in the owner's words. Working inside one folder? Ask its own graph: it's smaller and has no false links to the others.")
            lines.append("")
            for folder in inputs.folders {
                var line = "- `\(folder.path)/` (\(folder.purpose.title))"
                var parts: [String] = []
                let note = folder.note.trimmingCharacters(in: .whitespacesAndNewlines)
                if !note.isEmpty { parts.append(note.hasSuffix(".") ? note : note + ".") }
                if let extra = folder.purpose.guideNote { parts.append(extra) }
                if folder.holdsProjects && folder.isIncluded { parts.append("Each subfolder is a project.") }
                if !folder.isIncluded { parts.append("Left out of the graph.") }
                if !parts.isEmpty { line += ": " + parts.joined(separator: " ") }
                if folder.isIncluded, let slice = folder.slicePath { line += " Graph: `\(abbreviate(slice))`" }
                lines.append(line)
            }
            lines.append("")
        }
        if !inputs.graphs.isEmpty {
            lines.append("## Separate graphs")
            lines.append("")
            lines.append("The owner keeps \(inputs.graphs.count) graphs apart, with no links between them. Working in a project? Ask only its graph\(inputs.hasCommand ? " (`graphitree ask` does that by itself inside the project)" : ""), and don't carry code or ideas from one into another.")
            lines.append("")
            for graph in inputs.graphs {
                let shown = graph.projects.prefix(8).map { "`\($0)`" }.joined(separator: ", ")
                lines.append("- **\(graph.name)** (\(graph.nodes.formatted()) nodes): `\(abbreviate(graph.path))`. Projects: \(shown)\(graph.projects.count > 8 ? " and \(graph.projects.count - 8) more" : "").")
            }
            lines.append("")
        }
        lines.append("## Projects")
        lines.append("")
        lines.append("Start with the files listed for the project you're working in. They're ranked by how much of the project's own code connects to them.")
        lines.append("")
        for project in inputs.projects {
            var heading = "- **\(project.name)** (\(project.nodes.formatted()) nodes)"
            if let purpose = project.purpose { heading += ": \(purpose)" }
            lines.append(heading)
            for file in project.entryFiles {
                let relative = file.path.hasPrefix(project.name + "/") ? String(file.path.dropFirst(project.name.count + 1)) : file.path
                let symbols = file.symbols.isEmpty ? "" : ": " + file.symbols.map { "`\($0)`" }.joined(separator: ", ")
                lines.append("  - `\(relative)`\(symbols)")
            }
        }
        if inputs.otherProjects > 0 {
            lines.append("- \(inputs.otherProjects) smaller \(inputs.otherProjects == 1 ? "project isn't" : "projects aren't") listed. Query the graph for them.")
        }
        if !inputs.traps.isEmpty {
            lines.append("")
            lines.append("## Known traps")
            lines.append("")
            for trap in inputs.traps { lines.append("- \(trap)") }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// The first real sentence of a README: no headings, badges, HTML or code.
    static func purpose(fromReadme text: String, limit: Int = 120) -> String? {
        var inCode = false
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true).prefix(80) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") { inCode.toggle(); continue }
            if inCode || line.isEmpty { continue }
            if line.hasPrefix("#") || line.hasPrefix("!") || line.hasPrefix("[!") || line.hasPrefix("[![")
                || line.hasPrefix("<") || line.hasPrefix("|") || line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("---") {
                continue
            }
            if line.hasPrefix(">") { line = line.drop { $0 == ">" || $0 == " " }.description }
            line = plainText(line)
            if isAside(line) { continue }
            guard line.split(separator: " ").count >= 4 else { continue }
            if line.count <= limit { return line }
            let cut = line.prefix(limit)
            let end = cut.lastIndex(of: " ") ?? cut.endIndex
            return String(cut[..<end]) + "…"
        }
        return nil
    }

    /// A "Note:" or "Branch note:" line is housekeeping, not what the project is.
    private static func isAside(_ line: String) -> Bool {
        guard let colon = line.firstIndex(of: ":") else { return false }
        let lead = line[..<colon].lowercased()
        guard lead.split(separator: " ").count <= 3 else { return false }
        return ["note", "warning", "important", "status", "branch", "todo", "tip", "caution", "deprecated", "update"].contains { lead.contains($0) }
    }

    /// Markdown links become their text, and emphasis and code marks are dropped.
    private static func plainText(_ line: String) -> String {
        var text = line.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        for mark in ["**", "__", "`"] { text = text.replacingOccurrences(of: mark, with: "") }
        return text.trimmingCharacters(in: .whitespaces)
    }

    static func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
}

extension GraphIndex {
    /// Projects by size, each with the files most of its own code connects to.
    /// Noise, config keys, missing files, suspect hubs and names shared by many repos are left out.
    func guideProjects(excluding hubs: Set<String>, limit: Int = AgentGuide.projectLimit) throws -> (projects: [GuideProject], others: Int) {
        try queue.read { db in
            let sizes = try Row.fetchAll(db, sql: """
                SELECT project, COUNT(*) FROM nodes WHERE hidden = 0 AND project != ? GROUP BY project ORDER BY 2 DESC, 1
                """, arguments: [SourcePath.noProject])
            // A name defined in many repos, such as `main()`, says nothing about any one of them.
            let common = Set(try String.fetchAll(db, sql: """
                SELECT label_key FROM nodes WHERE hidden = 0 GROUP BY label_key HAVING COUNT(DISTINCT project) >= 4
                """))
            // Loose files at the top of the root, such as a PDF, aren't projects.
            let real = sizes.filter { row in
                let name: String = row[0]
                return name.contains("/") || (name as NSString).pathExtension.isEmpty
            }
            var projects: [GuideProject] = []
            for row in real.prefix(limit) {
                let project: String = row[0]
                let candidates = try Row.fetchAll(db, sql: """
                    SELECT n.id, n.source_file, n.label, n.label_key, n.degree FROM nodes n
                    LEFT JOIN files f ON f.path = n.source_file
                    WHERE n.project = ? AND n.hidden = 0 AND n.noise_kind IS NULL AND n.config_key = 0
                    AND n.source_file != '' AND COALESCE(f.is_missing, 0) = 0
                    ORDER BY n.degree DESC LIMIT 600
                    """, arguments: [project])
                var scoreByFile: [String: Int] = [:]
                var symbolsByFile: [String: [String]] = [:]
                for candidate in candidates {
                    let id: String = candidate[0]
                    let path: String = candidate[1]
                    let label: String = candidate[2]
                    let key: String = candidate[3]
                    let degree: Int = candidate[4]
                    guard !hubs.contains(id), !common.contains(key) else { continue }
                    scoreByFile[path, default: 0] += degree
                    // graphify names a file's own node by its path, so it repeats the file.
                    let isFileNode = path.hasSuffix(label) || label.hasSuffix((path as NSString).lastPathComponent)
                    let bare = label.replacingOccurrences(of: "()", with: "")
                    if !isFileNode, bare.count > 2, (symbolsByFile[path]?.count ?? 0) < AgentGuide.symbolsPerFile {
                        symbolsByFile[path, default: []].append(label)
                    }
                }
                let files = scoreByFile
                    .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                    .prefix(AgentGuide.filesPerProject)
                    .map { GuideProject.EntryFile(path: $0.key, symbols: symbolsByFile[$0.key] ?? []) }
                projects.append(GuideProject(name: project, nodes: row[1], purpose: nil, entryFiles: files))
            }
            return (projects, max(0, real.count - projects.count))
        }
    }
}

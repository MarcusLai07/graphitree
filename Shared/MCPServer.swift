import Foundation

// What Graphitree answers for AI tools, through the `graphitree` command line or its MCP server: the
// owner's picks by job, the stack, how they work, and questions to the graph or one folder's slice.

struct GraphitreeTools {
    let source: GraphSource
    /// Where the tool was started. Inside a labelled folder, questions go to that folder's slice.
    let cwd: String
    /// `cli` or `mcp`, for the usage log.
    var via = "cli"
    /// Where questions are logged, or nil to log nothing. Insights read it.
    var usageLog: URL?

    var playbook: Playbook { PlaybookFile.load(from: source.outDirectory) }

    private func log(_ tool: String, _ query: String, found: Int) {
        guard let usageLog else { return }
        UsageLog.record(UsageEvent(date: .now, via: via, tool: tool, query: query, found: found, cwd: cwd), to: usageLog)
    }

    func pick(_ job: String) -> String {
        let book = playbook
        log("pick", job, found: PlaybookPicks.find(job, in: book).count)
        return PlaybookPicks.answer(job, in: book)
    }

    /// The labelled main folder this runs in, for folder-specific stack answers.
    var folder: String? {
        let root = URL(fileURLWithPath: source.rootPath).standardizedFileURL.path + "/"
        let here = URL(fileURLWithPath: cwd).standardizedFileURL.path + "/"
        guard here.hasPrefix(root), here != root else { return nil }
        return here.dropFirst(root.count).split(separator: "/").first.map(String.init)
    }

    func stack(folder chosen: String? = nil) -> String {
        log("stack", chosen ?? "", found: 1)
        return PlaybookPicks.stackText(playbook, folder: chosen ?? folder)
    }

    func habits() -> String {
        log("how", "", found: 1)
        return PlaybookPicks.habitsText(playbook)
    }

    func playbookText() -> String {
        let url = source.outDirectory.appendingPathComponent(PlaybookFile.markdownName)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "The owner hasn't written a playbook yet."
    }

    func folders() -> String {
        guard let map = FolderFile.load(from: source.outDirectory), !map.folders.isEmpty else {
            return "The folders under \(AgentGuide.abbreviate(source.rootPath)) aren't labelled yet."
        }
        var text = map.folders.map { label in
            var line = "- \(label.path)/ (\(label.purpose.title))"
            if !label.note.isEmpty { line += ": \(label.note)" }
            if !label.isIncluded { line += " Left out of the graph." }
            return line
        }.joined(separator: "\n")
        let cuts = GraphCuts.load(from: source.outDirectory)
        if !cuts.isEmpty {
            text += "\n\nThe owner keeps \(cuts.count) separate graphs. Questions asked inside a project go to its graph only:"
            for cut in cuts {
                let shown = cut.projects.prefix(6).joined(separator: ", ")
                text += "\n- \(cut.name): \(cut.projects.count) project\(cut.projects.count == 1 ? "" : "s") (\(shown)\(cut.projects.count > 6 ? ", …" : ""))"
            }
        }
        return text
    }

    /// The separate graph a question goes to: the one named, or the one this runs inside.
    func cut(named name: String?, ignoresCuts: Bool) throws -> GraphCuts.Entry? {
        if let name, !name.isEmpty {
            guard let entry = GraphCuts.entry(named: name, outDirectory: source.outDirectory) else {
                let names = GraphCuts.load(from: source.outDirectory).map(\.name)
                throw PlaybookError(message: names.isEmpty ? "There's only one graph here." : "There's no graph called \(name). The graphs are \(names.joined(separator: ", ")).")
            }
            return entry
        }
        return ignoresCuts ? nil : GraphCuts.entry(for: cwd, source: source)
    }

    /// The graph a question goes to: a named graph or folder slice, the separate graph this runs
    /// inside, the folder slice for where this runs, the clean graph when it's current, or the raw graph.
    func graphPath(folder: String?, wholeGraph: Bool, graph name: String? = nil, ignoresCuts: Bool = false) throws -> String {
        if let entry = try cut(named: name, ignoresCuts: ignoresCuts || (folder?.isEmpty == false)) {
            return GraphCuts.url(of: entry, outDirectory: source.outDirectory).path
        }
        if let folder, !folder.isEmpty {
            let slice = FolderSlices.url(for: folder, outDirectory: source.outDirectory).path
            guard FileManager.default.fileExists(atPath: slice) else {
                throw PlaybookError(message: "There's no graph for the folder \(folder). Labelled folders get one when Graphitree saves labels or rebuilds.")
            }
            return slice
        }
        if !wholeGraph, let here = GraphLocator.slice(for: cwd, source: source) { return here.path }
        let clean = source.outDirectory.appendingPathComponent("graph.clean.json").path
        let fileManager = FileManager.default
        if let cleanDate = (try? fileManager.attributesOfItem(atPath: clean))?[.modificationDate] as? Date,
           let rawDate = (try? fileManager.attributesOfItem(atPath: source.graphURL.path))?[.modificationDate] as? Date,
           cleanDate >= rawDate {
            return clean
        }
        return source.graphURL.path
    }

    var budget: Int {
        let rc = (try? String(contentsOfFile: (source.rootPath as NSString).appendingPathComponent(".graphifyrc"), encoding: .utf8)) ?? ""
        return RCFile.value(RCFile.budgetKey, in: rc).flatMap(Int.init) ?? AgentGuide.defaultBudget
    }

    func ask(_ question: String, folder: String? = nil, graph name: String? = nil, wholeGraph: Bool = false, ignoresCuts: Bool = false, budget: Int? = nil) throws -> String {
        let graph = try graphPath(folder: folder, wholeGraph: wholeGraph, graph: name, ignoresCuts: ignoresCuts)
        let output = try graphify(["query", question, "--graph", graph, "--budget", String(budget ?? self.budget)])
        log("ask", question, found: SessionReader.foundCount(in: output))
        return output
    }

    func affected(_ name: String, folder: String? = nil, graph graphName: String? = nil, ignoresCuts: Bool = false) throws -> String {
        let graph = try graphPath(folder: folder, wholeGraph: folder == nil, graph: graphName, ignoresCuts: ignoresCuts)
        let output = try graphify(["affected", name, "--graph", graph])
        log("affected", name, found: output == "Nothing matched." ? 0 : 1)
        return output
    }

    private func graphify(_ arguments: [String]) throws -> String {
        guard let graphify = GraphRebuilder.locateGraphify() else { throw RebuildError.graphifyNotFound }
        let result = try ProcessRunner.run(graphify, arguments, in: URL(fileURLWithPath: source.rootPath), timeout: 90)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.status == 0 else {
            let errors = result.errors.trimmingCharacters(in: .whitespacesAndNewlines)
            throw PlaybookError(message: errors.isEmpty ? "graphify stopped with exit \(result.status)." : errors)
        }
        return output.isEmpty ? "Nothing matched." : output
    }
}

// MARK: - MCP

/// A Model Context Protocol server over stdio: one JSON-RPC message per line in, one per line out.
final class MCPServer {
    static let supportedVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]
    static let version = "0.1.0"
    static let instructions = "Graphitree knows the owner's code knowledge base and playbook. Before adding a dependency or writing a component, call find_pick with the job, such as toasts, forms or a date picker, and use what it returns. Before reading code, call ask_graph to find the files that matter."

    let tools: GraphitreeTools

    init(tools: GraphitreeTools) { self.tools = tools }

    static let toolList: [[String: Any]] = [
        tool("find_pick", "Which library the owner uses for a job, such as toasts, forms, a drawer or a command menu. Call it before adding a dependency or writing a component. Matches everyday words, so \"notifications\" finds the toast library.",
             ["job": ("string", "The job, in plain words, such as \"toast notifications\" or \"date picker\".")], required: ["job"]),
        tool("get_stack", "The owner's default stack for new work: platforms, languages, framework, UI components, styling, back end, data, sign-in, hosting, testing and AI. Some folders have their own answers.",
             ["folder": ("string", "Optional: the main folder the work is in, such as \"work\", for its own answers.")], required: []),
        tool("how_owner_works", "How the owner likes to work: what they build, who uses it, what to always and never do, design taste, and how they work with AI.", [:], required: []),
        tool("read_playbook", "The owner's whole playbook as markdown: rules for AI tools, every library with when to use it, the stack and working notes.", [:], required: []),
        tool("ask_graph", "Search the owner's code knowledge graph for the functions, classes and files involved in a question, each with its file and line. Read only what it names.",
             ["question": ("string", "The task or question in your own words."),
              "folder": ("string", "Optional: a labelled main folder, such as \"work\", to search only its slice of the graph."),
              "graph": ("string", "Optional: one of the owner's separate graphs by name (list_folders names them). Inside a project, its own graph is used anyway.")], required: ["question"]),
        tool("what_depends_on", "What depends on a function, class or file, before you change it.",
             ["name": ("string", "The function, class or file name."),
              "graph": ("string", "Optional: one of the owner's separate graphs by name.")], required: ["name"]),
        tool("list_folders", "What each main folder in the knowledge base is for, in the owner's words, and which are left out.", [:], required: []),
    ]

    private static func tool(_ name: String, _ description: String, _ properties: [String: (String, String)], required: [String]) -> [String: Any] {
        [
            "name": name,
            "description": description,
            "inputSchema": [
                "type": "object",
                "properties": properties.mapValues { ["type": $0.0, "description": $0.1] },
                "required": required,
            ] as [String: Any],
        ]
    }

    /// Answers one line. Notifications get no answer.
    func handle(line: String) -> String? {
        guard let data = line.data(using: .utf8), let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return Self.encode(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "Parse error"]])
        }
        return handle(message).map(Self.encode)
    }

    func handle(_ message: [String: Any]) -> [String: Any]? {
        guard let method = message["method"] as? String else { return nil }
        guard let id = message["id"] else { return nil }
        let params = message["params"] as? [String: Any] ?? [:]
        func reply(_ result: [String: Any]) -> [String: Any] { ["jsonrpc": "2.0", "id": id, "result": result] }
        func failure(_ code: Int, _ text: String) -> [String: Any] { ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": text]] }

        switch method {
        case "initialize":
            let asked = params["protocolVersion"] as? String ?? ""
            return reply([
                "protocolVersion": Self.supportedVersions.contains(asked) ? asked : Self.supportedVersions[0],
                "capabilities": ["tools": ["listChanged": false]],
                "serverInfo": ["name": "graphitree", "version": Self.version],
                "instructions": Self.instructions,
            ])
        case "ping":
            return reply([:])
        case "tools/list":
            return reply(["tools": Self.toolList])
        case "tools/call":
            guard let name = params["name"] as? String else { return failure(-32602, "Missing tool name") }
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            let (text, isError) = call(name, arguments)
            return reply(["content": [["type": "text", "text": text]], "isError": isError])
        default:
            return failure(-32601, "Method not found: \(method)")
        }
    }

    func call(_ name: String, _ arguments: [String: Any]) -> (String, Bool) {
        func text(_ key: String) -> String? {
            let value = (arguments[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return value?.isEmpty == false ? value : nil
        }
        do {
            switch name {
            case "find_pick":
                guard let job = text("job") else { return ("Say which job, such as \"toasts\".", true) }
                return (tools.pick(job), false)
            case "get_stack": return (tools.stack(folder: text("folder")), false)
            case "how_owner_works": return (tools.habits(), false)
            case "read_playbook": return (tools.playbookText(), false)
            case "list_folders": return (tools.folders(), false)
            case "ask_graph":
                guard let question = text("question") else { return ("Ask a question.", true) }
                return (try tools.ask(question, folder: text("folder"), graph: text("graph"), wholeGraph: true), false)
            case "what_depends_on":
                guard let target = text("name") else { return ("Name a function, class or file.", true) }
                return (try tools.affected(target, graph: text("graph")), false)
            default:
                return ("Graphitree has no tool called \(name).", true)
            }
        } catch {
            return (error.localizedDescription, true)
        }
    }

    static func encode(_ object: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    /// Serves until stdin closes.
    func run() {
        while let line = readLine(strippingNewline: true) {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            if let response = handle(line: line) {
                FileHandle.standardOutput.write(Data((response + "\n").utf8))
            }
        }
    }
}

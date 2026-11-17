import Foundation
import GRDB

/// One node in `graphify query` output: `NODE label [src=path loc=L12 community=3]`.
struct QueryNode: Equatable, Sendable {
    let label: String
    let path: String
    let location: String
    let community: Int?
}

/// What `graphify query` printed, read back into parts.
struct QueryAnswer: Equatable, Sendable {
    /// How many nodes the traversal reached, before the token budget cut the list.
    var found: Int?
    var nodes: [QueryNode] = []
    /// How many found nodes the token budget left out.
    var cut: Int?

    /// Reads both output styles: graphify 0.9.6 (`Traversal: … | 162 nodes found`,
    /// `... (truncated — 96 more nodes cut`) and 0.9.105 (`[!] TRUNCATED: showing 41 of 1460 nodes`).
    static func parse(_ text: String) -> QueryAnswer {
        var answer = QueryAnswer()
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("NODE "), let node = node(from: line) {
                answer.nodes.append(node)
            } else if line.contains("Traversal:") {
                answer.found = number(before: " nodes found", in: line) ?? number(before: " node found", in: line) ?? answer.found
            } else if line.hasPrefix("... (truncated") {
                answer.cut = number(before: " more node", in: line)
            } else if line.hasPrefix("[!] TRUNCATED"), let range = line.range(of: "showing ") {
                let parts = line[range.upperBound...].split(separator: " ")
                if parts.count >= 3, parts[1] == "of", let shown = Int(parts[0]), let total = Int(parts[2]) {
                    answer.found = total
                    answer.cut = max(0, total - shown)
                }
            }
        }
        return answer
    }

    /// Reads from the end, so labels with spaces or brackets still parse.
    private static func node(from line: Substring) -> QueryNode? {
        let body = line.dropFirst("NODE ".count)
        guard body.hasSuffix("]"),
              let open = body.range(of: " [src=", options: .backwards) else { return nil }
        let label = String(body[..<open.lowerBound])
        var attributes = body[open.upperBound...].dropLast()
        var community: Int?
        if let range = attributes.range(of: " community=", options: .backwards) {
            community = Int(attributes[range.upperBound...])
            attributes = attributes[..<range.lowerBound]
        }
        var location = ""
        if let range = attributes.range(of: " loc=", options: .backwards) {
            location = String(attributes[range.upperBound...])
            attributes = attributes[..<range.lowerBound]
        }
        return QueryNode(label: label, path: String(attributes), location: location, community: community)
    }

    private static func number(before marker: String, in line: Substring) -> Int? {
        guard let range = line.range(of: marker) else { return nil }
        let digits = line[..<range.lowerBound].reversed().prefix { $0.isNumber }
        return Int(String(digits.reversed()))
    }
}

/// A returned node matched back to the index, with what makes it noise.
struct AnswerItem: Identifiable, Equatable, Sendable {
    let id: String
    /// Nil when the node couldn't be matched to the index.
    let nodeID: String?
    let label: String
    let path: String
    let location: String
    let project: String
    let isGenerated: Bool
    let isMissingFile: Bool
    let isHidden: Bool

    var isNoise: Bool { isGenerated || isMissingFile }
}

enum GraphQuery {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Runs `graphify query` on one graph file. Logging is off, so these questions don't mix
    /// into the history of what agents asked.
    static func run(question: String, graph: URL, timeout: TimeInterval = 30) throws -> String {
        guard let executable = GraphRebuilder.locateGraphify() else {
            throw Failure(message: "graphify isn't installed where Graphitree looks for it (~/.local/bin, /opt/homebrew/bin or /usr/local/bin).")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["query", question, "--graph", graph.path]
        process.currentDirectoryURL = graph.deletingLastPathComponent().deletingLastPathComponent()
        var environment = ProcessInfo.processInfo.environment
        environment["GRAPHIFY_QUERY_LOG_DISABLE"] = "1"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        process.environment = environment
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()

        let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)
        // Both pipes are drained at once, so neither can fill up and stall graphify.
        var errorData = Data()
        let errorsRead = DispatchGroup()
        errorsRead.enter()
        DispatchQueue.global().async {
            errorData = errors.fileHandleForReading.readDataToEndOfFile()
            errorsRead.leave()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        errorsRead.wait()
        deadline.cancel()

        if process.terminationReason == .uncaughtSignal {
            throw Failure(message: "graphify took longer than \(Int(timeout)) seconds, so the question was stopped.")
        }
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw Failure(message: message.isEmpty ? "graphify query stopped with exit \(process.terminationStatus)." : message)
        }
        return String(decoding: data, as: UTF8.self)
    }
}

extension GraphIndex {
    /// Matches each returned node to the index by label and file, preferring the same line.
    func resolve(_ answer: QueryAnswer) throws -> [AnswerItem] {
        try queue.read { db in
            var items: [AnswerItem] = []
            for (index, node) in answer.nodes.enumerated() {
                let row = try Row.fetchOne(db, sql: """
                    SELECT n.id, n.project, n.noise_kind, n.hidden, COALESCE(f.is_missing, 0) FROM nodes n
                    LEFT JOIN files f ON f.path = n.source_file
                    WHERE n.label = ? AND n.source_file = ?
                    ORDER BY COALESCE(n.source_location, '') = ? DESC LIMIT 1
                    """, arguments: [node.label, node.path, node.location])
                let nodeID: String? = row?[0]
                let noiseKind: String? = row?[2]
                items.append(AnswerItem(
                    id: nodeID ?? "unmatched:\(index)",
                    nodeID: nodeID,
                    label: node.label,
                    path: node.path,
                    location: node.location,
                    project: row?[1] ?? (node.path.isEmpty ? SourcePath.noProject : source.scheme.project(of: node.path)),
                    isGenerated: noiseKind != nil,
                    isMissingFile: (row?[4] as Int? ?? 0) != 0,
                    isHidden: (row?[3] as Int? ?? 0) != 0
                ))
            }
            return items
        }
    }
}

extension GraphScene {
    /// An answer drawn as a constellation: the question in the centre, the projects it reached,
    /// and the returned nodes behind them.
    static func answer(question: String, found: Int?, items: [AnswerItem], scheme: ProjectScheme = ProjectScheme(singleRepoName: nil)) -> GraphScene {
        let title = question.count > 48 ? String(question.prefix(47)) + "…" : question
        var builder = ConstellationBuilder(
            centre: SceneNode(
                id: GraphScene.ringCenterID,
                label: title,
                value: max(found ?? items.count, 1),
                group: -1,
                ghost: false,
                ring: 0,
                unit: "nodes found"
            ),
            membersPerProject: 30,
            scheme: scheme
        )
        builder.addByProject(items.map { item in
            ConstellationItem(
                id: item.id,
                label: item.label,
                project: item.project,
                value: 1,
                isNoise: item.isNoise,
                isHidden: item.isHidden
            )
        }, suspect: false)
        return builder.scene
    }
}

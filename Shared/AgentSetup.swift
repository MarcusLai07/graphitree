import Foundation

/// An instructions file someone added by hand, for a tool Graphitree doesn't list.
struct AgentTarget: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let file: String
}

/// Writes and removes Graphitree's pointer in each tool's settings. Every change is shown first,
/// marked so it can be found again, and backed up before the file is touched.
enum AgentSetup {
    static let startMarker = "<!-- graphitree:knowledge-base:start -->"
    static let endMarker = "<!-- graphitree:knowledge-base:end -->"
    private static let marked = MarkedBlock(markers: [(startMarker, endMarker)])
    /// The MCP server's name in chat apps' settings.
    static let serverName = "graphitree"
    /// graphify's own server, which earlier versions set up. Connecting replaces it.
    static let legacyServerName = "graphify"

    /// Any other tool's instructions file, picked by the person. A folder means its `AGENTS.md`,
    /// the file most coding agents read.
    static func customTarget(path: String) -> AgentTarget {
        var isFolder: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isFolder)
        let file = exists && isFolder.boolValue ? (path as NSString).appendingPathComponent("AGENTS.md") : path
        let folder = ((file as NSString).deletingLastPathComponent as NSString).lastPathComponent
        return AgentTarget(id: "custom:" + file, name: "\(folder)/\((file as NSString).lastPathComponent)", file: file)
    }

    /// The pointer without its markers, for tools that take instructions in a settings box.
    static func pastableBlock(guidePath: String, root: String) -> String {
        block(guidePath: guidePath, root: root)
            .split(separator: "\n")
            .filter { !$0.hasPrefix("<!-- graphitree:") }
            .joined(separator: "\n")
    }

    /// The standard `mcpServers` entry that most MCP clients accept.
    static func mcpSnippet(_ launch: MCPLaunch) -> String {
        mcpPreview(.mcpServers, launch: launch)
    }

    // MARK: - Instruction files

    static func block(guidePath: String, root: String) -> String {
        """
        \(startMarker)
        ## Code knowledge base
        A knowledge graph of the code under `\(AgentGuide.abbreviate(root))` is kept by Graphitree. Before exploring or changing code there, read `\(AgentGuide.abbreviate(guidePath))` and follow its steps: ask the graph first, then read only the files it names. It saves most of the tokens otherwise spent exploring.
        \(endMarker)
        """
    }

    static func isConnected(_ text: String) -> Bool {
        !marked.ranges(in: text).isEmpty
    }

    /// Replaces Graphitree's block if it's there, otherwise adds it at the end. Everything else stays.
    static func applying(_ block: String, to text: String) -> String {
        marked.applying(block, to: text)
    }

    /// Takes out Graphitree's block and the blank line it added, leaving the rest as it was.
    static func removing(from text: String) -> String {
        marked.removing(from: text)
    }

    /// Claude Code's own instructions run `graphify query` without `--graph`, which reads the
    /// noisy graph. This adds the clean graph to that command. Nil when there's nothing to change.
    static func pointingQueriesAtCleanGraph(_ text: String, cleanGraph: String) -> String? {
        let bare = "graphify query \"<question>\"`"
        guard text.contains(bare) else { return nil }
        return text.replacingOccurrences(of: bare, with: "graphify query \"<question>\" --graph \(cleanGraph)`")
    }

    // MARK: - Files

    /// Copies the file aside before Graphitree changes it, once per day so repeated edits don't pile up.
    static func backUp(_ path: String, now: Date = .now) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: path) else { return }
        let stamp = ISO8601DateFormatter.string(from: now, timeZone: .current, formatOptions: [.withFullDate])
        let backup = path + ".graphitree-backup-" + stamp
        if !manager.fileExists(atPath: backup) {
            try manager.copyItem(atPath: path, toPath: backup)
        }
    }

    /// Writes through a temporary file, so a tool never reads a half-written settings file.
    static func write(_ text: String, to path: String) throws {
        try write(Data(text.utf8), to: path)
    }

    static func write(_ data: Data, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

/// A block the app writes into someone else's file, between a start and an end marker. Several
/// marker pairs can mean the same block, such as the ones from before the rename, so every pair is
/// found, replaced and removed alike.
struct MarkedBlock {
    let markers: [(start: String, end: String)]

    /// Every block in the text, in order, under any of the markers.
    func ranges(in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        for marker in markers {
            var from = text.startIndex
            while let start = text.range(of: marker.start, range: from..<text.endIndex),
                  let end = text.range(of: marker.end, range: start.upperBound..<text.endIndex) {
                found.append(start.lowerBound..<end.upperBound)
                from = end.upperBound
            }
        }
        // One block can't sit inside another; if it seems to, the outer one wins.
        var result: [Range<String.Index>] = []
        for range in found.sorted(by: { $0.lowerBound < $1.lowerBound }) where !result.contains(where: { $0.overlaps(range) }) {
            result.append(range)
        }
        return result
    }

    /// Puts `block` where the first block is, or at the end when there's none. Any other block
    /// goes, so the file never ends up with two.
    func applying(_ block: String, to text: String) -> String {
        let found = ranges(in: text)
        guard !found.isEmpty else {
            var result = text
            if !result.isEmpty && !result.hasSuffix("\n") { result += "\n" }
            if !result.isEmpty { result += "\n" }
            return result + block + "\n"
        }
        var result = rebuilt(text, without: found, keepingFirstAs: block)
        if found.count > 1 { while result.hasSuffix("\n\n") { result.removeLast() } }
        return result
    }

    /// Takes out every block and the line break after it, leaving the rest as it was.
    func removing(from text: String) -> String {
        let found = ranges(in: text)
        guard !found.isEmpty else { return text }
        var result = rebuilt(text, without: found, keepingFirstAs: nil)
        while result.hasSuffix("\n\n") { result.removeLast() }
        return result
    }

    /// The first block in the text, as it's written there.
    func existing(in text: String) -> String? {
        ranges(in: text).first.map { String(text[$0]) }
    }

    private func rebuilt(_ text: String, without found: [Range<String.Index>], keepingFirstAs block: String?) -> String {
        var result = ""
        var cursor = text.startIndex
        for (index, range) in found.enumerated() {
            result += text[cursor..<range.lowerBound]
            cursor = range.upperBound
            if index == 0, let block {
                result += block
            } else if text[cursor...].hasPrefix("\n") {
                cursor = text.index(after: cursor)
            }
        }
        return result + text[cursor...]
    }
}

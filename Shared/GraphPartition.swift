import CryptoKit
import Foundation

/// Splits one `graph.json` into a file per project, and joins the files back, without losing
/// anything. Backups store the parts: each stays far under GitHub's file limits, and git keeps only
/// what changed between backups, which it can't do for a compressed file.
///
/// The split is a pure partition:
/// - every node is in exactly one file: its project's, or `_unattributed.json` when it has no source file;
/// - an edge is in a project's file when both its ends are, otherwise in `_links.json`;
/// - everything else in the graph is copied unchanged into `_index.json`.
enum GraphPartition {
    static let unattributed = "_unattributed"
    static let links = "_links"
    static let index = "_index"
    /// Written into `_index.json`, so a join knows the parts and can check itself.
    static let metadataKey = "graphitree_parts"

    struct Summary: Equatable, Sendable {
        let nodes: Int
        let edges: Int
        let fingerprint: String
    }

    // MARK: Reading and writing whole graphs

    static func read(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["nodes"] is [[String: Any]] else {
            throw PlaybookError(message: "\(url.lastPathComponent) isn't a graph graphify can read.")
        }
        return root
    }

    static func edgeKey(of root: [String: Any]) -> String { root["links"] != nil ? "links" : (root["edges"] != nil ? "edges" : "links") }

    // MARK: Cutting

    /// Keeps only the given projects' nodes, the edges and hyperedges among them, and the nodes
    /// with no source file that they link to. Hyperedges are trimmed in both places graphify keeps them.
    static func cut(_ root: [String: Any], keeping projects: Set<String>, project: (String) -> String) -> [String: Any] {
        let key = edgeKey(of: root)
        let nodes = root["nodes"] as? [[String: Any]] ?? []
        let edges = root[key] as? [[String: Any]] ?? []
        var kept = Set<String>()
        var loose = Set<String>()
        for node in nodes {
            guard let id = node["id"] as? String else { continue }
            let source = node["source_file"] as? String ?? ""
            if source.isEmpty { loose.insert(id) } else if projects.contains(project(source)) { kept.insert(id) }
        }
        // Library nodes with no source file come along when something kept links to them.
        var linkedLoose = Set<String>()
        for edge in edges {
            guard let source = edge["source"] as? String, let target = edge["target"] as? String else { continue }
            if kept.contains(source), loose.contains(target) { linkedLoose.insert(target) }
            if kept.contains(target), loose.contains(source) { linkedLoose.insert(source) }
        }
        let ids = kept.union(linkedLoose)
        var result = root
        result["nodes"] = nodes.filter { ($0["id"] as? String).map(ids.contains) ?? false }
        result[key] = edges.filter { edge in
            guard let source = edge["source"] as? String, let target = edge["target"] as? String else { return false }
            return ids.contains(source) && ids.contains(target)
        }
        if let hyperedges = root["hyperedges"] as? [[String: Any]] { result["hyperedges"] = trim(hyperedges, to: ids) }
        if var attributes = root["graph"] as? [String: Any], let hyperedges = attributes["hyperedges"] as? [[String: Any]] {
            attributes["hyperedges"] = trim(hyperedges, to: ids)
            result["graph"] = attributes
        }
        return result
    }

    /// Hyperedges with only their members inside `ids`, dropping any left with fewer than two.
    static func trim(_ hyperedges: [[String: Any]], to ids: Set<String>) -> [[String: Any]] {
        hyperedges.compactMap { hyperedge in
            guard let members = hyperedge["nodes"] as? [String] else { return nil }
            let remaining = members.filter(ids.contains)
            guard remaining.count >= 2 else { return nil }
            var trimmed = hyperedge
            trimmed["nodes"] = remaining
            return trimmed
        }
    }

    // MARK: Splitting

    /// The parts, by path inside the backup's `graph/` folder: `personal/odyssey.json`,
    /// `demo-app.json`, `_links.json`, `_unattributed.json`, `_index.json`.
    static func split(_ root: [String: Any], project: (String) -> String) throws -> [String: Data] {
        let key = edgeKey(of: root)
        let nodes = root["nodes"] as? [[String: Any]] ?? []
        let edges = root[key] as? [[String: Any]] ?? []
        var partOfNode: [String: String] = [:]
        var nodesByPart: [String: [[String: Any]]] = [:]
        for node in nodes {
            let id = node["id"] as? String ?? ""
            let source = node["source_file"] as? String ?? ""
            let part = source.isEmpty ? unattributed : project(source)
            partOfNode[id] = part
            nodesByPart[part, default: []].append(node)
        }
        var edgesByPart: [String: [[String: Any]]] = [:]
        for edge in edges {
            let source = edge["source"] as? String ?? ""
            let target = edge["target"] as? String ?? ""
            if let part = partOfNode[source], part == partOfNode[target], part != unattributed {
                edgesByPart[part, default: []].append(edge)
            } else {
                edgesByPart[links, default: []].append(edge)
            }
        }
        var files: [String: Data] = [:]
        let parts = Set(nodesByPart.keys).union(edgesByPart.keys).subtracting([links])
        for part in parts {
            files[fileName(for: part)] = try encodeRecords(["nodes": sortedNodes(nodesByPart[part] ?? []), key: sortedEdges(edgesByPart[part] ?? [])])
        }
        files[fileName(for: links)] = try encodeRecords(["nodes": [], key: sortedEdges(edgesByPart[links] ?? [])])
        var indexObject = root
        indexObject["nodes"] = nil
        indexObject[key] = nil
        indexObject[metadataKey] = [
            "edge_key": key,
            "nodes": nodes.count,
            "edges": edges.count,
            "fingerprint": try summary(of: root).fingerprint,
            "files": files.keys.sorted(),
        ] as [String: Any]
        files[fileName(for: index)] = try JSONSerialization.data(withJSONObject: indexObject, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return files
    }

    static func fileName(for part: String) -> String {
        // A project path keeps its folders, so names can't collide. Nothing climbs out of `graph/`.
        let safe = part.split(separator: "/").filter { $0 != ".." && $0 != "." && !$0.isEmpty }.joined(separator: "/")
        return (safe.isEmpty ? unattributed : safe) + ".json"
    }

    // MARK: Joining

    /// Puts the parts back into one graph.
    static func join(_ files: [String: Data]) throws -> [String: Any] {
        guard let indexData = files[fileName(for: index)],
              var root = try JSONSerialization.jsonObject(with: indexData) as? [String: Any] else {
            throw PlaybookError(message: "The backup has no _index.json, so its graph can't be put back together.")
        }
        let metadata = root[metadataKey] as? [String: Any]
        root[metadataKey] = nil
        let key = metadata?["edge_key"] as? String ?? "links"
        var nodes: [[String: Any]] = []
        var edges: [[String: Any]] = []
        for (name, data) in files.sorted(by: { $0.key < $1.key }) where name != fileName(for: index) {
            guard let part = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            nodes += part["nodes"] as? [[String: Any]] ?? []
            edges += part[key] as? [[String: Any]] ?? []
        }
        root["nodes"] = sortedNodes(nodes)
        root[key] = sortedEdges(edges)
        return root
    }

    /// Joins and checks against what `_index.json` recorded at split time. Throws on any mismatch.
    static func verify(_ files: [String: Data]) throws -> Summary {
        guard let indexData = files[fileName(for: index)],
              let indexObject = try JSONSerialization.jsonObject(with: indexData) as? [String: Any],
              let metadata = indexObject[metadataKey] as? [String: Any],
              let expected = metadata["fingerprint"] as? String else {
            throw PlaybookError(message: "The graph's parts have no record to check against.")
        }
        let joined = try summary(of: try join(files))
        guard joined.fingerprint == expected,
              joined.nodes == metadata["nodes"] as? Int,
              joined.edges == metadata["edges"] as? Int else {
            throw PlaybookError(message: "The graph's parts don't add back up to the graph (\(joined.nodes) nodes and \(joined.edges) edges after joining). Nothing was committed.")
        }
        return joined
    }

    /// Counts and a hash that ignore the order of nodes and edges, for checking a join.
    static func summary(of root: [String: Any]) throws -> Summary {
        let key = edgeKey(of: root)
        let nodes = root["nodes"] as? [[String: Any]] ?? []
        let edges = root[key] as? [[String: Any]] ?? []
        var hasher = SHA256()
        for line in try nodes.map(canonical).sorted() { hasher.update(data: Data(line.utf8)); hasher.update(data: Data([10])) }
        hasher.update(data: Data("--edges--".utf8))
        for line in try edges.map(canonical).sorted() { hasher.update(data: Data(line.utf8)); hasher.update(data: Data([10])) }
        var rest = root
        rest["nodes"] = nil
        rest[key] = nil
        rest[metadataKey] = nil
        hasher.update(data: Data("--rest--".utf8))
        hasher.update(data: Data(try canonical(rest).utf8))
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return Summary(nodes: nodes.count, edges: edges.count, fingerprint: digest)
    }

    // MARK: Encoding

    private static func canonical(_ object: [String: Any]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
    }

    private static func sortedNodes(_ nodes: [[String: Any]]) -> [[String: Any]] {
        nodes.sorted { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    }

    private static func sortedEdges(_ edges: [[String: Any]]) -> [[String: Any]] {
        let keyed = edges.map { edge -> (String, [String: Any]) in
            let text = (try? canonical(edge)) ?? ""
            return ((edge["source"] as? String ?? "") + "\u{1}" + (edge["target"] as? String ?? "") + "\u{1}" + text, edge)
        }
        return keyed.sorted { $0.0 < $1.0 }.map(\.1)
    }

    /// A small JSON object with one record per line, so unchanged records stay unchanged lines.
    private static func encodeRecords(_ lists: [String: [[String: Any]]]) throws -> Data {
        var text = "{"
        for (offset, name) in lists.keys.sorted().enumerated() {
            if offset > 0 { text += "," }
            text += "\n\"\(name)\": ["
            let records = try lists[name, default: []].map(canonical)
            text += records.isEmpty ? "]" : "\n" + records.joined(separator: ",\n") + "\n]"
        }
        text += "\n}\n"
        return Data(text.utf8)
    }
}

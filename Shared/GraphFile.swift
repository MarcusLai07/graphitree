import Foundation

/// A graphify output folder and the project root its `source_file` paths are relative to.
struct GraphSource: Sendable {
    let outDirectory: URL
    let rootPath: String
    let scheme: ProjectScheme

    init(outDirectory: URL) {
        self.outDirectory = outDirectory
        rootPath = Self.readRoot(outDirectory: outDirectory)
        let isRepo = FileManager.default.fileExists(atPath: rootPath + "/.git")
        if isRepo {
            scheme = ProjectScheme(singleRepoName: (rootPath as NSString).lastPathComponent)
        } else if let map = FolderFile.load(from: outDirectory), !map.folders.isEmpty {
            // The person's labels say which folders hold projects and how the map groups them.
            scheme = ProjectScheme(singleRepoName: nil, groups: map.groups, areas: map.areasByFolder, projectAreas: map.areasByProject)
        } else {
            let detected = FolderScan.detectedGroups(root: rootPath)
            scheme = ProjectScheme(singleRepoName: nil, groups: detected.isEmpty ? SourcePath.defaultGroups : detected)
        }
    }

    var graphURL: URL { outDirectory.appendingPathComponent("graph.json") }
    var labelsURL: URL { outDirectory.appendingPathComponent(".graphify_labels.json") }

    /// graphify records the build root in `.graphify_root`, sometimes wrapped in quotes.
    /// Falls back to the output folder's parent.
    private static func readRoot(outDirectory: URL) -> String {
        let marker = outDirectory.appendingPathComponent(".graphify_root")
        if let text = try? String(contentsOf: marker, encoding: .utf8) {
            let root = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'")))
            if root.hasPrefix("/") { return root }
        }
        return outDirectory.deletingLastPathComponent().path
    }

    /// Where a source file is on disk, or nil if it's gone. A per-repo graph can hold paths
    /// written from a parent folder, like `personal/depot/docs/a.md`, so those check upward too.
    func existingPath(for path: String) -> String? {
        let fileManager = FileManager.default
        let direct = SourcePath.absolute(path, root: rootPath)
        if fileManager.fileExists(atPath: direct) { return direct }
        guard scheme.singleRepoName != nil, !path.hasPrefix("/") else { return nil }
        var ancestor = rootPath as NSString
        for _ in 0..<3 {
            ancestor = ancestor.deletingLastPathComponent as NSString
            let candidate = ancestor.appendingPathComponent(path)
            if fileManager.fileExists(atPath: candidate) { return candidate }
        }
        return nil
    }
}

/// How paths map to projects. In a single repo, top-level folders like `src` aren't projects.
/// Otherwise a group folder, like `work/`, holds projects, and any other top-level folder is one.
struct ProjectScheme: Sendable, Equatable {
    let singleRepoName: String?
    var groups: Set<String> = SourcePath.defaultGroups
    /// Areas by top-level folder, from the person's labels.
    var areas: [String: FolderArea] = [:]
    /// Areas by project, where Arrange put a project somewhere its main folder doesn't.
    var projectAreas: [String: FolderArea] = [:]

    func project(of path: String) -> String {
        guard let singleRepoName else { return SourcePath.project(of: path, groups: groups) }
        return path.isEmpty ? SourcePath.noProject : singleRepoName
    }

    /// Where a project sits on the map: where Arrange put it, its own or its group's label, or a
    /// group's name when nothing is labelled. Nil means "Other".
    func area(ofProject project: String) -> FolderArea? {
        if let area = projectAreas[project] { return area }
        let top = project.split(separator: "/").first.map(String.init) ?? project
        if let area = areas[top] { return area }
        guard areas.isEmpty, groups.contains(top), project.contains("/") else { return nil }
        return FolderArea(name: top.capitalized, purpose: FolderPurpose.defaults.first { $0.id == top.lowercased() } ?? .other)
    }
}

/// The parts of `graph.json` the index needs. Everything else in the file is ignored.
struct RawGraph: Decodable {
    let nodes: [RawNode]
    let edges: [RawEdge]

    private enum CodingKeys: String, CodingKey {
        case nodes, links, edges
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([RawNode].self, forKey: .nodes)
        // NetworkX writes "links"; some graphify versions write "edges".
        edges = try container.decodeIfPresent([RawEdge].self, forKey: .links)
            ?? container.decodeIfPresent([RawEdge].self, forKey: .edges)
            ?? []
    }
}

struct RawNode: Decodable {
    let id: String
    let label: String
    let normLabel: String?
    let fileType: String?
    let sourceFile: String?
    let sourceLocation: String?
    let community: Int?
    /// graphify's name for the node's community: a chosen one, or a stand-in named after its busiest symbol.
    let communityName: String?

    private enum CodingKeys: String, CodingKey {
        case id, label, community
        case communityName = "community_name"
        case normLabel = "norm_label"
        case fileType = "file_type"
        case sourceFile = "source_file"
        case sourceLocation = "source_location"
    }
}

struct RawEdge: Decodable {
    let source: String
    let target: String
    let relation: String?
    let confidence: String?
}

enum NoiseKind: String, Sendable {
    case generated
    case vendored
}

enum SourcePath {
    static let noProject = "(none)"

    /// Folders whose subfolders are projects, when nothing else says so.
    static let defaultGroups: Set<String> = ["work", "personal"]

    /// `work/foo/src/a.ts` is project `work/foo`; `demo-app/a.md` is project `demo-app`.
    static func project(of path: String, groups: Set<String> = defaultGroups) -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard let first = parts.first, !first.isEmpty else { return noProject }
        if groups.contains(String(first)), parts.count > 2 {
            return parts.prefix(2).joined(separator: "/")
        }
        return String(first)
    }

    /// Matches build output and third-party code. Deliberately leaves `components/ui` alone:
    /// those files are copied into a project and are the owner's to edit.
    static func noiseKind(of path: String) -> NoiseKind? {
        // The leading slash lets folder markers match at the very start of a per-repo path.
        let rooted = "/" + path
        let vendored = ["/static/lib/", "/vendor/", "/node_modules/", "/third_party/"]
        if path.hasSuffix(".min.js") || path.hasSuffix(".min.css")
            || vendored.contains(where: rooted.contains) {
            return .vendored
        }
        let generated = ["/generated/", ".gen.", "/dist/", "/build/", "/.next/", "/migrations/"]
        // Bundlers write `*.bundle.js`, which is minified output even without `.min` in its name.
        if path.hasSuffix(".d.ts") || path.hasSuffix(".bundle.js") || generated.contains(where: rooted.contains) {
            return .generated
        }
        return nil
    }

    static func absolute(_ path: String, root: String) -> String {
        path.hasPrefix("/") ? path : root + "/" + path
    }

    /// The folder a noisy file belongs to, or the file itself for one-off matches like `routeTree.gen.ts`.
    static func noiseGroup(of path: String) -> String? {
        guard noiseKind(of: path) != nil else { return nil }
        let rooted = "/" + path
        let folders = ["/static/lib/", "/vendor/", "/node_modules/", "/third_party/", "/generated/", "/dist/", "/build/", "/.next/", "/migrations/"]
        let earliest = folders.compactMap { rooted.range(of: $0) }.min { $0.lowerBound < $1.lowerBound }
        guard let earliest else { return path }
        return String(rooted[rooted.index(after: rooted.startIndex)..<earliest.upperBound])
    }

    /// A key inside a config file, such as `scripts` in `package.json`. The file's own node doesn't count.
    static func isConfigKey(labelKey: String, path: String) -> Bool {
        let name = (path as NSString).lastPathComponent.lowercased()
        guard name.hasSuffix(".json") || name.hasSuffix(".toml") || name.hasSuffix(".yaml") || name.hasSuffix(".yml") else {
            return false
        }
        return labelKey.lowercased() != name
    }

    /// A line for `.graphifyignore`. The leading slash anchors it to the graph root, and
    /// `[` is escaped because graphify matches these with `fnmatch`.
    static func ignoreLine(for group: String) -> String {
        "/" + group.replacingOccurrences(of: "[", with: "[[]")
    }
}

enum EdgeKind {
    /// Relations that come from resolving code symbols, where a name can match the wrong project.
    static let codeRelations: Set<String> = [
        "calls", "indirect_call", "references", "imports", "imports_from",
        "implements", "inherits", "method", "contains", "re_exports",
    ]

    /// Likely a false match: code resolved to code in a different project.
    static func isSuspect(relation: String?, sourceProject: String?, targetProject: String?, bothCode: Bool) -> Bool {
        guard bothCode, let relation, codeRelations.contains(relation) else { return false }
        return isCrossProject(sourceProject, targetProject)
    }

    static func isCrossProject(_ source: String?, _ target: String?) -> Bool {
        guard let source, let target,
              source != SourcePath.noProject, target != SourcePath.noProject else { return false }
        return source != target
    }
}

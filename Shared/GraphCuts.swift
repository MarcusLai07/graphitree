import Foundation

/// Separate graphs as files AI tools can ask: `graphify-out/graphs/<slug>.json`, one per graph, cut
/// from the one build with the same rule backups use. Links between graphs are left out, so an AI
/// tool asking one graph never follows a link into another. `graphs/cuts.json` lists which projects
/// each cut holds, so the command line and MCP server find the right cut without reading the
/// arrangement. With one graph there are no cuts, and the folder slices do the job.
enum GraphCuts {
    static let folderName = "graphs"
    static let indexName = "cuts.json"

    struct Entry: Codable, Equatable, Sendable {
        let id: String
        let name: String
        let slug: String
        /// Relative to graphify-out, such as `graphs/work.json`.
        let file: String
        let projects: [String]
        let nodes: Int
    }

    private struct Index: Codable {
        var version = 1
        var graphs: [Entry]
    }

    static func directory(_ outDirectory: URL) -> URL { outDirectory.appendingPathComponent(folderName, isDirectory: true) }

    static func load(from outDirectory: URL) -> [Entry] {
        guard let data = try? Data(contentsOf: directory(outDirectory).appendingPathComponent(indexName)),
              let index = try? JSONDecoder().decode(Index.self, from: data) else { return [] }
        return index.graphs
    }

    static func url(of entry: Entry, outDirectory: URL) -> URL { outDirectory.appendingPathComponent(entry.file) }

    /// Writes a cut per graph and the list of cuts, and removes cuts for graphs no longer there.
    /// With one graph, removes them all. Returns the entries written.
    @discardableResult
    static func write(_ root: [String: Any], arrangement: Arrangement, outDirectory: URL) throws -> [Entry] {
        let folder = directory(outDirectory)
        let fileManager = FileManager.default
        guard arrangement.graphs.count > 1 else {
            if fileManager.fileExists(atPath: folder.path) { try fileManager.removeItem(at: folder) }
            return []
        }
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let groups = Set(arrangement.labels.filter(\.holdsProjects).map(\.path))
        let homeID = arrangement.graphs.first(where: \.isHome)?.id ?? arrangement.graphs[0].id
        let arranged = Set(arrangement.projects.map(\.path))
        var ownerByProject: [String: String?] = [:]
        func owner(of path: String) -> String? {
            let project = SourcePath.project(of: path, groups: groups)
            if let known = ownerByProject[project] { return known }
            // Anything not in an arranged project (hidden folders, loose files) goes with the home graph.
            let found = arranged.contains(project) ? arrangement.graph(ofProject: project)?.id : homeID
            ownerByProject[project] = found
            return found
        }
        var entries: [Entry] = []
        var slugs = Set<String>()
        for graph in arrangement.graphs {
            var slug = graph.slug
            var counter = 2
            while !slugs.insert(slug).inserted {
                slug = "\(graph.slug)-\(counter)"
                counter += 1
            }
            let cut = BackupContents.cut(root) { owner(of: $0) == graph.id }
            let data = try JSONSerialization.data(withJSONObject: cut, options: [.withoutEscapingSlashes, .sortedKeys])
            let file = folderName + "/" + slug + ".json"
            try writeAtomically(data, to: outDirectory.appendingPathComponent(file))
            let projects = arrangement.projects(inGraph: graph.id).map(\.path).sorted()
            entries.append(Entry(id: graph.id, name: graph.name, slug: slug, file: file, projects: projects, nodes: (cut["nodes"] as? [Any])?.count ?? 0))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try writeAtomically(try encoder.encode(Index(graphs: entries)), to: folder.appendingPathComponent(indexName))
        let wanted = Set(entries.map { ($0.file as NSString).lastPathComponent } + [indexName])
        for name in (try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? [] where !wanted.contains(name) {
            try? fileManager.removeItem(at: folder.appendingPathComponent(name))
        }
        return entries
    }

    /// The cut a working folder's project is in, such as `personal/odyssey/src` → the Personal cut.
    static func entry(for cwd: String, source: GraphSource) -> Entry? {
        let root = URL(fileURLWithPath: source.rootPath).standardizedFileURL.path + "/"
        let here = URL(fileURLWithPath: cwd).standardizedFileURL.path + "/"
        guard here.hasPrefix(root), here != root else { return nil }
        let relative = String(here.dropFirst(root.count).dropLast())
        return entry(forPath: relative, outDirectory: source.outDirectory)
    }

    /// The cut holding the project a path relative to the root is in.
    static func entry(forPath relative: String, outDirectory: URL) -> Entry? {
        let entries = load(from: outDirectory)
        var best: (Entry, Int)?
        for entry in entries {
            for project in entry.projects where relative == project || relative.hasPrefix(project + "/") {
                if project.count > best?.1 ?? -1 { best = (entry, project.count) }
            }
        }
        guard let found = best?.0, FileManager.default.fileExists(atPath: url(of: found, outDirectory: outDirectory).path) else { return nil }
        return found
    }

    /// A cut by its name or slug, ignoring case.
    static func entry(named name: String, outDirectory: URL) -> Entry? {
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        return load(from: outDirectory).first { $0.name.lowercased() == wanted || $0.slug == wanted || $0.slug == GraphPlan.slug(wanted) }
    }

    private static func writeAtomically(_ data: Data, to url: URL) throws {
        let temporary = url.path + ".\(UUID().uuidString).tmp"
        try data.write(to: URL(fileURLWithPath: temporary))
        guard rename(temporary, url.path) == 0 else {
            try? FileManager.default.removeItem(atPath: temporary)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }
}

/// Cutting both kinds at once, from one read of graph.json: a slice per labelled main folder and a
/// cut per separate graph.
enum GraphSlicing {
    /// Writes the folder slices and graph cuts. `arrangement` nil reads it from disk, which scans
    /// the folders. Returns an error message or nil.
    static func writeAll(outDirectory: URL, labels: [FolderLabel]? = nil, arrangement given: Arrangement? = nil) -> String? {
        let source = GraphSource(outDirectory: outDirectory)
        guard let root = try? GraphPartition.read(source.graphURL) else { return nil }
        var failures: [String] = []
        if let labels = labels ?? FolderFile.load(from: outDirectory)?.folders {
            do {
                try FolderSlices.write(root, outDirectory: outDirectory, folders: labels.filter(\.isIncluded).map(\.path))
            } catch {
                failures.append("the folder graphs couldn't be written: \(error.localizedDescription)")
            }
        }
        let plans = GraphPlans.load(from: outDirectory) ?? []
        if plans.count > 1 || FileManager.default.fileExists(atPath: GraphCuts.directory(outDirectory).path) {
            let arrangement = given ?? BackupJob.arrangement(outDirectory: outDirectory, graph: root, scan: FolderScan.scan(root: source.rootPath, identity: []))
            do {
                try GraphCuts.write(root, arrangement: arrangement, outDirectory: outDirectory)
            } catch {
                failures.append("the separate graphs couldn't be written: \(error.localizedDescription)")
            }
        }
        return failures.isEmpty ? nil : failures.joined(separator: "; ")
    }
}

import Foundation

struct GraphEntry: Identifiable, Hashable, Sendable {
    let name: String
    let outDirectory: URL
    let modifiedAt: Date

    var id: String { outDirectory.path }
}

/// Finds every graphify output folder under a root, machine-wide graph first.
enum GraphCatalog {
    /// Graphs for folders the person mapped elsewhere, named after the folder.
    static func mapped(_ roots: [String], excluding known: Set<String>) -> [GraphEntry] {
        roots.compactMap { root in
            let out = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("graphify-out", isDirectory: true)
            guard !known.contains(out.standardizedFileURL.path),
                  let attributes = try? FileManager.default.attributesOfItem(atPath: out.appendingPathComponent("graph.json").path) else { return nil }
            return GraphEntry(name: (root as NSString).lastPathComponent, outDirectory: out, modifiedAt: attributes[.modificationDate] as? Date ?? .distantPast)
        }
    }

    static func discover(under root: URL, maxDepth: Int = 3) -> [GraphEntry] {
        let fileManager = FileManager.default
        var found: [GraphEntry] = []
        let rootPath = root.standardizedFileURL.path

        func visit(_ directory: URL, depth: Int) {
            guard depth <= maxDepth,
                  let children = try? fileManager.contentsOfDirectory(
                      at: directory,
                      includingPropertiesForKeys: [.isDirectoryKey],
                      options: [.skipsHiddenFiles]
                  ) else { return }
            for child in children {
                guard (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                      child.lastPathComponent != "node_modules" else { continue }
                if child.lastPathComponent == "graphify-out" {
                    let graph = child.appendingPathComponent("graph.json")
                    guard let attributes = try? fileManager.attributesOfItem(atPath: graph.path) else { continue }
                    let parent = child.deletingLastPathComponent().standardizedFileURL.path
                    let relative = parent == rootPath ? "" : String(parent.dropFirst(rootPath.count + 1))
                    found.append(GraphEntry(
                        name: relative.isEmpty ? "Machine-wide" : relative,
                        outDirectory: child,
                        modifiedAt: attributes[.modificationDate] as? Date ?? .distantPast
                    ))
                } else {
                    visit(child, depth: depth + 1)
                }
            }
        }

        visit(root, depth: 1)
        return found.sorted {
            if ($0.name == "Machine-wide") != ($1.name == "Machine-wide") { return $0.name == "Machine-wide" }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

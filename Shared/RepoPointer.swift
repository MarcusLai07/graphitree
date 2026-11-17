import Foundation

// A pointer inside a repo, for cloud agents that never see the owner's Mac: a short block in the
// repo's AGENTS.md (or CLAUDE.md) with the owner's picks and stack. It's committed with the repo,
// so the person ticks each repo and sees the block first.

enum RepoPointer {
    static let startMarker = "<!-- graphitree-playbook:start -->"
    static let endMarker = "<!-- graphitree-playbook:end -->"
    private static let marked = MarkedBlock(markers: [(startMarker, endMarker)])

    enum Status: Equatable, Sendable {
        /// No pointer yet.
        case none
        case current
        /// A pointer from an older playbook.
        case outdated
    }

    /// The file that gets the pointer: AGENTS.md when the repo has one, else CLAUDE.md when it
    /// has one, else a new AGENTS.md, which most coding agents read.
    static func targetFile(repo: String) -> String {
        let fileManager = FileManager.default
        let agents = (repo as NSString).appendingPathComponent("AGENTS.md")
        let claude = (repo as NSString).appendingPathComponent("CLAUDE.md")
        if fileManager.fileExists(atPath: agents) { return agents }
        if fileManager.fileExists(atPath: claude) { return claude }
        return agents
    }

    /// The block itself: the owner's picks and stack, and the folder's purpose when there is one.
    static func block(playbook: Playbook, folder: FolderLabel?, hasCommand: Bool, graph: String? = nil) -> String {
        var lines = [startMarker]
        lines.append("<!-- Written by Graphitree from the owner's playbook. Graphitree rewrites this block, so change the playbook instead. -->")
        lines.append("## The owner's playbook")
        lines.append("")
        if let folder, !folder.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let note = folder.note.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("This repo is in the owner's \(folder.areaName) folder: \(note.hasSuffix(".") ? note : note + ".")")
            lines.append("")
        }
        lines.append("Before you add a dependency or write a component, use the owner's picks below, and ask before going against them. Prefer what this repo already depends on.")
        // The folder's own stack answers replace the defaults inside it.
        var local = playbook.effective(for: folder?.path)
        local.folderStacks = nil
        let summary = PlaybookFile.guideSummary(local)
        if !summary.isEmpty {
            lines.append("")
            lines.append(contentsOf: summary)
        }
        if let graph {
            lines.append("")
            lines.append("The owner keeps this repo's code in a graph of its own, \(graph), apart from their other code. Don't bring in code or patterns from their other graphs.")
        }
        if hasCommand {
            lines.append("")
            lines.append("On the owner's Mac, `graphitree pick <job>` finds the pick for a job and `graphitree ask \"<task>\"` searches the code knowledge graph\(graph == nil ? "" : " (this repo's graph only)").")
        }
        lines.append(endMarker)
        return lines.joined(separator: "\n")
    }

    static func existingBlock(in text: String) -> String? {
        marked.existing(in: text)
    }

    /// Replaces the pointer if it's there, otherwise adds it at the end. Everything else stays.
    static func applying(_ block: String, to text: String) -> String {
        marked.applying(block, to: text)
    }

    /// Takes the pointer out, and the line break after it, leaving the rest as it was.
    static func removing(from text: String) -> String {
        marked.removing(from: text)
    }

    static func status(repo: String, block: String) -> Status {
        let text = (try? String(contentsOfFile: targetFile(repo: repo), encoding: .utf8)) ?? ""
        let found = marked.ranges(in: text)
        guard let first = found.first else { return .none }
        // A second block also needs rewriting.
        return found.count == 1 && String(text[first]) == block ? .current : .outdated
    }

    /// Writes or updates the pointer. There's no backup file: the repo's own history keeps the old version.
    static func write(_ block: String, repo: String) throws {
        let file = targetFile(repo: repo)
        let text = (try? String(contentsOfFile: file, encoding: .utf8)) ?? ""
        let updated = applying(block, to: text)
        guard updated != text else { return }
        try updated.write(toFile: file, atomically: true, encoding: .utf8)
    }

    /// Removes the pointer. A file Graphitree created and that holds nothing else is removed too.
    static func remove(repo: String) throws {
        let file = targetFile(repo: repo)
        guard let text = try? String(contentsOfFile: file, encoding: .utf8), existingBlock(in: text) != nil else { return }
        let updated = removing(from: text)
        if updated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try FileManager.default.removeItem(atPath: file)
        } else {
            try updated.write(toFile: file, atomically: true, encoding: .utf8)
        }
    }
}

/// A repo that can hold a pointer, with the block it would get now and what it has.
struct PointerRepo: Identifiable, Equatable, Sendable {
    /// Relative to the root, such as `personal/odyssey`.
    let path: String
    /// The file the pointer goes in, such as `AGENTS.md`.
    let file: String
    let status: RepoPointer.Status
    /// The block the repo would get now.
    let block: String
    /// In a folder other people can read, such as work or a client's, so the block is seen by them.
    let isShared: Bool

    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }

    /// Repos at the top level, then each group's. Folders labelled to stay out of the graph by
    /// default, such as reference and archive, are someone else's or old, so they get none.
    static func list(scan: FolderScanResult, labels: [FolderLabel], root: String, block: (String) -> String) -> [PointerRepo] {
        let byPath = Dictionary(labels.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [PointerRepo] = []
        for folder in scan.folders {
            let label = byPath[folder.path]
            if label?.purpose.isLeftOutByDefault == true { continue }
            let repos = folder.repo.map { [$0.path] } ?? folder.children.map(\.path)
            for repo in repos {
                let absolute = (root as NSString).appendingPathComponent(repo)
                let text = block(repo)
                result.append(PointerRepo(
                    path: repo,
                    file: (RepoPointer.targetFile(repo: absolute) as NSString).lastPathComponent,
                    status: RepoPointer.status(repo: absolute, block: text),
                    block: text,
                    isShared: label?.purpose.isShared == true
                ))
            }
        }
        return result
    }
}

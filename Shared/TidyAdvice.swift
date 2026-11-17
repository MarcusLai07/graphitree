import Foundation

// Tidy Up's advice: for each suggestion, what to keep, what can go, and why. Nothing is deleted
// without the person confirming one item, and a repo is offered for deletion only when nothing in
// it would be lost: every change committed, every commit on a remote.

/// What deleting a repo would lose, from git.
struct RepoCheck: Equatable, Sendable {
    /// Files changed or added and not committed.
    var uncommitted = 0
    /// Commits that aren't on any remote.
    var unpushed = 0
    var stashes = 0
    var hasRemote = false
    var lastCommit: Date?
    var branch: String?
    /// A git worktree: its commits live in its main repo, so removing it loses only uncommitted work.
    var isWorktree = false

    /// What would be lost, in words. Empty when everything is safe elsewhere.
    var losses: [String] {
        var lines: [String] = []
        if uncommitted > 0 { lines.append("\(uncommitted) changed file\(uncommitted == 1 ? "" : "s") not committed") }
        if !isWorktree {
            if !hasRemote {
                lines.append("no remote: this is the only copy")
            } else if unpushed > 0 {
                lines.append("\(unpushed) commit\(unpushed == 1 ? "" : "s") not pushed")
            }
            if stashes > 0 { lines.append("\(stashes) stash\(stashes == 1 ? "" : "es")") }
        }
        return lines
    }

    var canDelete: Bool { losses.isEmpty }

    /// Asks git about a repo. A folder git can't read comes back as having no remote, so it's never
    /// offered for deletion.
    static func run(_ path: String, isWorktree: Bool = false) -> RepoCheck {
        func git(_ arguments: [String]) -> String? {
            guard let result = try? ProcessRunner.run("/usr/bin/git", ["-C", path] + arguments, timeout: 20), result.status == 0 else { return nil }
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func lines(_ text: String?) -> Int { text.map { $0.split(separator: "\n").count } ?? 0 }
        var check = RepoCheck(isWorktree: isWorktree)
        guard let status = git(["status", "--porcelain"]) else { return check }
        check.uncommitted = lines(status)
        check.hasRemote = !(git(["remote"]) ?? "").isEmpty
        check.unpushed = Int(git(["rev-list", "--count", "HEAD", "--not", "--remotes"]) ?? "") ?? 0
        check.stashes = lines(git(["stash", "list"]))
        check.lastCommit = (git(["log", "-1", "--format=%ct"]).flatMap(TimeInterval.init)).map(Date.init(timeIntervalSince1970:))
        check.branch = git(["rev-parse", "--abbrev-ref", "HEAD"])
        return check
    }
}

/// One clone of a repo, with what git says about it.
struct CloneFacts: Equatable, Sendable {
    let path: String
    let check: RepoCheck
    /// The repo's name from its remote, such as `weather-widget`.
    let remoteName: String?
    let isInGraph: Bool
}

enum TidyAdvice {
    /// Of several clones of one repo, the one to keep and what makes it the one. The main checkout
    /// wins over a worktree, then the one in the graph, then the one named like the repo, then the
    /// one with the newest commit.
    static func keeper(of clones: [CloneFacts]) -> (path: String, reasons: [String])? {
        guard !clones.isEmpty else { return nil }
        let newest = clones.compactMap(\.check.lastCommit).max()
        func score(_ clone: CloneFacts) -> Int {
            var score = 0
            if !clone.check.isWorktree { score += 8 }
            if clone.isInGraph { score += 4 }
            if let name = clone.remoteName, (clone.path as NSString).lastPathComponent.lowercased() == name.lowercased() { score += 2 }
            if let newest, clone.check.lastCommit == newest { score += 1 }
            return score
        }
        let ranked = clones.sorted { score($0) != score($1) ? score($0) > score($1) : $0.path < $1.path }
        let best = ranked[0]
        var reasons: [String] = []
        if !best.check.isWorktree && clones.contains(where: \.check.isWorktree) { reasons.append("the main checkout") }
        if best.isInGraph && clones.contains(where: { !$0.isInGraph }) { reasons.append("already in the graph") }
        if let name = best.remoteName, (best.path as NSString).lastPathComponent.lowercased() == name.lowercased() { reasons.append("named like the repo") }
        if let newest, best.check.lastCommit == newest, let date = best.check.lastCommit { reasons.append("newest commit, \(shortDate(date))") }
        return (best.path, reasons)
    }

    /// Why a clone isn't the one to keep, as a sentence.
    static func whyNot(_ clone: CloneFacts) -> String {
        var parts: [String] = []
        if clone.check.isWorktree { parts.append("a worktree") }
        if !clone.isInGraph { parts.append("left out of the graph") }
        if let date = clone.check.lastCommit { parts.append("last commit \(shortDate(date))") }
        if let branch = clone.check.branch, branch != "HEAD" { parts.append("on \(branch)") }
        guard let first = parts.first else { return "" }
        parts[0] = first.prefix(1).uppercased() + first.dropFirst()
        return parts.joined(separator: ", ") + "."
    }

    /// `weather-widget` from any form of a GitHub remote.
    static func repoName(fromRemote remote: String?) -> String? {
        guard let remote else { return nil }
        let last = remote.split(whereSeparator: { $0 == "/" || $0 == ":" }).last.map(String.init) ?? ""
        let name = last.hasSuffix(".git") ? String(last.dropLast(4)) : last
        return name.isEmpty ? nil : name
    }

    /// How a loose file compares with its copy inside a project.
    enum CopyVerdict: Equatable, Sendable {
        /// Byte for byte the same, so the loose one can go.
        case identical
        /// Different contents. `looseIsNewer` says which was changed last.
        case differs(looseIsNewer: Bool)
        case missing
    }

    static func compare(loose: String, copy: String) -> CopyVerdict {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: loose), fileManager.fileExists(atPath: copy) else { return .missing }
        if fileManager.contentsEqual(atPath: loose, andPath: copy) { return .identical }
        let looseDate = (try? fileManager.attributesOfItem(atPath: loose)[.modificationDate] as? Date) ?? .distantPast
        let copyDate = (try? fileManager.attributesOfItem(atPath: copy)[.modificationDate] as? Date) ?? .distantPast
        return .differs(looseIsNewer: looseDate > copyDate)
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

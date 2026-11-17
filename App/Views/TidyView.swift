import AppKit
import SwiftUI

/// Tidy Up: what's on disk that muddies the graph (copies, second clones, other people's repos,
/// work untouched for a year) with what to keep, what can go, and why. Nothing is deleted until the
/// person confirms that one item, and a repo is offered only when nothing in it would be lost.
struct TidyView: View {
    @Environment(AppModel.self) private var model
    let openBuild: () -> Void

    private struct PendingMove: Identifiable {
        let paths: [String]
        let destination: String
        var id: String { paths.joined(separator: "|") + ">" + destination }
    }

    /// Items waiting for the person to confirm they go to the Trash.
    private struct Trashing: Identifiable {
        let paths: [String]
        /// Why it's safe, in a sentence.
        let note: String
        var id: String { paths.joined(separator: "|") }
    }

    private struct Worktree: Identifiable {
        let path: String
        let main: String
        let branch: String?
        var id: String { path }
    }

    @State private var scan: FolderScanResult?
    @State private var labels: [FolderLabel] = []
    @State private var ignored: Set<String> = []
    /// What git says about each repo a suggestion names, by its path from the root.
    @State private var checks: [String: RepoCheck] = [:]
    @State private var copies: [String: TidyAdvice.CopyVerdict] = [:]
    @State private var message: String?
    @State private var needsRebuild = false
    @State private var pendingMove: PendingMove?
    @State private var trashing: Trashing?
    @State private var removingWorktree: Worktree?
    @State private var trashed: [(original: URL, inTrash: URL)] = []
    @AppStorage("dismissedTidyTips") private var dismissedRaw = ""

    private var root: String { model.graphRoot }
    private var dismissed: Set<String> { Set(dismissedRaw.split(separator: "\n").map(String.init)) }

    private var repos: [String: RepoInfo] {
        var result: [String: RepoInfo] = [:]
        for folder in scan?.folders ?? [] {
            if let repo = folder.repo { result[repo.path] = repo }
            for child in folder.children { result[child.path] = child }
        }
        return result
    }

    /// Suggestions still open: not dismissed, with at least one repo or file the person hasn't kept.
    private var tips: [TidyTip] {
        guard let scan else { return [] }
        return TidyTips.tips(scan: scan, labels: labels, ignored: ignored, root: root).filter { $0.isOpen(dismissed: dismissed) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if scan == nil {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Looking at your folders…").foregroundStyle(.secondary)
                    }
                } else if tips.isEmpty {
                    ContentUnavailableView("Nothing to Tidy", systemImage: "sparkles", description: Text("No copies, second clones, other people's repos or year-old work under \(AgentGuide.abbreviate(root))."))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                } else {
                    ForEach(tips) { tip in card(tip) }
                }
            }
            .padding(18)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: model.outDirectory) { await load() }
        .alert(
            pendingMove.map { "Move \($0.paths.count == 1 ? $0.paths[0] : "\($0.paths.count) items") into \($0.destination)?" } ?? "",
            isPresented: Binding(get: { pendingMove != nil }, set: { if !$0 { pendingMove = nil } }),
            presenting: pendingMove
        ) { move in
            Button("Move") { perform(move) }
            Button("Cancel", role: .cancel) {}
        } message: { move in
            Text("\(move.paths.joined(separator: ", ")) will move into \(AgentGuide.abbreviate((root as NSString).appendingPathComponent(move.destination))). Editors or terminals open in \(move.paths.count == 1 ? "it" : "them") will lose track. You can undo the move here, and the next rebuild picks up the new place.")
        }
        .alert(
            trashing.map { "Move \($0.paths.count == 1 ? ($0.paths[0] as NSString).lastPathComponent : "\($0.paths.count) items") to the Trash?" } ?? "",
            isPresented: Binding(get: { trashing != nil }, set: { if !$0 { trashing = nil } }),
            presenting: trashing
        ) { item in
            Button("Move to Trash", role: .destructive) { trash(item.paths) }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text(item.paths.joined(separator: "\n") + "\n\n" + item.note + " You can put it back from the Trash, or with Put Back here.")
        }
        .alert(
            removingWorktree.map { "Remove the worktree \(($0.path as NSString).lastPathComponent)?" } ?? "",
            isPresented: Binding(get: { removingWorktree != nil }, set: { if !$0 { removingWorktree = nil } }),
            presenting: removingWorktree
        ) { worktree in
            Button("Remove Worktree", role: .destructive) { remove(worktree) }
            Button("Cancel", role: .cancel) {}
        } message: { worktree in
            Text("git removes the folder \(worktree.path). Its branch\(worktree.branch.map { " \($0)" } ?? "") and every commit stay in \(worktree.main), so nothing is lost.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tidy up").font(.headline)
                Text(tips.isEmpty ? "" : "\(tips.count) suggestion\(tips.count == 1 ? "" : "s"). Nothing is deleted until you confirm it, and a repo only when nothing in it would be lost.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !dismissed.isEmpty {
                    Button("Show Dismissed") { dismissedRaw = "" }.buttonStyle(.link).font(.caption)
                }
            }
            if let message {
                HStack(spacing: 8) {
                    Text(message).font(.caption).foregroundStyle(Palette.gold).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if needsRebuild { Button("Open Build", action: openBuild).buttonStyle(SoftButtonStyle()) }
                }
            }
            if !trashed.isEmpty {
                HStack {
                    Label("Moved \(trashed.map { $0.original.lastPathComponent }.joined(separator: ", ")) to the Trash", systemImage: "trash").font(.caption)
                    Spacer()
                    Button("Put Back") { putBack() }.buttonStyle(SoftButtonStyle())
                }
                .modifier(RowCard())
            }
            if let last = model.lastFolderMove {
                HStack {
                    Label("Moved \(last.from) to \(last.to)", systemImage: "arrow.turn.down.right").font(.caption)
                    Spacer()
                    Button("Undo Move") {
                        Task {
                            message = await model.undoLastMove().map { "Couldn't undo: \($0)" } ?? "Moved \(last.to) back to \(last.from)."
                            await load()
                        }
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                .modifier(RowCard())
            }
        }
    }

    // MARK: - Cards

    private func card(_ tip: TidyTip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: tip.symbol).foregroundStyle(Palette.gold).frame(width: 20).padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tip.title).font(.callout.weight(.medium))
                    Text(tip.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if case .plain = tip.subject, let action = tip.action { actionControl(action) }
                Button("Dismiss", systemImage: "xmark") { dismiss(tip.id) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Dismiss this suggestion")
            }
            switch tip.subject {
            case .plain:
                EmptyView()
            case .copies(let map):
                copiesBody(map)
            case .clones(let paths, let remote):
                clonesBody(paths, remote: remote, tipID: tip.id)
            case .notYours:
                ForEach(openPaths(tip), id: \.self) { path in notYoursRow(path) }
            case .stale(_, let topLevel):
                ForEach(openPaths(tip), id: \.self) { path in staleRow(path, topLevel: topLevel) }
            }
        }
        .modifier(RowCard())
    }

    /// Loose files beside their copy in a project: identical ones can go, different ones need a look.
    private func copiesBody(_ map: [String: String]) -> some View {
        let files = map.keys.sorted()
        let identical = files.filter { copies[$0] == .identical }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(files, id: \.self) { file in
                let copy = map[file] ?? ""
                switch copies[file] {
                case .identical:
                    verdictRow(.remove, file, "The same, byte for byte, as \(copy). Keep that one, inside its project.")
                case .differs(let looseIsNewer):
                    verdictRow(.decide, file, "Differs from \(copy). The \(looseIsNewer ? "loose one" : "project's copy") was changed last, so check before keeping one.") {
                        Button("Show Both") { reveal([file, copy]) }.buttonStyle(SoftButtonStyle())
                    }
                case .missing:
                    verdictRow(.decide, file, "Its copy \(copy) is gone.")
                case nil:
                    verdictRow(.checking, file, "Comparing with \(copy)…")
                }
            }
            if !identical.isEmpty {
                HStack {
                    Spacer()
                    Button("Show in Finder") { reveal(identical) }.buttonStyle(SoftButtonStyle())
                    Button("Move \(identical.count == 1 ? "It" : "\(identical.count) Copies") to Trash") {
                        trashing = Trashing(paths: identical, note: "\(identical.count == 1 ? "It's" : "Each is") identical to the copy inside its project, which stays.")
                    }
                    .buttonStyle(GoldButtonStyle())
                }
            }
        }
    }

    /// The clone to keep, and what can happen to each other one.
    private func clonesBody(_ paths: [String], remote: String, tipID: String) -> some View {
        let name = TidyAdvice.repoName(fromRemote: remote)
        let facts = paths.compactMap { path in checks[path].map { CloneFacts(path: path, check: $0, remoteName: name, isInGraph: isInGraph(path)) } }
        let keeper = facts.count == paths.count ? TidyAdvice.keeper(of: facts) : nil
        return VStack(alignment: .leading, spacing: 6) {
            if let keeper {
                verdictRow(.keep, keeper.path, keeper.reasons.isEmpty ? "The one to keep." : "Keep this one: \(keeper.reasons.joined(separator: ", ")).")
                ForEach(facts.filter { $0.path != keeper.path }, id: \.path) { clone in
                    removalRow(clone.path, check: clone.check, why: TidyAdvice.whyNot(clone), keepTitle: "Keep Both") { dismiss(tipID) }
                }
            } else {
                ForEach(paths, id: \.self) { path in verdictRow(.checking, path, "Asking git what's in it…") }
            }
        }
    }

    /// Someone else's repo: does the person still need it?
    private func notYoursRow(_ path: String) -> some View {
        let repo = repos[path]
        var facts: [String] = []
        if let owner = repo?.remoteOwner { facts.append("From \(owner)") }
        if let active = repo?.lastActive { facts.append("last touched \(TidyAdvice.shortDate(active))") }
        let why = "Do you still need it?" + (facts.isEmpty ? "" : " " + facts.joined(separator: ", ") + ".")
        return removalRow(path, check: checks[path], why: why, keepTitle: "I Use It")
    }

    /// Work untouched for a year: archive it, or delete it when it's all safe on a remote.
    private func staleRow(_ path: String, topLevel: Bool) -> some View {
        let active = scan?.folders.first { $0.path == path }?.lastActive ?? repos[path]?.lastActive
        let why = "Untouched since \(active.map(TidyAdvice.shortDate) ?? "over a year ago")."
        return removalRow(path, check: repos[path] == nil ? nil : checks[path], why: why, archives: topLevel)
    }

    /// A repo that could go: what deleting it would lose, and the ways to deal with it.
    /// `keep` is what keeping it does: by default, stop suggesting this one repo.
    private func removalRow(_ path: String, check: RepoCheck?, why: String, keepTitle: String = "Keep It", archives: Bool = false, keep: (() -> Void)? = nil) -> some View {
        let isRepo = repos[path] != nil
        let detail: String
        let kind: VerdictKind
        if !isRepo {
            kind = .decide
            detail = why + " It's a folder, not a repo, so it isn't offered for deletion."
        } else if let check {
            kind = check.canDelete ? .remove : .decide
            detail = why + " " + (check.canDelete
                ? (check.isWorktree ? "Nothing uncommitted, so removing it loses nothing." : "Everything is committed and pushed, so deleting it loses nothing.")
                : "Not safe to delete: \(check.losses.joined(separator: ", ")).")
        } else {
            kind = .checking
            detail = why + " Asking git what's in it…"
        }
        return verdictRow(kind, path, detail) {
            HStack(spacing: 6) {
                Button(keepTitle) { if let keep { keep() } else { dismiss("keep:" + path) } }
                    .buttonStyle(SoftButtonStyle())
                    .help("Keep it as it is, and stop suggesting it")
                if archives {
                    Button("Archive") { Task { await archive(path) } }
                        .buttonStyle(SoftButtonStyle())
                        .help("Label it Archive: it stays on disk, out of the graph")
                } else if isInGraph(path) {
                    Button("Leave Out") { leaveOut([path]) }
                        .buttonStyle(SoftButtonStyle())
                        .help("Keep it on disk, out of the graph")
                }
                if let check, check.canDelete, isRepo {
                    if check.isWorktree, let main = repos[path]?.worktreeOf {
                        Button("Remove Worktree") { removingWorktree = Worktree(path: path, main: main, branch: check.branch) }
                            .buttonStyle(GoldButtonStyle())
                    } else {
                        Button("Move to Trash") {
                            let remote = repos[path]?.remote.map { " It can be cloned again from \($0)." } ?? ""
                            trashing = Trashing(paths: [path], note: "Everything in it is committed and pushed.\(remote)")
                        }
                        .buttonStyle(GoldButtonStyle())
                    }
                }
            }
        }
    }

    private enum VerdictKind {
        case keep, remove, decide, checking

        var symbol: String {
            switch self {
            case .keep: return "checkmark.circle.fill"
            case .remove: return "trash.circle.fill"
            case .decide: return "questionmark.circle.fill"
            case .checking: return "ellipsis.circle"
            }
        }

        var colour: Color {
            switch self {
            case .keep: return Palette.jade
            case .remove: return Palette.coral
            case .decide: return Palette.gold
            case .checking: return .secondary
            }
        }
    }

    private func verdictRow(_ kind: VerdictKind, _ path: String, _ detail: String) -> some View {
        verdictRow(kind, path, detail) { EmptyView() }
    }

    private func verdictRow<Actions: View>(_ kind: VerdictKind, _ path: String, _ detail: String, @ViewBuilder actions: () -> Actions) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: kind.symbol).foregroundStyle(kind.colour).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(path).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            actions()
        }
        .padding(.leading, 30)
    }

    @ViewBuilder
    private func actionControl(_ action: TidyTip.Action) -> some View {
        switch action {
        case .label(let path, let purpose):
            Button("Label \(purpose.title)") { Task { await relabel(path, as: purpose) } }
                .buttonStyle(SoftButtonStyle())
        case .move(let paths, let destinations):
            Menu("Move To") {
                ForEach(Array(Set(destinations)).sorted(by: { a, b in destinations.firstIndex(of: a)! < destinations.firstIndex(of: b)! }), id: \.self) { destination in
                    Button(destination + "/") { pendingMove = PendingMove(paths: paths, destination: destination) }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        case .reveal(let paths):
            Button("Show in Finder") { reveal(paths) }.buttonStyle(SoftButtonStyle())
        case .leaveOut(let paths):
            Button("Leave Out") { leaveOut(paths) }.buttonStyle(SoftButtonStyle())
        }
    }

    // MARK: - What a tip names

    private func openPaths(_ tip: TidyTip) -> [String] { tip.openPaths(dismissed: dismissed) }

    private func isInGraph(_ path: String) -> Bool {
        let top = String(path.split(separator: "/").first ?? Substring(path))
        if labels.first(where: { $0.path == top })?.isIncluded == false { return false }
        return !ignored.contains(FolderIgnore.line(for: path))
    }

    private func absolute(_ path: String) -> String { (root as NSString).appendingPathComponent(path) }

    // MARK: - Actions

    private func dismiss(_ id: String) {
        dismissedRaw = dismissed.union([id]).sorted().joined(separator: "\n")
    }

    private func reveal(_ paths: [String]) {
        NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: absolute($0)) })
    }

    private func leaveOut(_ paths: [String]) {
        if let failure = model.leaveOut(paths) {
            message = "Couldn't change .graphifyignore: \(failure)"
        } else {
            message = "Left out \(paths.joined(separator: ", ")). Rebuild with Allow a Smaller Graph on to take \(paths.count == 1 ? "it" : "them") out."
            needsRebuild = true
            ignored = model.ignoredPatterns()
        }
    }

    /// Labels a main folder, and saves the labels straight away: a tidy-up is one decision.
    private func relabel(_ path: String, as purpose: FolderPurpose) async {
        let kinds = model.folderMap()?.kinds ?? FolderPurpose.defaults
        guard let index = labels.firstIndex(where: { $0.path == path }), kinds.contains(where: { $0.id == purpose.id }) else {
            message = "\(purpose.title) isn't one of your labels any more. Add it back in Arrange › Labels."
            return
        }
        var updated = labels
        updated[index].purpose = kinds.resolve(purpose)
        updated[index].isIncluded = !updated[index].purpose.isLeftOutByDefault
        if let failure = await model.saveFolders(updated) {
            message = failure
        } else {
            message = "Labelled \(path) \(updated[index].purpose.title)."
            needsRebuild = !updated[index].isIncluded
            await load()
        }
    }

    /// Archive is the label that leaves old work out. Without one, the folder is left out instead.
    private func archive(_ path: String) async {
        let kinds = model.folderMap()?.kinds ?? FolderPurpose.defaults
        if let archive = kinds.first(where: { $0.id == FolderPurpose.archive.id }) ?? kinds.first(where: \.isLeftOutByDefault) {
            await relabel(path, as: archive)
        } else {
            leaveOut([path])
        }
    }

    private func trash(_ paths: [String]) {
        var moved: [(original: URL, inTrash: URL)] = []
        for path in paths {
            let url = URL(fileURLWithPath: absolute(path))
            var result: NSURL?
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: &result)
                if let result { moved.append((url, result as URL)) }
            } catch {
                message = "Couldn't move \(path) to the Trash: \(error.localizedDescription)"
                break
            }
        }
        guard !moved.isEmpty else { return }
        trashed = moved
        let inGraph = paths.filter(isInGraph)
        message = "Moved \(moved.map { $0.original.lastPathComponent }.joined(separator: ", ")) to the Trash." + (inGraph.isEmpty ? "" : " Rebuild to take \(inGraph.count == 1 ? "it" : "them") out of the graph.")
        needsRebuild = !inGraph.isEmpty
        Task { await load() }
    }

    private func putBack() {
        for item in trashed {
            do {
                try FileManager.default.moveItem(at: item.inTrash, to: item.original)
            } catch {
                message = "Couldn't put back \(item.original.lastPathComponent): \(error.localizedDescription)"
                return
            }
        }
        message = "Put back \(trashed.map { $0.original.lastPathComponent }.joined(separator: ", "))."
        trashed = []
        Task { await load() }
    }

    private func remove(_ worktree: Worktree) {
        let main = worktree.main.hasPrefix("/") ? worktree.main : absolute(worktree.main)
        let result = try? ProcessRunner.run("/usr/bin/git", ["-C", main, "worktree", "remove", absolute(worktree.path)], timeout: 60)
        if result?.status == 0 {
            message = "Removed the worktree \(worktree.path). Its branch stays in \(worktree.main)."
            needsRebuild = isInGraph(worktree.path)
        } else {
            message = "git couldn't remove \(worktree.path): \(result?.errors.trimmingCharacters(in: .whitespacesAndNewlines) ?? "it didn't run")"
        }
        Task { await load() }
    }

    private func perform(_ move: PendingMove) {
        Task {
            if let failure = await model.move(move.paths, into: move.destination) {
                message = "Couldn't move: \(failure)"
            } else {
                message = "Moved \(move.paths.joined(separator: ", ")) into \(move.destination). Rebuild to update the graph."
            }
            await load()
        }
    }

    // MARK: - Loading

    private func load() async {
        let result = await model.scanFolders()
        labels = FolderScan.labels(saved: model.folderMap(), scan: result)
        ignored = model.ignoredPatterns()
        scan = result
        await checkSubjects()
    }

    /// Asks git about every repo the suggestions name, and compares every loose copy, off the main thread.
    private func checkSubjects() async {
        let root = root
        let known = repos
        var repoPaths: Set<String> = []
        var copyPairs: [String: String] = [:]
        for tip in TidyTips.tips(scan: scan ?? FolderScanResult(), labels: labels, ignored: ignored, root: root) {
            switch tip.subject {
            case .plain: break
            case .copies(let map): copyPairs.merge(map) { first, _ in first }
            case .clones(let paths, _), .notYours(let paths), .stale(let paths, _):
                repoPaths.formUnion(paths.filter { known[$0] != nil })
            }
        }
        let worktrees = Set(repoPaths.filter { known[$0]?.worktreeOf != nil })
        let found: ([String: RepoCheck], [String: TidyAdvice.CopyVerdict]) = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var checks: [String: RepoCheck] = [:]
                for path in repoPaths {
                    checks[path] = RepoCheck.run((root as NSString).appendingPathComponent(path), isWorktree: worktrees.contains(path))
                }
                var verdicts: [String: TidyAdvice.CopyVerdict] = [:]
                for (file, copy) in copyPairs {
                    verdicts[file] = TidyAdvice.compare(loose: (root as NSString).appendingPathComponent(file), copy: (root as NSString).appendingPathComponent(copy))
                }
                continuation.resume(returning: (checks, verdicts))
            }
        }
        checks = found.0
        copies = found.1
    }
}

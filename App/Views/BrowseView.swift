import AppKit
import SwiftUI

enum Editor {
    /// Opens at the line when VS Code is installed, otherwise in the file's default app.
    static func open(path: String, location: String?) {
        let line = EditorLink.line(from: location)
        if let url = EditorLink.vscodeURL(path: path, line: line),
           NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }
}

/// Browse: every node in the graph as an outline to search, open and show on the map, and the
/// pointers that carry the owner's playbook into each repo for cloud agents. It lives in Folders,
/// which owns its search box and the switch between the graph and the repos.
struct BrowseView: View {
    @Binding var query: String
    @Binding var showsInspector: Bool
    /// Lists the repos to tick for pointers, instead of the graph.
    @Binding var showsPointers: Bool

    private struct Row: Identifiable {
        let item: OutlineItem
        let depth: Int
        var id: String { item.id }
    }

    /// Writing or removing pointers, waiting for the person to confirm.
    private struct PointerChange: Identifiable {
        let removes: Bool
        let repos: [PointerRepo]
        var id: String { "\(removes)|" + repos.map(\.path).joined(separator: ",") }
    }

    @Environment(AppModel.self) private var model
    @Environment(\.showOnMap) private var showOnMap

    @State private var results: [OutlineItem] = []
    @State private var isSearching = false
    @State private var roots: [OutlineItem] = []
    @State private var children: [String: [OutlineItem]] = [:]
    @State private var expanded = Set<String>()
    @State private var selection: String?
    @State private var inspected: OutlineItem?
    /// The symbol in the details, which can move along its links.
    @State private var inspectedNode: String?

    @State private var pointers: [PointerRepo] = []
    @State private var picks: Set<String> = []
    /// `-browseRepo personal/app` selects a repo at launch, for screenshots.
    @State private var pickedRepo: String? = UserDefaults.standard.string(forKey: "browseRepo")
    @State private var change: PointerChange?
    @State private var message: String?

    private var isQuerying: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    private var outlineRows: [Row] {
        var rows: [Row] = []
        func add(_ items: [OutlineItem], depth: Int) {
            for item in items {
                rows.append(Row(item: item, depth: depth))
                if expanded.contains(item.id), let nested = children[item.id] {
                    add(nested, depth: depth + 1)
                }
            }
        }
        add(roots, depth: 0)
        return rows
    }

    private var visibleRows: [Row] {
        isQuerying ? results.map { Row(item: $0, depth: 0) } : outlineRows
    }

    private func pointer(_ path: String) -> PointerRepo? { pointers.first { $0.path == path } }

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if showsPointers { pointerList } else { outline }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showsInspector {
                Rectangle().fill(Palette.hairline).frame(width: 1)
                details.frame(width: 340)
            }
        }
        .onChange(of: selection) { _, newValue in
            guard let newValue, let item = visibleRows.first(where: { $0.id == newValue })?.item else { return }
            inspected = item
            if case .symbol(let id, _, _) = item.kind { inspectedNode = id } else { inspectedNode = nil }
        }
        .task(id: query) {
            guard isQuerying else {
                results = []
                return
            }
            isSearching = true
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let found = await model.search(query)
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
        .task(id: model.revision) {
            roots = await model.outlineChildren(of: nil)
            var refreshed: [String: [OutlineItem]] = [:]
            for row in outlineRowsForReload where expanded.contains(row.id) {
                refreshed[row.id] = await model.outlineChildren(of: row)
            }
            children = refreshed
        }
        .task(id: model.settingsRevision) { pointers = await model.pointerRepos() }
        .alert(changeTitle, isPresented: Binding(get: { change != nil }, set: { if !$0 { change = nil } }), presenting: change) { change in
            Button(change.removes ? "Remove Them" : "Write Them") { apply(change) }
            Button("Cancel", role: .cancel) {}
        } message: { change in
            Text(changeDetail(change))
        }
    }

    // MARK: - The graph

    private var outline: some View {
        List(visibleRows, selection: $selection) { row in
            OutlineRow(
                item: row.item,
                depth: isQuerying ? 0 : row.depth,
                showsDisclosure: !isQuerying && row.item.isExpandable,
                isExpanded: expanded.contains(row.id),
                pointer: projectPath(row.item).flatMap(pointer)
            ) {
                toggle(row.item)
            }
            .tag(row.id)
            .contextMenu {
                if let showOnMap, canShowOnMap(row.item) {
                    Button("Show on Map") { showOnMap(row.item.kind) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if isQuerying && results.isEmpty && !isSearching {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func projectPath(_ item: OutlineItem) -> String? {
        if case .project(let name) = item.kind { return name }
        return nil
    }

    /// Nodes with no source file have no project, so they're on no level of the map.
    private func canShowOnMap(_ item: OutlineItem) -> Bool {
        switch item.kind {
        case .project(let name), .community(let name, _), .file(let name, _, _): return name != SourcePath.noProject
        case .symbol: return true
        }
    }

    @ViewBuilder
    private var details: some View {
        if showsPointers {
            if let repo = pickedRepo.flatMap(pointer) {
                PointerInspector(repo: repo, inGraph: roots.contains { projectPath($0) == repo.path }) { removes in
                    change = PointerChange(removes: removes, repos: [repo])
                }
            } else {
                ContentUnavailableView("No Repo Selected", systemImage: "doc.text", description: Text("Select a repo to see the exact block it gets."))
            }
        } else if let inspectedNode {
            VStack(spacing: 0) {
                mapBar(.symbol(id: inspectedNode, path: "", location: nil))
                NodeInspector(nodeID: inspectedNode) { self.inspectedNode = $0 }
            }
        } else if let inspected {
            switch inspected.kind {
            case .project(let name):
                ProjectInspector(item: inspected, pointer: pointer(name), change: { removes in
                    if let repo = pointer(name) { change = PointerChange(removes: removes, repos: [repo]) }
                })
            case .file:
                VStack(spacing: 0) {
                    mapBar(inspected.kind)
                    FileInspector(item: inspected)
                }
            case .community, .symbol:
                VStack(alignment: .leading, spacing: 8) {
                    mapBar(inspected.kind)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(inspected.title).font(.headline)
                        Text("\(inspected.count.formatted()) \(inspected.count == 1 ? "node" : "nodes")").foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    Spacer()
                }
            }
        } else {
            ContentUnavailableView("Nothing Selected", systemImage: "scope", description: Text("Select a project, file or symbol to see it here."))
        }
    }

    /// The details' top row: where the item is on the map.
    @ViewBuilder
    private func mapBar(_ kind: OutlineItem.Kind) -> some View {
        if let showOnMap, canShowOnMap(OutlineItem(kind: kind, title: "", subtitle: "", count: 0, hiddenCount: 0)) {
            HStack {
                Spacer()
                Button("Show on Map", systemImage: "scope") { showOnMap(kind) }
                    .buttonStyle(SoftButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
        }
    }

    // MARK: - Pointers

    /// Repos by the main folder they sit in: top-level repos together, then each group's.
    private var pointerGroups: [(folder: String, repos: [PointerRepo])] {
        var order: [String] = []
        var byFolder: [String: [PointerRepo]] = [:]
        for repo in pointers {
            let folder = repo.path.contains("/") ? String(repo.path.split(separator: "/")[0]) : ""
            if byFolder[folder] == nil { order.append(folder) }
            byFolder[folder, default: []].append(repo)
        }
        return order.sorted { ($0.isEmpty ? 0 : 1, $0) < ($1.isEmpty ? 0 : 1, $1) }.map { ($0, byFolder[$0] ?? []) }
    }

    private var pointerList: some View {
        let outdated = pointers.filter { $0.status == .outdated }.map(\.path)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Your playbook, in each repo's AGENTS.md, for cloud agents that never see this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Select All") { picks = Set(pointers.map(\.path)) }
                    .disabled(picks.count == pointers.count)
                if !outdated.isEmpty {
                    Button("Out of Date (\(outdated.count))") { picks = Set(outdated) }
                        .help("Select the pointers written from an older playbook")
                }
                Button("None") { picks = [] }.disabled(picks.isEmpty)
            }
            .buttonStyle(SoftButtonStyle())
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Rectangle().fill(Palette.hairline).frame(height: 1)
            List(selection: $pickedRepo) {
                ForEach(pointerGroups, id: \.folder) { group in
                    Section {
                        ForEach(group.repos) { repo in
                            pointerRow(repo).tag(repo.path)
                        }
                    } header: {
                        pointerGroupHeader(group.folder, repos: group.repos)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(spacing: 8) {
                if let message {
                    Text(message).font(.caption).foregroundStyle(Palette.gold).lineLimit(2)
                } else {
                    Text("Nothing is committed or pushed. The files change in each repo's folder.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                let removable = pointers.filter { picks.contains($0.path) && $0.status != .none }
                Button("Remove (\(removable.count))") { change = PointerChange(removes: true, repos: removable) }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(removable.isEmpty)
                Button("Add or Update (\(picks.count))") {
                    change = PointerChange(removes: false, repos: pointers.filter { picks.contains($0.path) })
                }
                .buttonStyle(GoldButtonStyle())
                .disabled(picks.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func pointerGroupHeader(_ folder: String, repos: [PointerRepo]) -> some View {
        let all = Set(repos.map(\.path))
        let isAll = all.isSubset(of: picks)
        return HStack(spacing: 8) {
            Text(folder.isEmpty ? "Top level" : folder + "/").font(.caption.weight(.semibold))
            if repos.contains(where: \.isShared) {
                Label("Shared with others", systemImage: "person.2").font(.caption2).foregroundStyle(Palette.gold)
                    .help("Other people can read these repos, so they'll see the block too")
            }
            Spacer()
            Button(isAll ? "Deselect All" : "Select All") {
                if isAll { picks.subtract(all) } else { picks.formUnion(all) }
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }

    private func pointerRow(_ repo: PointerRepo) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { picks.contains(repo.path) },
                set: { if $0 { picks.insert(repo.path) } else { picks.remove(repo.path) } }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            Text(repo.name).lineLimit(1)
            Text(repo.file).font(.caption.monospaced()).foregroundStyle(.tertiary)
            Spacer(minLength: 8)
            PointerStatusLabel(status: repo.status)
        }
    }

    private var changeTitle: String {
        guard let change else { return "" }
        let count = change.repos.count == 1 ? change.repos[0].name : "\(change.repos.count) repos"
        return change.removes ? "Remove the pointer from \(count)?" : "Add or update the pointer in \(count)?"
    }

    private func changeDetail(_ change: PointerChange) -> String {
        var text = change.repos.map { "\($0.path)/\($0.file)" }.joined(separator: "\n")
        let shared = change.repos.filter(\.isShared)
        if !change.removes, !shared.isEmpty {
            text += "\n\n\(shared.count == 1 ? shared[0].name + " is" : "\(shared.count) of them are") in a folder other people can read, so they'll see your picks once it's committed."
        }
        if !change.removes { text += "\n\nThe files change in each repo's folder. Nothing is committed or pushed." }
        return text
    }

    private func apply(_ change: PointerChange) {
        let paths = change.repos.map(\.path)
        let labels = model.folderMap()?.folders ?? []
        let failure = change.removes ? model.removeRepoPointers(paths) : model.writeRepoPointers(paths, labels: labels)
        let count = paths.count == 1 ? paths[0] : "\(paths.count) repos"
        message = failure ?? (change.removes ? "Removed the pointer from \(count)." : "Wrote the pointer in \(count). Commit it with the repo when you're ready.")
        picks.subtract(paths)
        Task { pointers = await model.pointerRepos() }
    }

    // MARK: - Loading

    /// Everything currently loaded, so a rule change can refresh the counts of expanded rows.
    private var outlineRowsForReload: [OutlineItem] {
        roots + children.values.flatMap { $0 }
    }

    private func toggle(_ item: OutlineItem) {
        if expanded.contains(item.id) {
            expanded.remove(item.id)
            return
        }
        expanded.insert(item.id)
        guard children[item.id] == nil else { return }
        Task {
            children[item.id] = await model.outlineChildren(of: item)
        }
    }
}

/// Whether a repo has the pointer, and whether it's the current one.
private struct PointerStatusLabel: View {
    let status: RepoPointer.Status
    var compact = false

    var body: some View {
        switch status {
        case .current:
            label("Has pointer", "checkmark.circle.fill", Palette.jade)
        case .outdated:
            label("Out of date", "arrow.triangle.2.circlepath", Palette.gold)
        case .none:
            if compact { EmptyView() } else { Text("No pointer").font(.caption).foregroundStyle(.tertiary) }
        }
    }

    @ViewBuilder
    private func label(_ title: String, _ symbol: String, _ colour: Color) -> some View {
        if compact {
            Image(systemName: symbol).font(.caption).foregroundStyle(colour).help("Pointer: \(title.lowercased())")
        } else {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(colour)
        }
    }
}

/// The pointer a repo has, and the exact block it would get.
private struct PointerInspector: View {
    let repo: PointerRepo
    /// Whether the repo is a project in the graph, so it can be shown on the map.
    let inGraph: Bool
    let change: (_ removes: Bool) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.showOnMap) private var showOnMap

    private var absolute: String { (model.graphRoot as NSString).appendingPathComponent(repo.path) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(repo.name).font(.headline)
                Text(repo.path).font(.callout).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                if let showOnMap, inGraph {
                    Button("Show on Map", systemImage: "scope") { showOnMap(.project(repo.path)) }
                }
                Button("Show in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: absolute)])
                }
            }
            .buttonStyle(SoftButtonStyle())
            PointerSection(repo: repo, change: change)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A repo's pointer: what it has, where it goes, the block, and the buttons for this one repo.
private struct PointerSection: View {
    let repo: PointerRepo
    let change: (_ removes: Bool) -> Void

    private var verdict: String {
        switch repo.status {
        case .current: return "\(repo.file) has this block. Nothing to change."
        case .outdated: return "\(repo.file) has an older block. Updating replaces it with this one."
        case .none: return "\(repo.file) gets this block at the end\(repo.file == "AGENTS.md" ? ", and is made if it isn't there" : "")."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pointer for cloud agents").font(.callout.weight(.medium))
                Spacer()
                PointerStatusLabel(status: repo.status)
            }
            Text(verdict).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if repo.isShared {
                Label("Other people can read this repo, so they'll see the block once it's committed.", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(Palette.gold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                Text(repo.block)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 220)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 6) {
                Spacer()
                if repo.status != .none {
                    Button("Remove") { change(true) }.buttonStyle(SoftButtonStyle())
                }
                Button(repo.status == .none ? "Add" : "Update") { change(false) }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(repo.status == .current)
            }
        }
    }
}

/// A project: its size, where it is, and its repo's pointer.
private struct ProjectInspector: View {
    let item: OutlineItem
    let pointer: PointerRepo?
    let change: (_ removes: Bool) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.showOnMap) private var showOnMap

    private var name: String {
        if case .project(let name) = item.kind { return name }
        return item.title
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.headline).textSelection(.enabled)
                    Text("\(item.count.formatted()) \(item.count == 1 ? "node" : "nodes")\(item.hiddenCount > 0 ? ", \(item.hiddenCount.formatted()) hidden" : "")")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if name != SourcePath.noProject {
                    HStack(spacing: 6) {
                        if let showOnMap { Button("Show on Map", systemImage: "scope") { showOnMap(item.kind) } }
                        let folder = (model.graphRoot as NSString).appendingPathComponent(name)
                        if FileManager.default.fileExists(atPath: folder) {
                            Button("Show in Finder", systemImage: "folder") {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folder)])
                            }
                        }
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                Rectangle().fill(Palette.hairline).frame(height: 1)
                if let pointer {
                    PointerSection(repo: pointer, change: change)
                } else {
                    Text(name == SourcePath.noProject
                         ? "Nodes with no source file. They're on no level of the map."
                         : "No pointer: this project isn't a repo of its own, or its folder is labelled to stay out of the graph.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct OutlineRow: View {
    let item: OutlineItem
    let depth: Int
    let showsDisclosure: Bool
    let isExpanded: Bool
    var pointer: PointerRepo?
    let toggle: () -> Void

    private var symbol: String {
        switch item.kind {
        case .project: return "folder"
        case .community: return "circle.hexagongrid"
        case .file: return "doc.text"
        case .symbol: return "function"
        }
    }

    private var countText: String {
        if case .symbol = item.kind { return "\(item.count.formatted()) \(item.count == 1 ? "link" : "links")" }
        return item.count.formatted()
    }

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if showsDisclosure {
                    Button(action: toggle) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .font(.caption)
                            .frame(width: 14, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
                } else {
                    Color.clear.frame(width: 14, height: 14)
                }
            }
            Image(systemName: item.isHidden ? "eye.slash" : symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).lineLimit(1)
                if !item.subtitle.isEmpty, item.subtitle != item.title {
                    Text(item.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            if item.hiddenCount > 0 && !item.isHidden {
                Text("\(item.hiddenCount.formatted()) hidden")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            Text(countText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if let pointer {
                PointerStatusLabel(status: pointer.status, compact: true).frame(width: 14)
            }
        }
        .padding(.leading, CGFloat(depth) * 16)
        .opacity(item.isHidden ? 0.55 : 1)
    }
}

private struct FileInspector: View {
    let item: OutlineItem
    @Environment(AppModel.self) private var model

    private var path: String {
        if case .file(_, _, let path) = item.kind { return path }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title).font(.headline).textSelection(.enabled)
            Text(path).foregroundStyle(.secondary).textSelection(.enabled)
            Text("\(item.count.formatted()) \(item.count == 1 ? "node" : "nodes") in this community")
                .foregroundStyle(.secondary)
            if let absolute = GraphSource(outDirectory: model.outDirectory).existingPath(for: path), !path.isEmpty {
                Button("Open in Editor", systemImage: "arrow.up.forward.app") {
                    Editor.open(path: absolute, location: nil)
                }
            } else {
                Text("This file no longer exists.").foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NodeInspector: View {
    let nodeID: String
    let navigate: (String) -> Void

    @Environment(AppModel.self) private var model
    @State private var detail: NodeDetail?

    var body: some View {
        Group {
            if let detail {
                content(detail)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: "\(nodeID)|\(model.revision)") {
            detail = await model.nodeDetail(id: nodeID)
        }
    }

    private func content(_ detail: NodeDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.label).font(.headline).textSelection(.enabled)
                Text(detail.path.isEmpty ? "No source file" : detail.path + (detail.location.map { " " + $0 } ?? ""))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text([detail.project, detail.fileType, detail.communityLabel].compactMap { $0 }.joined(separator: " · "))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if detail.isHidden {
                    Label(detail.hidingRuleSummary ?? "Hidden", systemImage: "eye.slash")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                HStack {
                    if let absolute = detail.absolutePath {
                        Button("Open in Editor", systemImage: "arrow.up.forward.app") {
                            Editor.open(path: absolute, location: detail.location)
                        }
                    }
                    if !detail.path.isEmpty {
                        Button("Copy Path", systemImage: "doc.on.doc") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(detail.absolutePath ?? detail.path, forType: .string)
                        }
                        .labelStyle(.iconOnly)
                        .help("Copy the file's path")
                    }
                    if detail.isHidden, let rule = detail.hidingRuleID {
                        Button("Undo Rule", systemImage: "arrow.uturn.backward") { model.undo(ruleIDs: [rule]) }
                    } else if !detail.isHidden {
                        Button("Hide", systemImage: "eye.slash") {
                            model.perform([.hideNode(id: detail.id, label: detail.label)])
                        }
                    }
                }
                .padding(.top, 6)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(Palette.hairline).frame(height: 1)

            Text(detail.neighbourTotal > detail.neighbours.count
                ? "Links (showing \(detail.neighbours.count.formatted()) of \(detail.neighbourTotal.formatted()))"
                : "Links (\(detail.neighbourTotal.formatted()))")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            List(detail.neighbours) { neighbour in
                Button { navigate(neighbour.nodeID) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(neighbour.label).lineLimit(1)
                            Text(neighbour.project)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(neighbour.relation).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                            Text(neighbour.confidence.capitalized).font(.callout).foregroundStyle(.tertiary).lineLimit(1)
                        }
                    }
                    .opacity(neighbour.isRemoved ? 0.5 : 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .scrollContentBackground(.hidden)
        }
    }
}

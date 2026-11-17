import AppKit
import SwiftUI

/// Arrange: drag projects into areas and graphs, or leave them out, and say what each main folder
/// is for with the person's own labels. Edits are a draft with its own undo until Save. Arranging
/// never moves files; the chip menu's On Disk section moves and renames folders, each checked and
/// confirmed in a sheet, and undoable.
struct ArrangeView: View {
    @Environment(AppModel.self) private var model
    let openBuild: () -> Void
    let openBackup: () -> Void
    let openTidy: () -> Void

    @State private var saved: Arrangement?
    @State private var draft: Arrangement?
    @State private var history: [Arrangement] = []
    @State private var scan: FolderScanResult?
    @State private var selectedGraph: String?
    @State private var message: String?
    @State private var isSaving = false
    @State private var dropTarget: String?
    @State private var renaming: Renaming?
    @State private var renameText = ""
    @State private var moveSheet: MoveSheetItem?
    @State private var newFolderFor: ArrangeProject?
    @State private var moved: FolderMove?
    @State private var rulesToCarry: [RuleCarry] = []
    @State private var needsRebuild = false
    @State private var showsLabels = false
    /// The area whose folders' notes are open.
    @State private var notesFor: String?
    @AppStorage("dismissedTidyTips") private var dismissedTipsRaw = ""

    private struct Renaming: Identifiable {
        enum Kind { case area, graph }
        let kind: Kind
        let id: String
        var key: String { "\(kind)-\(id)" }
    }

    private var root: String { model.graphRoot }
    private var isDirty: Bool { draft != nil && draft != saved }

    var body: some View {
        Group {
            if let draft {
                HStack(alignment: .top, spacing: 0) {
                    board(draft)
                    Rectangle().fill(Palette.hairline).frame(width: 1)
                    sideColumn(draft)
                        .frame(width: 290)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Looking at your projects…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: model.outDirectory) { await load() }
        .onChange(of: history.count) { updateUndo() }
        .onDisappear { model.panelUndo = nil }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }), presenting: renaming) { item in
            TextField("Name", text: $renameText)
            Button("Rename") {
                change { arrangement in
                    if item.kind == .area { arrangement.renameArea(item.id, to: renameText) } else { arrangement.renameGraph(item.id, to: renameText) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $moveSheet) { item in
            if let saved {
                MoveSheet(start: item.request, arrangement: saved) { result in finishMove(result) }
                    .environment(model)
            }
        }
        .sheet(isPresented: $showsLabels) {
            if let draft {
                LabelsSheet(kinds: draft.kinds, uses: { draft.uses(of: $0) }) { list in
                    if !list.isSame(as: draft.kinds) { change { $0.setKinds(list) } }
                }
            }
        }
        .sheet(item: $newFolderFor) { project in
            NewFolderSheet { folder in
                Task {
                    await load()
                    moveSheet = MoveSheetItem(request: MoveRequest(item: project.path, newParent: folder))
                }
            }
            .environment(model)
        }
    }

    // MARK: - Board

    private func board(_ arrangement: Arrangement) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Arrange your graphs").font(.headline)
                            Label("Arranging never moves files", systemImage: "checkmark.shield")
                                .font(.caption2)
                                .foregroundStyle(Palette.jade)
                        }
                        Text("Drag projects into areas and graphs. Each graph gets its own cut of the map and its own backup. Left out projects aren't built, mapped or backed up; their folders stay on disk.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Picker("Graphs", selection: Binding(
                        get: { arrangement.graphs.count > 1 },
                        set: { split in change { split ? $0.split() : $0.merge() } }
                    )) {
                        Label("One Graph", systemImage: "arrow.triangle.merge").tag(false)
                        Label("Separate Graphs", systemImage: "arrow.triangle.branch").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .help("One graph lets AI tools follow links across everything. Separate graphs keep them apart, each with its own backup.")
                    Button("Labels…", systemImage: "tag") { showsLabels = true }
                        .buttonStyle(SoftButtonStyle())
                        .help("Edit what your main folders can be: names, icons, colours and what AI tools are told")
                }
                if let message {
                    HStack(spacing: 8) {
                        Text(message).font(.caption).foregroundStyle(Palette.gold).fixedSize(horizontal: false, vertical: true)
                        if needsRebuild {
                            Button("Open Build", action: openBuild).buttonStyle(SoftButtonStyle())
                        }
                    }
                }
                if let moved { moveResult(moved) }
                carryCards
                tidyLink(arrangement)
                ForEach(arrangement.graphs) { graph in island(graph, in: arrangement) }
                dropZone(id: "new", title: "Drop an area or a project here to give it a graph of its own", symbol: "plus") { payload in
                    drop(payload, on: .newGraph)
                }
                leftOutTray(arrangement)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Suggestions

    private var dismissedTips: Set<String> { Set(dismissedTipsRaw.split(separator: "\n").map(String.init)) }

    /// Tidy Up's suggestions, as one line: they're about what's on disk, so they live in their own tab.
    @ViewBuilder
    private func tidyLink(_ arrangement: Arrangement) -> some View {
        let tips = (scan.map { TidyTips.tips(scan: $0, labels: arrangement.labels, ignored: arrangement.ignoredLines, root: root) } ?? [])
            .filter { $0.isOpen(dismissed: dismissedTips) }
        if !tips.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(Palette.gold)
                Text("\(tips.count) tidy-up suggestion\(tips.count == 1 ? "" : "s"): \(tips.prefix(2).map(\.title).joined(separator: "; "))\(tips.count > 2 ? "…" : "")")
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Button("Open Tidy Up", action: openTidy).buttonStyle(SoftButtonStyle())
            }
            .modifier(RowCard())
        }
    }

    // MARK: Graphs

    private func island(_ graph: GraphPlan, in arrangement: Arrangement) -> some View {
        let selected = (selectedGraph ?? arrangement.graphs.first?.id) == graph.id
        let isTarget = dropTarget == "graph-" + graph.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(graphColor(graph, in: arrangement)).frame(width: 12, height: 12)
                Text(graph.name).font(.body.weight(.semibold))
                Text("\(arrangement.nodes(inGraph: graph.id).formatted()) nodes · \(arrangement.projects(inGraph: graph.id).count) projects")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if graph.isHome && arrangement.graphs.count > 1 {
                    Text("Home").font(.caption2).foregroundStyle(Palette.gold).help("This graph's backup also carries the playbook.")
                }
                Spacer(minLength: 8)
                destinationBadge(graph)
                Menu {
                    Button("Rename…") { startRename(.graph, graph.id, graph.name) }
                    if arrangement.graphs.count > 1 && !graph.isHome {
                        Button("Make Home") { change { $0.makeHome(graph.id) } }
                    }
                    Menu("Add an Area") {
                        ForEach(arrangement.kinds.filter { !$0.isLeftOutByDefault }) { purpose in
                            Button(purpose.title) { change { $0.addArea(purpose: purpose, toGraph: graph.id) } }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedGraph = graph.id }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10, alignment: .top)], alignment: .leading, spacing: 10) {
                ForEach(graph.areaIDs.compactMap(arrangement.area)) { area in
                    areaBox(area, in: arrangement)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(isTarget ? 0.07 : 0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(selected ? Palette.gold.opacity(0.55) : Color.white.opacity(0.07)))
        .dropDestination(for: String.self) { items, _ in
            items.first.map { drop($0, on: .graph(graph.id)) } ?? false
        } isTargeted: { dropTarget = $0 ? "graph-" + graph.id : (dropTarget == "graph-" + graph.id ? nil : dropTarget) }
    }

    private func destinationBadge(_ graph: GraphPlan) -> some View {
        let plan = graph.backup
        let (symbol, text): (String, String) = switch plan.destination {
        case .github: ("lock.fill", "\(plan.login ?? "?")/\(plan.repo)")
        case .local: ("laptopcomputer", "This Mac only")
        case .none: ("icloud.slash", "Not backed up")
        }
        return Button(action: openBackup) {
            Label(text, systemImage: symbol).font(.caption).lineLimit(1)
        }
        .buttonStyle(ChipStyle(isOn: false))
        .help("Where this graph's backup goes. Opens Back Up.")
    }

    private func areaBox(_ area: AreaInfo, in arrangement: Arrangement) -> some View {
        let projects = arrangement.projects(in: area.id)
        let colour = Palette.series(area.purpose.colorSlot)
        let isTarget = dropTarget == "area-" + area.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal").font(.caption2).foregroundStyle(.tertiary)
                Circle().fill(colour).frame(width: 8, height: 8)
                Text(area.name).font(.callout.weight(.semibold))
                Text("\(projects.count) · \(arrangement.nodes(inArea: area.id).formatted())")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if !area.labelPaths.isEmpty { notesButton(area, in: arrangement) }
                areaMenu(area, in: arrangement)
            }
            .draggable("area:" + area.id) {
                Label(area.name, systemImage: "square.stack.3d.up").padding(6).background(Palette.panel, in: Capsule())
            }
            if projects.isEmpty {
                Text("Drop projects here").font(.caption).foregroundStyle(.tertiary).padding(.vertical, 6)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(projects) { project in chip(project, colour: colour, in: arrangement) }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colour.opacity(isTarget ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(colour.opacity(isTarget ? 0.7 : 0.22)))
        .dropDestination(for: String.self) { items, _ in
            items.first.map { drop($0, on: .area(area.id)) } ?? false
        } isTargeted: { dropTarget = $0 ? "area-" + area.id : (dropTarget == "area-" + area.id ? nil : dropTarget) }
    }

    /// The words AI tools read about this area's folders, and whether each folder inside is a project.
    private func notesButton(_ area: AreaInfo, in arrangement: Arrangement) -> some View {
        let labels = arrangement.labels.filter { area.labelPaths.contains($0.path) }
        let hasNotes = labels.contains { !$0.note.trimmingCharacters(in: .whitespaces).isEmpty }
        return Button {
            notesFor = area.id
        } label: {
            Image(systemName: hasNotes ? "text.bubble.fill" : "text.bubble")
                .foregroundStyle(hasNotes ? Palette.gold : .secondary)
        }
        .buttonStyle(.plain)
        .help(hasNotes ? labels.map(\.note).filter { !$0.isEmpty }.joined(separator: "\n") : "Tell AI tools what \(area.labelPaths.map { $0 + "/" }.joined(separator: " and ")) is for")
        .popover(isPresented: Binding(get: { notesFor == area.id }, set: { if !$0 { notesFor = nil } }), arrowEdge: .bottom) {
            FolderNotesEditor(paths: area.labelPaths, labels: labels) { edits in
                let changed = edits.contains { path, edit in
                    let label = labels.first { $0.path == path }
                    return label?.note != edit.note || label?.holdsProjects != edit.holdsProjects
                }
                guard changed else { return }
                change { arrangement in
                    for (path, edit) in edits {
                        arrangement.setNote(edit.note, forFolder: path)
                        arrangement.setHoldsProjects(edit.holdsProjects, forFolder: path)
                    }
                }
            }
        }
    }

    private func areaMenu(_ area: AreaInfo, in arrangement: Arrangement) -> some View {
        Menu {
            Button("Rename…") { startRename(.area, area.id, area.name) }
            Menu("Purpose") {
                ForEach(arrangement.kinds.filter { !$0.isLeftOutByDefault }) { purpose in
                    Button {
                        change { $0.setPurpose(purpose, ofArea: area.id) }
                    } label: {
                        if purpose == area.purpose { Label(purpose.title, systemImage: "checkmark") } else { Text(purpose.title) }
                    }
                }
            }
            if arrangement.graphs.count > 1 {
                Menu("Move to Graph") {
                    ForEach(arrangement.graphs.filter { !$0.areaIDs.contains(area.id) }) { graph in
                        Button(graph.name) { change { $0.moveArea(area.id, to: .graph(graph.id)) } }
                    }
                }
            }
            Button("Give It a Graph of Its Own") { change { $0.moveArea(area.id, to: .newGraph) } }
            Divider()
            Button("Leave It Out") { change { $0.moveArea(area.id, to: .leftOut) } }
            if area.isMade && arrangement.projects(in: area.id).isEmpty {
                Button("Remove Area") { change { $0.removeArea(area.id) } }
            }
            if !area.labelPaths.isEmpty {
                Divider()
                ForEach(area.labelPaths, id: \.self) { path in
                    Button("Show \(path)/ in Finder") { reveal([path]) }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func chip(_ project: ArrangeProject, colour: Color?, in arrangement: Arrangement) -> some View {
        HStack(spacing: 5) {
            if let colour {
                Circle().fill(colour).frame(width: 7, height: 7)
            } else {
                Circle().strokeBorder(Color.secondary, lineWidth: 1).frame(width: 7, height: 7)
            }
            Text(project.name).font(.caption).lineLimit(1)
            if project.hasOwnCommits == false && colour != nil {
                Text("not yours").font(.caption2).foregroundStyle(Palette.coral).help("You've never committed to it.")
            }
            if let reason = arrangement.leftOutReason(project.path), colour == nil {
                Text(reason).font(.caption2).foregroundStyle(.secondary)
            } else if project.nodes > 0 {
                Text(project.nodes.formatted()).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            } else {
                Text("new").font(.caption2).foregroundStyle(Palette.jade).help("Not in the graph yet. It joins on the next rebuild.")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
        .draggable("project:" + project.path) {
            Text(project.name).font(.caption).padding(.horizontal, 8).padding(.vertical, 4).background(Palette.panel, in: Capsule())
        }
        .contextMenu { chipMenu(project, in: arrangement) }
        .help(AgentGuide.abbreviate((root as NSString).appendingPathComponent(project.path)) + (project.worktreeOf.map { "\nA worktree of \($0)" } ?? ""))
    }

    @ViewBuilder
    private func chipMenu(_ project: ArrangeProject, in arrangement: Arrangement) -> some View {
        let current = arrangement.placement(of: project.path)
        Section("Put \(project.name) In") {
            ForEach(arrangement.graphs) { graph in
                ForEach(graph.areaIDs.compactMap(arrangement.area)) { area in
                    Button {
                        change { _ = $0.put([project.path], in: .area(area.id)) }
                    } label: {
                        let title = arrangement.graphs.count > 1 && graph.name != area.name ? "\(graph.name) › \(area.name)" : area.name
                        if current == .area(area.id) { Label(title, systemImage: "checkmark") } else { Text(title) }
                    }
                }
            }
            Button("A New Graph") { change { _ = $0.put([project.path], in: .newGraph) } }
            Button("Left Out") { change { _ = $0.put([project.path], in: .leftOut) } }
                .disabled(current.isLeftOut)
        }
        Section("On Disk") {
            if isDirty {
                Button("Save the Arrangement to Move Folders") {}
                    .disabled(true)
            } else {
                Button("Rename Folder…") { moveSheet = MoveSheetItem(request: .rename(project.path, to: project.name)) }
                Menu("Move Folder To") {
                    let parent = MoveRequest.parent(of: project.path)
                    ForEach(arrangement.labels.filter { $0.holdsProjects && $0.path != parent && FileManager.default.fileExists(atPath: FolderMoves.absolute($0.path, root: root)) }) { label in
                        Button(label.path + "/") { moveSheet = MoveSheetItem(request: MoveRequest(item: project.path, newParent: label.path)) }
                    }
                    if !parent.isEmpty {
                        Button("The Top Level") { moveSheet = MoveSheetItem(request: MoveRequest(item: project.path, newParent: "")) }
                    }
                    Divider()
                    Button("New Folder…") { newFolderFor = project }
                }
            }
            Button("Show in Finder") { reveal([project.path]) }
        }
    }

    // MARK: Drop zones

    private func dropZone(id: String, title: String, symbol: String, onDrop: @escaping (String) -> Bool) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(dropTarget == id ? Palette.gold : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(dropTarget == id ? 0.06 : 0.015), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(dropTarget == id ? Palette.gold : Color.white.opacity(0.15)))
            .dropDestination(for: String.self) { items, _ in
                items.first.map(onDrop) ?? false
            } isTargeted: { dropTarget = $0 ? id : (dropTarget == id ? nil : dropTarget) }
    }

    private func leftOutTray(_ arrangement: Arrangement) -> some View {
        let projects = arrangement.leftOut
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "archivebox")
                Text("Left out").font(.callout.weight(.semibold))
                Text("Not built, not on the map, not backed up. The folders stay on disk.").font(.caption).foregroundStyle(.secondary)
            }
            if projects.isEmpty {
                Text("Nothing left out").font(.caption).foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(projects) { project in chip(project, colour: nil, in: arrangement) }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(dropTarget == "left" ? 0.06 : 0.02), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(dropTarget == "left" ? Palette.gold.opacity(0.6) : Color.white.opacity(0.07)))
        .dropDestination(for: String.self) { items, _ in
            items.first.map { drop($0, on: .leftOut) } ?? false
        } isTargeted: { dropTarget = $0 ? "left" : (dropTarget == "left" ? nil : dropTarget) }
    }

    // MARK: - Side column

    private func sideColumn(_ arrangement: Arrangement) -> some View {
        let graph = arrangement.graphs.first { $0.id == selectedGraph } ?? arrangement.graphs.first
        let changes = saved.map { arrangement.changes(from: $0) } ?? []
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("How it will look").font(.headline)
                Text("Each graph grows from your folder down to its projects. Bigger orbs hold more code.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if arrangement.graphs.count > 1 {
                        Picker("Graph", selection: Binding(get: { graph?.id ?? "" }, set: { selectedGraph = $0 })) {
                            ForEach(arrangement.graphs) { Text($0.name).tag($0.id) }
                        }
                        .labelsHidden()
                    }
                    if let graph {
                        GraphTreePreview(graph: graph, arrangement: arrangement)
                        legend(graph, in: arrangement)
                    }
                    Text("Changes").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                    if changes.isEmpty {
                        Text("None yet. This is how the graph is built today.").font(.caption).foregroundStyle(.tertiary)
                    } else {
                        ForEach(changes.prefix(8), id: \.self) { line in
                            Text(line).font(.caption).fixedSize(horizontal: false, vertical: true)
                        }
                        if changes.count > 8 { Text("and \(changes.count - 8) more").font(.caption).foregroundStyle(.tertiary) }
                    }
                    Text(arrangement.graphs.count > 1
                         ? "Separate graphs keep AI tools from following links between them. Each is cut from the same build, so splitting costs nothing to build."
                         : "One graph lets AI tools follow links across all your projects. Areas still colour the map.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(spacing: 8) {
                Button("Undo", systemImage: "arrow.uturn.backward") { undo() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(SoftButtonStyle())
                    .disabled(history.isEmpty)
                    .help("Undo (⌘Z)")
                Button("Revert") { revert() }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(!isDirty)
                Spacer(minLength: 4)
                if isSaving { ProgressView().controlSize(.small) }
                Button("Save Arrangement") { Task { await save() } }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(!isDirty || isSaving || model.isRebuilding)
            }
            .padding(12)
        }
    }

    private func legend(_ graph: GraphPlan, in arrangement: Arrangement) -> some View {
        let areas = graph.areaIDs.compactMap(arrangement.area)
        let total = max(1, arrangement.nodes(inGraph: graph.id))
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                HStack(spacing: 1) {
                    ForEach(areas) { area in
                        Rectangle()
                            .fill(Palette.series(area.purpose.colorSlot))
                            .frame(width: max(2, proxy.size.width * CGFloat(arrangement.nodes(inArea: area.id)) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 5)
            .clipShape(Capsule())
            ForEach(areas) { area in
                HStack(spacing: 6) {
                    Circle().fill(Palette.series(area.purpose.colorSlot)).frame(width: 7, height: 7)
                    Text(area.name).font(.caption)
                    Spacer()
                    Text("\(arrangement.projects(in: area.id).count) · \(arrangement.nodes(inArea: area.id).formatted())").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func graphColor(_ graph: GraphPlan, in arrangement: Arrangement) -> Color {
        let areas = graph.areaIDs.compactMap(arrangement.area)
        return areas.count == 1 ? Palette.series(areas[0].purpose.colorSlot) : Palette.gold
    }

    /// Applies a change to the draft, keeping the previous state for undo.
    private func change(_ edit: (inout Arrangement) -> Void) {
        guard var next = draft else { return }
        let before = next
        edit(&next)
        guard next != before else { return }
        history.append(before)
        if history.count > 60 { history.removeFirst() }
        draft = next
        if let selectedGraph, !next.graphs.contains(where: { $0.id == selectedGraph }) { self.selectedGraph = nil }
        message = nil
        needsRebuild = false
    }

    private func drop(_ payload: String, on target: Arrangement.Target) -> Bool {
        if payload.hasPrefix("project:") {
            let path = String(payload.dropFirst("project:".count))
            var refusal: String?
            change { refusal = $0.put([path], in: target) }
            if let refusal { message = refusal }
            return refusal == nil
        }
        if payload.hasPrefix("area:") {
            let id = String(payload.dropFirst("area:".count))
            switch target {
            case .area(let other):
                // An area dropped on another area joins that area's graph.
                guard let graph = draft?.graph(ofArea: other), draft?.graph(ofArea: id)?.id != graph.id else { return false }
                change { $0.moveArea(id, to: .graph(graph.id)) }
            default:
                change { $0.moveArea(id, to: target) }
            }
            return true
        }
        return false
    }

    private func undo() {
        guard let previous = history.popLast() else { return }
        draft = previous
    }

    private func revert() {
        guard let saved else { return }
        history.append(draft ?? saved)
        draft = saved
    }

    private func updateUndo() {
        model.panelUndo = history.isEmpty ? nil : AppModel.PanelUndo(title: "Undo Arrange Change") { undo() }
    }

    private func startRename(_ kind: Renaming.Kind, _ id: String, _ name: String) {
        renameText = name
        renaming = Renaming(kind: kind, id: id)
    }

    private func reveal(_ paths: [String]) {
        NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: (root as NSString).appendingPathComponent($0)) })
    }

    // MARK: - On disk

    private func finishMove(_ result: Result<FolderMove, PlaybookError>) {
        switch result {
        case .success(let move):
            moved = move
            message = nil
            needsRebuild = false
        case .failure(let error):
            message = "Couldn't move: \(error.message)"
        }
        Task { await load() }
    }

    /// What the last move did, with undo and the code rebuild that picks up the new path.
    private func moveResult(_ move: FolderMove) -> some View {
        let fixed = move.fixups?.summary ?? []
        let problems = move.fixups?.problems ?? []
        let isRename = MoveRequest.parent(of: move.from) == MoveRequest.parent(of: move.to)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: problems.isEmpty ? "checkmark.circle" : "exclamationmark.triangle").foregroundStyle(problems.isEmpty ? Palette.jade : Palette.coral).frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(isRename ? "Renamed \((move.from as NSString).lastPathComponent) to \((move.to as NSString).lastPathComponent)" : "Moved \((move.from as NSString).lastPathComponent) to \(MoveRequest.parent(of: move.to).isEmpty ? "the top level" : MoveRequest.parent(of: move.to) + "/")")
                    .font(.callout.weight(.medium))
                Text((fixed.isEmpty ? "" : "Also updated \(fixed.joined(separator: ", ")). ") + "Rebuild code so the graph reads its files under the new path. Its docs come back with the next docs pass, so this rebuild allows a smaller graph.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                ForEach(problems, id: \.self) { Text($0).font(.caption).foregroundStyle(Palette.coral).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 8)
            Button("Undo") {
                Task {
                    if let failure = await model.undoLastMove() {
                        message = "Couldn't undo: \(failure)"
                    } else {
                        message = "Put \((move.to as NSString).lastPathComponent) back at \(move.from)."
                        moved = nil
                    }
                    await load()
                }
            }
            .buttonStyle(SoftButtonStyle())
            .disabled(model.lastFolderMove != move)
            Button("Rebuild Code") {
                model.startRebuild(force: true)
                moved = nil
                openBuild()
            }
            .buttonStyle(GoldButtonStyle())
            .disabled(model.isRebuilding)
            Button("Dismiss", systemImage: "xmark") { moved = nil }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .modifier(RowCard())
    }

    /// Cleanup rules that named a moved folder's old path, once the rebuild has made the new nodes.
    @ViewBuilder
    private var carryCards: some View {
        ForEach(rulesToCarry, id: \.move) { item in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wand.and.stars").foregroundStyle(Palette.gold).frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.rules.count) cleanup rule\(item.rules.count == 1 ? "" : "s") named \(item.move.from)").font(.callout.weight(.medium))
                    Text("The folder is \(item.move.to) now, and the rebuild found the same nodes there. Carrying the rules over hides the same things again; the old rules are withdrawn.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("Carry Over") {
                    model.carryRules(item.rules)
                    rulesToCarry.removeAll { $0.move == item.move }
                }
                .buttonStyle(SoftButtonStyle())
            }
            .modifier(RowCard())
        }
    }

    private func load(keepingDraft: Bool = false) async {
        let result = await model.scanFolders()
        let arrangement = await model.loadArrangement(scan: result)
        scan = result
        saved = arrangement
        rulesToCarry = await model.rulesToCarry()
        if !keepingDraft || draft == nil {
            draft = arrangement
            history = []
        } else if var current = draft {
            // A move changed what's on disk: keep the draft's choices over the new project list.
            current.projects = arrangement.projects
            current.labels = arrangement.labels
            draft = current
        }
    }

    private func save() async {
        guard let draft else { return }
        isSaving = true
        let leavesOut = Set(draft.ignoreChanges.add).subtracting(saved?.ignoreChanges.add ?? [])
        let failure = await model.saveArrangement(draft)
        isSaving = false
        if let failure {
            message = failure
            return
        }
        saved = draft
        history = []
        message = leavesOut.isEmpty ? "Saved. The map follows the new areas." : "Saved. Rebuild with Allow a Smaller Graph for left out projects to leave the graph."
        needsRebuild = !leavesOut.isEmpty
    }
}

/// The mockup's tree: the graph's root at the top, its areas below, and its projects fanned out
/// at the ends, sized by how much code they hold.
struct GraphTreePreview: View {
    let graph: GraphPlan
    let arrangement: Arrangement

    var body: some View {
        Canvas { context, size in
            let areas = graph.areaIDs.compactMap(arrangement.area).filter { !arrangement.projects(in: $0.id).isEmpty }
            let centre = size.width / 2
            let ground: CGFloat = 28
            guard !areas.isEmpty else {
                context.draw(Text("Nothing in this graph yet").font(.caption).foregroundStyle(.secondary), at: CGPoint(x: centre, y: size.height / 2))
                return
            }
            struct Leaf { let area: AreaInfo; let project: ArrangeProject; let weight: CGFloat; var point = CGPoint.zero; var angle: CGFloat = 0; var radius: CGFloat = 2 }
            var leaves: [Leaf] = []
            for area in areas {
                var middle: [ArrangeProject] = []
                for (index, project) in arrangement.projects(in: area.id).enumerated() {
                    if index % 2 == 1 { middle.append(project) } else { middle.insert(project, at: 0) }
                }
                leaves += middle.map { Leaf(area: area, project: $0, weight: sqrt(CGFloat(max($0.nodes, 4))) + 7) }
            }
            let total = leaves.reduce(0) { $0 + $1.weight }
            let start: CGFloat = 0.16
            let end: CGFloat = .pi - 0.16
            var done: CGFloat = 0
            for index in leaves.indices {
                let weight = leaves[index].weight
                let angle = end - (end - start) * ((done + weight / 2) / total)
                done += weight
                let reach: CGFloat = index % 2 == 1 ? 0.8 : 1
                leaves[index].angle = angle
                leaves[index].point = CGPoint(x: centre + cos(angle) * (size.width / 2 - 16) * reach, y: ground + sin(angle) * (size.height - ground - 22) * reach)
                leaves[index].radius = 1.8 + sqrt(CGFloat(leaves[index].project.nodes)) / 12
            }
            context.stroke(Path { $0.move(to: CGPoint(x: 6, y: ground)); $0.addLine(to: CGPoint(x: size.width - 6, y: ground)) }, with: .color(.white.opacity(0.1)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            for area in areas {
                let mine = leaves.filter { $0.area.id == area.id }
                let weights = mine.reduce(0) { $0 + $1.weight }
                let angle = mine.reduce(0) { $0 + $1.angle * $1.weight } / max(weights, 1)
                let anchor = CGPoint(x: centre + cos(angle) * 52, y: ground + 22 + sin(angle) * 74)
                let colour = Palette.series(area.purpose.colorSlot)
                let nodes = CGFloat(arrangement.nodes(inArea: area.id))
                var trunk = Path()
                trunk.move(to: CGPoint(x: centre, y: ground))
                trunk.addCurve(to: anchor, control1: CGPoint(x: centre, y: ground + 30), control2: CGPoint(x: anchor.x, y: anchor.y - 34))
                context.stroke(trunk, with: .color(colour.opacity(0.7)), lineWidth: 1 + sqrt(nodes) / 38)
                for leaf in mine {
                    var branch = Path()
                    branch.move(to: anchor)
                    branch.addCurve(to: leaf.point, control1: CGPoint(x: anchor.x, y: anchor.y + (leaf.point.y - anchor.y) * 0.55), control2: CGPoint(x: leaf.point.x, y: leaf.point.y - (leaf.point.y - anchor.y) * 0.45))
                    context.stroke(branch, with: .color(colour.opacity(0.32)), lineWidth: 0.6 + sqrt(CGFloat(leaf.project.nodes)) / 70)
                    let dot = CGRect(x: leaf.point.x - leaf.radius, y: leaf.point.y - leaf.radius, width: leaf.radius * 2, height: leaf.radius * 2)
                    context.fill(Path(ellipseIn: dot), with: .color(colour))
                }
                context.fill(Path(ellipseIn: CGRect(x: anchor.x - 4.5, y: anchor.y - 4.5, width: 9, height: 9)), with: .color(colour))
                context.draw(Text(area.name).font(.caption2.weight(.semibold)).foregroundStyle(colour), at: CGPoint(x: anchor.x + (anchor.x < centre ? -8 : 8), y: anchor.y - 8), anchor: anchor.x < centre ? .trailing : .leading)
            }
            for leaf in leaves.filter({ $0.project.nodes > 0 }).sorted(by: { $0.project.nodes > $1.project.nodes }).prefix(5) {
                context.draw(Text(leaf.project.name).font(.system(size: 9)).foregroundStyle(.secondary), at: CGPoint(x: leaf.point.x, y: leaf.point.y + leaf.radius + 8))
            }
            context.fill(Path(ellipseIn: CGRect(x: centre - 6, y: ground - 6, width: 12, height: 12)), with: .color(Palette.gold))
            context.draw(Text(graph.name).font(.caption.weight(.semibold)), at: CGPoint(x: centre, y: ground - 16))
        }
        .frame(height: 290)
    }
}

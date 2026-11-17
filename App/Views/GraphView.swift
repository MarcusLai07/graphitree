import SwiftUI

/// The whole window: the graph, with every other screen floating over it.
struct GraphView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    let snapshot: WorkspaceSnapshot
    @Binding var panel: ShellPanel?
    @Binding var isChoosingFolder: Bool

    @AppStorage("graphLayout") private var layout: GraphLayout = .links
    @AppStorage("graphShowsNames") private var showsNames = true
    @AppStorage(BuildChoice.defaultsKey) private var buildChoice = BuildChoice.automatic

    @State private var path: [SceneLevel] = []
    @State private var titles: [String] = []
    @State private var scene: GraphScene?
    /// Identifies the scene actually loaded, which lags `sceneID` while a level is fetched.
    @State private var loadedSceneID = ""
    @State private var showHidden = false
    @State private var isolatedGroup: Int?
    @State private var selectedID: String?
    @State private var focus: GraphFocus?
    @State private var fitRequest = 0
    @State private var zoom: GraphZoom?
    @State private var isLoading = true
    @State private var failure: String?
    @State private var notice: String?
    @State private var review: ReviewSession?
    @State private var askSession: AskSession?
    @State private var askText = ""
    @State private var isPaletteOpen = false
    @State private var paletteProjects: [PaletteItem] = []
    /// The health check under the pointer, whose projects light up on the map.
    @State private var hoveredDetector: Detector?

    /// Where the canvas and the floating chrome sit in the window, so the graph frames itself in
    /// what the chrome leaves free, and panels line up with the chrome, at any window size.
    @State private var canvasFrame = CGRect.zero
    @State private var headerFrame = CGRect.zero
    @State private var leftColumnFrame = CGRect.zero
    @State private var rightColumnFrame = CGRect.zero
    @State private var bottomBarFrame = CGRect.zero

    private var level: SceneLevel? { path.last }

    /// Switching between the flat views reuses the drawn scene. Only Rings needs different data.
    private var sceneID: String {
        if let askSession {
            let state: String
            switch askSession.shown {
            case .running: state = "running"
            case .ready(let outcome): state = "ready\(outcome.items.count)"
            case .failed: state = "failed"
            }
            return "ask|\(askSession.id)|\(askSession.showsWithRules)|\(state)"
        }
        if let review {
            return "review|\(review.detector.rawValue)|\(currentFinding?.id ?? "done")|\(model.revision)"
        }
        return "\(String(describing: level))|\(showHidden)|\(layout.needsRingScene)|\(model.revision)"
    }

    /// Review and answers each show one constellation that clicks can't wander away from.
    private var isLocked: Bool { review != nil || askSession != nil }

    private var reviewQueue: [Finding] {
        guard let review else { return [] }
        return ReviewQueue.ordered(snapshot.findings[review.detector] ?? [])
    }

    private var currentFinding: Finding? {
        guard let review else { return nil }
        let queue = reviewQueue
        return queue.first { $0.id == review.currentID } ?? queue.first
    }

    /// Projects with findings for the hovered health check, when the map shows projects.
    private var spotlightIDs: [String]? {
        guard review == nil, case .projects = level, let hoveredDetector, let scene else { return nil }
        let projects = Set((snapshot.findings[hoveredDetector] ?? []).map(\.project))
        let ids = scene.nodes.map(\.id).filter { projects.contains($0) }
        return ids.isEmpty ? nil : ids.sorted()
    }

    private var selectedNode: SceneNode? {
        guard let selectedID else { return nil }
        return scene?.nodes.first { $0.id == selectedID }
    }

    private var isSymbolLevel: Bool {
        if case .symbols = level { return true }
        return false
    }

    /// The real node behind a selection, when the selection is a single symbol.
    private var inspectedSymbolID: String? {
        guard let selectedID, selectedID != GraphScene.ringCenterID else { return nil }
        if isSymbolLevel { return selectedID }
        if case .files = level, let ring = GraphScene.ringChild(selectedID) { return ring.child }
        return nil
    }

    /// The left rail's width. The level card on the right matches it, so the bottom bar and the
    /// graph sit in the middle of the window.
    private static let sideWidth: CGFloat = 216
    /// The right column's width while it holds a drawer: an answer, a finding or a selection.
    private static let drawerWidth: CGFloat = 332
    /// The band the top bar sits in, which moves the window like a title bar.
    private static let titleBand: CGFloat = 66
    /// The space between the chrome and what it frames.
    private static let chromeGap: CGFloat = 12

    /// Whether the right column holds a drawer, rather than only the level card.
    private var hasDrawer: Bool {
        askSession != nil || (review != nil && currentFinding != nil) || inspectedSymbolID != nil || selectedNode != nil
    }

    /// What the floating chrome covers, from each edge of the canvas. The graph frames itself in the
    /// rest, and keeps doing so as the window resizes. Values are whole points, so the web view
    /// only hears about real changes.
    private var insets: GraphInsets {
        let gap = Self.chromeGap
        let left = leftColumnFrame.width > 0 ? leftColumnFrame.maxX - canvasFrame.minX + gap : 244
        let top = headerFrame.height > 0 ? headerFrame.maxY - canvasFrame.minY + gap : 116
        let bottom = bottomBarFrame.height > 0 ? canvasFrame.maxY - bottomBarFrame.minY + gap : 118
        let right = hasDrawer && rightColumnFrame.width > 0 ? canvasFrame.maxX - rightColumnFrame.minX + gap : 16
        return GraphInsets(
            left: Double(left.rounded()),
            right: Double(right.rounded()),
            top: Double(top.rounded()),
            bottom: Double(bottom.rounded())
        )
    }

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()
            windowDragStrip
            if let panel { panelLayer(panel) }
            chrome.ignoresSafeArea()
            if isPaletteOpen {
                CommandPalette(
                    actions: paletteActions,
                    projects: paletteProjects,
                    searchNodes: paletteNodes,
                    ask: { startAsk($0) },
                    close: { isPaletteOpen = false }
                )
            }
        }
        .background {
            Button("Search or Run a Command", action: openPalette).keyboardShortcut("k").hidden()
            Button("Find a Node", action: openPalette).keyboardShortcut("f").hidden()
        }
        .onKeyDown(isActive: review != nil && panel == nil && !isPaletteOpen, handleReviewKey)
        .onKeyDown(isActive: askSession != nil && panel == nil && !isPaletteOpen) { event in
            guard event.keyCode == KeyCode.escape, !KeyCode.isEditingText else { return false }
            askSession = nil
            return true
        }
        // Review and answers focus their own centre, which the graph doesn't have.
        .onChange(of: isLocked) { if !isLocked { focus = nil } }
        .task(id: sceneID) { await loadScene() }
        .onAppear(perform: openLaunchPanel)
        .task(id: notice) {
            guard notice != nil else { return }
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { notice = nil }
        }
    }

    /// `open -a Graphitree --args -openPanel agents` opens a panel at launch, for screenshots and checks.
    /// Launch arguments aren't saved, so the next normal launch is unaffected. Without one, Build
    /// opens once for someone new, at the start of its setup.
    private func openLaunchPanel() {
        switch UserDefaults.standard.string(forKey: "openPanel") {
        case "browse": panel = .folders(.browse)
        case "build", "setup", "rebuild", "rules": panel = .build
        case "folders": panel = .folders(.arrange)
        case "tidy": panel = .folders(.tidy)
        case "agents": panel = .agents
        case "playbook": panel = .playbook
        case "insights": panel = .insights
        case "usage": panel = .usage
        default:
            // Someone new gets the setup once, before they've saved one or seen it.
            if !UserDefaults.standard.bool(forKey: "setupSeen") && !model.isSetUp {
                panel = .build
            }
        }
    }

    // MARK: - What builds

    private var builderBadge: BuilderBadge {
        BuilderBadge.current(stored: buildChoice, options: model.aiOptions.map(\.id), health: model.connectionHealth)
    }

    private var builderHelp: String {
        switch builderBadge {
        case .connect:
            return "No AI model is connected. Click to connect one."
        case .codeOnly:
            return "Rebuilds read code only. Click to pick a model."
        case .model(let id, _):
            let problem = model.connectionHealth[id].flatMap { $0.isProblem ? " · \($0.status)" : nil } ?? ""
            return "\(BuildChoice.name(of: id)) builds the graph\(problem)"
        }
    }

    // MARK: - Layers

    private var canvas: some View {
        ZStack {
            GraphCanvas(
                scene: scene,
                sceneID: loadedSceneID,
                layout: isLocked ? .rings : layout,
                showsLabels: showsNames,
                isolatedGroup: isolatedGroup,
                focus: focus,
                fitRequest: fitRequest,
                zoom: zoom,
                insets: insets,
                reducesMotion: reducesMotion,
                isReviewing: isLocked,
                spotlight: spotlightIDs,
                onEvent: handle
            )
            .accessibilityLabel("Graph canvas")
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { canvasFrame = $0 }
            if isLoading { ProgressView() }
            if let failure {
                ContentUnavailableView("Couldn't Draw the Graph", systemImage: "exclamationmark.triangle", description: Text(failure))
                    .background(Palette.ink)
            }
        }
    }

    /// The canvas fills the title bar, so the band behind the top bar moves the window instead.
    private var windowDragStrip: some View {
        VStack(spacing: 0) {
            WindowDragArea().frame(height: Self.titleBand)
            Spacer(minLength: 0)
        }
        .ignoresSafeArea()
    }

    private func panelLayer(_ current: ShellPanel) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .contentShape(Rectangle())
                .onTapGesture { panel = nil }
                .accessibilityLabel("Close panel")
            PanelContent(panel: current, snapshot: snapshot, open: { panel = $0 })
                .environment(\.closePanel, { panel = nil })
                .environment(\.showOnMap, { show($0) })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassPanel(cornerRadius: 18)
                .padding(.leading, panelLeading)
                .padding(.trailing, 16)
                .padding(.top, panelTop)
                .padding(.bottom, 16)
        }
        .ignoresSafeArea()
    }

    /// Panels open beside the rail and under the header, wherever the window's size puts them.
    private var panelLeading: CGFloat {
        leftColumnFrame.width > 0 ? leftColumnFrame.maxX - canvasFrame.minX + 10 : 242
    }

    private var panelTop: CGFloat {
        headerFrame.height > 0 ? headerFrame.maxY - canvasFrame.minY + 10 : 114
    }

    private var chrome: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                topBar
                HealthBar(
                    snapshot: snapshot,
                    panel: panel,
                    reviewing: review?.detector,
                    toggleReview: toggleReview,
                    hoverDetector: { hoveredDetector = $0 }
                )
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { headerFrame = $0 }

            HStack(alignment: .top, spacing: 16) {
                // The rail sits at the bottom, on the legend, so the top left is left to the graph.
                VStack(spacing: 10) {
                    Spacer(minLength: 0)
                    NavigationRail(
                        snapshot: snapshot,
                        panel: $panel,
                        isSetUp: model.isSetUp,
                        isRebuilding: model.isRebuilding,
                        hasWaitingPass: model.waitingDocsPass != nil,
                        builder: builderBadge,
                        builderHelp: builderHelp
                    )
                    legend
                }
                .frame(width: Self.sideWidth)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { leftColumnFrame = $0 }

                VStack(spacing: 8) {
                    if panel == nil, let problem = model.raisedProblem, let health = model.connectionHealth[problem] {
                        ConnectionBanner(id: problem, health: health) { panel = .agents }
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    noticeBanner
                    Spacer(minLength: 0)
                    if panel == nil {
                        Group {
                            if let review { reviewHUD(review) } else { askBar }
                        }
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { bottomBarFrame = $0 }
                    }
                }
                .frame(maxWidth: .infinity)

                if panel == nil {
                    rightColumn
                        .frame(width: hasDrawer ? Self.drawerWidth : Self.sideWidth)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rightColumnFrame = $0 }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            navigationPill.frame(maxWidth: .infinity, alignment: .leading)
            viewControls
            // A narrow window keeps the search box's shortcut and drops its words.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    cleanGraphPill
                    searchField(isCompact: false)
                }
                HStack(spacing: 8) {
                    cleanGraphPill
                    searchField(isCompact: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var navigationPill: some View {
        HStack(spacing: 9) {
            BrandMark()
            if titles.count <= 1 { Text("Graphitree").font(.headline).fixedSize() }
            ChromeDivider()
            graphMenu
            if askSession != nil {
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                Text("Ask").font(.callout.weight(.medium))
            } else if let review {
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                Text("Review").font(.callout).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                Text(review.detector.title).font(.callout.weight(.medium)).lineLimit(1)
            } else {
                navigationTrail
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background { WindowDragArea() }
        .glassPanel(cornerRadius: 14)
        .padding(.leading, 76) // Clears the window's traffic lights.
    }

    @ViewBuilder
    private var navigationTrail: some View {
        if titles.count > 1 { upButton }
        Text(titles.last ?? "")
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
                .help(titles.last ?? "")
    }

    /// Clicking goes up one level. Holding it lists every level above, to jump further.
    private var upButton: some View {
        Menu {
            ForEach(Array(titles.enumerated().dropLast().reversed()), id: \.offset) { index, title in
                Button(title) { goBack(to: index) }
            }
        } label: {
            Image(systemName: "chevron.up")
        } primaryAction: {
            goUp()
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .tint(.secondary)
        .fixedSize()
        .help("Up one level (⌘↑). Hold for every level above.")
        .accessibilityLabel("Up one level")
        .background {
            Button("Up One Level", action: goUp)
                .keyboardShortcut(.upArrow, modifiers: .command)
                .hidden()
        }
    }

    private var graphMenu: some View {
        Menu {
            ForEach(model.catalog) { entry in
                Button(entry.name) { model.choose(entry.outDirectory) }
            }
            Divider()
            Button("Map a Folder…") { isChoosingFolder = true }
        } label: {
            Text(model.currentGraphName).font(.callout.weight(.medium))
        }
        .menuStyle(.borderlessButton)
        .tint(.primary)
        .fixedSize()
        .help("Switch graph")
        .accessibilityLabel("Switch graph, currently \(model.currentGraphName)")
    }

    private var viewControls: some View {
        HStack(spacing: 4) {
            ForEach(GraphLayout.allCases) { option in
                Button {
                    // Review and answers lock the layout, so picking one goes back to the graph.
                    review = nil
                    askSession = nil
                    layout = option
                } label: {
                    Image(systemName: option.symbol)
                }
                .buttonStyle(ChromeButtonStyle(isOn: !isLocked && layout == option))
                .help(isLocked ? "Back to the graph as \(option.title)" : option.title)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(layout == option ? .isSelected : [])
            }
            ChromeDivider().padding(.horizontal, 3)
            Button("Zoom Out", systemImage: "minus") { zoom = GraphZoom(zoomsIn: false) }
                .keyboardShortcut("-")
                .help("Zoom out (⌘-)")
            Button("Zoom In", systemImage: "plus") { zoom = GraphZoom(zoomsIn: true) }
                .keyboardShortcut("=")
                .help("Zoom in (⌘=)")
            Button("Fit", systemImage: "arrow.up.left.and.arrow.down.right") { fitRequest += 1 }
                .keyboardShortcut("0")
                .help("Fit the graph (⌘0)")
            ChromeDivider().padding(.horizontal, 3)
            Button { showsNames.toggle() } label: {
                Text("Aa").fontWeight(.semibold)
            }
            .buttonStyle(ChromeButtonStyle(isOn: showsNames))
            .help("Show node names")
            .accessibilityLabel("Names")
            .accessibilityAddTraits(showsNames ? .isSelected : [])
            Button { showHidden.toggle() } label: {
                Image(systemName: showHidden ? "eye" : "eye.slash")
            }
            .buttonStyle(ChromeButtonStyle(isOn: showHidden))
            .help("Show hidden nodes, greyed out")
            .accessibilityLabel("Show hidden nodes")
            .accessibilityAddTraits(showHidden ? .isSelected : [])
        }
        .labelStyle(.iconOnly)
        .buttonStyle(ChromeButtonStyle())
        .padding(.horizontal, 6)
        .frame(height: 42)
        .background { WindowDragArea() }
        .glassPanel(cornerRadius: 14)
        .fixedSize()
    }

    /// Short, because the Write button shares the pill once there is something to write.
    private var cleanStatus: (text: String, colour: Color) {
        switch snapshot.clean {
        case .notWritten: return (model.canWriteClean ? "Clean graph" : "Clean graph not written", .secondary)
        case .upToDate: return ("Clean graph up to date", Palette.jade)
        case .outOfDate: return ("Clean graph", Palette.gold)
        }
    }

    private var cleanGraphPill: some View {
        HStack(spacing: 8) {
            Circle().fill(cleanStatus.colour).frame(width: 7, height: 7)
            Text(cleanStatus.text).font(.callout).foregroundStyle(.secondary).lineLimit(1).fixedSize()
            if model.canWriteClean {
                Button("Write") { model.writeCleanGraph() }
                    .buttonStyle(GoldButtonStyle())
                    .keyboardShortcut("s")
                    .help("Write graph.clean.json with your rules applied (⌘S)")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background { WindowDragArea() }
        .glassPanel(cornerRadius: 14)
        .help("graph.clean.json is your graph with the rules applied. Queries only use it once the graphify query line in CLAUDE.md points at it.")
    }

    private func searchField(isCompact: Bool) -> some View {
        Button(action: openPalette) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                if !isCompact {
                    Text("Search or command").foregroundStyle(.secondary).lineLimit(1).fixedSize()
                    Spacer(minLength: 4)
                }
                KeyCap("⌘K")
            }
            .padding(.horizontal, 11)
            .frame(width: isCompact ? nil : 206, height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(cornerRadius: 14)
        .help("Find a node or project, or run a command (⌘K)")
        .accessibilityLabel("Search or run a command")
    }

    @ViewBuilder
    private var noticeBanner: some View {
        if let notice {
            Text(notice)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassPanel(cornerRadius: 12)
        }
    }

    // MARK: - Bottom and right

    /// The bottom bar: the graph's size, and a box to ask it a question the way an agent would.
    private var askBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if askSession == nil {
                HStack(spacing: 18) {
                    vital(snapshot.overview.visibleNodes, "nodes")
                    vital(snapshot.overview.visibleEdges, "edges")
                    vital(snapshot.overview.communities, "communities")
                }
                .padding(.horizontal, 4)
            }
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(Palette.gold)
                TextField("Ask the graph: where are payments handled?", text: $askText)
                    .textFieldStyle(.plain)
                    .onSubmit { startAsk(askText) }
                    .onExitCommand {
                        if askSession != nil { askSession = nil } else { askText = "" }
                    }
                if askSession != nil {
                    Button { askSession = nil } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                            KeyCap("esc")
                        }
                    }
                    .buttonStyle(SoftButtonStyle())
                    .help("Back to the graph (Esc)")
                } else {
                    Button { startAsk(askText) } label: { Image(systemName: "arrow.right") }
                        .buttonStyle(ChromeButtonStyle(isOn: !askText.trimmingCharacters(in: .whitespaces).isEmpty))
                        .disabled(askText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .help("Ask (Return)")
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 5)
            .frame(height: 40)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.white.opacity(0.07)))
        }
        .padding(10)
        .frame(maxWidth: 560)
        .glassPanel(cornerRadius: 16)
    }

    private func vital(_ value: Int, _ title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value.formatted())
                .font(.system(.callout, design: .monospaced).weight(.medium))
            Text(title).font(.callout).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var rightColumn: some View {
        VStack(spacing: 12) {
            if askSession != nil {
                AnswerPanel(
                    session: Binding(get: { askSession ?? AskSession(question: "") }, set: { askSession = $0 }),
                    comparison: answerComparison,
                    suspectHubs: Set((snapshot.findings[.crossProject] ?? []).map(\.anchor)),
                    open: { jump(toNode: $0) },
                    writeCleanGraph: { model.writeCleanGraph() }
                )
                .frame(maxHeight: .infinity)
                .glassPanel()
            } else if review != nil {
                if let finding = currentFinding {
                    FindingInspector(detector: finding.detector, findings: [finding])
                        .frame(maxHeight: .infinity)
                        .glassPanel()
                } else {
                    Spacer(minLength: 0)
                }
            } else if let symbol = inspectedSymbolID {
                NodeInspector(nodeID: symbol) { jump(toNode: $0) }
                    .frame(maxHeight: .infinity)
                    .glassPanel()
            } else if let selectedNode {
                ScrollView {
                    SelectionDrawer(
                        node: selectedNode,
                        project: selectedProject(selectedNode),
                        snapshot: snapshot,
                        canOpen: selectedNode.id != GraphScene.ringCenterID && !isSymbolLevel,
                        drill: { drill(into: selectedNode.id) },
                        openList: { panel = .detector($0) },
                        review: { startReview($0.detector, at: $0.id) }
                    )
                }
                .scrollBounceBehavior(.basedOnSize)
                .fixedSize(horizontal: false, vertical: true)
                .glassPanel()
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
            }
            if !isLocked { levelCard }
        }
    }

    /// The project a selection stands for, when it is one.
    private func selectedProject(_ node: SceneNode) -> String? {
        switch level {
        case .projects where node.id != GraphScene.ringCenterID && GraphScene.ringChild(node.id) == nil:
            return node.id
        case .communities(let project) where node.id == GraphScene.ringCenterID:
            return project
        default:
            return nil
        }
    }

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titles.last ?? "Graph").font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
            if let scene {
                Text(levelSummary(scene)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 14)
    }

    private func levelSummary(_ scene: GraphScene) -> String {
        var text = "\(scene.nodes.count.formatted()) \(scene.nodes.count == 1 ? "node" : "nodes") and \(scene.edges.count.formatted()) \(scene.edges.count == 1 ? "link" : "links") drawn."
        if scene.omittedNodes > 0 { text += " \(scene.omittedNodes.formatted()) smaller nodes aren't drawn." }
        if !isSymbolLevel { text += " Double-click to open." }
        return text
    }

    @ViewBuilder
    private var legend: some View {
        if let groups = scene?.groups, groups.count >= 2 {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                    ForEach(groups) { group in
                        Button {
                            isolatedGroup = isolatedGroup == group.id ? nil : group.id
                        } label: {
                            HStack(spacing: 7) {
                                Circle().fill(Palette.series(group.slot)).frame(width: 9, height: 9)
                                Text(group.label).lineLimit(1).truncationMode(.middle)
                            }
                            .font(.caption.weight(isolatedGroup == group.id ? .semibold : .regular))
                            .foregroundStyle(isolatedGroup == nil || isolatedGroup == group.id ? .primary : .tertiary)
                            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("\(group.label): \(group.count.formatted())")
                        .accessibilityAddTraits(isolatedGroup == group.id ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 118)
            .fixedSize(horizontal: false, vertical: true)
            .glassPanel(cornerRadius: 14)
        }
    }

    // MARK: - Navigation

    private func handle(_ event: GraphCanvasEvent) {
        // Review scenes are one finding, so clicks there don't select or drill.
        if isLocked {
            if case .failed(let message) = event { failure = message }
            return
        }
        switch event {
        case .select(let id):
            selectedID = id
        case .clear:
            selectedID = nil
        case .drill(let id):
            drill(into: id)
        case .failed(let message):
            failure = message
        }
    }

    /// Opening a ring-two node goes down two levels: into its parent, then into it.
    private func drill(into id: String) {
        guard id != GraphScene.ringCenterID else { return }
        if let ring = GraphScene.ringChild(id) {
            drill(through: [ring.parent, ring.child])
        } else {
            drill(through: [id])
        }
    }

    private func drill(through ids: [String]) {
        guard let start = level else { return }
        Task {
            var current = start
            var newLevels: [SceneLevel] = []
            var newTitles: [String] = []
            var landedOn: String?
            for id in ids {
                guard let child = await model.childLevel(of: current, nodeID: id) else {
                    // Symbols are the bottom, so a symbol is selected rather than opened.
                    landedOn = id
                    break
                }
                newLevels.append(child)
                newTitles.append(await model.title(of: child))
                current = child
            }
            guard !newLevels.isEmpty else { return }
            focus = landedOn.map { GraphFocus(id: $0) }
            selectedID = nil
            isolatedGroup = nil
            path += newLevels
            titles += newTitles
        }
    }

    private func goUp() {
        if titles.count > 1 { goBack(to: titles.count - 2) }
    }

    private func goBack(to index: Int) {
        focus = nil
        selectedID = nil
        isolatedGroup = nil
        path = Array(path.prefix(index + 1))
        titles = Array(titles.prefix(index + 1))
    }

    private func jump(to item: OutlineItem) {
        guard case .symbol(let id, _, _) = item.kind else { return }
        jump(toNode: id)
    }

    /// Opens the level an outline item is drawn on, then selects it and moves the camera onto it.
    private func show(_ kind: OutlineItem.Kind) {
        let byProjects = path.first == .projects
        let levels: [SceneLevel]
        let target: String?
        switch kind {
        case .symbol(let id, _, _):
            jump(toNode: id)
            return
        case .project(let project):
            levels = byProjects ? [.projects] : [.communities(project: project)]
            target = byProjects ? project : nil
        case .community(let project, let community):
            levels = (byProjects ? [.projects] : []) + [.communities(project: project)]
            target = GraphIndex.communityKey(community)
        case .file(let project, let community, let file):
            levels = (byProjects ? [.projects] : []) + [.communities(project: project), .files(project: project, community: community)]
            target = file
        }
        Task {
            var newTitles: [String] = []
            for level in levels {
                newTitles.append(await model.title(of: level))
            }
            review = nil
            askSession = nil
            panel = nil
            selectedID = nil
            isolatedGroup = nil
            path = levels
            titles = newTitles
            focus = target.map { GraphFocus(id: $0) }
        }
    }

    /// Opens the level that holds a node, then selects it and moves the camera onto it.
    private func jump(toNode id: String) {
        Task {
            guard let location = await model.location(ofNode: id) else {
                notice = "That node has no source file, so it isn't in the graph's levels. Find it in Folders › Browse."
                return
            }
            var newTitles: [String] = []
            for level in location.levels {
                newTitles.append(await model.title(of: level))
            }
            review = nil
            askSession = nil
            panel = nil
            if location.isHidden { showHidden = true }
            selectedID = nil
            isolatedGroup = nil
            path = location.levels
            titles = newTitles
            focus = GraphFocus(id: id)
        }
    }

    // MARK: - Loading

    private func loadScene() async {
        isLoading = true
        if askSession != nil {
            loadAnswerScene()
            return
        }
        if review != nil {
            await loadReviewScene()
            return
        }
        if path.isEmpty {
            guard let root = await model.rootLevel() else { return }
            titles = [await model.title(of: root)]
            path = [root]
            return // Setting the path changes the task id, which loads the scene.
        }
        guard let level else { return }
        let requestedID = sceneID
        let loaded = layout.needsRingScene
            ? await model.ringScene(at: level, showHidden: showHidden)
            : await model.scene(at: level, showHidden: showHidden)
        guard !Task.isCancelled else { return }
        scene = loaded
        loadedSceneID = requestedID
        isLoading = false
        if let focus, loaded?.nodes.contains(where: { $0.id == focus.id }) == false {
            notice = "That node is one of the smaller ones left out of this view."
            self.focus = nil
        }
    }

    private func loadReviewScene() async {
        let requestedID = sceneID
        guard let finding = currentFinding else {
            scene = GraphScene(nodes: [], edges: [], groups: [], omittedNodes: 0)
            loadedSceneID = requestedID
            isLoading = false
            return
        }
        let loaded = await model.reviewScene(for: finding)
        guard !Task.isCancelled else { return }
        scene = loaded
        loadedSceneID = requestedID
        isLoading = false
        focus = GraphFocus(id: GraphScene.ringCenterID, movesCamera: false)
    }

    // MARK: - Ask

    private var answerComparison: AnswerComparison {
        if askSession?.withRules != nil { return .available }
        return snapshot.rules.isEmpty ? .noRules : .needsCleanGraph
    }

    /// Asks graphify as an agent would. With rules and an up-to-date clean graph, it asks both.
    private func startAsk(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        review = nil
        panel = nil
        selectedID = nil
        isolatedGroup = nil
        askText = question
        var compares = false
        if case .upToDate = snapshot.clean, !snapshot.rules.isEmpty { compares = true }
        let session = AskSession(question: question, withRules: compares ? .running : nil)
        askSession = session
        Task {
            let state = await model.askGraph(question, onCleanGraph: false)
            if askSession?.id == session.id { askSession?.now = state }
        }
        if compares {
            Task {
                let state = await model.askGraph(question, onCleanGraph: true)
                if askSession?.id == session.id { askSession?.withRules = state }
            }
        }
    }

    private func loadAnswerScene() {
        let requestedID = sceneID
        guard let askSession else { return }
        switch askSession.shown {
        case .running:
            return // Keep the current picture under the spinner until the answer arrives.
        case .failed:
            isLoading = false
        case .ready(let outcome):
            scene = GraphScene.answer(question: askSession.question, found: outcome.answer.found, items: outcome.items, scheme: GraphSource(outDirectory: model.outDirectory).scheme)
            loadedSceneID = requestedID
            isLoading = false
            focus = GraphFocus(id: GraphScene.ringCenterID, movesCamera: false)
        }
    }

    // MARK: - Review

    private func toggleReview(_ detector: Detector) {
        if review?.detector == detector {
            review = nil
        } else {
            startReview(detector)
        }
    }

    private func startReview(_ detector: Detector, at findingID: String? = nil) {
        askSession = nil
        panel = nil
        selectedID = nil
        isolatedGroup = nil
        hoveredDetector = nil
        let queue = ReviewQueue.ordered(snapshot.findings[detector] ?? [])
        review = ReviewSession(detector: detector, currentID: findingID ?? queue.first?.id)
    }

    private func step(forward: Bool) {
        guard var session = review, let current = currentFinding else { return }
        let queue = reviewQueue
        guard let index = queue.firstIndex(where: { $0.id == current.id }) else { return }
        let target = forward ? index + 1 : index - 1
        guard queue.indices.contains(target) else { return }
        session.currentID = queue[target].id
        review = session
    }

    private func decide(reject: Bool) {
        guard var session = review, let current = currentFinding else { return }
        session.currentID = ReviewQueue.neighbour(of: current.id, in: reviewQueue)?.id
        session.history.append(ReviewSession.Decision(findingID: current.id, rejected: reject))
        if reject { session.rejected += 1 } else { session.kept += 1 }
        review = session
        if reject { model.remove([current]) } else { model.keep([current]) }
    }

    private func undoDecision() {
        guard var session = review, let last = session.history.popLast() else { return }
        if last.rejected { session.rejected -= 1 } else { session.kept -= 1 }
        session.currentID = last.findingID
        review = session
        model.undoLast()
    }

    private func reviewHUD(_ session: ReviewSession) -> some View {
        let queue = reviewQueue
        let finding = currentFinding
        return ReviewHUD(
            session: session,
            finding: finding,
            position: (finding.flatMap { current in queue.firstIndex { $0.id == current.id } } ?? 0) + 1,
            remaining: queue.count,
            canWriteClean: model.canWriteClean,
            actions: ReviewActions(
                previous: { step(forward: false) },
                next: { step(forward: true) },
                reject: { decide(reject: true) },
                keep: { decide(reject: false) },
                undo: undoDecision,
                list: { panel = .detector(session.detector) },
                exit: { review = nil },
                writeClean: { model.writeCleanGraph() }
            )
        )
    }

    /// Single keys drive review: J and K move, X rejects, A keeps, U undoes, L lists, Esc leaves.
    private func handleReviewKey(_ event: NSEvent) -> Bool {
        guard KeyCode.isPlain(event), !KeyCode.isEditingText else { return false }
        switch event.keyCode {
        case KeyCode.escape: review = nil; return true
        case KeyCode.right: step(forward: true); return true
        case KeyCode.left: step(forward: false); return true
        default: break
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "j": step(forward: true)
        case "k": step(forward: false)
        case "x": decide(reject: true)
        case "a": decide(reject: false)
        case "u": undoDecision()
        case "l": if let review { panel = .detector(review.detector) }
        default: return false
        }
        return true
    }

    // MARK: - Command palette

    private func openPalette() {
        isPaletteOpen = true
        Task {
            guard case .projects = path.first else {
                paletteProjects = []
                return
            }
            let roots = await model.outlineChildren(of: nil)
            paletteProjects = roots.compactMap { item in
                guard case .project(let name) = item.kind else { return nil }
                return PaletteItem(
                    id: "project:\(name)",
                    title: name,
                    subtitle: "\(item.count.formatted()) nodes",
                    symbol: "folder",
                    run: { openProject(name) }
                )
            }
        }
    }

    private func openProject(_ name: String) {
        review = nil
        askSession = nil
        panel = nil
        selectedID = nil
        isolatedGroup = nil
        Task {
            let level = SceneLevel.communities(project: name)
            let title = await model.title(of: level)
            path = [.projects, level]
            titles = [titles.first ?? "Projects", title]
        }
    }

    private func paletteNodes(_ text: String) async -> [PaletteItem] {
        let found = await model.search(text)
        return found.prefix(8).compactMap { item in
            guard case .symbol(let id, _, _) = item.kind else { return nil }
            return PaletteItem(id: "node:\(id)", title: item.title, subtitle: item.subtitle, symbol: "function", run: { jump(toNode: id) })
        }
    }

    private var paletteActions: [PaletteItem] {
        var items: [PaletteItem] = Detector.allCases.compactMap { detector in
            let count = snapshot.count(detector)
            guard count > 0 else { return nil }
            return PaletteItem(
                id: "review:\(detector.rawValue)",
                title: "Review \(detector.title)",
                subtitle: "\(count.formatted()) to review",
                symbol: detector.symbol,
                run: { startReview(detector) }
            )
        }
        if model.canWriteClean {
            items.append(PaletteItem(id: "write", title: "Write Clean Graph", symbol: "square.and.arrow.down", hint: "⌘S", run: { model.writeCleanGraph() }))
        }
        if snapshot.canUndo {
            items.append(PaletteItem(id: "undo", title: "Undo Last Decision", symbol: "arrow.uturn.backward", hint: "⌘Z", run: { model.undoLast() }))
        }
        items += [
            PaletteItem(id: "browse", title: "Browse All Nodes", subtitle: "In Folders", symbol: "list.bullet.indent", run: { review = nil; panel = .folders(.browse) }),
            PaletteItem(id: "build", title: model.isSetUp ? "Rebuild Graph" : "Set Up and Build", subtitle: "Pick the AI model, what graphify reads and how much AI tools get back, then build", symbol: "hammer", run: { review = nil; askSession = nil; panel = .build }),
            PaletteItem(id: "rules", title: "Show Cleanup Rules", subtitle: "\(snapshot.rules.count.formatted()) saved, listed in Build", symbol: "checklist", run: { review = nil; askSession = nil; panel = .build }),
            PaletteItem(id: "folders", title: "Folders", subtitle: "Browse nodes, arrange and back up folders, and tidy up", symbol: "folder", run: { review = nil; askSession = nil; panel = .folders(nil) }),
            PaletteItem(id: "insights", title: "Insights", subtitle: "What AI tools asked, what found nothing, jobs with no pick", symbol: "chart.bar.xaxis", run: { review = nil; askSession = nil; panel = .insights }),
            PaletteItem(id: "map", title: "Map a Folder…", subtitle: "Open or build the graph for any folder", symbol: "folder.badge.plus", run: { isChoosingFolder = true }),
            PaletteItem(id: "playbook", title: "Playbook", subtitle: "Chat, libraries, stack and how you work, for AI tools", symbol: "books.vertical", run: { review = nil; askSession = nil; panel = .playbook }),
            PaletteItem(id: "agents", title: "Set Up AI Models", subtitle: "Pick who builds the graph and connect the apps that ask it", symbol: "brain.head.profile", run: { review = nil; askSession = nil; panel = .agents }),
        ]
        items += GraphLayout.allCases.map { option in
            PaletteItem(id: "layout:\(option.rawValue)", title: "Show as \(option.title)", symbol: option.symbol, run: { review = nil; layout = option })
        }
        items += [
            PaletteItem(id: "names", title: showsNames ? "Hide Names" : "Show Names", symbol: "textformat", run: { showsNames.toggle() }),
            PaletteItem(id: "hidden", title: showHidden ? "Hide Hidden Nodes" : "Show Hidden Nodes", symbol: "eye", run: { showHidden.toggle() }),
            PaletteItem(id: "fit", title: "Fit Graph", symbol: "arrow.up.left.and.arrow.down.right", hint: "⌘0", run: { fitRequest += 1 }),
        ]
        if titles.count > 1, review == nil {
            items.append(PaletteItem(id: "up", title: "Go Up One Level", symbol: "chevron.up", hint: "⌘↑", run: goUp))
        }
        items += model.catalog
            .filter { $0.outDirectory.standardizedFileURL != model.outDirectory.standardizedFileURL }
            .map { entry in
                PaletteItem(id: "graph:\(entry.outDirectory.path)", title: "Switch to \(entry.name)", symbol: "point.3.connected.trianglepath.dotted", run: { model.choose(entry.outDirectory) })
            }
        items.append(PaletteItem(id: "reload", title: "Reload Graph", symbol: "arrow.clockwise", hint: "⌘R", run: { model.load() }))
        return items
    }
}

import AppKit
import SwiftUI

/// A screen that floats over the graph.
enum ShellPanel: Hashable {
    /// Browse and the folder tools. Without a tab, it opens where it was last left.
    case folders(FoldersTab?)
    case detector(Detector)
    case build
    case agents
    /// Claude's plan limits and Claude Code's activity on this Mac.
    case usage
    case playbook
    case insights
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var panel: ShellPanel?
    @State private var isChoosingFolder = false

    var body: some View {
        @Bindable var model = model

        ZStack {
            CanvasBackdrop().ignoresSafeArea()
            // A new install connects a model before anything else. The graph opens behind it.
            if model.firstRunOpen {
                FirstRunView()
            } else {
                content
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.appBecameActive()
        }
        // The menu bar, widgets and notifications ask for the Usage page through the router.
        .onReceive(AppRouter.shared.$pending.compactMap { $0 }) { _ in
            route(AppRouter.shared.take())
        }
        .background(WindowReader { MainWindow.current = $0 })
        .preferredColorScheme(.dark)
        .tint(Palette.gold)
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { model.mapFolder(url) }
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func route(_ request: AppRouter.Request?) {
        switch request {
        case .usage(let provider)?:
            if let provider { UserDefaults.standard.set(provider.rawValue, forKey: ClaudeUsageStore.Key.provider) }
            panel = .usage
        case .usageSettings?:
            panel = .usage
            AppRouter.shared.showsUsageSettings = true
        case .window?, nil:
            break
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading(let phase):
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text(phase.rawValue).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready(let snapshot):
            // Each graph gets a fresh stage, so a position in the old graph doesn't carry over.
            GraphView(snapshot: snapshot, panel: $panel, isChoosingFolder: $isChoosingFolder)
                .id(model.outDirectory)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Open the Graph", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Choose a Folder to Map…") { isChoosingFolder = true }
                Button("Try Again") { model.load() }
            }
        }
    }
}

/// The screen shown in the floating panel.
struct PanelContent: View {
    @Environment(AppModel.self) private var model
    let panel: ShellPanel
    let snapshot: WorkspaceSnapshot
    let open: (ShellPanel) -> Void

    var body: some View {
        switch panel {
        case .detector(let detector):
            TriageView(detector: detector, findings: snapshot.findings[detector] ?? [])
                .id(detector)
        case .build:
            BuildView(snapshot: snapshot, openModels: { open(.agents) }, openPlaybook: { open(.playbook) }, openFolders: { open(.folders($0)) })
        case .folders(let start):
            // A link to another tab while Folders is open starts it afresh on that tab.
            FoldersView(openBuild: { open(.build) }, start: start)
                .id(start)
        case .agents:
            AgentsView()
        case .usage:
            UsageView()
        case .playbook:
            PlaybookView(openModels: { open(.agents) })
        case .insights:
            InsightsView(openPlaybook: { open(.playbook) })
        }
    }
}

import SwiftUI

@main
struct GraphitreeApp: App {
    @State private var model: AppModel
    @State private var lab = LabRouter()

    init() {
        _model = State(initialValue: AppModel())
        // Starts the daily update check.
        _ = Updates.shared
    }

    var body: some Scene {
        WindowGroup("Graphitree") {
            RootView()
                .environment(model)
                .environment(lab)
                .frame(minWidth: 1240, minHeight: 720)
                .task {
                    model.load()
                    model.refreshCatalog()
                    // Keeps the plan-limit history going, once the Usage page has read it before.
                    UsageRefresher.shared.startIfEnabled()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 860)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Graphitree") { AboutPanel.show() }
                CheckForUpdatesButton(updates: .shared)
                Button("Uninstall Graphitree…") { UninstallCommand.confirmAndUninstall(model: model) }
            }
            CommandMenu("Graph") {
                ForEach(model.catalog) { entry in
                    Button(entry.name) { model.choose(entry.outDirectory) }
                }
                Divider()
                Button("Reload") { model.load() }
                    .keyboardShortcut("r")
                    .disabled(model.isLoading)
            }
            CommandGroup(replacing: .undoRedo) {
                // A panel with its own undo, like Arrange's draft, takes ⌘Z while it's open.
                if let panelUndo = model.panelUndo {
                    Button(panelUndo.title) { panelUndo.run() }
                        .keyboardShortcut("z")
                } else {
                    Button("Undo Last Decision") { model.undoLast() }
                        .keyboardShortcut("z")
                        .disabled(model.snapshot?.canUndo != true)
                }
            }
        }

        // The Playbook lab: try a library live before verifying it. Playbook cards open it.
        Window("Playbook Lab", id: "lab") {
            LabWindow()
                .environment(lab)
        }
        .defaultSize(width: 1320, height: 880)
    }
}

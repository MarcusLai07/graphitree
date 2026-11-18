import SwiftUI

@main
struct GraphitreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: AppModel
    @State private var lab = LabRouter()
    @AppStorage(MenuBarSettings.Key.shows) private var showsMenuBar = true
    /// Started by the login job: the window stays closed until it's asked for.
    private let launchBehavior: SceneLaunchBehavior

    init() {
        _model = State(initialValue: AppModel())
        launchBehavior = MenuBarSettings.startsInMenuBar ? .suppressed : .automatic
        // Starts the daily update check.
        _ = Updates.shared
    }

    var body: some Scene {
        WindowGroup("Graphitree", id: "main") {
            RootView()
                .environment(model)
                .environment(lab)
                .frame(minWidth: 1240, minHeight: 720)
                .task {
                    model.load()
                    model.refreshCatalog()
                }
                // Widgets and notifications open graphitree:// links. An open window takes them;
                // with none open, SwiftUI opens one for them.
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .onOpenURL { AppRouter.shared.handle($0) }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 860)
        .defaultLaunchBehavior(launchBehavior)
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
        // Links go to the main window, never here.
        .handlesExternalEvents(matching: [])

        // The plan's limits at a glance. While it's on, Graphitree keeps running with its window
        // closed, out of the Dock, so the readings, widgets and notifications keep going.
        MenuBarExtra(isInserted: $showsMenuBar) {
            MenuBarView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

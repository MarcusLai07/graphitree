import AppKit
import SwiftUI

// Renders one of Graphitree's panels in a window that's never put on screen and saves it as a PNG,
// so changes can be checked without taking the screen from whoever is using the Mac.
//
//   GraphitreeShots <panel> <out.png> [-key value …]
//
// `window` renders the whole main window instead, at `-width 1240 -height 720`, to check how the
// chrome arranges itself at a size. The graph is drawn by a web page that ships only inside the
// app, so the canvas is empty there.
//
// `firstrun` renders the "Connect an AI model" screen a new install opens on.
//
// Panels: build, folders, playbook, agents, browse, insights, usage. The panels' own launch options pick the
// state, such as `-buildMode home`, `-setupStep noise`, `-playbookTab stack`, `-agentsTab keys`
// or `-readsDocsOnRebuild YES`. `-settle 6` is how many seconds to let the panel load, and
// `-height 2000` makes the picture taller for long panels. Graphitree's
// saved settings are read but never written: the tool writes only to its own defaults.

final class ShotDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do {
                try await shoot()
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("GraphitreeShots: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
    }
}

struct ShotError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
func shoot() async throws {
    let arguments = CommandLine.arguments
    guard arguments.count >= 3 else {
        throw ShotError(message: "usage: GraphitreeShots <window|firstrun|build|folders|playbook|agents|browse> <out.png> [-key value …]")
    }
    let panel: ShellPanel
    if arguments[1] == "move" || arguments[1] == "newfolder" || arguments[1] == "labels" || arguments[1] == "usagesettings" || arguments[1] == "claudesignin" {
        try await shootSheet(arguments[1], output: URL(fileURLWithPath: arguments[2]))
        return
    }
    if arguments[1] == "window" {
        try await shootWindow(output: URL(fileURLWithPath: arguments[2]))
        return
    }
    if arguments[1] == "firstrun" {
        try await shootFirstRun(output: URL(fileURLWithPath: arguments[2]))
        return
    }
    if arguments[1] == "widgets" {
        // The menu bar's label and popover, and every widget size (see Shots/WidgetShot.swift).
        try await shootWidgets(folder: URL(fileURLWithPath: arguments[2], isDirectory: true))
        return
    }
    if arguments[1] == "lab" {
        // A path ending in "/" renders every slot into that folder (see Shots/LabShot.swift).
        try await shootLab(output: URL(fileURLWithPath: arguments[2], isDirectory: arguments[2].hasSuffix("/")))
        return
    }
    switch arguments[1] {
    case "build": panel = .build
    case "folders": panel = .folders(.arrange)
    case "playbook": panel = .playbook
    case "agents": panel = .agents
    case "browse": panel = .folders(.browse)
    case "tidy": panel = .folders(.tidy)
    case "insights": panel = .insights
    case "usage": panel = .usage
    default: throw ShotError(message: "unknown panel \(arguments[1])")
    }
    let output = URL(fileURLWithPath: arguments[2])
    let settle = UserDefaults.standard.double(forKey: "settle") > 0 ? UserDefaults.standard.double(forKey: "settle") : 6

    let model = AppModel()
    model.load()
    // Usage shows its last stored reading; a screenshot never asks the keychain for Claude's sign-in.
    UsageRefresher.readsLimits = false
    let deadline = Date().addingTimeInterval(180)
    while model.snapshot == nil {
        if case .failed(let message) = model.state { throw ShotError(message: message) }
        guard Date() < deadline else { throw ShotError(message: "the graph didn't open in time") }
        try await Task.sleep(for: .milliseconds(200))
    }
    guard let snapshot = model.snapshot else { return }

    let height = UserDefaults.standard.double(forKey: "height")
    let size = NSSize(width: 1060, height: height > 0 ? height : 900)
    let view = PanelContent(panel: panel, snapshot: snapshot, open: { _ in })
        .environment(model)
        .environment(\.closePanel, {})
        .frame(width: size.width, height: size.height)
        .background(Palette.panel)
        .preferredColorScheme(.dark)
        .tint(Palette.gold)
    let hosting = NSHostingView(rootView: view)
    hosting.frame = NSRect(origin: .zero, size: size)
    hosting.appearance = NSAppearance(named: .darkAqua)
    // The window gives the views a home; it is never ordered on screen.
    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = hosting
    window.isReleasedWhenClosed = false

    // Let the panel's own loading finish: scans, estimates, the playbook.
    try await Task.sleep(for: .seconds(settle))
    hosting.layoutSubtreeIfNeeded()
    guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
        throw ShotError(message: "couldn't make a bitmap")
    }
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ShotError(message: "couldn't encode the PNG") }
    try png.write(to: output)
    print("wrote \(output.path)")
}

/// The main window, chrome and all, at `-width` by `-height` points.
@MainActor
func shootWindow(output: URL) async throws {
    let defaults = UserDefaults.standard
    let settle = defaults.double(forKey: "settle") > 0 ? defaults.double(forKey: "settle") : 4
    let model = AppModel()
    model.load()
    let deadline = Date().addingTimeInterval(180)
    while model.snapshot == nil {
        if case .failed(let message) = model.state { throw ShotError(message: message) }
        guard Date() < deadline else { throw ShotError(message: "the graph didn't open in time") }
        try await Task.sleep(for: .milliseconds(200))
    }
    let size = NSSize(
        width: defaults.double(forKey: "width") > 0 ? defaults.double(forKey: "width") : 1400,
        height: defaults.double(forKey: "height") > 0 ? defaults.double(forKey: "height") : 860
    )
    // The web view stops `cacheDisplay` drawing anything, so this draws the SwiftUI tree itself.
    // The canvas comes out as a placeholder, and glass as plain fills.
    let root = RootView()
        .environment(model)
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .dark)
    // Let the graph's scene and the chrome's measurements settle before drawing.
    let hosting = NSHostingView(rootView: root)
    hosting.frame = NSRect(origin: .zero, size: size)
    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = hosting
    window.isReleasedWhenClosed = false
    try await Task.sleep(for: .seconds(settle))
    let renderer = ImageRenderer(content: root)
    renderer.scale = 2
    guard let image = renderer.cgImage else { throw ShotError(message: "couldn't draw the window") }
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ShotError(message: "couldn't encode the PNG") }
    try png.write(to: output)
    print("wrote \(output.path)")
}

/// The "Connect an AI model" screen a new install opens on, at `-width` by `-height` points. It
/// looks for Claude Code and servers on this Mac for real; `-claudeSignInPreview` doesn't apply here.
@MainActor
func shootFirstRun(output: URL) async throws {
    let defaults = UserDefaults.standard
    let settle = defaults.double(forKey: "settle") > 0 ? defaults.double(forKey: "settle") : 4
    let model = AppModel()
    let size = NSSize(
        width: defaults.double(forKey: "width") > 0 ? defaults.double(forKey: "width") : 1400,
        height: defaults.double(forKey: "height") > 0 ? defaults.double(forKey: "height") : 900
    )
    let root = ZStack {
        CanvasBackdrop()
        FirstRunView()
    }
    .environment(model)
    .frame(width: size.width, height: size.height)
    .preferredColorScheme(.dark)
    .tint(Palette.gold)
    let hosting = NSHostingView(rootView: root)
    hosting.frame = NSRect(origin: .zero, size: size)
    hosting.appearance = NSAppearance(named: .darkAqua)
    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = hosting
    window.isReleasedWhenClosed = false
    try await Task.sleep(for: .seconds(settle))
    hosting.layoutSubtreeIfNeeded()
    guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw ShotError(message: "couldn't make a bitmap") }
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ShotError(message: "couldn't encode the PNG") }
    try png.write(to: output)
    print("wrote \(output.path)")
}

/// The move sheet or the new folder sheet, on their own. `-moveItem personal/app -moveTo work`
/// shows a move; `-moveItem personal/app -moveName app2` a rename; `-folderName clients` fills the
/// new folder's name. The sheet checks for real (git, lsof) but nothing moves: no button is pressed.
@MainActor
func shootSheet(_ kind: String, output: URL) async throws {
    let defaults = UserDefaults.standard
    let model = AppModel()
    let settle = defaults.double(forKey: "settle") > 0 ? defaults.double(forKey: "settle") : 8
    let view: AnyView
    if kind == "usagesettings" {
        view = AnyView(UsageSettingsView())
    } else if kind == "claudesignin" {
        view = AnyView(ClaudeSignInSheet())
    } else if kind == "labels" {
        let map = model.folderMap()
        view = AnyView(LabelsSheet(kinds: map?.kinds ?? FolderPurpose.defaults, uses: { kind in map?.folders.filter { $0.purpose == kind }.count ?? 0 }) { _ in })
    } else if kind == "move" {
        guard let item = defaults.string(forKey: "moveItem") else { throw ShotError(message: "pass -moveItem <folder>") }
        let request = defaults.string(forKey: "moveTo").map { MoveRequest(item: item, newParent: $0) } ?? MoveRequest.rename(item, to: defaults.string(forKey: "moveName") ?? (item as NSString).lastPathComponent)
        let arrangement = await model.loadArrangement()
        view = AnyView(MoveSheet(start: request, arrangement: arrangement) { _ in })
    } else {
        view = AnyView(NewFolderSheet(initialName: defaults.string(forKey: "folderName") ?? "", initialRule: defaults.string(forKey: "folderRule") ?? "") { _ in })
    }
    let height = defaults.double(forKey: "height") > 0 ? defaults.double(forKey: "height") : (kind == "claudesignin" ? 400 : 720)
    let size = NSSize(width: kind == "move" || kind == "usagesettings" ? 540 : (kind == "labels" ? 680 : 500),
                      height: kind == "labels" ? 520 : (kind == "usagesettings" ? 640 : height))
    let root = view
        .environment(model)
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(Palette.panel)
        .preferredColorScheme(.dark)
        .tint(Palette.gold)
    let hosting = NSHostingView(rootView: root)
    hosting.frame = NSRect(origin: .zero, size: size)
    hosting.appearance = NSAppearance(named: .darkAqua)
    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = hosting
    window.isReleasedWhenClosed = false
    try await Task.sleep(for: .seconds(settle))
    hosting.layoutSubtreeIfNeeded()
    guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw ShotError(message: "couldn't make a bitmap") }
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ShotError(message: "couldn't encode the PNG") }
    try png.write(to: output)
    print("wrote \(output.path)")
}

// The tool has no bundle, so the AI models' logos come from the repo (shot.sh runs from its root).
MainActor.assumeIsolated {
    ModelBrand.logoFolder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("App/Resources/ModelLogos")
    ProviderMark.folder = ModelBrand.logoFolder
    // Never reads, writes the widgets' feed, or notifies.
    UsageFeed.isEnabled = false
    CodexLimits.readsLogs = false
    UsageRefresher.readsLimits = false
}

// Read Graphitree's own settings, such as which graph is open. Writes stay in this tool's domain.
UserDefaults.standard.addSuite(named: "com.marcuslai.Graphitree")
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = ShotDelegate()
app.delegate = delegate
app.run()

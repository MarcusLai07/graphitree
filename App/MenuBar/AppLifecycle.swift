import AppKit
import SwiftUI
import UserNotifications

/// Where a widget, notification or the menu bar wants the window to go. The main window's root
/// view takes the request when it appears, or at once if it's open.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    enum Request: Equatable {
        /// The Usage page, on a provider's plan when given.
        case usage(UsageProvider?)
        /// The Usage page with its menu bar and notification settings open.
        case usageSettings
        /// Just the window.
        case window
    }

    @Published var pending: Request?
    /// The Usage page shows its settings sheet while this is set.
    @Published var showsUsageSettings = false

    private init() {}

    /// `graphitree://usage?plan=codex`, `graphitree://usage/settings`, `graphitree://open`.
    static func request(for url: URL) -> Request? {
        guard url.scheme?.lowercased() == "graphitree" else { return nil }
        switch url.host?.lowercased() {
        case "usage":
            if url.path.lowercased().hasPrefix("/settings") { return .usageSettings }
            let plan = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "plan" }?.value
            return .usage(plan.flatMap(UsageProvider.init(rawValue:)))
        default:
            // graphitree://open, and anything this version doesn't know.
            return .window
        }
    }

    static func url(for provider: UsageProvider) -> URL {
        url(for: .usage(provider))
    }

    static func url(for request: Request) -> URL {
        switch request {
        case .usage(let provider?): return URL(string: "graphitree://usage?plan=\(provider.rawValue)")!
        case .usage(nil): return URL(string: "graphitree://usage")!
        case .usageSettings: return URL(string: "graphitree://usage/settings")!
        case .window: return URL(string: "graphitree://open")!
        }
    }

    func handle(_ url: URL) {
        if let request = Self.request(for: url) { pending = request }
    }

    /// Takes the pending request, once.
    func take() -> Request? {
        defer { pending = nil }
        return pending
    }
}

/// The main window, as its root view last saw it: what the menu bar brings back rather than
/// opening a second one.
@MainActor
enum MainWindow {
    static weak var current: NSWindow?
    /// Opens a new main window. Set by the menu bar's label, the one view that's always there
    /// while the menu bar is on.
    static var open: (() -> Void)?

    /// Sends a request, then brings the main window forward to take it, or opens one, and makes
    /// Graphitree the active app with its Dock icon.
    static func show(_ request: AppRouter.Request = .window) {
        AppRouter.shared.pending = request
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        if let window = current, window.isVisible || window.isMiniaturized {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else if let open {
            open()
        } else {
            // No menu bar to open it from: the request's link, sent to this copy of Graphitree
            // only, makes SwiftUI open a window for it.
            NSWorkspace.shared.open([AppRouter.url(for: request)], withApplicationAt: Bundle.main.bundleURL,
                                    configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

/// Reports the window a view is in, once it's in one.
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ReaderView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ReaderView: NSView {
        var onWindow: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindow?(window) }
        }
    }
}

/// While the menu bar item is on, Graphitree leaves the Dock when its last window closes and
/// comes back when one opens, as menu bar apps do. With the item off it stays in the Dock.
@MainActor
enum DockPresence {
    private static var observers: [NSObjectProtocol] = []

    static func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                if isAppWindow(window), NSApp.activationPolicy() != .regular {
                    NSApp.setActivationPolicy(.regular)
                }
            }
        })
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                guard isAppWindow(window) else { return }
                // After the window has gone.
                DispatchQueue.main.async { update(closing: window) }
            }
        })
    }

    /// A window of Graphitree's own: titled, at the normal level, and not a panel such as the
    /// menu bar's popover.
    static func isAppWindow(_ window: NSWindow) -> Bool {
        window.styleMask.contains(.titled) && !(window is NSPanel) && window.level == .normal
    }

    static func update(closing: NSWindow? = nil) {
        guard MenuBarSettings.shows else {
            if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
            return
        }
        let anyOpen = NSApp.windows.contains { $0 !== closing && isAppWindow($0) && ($0.isVisible || $0.isMiniaturized) }
        let policy: NSApplication.ActivationPolicy = anyOpen ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Started by the login job: no Dock icon until the window is opened.
        if MenuBarSettings.startsInMenuBar { NSApp.setActivationPolicy(.accessory) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            DockPresence.start()
            UsageFeed.shared.start()
            MenuBarSettings.repairLoginJob()
            if UsageAlerts.canNotify { UNUserNotificationCenter.current().delegate = self }
        }
    }

    /// Shows the alert while Graphitree is in front, too.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// Clicking an alert opens the Usage page on its plan.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let provider = (response.notification.request.content.userInfo["provider"] as? String).flatMap(UsageProvider.init(rawValue:))
        DispatchQueue.main.async {
            MainActor.assumeIsolated { MainWindow.show(.usage(provider)) }
        }
        completionHandler()
    }
}

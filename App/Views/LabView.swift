import AppKit
import SwiftUI
import WebKit

/// Which canvas the lab shows: the React one in a web view, or the native SwiftUI one.
enum LabFramework: String {
    case react, swiftUI = "swiftui"
}

/// Which route the Playbook lab window shows: "compose", "try/<library>" or a notes page, and
/// which framework's canvas. A Playbook card sets it, then opens the window.
@MainActor
@Observable
final class LabRouter {
    private(set) var route = "compose"
    /// Counts requests, so asking again for the route that was asked for last still goes back to
    /// it. The lab steps #/try/<library> back to #/compose once it has opened the library.
    private(set) var request = 0
    /// Remembered between launches.
    var framework: LabFramework {
        didSet { UserDefaults.standard.set(framework.rawValue, forKey: "lab.framework") }
    }

    init() {
        framework = UserDefaults.standard.string(forKey: "lab.framework").flatMap(LabFramework.init(rawValue:)) ?? .react
    }

    /// Opens a React route. Every library in the Playbook is a web library today.
    func show(_ route: String) {
        self.route = route
        request += 1
        framework = .react
    }
}

/// The Playbook lab window. The toolbar switches between two canvases:
/// - React: the lab page bundled in Resources (lab.html, lab.bundle.js, lab.css), in a web view
///   with no network access.
/// - SwiftUI: the native composer in App/Views/SwiftLab, drawn by Graphitree itself.
struct LabWindow: View {
    @Environment(LabRouter.self) private var router
    @State private var swiftCanvas = SwiftLabCanvas()

    var body: some View {
        @Bindable var router = router
        ZStack {
            // The web view stays alive behind the SwiftUI canvas, so switching back keeps its
            // canvas instead of reloading the page.
            Group {
                if let url = Bundle.main.url(forResource: "lab", withExtension: "html") {
                    LabWebView(url: url, route: router.route, request: router.request)
                } else {
                    Text("The React lab isn't in this build. Run npm run build:app in playground/, then build again.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .opacity(router.framework == .react ? 1 : 0)
            .allowsHitTesting(router.framework == .react)
            .accessibilityHidden(router.framework != .react)

            if router.framework == .swiftUI {
                SwiftLabComposer(canvas: swiftCanvas)
                    .background(Palette.panel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Canvas", selection: $router.framework) {
                    Text("React · Web").tag(LabFramework.react)
                    Text("SwiftUI · Mac").tag(LabFramework.swiftUI)
                }
                .pickerStyle(.segmented)
                .help("Which framework the canvas is built with")
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .preferredColorScheme(.dark)
    }
}

struct LabWebView: NSViewRepresentable {
    let url: URL
    let route: String
    let request: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        // The app is dark, so the lab starts dark. Its own toggle still switches to light.
        webView.appearance = NSAppearance(named: .darkAqua)
        #if DEBUG
        webView.isInspectable = true
        #endif
        var start = URLComponents(url: url, resolvingAgainstBaseURL: false)
        start?.fragment = "/" + LabCatalog.safeRoute(route)
        webView.loadFileURL(start?.url ?? url, allowingReadAccessTo: url.deletingLastPathComponent())
        context.coordinator.shownRequest = request
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.shownRequest != request else { return }
        context.coordinator.shownRequest = request
        webView.evaluateJavaScript("location.hash = '#/\(LabCatalog.safeRoute(route))'")
    }

    /// Links to a library's site open in the browser, not inside the lab.
    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var shownRequest = -1

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url, Self.isExternal(url) else { return .allow }
            NSWorkspace.shared.open(url)
            return .cancel
        }

        /// `target="_blank"` links ask for a new web view instead of navigating.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url, Self.isExternal(url) { NSWorkspace.shared.open(url) }
            return nil
        }

        private static func isExternal(_ url: URL) -> Bool {
            ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "")
        }
    }
}

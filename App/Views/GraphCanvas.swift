import SwiftUI
import WebKit

enum GraphLayout: String, CaseIterable, Identifiable {
    case links, circle, rings, areas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .links: return "Links"
        case .circle: return "Circle"
        case .rings: return "Rings"
        case .areas: return "Areas"
        }
    }

    var symbol: String {
        switch self {
        case .links: return "point.3.filled.connected.trianglepath.dotted"
        case .circle: return "circle.dotted"
        case .rings: return "circle.circle"
        case .areas: return "circle.grid.cross"
        }
    }

    /// Rings draw a level with its children's children, so they need their own scene.
    var needsRingScene: Bool { self == .rings }
}

/// A request to select a node and move the camera onto it, once it's drawn.
struct GraphFocus: Equatable {
    let id: String
    var movesCamera = true
    let token = UUID()
}

/// A request to zoom one step.
struct GraphZoom: Equatable {
    let zoomsIn: Bool
    let token = UUID()
}

/// How much of the canvas the floating panels cover, so the graph centres in what's left.
struct GraphInsets: Equatable, Encodable {
    var left: Double
    var right: Double
    var top: Double
    var bottom: Double
}

enum GraphCanvasEvent {
    case select(String)
    case clear
    case drill(String)
    case failed(String)
}

/// Draws a `GraphScene`. Everything renderer-specific stays behind this view and its events,
/// so a Metal implementation can replace it without touching `GraphView`.
struct GraphCanvas: NSViewRepresentable {
    let scene: GraphScene?
    let sceneID: String
    let layout: GraphLayout
    let showsLabels: Bool
    let isolatedGroup: Int?
    let focus: GraphFocus?
    let fitRequest: Int
    let zoom: GraphZoom?
    let insets: GraphInsets
    let reducesMotion: Bool
    let isReviewing: Bool
    let spotlight: [String]?
    let onEvent: (GraphCanvasEvent) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "studio")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.appearance = NSAppearance(named: .darkAqua)
        #if DEBUG
        webView.isInspectable = true
        #endif
        context.coordinator.webView = webView
        if let url = Bundle.main.url(forResource: "graph", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onEvent = onEvent
        context.coordinator.update(
            scene: scene,
            sceneID: sceneID,
            layout: layout,
            showsLabels: showsLabels,
            isolatedGroup: isolatedGroup,
            focus: focus,
            fitRequest: fitRequest,
            zoom: zoom,
            insets: insets,
            reducesMotion: reducesMotion,
            isReviewing: isReviewing,
            spotlight: spotlight
        )
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "studio")
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var onEvent: ((GraphCanvasEvent) -> Void)?

        private var isReady = false
        private var scene: GraphScene?
        private var sceneID = ""
        private var renderedSceneID: String?
        private var renderedRingScene = false
        private var layout = GraphLayout.links
        private var sentLayout: GraphLayout?
        private var showsLabels = true
        private var sentLabels: Bool?
        private var isolatedGroup: Int?
        private var sentIsolation: Int?
        private var focus: GraphFocus?
        private var sentFocus: GraphFocus?
        private var fitRequest = 0
        private var sentFit = 0
        private var zoom: GraphZoom?
        private var sentZoom: GraphZoom?
        private var insets = GraphInsets(left: 0, right: 0, top: 0, bottom: 0)
        private var sentInsets: GraphInsets?
        private var reducesMotion = false
        private var sentReducesMotion: Bool?
        private var isReviewing = false
        private var sentReviewing: Bool?
        private var spotlight: [String]?
        private var sentSpotlight: [String]??

        func update(
            scene: GraphScene?,
            sceneID: String,
            layout: GraphLayout,
            showsLabels: Bool,
            isolatedGroup: Int?,
            focus: GraphFocus?,
            fitRequest: Int,
            zoom: GraphZoom?,
            insets: GraphInsets,
            reducesMotion: Bool,
            isReviewing: Bool,
            spotlight: [String]?
        ) {
            self.scene = scene
            self.sceneID = sceneID
            self.layout = layout
            self.showsLabels = showsLabels
            self.isolatedGroup = isolatedGroup
            self.focus = focus
            self.fitRequest = fitRequest
            self.zoom = zoom
            self.insets = insets
            self.reducesMotion = reducesMotion
            self.isReviewing = isReviewing
            self.spotlight = spotlight
            flush()
        }

        /// A JavaScript string literal, so IDs with quotes or slashes can't break the call.
        private func literal(_ text: String) -> String {
            (try? JSONEncoder().encode(text)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        }

        private func flush() {
            guard isReady, let webView else { return }
            // Insets go first, so the first drawing already centres in the free space.
            if sentInsets != insets, let data = try? JSONEncoder().encode(insets), let json = String(data: data, encoding: .utf8) {
                sentInsets = insets
                webView.evaluateJavaScript("window.studio.setInsets(\(json)); void 0")
            }
            if sentReducesMotion != reducesMotion {
                sentReducesMotion = reducesMotion
                webView.evaluateJavaScript("window.studio.setMotion(\(!reducesMotion)); void 0")
            }
            if sentReviewing != isReviewing {
                sentReviewing = isReviewing
                webView.evaluateJavaScript("window.studio.setReviewing(\(isReviewing)); void 0")
            }
            if let scene, renderedSceneID != sceneID,
               let data = try? JSONEncoder().encode(scene),
               let json = String(data: data, encoding: .utf8) {
                renderedSceneID = sceneID
                renderedRingScene = scene.nodes.contains { $0.ring != nil }
                sentIsolation = nil
                sentLayout = layout
                webView.evaluateJavaScript("window.studio.render(\(json), \(literal(layout.rawValue)), \(isReviewing)); void 0")
            } else if sentLayout != layout, renderedSceneID != nil, layout.needsRingScene == renderedRingScene {
                // Switching to or from Rings waits for its own scene instead of re-laying the old one.
                sentLayout = layout
                webView.evaluateJavaScript("window.studio.setLayout(\(literal(layout.rawValue))); void 0")
            }
            if sentLabels != showsLabels {
                sentLabels = showsLabels
                webView.evaluateJavaScript("window.studio.setLabels(\(showsLabels)); void 0")
            }
            // Focus waits until the drawn scene contains the node.
            if let focus, sentFocus != focus, renderedSceneID == sceneID,
               scene?.nodes.contains(where: { $0.id == focus.id }) == true {
                sentFocus = focus
                webView.evaluateJavaScript("window.studio.focus(\(literal(focus.id)), \(focus.movesCamera)); void 0")
            }
            if sentIsolation != isolatedGroup {
                sentIsolation = isolatedGroup
                webView.evaluateJavaScript("window.studio.isolate(\(isolatedGroup.map(String.init) ?? "null")); void 0")
            }
            if sentSpotlight != .some(spotlight) {
                sentSpotlight = .some(spotlight)
                let ids = spotlight.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) } ?? "null"
                webView.evaluateJavaScript("window.studio.spotlight(\(ids)); void 0")
            }
            if sentFit != fitRequest {
                sentFit = fitRequest
                webView.evaluateJavaScript("window.studio.fit(); void 0")
            }
            if let zoom, sentZoom != zoom {
                sentZoom = zoom
                webView.evaluateJavaScript("window.studio.zoom(\(zoom.zoomsIn)); void 0")
            }
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "ready":
                isReady = true
                flush()
            case "select":
                if let id = body["id"] as? String { onEvent?(.select(id)) }
            case "clear":
                onEvent?(.clear)
            case "drill":
                if let id = body["id"] as? String { onEvent?(.drill(id)) }
            case "error":
                onEvent?(.failed(body["message"] as? String ?? "The graph couldn't be drawn."))
            default:
                break
            }
        }
    }
}

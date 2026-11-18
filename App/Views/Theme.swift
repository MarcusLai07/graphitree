import AppKit
import SwiftUI

/// The dark field the graph floats on. The web view above it is transparent.
struct CanvasBackdrop: View {
    var body: some View {
        ZStack {
            Palette.ink
            RadialGradient(
                colors: [Palette.canvasGlow.opacity(0.55), Palette.canvasGlow.opacity(0.22), .clear],
                center: UnitPoint(x: 0.47, y: 0.5),
                startRadius: 0,
                endRadius: 680
            )
        }
    }
}

private struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reducesTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if reducesTransparency {
                content
                    .background(Palette.panel, in: shape)
                    .overlay(shape.strokeBorder(Palette.hairline))
            } else if #available(macOS 26.0, *) {
                content.glassEffect(.regular.tint(Palette.panel.opacity(0.6)), in: shape)
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(shape.strokeBorder(Palette.hairline))
            }
        }
        // Clicks on a panel's empty areas must not reach the graph underneath.
        .contentShape(shape)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }
}

/// A square or labelled button in the floating chrome. `isOn` draws the gold selected state.
struct ChromeButtonStyle: ButtonStyle {
    var isOn = false

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, isOn: isOn)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let isOn: Bool
        @State private var isHovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
            configuration.label
                .font(.callout.weight(.medium))
                .foregroundStyle(isOn ? Palette.gold : (isHovering ? Color.primary : Color.secondary))
                .frame(minWidth: 30, minHeight: 30)
                .background(isOn ? Palette.gold.opacity(0.14) : Color.white.opacity(isHovering ? 0.07 : 0), in: shape)
                .overlay {
                    if isOn { shape.strokeBorder(Palette.gold.opacity(0.28)) }
                }
                .contentShape(shape)
                // A disabled button has to look it, or it reads as broken.
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
                .onHover { isHovering = $0 }
        }
    }
}

/// The one main action in a group.
struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GoldButton(configuration: configuration)
    }

    /// Dims when disabled, so the one main action never looks ready when it isn't.
    private struct GoldButton: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color(hex: 0x1B1408))
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background(
                    LinearGradient(colors: [Color(hex: 0xF6DC9F), Color(hex: 0xE9C272)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
        }
    }
}

/// A quiet button that sits on glass.
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            configuration.label
                .font(.callout.weight(.medium))
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.06), in: shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.1)))
                .contentShape(shape)
                .opacity(isEnabled ? 1 : 0.4)
        }
    }
}

struct BrandMark: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: 0xFBF1DA), Palette.gold, Color(hex: 0x6E5B33)],
                    center: UnitPoint(x: 0.34, y: 0.3),
                    startRadius: 0,
                    endRadius: 11
                )
            )
            .frame(width: 16, height: 16)
            .shadow(color: Palette.gold.opacity(0.55), radius: 5)
            .accessibilityHidden(true)
    }
}

/// Empty chrome that moves the window like a title bar. Double-clicking does what the
/// title bar's double-click setting in System Settings says.
struct WindowDragArea: View {
    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
            .simultaneousGesture(TapGesture(count: 2).onEnded(Self.titleBarDoubleClick))
            .allowsWindowActivationEvents(true)
    }

    private static func titleBarDoubleClick() {
        guard let window = NSApp.keyWindow else { return }
        switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
        case "Minimize": window.miniaturize(nil)
        case "None": break
        default: window.zoom(nil)
        }
    }
}

/// A thin vertical rule between groups in a pill.
struct ChromeDivider: View {
    var body: some View {
        Rectangle().fill(Palette.hairline).frame(width: 1, height: 18)
    }
}

private struct ClosePanelKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private struct ShowOnMapKey: EnvironmentKey {
    static let defaultValue: ((OutlineItem.Kind) -> Void)? = nil
}

extension EnvironmentValues {
    /// Closes the panel and shows a project, community, file or symbol on the map. Nil where
    /// there's no map, such as in screenshots.
    var showOnMap: ((OutlineItem.Kind) -> Void)? {
        get { self[ShowOnMapKey.self] }
        set { self[ShowOnMapKey.self] = newValue }
    }

    /// Closes the floating panel this view is in.
    var closePanel: () -> Void {
        get { self[ClosePanelKey.self] }
        set { self[ClosePanelKey.self] = newValue }
    }
}

/// The title row of a floating panel: its name, its actions, and a close button.
struct PanelHeader<Actions: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var actions: Actions

    @Environment(\.closePanel) private var close

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.title3.weight(.semibold)).lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            actions
            Button("Close", systemImage: "xmark", action: close)
                .labelStyle(.iconOnly)
                .buttonStyle(ChromeButtonStyle())
                .keyboardShortcut(.cancelAction)
                .help("Close (Esc)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

extension PanelHeader where Actions == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

extension View {
    /// The tile behind a card, without padding: for cards laid out edge to edge inside, such as a
    /// strip of figures or a table.
    func cardSurface() -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return background(Palette.card, in: shape).overlay(shape.strokeBorder(Palette.cardStroke))
    }
}

/// The card behind each row in the AI Models panel, the setup wizard and Usage.
struct RowCard: ViewModifier {
    var padding: CGFloat = 12

    func body(content: Content) -> some View {
        content.padding(padding).cardSurface()
    }
}

import AppKit
import SwiftUI

/// Walking one detector's findings on the canvas.
struct ReviewSession: Equatable {
    struct Decision: Equatable {
        let findingID: String
        let rejected: Bool
    }

    let detector: Detector
    var currentID: String?
    var kept = 0
    var rejected = 0
    /// Only this session's decisions, so undo never reaches back into earlier work.
    var history: [Decision] = []
}

struct ReviewActions {
    let previous: () -> Void
    let next: () -> Void
    let reject: () -> Void
    let keep: () -> Void
    let undo: () -> Void
    let list: () -> Void
    let exit: () -> Void
    let writeClean: () -> Void
}

/// The bar at the bottom of the canvas while reviewing.
struct ReviewHUD: View {
    let session: ReviewSession
    let finding: Finding?
    let position: Int
    let remaining: Int
    let canWriteClean: Bool
    let actions: ReviewActions

    private var rejectTitle: String { session.detector == .crossProject ? "Reject" : "Hide" }

    private var progress: Double {
        let decided = session.kept + session.rejected
        let total = decided + remaining
        return total == 0 ? 1 : Double(decided) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ProgressLine(fraction: progress)
            if let finding {
                current(finding)
                controls
            } else {
                finished
            }
        }
        .padding(14)
        .frame(width: 580)
        .glassPanel(cornerRadius: 16)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: session.detector.symbol).foregroundStyle(Palette.gold)
            Text("Reviewing \(session.detector.title)").font(.callout.weight(.semibold))
            if finding != nil {
                Text("\(position.formatted()) of \(remaining.formatted())")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text("\(session.kept.formatted()) kept · \(session.rejected.formatted()) \(session.detector == .crossProject ? "rejected" : "hidden")")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func current(_ finding: Finding) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(finding.title)
                .font(.system(.title3, design: .monospaced).weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Text(([finding.affects] + (finding.note.isEmpty ? [] : [finding.note]) + [finding.location]).joined(separator: " · "))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // Only the two decisions carry words. The rest are icons with their key beside them.
    private var controls: some View {
        HStack(spacing: 6) {
            HUDButton(title: "Previous", symbol: "chevron.left", key: "K", showsTitle: false, action: actions.previous)
            HUDButton(title: "Next", symbol: "chevron.right", key: "J", showsTitle: false, action: actions.next)
            HUDButton(title: "Undo", symbol: "arrow.uturn.backward", key: "U", showsTitle: false, action: actions.undo)
                .disabled(session.history.isEmpty)
            Spacer(minLength: 8)
            HUDButton(title: "Keep", symbol: "checkmark", key: "A", action: actions.keep)
                .help("Keep it. It won't come back as a finding. (A)")
            HUDButton(title: rejectTitle, symbol: session.detector == .crossProject ? "link.badge.plus" : "eye.slash", key: "X", isPrimary: true, action: actions.reject)
                .help("Save a rule. You can undo it. (X)")
            Spacer(minLength: 8)
            HUDButton(title: "Open List", symbol: "list.bullet", key: "L", showsTitle: false, action: actions.list)
            HUDButton(title: "Stop Reviewing", symbol: "xmark", key: "esc", showsTitle: false, action: actions.exit)
        }
    }

    private var finished: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing left to review").font(.title3.weight(.semibold))
                Text(canWriteClean
                    ? "Write the clean graph to use your decisions in queries."
                    : "Every finding here has been decided.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if !session.history.isEmpty {
                HUDButton(title: "Undo", symbol: "arrow.uturn.backward", key: "U", showsTitle: false, action: actions.undo)
            }
            if canWriteClean {
                Button("Write Clean Graph", action: actions.writeClean).buttonStyle(GoldButtonStyle())
            }
            HUDButton(title: "Done", symbol: "xmark", key: "esc", action: actions.exit)
        }
    }
}

private struct ProgressLine: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(Palette.gold).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

/// A labelled button with its single-key shortcut shown beside it.
private struct HUDButton: View {
    let title: String
    let symbol: String
    let key: String
    var showsTitle = true
    var isPrimary = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                if showsTitle { Text(title).fixedSize() }
                KeyCap(key, isOnGold: isPrimary)
            }
        }
        .buttonStyle(HUDButtonStyle(isPrimary: isPrimary))
        .help(showsTitle ? "" : "\(title) (\(key))")
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(title)
        .accessibilityHint("Shortcut \(key)")
    }
}

private struct HUDButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        if isPrimary {
            GoldButtonStyle().makeBody(configuration: configuration)
        } else {
            SoftButtonStyle().makeBody(configuration: configuration)
        }
    }
}

struct KeyCap: View {
    let key: String
    var isOnGold = false

    init(_ key: String, isOnGold: Bool = false) {
        self.key = key
        self.isOnGold = isOnGold
    }

    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(isOnGold ? Color(hex: 0x1B1408).opacity(0.7) : Color.secondary)
            .padding(.horizontal, 4)
            .frame(minWidth: 16, minHeight: 16)
            .background(
                RoundedRectangle(cornerRadius: 4).strokeBorder(isOnGold ? Color(hex: 0x1B1408).opacity(0.3) : Color.white.opacity(0.18))
            )
    }
}

/// Watches key presses while active. The handler returns true when it used the key.
private final class KeyHandlerBox {
    var handler: ((NSEvent) -> Bool)?
}

private struct KeyMonitorModifier: ViewModifier {
    let isActive: Bool
    let handler: (NSEvent) -> Bool

    @State private var box = KeyHandlerBox()
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        box.handler = handler
        return content
            .onAppear { sync() }
            .onChange(of: isActive) { sync() }
            .onDisappear { stop() }
    }

    private func sync() {
        if isActive, monitor == nil {
            let box = box
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                (box.handler?(event) ?? false) ? nil : event
            }
        } else if !isActive {
            stop()
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

extension View {
    func onKeyDown(isActive: Bool, _ handler: @escaping (NSEvent) -> Bool) -> some View {
        modifier(KeyMonitorModifier(isActive: isActive, handler: handler))
    }
}

enum KeyCode {
    static let returnKey: UInt16 = 36
    static let enter: UInt16 = 76
    static let escape: UInt16 = 53
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    static let down: UInt16 = 125
    static let up: UInt16 = 126

    /// True for a key pressed on its own, without Command, Control or Option.
    static func isPlain(_ event: NSEvent) -> Bool {
        event.modifierFlags.intersection([.command, .control, .option]).isEmpty
    }

    /// True while a text field is being edited, when single-letter shortcuts must stay out of the way.
    static var isEditingText: Bool {
        NSApp.keyWindow?.firstResponder is NSText
    }
}

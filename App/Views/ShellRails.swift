import SwiftUI

/// The left rail: the way into every screen that isn't the graph.
struct NavigationRail: View {
    let snapshot: WorkspaceSnapshot
    @Binding var panel: ShellPanel?
    var isSetUp = true
    var isRebuilding = false
    var hasWaitingPass = false
    /// What builds the graph, shown at the end of the AI Models row.
    var builder: BuilderBadge = .codeOnly
    var builderHelp = ""

    @ObservedObject private var usage = UsageRefresher.shared

    private var data: OverviewData { snapshot.overview }

    private var builtAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: data.builtAt, relativeTo: .now)
    }

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return data.graphPath.hasPrefix(home) ? "~" + data.graphPath.dropFirst(home.count) : data.graphPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 1) {
                buildRow
                row("Folders", symbol: "folder", target: .folders(nil), isOn: isFoldersOpen)
                    .help("Browse every node, arrange folders and back them up")
                row("AI Models", symbol: "brain.head.profile", target: .agents) { builderBadge }
                    .help(builderHelp)
                row("Usage", symbol: "gauge.with.dots.needle.33percent", target: .usage) { usageBadge }
                    .help(usageHelp)
                row("Playbook", symbol: "books.vertical", target: .playbook)
                row("Insights", symbol: "chart.bar.xaxis", target: .insights)
            }
            Text("Built \(builtAgo)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .help("\(displayPath), built \(data.builtAt.formatted(date: .abbreviated, time: .shortened))")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private var isFoldersOpen: Bool {
        if case .folders = panel { return true }
        return false
    }

    /// Build shows whether it's running, or that the graph still needs its setup.
    private var buildRow: some View {
        row("Build", symbol: "hammer", target: .build) {
            if isRebuilding {
                ProgressView().controlSize(.mini)
            } else if hasWaitingPass {
                Text("Waiting").font(.caption).foregroundStyle(Palette.gold)
            } else if !isSetUp {
                Text("Set up").font(.caption).foregroundStyle(Palette.gold)
            }
        }
    }

    /// The logo of whatever builds the graph, with a dot when it needs attention.
    @ViewBuilder
    private var builderBadge: some View {
        switch builder {
        case .connect:
            Text("Connect").font(.caption).foregroundStyle(Palette.gold)
        case .codeOnly:
            Text("Code only").font(.caption).foregroundStyle(.tertiary)
        case .model(let id, let level):
            ModelLogo(id: id, size: 16, level: level)
        }
    }

    /// The session limit's figure once there's a reading, coloured as it nears the limit.
    @ViewBuilder
    private var usageBadge: some View {
        if let percent = usage.snapshot?.session?.utilization {
            Text("\(Int(percent.rounded()))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(percent >= 70 ? AnyShapeStyle(usageColor(percent)) : AnyShapeStyle(.tertiary))
        }
    }

    private var usageHelp: String {
        guard let session = usage.snapshot?.session?.utilization else {
            return "Claude's plan limits, and what Claude Code used on this Mac"
        }
        var text = "Session limit \(Int(session.rounded()))% used"
        if let weekly = usage.snapshot?.weekly?.utilization { text += ", weekly \(Int(weekly.rounded()))%" }
        return text
    }

    private func row(_ title: String, symbol: String, target: ShellPanel, isOn: Bool? = nil) -> some View {
        row(title, symbol: symbol, target: target, isOn: isOn) { EmptyView() }
    }

    /// `isOn` is for a row that stands for more than one panel. Clicking a lit row closes it.
    private func row<Trailing: View>(_ title: String, symbol: String, target: ShellPanel, isOn: Bool? = nil, @ViewBuilder trailing: () -> Trailing) -> some View {
        let isOn = isOn ?? (panel == target)
        return Button {
            panel = isOn ? nil : target
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol).frame(width: 16).foregroundStyle(.secondary)
                Text(title).lineLimit(1)
                Spacer(minLength: 6)
                trailing()
            }
        }
        .buttonStyle(RailRowStyle(isOn: isOn))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A quiet strip under the top bar: how noisy the graph is, and a way into each cleanup check.
/// It stays out of the way, because most people use the graph more than they tidy it.
struct HealthBar: View {
    let snapshot: WorkspaceSnapshot
    let panel: ShellPanel?
    let reviewing: Detector?
    let toggleReview: (Detector) -> Void
    let hoverDetector: (Detector?) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reducesTransparency

    private var data: OverviewData { snapshot.overview }

    private var noisePercent: String {
        data.noiseShare.formatted(.percent.precision(.fractionLength(0)))
    }

    private func count(for detector: Detector) -> Int {
        switch detector {
        case .generated: return data.generatedOrVendoredNodes
        case .crossProject: return data.suspectCrossEdges
        case .duplicates: return snapshot.count(.duplicates)
        case .missing: return data.missingFiles
        case .configLabels: return snapshot.count(.configLabels)
        case .isolated: return data.isolatedNodes
        case .noSource: return data.nodesWithoutSource
        }
    }

    /// How much of each check's name fits.
    private enum Naming { case full, short, none }

    var body: some View {
        // The widest version that fits the window: full names, then short ones, then icons.
        ViewThatFits(in: .horizontal) {
            strip(.full)
            strip(.short)
            strip(.none)
        }
    }

    private func strip(_ naming: Naming) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return HStack(spacing: 1) {
            summary
            Rectangle().fill(Palette.hairline).frame(width: 1, height: 14).padding(.horizontal, 7)
            ForEach(Detector.allCases) { detector in
                chip(detector, naming: naming)
            }
        }
        .padding(.horizontal, 3)
        .frame(height: 30)
        .background(reducesTransparency ? Palette.panel : Palette.panel.opacity(0.55), in: shape)
        .overlay(shape.strokeBorder(Palette.hairline))
        .contentShape(shape)
        .fixedSize()
    }

    private var summary: some View {
        HStack(spacing: 6) {
            Text("Health").foregroundStyle(.tertiary)
            Text(noisePercent).monospacedDigit()
            Text("noise").foregroundStyle(.secondary)
            HealthMeter(fraction: data.noiseShare, height: 4).frame(width: 34)
        }
        .font(.subheadline)
        .padding(.leading, 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Graph health")
        .accessibilityValue("\(noisePercent) likely noise")
        .help("\(data.noiseNodes.formatted()) of \(data.visibleNodes.formatted()) nodes are generated, vendored or from missing files.")
    }

    /// Starts review mode for a check. Hovering lights up its projects on the map.
    private func chip(_ detector: Detector, naming: Naming) -> some View {
        let isOn = reviewing == detector || panel == .detector(detector)
        let total = count(for: detector)
        return Button {
            toggleReview(detector)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: detector.symbol).foregroundStyle(isOn ? Palette.gold : .secondary)
                switch naming {
                case .full: Text(detector.title).lineLimit(1)
                case .short: Text(detector.shortTitle).lineLimit(1)
                case .none: EmptyView()
                }
                Text(total.formatted())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            // Nothing to review reads as done, not as a control to reach for.
            .opacity(total == 0 && !isOn ? 0.5 : 1)
        }
        .buttonStyle(HealthChipStyle(isOn: isOn))
        .onHover { hoverDetector($0 ? detector : nil) }
        .help(reviewing == detector ? "Stop reviewing" : "\(detector.title): review them one at a time")
        .accessibilityLabel(detector.title)
        .accessibilityValue(total.formatted())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private extension Detector {
    /// The name when the full one doesn't fit the window.
    var shortTitle: String {
        switch self {
        case .generated: return "Generated"
        case .crossProject: return "Cross-project"
        case .duplicates: return "Duplicates"
        case .missing: return "Missing"
        case .configLabels: return "Config"
        case .isolated: return "Isolated"
        case .noSource: return "No source"
        }
    }
}

private struct HealthChipStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, isOn: isOn)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let isOn: Bool
        @State private var isHovering = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
            configuration.label
                .font(.subheadline)
                .foregroundStyle(isOn || isHovering ? Color.primary : Color.secondary)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(isOn ? Palette.gold.opacity(0.13) : Color.white.opacity(isHovering ? 0.06 : 0), in: shape)
                .overlay {
                    if isOn { shape.strokeBorder(Palette.gold.opacity(0.26)) }
                }
                .contentShape(shape)
                .opacity(configuration.isPressed ? 0.75 : 1)
                .onHover { isHovering = $0 }
        }
    }
}

private struct RailRowStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, isOn: isOn)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let isOn: Bool
        @State private var isHovering = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            configuration.label
                .padding(.horizontal, 8)
                .frame(height: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isOn ? Palette.gold.opacity(0.13) : Color.white.opacity(isHovering ? 0.06 : 0), in: shape)
                .overlay {
                    if isOn { shape.strokeBorder(Palette.gold.opacity(0.26)) }
                }
                .contentShape(shape)
                .onHover { isHovering = $0 }
        }
    }
}

private struct HealthMeter: View {
    let fraction: Double
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(Palette.gold)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
    }
}

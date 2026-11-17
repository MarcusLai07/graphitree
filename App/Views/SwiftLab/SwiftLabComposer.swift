import AppKit
import SwiftUI

/// The SwiftUI canvas's state: the blocks, the canvas settings and the selection. Saved in the
/// app's defaults, so the canvas is there the next time the lab opens.
@MainActor
@Observable
final class SwiftLabCanvas {
    private(set) var blocks: [SwiftBlock] = [] { didSet { save() } }
    var settings = SwiftLabSettings() { didSet { save() } }
    var selected: UUID?
    /// What Clear removed, so it can come back.
    private(set) var cleared: [SwiftBlock]?

    private let defaults: UserDefaults?
    private static let key = "swiftLab.canvas.v1"

    private struct Saved: Codable {
        var blocks: [SwiftBlock]
        var settings: SwiftLabSettings
    }

    /// `defaults: nil` keeps the canvas in memory only, for screenshots.
    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        guard let data = defaults?.data(forKey: Self.key), let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        // Drop blocks whose adapter is gone, and fill in options added since they were saved.
        blocks = saved.blocks.compactMap { block in
            guard let adapter = SwiftLab.adapterByID[block.adapter] else { return nil }
            var block = block
            block.options = SwiftLab.carryOver(block.options, to: adapter)
            return block
        }
        settings = saved.settings
    }

    private func save() {
        guard let defaults, let data = try? JSONEncoder().encode(Saved(blocks: blocks, settings: settings)) else { return }
        defaults.set(data, forKey: Self.key)
    }

    var reduceMotion: Bool { settings.reduceMotion }

    func add(_ slot: SwiftSlot) {
        guard let adapter = SwiftLab.best(for: slot, settings: settings) else { return }
        let block = SwiftLab.block(adapter)
        blocks.append(block)
        selected = block.id
    }

    func remove(_ id: UUID) {
        blocks.removeAll { $0.id == id }
        if selected == id { selected = nil }
    }

    func move(_ id: UUID, by offset: Int) {
        guard let index = blocks.firstIndex(where: { $0.id == id }), blocks.indices.contains(index + offset) else { return }
        blocks.swapAt(index, index + offset)
    }

    func duplicate(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        var copy = blocks[index]
        copy.id = UUID()
        blocks.insert(copy, at: index + 1)
        selected = copy.id
    }

    func setAdapter(_ adapter: SwiftAdapter, for id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].options = SwiftLab.carryOver(blocks[index].options, to: adapter)
        blocks[index].adapter = adapter.id
    }

    func setOption(_ option: String, to value: LabValue, for id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].options[option] = value
    }

    func clear() {
        guard !blocks.isEmpty else { return }
        cleared = blocks
        blocks = []
        selected = nil
    }

    func undoClear() {
        guard let cleared else { return }
        blocks = cleared
        self.cleared = nil
    }

    func start(_ starter: SwiftLab.Starter) {
        blocks = starter.slots.compactMap { SwiftLab.best(for: $0, settings: settings).map(SwiftLab.block) }
        selected = nil
        cleared = nil
    }

    func issues(for block: SwiftBlock) -> [LabIssue] {
        guard let adapter = SwiftLab.adapterByID[block.adapter] else { return [] }
        return SwiftLab.issues(for: adapter, settings: settings)
    }
}

/// The SwiftUI canvas of the Playbook lab: add components on the left, see them on the canvas,
/// pick how each is built on the right.
struct SwiftLabComposer: View {
    @State private var canvas: SwiftLabCanvas

    init(canvas: SwiftLabCanvas) {
        _canvas = State(initialValue: canvas)
    }

    var body: some View {
        HStack(spacing: 0) {
            SwiftLabRail(canvas: canvas)
                .frame(width: 248)
            Divider()
            SwiftLabCanvasView(canvas: canvas)
                .frame(maxWidth: .infinity)
            Divider()
            SwiftLabInspector(canvas: canvas)
                .frame(width: 330)
        }
    }
}

// MARK: - Shared pieces

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}

private struct IssueRows: View {
    let issues: [LabIssue]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                Label {
                    Text(LocalizedStringKey(issue.text))
                } icon: {
                    Image(systemName: Self.symbol(issue.severity))
                }
                .font(.caption)
                .foregroundStyle(Self.color(issue.severity))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    static func symbol(_ severity: LabIssue.Severity) -> String {
        switch severity {
        case .blocked: "nosign"
        case .warn: "exclamationmark.triangle"
        case .info: "info.circle"
        }
    }

    static func color(_ severity: LabIssue.Severity) -> Color {
        switch severity {
        case .blocked: Palette.coral
        case .warn: .orange
        case .info: .secondary
        }
    }
}

private struct MinOSBadge: View {
    let minOS: Int
    let target: Int
    var body: some View {
        Text("macOS \(minOS)+")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(minOS > target ? Color.orange : Color.secondary)
            .background(Capsule().strokeBorder(minOS > target ? Color.orange.opacity(0.6) : Color.secondary.opacity(0.35)))
    }
}

private func copyToPasteboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

// MARK: - Rail

private struct SwiftLabRail: View {
    @Bindable var canvas: SwiftLabCanvas

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("Add a component")
                    ForEach(SwiftSlot.groups, id: \.self) { group in
                        let slots = SwiftSlot.allCases.filter { $0.group == group && !SwiftLab.adapters(for: $0).isEmpty }
                        if !slots.isEmpty {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(group).font(.caption).foregroundStyle(.tertiary).padding(.leading, 6)
                                ForEach(slots, id: \.self) { slot in
                                    RailButton(slot: slot, count: SwiftLab.adapters(for: slot).count) { add(slot) }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("This app")
                    labelled("Deployment target (macOS)") {
                        Picker("Deployment target", selection: $canvas.settings.target) {
                            ForEach(SwiftLabSettings.targets, id: \.self) { Text("\($0)").tag($0) }
                        }
                    }
                    labelled("Appearance") {
                        Picker("Appearance", selection: $canvas.settings.appearance) {
                            ForEach(LabAppearance.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("Extras")
                    labelled("Animation") {
                        Picker("Animation", selection: $canvas.settings.motionStyle) {
                            ForEach(LabAnimation.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                    labelled("Entrance") {
                        Picker("Entrance", selection: $canvas.settings.entrance) {
                            ForEach(LabEntrance.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                    Toggle(isOn: $canvas.settings.reduceMotion) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Reduce motion")
                            Text("Acts like the macOS setting").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    labelled("Control size") {
                        Picker("Control size", selection: $canvas.settings.controlSize) {
                            ForEach(LabControlSize.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                    labelled("Tint") {
                        HStack(spacing: 6) {
                            ForEach(LabTint.allCases, id: \.self) { tint in
                                Button { canvas.settings.tint = tint } label: {
                                    Circle()
                                        .fill(tint.color ?? Color.accentColor)
                                        .frame(width: 18, height: 18)
                                        .overlay(Circle().strokeBorder(.primary.opacity(canvas.settings.tint == tint ? 0.9 : 0), lineWidth: 2).padding(-3))
                                }
                                .buttonStyle(.plain)
                                .help(tint.label)
                                .accessibilityLabel(tint.label)
                                .accessibilityAddTraits(canvas.settings.tint == tint ? .isSelected : [])
                            }
                        }
                        .padding(.leading, 3)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .pickerStyle(.segmented)
    }

    private func add(_ slot: SwiftSlot) {
        let reduce = canvas.settings.reduceMotion || canvas.settings.entrance == .none
        withAnimation(reduce ? nil : canvas.settings.motionStyle.animation) { canvas.add(slot) }
    }

    private func labelled(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RailButton: View {
    let slot: SwiftSlot
    let count: Int
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: slot.symbol).frame(width: 18).foregroundStyle(.secondary)
                Text(slot.name)
                Spacer()
                Text("\(count)").font(.caption).monospacedDigit().foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(.rect)
            .background(hovering ? Color.primary.opacity(0.07) : .clear, in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Add a \(slot.name.lowercased()): \(count) ways to build it")
    }
}

// MARK: - Canvas

private struct SwiftLabCanvasView: View {
    @Bindable var canvas: SwiftLabCanvas
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var reduce: Bool { canvas.settings.reduceMotion || systemReduceMotion }

    private var entrance: AnyTransition {
        if reduce { return .opacity }
        switch canvas.settings.entrance {
        case .none: return .identity
        case .opacity: return .opacity
        case .slide: return .move(edge: .bottom).combined(with: .opacity)
        case .scale: return .scale(scale: 0.92).combined(with: .opacity)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    page
                        .frame(maxWidth: 760)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                }
                .background {
                    Color.clear.contentShape(.rect).onTapGesture { canvas.selected = nil }
                }
                .onChange(of: canvas.blocks.last?.id) { _, id in
                    guard let id, id == canvas.selected else { return }
                    withAnimation(reduce ? nil : .smooth) { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
        .background(Palette.ink.opacity(0.35))
    }

    private var header: some View {
        let attention = canvas.blocks.reduce(0) { n, block in n + canvas.issues(for: block).filter { $0.severity != .info }.count }
        return HStack(spacing: 10) {
            Text("Canvas").font(.headline)
            Text(canvas.blocks.count == 1 ? "1 block" : "\(canvas.blocks.count) blocks")
                .foregroundStyle(.secondary)
            if attention > 0 {
                Label("\(attention) to check", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Spacer()
            if canvas.cleared != nil && canvas.blocks.isEmpty {
                Button("Undo Clear") { canvas.undoClear() }
            }
            Button {
                copyToPasteboard(SwiftLab.canvasCode(canvas.blocks, settings: canvas.settings))
            } label: {
                Label("Copy Code", systemImage: "doc.on.doc")
            }
            .disabled(canvas.blocks.isEmpty)
            Button("Clear") { canvas.clear() }
                .disabled(canvas.blocks.isEmpty)
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    @ViewBuilder
    private var page: some View {
        VStack(spacing: 14) {
            if canvas.blocks.isEmpty {
                emptyCanvas
            } else {
                ForEach(Array(canvas.blocks.enumerated()), id: \.element.id) { index, block in
                    BlockFrame(
                        canvas: canvas,
                        block: block,
                        first: index == 0,
                        last: index == canvas.blocks.count - 1
                    )
                    .id(block.id)
                    .transition(entrance)
                }
            }
        }
        .environment(\.labMotion, LabMotion(animation: reduce ? nil : canvas.settings.motionStyle.animation, reduce: reduce))
        .controlSize(canvas.settings.controlSize.controlSize)
        .tint(canvas.settings.tint.color)
        .modifier(SchemeOverride(scheme: canvas.settings.appearance.colorScheme))
    }

    private var emptyCanvas: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                Text("Start with an empty canvas").font(.headline)
                Text("Add a component from the left, then pick how SwiftUI builds it. Anything that needs a newer macOS than the app targets says so.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            HStack(spacing: 8) {
                Text("Or start from").font(.caption).foregroundStyle(.secondary)
                ForEach(SwiftLab.starters, id: \.name) { starter in
                    Button {
                        withAnimation(reduce ? nil : canvas.settings.motionStyle.animation) { canvas.start(starter) }
                    } label: {
                        Label(starter.name, systemImage: starter.symbol)
                    }
                }
            }
        }
        .padding(.vertical, 56)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundStyle(.secondary.opacity(0.4)))
    }
}

/// Puts the canvas in light or dark without touching the rest of the window.
private struct SchemeOverride: ViewModifier {
    let scheme: ColorScheme?
    func body(content: Content) -> some View {
        if let scheme {
            content.environment(\.colorScheme, scheme)
        } else {
            content
        }
    }
}

private struct BlockFrame: View {
    let canvas: SwiftLabCanvas
    let block: SwiftBlock
    let first: Bool
    let last: Bool
    @State private var hovering = false

    var body: some View {
        let adapter = SwiftLab.adapterByID[block.adapter]
        let issues = canvas.issues(for: block)
        let blocked = issues.filter { $0.severity == .blocked }
        let warnings = issues.filter { $0.severity == .warn }.count
        let selected = canvas.selected == block.id

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: block.slot.symbol).foregroundStyle(.secondary)
                Text(block.slot.name).fontWeight(.medium)
                if let adapter {
                    Text(adapter.label == adapter.library.name ? adapter.label : "\(adapter.label) · \(adapter.library.name)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if warnings > 0 {
                    Label("\(warnings)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .help("\(warnings) to check: select the block to see why")
                }
                Spacer()
                HStack(spacing: 2) {
                    iconButton("arrow.up", "Move Up", disabled: first) { canvas.move(block.id, by: -1) }
                    iconButton("arrow.down", "Move Down", disabled: last) { canvas.move(block.id, by: 1) }
                    iconButton("plus.square.on.square", "Duplicate") { canvas.duplicate(block.id) }
                    iconButton("trash", "Remove") { canvas.remove(block.id) }
                }
                .opacity(hovering || selected ? 1 : 0)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .contentShape(.rect)
            .onTapGesture { canvas.selected = block.id }

            Divider()

            Group {
                if let adapter, !blocked.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(adapter.label) can't be drawn here").font(.callout.weight(.medium))
                        IssueRows(issues: blocked)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    SwiftLabViews.view(for: block.adapter, options: block.options)
                        .frame(maxWidth: .infinity)
                        .id(block.adapter)
                        .transition(.opacity)
                }
            }
            .padding(14)
        }
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected ? Palette.gold : Color.primary.opacity(hovering ? 0.25 : 0.12), lineWidth: selected ? 2 : 1)
        }
        .onHover { hovering = $0 }
        .simultaneousGesture(TapGesture().onEnded { canvas.selected = block.id })
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(block.slot.name) block")
    }

    private func iconButton(_ symbol: String, _ label: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.smooth) { action() } }) {
            Image(systemName: symbol).frame(width: 22, height: 20)
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Inspector

private struct SwiftLabInspector: View {
    @Bindable var canvas: SwiftLabCanvas

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let id = canvas.selected, let block = canvas.blocks.first(where: { $0.id == id }) {
                    BlockInspector(canvas: canvas, block: block)
                } else {
                    CanvasSummary(canvas: canvas)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct BlockInspector: View {
    let canvas: SwiftLabCanvas
    let block: SwiftBlock

    var body: some View {
        let adapter = SwiftLab.adapterByID[block.adapter]
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: block.slot.symbol).foregroundStyle(.secondary).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.slot.name).font(.headline)
                Text(block.slot.hint).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { canvas.selected = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .help("Close")
                .accessibilityLabel("Close inspector")
        }

        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("How it's built")
            ForEach(SwiftLab.adapters(for: block.slot)) { option in
                AdapterCard(adapter: option, chosen: option.id == block.adapter, settings: canvas.settings) {
                    withAnimation(.smooth) { canvas.setAdapter(option, for: block.id) }
                }
            }
        }

        if let adapter, !adapter.options.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Options")
                ForEach(adapter.options) { option in
                    OptionControl(option: option, value: block.options[option.id] ?? option.defaultValue) { value in
                        canvas.setOption(option.id, to: value, for: block.id)
                    }
                }
            }
        }

        if let adapter {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Availability")
                Text("Needs macOS \(adapter.minOS). The app targets macOS \(canvas.settings.target), and this Mac runs macOS \(SwiftLab.runningOS).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: adapter.library.url) {
                    Label("\(adapter.library.name) documentation", systemImage: "arrow.up.right.square")
                }
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionTitle("Code")
                    Spacer()
                    Button {
                        copyToPasteboard(adapter.code(block.options))
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                CodeBox(text: adapter.code(block.options))
            }
        }
    }
}

private struct AdapterCard: View {
    let adapter: SwiftAdapter
    let chosen: Bool
    let settings: SwiftLabSettings
    let action: () -> Void

    var body: some View {
        let issues = SwiftLab.issues(for: adapter, settings: settings)
        let blocked = issues.contains { $0.severity == .blocked }
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(adapter.label).fontWeight(.medium)
                    Text(adapter.library.name).font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    MinOSBadge(minOS: adapter.minOS, target: settings.target)
                }
                Text(adapter.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !issues.isEmpty { IssueRows(issues: issues).padding(.top, 2) }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .background(chosen ? Palette.gold.opacity(0.08) : .clear, in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(chosen ? Palette.gold.opacity(0.8) : Color.primary.opacity(0.12))
            }
            .opacity(blocked && !chosen ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

private struct OptionControl: View {
    let option: LabOption
    let value: LabValue
    let set: (LabValue) -> Void

    var body: some View {
        switch option.kind {
        case .toggle:
            Toggle(option.label, isOn: Binding(get: { value.flag ?? false }, set: { set(.flag($0)) }))
                .toggleStyle(.switch)
                .controlSize(.small)
        case .text:
            VStack(alignment: .leading, spacing: 4) {
                Text(option.label).font(.caption).foregroundStyle(.secondary)
                TextField(option.label, text: Binding(get: { value.text ?? "" }, set: { set(.text($0)) }))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
            }
        case .choice(let choices):
            VStack(alignment: .leading, spacing: 4) {
                Text(option.label).font(.caption).foregroundStyle(.secondary)
                let binding = Binding(get: { value.text ?? "" }, set: { set(.text($0)) })
                // Segments when they fit the 300pt column, a menu otherwise.
                if choices.count <= 4 && choices.reduce(0, { $0 + $1.label.count }) <= 30 {
                    Picker(option.label, selection: binding) {
                        ForEach(choices, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } else {
                    Picker(option.label, selection: binding) {
                        ForEach(choices, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
    }
}

private struct CodeBox: View {
    let text: String
    var body: some View {
        ScrollView(.horizontal) {
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize()
                .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))
    }
}

private struct CanvasSummary: View {
    let canvas: SwiftLabCanvas

    var body: some View {
        if canvas.blocks.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nothing on the canvas yet").font(.headline)
                Text("Add a component from the left. Select a block to choose how it's built, change its options and read its code.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            let adapters = canvas.blocks.compactMap { SwiftLab.adapterByID[$0.adapter] }
            let needs = adapters.map(\.minOS).max() ?? 13
            VStack(alignment: .leading, spacing: 4) {
                Text("Canvas").font(.headline)
                Text("Select a block to change how it's built.").font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Frameworks")
                ForEach(SwiftLibrary.allCases.filter { library in adapters.contains { $0.library == library } }, id: \.self) { library in
                    HStack {
                        Text(library.name)
                        Spacer()
                        Text(library.importLine).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Availability")
                Text("This canvas needs macOS \(needs). The app targets macOS \(canvas.settings.target).")
                    .font(.callout)
                    .foregroundStyle(needs > canvas.settings.target ? Color.orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("To check")
                let flagged = canvas.blocks.compactMap { block -> (SwiftBlock, [LabIssue])? in
                    let issues = canvas.issues(for: block).filter { $0.severity != .info }
                    return issues.isEmpty ? nil : (block, issues)
                }
                if flagged.isEmpty {
                    Text("Everything here runs on the app's target.").font(.callout).foregroundStyle(Palette.jade)
                } else {
                    ForEach(flagged, id: \.0.id) { block, issues in
                        VStack(alignment: .leading, spacing: 4) {
                            Button("\(block.slot.name) · \(SwiftLab.adapterByID[block.adapter]?.label ?? "")") { canvas.selected = block.id }
                                .buttonStyle(.link)
                                .font(.caption.weight(.medium))
                            IssueRows(issues: issues)
                        }
                    }
                }
            }

            Button {
                copyToPasteboard(SwiftLab.canvasCode(canvas.blocks, settings: canvas.settings))
            } label: {
                Label("Copy Code for the Canvas", systemImage: "doc.on.doc")
            }
        }
    }
}

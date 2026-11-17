import Foundation

/// The SwiftUI side of the Playbook lab: the same composer as the React lab (an empty canvas,
/// components, a library for each, extras on top), drawn natively by Graphitree.
///
/// This file is the model and the rules, with no SwiftUI in it, so the checks can run it. Each
/// adapter's metadata (options, availability, code) lives in `Shared/SwiftLabAdapters/`, and its
/// view in `App/Views/SwiftLab/`, both keyed by the adapter's id.
///
/// The compatibility question on this side is mostly availability: which macOS an API needs
/// against the app's deployment target, and whether this Mac can draw it at all.
enum SwiftLab {}

/// An option's value. Options are either a choice (a string) or a switch.
enum LabValue: Codable, Hashable {
    case text(String)
    case flag(Bool)

    var text: String? { if case .text(let value) = self { value } else { nil } }
    var flag: Bool? { if case .flag(let value) = self { value } else { nil } }
}

typealias LabOptions = [String: LabValue]

extension LabOptions {
    /// The option's text, or "" when it isn't set or isn't text.
    func text(_ id: String) -> String { self[id]?.text ?? "" }
    func flag(_ id: String) -> Bool { self[id]?.flag ?? false }
}

struct LabOption: Identifiable {
    struct Choice: Hashable {
        let value: String
        let label: String
    }

    enum Kind {
        case choice([Choice])
        case toggle
        case text
    }

    let id: String
    let label: String
    let kind: Kind
    let defaultValue: LabValue

    static func choice(_ id: String, _ label: String, _ choices: [(String, String)], default value: String) -> LabOption {
        LabOption(id: id, label: label, kind: .choice(choices.map { Choice(value: $0.0, label: $0.1) }), defaultValue: .text(value))
    }

    static func toggle(_ id: String, _ label: String, default value: Bool) -> LabOption {
        LabOption(id: id, label: label, kind: .toggle, defaultValue: .flag(value))
    }

    static func text(_ id: String, _ label: String, default value: String) -> LabOption {
        LabOption(id: id, label: label, kind: .text, defaultValue: .text(value))
    }

    /// Whether a value fits this option: the right kind, and one of the choices for a choice.
    func accepts(_ value: LabValue) -> Bool {
        switch (kind, value) {
        case (.choice(let choices), .text(let text)): choices.contains { $0.value == text }
        case (.toggle, .flag), (.text, .text): true
        default: false
        }
    }
}

enum SwiftSlot: String, CaseIterable, Codable {
    case button, banner, sheet, picker, tabs, number, chart, feed, card, text, avatars, nav, empty

    var name: String {
        switch self {
        case .button: "Button"
        case .banner: "Toast or banner"
        case .sheet: "Sheet or panel"
        case .picker: "Picker"
        case .tabs: "Tabs"
        case .number: "KPI number"
        case .chart: "Chart"
        case .feed: "Activity feed"
        case .card: "Card effect"
        case .text: "Text effect"
        case .avatars: "Avatar group"
        case .nav: "Navigation"
        case .empty: "Empty state"
        }
    }

    var group: String {
        switch self {
        case .button, .banner, .sheet, .picker, .tabs: "Controls"
        case .number, .chart, .feed: "Data"
        case .card, .text, .avatars: "Motion"
        case .nav, .empty: "Layout"
        }
    }

    /// An SF Symbol for the rail and the block's header.
    var symbol: String {
        switch self {
        case .button: "cursorarrow.click"
        case .banner: "bell"
        case .sheet: "sidebar.right"
        case .picker: "filemenu.and.selection"
        case .tabs: "rectangle.split.3x1"
        case .number: "number"
        case .chart: "chart.bar"
        case .feed: "list.bullet"
        case .card: "rectangle.on.rectangle"
        case .text: "textformat"
        case .avatars: "person.2"
        case .nav: "sidebar.left"
        case .empty: "tray"
        }
    }

    var hint: String {
        switch self {
        case .button: "A call to action"
        case .banner: "A short message that comes and goes"
        case .sheet: "A panel that slides in"
        case .picker: "Choose one of a few"
        case .tabs: "Switch between views"
        case .number: "A number that changes"
        case .chart: "Sales by month"
        case .feed: "Events arriving"
        case .card: "A card that reacts"
        case .text: "A headline that animates"
        case .avatars: "Who's on it"
        case .nav: "Sidebar and detail"
        case .empty: "Nothing here yet"
        }
    }

    static let groups = ["Controls", "Data", "Motion", "Layout"]
}

/// Where a SwiftUI adapter comes from. Built into macOS for now; Swift packages come later.
enum SwiftLibrary: String, Codable, CaseIterable {
    case swiftUI = "swiftui"
    case swiftCharts = "swift-charts"

    var name: String {
        switch self {
        case .swiftUI: "SwiftUI"
        case .swiftCharts: "Swift Charts"
        }
    }

    var url: URL {
        switch self {
        case .swiftUI: URL(string: "https://developer.apple.com/documentation/swiftui")!
        case .swiftCharts: URL(string: "https://developer.apple.com/documentation/charts")!
        }
    }

    /// Built-in frameworks need no install, only an import.
    var importLine: String {
        switch self {
        case .swiftUI: "import SwiftUI"
        case .swiftCharts: "import Charts"
        }
    }
}

struct SwiftAdapter: Identifiable {
    /// Unique across adapters, kebab-case: "button-glass".
    let id: String
    let slot: SwiftSlot
    var library: SwiftLibrary = .swiftUI
    /// Short name for the picker: "Liquid Glass button".
    let label: String
    /// One line on what makes it different.
    let note: String
    /// The macOS major version its APIs need, such as 14 for `.contentTransition(.numericText())`.
    var minOS = 13
    /// Built by hand from smaller parts, because SwiftUI has nothing ready-made for the job.
    var handBuilt = false
    /// Runs an animation that repeats on its own, such as a mesh gradient that drifts.
    var repeats = false
    /// Stops repeating or moving when Reduce motion is on. Our adapters read it; the code says how.
    var honoursReduceMotion = true
    var options: [LabOption] = []
    /// The SwiftUI code for the current options, with its imports.
    let code: (LabOptions) -> String
}

enum LabAppearance: String, Codable, CaseIterable {
    case system, light, dark
    var label: String { rawValue.capitalized }
}

enum LabAnimation: String, Codable, CaseIterable {
    case smooth, snappy, bouncy
    var label: String { rawValue.capitalized }
    var code: String { ".\(rawValue)" }
}

enum LabEntrance: String, Codable, CaseIterable {
    case none, opacity, slide, scale
    var label: String {
        switch self {
        case .none: "None"
        case .opacity: "Fade"
        case .slide: "Slide"
        case .scale: "Scale"
        }
    }
}

enum LabControlSize: String, Codable, CaseIterable {
    case small, regular, large
    var label: String { rawValue.capitalized }
}

enum LabTint: String, Codable, CaseIterable {
    case accent, gold, blue, green, orange, pink
    var label: String { rawValue.capitalized }
}

/// The canvas settings: what the app targets, and the extras applied to every block.
struct SwiftLabSettings: Codable, Equatable {
    /// The app's deployment target, as a macOS major version.
    var target = 15
    var appearance = LabAppearance.system
    /// Named so `$settings.motionStyle` doesn't collide with `Binding.animation()`.
    var motionStyle = LabAnimation.smooth
    var entrance = LabEntrance.slide
    /// Acts like the macOS setting: blocks stop repeating animations and move less.
    var reduceMotion = false
    var controlSize = LabControlSize.regular
    var tint = LabTint.accent

    static let targets = [14, 15, 26, 27]
}

struct SwiftBlock: Codable, Identifiable, Equatable {
    var id = UUID()
    let slot: SwiftSlot
    var adapter: String
    var options: LabOptions
}

struct LabIssue: Equatable {
    enum Severity: Int, Comparable {
        case info, warn, blocked
        static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
    }

    let severity: Severity
    let text: String
}

extension SwiftLab {
    static let adapters: [SwiftAdapter] = controlAdapters + dataAdapters + motionAdapters + layoutAdapters

    static let adapterByID: [String: SwiftAdapter] = Dictionary(adapters.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    static func adapters(for slot: SwiftSlot) -> [SwiftAdapter] { adapters.filter { $0.slot == slot } }

    /// The macOS major version this Mac runs, which decides what the lab can draw.
    static var runningOS: Int { ProcessInfo.processInfo.operatingSystemVersion.majorVersion }

    static func defaults(for adapter: SwiftAdapter) -> LabOptions {
        Dictionary(adapter.options.map { ($0.id, $0.defaultValue) }, uniquingKeysWith: { first, _ in first })
    }

    /// Options for a block switching adapter: values that fit the new adapter's options stay.
    static func carryOver(_ previous: LabOptions, to adapter: SwiftAdapter) -> LabOptions {
        var options = defaults(for: adapter)
        for option in adapter.options {
            if let value = previous[option.id], option.accepts(value) { options[option.id] = value }
        }
        return options
    }

    static func block(_ adapter: SwiftAdapter) -> SwiftBlock {
        SwiftBlock(slot: adapter.slot, adapter: adapter.id, options: defaults(for: adapter))
    }

    static func issues(for adapter: SwiftAdapter, settings: SwiftLabSettings, runningOS: Int = runningOS) -> [LabIssue] {
        var issues: [LabIssue] = []
        if runningOS < adapter.minOS {
            issues.append(LabIssue(severity: .blocked, text: "Needs macOS \(adapter.minOS). This Mac runs macOS \(runningOS), so the lab can't draw it."))
        } else if settings.target < adapter.minOS {
            issues.append(LabIssue(
                severity: .warn,
                text: "Needs macOS \(adapter.minOS); the app targets macOS \(settings.target). Wrap it in `if #available(macOS \(adapter.minOS), *)` with a fallback, or raise the target."
            ))
        }
        if settings.reduceMotion && adapter.repeats && !adapter.honoursReduceMotion {
            issues.append(LabIssue(severity: .warn, text: "Keeps animating when Reduce motion is on."))
        }
        if adapter.handBuilt {
            issues.append(LabIssue(severity: .info, text: "SwiftUI has nothing ready-made for this, so it's built from smaller parts. The code is all of it."))
        }
        return issues
    }

    /// The adapter a new block starts with: the one with the fewest problems, then list order.
    static func best(for slot: SwiftSlot, settings: SwiftLabSettings, runningOS: Int = runningOS) -> SwiftAdapter? {
        func score(_ adapter: SwiftAdapter) -> Int {
            issues(for: adapter, settings: settings, runningOS: runningOS).reduce(0) { total, issue in
                total + (issue.severity == .blocked ? 100 : issue.severity == .warn ? 10 : 0)
            }
        }
        return adapters(for: slot).enumerated().min { a, b in
            let (sa, sb) = (score(a.element), score(b.element))
            return sa != sb ? sa < sb : a.offset < b.offset
        }?.element
    }

    /// The modifiers the canvas settings put around every block, as code.
    static func rootModifiers(_ settings: SwiftLabSettings) -> [String] {
        var lines: [String] = []
        if settings.controlSize != .regular { lines.append(".controlSize(.\(settings.controlSize.rawValue))") }
        if settings.tint != .accent { lines.append(".tint(\(settings.tint == .gold ? "Color(red: 0.95, green: 0.81, blue: 0.53)" : "." + settings.tint.rawValue))") }
        if settings.appearance != .system { lines.append(".preferredColorScheme(.\(settings.appearance.rawValue))") }
        return lines
    }

    /// Everything needed to rebuild the canvas: the root modifiers, then each block's code.
    static func canvasCode(_ blocks: [SwiftBlock], settings: SwiftLabSettings) -> String {
        var parts: [String] = []
        let root = rootModifiers(settings)
        if !root.isEmpty {
            parts.append("// On the window's root view\n" + root.joined(separator: "\n"))
        }
        for block in blocks {
            guard let adapter = adapterByID[block.adapter] else { continue }
            parts.append("// \(block.slot.name): \(adapter.label) (\(adapter.library.name), macOS \(adapter.minOS)+)\n" + adapter.code(block.options))
        }
        return parts.joined(separator: "\n\n")
    }

    /// A ready-made canvas to start from, laid out for a Mac app.
    struct Starter {
        let name: String
        let symbol: String
        let slots: [SwiftSlot]
    }

    static let starters = [
        Starter(name: "Dashboard", symbol: "rectangle.3.group", slots: [.number, .chart, .feed, .banner]),
        Starter(name: "Document app", symbol: "doc.richtext", slots: [.nav, .tabs, .sheet, .empty]),
        Starter(name: "Controls", symbol: "slider.horizontal.3", slots: [.button, .picker, .avatars, .card]),
    ]
}

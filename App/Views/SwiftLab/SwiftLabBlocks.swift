import SwiftUI

// What every SwiftUI lab block shares: the canvas's motion settings, sample data in the same
// Malaysian wholesale flavour as the React lab, and the registry from adapter id to view.
// Each adapter's metadata (options, availability, code) is in Shared/SwiftLabAdapters/.

/// The canvas's motion, as a block should use it. The lab's Reduce motion switch can't change
/// the system's `accessibilityReduceMotion`, so blocks read this, which folds the two together.
struct LabMotion {
    /// The canvas's animation for state changes, or nil when motion is reduced.
    var animation: Animation?
    /// True when either the lab's switch or the Mac's setting asks for reduced motion.
    var reduce: Bool

    /// Runs a state change with the canvas's animation.
    func perform(_ change: () -> Void) {
        withAnimation(animation, change)
    }
}

extension EnvironmentValues {
    @Entry var labMotion = LabMotion(animation: .smooth, reduce: false)
}

extension LabAnimation {
    var animation: Animation {
        switch self {
        case .smooth: .smooth
        case .snappy: .snappy
        case .bouncy: .bouncy
        }
    }
}

extension LabTint {
    var color: Color? {
        switch self {
        case .accent: nil
        case .gold: Palette.gold
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .pink: .pink
        }
    }
}

extension LabControlSize {
    var controlSize: ControlSize {
        switch self {
        case .small: .small
        case .regular: .regular
        case .large: .large
        }
    }
}

extension LabAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Sample data for blocks: the same orders, customers and depots as the React lab.
enum LabSample {
    struct Order: Identifiable, Hashable {
        let id: String
        let customer: String
        let depot: String
        let total: Double
    }

    static let orders = [
        Order(id: "#4821", customer: "Jaya Grocer Bangsar", depot: "Shah Alam DC", total: 2665.20),
        Order(id: "#4817", customer: "99 Speedmart Puchong", depot: "Shah Alam DC", total: 1180.50),
        Order(id: "#4820", customer: "Kedai Runcit Ahmad", depot: "Penang Hub", total: 412.80),
        Order(id: "#4823", customer: "KK Wholesale Centre", depot: "Kota Kinabalu Depot", total: 7018.74),
        Order(id: "#4826", customer: "Mydin Subang Jaya", depot: "Shah Alam DC", total: 3920.00),
    ]

    static let customers = ["Jaya Grocer Bangsar", "99 Speedmart Puchong", "Kedai Runcit Ahmad", "KK Wholesale Centre", "Mydin Subang Jaya", "Lotus's Seri Kembangan", "Aeon Big Mid Valley"]

    static let depots = ["Shah Alam DC", "Penang Hub", "Johor Bahru DC", "Kuching Depot", "Kota Kinabalu Depot"]

    /// Net sales by month, in RM, split by channel.
    static let sales: [(month: String, channel: String, value: Double)] = {
        let months = ["Jun", "Jul", "Aug", "Sep", "Oct", "Nov"]
        let modern = [182_000.0, 196_500, 188_200, 210_400, 224_900, 241_300]
        let traditional = [96_400.0, 101_200, 99_800, 104_600, 111_000, 118_700]
        return months.indices.flatMap { i in
            [(months[i], "Modern trade", modern[i]), (months[i], "Traditional trade", traditional[i])]
        }
    }()

    static let ringgit = FloatingPointFormatStyle<Double>.Currency(code: "MYR").locale(Locale(identifier: "en_MY"))
}

/// Adapter id to view. Each group file adds its own dictionary.
enum SwiftLabViews {
    typealias Make = (LabOptions) -> AnyView

    static let all: [String: Make] = [ControlBlocks.views, DataBlocks.views, MotionBlocks.views, LayoutBlocks.views]
        .reduce(into: [:]) { result, group in result.merge(group) { first, _ in first } }

    @ViewBuilder
    static func view(for id: String, options: LabOptions) -> some View {
        if let make = all[id] {
            make(options)
        } else {
            Text("No view for \(id) yet.").foregroundStyle(.secondary)
        }
    }
}

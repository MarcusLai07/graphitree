import Foundation

// SwiftUI lab adapters for motion: card effect, text effect, avatar group.
// Each adapter's view is in App/Views/SwiftLab/MotionBlocks.swift, under the same id. Both read
// `MotionSample` below, so the numbers in an adapter's code are the ones its block draws with.

extension SwiftLab {
    static let motionAdapters: [SwiftAdapter] = [
        // MARK: Card effect

        SwiftAdapter(
            id: "card-hover",
            slot: .card,
            label: "Hover lift",
            note: "Lifts and deepens its shadow under the pointer with .onHover; under Reduce motion only the border and shadow change",
            minOS: 13,
            options: [
                .choice("background", "Background", [("material", "Material"), ("thin", "Thin material"), ("plain", "Plain")], default: "material"),
                .choice("lift", "Lift", [("subtle", "Subtle"), ("medium", "Medium"), ("strong", "Strong")], default: "medium"),
                .toggle("shadow", "Shadow", default: true),
            ],
            code: MotionCode.hoverCard
        ),
        SwiftAdapter(
            id: "card-mesh",
            slot: .card,
            label: "Mesh gradient",
            note: "A MeshGradient whose points drift on a TimelineView, and hold still under Reduce motion",
            minOS: 15,
            repeats: true,
            options: [
                .choice("palette", "Palette", [("lagoon", "Lagoon"), ("sunset", "Sunset"), ("orchid", "Orchid")], default: "lagoon"),
                .choice("speed", "Drift", [("slow", "Slow"), ("medium", "Medium"), ("fast", "Fast")], default: "medium"),
                .toggle("content", "Card content", default: true),
            ],
            code: MotionCode.meshCard
        ),
        SwiftAdapter(
            id: "card-glass",
            slot: .card,
            label: "Liquid Glass",
            note: ".glassEffect over the week's sell-out bars, with a material before macOS 26",
            minOS: 26,
            options: [
                .choice("variant", "Glass", [("regular", "Regular"), ("clear", "Clear")], default: "regular"),
                .choice("tint", "Tint", [("none", "None"), ("blue", "Blue"), ("green", "Green"), ("orange", "Orange")], default: "none"),
                .choice("shape", "Shape", [("rounded", "Rounded"), ("capsule", "Capsule")], default: "rounded"),
                .toggle("interactive", "Interactive", default: true),
            ],
            code: MotionCode.glassCard
        ),
        SwiftAdapter(
            id: "card-glow",
            slot: .card,
            label: "Phase glow",
            note: "A PhaseAnimator pulses a coloured glow and border; it holds a steady glow under Reduce motion",
            minOS: 14,
            repeats: true,
            options: [
                .choice("color", "Colour", [("blue", "Blue"), ("green", "Green"), ("orange", "Orange"), ("pink", "Pink")], default: "blue"),
                .choice("intensity", "Intensity", [("soft", "Soft"), ("strong", "Strong")], default: "soft"),
                .choice("cadence", "Pulse", [("calm", "Calm"), ("brisk", "Brisk")], default: "calm"),
            ],
            code: MotionCode.glowCard
        ),

        // MARK: Text effect

        SwiftAdapter(
            id: "text-keyframes",
            slot: .text,
            label: "Keyframe headline",
            note: "A KeyframeAnimator plays opacity, scale, offset and tilt tracks; only the fade plays under Reduce motion",
            minOS: 14,
            options: [
                .choice("motion", "Motion", [("pop", "Pop"), ("drop", "Drop in"), ("swing", "Swing")], default: "pop"),
                .choice("speed", "Speed", [("slow", "Slow"), ("normal", "Normal"), ("fast", "Fast")], default: "normal"),
                .text("headline", "Headline", default: MotionSample.headline),
            ],
            code: MotionCode.keyframeHeadline
        ),
        SwiftAdapter(
            id: "text-reveal",
            slot: .text,
            label: "Word-by-word reveal",
            note: "A TextRenderer draws each word in turn, marked with a TextAttribute; words only fade under Reduce motion",
            minOS: 15,
            options: [
                .choice("effect", "Effect", [("fade", "Fade"), ("rise", "Rise"), ("blur", "Blur and rise")], default: "rise"),
                .choice("pace", "Pace", [("slow", "Slow"), ("normal", "Normal"), ("fast", "Fast")], default: "normal"),
                .text("headline", "Headline", default: MotionSample.headline),
            ],
            code: MotionCode.wordReveal
        ),
        SwiftAdapter(
            id: "text-swap",
            slot: .text,
            label: "Interpolated swap",
            note: ".contentTransition(.interpolate) morphs one order status into the next; it crossfades under Reduce motion",
            minOS: 13,
            options: [
                .choice("transition", "Transition", [("interpolate", "Interpolate"), ("opacity", "Opacity"), ("identity", "None")], default: "interpolate"),
                .toggle("weight", "Weight shift", default: true),
                .toggle("colour", "Colour per status", default: true),
            ],
            code: MotionCode.statusSwap
        ),
        SwiftAdapter(
            id: "text-heading",
            slot: .text,
            label: "Heading",
            note: "Plain Text in a system font, with no motion: the baseline",
            minOS: 13,
            options: [
                .choice("size", "Size", [("largeTitle", "Large title"), ("title", "Title"), ("title2", "Title 2"), ("title3", "Title 3")], default: "title"),
                .choice("weight", "Weight", [("regular", "Regular"), ("medium", "Medium"), ("semibold", "Semibold"), ("bold", "Bold"), ("heavy", "Heavy")], default: "semibold"),
                .choice("design", "Design", [("default", "Default"), ("rounded", "Rounded"), ("serif", "Serif"), ("monospaced", "Monospaced")], default: "default"),
            ],
            code: MotionCode.heading
        ),

        // MARK: Avatar group

        SwiftAdapter(
            id: "avatars-stack",
            slot: .avatars,
            label: "Overlapping stack",
            note: "Initials circles overlap, spread apart on hover, and end with a +N for the rest",
            minOS: 13,
            handBuilt: true,
            options: [
                .choice("size", "Size", [("sm", "Small"), ("md", "Medium"), ("lg", "Large")], default: "md"),
                .choice("max", "Shown before +N", [("3", "3"), ("5", "5"), ("8", "All 8")], default: "5"),
                .choice("spread", "Spread on hover", [("tight", "Tight"), ("some", "Some"), ("wide", "Wide")], default: "some"),
            ],
            code: MotionCode.avatarStack
        ),
        SwiftAdapter(
            id: "avatars-row",
            slot: .avatars,
            label: "Plain row",
            note: "Initials circles side by side, with no overlap or motion: the baseline",
            minOS: 13,
            handBuilt: true,
            options: [
                .choice("size", "Size", [("sm", "Small"), ("md", "Medium"), ("lg", "Large")], default: "md"),
                .choice("max", "Shown before +N", [("3", "3"), ("5", "5"), ("8", "All 8")], default: "5"),
                .toggle("names", "First names", default: false),
            ],
            code: MotionCode.avatarRow
        ),
    ]

    /// What the motion blocks show, in the same flavour as the React lab, and the numbers behind
    /// each option. The views and the code both read these.
    enum MotionSample {
        struct Person {
            let initials: String
            let name: String
            let role: String
            /// sRGB, the 600 shade the React lab uses, which carries white initials.
            let color: UInt32

            var firstName: Substring { name.prefix { $0 != " " } }
        }

        static let team = [
            Person(initials: "AL", name: "Aisyah Latif", role: "Sales ops lead", color: 0x0284C7),
            Person(initials: "KW", name: "Kevin Wong", role: "Key accounts", color: 0x059669),
            Person(initials: "PR", name: "Priya Raman", role: "Trade marketing", color: 0x7C3AED),
            Person(initials: "HZ", name: "Hafiz Zulkifli", role: "Logistics", color: 0xD97706),
            Person(initials: "ML", name: "Mei Ling Tan", role: "Finance", color: 0xE11D48),
            Person(initials: "NA", name: "Nur Aina Hashim", role: "Merchandising", color: 0x0D9488),
            Person(initials: "RK", name: "Rajesh Kumar", role: "Distributor sales", color: 0x4F46E5),
            Person(initials: "DT", name: "Daniel Teoh", role: "Demand planning", color: 0xEA580C),
        ]
        static let teamTitle = "Kopi Senja launch plan"
        static let teamDetail = "Due 14 Jan · \(team.count) people · Shah Alam DC"

        static let cardTitle = "Sell-out · Klang Valley"
        static let cardDetail = "Kopi Senja 3-in-1 · last 7 days"
        static let cardAmount = "RM 184,230"
        static let cardChange = "+18.4%"
        static let glassTitle = "Weekly sell-out is ready"
        static let glassDetail = "Kopi Senja 3-in-1 · Klang Valley"
        /// Daily sell-out for the last 7 days, as a share of the bar's full height.
        static let week = [0.42, 0.64, 0.51, 0.78, 0.69, 0.90, 0.84]

        static let eyebrow = "Sales summary · November"
        static let headline = "November sell-out grew 18% in Klang Valley, led by Kopi Senja"
        static let subline = "Two outlets in Penang are below their reorder point."

        static let order = "Order #4821 · Jaya Grocer Bangsar · RM 2,665.20"
        /// The order's statuses, each with the name of a system colour.
        static let statuses: [(text: String, color: String)] = [
            ("Picking at Shah Alam DC", "orange"),
            ("Packed · 4 lines · 38 kg", "blue"),
            ("Out for delivery", "purple"),
            ("Delivered to Jaya Grocer Bangsar", "green"),
        ]

        /// A 3 by 3 mesh's colours, row by row, in sRGB. Mid-tones, so white text reads on them
        /// and the card stands out on a light or a dark canvas.
        static func mesh(_ palette: String) -> [UInt32] {
            switch palette {
            case "sunset": [0xEA580C, 0xF59E0B, 0xE11D48, 0xDB2777, 0xF97316, 0xBE185D, 0x9333EA, 0xC026D3, 0x7C3AED]
            case "orchid": [0x7C3AED, 0xC026D3, 0xDB2777, 0x4F46E5, 0xA855F7, 0xE11D48, 0x1D4ED8, 0x6D28D9, 0x9D174D]
            default: [0x0F766E, 0x0891B2, 0x1D4ED8, 0x059669, 0x0EA5E9, 0x4338CA, 0x0D9488, 0x2563EB, 0x6D28D9]
            }
        }

        /// How much the hover card grows, and how many points it rises.
        static func lift(_ id: String) -> (scale: Double, rise: Double) {
            switch id {
            case "subtle": (1.01, 2)
            case "strong": (1.04, 10)
            default: (1.02, 5)
            }
        }

        /// How fast the mesh drifts, in radians a second.
        static func drift(_ id: String) -> Double {
            switch id {
            case "slow": 0.35
            case "fast": 1.4
            default: 0.7
            }
        }

        /// The glow's opacity dim and lit, and its radius lit. Dim, the radius is a third.
        static func glow(_ id: String) -> (dim: Double, lit: Double, radius: Double) {
            id == "strong" ? (0.2, 0.7, 24) : (0.1, 0.4, 15)
        }

        /// Seconds for each half of the glow's pulse.
        static func cadence(_ id: String) -> Double {
            id == "brisk" ? 0.8 : 1.6
        }

        /// Multiplies every keyframe's duration.
        static func timeScale(_ id: String) -> Double {
            switch id {
            case "slow": 1.6
            case "fast": 0.6
            default: 1
            }
        }

        /// How far each word rises into place, and how blurred it starts, in points.
        static func reveal(_ id: String) -> (rise: Double, blur: Double) {
            switch id {
            case "fade": (0, 0)
            case "blur": (6, 5)
            default: (10, 0)
            }
        }

        /// Seconds between one word starting and the next.
        static func wordPace(_ id: String) -> Double {
            switch id {
            case "slow": 0.16
            case "fast": 0.05
            default: 0.09
            }
        }

        /// An avatar's diameter, in points.
        static func avatarSize(_ id: String) -> Double {
            switch id {
            case "sm": 28
            case "lg": 42
            default: 34
            }
        }

        /// The gap between avatars once the stack spreads, in points.
        static func avatarSpread(_ id: String) -> Double {
            switch id {
            case "tight": 2
            case "wide": 14
            default: 8
            }
        }

        static func avatarsShown(_ id: String) -> Int {
            min(Int(id) ?? 5, team.count)
        }
    }
}

/// Each motion adapter's code, built from its options and `MotionSample`.
private enum MotionCode {
    typealias Sample = SwiftLab.MotionSample

    // MARK: Card effect

    static func hoverCard(_ o: LabOptions) -> String {
        let lift = Sample.lift(o.text("lift"))
        let fill = switch o.text("background") {
        case "thin": ".thinMaterial"
        case "plain": ".background"
        default: ".regularMaterial"
        }
        var card = sellOut + [
            ".background(\(fill), in: RoundedRectangle(cornerRadius: 14))",
            ".overlay {",
            "    RoundedRectangle(cornerRadius: 14)",
            "        .strokeBorder(Color.primary.opacity(isHovered ? 0.2 : 0.08))",
            "}",
            "// Lifts only while motion is allowed; the border answers the pointer either way.",
            ".scaleEffect(isHovered && !reduceMotion ? \(number(lift.scale)) : 1)",
            ".offset(y: isHovered && !reduceMotion ? -\(number(lift.rise)) : 0)",
        ]
        if o.flag("shadow") {
            card.append(".shadow(color: .black.opacity(isHovered ? 0.18 : 0.06), radius: isHovered ? 16 : 4, y: isHovered ? 8 : 2)")
        }
        card += [
            ".animation(.easeOut(duration: 0.2), value: isHovered)",
            ".onHover { isHovered = $0 }",
        ]
        return swiftUI([
            "struct SellOutCard: View {",
            "    @State private var isHovered = false",
            "    @Environment(\\.accessibilityReduceMotion) private var reduceMotion",
            "",
            "    var body: some View {",
            indent(card, 8),
            "    }",
            "}",
        ])
    }

    static func meshCard(_ o: LabOptions) -> String {
        var card = [
            "// Drifts while motion is allowed, and holds still when Reduce motion is on.",
            "TimelineView(.animation(paused: reduceMotion)) { timeline in",
            "    let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * \(number(Sample.drift(o.text("speed"))))",
            "    MeshGradient(width: 3, height: 3, points: points(at: t), colors: colors)",
            "}",
            ".frame(height: 168)",
            ".clipShape(.rect(cornerRadius: 16))",
        ]
        if o.flag("content") {
            card += [
                ".overlay(alignment: .bottomLeading) {",
                "    VStack(alignment: .leading, spacing: 2) {",
                "        Text(\"\(Sample.cardTitle)\").font(.headline)",
                "        Text(\"\(Sample.cardAmount)\").font(.largeTitle.weight(.semibold)).monospacedDigit()",
                "        Text(\"\(Sample.cardDetail) · \(Sample.cardChange)\").font(.caption)",
                "    }",
                "    .foregroundStyle(.white)",
                "    .shadow(color: .black.opacity(0.3), radius: 6)",
                "    .padding(20)",
                "}",
            ]
        }
        return swiftUI([
            "struct MeshCard: View {",
            "    @Environment(\\.accessibilityReduceMotion) private var reduceMotion",
            "",
            "    var body: some View {",
            indent(card, 8),
            "    }",
            "",
            "    /// The corners stay put, the edge points slide along their edges, and the centre circles.",
            "    private func points(at t: Double) -> [SIMD2<Float>] {",
            "        let s = Float(sin(t)) * 0.2, c = Float(cos(t)) * 0.2",
            "        return [",
            "            [0, 0], [0.5 + s, 0], [1, 0],",
            "            [0, 0.5 + c], [0.5 + c * 0.6, 0.5 + s * 0.6], [1, 0.5 - s],",
            "            [0, 1], [0.5 - c, 1], [1, 1],",
            "        ]",
            "    }",
            "",
            "    private let colors: [Color] = [",
            indent(Sample.mesh(o.text("palette")).map { rgb($0) + "," }, 8),
            "    ]",
            "}",
        ])
    }

    static func glassCard(_ o: LabOptions) -> String {
        var glass = o.text("variant") == "clear" ? ".clear" : ".regular"
        if o.text("tint") != "none" { glass += ".tint(.\(o.text("tint")).opacity(0.35))" }
        let interactive = o.flag("interactive")
        if interactive { glass += ".interactive(!reduceMotion)" }
        let shape = o.text("shape") == "capsule" ? "Capsule()" : "RoundedRectangle(cornerRadius: 20)"
        var modifier = ["/// Liquid Glass on macOS 26, and a material before it.", "struct GlassBackground: ViewModifier {"]
        if interactive {
            modifier += ["    @Environment(\\.accessibilityReduceMotion) private var reduceMotion", ""]
        }
        modifier += [
            "    func body(content: Content) -> some View {",
            "        if #available(macOS 26, *) {",
            "            content.glassEffect(\(glass), in: \(shape))",
            "        } else {",
            "            content.background(.regularMaterial, in: \(shape))",
            "        }",
            "    }",
            "}",
        ]
        return swiftUI([
            "// Glass belongs on a layer above content, like this card floating over the week's chart.",
            "HStack(spacing: 12) {",
            "    Image(systemName: \"sparkles\").font(.title3)",
            "    VStack(alignment: .leading, spacing: 2) {",
            "        Text(\"\(Sample.glassTitle)\").font(.headline)",
            "        Text(\"\(Sample.glassDetail)\").font(.caption).foregroundStyle(.secondary)",
            "    }",
            "    Spacer()",
            "    Text(\"\(Sample.cardAmount)\").font(.title3.weight(.semibold)).monospacedDigit()",
            "}",
            ".padding(.horizontal, 20)",
            ".padding(.vertical, 14)",
            ".frame(maxWidth: 440)",
            ".modifier(GlassBackground())",
            "",
        ] + modifier)
    }

    static func glowCard(_ o: LabOptions) -> String {
        let glow = Sample.glow(o.text("intensity"))
        let color = o.text("color")
        return swiftUI([
            "struct GlowCard: View {",
            "    @Environment(\\.accessibilityReduceMotion) private var reduceMotion",
            "",
            "    var body: some View {",
            "        if reduceMotion {",
            "            glow(card, lit: true) // a steady glow instead of a pulse",
            "        } else {",
            "            card.phaseAnimator([false, true]) { content, lit in",
            "                glow(content, lit: lit)",
            "            } animation: { _ in",
            "                .easeInOut(duration: \(number(Sample.cadence(o.text("cadence")))))",
            "            }",
            "        }",
            "    }",
            "",
            "    private var card: some View {",
            indent(sellOut + [".background(.background, in: .rect(cornerRadius: 14))"], 8),
            "    }",
            "",
            "    private func glow(_ content: some View, lit: Bool) -> some View {",
            "        content",
            "            .shadow(color: .\(color).opacity(lit ? \(number(glow.lit)) : \(number(glow.dim))), radius: lit ? \(number(glow.radius)) : \(number(glow.radius / 3)))",
            "            .overlay {",
            "                RoundedRectangle(cornerRadius: 14)",
            "                    .strokeBorder(.\(color).opacity(lit ? 0.8 : 0.3), lineWidth: 1.5)",
            "            }",
            "    }",
            "}",
        ])
    }

    /// The sell-out card's content, as the hover and glow cards draw it.
    static let sellOut = [
        "VStack(alignment: .leading, spacing: 14) {",
        "    HStack(alignment: .firstTextBaseline) {",
        "        VStack(alignment: .leading, spacing: 2) {",
        "            Text(\"\(Sample.cardTitle)\").font(.headline)",
        "            Text(\"\(Sample.cardDetail)\").font(.caption).foregroundStyle(.secondary)",
        "        }",
        "        Spacer()",
        "        Text(\"\(Sample.cardChange)\").font(.caption.weight(.medium)).foregroundStyle(.green)",
        "    }",
        "    HStack(alignment: .bottom) {",
        "        Text(\"\(Sample.cardAmount)\").font(.title2.weight(.semibold)).monospacedDigit()",
        "        Spacer()",
        "        WeekBars() // the last 7 days of sell-out",
        "    }",
        "}",
        ".padding(18)",
        ".frame(maxWidth: 416)",
    ]

    // MARK: Text effect

    static func keyframeHeadline(_ o: LabOptions) -> String {
        let scale = Sample.timeScale(o.text("speed"))
        func seconds(_ value: Double) -> String { number(value * scale) }
        let tracks: [String] = switch o.text("motion") {
        case "drop": [
            "KeyframeTrack(\\.opacity) {",
            "    MoveKeyframe(0)",
            "    LinearKeyframe(1, duration: \(seconds(0.2)))",
            "}",
            "KeyframeTrack(\\.y) {",
            "    MoveKeyframe(-36)",
            "    SpringKeyframe(0, duration: \(seconds(0.6)), spring: .bouncy)",
            "}",
        ]
        case "swing": [
            "KeyframeTrack(\\.opacity) {",
            "    MoveKeyframe(0)",
            "    LinearKeyframe(1, duration: \(seconds(0.2)))",
            "}",
            "KeyframeTrack(\\.y) {",
            "    MoveKeyframe(14)",
            "    CubicKeyframe(0, duration: \(seconds(0.35)))",
            "}",
            "KeyframeTrack(\\.tilt) {",
            "    MoveKeyframe(-6)",
            "    SpringKeyframe(3, duration: \(seconds(0.25)))",
            "    SpringKeyframe(-1.5, duration: \(seconds(0.2)))",
            "    SpringKeyframe(0, duration: \(seconds(0.3)))",
            "}",
        ]
        default: [
            "KeyframeTrack(\\.opacity) {",
            "    MoveKeyframe(0)",
            "    LinearKeyframe(1, duration: \(seconds(0.25)))",
            "}",
            "KeyframeTrack(\\.scale) {",
            "    MoveKeyframe(0.7)",
            "    SpringKeyframe(1.06, duration: \(seconds(0.3)))",
            "    SpringKeyframe(1, duration: \(seconds(0.35)))",
            "}",
        ]
        }
        return swiftUI([
            "struct HeadlineFrame {",
            "    var opacity = 1.0",
            "    var scale = 1.0",
            "    var y = 0.0",
            "    var tilt = 0.0 // degrees",
            "}",
            "",
            "struct KeyframeHeadline: View {",
            "    @State private var replays = 0",
            "    @Environment(\\.accessibilityReduceMotion) private var reduceMotion",
            "",
            "    var body: some View {",
            "        VStack(alignment: .leading, spacing: 8) {",
            "            Text(\"\(Sample.eyebrow)\").font(.caption).foregroundStyle(.secondary)",
            "            Text(\"\(literal(headline(o)))\")",
            "                .font(.title.weight(.semibold))",
            "                .keyframeAnimator(initialValue: HeadlineFrame(), trigger: replays) { [reduceMotion] content, frame in",
            "                    // Under Reduce motion only the fade plays.",
            "                    content",
            "                        .opacity(frame.opacity)",
            "                        .scaleEffect(reduceMotion ? 1 : frame.scale, anchor: .leading)",
            "                        .offset(y: reduceMotion ? 0 : frame.y)",
            "                        .rotationEffect(.degrees(reduceMotion ? 0 : frame.tilt), anchor: .leading)",
            "                } keyframes: { _ in",
            indent(tracks, 20),
            "                }",
            "            Button(\"Replay\", systemImage: \"arrow.counterclockwise\") { replays += 1 }",
            "        }",
            "        .onAppear { replays += 1 }",
            "    }",
            "}",
        ])
    }

    static func wordReveal(_ o: LabOptions) -> String {
        let effect = Sample.reveal(o.text("effect"))
        func moving(_ value: Double) -> String { value == 0 ? "0" : "reduceMotion ? 0 : \(number(value))" }
        return swiftUI([
            "/// Marks each word, so the renderer can time it.",
            "struct WordIndex: TextAttribute {",
            "    let value: Int",
            "}",
            "",
            "/// Draws the words in turn; each takes three words' time to arrive.",
            "struct WordReveal: TextRenderer {",
            "    var progress: Double // 0 to 1",
            "    let words: Int",
            "    let rise: Double",
            "    let blur: Double",
            "",
            "    var animatableData: Double {",
            "        get { progress }",
            "        set { progress = newValue }",
            "    }",
            "",
            "    var displayPadding: EdgeInsets {",
            "        EdgeInsets(top: blur, leading: blur, bottom: rise + blur, trailing: blur)",
            "    }",
            "",
            "    func draw(layout: Text.Layout, in context: inout GraphicsContext) {",
            "        let clock = progress * Double(words + 2)",
            "        for line in layout {",
            "            for run in line {",
            "                let word = Double(run[WordIndex.self]?.value ?? 0)",
            "                let shown = min(max((clock - word) / 3, 0), 1)",
            "                var copy = context",
            "                copy.opacity = shown",
            "                copy.translateBy(x: 0, y: (1 - shown) * rise)",
            "                if blur > 0 { copy.addFilter(.blur(radius: (1 - shown) * blur)) }",
            "                copy.draw(run)",
            "            }",
            "        }",
            "    }",
            "}",
            "",
            "struct RevealHeadline: View {",
            "    @State private var replays = 0",
            "    @Environment(\\.accessibilityReduceMotion) private var reduceMotion",
            "    private let words = \"\(literal(headline(o)))\".split(separator: \" \").map(String.init)",
            "",
            "    var body: some View {",
            "        VStack(alignment: .leading, spacing: 8) {",
            "            Text(\"\(Sample.eyebrow)\").font(.caption).foregroundStyle(.secondary)",
            "            // A new id plays the reveal again. Under Reduce motion the words only fade.",
            "            RevealText(words: words, rise: \(moving(effect.rise)), blur: \(moving(effect.blur)))",
            "                .id(replays)",
            "            Button(\"Replay\", systemImage: \"arrow.counterclockwise\") { replays += 1 }",
            "        }",
            "    }",
            "}",
            "",
            "struct RevealText: View {",
            "    let words: [String]",
            "    let rise: Double",
            "    let blur: Double",
            "    @State private var progress = 0.0",
            "",
            "    var body: some View {",
            "        words.enumerated()",
            "            .reduce(Text(verbatim: \"\")) { text, word in",
            "                Text(\"\\(text)\\(Text(verbatim: word.element + \" \").customAttribute(WordIndex(value: word.offset)))\")",
            "            }",
            "            .font(.title.weight(.semibold))",
            "            .textRenderer(WordReveal(progress: progress, words: words.count, rise: rise, blur: blur))",
            "            .onAppear {",
            "                withAnimation(.linear(duration: Double(words.count + 2) * \(number(Sample.wordPace(o.text("pace")))))) { progress = 1 }",
            "            }",
            "    }",
            "}",
        ])
    }

    static func statusSwap(_ o: LabOptions) -> String {
        let transition = o.text("transition")
        let morphs = transition == "interpolate"
        let weight = o.flag("weight") ? "step.isMultiple(of: 2) ? .regular : .heavy" : ".semibold"
        var lines = ["struct OrderStatus: View {", "    @State private var step = 0"]
        if morphs { lines.append("    @Environment(\\.accessibilityReduceMotion) private var reduceMotion") }
        lines += [
            "",
            "    private let steps = [",
            indent(Sample.statuses.map { "\"\($0.text)\"," }, 8),
            "    ]",
        ]
        if o.flag("colour") {
            lines.append("    private let colors: [Color] = [\(Sample.statuses.map { "." + $0.color }.joined(separator: ", "))]")
        }
        lines += [
            "",
            "    var body: some View {",
            "        VStack(alignment: .leading, spacing: 10) {",
            "            Text(\"\(Sample.order)\").font(.caption).foregroundStyle(.secondary)",
            "            Text(steps[step])",
            "                .font(.system(size: 28, weight: \(weight)))",
        ]
        if o.flag("colour") { lines.append("                .foregroundStyle(colors[step])") }
        lines.append(morphs
            ? "                .contentTransition(reduceMotion ? .opacity : .interpolate) // a crossfade under Reduce motion"
            : "                .contentTransition(.\(transition))")
        lines += [
            "            Button(\"Next status\") {",
            "                withAnimation(.easeInOut(duration: 0.4)) { step = (step + 1) % steps.count }",
            "            }",
            "        }",
            "    }",
            "}",
        ]
        return swiftUI(lines)
    }

    static func heading(_ o: LabOptions) -> String {
        var arguments = [".\(o.text("size"))"]
        if o.text("design") != "default" { arguments.append("design: .\(o.text("design"))") }
        if o.text("weight") != "regular" { arguments.append("weight: .\(o.text("weight"))") }
        let font = arguments.count == 1 ? arguments[0] : ".system(\(arguments.joined(separator: ", ")))"
        return swiftUI([
            "VStack(alignment: .leading, spacing: 8) {",
            "    Text(\"\(Sample.eyebrow)\")",
            "        .font(.caption)",
            "        .foregroundStyle(.secondary)",
            "    Text(\"\(Sample.headline)\")",
            "        .font(\(font))",
            "    Text(\"\(Sample.subline)\")",
            "        .foregroundStyle(.secondary)",
            "}",
        ])
    }

    // MARK: Avatar group

    static func avatarStack(_ o: LabOptions) -> String {
        swiftUI(person() + [
            "",
            "struct AvatarStack: View {",
            "    let people: [Person]",
            "    @State private var isHovered = false",
            "    @Environment(\\.accessibilityReduceMotion) private var reduceMotion",
            "",
            "    private let size: CGFloat = \(number(Sample.avatarSize(o.text("size"))))",
            "    private let shown = \(Sample.avatarsShown(o.text("max")))",
            "",
            "    var body: some View {",
            "        HStack(spacing: isHovered ? \(number(Sample.avatarSpread(o.text("spread")))) : -size * 0.2) {",
            "            ForEach(Array(people.prefix(shown).enumerated()), id: \\.element.id) { index, person in",
            "                Text(person.id)",
            "                    .font(.system(size: size * 0.36, weight: .semibold))",
            "                    .foregroundStyle(.white)",
            "                    .frame(width: size, height: size)",
            "                    .background(person.color, in: Circle())",
            "                    .overlay { Circle().strokeBorder(.background, lineWidth: 2) }",
            "                    .zIndex(Double(shown - index)) // the first sits on top",
            "                    .help(person.name)",
            "            }",
        ] + more(indent: 12) + [
            "        }",
            "        .contentShape(Rectangle())",
            "        .onHover { isHovered = $0 }",
            "        // Under Reduce motion the stack spreads in place, without sliding.",
            "        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: isHovered)",
            "        .accessibilityElement(children: .ignore)",
            "        .accessibilityLabel(people.map(\\.name).formatted(.list(type: .and)))",
            "    }",
            "}",
        ])
    }

    static func avatarRow(_ o: LabOptions) -> String {
        let names = o.flag("names")
        var circle = [
            "Text(person.id)",
            "    .font(.system(size: size * 0.36, weight: .semibold))",
            "    .foregroundStyle(.white)",
            "    .frame(width: size, height: size)",
            "    .background(person.color, in: Circle())",
        ]
        if names {
            circle = ["VStack(spacing: 4) {"] + circle.map { "    " + $0 } + [
                "    Text(person.name.prefix { $0 != \" \" })",
                "        .font(.caption2)",
                "        .foregroundStyle(.secondary)",
                "}",
                ".help(person.name)",
            ]
        } else {
            circle.append("    .help(person.name)")
        }
        return swiftUI(person() + [
            "",
            "struct AvatarRow: View {",
            "    let people: [Person]",
            "    private let size: CGFloat = \(number(Sample.avatarSize(o.text("size"))))",
            "    private let shown = \(Sample.avatarsShown(o.text("max")))",
            "",
            "    var body: some View {",
            "        HStack(alignment: .top, spacing: 10) {",
            "            ForEach(people.prefix(shown)) { person in",
            indent(circle, 16),
            "            }",
        ] + more(indent: 12) + [
            "        }",
            "    }",
            "}",
        ])
    }

    static func person() -> [String] {
        [
            "struct Person: Identifiable {",
            "    let id: String // initials, such as \"AL\"",
            "    let name: String",
            "    let color: Color",
            "}",
        ]
    }

    /// The "+N" circle for everyone past `shown`.
    static func more(indent spaces: Int) -> [String] {
        [indent([
            "if people.count > shown {",
            "    Text(\"+\\(people.count - shown)\")",
            "        .font(.system(size: size * 0.34, weight: .semibold))",
            "        .foregroundStyle(.secondary)",
            "        .frame(width: size, height: size)",
            "        .background(.quaternary, in: Circle())",
            "}",
        ], spaces)]
    }

    // MARK: Helpers

    static func headline(_ o: LabOptions) -> String {
        let text = o.text("headline").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? Sample.headline : text
    }

    static func swiftUI(_ lines: [String]) -> String {
        "import SwiftUI\n\n" + lines.joined(separator: "\n")
    }

    /// Indents every non-empty line, including lines inside multi-line strings.
    static func indent(_ lines: [String], _ spaces: Int) -> String {
        let pad = String(repeating: " ", count: spaces)
        return lines
            .flatMap { $0.split(separator: "\n", omittingEmptySubsequences: false) }
            .map { $0.isEmpty ? "" : pad + $0 }
            .joined(separator: "\n")
    }

    /// A number as Swift source, with at most two decimals and no trailing zeros: 1.02, 5, 0.4.
    static func number(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text == "-0" ? "0" : text
    }

    static func rgb(_ hex: UInt32) -> String {
        let channel = { (shift: UInt32) in number(Double((hex >> shift) & 0xFF) / 255) }
        return "Color(red: \(channel(16)), green: \(channel(8)), blue: \(channel(0)))"
    }

    /// Text as the inside of a Swift string literal.
    static func literal(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

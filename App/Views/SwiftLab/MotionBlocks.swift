import SwiftUI

// Views for the motion adapters in Shared/SwiftLabAdapters/Motion.swift. The content and the
// numbers come from `SwiftLab.MotionSample` there, so each block draws what its code says.
// Every block reads `labMotion`: when it says reduce, repeating animations stop, entrances only
// fade, and hover changes land without moving.

enum MotionBlocks {
    static let views: [String: SwiftLabViews.Make] = [
        "card-hover": { AnyView(HoverCardBlock(options: $0)) },
        "card-mesh": { AnyView(MeshCardBlock(options: $0)) },
        "card-glass": { AnyView(GlassCardBlock(options: $0)) },
        "card-glow": { AnyView(GlowCardBlock(options: $0)) },
        "text-keyframes": { AnyView(KeyframeHeadlineBlock(options: $0)) },
        "text-reveal": { AnyView(WordRevealBlock(options: $0)) },
        "text-swap": { AnyView(StatusSwapBlock(options: $0)) },
        "text-heading": { AnyView(HeadingBlock(options: $0)) },
        "avatars-stack": { AnyView(AvatarStackBlock(options: $0)) },
        "avatars-row": { AnyView(AvatarRowBlock(options: $0)) },
    ]
}

private typealias Sample = SwiftLab.MotionSample

// MARK: - Card effect

private struct HoverCardBlock: View {
    let options: LabOptions
    @State private var hovering = false
    @Environment(\.labMotion) private var motion

    var body: some View {
        let lift = Sample.lift(options.text("lift"))
        let rises = hovering && !motion.reduce
        let shadow = options.flag("shadow")
        SellOutContent()
            .background(fill, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(hovering ? 0.2 : 0.08))
            }
            .scaleEffect(rises ? lift.scale : 1)
            .offset(y: rises ? -lift.rise : 0)
            .shadow(color: .black.opacity(shadow ? (hovering ? 0.18 : 0.06) : 0), radius: hovering ? 16 : 4, y: hovering ? 8 : 2)
            .onHover { inside in motion.perform { hovering = inside } }
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background { backdrop }
            .background(.background.secondary, in: .rect(cornerRadius: 10))
    }

    private var fill: AnyShapeStyle {
        switch options.text("background") {
        case "thin": AnyShapeStyle(.thinMaterial)
        case "plain": AnyShapeStyle(.background)
        default: AnyShapeStyle(.regularMaterial)
        }
    }

    /// Two soft blobs behind the card, so a material has something to show through.
    private var backdrop: some View {
        ZStack {
            Circle().fill(Color.blue.opacity(0.55)).frame(width: 130, height: 130).offset(x: -120, y: -8)
            Circle().fill(Color.orange.opacity(0.55)).frame(width: 110, height: 110).offset(x: 130, y: 12)
        }
        .blur(radius: 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(.rect(cornerRadius: 10))
    }
}

private struct MeshCardBlock: View {
    let options: LabOptions
    @Environment(\.labMotion) private var motion

    var body: some View {
        let colors = Sample.mesh(options.text("palette")).map { Color(hex: $0) }
        let drift = Sample.drift(options.text("speed"))
        let still = motion.reduce
        TimelineView(.animation(paused: still)) { timeline in
            let t = still ? 0 : timeline.date.timeIntervalSinceReferenceDate * drift
            MeshGradient(width: 3, height: 3, points: meshPoints(at: t), colors: colors)
        }
        .frame(height: 168)
        .frame(maxWidth: 520)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(alignment: .bottomLeading) {
            if options.flag("content") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Sample.cardTitle).font(.headline)
                    Text(Sample.cardAmount).font(.largeTitle.weight(.semibold)).monospacedDigit()
                    Text(verbatim: "\(Sample.cardDetail) · \(Sample.cardChange)").font(.caption)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 6)
                .padding(20)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }
}

/// A 3 by 3 mesh at time `t`: the corners stay put, the edge points slide along their edges, and
/// the centre circles.
private func meshPoints(at t: Double) -> [SIMD2<Float>] {
    let s = Float(sin(t)) * 0.2, c = Float(cos(t)) * 0.2
    func point(_ x: Float, _ y: Float) -> SIMD2<Float> { SIMD2(x, y) }
    return [
        point(0, 0), point(0.5 + s, 0), point(1, 0),
        point(0, 0.5 + c), point(0.5 + c * 0.6, 0.5 + s * 0.6), point(1, 0.5 - s),
        point(0, 1), point(0.5 - c, 1), point(1, 1),
    ]
}

private struct GlassCardBlock: View {
    let options: LabOptions
    @Environment(\.labMotion) private var motion

    var body: some View {
        ZStack {
            // Glass needs something behind it: the week's sell-out, drawn large.
            WeekBars(
                style: AnyShapeStyle(LinearGradient(colors: [.cyan, .blue, .purple], startPoint: .top, endPoint: .bottom)),
                height: 150,
                spacing: 14
            )
            .padding(.horizontal, 8)
            glass(content)
                .padding(.horizontal, 24)
        }
        .frame(height: 168)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }

    private var content: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(Sample.glassTitle).font(.headline)
                Text(Sample.glassDetail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Sample.cardAmount).font(.title3.weight(.semibold)).monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: 440)
    }

    @ViewBuilder
    private func glass(_ content: some View) -> some View {
        let shape = options.text("shape") == "capsule" ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: 20))
        if #available(macOS 26, *) {
            content.glassEffect(glassStyle, in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }

    @available(macOS 26, *)
    private var glassStyle: Glass {
        var glass: Glass = options.text("variant") == "clear" ? .clear : .regular
        if let tint = motionColor(options.text("tint")) { glass = glass.tint(tint.opacity(0.35)) }
        // Interactive glass flexes under the pointer, so it sits still under Reduce motion.
        if options.flag("interactive") && !motion.reduce { glass = glass.interactive() }
        return glass
    }
}

private struct GlowCardBlock: View {
    let options: LabOptions
    @Environment(\.labMotion) private var motion

    var body: some View {
        Group {
            if motion.reduce {
                glow(card, lit: true)
            } else {
                card.phaseAnimator([false, true]) { content, lit in
                    glow(content, lit: lit)
                } animation: { _ in
                    .easeInOut(duration: Sample.cadence(options.text("cadence")))
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }

    private var card: some View {
        SellOutContent().background(.background, in: .rect(cornerRadius: 14))
    }

    private func glow(_ content: some View, lit: Bool) -> some View {
        let color = motionColor(options.text("color")) ?? .blue
        let glow = Sample.glow(options.text("intensity"))
        return content
            .shadow(color: color.opacity(lit ? glow.lit : glow.dim), radius: lit ? glow.radius : glow.radius / 3)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(color.opacity(lit ? 0.8 : 0.3), lineWidth: 1.5)
            }
    }
}

/// The sell-out card's content, shared by the hover and glow cards.
private struct SellOutContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Sample.cardTitle).font(.headline)
                    Text(Sample.cardDetail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                GainChip()
            }
            HStack(alignment: .bottom) {
                Text(Sample.cardAmount).font(.title2.weight(.semibold)).monospacedDigit()
                Spacer()
                WeekBars(style: AnyShapeStyle(Color.blue.opacity(0.8)), height: 44, spacing: 5)
                    .frame(width: 150)
            }
        }
        .padding(18)
        .frame(maxWidth: 416)
    }
}

/// The sell-out change, in a green dark enough for a light card and light enough for a dark one.
private struct GainChip: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let green = colorScheme == .dark ? Color(hex: 0x34D399) : Color(hex: 0x047857)
        Text(Sample.cardChange)
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(green)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(green.opacity(0.12), in: Capsule())
    }
}

private struct WeekBars: View {
    let style: AnyShapeStyle
    let height: CGFloat
    let spacing: CGFloat

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Sample.week.indices, id: \.self) { day in
                UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                    .fill(style)
                    .frame(height: height * Sample.week[day])
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel("Daily sell-out, last 7 days, rising towards the weekend")
    }
}

// MARK: - Text effect

/// The panel a text block sits on: an eyebrow, the text, and an optional Replay button.
private struct MotionTextFrame<Content: View>: View {
    var eyebrow = Sample.eyebrow
    var onReplay: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(.trailing, onReplay == nil ? 0 : 96)
        .overlay(alignment: .topTrailing) {
            if let onReplay {
                Button(action: onReplay) {
                    Label("Replay", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }
}

private struct HeadlineFrame {
    var opacity = 1.0
    var scale = 1.0
    var y = 0.0
    /// Degrees.
    var tilt = 0.0
}

private struct KeyframeHeadlineBlock: View {
    let options: LabOptions
    @State private var replays = 0

    var body: some View {
        MotionTextFrame(onReplay: { replays += 1 }) {
            // A new id plays it again; so does changing the motion or the speed.
            KeyframeHeadline(
                text: headlineOption(options),
                style: options.text("motion"),
                timeScale: Sample.timeScale(options.text("speed"))
            )
            .id("\(replays)-\(options.text("motion"))-\(options.text("speed"))")
        }
    }
}

private struct KeyframeHeadline: View {
    let text: String
    let style: String
    let timeScale: Double
    @State private var trigger = 0
    @Environment(\.labMotion) private var motion

    var body: some View {
        let headline = Text(text).font(.title.weight(.semibold))
        let reduce = motion.reduce
        let f = timeScale
        Group {
            switch style {
            case "drop":
                headline.keyframeAnimator(initialValue: HeadlineFrame(), trigger: trigger) { content, frame in
                    motionHeadline(content, frame, reduce: reduce)
                } keyframes: { _ in
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 0.2 * f)
                    }
                    KeyframeTrack(\.y) {
                        MoveKeyframe(-36)
                        SpringKeyframe(0, duration: 0.6 * f, spring: .bouncy)
                    }
                }
            case "swing":
                headline.keyframeAnimator(initialValue: HeadlineFrame(), trigger: trigger) { content, frame in
                    motionHeadline(content, frame, reduce: reduce)
                } keyframes: { _ in
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 0.2 * f)
                    }
                    KeyframeTrack(\.y) {
                        MoveKeyframe(14)
                        CubicKeyframe(0, duration: 0.35 * f)
                    }
                    KeyframeTrack(\.tilt) {
                        MoveKeyframe(-6)
                        SpringKeyframe(3, duration: 0.25 * f)
                        SpringKeyframe(-1.5, duration: 0.2 * f)
                        SpringKeyframe(0, duration: 0.3 * f)
                    }
                }
            default:
                headline.keyframeAnimator(initialValue: HeadlineFrame(), trigger: trigger) { content, frame in
                    motionHeadline(content, frame, reduce: reduce)
                } keyframes: { _ in
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 0.25 * f)
                    }
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(0.7)
                        SpringKeyframe(1.06, duration: 0.3 * f)
                        SpringKeyframe(1, duration: 0.35 * f)
                    }
                }
            }
        }
        .onAppear { trigger += 1 }
    }
}

/// Applies one keyframe. Under Reduce motion only the fade plays.
private func motionHeadline(_ content: some View, _ frame: HeadlineFrame, reduce: Bool) -> some View {
    content
        .opacity(frame.opacity)
        .scaleEffect(reduce ? 1 : frame.scale, anchor: .leading)
        .offset(y: reduce ? 0 : frame.y)
        .rotationEffect(.degrees(reduce ? 0 : frame.tilt), anchor: .leading)
}

private struct WordRevealBlock: View {
    let options: LabOptions
    @State private var replays = 0
    @Environment(\.labMotion) private var motion

    var body: some View {
        let effect = Sample.reveal(options.text("effect"))
        MotionTextFrame(onReplay: { replays += 1 }) {
            // A new id plays it again; so does changing the effect or the pace.
            WordRevealText(
                words: headlineOption(options).split(separator: " ").map(String.init),
                rise: motion.reduce ? 0 : effect.rise,
                blur: motion.reduce ? 0 : effect.blur,
                secondsPerWord: Sample.wordPace(options.text("pace"))
            )
            .id("\(replays)-\(options.text("effect"))-\(options.text("pace"))")
        }
    }
}

/// Marks each word with its place, so the renderer can time it.
private struct WordIndexAttribute: TextAttribute {
    let value: Int
}

/// Draws the words in turn; each takes three words' time to arrive.
private struct WordRevealRenderer: TextRenderer {
    var progress: Double
    let words: Int
    let rise: Double
    let blur: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var displayPadding: EdgeInsets {
        EdgeInsets(top: blur, leading: blur, bottom: rise + blur, trailing: blur)
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let clock = progress * Double(words + 2)
        for line in layout {
            for run in line {
                let word = Double(run[WordIndexAttribute.self]?.value ?? 0)
                let shown = min(max((clock - word) / 3, 0), 1)
                guard shown > 0 else { continue }
                var copy = context
                copy.opacity = shown
                if rise > 0 { copy.translateBy(x: 0, y: (1 - shown) * rise) }
                if blur > 0 && shown < 1 { copy.addFilter(.blur(radius: (1 - shown) * blur)) }
                copy.draw(run)
            }
        }
    }
}

private struct WordRevealText: View {
    let words: [String]
    let rise: Double
    let blur: Double
    let secondsPerWord: Double
    @State private var progress = 0.0

    var body: some View {
        words.enumerated()
            .reduce(Text(verbatim: "")) { text, word in
                Text("\(text)\(Text(verbatim: word.element + " ").customAttribute(WordIndexAttribute(value: word.offset)))")
            }
            .font(.title.weight(.semibold))
            .textRenderer(WordRevealRenderer(progress: progress, words: words.count, rise: rise, blur: blur))
            .onAppear {
                withAnimation(.linear(duration: Double(words.count + 2) * secondsPerWord)) { progress = 1 }
            }
    }
}

private struct StatusSwapBlock: View {
    let options: LabOptions
    @State private var step = 0
    @Environment(\.labMotion) private var motion

    var body: some View {
        let status = Sample.statuses[step]
        MotionTextFrame(eyebrow: Sample.order) {
            Text(status.text)
                .font(.system(size: 28, weight: weight))
                .foregroundStyle(options.flag("colour") ? motionColor(status.color) ?? .primary : .primary)
                .contentTransition(transition)
            Button("Next status", action: advance)
                .padding(.top, 4)
        }
    }

    private var weight: Font.Weight {
        guard options.flag("weight") else { return .semibold }
        return step.isMultiple(of: 2) ? .regular : .heavy
    }

    private var transition: ContentTransition {
        switch options.text("transition") {
        case "identity": .identity
        case "opacity": .opacity
        default: motion.reduce ? .opacity : .interpolate
        }
    }

    private func advance() {
        // Under Reduce motion the status crossfades rather than morphing.
        let animation = motion.reduce ? Animation.easeInOut(duration: 0.25) : motion.animation
        withAnimation(animation) { step = (step + 1) % Sample.statuses.count }
    }
}

private struct HeadingBlock: View {
    let options: LabOptions

    var body: some View {
        MotionTextFrame {
            Text(Sample.headline).font(.system(style, design: design, weight: weight))
            Text(Sample.subline).foregroundStyle(.secondary)
        }
    }

    private var style: Font.TextStyle {
        switch options.text("size") {
        case "largeTitle": .largeTitle
        case "title2": .title2
        case "title3": .title3
        default: .title
        }
    }

    private var design: Font.Design {
        switch options.text("design") {
        case "rounded": .rounded
        case "serif": .serif
        case "monospaced": .monospaced
        default: .default
        }
    }

    private var weight: Font.Weight {
        switch options.text("weight") {
        case "medium": .medium
        case "semibold": .semibold
        case "bold": .bold
        case "heavy": .heavy
        default: .regular
        }
    }
}

private func headlineOption(_ options: LabOptions) -> String {
    let text = options.text("headline").trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? Sample.headline : text
}

// MARK: - Avatar group

private struct AvatarStackBlock: View {
    let options: LabOptions
    @State private var hovering = false
    @Environment(\.labMotion) private var motion

    var body: some View {
        let size = Sample.avatarSize(options.text("size"))
        let shown = Array(Sample.team.prefix(Sample.avatarsShown(options.text("max"))))
        let rest = Sample.team.count - shown.count
        VStack(alignment: .leading, spacing: 12) {
            TeamCaption()
            HStack(spacing: hovering ? Sample.avatarSpread(options.text("spread")) : -size * 0.2) {
                ForEach(Array(shown.enumerated()), id: \.element.initials) { index, person in
                    AvatarCircle(person: person, size: size)
                        .overlay { Circle().strokeBorder(.background.secondary, lineWidth: 2) }
                        .zIndex(Double(shown.count - index))
                }
                if rest > 0 {
                    MoreAvatars(count: rest, size: size)
                        .overlay { Circle().strokeBorder(.background.secondary, lineWidth: 2) }
                }
            }
            .contentShape(Rectangle())
            // Under Reduce motion `perform` runs without animation, so the stack spreads in place.
            .onHover { inside in motion.perform { hovering = inside } }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }
}

private struct AvatarRowBlock: View {
    let options: LabOptions

    var body: some View {
        let size = Sample.avatarSize(options.text("size"))
        let shown = Array(Sample.team.prefix(Sample.avatarsShown(options.text("max"))))
        let rest = Sample.team.count - shown.count
        let names = options.flag("names")
        VStack(alignment: .leading, spacing: 12) {
            TeamCaption()
            HStack(alignment: .top, spacing: 10) {
                ForEach(shown, id: \.initials) { person in
                    VStack(spacing: 4) {
                        AvatarCircle(person: person, size: size)
                        if names {
                            Text(person.firstName).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                if rest > 0 {
                    MoreAvatars(count: rest, size: size)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }
}

private struct AvatarCircle: View {
    let person: Sample.Person
    let size: Double

    var body: some View {
        let tip = "\(person.name) · \(person.role)"
        Text(person.initials)
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: person.color), in: Circle())
            .help(tip)
            .accessibilityLabel(tip)
    }
}

private struct MoreAvatars: View {
    let count: Int
    let size: Double

    var body: some View {
        let others = Sample.team.suffix(count).map(\.name).joined(separator: ", ")
        Text(verbatim: "+\(count)")
            .font(.system(size: size * 0.34, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(.quaternary, in: Circle())
            .help(others)
            .accessibilityLabel(others)
    }
}

private struct TeamCaption: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Sample.teamTitle).font(.headline)
            Text(Sample.teamDetail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers

/// A system colour by the name the options use, or nil for "none".
private func motionColor(_ name: String) -> Color? {
    switch name {
    case "blue": .blue
    case "green": .green
    case "orange": .orange
    case "pink": .pink
    case "purple": .purple
    default: nil
    }
}

import SwiftUI

extension Color {
    /// Anthropic clay — the brand accent from the wireframes (#D97757).
    static let clay = Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255)

    /// Track behind bars and pills.
    static let track = Color.primary.opacity(0.08)
    /// The data accent: first series, bars, heatmaps. Graphitree's violet, which the graph uses
    /// for work projects; gold stays for selection.
    static let dataAccent = Palette.violet
    static let chartSky = Color(hex: 0x6CC6FF)
    static let chartTeal = Palette.jade
    static let chartAmber = Color(hex: 0xF5C04A)
    static let chartPink = Color(hex: 0xF27FB8)
    static let chartViolet = Color(hex: 0xC09BFF)
    static let chartGreen = Color(hex: 0x6FD98C)
    /// Cost figures, as Magpie shows them.
    static let costGreen = Palette.jade
}

extension UsageProvider {
    /// The provider's own colour, for its marks: Claude's clay, Gemini's blue, and a pale grey for
    /// the tools whose brands are black and white.
    var accent: Color {
        switch self {
        case .claude: return .clay
        case .gemini: return Color(hex: 0x8AB4F8)
        case .codex, .copilot, .opencode: return Color(hex: 0xC9D1D9)
        }
    }
}

extension MetricKind {
    /// Each window's series color.
    var chartColor: Color {
        switch self {
        case .session: return .dataAccent
        case .weekly: return .chartSky
        case .weeklyFable: return .chartTeal
        case .weeklyOpus: return .chartViolet
        case .weeklySonnet: return .chartGreen
        case .extraUsage: return .chartAmber
        }
    }

    /// A limit's bar: its series color until it nears the limit, then the
    /// escalation colors (orange from 70%, red from 90%).
    func meterColor(percentUsed: Double) -> Color {
        percentUsed >= 70 ? usageColor(percentUsed) : chartColor
    }
}

/// "Runs out Sat 14:00 at this pace" (orange) or "Lasts past the reset at
/// this pace", from the window's readings this cycle.
struct ForecastLine: View {
    let forecast: Forecast
    var font: Font = .system(size: 11.5)

    var body: some View {
        switch forecast {
        case .runsOut(let date):
            Text("Runs out \(timeText(date)) at this pace")
                .font(font)
                .foregroundStyle(.orange)
        case .lastsPastReset:
            Text("Lasts past the reset at this pace")
                .font(font)
                .foregroundStyle(.secondary)
        }
    }

    private func timeText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        }
        return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

/// Semantic escalation from the wireframe legend: clay < 70%, orange ≥ 70%,
/// red ≥ 90%. Color never carries meaning alone — the numeral stays prominent.
func usageColor(_ percent: Double) -> Color {
    if percent >= 90 { return .red }
    if percent >= 70 { return .orange }
    return .clay
}

/// The 12-ray sunburst app mark used across widget, popover, and sign-in.
struct SunburstMark: View {
    var size: CGFloat = 15
    var color: Color = .clay

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let unit = canvasSize.width / 24
            for i in 0..<12 {
                let angle = Double(i) * 30 * .pi / 180
                var path = Path()
                path.move(to: CGPoint(x: center.x + cos(angle) * unit * 3.2,
                                      y: center.y + sin(angle) * unit * 3.2))
                path.addLine(to: CGPoint(x: center.x + cos(angle) * unit * 9,
                                         y: center.y + sin(angle) * unit * 9))
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: unit * 2.1, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Capsule progress bar on a quaternary track (6 pt, or 4 pt thin). `tint`
/// overrides the escalation color of `percent`, for Left mode, where the
/// fill is what's left but the color still follows what's used.
struct UsageBar: View {
    let percent: Double
    var height: CGFloat = 6
    var tint: Color? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.track)
                if percent > 0 {
                    Capsule()
                        .fill(tint ?? usageColor(percent))
                        .frame(width: max(height, geo.size.width * min(percent, 100) / 100))
                }
            }
        }
        .frame(height: height)
    }
}

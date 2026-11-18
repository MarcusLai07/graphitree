import SwiftUI

// The small meters the menu bar's popover and the desktop widgets draw, ported from Claude
// Usage's. The widget extension compiles this file too, so it uses nothing from the window.

/// One labelled limit: the name, "17% used", a thin bar in the window's colour (orange, then red,
/// near the limit), and the reset and pace line.
struct MetricBarRow: View {
    let metric: MetricDisplay
    var showCaption = true

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                MetricValue(metric: metric)
            }
            UsageBar(percent: metric.shownPercent, height: 5,
                     tint: metric.kind.meterColor(percentUsed: metric.percent))
            if showCaption {
                MetricCaption(metric: metric, font: .system(size: 10.5))
            }
        }
    }
}

/// "17% used" or "83% left": the figure in semibold digits, orange or red only near the limit.
struct MetricValue: View {
    let metric: MetricDisplay
    var size: CGFloat = 12.5

    var body: some View {
        let figure = Text(metric.valueText)
            .font(.system(size: size, weight: .semibold).monospacedDigit())
            .foregroundStyle(metric.percent >= 70 ? metric.color : Color.primary)
        if let unit = metric.unitText {
            figure + Text(" \(unit)")
                .font(.system(size: size * 0.92, weight: .medium))
                .foregroundStyle(.secondary)
        } else {
            figure
        }
    }
}

/// A round gauge with the figure in the middle. `tint` replaces the escalation colour, as on
/// `UsageBar`; `label` ("left") sits under the figure.
struct UsageRing: View {
    let percent: Double
    let size: CGFloat
    let stroke: CGFloat
    var tint: Color? = nil
    var label: String? = nil

    init(percent: Double, size: CGFloat, stroke: CGFloat, tint: Color? = nil, label: String? = nil) {
        self.percent = percent
        self.size = size
        self.stroke = stroke
        self.tint = tint
        self.label = label
    }

    /// The metric's figure in its window's colour, labelled "left" in Left mode.
    init(metric: MetricDisplay, size: CGFloat, stroke: CGFloat) {
        self.init(percent: metric.shownPercent, size: size, stroke: stroke,
                  tint: metric.kind.meterColor(percentUsed: metric.percent),
                  label: metric.showLeft ? "left" : nil)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.track, lineWidth: stroke)
            Circle()
                .trim(from: 0, to: min(percent, 100) / 100)
                .stroke(tint ?? usageColor(percent), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                (Text("\(Int(percent.rounded(.down)))")
                    .font(.system(size: size * 0.27, weight: .semibold).monospacedDigit())
                 + Text("%")
                    .font(.system(size: size * 0.15, weight: .medium)))
                if let label {
                    Text(label)
                        .font(.system(size: max(8, size * 0.11), weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(stroke / 2)
        .frame(width: size, height: size)
    }
}

/// How old the reading is, counting up: "4:28". Orange with a warning clock when the last
/// reading failed or Graphitree has stopped reading.
struct AgeBadge: View {
    let since: Date
    var stale = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: stale ? "clock.badge.exclamationmark" : "clock")
                .font(.system(size: 8, weight: .semibold))
            Text(since, style: .timer)
        }
        .font(.system(size: 9.5, weight: .medium).monospacedDigit())
        .foregroundStyle(stale ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
    }
}

/// "Updated 3 min ago", or for Codex "As of Codex's last reply, 2 hr ago", which ages without
/// being stale: Codex's limits change only when it runs.
struct ReadingAge: View {
    let provider: UsageProvider
    let since: Date
    var stale = false

    var text: Text {
        switch provider {
        case .claude:
            return Text(stale ? "Last updated " : "Updated ") + Text(since, style: .relative) + Text(" ago")
        case .codex:
            return Text("As of Codex's last reply, ") + Text(since, style: .relative) + Text(" ago")
        }
    }

    var body: some View { text }
}

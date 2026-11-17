import SwiftUI

// Ported from Claude Usage's window and set on Graphitree's glass: the page is the panel itself,
// cards are RowCards, and tabs are the segmented control AI Models uses. The data palette is in
// UsageTheme.swift.

/// Stable model → color assignment for charts, in share order: the data
/// accent first, then hues far enough apart to tell stacked bars apart.
let modelPalette: [Color] = [.dataAccent, .chartTeal, .chartSky, .chartPink, .chartAmber,
                             .chartViolet, .chartGreen, Palette.slate]

/// "7.16B", "22.8M", "267K": three significant digits, as Magpie shows them.
func compactTokens(_ count: Int) -> String {
    count.formatted(.number.notation(.compactName).precision(.significantDigits(1...3)))
}

/// "≈$4,112", "≈$0.128": dollars at API list prices, more precision when small.
func costText(_ usd: Double, approximate: Bool = true) -> String {
    let prefix = approximate ? "≈$" : "$"
    if usd >= 100 { return prefix + Int(usd.rounded()).formatted() }
    if usd >= 1 { return prefix + String(format: "%.2f", usd) }
    return prefix + String(format: "%.3f", usd)
}

/// "Nov 12 15:20" (the system's month-day-hour format adds "at").
func shortDateTime(_ date: Date) -> String {
    "\(date.formatted(.dateTime.month(.abbreviated).day())) \(date.formatted(.dateTime.hour().minute()))"
}

// MARK: - Card

extension View {
    /// Window content card: 10 pt radius, hairline stroke, 16 pt padding.
    func designCard(padding: CGFloat = 16) -> some View {
        modifier(RowCard(padding: padding))
    }
}

/// A section's small-caps label ("ALLOWANCES"), as Magpie heads its blocks.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.7)
            .foregroundStyle(Palette.gold.opacity(0.9))
    }
}

/// One choice from a few, as the segmented control AI Models uses (gold when selected). `size`
/// below the default draws it small, for controls inside cards.
struct PillTabs<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var size: CGFloat = 12.5

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options.indices, id: \.self) { index in
                Text(options[index].title).tag(options[index].value)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(size < 12.5 ? .small : .regular)
        .fixedSize()
    }
}

/// A stat tile's parts: small label, figure, muted caption (Magpie's strip).
struct StatTile: View {
    let label: String
    let value: String
    var caption: String? = nil
    var valueColor: Color? = nil
    /// 0–100: a thin bar under the figure (Magpie's cache hit rate).
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .medium).monospacedDigit())
                .foregroundStyle(valueColor.map(AnyShapeStyle.init) ?? AnyShapeStyle(.primary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let progress {
                UsageBarTinted(percent: progress, color: .costGreen)
                    .padding(.vertical, 2)
            }
            if let caption {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

/// Tiles joined in one panel with hairline dividers.
struct StatStripPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            content()
        }
        .fixedSize(horizontal: false, vertical: true)
        .cardSurface()
    }
}

/// A thin vertical hairline between joined tiles.
struct TileDivider: View {
    var body: some View {
        Rectangle().fill(Palette.cardStroke).frame(width: 0.5)
    }
}

struct CardTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Status

struct UsageStatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.16)))
    }
}

struct AgeIndicator: View {
    let since: Date
    var stale = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: stale ? "clock.badge.exclamationmark" : "clock")
                .font(.system(size: 11))
            Text(since, style: .relative) + Text(" ago")
        }
        .font(.system(size: 11.5))
        .foregroundStyle(stale ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
    }
}

struct RefreshButton: View {
    let isRefreshing: Bool
    var help = "Refresh now"
    let action: () async -> Void

    var body: some View {
        Group {
            if isRefreshing {
                ProgressView().controlSize(.small).frame(width: 30, height: 30)
            } else {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await action() }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(ChromeButtonStyle())
                .help(help)
            }
        }
    }
}

// MARK: - Empty states (analytics token block)

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(GoldButtonStyle())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.vertical, 20)
    }
}

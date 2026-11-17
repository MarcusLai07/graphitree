import Charts
import SwiftUI

// Views for the data adapters in Shared/SwiftLabAdapters/Data.swift.

enum DataBlocks {
    static let views: [String: SwiftLabViews.Make] = [
        "number-numeric-text": { AnyView(NumericKPIBlock(options: $0)) },
        "number-plain-text": { AnyView(PlainKPIBlock(options: $0)) },
        "number-gauge": { AnyView(GaugeKPIBlock(options: $0)) },
        "chart-swift-charts": { AnyView(SalesChartBlock(options: $0)) },
        "chart-donut": { AnyView(DonutBlock(options: $0)) },
        "feed-transition": { AnyView(TransitionFeedBlock(options: $0)) },
        "feed-list": { AnyView(ListFeedBlock(options: $0)) },
    ]
}

private extension View {
    /// The card every data block sits on, as the control blocks do.
    func dataCard() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: 10))
    }
}

/// Runs `action` every `seconds`, or never when it's nil. The timer only counts; `onChange` runs
/// the action, so it always sees the canvas's current motion settings.
private struct Ticker: ViewModifier {
    let seconds: Double?
    let action: () -> Void
    @State private var ticks = 0

    func body(content: Content) -> some View {
        content
            .task(id: seconds) {
                guard let seconds else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(seconds))
                    guard !Task.isCancelled else { return }
                    ticks += 1
                }
            }
            .onChange(of: ticks) { action() }
    }
}

// MARK: - KPI number

/// A day's net sales at Shah Alam DC, moved by the sample orders and the odd refund.
private struct SalesDay {
    static let start = 48_210.40
    static let target = 60_000.0

    private static let steps: [(amount: Double, caption: String)] = {
        let o = LabSample.orders
        return [
            (o[0].total, "Order \(o[0].id) · \(o[0].customer)"),
            (o[1].total, "Order \(o[1].id) · \(o[1].customer)"),
            (-o[2].total, "Refund \(o[2].id) · \(o[2].customer)"),
            (o[3].total, "Order \(o[3].id) · \(o[3].customer)"),
            (o[4].total, "Order \(o[4].id) · \(o[4].customer)"),
            (-o[1].total, "Refund \(o[1].id) · \(o[1].customer)"),
        ]
    }()

    var sales = start
    var change = 0.0
    var caption = "Since 8:00 · Shah Alam DC"
    private var step = 0

    /// The next order or refund. Past RM 70,000 the day starts over, so auto-tick never runs away.
    mutating func next() {
        if sales > 70_000 {
            sales = Self.start
            change = 0
            caption = "A new day · Shah Alam DC"
            return
        }
        let (amount, caption) = Self.steps[step % Self.steps.count]
        step += 1
        sales += amount
        change = amount
        self.caption = caption
    }

    static func text(_ sales: Double, format: String) -> String {
        switch format {
        case "percent": (sales / target).formatted(.percent.precision(.fractionLength(1)))
        case "compact": "RM " + sales.formatted(.number.notation(.compactName).precision(.fractionLength(1)))
        default: sales.formatted(LabSample.ringgit)
        }
    }

    /// What `.numericText(value:)` compares to know whether the digits count up or down.
    static func transitionValue(_ sales: Double, format: String) -> Double {
        format == "percent" ? sales / target : sales
    }
}

/// The frame both text KPIs share: a label, the figure, a line under it, and the button.
private struct KPICard<Figure: View, Footer: View>: View {
    let action: () -> Void
    @ViewBuilder let figure: Figure
    @ViewBuilder let footer: Footer

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Net sales today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                figure
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                footer
                    .font(.callout)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(action: action) {
                Label("New order", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .dataCard()
    }
}

private struct NumericKPIBlock: View {
    let options: LabOptions
    @State private var day = SalesDay()
    @Environment(\.labMotion) private var motion

    private var format: String { options.text("format") }

    var body: some View {
        KPICard(action: record) {
            Text(SalesDay.text(day.sales, format: format))
                .monospacedDigit()
                .contentTransition(motion.reduce ? .identity : .numericText(value: SalesDay.transitionValue(day.sales, format: format)))
        } footer: {
            HStack(spacing: 6) {
                if options.flag("trend") {
                    Image(systemName: day.change < 0 ? "arrow.down.right" : day.change > 0 ? "arrow.up.right" : "arrow.right")
                        .foregroundStyle(day.change < 0 ? Color.red : day.change > 0 ? Color.green : Color.secondary)
                        .fontWeight(.semibold)
                    if day.change != 0 {
                        Text(day.change.formatted(LabSample.ringgit.sign(strategy: .always())))
                            .monospacedDigit()
                    }
                }
                Text(day.caption)
                    .foregroundStyle(.secondary)
            }
        }
        // Auto-tick: the figure keeps updating with Reduce motion on, only without the roll.
        .modifier(Ticker(seconds: options.flag("tick") ? 2 : nil, action: record))
    }

    private func record() {
        motion.perform { day.next() }
    }
}

private struct PlainKPIBlock: View {
    let options: LabOptions
    @State private var day = SalesDay()

    var body: some View {
        // No animation at all: the baseline swaps the text in one frame.
        KPICard(action: { day.next() }) {
            Text(SalesDay.text(day.sales, format: options.text("format")))
                .monospacedDigit(options.flag("monospaced"))
                .contentTransition(.identity)
        } footer: {
            if options.flag("target") {
                Text("of \(SalesDay.target.formatted(LabSample.ringgit.precision(.fractionLength(0)))) target · \(day.caption)")
                    .foregroundStyle(.secondary)
            } else {
                Text(day.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func monospacedDigit(_ on: Bool) -> some View {
        if on { monospacedDigit() } else { self }
    }
}

private struct GaugeKPIBlock: View {
    let options: LabOptions
    @State private var day = SalesDay()
    @Environment(\.labMotion) private var motion

    private var style: String { options.text("style") }
    private var isLinear: Bool { style.lowercased().contains("linear") || style == "automatic" }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            if isLinear {
                // The linear styles draw the gauge's own label, so the caption leaves its title out.
                VStack(alignment: .leading, spacing: 6) {
                    tinted(styled(gauge))
                        .frame(maxWidth: 380)
                    caption(titled: false)
                }
            } else {
                tinted(styled(gauge))
                caption(titled: true)
            }
            Spacer(minLength: 0)
            Button {
                motion.perform { day.next() }
            } label: {
                Label("New order", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .dataCard()
    }

    private func caption(titled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if titled {
                Text("November target").font(.headline)
            }
            Text("\(day.sales.formatted(LabSample.ringgit)) of \(SalesDay.target.formatted(LabSample.ringgit.precision(.fractionLength(0)))) · \(day.caption)")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var gauge: some View {
        let value = min(day.sales, SalesDay.target)
        let percent = Text(day.sales / SalesDay.target, format: .percent.precision(.fractionLength(0)))
        if options.flag("bounds") {
            Gauge(value: value, in: 0...SalesDay.target) {
                Text("November target")
            } currentValueLabel: {
                percent
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("60K")
            }
        } else {
            Gauge(value: value, in: 0...SalesDay.target) {
                Text("November target")
            } currentValueLabel: {
                percent
            }
        }
    }

    @ViewBuilder
    private func styled(_ gauge: some View) -> some View {
        switch style {
        case "accessoryCircular": gauge.gaugeStyle(.accessoryCircular)
        case "linearCapacity": gauge.gaugeStyle(.linearCapacity)
        case "accessoryLinearCapacity": gauge.gaugeStyle(.accessoryLinearCapacity)
        case "accessoryLinear": gauge.gaugeStyle(.accessoryLinear)
        case "automatic": gauge.gaugeStyle(.automatic)
        default: gauge.gaugeStyle(.accessoryCircularCapacity)
        }
    }

    @ViewBuilder
    private func tinted(_ gauge: some View) -> some View {
        if options.flag("gradient") {
            gauge.tint(Gradient(colors: [.red, .orange, .green]))
        } else {
            gauge
        }
    }
}

// MARK: - Chart

/// One month's net sales for a channel, or for all channels together.
private struct Sale: Identifiable {
    let month: String
    let channel: String
    let value: Double
    var id: String { month + channel }

    static let byChannel = LabSample.sales.map { Sale(month: $0.month, channel: $0.channel, value: $0.value) }

    static let months: [String] = LabSample.sales.reduce(into: []) { months, sale in
        if !months.contains(sale.month) { months.append(sale.month) }
    }

    static let totals = months.map { month in
        Sale(month: month, channel: "All channels", value: byChannel.filter { $0.month == month }.reduce(0) { $0 + $1.value })
    }

    static func total(in month: String) -> Double {
        byChannel.filter { $0.month == month }.reduce(0) { $0 + $1.value }
    }
}

private struct SalesChartBlock: View {
    let options: LabOptions
    @State private var selectedMonth: String?

    private var split: Bool { options.flag("split") }
    private var smooth: Bool { options.flag("smooth") }
    private var selection: String { options.text("select") }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Net sales by month").font(.headline)
                Spacer()
                Text(selection == "none" ? "Jun–Nov 2026" : selection == "hover" ? "Hover a month" : "Click or drag across the months")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            selectable(chart)
                .frame(height: 190)
        }
        .dataCard()
        .onChange(of: selection) { selectedMonth = nil }
    }

    private var chart: some View {
        Chart {
            ForEach(split ? Sale.byChannel : Sale.totals) { sale in
                mark(sale)
            }
            if let selectedMonth, selection != "none" {
                RuleMark(x: .value("Month", selectedMonth))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        Text("\(selectedMonth) · \(Sale.total(in: selectedMonth).formatted(LabSample.ringgit.precision(.fractionLength(0))))")
                            .font(.caption.bold())
                            .monospacedDigit()
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.background, in: .capsule)
                            .overlay(Capsule().strokeBorder(.separator))
                    }
            }
        }
        .chartForegroundStyleScale(
            domain: split ? ["Modern trade", "Traditional trade"] : ["All channels"],
            range: split ? [Color.blue, Color.orange] : [Color.blue]
        )
        .chartLegend(split ? .visible : .hidden)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text("RM \(amount.formatted(.number.notation(.compactName)))")
                    }
                }
            }
        }
    }

    @ChartContentBuilder
    private func mark(_ sale: Sale) -> some ChartContent {
        let dimmed = selectedMonth != nil && selectedMonth != sale.month
        switch options.text("mark") {
        case "line":
            LineMark(x: .value("Month", sale.month), y: .value("Net sales", sale.value))
                .foregroundStyle(by: .value("Channel", sale.channel))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(smooth ? .catmullRom : .linear)
        case "area":
            AreaMark(x: .value("Month", sale.month), y: .value("Net sales", sale.value))
                .foregroundStyle(by: .value("Channel", sale.channel))
                .interpolationMethod(smooth ? .catmullRom : .linear)
        case "point":
            PointMark(x: .value("Month", sale.month), y: .value("Net sales", sale.value))
                .foregroundStyle(by: .value("Channel", sale.channel))
                .symbolSize(60)
                .opacity(dimmed ? 0.35 : 1)
        default:
            BarMark(x: .value("Month", sale.month), y: .value("Net sales", sale.value), width: .ratio(0.6))
                .foregroundStyle(by: .value("Channel", sale.channel))
                .cornerRadius(3)
                .opacity(dimmed ? 0.35 : 1)
        }
    }

    @ViewBuilder
    private func selectable(_ chart: some View) -> some View {
        switch selection {
        case "drag":
            chart.chartXSelection(value: $selectedMonth)
        case "hover":
            chart.chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            guard case .active(let location) = phase, let plot = proxy.plotFrame else {
                                selectedMonth = nil
                                return
                            }
                            selectedMonth = proxy.value(atX: location.x - geometry[plot].minX, as: String.self)
                        }
                }
            }
        default:
            chart
        }
    }
}

private struct DonutBlock: View {
    let options: LabOptions
    @State private var selectedAngle: Double?
    @State private var hoveredRow: String?

    struct Share: Identifiable {
        let name: String
        let value: Double
        let colour: Color
        var id: String { name }
    }

    /// November's net sales by channel, from the sample data.
    static let byChannel: [Share] = zip(LabSample.sales.filter { $0.month == "Nov" }, [Color.blue, .orange]).map {
        Share(name: $0.channel, value: $0.value, colour: $1)
    }

    /// The same November total split across the depots, in the depots' own order, so a depot keeps its colour.
    static let byDepot: [Share] = {
        let total = byChannel.reduce(0) { $0 + $1.value }
        let weights = [0.41, 0.18, 0.16, 0.11, 0.14]
        let colours: [Color] = [.blue, .orange, .teal, .purple, .pink]
        return LabSample.depots.indices.map { Share(name: LabSample.depots[$0], value: (total * weights[$0]).rounded(), colour: colours[$0]) }
    }()

    private var shares: [Share] { options.text("by") == "depot" ? Self.byDepot : Self.byChannel }
    private var total: Double { shares.reduce(0) { $0 + $1.value } }

    private var innerRadius: MarkDimension {
        switch options.text("ring") {
        case "thin": .ratio(0.78)
        case "pie": 0
        default: .ratio(0.6)
        }
    }

    /// The share under the pointer, from the chart or from the table beside it.
    private var selected: Share? {
        guard options.flag("select") else { return nil }
        if let hoveredRow { return shares.first { $0.name == hoveredRow } }
        guard let selectedAngle else { return nil }
        var running = 0.0
        return shares.first { running += $0.value; return selectedAngle <= running }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            selectable(chart)
                .frame(width: 190, height: 190)
            VStack(alignment: .leading, spacing: 10) {
                Text("November net sales").font(.headline)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(shares) { share in
                        row(share)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .dataCard()
        .onChange(of: options.text("by")) {
            selectedAngle = nil
            hoveredRow = nil
        }
    }

    private var chart: some View {
        Chart(shares) { share in
            SectorMark(angle: .value("Net sales", share.value), innerRadius: innerRadius, angularInset: 1.5)
                .cornerRadius(4)
                .foregroundStyle(by: .value("Name", share.name))
                .opacity(selected == nil || selected?.id == share.id ? 1 : 0.35)
        }
        .chartForegroundStyleScale(domain: shares.map(\.name), range: shares.map(\.colour))
        .chartLegend(.hidden)
        .chartBackground { proxy in
            GeometryReader { geometry in
                if options.flag("centre"), options.text("ring") != "pie", let plot = proxy.plotFrame {
                    let frame = geometry[plot]
                    VStack(spacing: 2) {
                        Text(selected?.name ?? "November")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text((selected?.value ?? total).formatted(LabSample.ringgit.precision(.fractionLength(0))))
                            .font(.headline)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: frame.width * 0.55)
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        }
    }

    @ViewBuilder
    private func selectable(_ chart: some View) -> some View {
        if options.flag("select") {
            chart.chartAngleSelection(value: $selectedAngle)
        } else {
            chart
        }
    }

    /// The table beside the ring: the legend, with the values the ring leaves out.
    private func row(_ share: Share) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(share.colour)
                .frame(width: 10, height: 10)
            Text(share.name)
                .frame(width: 150, alignment: .leading)
            Text(share.value.formatted(LabSample.ringgit.precision(.fractionLength(0))))
                .monospacedDigit()
                .frame(width: 96, alignment: .trailing)
            Text((share.value / total).formatted(.percent.precision(.fractionLength(0))))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .font(.callout)
        .opacity(selected == nil || selected?.id == share.id ? 1 : 0.5)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { hoveredRow = share.name } else if hoveredRow == share.name { hoveredRow = nil }
        }
    }
}

// MARK: - Activity feed

/// Something that happened at a depot: an order, a payment, a delivery or a warning.
private struct FeedEvent: Identifiable {
    let id: Int
    let symbol: String
    let warning: Bool
    let title: String
    let detail: String
    let date: Date

    /// The nth event in a repeating day: confirmed, picked, paid, delivered, low stock.
    static func make(_ n: Int, date: Date = .now) -> FeedEvent {
        let order = LabSample.orders[n % LabSample.orders.count]
        let number = "#\(4827 + n / 5)"
        let amount = order.total.formatted(LabSample.ringgit)
        switch n % 5 {
        case 0:
            return FeedEvent(id: n, symbol: "checkmark.seal", warning: false, title: "Order \(number) confirmed", detail: "\(order.customer) · \(amount)", date: date)
        case 1:
            return FeedEvent(id: n, symbol: "shippingbox", warning: false, title: "Picking started", detail: "Order \(number) at \(order.depot)", date: date)
        case 2:
            return FeedEvent(id: n, symbol: "creditcard", warning: false, title: "Payment received", detail: "\(amount) from \(order.customer)", date: date)
        case 3:
            return FeedEvent(id: n, symbol: "truck.box", warning: false, title: "Out for delivery", detail: "\(order.customer) · from \(order.depot)", date: date)
        default:
            return FeedEvent(id: n, symbol: "exclamationmark.triangle", warning: true, title: "Low stock", detail: "Milo 1kg · 12 cartons left at \(order.depot)", date: date)
        }
    }
}

/// The events so far, newest first, and the count that numbers the next one.
private struct FeedLog {
    private(set) var events: [FeedEvent]
    private var next: Int
    let limit: Int

    init(limit: Int) {
        let now = Date.now
        events = (0..<3).reversed().map { FeedEvent.make($0, date: now.addingTimeInterval(Double($0 - 3) * 40)) }
        next = 3
        self.limit = limit
    }

    mutating func arrive() {
        events.insert(FeedEvent.make(next), at: 0)
        next += 1
        if events.count > limit { events.removeLast(events.count - limit) }
    }
}

private struct FeedRow: View {
    let event: FeedEvent
    let timestamps: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.symbol)
                .foregroundStyle(event.warning ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.tint))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            if timestamps {
                Text(event.date, format: .dateTime.hour().minute().second())
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The feed's title line, with how events arrive and a button to bring one in now.
private struct FeedHeader: View {
    let arrival: String
    let arrive: () -> Void

    var body: some View {
        HStack {
            Text("All depots").font(.headline)
            Text(arrival == "manual" ? "Manual" : "Live · every \(arrival)s")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: arrive) {
                Label("Simulate event", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct TransitionFeedBlock: View {
    let options: LabOptions
    @State private var log = FeedLog(limit: 4)
    @Environment(\.labMotion) private var motion

    private var insertion: AnyTransition {
        switch options.text("transition") {
        case "move": .move(edge: .top)
        case "opacity": .opacity
        case "scale": .scale(scale: 0.85).combined(with: .opacity)
        default: .push(from: .top)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeedHeader(arrival: options.text("arrival"), arrive: arrive)
            VStack(spacing: 6) {
                ForEach(log.events) { event in
                    FeedRow(event: event, timestamps: options.flag("timestamps"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.background, in: .rect(cornerRadius: 8))
                        .transition(.asymmetric(insertion: insertion, removal: .opacity))
                }
            }
            .frame(height: 188, alignment: .top)
            .clipped()
        }
        .dataCard()
        .modifier(Ticker(seconds: Double(options.text("arrival")), action: arrive))
    }

    /// New events keep coming with Reduce motion on; they appear without moving.
    private func arrive() {
        motion.perform { log.arrive() }
    }
}

private struct ListFeedBlock: View {
    let options: LabOptions
    @State private var log = FeedLog(limit: 30)
    @Environment(\.labMotion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeedHeader(arrival: options.text("arrival"), arrive: arrive)
            styled(List(log.events) { event in
                FeedRow(event: event, timestamps: options.flag("timestamps"))
            })
            .frame(height: 188)
            .clipShape(.rect(cornerRadius: 8))
        }
        .dataCard()
        .modifier(Ticker(seconds: Double(options.text("arrival")), action: arrive))
    }

    private func arrive() {
        motion.perform { log.arrive() }
    }

    @ViewBuilder
    private func styled(_ list: some View) -> some View {
        switch options.text("style") {
        case "plain": list.listStyle(.plain)
        case "bordered": list.listStyle(.bordered)
        default: list.listStyle(.inset)
        }
    }
}

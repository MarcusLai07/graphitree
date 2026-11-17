import Foundation

// SwiftUI lab adapters for data: number, chart, feed.
// Each adapter's view is in App/Views/SwiftLab/DataBlocks.swift, under the same id.
//
// Adapters for one slot share option ids where they mean the same thing ("format", "arrival",
// "timestamps", "mark"), so switching adapter keeps what the person picked.

extension SwiftLab {
    static let dataAdapters: [SwiftAdapter] = [
        // MARK: KPI number

        SwiftAdapter(
            id: "number-numeric-text",
            slot: .number,
            label: "Numeric text KPI",
            note: "Each digit rolls to the new value with `.contentTransition(.numericText(value:))`, counting up or down",
            minOS: 14,
            repeats: true,
            options: [
                .choice("format", "Format", DataCode.formats, default: "ringgit"),
                .toggle("trend", "Trend arrow", default: true),
                .toggle("tick", "Auto-tick", default: false),
            ],
            code: { o in
                let format = o.text("format")
                var lines = ["import SwiftUI", "", "struct SalesTodayKPI: View {", "    @State private var sales = 48_210.40"]
                if o.flag("trend") { lines.append("    @State private var change = 0.0") }
                lines.append("    @Environment(\\.accessibilityReduceMotion) private var reduceMotion")
                if format == "percent" { lines.append("    private let target = 60_000.0") }
                lines += [
                    "",
                    "    var body: some View {",
                    "        HStack(alignment: .firstTextBaseline) {",
                    "            VStack(alignment: .leading, spacing: 4) {",
                    "                Text(\"Net sales today\")",
                    "                    .font(.caption)",
                    "                    .foregroundStyle(.secondary)",
                    "                \(DataCode.valueText(format))",
                    "                    .font(.system(size: 40, weight: .semibold, design: .rounded))",
                    "                    .monospacedDigit()",
                    "                    .contentTransition(.numericText(value: \(format == "percent" ? "sales / target" : "sales")))",
                ]
                if o.flag("trend") {
                    lines += [
                        "                Label(change.formatted(.currency(code: \"MYR\").sign(strategy: .always())),",
                        "                      systemImage: change < 0 ? \"arrow.down.right\" : \"arrow.up.right\")",
                        "                    .font(.callout)",
                        "                    .foregroundStyle(change < 0 ? .red : .green)",
                    ]
                }
                lines += [
                    "            }",
                    "            Spacer()",
                    "            Button(\"New order\", systemImage: \"plus\") { record(2_665.20) }",
                    "        }",
                ]
                if o.flag("tick") {
                    lines += [
                        "        .task {",
                        "            // Auto-tick: the data keeps updating; Reduce motion only drops the animation.",
                        "            while !Task.isCancelled {",
                        "                try? await Task.sleep(for: .seconds(2))",
                        "                record(1_180.50)",
                        "            }",
                        "        }",
                    ]
                }
                lines += [
                    "    }",
                    "",
                    "    private func record(_ amount: Double) {",
                    "        withAnimation(reduceMotion ? nil : .smooth) {",
                ]
                if o.flag("trend") { lines.append("            change = amount") }
                lines += [
                    "            sales += amount",
                    "        }",
                    "    }",
                    "}",
                ]
                return lines.joined(separator: "\n")
            }
        ),

        SwiftAdapter(
            id: "number-plain-text",
            slot: .number,
            label: "Plain text KPI",
            note: "A Text that swaps to the new value with no transition: the baseline to compare against",
            minOS: 13,
            options: [
                .choice("format", "Format", DataCode.formats, default: "ringgit"),
                .toggle("monospaced", "Monospaced digits", default: true),
                .toggle("target", "Show target", default: false),
            ],
            code: { o in
                let format = o.text("format")
                var lines = ["import SwiftUI", "", "struct SalesTodayKPI: View {", "    @State private var sales = 48_210.40"]
                if format == "percent" || o.flag("target") { lines.append("    private let target = 60_000.0") }
                lines += [
                    "",
                    "    var body: some View {",
                    "        HStack(alignment: .firstTextBaseline) {",
                    "            VStack(alignment: .leading, spacing: 4) {",
                    "                Text(\"Net sales today\")",
                    "                    .font(.caption)",
                    "                    .foregroundStyle(.secondary)",
                    "                \(DataCode.valueText(format))",
                    "                    .font(.system(size: 40, weight: .semibold, design: .rounded))",
                ]
                if o.flag("monospaced") { lines.append("                    .monospacedDigit()") }
                if o.flag("target") {
                    lines += [
                        "                Text(\"of \\(target, format: .currency(code: \"MYR\").precision(.fractionLength(0))) target\")",
                        "                    .font(.callout)",
                        "                    .foregroundStyle(.secondary)",
                    ]
                }
                lines += [
                    "            }",
                    "            Spacer()",
                    "            Button {",
                    "                sales += 2_665.20",
                    "            } label: {",
                    "                Label(\"New order\", systemImage: \"plus\")",
                    "            }",
                    "        }",
                    "    }",
                    "}",
                ]
                return lines.joined(separator: "\n")
            }
        ),

        SwiftAdapter(
            id: "number-gauge",
            slot: .number,
            label: "Gauge",
            note: "The system Gauge against the month's target, in each style macOS has. Only the accessory styles draw a gradient tint",
            minOS: 13,
            options: [
                .choice("style", "Style", [
                    ("accessoryCircularCapacity", "Circular capacity"),
                    ("accessoryCircular", "Circular"),
                    ("linearCapacity", "Linear capacity"),
                    ("accessoryLinearCapacity", "Accessory linear capacity"),
                    ("accessoryLinear", "Accessory linear"),
                    ("automatic", "Automatic"),
                ], default: "accessoryCircularCapacity"),
                .toggle("bounds", "Bounds labels", default: true),
                .toggle("gradient", "Gradient tint", default: false),
            ],
            code: { o in
                var lines = [
                    "import SwiftUI",
                    "",
                    "struct MonthlyTargetGauge: View {",
                    "    @State private var sales = 48_210.40",
                    "    private let target = 60_000.0",
                    "    @Environment(\\.accessibilityReduceMotion) private var reduceMotion",
                    "",
                    "    var body: some View {",
                    "        HStack(spacing: 16) {",
                    "            Gauge(value: min(sales, target), in: 0...target) {",
                    "                Text(\"November target\")",
                    "            } currentValueLabel: {",
                    "                Text(sales / target, format: .percent.precision(.fractionLength(0)))",
                ]
                if o.flag("bounds") {
                    lines += [
                        "            } minimumValueLabel: {",
                        "                Text(\"0\")",
                        "            } maximumValueLabel: {",
                        "                Text(\"60K\")",
                    ]
                }
                lines += [
                    "            }",
                    "            .gaugeStyle(.\(o.text("style")))",
                ]
                if o.flag("gradient") { lines.append("            .tint(Gradient(colors: [.red, .orange, .green]))") }
                lines += [
                    "",
                    "            Button(\"New order\", systemImage: \"plus\") {",
                    "                withAnimation(reduceMotion ? nil : .smooth) { sales += 2_665.20 }",
                    "            }",
                    "        }",
                    "    }",
                    "}",
                ]
                return lines.joined(separator: "\n")
            }
        ),

        // MARK: Chart

        SwiftAdapter(
            id: "chart-swift-charts",
            slot: .chart,
            library: .swiftCharts,
            label: "Swift Charts",
            note: "Net sales by month as bars, lines, areas or points, split by channel, with a selected month",
            minOS: 14,
            options: [
                .choice("mark", "Mark", [("bar", "Bar"), ("line", "Line"), ("area", "Area"), ("point", "Point")], default: "bar"),
                .toggle("split", "Split by channel", default: true),
                .toggle("smooth", "Smooth curve", default: false),
                .choice("select", "Selection", [("hover", "Hover"), ("drag", "Click or drag"), ("none", "None")], default: "hover"),
            ],
            code: { o in DataCode.salesChart(o) }
        ),

        SwiftAdapter(
            id: "chart-donut",
            slot: .chart,
            library: .swiftCharts,
            label: "Donut (SectorMark)",
            note: "November's sales as sectors of a ring, by channel or by depot, with the selected share in the middle",
            minOS: 14,
            options: [
                .choice("by", "Split by", [("channel", "Channel"), ("depot", "Depot")], default: "channel"),
                .choice("ring", "Shape", [("donut", "Donut"), ("thin", "Thin ring"), ("pie", "Pie")], default: "donut"),
                .toggle("select", "Selection", default: true),
                .toggle("centre", "Total in the middle", default: true),
            ],
            code: { o in DataCode.donut(o) }
        ),

        // MARK: Activity feed

        SwiftAdapter(
            id: "feed-transition",
            slot: .feed,
            label: "Live feed with transitions",
            note: "Events arrive at the top of a stack and come in with an insertion transition",
            minOS: 13,
            repeats: true,
            options: [
                .choice("transition", "Insertion", [("push", "Push"), ("move", "Move"), ("opacity", "Fade"), ("scale", "Scale")], default: "push"),
                .choice("arrival", "Arrives", DataCode.arrivals, default: "3"),
                .toggle("timestamps", "Timestamps", default: true),
            ],
            code: { o in DataCode.feed(o, list: false) }
        ),

        SwiftAdapter(
            id: "feed-list",
            slot: .feed,
            label: "Plain List",
            note: "A system List that rows are added to, with only the table's own animation: the baseline",
            minOS: 13,
            repeats: true,
            options: [
                .choice("arrival", "Arrives", DataCode.arrivals, default: "3"),
                .toggle("timestamps", "Timestamps", default: true),
                .choice("style", "List style", [("inset", "Inset"), ("plain", "Plain"), ("bordered", "Bordered")], default: "inset"),
            ],
            code: { o in DataCode.feed(o, list: true) }
        ),
    ]
}

/// Code fragments the data adapters share.
private enum DataCode {
    static let formats = [("ringgit", "RM"), ("percent", "% of target"), ("compact", "Compact")]
    static let arrivals = [("1.5", "Every 1.5s"), ("3", "Every 3s"), ("manual", "Manual")]

    /// The Text that shows the sales figure in a format.
    static func valueText(_ format: String) -> String {
        switch format {
        case "percent": "Text(sales / target, format: .percent.precision(.fractionLength(1)))"
        case "compact": "Text(\"RM \\(sales, format: .number.notation(.compactName).precision(.fractionLength(1)))\")"
        default: "Text(sales, format: .currency(code: \"MYR\"))"
        }
    }

    static func salesChart(_ o: LabOptions) -> String {
        let mark = o.text("mark")
        let split = o.flag("split")
        let smooth = o.flag("smooth") && (mark == "line" || mark == "area")
        let select = o.text("select")
        let markType = ["line": "LineMark", "area": "AreaMark", "point": "PointMark"][mark] ?? "BarMark"
        let data = split ? "sales" : "monthlyTotals"

        var lines = [
            "import SwiftUI",
            "import Charts",
            "",
            "struct Sale: Identifiable {",
            "    let month: String",
            "    let channel: String",
            "    let value: Double",
            "    var id: String { month + channel }",
            "}",
            "",
            "struct SalesChart: View {",
            "    let \(data): [Sale]",
        ]
        if select != "none" { lines.append("    @State private var selectedMonth: String?") }
        lines += [
            "",
            "    var body: some View {",
            "        Chart {",
            "            ForEach(\(data)) { sale in",
            "                \(markType)(",
            "                    x: .value(\"Month\", sale.month),",
            "                    y: .value(\"Net sales\", sale.value)",
            "                )",
        ]
        lines.append(split ? "                .foregroundStyle(by: .value(\"Channel\", sale.channel))" : "                .foregroundStyle(.blue)")
        switch mark {
        case "bar": lines.append("                .cornerRadius(3)")
        case "line": lines.append("                .lineStyle(StrokeStyle(lineWidth: 2))")
        case "point": lines.append("                .symbolSize(60)")
        default: break
        }
        if smooth { lines.append("                .interpolationMethod(.catmullRom)") }
        lines.append("            }")
        if select != "none" {
            lines += [
                "            if let selectedMonth {",
                "                RuleMark(x: .value(\"Month\", selectedMonth))",
                "                    .foregroundStyle(Color.secondary.opacity(0.35))",
                "                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {",
                "                        Text(\"\\(selectedMonth) · \\(total(in: selectedMonth), format: .currency(code: \"MYR\").precision(.fractionLength(0)))\")",
                "                            .font(.caption.bold())",
                "                            .padding(.horizontal, 7)",
                "                            .background(.background, in: .capsule)",
                "                    }",
                "            }",
            ]
        }
        lines.append("        }")
        if split {
            lines.append("        .chartForegroundStyleScale([\"Modern trade\": Color.blue, \"Traditional trade\": Color.orange])")
        }
        lines += [
            "        .chartYAxis {",
            "            AxisMarks { value in",
            "                AxisGridLine()",
            "                AxisValueLabel { Text(\"RM \\(value.as(Double.self) ?? 0, format: .number.notation(.compactName))\") }",
            "            }",
            "        }",
        ]
        switch select {
        case "drag":
            lines.append("        .chartXSelection(value: $selectedMonth)")
        case "hover":
            lines += [
                "        .chartOverlay { proxy in",
                "            GeometryReader { geometry in",
                "                Rectangle().fill(.clear).contentShape(Rectangle())",
                "                    .onContinuousHover { phase in",
                "                        guard case .active(let location) = phase, let plot = proxy.plotFrame else {",
                "                            selectedMonth = nil",
                "                            return",
                "                        }",
                "                        selectedMonth = proxy.value(atX: location.x - geometry[plot].minX, as: String.self)",
                "                    }",
                "            }",
                "        }",
            ]
        default: break
        }
        lines += ["        .frame(height: 200)", "    }"]
        if select != "none" {
            lines += [
                "",
                "    private func total(in month: String) -> Double {",
                "        \(data).filter { $0.month == month }.reduce(0) { $0 + $1.value }",
                "    }",
            ]
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    static func donut(_ o: LabOptions) -> String {
        let byDepot = o.text("by") == "depot"
        let noun = byDepot ? "Depot" : "Channel"
        let ring = ["thin": ".ratio(0.78)", "pie": "0"][o.text("ring")] ?? ".ratio(0.6)"
        let select = o.flag("select")
        let colours = byDepot
            ? "[\"Shah Alam DC\": Color.blue, \"Penang Hub\": .orange, \"Johor Bahru DC\": .teal, \"Kuching Depot\": .purple, \"Kota Kinabalu Depot\": .pink]"
            : "[\"Modern trade\": Color.blue, \"Traditional trade\": .orange]"

        var lines = [
            "import SwiftUI",
            "import Charts",
            "",
            "struct Share: Identifiable {",
            "    let name: String",
            "    let value: Double",
            "    var id: String { name }",
            "}",
            "",
            "struct NovemberDonut: View {",
            "    let shares: [Share]   // November net sales by \(noun.lowercased())",
        ]
        if select {
            lines += [
                "    @State private var selectedAngle: Double?",
                "",
                "    /// The share under the pointer: the angle is a running total of the values.",
                "    private var selected: Share? {",
                "        guard let selectedAngle else { return nil }",
                "        var total = 0.0",
                "        return shares.first { total += $0.value; return selectedAngle <= total }",
                "    }",
            ]
        }
        lines += [
            "",
            "    var body: some View {",
            "        Chart(shares) { share in",
            "            SectorMark(",
            "                angle: .value(\"Net sales\", share.value),",
            "                innerRadius: \(ring),",
            "                angularInset: 1.5",
            "            )",
            "            .cornerRadius(4)",
            "            .foregroundStyle(by: .value(\"\(noun)\", share.name))",
        ]
        if select { lines.append("            .opacity(selected == nil || selected?.id == share.id ? 1 : 0.35)") }
        lines += [
            "        }",
            "        .chartForegroundStyleScale(\(colours))",
        ]
        if select { lines.append("        .chartAngleSelection(value: $selectedAngle)") }
        if o.flag("centre") && o.text("ring") != "pie" {
            let label = select ? "selected?.name ?? \"November\"" : "\"November\""
            let value = select ? "selected?.value ?? shares.reduce(0) { $0 + $1.value }" : "shares.reduce(0) { $0 + $1.value }"
            lines += [
                "        .chartBackground { proxy in",
                "            GeometryReader { geometry in",
                "                if let plot = proxy.plotFrame {",
                "                    let frame = geometry[plot]",
                "                    VStack {",
                "                        Text(\(label)).font(.caption).foregroundStyle(.secondary)",
                "                        Text(\(value), format: .currency(code: \"MYR\").precision(.fractionLength(0)))",
                "                            .font(.headline)",
                "                    }",
                "                    .position(x: frame.midX, y: frame.midY)",
                "                }",
                "            }",
                "        }",
            ]
        }
        lines += ["        .frame(height: 200)", "    }", "}"]
        return lines.joined(separator: "\n")
    }

    static func feed(_ o: LabOptions, list: Bool) -> String {
        let arrival = o.text("arrival")
        let timestamps = o.flag("timestamps")
        let transition: String = switch o.text("transition") {
        case "move": ".move(edge: .top)"
        case "opacity": ".opacity"
        case "scale": ".scale(scale: 0.85).combined(with: .opacity)"
        default: ".push(from: .top)"
        }

        var lines = [
            "import SwiftUI",
            "",
            "struct OrderEvent: Identifiable {",
            "    let id = UUID()",
            "    let symbol: String   // \"checkmark.seal\"",
            "    let title: String    // \"Order #4821 confirmed\"",
            "    let detail: String   // \"Jaya Grocer Bangsar · RM 2,665.20\"",
            "    let date = Date.now",
            "}",
            "",
            "struct OrderFeed: View {",
            "    @State private var events: [OrderEvent] = []",
            "    @Environment(\\.accessibilityReduceMotion) private var reduceMotion",
            "",
            "    var body: some View {",
            "        VStack(alignment: .leading) {",
            "            HStack {",
            "                Text(\"Shah Alam DC\").font(.headline)",
            "                Spacer()",
            "                Button(\"Simulate event\", action: arrive)",
            "            }",
        ]
        let row = [
            "HStack {",
            "    Image(systemName: event.symbol).foregroundStyle(.tint)",
            "    VStack(alignment: .leading) {",
            "        Text(event.title)",
            "        Text(event.detail).font(.caption).foregroundStyle(.secondary)",
            "    }",
        ] + (timestamps ? [
            "    Spacer()",
            "    Text(event.date, format: .dateTime.hour().minute().second())",
            "        .font(.caption).monospacedDigit().foregroundStyle(.secondary)",
        ] : []) + ["}"]

        if list {
            lines.append("            List(events) { event in")
            lines += row.map { "                " + $0 }
            lines.append("            }")
            lines.append("            .listStyle(.\(o.text("style")))")
        } else {
            lines.append("            VStack(spacing: 6) {")
            lines.append("                ForEach(events.prefix(5)) { event in")
            lines += row.map { "                    " + $0 }
            lines.append("                    .transition(.asymmetric(insertion: \(transition), removal: .opacity))")
            lines.append("                }")
            lines.append("            }")
            lines.append("            .frame(maxHeight: .infinity, alignment: .top)")
            lines.append("            .clipped()")
        }
        lines.append("        }")
        if arrival != "manual" {
            lines += [
                "        .task {",
                "            // New events keep arriving; Reduce motion only drops the animation.",
                "            while !Task.isCancelled {",
                "                try? await Task.sleep(for: .seconds(\(arrival)))",
                "                arrive()",
                "            }",
                "        }",
            ]
        }
        lines += [
            "    }",
            "",
            "    private func arrive() {",
            "        withAnimation(reduceMotion ? nil : .smooth) {",
            "            events.insert(.next(), at: 0)",
            "        }",
            "    }",
            "}",
        ]
        return lines.joined(separator: "\n")
    }
}

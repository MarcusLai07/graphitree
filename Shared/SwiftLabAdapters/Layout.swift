import Foundation

// SwiftUI lab adapters for layout: nav, empty.
// Each adapter's view is in App/Views/SwiftLab/LayoutBlocks.swift, under the same id.
//
// The two empty states share option ids ("kind", "action", "query"), so switching between them
// keeps the person's picks, and they share their words through `SwiftLab.EmptyCopy`.

extension SwiftLab {
    static let layoutAdapters: [SwiftAdapter] = [
        // MARK: Navigation

        SwiftAdapter(
            id: "nav-split-view",
            slot: .nav,
            label: "NavigationSplitView",
            note: "Depots, their orders and one order's detail in two or three columns",
            minOS: 13,
            options: [
                .choice("columns", "Columns", [("three", "Three"), ("two", "Two")], default: "three"),
                .choice("visibility", "Showing", [("all", "All columns"), ("doubleColumn", "Double column"), ("detailOnly", "Detail only")], default: "all"),
                .toggle("badges", "Badges", default: true),
            ],
            code: { o in LayoutCode.splitView(o) }
        ),

        SwiftAdapter(
            id: "nav-tab-view",
            slot: .nav,
            label: "TabView with Tab",
            note: "The macOS 15 Tab API: tabs that become a sidebar with `.sidebarAdaptable`, with sections and badges",
            minOS: 15,
            options: [
                .choice("style", "Style", [("sidebarAdaptable", "Sidebar adaptable"), ("tabBarOnly", "Tab bar only"), ("grouped", "Grouped"), ("automatic", "Automatic")], default: "sidebarAdaptable"),
                .toggle("sections", "Depot section", default: true),
                .toggle("badges", "Badges", default: true),
            ],
            code: { o in LayoutCode.tabView(o) }
        ),

        // MARK: Empty state

        SwiftAdapter(
            id: "empty-unavailable",
            slot: .empty,
            label: "ContentUnavailableView",
            note: "The system empty state: the ready-made search one, or your own label, description and actions",
            minOS: 14,
            options: [
                .choice("kind", "Kind", EmptyCopy.kinds, default: "orders"),
                .toggle("action", "Action", default: true),
                .text("query", "Search text", default: "Milo 1kg"),
            ],
            code: { o in LayoutCode.unavailable(o) }
        ),

        SwiftAdapter(
            id: "empty-hand-built",
            slot: .empty,
            label: "Hand-built empty state",
            note: "An SF Symbol, two lines of text and a button in a VStack: what you'd write before macOS 14",
            minOS: 13,
            handBuilt: true,
            options: [
                .choice("kind", "Kind", EmptyCopy.kinds, default: "orders"),
                .toggle("action", "Action", default: true),
                .text("query", "Search text", default: "Milo 1kg"),
                .toggle("circle", "Symbol in a circle", default: false),
            ],
            code: { o in LayoutCode.handBuilt(o) }
        ),
    ]

    /// The words of each kind of empty state, shared by the code and the views.
    struct EmptyCopy {
        let symbol: String
        let title: String
        let description: String
        let action: String

        static let kinds = [("orders", "No orders"), ("search", "Search"), ("custom", "Custom")]

        static func of(_ kind: String, query: String) -> EmptyCopy {
            switch kind {
            case "search":
                EmptyCopy(
                    symbol: "magnifyingglass",
                    title: query.isEmpty ? "No Results" : "No Results for “\(query)”",
                    description: "Check the spelling or try a new search.",
                    action: "Clear search"
                )
            case "custom":
                EmptyCopy(
                    symbol: "truck.box",
                    title: "No deliveries today",
                    description: "Shah Alam DC has nothing scheduled to leave today.",
                    action: "Schedule a delivery"
                )
            default:
                EmptyCopy(
                    symbol: "tray",
                    title: "No orders yet",
                    description: "Orders for Shah Alam DC show up here once a customer confirms one.",
                    action: "New order"
                )
            }
        }
    }
}

/// Code fragments the layout adapters share.
private enum LayoutCode {
    /// A Swift string literal for `text`.
    static func literal(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    static func splitView(_ o: LabOptions) -> String {
        let three = o.text("columns") != "two"
        let badges = o.flag("badges")
        let visibility = o.text("visibility")
        var lines = [
            "import SwiftUI",
            "",
            "struct Order: Identifiable {",
            "    let id: String          // \"#4821\"",
            "    let customer: String    // \"Jaya Grocer Bangsar\"",
            "    let depot: String       // \"Shah Alam DC\"",
            "    let total: Double",
            "}",
            "",
            "struct DepotBrowser: View {",
            "    let orders: [Order]",
        ]
        if three {
            lines += [
                "    let depots: [String]",
                "    @State private var depot: String? = \"Shah Alam DC\"",
            ]
        }
        lines += [
            "    @State private var selection: Order.ID? = \"#4821\"",
            "    @State private var visibility = NavigationSplitViewVisibility.\(visibility)",
            "",
            "    var body: some View {",
            "        NavigationSplitView(columnVisibility: $visibility) {",
        ]
        if three {
            lines += [
                "            List(depots, id: \\.self, selection: $depot) { depot in",
                "                Label(depot, systemImage: \"building.2\")",
            ]
            if badges { lines.append("                    .badge(orders.filter { $0.depot == depot }.count)") }
            lines += [
                "            }",
                "            .navigationSplitViewColumnWidth(min: 180, ideal: 180)",
                "        } content: {",
                "            List(orders.filter { $0.depot == depot }, selection: $selection) { order in",
            ]
        } else {
            lines.append("            List(orders, selection: $selection) { order in")
        }
        lines += [
            "                VStack(alignment: .leading) {",
            "                    Text(order.id).font(.headline)",
            "                    Text(order.customer).foregroundStyle(.secondary)",
            "                }",
        ]
        if badges && !three { lines.append("                .badge(Text(order.total, format: .currency(code: \"MYR\").precision(.fractionLength(0))))") }
        lines += [
            "            }",
            "            .navigationSplitViewColumnWidth(min: \(three ? "180, ideal: 190" : "240, ideal: 260"))",
            "        } detail: {",
            "            if let order = orders.first(where: { $0.id == selection }) {",
            "                OrderDetail(order: order)",
            "            } else {",
            "                Text(\"Select an order\").foregroundStyle(.secondary)",
            "            }",
            "        }",
            "    }",
            "}",
        ]
        return lines.joined(separator: "\n")
    }

    static func tabView(_ o: LabOptions) -> String {
        var lines = [
            "import SwiftUI",
            "",
            "struct OrdersTabs: View {",
            "    let depots: [String]",
            "    @State private var tab = \"orders\"",
            "",
            "    var body: some View {",
            "        TabView(selection: $tab) {",
            "            Tab(\"Orders\", systemImage: \"shippingbox\", value: \"orders\") {",
            "                OrdersList()",
            "            }",
        ]
        if o.flag("badges") { lines.append("            .badge(5)") }
        lines += [
            "            Tab(\"Deliveries\", systemImage: \"truck.box\", value: \"deliveries\") {",
            "                DeliveriesList()",
            "            }",
        ]
        if o.flag("badges") { lines.append("            .badge(2)") }
        if o.flag("sections") {
            lines += [
                "            TabSection(\"Depots\") {",
                "                ForEach(depots, id: \\.self) { depot in",
                "                    Tab(depot, systemImage: \"building.2\", value: depot) {",
                "                        DepotSummary(depot: depot)",
                "                    }",
                "                }",
                "            }",
            ]
        }
        lines += [
            "        }",
            "        .tabViewStyle(.\(o.text("style")))",
            "    }",
            "}",
        ]
        return lines.joined(separator: "\n")
    }

    static func unavailable(_ o: LabOptions) -> String {
        let kind = o.text("kind")
        let query = o.text("query")
        let copy = SwiftLab.EmptyCopy.of(kind, query: query)
        var lines = ["import SwiftUI", ""]
        if kind == "search" {
            let search = query.isEmpty ? "ContentUnavailableView.search" : "ContentUnavailableView.search(text: \(literal(query)))"
            if o.flag("action") {
                lines += [
                    "// The ready-made search view has no actions, so the button goes under it.",
                    "VStack {",
                    "    \(search)",
                    "    Button(\(literal(copy.action))) { query = \"\" }",
                    "}",
                ]
            } else {
                lines.append(search)
            }
            return lines.joined(separator: "\n")
        }
        lines += [
            "ContentUnavailableView {",
            "    Label(\(literal(copy.title)), systemImage: \(literal(copy.symbol)))",
            "} description: {",
            "    Text(\(literal(copy.description)))",
        ]
        if o.flag("action") {
            lines += [
                "} actions: {",
                "    Button(\(literal(copy.action))) { create() }",
                "        .buttonStyle(.borderedProminent)",
            ]
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    static func handBuilt(_ o: LabOptions) -> String {
        let copy = SwiftLab.EmptyCopy.of(o.text("kind"), query: o.text("query"))
        var lines = [
            "import SwiftUI",
            "",
            "VStack(spacing: 8) {",
            "    Image(systemName: \(literal(copy.symbol)))",
        ]
        if o.flag("circle") {
            lines += [
                "        .font(.system(size: 28))",
                "        .foregroundStyle(.tint)",
                "        .frame(width: 64, height: 64)",
                "        .background(.tint.opacity(0.12), in: Circle())",
            ]
        } else {
            lines += [
                "        .font(.system(size: 40))",
                "        .foregroundStyle(.secondary)",
            ]
        }
        lines += [
            "    Text(\(literal(copy.title)))",
            "        .font(.title2.bold())",
            "    Text(\(literal(copy.description)))",
            "        .foregroundStyle(.secondary)",
            "        .multilineTextAlignment(.center)",
        ]
        if o.flag("action") {
            lines += [
                "    Button(\(literal(copy.action))) { create() }",
                "        .buttonStyle(.borderedProminent)",
                "        .padding(.top, 4)",
            ]
        }
        lines += [
            "}",
            ".frame(maxWidth: 340)",
            ".frame(maxWidth: .infinity, maxHeight: .infinity)",
        ]
        return lines.joined(separator: "\n")
    }
}

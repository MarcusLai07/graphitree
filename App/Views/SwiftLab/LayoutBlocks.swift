import SwiftUI

// Views for the layout adapters in Shared/SwiftLabAdapters/Layout.swift.

enum LayoutBlocks {
    static let views: [String: SwiftLabViews.Make] = [
        "nav-split-view": { AnyView(SplitViewBlock(options: $0)) },
        "nav-tab-view": { AnyView(TabViewBlock(options: $0)) },
        "empty-unavailable": { AnyView(UnavailableBlock(options: $0)) },
        "empty-hand-built": { AnyView(HandBuiltEmptyBlock(options: $0)) },
    ]
}

// Keeping navigation inside its block. On macOS 26 and later, checked in a window that bridges
// toolbars as the lab's does:
// - NavigationSplitView and a `.sidebarAdaptable` TabView add a sidebar toggle to the window's
//   toolbar. `.toolbar(removing: .sidebarToggle)` stops it only from inside the sidebar: on the
//   sidebar column's view, or in `tabViewSidebarHeader`. On the split view itself it does nothing.
//   It also hides a `navigationSplitViewColumnWidth` applied before it, so it goes first.
// - A TabView's tab bar becomes a "Navigation Tab Bar" item in the window's toolbar, whatever is
//   above it, unless it's inside a ScrollView or uses `.grouped`.
// None of this is in the adapters' code: in an app of its own, those items belong in the toolbar.

private extension View {
    /// A small window for the navigation blocks: a fixed height and a rounded edge.
    func miniWindow() -> some View {
        frame(height: 280)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }
}

// MARK: - Navigation

private struct SplitViewBlock: View {
    let options: LabOptions
    @State private var depot: String? = "Shah Alam DC"
    @State private var selection: LabSample.Order.ID? = "#4821"
    @State private var visibility = NavigationSplitViewVisibility.all
    @Environment(\.labMotion) private var motion

    private var badges: Bool { options.flag("badges") }

    private func orders(at depot: String?) -> [LabSample.Order] {
        LabSample.orders.filter { $0.depot == depot }
    }

    var body: some View {
        Group {
            if options.text("columns") == "two" {
                NavigationSplitView(columnVisibility: $visibility) {
                    orderList(LabSample.orders, totals: badges)
                        .toolbar(removing: .sidebarToggle)
                        .navigationSplitViewColumnWidth(min: 240, ideal: 260)
                } detail: {
                    detail
                }
            } else {
                NavigationSplitView(columnVisibility: $visibility) {
                    List(LabSample.depots, id: \.self, selection: $depot) { depot in
                        Label(depot, systemImage: "building.2")
                            .lineLimit(1)
                            .badge(badges ? orders(at: depot).count : 0)
                    }
                    .toolbar(removing: .sidebarToggle)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 180)
                } content: {
                    orderList(orders(at: depot), totals: false)
                        .navigationSplitViewColumnWidth(min: 180, ideal: 190)
                } detail: {
                    detail
                }
            }
        }
        .miniWindow()
        .onChange(of: options.text("visibility"), initial: true) { _, value in
            let next: NavigationSplitViewVisibility = switch value {
            case "doubleColumn": .doubleColumn
            case "detailOnly": .detailOnly
            default: .all
            }
            if next != visibility { motion.perform { visibility = next } }
        }
        .onChange(of: depot) {
            if !orders(at: depot).contains(where: { $0.id == selection }) {
                selection = orders(at: depot).first?.id
            }
        }
    }

    private func orderList(_ orders: [LabSample.Order], totals: Bool) -> some View {
        List(orders, selection: $selection) { order in
            VStack(alignment: .leading, spacing: 2) {
                Text("Order \(order.id)").font(.headline)
                Text(order.customer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .badge(totals ? Text(order.total.formatted(LabSample.ringgit.precision(.fractionLength(0)))) : nil)
        }
        .overlay {
            if orders.isEmpty {
                Text("No orders").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let order = LabSample.orders.first(where: { $0.id == selection }) {
            OrderDetail(order: order)
        } else {
            Text("Select an order")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct OrderDetail: View {
    let order: LabSample.Order

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Order \(order.id)").font(.title2.bold())
                Spacer()
                Text("Picking")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.tint.opacity(0.15), in: .capsule)
            }
            Text(order.customer).font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Depot").foregroundStyle(.secondary)
                    Text(order.depot)
                }
                GridRow {
                    Text("Total").foregroundStyle(.secondary)
                    Text(order.total.formatted(LabSample.ringgit)).monospacedDigit()
                }
                GridRow {
                    Text("Delivery").foregroundStyle(.secondary)
                    Text("Tomorrow, 9:00–12:00")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct TabViewBlock: View {
    let options: LabOptions
    @State private var tab = "orders"

    private var badges: Bool { options.flag("badges") }

    var body: some View {
        styled(TabView(selection: $tab) {
            Tab("Orders", systemImage: "shippingbox", value: "orders") {
                TabPane(title: "Open orders", rows: LabSample.orders.prefix(4).map {
                    ("Order \($0.id)", $0.customer, $0.total.formatted(LabSample.ringgit))
                })
            }
            .badge(badges ? LabSample.orders.count : 0)
            Tab("Deliveries", systemImage: "truck.box", value: "deliveries") {
                TabPane(title: "Out today", rows: [
                    ("Order #4817", "99 Speedmart Puchong", "10:30"),
                    ("Order #4821", "Jaya Grocer Bangsar", "14:00"),
                ])
            }
            .badge(badges ? 2 : 0)
            if options.flag("sections") {
                TabSection("Depots") {
                    ForEach(LabSample.depots, id: \.self) { depot in
                        Tab(depot, systemImage: "building.2", value: depot) {
                            TabPane(title: depot, rows: LabSample.orders.filter { $0.depot == depot }.map {
                                ("Order \($0.id)", $0.customer, $0.total.formatted(LabSample.ringgit))
                            })
                        }
                    }
                }
            }
        }
        .tabViewSidebarHeader {
            // Only from inside the sidebar does this keep the toggle out of the lab's toolbar.
            Text("Sales desk")
                .font(.caption)
                .foregroundStyle(.secondary)
                // The sidebar is as wide as its widest view; this keeps the depots' names whole.
                .frame(minWidth: 190, alignment: .leading)
                .toolbar(removing: .sidebarToggle)
        })
        .frame(height: 280)
        // A ScrollView that doesn't scroll, so the tab bar stays in the block.
        .wrappedInScrollView()
        .miniWindow()
        .onChange(of: options.flag("sections")) {
            if LabSample.depots.contains(tab) { tab = "orders" }
        }
    }

    @ViewBuilder
    private func styled(_ tabs: some View) -> some View {
        switch options.text("style") {
        case "tabBarOnly": tabs.tabViewStyle(.tabBarOnly)
        case "grouped": tabs.tabViewStyle(.grouped)
        case "automatic": tabs.tabViewStyle(.automatic)
        default: tabs.tabViewStyle(.sidebarAdaptable)
        }
    }
}

private extension View {
    func wrappedInScrollView() -> some View {
        ScrollView { self }
            .scrollDisabled(true)
            .scrollIndicators(.never)
    }
}

/// One tab's content: a title and a few rows.
private struct TabPane: View {
    let title: String
    let rows: [(String, String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if rows.isEmpty {
                Text("No open orders").foregroundStyle(.secondary)
            }
            ForEach(rows.indices, id: \.self) { i in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(rows[i].0)
                        Text(rows[i].1).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(rows[i].2).monospacedDigit().foregroundStyle(.secondary)
                }
                .lineLimit(1)
                if i < rows.count - 1 { Divider() }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Empty state

/// The box an empty state sits in. Its action fills the box with orders, and a link empties it
/// again, so the change between the two can be seen.
private struct EmptyStateFrame<Empty: View>: View {
    @Binding var filled: Bool
    @ViewBuilder let empty: Empty
    @Environment(\.labMotion) private var motion

    var body: some View {
        ZStack {
            if filled {
                orders.transition(.opacity)
            } else {
                empty.transition(.opacity)
            }
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }

    private var orders: some View {
        let orders = LabSample.orders.filter { $0.depot == "Shah Alam DC" }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Shah Alam DC · \(orders.count) orders").font(.headline)
                Spacer()
                Button("Empty it again") { motion.perform { filled = false } }
                    .buttonStyle(.link)
            }
            ForEach(orders) { order in
                HStack {
                    Text("Order \(order.id)")
                    Text(order.customer).foregroundStyle(.secondary)
                    Spacer()
                    Text(order.total.formatted(LabSample.ringgit)).monospacedDigit()
                }
                Divider()
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }
}

private struct UnavailableBlock: View {
    let options: LabOptions
    @State private var filled = false
    @Environment(\.labMotion) private var motion

    var body: some View {
        let query = options.text("query")
        let copy = SwiftLab.EmptyCopy.of(options.text("kind"), query: query)
        EmptyStateFrame(filled: $filled) {
            if options.text("kind") == "search" {
                // The ready-made search view has no actions, so the button goes under it.
                VStack {
                    if query.isEmpty {
                        ContentUnavailableView.search
                    } else {
                        ContentUnavailableView.search(text: query)
                    }
                    if options.flag("action") {
                        Button(copy.action, action: fill)
                            .padding(.bottom, 20)
                    }
                }
            } else {
                ContentUnavailableView {
                    Label(copy.title, systemImage: copy.symbol)
                } description: {
                    Text(copy.description)
                } actions: {
                    if options.flag("action") {
                        Button(copy.action, action: fill)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private func fill() {
        motion.perform { filled = true }
    }
}

private struct HandBuiltEmptyBlock: View {
    let options: LabOptions
    @State private var filled = false
    @Environment(\.labMotion) private var motion

    var body: some View {
        let copy = SwiftLab.EmptyCopy.of(options.text("kind"), query: options.text("query"))
        EmptyStateFrame(filled: $filled) {
            VStack(spacing: 8) {
                symbol(copy.symbol)
                Text(copy.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(copy.description)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if options.flag("action") {
                    Button(copy.action) { motion.perform { filled = true } }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func symbol(_ name: String) -> some View {
        if options.flag("circle") {
            Image(systemName: name)
                .font(.system(size: 28))
                .foregroundStyle(.tint)
                .frame(width: 64, height: 64)
                .background(.tint.opacity(0.12), in: Circle())
        } else {
            Image(systemName: name)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        }
    }
}

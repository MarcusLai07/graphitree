import SwiftUI
import Symbols

// Views for the control adapters in Shared/SwiftLabAdapters/Controls.swift.
// Panel-like blocks (banners, the inspector, the filter list, the tab views) sit in a MiniWindow,
// a fixed frame with a title strip and a rounded border, so they read as a small window in the
// canvas and never reach for the lab window's own toolbar.

enum ControlBlocks {
    static let views: [String: SwiftLabViews.Make] = [
        "button-swiftui": { AnyView(SystemButtonBlock(options: $0)) },
        "button-glass": { AnyView(GlassButtonBlock(options: $0)) },
        "button-symbol-effect": { AnyView(SymbolEffectButtonBlock(options: $0)) },
        "banner-overlay": { AnyView(OverlayBannerBlock(options: $0)) },
        "banner-glass": { AnyView(GlassBannerBlock(options: $0)) },
        "banner-stack": { AnyView(ToastStackBlock(options: $0)) },
        "sheet-sheet": { AnyView(SheetBlock(options: $0)) },
        "sheet-popover": { AnyView(PopoverBlock(options: $0)) },
        "sheet-inspector": { AnyView(InspectorBlock(options: $0)) },
        "sheet-confirmation": { AnyView(ConfirmationBlock(options: $0)) },
        "picker-swiftui": { AnyView(SystemPickerBlock(options: $0)) },
        "picker-menu": { AnyView(CommandMenuBlock(options: $0)) },
        "picker-filter": { AnyView(FilterListBlock(options: $0)) },
        "tabs-tabview": { AnyView(TabViewBlock(options: $0)) },
        "tabs-segmented": { AnyView(PickerTabsBlock(options: $0, tabsStyle: false)) },
        "tabs-picker-tabs": { AnyView(PickerTabsBlock(options: $0, tabsStyle: true)) },
    ]
}

// MARK: - Shared parts

/// A small window inside the canvas: traffic-light dots, a title, an accessory on the right,
/// and the content in a fixed height.
private struct MiniWindow<Accessory: View, Content: View>: View {
    let title: String
    let height: CGFloat
    let accessory: Accessory
    let content: Content

    init(_ title: String, height: CGFloat = 240, @ViewBuilder accessory: () -> Accessory, @ViewBuilder content: () -> Content) {
        self.title = title
        self.height = height
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(.quaternary).frame(width: 9, height: 9)
                }
                Text(title)
                    .font(.callout.weight(.semibold))
                    .padding(.leading, 8)
                Spacer(minLength: 8)
                accessory
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(.bar)
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(.background)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }
}

extension MiniWindow where Accessory == EmptyView {
    init(_ title: String, height: CGFloat = 240, @ViewBuilder content: () -> Content) {
        self.init(title, height: height, accessory: { EmptyView() }, content: content)
    }
}

/// The card most single-control blocks sit on, matching `button-swiftui`.
private extension View {
    func blockCard() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: 10))
    }

    @ViewBuilder
    func labelsHidden(_ hidden: Bool) -> some View {
        if hidden { labelsHidden() } else { self }
    }
}

private struct OrderRow: View {
    let order: LabSample.Order

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("Order \(order.id) · \(order.customer)").font(.callout)
                Text(order.depot).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(order.total.formatted(LabSample.ringgit))
                .font(.callout)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// The lines of order #4821, which add up to its RM 2,665.20.
private enum OrderLines {
    static let all: [(item: String, quantity: Int, total: Double)] = [
        ("Beras wangi 10kg", 40, 1120.00),
        ("Minyak masak 5kg", 30, 945.00),
        ("Gula pasir 1kg", 120, 342.00),
        ("Teh tarik 3-in-1", 24, 258.20),
    ]
}

// MARK: - Button

private struct SystemButtonBlock: View {
    let options: LabOptions
    @State private var confirmed = 0
    @Environment(\.labMotion) private var motion

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Order #4821").font(.headline)
                Text(confirmed == 0 ? "Jaya Grocer Bangsar · 4 lines · RM 2,665.20" : "Confirmed \(confirmed)× · picking at Shah Alam DC")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer()
            styled(button)
        }
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }

    private var role: ButtonRole? {
        switch options.text("role") {
        case "destructive": .destructive
        case "cancel": .cancel
        default: nil
        }
    }

    private var button: some View {
        Button(role: role) {
            motion.perform { confirmed += 1 }
        } label: {
            if options.flag("symbol") {
                Label("Confirm order", systemImage: "checkmark.circle")
            } else {
                Text("Confirm order")
            }
        }
    }

    @ViewBuilder
    private func styled(_ button: some View) -> some View {
        switch options.text("style") {
        case "bordered": button.buttonStyle(.bordered)
        case "borderedProminent": button.buttonStyle(.borderedProminent)
        case "borderless": button.buttonStyle(.borderless)
        case "link": button.buttonStyle(.link)
        default: button.buttonStyle(.automatic)
        }
    }
}

private struct GlassButtonBlock: View {
    let options: LabOptions
    @State private var status = "Jaya Grocer Bangsar · 4 lines · RM 2,665.20"
    @Environment(\.labMotion) private var motion

    var body: some View {
        if options.flag("backdrop") {
            // Glass is made to float over content: the lines show through it, bent at the edges.
            VStack(alignment: .leading, spacing: 5) {
                Text("Order #4821 · Jaya Grocer Bangsar").font(.headline)
                ForEach(OrderLines.all, id: \.item) { line in
                    HStack {
                        Text("\(line.item) × \(line.quantity)")
                        Spacer()
                        Text(line.total.formatted(LabSample.ringgit)).monospacedDigit()
                    }
                    .font(.callout)
                }
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .overlay(alignment: .trailing) { buttons }
            .blockCard()
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Order #4821").font(.headline)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                Spacer()
                buttons
            }
            .blockCard()
        }
    }

    private func set(_ text: String) {
        motion.perform { status = text }
    }

    @ViewBuilder
    private var buttons: some View {
        if #available(macOS 26, *) {
            glassButtons
        } else {
            HStack(spacing: 8) {
                Text("Liquid Glass needs macOS 26").font(.caption).foregroundStyle(.secondary)
                Button("Confirm order") { set("Confirmed · picking at Shah Alam DC") }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @available(macOS 26, *)
    @ViewBuilder
    private var glassButtons: some View {
        let shape: ButtonBorderShape = options.text("shape") == "roundedRectangle" ? .roundedRectangle : .capsule
        if options.flag("container") {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 8) {
                    Button("Hold") { set("On hold · Shah Alam DC keeps the stock") }
                        .buttonStyle(.glass)
                    styled(confirm)
                }
            }
            .buttonBorderShape(shape)
        } else {
            styled(confirm)
                .buttonBorderShape(shape)
        }
    }

    private var confirm: some View {
        Button {
            set("Confirmed · picking at Shah Alam DC")
        } label: {
            Label("Confirm order", systemImage: "checkmark.circle")
        }
    }

    @available(macOS 26, *)
    @ViewBuilder
    private func styled(_ button: some View) -> some View {
        switch options.text("style") {
        case "clear": button.buttonStyle(.glass(.clear))
        case "glassProminent": button.buttonStyle(.glassProminent)
        default: button.buttonStyle(.glass)
        }
    }
}

private struct SymbolEffectButtonBlock: View {
    let options: LabOptions
    @State private var runs = 0
    @State private var working = false
    @Environment(\.labMotion) private var motion

    private var content: (title: String, symbol: String) { SwiftLab.symbolButtonContent(options.text("symbol")) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: content.symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.12), in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(headline).font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer()
            Button {
                motion.perform { runs += 1 }
            } label: {
                Label(content.title, systemImage: content.symbol)
            }
            .buttonStyle(.bordered)
            .disabled(working)
        }
        // On the row, so it plays on every symbol in it: the tile's and the button's.
        .modifier(SymbolEffectPlayer(effect: options.text("effect"), play: options.text("play"), runs: runs, working: working, reduce: motion.reduce))
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
        .task(id: runs) {
            // "While working" stands for two seconds of work after each click.
            guard runs > 0, options.text("play") == "working" else { return }
            working = true
            try? await Task.sleep(for: .seconds(2))
            working = false
        }
    }

    private var headline: String {
        switch options.text("symbol") {
        case "notify": "Penang Hub"
        case "dispatch": "Order #4821 · Jaya Grocer Bangsar"
        default: "Stock at Shah Alam DC"
        }
    }

    private var status: String {
        if working {
            return switch options.text("symbol") {
            case "notify": "Notifying the depot…"
            case "dispatch": "Booking a lorry…"
            default: "Syncing 1,284 SKUs…"
            }
        }
        if runs == 0 {
            return switch options.text("symbol") {
            case "notify": "Pick-up at 14:30 · 6 orders waiting"
            case "dispatch": "Packed · 4 cartons · RM 2,665.20"
            default: "1,284 SKUs · last synced 09:12"
            }
        }
        return switch options.text("symbol") {
        case "notify": "Notified \(runs)× · driver on the way"
        case "dispatch": "Dispatched \(runs)× · out for delivery"
        default: "Synced \(runs)× · 1,284 SKUs up to date"
        }
    }
}

/// Plays one symbol effect: once per change of `runs`, while `working`, or all the time.
/// The last two repeat on their own, so they stop when motion is reduced.
private struct SymbolEffectPlayer: ViewModifier {
    let effect: String
    let play: String
    let runs: Int
    let working: Bool
    let reduce: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        switch effect {
        case "wiggle": apply(.wiggle, to: content)
        case "breathe": apply(.breathe, to: content)
        case "rotate": apply(.rotate, to: content)
        default: apply(.bounce, to: content)
        }
    }

    @ViewBuilder
    private func apply<Effect: SymbolEffect & DiscreteSymbolEffect & IndefiniteSymbolEffect>(_ effect: Effect, to content: Content) -> some View {
        switch play {
        case "working": content.symbolEffect(effect, isActive: working && !reduce)
        case "always": content.symbolEffect(effect, isActive: !reduce)
        default: content.symbolEffect(effect, value: runs)
        }
    }
}

// MARK: - Banner

/// What a banner appears over, and its timing. The banner shows once when the block appears and
/// again on each click; with auto-dismiss on, it leaves after three seconds.
private struct BannerStage<Banner: View>: View {
    let options: LabOptions
    @ViewBuilder let banner: (_ dismiss: @escaping () -> Void) -> Banner
    @State private var shown = false
    @State private var shows = 0
    @Environment(\.labMotion) private var motion

    private var edge: Edge { options.text("edge") == "bottom" ? .bottom : .top }

    var body: some View {
        MiniWindow("Orders · Shah Alam DC", height: 240) {
            Button("Confirm order #4821", action: show)
        } content: {
            VStack(spacing: 0) {
                ForEach(LabSample.orders.prefix(4)) { order in
                    OrderRow(order: order)
                    Divider()
                }
                Spacer(minLength: 0)
            }
            .overlay(alignment: edge == .top ? .top : .bottom) {
                if shown {
                    banner(dismiss)
                        .padding(10)
                        .transition(motion.reduce ? .opacity : .move(edge: edge).combined(with: .opacity))
                }
            }
            .clipped()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            if shows == 0 { show() }
        }
        .task(id: "\(shows) \(options.flag("autoDismiss"))") {
            guard shown, options.flag("autoDismiss") else { return }
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { dismiss() }
        }
    }

    private func show() {
        motion.perform { shown = true }
        shows += 1
    }

    private func dismiss() {
        motion.perform { shown = false }
    }
}

private struct OverlayBannerBlock: View {
    let options: LabOptions

    var body: some View {
        BannerStage(options: options) { dismiss in
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Order #4821 confirmed").font(.callout.weight(.semibold))
                    Text("Picking starts at Shah Alam DC").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                if options.flag("action") {
                    Button("Undo", action: dismiss)
                        .buttonStyle(.borderless)
                }
                if !options.flag("autoDismiss") {
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Dismiss")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 420)
            .background { bannerBackground }
        }
    }

    @ViewBuilder
    private var bannerBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        if options.text("style") == "tinted" {
            shape.fill(.background)
                .overlay(shape.fill(.tint.opacity(0.14)))
                .overlay(shape.strokeBorder(.tint.opacity(0.35)))
        } else {
            shape.fill(.regularMaterial)
                .overlay(shape.strokeBorder(.separator))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
    }
}

private struct GlassBannerBlock: View {
    let options: LabOptions
    @Namespace private var glassSpace

    var body: some View {
        BannerStage(options: options) { dismiss in
            if #available(macOS 26, *) {
                glassBanner(dismiss)
            } else {
                message
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: .capsule)
            }
        }
    }

    private var message: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Order #4821 confirmed").font(.callout.weight(.semibold))
                Text("Picking starts at Shah Alam DC").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @available(macOS 26, *)
    private func glassBanner(_ dismiss: @escaping () -> Void) -> some View {
        let rounded = options.text("shape") == "rounded"
        let glass: Glass = options.flag("tint") ? .regular.tint(.green.opacity(0.35)) : .regular
        return GlassEffectContainer(spacing: 10) {
            HStack(spacing: 6) {
                message
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(glass, in: rounded ? AnyShape(.rect(cornerRadius: 14)) : AnyShape(.capsule))
                    .glassEffectID("banner", in: glassSpace)
                Button("Undo", action: dismiss)
                    .buttonStyle(.glass)
                    .buttonBorderShape(rounded ? .roundedRectangle : .capsule)
                    .controlSize(.large)
                    .glassEffectID("undo", in: glassSpace)
            }
        }
    }
}

private struct LabToast: Identifiable, Equatable {
    enum Kind { case success, warning, info, error }

    let id: Int
    let kind: Kind
    let title: String
    let detail: String

    var symbol: String {
        switch kind {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch kind {
        case .success: .green
        case .warning: .orange
        case .info: .blue
        case .error: .red
        }
    }

    static let samples: [(Kind, String, String)] = [
        (.success, "Order #4826 confirmed", "Mydin Subang Jaya · RM 3,920.00"),
        (.warning, "Low stock at Penang Hub", "Minyak masak 5kg · 12 cartons left"),
        (.info, "Invoice INV-2207 sent", "99 Speedmart Puchong · RM 1,180.50"),
        (.error, "Route KK-03 delayed", "Kota Kinabalu Depot · 45 min late"),
        (.success, "Order #4821 picked", "Jaya Grocer Bangsar · Shah Alam DC"),
    ]

    static func sample(_ index: Int) -> LabToast {
        let (kind, title, detail) = samples[index % samples.count]
        return LabToast(id: index, kind: kind, title: title, detail: detail)
    }
}

private struct ToastStackBlock: View {
    let options: LabOptions
    @State private var toasts = (0..<3).map(LabToast.sample)
    @State private var next = 3
    @State private var hovering = false
    @Environment(\.labMotion) private var motion

    private let toastHeight: CGFloat = 54
    private var bottom: Bool { options.text("edge") != "top" }
    private var expanded: Bool {
        switch options.text("expand") {
        case "always": true
        case "never": false
        default: hovering
        }
    }

    var body: some View {
        MiniWindow("Activity · Shah Alam DC", height: 270) {
            Button("Add toast", action: add)
        } content: {
            VStack(spacing: 0) {
                ForEach(LabSample.orders) { order in
                    OrderRow(order: order)
                    Divider()
                }
                Spacer(minLength: 0)
            }
            .overlay(alignment: bottom ? .bottomTrailing : .topTrailing) {
                stack.padding(12)
            }
            .clipped()
        }
    }

    private var stack: some View {
        let visible = Array(toasts.suffix(3))
        let gap: CGFloat = expanded ? toastHeight + 8 : 10
        return ZStack(alignment: bottom ? .bottom : .top) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, toast in
                let depth = visible.count - 1 - index
                ToastRow(toast: toast, rich: options.flag("richColors"), height: toastHeight)
                    .scaleEffect(expanded ? 1 : 1 - CGFloat(depth) * 0.05, anchor: bottom ? .top : .bottom)
                    .offset(y: CGFloat(depth) * gap * (bottom ? -1 : 1))
                    .zIndex(Double(index))
                    .transition(.asymmetric(
                        insertion: motion.reduce ? .opacity : .move(edge: bottom ? .bottom : .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .task(id: hovering || !options.flag("autoDismiss")) {
                        // Paused while the pointer is over the stack, as Sonner does.
                        guard options.flag("autoDismiss"), !hovering else { return }
                        try? await Task.sleep(for: .seconds(4))
                        if !Task.isCancelled { motion.perform { toasts.removeAll { $0.id == toast.id } } }
                    }
            }
        }
        .frame(width: 320)
        // Tall enough for the fanned-out stack, so hovering a toast behind doesn't collapse it.
        .frame(height: toastHeight + CGFloat(max(visible.count - 1, 0)) * gap, alignment: bottom ? .bottom : .top)
        .contentShape(Rectangle())
        .onHover { inside in
            guard options.text("expand") == "hover" else { return }
            motion.perform { hovering = inside }
        }
    }

    private func add() {
        let toast = LabToast.sample(next)
        next += 1
        motion.perform {
            toasts.append(toast)
            if toasts.count > 6 { toasts.removeFirst() }
        }
    }
}

private struct ToastRow: View {
    let toast: LabToast
    let rich: Bool
    let height: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        HStack(spacing: 10) {
            Image(systemName: toast.symbol)
                .font(.title3)
                .foregroundStyle(rich ? AnyShapeStyle(toast.color) : AnyShapeStyle(.secondary))
            VStack(alignment: .leading, spacing: 1) {
                Text(toast.title).font(.callout.weight(.semibold))
                Text(toast.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: height)
        .background {
            shape.fill(.background)
            if rich { shape.fill(toast.color.opacity(0.1)) }
        }
        .overlay(shape.strokeBorder(.separator))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}

// MARK: - Sheet

private struct Delivery: Equatable {
    var depot = "Shah Alam DC"
    var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    var note = ""
}

private struct SheetBlock: View {
    let options: LabOptions
    @State private var editing = false
    @State private var delivery = Delivery()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Order #4821 · Jaya Grocer Bangsar").font(.headline)
                Text("From \(delivery.depot) on \(delivery.date.formatted(date: .abbreviated, time: .omitted))\(delivery.note.isEmpty ? "" : " · “\(delivery.note)”")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit delivery…") { editing = true }
        }
        .blockCard()
        .sheet(isPresented: $editing) {
            sized(DeliveryForm(delivery: $delivery, grouped: options.text("formStyle") != "columns"))
        }
    }

    @ViewBuilder
    private func sized(_ form: some View) -> some View {
        switch options.text("sizing") {
        case "form": form.presentationSizing(.form)
        case "page": form.presentationSizing(.page)
        case "fitted": form.presentationSizing(.fitted)
        default: form
        }
    }
}

private struct DeliveryForm: View {
    @Binding var delivery: Delivery
    let grouped: Bool
    @State private var draft: Delivery
    @Environment(\.dismiss) private var dismiss

    init(delivery: Binding<Delivery>, grouped: Bool) {
        _delivery = delivery
        self.grouped = grouped
        _draft = State(initialValue: delivery.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            if grouped {
                Form { fields }.formStyle(.grouped)
            } else {
                Form { fields }.formStyle(.columns).padding(20)
            }
            Divider()
            HStack {
                Spacer()
                // Scoped to this sheet while it's open, not to the lab window.
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    delivery = draft
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(minWidth: 380)
    }

    @ViewBuilder
    private var fields: some View {
        Section("Order #4821 · Jaya Grocer Bangsar") {
            Picker("Depot", selection: $draft.depot) {
                ForEach(LabSample.depots, id: \.self) { Text($0) }
            }
            DatePicker("Deliver on", selection: $draft.date, displayedComponents: .date)
            TextField("Note for the driver", text: $draft.note, prompt: Text("Loading bay 2, before 10am"))
        }
    }
}

private struct PopoverBlock: View {
    let options: LabOptions
    @State private var shown = false
    @State private var cartons = 4
    @State private var priority = false

    private var editing: Bool { options.text("content") == "edit" }

    private var arrowEdge: Edge {
        switch options.text("arrowEdge") {
        case "top": .top
        case "leading": .leading
        case "trailing": .trailing
        default: .bottom
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Order #4821").font(.headline)
                    if priority { Image(systemName: "flag.fill").foregroundStyle(.tint) }
                }
                Text("Jaya Grocer Bangsar · \(cartons) cartons · RM 2,665.20")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                shown.toggle()
            } label: {
                Label(editing ? "Quick edit" : "Order lines", systemImage: editing ? "slider.horizontal.3" : "list.bullet.rectangle")
            }
            .popover(isPresented: $shown, arrowEdge: arrowEdge) {
                if editing { edit } else { lines }
            }
        }
        .blockCard()
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Order #4821 · Jaya Grocer Bangsar").font(.headline)
            ForEach(OrderLines.all, id: \.item) { line in
                HStack {
                    Text("\(line.item) × \(line.quantity)")
                    Spacer(minLength: 16)
                    Text(line.total.formatted(LabSample.ringgit)).monospacedDigit()
                }
                .font(.callout)
            }
            Divider()
            HStack {
                Text("Total").font(.callout.weight(.semibold))
                Spacer()
                Text(2665.20.formatted(LabSample.ringgit)).font(.callout.weight(.semibold)).monospacedDigit()
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private var edit: some View {
        Form {
            Stepper("Cartons: \(cartons)", value: $cartons, in: 1...40)
            Toggle("Priority delivery", isOn: $priority)
        }
        .padding(16)
        .frame(width: 260)
    }
}

private struct InspectorBlock: View {
    let options: LabOptions
    @State private var shown = true
    @State private var selection: String? = "#4821"
    @Environment(\.labMotion) private var motion

    private var order: LabSample.Order? { LabSample.orders.first { $0.id == selection } }

    var body: some View {
        MiniWindow("Orders · Shah Alam DC", height: 260) {
            Button {
                motion.perform { shown.toggle() }
            } label: {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(shown ? "Hide the inspector" : "Show the inspector")
        } content: {
            List(LabSample.orders, selection: $selection) { order in
                OrderRow(order: order)
                    .padding(.horizontal, -12)
            }
            .listStyle(.inset)
            .inspector(isPresented: $shown) {
                inspector
                    .inspectorColumnWidth(options.text("width") == "wide" ? 280 : 210)
            }
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if let order {
            if options.flag("sections") {
                Form {
                    Section("Order \(order.id)") {
                        LabeledContent("Customer", value: order.customer)
                        LabeledContent("Depot", value: order.depot)
                    }
                    Section("Total") {
                        Text(order.total.formatted(LabSample.ringgit)).monospacedDigit()
                    }
                }
                .formStyle(.grouped)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Order \(order.id)").font(.headline)
                    LabeledContent("Customer", value: order.customer)
                    LabeledContent("Depot", value: order.depot)
                    LabeledContent("Total") {
                        Text(order.total.formatted(LabSample.ringgit)).monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
                .font(.callout)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Select an order")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ConfirmationBlock: View {
    let options: LabOptions
    @State private var asking = false
    @State private var cancelled = false
    @Environment(\.labMotion) private var motion

    private var titleVisibility: Visibility {
        switch options.text("titleVisibility") {
        case "visible": .visible
        case "hidden": .hidden
        default: .automatic
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Order #4821 · Jaya Grocer Bangsar").font(.headline)
                Text(cancelled ? "Cancelled · RM 2,665.20 refunded" : "Picking at Shah Alam DC · RM 2,665.20")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer()
            if cancelled {
                Button("Restore order") { motion.perform { cancelled = false } }
            } else {
                Button("Cancel order…", role: .destructive) { asking = true }
            }
        }
        .blockCard()
        .modifier(CancelDialog(isPresented: $asking, titleVisibility: titleVisibility, message: options.flag("message")) {
            motion.perform { cancelled = true }
        })
        .dialogSeverity(options.text("severity") == "critical" ? .critical : .automatic)
        .dialogIcon(options.flag("icon") ? Image(systemName: "shippingbox") : nil)
    }
}

private struct CancelDialog: ViewModifier {
    @Binding var isPresented: Bool
    let titleVisibility: Visibility
    let message: Bool
    let cancel: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if message {
            content.confirmationDialog("Cancel order #4821?", isPresented: $isPresented, titleVisibility: titleVisibility) {
                actions
            } message: {
                Text("Jaya Grocer Bangsar is refunded RM 2,665.20 and Shah Alam DC stops picking.")
            }
        } else {
            content.confirmationDialog("Cancel order #4821?", isPresented: $isPresented, titleVisibility: titleVisibility) {
                actions
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        Button("Cancel order", role: .destructive, action: cancel)
        Button("Keep order", role: .cancel) {}
    }
}

// MARK: - Picker

private struct SystemPickerBlock: View {
    let options: LabOptions
    @State private var status = "picking"
    @State private var depot = "Shah Alam DC"

    private var depots: Bool { options.text("items") == "depots" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if options.text("style") == "inline" {
                // Inline is meant for a Form, a List or a menu. On its own it draws as radio buttons.
                Form {
                    Section(depots ? "Depot" : "Status") {
                        picker
                            .pickerStyle(.inline)
                            .labelsHidden(options.flag("labelsHidden"))
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: depots ? 214 : 104)
                .padding(.horizontal, -14)
                .padding(.vertical, -10)
            } else {
                styled(picker)
                    .labelsHidden(options.flag("labelsHidden"))
                    .fixedSize()
            }
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .blockCard()
    }

    private var summary: String {
        if depots { return "Next pick-up from \(depot) at 14:30" }
        return switch status {
        case "pending": "Order #4821 is waiting for Shah Alam DC"
        case "shipped": "Order #4821 is on its way to Jaya Grocer Bangsar"
        default: "Order #4821 is being picked at Shah Alam DC"
        }
    }

    @ViewBuilder
    private var picker: some View {
        if depots {
            Picker("Depot", selection: $depot) {
                ForEach(LabSample.depots, id: \.self) { Text($0).tag($0) }
            }
        } else {
            Picker("Status", selection: $status) {
                Label("Pending", systemImage: "clock").tag("pending")
                Label("Picking", systemImage: "shippingbox").tag("picking")
                Label("Shipped", systemImage: "truck.box").tag("shipped")
            }
        }
    }

    @ViewBuilder
    private func styled(_ picker: some View) -> some View {
        switch options.text("style") {
        case "segmented": picker.pickerStyle(.segmented)
        case "radioGroup": picker.pickerStyle(.radioGroup)
        default: picker.pickerStyle(.menu)
        }
    }
}

private struct CommandMenuBlock: View {
    let options: LabOptions
    @State private var last = "Choose an action for this order"
    @State private var priority = false
    @Environment(\.labMotion) private var motion

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Order #4821 · Jaya Grocer Bangsar").font(.headline)
                    if priority { Image(systemName: "flag.fill").foregroundStyle(.tint) }
                }
                Text(last)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer()
            styled(menu)
                .fixedSize()
        }
        .blockCard()
    }

    private func did(_ text: String) {
        motion.perform { last = text }
    }

    @ViewBuilder
    private var menu: some View {
        if options.flag("primaryAction") {
            Menu {
                items
            } label: {
                label("Confirm", symbol: "checkmark.circle")
            } primaryAction: {
                did("Confirmed · picking at Shah Alam DC")
            }
        } else {
            Menu {
                items
            } label: {
                label("Actions", symbol: options.text("style") == "icon" ? "ellipsis.circle" : "bolt")
            }
        }
    }

    @ViewBuilder
    private func label(_ title: String, symbol: String) -> some View {
        if options.text("style") == "icon" {
            Label(title, systemImage: symbol).labelStyle(.iconOnly)
        } else {
            Label(title, systemImage: symbol)
        }
    }

    @ViewBuilder
    private var items: some View {
        Section("Order #4821") {
            item("Duplicate order", hint: "⌘D") { did("Duplicated as order #4827") }
            item("Print picking slip", hint: "⌘P") { did("Picking slip sent to Shah Alam DC") }
            Toggle("Priority delivery", isOn: Binding(get: { priority }, set: { on in
                motion.perform { priority = on }
                did(on ? "Marked priority · first lorry out" : "Back in the normal queue")
            }))
        }
        Section {
            Menu("Move to depot") {
                ForEach(LabSample.depots, id: \.self) { depot in
                    Button(depot) { did("Moved to \(depot)") }
                }
            }
            item("Cancel order…", hint: "⌘⌫", role: .destructive) { did("Cancelled · RM 2,665.20 refunded") }
        }
    }

    /// A menu item whose shortcut is a text hint (the item's subtitle), never a real
    /// `.keyboardShortcut`, so nothing reaches the lab window's key handling.
    private func item(_ title: String, hint: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title)
            if options.flag("hints") { Text(hint) }
        }
    }

    @ViewBuilder
    private func styled(_ menu: some View) -> some View {
        switch options.text("style") {
        case "borderless":
            menu.menuStyle(.button).buttonStyle(.borderless)
        case "icon":
            menu.menuStyle(.button).buttonStyle(.borderless).menuIndicator(.hidden)
        default:
            menu.menuStyle(.button)
        }
    }
}

private struct FilterListBlock: View {
    let options: LabOptions
    @State private var query = ""
    @State private var selection: String? = "Jaya Grocer Bangsar"

    private var matches: [String] {
        query.isEmpty ? LabSample.customers : LabSample.customers.filter { Self.hits(query, in: $0, mode: options.text("match")) != nil }
    }

    var body: some View {
        MiniWindow("Customers", height: 270) {
            Text("\(matches.count) of \(LabSample.customers.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } content: {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(.secondary)
                    TextField("Filter customers", text: $query, prompt: Text(options.text("match") == "fuzzy" ? "Try “jgb”" : "Filter customers"))
                        .textFieldStyle(.roundedBorder)
                }
                .padding([.horizontal, .top], 10)
                styled(list)
                    .overlay {
                        if matches.isEmpty { ContentUnavailableView.search(text: query) }
                    }
            }
        }
    }

    private var list: some View {
        List(matches, id: \.self, selection: $selection) { name in
            HStack {
                Text(highlighted(name))
                Spacer()
                Text(Self.depot(for: name))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func styled(_ list: some View) -> some View {
        switch options.text("listStyle") {
        case "plain": list.listStyle(.plain)
        case "inset": list.listStyle(.inset)
        default: list.listStyle(.bordered(alternatesRowBackgrounds: true)).padding([.horizontal, .bottom], 10)
        }
    }

    private func highlighted(_ name: String) -> AttributedString {
        guard options.flag("highlight"), !query.isEmpty, let hits = Self.hits(query, in: name, mode: options.text("match")) else {
            return AttributedString(name)
        }
        var text = AttributedString()
        for (offset, character) in name.enumerated() {
            var piece = AttributedString(String(character))
            if hits.contains(offset) { piece.font = .body.bold() }
            text += piece
        }
        return text
    }

    private static func depot(for name: String) -> String {
        let index = LabSample.customers.firstIndex(of: name) ?? 0
        return LabSample.depots[index % LabSample.depots.count]
    }

    /// The offsets of the characters in `name` that match `query`, or nil when it doesn't match.
    private static func hits(_ query: String, in name: String, mode: String) -> Set<Int>? {
        switch mode {
        case "prefix":
            guard name.lowercased().hasPrefix(query.lowercased()) else { return nil }
            return Set(0..<query.count)
        case "fuzzy":
            // The query's letters appear in the name in order: "jgb" finds Jaya Grocer Bangsar.
            var hits = Set<Int>()
            var offset = 0
            var rest = Array(name.lowercased())
            for letter in query.lowercased() where letter != " " {
                guard let found = rest.firstIndex(of: letter) else { return nil }
                hits.insert(offset + found)
                offset += found + 1
                rest = Array(rest[(found + 1)...])
            }
            return hits
        default:
            guard let range = name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else { return nil }
            let start = name.distance(from: name.startIndex, to: range.lowerBound)
            return Set(start..<(start + name.distance(from: range.lowerBound, to: range.upperBound)))
        }
    }
}

// MARK: - Tabs

private enum LabSection: String, CaseIterable, Hashable {
    case orders, stock, invoices

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .orders: "list.bullet"
        case .stock: "shippingbox"
        case .invoices: "doc.text"
        }
    }
}

/// The content behind each tab, shared by the tab adapters.
private struct LabSectionPane: View {
    let section: LabSection

    var body: some View {
        VStack(spacing: 0) {
            switch section {
            case .orders:
                ForEach(LabSample.orders.prefix(3)) { order in
                    OrderRow(order: order)
                    Divider()
                }
            case .stock:
                ForEach(stock, id: \.item) { line in
                    row(line.item, detail: line.cartons < 50 ? "Low · reorder from Penang Hub" : "Shah Alam DC", value: "\(line.cartons.formatted()) cartons", low: line.cartons < 50)
                    Divider()
                }
            case .invoices:
                ForEach(invoices, id: \.number) { invoice in
                    row("\(invoice.number) · \(invoice.customer)", detail: invoice.paid ? "Paid" : "Due in 14 days", value: invoice.total.formatted(LabSample.ringgit), low: !invoice.paid)
                    Divider()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private let stock: [(item: String, cartons: Int)] = [("Beras wangi 10kg", 1240), ("Minyak masak 5kg", 36), ("Gula pasir 1kg", 3400)]

    private let invoices: [(number: String, customer: String, total: Double, paid: Bool)] = [
        ("INV-2207", "99 Speedmart Puchong", 1180.50, true),
        ("INV-2208", "Jaya Grocer Bangsar", 2665.20, false),
        ("INV-2209", "Mydin Subang Jaya", 3920.00, false),
    ]

    private func row(_ title: String, detail: String, value: String, low: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout)
                Text(detail).font(.caption).foregroundStyle(low ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            Spacer(minLength: 8)
            Text(value).font(.callout).monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

private struct TabViewBlock: View {
    let options: LabOptions
    @State private var section = LabSection.orders

    /// The option picks the tab, the way an app sets the selection from code.
    private var chosen: LabSection {
        let picked = LabSection(rawValue: options.text("selected")) ?? .orders
        return picked == .invoices && !options.flag("invoices") ? .orders : picked
    }

    var body: some View {
        MiniWindow("Shah Alam DC", height: 270) {
            TabView(selection: $section) {
                Tab("Orders", systemImage: "list.bullet", value: LabSection.orders) {
                    LabSectionPane(section: .orders)
                }
                Tab("Stock", systemImage: "shippingbox", value: LabSection.stock) {
                    LabSectionPane(section: .stock)
                }
                // An if, because the Mac tab bar still draws a tab given .hidden(true) (macOS 27).
                if options.flag("invoices") {
                    Tab("Invoices", systemImage: "doc.text", value: LabSection.invoices) {
                        LabSectionPane(section: .invoices)
                    }
                }
            }
            .tabViewStyle(.automatic)
            .padding(10)
        }
        .onAppear { section = chosen }
        .onChange(of: chosen) { _, new in section = new }
        .onChange(of: options.flag("invoices")) { _, shown in
            if !shown && section == .invoices { section = .orders }
        }
    }
}

/// A Picker over the content that swaps it with a transition: `.segmented`, or macOS 27's `.tabs`.
private struct PickerTabsBlock: View {
    let options: LabOptions
    let tabsStyle: Bool
    @State private var section = LabSection.orders
    @State private var forward = true
    @Environment(\.labMotion) private var motion

    var body: some View {
        MiniWindow("Shah Alam DC", height: 270) {
            VStack(spacing: 10) {
                styled(picker)
                    .labelsHidden()
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: options.text("alignment") == "leading" ? .leading : .center)
                    .padding(.horizontal, 12)
                ZStack {
                    LabSectionPane(section: section)
                        .id(section)
                        .transition(transition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .padding(.top, 10)
        }
    }

    private var selection: Binding<LabSection> {
        Binding {
            section
        } set: { new in
            let all = LabSection.allCases
            forward = (all.firstIndex(of: new) ?? 0) >= (all.firstIndex(of: section) ?? 0)
            if options.text("transition") == "none" {
                section = new
            } else {
                motion.perform { section = new }
            }
        }
    }

    private var transition: AnyTransition {
        if motion.reduce { return .opacity }
        return switch options.text("transition") {
        case "push": .push(from: forward ? .trailing : .leading)
        case "blurReplace": AnyTransition(.blurReplace)
        case "none": .identity
        default: .opacity
        }
    }

    private var picker: some View {
        Picker("Section", selection: selection) {
            ForEach(LabSection.allCases, id: \.self) { section in
                if options.flag("icons") {
                    Label(section.title, systemImage: section.symbol).labelStyle(.iconOnly).tag(section)
                } else {
                    Text(section.title).tag(section)
                }
            }
        }
    }

    @ViewBuilder
    private func styled(_ picker: some View) -> some View {
        if tabsStyle {
            if #available(macOS 27, *) {
                picker.pickerStyle(.tabs)
            } else {
                VStack(spacing: 4) {
                    picker.pickerStyle(.segmented)
                    Text("The .tabs style needs macOS 27").font(.caption).foregroundStyle(.secondary)
                }
            }
        } else {
            picker.pickerStyle(.segmented)
        }
    }
}

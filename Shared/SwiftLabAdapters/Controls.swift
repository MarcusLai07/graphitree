import Foundation

// SwiftUI lab adapters for controls: button, banner, sheet, picker, tabs.
// Each adapter's view is in App/Views/SwiftLab/ControlBlocks.swift, under the same id.
//
// minOS is the newest API each adapter's code uses, checked against the macOS 27 SDK's
// swiftinterface files (SwiftUI, SwiftUICore, Symbols). The note on each says which API.

extension SwiftLab {
    static let controlAdapters: [SwiftAdapter] = buttonAdapters + bannerAdapters + sheetAdapters + pickerAdapters + tabsAdapters

    // MARK: Button

    private static let buttonAdapters: [SwiftAdapter] = [
        SwiftAdapter(
            id: "button-swiftui",
            slot: .button,
            label: "Button",
            note: "The system button in each of its styles, with a role and an SF Symbol",
            minOS: 13,
            options: [
                .choice("style", "Style", [("automatic", "Automatic"), ("bordered", "Bordered"), ("borderedProminent", "Prominent"), ("borderless", "Borderless"), ("link", "Link")], default: "borderedProminent"),
                .choice("role", "Role", [("none", "None"), ("destructive", "Destructive"), ("cancel", "Cancel")], default: "none"),
                .toggle("symbol", "SF Symbol", default: true),
            ],
            code: { o in
                let role = o.text("role") == "none" ? "" : "role: .\(o.text("role")), "
                let label = o.flag("symbol") ? "Label(\"Confirm order\", systemImage: \"checkmark.circle\")" : "Text(\"Confirm order\")"
                return """
                import SwiftUI

                Button(\(role)action: confirm) {
                    \(label)
                }
                .buttonStyle(.\(o.text("style")))
                """
            }
        ),
        // .buttonStyle(.glass), .glass(_:), .glassProminent and GlassEffectContainer: macOS 26.
        SwiftAdapter(
            id: "button-glass",
            slot: .button,
            label: "Liquid Glass button",
            note: "The macOS 26 glass button styles, alone or blended in a GlassEffectContainer",
            minOS: 26,
            options: [
                .choice("style", "Glass", [("glass", "Regular"), ("clear", "Clear"), ("glassProminent", "Prominent")], default: "glass"),
                .choice("shape", "Shape", [("capsule", "Capsule"), ("roundedRectangle", "Rounded")], default: "capsule"),
                .toggle("container", "Glass container", default: true),
                .toggle("backdrop", "Over content", default: false),
            ],
            code: { o in
                let style = switch o.text("style") {
                case "clear": ".glass(.clear)"
                case "glassProminent": ".glassProminent"
                default: ".glass"
                }
                let shape = ".buttonBorderShape(.\(o.text("shape")))"
                let buttons = o.flag("container")
                    ? """
                    // Glass in one container samples one backdrop, and shapes blend as they meet.
                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 8) {
                            Button("Hold", action: hold)
                                .buttonStyle(.glass)
                            Button(action: confirm) {
                                Label("Confirm order", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(\(style))
                        }
                    }
                    \(shape)
                    """
                    : """
                    Button(action: confirm) {
                        Label("Confirm order", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(\(style))
                    \(shape)
                    """
                guard o.flag("backdrop") else { return "import SwiftUI\n\n" + buttons }
                let floating = buttons.split(separator: "\n", omittingEmptySubsequences: false).map { "        " + $0 }.joined(separator: "\n")
                return """
                import SwiftUI

                // Glass is made to float over content, which shows through it, bent at the edges.
                OrderLinesView(order: order)
                    .overlay(alignment: .trailing) {
                \(floating)
                    }
                """
            }
        ),
        // .symbolEffect(_:value:) and .bounce: macOS 14. .wiggle, .breathe, .rotate, and .bounce as an
        // indefinite effect: macOS 15 (Symbols framework).
        SwiftAdapter(
            id: "button-symbol-effect",
            slot: .button,
            label: "SF Symbol effect",
            note: "A button whose symbol bounces, wiggles, breathes or rotates, once per click or while it works",
            minOS: 15,
            repeats: true,
            options: [
                .choice("effect", "Effect", [("bounce", "Bounce"), ("wiggle", "Wiggle"), ("breathe", "Breathe"), ("rotate", "Rotate")], default: "bounce"),
                .choice("play", "Plays", [("tap", "Once per click"), ("working", "While working"), ("always", "Continuously")], default: "tap"),
                .choice("symbol", "Symbol", [("sync", "Sync"), ("notify", "Notify"), ("dispatch", "Dispatch")], default: "sync"),
            ],
            code: { o in
                let (title, symbol) = symbolButtonContent(o.text("symbol"))
                let effect = o.text("effect").isEmpty ? "bounce" : o.text("effect")
                let typeName = title.capitalized.replacingOccurrences(of: " ", with: "")
                switch o.text("play") {
                case "working":
                    return """
                    import SwiftUI

                    struct \(typeName)Button: View {
                        @Environment(\\.accessibilityReduceMotion) private var reduceMotion
                        @State private var isWorking = false

                        var body: some View {
                            Button {
                                Task {
                                    isWorking = true
                                    await work()
                                    isWorking = false
                                }
                            } label: {
                                Label("\(title)", systemImage: "\(symbol)")
                            }
                            .disabled(isWorking)
                            // Indefinite: plays until isActive turns false.
                            .symbolEffect(.\(effect), isActive: isWorking && !reduceMotion)
                        }
                    }
                    """
                case "always":
                    return """
                    import SwiftUI

                    struct \(typeName)Button: View {
                        @Environment(\\.accessibilityReduceMotion) private var reduceMotion

                        var body: some View {
                            Button(action: run) {
                                Label("\(title)", systemImage: "\(symbol)")
                            }
                            // Repeats on its own, so it stops when Reduce motion is on.
                            .symbolEffect(.\(effect), isActive: !reduceMotion)
                        }
                    }
                    """
                default:
                    return """
                    import SwiftUI

                    struct \(typeName)Button: View {
                        @State private var runs = 0

                        var body: some View {
                            Button {
                                runs += 1
                                run()
                            } label: {
                                Label("\(title)", systemImage: "\(symbol)")
                            }
                            // Discrete: plays once each time the value changes.
                            .symbolEffect(.\(effect), value: runs)
                        }
                    }
                    """
                }
            }
        ),
    ]

    /// The SF Symbol button's title and symbol for its `symbol` option. The view uses it too.
    static func symbolButtonContent(_ id: String) -> (title: String, symbol: String) {
        switch id {
        case "notify": ("Notify depot", "bell")
        case "dispatch": ("Dispatch", "shippingbox")
        default: ("Sync stock", "arrow.triangle.2.circlepath")
        }
    }

    // MARK: Banner

    private static let bannerAdapters: [SwiftAdapter] = [
        // .overlay(alignment:content:) and .task(id:): macOS 12. Task.sleep(for:): macOS 13.
        SwiftAdapter(
            id: "banner-overlay",
            slot: .banner,
            label: "Overlay banner",
            note: "An overlay that slides in from an edge and dismisses itself: a transition and a task",
            minOS: 13,
            handBuilt: true,
            options: [
                .choice("edge", "Edge", [("top", "Top"), ("bottom", "Bottom")], default: "top"),
                .choice("style", "Style", [("material", "Material"), ("tinted", "Tinted")], default: "material"),
                .toggle("autoDismiss", "Auto-dismiss", default: true),
                .toggle("action", "Undo button", default: true),
            ],
            code: { o in
                let edge = o.text("edge") == "bottom" ? "bottom" : "top"
                let dismiss = o.flag("autoDismiss")
                    ? """

                                .task(id: showBanner) {
                                    guard showBanner else { return }
                                    try? await Task.sleep(for: .seconds(3))
                                    withAnimation { showBanner = false }
                                }
                    """
                    : ""
                let action = o.flag("action")
                    ? """

                                Button("Undo") { withAnimation { showBanner = false } }
                                    .buttonStyle(.borderless)
                    """
                    : ""
                let close = dismiss.isEmpty
                    ? """

                                Button("Dismiss", systemImage: "xmark") { withAnimation { showBanner = false } }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(.borderless)
                    """
                    : ""
                let background = o.text("style") == "tinted"
                    ? """
                    .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.background)
                                    .overlay(RoundedRectangle(cornerRadius: 10).fill(.tint.opacity(0.14)))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.tint.opacity(0.35)))
                            }
                    """
                    : """
                    .background(.regularMaterial, in: .rect(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    """
                return """
                import SwiftUI

                // SwiftUI has no banner or toast: an overlay, a transition and a task make one.
                struct OrdersView: View {
                    @State private var showBanner = false

                    var body: some View {
                        OrderList(onConfirm: { withAnimation { showBanner = true } })
                            .overlay(alignment: .\(edge)) {
                                if showBanner {
                                    banner
                                        .transition(.move(edge: .\(edge)).combined(with: .opacity))
                                        .padding(10)
                                }
                            }\(dismiss)
                    }

                    private var banner: some View {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Order #4821 confirmed").font(.callout.weight(.semibold))
                                Text("Picking starts at Shah Alam DC").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 12)\(action)\(close)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: 420)
                        \(background)
                    }
                }
                """
            }
        ),
        // .glassEffect(_:in:), Glass.tint(_:), GlassEffectContainer, .glassEffectID(_:in:) and
        // .buttonStyle(.glass): macOS 26.
        SwiftAdapter(
            id: "banner-glass",
            slot: .banner,
            label: "Liquid Glass banner",
            note: "A glass capsule over the content, with an Undo pill that splits off it in a GlassEffectContainer",
            minOS: 26,
            handBuilt: true,
            options: [
                .choice("edge", "Edge", [("top", "Top"), ("bottom", "Bottom")], default: "top"),
                .choice("shape", "Shape", [("capsule", "Capsule"), ("rounded", "Rounded")], default: "capsule"),
                .toggle("tint", "Success tint", default: false),
                .toggle("autoDismiss", "Auto-dismiss", default: true),
            ],
            code: { o in
                let edge = o.text("edge") == "bottom" ? "bottom" : "top"
                let glass = o.flag("tint") ? ".regular.tint(.green.opacity(0.35))" : ".regular"
                let shape = o.text("shape") == "rounded" ? ".rect(cornerRadius: 14)" : ".capsule"
                let dismiss = o.flag("autoDismiss")
                    ? """

                                .task(id: showBanner) {
                                    guard showBanner else { return }
                                    try? await Task.sleep(for: .seconds(3))
                                    withAnimation { showBanner = false }
                                }
                    """
                    : ""
                return """
                import SwiftUI

                // Liquid Glass gives the material, not the banner: the overlay and timing are still yours.
                struct OrdersView: View {
                    @State private var showBanner = false
                    @Namespace private var glass

                    var body: some View {
                        OrderList(onConfirm: { withAnimation { showBanner = true } })
                            .overlay(alignment: .\(edge)) {
                                if showBanner {
                                    GlassEffectContainer(spacing: 10) {
                                        HStack(spacing: 6) {
                                            Label("Order #4821 confirmed · Shah Alam DC", systemImage: "checkmark.circle.fill")
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .glassEffect(\(glass), in: \(shape))
                                                .glassEffectID("banner", in: glass)
                                            Button("Undo") { withAnimation { showBanner = false } }
                                                .buttonStyle(.glass)
                                                .glassEffectID("undo", in: glass)
                                        }
                                    }
                                    .transition(.move(edge: .\(edge)).combined(with: .opacity))
                                    .padding(12)
                                }
                            }\(dismiss)
                    }
                }
                """
            }
        ),
        // Built from ZStack, offset, scaleEffect, zIndex and .onHover: nothing past macOS 13.
        SwiftAdapter(
            id: "banner-stack",
            slot: .banner,
            label: "Stacked toasts",
            note: "Toasts that pile up like Sonner's and fan out on hover, built from a ZStack",
            minOS: 13,
            handBuilt: true,
            options: [
                .choice("edge", "Edge", [("top", "Top"), ("bottom", "Bottom")], default: "bottom"),
                .choice("expand", "Expand", [("hover", "On hover"), ("always", "Always"), ("never", "Never")], default: "hover"),
                .toggle("richColors", "Rich colours", default: true),
                .toggle("autoDismiss", "Auto-dismiss", default: false),
            ],
            code: { o in
                let bottom = o.text("edge") != "top"
                let sign = bottom ? "-" : ""
                let expanded = switch o.text("expand") {
                case "always": "true"
                case "never": "false"
                default: "isHovering"
                }
                let hover = o.text("expand") == "hover" ? "\n        .onHover { hovering in withAnimation(.snappy) { isHovering = hovering } }" : ""
                let fill = o.flag("richColors")
                    ? ".background(toast.kind.color.opacity(0.12), in: .rect(cornerRadius: 10))\n        .background(.background, in: .rect(cornerRadius: 10))"
                    : ".background(.background, in: .rect(cornerRadius: 10))"
                let icon = o.flag("richColors") ? ".foregroundStyle(toast.kind.color)" : ".foregroundStyle(.secondary)"
                let dismiss = o.flag("autoDismiss")
                    ? """

                                        .task(id: isHovering) {
                                            // Paused while the pointer is over the stack.
                                            guard !isHovering else { return }
                                            try? await Task.sleep(for: .seconds(4))
                                            withAnimation { toasts.removeAll { $0.id == toast.id } }
                                        }
                    """
                    : ""
                return """
                import SwiftUI

                // SwiftUI has no toasts. A ZStack of them, newest in front, with each one behind
                // tucked up and scaled down, is the shape Sonner made familiar.
                struct ToastStack: View {
                    @Binding var toasts: [Toast]   // newest last
                    @State private var isHovering = false
                    private var expanded: Bool { \(expanded) }

                    var body: some View {
                        ZStack(alignment: .\(bottom ? "bottom" : "top")) {
                            ForEach(Array(toasts.suffix(3).enumerated()), id: \\.element.id) { index, toast in
                                let depth = min(toasts.count, 3) - 1 - index   // 0 is the newest
                                ToastRow(toast: toast)
                                    .scaleEffect(expanded ? 1 : 1 - CGFloat(depth) * 0.05, anchor: .\(bottom ? "top" : "bottom"))
                                    .offset(y: \(sign)CGFloat(depth) * (expanded ? 60 : 10))
                                    .zIndex(Double(index))
                                    .transition(.move(edge: .\(bottom ? "bottom" : "top")).combined(with: .opacity))\(dismiss)
                            }
                        }
                        .frame(width: 320)\(hover)
                    }
                }

                struct ToastRow: View {
                    let toast: Toast

                    var body: some View {
                        HStack(spacing: 10) {
                            Image(systemName: toast.kind.symbol)\(icon)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(toast.title).font(.callout.weight(.semibold))
                                Text(toast.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        \(fill)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                    }
                }
                """
            }
        ),
    ]

    // MARK: Sheet

    private static let sheetAdapters: [SwiftAdapter] = [
        // .presentationSizing(_:) with .form, .page and .fitted: macOS 15. Form styles: macOS 13.
        SwiftAdapter(
            id: "sheet-sheet",
            slot: .sheet,
            label: "Sheet",
            note: "A modal sheet on the window, sized by presentationSizing",
            minOS: 15,
            options: [
                .choice("sizing", "Sizing", [("automatic", "Automatic"), ("form", "Form"), ("page", "Page"), ("fitted", "Fitted")], default: "form"),
                .choice("formStyle", "Form style", [("grouped", "Grouped"), ("columns", "Columns")], default: "grouped"),
            ],
            code: { o in
                let sizing = o.text("sizing")
                let sizingLine = sizing == "automatic" || sizing.isEmpty ? "" : "\n            .presentationSizing(.\(sizing))"
                return """
                import SwiftUI

                Button("Edit delivery…") { isEditing = true }
                    .sheet(isPresented: $isEditing) {
                        DeliveryForm(order: order)\(sizingLine)
                    }

                struct DeliveryForm: View {
                    let order: Order
                    @Environment(\\.dismiss) private var dismiss
                    @State private var depot = "Shah Alam DC"
                    @State private var date = Date.now
                    @State private var note = ""

                    var body: some View {
                        VStack(spacing: 0) {
                            Form {
                                Section("Order \\(order.id) · \\(order.customer)") {
                                    Picker("Depot", selection: $depot) {
                                        ForEach(depots, id: \\.self) { Text($0) }
                                    }
                                    DatePicker("Deliver on", selection: $date, displayedComponents: .date)
                                    TextField("Note for the driver", text: $note)
                                }
                            }
                            .formStyle(.\(o.text("formStyle")))
                            HStack {
                                Spacer()
                                Button("Cancel", role: .cancel) { dismiss() }
                                    .keyboardShortcut(.cancelAction)
                                Button("Save") { save(); dismiss() }
                                    .keyboardShortcut(.defaultAction)
                            }
                            .padding()
                        }
                    }
                }
                """
            }
        ),
        // .popover(isPresented:attachmentAnchor:arrowEdge:content:): macOS 10.15.
        SwiftAdapter(
            id: "sheet-popover",
            slot: .sheet,
            label: "Popover",
            note: "A popover anchored to the button, with its arrow on the edge you choose",
            minOS: 13,
            options: [
                .choice("arrowEdge", "Arrow edge", [("top", "Top"), ("bottom", "Bottom"), ("leading", "Leading"), ("trailing", "Trailing")], default: "bottom"),
                .choice("content", "Content", [("lines", "Order lines"), ("edit", "Quick edit")], default: "lines"),
            ],
            code: { o in
                let body = o.text("content") == "edit"
                    ? """
                            Form {
                                Stepper("Cartons: \\(cartons)", value: $cartons, in: 1...40)
                                Toggle("Priority delivery", isOn: $priority)
                            }
                            .padding()
                            .frame(width: 260)
                    """
                    : """
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Order #4821 · Jaya Grocer Bangsar").font(.headline)
                                ForEach(order.lines) { line in
                                    LabeledContent(line.item, value: line.total, format: .currency(code: "MYR"))
                                }
                            }
                            .padding()
                            .frame(width: 280)
                    """
                return """
                import SwiftUI

                Button("Order lines", systemImage: "list.bullet.rectangle") { showLines.toggle() }
                    .popover(isPresented: $showLines, arrowEdge: .\(o.text("arrowEdge"))) {
                \(body)
                    }
                """
            }
        ),
        // .inspector(isPresented:content:) and .inspectorColumnWidth(_:): macOS 14.
        SwiftAdapter(
            id: "sheet-inspector",
            slot: .sheet,
            label: "Inspector",
            note: "A trailing panel beside the content, shown and hidden with a button",
            minOS: 14,
            options: [
                .choice("width", "Width", [("narrow", "Narrow"), ("wide", "Wide")], default: "narrow"),
                .toggle("sections", "Grouped form", default: true),
            ],
            code: { o in
                let width = o.text("width") == "wide" ? 280 : 210
                let content = o.flag("sections")
                    ? """
                            Form {
                                Section("Order") {
                                    LabeledContent("Customer", value: order.customer)
                                    LabeledContent("Depot", value: order.depot)
                                }
                                Section("Total") {
                                    Text(order.total, format: .currency(code: "MYR"))
                                }
                            }
                            .formStyle(.grouped)
                    """
                    : """
                            VStack(alignment: .leading, spacing: 8) {
                                Text(order.id).font(.headline)
                                LabeledContent("Customer", value: order.customer)
                                LabeledContent("Depot", value: order.depot)
                                LabeledContent("Total", value: order.total, format: .currency(code: "MYR"))
                                Spacer()
                            }
                            .padding()
                    """
                return """
                import SwiftUI

                OrderList(selection: $selection)
                    .inspector(isPresented: $showInspector) {
                \(content)
                        .inspectorColumnWidth(\(width))
                    }

                // A button in your own header, or in the window toolbar if the window is yours:
                Button("Inspector", systemImage: "sidebar.trailing") { showInspector.toggle() }
                """
            }
        ),
        // .confirmationDialog: macOS 12. .dialogSeverity(_:) and .dialogIcon(_:): macOS 13.
        SwiftAdapter(
            id: "sheet-confirmation",
            slot: .sheet,
            label: "Confirmation dialog",
            note: "Asks before a destructive action, as an alert on the window",
            minOS: 13,
            options: [
                .choice("titleVisibility", "Title", [("automatic", "Automatic"), ("visible", "Visible"), ("hidden", "Hidden")], default: "visible"),
                .choice("severity", "Severity", [("automatic", "Automatic"), ("critical", "Critical")], default: "automatic"),
                .toggle("message", "Message", default: true),
                .toggle("icon", "Custom icon", default: false),
            ],
            code: { o in
                let message = o.flag("message")
                    ? """
                     message: { order in
                        Text("Jaya Grocer Bangsar is refunded \\(order.total, format: .currency(code: "MYR")) and Shah Alam DC stops picking.")
                    }
                    """
                    : ""
                var modifiers: [String] = []
                if o.text("severity") == "critical" { modifiers.append(".dialogSeverity(.critical)") }
                if o.flag("icon") { modifiers.append(".dialogIcon(Image(systemName: \"shippingbox\"))") }
                let tail = modifiers.isEmpty ? "" : "\n" + modifiers.joined(separator: "\n")
                return """
                import SwiftUI

                Button("Cancel order…", role: .destructive) {
                    orderToCancel = order
                    isConfirming = true
                }
                .confirmationDialog(
                    "Cancel order #4821?",
                    isPresented: $isConfirming,
                    titleVisibility: .\(o.text("titleVisibility")),
                    presenting: orderToCancel
                ) { order in
                    Button("Cancel order", role: .destructive) { cancel(order) }
                    Button("Keep order", role: .cancel) {}
                }\(message)\(tail)
                """
            }
        ),
    ]

    // MARK: Picker

    private static let pickerAdapters: [SwiftAdapter] = [
        // .pickerStyle(.menu) and .inline: macOS 11. .segmented and .radioGroup: 10.15. Form styles: 13.
        // (.palette, macOS 14, is left out: on its own it draws exactly like .segmented on a Mac.)
        SwiftAdapter(
            id: "picker-swiftui",
            slot: .picker,
            label: "Picker",
            note: "The system picker in each macOS style: menu, segmented, radio group, and inline in a Form",
            minOS: 13,
            options: [
                .choice("style", "Style", [("menu", "Menu"), ("segmented", "Segmented"), ("radioGroup", "Radio group"), ("inline", "Inline")], default: "menu"),
                .choice("items", "Items", [("status", "Order status"), ("depots", "Depots")], default: "status"),
                .toggle("labelsHidden", "Hide label", default: false),
            ],
            code: { o in
                let depots = o.text("items") == "depots"
                let label = depots ? "Depot" : "Status"
                let content = depots
                    ? "ForEach(depots, id: \\.self) { Text($0) }"
                    : """
                    Label("Pending", systemImage: "clock").tag(Status.pending)
                        Label("Picking", systemImage: "shippingbox").tag(Status.picking)
                        Label("Shipped", systemImage: "truck.box").tag(Status.shipped)
                    """
                let hidden = o.flag("labelsHidden") ? "\n.labelsHidden()" : ""
                guard o.text("style") == "inline" else {
                    return """
                    import SwiftUI

                    Picker("\(label)", selection: $\(label.lowercased())) {
                        \(content)
                    }
                    .pickerStyle(.\(o.text("style")))\(hidden)
                    """
                }
                // Inline belongs in a Form, a List or a menu; alone it draws as radio buttons.
                let rows = content.replacingOccurrences(of: "\n    ", with: "\n            ")
                return """
                import SwiftUI

                Form {
                    Section("\(label)") {
                        Picker("\(label)", selection: $\(label.lowercased())) {
                            \(rows)
                        }
                        .pickerStyle(.inline)\(hidden.replacingOccurrences(of: "\n", with: "\n        "))
                    }
                }
                .formStyle(.grouped)
                """
            }
        ),
        // Menu(content:label:primaryAction:): macOS 12. .menuStyle(.button): macOS 13.
        SwiftAdapter(
            id: "picker-menu",
            slot: .picker,
            label: "Command menu",
            note: "A Menu of actions in sections, with a submenu, a toggle and text hints for shortcuts",
            minOS: 13,
            options: [
                .choice("style", "Style", [("button", "Button"), ("borderless", "Borderless"), ("icon", "Icon only")], default: "button"),
                .toggle("primaryAction", "Primary action", default: false),
                .toggle("hints", "Shortcut hints", default: true),
            ],
            code: { o in
                let hint: (String, String) -> String = { title, keys in
                    o.flag("hints") ? "{\n            Text(\"\(title)\")\n            Text(\"\(keys)\")\n        }" : "{ Text(\"\(title)\") }"
                }
                // With a primary action, clicking the button confirms and the arrow opens the menu.
                let primaryAction = o.flag("primaryAction")
                let title = primaryAction ? "Confirm" : "Actions"
                var label = "Label(\"\(title)\", systemImage: \"\(primaryAction ? "checkmark.circle" : "bolt")\")"
                let style: String
                switch o.text("style") {
                case "borderless":
                    style = ".menuStyle(.button)\n.buttonStyle(.borderless)"
                case "icon":
                    if !primaryAction { label = "Label(\"Actions\", systemImage: \"ellipsis.circle\")" }
                    label += "\n        .labelStyle(.iconOnly)"
                    style = ".menuStyle(.button)\n.buttonStyle(.borderless)\n.menuIndicator(.hidden)"
                default:
                    style = ".menuStyle(.button)"
                }
                let primary = o.flag("primaryAction") ? " primaryAction: {\n    confirm(order)\n}" : ""
                let hintNote = o.flag("hints") ? "\n// A second Text is the item's subtitle. Hints only: no .keyboardShortcut, so nothing goes global." : ""
                return """
                import SwiftUI
                \(hintNote)
                Menu {
                    Section("Order #4821") {
                        Button(action: duplicate) \(hint("Duplicate order", "⌘D"))
                        Button(action: printSlip) \(hint("Print picking slip", "⌘P"))
                        Toggle("Priority delivery", isOn: $priority)
                    }
                    Section {
                        Menu("Move to depot") {
                            ForEach(depots, id: \\.self) { depot in
                                Button(depot) { move(to: depot) }
                            }
                        }
                        Button(role: .destructive, action: cancel) \(hint("Cancel order…", "⌘⌫"))
                    }
                } label: {
                    \(label)
                }\(primary)
                \(style)
                """
            }
        ),
        // A TextField filtering a List: macOS 13. ContentUnavailableView.search(text:): macOS 14.
        SwiftAdapter(
            id: "picker-filter",
            slot: .picker,
            label: "Filter list",
            note: "A text field that narrows a list as you type, without .searchable taking the window's toolbar",
            minOS: 14,
            handBuilt: true,
            options: [
                .choice("match", "Match", [("contains", "Contains"), ("prefix", "Starts with"), ("fuzzy", "Fuzzy")], default: "contains"),
                .choice("listStyle", "List style", [("inset", "Inset"), ("bordered", "Bordered"), ("plain", "Plain")], default: "bordered"),
                .toggle("highlight", "Highlight matches", default: true),
            ],
            code: { o in
                let match = switch o.text("match") {
                case "prefix": "customers.filter { $0.lowercased().hasPrefix(query.lowercased()) }"
                case "fuzzy": "customers.filter { isFuzzyMatch(query, $0) }"
                default: "customers.filter { $0.localizedCaseInsensitiveContains(query) }"
                }
                let fuzzy = o.text("match") == "fuzzy"
                    ? """


                    /// True when the query's letters appear in the name, in order: "jgb" finds Jaya Grocer Bangsar.
                    func isFuzzyMatch(_ query: String, _ name: String) -> Bool {
                        var rest = name.lowercased()[...]
                        for letter in query.lowercased() where letter != " " {
                            guard let found = rest.firstIndex(of: letter) else { return false }
                            rest = rest[rest.index(after: found)...]
                        }
                        return true
                    }
                    """
                    : ""
                let listStyle = switch o.text("listStyle") {
                case "plain": ".plain"
                case "inset": ".inset"
                default: ".bordered(alternatesRowBackgrounds: true)"
                }
                let row = o.flag("highlight") ? "Text(highlighted(name))" : "Text(name)"
                let highlight = o.flag("highlight")
                    ? """


                        private func highlighted(_ name: String) -> AttributedString {
                            var text = AttributedString(name)
                            if !query.isEmpty, let range = text.range(of: query, options: .caseInsensitive) {
                                text[range].font = .body.bold()
                            }
                            return text
                        }
                    """
                    : ""
                return """
                import SwiftUI

                // .searchable puts its field in the window's toolbar. A TextField over a List stays put.
                struct CustomerFilter: View {
                    @State private var query = ""
                    @State private var selection: String?

                    private var matches: [String] {
                        query.isEmpty ? customers : \(match)
                    }

                    var body: some View {
                        VStack(spacing: 8) {
                            TextField("Filter customers", text: $query)
                                .textFieldStyle(.roundedBorder)
                            List(matches, id: \\.self, selection: $selection) { name in
                                \(row)
                            }
                            .listStyle(\(listStyle))
                            .overlay {
                                if matches.isEmpty { ContentUnavailableView.search(text: query) }
                            }
                        }
                    }\(highlight)
                }\(fuzzy)
                """
            }
        ),
    ]

    // MARK: Tabs

    private static let tabsAdapters: [SwiftAdapter] = [
        // TabView with Tab(_:systemImage:value:content:), and if in a TabContentBuilder: macOS 15.
        SwiftAdapter(
            id: "tabs-tabview",
            slot: .tabs,
            label: "TabView",
            note: "TabView with the Tab API: a typed selection, and a tab shown only when it applies",
            minOS: 15,
            options: [
                .choice("selected", "Selected", [("orders", "Orders"), ("stock", "Stock"), ("invoices", "Invoices")], default: "orders"),
                .toggle("invoices", "Invoices tab", default: true),
            ],
            code: { o in
                let selected = o.text("selected").isEmpty ? "orders" : o.text("selected")
                let invoices = o.flag("invoices")
                    ? """
                    Tab("Invoices", systemImage: "doc.text", value: .invoices) {
                            InvoicesPane()
                        }
                    """
                    : """
                    // An if, not .hidden(): the Mac tab bar still draws a hidden tab (macOS 27).
                        if canSeeInvoices {
                            Tab("Invoices", systemImage: "doc.text", value: .invoices) {
                                InvoicesPane()
                            }
                        }
                    """
                return """
                import SwiftUI

                enum Section: Hashable { case orders, stock, invoices }

                @State private var section = Section.\(selected)

                // A Mac tab bar shows the titles. The symbols, and any .badge, show in the
                // .sidebarAdaptable style, which wants to be the window's root view.
                TabView(selection: $section) {
                    Tab("Orders", systemImage: "list.bullet", value: .orders) {
                        OrdersPane()
                    }
                    Tab("Stock", systemImage: "shippingbox", value: .stock) {
                        StockPane()
                    }
                    \(invoices)
                }
                """
            }
        ),
        // Transition.blurReplace and Transition.push(from:): macOS 14. Segmented Picker: 10.15.
        SwiftAdapter(
            id: "tabs-segmented",
            slot: .tabs,
            label: "Segmented switcher",
            note: "A segmented Picker that swaps the content below it with a transition",
            minOS: 14,
            options: tabsSwitcherOptions,
            code: { o in tabsSwitcherCode(o, style: ".segmented") }
        ),
        // .pickerStyle(.tabs) (TabsPickerStyle): macOS 27.
        SwiftAdapter(
            id: "tabs-picker-tabs",
            slot: .tabs,
            label: "Tabs picker style",
            note: "macOS 27's .tabs picker style: segmented, but drawn and announced as tabs",
            minOS: 27,
            options: tabsSwitcherOptions,
            code: { o in tabsSwitcherCode(o, style: ".tabs") }
        ),
    ]

    private static let tabsSwitcherOptions: [LabOption] = [
        .choice("transition", "Transition", [("push", "Push"), ("blurReplace", "Blur replace"), ("opacity", "Fade"), ("none", "None")], default: "push"),
        .choice("alignment", "Alignment", [("center", "Centred"), ("leading", "Leading")], default: "center"),
        .toggle("icons", "Icons only", default: false),
    ]

    private static func tabsSwitcherCode(_ o: LabOptions, style: String) -> String {
        let content = o.flag("icons")
            ? """
            // A Mac segmented control shows a Label's title, so icons need .iconOnly.
                    Label("Orders", systemImage: "list.bullet").labelStyle(.iconOnly).tag(Section.orders)
                    Label("Stock", systemImage: "shippingbox").labelStyle(.iconOnly).tag(Section.stock)
                    Label("Invoices", systemImage: "doc.text").labelStyle(.iconOnly).tag(Section.invoices)
            """
            : """
            Text("Orders").tag(Section.orders)
                    Text("Stock").tag(Section.stock)
                    Text("Invoices").tag(Section.invoices)
            """
        let transition: String
        var direction = ""
        switch o.text("transition") {
        case "none": transition = ""
        case "opacity": transition = "\n            .transition(.opacity)"
        case "blurReplace": transition = "\n            .transition(.blurReplace)"
        default:
            transition = "\n            .transition(.push(from: movingForward ? .trailing : .leading))"
            direction = "\n\n// Set movingForward from the old and new index in .onChange(of: section)."
        }
        let animation = o.text("transition") == "none" ? "" : "\n.animation(.smooth, value: section)"
        let frame = o.text("alignment") == "leading" ? "\n    .frame(maxWidth: .infinity, alignment: .leading)" : "\n    .fixedSize()"
        return """
        import SwiftUI

        enum Section: Hashable { case orders, stock, invoices }

        VStack(spacing: 12) {
            Picker("Section", selection: $section) {
                \(content)
            }
            .pickerStyle(\(style))
            .labelsHidden()\(frame)

            ZStack {
                pane(for: section)
                    .id(section)\(transition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }\(animation)\(direction)
        """
    }
}

import SwiftUI

/// One row in the ⌘K palette: a command, a project, or a node.
struct PaletteItem: Identifiable {
    let id: String
    let title: String
    var subtitle: String?
    let symbol: String
    var hint: String?
    let run: () -> Void
}

/// ⌘K: find any node or project, or run any command, from one box.
struct CommandPalette: View {
    let actions: [PaletteItem]
    let projects: [PaletteItem]
    let searchNodes: (String) async -> [PaletteItem]
    let ask: (String) -> Void
    let close: () -> Void

    @State private var query = ""
    @State private var nodes: [PaletteItem] = []
    @State private var highlighted = 0
    @FocusState private var isFocused: Bool

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    private var sections: [(title: String, items: [PaletteItem])] {
        guard !trimmed.isEmpty else { return [("Actions", actions)] }
        // Commands and projects compete in one list, so the closest name wins whatever it is.
        let question = trimmed
        let askItem = PaletteItem(
            id: "ask",
            title: "Ask the graph “\(question)”",
            subtitle: "See what an agent would get back",
            symbol: "sparkles",
            run: { ask(question) }
        )
        return [
            ("Best Matches", Array(ranked(actions + projects).prefix(8))),
            ("Ask", [askItem]),
            ("Nodes", nodes),
        ].filter { !$0.items.isEmpty }
    }

    private var flat: [PaletteItem] { sections.flatMap(\.items) }

    private func ranked(_ items: [PaletteItem]) -> [PaletteItem] {
        items
            .compactMap { item in FuzzyMatch.score(trimmed, in: item.title).map { (item, $0) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
                .accessibilityLabel("Close")
            panel.padding(.top, 84)
        }
        .defaultFocus($isFocused, true)
        .task {
            // Focus only sticks once the field is in the window, a moment after it appears.
            try? await Task.sleep(for: .milliseconds(60))
            isFocused = true
        }
        .task(id: trimmed) { await refreshNodes() }
        .onKeyDown(isActive: true, handleKey)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.title3).foregroundStyle(.secondary)
                TextField("Find a node or project, or run a command", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                KeyCap("esc")
            }
            .padding(.horizontal, 16)
            .frame(height: 52)

            Rectangle().fill(Palette.hairline).frame(height: 1)

            if flat.isEmpty {
                Text(trimmed.count < 2 ? "Keep typing to search nodes." : "No matches.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            } else {
                results
            }
        }
        .frame(width: 620)
        .glassPanel(cornerRadius: 18)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sections, id: \.title) { section in
                        Text(section.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                        ForEach(section.items) { item in
                            row(item, isHighlighted: flat.indices.contains(highlighted) && flat[highlighted].id == item.id)
                                .id(item.id)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 400)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: highlighted) {
                if flat.indices.contains(highlighted) { proxy.scrollTo(flat[highlighted].id) }
            }
        }
    }

    private func row(_ item: PaletteItem, isHighlighted: Bool) -> some View {
        Button { run(item) } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .frame(width: 18)
                    .foregroundStyle(isHighlighted ? Palette.gold : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).lineLimit(1)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 8)
                if let hint = item.hint {
                    Text(hint).font(.caption.monospaced()).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 36)
            .background(isHighlighted ? Palette.gold.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    private func run(_ item: PaletteItem) {
        close()
        item.run()
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case KeyCode.escape:
            close()
        case KeyCode.down:
            if !flat.isEmpty { highlighted = min(highlighted + 1, flat.count - 1) }
        case KeyCode.up:
            highlighted = max(highlighted - 1, 0)
        case KeyCode.returnKey, KeyCode.enter:
            if flat.indices.contains(highlighted) { run(flat[highlighted]) }
        default:
            return false
        }
        return true
    }

    private func refreshNodes() async {
        highlighted = 0
        guard trimmed.count >= 2 else {
            nodes = []
            return
        }
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }
        let found = await searchNodes(trimmed)
        guard !Task.isCancelled else { return }
        nodes = found
    }
}

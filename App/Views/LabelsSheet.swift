import SwiftUI

/// The person's labels for main folders: the defaults, edited, and their own. Each label decides a
/// folder's colour on the map, whether it's in the graph to start with, whether others can read it,
/// and what AI tools are told. Changes join Arrange's draft, so they're saved with it.
struct LabelsSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// How many main folders and areas use a label, in the draft.
    let uses: (FolderPurpose) -> Int
    let onDone: ([FolderPurpose]) -> Void

    @State private var kinds: [FolderPurpose]
    @State private var selectedID: String?
    @State private var confirmingDelete: FolderPurpose?

    init(kinds: [FolderPurpose], uses: @escaping (FolderPurpose) -> Int, onDone: @escaping ([FolderPurpose]) -> Void) {
        self.uses = uses
        self.onDone = onDone
        _kinds = State(initialValue: kinds)
        _selectedID = State(initialValue: kinds.first?.id)
    }

    private static let symbols = [
        "briefcase", "person", "building.2", "doc.text", "books.vertical", "archivebox", "folder", "tag",
        "flask", "hammer", "graduationcap", "gamecontroller", "paintbrush", "lightbulb", "star", "heart",
        "globe", "cpu", "leaf", "cart", "house", "shippingbox", "music.note", "camera",
    ]

    /// The map's colours: three hues stay colour-blind safe, and everything else is grey.
    private static let colours: [(slot: Int, name: String)] = [(0, "Green"), (1, "Purple"), (2, "Orange"), (-1, "Grey")]

    private var selectedIndex: Int? { kinds.firstIndex { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Labels").font(.title3.weight(.semibold))
                Text("What your main folders can be. A label sets a folder's colour on the map, whether it's in the graph to start with, and what AI tools are told about it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(spacing: 0) {
                list.frame(width: 220)
                Rectangle().fill(Palette.hairline).frame(width: 1)
                Group {
                    if let index = selectedIndex { editor($kinds[index]) } else { Spacer() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack {
                Button("Restore Defaults") { restoreDefaults() }
                    .buttonStyle(.link)
                    .help("Put the built-in labels back as they were. Your own labels stay.")
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Done") {
                    onDone(kinds)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(GoldButtonStyle())
            }
            .padding(14)
        }
        .frame(width: 680, height: 520)
        .background(Palette.panel)
        .alert(
            confirmingDelete.map { "Delete “\($0.title)”?" } ?? "",
            isPresented: Binding(get: { confirmingDelete != nil }, set: { if !$0 { confirmingDelete = nil } }),
            presenting: confirmingDelete
        ) { kind in
            Button("Delete", role: .destructive) { delete(kind) }
            Button("Cancel", role: .cancel) {}
        } message: { kind in
            let count = uses(kind)
            Text("\(count) folder\(count == 1 ? "" : "s") or area\(count == 1 ? "" : "s") use it. They become Other when you save.")
        }
    }

    // MARK: - List

    private var list: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(kinds) { kind in
                    HStack(spacing: 8) {
                        Image(systemName: kind.symbol).frame(width: 18).foregroundStyle(Palette.series(kind.colorSlot))
                        Text(kind.title.isEmpty ? "Untitled" : kind.title).lineLimit(1)
                        Spacer(minLength: 4)
                        let count = uses(kind)
                        if count > 0 {
                            Text(count.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                                .help("\(count) folder\(count == 1 ? "" : "s") or area\(count == 1 ? "" : "s") use it")
                        }
                    }
                    .tag(kind.id)
                }
                .onMove { kinds.move(fromOffsets: $0, toOffset: $1) }
            }
            .scrollContentBackground(.hidden)
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(spacing: 6) {
                Button("Add Label", systemImage: "plus") { add() }
                    .buttonStyle(SoftButtonStyle())
                Spacer()
                if let index = selectedIndex {
                    let kind = kinds[index]
                    Button("Delete", systemImage: "trash") {
                        if uses(kind) > 0 { confirmingDelete = kind } else { delete(kind) }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(SoftButtonStyle())
                    .disabled(kind.id == FolderPurpose.other.id)
                    .help(kind.id == FolderPurpose.other.id ? "Other stays: folders go there when their label is deleted" : "Delete this label")
                }
            }
            .padding(10)
        }
    }

    // MARK: - Editor

    private func editor(_ kind: Binding<FolderPurpose>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    symbolMenu(kind)
                    TextField("Name", text: kind.title)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.weight(.medium))
                }
                field("Colour on the map") {
                    Picker("Colour", selection: Binding(
                        get: { (0...2).contains(kind.wrappedValue.colorSlot) ? kind.wrappedValue.colorSlot : -1 },
                        set: { kind.wrappedValue.colorSlot = $0 }
                    )) {
                        ForEach(Self.colours, id: \.slot) { colour in
                            Text(colour.name).tag(colour.slot)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                field("What it's for") {
                    TextField("A sentence, shown when you pick a label", text: kind.detail)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Leave its folders out of the graph to start with", isOn: kind.isLeftOutByDefault)
                    Toggle("Other people can read its repos, like a job's or a client's", isOn: kind.isShared)
                    Toggle("Notes and docs rather than code", isOn: kind.isDocs)
                }
                .toggleStyle(.checkbox)
                .font(.callout)
                field("What AI tools are told") {
                    TextField("Optional. Added to the guide for every folder with this label.", text: kind.guideText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...5)
                }
                if kind.wrappedValue.isDefault {
                    Text("A built-in label. Restore Defaults puts it back as it was.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
        }
    }

    private func symbolMenu(_ kind: Binding<FolderPurpose>) -> some View {
        Menu {
            ForEach(Self.symbols, id: \.self) { symbol in
                Button { kind.wrappedValue.symbol = symbol } label: { Label(symbol, systemImage: symbol) }
            }
        } label: {
            Image(systemName: kind.wrappedValue.symbol)
                .foregroundStyle(Palette.series(kind.wrappedValue.colorSlot))
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Icon")
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Actions

    private func add() {
        let kind = FolderPurpose.custom(title: "New label")
        // New labels go before Other, which stays last.
        let otherIndex = kinds.firstIndex { $0.id == FolderPurpose.other.id } ?? kinds.endIndex
        kinds.insert(kind, at: otherIndex)
        selectedID = kind.id
    }

    private func delete(_ kind: FolderPurpose) {
        guard kind.id != FolderPurpose.other.id, let index = kinds.firstIndex(of: kind) else { return }
        kinds.remove(at: index)
        selectedID = kinds[min(index, kinds.count - 1)].id
    }

    private func restoreDefaults() {
        let own = kinds.filter { !$0.isDefault }
        let otherIndex = FolderPurpose.defaults.firstIndex { $0.id == FolderPurpose.other.id } ?? FolderPurpose.defaults.endIndex
        var restored = FolderPurpose.defaults
        restored.insert(contentsOf: own, at: otherIndex)
        kinds = restored
    }
}

/// A main folder's words for AI tools, and whether each folder inside it is a project. Edits apply
/// to Arrange's draft when the popover closes, as one step to undo.
struct FolderNotesEditor: View {
    let paths: [String]
    let labels: [FolderLabel]
    let onClose: ([String: (note: String, holdsProjects: Bool)]) -> Void

    @State private var edits: [String: (note: String, holdsProjects: Bool)]

    init(paths: [String], labels: [FolderLabel], onClose: @escaping ([String: (note: String, holdsProjects: Bool)]) -> Void) {
        self.paths = paths
        self.labels = labels
        self.onClose = onClose
        var start: [String: (note: String, holdsProjects: Bool)] = [:]
        for path in paths {
            let label = labels.first { $0.path == path }
            start[path] = (label?.note ?? "", label?.holdsProjects ?? false)
        }
        _edits = State(initialValue: start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(paths, id: \.self) { path in
                VStack(alignment: .leading, spacing: 6) {
                    Text(path + "/").font(.callout.weight(.semibold))
                    TextField("What's it for? AI tools read this in the guide.", text: Binding(
                        get: { edits[path]?.note ?? "" },
                        set: { edits[path]?.note = $0 }
                    ), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    Toggle("Each folder inside is a project", isOn: Binding(
                        get: { edits[path]?.holdsProjects ?? false },
                        set: { edits[path]?.holdsProjects = $0 }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .help("Projects on the board follow this when you save")
                }
            }
        }
        .padding(14)
        .frame(width: 340)
        .onDisappear { onClose(edits) }
    }
}

import SwiftUI

struct TriageView: View {
    @Environment(AppModel.self) private var model
    let detector: Detector
    let findings: [Finding]

    @State private var selection = Set<Finding.ID>()
    @State private var sortOrder = [KeyPathComparator(\Finding.count, order: .reverse)]
    @State private var showsInspector = true
    @State private var isConfirmingIgnore = false

    private var sorted: [Finding] { findings.sorted(using: sortOrder) }
    private var selected: [Finding] { sorted.filter { selection.contains($0.id) } }
    private var ignorable: [Finding] { selected.filter { $0.ignoreLine != nil } }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: detector.title, subtitle: "\(findings.count.formatted()) \(findings.count == 1 ? "finding" : "findings") to review") {
                Button(detector.removeTitle, systemImage: detector == .crossProject ? "link.badge.plus" : "eye.slash") {
                    act { model.remove($0) }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(selection.isEmpty)
                .help("\(detector.removeTitle) (⌘⌫)")

                Button("Keep", systemImage: "checkmark") {
                    act { model.keep($0) }
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .disabled(selection.isEmpty)
                .help("Keep and remove from this list (⇧⌘K)")

                if detector == .generated {
                    Button("Add to .graphifyignore…", systemImage: "nosign") {
                        isConfirmingIgnore = true
                    }
                    .disabled(ignorable.isEmpty)
                }

                Button("Details", systemImage: "sidebar.right") { showsInspector.toggle() }
                    .labelStyle(.iconOnly)
                    .keyboardShortcut("i")
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(spacing: 0) {
                Group {
                    if findings.isEmpty {
                        ContentUnavailableView(
                            "Nothing Left to Review",
                            systemImage: "checkmark.circle",
                            description: Text(detector.explanation)
                        )
                    } else {
                        table
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if showsInspector {
                    Rectangle().fill(Palette.hairline).frame(width: 1)
                    FindingInspector(detector: detector, findings: selected)
                        .frame(width: 320)
                }
            }
        }
        .alert("Add to .graphifyignore?", isPresented: $isConfirmingIgnore) {
            Button("Add and Hide") { act { model.addToIgnoreFile($0) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
                Future graphify builds will skip:

                \(ignorable.compactMap(\.ignoreLine).joined(separator: "\n"))

                These are also hidden now. Undo restores the nodes, but the ignore lines stay until you remove them from the file.
                """)
        }
    }

    private var table: some View {
        Table(sorted, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Finding", value: \.title) { finding in
                VStack(alignment: .leading, spacing: 1) {
                    Text(finding.title).lineLimit(1)
                    Text(finding.location)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.vertical, 2)
            }
            .width(min: 200, ideal: 320)
            TableColumn("Project", value: \.project) { finding in
                Text(finding.project).foregroundStyle(.secondary).lineLimit(1)
            }
            .width(min: 80, ideal: 130, max: 200)
            TableColumn("Affects", value: \.count) { finding in
                VStack(alignment: .trailing, spacing: 1) {
                    Text(finding.affects).monospacedDigit().lineLimit(1)
                    if !finding.note.isEmpty {
                        Text(finding.note).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
            }
            .width(min: 120, ideal: 140, max: 180)
        }
        .scrollContentBackground(.hidden)
        .alternatingRowBackgrounds(.disabled)
        .contextMenu(forSelectionType: Finding.ID.self) { ids in
            if !ids.isEmpty {
                Button(detector.removeTitle) { act(on: ids) { model.remove($0) } }
                Button("Keep") { act(on: ids) { model.keep($0) } }
            }
        }
    }

    private func act(_ action: ([Finding]) -> Void) {
        act(on: selection, action)
    }

    /// Moves the selection to the next row straight away, so review can continue by keyboard.
    private func act(on ids: Set<Finding.ID>, _ action: ([Finding]) -> Void) {
        let rows = sorted
        let targets = rows.filter { ids.contains($0.id) }
        guard !targets.isEmpty else { return }
        let lastIndex = rows.lastIndex { ids.contains($0.id) } ?? 0
        let next = rows[(lastIndex + 1)...].first { !ids.contains($0.id) }
            ?? rows[..<lastIndex].last { !ids.contains($0.id) }
        selection = next.map { [$0.id] } ?? []
        action(targets)
    }
}

struct FindingInspector: View {
    @Environment(AppModel.self) private var model
    let detector: Detector
    let findings: [Finding]

    @State private var details: [FindingDetail] = []
    @State private var isLoading = false

    private var taskKey: String { "\(findings.first?.id ?? "")|\(findings.count)|\(model.revision)" }

    var body: some View {
        Group {
            if findings.count == 1, let finding = findings.first {
                single(finding)
            } else if findings.count > 1 {
                ContentUnavailableView {
                    Label("\(findings.count) Selected", systemImage: detector.symbol)
                } description: {
                    Text("\(findings.reduce(0) { $0 + $1.count }.formatted()) \(findings[0].unit) in total")
                }
            } else {
                ContentUnavailableView {
                    Label(detector.title, systemImage: detector.symbol)
                } description: {
                    Text(detector.explanation)
                }
            }
        }
        .task(id: taskKey) {
            guard findings.count == 1, let finding = findings.first else {
                details = []
                return
            }
            isLoading = true
            let loaded = await model.details(for: finding)
            guard !Task.isCancelled else { return }
            details = loaded
            isLoading = false
        }
    }

    private func single(_ finding: Finding) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(finding.title).font(.headline).textSelection(.enabled)
                Text(finding.location)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(([finding.affects] + (finding.note.isEmpty ? [] : [finding.note])).joined(separator: " · "))
                    .foregroundStyle(.secondary)
                Text(detector.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(Palette.hairline).frame(height: 1)

            List(details) { detail in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(detail.title).lineLimit(1)
                        Text(detail.subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 4)
                    Text(detail.trailing)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                    if let rejection = detail.rejection {
                        Button("Reject", systemImage: "xmark.circle") { model.perform([rejection]) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .help("Reject only this link")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .overlay {
                if isLoading && details.isEmpty { ProgressView() }
            }
        }
    }
}

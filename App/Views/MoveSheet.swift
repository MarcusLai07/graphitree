import AppKit
import SwiftUI

/// What the On Disk menu opens: a move or a rename of one project's folder, checked first.
struct MoveSheetItem: Identifiable {
    let id = UUID()
    let request: MoveRequest
}

/// The confirm sheet for moving or renaming a folder: where it goes, what Graphitree also updates,
/// what changes for git, and what's up to the person. Nothing moves until they press the button.
struct MoveSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let start: MoveRequest
    let arrangement: Arrangement
    let onDone: (Result<FolderMove, PlaybookError>) -> Void

    @State private var name: String
    @State private var check: MoveCheck?
    @State private var switchRemote = false
    @State private var isMoving = false

    init(start: MoveRequest, arrangement: Arrangement, onDone: @escaping (Result<FolderMove, PlaybookError>) -> Void) {
        self.start = start
        self.arrangement = arrangement
        self.onDone = onDone
        _name = State(initialValue: start.newName)
    }

    private var request: MoveRequest { MoveRequest(item: start.item, newParent: start.newParent, newName: start.isRename ? name : start.newName) }
    private var root: String { model.graphRoot }

    var body: some View {
        MoveSheetBody(
            request: request,
            root: root,
            name: $name,
            check: check?.request == request ? check : nil,
            switchRemote: $switchRemote,
            isMoving: isMoving,
            docsLine: check.map(docsLine) ?? nil,
            onCancel: { dismiss() },
            onMove: { Task { await move() } }
        )
        .task(id: request) {
            // A short pause while typing a new name, so git and lsof don't run on every key.
            if start.isRename { try? await Task.sleep(for: .milliseconds(350)) }
            guard !Task.isCancelled else { return }
            let found = await model.checkMove(request, arrangement: arrangement)
            if found.request == request { check = found }
        }
    }

    private func docsLine(_ check: MoveCheck) -> String? {
        guard !check.docs.isEmpty else { return nil }
        let files = check.docs.files.count
        let tokens: Int
        if let docs = model.docsPass() {
            tokens = model.docsCost(check.docs, docs: docs).totalTokens
        } else {
            tokens = check.docs.contentTokens
        }
        return "The next docs pass reads its \(files) doc\(files == 1 ? "" : "s") again, about \(Self.short(tokens)) tokens: graphify's cache is keyed by each file's path. Until then the graph has its code but not what AI read from its docs."
    }

    static func short(_ tokens: Int) -> String {
        tokens >= 1_000_000 ? String(format: "%.1fM", Double(tokens) / 1_000_000) : tokens >= 1_000 ? "\(tokens / 1_000)k" : "\(tokens)"
    }

    private func move() async {
        guard let check, check.canMove else { return }
        isMoving = true
        let remote = switchRemote ? check.remoteChoice?.suggested : nil
        let result = await model.performMove(request, arrangement: arrangement, remote: remote)
        isMoving = false
        dismiss()
        onDone(result)
    }
}

/// The sheet's layout, apart from the model, so screenshots can show it with a made-up check.
struct MoveSheetBody: View {
    let request: MoveRequest
    let root: String
    @Binding var name: String
    let check: MoveCheck?
    @Binding var switchRemote: Bool
    let isMoving: Bool
    let docsLine: String?
    let onCancel: () -> Void
    let onMove: () -> Void

    private func shown(_ path: String) -> String {
        AgentGuide.abbreviate(FolderMoves.absolute(path, root: root))
    }

    private var title: String {
        if request.isRename { return "Rename \(request.name)" }
        return "Move \(request.name) to \(request.newParent.isEmpty ? "the top level" : request.newParent + "/")?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.semibold))
                Text(request.isRename
                     ? "The folder is renamed on disk. Its GitHub repo keeps its own name."
                     : "The folder moves on disk with everything in it, .git included.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if request.isRename {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .onSubmit { if check?.canMove == true { onMove() } }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(shown(request.item)).foregroundStyle(.secondary).strikethrough(!request.changesNothing, color: .secondary.opacity(0.6))
                Label(shown(request.target), systemImage: "arrow.turn.down.right").foregroundStyle(Palette.gold)
            }
            .font(.caption.monospaced())
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let check {
                        if let problem = FolderMoves.nameProblem(request.newName) ?? check.blockers.first {
                            ForEach([problem] + check.blockers.filter { $0 != problem }, id: \.self) { line in
                                item(line, symbol: "exclamationmark.octagon", colour: Palette.coral)
                            }
                        }
                        section("Graphitree also updates") {
                            ForEach(check.updates, id: \.self) { item($0, symbol: "checkmark", colour: Palette.jade) }
                        }
                        if !check.rules.isEmpty {
                            section("Your git rules") {
                                ForEach(check.rules, id: \.self) { item($0, symbol: "person.badge.key", colour: Palette.gold) }
                                if let choice = check.remoteChoice {
                                    Picker("Remote", selection: $switchRemote) {
                                        Text("Keep pushing to \(choice.currentOwner)").tag(false)
                                        Text("Point it at \(choice.newLogin)/\(FolderMoves.repoName(ofRemote: choice.current))").tag(true)
                                    }
                                    .pickerStyle(.radioGroup)
                                    .labelsHidden()
                                    .padding(.leading, 24)
                                    Text(switchRemote
                                         ? "Sets origin to \(choice.suggested). The repo has to exist on \(choice.newLogin) before the next push."
                                         : "Only the commit identity changes. Pushes still go to \(choice.currentOwner).")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .padding(.leading, 24)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        if let docsLine {
                            section("Cost") { item(docsLine, symbol: "sparkles", colour: Palette.gold) }
                        }
                        section("Up to you") {
                            ForEach(check.yours, id: \.self) { item($0, symbol: "info.circle", colour: .secondary) }
                        }
                    } else if let problem = FolderMoves.nameProblem(request.newName) {
                        item(problem, symbol: "exclamationmark.octagon", colour: Palette.coral)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Checking what the move touches…").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 160, maxHeight: 480)

            HStack {
                Text("You can undo the move from Arrange.").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(SoftButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(isMoving ? "Moving…" : request.isRename ? "Rename Folder" : "Move Folder", action: onMove)
                    .buttonStyle(GoldButtonStyle())
                    .disabled(check?.canMove != true || isMoving || FolderMoves.nameProblem(request.newName) != nil)
            }
        }
        .padding(20)
        .frame(width: 540)
        .background(Palette.panel)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func item(_ text: String, symbol: String, colour: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).font(.caption).foregroundStyle(colour).frame(width: 16)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A new folder at the top of the root to move projects into, labelled to hold projects. Shows the
/// git rule line to copy, since Graphitree doesn't edit `~/.gitconfig`.
struct NewFolderSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let onCreated: (String) -> Void

    @State private var name: String
    @State private var purpose: FolderPurpose = .other
    @State private var rules: GitRules?
    @State private var ruleFolder: String
    @State private var failure: String?

    init(initialName: String = "", initialRule: String = "", onCreated: @escaping (String) -> Void) {
        self.onCreated = onCreated
        _name = State(initialValue: initialName)
        _ruleFolder = State(initialValue: initialRule)
    }

    private var problem: String? {
        guard !name.isEmpty else { return nil }
        if let problem = FolderMoves.nameProblem(name) { return problem }
        let existing = (try? FileManager.default.contentsOfDirectory(atPath: model.graphRoot)) ?? []
        return existing.contains { $0.lowercased() == name.lowercased() } ? "There's already something called \(name)." : nil
    }

    private var chosenRule: GitRule? { rules?.rules.first { $0.folder == ruleFolder } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New folder in \(AgentGuide.abbreviate(model.graphRoot))").font(.title3.weight(.semibold))
                Text("Somewhere to move projects into. Each folder inside it is a project.").font(.caption).foregroundStyle(.secondary)
            }
            TextField("clients", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
            if let problem {
                Text(problem).font(.caption).foregroundStyle(Palette.coral)
            }
            Picker("Purpose", selection: $purpose) {
                ForEach(model.folderMap()?.kinds ?? FolderPurpose.defaults) { Text($0.title).tag($0) }
            }
            .fixedSize()
            VStack(alignment: .leading, spacing: 6) {
                Text("Commits made in it").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                if let rules {
                    Picker("Commits", selection: $ruleFolder) {
                        Text("Your global identity\(rules.global.map { ": \($0.display)" } ?? "")").tag("")
                        ForEach(rules.rules) { rule in
                            Text("Like \(FolderMoves.relative(String(rule.folder.dropLast()), root: model.graphRoot))/\(rule.identity.map { ": \($0.display)" } ?? "")").tag(rule.folder)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    if let rule = chosenRule, !name.isEmpty, problem == nil {
                        let lines = FolderMoves.includeIfLines(folder: name, root: model.graphRoot, like: rule)
                        Text("Add this to ~/.gitconfig before moving repos in. Graphitree doesn't edit it. If your shell picks the gh account by folder, add \(name)/ there too.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(alignment: .top) {
                            Text(lines).font(.caption.monospaced()).textSelection(.enabled)
                            Spacer()
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(lines + "\n", forType: .string)
                            }
                            .buttonStyle(SoftButtonStyle())
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            if let failure {
                Text(failure).font(.caption).foregroundStyle(Palette.coral)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(SoftButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Create Folder") {
                    if let failure = model.newFolder(name, purpose: purpose) {
                        self.failure = failure
                    } else {
                        dismiss()
                        onCreated(name)
                    }
                }
                .buttonStyle(GoldButtonStyle())
                .disabled(name.isEmpty || problem != nil)
            }
        }
        .padding(20)
        .frame(width: 500)
        .background(Palette.panel)
        .task {
            let found = await Task.detached { GitRules.read() }.value
            rules = found
        }
    }
}

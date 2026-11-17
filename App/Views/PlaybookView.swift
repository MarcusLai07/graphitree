import AppKit
import SwiftUI

/// The playbook: the libraries AI tools should reach for, the stack to default to, and how you
/// work. It's written as PLAYBOOK.md next to the guide, which tells tools to read it.
struct PlaybookView: View {
    @Environment(AppModel.self) private var model
    /// Missing where the Playbook is drawn without the app around it, such as GraphitreeShots.
    @Environment(LabRouter.self) private var lab: LabRouter?
    @Environment(\.openWindow) private var openWindow
    let openModels: () -> Void

    @State private var playbook = Playbook()
    @State private var isLoaded = false
    @State private var tab: PlaybookTab = .chat
    @State private var message: String?
    @State private var saveTask: Task<Void, Never>?
    @State private var isDirty = false

    // Libraries
    @State private var addText = ""
    @State private var editing: UUID?
    @State private var drafting: Set<UUID> = []
    @State private var pendingRemoval: UUID?

    // Stack
    @State private var scan: StackScanResult?
    @State private var isScanning = false

    // Storage
    @AppStorage("playbookStorage") private var storage = "local"
    @AppStorage("playbookAccount") private var account = ""
    @AppStorage("playbookRepoName") private var repoName = "graphitree-playbook"
    @AppStorage("playbookRemote") private var remote = ""
    @AppStorage("playbookLastBackup") private var lastBackup = 0.0
    @State private var accounts: [String] = []
    @State private var hasCheckedAccounts = false
    @State private var isConfirmingCreate = false
    @State private var isBackingUp = false
    @State private var addsToGraph = true
    /// Which folder's stack the Stack tab edits. Empty means everywhere.
    @State private var stackScope = ""
    @State private var stackFolders: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Playbook", subtitle: "What AI tools should reach for when they build")
            Rectangle().fill(Palette.hairline).frame(height: 1)
            VStack(alignment: .leading, spacing: 12) {
                summaryStrip
                Picker("Section", selection: $tab) {
                    ForEach(PlaybookTab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if let message {
                    Text(message).font(.caption).foregroundStyle(Palette.gold).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding([.horizontal, .top], 18)
            .padding(.bottom, 12)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            if tab == .chat {
                PlaybookChatView(playbook: playbook, scan: scan, apply: applyChange, openModels: openModels)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(tab.intro).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        switch tab {
                        case .chat: EmptyView()
                        case .libraries: librariesTab
                        case .stack: stackTab
                        case .habits: habitsTab
                        case .storage: storageTab
                        }
                    }
                    .padding([.horizontal, .bottom], 18)
                    .padding(.top, 4)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task { await load() }
        .onDisappear { finishEditing() }
    }

    /// A change the chat suggested, applied the same way as an edit made by hand.
    private func applyChange(_ change: PlaybookChange) {
        edit { $0 = PlaybookChat.applying(change, to: $0) }
        message = nil
    }

    // MARK: - Summary

    private var summaryStrip: some View {
        let verified = playbook.libraries.filter(\.verified).count
        let answered = PlaybookQuestions.stack.filter { !(playbook.stack[$0.id]?.isEmpty ?? true) }.count
        let habits = PlaybookQuestions.habits.filter { !(playbook.habits[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        return HStack(spacing: 8) {
            tile("Libraries", symbol: "books.vertical.fill", value: "\(playbook.libraries.count)", detail: playbook.libraries.isEmpty ? "None yet" : "\(verified) verified") { tab = .libraries }
            tile("Stack", symbol: "square.stack.3d.up.fill", value: "\(answered)/\(PlaybookQuestions.stack.count)", detail: "answered") { tab = .stack }
            tile("How you work", symbol: "person.text.rectangle.fill", value: "\(habits)/\(PlaybookQuestions.habits.count)", detail: "filled in") { tab = .habits }
            tile("Stored", symbol: storage == "github" ? "lock.icloud.fill" : "internaldrive.fill", value: storage == "github" ? "GitHub" : "This Mac", detail: backupDetail) { tab = .storage }
        }
    }

    private var backupDetail: String {
        guard storage == "github" else { return "Only here" }
        guard lastBackup > 0 else { return "Not backed up yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Backed up \(formatter.localizedString(for: Date(timeIntervalSince1970: lastBackup), relativeTo: .now))"
    }

    private func tile(_ title: String, symbol: String, value: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(Palette.gold.opacity(0.9))
                Text(value).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(RowCard())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Libraries

    private var librariesTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add libraries").font(.body.weight(.medium))
                Text("One per line: a name, a link, or \"Name – link\". Paste a whole list at once.").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $addText)
                    .font(.system(.callout, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(height: 64)
                    .padding(6)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                HStack {
                    Spacer()
                    Button("Add") { addPasted() }
                        .buttonStyle(GoldButtonStyle())
                        .disabled(addText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .modifier(RowCard())

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Already in your projects").font(.body.weight(.medium))
                    FlowLayout(spacing: 6) {
                        ForEach(suggestions, id: \.name) { item in
                            Button { addKnown(item.library) } label: {
                                Label("\(item.name) · \(item.projects)", systemImage: "plus").font(.caption)
                            }
                            .buttonStyle(ChipStyle(isOn: false))
                            .help("Used in \(item.projects) project\(item.projects == 1 ? "" : "s"). Add it to the playbook.")
                        }
                    }
                }
                .modifier(RowCard())
            }

            if !undescribed.isEmpty || !drafting.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").foregroundStyle(Palette.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drafting.isEmpty ? "\(undescribed.count) librar\(undescribed.count == 1 ? "y has" : "ies have") no details yet" : "Claude is researching \(drafting.count) librar\(drafting.count == 1 ? "y" : "ies")…")
                            .font(.body.weight(.medium))
                        Text("Claude Code looks each one up on the web, using your plan, about 30 seconds for six. You check its drafts before AI tools rely on them.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if drafting.isEmpty {
                        Button("Draft with Claude") { Task { await draft(undescribed) } }.buttonStyle(GoldButtonStyle())
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .modifier(RowCard())
            }

            if playbook.libraries.isEmpty {
                Text("No libraries yet. Paste your list above, or add ones your projects already use.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                healthCheckCard
                if !LabCatalog.bundled.entries.isEmpty { labCard }
            }
            ForEach(playbook.librariesByTask, id: \.task) { group in
                Text(group.task.isEmpty ? "No task yet" : group.task)
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.gold.opacity(0.85))
                    .padding(.top, 6)
                ForEach(group.libraries) { libraryCard($0) }
            }
        }
    }

    private var undescribed: [PlaybookLibrary] { playbook.libraries.filter { !$0.isDescribed && !$0.verified } }

    private var suggestions: [(name: String, projects: Int, library: PlaybookLibrary)] {
        guard let scan else { return [] }
        var seen: Set<String> = []
        return StackScan.knownLibraries.compactMap { known in
            guard let projects = scan.libraries[known.name], !PlaybookImport.contains(known, in: playbook.libraries), seen.insert(known.name).inserted else { return nil }
            return (known.name, projects.count, PlaybookLibrary(name: known.name, url: known.url, task: known.task))
        }
        .sorted { $0.projects > $1.projects }
    }

    /// Re-researching every library, now or once a month. Changes land in the chat to apply.
    private var healthCheckCard: some View {
        @Bindable var model = model
        let batches = Int(ceil(Double(playbook.libraries.count) / Double(PlaybookResearch.batchSize)))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "stethoscope").foregroundStyle(Palette.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Library check").font(.body.weight(.medium))
                    Text("Claude Code looks every library up again and flags any that became unmaintained or changed how they install. About \(BuildView.tokens(batches * 25_000)) tokens of your plan for \(playbook.libraries.count). What changed appears in Chat for you to apply.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let last = model.freshness.lastLibraryCheck {
                        Text("Last checked \(last.formatted(date: .abbreviated, time: .omitted)).").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 8)
                if model.isCheckingLibraries {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Check Now") {
                        Task {
                            saveTask?.cancel()
                            save()
                            await model.checkLibraries()
                            message = "The library check is done. See Chat for what changed."
                        }
                    }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(model.isChatting)
                }
            }
            Toggle("Check every month while Graphitree is open", isOn: $model.freshness.checksLibrariesMonthly)
                .toggleStyle(.checkbox)
                .font(.caption)
                .padding(.leading, 26)
        }
        .modifier(RowCard())
    }

    /// The Playbook lab: a composer where the libraries can be tried together, before you verify them.
    private var labCard: some View {
        let covered = playbook.libraries.filter { LabCatalog.bundled.route(for: $0.name) != nil }.count
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flask").foregroundStyle(Palette.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Playbook lab").font(.body.weight(.medium))
                Text("Compose a screen from components and pick which library draws each one, on a React canvas or a native SwiftUI one. \(covered) of these libraries can go on the React canvas, and Try It opens a card's library there. The lab ships with Graphitree, so nothing loads from the web.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Open Lab") { openLab("compose") }
                .buttonStyle(SoftButtonStyle())
        }
        .modifier(RowCard())
    }

    private func openLab(_ route: String) {
        lab?.show(route)
        openWindow(id: "lab")
    }

    private func libraryCard(_ library: PlaybookLibrary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(library.name).font(.body.weight(.semibold))
                badge(library)
                Spacer(minLength: 8)
                if drafting.contains(library.id) {
                    ProgressView().controlSize(.small)
                } else {
                    if let route = LabCatalog.bundled.route(for: library.name) {
                        Button("Try It") { openLab(route) }
                            .buttonStyle(SoftButtonStyle())
                            .help("Open \(library.name) in the Playbook lab")
                    }
                    Button(library.verified ? "Unverify" : "Verify") { update(library.id) { $0.verified.toggle() } }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(!library.isDescribed)
                        .help(library.verified ? "Mark it as a draft again" : "You've checked these details. AI tools can rely on them.")
                    Button(editing == library.id ? "Done" : "Edit") { editing = editing == library.id ? nil : library.id }
                        .buttonStyle(SoftButtonStyle())
                    Button("Remove", systemImage: "trash") { pendingRemoval = library.id }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Remove from the playbook")
                }
            }
            if !library.url.isEmpty, let url = URL(string: library.url) {
                Link(library.url, destination: url).font(.caption).foregroundStyle(Palette.gold.opacity(0.85))
            }
            if editing == library.id {
                libraryForm(library.id)
            } else {
                if !library.purpose.isEmpty { Text(library.purpose).font(.callout).fixedSize(horizontal: false, vertical: true) }
                if !library.useWhen.isEmpty { fact("Use when", library.useWhen) }
                if !library.avoidWhen.isEmpty { fact("Avoid when", library.avoidWhen) }
                if !library.install.isEmpty {
                    HStack(spacing: 6) {
                        Text(library.install).font(.caption.monospaced()).textSelection(.enabled)
                        if !library.platforms.isEmpty { Text("· \(library.platforms)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if !library.health.isEmpty {
                    Label(library.health, systemImage: library.looksAbandoned ? "exclamationmark.triangle.fill" : "heart.text.square")
                        .font(.caption)
                        .foregroundStyle(library.looksAbandoned ? Palette.coral : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !library.notes.isEmpty { fact("Your note", library.notes) }
            }
            if pendingRemoval == library.id {
                HStack {
                    Text("Remove \(library.name) from the playbook?").font(.callout)
                    Spacer()
                    Button("Cancel") { pendingRemoval = nil }.buttonStyle(SoftButtonStyle())
                    Button("Remove It") { remove(library.id) }.buttonStyle(GoldButtonStyle())
                }
            }
        }
        .modifier(RowCard())
    }

    @ViewBuilder
    private func badge(_ library: PlaybookLibrary) -> some View {
        if library.looksAbandoned {
            Text("Avoid for new work").font(.caption2.weight(.semibold)).foregroundStyle(Palette.coral)
        }
        if library.verified {
            Label("Verified", systemImage: "checkmark.seal.fill").font(.caption2.weight(.semibold)).foregroundStyle(Palette.jade)
        } else if library.drafted {
            Label("Claude's draft", systemImage: "sparkles").font(.caption2.weight(.semibold)).foregroundStyle(Palette.gold)
        } else if !library.isDescribed {
            Text("Not described").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func fact(_ title: String, _ text: String) -> some View {
        (Text(title + ": ").foregroundStyle(.secondary) + Text(text))
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func libraryForm(_ id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            field("Name", \.name, id)
            field("Link", \.url, id)
            field("Task", \.task, id, placeholder: "Toasts, Drawers, UI components…")
            field("What it's for", \.purpose, id)
            field("Use when", \.useWhen, id)
            field("Avoid when", \.avoidWhen, id)
            field("Install", \.install, id, placeholder: "npm install …")
            field("Works with", \.platforms, id, placeholder: "React, any web stack…")
            field("Health", \.health, id, placeholder: "Maintained? Latest release?")
            field("Your note", \.notes, id, placeholder: "Anything AI tools should know, such as how you use it")
            HStack {
                Button("Redraft with Claude") {
                    if let library = playbook.libraries.first(where: { $0.id == id }) { Task { await draft([library]) } }
                }
                .buttonStyle(SoftButtonStyle())
                .disabled(!drafting.isEmpty)
                Spacer()
                Button("Done") { editing = nil }.buttonStyle(GoldButtonStyle())
            }
        }
    }

    private func field(_ label: String, _ keyPath: WritableKeyPath<PlaybookLibrary, String>, _ id: UUID, placeholder: String = "") -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).font(.callout).frame(width: 96, alignment: .leading)
            TextField(placeholder, text: Binding(
                get: { playbook.libraries.first { $0.id == id }?[keyPath: keyPath] ?? "" },
                set: { value in update(id) { $0[keyPath: keyPath] = value } }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...4)
        }
    }

    // MARK: - Stack

    private var stackTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isScanning ? "Scanning your projects…" : scan.map { "Scanned \($0.projectsScanned) projects in \(AgentGuide.abbreviate(model.graphRoot))" } ?? "Not scanned yet")
                        .font(.body.weight(.medium))
                    Text("Numbers on a choice are how many projects already use it. The scan reads manifests such as package.json on this Mac, with no AI.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("Fill In From Scan") { fillFromScan() }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(scan == nil)
                    .help("Picks what most projects use, for questions you haven't answered")
                Button("Rescan") { Task { await runScan() } }.buttonStyle(SoftButtonStyle()).disabled(isScanning)
            }
            .modifier(RowCard())
            if !stackFolders.isEmpty { scopeBar }
            ForEach(PlaybookQuestions.stack) { questionCard($0) }
        }
    }

    /// Everywhere, or one main folder with answers of its own, such as a different back end at work.
    private var scopeBar: some View {
        HStack(spacing: 10) {
            Text("Answers for").font(.callout)
            Picker("Answers for", selection: $stackScope) {
                Text("Everywhere").tag("")
                ForEach(stackFolders, id: \.self) { folder in
                    Text(folder + "/" + (playbook.folderStacks?[folder]?.values.contains { !$0.isEmpty } == true ? "  (own answers)" : "")).tag(folder)
                }
            }
            .labelsHidden()
            .fixedSize()
            Text(stackScope.isEmpty
                 ? "The defaults for new work. A folder can have its own answers."
                 : "Answers here replace the defaults only inside \(stackScope)/. Grey choices are the defaults it follows.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .modifier(RowCard())
    }

    /// The answer the Stack tab shows: the folder's own, or the default it follows.
    private func shownAnswer(_ question: String) -> (answer: StackAnswer, isOwn: Bool) {
        guard !stackScope.isEmpty else { return (playbook.stack[question] ?? StackAnswer(), true) }
        if let own = playbook.folderStacks?[stackScope]?[question], !own.isEmpty { return (own, true) }
        return (playbook.stack[question] ?? StackAnswer(), false)
    }

    private func questionCard(_ question: StackQuestion) -> some View {
        let shown = shownAnswer(question.id)
        let answer = shown.answer
        let extras = answer.choices.filter { choice in !question.options.contains { $0.name == choice } }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(question.title).font(.body.weight(.semibold))
                Text(question.prompt).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !stackScope.isEmpty && shown.isOwn {
                    Button("Use the Defaults") {
                        edit { book in
                            book.folderStacks?[stackScope]?[question.id] = nil
                            if book.folderStacks?[stackScope]?.isEmpty == true { book.folderStacks?[stackScope] = nil }
                        }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                } else if !stackScope.isEmpty {
                    Text("Follows the defaults").font(.caption).foregroundStyle(.tertiary)
                }
            }
            FlowLayout(spacing: 6) {
                ForEach(question.options + extras.map { StackOption(name: $0, bestFor: "Your own answer") }, id: \.name) { option in
                    let isOn = answer.choices.contains(option.name)
                    let used = scan?.projects(using: option.name, for: question.id) ?? 0
                    Button { toggle(option.name, in: question.id) } label: {
                        HStack(spacing: 4) {
                            Text(option.name).font(.caption)
                            if used > 0 {
                                Text("\(used)").font(.caption2.weight(.bold)).foregroundStyle(isOn ? Color.black.opacity(0.7) : Palette.jade)
                            }
                        }
                    }
                    .buttonStyle(ChipStyle(isOn: isOn))
                    .opacity(shown.isOwn || !isOn ? 1 : 0.5)
                    .help("Best for: \(option.bestFor)\(used > 0 ? ". Used in \(used) project\(used == 1 ? "" : "s")." : "")")
                }
            }
            HStack(spacing: 8) {
                TextField("Other, or exceptions (e.g. \"Vite for internal dashboards\")", text: Binding(
                    get: { shownAnswer(question.id).answer.notes },
                    set: { value in
                        if stackScope.isEmpty {
                            edit { $0.stack[question.id, default: StackAnswer()].notes = value }
                        } else {
                            let base = shownAnswer(question.id).answer
                            edit { book in
                                var own = book.folderStacks?[stackScope]?[question.id] ?? base
                                own.notes = value
                                book.folderStacks = book.folderStacks ?? [:]
                                book.folderStacks![stackScope, default: [:]][question.id] = own
                            }
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
        .modifier(RowCard())
    }

    // MARK: - How you work

    private var habitsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(PlaybookQuestions.habits) { prompt in
                VStack(alignment: .leading, spacing: 6) {
                    Text(prompt.title).font(.body.weight(.semibold))
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: Binding(
                            get: { playbook.habits[prompt.id] ?? "" },
                            set: { value in edit { $0.habits[prompt.id] = value } }
                        ))
                        .font(.callout)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 48, maxHeight: 90)
                        .padding(6)
                        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                        if (playbook.habits[prompt.id] ?? "").isEmpty {
                            Text(prompt.example)
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .modifier(RowCard())
            }
        }
    }

    // MARK: - Storage

    private var storageTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            graphCard
            Text("Backup").font(.headline).padding(.top, 6)
            choice(isOn: storage == "local", title: "Only on this Mac", detail: "PLAYBOOK.md and playbook.json stay next to the guide in \(AgentGuide.abbreviate(model.playbookDirectory.path)).") {
                storage = "local"
            }
            choice(isOn: storage == "github", title: "Also back up to a private GitHub repo", detail: "Graphitree pushes a copy of the two playbook files to a private repo of yours. The graph itself never leaves this Mac.") {
                storage = "github"
            }
            if storage == "github" { githubCard }
            HStack {
                Button("Show Files in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([model.playbookDirectory.appendingPathComponent(PlaybookFile.markdownName)])
                }
                .buttonStyle(SoftButtonStyle())
                .disabled(!FileManager.default.fileExists(atPath: model.playbookDirectory.appendingPathComponent(PlaybookFile.markdownName).path))
                Spacer()
            }
        }
    }

    /// The copy under the graph's root, which graphify's docs pass turns into nodes.
    private var graphCard: some View {
        let copy = PlaybookFile.graphCopyURL(root: model.graphRoot)
        return VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { addsToGraph }, set: { adds in
                model.setPlaybookAddsToGraph(adds)
                addsToGraph = adds
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add it to the knowledge graph")
                    Text("Graphitree keeps a copy in \(AgentGuide.abbreviate(copy.deletingLastPathComponent().path)), where graphify reads it. The next rebuild that reads docs adds it, so graph questions that name a library or part of your stack return your entry next to your code. The guide lists your picks by job either way.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if addsToGraph && FileManager.default.fileExists(atPath: copy.path) {
                HStack {
                    Label(model.playbookIsNewerThanGraph ? "Changed since the last build. Rebuild with docs to update the graph." : "The copy is up to date.", systemImage: model.playbookIsNewerThanGraph ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(model.playbookIsNewerThanGraph ? Palette.gold : Palette.jade)
                    Spacer()
                    Button("Show Copy") { NSWorkspace.shared.activateFileViewerSelecting([copy]) }
                        .buttonStyle(SoftButtonStyle())
                }
                .padding(.leading, 20)
            }
        }
        .modifier(RowCard())
    }

    private var githubCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !hasCheckedAccounts {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Checking which GitHub accounts gh is signed in to…").font(.callout).foregroundStyle(.secondary)
                }
            } else if accounts.isEmpty {
                Text("Graphitree uses the GitHub command, gh. Sign in with `gh auth login` in Terminal, then come back.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Check Again") { Task { await loadAccounts() } }.buttonStyle(SoftButtonStyle())
            } else {
                HStack(spacing: 10) {
                    Text("Account").font(.callout).frame(width: 80, alignment: .leading)
                    Picker("Account", selection: $account) {
                        ForEach(accounts, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(!remote.isEmpty)
                }
                if remote.isEmpty {
                    HStack(spacing: 10) {
                        Text("Repo name").font(.callout).frame(width: 80, alignment: .leading)
                        TextField("graphitree-playbook", text: $repoName).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                    }
                    if isConfirmingCreate {
                        Text("Creates github.com/\(account)/\(repoName) as a private repo, then pushes PLAYBOOK.md and playbook.json. If the repo already exists, Graphitree pushes to it instead.")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Spacer()
                            Button("Cancel") { isConfirmingCreate = false }.buttonStyle(SoftButtonStyle())
                            Button("Create and Back Up") { Task { await backUp(create: true) } }.buttonStyle(GoldButtonStyle())
                        }
                    } else {
                        HStack {
                            Spacer()
                            Button("Create Private Repo…") { isConfirmingCreate = true }
                                .buttonStyle(GoldButtonStyle())
                                .disabled(account.isEmpty || repoName.trimmingCharacters(in: .whitespaces).isEmpty || playbook.isEmpty)
                                .help(playbook.isEmpty ? "Add something to the playbook first" : "")
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill").foregroundStyle(Palette.jade)
                        Text(remote.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: ".git", with: "")).font(.callout.monospaced())
                        Spacer()
                        if isBackingUp {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Back Up Now") { Task { await backUp(create: false) } }.buttonStyle(GoldButtonStyle())
                        }
                        if let url = URL(string: remote.replacingOccurrences(of: ".git", with: "")) {
                            Link("Open", destination: url).font(.callout)
                        }
                    }
                    Text("\(backupDetail). Graphitree also backs up when you close this panel after a change.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Stop Using This Repo") { remote = ""; isConfirmingCreate = false }
                        .buttonStyle(.link)
                        .help("Forgets the repo here. It stays on GitHub.")
                }
            }
        }
        .modifier(RowCard())
        .task { if !hasCheckedAccounts { await loadAccounts() } }
        .onChange(of: accounts) { if account.isEmpty || !accounts.contains(account) { account = accounts.first ?? "" } }
    }

    private func choice(isOn: Bool, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle").foregroundStyle(isOn ? Palette.gold : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium))
                    Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(isOn ? Palette.gold.opacity(0.08) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(isOn ? Palette.gold.opacity(0.35) : Color.white.opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Changes

    private func load() async {
        playbook = model.loadPlaybook()
        // Folders that can have their own stack: the labelled ones in the graph, or the groups.
        let source = GraphSource(outDirectory: model.outDirectory)
        if source.scheme.singleRepoName == nil {
            stackFolders = model.folderMap()?.folders.filter { $0.isIncluded && !$0.purpose.isDocs }.map(\.path).sorted() ?? source.scheme.groups.sorted()
        }
        addsToGraph = model.playbookAddsToGraph
        isLoaded = true
        if let raw = UserDefaults.standard.string(forKey: "playbookTab"), let start = PlaybookTab(rawValue: raw) { tab = start }
        await runScan()
    }

    private func loadAccounts() async {
        accounts = await model.githubAccounts()
        hasCheckedAccounts = true
    }

    private func runScan() async {
        isScanning = true
        scan = await model.scanStack()
        isScanning = false
    }

    /// Saves shortly after the last change, so typing doesn't write the file on every key.
    private func edit(_ change: (inout Playbook) -> Void) {
        change(&playbook)
        isDirty = true
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func save() {
        if let error = model.savePlaybook(playbook) { message = "Couldn't save the playbook: \(error)" }
    }

    private func update(_ id: UUID, _ change: (inout PlaybookLibrary) -> Void) {
        edit { book in
            if let index = book.libraries.firstIndex(where: { $0.id == id }) { change(&book.libraries[index]) }
        }
    }

    private func addPasted() {
        let new = PlaybookImport.libraries(from: addText)
        let before = playbook.libraries.count
        edit { $0.libraries = PlaybookImport.merging(new, into: $0.libraries) }
        let added = playbook.libraries.count - before
        message = added == 0 ? "Those are already in the playbook." : "Added \(added) librar\(added == 1 ? "y" : "ies"). Draft their details with Claude, or edit them yourself."
        addText = ""
    }

    private func addKnown(_ library: PlaybookLibrary) {
        edit { $0.libraries = PlaybookImport.merging([library], into: $0.libraries) }
    }

    private func remove(_ id: UUID) {
        pendingRemoval = nil
        edit { $0.libraries.removeAll { $0.id == id } }
    }

    private func draft(_ libraries: [PlaybookLibrary]) async {
        guard !libraries.isEmpty else { return }
        drafting = Set(libraries.map(\.id))
        message = nil
        let result = await model.draftLibraries(libraries)
        drafting = []
        switch result {
        case .success(let drafts):
            edit { book in
                for index in book.libraries.indices {
                    if let draft = drafts[book.libraries[index].id] {
                        book.libraries[index] = PlaybookResearch.applying(draft, to: book.libraries[index])
                    }
                }
            }
            let missed = libraries.count - drafts.count
            message = "Claude drafted \(drafts.count) librar\(drafts.count == 1 ? "y" : "ies")\(missed > 0 ? ", and couldn't find \(missed)" : ""). Check each one, then mark it verified."
        case .failure(let error):
            message = "Claude couldn't draft them: \(error.message)"
        }
    }

    private func toggle(_ option: String, in question: String) {
        // In a folder, the first change starts from the defaults it was following.
        let scope = stackScope
        let base = shownAnswer(question).answer
        edit { book in
            var answer = scope.isEmpty ? (book.stack[question] ?? StackAnswer()) : (book.folderStacks?[scope]?[question] ?? base)
            if let index = answer.choices.firstIndex(of: option) { answer.choices.remove(at: index) } else { answer.choices.append(option) }
            if scope.isEmpty {
                book.stack[question] = answer
            } else {
                book.folderStacks = book.folderStacks ?? [:]
                book.folderStacks![scope, default: [:]][question] = answer
            }
        }
    }

    /// For each unanswered question, picks what's used by at least half as many projects as the top choice.
    private func fillFromScan() {
        guard let scan else { return }
        var filled = 0
        edit { book in
            for question in PlaybookQuestions.stack where book.stack[question.id]?.choices.isEmpty ?? true {
                let counts = question.options.map { ($0.name, scan.projects(using: $0.name, for: question.id)) }.filter { $0.1 > 0 }
                guard let top = counts.map(\.1).max() else { continue }
                let picks = counts.filter { Double($0.1) >= Double(top) / 2 }.map(\.0)
                book.stack[question.id, default: StackAnswer()].choices = picks
                filled += 1
            }
        }
        message = filled == 0 ? "Every question with scan results already has an answer." : "Filled \(filled) question\(filled == 1 ? "" : "s") from what your projects use. Change anything that isn't your default for new work."
    }

    private func backUp(create: Bool) async {
        saveTask?.cancel()
        save()
        isBackingUp = true
        isConfirmingCreate = false
        let result = await model.backUpPlaybook(remote: create ? nil : remote, createNamed: create ? repoName.trimmingCharacters(in: .whitespaces) : nil, account: account)
        isBackingUp = false
        switch result {
        case .success(let url):
            remote = url
            lastBackup = Date.now.timeIntervalSince1970
            isDirty = false
            message = "Backed up to \(url.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: ".git", with: ""))."
        case .failure(let error):
            message = "Backup failed: \(error.message)"
        }
    }

    /// Saves what's pending and, when backing up to GitHub, pushes the change.
    private func finishEditing() {
        guard isLoaded else { return }
        if saveTask != nil {
            saveTask?.cancel()
            save()
        }
        if isDirty, storage == "github", !remote.isEmpty, !account.isEmpty {
            let model = model
            let remote = remote
            let account = account
            Task {
                if case .success = await model.backUpPlaybook(remote: remote, createNamed: nil, account: account) {
                    UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "playbookLastBackup")
                }
            }
        }
    }
}

private enum PlaybookTab: String, CaseIterable, Identifiable {
    case chat, libraries, stack, habits, storage

    var id: String { rawValue }
    var title: String {
        switch self {
        case .chat: return "Chat"
        case .libraries: return "Libraries"
        case .stack: return "Stack"
        case .habits: return "How You Work"
        case .storage: return "Storage"
        }
    }
    var intro: String {
        switch self {
        case .chat: return "Ask about libraries, your stack or how you work."
        case .libraries: return "Libraries you trust, by the job they do. AI tools use these instead of writing their own toast, drawer or command menu."
        case .stack: return "What new work should start from. Pick your defaults; existing projects keep what they use."
        case .habits: return "How you like to work, written once so every AI tool knows it. Like memory, but yours to edit. The Chat tab can also learn it from your recent sessions."
        case .storage: return "The playbook lives next to the guide, and a copy goes into the knowledge graph. Keep it on this Mac, or back it up to a private repo."
        }
    }
}

/// A rounded chip that's gold when chosen.
struct ChipStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(isOn ? Color.black : .primary)
            .background(isOn ? Palette.gold : Color.white.opacity(configuration.isPressed ? 0.14 : 0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Color.clear : Color.white.opacity(0.08)))
            .contentShape(Capsule())
    }
}

/// Lays children out in rows, wrapping when a row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

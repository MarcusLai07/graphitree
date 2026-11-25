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
    /// The graph folder the playbook came from. Saves go back there, even when the panel closes
    /// because the person switched to another graph.
    @State private var loadedFrom: URL?
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
    @AppStorage("playbookLibraryView") private var libraryLayout: LibraryLayout = .map
    @State private var search = ""
    @State private var statusFilter: LibraryFilter = .all
    /// One category's libraries only; nil shows them all.
    @State private var categoryFilter: String?
    /// The library open in the list, as its full card.
    @State private var expanded: UUID?
    @State private var hoveredRow: UUID?
    /// A library to bring into view, such as one picked on the map.
    @State private var scrollTarget: UUID?
    @State private var isAdding = false
    @State private var isShowingCheck = false
    /// The category whose rules are showing in a popover, "" for everywhere.
    @State private var shownRules: String?
    /// Drafts being reviewed one at a time, in order. Empty when not reviewing.
    @State private var reviewQueue: [UUID] = []
    @State private var reviewIndex = 0
    @State private var reviewVerified = 0

    // Stack
    @State private var scan: StackScanResult?
    @State private var isScanning = false

    // Storage: this graph's own backup, since each graph has its own playbook.
    @State private var backup = PlaybookBackupSettings()
    @State private var accounts: [String] = []
    @State private var hasCheckedAccounts = false
    @State private var isConfirmingCreate = false
    @State private var isConfirmingRestore = false
    @State private var isBackingUp = false
    /// The repo's playbook, when a backup stopped because the repo has changes this Mac hasn't seen.
    @State private var conflict: (remote: String, theirs: Playbook)?
    @State private var addsToGraph = true
    /// Which folder's stack the Stack tab edits. Empty means everywhere.
    @State private var stackScope = ""
    @State private var stackFolders: [String] = []
    /// Repos that can get a starter, for the tab's title.
    @State private var starterOffers = 0
    /// Goes up with each save, so the Starters tab previews what's saved.
    @State private var playbookRevision = 0

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Playbook", subtitle: "What AI tools should reach for when they build")
            Rectangle().fill(Palette.hairline).frame(height: 1)
            VStack(alignment: .leading, spacing: 12) {
                summaryStrip
                Picker("Section", selection: $tab) {
                    ForEach(PlaybookTab.allCases) { tab in
                        Text(tab == .starters && starterOffers > 0 ? "\(tab.title) (\(starterOffers))" : tab.title).tag(tab)
                    }
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
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(tab.intro).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            switch tab {
                            case .chat: EmptyView()
                            case .libraries: librariesTab
                            case .rules: rulesTab
                            case .skills: PlaybookSkillsTab(playbook: playbook, edit: edit)
                            case .starters: PlaybookStartersTab(playbookRevision: playbookRevision) { starterOffers = $0 }
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
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        // After the list has drawn the row.
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(80))
                            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(target, anchor: .top) }
                            scrollTarget = nil
                        }
                    }
                }
            }
        }
        .task { await load() }
        .onDisappear { finishEditing() }
        .onChange(of: backup) {
            if isLoaded, let loadedFrom { PlaybookBackupStore.save(backup, for: loadedFrom) }
        }
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
            tile("Rules", symbol: "list.bullet.rectangle.fill", value: "\(playbook.rules.count)", detail: playbook.rules.isEmpty ? "None yet" : "\(playbook.rules(for: "").count) everywhere") { tab = .rules }
            tile("Stack", symbol: "square.stack.3d.up.fill", value: "\(answered)/\(PlaybookQuestions.stack.count)", detail: "answered") { tab = .stack }
            tile("How you work", symbol: "person.text.rectangle.fill", value: "\(habits)/\(PlaybookQuestions.habits.count)", detail: "filled in") { tab = .habits }
            tile("Stored", symbol: backup.github ? "lock.icloud.fill" : "internaldrive.fill", value: backup.github ? "GitHub" : "This Mac", detail: backupDetail) { tab = .storage }
        }
    }

    private var backupDetail: String {
        guard backup.github else { return "Only here" }
        if backup.problem != nil, !backup.remote.isEmpty { return "Backup needs a look" }
        guard let last = backup.lastBackup else { return "Not backed up yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Backed up \(formatter.localizedString(for: last, relativeTo: .now))"
    }

    /// The repo name to create, the graph's default until the person types one.
    private var repoName: Binding<String> {
        Binding(
            get: {
                guard backup.repoName.isEmpty else { return backup.repoName }
                return PlaybookBackup.defaultRepoName(singleRepo: GraphSource(outDirectory: loadedFrom ?? model.outDirectory).scheme.singleRepoName)
            },
            set: { backup.repoName = $0 }
        )
    }

    private static func place(_ remote: String) -> String {
        remote.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: ".git", with: "")
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
            if playbook.libraries.isEmpty {
                addPanel.modifier(RowCard())
                Text("No libraries yet. Paste your list above, or add ones your projects already use.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if !reviewQueue.isEmpty {
                reviewPanel
            } else {
                librariesToolbar
                if !undescribed.isEmpty || !drafting.isEmpty { draftBanner }
                filterBar
                switch libraryLayout {
                case .map: libraryMap
                case .list: libraryList
                }
            }
        }
    }

    // MARK: Toolbar and filters

    private var librariesToolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search names, jobs and notes", text: $search).textFieldStyle(.plain)
                if !search.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") { search = "" }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Picker("Show as", selection: $libraryLayout) {
                ForEach(LibraryLayout.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help("Map shows the whole stack at a glance. List has every detail.")
            Button("Add…", systemImage: "plus") { isAdding = true }
                .buttonStyle(SoftButtonStyle())
                .popover(isPresented: $isAdding, arrowEdge: .bottom) {
                    addPanel.padding(14).frame(width: 440)
                }
            Button("Check…", systemImage: "stethoscope") { isShowingCheck = true }
                .buttonStyle(SoftButtonStyle())
                .popover(isPresented: $isShowingCheck, arrowEdge: .bottom) {
                    healthCheckContent.padding(14).frame(width: 420)
                }
            if !LabCatalog.bundled.entries.isEmpty {
                Button("Lab", systemImage: "flask") { openLab("compose") }
                    .buttonStyle(SoftButtonStyle())
                    .help("Open the Playbook lab: compose a screen and pick which library draws each part, before you verify them.")
            }
        }
    }

    /// Adding libraries by hand, and the ones the scan found in your projects.
    private var addPanel: some View {
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
                Button("Add") {
                    addPasted()
                    isAdding = false
                }
                .buttonStyle(GoldButtonStyle())
                .disabled(addText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !suggestions.isEmpty {
                Text("Already in your projects").font(.body.weight(.medium)).padding(.top, 6)
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
        }
    }

    private var draftBanner: some View {
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

    /// Status chips, then category chips, then the rules for everywhere and the way into reviewing drafts.
    private var filterBar: some View {
        let all = playbook.libraries
        let drafts = all.filter { !$0.verified && $0.isDescribed }.count
        let statuses = LibraryStatus.allCases.filter { status in all.contains { LibraryFilter.status(status).matches($0) } }
        return VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6) {
                filterChip("All", count: all.count, .all)
                ForEach(statuses) { status in
                    filterChip(status.title, count: all.filter { LibraryFilter.status(status).matches($0) }.count, .status(status))
                }
                filterChip("Drafts", count: all.filter { !$0.verified }.count, .drafts)
            }
            FlowLayout(spacing: 6) {
                ForEach(playbook.outline, id: \.category) { group in
                    let count = group.tasks.reduce(0) { $0 + $1.entries.count }
                    let name = group.category.isEmpty ? "Not filed" : group.category
                    Button("\(name) \(count)") { categoryFilter = categoryFilter == group.category ? nil : group.category }
                        .font(.caption)
                        .buttonStyle(ChipStyle(isOn: categoryFilter == group.category))
                }
            }
            HStack(spacing: 10) {
                rulesButton(for: "", label: "for everywhere")
                Spacer(minLength: 8)
                if drafts > 0 {
                    Text("\(drafts) draft\(drafts == 1 ? "" : "s") to check").font(.caption).foregroundStyle(.secondary)
                    Button("Review Drafts") { startReview() }
                        .buttonStyle(SoftButtonStyle())
                        .help("Step through Claude's drafts one at a time and verify each one")
                }
            }
        }
    }

    private func filterChip(_ title: String, count: Int, _ filter: LibraryFilter) -> some View {
        Button("\(title) \(count)") { statusFilter = statusFilter == filter && filter != .all ? .all : filter }
            .font(.caption)
            .buttonStyle(ChipStyle(isOn: statusFilter == filter))
    }

    /// "3 rules" for a category ("" for everywhere), opening them in a popover. Nothing when there are none.
    @ViewBuilder
    private func rulesButton(for category: String, label: String = "") -> some View {
        let rules = playbook.rules(for: category)
        if !rules.isEmpty {
            Button {
                shownRules = category
            } label: {
                Label("\(rules.count) rule\(rules.count == 1 ? "" : "s")\(label.isEmpty ? "" : " " + label)", systemImage: "list.bullet.rectangle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: Binding(get: { shownRules == category }, set: { if !$0 { shownRules = nil } }), arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.isEmpty ? "Rules for everywhere" : "Rules for \(category)").font(.body.weight(.medium))
                    ForEach(rules) { rule in
                        Label(rule.text, systemImage: "list.bullet")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack {
                        Spacer()
                        Button("Edit in Rules") {
                            shownRules = nil
                            tab = .rules
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
                .padding(14)
                .frame(width: 380)
            }
        }
    }

    // MARK: What the filters leave

    /// The outline with the search, status and category applied. A pair whose library is hidden
    /// stands on its own.
    private var visibleOutline: [OutlineGroup] {
        let words = search.lowercased().split(separator: " ").map(String.init)
        func passes(_ library: PlaybookLibrary) -> Bool {
            guard statusFilter.matches(library) else { return false }
            guard !words.isEmpty else { return true }
            let text = [library.name, library.task, library.category, library.purpose, library.useWhen, library.avoidWhen,
                        library.useInstead, library.notes, library.pairsWith, library.install].joined(separator: " ").lowercased()
            return words.allSatisfy { text.contains($0) }
        }
        return playbook.outline.compactMap { group in
            if let categoryFilter, categoryFilter != group.category { return nil }
            let jobs = group.tasks.compactMap { job -> OutlineJob? in
                var entries: [OutlineEntry] = []
                var root: (id: UUID, shown: Bool)?
                for (library, depth) in job.entries {
                    if depth == 0 { root = (library.id, passes(library)) }
                    guard passes(library) else { continue }
                    let underRoot = depth > 0 && root?.shown == true
                    entries.append(OutlineEntry(library: library, depth: underRoot ? depth : 0, root: underRoot ? root!.id : library.id))
                }
                return entries.isEmpty ? nil : OutlineJob(task: job.task, entries: entries)
            }
            return jobs.isEmpty ? nil : OutlineGroup(category: group.category, jobs: jobs)
        }
    }

    @ViewBuilder
    private var nothingMatches: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No libraries match.").font(.callout).foregroundStyle(.secondary)
            Button("Show All") {
                search = ""
                statusFilter = .all
                categoryFilter = nil
            }
            .buttonStyle(SoftButtonStyle())
        }
        .padding(.top, 6)
    }

    // MARK: Map

    /// The whole stack at a glance: a card per category, a line per job with its pick, the
    /// libraries that pair with it after a +, and what to avoid struck through at the bottom.
    private var libraryMap: some View {
        let groups = visibleOutline
        return Group {
            if groups.isEmpty {
                nothingMatches
            } else {
                // Two columns, each card going to the shorter one, so a long card leaves no gap beside it.
                let columns = groups.reduce(into: (left: [OutlineGroup](), right: [OutlineGroup](), leftLines: 0, rightLines: 0)) { result, group in
                    let lines = group.jobs.count + group.jobs.flatMap(\.entries).filter(\.library.isAvoided).count + 2
                    if result.leftLines <= result.rightLines {
                        result.left.append(group)
                        result.leftLines += lines
                    } else {
                        result.right.append(group)
                        result.rightLines += lines
                    }
                }
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 10) { ForEach(columns.left) { mapCard($0) } }.frame(maxWidth: .infinity, alignment: .top)
                    VStack(spacing: 10) { ForEach(columns.right) { mapCard($0) } }.frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
    }

    private func mapCard(_ group: OutlineGroup) -> some View {
        let avoided = group.jobs.flatMap(\.entries).map(\.library).filter(\.isAvoided)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button(group.category.isEmpty ? "Not filed yet" : group.category) {
                    categoryFilter = group.category
                    libraryLayout = .list
                }
                .buttonStyle(.plain)
                .font(.body.weight(.semibold))
                .help("Show \(group.category.isEmpty ? "these" : group.category) as a list")
                Text("\(group.jobs.reduce(0) { $0 + $1.entries.count })").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 6)
                rulesButton(for: group.category)
            }
            ForEach(group.jobs) { job in
                let lines = mapLines(job.entries.filter { !$0.library.isAvoided })
                if !lines.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(job.task.isEmpty ? "Other" : job.task)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 104, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(lines, id: \.lead.id) { line in
                                FlowLayout(spacing: 4) {
                                    mapName(line.lead)
                                    if let status = line.lead.status, status != .default {
                                        Text(status.title.lowercased()).font(.caption2.weight(.semibold)).foregroundStyle(statusColor(status))
                                    }
                                    ForEach(line.pairs) { pair in
                                        Text("+").font(.caption).foregroundStyle(.secondary)
                                        mapName(pair, leads: false)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if !avoided.isEmpty {
                Rectangle().fill(Palette.hairline).frame(height: 1).padding(.vertical, 2)
                ForEach(avoided) { library in
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Button { open(library) } label: { Text(library.name).strikethrough() }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(Palette.coral)
                        if !library.useInstead.isEmpty {
                            Text("→ \(library.useInstead)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .help(library.avoidWhen.isEmpty ? LibraryStatus.avoid.meaning : library.avoidWhen)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(RowCard())
    }

    /// A job's libraries as lines: each one that leads, with its pairs after it.
    private func mapLines(_ entries: [OutlineEntry]) -> [(lead: PlaybookLibrary, pairs: [PlaybookLibrary])] {
        var lines: [(lead: PlaybookLibrary, pairs: [PlaybookLibrary])] = []
        for entry in entries {
            if entry.depth > 0, let last = lines.indices.last, lines[last].lead.id == entry.root {
                lines[last].pairs.append(entry.library)
            } else {
                lines.append((entry.library, []))
            }
        }
        return lines
    }

    /// A library's name on the map, bold when it's the pick. One that pairs with another stays light.
    private func mapName(_ library: PlaybookLibrary, leads: Bool = true) -> some View {
        let isPick = leads && library.status == .default
        return Button { open(library) } label: {
            HStack(spacing: 3) {
                Text(library.name)
                if library.verified { Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(Palette.jade) }
            }
        }
        .buttonStyle(.plain)
        .font(.callout.weight(isPick ? .semibold : .regular))
        .foregroundStyle(isPick ? .primary : .secondary)
        .help(library.useWhen.isEmpty ? library.purpose : library.useWhen)
    }

    /// Shows one library's details in the list.
    private func open(_ library: PlaybookLibrary) {
        libraryLayout = .list
        expanded = library.id
        scrollTarget = library.id
    }

    // MARK: List

    /// One short row per library, under its category. A row opens into the full card.
    private var libraryList: some View {
        let groups = visibleOutline
        return VStack(alignment: .leading, spacing: 6) {
            if groups.isEmpty { nothingMatches }
            ForEach(groups) { group in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(group.category.isEmpty ? "Not filed yet" : group.category)
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.gold.opacity(0.85))
                    Text("\(group.jobs.reduce(0) { $0 + $1.entries.count })").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    rulesButton(for: group.category)
                }
                .padding(.top, 8)
                VStack(alignment: .leading, spacing: 0) {
                    let entries = group.jobs.flatMap(\.entries)
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Rectangle().fill(Palette.hairline).frame(height: 1) }
                        Group {
                            if expanded == entry.id {
                                libraryCard(entry.library, collapsible: true)
                                    .padding(6)
                            } else {
                                libraryRow(entry)
                            }
                        }
                        .padding(.leading, CGFloat(entry.depth) * 18)
                        .id(entry.id)
                    }
                }
                .cardSurface()
            }
        }
    }

    private func libraryRow(_ entry: OutlineEntry) -> some View {
        let library = entry.library
        let summary: String = {
            if library.isAvoided || library.status == .legacy, !library.useInstead.isEmpty { return "Use \(library.useInstead) instead" }
            let when = library.useWhen.isEmpty ? library.purpose : library.useWhen
            return when.components(separatedBy: ". ").first ?? when
        }()
        return Button {
            expanded = library.id
            editing = nil
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(spacing: 4) {
                    if entry.depth > 0 { Text("↳").foregroundStyle(.tertiary) }
                    Text(library.name).fontWeight(.semibold).lineLimit(1)
                    if library.verified { Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(Palette.jade) }
                }
                .frame(width: max(120, 190 - CGFloat(entry.depth) * 18), alignment: .leading)
                statusLabel(library).frame(width: 66, alignment: .leading)
                Text(library.task.isEmpty ? "—" : library.task)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 128, alignment: .leading)
                Text(summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.tertiary)
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(hoveredRow == library.id ? Color.white.opacity(0.04) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hoveredRow = $0 ? library.id : (hoveredRow == library.id ? nil : hoveredRow) }
        .help(library.purpose)
    }

    @ViewBuilder
    private func statusLabel(_ library: PlaybookLibrary) -> some View {
        if library.isAvoided {
            Text("Avoid").font(.caption.weight(.semibold)).foregroundStyle(Palette.coral)
        } else if let status = library.status {
            Text(status.title).font(.caption.weight(.semibold)).foregroundStyle(statusColor(status))
        } else {
            Text("Not set").font(.caption).foregroundStyle(.tertiary)
        }
    }

    // MARK: Reviewing drafts

    /// Claude's drafts in reading order, skipping ones with nothing to check yet.
    private func startReview() {
        let order = playbook.outline.flatMap(\.tasks).flatMap(\.entries).map(\.library)
        reviewQueue = order.filter { !$0.verified && $0.isDescribed }.map(\.id)
        reviewIndex = 0
        reviewVerified = 0
        editing = nil
        message = nil
    }

    private func nextDraft() {
        editing = nil
        if reviewIndex + 1 < reviewQueue.count {
            reviewIndex += 1
        } else {
            endReview()
        }
    }

    private func endReview() {
        if !reviewQueue.isEmpty {
            message = "Verified \(reviewVerified) of \(reviewQueue.count) draft\(reviewQueue.count == 1 ? "" : "s")."
        }
        reviewQueue = []
        reviewIndex = 0
        editing = nil
    }

    private var reviewPanel: some View {
        let id = reviewQueue.indices.contains(reviewIndex) ? reviewQueue[reviewIndex] : nil
        let current = id.flatMap { id in playbook.libraries.first { $0.id == id } }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "checkmark.seal").foregroundStyle(Palette.gold)
                Text("Reviewing drafts").font(.body.weight(.medium))
                Text("\(reviewIndex + 1) of \(reviewQueue.count)").font(.callout).foregroundStyle(.secondary).monospacedDigit()
                Spacer(minLength: 8)
                Button("Stop") { endReview() }
                    .buttonStyle(SoftButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
            ProgressView(value: Double(reviewIndex), total: Double(max(reviewQueue.count, 1)))
                .tint(Palette.gold)
            Text("Check its link, install command and health against the library's own docs, and edit what's wrong. ⌘↩ verifies and moves on, ⌘→ skips.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let current {
                let filed = [current.category, current.task].filter { !$0.isEmpty }.joined(separator: " › ")
                if !filed.isEmpty { Text(filed).font(.caption).foregroundStyle(.secondary) }
                libraryCard(current, showsVerify: false)
                HStack {
                    Button("Back") {
                        editing = nil
                        reviewIndex -= 1
                    }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(reviewIndex == 0)
                    Spacer()
                    Button("Skip") { nextDraft() }
                        .buttonStyle(SoftButtonStyle())
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                    Button(current.verified ? "Verified, Next" : "Verify and Next") {
                        if !current.verified {
                            update(current.id) { $0.verified = true }
                            reviewVerified += 1
                        }
                        nextDraft()
                    }
                    .buttonStyle(GoldButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
                }
            } else {
                Text("This draft was removed.").font(.callout).foregroundStyle(.secondary)
                Button("Next") { nextDraft() }.buttonStyle(SoftButtonStyle())
            }
        }
        .modifier(RowCard())
    }

    // MARK: - Rules

    /// Rules that aren't about one library, grouped by where they apply.
    private var rulesTab: some View {
        let categories = [""] + PlaybookCategories.sorted(playbook.rules.map { PlaybookCategories.canonical($0.category) }).filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(playbook.rules.isEmpty ? "No rules yet." : "\(playbook.rules.count) rule\(playbook.rules.count == 1 ? "" : "s")")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu("Add Rule") {
                    Button("For Everywhere") { addRule(in: "") }
                    Divider()
                    ForEach(PlaybookCategories.names, id: \.self) { name in
                        Button("For \(name)") { addRule(in: name) }
                    }
                }
                .menuStyle(.button)
                .fixedSize()
            }
            ForEach(categories, id: \.self) { category in
                let rules = playbook.rules.filter { PlaybookCategories.canonical($0.category) == category }
                if !rules.isEmpty || category.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(category.isEmpty ? "Everywhere" : category)
                                .font(.caption.weight(.semibold))
                                .tracking(0.8)
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.gold.opacity(0.85))
                            if !category.isEmpty {
                                Text(PlaybookCategories.all.first { $0.name == category }?.covers ?? "").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if rules.isEmpty {
                            Text("Rules here apply to all work, such as \"One library per job\".").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(rules) { ruleRow($0) }
                    }
                    .modifier(RowCard())
                }
            }
        }
    }

    private func addRule(in category: String) {
        edit { $0.rules.append(PlaybookRule(text: "", category: category)) }
    }

    private func ruleRow(_ rule: PlaybookRule) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            TextField("A rule AI tools should follow", text: Binding(
                get: { playbook.rules.first { $0.id == rule.id }?.text ?? "" },
                set: { value in updateRule(rule.id) { $0.text = value } }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...6)
            Picker("Category", selection: Binding(
                get: { PlaybookCategories.canonical(playbook.rules.first { $0.id == rule.id }?.category ?? "") },
                set: { value in updateRule(rule.id) { $0.category = value } }
            )) {
                Text("Everywhere").tag("")
                ForEach(categoryChoices(including: rule.category), id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 196)
            .help("Move it to another category")
            Button("Remove", systemImage: "trash") { edit { $0.rules.removeAll { $0.id == rule.id } } }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove this rule")
        }
    }

    /// The known categories, plus one of the owner's own when it's in use.
    private func categoryChoices(including current: String) -> [String] {
        let own = PlaybookCategories.canonical(current)
        return PlaybookCategories.names + (own.isEmpty || PlaybookCategories.names.contains(own) ? [] : [own])
    }

    /// Other libraries this one can pair with, plus what it names now if that isn't one of them.
    private func pairingChoices(for id: UUID) -> [String] {
        let names = playbook.libraries.filter { $0.id != id && !$0.isAvoided }.map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let current = playbook.libraries.first { $0.id == id }?.pairsWith ?? ""
        return names + (current.isEmpty || names.contains(current) ? [] : [current])
    }

    private var undescribed: [PlaybookLibrary] { playbook.libraries.filter { !$0.isDescribed && !$0.verified } }

    private var suggestions: [(name: String, projects: Int, library: PlaybookLibrary)] {
        guard let scan else { return [] }
        var seen: Set<String> = []
        return StackScan.knownLibraries.compactMap { known in
            guard let projects = scan.libraries[known.name], !PlaybookImport.contains(known, in: playbook.libraries), seen.insert(known.name).inserted else { return nil }
            return (known.name, projects.count, PlaybookLibrary(name: known.name, url: known.url, task: known.task, category: PlaybookCategories.guess(task: known.task)))
        }
        .sorted { $0.projects > $1.projects }
    }

    /// Re-researching every library, now or once a month. Changes land in the chat to apply.
    private var healthCheckContent: some View {
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
                        isShowingCheck = false
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
    }

    private func openLab(_ route: String) {
        lab?.show(route)
        openWindow(id: "lab")
    }

    /// A library's full details and actions. In the list it folds back into its row.
    private func libraryCard(_ library: PlaybookLibrary, collapsible: Bool = false, showsVerify: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if collapsible {
                    Button("Fold", systemImage: "chevron.up") {
                        expanded = nil
                        editing = nil
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Fold back into its row")
                }
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
                    if showsVerify {
                        Button(library.verified ? "Unverify" : "Verify") { update(library.id) { $0.verified.toggle() } }
                            .buttonStyle(SoftButtonStyle())
                            .disabled(!library.isDescribed)
                            .help(library.verified ? "Mark it as a draft again" : "You've checked these details. AI tools can rely on them.")
                    }
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
                if !library.useInstead.isEmpty { fact("Use instead", library.useInstead) }
                if let partner = playbook.partner(of: library) {
                    fact("Pairs with", partner.name)
                } else if !library.pairsWith.isEmpty {
                    fact("Pairs with", "\(library.pairsWith), which isn't in the playbook")
                }
                let pairs = playbook.companions(of: library)
                if !pairs.isEmpty { fact("Pairs with it", pairs.map(\.name).joined(separator: ", ")) }
                if !library.install.isEmpty {
                    HStack(spacing: 6) {
                        Text(library.install).font(.caption.monospaced()).textSelection(.enabled)
                        if !library.platforms.isEmpty { Text("· \(library.platforms)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if !library.health.isEmpty {
                    let note = library.health.trimmingCharacters(in: .whitespacesAndNewlines)
                    let stop = note.last.map { ".!?".contains($0) } ?? true ? "" : "."
                    let checked = library.checkedOn.map { "\(stop) Checked \($0.formatted(date: .abbreviated, time: .omitted))." } ?? ""
                    Label(note + checked, systemImage: library.looksAbandoned ? "exclamationmark.triangle.fill" : "heart.text.square")
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
        if library.isAvoided {
            Text("Avoid for new work").font(.caption2.weight(.semibold)).foregroundStyle(Palette.coral)
                .help(library.status == .avoid ? LibraryStatus.avoid.meaning : "Its health note says it's no longer maintained")
        } else if let status = library.status {
            Text(status.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(statusColor(status))
                .help(status.meaning)
        }
        if library.verified {
            Label("Verified", systemImage: "checkmark.seal.fill").font(.caption2.weight(.semibold)).foregroundStyle(Palette.jade)
        } else if library.drafted {
            Label("Claude's draft", systemImage: "sparkles").font(.caption2.weight(.semibold)).foregroundStyle(Palette.gold)
        } else if !library.isDescribed {
            Text("Not described").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func statusColor(_ status: LibraryStatus) -> Color {
        switch status {
        case .default: return Palette.jade
        case .narrow: return Palette.gold
        case .legacy: return .secondary
        case .candidate: return Palette.violet
        case .avoid: return Palette.coral
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
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Category").font(.callout).frame(width: 96, alignment: .leading)
                Picker("Category", selection: Binding(
                    get: { PlaybookCategories.canonical(playbook.libraries.first { $0.id == id }?.category ?? "") },
                    set: { value in update(id) { $0.category = value } }
                )) {
                    Text("Not filed").tag("")
                    ForEach(categoryChoices(including: playbook.libraries.first { $0.id == id }?.category ?? ""), id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(maxWidth: 260, alignment: .leading)
            }
            field("Task", \.task, id, placeholder: "Toasts, Drawers, UI components…")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Pairs with").font(.callout).frame(width: 96, alignment: .leading)
                Picker("Pairs with", selection: Binding(
                    get: { playbook.libraries.first { $0.id == id }?.pairsWith ?? "" },
                    set: { value in update(id) { $0.pairsWith = value } }
                )) {
                    Text("Nothing: it has a job of its own").tag("")
                    ForEach(pairingChoices(for: id), id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(maxWidth: 360, alignment: .leading)
                .help("A plugin, binding or helper for another library is listed under it instead of as a job of its own")
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Status").font(.callout).frame(width: 96, alignment: .leading)
                Picker("Status", selection: Binding(
                    get: { playbook.libraries.first { $0.id == id }?.status },
                    set: { value in update(id) { $0.status = value } }
                )) {
                    Text("Not set").tag(LibraryStatus?.none)
                    ForEach(LibraryStatus.allCases) { Text("\($0.title): \($0.meaning)").tag(LibraryStatus?.some($0)) }
                }
                .labelsHidden()
                .frame(maxWidth: 360, alignment: .leading)
            }
            field("What it's for", \.purpose, id)
            field("Use when", \.useWhen, id)
            field("Avoid when", \.avoidWhen, id)
            field("Use instead", \.useInstead, id, placeholder: "For legacy or avoid: what new work should pick")
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
                set: { value in
                    update(id) { library in
                        library[keyPath: keyPath] = value
                        // Writing the health note is checking it.
                        if keyPath == \PlaybookLibrary.health { library.checkedOn = .now }
                    }
                }
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
            choice(isOn: !backup.github, title: "Only on this Mac", detail: "PLAYBOOK.md and playbook.json stay next to the guide in \(AgentGuide.abbreviate(model.playbookDirectory.path)).") {
                backup.github = false
            }
            choice(isOn: backup.github, title: "Also back up to a private GitHub repo", detail: "Graphitree pushes a copy of the two playbook files to a private repo of yours. The graph itself never leaves this Mac. Each graph has its own playbook, so each backs up to its own repo.") {
                backup.github = true
            }
            if backup.github { githubCard }
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
                    Picker("Account", selection: $backup.account) {
                        ForEach(accounts, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(!backup.remote.isEmpty)
                }
                if let conflict {
                    conflictCard(conflict)
                } else if backup.remote.isEmpty {
                    let name = repoName.wrappedValue.trimmingCharacters(in: .whitespaces)
                    HStack(spacing: 10) {
                        Text("Repo name").font(.callout).frame(width: 80, alignment: .leading)
                        TextField("graphitree-playbook", text: repoName).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                    }
                    if isConfirmingCreate {
                        // An empty playbook can only be filled from a repo, such as on a new Mac.
                        Text(playbook.isEmpty
                             ? "Brings the playbook in github.com/\(backup.account)/\(name) here, such as on a new Mac or after a reinstall. To start a new repo instead, add something to the playbook first."
                             : "Creates github.com/\(backup.account)/\(name) as a private repo, then pushes PLAYBOOK.md and playbook.json. If it already holds a different playbook, from another Mac or another graph, Graphitree asks which to keep.")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Spacer()
                            Button("Cancel") { isConfirmingCreate = false }.buttonStyle(SoftButtonStyle())
                            Button(playbook.isEmpty ? "Bring It Here" : "Create and Back Up") { Task { await backUp(create: true) } }.buttonStyle(GoldButtonStyle())
                        }
                    } else {
                        HStack {
                            Spacer()
                            if isBackingUp { ProgressView().controlSize(.small) }
                            Button(playbook.isEmpty ? "Restore From a Repo…" : "Create Private Repo…") { isConfirmingCreate = true }
                                .buttonStyle(GoldButtonStyle())
                                .disabled(backup.account.isEmpty || name.isEmpty || isBackingUp)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill").foregroundStyle(Palette.jade)
                        Text(Self.place(backup.remote)).font(.callout.monospaced())
                        Spacer()
                        if isBackingUp {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Back Up Now") { Task { await backUp(create: false) } }
                                .buttonStyle(GoldButtonStyle())
                                .disabled(playbook.isEmpty)
                                .help(playbook.isEmpty ? "Add something to the playbook first" : "")
                        }
                        if let url = URL(string: backup.remote.replacingOccurrences(of: ".git", with: "")) {
                            Link("Open", destination: url).font(.callout)
                        }
                    }
                    if let problem = backup.problem {
                        Text(problem).font(.caption).foregroundStyle(Palette.gold).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("\(backupDetail). Graphitree also backs up when you close this panel after a change.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isConfirmingRestore {
                        Text("Replaces this graph's playbook with the one in \(Self.place(backup.remote)). This Mac's playbook is kept beside it as playbook.replaced-….json.")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Spacer()
                            Button("Cancel") { isConfirmingRestore = false }.buttonStyle(SoftButtonStyle())
                            Button("Restore") { Task { await restore(from: backup.remote) } }.buttonStyle(GoldButtonStyle())
                        }
                    } else {
                        HStack(spacing: 16) {
                            Button("Restore From GitHub…") { isConfirmingRestore = true }
                                .buttonStyle(.link)
                                .disabled(isBackingUp)
                                .help("Brings the repo's playbook here, such as after a change on another Mac")
                            Button("Stop Using This Repo") {
                                backup.remote = ""
                                backup.problem = nil
                                isConfirmingCreate = false
                            }
                            .buttonStyle(.link)
                            .help("Forgets the repo here. It stays on GitHub.")
                        }
                    }
                }
            }
        }
        .modifier(RowCard())
        .task { if !hasCheckedAccounts { await loadAccounts() } }
        .onChange(of: accounts) {
            // A repo already in use keeps the account that pushes to it.
            if backup.remote.isEmpty, backup.account.isEmpty || !accounts.contains(backup.account) { backup.account = accounts.first ?? "" }
        }
    }

    /// A backup stopped because the repo has a playbook this Mac hasn't seen: pick which to keep.
    private func conflictCard(_ conflict: (remote: String, theirs: Playbook)) -> some View {
        let mine = loadedFrom.map { PlaybookFile.load(from: $0) } ?? playbook
        return VStack(alignment: .leading, spacing: 8) {
            Label("\(Self.place(conflict.remote)) has a playbook this Mac hasn't seen", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.medium))
                .foregroundStyle(Palette.gold)
            Text("In the repo: \(PlaybookBackup.summary(of: conflict.theirs)). On this Mac: \(PlaybookBackup.summary(of: mine)). It may be from another Mac or another graph. Nothing was pushed.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text("Use the repo's copy to bring it here; this Mac's is kept beside it as playbook.replaced-….json. Or replace the repo's copy with this Mac's; the repo's history keeps the old one.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                if isBackingUp {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Cancel") {
                        self.conflict = nil
                        if backup.remote.isEmpty { backup.problem = nil }
                    }
                    .buttonStyle(SoftButtonStyle())
                    Button("Replace the Repo's Copy") { Task { await backUp(create: false, replacing: true, to: conflict.remote) } }
                        .buttonStyle(SoftButtonStyle())
                    Button("Use the Repo's Copy") { Task { await restore(from: conflict.remote) } }
                        .buttonStyle(GoldButtonStyle())
                }
            }
        }
        .padding(10)
        .background(Palette.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        let directory = model.playbookDirectory
        loadedFrom = directory
        playbook = PlaybookFile.load(from: directory)
        backup = PlaybookBackupStore.load(for: directory)
        if PlaybookFile.isUnreadable(in: directory) {
            message = "Graphitree couldn't read \(PlaybookFile.jsonName), so the Playbook starts empty. The file is left as it is. Before anything new is saved, it's kept beside it as playbook.unreadable-….json."
        }
        // Folders that can have their own stack: the labelled ones in the graph, or the groups.
        let source = GraphSource(outDirectory: model.outDirectory)
        if source.scheme.singleRepoName == nil {
            stackFolders = model.folderMap()?.folders.filter { $0.isIncluded && !$0.purpose.isDocs }.map(\.path).sorted() ?? source.scheme.groups.sorted()
        }
        addsToGraph = model.playbookAddsToGraph
        starterOffers = model.starterSurvey().offers.count
        isLoaded = true
        if let raw = UserDefaults.standard.string(forKey: "playbookTab"), let start = PlaybookTab(rawValue: raw) { tab = start }
        // GraphitreeShots opens a library's card, or starts a review, with these.
        if let name = UserDefaults.standard.string(forKey: "playbookOpen"), let library = playbook.libraries.first(where: { $0.name == name }) {
            libraryLayout = .list
            expanded = library.id
        }
        if UserDefaults.standard.bool(forKey: "playbookReview") { startReview() }
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
            saveTask = nil
        }
    }

    private func save() {
        guard let loadedFrom else { return }
        if let error = model.savePlaybook(playbook, in: loadedFrom) { message = "Couldn't save the playbook: \(error)" }
        playbookRevision += 1
    }

    private func update(_ id: UUID, _ change: (inout PlaybookLibrary) -> Void) {
        edit { book in
            if let index = book.libraries.firstIndex(where: { $0.id == id }) { change(&book.libraries[index]) }
        }
    }

    private func updateRule(_ id: UUID, _ change: (inout PlaybookRule) -> Void) {
        edit { book in
            if let index = book.rules.firstIndex(where: { $0.id == id }) { change(&book.rules[index]) }
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

    /// Backs up to the repo in use, a new one (`create`), or `target`. `replacing` backs up over a
    /// repo copy this Mac hasn't seen, after the person chose to.
    private func backUp(create: Bool, replacing: Bool = false, to target: String? = nil) async {
        saveTask?.cancel()
        saveTask = nil
        save()
        isBackingUp = true
        isConfirmingCreate = false
        let name = repoName.wrappedValue.trimmingCharacters(in: .whitespaces)
        let account = backup.account
        let remote = target ?? (create ? "https://github.com/\(account)/\(name).git" : backup.remote)
        let result = await model.backUpPlaybook(remote: create && target == nil ? nil : remote, createNamed: create && target == nil ? name : nil, account: account, from: loadedFrom, replacing: replacing)
        isBackingUp = false
        reloadBackup()
        switch result {
        case .success(let url):
            conflict = nil
            isDirty = false
            message = "Backed up to \(Self.place(url))."
        case .failure(let error):
            if let theirs = error.remoteCopy {
                if playbook.isEmpty {
                    // Nothing here to lose: bring the repo's playbook in.
                    await restore(from: remote)
                } else {
                    conflict = (remote, theirs)
                    message = nil
                }
            } else {
                message = "Backup failed: \(error.message)"
            }
        }
    }

    /// Replaces this graph's playbook with the repo's, keeping this Mac's beside it.
    private func restore(from remote: String) async {
        saveTask?.cancel()
        saveTask = nil
        save()
        isBackingUp = true
        isConfirmingRestore = false
        let result = await model.restorePlaybook(remote: remote, account: backup.account, into: loadedFrom)
        isBackingUp = false
        reloadBackup()
        switch result {
        case .success(let restored):
            playbook = restored
            conflict = nil
            isDirty = false
            message = "Brought the playbook from \(Self.place(remote)) here: \(PlaybookBackup.summary(of: restored))."
        case .failure(let error):
            message = "Couldn't bring the playbook here: \(error.message)"
        }
    }

    /// The model records each backup's outcome in the graph's settings; show what it wrote.
    private func reloadBackup() {
        if let loadedFrom { backup = PlaybookBackupStore.load(for: loadedFrom) }
    }

    /// Saves what's pending and, when backing up to GitHub, pushes the change.
    private func finishEditing() {
        guard isLoaded else { return }
        if saveTask != nil {
            saveTask?.cancel()
            save()
        }
        if isDirty, backup.github, !backup.remote.isEmpty, !backup.account.isEmpty, !playbook.isEmpty, let loadedFrom {
            let model = model
            let remote = backup.remote
            let account = backup.account
            // The outcome, a stop included, lands in the graph's backup settings for next time.
            Task { _ = await model.backUpPlaybook(remote: remote, createNamed: nil, account: account, from: loadedFrom) }
        }
    }
}

private enum PlaybookTab: String, CaseIterable, Identifiable {
    case chat, libraries, rules, skills, starters, stack, habits, storage

    var id: String { rawValue }
    var title: String {
        switch self {
        case .chat: return "Chat"
        case .libraries: return "Libraries"
        case .rules: return "Rules"
        case .skills: return "Skills"
        case .starters: return "Starters"
        case .stack: return "Stack"
        case .habits: return "How You Work"
        case .storage: return "Storage"
        }
    }
    var intro: String {
        switch self {
        case .chat: return "Ask about libraries, your stack or how you work."
        case .libraries: return "Libraries you trust, filed by area and the job they do. AI tools use these instead of writing their own toast, drawer or command menu. Map shows the whole stack at a glance; List has every detail."
        case .rules: return "What AI tools should follow beyond any one library, such as \"One primitive system per app\". A rule filed under a category shows with that category's libraries."
        case .skills: return "Skills new repos get, in the Agent Skills format: .agents/skills/<name>/SKILL.md for every tool, and a link in .claude/skills/ for Claude Code. Skills are only written into a repo with its starter."
        case .starters: return "A starter for each repo with no setup of its own: an AGENTS.md from your rules and stack, a CLAUDE.md that imports it, and your skills. Written once, after you see it. The repo owns it from then on."
        case .stack: return "What new work should start from. Pick your defaults; existing projects keep what they use."
        case .habits: return "How you like to work, written once so every AI tool knows it. Like memory, but yours to edit. The Chat tab can also learn it from your recent sessions."
        case .storage: return "The playbook lives next to the guide, and a copy goes into the knowledge graph. Keep it on this Mac, or back it up to a private repo."
        }
    }
}

/// How the Libraries tab shows them.
private enum LibraryLayout: String, CaseIterable, Identifiable {
    case map, list

    var id: String { rawValue }
    var title: String { self == .map ? "Map" : "List" }
}

/// Which libraries the Libraries tab shows.
private enum LibraryFilter: Hashable {
    case all
    case status(LibraryStatus)
    /// Not verified yet.
    case drafts

    func matches(_ library: PlaybookLibrary) -> Bool {
        switch self {
        case .all: return true
        case .status(.avoid): return library.isAvoided
        case .status(let status): return !library.isAvoided && library.status == status
        case .drafts: return !library.verified
        }
    }
}

/// A library as the Libraries tab places it: under its job, or under the library it pairs with.
private struct OutlineEntry: Identifiable {
    let library: PlaybookLibrary
    /// 0 for a library with a line of its own, 1 and deeper for ones that pair with it.
    let depth: Int
    /// The library at depth 0 it sits under, or its own id.
    let root: UUID
    var id: UUID { library.id }
}

private struct OutlineJob: Identifiable {
    let task: String
    let entries: [OutlineEntry]
    var id: String { task }
}

private struct OutlineGroup: Identifiable {
    let category: String
    let jobs: [OutlineJob]
    var id: String { category }
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

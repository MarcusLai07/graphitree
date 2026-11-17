import AppKit
import SwiftUI

/// Back Up: where each graph's backup goes, what it saves and what stays on this Mac, then a
/// review of exactly what will be committed and pushed. Accounts follow the owner's git rules.
/// Nothing is pushed until the person presses Back Up Now.
struct BackupView: View {
    @Environment(AppModel.self) private var model
    let openArrange: () -> Void

    private enum Step { case setup, review, restore }

    @State private var arrangement: Arrangement?
    @State private var accounts: GitAccounts?
    @State private var bundles: [String: BackupBundle] = [:]
    @State private var bundleErrors: [String: String] = [:]
    @State private var diffs: [String: [BackupDiff.Line]] = [:]
    @State private var repoExists: [String: Bool] = [:]
    @State private var repoHasOtherHistory: [String: Bool] = [:]
    @State private var commitMessages: [String: String] = [:]
    @State private var results: [String: String] = [:]
    @State private var message: String?
    @State private var step: Step = .setup
    @AppStorage("dismissedBackupWarnings") private var dismissedRaw = ""

    private var root: String { model.graphRoot }
    private var dismissed: Set<String> { Set(dismissedRaw.split(separator: "\n").map(String.init)) }

    var body: some View {
        Group {
            if let arrangement, let accounts {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if step != .restore { header }
                            if let message {
                                Text(message).font(.caption).foregroundStyle(Palette.gold).fixedSize(horizontal: false, vertical: true)
                            }
                            switch step {
                            case .setup:
                                ForEach(arrangement.graphs) { graph in setupCard(graph, arrangement: arrangement, accounts: accounts) }
                                ownRepoNote
                            case .review:
                                ForEach(arrangement.graphs) { graph in reviewCard(graph, arrangement: arrangement, accounts: accounts) }
                            case .restore:
                                RestorePane(plans: arrangement.graphs, logins: accounts.logins)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Rectangle().fill(Palette.hairline).frame(width: 1)
                    sideColumn(arrangement: arrangement, accounts: accounts)
                        .frame(width: 290)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading your graphs and git rules…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: model.settingsRevision) { await load() }
        .onAppear {
            // `-backupStep review` opens the review at launch, for screenshots.
            switch UserDefaults.standard.string(forKey: "backupStep") {
            case "review": step = .review
            case "restore": step = .restore
            default: break
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(step == .setup ? "Back up" : "Review and back up").font(.headline)
            Text(step == .setup
                 ? "Pick where each graph's backup goes. Graphitree saves only what can't be rebuilt cheaply, and each graph goes to the account your git rules give its folders."
                 : "What each backup will write, commit and push. Files marked D stop being tracked; they stay on this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Setup

    private func setupCard(_ graph: GraphPlan, arrangement: Arrangement, accounts: GitAccounts) -> some View {
        let plan = graph.backup
        let bundle = bundles[graph.id]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(colour(graph, arrangement)).frame(width: 12, height: 12)
                Text(graph.name).font(.body.weight(.semibold))
                Text("\(arrangement.nodes(inGraph: graph.id).formatted()) nodes").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if graph.isHome && arrangement.graphs.count > 1 { Text("Home").font(.caption2).foregroundStyle(Palette.gold) }
                Spacer()
                lastBackup(graph)
            }
            field("In this backup") {
                FlowLayout(spacing: 6) {
                    ForEach(graph.areaIDs.compactMap(arrangement.area)) { area in
                        HStack(spacing: 4) {
                            Circle().fill(Palette.series(area.purpose.colorSlot)).frame(width: 7, height: 7)
                            Text(area.name).font(.caption)
                            Text("\(arrangement.projects(in: area.id).count)").font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.05), in: Capsule())
                    }
                    Button("Change", action: openArrange).buttonStyle(.link).font(.caption)
                }
            }
            field("Where it goes") {
                Picker("Where", selection: Binding(get: { plan.destination }, set: { setDestination($0, graph: graph, arrangement: arrangement, accounts: accounts) })) {
                    Label("Private GitHub Repo", systemImage: "lock").tag(BackupPlan.Destination.github)
                    Label("This Mac Only", systemImage: "laptopcomputer").tag(BackupPlan.Destination.local)
                    Label("Don't Back Up", systemImage: "icloud.slash").tag(BackupPlan.Destination.none)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            switch plan.destination {
            case .github:
                githubFields(graph, accounts: accounts)
            case .local:
                Text("A git repo in Graphitree's own folder keeps every version, so you can roll back. Nothing leaves this Mac.")
                    .font(.caption).foregroundStyle(.secondary).padding(.leading, 112)
            case .none:
                Text("Nothing is saved. If this Mac is lost, rebuilding means paying for the AI extraction again.")
                    .font(.caption).foregroundStyle(.secondary).padding(.leading, 112)
            }
            if plan.destination != .none {
                field("When") {
                    Picker("When", selection: Binding(get: { plan.when }, set: { value in update(graph.id, rebuild: false) { $0.when = value } })) {
                        Text("After Each Rebuild").tag(BackupPlan.When.rebuild)
                        Text("Daily").tag(BackupPlan.When.daily)
                        Text("When I Ask").tag(BackupPlan.When.manual)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                if let note = scheduleNote(plan, graph: graph) {
                    Text(note).font(.caption).foregroundStyle(.secondary).padding(.leading, 112).fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(BackupWarnings.warnings(graph: graph, arrangement: arrangement, accounts: accounts, root: root, largestBytes: bundle?.largest?.bytes, repoHasOtherHistory: repoHasOtherHistory[graph.id], dismissed: dismissed)) { warning in
                warningRow(warning, graph: graph)
            }
            if plan.destination != .none {
                if let bundle {
                    fileColumns(bundle, graph: graph)
                } else if let error = bundleErrors[graph.id] {
                    Text(error).font(.caption).foregroundStyle(Palette.coral)
                } else {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Working out what this backup holds…").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .modifier(RowCard())
    }

    @ViewBuilder
    private func githubFields(_ graph: GraphPlan, accounts: GitAccounts) -> some View {
        let plan = graph.backup
        let rules = BackupWarnings.loginsByFolder(graph: graph, arrangement: arrangement ?? Arrangement(labels: []), accounts: accounts, root: root)
        field("Account") {
            HStack(spacing: 8) {
                Picker("Account", selection: Binding(get: { plan.login ?? "" }, set: { login in update(graph.id) { $0.login = login.isEmpty ? nil : login } })) {
                    if plan.login == nil { Text("Pick an account").tag("") }
                    ForEach(accounts.logins, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                Text(rules.isEmpty ? "No git rule covers these folders" : "Your rules: " + rules.sorted { $0.key < $1.key }.map { "\($0.value.folders.joined(separator: ", ")) → \($0.key)" }.joined(separator: "; "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        field("Repo") {
            HStack(spacing: 6) {
                Text("\(plan.login ?? "?")/").font(.callout.monospaced()).foregroundStyle(.secondary)
                TextField("name", text: Binding(get: { plan.repo }, set: { value in update(graph.id, rebuild: false) { $0.repo = value.filter { $0.isLetter || $0.isNumber || "-_.".contains($0) } } }))
                    .textFieldStyle(.roundedBorder)
                    .font(.callout.monospaced())
                    .frame(maxWidth: 220)
                Label("Private", systemImage: "lock.fill").font(.caption).foregroundStyle(Palette.jade)
                if let exists = repoExists[graph.id] {
                    Text(exists ? "Exists on GitHub" : "New: created with \(plan.login ?? "this account")'s gh login").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        field("Signs as") {
            Text(plan.login.flatMap(accounts.identity(forLogin:))?.display ?? accounts.rules.global?.display ?? "git's own identity")
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        field("Pushes to") {
            Text(BackupStore.remote(for: plan) ?? "Pick an account and a name").font(.caption.monospaced()).textSelection(.enabled)
        }
        Text("Graphitree signs and pushes each backup itself, with that account's gh login. graphify-out sits outside your rule folders, so git alone would sign it with your global identity.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 112)
    }

    private func warningRow(_ warning: BackupWarning, graph: GraphPlan) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: warning.level == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(warning.level == .warning ? Palette.coral : Palette.gold)
            VStack(alignment: .leading, spacing: 4) {
                Text(warning.title).font(.callout.weight(.medium))
                Text(warning.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    ForEach(warning.buttons, id: \.self) { button in
                        Button(button.title) { act(button.action, graph: graph) }
                            .buttonStyle(SoftButtonStyle())
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((warning.level == .warning ? Palette.coral : Palette.gold).opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
    }

    private func fileColumns(_ bundle: BackupBundle, graph: GraphPlan) -> some View {
        let saved = bundle.items.filter(\.isSaved)
        let stays = bundle.items.filter { !$0.isSaved }
        let savedBytes = saved.reduce(0) { $0 + $1.bytes }
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                columnTitle(graph.backup.destination == .github ? "Saved to GitHub" : "Saved in git on this Mac", symbol: "checkmark", bytes: savedBytes)
                ForEach(saved) { item in itemRow(item, graph: graph) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                columnTitle("Stays on this Mac", symbol: "laptopcomputer", bytes: nil)
                ForEach(stays) { item in itemRow(item, graph: graph) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
    }

    private func columnTitle(_ title: String, symbol: String, bytes: Int?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.caption)
            Text(title).font(.caption.weight(.semibold))
            Spacer()
            if let bytes { Text(size(bytes)).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
        }
        .foregroundStyle(.secondary)
    }

    private func itemRow(_ item: BackupItem, graph: GraphPlan) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let option = item.option {
                Toggle("", isOn: Binding(
                    get: { option == .semantic ? graph.backup.semantic : graph.backup.map },
                    set: { value in update(graph.id) { if option == .semantic { $0.semantic = value } else { $0.map = value } } }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            } else {
                Image(systemName: item.isSaved ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(item.isSaved ? Palette.jade : .secondary)
                    .font(.caption)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(item.title).font(.caption.weight(.medium))
                    Spacer()
                    if item.bytes > 0 { Text(size(item.bytes)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }
                }
                Text(item.detail).font(.caption2.monospaced()).foregroundStyle(.tertiary).lineLimit(2)
                Text(item.why).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(item.isSaved || item.option == nil ? 1 : 0.6)
    }

    @ViewBuilder
    private func lastBackup(_ graph: GraphPlan) -> some View {
        let record = model.backupRecords()[graph.id]
        if model.backingUp.contains(graph.id) {
            HStack(spacing: 4) { ProgressView().controlSize(.mini); Text("Backing up…").font(.caption) }
        } else if let error = record?.lastError, record?.lastAttempt ?? .distantPast > record?.lastSuccess ?? .distantPast {
            Label("Last backup failed", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Palette.coral).help(error)
        } else if let success = record?.lastSuccess {
            Text("Backed up \(success.formatted(.relative(presentation: .named)))").font(.caption).foregroundStyle(.secondary)
                .help(record?.ranFrom == "background" ? "By the background job, while Graphitree was closed" : (record?.ranFrom == "command line" ? "From the graphitree command" : "From Graphitree"))
        }
    }

    /// When a backup runs on its own, and why it might not yet.
    private func scheduleNote(_ plan: BackupPlan, graph: GraphPlan) -> String? {
        if let waiting = BackupSchedule.waitingReason(plan, record: model.backupRecords()[graph.id]) { return waiting }
        let closed = model.backgroundBackupsReady ? " Also while Graphitree is closed, by the background job, which looks every four hours." : ""
        switch plan.when {
        case .rebuild: return "After each rebuild, at most once an hour." + closed
        case .daily: return "Once a day." + closed
        case .manual: return nil
        }
    }

    @ViewBuilder
    private var ownRepoNote: some View {
        let out = model.outDirectory
        let config = (try? String(contentsOf: out.appendingPathComponent(".git/config"), encoding: .utf8)) ?? ""
        if let remote = FolderScan.originURL(inConfig: config) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                Text("graphify-out is also a git repo of its own, pushing to \(remote). Graphitree's backups don't use it, so its history and that repo stay as they are. Anything else that commits there still does.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .modifier(RowCard())
        }
    }

    // MARK: - Review

    private func reviewCard(_ graph: GraphPlan, arrangement: Arrangement, accounts: GitAccounts) -> some View {
        let plan = graph.backup
        let bundle = bundles[graph.id]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                switch plan.destination {
                case .github:
                    Image(systemName: "lock.fill").foregroundStyle(Palette.jade)
                    Text("\(plan.login ?? "?")/\(plan.repo)").font(.callout.monospaced().weight(.semibold))
                    if repoExists[graph.id] == false { Text("new repo").font(.caption2).foregroundStyle(Palette.jade) }
                case .local:
                    Image(systemName: "laptopcomputer")
                    Text(graph.name).font(.callout.weight(.semibold))
                    Text("this Mac only").font(.caption2).foregroundStyle(.secondary)
                case .none:
                    Image(systemName: "icloud.slash")
                    Text("\(graph.name) isn't backed up").font(.callout)
                }
                Spacer()
                if plan.destination != .none, let bundle {
                    Text("\(graph.name) · \(size(bundle.savedBytes)) in \(bundle.files.count) files").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            if plan.destination != .none {
                if let bundle {
                    if let largest = bundle.largest, plan.destination == .github { sizeMeter(largest) }
                    if let lines = diffs[graph.id] {
                        VStack(alignment: .leading, spacing: 3) {
                            if lines.isEmpty { Text("Nothing changed since the last backup.").font(.caption).foregroundStyle(.secondary) }
                            ForEach(lines) { line in
                                HStack(spacing: 8) {
                                    Text(line.status).font(.caption.monospaced().weight(.bold)).foregroundStyle(line.status == "A" ? Palette.jade : line.status == "D" ? Palette.coral : Palette.gold).frame(width: 14)
                                    Text(line.path).font(.caption.monospaced())
                                    Spacer()
                                    Text(line.detail).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                    }
                    field("Message") {
                        TextField("Message", text: Binding(
                            get: { commitMessages[graph.id] ?? BackupMessages.defaultMessage(graph: graph, nodes: bundle.summary.nodes) },
                            set: { commitMessages[graph.id] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                    }
                    if let log = model.backupLogs[graph.id], !log.isEmpty {
                        Text(log).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let result = results[graph.id] { Text(result).font(.caption).foregroundStyle(Palette.gold) }
                } else if let error = bundleErrors[graph.id] {
                    Text(error).font(.caption).foregroundStyle(Palette.coral)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .modifier(RowCard())
    }

    private func sizeMeter(_ largest: (path: String, bytes: Int)) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Largest file: \(largest.path) · \(size(largest.bytes))").font(.caption2).foregroundStyle(.secondary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(largest.bytes > BackupContents.warnBytes ? Palette.coral : Palette.jade)
                        .frame(width: proxy.size.width * min(1, CGFloat(largest.bytes) / CGFloat(BackupContents.limitBytes)))
                    Rectangle().fill(Color.white.opacity(0.35)).frame(width: 1).offset(x: proxy.size.width * 0.5)
                }
            }
            .frame(height: 5)
            HStack {
                Text("0")
                Spacer()
                Text("50 MB warning")
                Spacer()
                Text("100 MB limit")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Side column

    private func sideColumn(arrangement: Arrangement, accounts: GitAccounts) -> some View {
        let active = arrangement.graphs.filter { $0.backup.destination != .none }
        let ready = active.allSatisfy { $0.backup.destination == .local || BackupStore.remote(for: $0.backup) != nil }
        return VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What gets saved, and why").font(.headline)
                    principle("checkmark", "Save what you decided or paid for.", "Your arrangement and cleanup rules, community names and the meaning AI extracted.")
                    principle("checkmark", "Save the graph itself,", "one file per project, so each stays under GitHub's limits and git keeps only what changed.")
                    principle("xmark", "Skip what rebuilds in seconds", "or is already in git history: the parse cache, dated copies and build state.")
                    principle("lock", "Follow your git rules.", "Each graph goes to the account your rules give its folders, signed as that account.")
                    Text("Your git rules").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 6)
                    ForEach(accounts.rules.rules) { rule in
                        ruleRow(BackupWarnings.describe(rule.folder, root: root), folderKey: rule.folder, identity: rule.identity, accounts: accounts)
                    }
                    ruleRow("Everything else", folderKey: "", identity: accounts.rules.global, accounts: accounts)
                    Text("Read from your git config and gh's signed-in accounts. Pick the account once if the guess is wrong.")
                        .font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                    if accounts.logins.isEmpty {
                        Text("gh isn't signed in to any GitHub account, so only This Mac Only works for now. Sign in with `gh auth login`.")
                            .font(.caption).foregroundStyle(Palette.coral).fixedSize(horizontal: false, vertical: true)
                    }
                    if step != .restore {
                        Button("Restore from Backup…", systemImage: "clock.arrow.circlepath") { step = .restore }
                            .buttonStyle(.link)
                            .font(.caption)
                            .padding(.top, 6)
                    }
                }
                .padding(14)
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(spacing: 8) {
                if step == .restore {
                    Button("Back", systemImage: "chevron.left") { step = .setup }
                        .labelStyle(.iconOnly)
                        .buttonStyle(SoftButtonStyle())
                    Text("Nothing in use changes.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                } else if step == .review {
                    Button("Back", systemImage: "chevron.left") { step = .setup }
                        .labelStyle(.iconOnly)
                        .buttonStyle(SoftButtonStyle())
                    Spacer()
                    Button(model.backingUp.isEmpty ? "Back Up Now" : "Backing Up…") { Task { await backUpAll(arrangement: arrangement, accounts: accounts) } }
                        .buttonStyle(GoldButtonStyle())
                        .disabled(active.isEmpty || !ready || !model.backingUp.isEmpty || bundles.count < arrangement.graphs.filter { $0.backup.destination != .none }.count)
                } else {
                    Text(active.isEmpty ? "Nothing is set to be backed up." : "\(active.count) of \(arrangement.graphs.count) graph\(arrangement.graphs.count == 1 ? "" : "s") will be saved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Review") { Task { await openReview(arrangement: arrangement) } }
                        .buttonStyle(GoldButtonStyle())
                        .disabled(active.isEmpty || !ready)
                }
            }
            .padding(12)
        }
    }

    private func principle(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).font(.caption).foregroundStyle(symbol == "xmark" ? .secondary : Palette.jade).frame(width: 14).padding(.top, 2)
            (Text(title).fontWeight(.semibold) + Text(" " + detail)).font(.caption).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ruleRow(_ folder: String, folderKey: String, identity: GitIdentity?, accounts: GitAccounts) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "folder").font(.caption)
                Text(folderKey.isEmpty ? folder : folder.hasSuffix("/") ? folder : folder + "/").font(.caption.weight(.medium))
                Spacer()
                Picker("Login", selection: Binding(
                    get: { accounts.loginByFolder[folderKey] ?? "" },
                    set: { login in
                        guard !login.isEmpty else { return }
                        model.confirmLogin(login, forRuleFolder: folderKey)
                        self.accounts?.loginByFolder[folderKey] = login
                    }
                )) {
                    if accounts.loginByFolder[folderKey] == nil { Text("Pick").tag("") }
                    ForEach(accounts.logins, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .controlSize(.small)
            }
            Text(identity?.display ?? "no identity set").font(.caption2.monospaced()).foregroundStyle(.tertiary).lineLimit(1)
        }
    }

    // MARK: - Actions

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title).font(.caption).foregroundStyle(.secondary).frame(width: 102, alignment: .trailing)
            content()
            Spacer(minLength: 0)
        }
    }

    private func colour(_ graph: GraphPlan, _ arrangement: Arrangement) -> Color {
        let areas = graph.areaIDs.compactMap(arrangement.area)
        return areas.count == 1 ? Palette.series(areas[0].purpose.colorSlot) : Palette.gold
    }

    private func size(_ bytes: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) }

    /// Changes one graph's backup settings and saves them. Options that change the files rebuild
    /// the preview.
    private func update(_ graphID: String, rebuild: Bool = true, _ edit: (inout BackupPlan) -> Void) {
        guard var arrangement, let index = arrangement.graphs.firstIndex(where: { $0.id == graphID }) else { return }
        var plan = arrangement.graphs[index].backup
        edit(&plan)
        guard plan != arrangement.graphs[index].backup else { return }
        let repoChanged = plan.repo != arrangement.graphs[index].backup.repo || plan.login != arrangement.graphs[index].backup.login
        arrangement.setBackup(plan, forGraph: graphID)
        self.arrangement = arrangement
        if repoChanged {
            repoExists[graphID] = nil
            repoHasOtherHistory[graphID] = nil
        }
        message = model.saveGraphPlans(arrangement.graphs)
        if rebuild { bundles[graphID] = nil; Task { await buildBundle(graphID, arrangement: arrangement) } }
    }

    private func setDestination(_ destination: BackupPlan.Destination, graph: GraphPlan, arrangement: Arrangement, accounts: GitAccounts) {
        update(graph.id) { plan in
            plan.destination = destination
            if destination == .github {
                if plan.login == nil { plan.login = BackupWarnings.suggestedLogin(graph: graph, arrangement: arrangement, accounts: accounts, root: root) }
                if plan.repo.isEmpty { plan.repo = GraphPlan.suggestedRepo(for: graph.name) }
            }
        }
    }

    private func act(_ action: BackupWarning.Action, graph: GraphPlan) {
        switch action {
        case .dismiss(let id):
            dismissedRaw = dismissed.union([id]).sorted().joined(separator: "\n")
        case .useLogin(let login):
            update(graph.id) { $0.login = login }
        case .newRepo(let name):
            update(graph.id) { $0.repo = name }
        case .splitByAccount:
            guard var arrangement, let accounts else { return }
            let root = self.root
            let made = arrangement.splitByAccount(graph.id) { accounts.login(for: (root as NSString).appendingPathComponent($0)) }
            guard !made.isEmpty else { return }
            Task {
                let failure = await model.saveArrangement(arrangement)
                message = failure ?? "Split into \(arrangement.graphs.count) graphs, one per account. Check each one's repo below."
            }
        }
    }

    private func load() async {
        let loaded = await model.loadArrangement()
        accounts = await model.gitAccounts(for: loaded)
        let changed = arrangement.map { $0.graphs != loaded.graphs || $0.placement != loaded.placement || $0.labels != loaded.labels } ?? true
        arrangement = loaded
        guard changed else { return }
        bundles = [:]
        bundleErrors = [:]
        for graph in loaded.graphs where graph.backup.destination != .none {
            await buildBundle(graph.id, arrangement: loaded)
        }
    }

    private func buildBundle(_ graphID: String, arrangement: Arrangement) async {
        switch await model.backupBundle(for: graphID, arrangement: arrangement) {
        case .success(let bundle):
            bundles[graphID] = bundle
            bundleErrors[graphID] = nil
        case .failure(let error):
            bundleErrors[graphID] = error.message
        }
    }

    /// Builds each backup fresh, compares it with its repo's copy, and asks GitHub whether each repo
    /// exists and whether Graphitree wrote its history.
    private func openReview(arrangement: Arrangement) async {
        step = .review
        diffs = [:]
        for graph in arrangement.graphs where graph.backup.destination != .none {
            if bundles[graph.id] == nil { await buildBundle(graph.id, arrangement: arrangement) }
            guard let bundle = bundles[graph.id] else { continue }
            let mirror = BackupStore.mirror(for: graph.backup, graph: graph)
            diffs[graph.id] = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async { continuation.resume(returning: BackupDiff.lines(bundle: bundle, mirror: mirror)) }
            }
            if graph.backup.destination == .github, let login = graph.backup.login, !graph.backup.repo.isEmpty, repoExists[graph.id] == nil {
                let repo = graph.backup.repo
                let (exists, ours): (Bool?, Bool?) = await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let exists = try? BackupRemote.exists(login: login, repo: repo)
                        let ours = exists == true ? BackupRemote.isGraphitreeBackup(login: login, repo: repo) : nil
                        continuation.resume(returning: (exists, ours))
                    }
                }
                repoExists[graph.id] = exists
                if exists == true, ours == false { repoHasOtherHistory[graph.id] = true }
            }
        }
    }

    private func backUpAll(arrangement: Arrangement, accounts: GitAccounts) async {
        message = nil
        for graph in arrangement.graphs where graph.backup.destination != .none {
            let identity = BackupJob.identity(for: graph, accounts: accounts)
            let text = commitMessages[graph.id] ?? BackupMessages.defaultMessage(graph: graph, nodes: bundles[graph.id]?.summary.nodes ?? arrangement.nodes(inGraph: graph.id))
            switch await model.backUp(graphID: graph.id, arrangement: arrangement, identity: identity, message: text) {
            case .success(let outcome): results[graph.id] = outcome
            case .failure(let error): results[graph.id] = error.message
            }
        }
        repoExists = [:]
        await openReview(arrangement: arrangement)
    }
}

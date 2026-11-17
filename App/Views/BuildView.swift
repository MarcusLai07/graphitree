import AppKit
import SwiftUI

/// Build: one place to set graphify up and rebuild. Until a setup is saved it walks through each
/// choice, starting with the AI model. After that it rebuilds straight away with the saved setup,
/// and lists every setting that shapes the graph, cleanup rules included.
struct BuildView: View {
    @Environment(AppModel.self) private var model
    let snapshot: WorkspaceSnapshot
    let openModels: () -> Void
    let openPlaybook: () -> Void
    /// Opens Folders on a tab.
    let openFolders: (FoldersTab) -> Void

    enum Step: Int, CaseIterable, Identifiable {
        case model, projects, noise, answers, review

        var id: Int { rawValue }
        var title: String {
            switch self {
            case .model: return "AI model"
            case .projects: return "Folders"
            case .noise: return "Leave out"
            case .answers: return "Answers"
            case .review: return "Review"
            }
        }
    }

    @State private var isInSetup = false
    @State private var step: Step = .model
    @State private var isLoaded = false

    // Setup choices. Nothing is written until the review step saves them.
    @State private var projects: [ProjectSize] = []
    @State private var folderLabels: [FolderLabel] = []
    @State private var savedFolderLabels: [FolderLabel] = []
    @State private var folderScan: FolderScanResult?
    @State private var projectFilter = ""
    @State private var leftOut: Set<String> = []
    @State private var chosenPresets: Set<String> = Set(SetupPresets.ignore.filter(\.isOnByDefault).map(\.id))
    @State private var customLines = ""
    @State private var ignoreText = ""
    @State private var size: AnswerSize = .medium
    @State private var reach: AnswerReach = .usual
    @State private var savedSize: AnswerSize?
    @State private var savedReach: AnswerReach?
    @State private var buildOptions: [(id: String, name: String)] = []
    @State private var buildsNow = true
    @State private var error: String?

    // Rebuilding with the saved setup.
    @State private var settings = GraphSettings()
    @State private var docs: DocsPass?
    @State private var readsDocsThisTime = false
    @State private var allowsSmallerGraph = false
    @State private var isConfirming = false
    @State private var showsCleanupRules = false
    @State private var playbookLibraries = 0
    @State private var playbookIsInGraph = false
    @State private var freshnessError: String?

    @AppStorage(BuildChoice.defaultsKey) private var buildChoice = BuildChoice.automatic
    @AppStorage("readsDocsOnRebuild") private var readsDocs = false
    @AppStorage("setupSeen") private var setupSeen = false

    private var root: String { model.graphRoot }
    private var overview: OverviewData { snapshot.overview }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: isInSetup ? (model.isSetUp ? "Change Setup" : "Set Up graphify") : "Build", subtitle: subtitle)
            Rectangle().fill(Palette.hairline).frame(height: 1)
            if isInSetup {
                stepBar.padding(.horizontal, 18).padding(.vertical, 12)
                Rectangle().fill(Palette.hairline).frame(height: 1)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) { stepContent }
                        .padding(18)
                        .frame(maxWidth: 760, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Rectangle().fill(Palette.hairline).frame(height: 1)
                footer.padding(.horizontal, 18).padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) { home }
                        .padding(18)
                        .frame(maxWidth: 760, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task { await load() }
        .task(id: "\(buildChoice)|\(model.revision)|\(model.settingsRevision)") { await refresh() }
        .onAppear { setupSeen = true }
        .alert("Rebuild This Graph?", isPresented: $isConfirming) {
            Button("Rebuild") { rebuild() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
    }

    private var subtitle: String {
        if isInSetup { return "\(Step.allCases.count) short steps. Nothing is written until you save." }
        return "Rebuilds with your saved setup"
    }

    // MARK: - Rebuild with the saved setup

    @ViewBuilder
    private var home: some View {
        if let waiting = model.waitingDocsPass, let docs { waitingCard(waiting, docs: docs) }
        rebuildCard
        if model.isRebuilding || model.rebuildResult != nil || !model.rebuildLog.isEmpty {
            progress
        }
        freshnessCard
        settingsList
    }

    private var rebuildCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Rebuild the graph").font(.title3.weight(.semibold))
                    Text("Built \(overview.builtAt.formatted(date: .abbreviated, time: .shortened)): \(overview.visibleNodes.formatted()) nodes from \(overview.sourceFiles.formatted()) files. graphify rereads only what changed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if model.isRebuilding {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { model.cancelRebuild() }.buttonStyle(SoftButtonStyle())
                } else {
                    Button("Rebuild Now", systemImage: "hammer") { isConfirming = true }
                        .buttonStyle(GoldButtonStyle())
                        .disabled(model.isLoading)
                }
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            Toggle(isOn: Binding(get: { readsDocsThisTime && docs != nil }, set: { readsDocsThisTime = $0 })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(docs.map { "Also read docs with \($0.name)" } ?? "Also read docs, papers and images")
                    Text(docsDetail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(docs == nil || model.isRebuilding)
            .onChange(of: readsDocsThisTime) { if readsDocsThisTime { Task { await model.estimateDocs() } } }
            if readsDocsThisTime, let docs { estimateLine(docs).padding(.leading, 20) }
            if model.playbookIsNewerThanGraph {
                Label("Your playbook changed after this build. Reading docs brings the new version into the graph.", systemImage: "books.vertical")
                    .font(.caption)
                    .foregroundStyle(Palette.gold)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 20)
            }
            if docs == nil {
                Button("Connect a Model…", action: openModels).buttonStyle(.link).padding(.leading, 20)
            }
            Toggle(isOn: $allowsSmallerGraph) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Allow a smaller graph")
                    Text(ignoreChangedSinceBuild
                         ? ".graphifyignore changed after the last build, so this is on. Uses --force."
                         : "Needed after deleting code or leaving more out. Uses --force.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(model.isRebuilding)
        }
        .modifier(RowCard())
    }

    private var docsDetail: String {
        guard let docs else { return "No model is connected, so only code is read." }
        return "Only new and changed files go to the model, \(billing(docs)). It also names new groups."
    }

    private var ignoreChangedSinceBuild: Bool {
        guard let changed = settings.ignoreChangedAt else { return false }
        return changed > overview.builtAt
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let result = model.rebuildResult { resultSummary(result) }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.rebuildLog.isEmpty ? "graphify output appears here." : model.rebuildLog)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(model.rebuildLog.isEmpty ? .tertiary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .id("log")
                }
                .frame(height: 200)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: model.rebuildLog) { proxy.scrollTo("log", anchor: .bottom) }
            }
        }
        .modifier(RowCard())
    }

    @ViewBuilder
    private func resultSummary(_ result: RebuildResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            switch result {
            case .finished(let report):
                Label("Rebuild finished", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(Palette.jade)
                Text("Nodes \(report.nodesBefore.formatted()) to \(report.nodesAfter.formatted()), edges \(report.edgesBefore.formatted()) to \(report.edgesAfter.formatted()). \(report.wroteCleanGraph ? "Cleanup rules reapplied and graph.clean.json rewritten." : "No cleanup rules to reapply.")")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if report.orphanedRules > 0 {
                    Button("\(report.orphanedRules) \(report.orphanedRules == 1 ? "rule no longer matches" : "rules no longer match") anything. Show them") { showsCleanupRules = true }
                        .buttonStyle(.link)
                }
            case .refusedToShrink:
                Label("graphify refused to make the graph smaller", systemImage: "exclamationmark.triangle").font(.headline)
                Text("Nothing changed. If you deleted code or left more out, turn on Allow a smaller graph and rebuild.")
                    .font(.callout).foregroundStyle(.secondary)
            case .failed(let code):
                Label("graphify stopped with an error (exit \(code))", systemImage: "exclamationmark.triangle").font(.headline).foregroundStyle(Palette.coral)
                Text("See the output below. Your graph wasn't reloaded.").font(.callout).foregroundStyle(.secondary)
            case .cancelled:
                Label("Rebuild cancelled", systemImage: "xmark.circle").font(.headline)
            }
        }
    }

    // MARK: What shapes the graph

    private var settingsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("What shapes your graph").font(.headline)
                Spacer()
                if let saved = model.setupAppliedAt {
                    Text("Setup saved \(saved.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("graphify reads every folder under \(AgentGuide.abbreviate(root)). These settings decide what it skips, who reads the docs and how much AI tools get back. Change one to go through that step again.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                settingRow("brain.head.profile", "AI model", value: docs?.name ?? "Code only", detail: modelDetail, change: .model)
                divider
                settingRow("line.3.horizontal.decrease.circle", "Left out", value: "\(settings.ignorePatterns.formatted()) pattern\(settings.ignorePatterns == 1 ? "" : "s")", detail: ".graphifyignore in \(AgentGuide.abbreviate(root)). Each repo's .gitignore applies too.", change: .noise) {
                    Button("Show File") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: (root as NSString).appendingPathComponent(".graphifyignore"))])
                    }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(settings.ignorePatterns == 0)
                }
                divider
                settingRow("folder", "Folders", value: savedFolderLabels.isEmpty ? "Not labelled yet" : "\(savedFolderLabels.count) labelled", detail: foldersDetail, change: hasFolderStep ? .projects : nil) {
                    Button("Open") { openFolders(.arrange) }.buttonStyle(SoftButtonStyle())
                }
                divider
                settingRow("text.bubble", "Answers", value: settings.answersSummary, detail: ".graphifyrc: how much one question to the graph returns.", change: .answers)
                divider
                settingRow("checklist", "Cleanup rules", value: "\(snapshot.rules.count.formatted())", detail: "What you hide or reject from Graph health. Graphitree reapplies these to graph.clean.json after each rebuild. graphify never sees them.", change: nil) {
                    Button(showsCleanupRules ? "Hide" : "Show") { showsCleanupRules.toggle() }
                        .buttonStyle(SoftButtonStyle())
                }
                if showsCleanupRules {
                    CleanupRulesList(snapshot: snapshot).padding(.leading, 30).padding(.bottom, 8)
                }
                divider
                settingRow("books.vertical", "Playbook", value: "\(playbookLibraries.formatted()) librar\(playbookLibraries == 1 ? "y" : "ies")", detail: playbookDetail, change: nil) {
                    Button("Open", action: openPlaybook).buttonStyle(SoftButtonStyle())
                }
            }
            .modifier(RowCard())
        }
    }

    private var divider: some View {
        Rectangle().fill(Palette.hairline).frame(height: 1).padding(.leading, 30)
    }

    private var foldersDetail: String {
        guard !savedFolderLabels.isEmpty else { return "\(projects.count.formatted()) projects in the graph. Say what each folder is for, and AI tools are told too." }
        let out = savedFolderLabels.filter { !$0.isIncluded }.map(\.path)
        let kept = savedFolderLabels.filter(\.isIncluded).map { "\($0.path): \($0.purpose.title)" }
        return kept.joined(separator: " · ") + (out.isEmpty ? "" : ". Left out: " + out.joined(separator: ", ")) + "."
    }

    private var modelDetail: String {
        guard docs != nil else { return "Docs, papers and images stay out of the graph." }
        return readsDocs ? "Reads new and changed docs on every rebuild." : "Reads docs only when you turn it on for a rebuild."
    }

    private var playbookDetail: String {
        guard playbookLibraries > 0 || model.playbookAddsToGraph else { return "Libraries and stack AI tools should use. Not filled in yet." }
        if !model.playbookAddsToGraph { return "Its picks are in the guide. It isn't added to the graph." }
        if playbookIsInGraph { return model.playbookIsNewerThanGraph ? "In the guide and the graph. The graph has an older version until docs are read again." : "In the guide and in the graph, so graph questions that name a library return its entry." }
        return "In the guide. It reaches the graph on the next rebuild that reads docs."
    }

    private func settingRow(_ symbol: String, _ title: String, value: String, detail: String, change: Step?) -> some View {
        settingRow(symbol, title, value: value, detail: detail, change: change) { EmptyView() }
    }

    private func settingRow<Extra: View>(_ symbol: String, _ title: String, value: String, detail: String, change: Step?, @ViewBuilder extra: () -> Extra) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Palette.gold).frame(width: 20).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.body.weight(.medium))
                    Text(value).font(.callout).foregroundStyle(.primary.opacity(0.85))
                }
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            extra()
            if let change {
                Button("Change") { beginSetup(at: change) }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(model.isRebuilding)
            }
        }
        .padding(.vertical, 9)
    }

    private var confirmMessage: String {
        var text = "This rewrites graph.json in \(model.outDirectory.path)."
        if allowsSmallerGraph { text += " The check that stops a smaller graph is turned off." }
        if readsDocsThisTime, let docs {
            text += " Then docs, papers and images graphify hasn't read before go to \(docs.name), \(billing(docs))."
            if let estimate = model.docsEstimate {
                text += estimate.isEmpty ? " Right now there are none." : " " + costSentence(estimate, docs: docs) + "."
            }
        }
        return text
    }

    // MARK: Cost and freshness

    /// "12 new or changed docs: about 80k tokens of your plan and 6 minutes".
    private func costSentence(_ estimate: DocsEstimate, docs: DocsPass) -> String {
        let cost = model.docsCost(estimate, docs: docs)
        let what: String
        switch docs.billing {
        case .plan: what = "of your plan"
        case .apiAccount: what = "billed to your API account"
        case .thisMac: what = "on this Mac"
        }
        return "\(estimate.files.count.formatted()) new or changed file\(estimate.files.count == 1 ? "" : "s"): about \(Self.tokens(cost.totalTokens)) tokens \(what) and \(cost.minutes) minute\(cost.minutes == 1 ? "" : "s")"
    }

    static func tokens(_ count: Int) -> String {
        count >= 1_000_000 ? String(format: "%.1fM", Double(count) / 1_000_000) : count >= 1_000 ? "\(count / 1_000)k" : "\(count)"
    }

    @ViewBuilder
    private func estimateLine(_ docs: DocsPass) -> some View {
        if model.isEstimatingDocs {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Counting what graphify would send…").font(.caption).foregroundStyle(.secondary)
            }
        } else if let error = model.docsEstimateError {
            Text(error).font(.caption).foregroundStyle(Palette.coral)
        } else if let estimate = model.docsEstimate {
            if estimate.isEmpty {
                Label("No docs are new or changed, so this costs nothing.", systemImage: "checkmark.circle").font(.caption).foregroundStyle(Palette.jade)
            } else {
                let cost = model.docsCost(estimate, docs: docs)
                let isLarge = cost.totalTokens > model.freshness.askAboveTokens
                VStack(alignment: .leading, spacing: 3) {
                    Label(costSentence(estimate, docs: docs) + ".", systemImage: isLarge ? "exclamationmark.triangle" : "gauge.with.dots.needle.33percent")
                        .font(.caption)
                        .foregroundStyle(isLarge ? Palette.gold : .secondary)
                    let top = estimate.byProject(root: model.graphRoot, scheme: GraphSource(outDirectory: model.outDirectory).scheme).prefix(3)
                    Text("Most from " + top.map { "\($0.project) (\($0.files))" }.joined(separator: ", ") + ". Estimates improve after each pass.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func waitingCard(_ estimate: DocsEstimate, docs: DocsPass) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hourglass").foregroundStyle(Palette.gold).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("A scheduled docs pass is waiting for you").font(.body.weight(.semibold))
                Text("\(costSentence(estimate, docs: docs)). That's more than your limit of \(Self.tokens(model.freshness.askAboveTokens)) tokens, so it didn't start on its own.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Skip This One") { model.skipWaitingDocsPass() }.buttonStyle(SoftButtonStyle())
            Button("Run Now") { model.runWaitingDocsPass() }.buttonStyle(GoldButtonStyle()).disabled(model.isRebuilding)
        }
        .modifier(RowCard())
    }

    private var freshnessCard: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Keep it fresh").font(.headline)
                Spacer()
                if let last = model.lastQuietUpdate {
                    Text("Last quiet update \(last.date.formatted(date: .omitted, time: .shortened)): \(last.summary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Toggle(isOn: $model.freshness.updatesCodeOnChange) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update code when files change")
                    Text("Free. While Graphitree is open, graphify rereads changed code once you've stopped editing for a minute or two.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Toggle(isOn: Binding(get: { model.freshness.updatesWhenClosed }, set: { on in
                if let failure = model.setUpdatesWhenClosed(on) { freshnessError = failure }
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Also every 4 hours when Graphitree is closed")
                    Text("Free. Adds a background job that runs graphify update for code only, and waits if graphify is already busy. Graphitree catches up the folder graphs and the guide when it next opens.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let freshnessError {
                Text(freshnessError).font(.caption).foregroundStyle(Palette.coral)
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(spacing: 10) {
                Text("Read docs")
                Picker("Read docs", selection: $model.freshness.docs) {
                    ForEach(DocsSchedule.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(docs == nil)
                if model.freshness.docs == .weekly {
                    Picker("Day", selection: $model.freshness.weekday) {
                        ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1]).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                if model.freshness.docs != .never {
                    Text("at")
                    Picker("Hour", selection: $model.freshness.hour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now).map { $0.formatted(date: .omitted, time: .shortened) } ?? "\(hour):00").tag(hour)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Spacer()
            }
            if model.freshness.docs != .never {
                HStack(spacing: 10) {
                    Text("Ask me first above")
                    Picker("Limit", selection: $model.freshness.askAboveTokens) {
                        ForEach([50_000, 150_000, 500_000, 2_000_000], id: \.self) { Text("\(Self.tokens($0)) tokens").tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    Spacer()
                }
                Text(docs == nil
                     ? "Connect a model first."
                     : "Runs while Graphitree is open. A time missed while the Mac slept runs at the next chance. A pass over the limit waits here for you instead of starting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .modifier(RowCard())
    }

    private func billing(_ docs: DocsPass) -> String {
        switch docs.billing {
        case .plan: return "using your plan"
        case .apiAccount: return "billed to your API account"
        case .thisMac: return "running on this Mac"
        }
    }

    private func rebuild() {
        model.startRebuild(force: allowsSmallerGraph, docs: readsDocsThisTime ? docs : nil)
    }

    // MARK: - Setup

    private var stepBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases) { item in
                Button { go(to: item) } label: {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle().fill(item == step ? Palette.gold : item.rawValue < step.rawValue ? Palette.jade.opacity(0.25) : Color.white.opacity(0.08))
                            if item.rawValue < step.rawValue {
                                Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(Palette.jade)
                            } else {
                                Text("\(item.rawValue + 1)").font(.caption2.weight(.bold)).foregroundStyle(item == step ? Color.black : .secondary)
                            }
                        }
                        .frame(width: 20, height: 20)
                        Text(item.title)
                            .font(.caption.weight(item == step ? .semibold : .regular))
                            .foregroundStyle(item == step ? .primary : .secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if item != Step.allCases.last {
                    Rectangle().fill(Palette.hairline).frame(height: 1).frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if model.isSetUp {
                Button("Cancel") { isInSetup = false }.buttonStyle(SoftButtonStyle())
            }
            if step != .model {
                Button("Back") { move(-1) }.buttonStyle(SoftButtonStyle())
            }
            Spacer()
            Text("Step \(step.rawValue + 1) of \(Step.allCases.count)").font(.caption).foregroundStyle(.secondary)
            Spacer()
            if step == .review {
                Button(buildsNow ? "Save and Build" : "Save") { apply() }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(!isLoaded || model.isRebuilding)
            } else {
                Button("Next") { move(1) }.buttonStyle(GoldButtonStyle())
            }
        }
    }

    private func beginSetup(at start: Step = .model) {
        error = nil
        step = start
        isInSetup = true
    }

    private func go(to target: Step) {
        // A single repo has nothing to choose on the folders step.
        if target == .projects && !hasFolderStep { return }
        step = target
    }

    private func move(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        if next == .projects && !hasFolderStep, let skip = Step(rawValue: next.rawValue + delta) {
            step = skip
        } else {
            step = next
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .model: modelStep
        case .projects: projectsStep
        case .noise: noiseStep
        case .answers: answersStep
        case .review: reviewStep
        }
    }

    // MARK: 1. AI model

    private var modelStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Start with an AI model", "graphify turns your folders into a map that AI tools ask before they read files. It reads code on its own. Docs, papers and images need an AI model, which also names the groups in the graph.")
            HStack(alignment: .top, spacing: 8) {
                explainer("doc.text.magnifyingglass", "Reads your code", "Functions, classes and imports, linked up. No AI and no cost.")
                explainer("sparkles", "Reads docs with AI", "Only new or changed files go to the model you pick below.")
                explainer("bubble.left.and.text.bubble.right", "Answers AI tools", "Tools ask the graph first, so they open fewer files.")
            }
            if buildOptions.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.gold).font(.title3)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No AI model is connected yet").font(.body.weight(.semibold))
                        Text("Connect Claude Code, an API key or a model on this Mac in AI Models, then come back to Build. Or build from code only for now and add a model later.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open AI Models…", action: openModels).buttonStyle(GoldButtonStyle())
                    }
                }
                .modifier(RowCard())
            } else {
                Text("Connected and ready").font(.headline)
            }
            ForEach(buildOptions, id: \.id) { option in
                choiceCard(
                    isOn: resolvedChoice == option.id,
                    title: option.name,
                    detail: option.id == "claude-code" ? "Uses your Claude plan. Nothing extra to pay." : "Uses the key or server you set up in AI Models.",
                    badge: "Connected"
                ) { buildChoice = option.id }
            }
            choiceCard(isOn: resolvedChoice == nil, title: "Nothing, code only", detail: "Free. Docs, papers and images stay out of the graph, and so does your playbook.") {
                buildChoice = BuildChoice.codeOnly
            }
            if !buildOptions.isEmpty {
                Button("Connect Another Model…", action: openModels).buttonStyle(.link)
            }
            Toggle(isOn: $readsDocs) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Read docs on every rebuild")
                    Text("Off means code only, unless you turn it on for one rebuild.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(resolvedChoice == nil)
            .modifier(RowCard())
        }
    }

    private var resolvedChoice: String? {
        BuildChoice.resolve(buildChoice, options: buildOptions.map(\.id))
    }

    // MARK: 2. Folders

    private var hasFolderStep: Bool { !folderLabels.isEmpty || projects.count > 1 }

    /// Projects inside groups that stay in the graph, which can be left out one by one.
    private var groupedProjects: [ProjectSize] {
        let kept = Set(folderLabels.filter { $0.holdsProjects && $0.isIncluded }.map(\.path))
        guard !folderLabels.isEmpty else { return projects }
        return projects.filter { project in
            guard let top = project.project.split(separator: "/").first.map(String.init), project.project.contains("/") else { return false }
            return kept.contains(top)
        }
    }

    private var visibleProjects: [ProjectSize] {
        let filter = projectFilter.trimmingCharacters(in: .whitespaces).lowercased()
        return filter.isEmpty ? groupedProjects : groupedProjects.filter { $0.project.lowercased().contains(filter) }
    }

    private var projectsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("What graphify reads", "Everything under \(AgentGuide.abbreviate(root)), except what .gitignore and .graphifyignore leave out. Say what each main folder is for: labels decide which folders hold projects, how the map groups them, and what AI tools are told. Reference and archive folders are left out.")
            if let folderScan, !folderLabels.isEmpty {
                FolderLabelsEditor(labels: $folderLabels, scan: folderScan, kinds: model.folderMap()?.kinds ?? FolderPurpose.defaults)
                Button("Tidy-Up Suggestions in Folders…") { openFolders(.tidy) }.buttonStyle(.link)
            }
            if !groupedProjects.isEmpty {
                Text("Projects").font(.headline).padding(.top, 4)
                Text("Leave out single projects AI tools should never see, such as experiments or work you keep apart.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !groupedProjects.isEmpty {
            HStack {
                TextField("Filter projects", text: $projectFilter).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                Spacer()
                Text("\(groupedProjects.count - leftOut.count) of \(groupedProjects.count) included").font(.caption).foregroundStyle(.secondary)
            }
            }
            VStack(spacing: 0) {
                ForEach(visibleProjects, id: \.project) { item in
                    Toggle(isOn: Binding(
                        get: { !leftOut.contains(item.project) },
                        set: { if $0 { leftOut.remove(item.project) } else { leftOut.insert(item.project) } }
                    )) {
                        HStack {
                            Text(item.project).font(.callout)
                            Spacer()
                            Text("\(item.nodes.formatted()) nodes").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    Rectangle().fill(Palette.hairline).frame(height: 1)
                }
            }
            .modifier(RowCard())
            .opacity(groupedProjects.isEmpty ? 0 : 1)
        }
    }

    // MARK: 3. Leave out

    private var noiseStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Leave out the noise", "These go into .graphifyignore, so graphify never reads them. That keeps the graph small and its answers on topic.")
            ForEach(SetupPresets.ignore) { preset in
                presetRow(preset)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Your own patterns").font(.body.weight(.medium))
                Text("One per line, written like .gitignore: a folder ends with /, and * matches any name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $customLines)
                    .font(.system(.callout, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(height: 70)
                    .padding(6)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                HStack {
                    Text(ignoreText.isEmpty ? "There's no .graphifyignore yet. Graphitree will create one." : "\(IgnoreFile.patterns(in: ignoreText).count) patterns are already in .graphifyignore.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !ignoreText.isEmpty {
                        Button("Show File") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: (root as NSString).appendingPathComponent(".graphifyignore"))])
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
            }
            .modifier(RowCard())
        }
    }

    private func presetRow(_ preset: IgnorePreset) -> some View {
        let applied = IgnoreFile.isApplied(preset, in: ignoreText)
        return HStack(alignment: .top, spacing: 10) {
            if applied {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.jade).frame(width: 34)
            } else {
                Toggle("", isOn: Binding(
                    get: { chosenPresets.contains(preset.id) },
                    set: { if $0 { chosenPresets.insert(preset.id) } else { chosenPresets.remove(preset.id) } }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(preset.title).font(.body.weight(.medium))
                    if applied {
                        Text("Already left out").font(.caption).foregroundStyle(Palette.jade)
                    } else if !preset.isOnByDefault {
                        Text("Optional").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(preset.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(preset.lines.joined(separator: "  ")).font(.caption.monospaced()).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .modifier(RowCard())
    }

    // MARK: 4. Answers

    private var answersStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("How much AI tools get back", "Each question to the graph returns a list of the code involved. A shorter answer costs the tool fewer tokens; a longer one finds more.")
            Text("Answer size").font(.headline)
            ForEach(AnswerSize.allCases) { option in
                choiceCard(isOn: size == option, title: option.title, detail: option.detail) { size = option }
            }
            Text("How far it looks").font(.headline).padding(.top, 4)
            ForEach(AnswerReach.allCases) { option in
                choiceCard(isOn: reach == option, title: option.title, detail: option.detail) { reach = option }
            }
            Text("Saved in .graphifyrc in \(AgentGuide.abbreviate(root)), which graphify reads for every question. The guide asks for the same size.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 5. Review

    private var newIgnoreLines: [String] {
        let projectLines = leftOut.sorted().map { SourcePath.ignoreLine(for: $0.hasSuffix("/") ? $0 : $0 + "/") }
        let presetLines = SetupPresets.ignore.filter { chosenPresets.contains($0.id) }.flatMap(\.lines)
        let custom = customLines.split(separator: "\n").map(String.init)
        return IgnoreFile.additions(projectLines + presetLines + custom, to: ignoreText)
    }

    private var reviewStep: some View {
        let lines = newIgnoreLines
        return VStack(alignment: .leading, spacing: 12) {
            heading("Check and save", "Graphitree backs up each file before changing it, as name.graphitree-backup-date. After this, Build rebuilds with these settings straight away.")
            reviewItem("AI model", docsSummary) { EmptyView() }
            if !folderLabels.isEmpty {
                reviewItem("Folders", folderSummary) { EmptyView() }
            }
            reviewItem(".graphifyignore", lines.isEmpty ? "No new lines." : "Adds \(lines.count) line\(lines.count == 1 ? "" : "s"):") {
                if !lines.isEmpty {
                    Text(lines.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            reviewItem(".graphifyrc", answersSummary) { EmptyView() }
            Toggle(isOn: $buildsNow) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Build now")
                    Text(buildNowDetail(lines))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .modifier(RowCard())
            if let error {
                Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(Palette.coral)
            }
        }
    }

    private func buildNowDetail(_ lines: [String]) -> String {
        var text = lines.isEmpty ? "Reads the code again with these settings." : "Leaving more out makes the graph smaller, so this build allows that (--force)."
        if readsDocs, let name = resolvedName { text += " \(name) reads new and changed docs too." }
        return text
    }

    private var resolvedName: String? {
        resolvedChoice.flatMap { id in buildOptions.first { $0.id == id }?.name }
    }

    private var folderSummary: String {
        let changed = folderLabels != savedFolderLabels
        let kept = folderLabels.filter(\.isIncluded).map { "\($0.path) (\($0.purpose.title))" }
        let out = folderLabels.filter { !$0.isIncluded }.map(\.path)
        var text = kept.isEmpty ? "No folders kept." : "Keeps " + kept.joined(separator: ", ") + "."
        if !out.isEmpty { text += " Leaves out " + out.joined(separator: ", ") + "." }
        if !changed && !savedFolderLabels.isEmpty { text += " (unchanged)" }
        return text
    }

    private var answersSummary: String {
        var text = "\(RCFile.budgetKey)=\(size.rawValue), \(RCFile.depthKey)=\(reach.rawValue)"
        if savedSize == size && savedReach == reach { text += " (unchanged)" }
        return text
    }

    private var docsSummary: String {
        guard let name = resolvedName else { return "Code only. Docs, papers and images stay out." }
        return "\(name). \(readsDocs ? "Reads new and changed docs on every rebuild." : "Reads docs only when you turn it on for a rebuild.")"
    }

    private func apply() {
        error = nil
        let lines = newIgnoreLines
        if let failure = model.applySetup(ignoreLines: lines, answerSize: size, reach: reach) {
            error = "Couldn't write the settings: \(failure)"
            return
        }
        let labels = folderLabels
        let foldersChanged = !labels.isEmpty && labels != savedFolderLabels
        let leavesFoldersOut = labels.contains { label in !label.isIncluded && savedFolderLabels.first { $0.path == label.path }?.isIncluded != false }
        Task {
            if foldersChanged, let failure = await model.saveFolders(labels, reloads: !buildsNow) {
                error = failure
                return
            }
            savedFolderLabels = labels
            if buildsNow {
                model.startRebuild(force: !lines.isEmpty || leavesFoldersOut || ignoreChangedSinceBuild, docs: readsDocs ? model.docsPass() : nil)
            }
            isInSetup = false
            await reloadFiles()
        }
    }

    // MARK: - Pieces

    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.weight(.semibold))
            Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func explainer(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Palette.gold)
            Text(title).font(.callout.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .modifier(RowCard())
    }

    private func choiceCard(isOn: Bool, title: String, detail: String, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isOn ? Palette.gold : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium))
                    Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let badge {
                    Label(badge, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Palette.jade)
                }
            }
            .padding(12)
            .background(isOn ? Palette.gold.opacity(0.08) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(isOn ? Palette.gold.opacity(0.35) : Color.white.opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reviewItem<Extra: View>(_ title: String, _ summary: String, @ViewBuilder extra: () -> Extra) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.body.weight(.medium))
            Text(summary).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            extra()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(RowCard())
    }

    // MARK: - Loading

    private func load() async {
        projects = await model.projectSizes()
        if GraphSource(outDirectory: model.outDirectory).scheme.singleRepoName == nil {
            let scan = await model.scanFolders()
            let saved = model.folderMap()
            folderLabels = FolderScan.labels(saved: saved, scan: scan)
            savedFolderLabels = saved == nil ? [] : folderLabels
            folderScan = scan
        }
        await reloadFiles()
        await refresh()
        readsDocsThisTime = readsDocs || model.playbookIsNewerThanGraph
        if readsDocsThisTime { Task { await model.estimateDocs() } }
        allowsSmallerGraph = ignoreChangedSinceBuild
        isInSetup = !model.isSetUp
        // `-setupStep noise` opens a setup step at launch, and `-buildMode home` skips the setup,
        // for screenshots and checks. Neither is saved.
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "setupStep"), let start = Step.allCases.first(where: { "\($0)" == raw }) {
            beginSetup(at: start)
        } else if defaults.string(forKey: "buildMode") == "home" {
            isInSetup = false
        }
        isLoaded = true
    }

    /// Rereads the files the setup writes, so its steps start from what's saved.
    private func reloadFiles() async {
        let rootFolder = root as NSString
        ignoreText = (try? String(contentsOfFile: rootFolder.appendingPathComponent(".graphifyignore"), encoding: .utf8)) ?? ""
        let rc = (try? String(contentsOfFile: rootFolder.appendingPathComponent(".graphifyrc"), encoding: .utf8)) ?? ""
        if let budget = RCFile.value(RCFile.budgetKey, in: rc).flatMap(Int.init) {
            size = AnswerSize.from(budget: budget)
            savedSize = size
        }
        if let depth = RCFile.value(RCFile.depthKey, in: rc).flatMap(Int.init), let saved = AnswerReach(rawValue: min(max(depth, 1), 3)) {
            reach = saved
            savedReach = saved
        }
        customLines = ""
        leftOut = []
        settings = model.graphSettings()
    }

    private func refresh() async {
        buildOptions = BuildChoice.options(home: model.agentHome, store: .standard)
        docs = model.docsPass()
        settings = model.graphSettings()
        playbookLibraries = model.loadPlaybook().libraries.count
        playbookIsInGraph = await model.nodeCount(inProject: PlaybookFile.graphFolder) > 0
    }
}

struct ProjectSize: Hashable, Sendable {
    let project: String
    let nodes: Int
}

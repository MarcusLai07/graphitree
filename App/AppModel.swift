import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum State {
        case loading(IndexPhase)
        case ready(WorkspaceSnapshot)
        case failed(String)
    }

    private static let outDirectoryKey = "graphOutDirectory"

    private(set) var state: State = .loading(.reading)
    private(set) var outDirectory: URL
    /// Increases whenever decisions change, so open detail lists know to reload.
    private(set) var revision = 0
    /// Bumped when a setting outside the graph changes, so panels reread it without redrawing the graph.
    private(set) var settingsRevision = 0
    private(set) var isWritingClean = false
    private(set) var catalog: [GraphEntry] = []
    private(set) var isRebuilding = false
    private(set) var rebuildLog = ""
    private(set) var rebuildResult: RebuildResult?
    var errorMessage: String?

    // Keeping the graph fresh: settings, the docs estimate, and what quiet rebuilds did.
    var freshness = FreshnessSettings() {
        didSet {
            guard freshness != oldValue else { return }
            // Turning a schedule on starts counting from now, so it doesn't fire for a slot that already passed.
            if oldValue.docs == .never, freshness.docs != .never, freshness.lastDocsPass == nil {
                freshness.lastDocsPass = .now
            }
            freshness.save()
            if freshness.updatesCodeOnChange != oldValue.updatesCodeOnChange { restartWatcher() }
        }
    }
    private(set) var docsEstimate: DocsEstimate?
    private(set) var isEstimatingDocs = false
    private(set) var docsEstimateError: String?
    /// A scheduled docs pass that would cost more than the limit, waiting for the person.
    private(set) var waitingDocsPass: DocsEstimate?
    private(set) var rebuildIsQuiet = false
    private(set) var lastQuietUpdate: (date: Date, summary: String)?

    // The Playbook's chat lives here, so a reply still arrives after its panel closes.
    private(set) var chatTurns: [ChatTurn] = []
    private(set) var isChatting = false
    private(set) var chatStartedAt: Date?

    @ObservationIgnored private var workspace: Workspace?
    @ObservationIgnored private var rebuilder: GraphRebuilder?
    @ObservationIgnored private var chatLoadedFor: URL?
    @ObservationIgnored private var refreshesGuideAfterLoad = false
    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var pendingChangeAt: Date?
    @ObservationIgnored private var lastQuietStart: Date = .distantPast
    @ObservationIgnored private var loadedGraphDate: Date?
    @ObservationIgnored private var askedAboutSlot: Date?
    @ObservationIgnored private var lastBackupCheck: Date = .distantPast
    @ObservationIgnored private var docsRunStarted: (date: Date, backend: String, files: Int, estimatedInput: Int)?
    @ObservationIgnored private var chatTask: Task<Void, Never>?
    @ObservationIgnored private var chatProcess: ChatProcess?
    @ObservationIgnored private var loadGeneration = 0
    /// `Workspace` isn't thread-safe, so every decision runs here, in order.
    @ObservationIgnored private let workQueue = DispatchQueue(label: "com.marcuslai.Graphitree.workspace")

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.outDirectoryKey) {
            outDirectory = URL(fileURLWithPath: saved)
        } else {
            outDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents/GitHub/graphify-out", isDirectory: true)
        }
        freshness = FreshnessSettings.load()
        refreshAIOptions()
        graphifyPath = GraphRebuilder.locateGraphify()
        // `-showFirstRun YES` opens the first-run screen whatever is connected, for screenshots and checks.
        // Without graphify it opens too, since nothing can be mapped until graphify is installed.
        firstRunOpen = UserDefaults.standard.bool(forKey: "showFirstRun") || needsModelSetup || graphifyPath == nil
        startFreshnessLoop()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            await self?.checkConnections()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.syncBackgroundJob() }
    }

    var snapshot: WorkspaceSnapshot? {
        if case .ready(let snapshot) = state { return snapshot }
        return nil
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var canWriteClean: Bool {
        guard let snapshot, !isWritingClean else { return false }
        switch snapshot.clean {
        case .notWritten: return !snapshot.rules.isEmpty
        case .outOfDate: return true
        case .upToDate: return false
        }
    }

    func choose(_ directory: URL) {
        guard !isRebuilding else {
            errorMessage = "Wait for the rebuild to finish before switching graphs."
            return
        }
        outDirectory = directory
        UserDefaults.standard.set(directory.path, forKey: Self.outDirectoryKey)
        rebuildLog = ""
        rebuildResult = nil
        load()
    }

    /// Reopens the graph. The index is only rebuilt if `graph.json` changed.
    func load() {
        loadGeneration += 1
        let generation = loadGeneration
        let source = GraphSource(outDirectory: outDirectory)
        state = .loading(.reading)
        workspace = nil

        workQueue.async { [weak self] in
            let result = Result { () throws -> (Workspace, WorkspaceSnapshot) in
                let workspace = try Workspace(
                    source: source,
                    cacheDirectory: try GraphIndex.defaultCacheDirectory()
                ) { phase in
                    Task { @MainActor in self?.show(phase, generation: generation) }
                }
                return (workspace, try workspace.snapshot())
            }
            Task { @MainActor in
                guard let self, generation == self.loadGeneration else { return }
                switch result {
                case .success(let (workspace, snapshot)):
                    self.workspace = workspace
                    self.state = .ready(snapshot)
                    self.revision += 1
                    self.loadedGraphDate = self.graphFileDate
                    self.restartWatcher()
                    if self.refreshesGuideAfterLoad {
                        self.refreshesGuideAfterLoad = false
                        self.refreshAgentGuideIfPresent()
                    }
                case .failure(let error):
                    self.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    /// Phase updates arrive asynchronously and must not overwrite a finished load.
    private func show(_ phase: IndexPhase, generation: Int) {
        guard generation == loadGeneration, isLoading else { return }
        state = .loading(phase)
    }

    private func update(_ work: @escaping @Sendable (Workspace) throws -> WorkspaceSnapshot) {
        guard let workspace else { return }
        let generation = loadGeneration
        workQueue.async { [weak self] in
            let result = Result { try work(workspace) }
            Task { @MainActor in
                guard let self, generation == self.loadGeneration else { return }
                switch result {
                case .success(let snapshot):
                    self.state = .ready(snapshot)
                    self.revision += 1
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Decisions

    func perform(_ actions: [CurationAction]) {
        update { try $0.perform(actions) }
    }

    func remove(_ findings: [Finding]) {
        perform(findings.map(\.removal))
    }

    func keep(_ findings: [Finding]) {
        perform(findings.map { .keep(findingID: $0.id, note: $0.title) })
    }

    /// Hides the findings now and stops future builds from extracting them.
    func addToIgnoreFile(_ findings: [Finding]) {
        let lines = findings.compactMap(\.ignoreLine)
        let actions = findings.map(\.removal)
        update { workspace in
            try workspace.addToIgnoreFile(lines)
            return try workspace.perform(actions)
        }
    }

    func undoLast() {
        update { try $0.undoLastBatch() }
    }

    func undo(ruleIDs: [String]) {
        update { try $0.undo(ruleIDs: ruleIDs) }
    }

    func writeCleanGraph() {
        guard let workspace else { return }
        let generation = loadGeneration
        isWritingClean = true
        workQueue.async { [weak self] in
            let result = Result { () throws -> WorkspaceSnapshot in
                try workspace.writeCleanGraph()
                return try workspace.snapshot()
            }
            Task { @MainActor in
                guard let self else { return }
                self.isWritingClean = false
                guard generation == self.loadGeneration else { return }
                switch result {
                case .success(let snapshot):
                    self.state = .ready(snapshot)
                    self.refreshAgentGuideIfPresent()
                case .failure(let error): self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Runs a read on the workspace queue. Reads that fail return `fallback`.
    private func ask<T: Sendable>(_ fallback: T, _ work: @escaping @Sendable (Workspace) throws -> T) async -> T {
        guard let workspace else { return fallback }
        return await withCheckedContinuation { continuation in
            workQueue.async {
                continuation.resume(returning: (try? work(workspace)) ?? fallback)
            }
        }
    }

    func details(for finding: Finding) async -> [FindingDetail] {
        await ask([]) { try $0.details(for: finding) }
    }

    func search(_ text: String) async -> [OutlineItem] {
        await ask([]) { try $0.search(text) }
    }

    func outlineChildren(of parent: OutlineItem?) async -> [OutlineItem] {
        await ask([]) { try $0.outlineChildren(of: parent) }
    }

    func nodeDetail(id: String) async -> NodeDetail? {
        await ask(nil) { try $0.nodeDetail(id: id) }
    }

    func rootLevel() async -> SceneLevel? {
        await ask(nil) { try $0.rootLevel() }
    }

    func childLevel(of level: SceneLevel, nodeID: String) async -> SceneLevel? {
        await ask(nil) { $0.childLevel(of: level, nodeID: nodeID) }
    }

    func title(of level: SceneLevel) async -> String {
        await ask("") { try $0.title(of: level) }
    }

    func scene(at level: SceneLevel, showHidden: Bool) async -> GraphScene? {
        await ask(nil) { try $0.scene(at: level, showHidden: showHidden) }
    }

    func ringScene(at level: SceneLevel, showHidden: Bool) async -> GraphScene? {
        await ask(nil) { try $0.ringScene(at: level, showHidden: showHidden) }
    }

    /// Asks graphify a question, then matches the answer back to the index.
    func askGraph(_ question: String, onCleanGraph: Bool) async -> AskState {
        guard let workspace else { return .failed("No graph is open.") }
        let graph = onCleanGraph ? workspace.cleanURL : GraphSource(outDirectory: outDirectory).graphURL
        // graphify takes a second or two, so it runs off the workspace queue and decisions keep working.
        let output: Result<String, Error> = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Result { try GraphQuery.run(question: question, graph: graph) })
            }
        }
        switch output {
        case .failure(let error):
            return .failed(error.localizedDescription)
        case .success(let text):
            let answer = QueryAnswer.parse(text)
            let items = await ask([]) { try $0.resolve(answer) }
            return .ready(AskOutcome(answer: answer, items: items))
        }
    }

    // MARK: - Agents

    /// Where AI tools keep their settings. A test can point this elsewhere with the `agentHomeOverride` default.
    var agentHome: String {
        UserDefaults.standard.string(forKey: "agentHomeOverride") ?? FileManager.default.homeDirectoryForCurrentUser.path
    }

    var graphRoot: String { GraphSource(outDirectory: outDirectory).rootPath }
    var guidePath: String { outDirectory.appendingPathComponent(AgentGuide.fileName).path }

    var hasCleanGraph: Bool {
        if case .upToDate = snapshot?.clean { return true }
        return false
    }

    /// The graph agents should query: the clean one once it's up to date.
    var queryGraphPath: String {
        hasCleanGraph
            ? outDirectory.appendingPathComponent("graph.clean.json").path
            : GraphSource(outDirectory: outDirectory).graphURL.path
    }

    /// The clean graph relative to the graph's root, matching `graphify query` run from there.
    var cleanGraphPathFromRoot: String {
        let clean = outDirectory.appendingPathComponent("graph.clean.json").path
        return clean.hasPrefix(graphRoot + "/") ? String(clean.dropFirst(graphRoot.count + 1)) : clean
    }

    /// The Python that runs the installed graphify, read from its launcher.
    var graphifyPython: String? {
        guard let launcher = GraphRebuilder.locateGraphify(),
              let handle = FileHandle(forReadingAtPath: launcher) else { return nil }
        defer { try? handle.close() }
        let head = String(decoding: (try? handle.read(upToCount: 400)) ?? Data(), as: UTF8.self)
        guard let first = head.split(separator: "\n").first, first.hasPrefix("#!") else { return nil }
        let path = first.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return path.contains(" ") ? nil : path
    }

    func agentGuideText() async -> String? {
        guard let snapshot else { return nil }
        return await ask(nil) { try $0.agentGuideText(findings: snapshot.findings, overview: snapshot.overview, clean: snapshot.clean) }
    }

    /// Writes the guide. Returns an error message, or nil when it worked.
    func writeAgentGuide() async -> String? {
        guard let snapshot else { return "No graph is open." }
        return await ask("The guide couldn't be written.") { workspace -> String? in
            let text = try workspace.agentGuideText(findings: snapshot.findings, overview: snapshot.overview, clean: snapshot.clean)
            try workspace.writeAgentGuide(text)
            return nil
        }
    }

    /// Keeps an existing guide in step with the graph. A guide nobody asked for is never created.
    func refreshAgentGuideIfPresent() {
        guard FileManager.default.fileExists(atPath: guidePath) else { return }
        Task { _ = await writeAgentGuide() }
    }

    /// The optional Python modules graphify can import, or nil when graphify isn't found.
    func graphifyModules() async -> Set<String>? {
        guard let python = graphifyPython else { return nil }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: GraphifyModules.available(python: python))
            }
        }
    }

    func moduleInstallCommand(_ modules: [String]) -> String {
        GraphifyModules.installCommand(modules: modules, python: graphifyPython, home: agentHome)
    }

    /// Puts graphify's skill into a coding tool. Returns an error message, or nil when it worked.
    func installSkill(_ tool: CodingTool) async -> String? {
        let home = agentHome
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try GraphifyCommand.installSkill(tool, home: home)
                    continuation.resume(returning: nil)
                } catch {
                    continuation.resume(returning: error.localizedDescription)
                }
            }
        }
    }

    /// The model Graphitree's rebuild reads docs with. Until someone picks one, it's the first that's
    /// set up, so connecting Claude Code is enough.
    func docsPass() -> DocsPass? {
        let stored = UserDefaults.standard.string(forKey: BuildChoice.defaultsKey) ?? BuildChoice.automatic
        let options = BuildChoice.options(home: agentHome, store: .standard).map(\.id)
        guard let id = BuildChoice.resolve(stored, options: options) else { return nil }
        return BuildChoice.docsPass(for: id, home: agentHome, store: .standard)
    }

    // MARK: - AI connections

    /// Every model that can build right now. Read again whenever a connection changes.
    private(set) var aiOptions: [ModelOption] = []
    /// What each connection's last check found, by coding tool or provider id.
    private(set) var connectionHealth: [String: ConnectionHealth] = [:]
    private(set) var checkingConnections: Set<String> = []
    private(set) var connectionsCheckedAt: Date?
    /// Whether the "Connect an AI model" screen is up. Decided at launch, so it stays to say
    /// what was connected, and closed by Continue or Not now.
    private(set) var firstRunOpen = false
    /// Where graphify is, or nil when it isn't installed. First run installs it.
    private(set) var graphifyPath: String?
    /// "Not now" on first run's graphify page, for this launch.
    private(set) var graphifySkipped = false
    /// While first run installs graphify, and what it's doing.
    private(set) var graphifyInstalling = false
    private(set) var graphifyStep: GraphifySetup.Step?
    private(set) var graphifyError: String?
    /// A connection AI Models should open at, set by a banner's Fix button.
    var modelsFocus: String?
    /// Problems the person closed, by id, so the same one isn't raised again.
    private var dismissedProblems: [String: String] = UserDefaults.standard.dictionary(forKey: "dismissedConnectionProblems") as? [String: String] ?? [:]
    @ObservationIgnored private var lastActiveCheck: Date = .distantPast

    private var storedBuildChoice: String {
        UserDefaults.standard.string(forKey: BuildChoice.defaultsKey) ?? BuildChoice.automatic
    }

    /// The model that builds the graph now, or nil for code only.
    var builderID: String? {
        _ = settingsRevision
        return BuildChoice.resolve(storedBuildChoice, options: aiOptions.map(\.id))
    }

    /// The problem the main window raises, if any.
    var raisedProblem: String? {
        ConnectionProblems.next(builder: builderID, health: connectionHealth, dismissed: dismissedProblems)
    }

    func refreshAIOptions() {
        let options = BuildChoice.options(home: agentHome, store: .standard).map { ModelOption(id: $0.id, name: $0.name) }
        if options != aiOptions { aiOptions = options }
        // A connection that's gone has nothing to report.
        for id in connectionHealth.keys where !options.contains(where: { $0.id == id }) { connectionHealth[id] = nil }
    }

    /// Checks every connection, or only the ones given. Problems that cleared can be raised again.
    func checkConnections(_ ids: [String]? = nil) async {
        refreshAIOptions()
        let targets = (ids ?? aiOptions.map(\.id)).filter { !checkingConnections.contains($0) }
        guard !targets.isEmpty else { return }
        checkingConnections.formUnion(targets)
        let home = agentHome
        await withTaskGroup(of: (String, ConnectionHealth?).self) { group in
            for id in targets {
                group.addTask { (id, await ConnectionChecker.check(id, home: home, store: .standard)) }
            }
            for await (id, found) in group {
                connectionHealth[id] = previewHealth(id) ?? found
                if connectionHealth[id]?.isProblem != true, dismissedProblems[id] != nil {
                    dismissedProblems[id] = nil
                    UserDefaults.standard.set(dismissedProblems, forKey: "dismissedConnectionProblems")
                }
            }
        }
        checkingConnections.subtract(targets)
        if ids == nil { connectionsCheckedAt = .now }
    }

    /// `-claudeSignInPreview signedOut` or `endsSoon` shows a sign-in problem, for screenshots and checks.
    private func previewHealth(_ id: String) -> ConnectionHealth? {
        guard id == "claude-code", let preview = UserDefaults.standard.string(forKey: "claudeSignInPreview") else { return nil }
        let signIn: ClaudeSignIn
        switch preview {
        case "signedOut": signIn = ClaudeSignIn(loggedIn: false)
        case "endsSoon": signIn = ClaudeSignIn(loggedIn: true, method: "claude.ai", plan: "max", expiresAt: .now.addingTimeInterval(2 * 86400 - 600))
        default: return nil
        }
        return ConnectionCheck.claudeCode(signIn, now: .now)
    }

    /// Makes a model the one that builds the graph, which also finishes first-run setup.
    func useForBuilds(_ id: String) {
        UserDefaults.standard.set(id, forKey: BuildChoice.defaultsKey)
        if id != BuildChoice.codeOnly { UserDefaults.standard.set(true, forKey: FirstRun.doneKey) }
        settingsRevision += 1
    }

    /// After a model is connected: if nothing builds yet, it does.
    func connected(_ id: String) {
        refreshAIOptions()
        if builderID == nil || !BuildChoice.isChosen(storedBuildChoice) { useForBuilds(id) }
        Task { await checkConnections([id]) }
    }

    /// After a model is removed.
    func disconnected(_ id: String) {
        if storedBuildChoice == id { UserDefaults.standard.set(BuildChoice.automatic, forKey: BuildChoice.defaultsKey) }
        connectionHealth[id] = nil
        refreshAIOptions()
        settingsRevision += 1
    }

    func dismissProblem(_ id: String) {
        guard let found = connectionHealth[id] else { return }
        dismissedProblems[id] = found.problemKey
        UserDefaults.standard.set(dismissedProblems, forKey: "dismissedConnectionProblems")
    }

    /// "Not now": code only for this launch. First run comes back next time.
    func skipFirstRun() {
        if !aiOptions.isEmpty && !BuildChoice.isChosen(storedBuildChoice) {
            UserDefaults.standard.set(BuildChoice.codeOnly, forKey: BuildChoice.defaultsKey)
            settingsRevision += 1
        }
        firstRunOpen = false
    }

    func closeFirstRun() { firstRunOpen = false }

    /// Whether first run still has a model to connect.
    var needsModelSetup: Bool {
        FirstRun.shows(
            hasOptions: !aiOptions.isEmpty,
            stored: storedBuildChoice,
            isDone: UserDefaults.standard.bool(forKey: FirstRun.doneKey),
            skippedThisLaunch: false
        )
    }

    /// First run shows its graphify page while graphify is missing, unless that's skipped.
    var needsGraphify: Bool { graphifyPath == nil && !graphifySkipped }

    /// Looks for graphify again, such as after it was installed in Terminal.
    func refreshGraphify() {
        graphifyPath = GraphRebuilder.locateGraphify()
        if graphifyPath != nil { graphifyError = nil }
    }

    /// Installs uv when it's missing, then graphify (`Shared/GraphifySetup.swift`).
    func installGraphify() {
        guard !graphifyInstalling else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        graphifyInstalling = true
        graphifyError = nil
        graphifyStep = GraphifySetup.locateUV(home: home) == nil ? .uv : .graphify
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = Result {
                try GraphifySetup.install(effects: .live(home: home)) { step in
                    Task { @MainActor in self?.graphifyStep = step }
                }
            }
            Task { @MainActor in
                guard let self else { return }
                self.graphifyInstalling = false
                switch outcome {
                case .success(let path):
                    self.graphifyPath = path
                    // So Uninstall Graphitree… can say Graphitree installed it.
                    UserDefaults.standard.set(true, forKey: GraphifySetup.installedKey)
                    if !self.needsModelSetup { self.firstRunOpen = false }
                case .failure(let error):
                    self.graphifyError = error.localizedDescription
                }
            }
        }
    }

    /// "Not now" on the graphify page: on to the model, or out of first run if that's set up.
    func skipGraphify() {
        graphifySkipped = true
        if !needsModelSetup { firstRunOpen = false }
    }

    /// Coming back to the app, such as after signing in in Terminal, checks what was wrong again.
    func appBecameActive() {
        let problems = connectionHealth.filter { $0.value.isProblem }.map(\.key)
        guard !problems.isEmpty, Date.now.timeIntervalSince(lastActiveCheck) > 15 else { return }
        lastActiveCheck = .now
        Task { await checkConnections(problems) }
    }

    /// Checks again every six hours while the app is open.
    private func connectionTick() async {
        guard Date.now.timeIntervalSince(connectionsCheckedAt ?? .distantPast) > ConnectionCheck.interval else { return }
        await checkConnections()
    }

    /// Opens Terminal on a command that needs the person, such as signing in through the browser.
    /// A small script file is opened rather than Terminal scripted, so no permission is asked.
    func runInTerminal(_ command: String) {
        let script = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-sign-in.command")
        let text = "#!/bin/zsh -l\nclear\n\(command)\necho\necho 'Done. Go back to Graphitree, which checks again.'\n"
        do {
            try text.write(to: script, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
            NSWorkspace.shared.open(script)
        } catch {
            errorMessage = "Couldn't open Terminal: \(error.localizedDescription)"
        }
    }

    /// `claude auth login`, run with the copy of Claude Code Graphitree builds with.
    func signInToClaudeCode() {
        guard let command = ToolLocator.command(["claude"], home: agentHome) else { return }
        runInTerminal("'\(command)' auth login")
    }

    // MARK: - Playbook

    /// The playbook lives next to the guide.
    var playbookDirectory: URL { outDirectory }

    func loadPlaybook() -> Playbook { PlaybookFile.load(from: playbookDirectory) }

    /// Writes the playbook, its copy for the graph, and the guide, which carries its picks.
    /// `directory` is the graph the playbook was loaded from: after a switch to another graph, an
    /// edit still lands in its own. Returns an error message or nil.
    func savePlaybook(_ playbook: Playbook, in directory: URL? = nil) -> String? {
        let directory = directory ?? playbookDirectory
        let root = GraphSource(outDirectory: directory).rootPath
        do {
            try PlaybookFile.save(playbook, to: directory)
            if PlaybookFile.addsToGraph(root: root) { try PlaybookFile.writeGraphCopy(playbook, root: root) }
        } catch {
            return error.localizedDescription
        }
        if directory.standardizedFileURL == playbookDirectory.standardizedFileURL { refreshAgentGuideIfPresent() }
        return nil
    }

    /// Whether a copy of the playbook sits under the graph's root, where graphify's docs pass reads it.
    var playbookAddsToGraph: Bool {
        PlaybookFile.addsToGraph(root: graphRoot)
    }

    func setPlaybookAddsToGraph(_ adds: Bool) {
        UserDefaults.standard.set(adds, forKey: PlaybookFile.graphCopyDefaultsKey)
        if adds {
            let playbook = loadPlaybook()
            if !playbook.isEmpty { try? PlaybookFile.writeGraphCopy(playbook, root: graphRoot) }
        } else {
            PlaybookFile.removeGraphCopy(root: graphRoot)
        }
        settingsRevision += 1
    }

    /// The playbook copy changed after the graph was built, so a docs rebuild would update it.
    var playbookIsNewerThanGraph: Bool {
        guard playbookAddsToGraph, let builtAt = snapshot?.overview.builtAt else { return false }
        return PlaybookFile.graphCopyIsNewer(than: builtAt, root: graphRoot)
    }

    // MARK: - Claude Code's memory

    /// Only for a root that holds projects, never inside one repo.
    var canCopyMemory: Bool { MemoryCopy.canCopy(root: graphRoot) }

    /// Whether a copy of Claude Code's memory sits under the graph's root, where graphify's docs pass reads it.
    var memoryAddsToGraph: Bool {
        _ = settingsRevision
        return canCopyMemory && MemoryCopy.isOn()
    }

    func memoryPlan() -> MemoryCopy.Plan {
        MemoryCopy.plan(root: graphRoot, home: agentHome, map: folderMap())
    }

    /// Brings the copy in line with Claude Code's notes, when it's on. Returns an error message or nil.
    @discardableResult
    func refreshMemoryCopy() -> String? {
        guard memoryAddsToGraph else { return nil }
        do {
            try MemoryCopy.write(memoryPlan(), root: graphRoot)
        } catch {
            return error.localizedDescription
        }
        return nil
    }

    /// Turning it off takes Graphitree's copies away. The graph keeps their nodes until a rebuild
    /// that allows a smaller graph.
    @discardableResult
    func setMemoryAddsToGraph(_ adds: Bool) -> String? {
        UserDefaults.standard.set(adds, forKey: MemoryCopy.defaultsKey)
        settingsRevision += 1
        guard adds else {
            MemoryCopy.remove(root: graphRoot)
            return nil
        }
        return refreshMemoryCopy()
    }

    /// A copy changed after the graph was built, so a docs rebuild would bring it in.
    var memoryIsNewerThanGraph: Bool {
        guard memoryAddsToGraph, let builtAt = snapshot?.overview.builtAt else { return false }
        return MemoryCopy.isNewer(than: builtAt, root: graphRoot)
    }

    // MARK: - Setup

    /// Reads the saved record; `settingsRevision` makes views that ask notice when it changes.
    var isSetUp: Bool {
        _ = settingsRevision
        return SetupRecord.standard.isSetUp(root: graphRoot)
    }

    var setupAppliedAt: Date? {
        _ = settingsRevision
        return SetupRecord.standard.appliedAt(root: graphRoot)
    }

    func nodeCount(inProject project: String) async -> Int {
        await ask(0) { try $0.nodeCount(inProject: project) }
    }

    func graphSettings() -> GraphSettings { GraphSettings.read(root: graphRoot) }

    func scanStack() async -> StackScanResult {
        let projects = await projectSizes().map(\.project)
        let root = graphRoot
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: StackScan.scan(root: root, projects: projects))
            }
        }
    }

    /// Asks Claude Code to describe libraries, a few per call. Returns drafts by library id.
    func draftLibraries(_ libraries: [PlaybookLibrary]) async -> Result<[UUID: LibraryDraft], PlaybookError> {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard let claude = ToolLocator.command(["claude"], home: home) else {
            return .failure(PlaybookError(message: "Claude Code's claude command isn't installed where Graphitree looks for it."))
        }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Batches run side by side, so a long list takes about as long as one batch.
                let batches = stride(from: 0, to: libraries.count, by: PlaybookResearch.batchSize).map {
                    Array(libraries[$0..<min($0 + PlaybookResearch.batchSize, libraries.count)])
                }
                let lock = NSLock()
                var found: [UUID: LibraryDraft] = [:]
                var lastError: String?
                DispatchQueue.concurrentPerform(iterations: batches.count) { index in
                    do {
                        let matched = PlaybookResearch.match(try PlaybookResearch.run(batches[index], claude: claude), to: batches[index])
                        lock.lock()
                        found.merge(matched) { _, new in new }
                        lock.unlock()
                    } catch {
                        lock.lock()
                        lastError = error.localizedDescription
                        lock.unlock()
                    }
                }
                if found.isEmpty, let lastError {
                    continuation.resume(returning: .failure(PlaybookError(message: lastError)))
                } else {
                    continuation.resume(returning: .success(found))
                }
            }
        }
    }

    // MARK: - Playbook chat

    /// The model the chat talks to: the one Build uses, or the first one set up.
    func chatEngine() -> Result<ChatEngine, PlaybookError> {
        _ = settingsRevision
        let stored = UserDefaults.standard.string(forKey: BuildChoice.defaultsKey) ?? BuildChoice.automatic
        return ChatEngine.resolve(stored: stored, home: agentHome, store: .standard)
    }

    func loadChatIfNeeded() {
        guard chatLoadedFor != outDirectory else { return }
        chatTurns = ChatStore.load(for: outDirectory)
        chatLoadedFor = outDirectory
    }

    func sendChat(_ text: String, playbook: Playbook, scan: StackScanResult?, extraContext: String? = nil) {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isChatting else { return }
        loadChatIfNeeded()
        chatTurns.append(ChatTurn(role: .user, text: message))
        ChatStore.save(chatTurns, for: outDirectory)
        let engine: ChatEngine
        switch chatEngine() {
        case .success(let found): engine = found
        case .failure(let error):
            chatTurns.append(ChatTurn(role: .assistant, text: error.message, isError: true))
            ChatStore.save(chatTurns, for: outDirectory)
            return
        }
        let process = ChatProcess()
        chatProcess = process
        isChatting = true
        chatStartedAt = .now
        let turns = chatTurns
        let directory = outDirectory
        chatTask = Task { [weak self] in
            let reply: ChatTurn
            do {
                let answer = try await PlaybookChat.send(turns, playbook: playbook, scan: scan, engine: engine, extraContext: extraContext) { process.started($0) }
                reply = ChatTurn(role: .assistant, text: answer.text.isEmpty ? "No answer came back." : answer.text, changes: answer.changes, isError: answer.text.isEmpty && answer.changes.isEmpty)
            } catch {
                reply = ChatTurn(role: .assistant, text: process.wasStopped || Task.isCancelled ? "Stopped." : error.localizedDescription, isError: true)
            }
            guard let self else { return }
            self.isChatting = false
            self.chatStartedAt = nil
            self.chatProcess = nil
            self.addTurn(reply, toChatOf: directory)
        }
    }

    /// Adds a turn to a graph's chat. When the person switched graphs while it was coming, it
    /// goes into that graph's saved chat, not the one on screen.
    private func addTurn(_ turn: ChatTurn, toChatOf directory: URL) {
        if outDirectory == directory {
            loadChatIfNeeded()
            chatTurns.append(turn)
            ChatStore.save(chatTurns, for: directory)
        } else {
            ChatStore.save(ChatStore.load(for: directory) + [turn], for: directory)
        }
    }

    func stopChat() {
        chatProcess?.stop()
        chatTask?.cancel()
    }

    func setChange(_ changeID: UUID, in turnID: UUID, to state: PlaybookChange.State) {
        guard let turn = chatTurns.firstIndex(where: { $0.id == turnID }),
              let change = chatTurns[turn].changes.firstIndex(where: { $0.id == changeID }) else { return }
        chatTurns[turn].changes[change].state = state
        ChatStore.save(chatTurns, for: outDirectory)
    }

    func clearChat() {
        guard !isChatting else { return }
        chatTurns = []
        ChatStore.save([], for: outDirectory)
    }

    func githubAccounts() async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { continuation.resume(returning: PlaybookBackup.accounts()) }
        }
    }

    /// Creates the private repo when `create` is set, then backs up the playbook in `directory`
    /// (the current graph's when nil). Returns the remote URL. When the repo has a playbook this
    /// Mac hasn't seen, the error carries it, unless `replacing` says to back up over it. The
    /// graph's backup settings record the outcome either way.
    func backUpPlaybook(remote: String?, createNamed name: String?, account: String, from directory: URL? = nil, replacing: Bool = false) async -> Result<String, PlaybookError> {
        let directory = directory ?? playbookDirectory
        let result: Result<String, PlaybookError> = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var url = remote ?? ""
                // An empty playbook has nothing to push, so a repo is only any use when it
                // already holds one to bring here: it's never created empty.
                let isEmpty = PlaybookFile.load(from: directory).isEmpty && !PlaybookFile.isUnreadable(in: directory)
                do {
                    if let name {
                        url = "https://github.com/\(account)/\(name).git"
                        if !isEmpty {
                            do {
                                url = try PlaybookBackup.createRepo(named: name, account: account)
                            } catch let error as PlaybookError where error.message.contains("already exists") {}
                        }
                    }
                    try PlaybookBackup.backUp(from: directory, remote: url, account: account, replacing: replacing)
                    continuation.resume(returning: .success(url))
                } catch let error as PlaybookError {
                    if name != nil, isEmpty, error.remoteCopy == nil {
                        let place = url.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: ".git", with: "")
                        continuation.resume(returning: .failure(PlaybookError(message: "\(place) has no playbook to bring here. Add something to the playbook first, then set up the repo.")))
                    } else {
                        continuation.resume(returning: .failure(error))
                    }
                } catch {
                    continuation.resume(returning: .failure(PlaybookError(message: error.localizedDescription)))
                }
            }
        }
        PlaybookBackupStore.update(for: directory) { settings in
            switch result {
            case .success(let url):
                settings.remote = url
                settings.account = account
                settings.lastBackup = .now
                settings.problem = nil
            case .failure(let error):
                settings.problem = error.message
            }
        }
        return result
    }

    /// Replaces the playbook in `directory` with the repo's latest, keeping this Mac's beside it
    /// as playbook.replaced-<time>.json. Returns the playbook now in place.
    func restorePlaybook(remote: String, account: String, into directory: URL? = nil) async -> Result<Playbook, PlaybookError> {
        let directory = directory ?? playbookDirectory
        let fetched: Result<(playbook: Playbook, commit: String), PlaybookError> = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: .success(try PlaybookBackup.takeRemoteCopy(remote: remote, account: account)))
                } catch let error as PlaybookError {
                    continuation.resume(returning: .failure(error))
                } catch {
                    continuation.resume(returning: .failure(PlaybookError(message: error.localizedDescription)))
                }
            }
        }
        let copy: (playbook: Playbook, commit: String)
        switch fetched {
        case .success(let found): copy = found
        case .failure(let error): return .failure(error)
        }
        if !PlaybookFile.load(from: directory).isEmpty {
            do {
                try PlaybookFile.keepAside(in: directory, as: "replaced")
            } catch {
                return .failure(PlaybookError(message: "Couldn't keep this Mac's playbook aside, so nothing was replaced: \(error.localizedDescription)"))
            }
        }
        if let error = savePlaybook(copy.playbook, in: directory) { return .failure(PlaybookError(message: error)) }
        PlaybookBackup.markSynced(copy.commit, in: PlaybookBackup.mirror(for: remote))
        PlaybookBackupStore.update(for: directory) { settings in
            settings.github = true
            settings.remote = remote
            settings.account = account
            settings.lastBackup = .now
            settings.problem = nil
        }
        return .success(PlaybookFile.load(from: directory))
    }

    func projectSizes() async -> [ProjectSize] {
        await ask([ProjectSize]()) { try $0.projectSizes().map { ProjectSize(project: $0.project, nodes: $0.nodes) } }
    }

    /// Writes the setup wizard's choices to the graph's root folder, backing each file up first.
    /// Returns an error message, or nil when it worked.
    func applySetup(ignoreLines: [String], answerSize: AnswerSize, reach: AnswerReach) -> String? {
        let root = graphRoot as NSString
        do {
            let ignorePath = root.appendingPathComponent(".graphifyignore")
            let ignoreText = (try? String(contentsOfFile: ignorePath, encoding: .utf8)) ?? ""
            let updatedIgnore = IgnoreFile.adding(ignoreLines, to: ignoreText, note: "Added by Graphitree's setup, \(Date.now.formatted(date: .abbreviated, time: .omitted))")
            if updatedIgnore != ignoreText {
                try AgentSetup.backUp(ignorePath)
                try AgentSetup.write(updatedIgnore, to: ignorePath)
            }
            let rcPath = root.appendingPathComponent(".graphifyrc")
            let rcText = (try? String(contentsOfFile: rcPath, encoding: .utf8)) ?? ""
            let updatedRC = RCFile.setting([(RCFile.budgetKey, String(answerSize.rawValue)), (RCFile.depthKey, String(reach.rawValue))], in: rcText)
            if updatedRC != rcText {
                try AgentSetup.backUp(rcPath)
                try AgentSetup.write(updatedRC, to: rcPath)
            }
            SetupRecord.standard.markApplied(root: graphRoot)
            settingsRevision += 1
            refreshAgentGuideIfPresent()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func reviewScene(for finding: Finding) async -> GraphScene? {
        await ask(nil) { try $0.reviewScene(for: finding) }
    }

    func location(ofNode id: String) async -> NodeLocation? {
        await ask(nil) { try $0.location(ofNode: id) }
    }

    // MARK: - Rebuild

    func startRebuild(force: Bool, docs: DocsPass? = nil, quiet: Bool = false) {
        guard !isRebuilding, let overview = snapshot?.overview else { return }
        let source = GraphSource(outDirectory: outDirectory)
        let rebuilder = GraphRebuilder()
        self.rebuilder = rebuilder
        isRebuilding = true
        rebuildIsQuiet = quiet
        rebuildLog = ""
        rebuildResult = nil
        pendingChangeAt = nil
        // Claude Code adds notes between rebuilds, so the copy catches up first.
        if let problem = refreshMemoryCopy() {
            appendRebuildLog("Couldn't update the copy of Claude Code's memory: \(problem)\n")
        }
        if let docs {
            // A sign-in or key that stopped working shows up while the rebuild runs, not after.
            if let builder = builderID { Task { await checkConnections([builder]) } }
            let estimate = docsEstimate
            let cost = estimate.map { DocsCost.estimate($0, backend: docs.backend, history: DocsRunLog.load()) }
            docsRunStarted = (.now, docs.backend, estimate?.files.count ?? 0, cost?.inputTokens ?? 0)
        } else {
            docsRunStarted = nil
        }
        let nodesBefore = overview.nodes
        let edgesBefore = overview.edges

        // graphify can run for minutes, so it stays off the workspace queue and decisions keep working.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = Result {
                try rebuilder.run(source: source, force: force, docs: docs) { text in
                    Task { @MainActor in self?.appendRebuildLog(text) }
                }
            }
            Task { @MainActor in
                guard let self else { return }
                switch outcome {
                case .failure(let error):
                    self.finishRebuild(nil)
                    self.errorMessage = error.localizedDescription
                case .success(let run):
                    if run.cancelled {
                        self.finishRebuild(.cancelled)
                    } else if run.refusedToShrink {
                        self.finishRebuild(.refusedToShrink)
                    } else if run.status != 0 {
                        self.finishRebuild(.failed(exitCode: run.status))
                    } else {
                        self.reloadAfterRebuild(source: source, nodesBefore: nodesBefore, edgesBefore: edgesBefore)
                    }
                }
            }
        }
    }

    func cancelRebuild() {
        rebuilder?.cancel()
    }

    private func finishRebuild(_ result: RebuildResult?) {
        isRebuilding = false
        rebuilder = nil
        rebuildResult = result
        // A docs pass is logged with graphify's own token count, so later estimates learn from it.
        if let started = docsRunStarted {
            docsRunStarted = nil
            let reported = DocsRunLog.reportedTokens(in: rebuildLog)
            DocsRunLog.append(DocsRun(
                date: started.date, backend: started.backend, files: started.files, estimatedInput: started.estimatedInput,
                actualInput: reported?.input, actualOutput: reported?.output, seconds: Int(Date.now.timeIntervalSince(started.date))
            ))
            if case .finished = result {
                freshness.lastDocsPass = started.date
                waitingDocsPass = nil
                docsEstimate = nil
            }
        }
        if rebuildIsQuiet {
            switch result {
            case .finished(let report):
                let change = report.nodesAfter - report.nodesBefore
                lastQuietUpdate = (.now, change == 0 ? "no change" : "\(change > 0 ? "+" : "")\(change.formatted()) nodes")
            case .refusedToShrink:
                lastQuietUpdate = (.now, "skipped: code was deleted, so it needs a rebuild that allows a smaller graph")
            case .failed(let code):
                lastQuietUpdate = (.now, "graphify stopped with exit \(code)")
            case .cancelled, nil:
                break
            }
        }
        loadedGraphDate = graphFileDate
        if case .finished = result { runDueBackups() }
    }

    private func appendRebuildLog(_ text: String) {
        rebuildLog += text
        if rebuildLog.count > 200_000 { rebuildLog = String(rebuildLog.suffix(150_000)) }
    }

    private func reloadAfterRebuild(source: GraphSource, nodesBefore: Int, edgesBefore: Int) {
        loadGeneration += 1
        let generation = loadGeneration
        workQueue.async { [weak self] in
            let result = Result {
                try Workspace.reopenAfterRebuild(
                    source: source,
                    cacheDirectory: try GraphIndex.defaultCacheDirectory(),
                    nodesBefore: nodesBefore,
                    edgesBefore: edgesBefore
                )
            }
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let reopened):
                    if generation == self.loadGeneration {
                        self.workspace = reopened.workspace
                        self.state = .ready(reopened.snapshot)
                        self.revision += 1
                        // Each labelled folder's slice is cut again from the new graph, then the guide points at them.
                        Task {
                            _ = await self.writeFolderSlices()
                            self.refreshAgentGuideIfPresent()
                        }
                    }
                    self.finishRebuild(.finished(reopened.report))
                case .failure(let error):
                    self.finishRebuild(nil)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Folders

    private static let mappedRootsKey = "mappedRoots"

    /// Folders the person has asked Graphitree to map, newest first.
    var mappedRoots: [String] { UserDefaults.standard.stringArray(forKey: Self.mappedRootsKey) ?? [] }

    private func remember(root: String) {
        let path = URL(fileURLWithPath: root).standardizedFileURL.path
        let roots = [path] + mappedRoots.filter { $0 != path }
        UserDefaults.standard.set(Array(roots.prefix(20)), forKey: Self.mappedRootsKey)
    }

    /// Opens the graph for any folder. A folder without one gets a graph built from its code
    /// first, which needs no AI model. Picking a graphify-out folder opens it directly.
    func mapFolder(_ url: URL) {
        guard !isRebuilding else {
            errorMessage = "Wait for the rebuild to finish before mapping another folder."
            return
        }
        let folder = url.standardizedFileURL
        let fileManager = FileManager.default
        if folder.lastPathComponent == "graphify-out", fileManager.fileExists(atPath: folder.appendingPathComponent("graph.json").path) {
            remember(root: GraphSource(outDirectory: folder).rootPath)
            choose(folder)
            refreshCatalog()
            return
        }
        let out = folder.appendingPathComponent("graphify-out", isDirectory: true)
        remember(root: folder.path)
        if fileManager.fileExists(atPath: out.appendingPathComponent("graph.json").path) {
            choose(out)
            refreshCatalog()
            return
        }
        let source = GraphSource(outDirectory: out)
        let rebuilder = GraphRebuilder()
        self.rebuilder = rebuilder
        isRebuilding = true
        rebuildLog = ""
        rebuildResult = nil
        state = .loading(.mapping)
        workspace = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = Result {
                try rebuilder.run(source: source, force: false) { text in
                    Task { @MainActor in self?.appendRebuildLog(text) }
                }
            }
            Task { @MainActor in
                guard let self else { return }
                self.isRebuilding = false
                self.rebuilder = nil
                switch outcome {
                case .success(let run) where run.status == 0 && !run.cancelled:
                    self.choose(out)
                    self.refreshCatalog()
                case .success(let run):
                    self.errorMessage = run.cancelled ? "Mapping \(folder.lastPathComponent) was cancelled." : "graphify couldn't map \(folder.lastPathComponent) (exit \(run.status)). \(self.rebuildLog.suffix(400))"
                    self.load()
                case .failure(let error as RebuildError) where error == .graphifyNotFound:
                    // Back to first run's graphify page, which installs it. Then map again.
                    self.graphifySkipped = false
                    self.refreshGraphify()
                    self.firstRunOpen = true
                    self.load()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.load()
                }
            }
        }
    }

    func folderMap() -> FolderMap? {
        _ = settingsRevision
        return FolderFile.load(from: outDirectory)
    }

    /// Every repo that can hold a pointer for cloud agents, with the block it would get now.
    func pointerRepos() async -> [PointerRepo] {
        let scan = await scanFolders()
        let labels = FolderScan.labels(saved: folderMap(), scan: scan)
        return PointerRepo.list(scan: scan, labels: labels, root: graphRoot) { repoPointerBlock(for: $0, labels: labels) }
    }

    func scanFolders() async -> FolderScanResult {
        let root = graphRoot
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: FolderScan.scan(root: root))
            }
        }
    }

    private var ignorePath: String { (graphRoot as NSString).appendingPathComponent(".graphifyignore") }

    /// The patterns in the root's `.graphifyignore`.
    func ignoredPatterns() -> Set<String> {
        _ = settingsRevision
        return IgnoreFile.patterns(in: (try? String(contentsOfFile: ignorePath, encoding: .utf8)) ?? "")
    }

    /// Adds and removes `.graphifyignore` lines, backing the file up first. Returns an error or nil.
    private func changeIgnoreFile(adding: [String], removing: [String], note: String) -> String? {
        let text = (try? String(contentsOfFile: ignorePath, encoding: .utf8)) ?? ""
        let updated = IgnoreFile.adding(adding, to: IgnoreFile.removing(removing.filter { !adding.contains($0) }, from: text), note: note)
        guard updated != text else { return nil }
        do {
            try AgentSetup.backUp(ignorePath)
            try AgentSetup.write(updated, to: ignorePath)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Saves the folder labels: `folders.json`, the lines that leave folders out, each folder's
    /// slice of the graph, then reopens the graph so projects and areas follow the labels.
    func saveFolders(_ labels: [FolderLabel], reloads: Bool = true) async -> String? {
        let out = outDirectory
        let root = graphRoot
        do {
            // Keep what Arrange saved alongside the labels.
            var map = FolderFile.load(from: out) ?? FolderMap()
            map.folders = labels
            try FolderFile.save(map, to: out)
        } catch {
            return "Couldn't save the labels: \(error.localizedDescription)"
        }
        let changes = FolderIgnore.changes(for: labels)
        if let failure = changeIgnoreFile(adding: changes.add, removing: changes.remove, note: "Left out in Graphitree's Folders, \(Date.now.formatted(date: .abbreviated, time: .omitted))") {
            return "Labels saved, but .graphifyignore couldn't be changed: \(failure)"
        }
        FolderScan.forgetDetectedGroups(root: root)
        let failure = await writeFolderSlices(labels: labels)
        settingsRevision += 1
        // A rebuild that follows reopens the graph itself; otherwise reopen now so projects and areas follow the labels.
        if reloads {
            refreshesGuideAfterLoad = true
            load()
        }
        return failure.map { "Labels saved, but \($0)" }
    }

    /// Cuts a slice of the graph for each included folder, and a graph per separate graph, from one
    /// read of graph.json. Nothing happens without labels.
    private func writeFolderSlices(labels: [FolderLabel]? = nil, arrangement: Arrangement? = nil) async -> String? {
        let out = outDirectory
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: GraphSlicing.writeAll(outDirectory: out, labels: labels, arrangement: arrangement))
            }
        }
    }

    /// Leaves repos out of the graph from the next rebuild on. Returns an error or nil.
    func leaveOut(_ paths: [String]) -> String? {
        let failure = changeIgnoreFile(adding: paths.map(FolderIgnore.line(for:)), removing: [], note: "Left out from a Graphitree tidy-up tip, \(Date.now.formatted(date: .abbreviated, time: .omitted))")
        settingsRevision += 1
        return failure
    }

    /// Moves top-level items into a folder, one at a time, stopping at the first problem. The
    /// arrangement follows a project that moves.
    func move(_ paths: [String], into folder: String) async -> String? {
        guard !isRebuilding else { return "A rebuild is running. Move it once the rebuild finishes." }
        let root = graphRoot
        let out = outDirectory
        let arrangement = await loadArrangement()
        let failure: String? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var current = arrangement
                for path in paths {
                    do {
                        try FolderMoves.move(path, into: folder, root: root, log: out, arrangement: current)
                        current = current.carried(from: path, to: folder + "/" + (path as NSString).lastPathComponent).arrangement
                    } catch {
                        continuation.resume(returning: error.localizedDescription)
                        return
                    }
                }
                continuation.resume(returning: nil)
            }
        }
        await afterMove()
        return failure
    }

    var lastFolderMove: FolderMove? {
        _ = settingsRevision
        return FolderMoves.load(from: outDirectory).last
    }

    /// Puts the last move back, with its fix-ups.
    func undoLastMove() async -> String? {
        guard !isRebuilding else { return "A rebuild is running. Undo the move once it finishes." }
        let root = graphRoot
        let out = outDirectory
        let arrangement = await loadArrangement()
        let failure: String? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FolderMoves.undoLast(root: root, log: out, arrangement: arrangement)
                    continuation.resume(returning: nil)
                } catch {
                    continuation.resume(returning: error.localizedDescription)
                }
            }
        }
        await afterMove()
        return failure
    }

    /// Why a move has to wait: a rebuild here, or graphify working elsewhere.
    var moveBusyReason: String? {
        if isRebuilding { return "A rebuild is running. Move it once the rebuild finishes." }
        if graphifyIsBusy { return "graphify is building right now, maybe from the background job. Move it once that finishes." }
        return nil
    }

    /// Everything the move sheet shows: what stops it, what it updates, git, and what's up to you.
    func checkMove(_ request: MoveRequest, arrangement: Arrangement) async -> MoveCheck {
        let root = graphRoot
        let out = outDirectory
        let busy = moveBusyReason
        let confirmed = BackupJob.confirmedLogins(.standard)
        let playbook = loadPlaybook()
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let accounts = BackupJob.accounts(for: arrangement, root: root, confirmed: confirmed)
                continuation.resume(returning: FolderMoves.check(request, root: root, outDirectory: out, arrangement: arrangement, rules: accounts.rules, accounts: accounts, busy: busy, playbook: playbook))
            }
        }
    }

    /// Moves or renames a project's folder, then cuts the graph again and reopens it so the map
    /// follows. `remote` points its remote somewhere new.
    func performMove(_ request: MoveRequest, arrangement: Arrangement, remote: String?) async -> Result<FolderMove, PlaybookError> {
        if let busy = moveBusyReason { return .failure(PlaybookError(message: busy)) }
        let root = graphRoot
        let out = outDirectory
        let result: Result<FolderMove, PlaybookError> = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: .success(try FolderMoves.perform(request, root: root, outDirectory: out, arrangement: arrangement, remote: remote)))
                } catch let error as PlaybookError {
                    continuation.resume(returning: .failure(error))
                } catch {
                    continuation.resume(returning: .failure(PlaybookError(message: error.localizedDescription)))
                }
            }
        }
        await afterMove()
        return result
    }

    /// Makes a folder at the top of the root, labelled to hold projects, for moving repos into.
    func newFolder(_ name: String, purpose: FolderPurpose) -> String? {
        do {
            try FolderMoves.newFolder(name, root: graphRoot)
            var map = FolderFile.load(from: outDirectory) ?? FolderMap()
            map.folders.append(FolderLabel(path: name, purpose: purpose, holdsProjects: true))
            try FolderFile.save(map, to: outDirectory)
            settingsRevision += 1
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// After a move or undo: forget cached folder lists, cut the graph again for the new
    /// arrangement and reopen it so the map's areas follow.
    private func afterMove() async {
        FolderScan.forgetDetectedGroups(root: graphRoot)
        settingsRevision += 1
        _ = await writeFolderSlices()
        refreshesGuideAfterLoad = true
        load()
    }

    /// Cleanup rules that named a moved folder's old path and can follow it now: the graph has
    /// been rebuilt, so their nodes exist under the new ids.
    func rulesToCarry() async -> [RuleCarry] {
        let out = outDirectory
        let moves = Array(FolderMoves.load(from: out).suffix(10))
        guard !moves.isEmpty, let log = try? CurationLog(url: out.appendingPathComponent("curation.jsonl")), !log.entries.isEmpty else { return [] }
        let entries = log.entries
        let graph = GraphSource(outDirectory: out).graphURL
        return await withCheckedContinuation { (continuation: CheckedContinuation<[RuleCarry], Never>) in
            DispatchQueue.global(qos: .utility).async {
                let nodes = (try? GraphPartition.read(graph))?["nodes"] as? [[String: Any]] ?? []
                let ids = Set(nodes.compactMap { $0["id"] as? String })
                var found: [RuleCarry] = []
                for move in moves {
                    let rules = FolderMoves.carriedRules(entries, from: move.from, to: move.to, nodeExists: { ids.contains($0) })
                    if !rules.isEmpty { found.append(RuleCarry(move: move, rules: rules)) }
                }
                continuation.resume(returning: found)
            }
        }
    }

    /// Writes the rules again for the new path and withdraws the old ones, in one batch each.
    func carryRules(_ rules: [CarriedRule]) {
        perform(rules.map(\.action))
        undo(ruleIDs: rules.map(\.id))
    }

    // MARK: - Arrange and back up

    /// Undo for the open panel's own draft, which ⌘Z runs instead of undoing a cleanup decision.
    struct PanelUndo {
        let title: String
        let run: @MainActor () -> Void
    }

    var panelUndo: PanelUndo?

    /// Node counts by project in the open graph.
    func nodesByProject() async -> [String: Int] {
        await ask([:]) { workspace in
            Dictionary(try workspace.projectSizes().map { ($0.project, $0.nodes) }, uniquingKeysWith: +)
        }
    }

    /// The arrangement as saved, with the projects on disk now and their sizes in the graph.
    func loadArrangement(scan given: FolderScanResult? = nil) async -> Arrangement {
        let scan: FolderScanResult
        if let given { scan = given } else { scan = await scanFolders() }
        _ = settingsRevision
        let sizes = await nodesByProject()
        let out = outDirectory
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: BackupJob.arrangement(outDirectory: out, graph: nil, scan: scan, nodes: sizes))
            }
        }
    }

    /// Saves the arrangement: `folders.json`, `graphs.json`, the lines that leave projects out, and
    /// each folder's slice, then reopens the graph so the map follows it.
    func saveArrangement(_ arrangement: Arrangement) async -> String? {
        let out = outDirectory
        do {
            try FolderFile.save(arrangement.folderMap, to: out)
            try GraphPlans.save(arrangement.graphs, to: out)
        } catch {
            return "Couldn't save the arrangement: \(error.localizedDescription)"
        }
        syncBackgroundJob()
        let changes = arrangement.ignoreChanges
        if let failure = changeIgnoreFile(adding: changes.add, removing: changes.remove, note: "Left out in Graphitree's Arrange, \(Date.now.formatted(date: .abbreviated, time: .omitted))") {
            return "Saved, but .graphifyignore couldn't be changed: \(failure)"
        }
        FolderScan.forgetDetectedGroups(root: graphRoot)
        let failure = await writeFolderSlices(labels: arrangement.labels, arrangement: arrangement)
        settingsRevision += 1
        refreshesGuideAfterLoad = true
        load()
        return failure.map { "Saved, but \($0)" }
    }

    /// Saves only the graphs and their backups, for changes made in Back Up.
    func saveGraphPlans(_ graphs: [GraphPlan]) -> String? {
        do {
            try GraphPlans.save(graphs, to: outDirectory)
            settingsRevision += 1
            return syncBackgroundJob()
        } catch {
            return "Couldn't save the backup settings: \(error.localizedDescription)"
        }
    }

    /// The owner's git rules and gh logins, with the login for each rule: confirmed ones, else a
    /// guess from the remotes of repos under it.
    func gitAccounts(for arrangement: Arrangement) async -> GitAccounts {
        let root = graphRoot
        let confirmed = BackupJob.confirmedLogins(.standard)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: BackupJob.accounts(for: arrangement, root: root, confirmed: confirmed))
            }
        }
    }

    /// Remembers which login goes with a git rule (`""` for everything no rule covers).
    func confirmLogin(_ login: String, forRuleFolder folder: String) {
        var confirmed = BackupJob.confirmedLogins(.standard)
        confirmed[folder] = login
        UserDefaults.standard.set(confirmed, forKey: BackupJob.confirmedLoginsKey)
        settingsRevision += 1
    }

    /// Builds what a graph's backup would hold, without writing anything.
    func backupBundle(for graphID: String, arrangement: Arrangement) async -> Result<BackupBundle, PlaybookError> {
        let out = outDirectory
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: .success(try BackupContents.build(graphID: graphID, arrangement: arrangement, outDirectory: out)))
                } catch {
                    continuation.resume(returning: .failure(PlaybookError(message: error.localizedDescription)))
                }
            }
        }
    }

    /// Graphs backing up now, and each one's log.
    private(set) var backingUp: Set<String> = []
    private(set) var backupLogs: [String: String] = [:]

    func backupRecords() -> [String: BackupStore.Record] {
        _ = settingsRevision
        return BackupStore.records()
    }

    /// Backs one graph up: builds its files, commits them as `identity` and pushes. Returns the
    /// outcome's message, or the error.
    /// An automatic run never creates a repo: that waits for the person's own first backup.
    func backUp(graphID: String, arrangement: Arrangement, identity: GitIdentity?, message: String, automatic: Bool = false) async -> Result<String, PlaybookError> {
        guard !backingUp.contains(graphID), let graph = arrangement.graphs.first(where: { $0.id == graphID }) else {
            return .failure(PlaybookError(message: "That backup is already running."))
        }
        backingUp.insert(graphID)
        backupLogs[graphID] = ""
        defer {
            backingUp.remove(graphID)
            settingsRevision += 1
        }
        let out = outDirectory
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let log: (String) -> Void = { line in
                    Task { @MainActor [weak self] in self?.backupLogs[graphID, default: ""] += line + "\n" }
                }
                do {
                    log("Gathering \(graph.name)'s files")
                    let bundle = try BackupContents.build(graphID: graphID, arrangement: arrangement, outDirectory: out)
                    let outcome = try BackupRunner.run(bundle: bundle, graph: graph, identity: identity, message: message, createRepo: !automatic, ranFrom: automatic ? "app, on its own" : "app", log: log)
                    log(outcome.message)
                    continuation.resume(returning: .success(outcome.message))
                } catch {
                    log("Stopped: \(error.localizedDescription)")
                    continuation.resume(returning: .failure(PlaybookError(message: error.localizedDescription)))
                }
            }
        }
    }

    /// Runs the open graph's backups that are due: after a rebuild, here or outside, and every
    /// ten minutes for "Daily". The same check the background job makes, so they never both run one.
    private func runDueBackups() {
        lastBackupCheck = .now
        guard backingUp.isEmpty, let plans = GraphPlans.load(from: outDirectory) else { return }
        let records = BackupStore.records()
        let date = graphFileDate
        let due = plans.filter { BackupSchedule.isDue($0.backup, record: records[$0.id], graphDate: date) }
        guard !due.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            let arrangement = await self.loadArrangement()
            let accounts = await self.gitAccounts(for: arrangement)
            for plan in due {
                guard let graph = arrangement.graphs.first(where: { $0.id == plan.id }) else { continue }
                _ = await self.backUp(graphID: graph.id, arrangement: arrangement, identity: BackupJob.identity(for: graph, accounts: accounts),
                                      message: BackupMessages.defaultMessage(graph: graph, nodes: arrangement.nodes(inGraph: graph.id)), automatic: true)
            }
        }
    }

    /// Whether this is Graphitree itself, not its screenshot or check tools, so only it changes the
    /// background job and the list of scheduled backups.
    private var isTheApp: Bool { Bundle.main.bundleIdentifier == GraphLocator.graphitreeDefaults }

    /// Lists the open graph for scheduled backups when it has any, then installs, updates or removes
    /// the background job to match the settings. Returns an error message or nil.
    @discardableResult
    func syncBackgroundJob() -> String? {
        guard isTheApp else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let hasScheduled: Bool
        if let plans = GraphPlans.load(from: outDirectory) {
            hasScheduled = ScheduledBackups.update(outDirectory: outDirectory, plans: plans)
        } else {
            hasScheduled = !ScheduledBackups.load().isEmpty
        }
        if freshness.updatesWhenClosed, freshness.updateRoot == nil {
            freshness.updateRoot = UpdateAgent.installedRoot(home: home) ?? graphRoot
        }
        guard freshness.updatesWhenClosed || hasScheduled else { return UpdateAgent.sync(arguments: nil, home: home) }
        let graphify = freshness.updatesWhenClosed ? GraphRebuilder.locateGraphify() : nil
        let cli = CommandLineTool.bundledPath ?? (CommandLineTool.isInstalled(home: home) ? CommandLineTool.linkPath(home: home) : nil)
        if hasScheduled, cli == nil { return "Graphitree's command line wasn't found, so backups can't run while Graphitree is closed." }
        if freshness.updatesWhenClosed, graphify == nil { return RebuildError.graphifyNotFound.localizedDescription }
        return UpdateAgent.sync(arguments: UpdateAgent.arguments(cli: cli, graphify: graphify, root: freshness.updatesWhenClosed ? freshness.updateRoot : nil), home: home)
    }

    /// Whether the background job will run this knowledge base's scheduled backups.
    var backgroundBackupsReady: Bool {
        _ = settingsRevision
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return UpdateAgent.installedArguments(home: home)?.contains("background") == true
            && ScheduledBackups.load().contains(outDirectory.standardizedFileURL.path)
    }

    // MARK: - Restore

    private(set) var isRestoring = false
    private(set) var restoreLog = ""

    /// Clones the chosen backups and joins them into a new graphify-out beside the root. Nothing in
    /// use is touched.
    func restore(_ sources: [BackupRestore.Source], root: String) async -> Result<BackupRestore.Restored, PlaybookError> {
        guard !isRestoring else { return .failure(PlaybookError(message: "A restore is already running.")) }
        isRestoring = true
        restoreLog = ""
        defer { isRestoring = false }
        let destination = BackupRestore.destination(root: root)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let log: (String) -> Void = { line in Task { @MainActor [weak self] in self?.restoreLog += line + "\n" } }
                let work = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-restore-\(UUID().uuidString)", isDirectory: true)
                defer { try? FileManager.default.removeItem(at: work) }
                do {
                    var folders: [URL] = []
                    for (offset, source) in sources.enumerated() {
                        log("Fetching \(source.name)")
                        let folder = work.appendingPathComponent("\(offset)", isDirectory: true)
                        try BackupRestore.fetch(source, into: folder)
                        folders.append(folder)
                    }
                    log("Joining the graph files and checking each backup adds back up")
                    let restored = try BackupRestore.combine(folders, into: destination, root: root)
                    log("Wrote \(restored.nodes.formatted()) nodes and \(restored.edges.formatted()) edges to \(AgentGuide.abbreviate(destination.path))")
                    log("Asking it a question with graphify")
                    if let problem = BackupRestore.checkWithGraphify(destination, graphify: GraphRebuilder.locateGraphify()) {
                        log(problem)
                    } else {
                        log("graphify reads it")
                    }
                    continuation.resume(returning: .success(restored))
                } catch {
                    log("Stopped: \(error.localizedDescription)")
                    continuation.resume(returning: .failure(PlaybookError(message: error.localizedDescription)))
                }
            }
        }
    }

    /// Moves a restored graph to `<root>/graphify-out` when nothing is there, then opens it.
    func putRestoredInPlace(_ folder: URL, root: String) -> String? {
        do {
            let target = try BackupRestore.putInPlace(folder, root: root)
            choose(target)
            refreshCatalog()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Insights and learning

    private(set) var insights: UsageInsights?
    private(set) var isReadingSessions = false
    private(set) var isCheckingLibraries = false
    /// Set by Insights so the Playbook chat starts the session-learning flow when it opens.
    var wantsSessionLearning = false
    static let insightDays = 30

    /// What the last month of sessions and Graphitree's own log show.
    func loadInsights() async {
        guard !isReadingSessions else { return }
        isReadingSessions = true
        let since = Date().addingTimeInterval(-Double(Self.insightDays) * 24 * 3600)
        let source = GraphSource(outDirectory: outDirectory)
        let playbook = loadPlaybook()
        insights = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let sessions = SessionReader.scan(since: since)
                continuation.resume(returning: UsageInsights.build(events: UsageLog.load(since: since), sessions: sessions, playbook: playbook, root: source.rootPath, scheme: source.scheme))
            }
        }
        isReadingSessions = false
    }

    var logsUsage: Bool {
        get {
            _ = settingsRevision
            return UserDefaults.standard.object(forKey: UsageLog.defaultsKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UsageLog.defaultsKey)
            settingsRevision += 1
        }
    }

    func clearUsageLog() {
        UsageLog.clear()
        Task { await loadInsights() }
    }

    /// The digest of the last month's sessions, and roughly what reading it costs the chat model.
    func sessionDigest() async -> (text: String, messages: Int, sessions: Int) {
        let since = Date().addingTimeInterval(-Double(Self.insightDays) * 24 * 3600)
        let source = GraphSource(outDirectory: outDirectory)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let scan = SessionReader.scan(since: since)
                let digest = SessionDigest.make(scan, root: source.rootPath, scheme: source.scheme)
                continuation.resume(returning: (digest, scan.messages.count, scan.files))
            }
        }
    }

    /// Asks the chat model to suggest notes and picks from the owner's own sessions.
    func learnFromSessions(digest: String, playbook: Playbook, scan: StackScanResult?) {
        sendChat("Learn how I work from my Claude Code sessions in the last \(Self.insightDays) days.", playbook: playbook, scan: scan,
                 extraContext: SessionDigest.instructions + "\n\n" + digest)
    }

    /// Re-researches every library and puts what changed in the chat, for the person to apply.
    func checkLibraries() async {
        let directory = outDirectory
        let libraries = loadPlaybook().libraries
        guard !libraries.isEmpty, !isCheckingLibraries else { return }
        isCheckingLibraries = true
        let result = await draftLibraries(libraries)
        isCheckingLibraries = false
        freshness.lastLibraryCheck = .now
        switch result {
        case .success(let drafts):
            let changes = PlaybookCheck.changes(for: libraries, drafts: drafts)
            addTurn(ChatTurn(role: .assistant, text: PlaybookCheck.summary(checked: drafts.count, changes: changes), changes: changes), toChatOf: directory)
        case .failure(let error):
            addTurn(ChatTurn(role: .assistant, text: "The library check stopped: \(error.message)", isError: true), toChatOf: directory)
        }
    }

    // MARK: - Keeping fresh

    private var graphFileDate: Date? {
        (try? FileManager.default.attributesOfItem(atPath: GraphSource(outDirectory: outDirectory).graphURL.path))?[.modificationDate] as? Date
    }

    /// Counts what a docs pass would read now, with graphify's own rules.
    func estimateDocs() async {
        guard let python = graphifyPython, !isEstimatingDocs else {
            if graphifyPython == nil { docsEstimateError = "graphify's Python wasn't found, so the docs can't be counted." }
            return
        }
        isEstimatingDocs = true
        docsEstimateError = nil
        let root = graphRoot
        let out = outDirectory
        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: Result { try DocsEstimator.run(python: python, root: root, outDirectory: out) })
            }
        }
        isEstimatingDocs = false
        switch result {
        case .success(let estimate): docsEstimate = estimate
        case .failure(let error): docsEstimateError = error.localizedDescription
        }
    }

    func docsCost(_ estimate: DocsEstimate, docs: DocsPass) -> DocsCost {
        DocsCost.estimate(estimate, backend: docs.backend, history: DocsRunLog.load())
    }

    /// Runs the docs pass that was waiting for the person.
    func runWaitingDocsPass() {
        guard let docs = docsPass() else { return }
        docsEstimate = waitingDocsPass ?? docsEstimate
        waitingDocsPass = nil
        startRebuild(force: false, docs: docs)
    }

    /// Skips the waiting pass until the next scheduled time.
    func skipWaitingDocsPass() {
        waitingDocsPass = nil
        freshness.lastDocsPass = .now
    }

    /// Whether any graphify is already working, such as the background job.
    private var graphifyIsBusy: Bool {
        guard let result = try? ProcessRunner.run("/usr/bin/pgrep", ["-f", "graphify (update|extract|label)"], timeout: 5) else { return false }
        return result.status == 0
    }

    func noteChange() {
        if pendingChangeAt == nil { pendingChangeAt = .now }
    }

    private func restartWatcher() {
        watcher?.stop()
        watcher = nil
        guard freshness.updatesCodeOnChange, case .ready = state else { return }
        let root = graphRoot
        watcher = FolderWatcher(root: root) { [weak self] paths in
            guard paths.contains(where: { ChangeFilter.matters($0, root: root) }) else { return }
            Task { @MainActor in self?.noteChange() }
        }
    }

    /// Turns the background job on or off. Returns an error message or nil.
    func setUpdatesWhenClosed(_ on: Bool) -> String? {
        if on, GraphRebuilder.locateGraphify() == nil { return RebuildError.graphifyNotFound.localizedDescription }
        let before = freshness
        freshness.updatesWhenClosed = on
        if on { freshness.updateRoot = graphRoot }
        if let failure = syncBackgroundJob() {
            freshness = before
            return failure
        }
        return nil
    }

    private func startFreshnessLoop() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await self?.connectionTick()
                await self?.freshnessTick()
            }
        }
    }

    /// Every half minute: notice outside changes to the graph, rebuild code after edits settle,
    /// and start or hold a scheduled docs pass.
    private func freshnessTick() async {
        guard case .ready = state, !isRebuilding, !isEstimatingDocs else { return }
        // The background job or a terminal rebuilt the graph: reopen it and recut the slices.
        if let date = graphFileDate, let loaded = loadedGraphDate, date > loaded, !graphifyIsBusy {
            refreshesGuideAfterLoad = true
            load()
            Task { _ = await writeFolderSlices() }
            runDueBackups()
            return
        }
        let now = Date.now
        // Backups set to "Daily", or one that waited out its hour since the last.
        if now.timeIntervalSince(lastBackupCheck) > 600 { runDueBackups() }
        // Code changed: wait until edits settle for 90 seconds, at most once every ten minutes.
        if freshness.updatesCodeOnChange, let changed = pendingChangeAt, now.timeIntervalSince(changed) > 90,
           now.timeIntervalSince(lastQuietStart) > 600, !graphifyIsBusy {
            lastQuietStart = now
            startRebuild(force: false, quiet: true)
            return
        }
        // The monthly library check, when it's on and Claude Code is there to do the research.
        if freshness.isLibraryCheckDue(now: now), !isChatting, ToolLocator.command(["claude"], home: FileManager.default.homeDirectoryForCurrentUser.path) != nil {
            await checkLibraries()
            return
        }
        // A scheduled docs pass: run it quietly when it's within the limit, or hold it for the person.
        if freshness.isDocsPassDue(now: now), let slot = freshness.lastSlot(before: now), askedAboutSlot != slot,
           waitingDocsPass == nil, let docs = docsPass(), !graphifyIsBusy {
            // A builder that's signed out or rejected would only fail: wait until it's fixed.
            if let builder = builderID {
                await checkConnections([builder])
                if connectionHealth[builder]?.isBroken == true {
                    askedAboutSlot = slot
                    return
                }
            }
            await estimateDocs()
            guard let estimate = docsEstimate else { return }
            askedAboutSlot = slot
            if estimate.isEmpty {
                freshness.lastDocsPass = now
            } else if docsCost(estimate, docs: docs).totalTokens <= freshness.askAboveTokens {
                startRebuild(force: false, docs: docs, quiet: true)
            } else {
                waitingDocsPass = estimate
            }
        }
    }

    // MARK: - Pointers in repos

    /// The block for one repo: the playbook's picks and stack, and its folder's purpose.
    func repoPointerBlock(for repo: String, labels: [FolderLabel]) -> String {
        let top = repo.split(separator: "/").first.map(String.init) ?? repo
        return RepoPointer.block(
            playbook: loadPlaybook(),
            folder: labels.first { $0.path == top },
            hasCommand: CommandLineTool.isInstalled(home: FileManager.default.homeDirectoryForCurrentUser.path),
            graph: GraphCuts.entry(forPath: repo, outDirectory: outDirectory)?.name
        )
    }

    /// Writes or updates the pointer in each repo. Returns the first error, or nil.
    func writeRepoPointers(_ repos: [String], labels: [FolderLabel]) -> String? {
        for repo in repos {
            do {
                try RepoPointer.write(repoPointerBlock(for: repo, labels: labels), repo: (graphRoot as NSString).appendingPathComponent(repo))
            } catch {
                return "Couldn't write the pointer in \(repo): \(error.localizedDescription)"
            }
        }
        return nil
    }

    func removeRepoPointers(_ repos: [String]) -> String? {
        for repo in repos {
            do {
                try RepoPointer.remove(repo: (graphRoot as NSString).appendingPathComponent(repo))
            } catch {
                return "Couldn't remove the pointer from \(repo): \(error.localizedDescription)"
            }
        }
        return nil
    }

    // MARK: - Graph list

    func refreshCatalog() {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/GitHub", isDirectory: true)
        let mapped = mappedRoots
        workQueue.async { [weak self] in
            var entries = GraphCatalog.discover(under: root)
            entries += GraphCatalog.mapped(mapped, excluding: Set(entries.map { $0.outDirectory.standardizedFileURL.path }))
            Task { @MainActor in self?.catalog = entries }
        }
    }

    var currentGraphName: String {
        catalog.first { $0.outDirectory.standardizedFileURL == outDirectory.standardizedFileURL }?.name
            ?? outDirectory.deletingLastPathComponent().lastPathComponent
    }
}

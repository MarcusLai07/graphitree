import Foundation

enum RebuildError: LocalizedError, Equatable {
    case graphifyNotFound
    case buildFolderMismatch(root: String)

    var errorDescription: String? {
        switch self {
        case .graphifyNotFound:
            return "graphify isn't installed, and it's what maps the code. Graphitree offers to install it the next time it opens, or run uv tool install graphifyy in Terminal."
        case .buildFolderMismatch(let root):
            return "This graph isn't the one graphify would rebuild from \(root), so rebuilding could overwrite a different graph."
        }
    }
}

struct RebuildReport: Equatable, Sendable {
    let nodesBefore: Int
    let edgesBefore: Int
    let nodesAfter: Int
    let edgesAfter: Int
    let orphanedRules: Int
    let wroteCleanGraph: Bool
}

enum RebuildResult: Equatable, Sendable {
    case finished(RebuildReport)
    case failed(exitCode: Int32)
    /// graphify's guard stopped a build that would have produced fewer nodes.
    case refusedToShrink
    case cancelled
}

/// Runs `graphify update` for one graph, and optionally `graphify extract` for its docs, and streams the output.
final class GraphRebuilder: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var wasCancelled = false

    static func locateGraphify() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin/graphify", "/opt/homebrew/bin/graphify", "/usr/local/bin/graphify"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// graphify writes to `<root>/graphify-out`, so anything else would rebuild the wrong graph.
    /// This matters for copies whose `.graphify_root` still points at the original.
    static func validate(_ source: GraphSource) throws {
        let expected = URL(fileURLWithPath: source.rootPath).appendingPathComponent("graphify-out").standardizedFileURL
        guard expected.resolvingSymlinksInPath().path == source.outDirectory.standardizedFileURL.resolvingSymlinksInPath().path else {
            throw RebuildError.buildFolderMismatch(root: source.rootPath)
        }
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        wasCancelled = true
        process?.terminate()
    }

    /// Blocks until graphify exits. With a docs pass, `graphify extract` runs after the update and
    /// sends only the docs, papers and images graphify hasn't read before to the chosen model.
    func run(
        source: GraphSource,
        force: Bool,
        docs: DocsPass? = nil,
        onOutput: @escaping @Sendable (String) -> Void
    ) throws -> (status: Int32, refusedToShrink: Bool, cancelled: Bool) {
        try Self.validate(source)
        guard let graphify = Self.locateGraphify() else { throw RebuildError.graphifyNotFound }

        let update = try runStep(graphify, ["update", source.rootPath] + (force ? ["--force"] : []), source: source, environment: [:], onOutput: onOutput)
        guard let docs, update.status == 0, !update.refusedToShrink, !update.cancelled else { return update }

        onOutput("\n── Reading new and changed docs with \(docs.name) ──\n")
        if docs.backend == "claude-cli" {
            onOutput("\(docs.name) reads one chunk at a time, and a chunk can take 10 minutes or more. graphify prints a line as each one finishes.\n")
        }
        var last = update
        for (index, step) in docs.steps(root: source.rootPath).enumerated() {
            if index > 0 { onOutput("\n── Naming new groups with \(docs.name) ──\n") }
            last = try runStep(graphify, step, source: source, environment: docs.environment, onOutput: onOutput)
            guard last.status == 0, !last.refusedToShrink, !last.cancelled else { return last }
        }
        return last
    }

    private func runStep(
        _ graphify: String,
        _ arguments: [String],
        source: GraphSource,
        environment extra: [String: String],
        onOutput: @escaping @Sendable (String) -> Void
    ) throws -> (status: Int32, refusedToShrink: Bool, cancelled: Bool) {
        lock.lock()
        let alreadyCancelled = wasCancelled
        lock.unlock()
        if alreadyCancelled { return (0, false, true) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: graphify)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: source.rootPath)
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        environment["PATH"] = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["GRAPHIFY_NO_TIPS"] = "1"
        environment["PYTHONUNBUFFERED"] = "1"
        environment.merge(extra) { _, new in new }
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let refused = RefusalFlag()
        let quiet = QuietClock()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            if text.contains("Refusing to overwrite") { refused.set() }
            quiet.heard()
            onOutput(text)
        }

        lock.lock()
        self.process = process
        lock.unlock()
        try process.run()
        // graphify can go silent for many minutes while a model call runs, which reads as stuck.
        let heartbeat = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        heartbeat.schedule(deadline: .now() + 60, repeating: 60)
        heartbeat.setEventHandler {
            if let minutes = quiet.minutesToReport() {
                onOutput("[graphitree] still working: nothing new from graphify for \(minutes) min\n")
            }
        }
        heartbeat.resume()
        process.waitUntilExit()
        heartbeat.cancel()
        pipe.fileHandleForReading.readabilityHandler = nil

        lock.lock()
        self.process = nil
        let cancelled = wasCancelled
        lock.unlock()
        return (process.terminationStatus, refused.value, cancelled)
    }

    /// How long graphify has printed nothing. Says so every few quiet minutes, never for its own lines.
    final class QuietClock: @unchecked Sendable {
        private let lock = NSLock()
        private var lastHeard: Date
        private var lastReported = 0
        private let every: Int

        init(start: Date = .now, every: Int = 3) {
            lastHeard = start
            self.every = every
        }

        func heard(at date: Date = .now) {
            lock.lock()
            lastHeard = date
            lastReported = 0
            lock.unlock()
        }

        /// Whole quiet minutes, once per `every` of them.
        func minutesToReport(at date: Date = .now) -> Int? {
            lock.lock()
            defer { lock.unlock() }
            let minutes = Int(date.timeIntervalSince(lastHeard) / 60)
            guard minutes >= lastReported + every else { return nil }
            lastReported = minutes
            return minutes
        }
    }

    private final class RefusalFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var isSet = false
        func set() {
            lock.lock()
            isSet = true
            lock.unlock()
        }
        var value: Bool {
            lock.lock()
            defer { lock.unlock() }
            return isSet
        }
    }
}

extension Workspace {
    /// Reopens after a rebuild, reapplies the rules and refreshes the clean graph.
    static func reopenAfterRebuild(
        source: GraphSource,
        cacheDirectory: URL,
        nodesBefore: Int,
        edgesBefore: Int
    ) throws -> (workspace: Workspace, snapshot: WorkspaceSnapshot, report: RebuildReport) {
        let workspace = try Workspace(source: source, cacheDirectory: cacheDirectory)
        var snapshot = try workspace.snapshot()
        let shouldWrite = !snapshot.rules.isEmpty || snapshot.clean != .notWritten
        if shouldWrite {
            try workspace.writeCleanGraph()
            snapshot = try workspace.snapshot()
        }
        let report = RebuildReport(
            nodesBefore: nodesBefore,
            edgesBefore: edgesBefore,
            nodesAfter: snapshot.overview.nodes,
            edgesAfter: snapshot.overview.edges,
            orphanedRules: snapshot.rules.filter(\.isOrphaned).count,
            wroteCleanGraph: shouldWrite
        )
        return (workspace, snapshot, report)
    }
}

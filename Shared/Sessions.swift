import Foundation

// Reading what happened in the owner's Claude Code sessions, on this Mac only: their own typed
// messages (to learn how they work), the questions AI tools asked the graph and what came back,
// and the packages they installed. Transcripts are large, so only recent files are read, line by
// line, and only lines that can matter are parsed.

struct SessionMessage: Equatable, Sendable {
    let date: Date
    /// The folder the session ran in.
    let cwd: String
    let text: String
}

/// A question an AI tool asked the graph, from `graphify query` or `graphitree` in a session.
struct GraphQuestion: Equatable, Sendable {
    let date: Date
    let cwd: String
    /// `query`, `pick`, `ask` or `affected`.
    let kind: String
    let question: String
    /// Nodes or picks that came back. Nil when the answer wasn't found in the transcript.
    var found: Int?
}

struct InstalledPackage: Equatable, Sendable {
    let name: String
    let cwd: String
    let date: Date
}

struct SessionScan: Equatable, Sendable {
    var messages: [SessionMessage] = []
    var questions: [GraphQuestion] = []
    var installs: [InstalledPackage] = []
    var files = 0
}

enum SessionReader {
    static var projectsFolder: URL { ClaudeTranscripts.projectsFolder }

    /// Reads every session file changed since `since`.
    static func scan(folder: URL = projectsFolder, since: Date, maxMessages: Int = 3_000) -> SessionScan {
        var result = SessionScan()
        for file in ClaudeTranscripts.files(under: [folder], modifiedSince: since) {
            result.files += 1
            read(file.url, since: since, into: &result, maxMessages: maxMessages)
        }
        result.messages.sort { $0.date > $1.date }
        result.questions.sort { $0.date > $1.date }
        return result
    }

    private static let dates: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func read(_ file: URL, since: Date, into result: inout SessionScan, maxMessages: Int) {
        // Questions wait here for their answers, which arrive in a later line.
        var pending: [String: Int] = [:]
        // Lines are checked as raw bytes first: most are huge tool output that never matters.
        func has(_ needle: String, _ bytes: UnsafeRawPointer, _ length: Int) -> Bool {
            ClaudeTranscripts.contains(bytes, length, needle)
        }
        ClaudeTranscripts.forEachLine(of: file) { buffer, length in
            let isUser = has("\"type\":\"user\"", buffer, length)
            let isTool = !isUser && has("\"tool_use\"", buffer, length) && has("\"Bash\"", buffer, length)
                && (has("graphify", buffer, length) || has(CommandLineTool.commandName, buffer, length) || has("install", buffer, length) || has(" add ", buffer, length))
            guard isUser || isTool else { return true }
            if isUser, has("\"tool_result\"", buffer, length) {
                // A tool's answer only matters when it answers a pending graph question.
                guard pending.keys.contains(where: { has($0, buffer, length) }) else { return true }
            } else if isUser, length > 200_000 {
                return true
            }
            let data = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer), count: length, deallocator: .none)
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return true }
            let date = (object["timestamp"] as? String).flatMap { dates.date(from: $0) } ?? .distantPast
            guard date >= since else { return true }
            let cwd = object["cwd"] as? String ?? ""
            let message = object["message"] as? [String: Any] ?? [:]
            if object["type"] as? String == "user" {
                if let text = message["content"] as? String {
                    if let typed = typedText(text), result.messages.count < maxMessages {
                        result.messages.append(SessionMessage(date: date, cwd: cwd, text: typed))
                    }
                } else if let items = message["content"] as? [[String: Any]] {
                    for item in items {
                        if item["type"] as? String == "text", let text = item["text"] as? String, let typed = typedText(text), result.messages.count < maxMessages {
                            result.messages.append(SessionMessage(date: date, cwd: cwd, text: typed))
                        } else if item["type"] as? String == "tool_result", let id = item["tool_use_id"] as? String, let index = pending.removeValue(forKey: id) {
                            result.questions[index].found = foundCount(in: resultText(item["content"]))
                        }
                    }
                }
            } else if let items = message["content"] as? [[String: Any]] {
                for item in items where item["type"] as? String == "tool_use" && item["name"] as? String == "Bash" {
                    guard let command = (item["input"] as? [String: Any])?["command"] as? String else { continue }
                    if let asked = question(in: command) {
                        result.questions.append(GraphQuestion(date: date, cwd: cwd, kind: asked.kind, question: asked.question, found: nil))
                        if let id = item["id"] as? String { pending[id] = result.questions.count - 1 }
                    }
                    for name in packages(in: command) {
                        result.installs.append(InstalledPackage(name: name, cwd: cwd, date: date))
                    }
                }
            }
            return true
        }
    }

    /// The person's own words, without the tags tools and the harness add to user turns.
    static func typedText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("<"), !trimmed.hasPrefix("Caveat:"), !trimmed.hasPrefix("[Request interrupted"),
              !trimmed.hasPrefix("This session is being continued") else { return nil }
        return String(trimmed.prefix(800))
    }

    private static func resultText(_ content: Any?) -> String {
        if let text = content as? String { return text }
        return (content as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }.joined(separator: "\n")
    }

    /// Nodes found by `graphify query`, or picks returned by `graphitree pick`.
    static func foundCount(in output: String) -> Int {
        if let range = output.range(of: #"(\d+) nodes? found"#, options: .regularExpression) {
            return Int(output[range].split(separator: " ").first ?? "") ?? 0
        }
        if output.contains("no pick for") || output.contains("Nothing matched") || output.contains("No matching") { return 0 }
        return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1
    }

    /// The question in a `graphify query "…"` or `graphitree pick|ask|affected …` command.
    static func question(in command: String) -> (kind: String, question: String)? {
        if let range = command.range(of: #"graphify query\s+"([^"]+)""#, options: .regularExpression) {
            let part = command[range]
            if let open = part.firstIndex(of: "\"") {
                return ("query", String(part[part.index(after: open)...].dropLast()))
            }
        }
        if let range = command.range(of: #"\#(CommandLineTool.commandName)\s+(pick|ask|affected)\s+[^|;&\n]+"#, options: .regularExpression) {
            let words = command[range].split(separator: " ", maxSplits: 2).map(String.init)
            guard words.count == 3 else { return nil }
            let text = words[2].components(separatedBy: " --").first ?? words[2]
            return (words[1], text.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")))
        }
        return nil
    }

    /// Packages a command adds: npm, pnpm, yarn, bun, pip and uv.
    static func packages(in command: String) -> [String] {
        var names: [String] = []
        let pattern = #"(?:npm (?:i|install|add)|pnpm (?:add|i|install)|yarn add|bun (?:add|i|install)|pip3? install|uv (?:add|pip install))[ \t]+([^|;&\n\\"`),}]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let text = command as NSString
        for match in regex.matches(in: command, range: NSRange(location: 0, length: text.length)) {
            let list = text.substring(with: match.range(at: 1))
            let words = list.split(separator: " ").map(String.init)
            // Global installs are command-line tools, not libraries an app uses.
            if words.contains("-g") || words.contains("--global") { continue }
            for word in words {
                guard !word.hasPrefix("-"), !word.hasPrefix("."), !word.hasPrefix("/"), word != "&&",
                      word.range(of: #"^[A-Z_][A-Z0-9_]*="#, options: .regularExpression) == nil else { continue }
                // `react@19` is react; `@scope/name@1` is @scope/name; `'pydantic>=2'` is pydantic.
                var name = word.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if let at = name.dropFirst().firstIndex(of: "@") { name = String(name[..<at]) }
                if let bracket = name.firstIndex(of: "[") { name = String(name[..<bracket]) }
                if let compare = name.firstIndex(where: { "<>~=!".contains($0) }) { name = String(name[..<compare]) }
                let isFile = [".txt", ".toml", ".cfg", ".lock", ".json", ".whl", ".tgz"].contains { name.lowercased().hasSuffix($0) }
                guard !name.isEmpty, !isFile, name.range(of: #"^[@a-zA-Z0-9][\w./@-]*$"#, options: .regularExpression) != nil else { continue }
                names.append(name.lowercased())
            }
        }
        return names
    }
}

// MARK: - Graphitree's own usage log

/// What AI tools asked Graphitree through `graphitree` and its MCP server. Local, and can be turned off.
struct UsageEvent: Codable, Equatable, Sendable {
    let date: Date
    /// `cli` or `mcp`.
    let via: String
    /// `pick`, `ask`, `affected`, `stack`, `how` or `playbook`.
    let tool: String
    let query: String
    let found: Int
    let cwd: String
}

enum UsageLog {
    static let defaultsKey = "logsUsage"

    static var url: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Graphitree/usage.jsonl")
    }

    /// On unless the person turned it off in Graphitree.
    static var isEnabled: Bool {
        GraphLocator.graphitreeSettings?.object(forKey: defaultsKey) as? Bool ?? true
    }

    static func record(_ event: UsageEvent, to url: URL = url) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(event) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data + Data("\n".utf8))
            try? handle.close()
        } else {
            try? (data + Data("\n".utf8)).write(to: url)
        }
        // Keeps the log small: past a megabyte, only the newest half stays.
        if let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int, size > 1_000_000,
           let text = try? String(contentsOf: url, encoding: .utf8) {
            let lines = text.split(separator: "\n")
            try? (lines.suffix(lines.count / 2).joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func load(since: Date, from url: URL = url) -> [UsageEvent] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return text.split(separator: "\n").compactMap { try? decoder.decode(UsageEvent.self, from: Data($0.utf8)) }.filter { $0.date >= since }
    }

    static func clear(_ url: URL = url) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Insights

/// What the last weeks show: how often AI tools asked, what came back empty, which jobs have no
/// pick, and packages in use that the playbook doesn't mention.
struct UsageInsights: Equatable, Sendable {
    struct Count: Equatable, Sendable {
        let name: String
        let count: Int
    }

    var questions = 0
    var picksAsked = 0
    var sessions = 0
    /// Graph questions that found nothing, newest first, without repeats.
    var emptyQuestions: [String] = []
    /// Jobs asked through `graphitree pick` or `find_pick` with no pick in the playbook.
    var missingPicks: [Count] = []
    var topJobs: [Count] = []
    /// Projects AI tools asked about most.
    var projects: [Count] = []
    /// Installed in sessions, not in the playbook.
    var unlistedPackages: [Count] = []

    /// Packages too common or too small to be a pick.
    static let ignoredPackages: Set<String> = [
        "typescript", "tsx", "ts-node", "vite", "react", "react-dom", "next", "eslint", "prettier", "vitest", "jest",
        "pip", "setuptools", "wheel", "uv", "dotenv", "nodemon", "concurrently", "npm", "pnpm", "yarn", "playwright",
    ]

    static func build(events: [UsageEvent], sessions: SessionScan, playbook: Playbook, root: String, scheme: ProjectScheme) -> UsageInsights {
        var insights = UsageInsights()
        insights.sessions = sessions.files
        func project(of cwd: String) -> String? {
            let prefix = root.hasSuffix("/") ? root : root + "/"
            guard cwd.hasPrefix(prefix) else { return nil }
            let name = scheme.project(of: String(cwd.dropFirst(prefix.count)) + "/x")
            // The graph's own folder and a group folder itself aren't projects.
            return name == "graphify-out" || scheme.groups.contains(name) ? nil : name
        }
        func counted(_ names: [String], limit: Int) -> [Count] {
            Dictionary(grouping: names, by: { $0 }).map { Count(name: $0.key, count: $0.value.count) }
                .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
                .prefix(limit).map { $0 }
        }

        let graphEvents = events.filter { $0.tool == "ask" || $0.tool == "affected" }
        let graphFromSessions = sessions.questions.filter { $0.kind == "query" || $0.kind == "ask" || $0.kind == "affected" }
        insights.questions = graphEvents.count + graphFromSessions.count

        var empty: [(Date, String)] = graphEvents.filter { $0.found == 0 }.map { ($0.date, $0.query) }
        empty += graphFromSessions.filter { $0.found == 0 }.map { ($0.date, $0.question) }
        var seen = Set<String>()
        insights.emptyQuestions = empty.sorted { $0.0 > $1.0 }.map(\.1).filter { seen.insert($0.lowercased()).inserted }.prefix(10).map { $0 }

        let pickEvents = events.filter { $0.tool == "pick" }
        let pickSessions = sessions.questions.filter { $0.kind == "pick" }
        insights.picksAsked = pickEvents.count + pickSessions.count
        let jobs = pickEvents.map { $0.query.lowercased() } + pickSessions.map { $0.question.lowercased() }
        insights.topJobs = counted(jobs, limit: 8)
        let missing = pickEvents.filter { $0.found == 0 }.map { $0.query.lowercased() } + pickSessions.filter { $0.found == 0 }.map { $0.question.lowercased() }
        insights.missingPicks = counted(missing, limit: 8)

        let asked = (events.filter { $0.tool != "stack" && $0.tool != "how" && $0.tool != "playbook" }.map(\.cwd) + sessions.questions.map(\.cwd)).compactMap(project)
        insights.projects = counted(asked, limit: 8)

        func key(_ name: String) -> String { name.lowercased().filter { $0.isLetter || $0.isNumber } }
        let listed = playbook.libraries.flatMap { library -> [String] in
            var keys = [key(library.name)]
            keys += library.install.split(separator: " ").map { key(String($0)) }
            return keys
        }
        let unlisted = sessions.installs.map(\.name).filter { name in
            let packageKey = key(name)
            guard !ignoredPackages.contains(name), !name.hasPrefix("@types/"), packageKey.count > 2 else { return false }
            return !listed.contains { !$0.isEmpty && ($0 == packageKey || packageKey.hasPrefix($0) || $0.hasPrefix(packageKey)) }
        }
        // Count each package once per folder it was installed in, so one busy session doesn't dominate.
        let unlistedNames = Set(unlisted)
        let perFolder = Set(sessions.installs.filter { unlistedNames.contains($0.name) }.map { "\($0.name)\u{1F}\($0.cwd)" })
        insights.unlistedPackages = counted(perFolder.map { String($0.split(separator: "\u{1F}").first ?? "") }, limit: 12)
        return insights
    }
}

// MARK: - Learning from sessions

enum SessionDigest {
    /// The owner's own messages, newest first and grouped by project, within a size limit, plus
    /// what they installed. This is what the chat model reads to suggest notes.
    static func make(_ scan: SessionScan, root: String, scheme: ProjectScheme, maxCharacters: Int = 24_000) -> String {
        func place(_ cwd: String) -> String {
            let prefix = root.hasSuffix("/") ? root : root + "/"
            if cwd.hasPrefix(prefix) { return scheme.project(of: String(cwd.dropFirst(prefix.count)) + "/x") }
            return (cwd as NSString).lastPathComponent.isEmpty ? "home" : (cwd as NSString).lastPathComponent
        }
        var lines: [String] = []
        var used = 0
        var seen = Set<String>()
        for message in scan.messages {
            let text = message.text.replacingOccurrences(of: "\n", with: " ")
            guard text.count >= 12, seen.insert(text.lowercased()).inserted else { continue }
            let line = "- [\(place(message.cwd))] \(text)"
            guard used + line.count <= maxCharacters else { break }
            lines.append(line)
            used += line.count
        }
        var digest = "The owner's own messages from \(scan.files) Claude Code sessions, newest first, as [project] text:\n" + lines.joined(separator: "\n")
        var projectsByPackage: [String: Set<String>] = [:]
        for install in scan.installs { projectsByPackage[install.name, default: []].insert(place(install.cwd)) }
        let installs: [(name: String, projects: Int)] = projectsByPackage.map { (name: $0.key, projects: $0.value.count) }
        let ranked = installs.sorted { a, b in a.projects == b.projects ? a.name < b.name : a.projects > b.projects }.prefix(30)
        if !ranked.isEmpty {
            digest += "\n\nPackages installed in those sessions (name: projects): " + ranked.map { "\($0.name): \($0.projects)" }.joined(separator: ", ")
        }
        return digest
    }

    static let instructions = """
    Below are the owner's own messages to AI coding tools, and the packages they installed. Suggest How You Work notes and playbook changes that these clearly show: preferences they repeat, corrections they make more than once, things they always ask for or push back on, and libraries they reach for. Describe patterns, not one-off requests, and never copy private details such as names, keys, client data or URLs. Each habit change gives the full new text for its prompt, keeping what's already written. In the reply, say briefly what you noticed and how many sessions it's based on.
    """
}

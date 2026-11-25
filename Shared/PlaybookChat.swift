import Foundation

// The Playbook's chat: the person talks to the model that builds their graph about libraries,
// the stack and how they work. A reply can carry changes to the playbook, and the person applies
// each one, so nothing reaches the knowledge base without them seeing it.

struct ChatTurn: Codable, Identifiable, Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case user, assistant
    }

    var id = UUID()
    var role: Role
    var text: String
    var changes: [PlaybookChange] = []
    var at = Date()
    /// A failed request, shown in the chat but never sent back to the model.
    var isError = false
}

/// A rule the chat suggests: a new one, or a change to the rule whose text is in `replaces`.
/// An empty `text` with `replaces` set removes that rule.
struct RuleDraft: Codable, Equatable, Sendable {
    var text: String
    var category: String = ""
    var replaces: String = ""
}

/// A skill the chat writes or rewrites, named by `name`. It's saved as a draft for the owner to check.
struct SkillDraft: Codable, Equatable, Sendable {
    var name: String
    var description: String = ""
    var body: String = ""
}

/// One change a reply suggests: a library to add or update, a stack answer, a habit, a rule or a skill.
struct PlaybookChange: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case library, stack, habit, rule, skill
    }

    enum State: String, Codable, Sendable {
        case proposed, applied, dismissed
    }

    var id = UUID()
    var kind: Kind
    var reason = ""
    var library: LibraryDraft?
    /// `StackQuestion.id` for a stack change.
    var question: String?
    var choices: [String] = []
    var notes = ""
    /// `HabitPrompt.id` for a habit change.
    var habit: String?
    var text = ""
    var state: State = .proposed
    /// The rule, for a rule change. Optional so chats saved before rules still load.
    var rule: RuleDraft?
    /// The skill, for a skill change.
    var skill: SkillDraft?
}

struct ChatReply: Equatable, Sendable {
    var text: String
    var changes: [PlaybookChange]
}

// MARK: - Which model answers

/// The model the chat talks to: the one that builds the graph, reached the way Graphitree can.
struct ChatEngine: Equatable, Sendable {
    enum Backend: Equatable, Sendable {
        /// `claude -p`, on the person's plan, with web search.
        case claudeCode(command: String)
        /// The Messages API with an API key.
        case anthropic(key: String, model: String)
        /// Any server that speaks OpenAI's chat completions: OpenAI, Gemini, Kimi, DeepSeek, Azure, Ollama, LM Studio.
        case openAI(url: String, headers: [String: String], model: String)
    }

    let id: String
    let name: String
    let backend: Backend
    let searchesWeb: Bool
    let billing: DocsPass.Billing

    static let anthropicDefaultModel = "claude-opus-5-5"

    /// The build model's chat engine. Code only falls back to the first model that's set up,
    /// because chatting is something the person starts themselves.
    static func resolve(stored: String, home: String, store: AIProviderStore) -> Result<ChatEngine, PlaybookError> {
        let options = BuildChoice.options(home: home, store: store).map(\.id)
        guard let id = BuildChoice.resolve(stored, options: options) ?? options.first else {
            return .failure(PlaybookError(message: "No AI model is connected. Connect Claude Code, an API key or a model on this Mac in AI Models first."))
        }
        return engine(for: id, home: home, store: store)
    }

    static func engine(for id: String, home: String, store: AIProviderStore) -> Result<ChatEngine, PlaybookError> {
        if let tool = AICatalog.codingTools.first(where: { $0.id == id }), tool.graphitreeBackend != nil {
            guard let command = ToolLocator.command(tool.commands, home: home) else {
                return .failure(PlaybookError(message: "\(tool.name) isn't installed where Graphitree looks for it."))
            }
            return .success(ChatEngine(id: id, name: tool.name, backend: .claudeCode(command: command), searchesWeb: true, billing: .plan))
        }
        guard let provider = AICatalog.providers.first(where: { $0.id == id }), store.isConfigured(provider) else {
            return .failure(PlaybookError(message: "That model isn't set up any more. Pick another in Build."))
        }
        let values = store.values(for: provider)
        func value(_ key: String) -> String? {
            let text = (values[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        let model = value(AIProviderStore.modelVariable) ?? provider.defaultModel
        let billing: DocsPass.Billing = provider.access == .local ? .thisMac : .apiAccount
        func openAI(_ base: String, key: String?) -> ChatEngine {
            var headers: [String: String] = [:]
            if let key { headers["Authorization"] = "Bearer \(key)" }
            return ChatEngine(id: id, name: provider.name, backend: .openAI(url: joined(base, "chat/completions"), headers: headers, model: model), searchesWeb: false, billing: billing)
        }
        switch provider.id {
        case "anthropic":
            guard let key = value("ANTHROPIC_API_KEY") else { break }
            let model = value(AIProviderStore.modelVariable) ?? anthropicDefaultModel
            return .success(ChatEngine(id: id, name: provider.name, backend: .anthropic(key: key, model: model), searchesWeb: false, billing: billing))
        case "openai":
            guard let key = value("OPENAI_API_KEY") else { break }
            return .success(openAI("https://api.openai.com/v1", key: key))
        case "gemini":
            guard let key = value("GEMINI_API_KEY") else { break }
            return .success(openAI("https://generativelanguage.googleapis.com/v1beta/openai", key: key))
        case "kimi":
            guard let key = value("MOONSHOT_API_KEY") else { break }
            return .success(openAI("https://api.moonshot.ai/v1", key: key))
        case "deepseek":
            guard let key = value("DEEPSEEK_API_KEY") else { break }
            return .success(openAI("https://api.deepseek.com/v1", key: key))
        case "azure":
            guard let key = value("AZURE_OPENAI_API_KEY"), let endpoint = value("AZURE_OPENAI_ENDPOINT") else { break }
            let url = joined(endpoint, "openai/deployments/\(model)/chat/completions") + "?api-version=2024-10-21"
            return .success(ChatEngine(id: id, name: provider.name, backend: .openAI(url: url, headers: ["api-key": key], model: model), searchesWeb: false, billing: billing))
        case "ollama":
            return .success(openAI(value("OLLAMA_BASE_URL") ?? "http://localhost:11434/v1", key: nil))
        case "openai-compatible":
            guard let base = value("OPENAI_BASE_URL") else { break }
            return .success(openAI(base, key: nil))
        default:
            return .failure(PlaybookError(message: "Chat can't use \(provider.name) yet. Pick Claude Code or another model in Build."))
        }
        return .failure(PlaybookError(message: "\(provider.name) is missing its key or server. Check it in AI Models."))
    }

    private static func joined(_ base: String, _ path: String) -> String {
        (base.hasSuffix("/") ? String(base.dropLast()) : base) + "/" + path
    }
}

// MARK: - The conversation

enum PlaybookChat {
    /// Turns sent back to the model, so a long chat doesn't grow without end.
    static let historyLimit = 16

    static var schemaObject: [String: Any] {
        func strings(_ names: [String]) -> [String: Any] {
            Dictionary(uniqueKeysWithValues: names.map { ($0, ["type": "string"] as [String: Any]) })
        }
        let libraryFields = ["name", "url", "task", "purpose", "useWhen", "avoidWhen", "install", "platforms", "health", "category", "useInstead", "pairsWith", "reason"]
        var libraryProperties = strings(libraryFields)
        libraryProperties["status"] = ["type": "string", "enum": [""] + LibraryStatus.allCases.map(\.rawValue)]
        let library: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "properties": libraryProperties, "required": libraryFields + ["status"],
        ]
        let ruleFields = ["text", "category", "replaces", "reason"]
        let rule: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "properties": strings(ruleFields), "required": ruleFields,
        ]
        let skillFields = ["name", "description", "body", "reason"]
        let skill: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "properties": strings(skillFields), "required": skillFields,
        ]
        var stackProperties = strings(["notes", "reason"])
        stackProperties["question"] = ["type": "string", "enum": PlaybookQuestions.stack.map(\.id)]
        stackProperties["choices"] = ["type": "array", "items": ["type": "string"]]
        let stack: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "properties": stackProperties, "required": ["question", "choices", "notes", "reason"],
        ]
        var habitProperties = strings(["text", "reason"])
        habitProperties["prompt"] = ["type": "string", "enum": PlaybookQuestions.habits.map(\.id)]
        let habit: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "properties": habitProperties, "required": ["prompt", "text", "reason"],
        ]
        return [
            "type": "object", "additionalProperties": false,
            "properties": [
                "reply": ["type": "string"],
                "libraries": ["type": "array", "items": library],
                "stack": ["type": "array", "items": stack],
                "habits": ["type": "array", "items": habit],
                "rules": ["type": "array", "items": rule],
                "skills": ["type": "array", "items": skill],
            ],
            "required": ["reply", "libraries", "stack", "habits", "rules", "skills"],
        ]
    }

    static var schema: String {
        let data = (try? JSONSerialization.data(withJSONObject: schemaObject, options: [.sortedKeys])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    /// What the model is told: its job, the questions, the playbook now and what the projects use.
    static func instructions(playbook: Playbook, scan: StackScanResult?, searchesWeb: Bool, asksForJSON: Bool, extraContext: String? = nil) -> String {
        var lines: [String] = []
        lines.append("You are the Playbook assistant in Graphitree, a Mac app that keeps a developer's code knowledge base. The playbook tells AI coding tools which libraries to reach for, what new work starts from, and how the owner likes to work. Graphitree writes it into the knowledge base, so every AI tool the owner uses sees it.")
        lines.append("")
        lines.append("Help the owner research choices and fill the playbook in.")
        lines.append("- Write the reply in plain, friendly language: short paragraphs or a short list, Markdown allowed. Recommend one choice rather than listing every option.")
        lines.append(searchesWeb
            ? "- Check facts on the web when they matter, such as the latest release, whether a library is maintained, and its install command."
            : "- You can't browse the web. Say so when something may have changed since your training.")
        lines.append("- Put changes in libraries, stack, habits, rules and skills only when the owner asks for them or agrees to a suggestion. Give each a short reason. The owner reviews every change before it's saved, so say in the reply what you're suggesting. Otherwise leave the lists empty.")
        lines.append("- A library change describes one library fully: name, url, task (2 to 4 words for the job, such as \"Toasts\"; reuse a task already in the playbook when it fits), purpose (one sentence), useWhen, avoidWhen, install, platforms, health (is it maintained: latest release and year). Write \"unknown\" for anything you can't confirm. To update a library already in the playbook, use its exact name.")
        lines.append("- A library change also has a category, a status and useInstead. category is one of the categories below, spelled as shown. status is default (the pick for its job), narrow (kept only for the job or place its notes describe), legacy (stays in projects that use it; not for new work), candidate (being considered; AI tools ask first) or avoid (not for new work). useInstead names what to pick instead, for legacy and avoid; otherwise it's empty. Leave category, status or useInstead empty to keep what the library has now, and only change them when the owner asks.")
        lines.append("- A job has one default. Put what the owner says about where a narrow or legacy library may be used in useWhen and avoidWhen.")
        lines.append("- pairsWith is the exact name of another library in the playbook that this one is used together with, such as react-markdown for remark-gfm: a plugin, a binding or a helper for it. The library is then listed under that one instead of as a job of its own. Write none to unpair it, and leave it empty to keep what it has.")
        lines.append("- A stack change gives the complete new list of choices for one question. Use the option names below where they fit; other names are allowed. notes holds exceptions, or is empty.")
        lines.append("- A habit change gives the complete new text for one prompt. Keep what's already there unless the owner asks to replace it.")
        lines.append("- A rule change adds a rule that isn't about one library, such as \"One primitive system per app\": text is one short instruction, and category is one of the categories below, or empty for a rule that applies everywhere. To change a rule, put its current text in replaces; to remove one, put its text in replaces and leave text empty. Otherwise replaces is empty.")
        lines.append("- A skill change writes one skill in the Agent Skills format that new repos get as .agents/skills/<name>/SKILL.md: name is lowercase letters, digits and single hyphens (it's also the folder); description says what it does and when to use it, in under 1024 characters; body is the instructions in Markdown, without frontmatter. Write it generically, for any of the owner's repos: no project names, paths or details from one repo. To rewrite a skill already in the playbook, use its exact name.")
        if asksForJSON {
            lines.append("- Answer with one JSON object and nothing else: {\"reply\": string, \"libraries\": [...], \"stack\": [...], \"habits\": [...], \"rules\": [...], \"skills\": [...]}, using the fields above, each change with a \"reason\". Stack changes use \"question\", \"choices\" and \"notes\"; habit changes use \"prompt\" and \"text\"; rule changes use \"text\", \"category\" and \"replaces\"; skill changes use \"name\", \"description\" and \"body\".")
        }
        lines.append("")
        lines.append("Categories (name: what goes in it):")
        for category in PlaybookCategories.all {
            lines.append("- \(category.name): \(category.covers)")
        }
        lines.append("")
        lines.append("Stack questions (id: title. Options):")
        for question in PlaybookQuestions.stack {
            lines.append("- \(question.id): \(question.title). \(question.options.map(\.name).joined(separator: ", "))")
        }
        lines.append("")
        lines.append("How-you-work prompts (id: title):")
        for prompt in PlaybookQuestions.habits {
            lines.append("- \(prompt.id): \(prompt.title)")
        }
        lines.append("")
        lines.append("The playbook now:")
        lines.append(playbookText(playbook))
        if let scan = scanText(scan) {
            lines.append("")
            lines.append(scan)
        }
        if let extraContext, !extraContext.isEmpty {
            lines.append("")
            lines.append(extraContext)
        }
        return lines.joined(separator: "\n")
    }

    static func playbookText(_ playbook: Playbook) -> String {
        var lines: [String] = []
        if playbook.libraries.isEmpty {
            lines.append("Libraries: none yet.")
        } else {
            lines.append("Libraries:")
            for library in playbook.libraries.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
                var marks: [String] = [library.verified ? "verified" : "draft"]
                if let status = library.status {
                    marks.append(status.rawValue)
                } else if library.looksAbandoned {
                    marks.append("avoid for new work")
                }
                var line = "- \(library.name)"
                let filed = [library.category, library.task].filter { !$0.isEmpty }
                if !filed.isEmpty { line += " (\(filed.joined(separator: " › ")))" }
                line += " [\(marks.joined(separator: ", "))]"
                if !library.purpose.isEmpty { line += ": \(library.purpose)" }
                if !library.useInstead.isEmpty { line += " Use instead: \(library.useInstead)." }
                if !library.pairsWith.isEmpty { line += " Pairs with: \(library.pairsWith)." }
                if !library.notes.isEmpty { line += " Owner's note: \(library.notes)" }
                lines.append(line)
            }
        }
        let rules = playbook.rules.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if rules.isEmpty {
            lines.append("Rules: none yet.")
        } else {
            lines.append("Rules (exact text, for replaces):")
            for rule in rules {
                let category = PlaybookCategories.canonical(rule.category)
                lines.append("- \(category.isEmpty ? "" : "[\(category)] ")\(rule.text)")
            }
        }
        if playbook.skills.isEmpty {
            lines.append("Skills: none yet.")
        } else {
            lines.append("Skills (exact names):")
            for skill in playbook.skills where !skill.name.isEmpty {
                lines.append("- \(skill.name)\(skill.drafted ? " (draft)" : ""): \(PlaybookFile.oneLine(skill.description))")
            }
        }
        let answered = PlaybookQuestions.stack.filter { !(playbook.stack[$0.id]?.isEmpty ?? true) }
        lines.append(answered.isEmpty ? "Stack: nothing answered yet." : "Stack:")
        for question in answered {
            let answer = playbook.stack[question.id]!
            var line = "- \(question.id): \(answer.choices.isEmpty ? "no default" : answer.choices.joined(separator: ", "))"
            if !answer.notes.isEmpty { line += ". Notes: \(answer.notes)" }
            lines.append(line)
        }
        let habits = PlaybookQuestions.habits.filter { !(playbook.habits[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        lines.append(habits.isEmpty ? "How the owner works: nothing written yet." : "How the owner works:")
        for prompt in habits {
            lines.append("- \(prompt.id): \(playbook.habits[prompt.id]!.replacingOccurrences(of: "\n", with: " "))")
        }
        return lines.joined(separator: "\n")
    }

    /// What the owner's projects use, from Graphitree's scan, so suggestions start from what's real.
    static func scanText(_ scan: StackScanResult?) -> String? {
        guard let scan, scan.projectsScanned > 0 else { return nil }
        var lines = ["What the owner's projects use, from a scan of \(scan.projectsScanned) projects (option: projects):"]
        for question in PlaybookQuestions.stack {
            let used = counted(scan.stack[question.id] ?? [:])
            if !used.isEmpty { lines.append("- \(question.title): \(used)") }
        }
        let libraries = counted(scan.libraries)
        if !libraries.isEmpty { lines.append("- Libraries found: \(libraries)") }
        let others = counted(scan.otherPackages, limit: otherPackagesLimit)
        if !others.isEmpty {
            lines.append("- Other dependencies, as package names the scan doesn't recognise. Build tools are mixed in, so judge which are libraries worth listing: \(others)")
        }
        return lines.joined(separator: "\n")
    }

    /// Enough for every library a person uses, short enough to keep the prompt small.
    static let otherPackagesLimit = 150

    /// "Zod (2), Zustand (2), Lucide (1)": most used first, then by name. Past `limit`, the
    /// rest are counted rather than named.
    private static func counted(_ uses: [String: Set<String>], limit: Int = .max) -> String {
        let pairs: [(name: String, count: Int)] = uses.map { (name: $0.key, count: $0.value.count) }.filter { $0.count > 0 }
        let sorted = pairs.sorted { a, b in a.count == b.count ? a.name < b.name : a.count > b.count }
        var text = sorted.prefix(limit).map { "\($0.name) (\($0.count))" }.joined(separator: ", ")
        if sorted.count > limit { text += ", and \(sorted.count - limit) more" }
        return text
    }

    /// The turns the model sees: recent ones, errors left out, each reply with what it suggested.
    static func history(_ turns: [ChatTurn]) -> [(role: ChatTurn.Role, text: String)] {
        var result: [(role: ChatTurn.Role, text: String)] = []
        for turn in turns.filter({ !$0.isError }).suffix(historyLimit) {
            var text = String(turn.text.prefix(4_000))
            if !turn.changes.isEmpty {
                let notes = turn.changes.map { change -> String in
                    let state = change.state == .applied ? "applied" : change.state == .dismissed ? "declined" : "not decided yet"
                    return "\(label(change)) (\(state))"
                }
                text += "\n[Suggested changes: \(notes.joined(separator: "; "))]"
            }
            // Messages must alternate, so two in a row from the same side are joined.
            if let last = result.last, last.role == turn.role {
                result[result.count - 1].text += "\n\n" + text
            } else {
                result.append((turn.role, text))
            }
        }
        while result.first?.role == .assistant { result.removeFirst() }
        return result
    }

    /// One prompt for `claude -p`, which takes no message list: the earlier turns, then the new one.
    static func cliPrompt(_ turns: [ChatTurn]) -> String {
        let messages = history(turns)
        guard let last = messages.last else { return "" }
        let earlier = messages.dropLast()
        if earlier.isEmpty { return last.text }
        var lines = ["The conversation so far:", ""]
        for message in earlier {
            lines.append("\(message.role == .user ? "Owner" : "You"): \(message.text)")
            lines.append("")
        }
        lines.append("The owner's new message:")
        lines.append(last.text)
        return lines.joined(separator: "\n")
    }

    static func cliArguments(prompt: String, instructions: String) -> [String] {
        [
            "-p", prompt,
            "--system-prompt", instructions,
            "--output-format", "json",
            "--json-schema", schema,
            "--tools", "WebSearch,WebFetch",
            "--allowedTools", "WebSearch,WebFetch",
            "--permission-mode", "dontAsk",
            "--setting-sources", "project",
            "--strict-mcp-config",
            "--no-session-persistence",
        ]
    }

    // MARK: Reading replies

    /// Claude Code's JSON result: `structured_output`, or JSON in `result` as a fallback.
    static func parseCLI(_ output: String) throws -> ChatReply {
        guard let data = output.data(using: .utf8),
              let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlaybookError(message: "Claude Code's reply wasn't JSON.")
        }
        if envelope["is_error"] as? Bool == true {
            throw PlaybookError(message: (envelope["result"] as? String) ?? "Claude Code reported an error.")
        }
        if let object = envelope["structured_output"] as? [String: Any] {
            return reply(from: object)
        }
        return parseLoose((envelope["result"] as? String) ?? "")
    }

    /// A reply that should be JSON but may come wrapped in a code fence or prose. Plain text still
    /// shows as the reply, just without changes.
    static func parseLoose(_ text: String) -> ChatReply {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}"), start < end,
           let data = String(trimmed[start...end]).data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["reply"] != nil {
            return reply(from: object)
        }
        return ChatReply(text: trimmed, changes: [])
    }

    static func reply(from object: [String: Any]) -> ChatReply {
        var changes: [PlaybookChange] = []
        func text(_ item: [String: Any], _ key: String) -> String {
            ((item[key] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for item in object["libraries"] as? [[String: Any]] ?? [] {
            let draft = LibraryDraft(
                name: text(item, "name"), url: text(item, "url"), task: text(item, "task"), purpose: text(item, "purpose"),
                useWhen: text(item, "useWhen"), avoidWhen: text(item, "avoidWhen"), install: text(item, "install"),
                platforms: text(item, "platforms"), health: text(item, "health"),
                status: text(item, "status"), category: text(item, "category"), useInstead: text(item, "useInstead"),
                pairsWith: text(item, "pairsWith")
            )
            guard !draft.name.isEmpty else { continue }
            changes.append(PlaybookChange(kind: .library, reason: text(item, "reason"), library: draft))
        }
        for item in object["stack"] as? [[String: Any]] ?? [] {
            let question = text(item, "question")
            guard PlaybookQuestions.stack.contains(where: { $0.id == question }) else { continue }
            let choices = (item["choices"] as? [String] ?? []).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            changes.append(PlaybookChange(kind: .stack, reason: text(item, "reason"), question: question, choices: choices, notes: text(item, "notes")))
        }
        for item in object["habits"] as? [[String: Any]] ?? [] {
            let prompt = text(item, "prompt")
            let body = text(item, "text")
            guard PlaybookQuestions.habits.contains(where: { $0.id == prompt }), !body.isEmpty else { continue }
            changes.append(PlaybookChange(kind: .habit, reason: text(item, "reason"), habit: prompt, text: body))
        }
        for item in object["rules"] as? [[String: Any]] ?? [] {
            let rule = RuleDraft(text: text(item, "text"), category: PlaybookCategories.canonical(text(item, "category")), replaces: text(item, "replaces"))
            guard !rule.text.isEmpty || !rule.replaces.isEmpty else { continue }
            changes.append(PlaybookChange(kind: .rule, reason: text(item, "reason"), rule: rule))
        }
        for item in object["skills"] as? [[String: Any]] ?? [] {
            let name = text(item, "name")
            let draft = SkillDraft(name: PlaybookSkill.isValidName(name) ? name : PlaybookSkill.suggestedName(name), description: text(item, "description"), body: text(item, "body"))
            guard !draft.name.isEmpty, !draft.body.isEmpty else { continue }
            changes.append(PlaybookChange(kind: .skill, reason: text(item, "reason"), skill: draft))
        }
        return ChatReply(text: text(object, "reply"), changes: changes)
    }

    // MARK: Applying changes

    private static func key(_ name: String) -> String { name.lowercased().filter { $0.isLetter || $0.isNumber } }

    static func existingLibrary(_ change: PlaybookChange, in playbook: Playbook) -> PlaybookLibrary? {
        guard let name = change.library?.name else { return nil }
        return playbook.libraries.first { key($0.name) == key(name) }
    }

    /// The playbook with one change in it. Library details count as a draft until the person verifies them.
    static func applying(_ change: PlaybookChange, to playbook: Playbook) -> Playbook {
        var result = playbook
        switch change.kind {
        case .library:
            guard let draft = change.library else { return result }
            if let index = result.libraries.firstIndex(where: { key($0.name) == key(draft.name) }) {
                result.libraries[index] = PlaybookResearch.applying(draft, to: result.libraries[index])
            } else {
                result.libraries.append(PlaybookResearch.applying(draft, to: PlaybookLibrary(name: draft.name)))
            }
        case .stack:
            guard let id = change.question, let question = PlaybookQuestions.stack.first(where: { $0.id == id }) else { return result }
            // A known option keeps its own spelling, so its chip lights up.
            var choices: [String] = []
            for choice in change.choices {
                let named = question.options.first { $0.name.caseInsensitiveCompare(choice) == .orderedSame }?.name ?? choice
                if !choices.contains(named) { choices.append(named) }
            }
            var answer = result.stack[id] ?? StackAnswer()
            answer.choices = choices
            if !change.notes.isEmpty { answer.notes = change.notes }
            result.stack[id] = answer
        case .habit:
            guard let id = change.habit else { return result }
            result.habits[id] = change.text
        case .rule:
            guard let draft = change.rule else { return result }
            let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let category = PlaybookCategories.canonical(draft.category)
            let target = key(draft.replaces)
            if !target.isEmpty, let index = result.rules.firstIndex(where: { key($0.text) == target }) {
                if text.isEmpty {
                    result.rules.remove(at: index)
                } else {
                    result.rules[index].text = text
                    result.rules[index].category = category
                }
            } else if !text.isEmpty, !result.rules.contains(where: { key($0.text) == key(text) }) {
                result.rules.append(PlaybookRule(text: text, category: category))
            }
        case .skill:
            guard let draft = change.skill else { return result }
            if let index = result.skills.firstIndex(where: { $0.name == draft.name }) {
                if !draft.description.isEmpty { result.skills[index].description = draft.description }
                result.skills[index].body = draft.body
                result.skills[index].drafted = true
            } else {
                result.skills.append(PlaybookSkill(name: draft.name, description: draft.description, body: draft.body, drafted: true))
            }
        }
        return result
    }

    /// A short name for a change, such as "Add Sonner" or "UI components: shadcn/ui, Radix UI".
    static func label(_ change: PlaybookChange, in playbook: Playbook? = nil) -> String {
        switch change.kind {
        case .library:
            let name = change.library?.name ?? "a library"
            if let playbook { return existingLibrary(change, in: playbook) == nil ? "Add \(name)" : "Update \(name)" }
            return "Library \(name)"
        case .stack:
            let title = PlaybookQuestions.stack.first { $0.id == change.question }?.title ?? "Stack"
            return "\(title): \(change.choices.isEmpty ? "no default" : change.choices.joined(separator: ", "))"
        case .habit:
            return PlaybookQuestions.habits.first { $0.id == change.habit }?.title ?? "How you work"
        case .rule:
            guard let rule = change.rule else { return "A rule" }
            let area = rule.category.isEmpty ? "" : " (\(rule.category))"
            if rule.text.isEmpty { return "Remove rule: \(rule.replaces)" }
            return rule.replaces.isEmpty ? "Add rule\(area): \(rule.text)" : "Change rule\(area): \(rule.text)"
        case .skill:
            let name = change.skill?.name ?? "a skill"
            if let playbook { return playbook.skills.contains { $0.name == name } ? "Rewrite skill \(name)" : "Add skill \(name)" }
            return "Skill \(name)"
        }
    }

    // MARK: Sending

    static func send(
        _ turns: [ChatTurn],
        playbook: Playbook,
        scan: StackScanResult?,
        engine: ChatEngine,
        extraContext: String? = nil,
        onProcess: @escaping @Sendable (Process) -> Void = { _ in }
    ) async throws -> ChatReply {
        switch engine.backend {
        case .claudeCode(let command):
            let instructions = instructions(playbook: playbook, scan: scan, searchesWeb: true, asksForJSON: false, extraContext: extraContext)
            let arguments = cliArguments(prompt: cliPrompt(turns), instructions: instructions)
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-chat-\(UUID().uuidString)")
                        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
                        defer { try? FileManager.default.removeItem(at: scratch) }
                        let result = try ProcessRunner.run(command, arguments, in: scratch, timeout: 300, onStart: onProcess)
                        if result.timedOut { throw PlaybookError(message: "Claude Code stopped before it answered.") }
                        if result.status != 0 && result.output.isEmpty {
                            let errors = result.errors.trimmingCharacters(in: .whitespacesAndNewlines)
                            throw PlaybookError(message: errors.isEmpty ? "Claude Code stopped with exit \(result.status)." : errors)
                        }
                        continuation.resume(returning: try parseCLI(result.output))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        case .anthropic(let key, let model):
            return try await sendAnthropic(turns, playbook: playbook, scan: scan, key: key, model: model, extraContext: extraContext)
        case .openAI(let url, let headers, let model):
            return try await sendOpenAI(turns, playbook: playbook, scan: scan, url: url, headers: headers, model: model, extraContext: extraContext)
        }
    }

    /// Models that take the server-side fallback for refusals.
    static let fallbackModels: Set<String> = ["claude-fable-5-2", "claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5"]

    static func anthropicBody(_ turns: [ChatTurn], playbook: Playbook, scan: StackScanResult?, model: String, structured: Bool, extraContext: String? = nil) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 16_000,
            "system": instructions(playbook: playbook, scan: scan, searchesWeb: false, asksForJSON: !structured, extraContext: extraContext),
            "messages": history(turns).map { ["role": $0.role.rawValue, "content": $0.text] },
        ]
        if structured {
            body["output_config"] = ["format": ["type": "json_schema", "schema": schemaObject]]
            if fallbackModels.contains(model) { body["fallbacks"] = "default" }
        }
        return body
    }

    private static func sendAnthropic(_ turns: [ChatTurn], playbook: Playbook, scan: StackScanResult?, key: String, model: String, extraContext: String?) async throws -> ChatReply {
        var headers = ["x-api-key": key, "anthropic-version": "2026-10-21"]
        // Structured output first; a model that doesn't take it gets the plain request.
        for structured in [true, false] {
            if structured && fallbackModels.contains(model) { headers["anthropic-beta"] = "server-side-fallback-2026-07-01" } else { headers["anthropic-beta"] = nil }
            let body = anthropicBody(turns, playbook: playbook, scan: scan, model: model, structured: structured, extraContext: extraContext)
            let (status, object) = try await post("https://api.anthropic.com/v1/messages", headers: headers, body: body)
            if status == 400 && structured { continue }
            guard (200..<300).contains(status) else { throw PlaybookError(message: apiError(object, status: status)) }
            if object["stop_reason"] as? String == "refusal" {
                throw PlaybookError(message: "The model declined to answer that. Try asking another way.")
            }
            let text = (object["content"] as? [[String: Any]] ?? []).filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
            return parseLoose(text)
        }
        throw PlaybookError(message: "The Anthropic API didn't accept the request.")
    }

    private static func sendOpenAI(_ turns: [ChatTurn], playbook: Playbook, scan: StackScanResult?, url: String, headers: [String: String], model: String, extraContext: String?) async throws -> ChatReply {
        var messages: [[String: Any]] = [["role": "system", "content": instructions(playbook: playbook, scan: scan, searchesWeb: false, asksForJSON: true, extraContext: extraContext)]]
        messages += history(turns).map { ["role": $0.role.rawValue, "content": $0.text] }
        let (status, object) = try await post(url, headers: headers, body: ["model": model, "messages": messages])
        guard (200..<300).contains(status) else { throw PlaybookError(message: apiError(object, status: status)) }
        let message = ((object["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]) ?? [:]
        return parseLoose((message["content"] as? String) ?? "")
    }

    private static func post(_ address: String, headers: [String: String], body: [String: Any]) async throws -> (Int, [String: Any]) {
        guard let url = URL(string: address) else { throw PlaybookError(message: "The server address \(address) isn't valid.") }
        var request = URLRequest(url: url, timeoutInterval: 300)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let object = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? ["raw": String(decoding: data.prefix(500), as: UTF8.self)]
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, object)
    }

    private static func apiError(_ object: [String: Any], status: Int) -> String {
        if let error = object["error"] as? [String: Any], let message = error["message"] as? String { return "The model's server said: \(message)" }
        if let message = object["error"] as? String { return "The model's server said: \(message)" }
        return "The model's server answered with HTTP \(status)."
    }
}

// MARK: - The monthly library check

enum PlaybookCheck {
    /// Changes worth showing after re-researching libraries: one that now looks abandoned or
    /// maintained again, a new install command, or a first health note. Small rewordings aren't.
    static func changes(for libraries: [PlaybookLibrary], drafts: [UUID: LibraryDraft]) -> [PlaybookChange] {
        libraries.compactMap { library in
            guard let draft = drafts[library.id] else { return nil }
            let updated = PlaybookResearch.applying(draft, to: library)
            var reasons: [String] = []
            if updated.looksAbandoned && !library.looksAbandoned { reasons.append("now looks unmaintained: \(updated.health)") }
            if !updated.looksAbandoned && library.looksAbandoned { reasons.append("looks maintained again: \(updated.health)") }
            if library.health.isEmpty && !updated.health.isEmpty { reasons.append("has no health note yet") }
            let install = draft.install.trimmingCharacters(in: .whitespacesAndNewlines)
            if !library.install.isEmpty, !install.isEmpty, install.lowercased() != "unknown", install != library.install {
                reasons.append("install is now `\(install)`")
            }
            guard !reasons.isEmpty else { return nil }
            var named = draft
            named.name = library.name
            return PlaybookChange(kind: .library, reason: library.name + " " + reasons.joined(separator: "; "), library: named)
        }
    }

    static func summary(checked: Int, changes: [PlaybookChange]) -> String {
        changes.isEmpty
            ? "Library check: I looked at \(checked) librar\(checked == 1 ? "y" : "ies") on the web, and nothing important changed."
            : "Library check: I looked at \(checked) librar\(checked == 1 ? "y" : "ies") on the web. \(changes.count) changed in a way that matters. Apply what you agree with."
    }
}

/// The running `claude` process, so Stop can end it from another thread.
final class ChatProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var stopped = false

    func started(_ process: Process) {
        lock.lock()
        defer { lock.unlock() }
        self.process = process
        if stopped { process.terminate() }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        stopped = true
        if process?.isRunning == true { process?.terminate() }
    }

    var wasStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }
}

/// Keeps each graph's chat between launches, outside the knowledge base.
enum ChatStore {
    static let keptTurns = 200

    static func url(for outDirectory: URL) -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let name = outDirectory.standardizedFileURL.path.map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        return support.appendingPathComponent("Graphitree/Chats/\(name).json")
    }

    static func load(for outDirectory: URL) -> [ChatTurn] {
        guard let data = try? Data(contentsOf: url(for: outDirectory)) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ChatTurn].self, from: data)) ?? []
    }

    static func save(_ turns: [ChatTurn], for outDirectory: URL) {
        let url = url(for: outDirectory)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(Array(turns.suffix(keptTurns))) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

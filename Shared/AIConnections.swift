import Foundation
import Security

// Everything Graphitree can connect, split by what it's for:
// - building the graph: coding tools you sign in to, API keys, and models on this Mac;
// - asking the knowledge base: chat apps, through Graphitree's own MCP server (`graphitree mcp`).
// A coding tool does both, so connecting it sets up both.

// MARK: - Coding tools

/// A coding agent that signs in with its own account. It can run graphify's skill to build the
/// graph, and it works in your repos, so it can read the guide too.
struct CodingTool: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// What the person signs in with.
    let account: String
    /// graphify's name for the tool, as in `graphify install --platform <platform>`.
    let platform: String
    /// Commands whose presence means the tool is installed.
    let commands: [String]
    /// App bundles whose presence means the tool is installed.
    let apps: [String]
    /// Where graphify puts its skill, from the home folder.
    let skillPath: String
    /// The instructions file the tool reads at the start of every session, from the home folder.
    let instructionsPath: String
    /// What else graphify's installer changes, said in the preview.
    let installerAlsoChanges: String?
    /// How to build the graph from inside the tool.
    let buildHint: String
    /// The graphify backend Graphitree can drive with this tool's sign-in, if there is one.
    let graphitreeBackend: String?

    func skillFile(home: String) -> String { home + "/" + skillPath }
    func instructionsFile(home: String) -> String { home + "/" + instructionsPath }
    var installArguments: [String] { ["install", "--platform", platform] }
}

/// Another tool graphify can install its skill into. Graphitree lists these but doesn't set them up.
struct OtherSkillTool: Hashable, Sendable {
    let name: String
    let platform: String
}

// MARK: - Models graphify calls itself

/// A model graphify can call directly while it builds, with an API key or on this Mac.
struct ModelProvider: Identifiable, Hashable, Sendable {
    enum Access: Hashable, Sendable {
        case apiKey
        case local
    }

    struct Setting: Hashable, Sendable {
        /// The environment variable graphify reads.
        let variable: String
        let label: String
        let placeholder: String
        let isSecret: Bool
        let isRequired: Bool
    }

    let id: String
    /// graphify's `--backend` name.
    let backend: String
    let name: String
    let access: Access
    /// graphify's default model, shown as the placeholder for the model field.
    let defaultModel: String
    let settings: [Setting]
    /// Set for the person when they can't be asked, such as the key a local server ignores.
    let fixedEnvironment: [String: String]
    /// The Python module graphify needs to talk to this provider.
    let module: String
    /// Where to get a key, or how to start the server.
    let note: String
    /// Whether the model field must be filled, because there's no sensible default.
    let needsModel: Bool
}

// MARK: - Chat apps

/// An app that can ask Graphitree's MCP server. Chat apps can't build the graph.
struct ChatApp: Identifiable, Hashable, Sendable {
    enum Format: Hashable, Sendable {
        /// `{"mcpServers": {name: {command, args}}}`, used by most clients.
        case mcpServers
        /// VS Code's `{"servers": {name: {type: "stdio", command, args}}}`.
        case vscode
    }

    let id: String
    let name: String
    let detail: String
    let apps: [String]
    /// The MCP settings file, from the home folder.
    let configPath: String
    let format: Format

    func configFile(home: String) -> String { home + "/" + configPath }
}

// MARK: - The catalog

enum AICatalog {
    static let codingTools: [CodingTool] = [
        CodingTool(
            id: "claude-code",
            name: "Claude Code",
            account: "Claude Pro or Max plan, or an Anthropic API key",
            platform: "claude",
            commands: ["claude"],
            apps: ["Claude.app"],
            skillPath: ".claude/skills/graphify/SKILL.md",
            instructionsPath: ".claude/CLAUDE.md",
            installerAlsoChanges: "graphify also lists its skill in ~/.claude/CLAUDE.md, so /graphify works.",
            buildHint: "Type /graphify in Claude Code, including the Code tab in the Claude app. Graphitree can also build with this plan.",
            graphitreeBackend: "claude-cli"
        ),
        CodingTool(
            id: "codex",
            name: "Codex CLI",
            account: "ChatGPT Plus, Pro or Business, or an OpenAI API key",
            platform: "codex",
            commands: ["codex"],
            apps: ["Codex.app"],
            skillPath: ".codex/skills/graphify/SKILL.md",
            instructionsPath: ".codex/AGENTS.md",
            installerAlsoChanges: nil,
            buildHint: "Ask Codex to run the graphify skill on a folder.",
            graphitreeBackend: nil
        ),
        CodingTool(
            id: "gemini",
            name: "Gemini CLI",
            account: "A Google account (free tier), or a Gemini API key",
            platform: "gemini",
            commands: ["gemini"],
            apps: [],
            skillPath: ".gemini/skills/graphify/SKILL.md",
            instructionsPath: ".gemini/GEMINI.md",
            installerAlsoChanges: nil,
            buildHint: "Type /graphify in Gemini CLI.",
            graphitreeBackend: nil
        ),
        CodingTool(
            id: "copilot",
            name: "GitHub Copilot CLI",
            account: "A GitHub Copilot plan",
            platform: "copilot",
            commands: ["copilot"],
            apps: [],
            skillPath: ".copilot/skills/graphify/SKILL.md",
            instructionsPath: ".copilot/copilot-instructions.md",
            installerAlsoChanges: nil,
            buildHint: "Type /graphify in Copilot CLI.",
            graphitreeBackend: nil
        ),
        CodingTool(
            id: "opencode",
            name: "OpenCode",
            account: "Any provider it supports, by sign-in or API key",
            platform: "opencode",
            commands: ["opencode"],
            apps: [],
            skillPath: ".config/opencode/skills/graphify/SKILL.md",
            instructionsPath: ".config/opencode/AGENTS.md",
            installerAlsoChanges: "graphify also adds its OpenCode plugin to ~/.config/opencode/plugins.",
            buildHint: "Type /graphify in OpenCode.",
            graphitreeBackend: nil
        ),
    ]

    /// Tools graphify's own installer supports that Graphitree doesn't set up.
    static let otherSkillTools: [OtherSkillTool] = [
        OtherSkillTool(name: "Kimi CLI", platform: "kimi"),
        OtherSkillTool(name: "Amp", platform: "amp"),
        OtherSkillTool(name: "Factory Droid", platform: "droid"),
        OtherSkillTool(name: "Kiro", platform: "kiro"),
        OtherSkillTool(name: "Kilo Code", platform: "kilo"),
        OtherSkillTool(name: "Aider", platform: "aider"),
        OtherSkillTool(name: "Trae", platform: "trae"),
        OtherSkillTool(name: "OpenClaw", platform: "claw"),
        OtherSkillTool(name: "Hermes", platform: "hermes"),
        OtherSkillTool(name: "Pi", platform: "pi"),
        OtherSkillTool(name: "CodeBuddy", platform: "codebuddy"),
        OtherSkillTool(name: "Devin CLI", platform: "devin"),
        OtherSkillTool(name: "Google Antigravity", platform: "antigravity"),
        OtherSkillTool(name: "Any Agent Skills tool", platform: "agents"),
    ]

    private static func key(_ variable: String, _ label: String = "API key") -> ModelProvider.Setting {
        ModelProvider.Setting(variable: variable, label: label, placeholder: "Paste the key", isSecret: true, isRequired: true)
    }

    static let providers: [ModelProvider] = [
        ModelProvider(
            id: "anthropic", backend: "claude", name: "Anthropic (Claude)", access: .apiKey,
            defaultModel: "claude-sonnet-4-6", settings: [key("ANTHROPIC_API_KEY")], fixedEnvironment: [:],
            module: "anthropic", note: "Get a key at console.anthropic.com. Billed per use.", needsModel: false
        ),
        ModelProvider(
            id: "openai", backend: "openai", name: "OpenAI (GPT)", access: .apiKey,
            defaultModel: "gpt-4.1-mini", settings: [key("OPENAI_API_KEY")], fixedEnvironment: [:],
            module: "openai", note: "Get a key at platform.openai.com. Billed per use.", needsModel: false
        ),
        ModelProvider(
            id: "gemini", backend: "gemini", name: "Google Gemini", access: .apiKey,
            defaultModel: "gemini-3-flash-preview", settings: [key("GEMINI_API_KEY")], fixedEnvironment: [:],
            module: "openai", note: "Get a key at aistudio.google.com. Has a free tier.", needsModel: false
        ),
        ModelProvider(
            id: "kimi", backend: "kimi", name: "Moonshot Kimi", access: .apiKey,
            defaultModel: "kimi-k2.6", settings: [key("MOONSHOT_API_KEY")], fixedEnvironment: [:],
            module: "openai", note: "Get a key at platform.moonshot.ai. Billed per use.", needsModel: false
        ),
        ModelProvider(
            id: "deepseek", backend: "deepseek", name: "DeepSeek", access: .apiKey,
            defaultModel: "deepseek-v4-flash", settings: [key("DEEPSEEK_API_KEY")], fixedEnvironment: [:],
            module: "openai", note: "Get a key at platform.deepseek.com. Billed per use.", needsModel: false
        ),
        ModelProvider(
            id: "azure", backend: "azure", name: "Azure OpenAI", access: .apiKey,
            defaultModel: "gpt-4o",
            settings: [
                key("AZURE_OPENAI_API_KEY"),
                ModelProvider.Setting(variable: "AZURE_OPENAI_ENDPOINT", label: "Endpoint", placeholder: "https://name.openai.azure.com", isSecret: false, isRequired: true),
            ],
            fixedEnvironment: [:],
            module: "openai", note: "Your organisation's Azure deployment. The model is the deployment name.", needsModel: false
        ),
        ModelProvider(
            id: "bedrock", backend: "bedrock", name: "Amazon Bedrock", access: .apiKey,
            defaultModel: "anthropic.claude-3-5-sonnet-20241022-v2:0",
            settings: [
                ModelProvider.Setting(variable: "AWS_PROFILE", label: "AWS profile", placeholder: "default", isSecret: false, isRequired: true),
                ModelProvider.Setting(variable: "AWS_REGION", label: "Region", placeholder: "us-east-1", isSecret: false, isRequired: true),
            ],
            fixedEnvironment: [:],
            module: "boto3", note: "Signs in with a profile from ~/.aws, so there's no key to paste here.", needsModel: false
        ),
        ModelProvider(
            id: "ollama", backend: "ollama", name: "Ollama", access: .local,
            defaultModel: "qwen2.5-coder:7b",
            settings: [
                ModelProvider.Setting(variable: "OLLAMA_BASE_URL", label: "Server", placeholder: "http://localhost:11434/v1", isSecret: false, isRequired: false),
            ],
            fixedEnvironment: [:],
            module: "openai", note: "Free and private. Install it from ollama.com, then pull a model.", needsModel: false
        ),
        ModelProvider(
            id: "openai-compatible", backend: "openai", name: "LM Studio, llama.cpp or vLLM", access: .local,
            defaultModel: "the model your server serves",
            settings: [
                ModelProvider.Setting(variable: "OPENAI_BASE_URL", label: "Server", placeholder: "http://localhost:1234/v1", isSecret: false, isRequired: true),
            ],
            // graphify insists on a key for the OpenAI backend; local servers ignore it.
            fixedEnvironment: ["OPENAI_API_KEY": "local"],
            module: "openai", note: "Any server on this Mac that speaks the OpenAI API.", needsModel: true
        ),
    ]

    static let chatApps: [ChatApp] = [
        ChatApp(
            id: "claude-desktop", name: "Claude Desktop",
            detail: "Chats in the Claude app. Its Code tab is Claude Code, which is set up under Build the graph.",
            apps: ["Claude.app"], configPath: "Library/Application Support/Claude/claude_desktop_config.json", format: .mcpServers
        ),
        ChatApp(
            id: "cursor", name: "Cursor",
            detail: "Cursor's agent and chat.",
            apps: ["Cursor.app"], configPath: ".cursor/mcp.json", format: .mcpServers
        ),
        ChatApp(
            id: "windsurf", name: "Windsurf",
            detail: "Windsurf's Cascade agent.",
            apps: ["Windsurf.app"], configPath: ".codeium/windsurf/mcp_config.json", format: .mcpServers
        ),
        ChatApp(
            id: "vscode", name: "VS Code (Copilot Chat)",
            detail: "Agent mode in Copilot Chat.",
            apps: ["Visual Studio Code.app"], configPath: "Library/Application Support/Code/User/mcp.json", format: .vscode
        ),
        ChatApp(
            id: "lmstudio", name: "LM Studio",
            detail: "Chats with models on this Mac.",
            apps: ["LM Studio.app"], configPath: ".lmstudio/mcp.json", format: .mcpServers
        ),
    ]
}

// MARK: - Finding tools on this Mac

enum ToolLocator {
    /// Folders where command-line tools usually live. Apps launched from Finder don't get the shell's PATH.
    static func commandFolders(home: String) -> [String] {
        var folders = [
            home + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", home + "/.npm-global/bin",
            home + "/.bun/bin", home + "/.volta/bin", home + "/.cargo/bin", home + "/bin", home + "/.opencode/bin",
        ]
        let nvm = home + "/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvm) {
            folders += versions.sorted().reversed().map { "\(nvm)/\($0)/bin" }
        }
        return folders
    }

    static func command(_ names: [String], home: String) -> String? {
        for folder in commandFolders(home: home) {
            for name in names where FileManager.default.isExecutableFile(atPath: "\(folder)/\(name)") {
                return "\(folder)/\(name)"
            }
        }
        return nil
    }

    static func app(_ names: [String], home: String) -> String? {
        for folder in ["/Applications", home + "/Applications"] {
            for name in names where FileManager.default.fileExists(atPath: "\(folder)/\(name)") {
                return "\(folder)/\(name)"
            }
        }
        return nil
    }

    static func isInstalled(_ tool: CodingTool, home: String) -> Bool {
        command(tool.commands, home: home) != nil || app(tool.apps, home: home) != nil
    }

    static func isInstalled(_ app: ChatApp, home: String) -> Bool {
        self.app(app.apps, home: home) != nil
    }
}

// MARK: - State

/// Which of a coding tool's two sides are set up.
struct CodingToolState: Equatable, Sendable {
    var isInstalled: Bool
    /// graphify's skill is in the tool, so it can build the graph.
    var builds: Bool
    /// Graphitree's pointer is in the tool's instructions, so it reads the guide.
    var reads: Bool

    var isConnected: Bool { builds && reads }
    var isPartial: Bool { builds != reads }

    static func read(_ tool: CodingTool, home: String) -> CodingToolState {
        let instructions = (try? String(contentsOfFile: tool.instructionsFile(home: home), encoding: .utf8)) ?? ""
        return CodingToolState(
            isInstalled: ToolLocator.isInstalled(tool, home: home),
            builds: FileManager.default.fileExists(atPath: tool.skillFile(home: home)),
            reads: AgentSetup.isConnected(instructions)
        )
    }
}

// MARK: - Keys and settings

/// Secrets live in the login Keychain, one item per provider setting.
struct AIKeychain: Sendable {
    let service: String

    static let standard = AIKeychain(service: "Graphitree AI keys")

    func read(_ account: String) -> String? {
        Self.item(account, service: service)
    }

    private static func item(_ account: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ value: String, for account: String) throws {
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let data = Data(value.utf8)
        let status = SecItemUpdate(match as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = match
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "Graphitree: \(account)"
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    func delete(_ account: String) {
        Self.deleteItem(account, service: service)
    }

    private static func deleteItem(_ account: String, service: String) {
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(match as CFDictionary)
    }

    struct KeychainError: LocalizedError {
        let status: OSStatus
        var errorDescription: String? {
            (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)"
        }
    }
}

/// Settings for the models graphify calls itself. Secrets go to the Keychain, the rest to defaults.
struct AIProviderStore: @unchecked Sendable {
    let defaults: UserDefaults
    let keychain: AIKeychain

    static let standard = AIProviderStore(defaults: .standard, keychain: .standard)

    private static let settingsKey = "aiProviderSettings"
    static let modelVariable = "model"

    private func account(_ provider: ModelProvider, _ variable: String) -> String { "\(provider.id).\(variable)" }

    private var allPlain: [String: [String: String]] {
        defaults.dictionary(forKey: Self.settingsKey) as? [String: [String: String]] ?? [:]
    }

    /// Every saved value for the provider, secrets included, keyed by variable (and `model`).
    func values(for provider: ModelProvider) -> [String: String] {
        var result = allPlain[provider.id] ?? [:]
        for setting in provider.settings where setting.isSecret {
            if let secret = keychain.read(account(provider, setting.variable)) { result[setting.variable] = secret }
        }
        return result
    }

    func isConfigured(_ provider: ModelProvider) -> Bool {
        let saved = values(for: provider)
        // A provider with nothing to fill in still counts as set up only once it's been saved.
        guard allPlain[provider.id] != nil || provider.settings.contains(where: \.isSecret) else { return false }
        let settingsFilled = provider.settings.filter(\.isRequired).allSatisfy { !(saved[$0.variable] ?? "").isEmpty }
        let modelFilled = !provider.needsModel || !(saved[Self.modelVariable] ?? "").isEmpty
        return settingsFilled && modelFilled
    }

    func save(_ values: [String: String], for provider: ModelProvider) throws {
        var plain: [String: String] = [:]
        for setting in provider.settings {
            let value = (values[setting.variable] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if setting.isSecret {
                if value.isEmpty { continue } // Leaving a key blank keeps the saved one.
                try keychain.save(value, for: account(provider, setting.variable))
            } else if !value.isEmpty {
                plain[setting.variable] = value
            }
        }
        let model = (values[Self.modelVariable] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty { plain[Self.modelVariable] = model }
        var all = allPlain
        all[provider.id] = plain
        defaults.set(all, forKey: Self.settingsKey)
    }

    func remove(_ provider: ModelProvider) {
        for setting in provider.settings where setting.isSecret {
            keychain.delete(account(provider, setting.variable))
        }
        var all = allPlain
        all[provider.id] = nil
        defaults.set(all, forKey: Self.settingsKey)
    }
}

// MARK: - Building with a model

/// A second pass after `graphify update`: `graphify extract`, which sends new or changed docs,
/// papers and images to a model, then `graphify label`, which names new groups with it.
struct DocsPass: Equatable, Sendable {
    enum Billing: Equatable, Sendable {
        case plan
        case apiAccount
        case thisMac
    }

    let name: String
    let backend: String
    let model: String?
    let environment: [String: String]
    let billing: Billing
    /// The Python module graphify needs for this backend, if any.
    let module: String?

    /// `extract` reads the docs; `label --missing-only` then names only the groups that have no
    /// real name yet (update gives them stand-ins) and rewrites the report, which `extract` leaves alone.
    func steps(root: String) -> [[String]] {
        [
            ["extract", root, "--backend", backend] + (model.map { ["--model", $0] } ?? []),
            ["label", root, "--missing-only", "--backend=\(backend)"] + (model.map { ["--model=\($0)"] } ?? []),
        ]
    }
}

/// Which model Graphitree's rebuild uses for docs. Stored as a coding tool's or provider's id.
enum BuildChoice {
    static let defaultsKey = "buildModel"

    /// Every choice that is set up right now, as (id, name).
    static func options(home: String, store: AIProviderStore) -> [(id: String, name: String)] {
        var result: [(String, String)] = []
        for tool in AICatalog.codingTools where tool.graphitreeBackend != nil && ToolLocator.command(tool.commands, home: home) != nil {
            result.append((tool.id, "\(tool.name), with your plan"))
        }
        for provider in AICatalog.providers where store.isConfigured(provider) {
            result.append((provider.id, provider.name))
        }
        return result
    }

    static func docsPass(for id: String, home: String, store: AIProviderStore) -> DocsPass? {
        if let tool = AICatalog.codingTools.first(where: { $0.id == id }), let backend = tool.graphitreeBackend {
            guard ToolLocator.command(tool.commands, home: home) != nil else { return nil }
            return DocsPass(name: tool.name, backend: backend, model: nil, environment: Self.environment(forCodingBackend: backend), billing: .plan, module: nil)
        }
        guard let provider = AICatalog.providers.first(where: { $0.id == id }), store.isConfigured(provider) else { return nil }
        let values = store.values(for: provider)
        var environment = provider.fixedEnvironment
        for setting in provider.settings {
            if let value = values[setting.variable], !value.isEmpty { environment[setting.variable] = value }
        }
        let model = values[AIProviderStore.modelVariable].flatMap { $0.isEmpty ? nil : $0 }
        return DocsPass(
            name: provider.name,
            backend: provider.backend,
            model: model,
            environment: environment,
            billing: provider.access == .local ? .thisMac : .apiAccount,
            module: provider.module
        )
    }

    /// graphify gives each call 10 minutes, then throws the work away and retries the chunk in
    /// halves. A Claude Code call over a chunk heavy with images can need longer than that, so it
    /// gets 30 minutes: a slow chunk finishes once instead of being paid for again in pieces.
    static func environment(forCodingBackend backend: String) -> [String: String] {
        backend == "claude-cli" ? ["GRAPHIFY_API_TIMEOUT": "1800"] : [:]
    }
}

// MARK: - graphify's optional modules

/// graphify talks to most providers, and serves MCP, through optional Python modules.
enum GraphifyModules {
    static let tracked = ["mcp", "openai", "anthropic", "boto3"]

    /// The modules graphify's Python can import. Empty when graphify isn't found.
    static func available(python: String) -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        let names = tracked.map { "'\($0)'" }.joined(separator: ",")
        process.arguments = ["-c", "import importlib.util as u\nfor m in [\(names)]:\n    print(m if u.find_spec(m) else '')"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return [] }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Set(String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init).filter { !$0.isEmpty })
    }

    /// The command that adds modules to graphify's own Python, matched to how graphify was installed.
    static func installCommand(modules: [String], python: String?, home: String) -> String {
        let list = modules.joined(separator: " ")
        guard let python else { return "uv tool install --force graphifyy && uv pip install --python ~/.local/share/uv/tools/graphifyy/bin/python \(list)" }
        let shown = AgentGuide.abbreviate(python)
        if python.contains("/uv/tools/") { return "uv pip install --python \(shown) \(list)" }
        if python.contains("/pipx/venvs/") { return "pipx inject graphifyy \(list)" }
        return "\(shown) -m pip install \(list)"
    }
}

// MARK: - MCP settings files

/// How a chat app starts Graphitree's MCP server: the command line inside Graphitree.app, told which graph to use.
struct MCPLaunch: Equatable, Sendable {
    let command: String
    let args: [String]

    static func graphitree(cli: String, outDirectory: String) -> MCPLaunch {
        MCPLaunch(command: cli, args: ["mcp", "--graph", outDirectory])
    }
}

/// The `graphitree` command: it ships inside Graphitree.app and is linked into `~/.local/bin`.
enum CommandLineTool {
    static let executableName = "graphitree-cli"
    static let commandName = "graphitree"

    /// The copy inside the running app, when there is one.
    static var bundledPath: String? { Bundle.main.url(forAuxiliaryExecutable: executableName)?.path }

    static func linkPath(home: String) -> String { home + "/.local/bin/" + commandName }

    /// Where the link points, or nil when there's no link.
    static func linkTarget(home: String) -> String? {
        try? FileManager.default.destinationOfSymbolicLink(atPath: linkPath(home: home))
    }

    static func isInstalled(home: String) -> Bool { FileManager.default.isExecutableFile(atPath: linkPath(home: home)) }

    /// Links the command. Never replaces a real file someone else put there.
    static func link(to target: String, home: String) throws {
        let fileManager = FileManager.default
        let path = linkPath(home: home)
        try fileManager.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        if (try? fileManager.attributesOfItem(atPath: path)) != nil || linkTarget(home: home) != nil {
            guard linkTarget(home: home) != nil else {
                throw PlaybookError(message: "\(AgentGuide.abbreviate(path)) is already a file that isn't Graphitree's, so it was left alone.")
            }
            try fileManager.removeItem(atPath: path)
        }
        try fileManager.createSymbolicLink(atPath: path, withDestinationPath: target)
    }

    /// Removes the link if it's Graphitree's.
    static func unlink(home: String) {
        guard let target = linkTarget(home: home), target.hasSuffix("/" + executableName) else { return }
        try? FileManager.default.removeItem(atPath: linkPath(home: home))
    }
}

extension AgentSetup {
    private static func serversKey(_ format: ChatApp.Format) -> String {
        format == .vscode ? "servers" : "mcpServers"
    }

    static func mcpEntry(_ format: ChatApp.Format, launch: MCPLaunch) -> [String: Any] {
        var entry: [String: Any] = ["command": launch.command, "args": launch.args]
        if format == .vscode { entry["type"] = "stdio" }
        return entry
    }

    /// Adds or replaces Graphitree's server, keeping every other setting and server. graphify's own
    /// server, which earlier versions set up, goes, since Graphitree's answers the same questions.
    static func mcpConfig(_ data: Data?, format: ChatApp.Format, launch: MCPLaunch) throws -> Data {
        var root = try parseObject(data)
        var servers = root[serversKey(format)] as? [String: Any] ?? [:]
        if isGraphifyServe(servers[legacyServerName]) { servers[legacyServerName] = nil }
        servers[serverName] = mcpEntry(format, launch: launch)
        root[serversKey(format)] = servers
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    static func mcpConfigRemovingServer(_ data: Data, format: ChatApp.Format) throws -> Data {
        var root = try parseObject(data)
        var servers = root[serversKey(format)] as? [String: Any] ?? [:]
        servers[serverName] = nil
        if isGraphifyServe(servers[legacyServerName]) { servers[legacyServerName] = nil }
        root[serversKey(format)] = servers
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    /// Only graphify's own server is replaced under the old name, never something else called that.
    private static func isGraphifyServe(_ entry: Any?) -> Bool {
        ((entry as? [String: Any])?["args"] as? [String])?.contains("graphify.serve") == true
    }

    static func mcpHasServer(_ data: Data?, format: ChatApp.Format) -> Bool {
        guard let root = try? parseObject(data), let servers = root[serversKey(format)] as? [String: Any] else { return false }
        return servers[serverName] != nil
    }

    /// The entry as it would appear in the file, for the preview.
    static func mcpPreview(_ format: ChatApp.Format, launch: MCPLaunch) -> String {
        let entry = [serverName: mcpEntry(format, launch: launch)]
        let data = (try? JSONSerialization.data(withJSONObject: [serversKey(format): entry], options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    private static func parseObject(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) else { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPConfigError.notAnObject
        }
        return object
    }

    enum MCPConfigError: LocalizedError {
        case notAnObject
        var errorDescription: String? { "The settings file isn't a JSON object, so Graphitree left it alone." }
    }
}

// MARK: - Running graphify for setup

enum GraphifyCommand {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Runs graphify and returns what it printed. `home` replaces HOME, so a test can use a fake one.
    static func run(
        _ arguments: [String],
        in directory: URL,
        home: String? = nil,
        environment extra: [String: String] = [:],
        timeout: TimeInterval = 60
    ) throws -> String {
        guard let executable = GraphRebuilder.locateGraphify() else {
            throw Failure(message: "graphify isn't installed where Graphitree looks for it (~/.local/bin, /opt/homebrew/bin or /usr/local/bin).")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        var environment = ProcessInfo.processInfo.environment
        let realHome = FileManager.default.homeDirectoryForCurrentUser.path
        environment["PATH"] = "\(realHome)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        environment["GRAPHIFY_NO_TIPS"] = "1"
        if let home { environment["HOME"] = home }
        environment.merge(extra) { _, new in new }
        process.environment = environment
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()

        let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)
        // Both pipes are drained at once, so neither can fill up and stall graphify.
        var errorData = Data()
        let errorsRead = DispatchGroup()
        errorsRead.enter()
        DispatchQueue.global().async {
            errorData = errors.fileHandleForReading.readDataToEndOfFile()
            errorsRead.leave()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        errorsRead.wait()
        deadline.cancel()

        if process.terminationReason == .uncaughtSignal {
            throw Failure(message: "graphify took longer than \(Int(timeout)) seconds, so it was stopped.")
        }
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw Failure(message: message.isEmpty ? "graphify stopped with exit \(process.terminationStatus)." : message)
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// Installs graphify's skill into a coding tool. It runs in an empty folder, so the parts of
    /// graphify's installer meant for one project (such as a GEMINI.md there) are thrown away.
    static func installSkill(_ tool: CodingTool, home: String) throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-install-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        _ = try run(tool.installArguments, in: scratch, home: home, timeout: 120)
        guard FileManager.default.fileExists(atPath: tool.skillFile(home: home)) else {
            throw Failure(message: "graphify finished, but its skill isn't at \(AgentGuide.abbreviate(tool.skillFile(home: home))).")
        }
    }
}

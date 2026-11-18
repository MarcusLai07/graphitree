import AppKit
import SwiftUI

/// Connects AI to the knowledge base: which model builds the graph, the others to switch to, and
/// the chat apps that can ask it. Every key is checked before it's saved, and nothing else changes
/// until you confirm a preview.
struct AgentsView: View {
    @Environment(AppModel.self) private var model

    @State private var guideText: String?
    @State private var showsGuide = false
    @State private var message: String?
    @State private var commandInstalled = CommandLineTool.isInstalled(home: FileManager.default.homeDirectoryForCurrentUser.path)

    @State private var toolStates: [String: CodingToolState] = [:]
    @State private var chatStates: [String: ChatState] = [:]
    @State private var customConnected: [String: Bool] = [:]
    @State private var configured: [String: Bool] = [:]
    @State private var savedModels: [String: String] = [:]
    /// The optional modules graphify can import. Nil until checked, or when graphify isn't found.
    @State private var modules: Set<String>?
    @State private var hasChecked = false

    @State private var pending: Pending?
    @State private var busy: String?
    /// The tile or row whose form is open: a provider's id, or a coding tool's key (see `toolKey`).
    @State private var adding: String?
    @State private var showsMoreTools = false
    @State private var showsMissingChats = false

    @State private var tab: AgentsTab = .models
    @AppStorage(BuildChoice.defaultsKey) private var buildChoice = BuildChoice.automatic
    @AppStorage("customAgentFiles") private var customFilesData = ""

    private var home: String { model.agentHome }
    private var guidePath: String { model.guidePath }
    private var guideExists: Bool { FileManager.default.fileExists(atPath: guidePath) }
    private var customFiles: [String] { customFilesData.split(separator: "\n").map(String.init) }
    private var customTargets: [AgentTarget] { customFiles.map(AgentSetup.customTarget) }
    private var python: String { model.graphifyPython ?? "python3" }

    private var presentChats: [ChatApp] { AICatalog.chatApps.filter { chatStates[$0.id]?.isInstalled ?? true } }
    private var missingChats: [ChatApp] { AICatalog.chatApps.filter { chatStates[$0.id]?.isInstalled == false } }

    private var builderID: String? { BuildChoice.resolve(buildChoice, options: model.aiOptions.map(\.id)) }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "AI Models", subtitle: "Which AI builds the graph, and which apps can ask it")
            Rectangle().fill(Palette.hairline).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    builderCard
                    Picker("Section", selection: $tab) {
                        ForEach(AgentsTab.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    if let message {
                        Text(message).font(.caption).foregroundStyle(Palette.gold)
                    }
                    Text(tab.intro)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    tabContent
                }
                .padding(18)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: model.revision) { await refresh() }
        .onAppear {
            // `-agentsTab chat` opens a tab at launch, for screenshots and checks. The tabs that
            // became Models still open it.
            if let raw = UserDefaults.standard.string(forKey: "agentsTab") {
                tab = AgentsTab(rawValue: raw) ?? (["coding", "keys", "local"].contains(raw) ? .models : tab)
            }
            applyFocus()
            // Opening the panel checks every connection again.
            Task { await model.checkConnections() }
        }
        .onChange(of: model.modelsFocus) { applyFocus() }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .models: modelsTab
        case .chat: chatSection
        case .guide: guideTab
        }
    }

    // MARK: - What builds the graph

    /// What builds the graph, how it's doing, how to fix it, and one click to switch.
    private var builderCard: some View {
        let id = builderID
        let health = id.flatMap { model.connectionHealth[$0] }
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let isBad = model.aiOptions.isEmpty || health?.isBroken == true
        return VStack(alignment: .leading, spacing: 12) {
            Label("Builds the graph", systemImage: "hammer.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.gold.opacity(0.9))
            if model.aiOptions.isEmpty {
                heroLine(BuildChoice.codeOnly, title: "Nothing is connected", detail: "Rebuilds read code only. Connect a model below so docs, PDFs and images are read too.")
            } else if let id {
                HStack(spacing: 12) {
                    ModelLogo(id: id, size: 44, level: health?.level)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(BuildChoice.name(of: id)).font(.title3.weight(.semibold))
                            StatusPill(health: health, isChecking: model.checkingConnections.contains(id))
                        }
                        Text(rowDetail(id, health: health))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button("Check Now", systemImage: "arrow.clockwise") { Task { await model.checkConnections() } }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(!model.checkingConnections.isEmpty)
                        .help(checkedLine)
                }
                if let health, health.isProblem { fixCallout(id, health) }
            } else {
                heroLine(BuildChoice.codeOnly, title: "Code only", detail: "Docs, papers and images stay out of the graph. Pick a model below to read them too.")
            }
            if !model.aiOptions.isEmpty {
                FlowLayout(spacing: 6) {
                    Text("Switch to").font(.caption).foregroundStyle(.tertiary).frame(height: 30)
                    ForEach(model.aiOptions) { switchChip($0.id) }
                    switchChip(BuildChoice.codeOnly)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isBad ? Palette.coral : Palette.gold).opacity(0.05), in: shape)
        .overlay(shape.strokeBorder((isBad ? Palette.coral : Palette.gold).opacity(0.3)))
    }

    private func heroLine(_ logo: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            ModelLogo(id: logo, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3.weight(.semibold))
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var checkedLine: String {
        guard let date = model.connectionsCheckedAt else { return "Checks every connection again" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last checked \(formatter.localizedString(for: date, relativeTo: .now)). Graphitree checks every six hours, and when this opens."
    }

    private func switchChip(_ id: String) -> some View {
        let isCodeOnly = id == BuildChoice.codeOnly
        let isOn = isCodeOnly ? builderID == nil : builderID == id
        let health = isCodeOnly ? nil : model.connectionHealth[id]
        let isOff = health?.isBroken == true && !isOn
        return Button {
            model.useForBuilds(id)
        } label: {
            HStack(spacing: 6) {
                ModelLogo(id: id, size: 18, level: health?.level)
                Text(isCodeOnly ? "Code only" : BuildChoice.name(of: id)).font(.callout)
                if isOn {
                    Text("Building").font(.caption2.weight(.semibold)).foregroundStyle(Palette.gold)
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 10)
            .frame(height: 30)
            .background(isOn ? Palette.gold.opacity(0.13) : Color.white.opacity(0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Palette.gold.opacity(0.35) : Color.white.opacity(0.08)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isOff)
        .opacity(isOff ? 0.5 : 1)
        .help(health.map { "\($0.status). \($0.detail)" } ?? (isCodeOnly ? "Rebuilds read code only" : ""))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func fixCallout(_ id: String, _ health: ConnectionHealth) -> some View {
        HStack(spacing: 10) {
            Image(systemName: health.fix == .signIn || health.fix.map(isAWS) == true ? "terminal" : "wrench.and.screwdriver")
                .foregroundStyle(Palette.gold)
            Text(fixExplanation(id, health))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(model.fixTitle(id, health)) { fix(id, health) }
                .buttonStyle(GoldButtonStyle())
        }
        .padding(10)
        .background(Palette.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func isAWS(_ fix: ConnectionHealth.Fix) -> Bool {
        if case .signInToAWS = fix { return true }
        return false
    }

    private func fixExplanation(_ id: String, _ health: ConnectionHealth) -> String {
        switch health.fix {
        case .signIn:
            return "Sign-in happens in your browser. Sign In Again opens Terminal with claude auth login, and Graphitree checks again when you come back."
        case .replaceKey:
            return id == "bedrock" ? "Change the profile, or add it to ~/.aws." : "Make a new key on \(BuildChoice.name(of: id))'s site, then paste it here. The old one is replaced in your Keychain."
        case .startServer:
            return "Start the server, then check again. Rebuilds leave docs out while it's off."
        case .pickModel:
            return "Pull the model on the server, or pick one it has."
        case .signInToAWS:
            return "Sign In to AWS opens Terminal with aws sso login, and Graphitree checks again when you come back."
        case nil:
            return health.detail
        }
    }

    /// Signing in or opening a server happens on the spot; a new key or model opens its form here.
    private func fix(_ id: String, _ health: ConnectionHealth) {
        _ = model.applyFix(id, health)
        applyFocus()
    }

    private func applyFocus() {
        guard let focus = model.modelsFocus else { return }
        model.modelsFocus = nil
        tab = .models
        if AICatalog.providers.contains(where: { $0.id == focus }) {
            adding = focus
            pending = nil
        }
    }

    // MARK: - Models

    /// A coding tool's key in the lists. Claude Code, which builds, uses its own id; the others get
    /// a prefix, since Gemini CLI and the Gemini API share one.
    private func toolKey(_ tool: CodingTool) -> String { tool.graphitreeBackend != nil ? tool.id : "tool:" + tool.id }

    private func codingTool(_ key: String) -> CodingTool? {
        if key.hasPrefix("tool:") { return AICatalog.codingTools.first { "tool:" + $0.id == key } }
        return AICatalog.codingTools.first { $0.id == key && $0.graphitreeBackend != nil }
    }

    /// Everything connected: the models that can build, then tools that read the guide.
    private var connectedKeys: [String] {
        var keys = model.aiOptions.map(\.id)
        for tool in AICatalog.codingTools where !keys.contains(toolKey(tool)) {
            if let state = toolStates[tool.id], state.isListed { keys.append(toolKey(tool)) }
        }
        return keys
    }

    private var modelsTab: some View {
        let connected = connectedKeys
        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Connected · \(connected.count)")
            if connected.isEmpty {
                Text("Nothing yet. Add a model below.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(RowCard())
            }
            ForEach(connected, id: \.self) { connectedRow($0) }
            modulesCard(AICatalog.providers.filter { configured[$0.id] == true })
            sectionTitle("Add a model").padding(.top, 10)
            addGroup(
                "With your plan",
                note: "Only Claude Code builds from Graphitree. The others build with /graphify inside the tool.",
                keys: AICatalog.codingTools.map(toolKey).filter { !connected.contains($0) }
            )
            addGroup(
                "With an API key",
                note: "Pay as you go. The key stays in your Keychain.",
                keys: AICatalog.providers.filter { $0.access == .apiKey && configured[$0.id] != true }.map(\.id)
            )
            addGroup(
                "On this Mac",
                note: "Free and private, but slower.",
                keys: AICatalog.providers.filter { $0.access == .local && configured[$0.id] != true }.map(\.id)
            )
            DisclosureGroup(isExpanded: $showsMoreTools) {
                moreTools.padding(.top, 6)
            } label: {
                Text("More tools graphify supports (\(AICatalog.otherSkillTools.count))").font(.callout).foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(Palette.gold.opacity(0.85))
            .padding(.top, 4)
    }

    private func connectedRow(_ key: String) -> some View {
        let tool = codingTool(key)
        let provider = tool == nil ? AICatalog.providers.first { $0.id == key } : nil
        let health = model.connectionHealth[key]
        let canBuild = model.aiOptions.contains { $0.id == key }
        let isBuilder = builderID == key
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let border = isBuilder ? Palette.gold.opacity(0.3) : (health?.isBroken == true ? Palette.coral.opacity(0.35) : Color.white.opacity(0.06))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ModelLogo(id: key, size: 32, level: health?.level)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(tool?.name ?? provider?.name ?? key).font(.body.weight(.medium))
                        if canBuild {
                            StatusPill(health: health, isChecking: model.checkingConnections.contains(key))
                        } else if let tool {
                            toolStatus(toolStates[tool.id])
                        }
                    }
                    Text(rowDetail(key, health: health))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                rowAction(key, health: health, canBuild: canBuild, isBuilder: isBuilder)
                rowMenu(key, tool: tool, provider: provider, canBuild: canBuild)
            }
            if let tool, let state = toolStates[tool.id], state.isInstalled {
                HStack(spacing: 6) {
                    sideChip("/graphify skill", symbol: "hammer", isOn: state.builds)
                    sideChip("Reads the guide", symbol: "book", isOn: state.reads)
                    Spacer(minLength: 8)
                    if !state.isConnected { toolButtons(tool, state: state) }
                }
                if case .tool(let id, let connect) = pending, id == tool.id { toolConfirmation(tool, connect: connect) }
            }
            if let provider {
                if let modules, !modules.contains(provider.module) {
                    Label("Needs graphify's \(provider.module) module", systemImage: "shippingbox")
                        .font(.caption)
                        .foregroundStyle(Palette.gold)
                }
                if adding == key {
                    ProviderConnectForm(provider: provider, isSetUp: true) { result in
                        adding = nil
                        if result != nil { message = "\(provider.name) is saved." }
                        Task { await refresh() }
                    }
                }
                if case .removeProvider(let id) = pending, id == provider.id {
                    confirmation(
                        provider.settings.contains(where: \.isSecret)
                            ? "Deletes the saved key from your Keychain and forgets \(provider.name)'s settings."
                            : "Forgets \(provider.name)'s settings.",
                        body: nil,
                        confirm: "Remove It"
                    ) { removeProvider(provider) }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.035), in: shape)
        .overlay(shape.strokeBorder(border))
    }

    /// What a row says under its name: the check's answer, the model, or how the tool builds.
    private func rowDetail(_ key: String, health: ConnectionHealth?) -> String {
        if let provider = AICatalog.providers.first(where: { $0.id == key }), codingTool(key) == nil {
            return [modelLine(provider), health?.detail].compactMap { $0 }.joined(separator: ". ")
        }
        if let health { return health.detail }
        if let tool = codingTool(key) {
            return tool.graphitreeBackend != nil ? "Builds with your Claude plan. Not checked yet." : tool.buildHint
        }
        return ""
    }

    @ViewBuilder
    private func rowAction(_ key: String, health: ConnectionHealth?, canBuild: Bool, isBuilder: Bool) -> some View {
        if let health, health.isBroken {
            Button(model.fixTitle(key, health)) { fix(key, health) }
                .buttonStyle(GoldButtonStyle())
        } else if isBuilder {
            Label("Builds the graph", systemImage: "hammer.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.gold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Palette.gold.opacity(0.12), in: Capsule())
                .fixedSize()
        } else if canBuild {
            Button("Use for Builds") { model.useForBuilds(key) }
                .buttonStyle(SoftButtonStyle())
        }
    }

    private func rowMenu(_ key: String, tool: CodingTool?, provider: ModelProvider?, canBuild: Bool) -> some View {
        Menu {
            if canBuild {
                Button("Check Now") { Task { await model.checkConnections([key]) } }
            }
            if let tool {
                if tool.graphitreeBackend != nil {
                    Button("Sign In Again…") { model.signInToClaudeCode() }
                }
                if let state = toolStates[tool.id], state.reads {
                    Divider()
                    Button("Stop Reading the Guide…") { pending = .tool(tool.id, connect: false) }
                }
            }
            if let provider {
                Button(provider.access == .local ? "Change Server or Model…" : (provider.id == "bedrock" ? "Change Profile or Model…" : "Change Key or Model…")) {
                    adding = provider.id
                    pending = nil
                }
                Divider()
                Button(provider.settings.contains(where: \.isSecret) ? "Remove Key…" : "Remove…", role: .destructive) {
                    pending = .removeProvider(provider.id)
                    adding = nil
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
    }

    @ViewBuilder
    private func addGroup(_ title: String, note: String, keys: [String]) -> some View {
        if !keys.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(note).font(.caption).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], spacing: 8) {
                    ForEach(keys, id: \.self) { addTile($0) }
                }
                if let adding, keys.contains(adding) { addForm(adding) }
            }
            .padding(.top, 4)
        }
    }

    private func addTile(_ key: String) -> some View {
        let tool = codingTool(key)
        let provider = tool == nil ? AICatalog.providers.first { $0.id == key } : nil
        let isMissing = tool.map { toolStates[$0.id]?.isInstalled == false } ?? false
        let isOpen = adding == key
        return Button {
            adding = isOpen ? nil : key
            pending = nil
        } label: {
            HStack(spacing: 10) {
                ModelLogo(id: key, size: 28, dimmed: isMissing)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tool?.name ?? (key == "openai-compatible" ? "LM Studio or another server" : provider?.name) ?? key).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(tileDetail(tool: tool, provider: provider, isMissing: isMissing)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(isOpen ? 0.07 : 0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(isOpen ? Palette.gold.opacity(0.4) : Color.white.opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tileDetail(tool: CodingTool?, provider: ModelProvider?, isMissing: Bool) -> String {
        if let tool {
            if isMissing { return "Not on this Mac" }
            return tool.graphitreeBackend != nil ? "Your Claude plan" : tool.account
        }
        guard let provider else { return "" }
        switch provider.id {
        case "gemini": return "API key, free tier"
        case "azure": return "Key and endpoint"
        case "bedrock": return "AWS profile"
        case "ollama": return ModelBrand.of("ollama").appPath != nil ? "On this Mac" : "Get it at ollama.com"
        case "openai-compatible": return "Any OpenAI-style server"
        default: return "API key, billed per use"
        }
    }

    @ViewBuilder
    private func addForm(_ key: String) -> some View {
        if let tool = codingTool(key) {
            toolSetupCard(tool)
        } else if let provider = AICatalog.providers.first(where: { $0.id == key }) {
            ProviderConnectForm(provider: provider, isSetUp: configured[provider.id] ?? false) { result in
                adding = nil
                if result != nil { message = "\(provider.name) is connected." }
                Task { await refresh() }
            }
        }
    }

    /// A coding tool that isn't connected yet: what it needs, and Connect.
    private func toolSetupCard(_ tool: CodingTool) -> some View {
        let state = toolStates[tool.id]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.name).font(.body.weight(.medium))
                    Text(tool.account).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                toolStatus(state)
                toolButtons(tool, state: state)
            }
            if let state, state.isInstalled {
                Text(tool.buildHint).font(.caption).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            } else if state != nil {
                Text("Graphitree looks for the \(tool.commands.joined(separator: " or ")) command\(tool.apps.isEmpty ? "" : " or \(tool.apps.joined(separator: ", "))"). Install \(tool.name), then come back.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if case .tool(let id, let connect) = pending, id == tool.id { toolConfirmation(tool, connect: connect) }
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.gold.opacity(0.3)))
    }

    private var guideTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: guideExists ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(guideExists ? Palette.jade : .secondary)
                Text(guideExists ? "\(guideAge). Graphitree updates it after each rebuild." : "Not written yet.").font(.callout)
                Spacer(minLength: 8)
                Button(guideExists ? "Update" : "Write Guide") { Task { await writeGuide() } }
                    .buttonStyle(SoftButtonStyle())
                Button(showsGuide ? "Hide Preview" : "Preview") {
                    showsGuide.toggle()
                    if showsGuide { Task { guideText = await model.agentGuideText() } }
                }
                .buttonStyle(SoftButtonStyle())
                if guideExists {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: guidePath)]) }
                        .buttonStyle(SoftButtonStyle())
                }
            }
            Text(AgentGuide.abbreviate(guidePath)).font(.caption.monospaced()).foregroundStyle(.tertiary).textSelection(.enabled)
            if showsGuide {
                ScrollView {
                    Text(guideText ?? "Writing the preview…")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 280)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            }
            otherWaysSection
            Text("Graphitree backs up a file before changing it (as name.graphitree-backup-date) and only touches its own marked lines, or its own graphify entry in MCP settings. Keys are kept in your login Keychain under \"\(AIKeychain.standard.service)\".")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var guideAge: String {
        guard let date = (try? FileManager.default.attributesOfItem(atPath: guidePath))?[.modificationDate] as? Date else { return "Written" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Written \(formatter.localizedString(for: date, relativeTo: .now))"
    }

    private var moreTools: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("graphify's installer also puts its skill into these. Graphitree doesn't know where each keeps its instructions, so add that file under Guide, Other ways, to have it read the guide too.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(AICatalog.otherSkillTools.map { "\($0.name) (\($0.platform))" }.joined(separator: " · "))
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text("graphify install --platform <name>").font(.caption.monospaced()).textSelection(.enabled)
                copyIcon("graphify install --platform ")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Coding tool pieces

    @ViewBuilder
    private func toolStatus(_ state: CodingToolState?) -> some View {
        if let state {
            if !state.isInstalled {
                Text("Not installed").font(.caption).foregroundStyle(.tertiary)
            } else if state.isConnected {
                Label("Reads the guide", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Palette.jade)
            } else if state.isPartial {
                Label("Half set up", systemImage: "circle.lefthalf.filled").font(.caption).foregroundStyle(Palette.gold)
            } else {
                Text("Not connected").font(.caption).foregroundStyle(.secondary)
            }
        } else {
            ProgressView().controlSize(.small)
        }
    }

    @ViewBuilder
    private func toolButtons(_ tool: CodingTool, state: CodingToolState?) -> some View {
        if busy == tool.id {
            ProgressView().controlSize(.small)
        } else if let state, state.isInstalled {
            if !state.isConnected {
                Button(state.isPartial ? "Finish Setup" : "Connect") { pending = .tool(tool.id, connect: true) }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(!state.reads && !guideExists)
                    .help(!state.reads && !guideExists ? "Write the guide first. The pointer leads to it." : "Shows exactly what changes before anything is written.")
            }
            if state.reads {
                Button("Disconnect") { pending = .tool(tool.id, connect: false) }
                    .buttonStyle(SoftButtonStyle())
            }
        }
    }

    private func toolConfirmation(_ tool: CodingTool, connect: Bool) -> some View {
        let state = toolStates[tool.id] ?? CodingToolState(isInstalled: true, builds: false, reads: false)
        let file = AgentGuide.abbreviate(tool.instructionsFile(home: home))
        var lines: [String] = []
        var preview: String?
        if connect {
            lines.append("Connecting \(tool.name) sets up both sides:")
            if !state.builds {
                let folder = AgentGuide.abbreviate((tool.skillFile(home: home) as NSString).deletingLastPathComponent)
                lines.append("• Build: runs `graphify \(tool.installArguments.joined(separator: " "))`, which puts graphify's skill in \(folder). \(tool.installerAlsoChanges ?? "")")
            } else {
                lines.append("• Build: graphify's skill is already there.")
            }
            if !state.reads {
                var read = "• Read: adds these lines to the end of \(file)."
                if tool.id == "claude-code", queryRewrite(for: tool.instructionsFile(home: home)) != nil {
                    read += " It also adds `--graph` with the clean graph to the `graphify query` command already in that file."
                }
                lines.append(read)
                preview = AgentSetup.block(guidePath: guidePath, root: model.graphRoot)
            } else {
                lines.append("• Read: the pointer is already there.")
            }
        } else {
            lines.append("Removes Graphitree's lines from \(file). graphify's skill stays, so you can still build from \(tool.name). `graphify uninstall` removes the skill from every tool.")
        }
        return confirmation(lines.joined(separator: "\n"), body: preview, confirm: connect ? "Connect" : "Remove It") {
            Task { await applyTool(tool, connect: connect) }
        }
    }

    // MARK: Provider pieces

    /// One command for every module a group of providers still needs, instead of one per row.
    @ViewBuilder
    private func modulesCard(_ providers: [ModelProvider]) -> some View {
        if let modules {
            let missing = Set(providers.map(\.module)).subtracting(modules).sorted()
            if !missing.isEmpty {
                let command = model.moduleInstallCommand(missing)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle").foregroundStyle(Palette.gold)
                        Text("graphify can't call \(missing.count == 1 ? "one of these" : "some of these") yet. Add \(missing.count == 1 ? "the module" : "the modules") it needs to its Python, then check again.")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button("Check Again") { Task { await refresh() } }.buttonStyle(SoftButtonStyle())
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(command).font(.caption.monospaced()).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                        copyIcon(command)
                    }
                }
                .modifier(RowCard())
            }
        }
    }

    private func modelLine(_ provider: ModelProvider) -> String {
        if let saved = savedModels[provider.id], !saved.isEmpty { return "Model: \(saved)" }
        return provider.needsModel ? "Model: \(provider.defaultModel)" : "Model: \(provider.defaultModel) (graphify's default)"
    }

    // MARK: - Chat apps

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            mcpServerCard
            VStack(spacing: 6) {
                ForEach(presentChats) { chatRow($0) }
                webAppsRow
            }
            if !missingChats.isEmpty {
                DisclosureGroup(isExpanded: $showsMissingChats) {
                    VStack(spacing: 6) { ForEach(missingChats) { chatRow($0) } }.padding(.top, 6)
                } label: {
                    Text("Not on this Mac (\(missingChats.count))").font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Graphitree's own server ships inside the app, so it needs nothing installed.
    private var launch: MCPLaunch? {
        CommandLineTool.bundledPath.map { MCPLaunch.graphitree(cli: $0, outDirectory: model.outDirectory.path) }
    }
    private var mcpReady: Bool { launch != nil }

    private var mcpServerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: mcpReady ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(mcpReady ? Palette.jade : Palette.gold)
                Text(mcpReady ? "Graphitree's MCP server is ready." : "Graphitree's MCP server is missing from this copy of the app.")
                    .font(.callout.weight(.medium))
                Spacer()
            }
            Text("It answers with your picks by job (\"toasts\" finds Sonner), your stack, how you work, and questions to \(AgentGuide.abbreviate(model.queryGraphPath)) or one folder's graph. Nothing extra to install.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("The graphitree command").font(.callout.weight(.medium))
                    Text(commandInstalled
                         ? "In \(AgentGuide.abbreviate(CommandLineTool.linkPath(home: realHome))). Try `graphitree pick toasts` or `graphitree ask \"…\"` in a terminal. The guide tells AI tools about it."
                         : "The same answers in a terminal, for you and for AI tools with a shell. Links into ~/.local/bin, which is already on your PATH.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if commandInstalled {
                    Button("Remove") {
                        CommandLineTool.unlink(home: realHome)
                        commandInstalled = false
                        model.refreshAgentGuideIfPresent()
                    }
                    .buttonStyle(SoftButtonStyle())
                } else {
                    Button("Install Command") { installCommand() }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(CommandLineTool.bundledPath == nil)
                }
            }
        }
        .modifier(RowCard())
    }

    private var realHome: String { FileManager.default.homeDirectoryForCurrentUser.path }

    private func installCommand() {
        guard let target = CommandLineTool.bundledPath else { return }
        do {
            try CommandLineTool.link(to: target, home: realHome)
            commandInstalled = true
            message = "The graphitree command is installed. The guide now mentions it."
            model.refreshAgentGuideIfPresent()
        } catch {
            message = "Couldn't install the command: \(error.localizedDescription)"
        }
    }

    private func chatRow(_ app: ChatApp) -> some View {
        let state = chatStates[app.id]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.body.weight(.medium))
                    Text(app.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(AgentGuide.abbreviate(app.configFile(home: home)))
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                if let state {
                    if !state.isInstalled {
                        Text("Not installed").font(.caption).foregroundStyle(.tertiary)
                    } else if state.isConnected {
                        Label("Connected", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Palette.jade)
                        Button("Disconnect") { pending = .chat(app.id, connect: false) }.buttonStyle(SoftButtonStyle())
                    } else {
                        Text("Not connected").font(.caption).foregroundStyle(.secondary)
                        Button("Connect") { pending = .chat(app.id, connect: true) }
                            .buttonStyle(SoftButtonStyle())
                            .disabled(!mcpReady)
                            .help("Shows exactly what changes before anything is written.")
                    }
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            if case .chat(let id, let connect) = pending, id == app.id {
                let file = AgentGuide.abbreviate(app.configFile(home: home))
                confirmation(
                    connect
                        ? "Adds Graphitree's MCP server to \(file), keeping your other settings and servers. Restart \(app.name) afterwards."
                        : "Removes Graphitree's server from \(file). Restart \(app.name) afterwards.",
                    body: connect ? launch.map { AgentSetup.mcpPreview(app.format, launch: $0) } : nil,
                    confirm: connect ? "Add It" : "Remove It"
                ) { applyChat(app, connect: connect) }
            }
        }
        .modifier(RowCard())
    }

    private var webAppsRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ChatGPT, claude.ai and other web apps").font(.body.weight(.medium))
            Text("They only reach MCP servers on the internet, so they can't use one on this Mac. Paste the guide into a project instead, under Other ways.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(RowCard())
    }

    // MARK: - Other ways

    private var otherWaysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            subsection("Share it another way", "For tools Graphitree can't set up for you.")
            otherWay(
                title: "Chat apps without MCP (ChatGPT, claude.ai, Gemini)",
                detail: "Paste the whole guide into a project's or custom GPT's instructions.",
                button: "Copy Guide"
            ) {
                if let text = await model.agentGuideText() {
                    copy(text)
                    message = "Guide copied."
                }
            }
            otherWay(
                title: "Editors with a rules box (Cursor, Windsurf, Zed)",
                detail: "Paste the pointer into the user or global rules setting.",
                button: "Copy Pointer"
            ) {
                copy(AgentSetup.pastableBlock(guidePath: guidePath, root: model.graphRoot))
                message = "Pointer copied."
            }
            otherWay(
                title: "Any other MCP client, including your own apps on API keys",
                detail: "Paste the config into the client's MCP settings.",
                button: "Copy MCP Config"
            ) {
                copy(launch.map(AgentSetup.mcpSnippet) ?? "")
                message = "MCP config copied."
            }
            otherWay(
                title: "Another tool's instructions file",
                detail: "Pick the markdown file a tool reads every session, or a folder to put AGENTS.md in.",
                button: "Add File…"
            ) { chooseCustomFile() }
            ForEach(customTargets) { customRow($0) }
        }
    }

    private func otherWay(title: String, detail: String, button: String, action: @escaping () async -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            Spacer(minLength: 8)
            Button(button) { Task { await action() } }
                .buttonStyle(SoftButtonStyle())
                .disabled(!guideExists)
                .help(guideExists ? "" : "Write the guide first")
        }
        .modifier(RowCard())
    }

    private func customRow(_ target: AgentTarget) -> some View {
        let isConnected = customConnected[target.id] ?? false
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.name).font(.body.weight(.medium))
                    Text(AgentGuide.abbreviate(target.file)).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                if isConnected {
                    Label("Reads the guide", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Palette.jade)
                    Button("Disconnect") { pending = .custom(target.id, connect: false) }.buttonStyle(SoftButtonStyle())
                } else {
                    Button("Connect") { pending = .custom(target.id, connect: true) }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(!guideExists)
                    Button("Forget", systemImage: "xmark") { forget(target) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Remove this file from the list")
                }
            }
            if case .custom(let id, let connect) = pending, id == target.id {
                confirmation(
                    connect ? "Adds these lines to the end of \(AgentGuide.abbreviate(target.file)):" : "Removes Graphitree's lines from \(AgentGuide.abbreviate(target.file)). Everything else stays.",
                    body: connect ? AgentSetup.block(guidePath: guidePath, root: model.graphRoot) : nil,
                    confirm: connect ? "Add It" : "Remove It"
                ) { applyPointer(file: target.file, name: target.name, connect: connect, rewriteClaude: false) }
            }
        }
        .modifier(RowCard())
    }

    // MARK: - Pieces

    private func subsection(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Palette.gold.opacity(0.85))
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private func sideChip(_ title: String, symbol: String, isOn: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isOn ? "checkmark" : symbol).font(.caption2.weight(.bold))
            Text(title).font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(isOn ? Palette.jade : Color.secondary)
        .background((isOn ? Palette.jade : Color.white).opacity(isOn ? 0.12 : 0.05), in: Capsule())
    }

    private func copyIcon(_ text: String) -> some View {
        Button("Copy", systemImage: "doc.on.doc") {
            copy(text)
            message = "Copied."
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(Palette.gold)
        .help("Copy")
    }

    private func confirmation(_ summary: String, body: String?, confirm: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summary).font(.callout).fixedSize(horizontal: false, vertical: true)
            if let body {
                ScrollView(.horizontal) {
                    Text(body)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                }
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                Spacer()
                Button("Cancel") { pending = nil }.buttonStyle(SoftButtonStyle())
                Button(confirm, action: action).buttonStyle(GoldButtonStyle())
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Changes

    private func applyTool(_ tool: CodingTool, connect: Bool) async {
        pending = nil
        let file = tool.instructionsFile(home: home)
        guard connect else {
            applyPointer(file: file, name: tool.name, connect: false, rewriteClaude: false)
            return
        }
        let state = toolStates[tool.id] ?? CodingToolState(isInstalled: true, builds: false, reads: false)
        if !state.builds {
            busy = tool.id
            let error = await model.installSkill(tool)
            busy = nil
            if let error {
                message = "Couldn't install graphify's skill into \(tool.name): \(error)"
                await refresh()
                return
            }
        }
        if !state.reads {
            applyPointer(file: file, name: tool.name, connect: true, rewriteClaude: tool.id == "claude-code")
        } else {
            message = "\(tool.name) can now build the graph and reads the guide."
            await refresh()
        }
    }

    private func applyPointer(file: String, name: String, connect: Bool, rewriteClaude: Bool) {
        pending = nil
        do {
            let existing = (try? String(contentsOfFile: file, encoding: .utf8)) ?? ""
            let block = AgentSetup.block(guidePath: guidePath, root: model.graphRoot)
            let updated: String
            if connect {
                let base = rewriteClaude ? (queryRewrite(for: file) ?? existing) : existing
                updated = AgentSetup.applying(block, to: base)
            } else {
                updated = AgentSetup.removing(from: existing)
            }
            try AgentSetup.backUp(file)
            try AgentSetup.write(updated, to: file)
            message = connect ? "\(name) is connected: it builds the graph and reads the guide." : "Graphitree's lines were removed from \(name)."
        } catch {
            message = "Couldn't change \(name): \(error.localizedDescription)"
        }
        Task { await refresh() }
    }

    private func applyChat(_ app: ChatApp, connect: Bool) {
        pending = nil
        let file = app.configFile(home: home)
        do {
            let data = FileManager.default.contents(atPath: file)
            guard let launch else { return }
            let updated = connect
                ? try AgentSetup.mcpConfig(data, format: app.format, launch: launch)
                : try AgentSetup.mcpConfigRemovingServer(data ?? Data("{}".utf8), format: app.format)
            try AgentSetup.backUp(file)
            try AgentSetup.write(updated, to: file)
            message = connect ? "\(app.name) can ask Graphitree after a restart." : "Graphitree was removed from \(app.name)."
        } catch {
            message = "Couldn't change \(app.name): \(error.localizedDescription)"
        }
        Task { await refresh() }
    }

    /// Claude Code's own query line, pointed at the clean graph, when there is one to point at.
    private func queryRewrite(for file: String) -> String? {
        guard model.hasCleanGraph, let text = try? String(contentsOfFile: file, encoding: .utf8) else { return nil }
        return AgentSetup.pointingQueriesAtCleanGraph(text, cleanGraph: model.cleanGraphPathFromRoot)
    }

    private func removeProvider(_ provider: ModelProvider) {
        pending = nil
        AIProviderStore.standard.remove(provider)
        model.disconnected(provider.id)
        message = "\(provider.name) was removed."
        Task { await refresh() }
    }

    private func chooseCustomFile() {
        let open = NSOpenPanel()
        open.title = "Choose a tool's instructions file"
        open.message = "Pick the markdown file the tool reads, or a folder to put AGENTS.md in."
        open.prompt = "Add"
        open.canChooseFiles = true
        open.canChooseDirectories = true
        open.canCreateDirectories = true
        open.allowsMultipleSelection = false
        open.directoryURL = URL(fileURLWithPath: home)
        guard open.runModal() == .OK, let url = open.url else { return }
        let target = AgentSetup.customTarget(path: url.path)
        let known = AICatalog.codingTools.map { $0.instructionsFile(home: home) }
        guard !customFiles.contains(target.file), !known.contains(target.file) else { return }
        customFilesData = (customFiles + [target.file]).joined(separator: "\n")
        Task { await refresh() }
    }

    private func forget(_ target: AgentTarget) {
        customFilesData = customFiles.filter { $0 != target.file }.joined(separator: "\n")
        Task { await refresh() }
    }

    // MARK: - Status

    private func refresh() async {
        let home = self.home
        var tools: [String: CodingToolState] = [:]
        for tool in AICatalog.codingTools { tools[tool.id] = CodingToolState.read(tool, home: home) }
        toolStates = tools
        // The Usage page, menu bar and widgets show the tools listed here.
        ShownProviders.shared.refresh()

        var chats: [String: ChatState] = [:]
        for app in AICatalog.chatApps {
            let settings = FileManager.default.contents(atPath: app.configFile(home: home))
            chats[app.id] = ChatState(
                isInstalled: ToolLocator.isInstalled(app, home: home),
                isConnected: AgentSetup.mcpHasServer(settings, format: app.format)
            )
        }
        chatStates = chats

        var custom: [String: Bool] = [:]
        for target in customTargets {
            custom[target.id] = AgentSetup.isConnected((try? String(contentsOfFile: target.file, encoding: .utf8)) ?? "")
        }
        customConnected = custom

        let store = AIProviderStore.standard
        var isSetUp: [String: Bool] = [:]
        var models: [String: String] = [:]
        for provider in AICatalog.providers {
            isSetUp[provider.id] = store.isConfigured(provider)
            if isSetUp[provider.id] == true { models[provider.id] = store.values(for: provider)[AIProviderStore.modelVariable] }
        }
        configured = isSetUp
        savedModels = models
        model.refreshAIOptions()

        modules = await model.graphifyModules()
        hasChecked = true
    }

    private func writeGuide() async {
        if let error = await model.writeAgentGuide() {
            message = "Couldn't write the guide: \(error)"
        } else {
            message = "Guide written."
            if showsGuide { guideText = await model.agentGuideText() }
        }
        await refresh()
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private enum AgentsTab: String, CaseIterable, Identifiable {
    case models, chat, guide

    var id: String { rawValue }
    var title: String {
        switch self {
        case .models: return "Models"
        case .chat: return "Chat Apps"
        case .guide: return "Guide"
        }
    }
    var intro: String {
        switch self {
        case .models: return "Graphitree checks each connection every six hours, and says here and on the map when one needs you."
        case .chat: return "Chat apps can't build the graph, but they can ask Graphitree through its MCP server: your picks, your stack and the graph."
        case .guide: return "The one file every connection leads to. It tells AI tools to ask the graph before reading code."
        }
    }
}

private struct ChatState: Equatable {
    let isInstalled: Bool
    let isConnected: Bool
}

private enum Pending: Equatable {
    case tool(String, connect: Bool)
    case chat(String, connect: Bool)
    case custom(String, connect: Bool)
    case removeProvider(String)
}


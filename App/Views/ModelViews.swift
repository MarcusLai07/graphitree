import AppKit
import SwiftUI

// Pieces shared by the AI Models panel, the first-run screen, the rail and the window's banner:
// each model's logo, its status, the form that connects a key or server, and the fixes.

// MARK: - Logos

/// How a model or tool looks. An installed app's own icon comes first, then the official mark
/// bundled in App/Resources/ModelLogos, then initials in the brand's colours.
///
/// The marks came from each vendor's own site or repo in November 2026, re-drawn at 256 px:
/// claude.com/icon.svg; chatgpt.com's favicon, which OpenAI's Codex page uses too;
/// geminicli.com/icon.png; GitHub's Octicons copilot-24.svg; opencode.ai, anthropic.com,
/// kimi.com, ollama.com and lmstudio.ai touch icons; gemini.google.com's sparkle; the
/// deepseek-ai GitHub avatar; ai.azure.com's favicon; and aws.amazon.com's touch icon for Bedrock.
/// They're used unmodified, only to say which service a connection is.
struct ModelBrand {
    let monogram: String
    let background: [Color]
    let foreground: Color
    /// Apps whose icon stands in for the logo when installed.
    let apps: [String]
    /// The bundled mark, as `ModelLogo-<name>.png`.
    var logo: String?
    /// The tile behind a mark that doesn't fill its own square. Nil for marks that are a tile already.
    var logoTile: Color?
    /// How far a mark on a tile sits in from the edge, as a share of the size.
    var logoInset: CGFloat = 0

    /// Ids are coding tools' and providers' ids. Gemini CLI and the Gemini API share one, so a tool
    /// that doesn't build is asked for as "tool:" and its id.
    static func of(_ id: String) -> ModelBrand {
        if id.hasPrefix("tool:") {
            let tool = String(id.dropFirst("tool:".count))
            return tool == "gemini" ? geminiCLI : of(tool)
        }
        switch id {
        case "claude-code": return ModelBrand(monogram: "C", background: [Color(hex: 0xD97757)], foreground: .white, apps: ["Claude.app"], logo: "claude-code", logoTile: Color(hex: 0xF0EEE6), logoInset: 0.16)
        case "codex": return ModelBrand(monogram: "Cx", background: [Color(hex: 0x111111)], foreground: .white, apps: ["Codex.app"], logo: "codex", logoTile: .white, logoInset: 0.02)
        case "copilot": return ModelBrand(monogram: "Co", background: [Color(hex: 0x24292F)], foreground: .white, apps: [], logo: "copilot", logoTile: .white, logoInset: 0.2)
        case "antigravity": return ModelBrand(monogram: "Ag", background: [Color(hex: 0x1A1C20)], foreground: Color(hex: 0x8AB4F8), apps: ["Antigravity.app"])
        case "opencode": return ModelBrand(monogram: "Oc", background: [Color(hex: 0x1C1C1C)], foreground: Color(hex: 0xF2F2F2), apps: [], logo: "opencode")
        case "anthropic": return ModelBrand(monogram: "A", background: [Color(hex: 0xF0EEE6)], foreground: Color(hex: 0x1F1E1D), apps: [], logo: "anthropic")
        case "openai": return ModelBrand(monogram: "O", background: [Color(hex: 0x0B0B0B)], foreground: .white, apps: [], logo: "openai", logoTile: .white, logoInset: 0.02)
        case "gemini": return ModelBrand(monogram: "G", background: [Color(hex: 0x4285F4), Color(hex: 0x9B72CB), Color(hex: 0xD96570)], foreground: .white, apps: [], logo: "gemini", logoTile: .white, logoInset: 0.16)
        case "kimi": return ModelBrand(monogram: "K", background: [Color(hex: 0x16191D)], foreground: .white, apps: [], logo: "kimi")
        case "deepseek": return ModelBrand(monogram: "D", background: [Color(hex: 0x4D6BFE)], foreground: .white, apps: [], logo: "deepseek")
        case "azure": return ModelBrand(monogram: "Az", background: [Color(hex: 0x0078D4)], foreground: .white, apps: [], logo: "azure", logoTile: .white, logoInset: 0.16)
        case "bedrock": return ModelBrand(monogram: "B", background: [Color(hex: 0x232F3E)], foreground: Color(hex: 0xFF9900), apps: [], logo: "bedrock")
        case "ollama": return ModelBrand(monogram: "Ol", background: [.white], foreground: Color(hex: 0x111111), apps: ["Ollama.app"], logo: "ollama", logoTile: .white, logoInset: 0.02)
        case "openai-compatible": return ModelBrand(monogram: "LM", background: [Color(hex: 0x4F3FD1)], foreground: .white, apps: ["LM Studio.app"], logo: "lmstudio")
        default: return ModelBrand(monogram: "{ }", background: [Color.white.opacity(0.06)], foreground: .secondary, apps: [])
        }
    }

    private static let geminiCLI = ModelBrand(monogram: "G", background: [Color(hex: 0x1E1E2E)], foreground: Color(hex: 0x4796E4), apps: [], logo: "gemini-cli")

    /// Where the bundled marks are. The screenshot tool, which has no bundle, points this at the repo.
    @MainActor static var logoFolder: URL?

    @MainActor private static var icons: [String: NSImage?] = [:]

    /// The installed app's icon, looked up once per app.
    @MainActor var appIcon: NSImage? {
        guard let name = apps.first else { return nil }
        if let cached = Self.icons[name] { return cached }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let icon = ToolLocator.app(apps, home: home).map { NSWorkspace.shared.icon(forFile: $0) }
        Self.icons[name] = icon
        return icon
    }

    /// The bundled mark, loaded once.
    @MainActor var logoImage: NSImage? {
        guard let logo else { return nil }
        let key = "logo:" + logo
        if let cached = Self.icons[key] { return cached }
        let file = "ModelLogo-\(logo)"
        let url = Self.logoFolder.map { $0.appendingPathComponent(file + ".png") }
            ?? Bundle.main.url(forResource: file, withExtension: "png")
        let image = url.flatMap(NSImage.init(contentsOf:))
        Self.icons[key] = image
        return image
    }

    /// Whether the app that runs this model's server is installed, so a banner can open it.
    @MainActor var appPath: String? {
        ToolLocator.app(apps, home: FileManager.default.homeDirectoryForCurrentUser.path)
    }
}

/// A model's logo, with a gold dot when it needs attention soon and a coral one when it's broken.
struct ModelLogo: View {
    let id: String
    var size: CGFloat = 28
    var level: ConnectionHealth.Level?
    var dimmed = false

    var body: some View {
        let brand = ModelBrand.of(id)
        tile(brand)
            .frame(width: size, height: size)
            .saturation(dimmed ? 0.1 : 1)
            .brightness(dimmed ? -0.25 : 0)
            .opacity(dimmed ? 0.7 : 1)
            .overlay(alignment: .bottomTrailing) {
                if let dot = Self.dotColor(level) {
                    Circle()
                        .fill(dot)
                        .frame(width: max(7, size * 0.32), height: max(7, size * 0.32))
                        .overlay(Circle().strokeBorder(Palette.panel, lineWidth: 2))
                        .offset(x: 2, y: 2)
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func tile(_ brand: ModelBrand) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
        if let icon = brand.appIcon {
            Image(nsImage: icon).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                // App icons have a margin; this lines them up with the tiles.
                .scaleEffect(1.18)
        } else if let mark = brand.logoImage {
            if let tile = brand.logoTile {
                shape
                    .fill(tile)
                    .overlay {
                        Image(nsImage: mark).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                            .padding(size * brand.logoInset)
                    }
            } else {
                Image(nsImage: mark).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                    .clipShape(shape)
            }
        } else {
            shape
                .fill(LinearGradient(colors: brand.background.count > 1 ? brand.background : brand.background + brand.background, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(shape.strokeBorder(Color.white.opacity(0.08)))
                .overlay {
                    Text(brand.monogram)
                        .font(.system(size: size * (brand.monogram.count > 1 ? 0.38 : 0.5), weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(brand.foreground)
                }
        }
    }

    static func dotColor(_ level: ConnectionHealth.Level?) -> Color? {
        switch level {
        case .warning: return Palette.gold
        case .broken: return Palette.coral
        default: return nil
        }
    }
}

// MARK: - Status

extension ConnectionHealth.Level {
    var color: Color {
        switch self {
        case .ok: return Palette.jade
        case .unknown: return .secondary
        case .warning: return Palette.gold
        case .broken: return Palette.coral
        }
    }
}

/// A connection's state in a few words.
struct StatusPill: View {
    let health: ConnectionHealth?
    var isChecking = false
    /// Shown before the first check, such as "Set up".
    var fallback = "Not checked yet"

    var body: some View {
        HStack(spacing: 5) {
            if isChecking && health == nil {
                ProgressView().controlSize(.mini)
                Text("Checking…")
            } else {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(health?.status ?? fallback)
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
        .fixedSize()
    }

    private var color: Color { health?.level.color ?? .secondary }
}

// MARK: - Fixes

extension AppModel {
    /// The button that fixes a problem, in words.
    func fixTitle(_ id: String, _ health: ConnectionHealth) -> String {
        switch health.fix {
        case .signIn: return "Sign In Again"
        case .replaceKey: return id == "bedrock" ? "Change Profile" : (id == "azure" ? "Check Key and Endpoint" : "Paste a New Key")
        case .startServer: return ModelBrand.of(id).appPath != nil ? "Open \(id == "ollama" ? "Ollama" : "LM Studio")" : "Show in AI Models"
        case .pickModel: return "Pick a Model"
        case .signInToAWS: return "Sign In to AWS"
        case nil: return "Open AI Models"
        }
    }

    /// Fixes what it can on the spot: signing in, or opening the server's app. Returns false when
    /// the fix is in AI Models, such as pasting a new key, so the caller opens it there.
    func applyFix(_ id: String, _ health: ConnectionHealth) -> Bool {
        switch health.fix {
        case .signIn:
            signInToClaudeCode()
            return true
        case .signInToAWS(let profile):
            runInTerminal("aws sso login --profile '\(profile)'")
            return true
        case .startServer:
            guard let path = ModelBrand.of(id).appPath else { break }
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
            // Give the server a moment, then look again.
            Task {
                try? await Task.sleep(for: .seconds(6))
                await checkConnections([id])
            }
            return true
        default:
            break
        }
        modelsFocus = id
        return false
    }
}

// MARK: - Connecting a key or server

/// The fields for one provider, checked with the provider before anything is saved. Keys go to the
/// Keychain; the rest to Graphitree's settings.
struct ProviderConnectForm: View {
    @Environment(AppModel.self) private var model
    let provider: ModelProvider
    var isSetUp = false
    /// Called after saving, with what the check found, or with nil on Cancel.
    let onDone: (ConnectionHealth?) -> Void

    @State private var draft: [String: String] = [:]
    @State private var isChecking = false
    @State private var result: ConnectionHealth?
    @State private var serverModels: [String]?
    @State private var lookedForServer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ModelLogo(id: provider.id, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(isSetUp ? "Change \(provider.name)" : "Connect \(provider.name)").font(.callout.weight(.semibold))
                    Text(intro).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(provider.settings, id: \.variable) { setting in
                HStack(spacing: 10) {
                    Text(setting.label).font(.callout).frame(width: 90, alignment: .leading)
                    if setting.isSecret {
                        SecureField(isSetUp ? "Saved. Leave blank to keep it." : setting.placeholder, text: binding(setting.variable))
                            .textFieldStyle(.roundedBorder)
                    } else {
                        TextField(setting.placeholder, text: binding(setting.variable))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { if provider.access == .local { Task { await lookForServer() } } }
                    }
                }
            }
            HStack(spacing: 10) {
                Text("Model").font(.callout).frame(width: 90, alignment: .leading)
                TextField(provider.needsModel ? "Required: \(provider.defaultModel)" : "\(provider.defaultModel) (graphify's default)", text: binding(AIProviderStore.modelVariable))
                    .textFieldStyle(.roundedBorder)
                if let serverModels, !serverModels.isEmpty {
                    Menu("Pick") {
                        ForEach(serverModels, id: \.self) { name in
                            Button(name) { draft[AIProviderStore.modelVariable] = name }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Models the server has")
                }
            }
            if provider.access == .local, lookedForServer {
                Text(serverLine).font(.caption).foregroundStyle(serverModels == nil ? Palette.gold : .secondary)
            }
            HStack(spacing: 8) {
                Group {
                    if isChecking {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(provider.access == .local ? "Asking the server…" : "Checking with \(provider.name)…")
                        }
                        .foregroundStyle(.secondary)
                    } else if let result {
                        Text(result.isBroken ? result.detail : savedLine(result))
                            .foregroundStyle(result.isBroken ? Palette.coral : (result.level == .ok ? Palette.jade : Palette.gold))
                    } else {
                        Text(provider.access == .local ? "Nothing leaves this Mac." : "Checked before it's saved. Kept in your Keychain.")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Cancel") { onDone(nil) }.buttonStyle(SoftButtonStyle())
                Button(isSetUp ? "Check and Save" : "Check and Connect") { Task { await checkAndSave() } }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(!canSave || isChecking)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.gold.opacity(0.3)))
        .task(id: provider.id) {
            loadDraft()
            if provider.access == .local { await lookForServer() }
        }
    }

    private var intro: String {
        switch provider.access {
        case .local: return "Graphitree looks for the server and lists the models it has."
        case .apiKey where provider.id == "bedrock": return "Signs in with a profile from ~/.aws, so there's no key to paste here."
        case .apiKey: return "Graphitree checks the key with \(provider.name) before saving it. Nothing is generated, so it costs nothing."
        }
    }

    private var serverLine: String {
        guard let serverModels else { return "Nothing answers there yet. Start the server, then press Return in the Server field." }
        return serverModels.isEmpty ? "The server answers, but has no models yet." : "The server answers and has \(serverModels.count) model\(serverModels.count == 1 ? "" : "s")."
    }

    private func savedLine(_ result: ConnectionHealth) -> String {
        switch result.level {
        case .ok: return provider.access == .local ? "It works. Saved." : "It works. Saved to your Keychain."
        case .unknown: return "Saved. Graphitree couldn't check it right now and tries again later."
        case .warning: return "Saved. \(result.detail)"
        case .broken: return result.detail
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { draft[key] ?? "" }, set: { draft[key] = $0; result = nil })
    }

    private var canSave: Bool {
        for setting in provider.settings where setting.isRequired {
            let value = (draft[setting.variable] ?? "").trimmingCharacters(in: .whitespaces)
            if value.isEmpty && !(setting.isSecret && isSetUp) { return false }
        }
        if provider.needsModel && (draft[AIProviderStore.modelVariable] ?? "").trimmingCharacters(in: .whitespaces).isEmpty { return false }
        return true
    }

    private func loadDraft() {
        let saved = AIProviderStore.standard.values(for: provider)
        var values: [String: String] = [:]
        for setting in provider.settings where !setting.isSecret { values[setting.variable] = saved[setting.variable] ?? "" }
        // A new LM Studio connection starts at LM Studio's own address.
        if provider.id == "openai-compatible", (values["OPENAI_BASE_URL"] ?? "").isEmpty { values["OPENAI_BASE_URL"] = "http://localhost:1234/v1" }
        values[AIProviderStore.modelVariable] = saved[AIProviderStore.modelVariable] ?? ""
        draft = values
    }

    /// The draft as it would be saved: a blank key keeps the saved one.
    private var candidate: [String: String] {
        var values = draft
        let saved = AIProviderStore.standard.values(for: provider)
        for setting in provider.settings where setting.isSecret && (values[setting.variable] ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            values[setting.variable] = saved[setting.variable]
        }
        return values.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func lookForServer() async {
        serverModels = await ConnectionChecker.serverModels(provider, values: candidate)
        lookedForServer = true
        // An empty model field takes the server's only model, or graphify's default when it's there.
        if let serverModels, (draft[AIProviderStore.modelVariable] ?? "").isEmpty {
            if serverModels.count == 1 {
                draft[AIProviderStore.modelVariable] = serverModels[0]
            } else if provider.needsModel, let first = serverModels.first {
                draft[AIProviderStore.modelVariable] = first
            }
        }
    }

    private func checkAndSave() async {
        isChecking = true
        result = nil
        let found = await ConnectionChecker.check(provider, values: candidate, home: model.agentHome)
        isChecking = false
        result = found
        // A key that's turned down, or a model the server doesn't have, isn't saved, so whatever
        // worked before stays.
        guard !found.isBroken else { return }
        do {
            try AIProviderStore.standard.save(draft, for: provider)
            model.connected(provider.id)
            onDone(found)
        } catch {
            result = ConnectionHealth(level: .broken, status: "Not saved", detail: "Couldn't save \(provider.name): \(error.localizedDescription)")
        }
    }
}

// MARK: - The window's banner

/// One problem at a time, over the graph: what's wrong, the fix, and another model to use instead.
struct ConnectionBanner: View {
    @Environment(AppModel.self) private var model
    let id: String
    let health: ConnectionHealth
    let openModels: () -> Void

    var body: some View {
        let isBuilder = model.builderID == id
        let alternative = isBuilder && health.isBroken
            ? ConnectionProblems.alternative(to: id, options: model.aiOptions.map(\.id), health: model.connectionHealth)
            : nil
        HStack(spacing: 10) {
            ModelLogo(id: id, size: 24, level: health.level)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(BuildChoice.name(of: id)): \(health.status.lowercased())").font(.callout.weight(.semibold))
                Text(consequence(isBuilder: isBuilder))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 360, alignment: .leading)
            Button(model.fixTitle(id, health)) {
                if !model.applyFix(id, health) { openModels() }
            }
            .buttonStyle(GoldButtonStyle())
            if let alternative {
                Button("Use \(BuildChoice.name(of: alternative))") { model.useForBuilds(alternative) }
                    .buttonStyle(SoftButtonStyle())
            }
            Button("Dismiss", systemImage: "xmark") { model.dismissProblem(id) }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Hide until something changes. AI Models still shows it.")
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .glassPanel(cornerRadius: 14)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(health.level.color.opacity(0.45)))
        .fixedSize()
    }

    private func consequence(isBuilder: Bool) -> String {
        guard isBuilder else { return health.detail }
        switch health.level {
        case .broken: return "It builds the graph, so rebuilds read code only until it's fixed."
        default: return health.detail
        }
    }
}

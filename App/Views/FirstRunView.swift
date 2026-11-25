import AppKit
import SwiftUI

/// What a new install opens on. Without graphify, which maps the code, it offers to install it
/// first. Then it connects the AI model that builds the graph: whatever's already on this Mac
/// comes first, then API keys, then models on this Mac. "Not now" maps code only, and the
/// screen comes back next launch until a model is connected and graphify is installed.
struct FirstRunView: View {
    @Environment(AppModel.self) private var model

    private enum Found: Equatable {
        case looking
        /// Claude Code is installed. Nil sign-in means Graphitree couldn't ask it.
        case claude(ClaudeSignIn?)
        /// Not Claude Code, but a key or server that's already set up.
        case other(ModelOption)
        case nothing
    }

    @State private var found: Found = .looking
    @State private var connectedID: String?
    @State private var opened: String?
    /// The models each server on this Mac has, or nil when it doesn't answer.
    @State private var servers: [String: [String]?] = [:]
    @State private var copiedCommands = false

    private static let keyProviders = ["anthropic", "openai", "gemini", "deepseek", "kimi", "azure"]
    private static let localProviders = ["ollama", "openai-compatible"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 9) {
                    BrandMark()
                    Text("Graphitree").font(.headline)
                }
                steps
                if model.needsGraphify {
                    graphifyPage
                } else {
                    modelPage
                }
            }
            .padding(.horizontal, 44)
            .padding(.top, 56)
            .padding(.bottom, 40)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .task { await look() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Back from signing in, or from installing something, graphify in Terminal included.
            if !model.graphifyInstalling { model.refreshGraphify() }
            if connectedID == nil { Task { await look() } }
        }
    }

    @ViewBuilder
    private var modelPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connect an AI model").font(.system(size: 32, weight: .semibold))
            Text("graphify maps your code on its own, but an AI model is what reads your docs, names the groups on the map and answers in Ask and the Playbook. Connect one to start.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        reasons
        if let connectedID {
            doneCard(connectedID)
        } else {
            foundCard
            HStack(alignment: .top, spacing: 20) {
                keysColumn.frame(maxWidth: .infinity, alignment: .topLeading)
                localColumn.frame(width: 300, alignment: .topLeading)
            }
            skipRow
        }
    }

    // MARK: - graphify

    private var home: String { FileManager.default.homeDirectoryForCurrentUser.path }

    @ViewBuilder
    private var graphifyPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Get graphify").font(.system(size: 32, weight: .semibold))
            Text("graphify maps your code into the graph Graphitree shows. It's free and open source, and it runs on this Mac. Graphitree can install it for you.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        graphifyCard
        terminalCard
        HStack(spacing: 10) {
            Button("Not now") { model.skipGraphify() }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.gold)
                .underline()
                .disabled(model.graphifyInstalling)
            Text("Graphitree opens graphs graphify already made, but can't map anything new without it. It asks again next time you open it.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }

    private var graphifyCard: some View {
        let hasUV = GraphifySetup.locateUV(home: home) != nil
        let failed = model.graphifyError != nil && !model.graphifyInstalling
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: failed ? "exclamationmark.triangle" : "shippingbox")
                .font(.system(size: 28))
                .foregroundStyle(failed ? Palette.coral : Palette.gold)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                if model.graphifyInstalling {
                    Text("Installing graphify").font(.title3.weight(.semibold))
                    Text(model.graphifyStep?.title ?? "Starting…").foregroundStyle(.secondary)
                } else if let error = model.graphifyError {
                    Text("graphify didn't install").font(.title3.weight(.semibold))
                    Text(error).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                } else {
                    Text("graphify isn't on this Mac yet").font(.title3.weight(.semibold))
                    Text(hasUV
                         ? "Graphitree installs it with uv, which is already here."
                         : "Graphitree installs uv, Astral's tool for Python apps, with its official installer, then graphify with uv. Both go in ~/.local/bin, and your shell settings stay as they are.")
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            if model.graphifyInstalling {
                ProgressView().controlSize(.small).padding(.top, 6)
            } else {
                Button(failed ? "Try Again" : "Install graphify") { model.installGraphify() }
                    .buttonStyle(GoldButtonStyle())
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .modifier(BigCard(tint: failed ? Palette.coral : Palette.gold))
    }

    /// The same install, for someone who'd rather use Terminal. Coming back to Graphitree looks again.
    private var terminalCard: some View {
        let commands = GraphifySetup.terminalCommands(hasUV: GraphifySetup.locateUV(home: home) != nil).joined(separator: "\n")
        return VStack(alignment: .leading, spacing: 8) {
            Text("Or install it in Terminal").font(.headline)
            Text("Run this, then come back to Graphitree. It looks again when you do.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 10) {
                Text(commands)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(copiedCommands ? "Copied" : "Copy", systemImage: copiedCommands ? "checkmark" : "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(commands, forType: .string)
                    copiedCommands = true
                }
                .buttonStyle(SoftButtonStyle())
            }
            .padding(12)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Pieces

    private var steps: some View {
        HStack(spacing: 10) {
            step(1, "Get graphify", isOn: model.needsGraphify, isDone: model.graphifyPath != nil)
            Rectangle().fill(Palette.hairline).frame(width: 28, height: 1)
            step(2, "Connect a model", isOn: !model.needsGraphify && connectedID == nil, isDone: connectedID != nil)
            Rectangle().fill(Palette.hairline).frame(width: 28, height: 1)
            step(3, "Choose folders", isOn: false, isDone: false)
            Rectangle().fill(Palette.hairline).frame(width: 28, height: 1)
            step(4, "Build the map", isOn: false, isDone: false)
        }
        .font(.callout)
    }

    private func step(_ number: Int, _ title: String, isOn: Bool, isDone: Bool) -> some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill(isOn || isDone ? Palette.gold : Color.white.opacity(0.08))
                if isDone {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold))
                } else {
                    Text("\(number)").font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(isOn || isDone ? Color(hex: 0x1B1408) : .secondary)
            .frame(width: 20, height: 20)
            Text(title).foregroundStyle(isOn ? .primary : .secondary)
        }
    }

    private var reasons: some View {
        HStack(alignment: .top, spacing: 10) {
            reason("Reads docs and images", "Only new or changed files go to the model.", symbol: "doc.text.image")
            reason("Names the map", "Groups get real names, not numbers.", symbol: "tag")
            reason("Answers questions", "Ask and the Playbook chat use it too.", symbol: "bubble.left.and.text.bubble.right")
        }
    }

    private func reason(_ title: String, _ detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.callout.weight(.semibold)).foregroundStyle(Palette.gold.opacity(0.95))
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .modifier(RowCard())
    }

    @ViewBuilder
    private var foundCard: some View {
        switch found {
        case .looking:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Looking for AI tools on this Mac…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(BigCard(tint: nil))
        case .claude(let signIn):
            let signedOut = signIn?.loggedIn == false
            HStack(spacing: 14) {
                ModelLogo(id: "claude-code", size: 48, level: signedOut ? .broken : nil)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Found on this Mac").font(.caption.weight(.semibold)).foregroundStyle(Palette.gold)
                    Text("Claude Code").font(.title3.weight(.semibold))
                    Text(signedOut
                         ? "Installed, but signed out. Sign in with your Claude plan, then come back."
                         : "\(signIn?.planName.map { "Signed in with your \($0)." } ?? "Signed in.") Nothing extra to pay.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                if signedOut {
                    Button("Check Again") { Task { await look() } }.buttonStyle(SoftButtonStyle())
                    Button("Sign In…") { model.signInToClaudeCode() }
                        .buttonStyle(GoldButtonStyle())
                        .help("Opens Terminal with claude auth login. Sign-in happens in your browser.")
                } else {
                    Button("Use Claude Code") { use("claude-code") }
                        .buttonStyle(GoldButtonStyle())
                        .controlSize(.large)
                }
            }
            .modifier(BigCard(tint: signedOut ? Palette.coral : Palette.gold))
        case .other(let option):
            HStack(spacing: 14) {
                ModelLogo(id: option.id, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Already set up").font(.caption.weight(.semibold)).foregroundStyle(Palette.gold)
                    Text(option.name).font(.title3.weight(.semibold))
                    Text("Graphitree found it in its settings.").foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button("Use \(BuildChoice.name(of: option.id))") { use(option.id) }.buttonStyle(GoldButtonStyle())
            }
            .modifier(BigCard(tint: Palette.gold))
        case .nothing:
            HStack(spacing: 14) {
                ModelLogo(id: "none", size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("No AI tool found on this Mac").font(.title3.weight(.semibold))
                    Text("Paste an API key below, or install Claude Code or Ollama and come back. Graphitree looks again when you do.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button("Look Again", systemImage: "arrow.clockwise") { Task { await look() } }.buttonStyle(SoftButtonStyle())
            }
            .modifier(BigCard(tint: nil))
        }
    }

    private func doneCard(_ id: String) -> some View {
        HStack(spacing: 14) {
            ModelLogo(id: id, size: 44, level: model.connectionHealth[id]?.level)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(BuildChoice.name(of: id)) is connected").font(.title3.weight(.semibold))
                Text(model.connectionHealth[id].map { "\($0.detail) " } ?? "")
                    + Text("It builds the graph from now on. You can switch any time in AI Models.")
            }
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Button("Continue") { model.closeFirstRun() }
                .buttonStyle(GoldButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .modifier(BigCard(tint: Palette.jade))
    }

    private var keysColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or paste an API key").font(.headline)
            Text("Pay as you go. The key is checked before it's saved, and kept in your Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Self.keyProviders, id: \.self) { id in
                    tile(id, detail: keyDetail(id), dimmed: false)
                }
            }
            if let opened, Self.keyProviders.contains(opened), let provider = provider(opened) {
                form(provider)
            }
        }
    }

    private var localColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or run one on this Mac").font(.headline)
            Text("Free and private, but slower.").font(.caption).foregroundStyle(.secondary)
            ForEach(Self.localProviders, id: \.self) { id in
                tile(id, detail: localDetail(id), dimmed: isMissing(id))
            }
            if let opened, Self.localProviders.contains(opened), let provider = provider(opened) {
                form(provider)
            }
            Text("Codex, Antigravity, Copilot and other coding tools build with graphify's skill inside the tool. Connect them later in AI Models.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    private func tile(_ id: String, detail: String, dimmed: Bool) -> some View {
        let isOpen = opened == id
        return Button {
            opened = isOpen ? nil : id
        } label: {
            HStack(spacing: 10) {
                ModelLogo(id: id, size: 28, dimmed: dimmed)
                VStack(alignment: .leading, spacing: 1) {
                    Text(shortName(id)).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
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

    private func form(_ provider: ModelProvider) -> some View {
        ProviderConnectForm(provider: provider) { result in
            opened = nil
            guard result != nil else { return }
            model.useForBuilds(provider.id)
            connectedID = provider.id
        }
    }

    private var skipRow: some View {
        HStack(spacing: 10) {
            Button("Not now, map code only") { model.skipFirstRun() }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.gold)
                .underline()
            Text("Docs, papers and images are left out, and Graphitree asks again next time you open it.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }

    // MARK: - Words

    private func provider(_ id: String) -> ModelProvider? { AICatalog.providers.first { $0.id == id } }

    private func shortName(_ id: String) -> String {
        switch id {
        case "anthropic": return "Anthropic"
        case "openai": return "OpenAI"
        case "openai-compatible": return "LM Studio or another server"
        default: return provider(id)?.name ?? BuildChoice.name(of: id)
        }
    }

    private func keyDetail(_ id: String) -> String {
        switch id {
        case "gemini": return "API key, free tier"
        case "azure": return "Key and endpoint"
        default: return "API key, billed per use"
        }
    }

    private func isMissing(_ id: String) -> Bool {
        (servers[id] ?? nil) == nil && ModelBrand.of(id).appPath == nil
    }

    private func localDetail(_ id: String) -> String {
        if let models = servers[id] ?? nil {
            return "Running · \(models.count) model\(models.count == 1 ? "" : "s")"
        }
        if ModelBrand.of(id).appPath != nil { return "Installed, not running" }
        if servers[id] == nil { return "Looking…" }
        return id == "ollama" ? "Not found · get it at ollama.com" : "Not found · get it at lmstudio.ai"
    }

    // MARK: - Actions

    private func use(_ id: String) {
        model.useForBuilds(id)
        Task { await model.checkConnections([id]) }
        connectedID = id
    }

    /// Looks for Claude Code, anything already set up, and servers on this Mac.
    private func look() async {
        model.refreshAIOptions()
        if let command = ToolLocator.command(["claude"], home: model.agentHome) {
            found = .claude(await ConnectionChecker.claudeSignIn(command: command))
        } else if let first = model.aiOptions.first {
            found = .other(first)
        } else {
            found = .nothing
        }
        for id in Self.localProviders {
            guard let provider = provider(id) else { continue }
            let values = id == "openai-compatible" ? ["OPENAI_BASE_URL": "http://localhost:1234/v1"] : AIProviderStore.standard.values(for: provider)
            servers[id] = .some(await ConnectionChecker.serverModels(provider, values: values))
        }
    }
}

/// The large cards on the first-run screen.
private struct BigCard: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        content
            .padding(16)
            .background((tint ?? .white).opacity(tint == nil ? 0.035 : 0.07), in: shape)
            .overlay(shape.strokeBorder((tint ?? .white).opacity(tint == nil ? 0.08 : 0.35)))
    }
}

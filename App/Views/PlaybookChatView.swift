import SwiftUI

/// The Playbook's first tab: a chat with the model that builds the graph. It researches libraries
/// and the stack, and suggests changes that wait here until the person applies them.
struct PlaybookChatView: View {
    @Environment(AppModel.self) private var model
    let playbook: Playbook
    let scan: StackScanResult?
    /// Puts one change into the playbook, through the panel's own save.
    let apply: (PlaybookChange) -> Void
    let openModels: () -> Void

    @State private var draft = ""
    @FocusState private var isTyping: Bool
    @State private var learning: (digest: String, messages: Int, sessions: Int)?
    @State private var isPreparingLearning = false

    private static let suggestions = [
        "Which of my libraries are still maintained? Mark any I should stop using.",
        "What should I use for forms in React? Add your pick.",
        "Look at my stack answers and fix anything that doesn't match what I use for new work.",
        "Help me fill in How You Work. Ask me a few questions first.",
    ]

    var body: some View {
        VStack(spacing: 0) {
            engineBar
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(Palette.hairline).frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if model.chatTurns.isEmpty { welcome }
                        ForEach(model.chatTurns) { turn in
                            bubble(turn).id(turn.id)
                        }
                        if model.isChatting { thinking.id("thinking") }
                    }
                    .padding(18)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: model.chatTurns.count) { scrollToEnd(proxy) }
                .onChange(of: model.isChatting) { scrollToEnd(proxy) }
                .onAppear { scrollToEnd(proxy) }
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            composer
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            model.loadChatIfNeeded()
            if model.wantsSessionLearning {
                model.wantsSessionLearning = false
                Task { await prepareLearning() }
            }
        }
        .alert(
            learning.map { "Learn from \($0.sessions) session file\($0.sessions == 1 ? "" : "s")?" } ?? "",
            isPresented: Binding(get: { learning != nil }, set: { if !$0 { learning = nil } })
        ) {
            Button("Learn") {
                if let learning { model.learnFromSessions(digest: learning.digest, playbook: playbook, scan: scan) }
                learning = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(learningMessage)
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if model.isChatting {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = model.chatTurns.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Which model

    @ViewBuilder
    private var engineBar: some View {
        switch model.chatEngine() {
        case .success(let engine):
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Palette.gold)
                Text("Chatting with \(engine.name)").font(.callout.weight(.medium))
                Text(engineDetail(engine)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 8)
                if isPreparingLearning {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Learn From My Sessions…") { Task { await prepareLearning() } }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(model.isChatting)
                        .help("Suggests How You Work notes and picks from your own messages in recent Claude Code sessions")
                }
                if !model.chatTurns.isEmpty {
                    Button("Clear Chat") { model.clearChat() }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(model.isChatting)
                }
            }
        case .failure(let error):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.gold)
                Text(error.message).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Open AI Models…", action: openModels).buttonStyle(GoldButtonStyle())
            }
        }
    }

    private func engineDetail(_ engine: ChatEngine) -> String {
        let billing: String
        switch engine.billing {
        case .plan: billing = "uses your plan"
        case .apiAccount: billing = "billed to your API account"
        case .thisMac: billing = "runs on this Mac"
        }
        return engine.searchesWeb ? "Searches the web, \(billing)." : "Answers from what it knows, \(billing)."
    }

    // MARK: - Learning from sessions

    private func prepareLearning() async {
        isPreparingLearning = true
        let found = await model.sessionDigest()
        isPreparingLearning = false
        learning = found.messages == 0 ? nil : (digest: found.text, messages: found.messages, sessions: found.sessions)
        if found.messages == 0 {
            model.sendChat("Learn how I work from my recent sessions.", playbook: playbook, scan: scan, extraContext: "There are no Claude Code session messages from the last \(AppModel.insightDays) days on this Mac. Say so, and offer to ask a few questions instead.")
        }
    }

    private var learningMessage: String {
        guard let learning else { return "" }
        let overhead: Int
        if case .success(let engine) = model.chatEngine(), case .claudeCode = engine.backend { overhead = 45_000 } else { overhead = 3_000 }
        let tokens = learning.digest.count / 4 + overhead
        return "Sends \(learning.messages.formatted()) of your own messages from the last \(AppModel.insightDays) days to \(engineName): about \(BuildView.tokens(tokens)) tokens. Tool output and pasted files aren't included. It suggests notes and picks without private details, and nothing is saved until you apply them."
    }

    // MARK: - Conversation

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask about libraries, your stack or how you work").font(.title3.weight(.semibold))
            Text("It sees your playbook and what your projects use. When it suggests a change, nothing is saved until you apply it. Saved changes go into the guide and the knowledge graph, so every AI tool sees them.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Button { send(suggestion) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Palette.gold)
                            Text(suggestion).font(.callout).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.06)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isChatting || !canChat)
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(_ turn: ChatTurn) -> some View {
        if turn.role == .user {
            HStack {
                Spacer(minLength: 80)
                Text(turn.text)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Palette.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.gold.opacity(0.22)))
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if turn.isError {
                    Label(turn.text, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(Palette.coral)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(markdown(turn.text))
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !turn.changes.isEmpty { changes(in: turn) }
            }
            .padding(.trailing, 40)
        }
    }

    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }

    private func changes(in turn: ChatTurn) -> some View {
        let open = turn.changes.filter { $0.state == .proposed }
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Suggested changes").font(.caption.weight(.semibold)).foregroundStyle(Palette.gold)
                Spacer()
                if open.count > 1 {
                    Button("Apply All \(open.count)") {
                        for change in open { applyChange(change, in: turn) }
                    }
                    .buttonStyle(SoftButtonStyle())
                }
            }
            .padding(.bottom, 6)
            ForEach(turn.changes) { change in
                changeRow(change, in: turn)
                if change.id != turn.changes.last?.id {
                    Rectangle().fill(Palette.hairline).frame(height: 1)
                }
            }
        }
        .modifier(RowCard())
    }

    private func changeRow(_ change: PlaybookChange, in turn: ChatTurn) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol(change.kind)).foregroundStyle(.secondary).frame(width: 18).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(PlaybookChat.label(change, in: playbook)).font(.callout.weight(.medium))
                if let detail = detail(change) {
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
                if !change.reason.isEmpty {
                    Text(change.reason).font(.caption).foregroundStyle(.tertiary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            switch change.state {
            case .proposed:
                Button("Skip") { model.setChange(change.id, in: turn.id, to: .dismissed) }
                    .buttonStyle(SoftButtonStyle())
                Button("Apply") { applyChange(change, in: turn) }
                    .buttonStyle(GoldButtonStyle())
            case .applied:
                Label("Applied", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Palette.jade)
            case .dismissed:
                Text("Skipped").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 7)
    }

    private func symbol(_ kind: PlaybookChange.Kind) -> String {
        switch kind {
        case .library: return "books.vertical"
        case .stack: return "square.stack.3d.up"
        case .habit: return "person.text.rectangle"
        }
    }

    private func detail(_ change: PlaybookChange) -> String? {
        switch change.kind {
        case .library:
            guard let library = change.library else { return nil }
            let parts = [library.task, library.purpose].filter { !$0.isEmpty && $0.lowercased() != "unknown" }
            return parts.isEmpty ? nil : parts.joined(separator: ". ")
        case .stack:
            let now = playbook.stack[change.question ?? ""]?.choices ?? []
            var text = "Now: \(now.isEmpty ? "not answered" : now.joined(separator: ", "))."
            if !change.notes.isEmpty { text += " Notes: \(change.notes)" }
            return text
        case .habit:
            return change.text
        }
    }

    private func applyChange(_ change: PlaybookChange, in turn: ChatTurn) {
        apply(change)
        model.setChange(change.id, in: turn.id, to: .applied)
    }

    private var thinking: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = Int(context.date.timeIntervalSince(model.chatStartedAt ?? context.date))
                Text("\(engineName) is \(searches ? "researching" : "thinking")… \(seconds) s")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Button("Stop") { model.stopChat() }.buttonStyle(SoftButtonStyle())
        }
    }

    private var engineName: String {
        if case .success(let engine) = model.chatEngine() { return engine.name }
        return "The model"
    }

    private var searches: Bool {
        if case .success(let engine) = model.chatEngine() { return engine.searchesWeb }
        return false
    }

    private var canChat: Bool {
        if case .success = model.chatEngine() { return true }
        return false
    }

    // MARK: - Writing

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask about a library, your stack or how you work…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.callout)
                .lineLimit(1...6)
                .focused($isTyping)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(isTyping ? 0.16 : 0.07)))
                .onSubmit { send(draft) }
                .disabled(!canChat)
            Button("Send", systemImage: "arrow.up") { send(draft) }
                .labelStyle(.iconOnly)
                .buttonStyle(GoldButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.isChatting || !canChat || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send (⌘↩)")
        }
    }

    private func send(_ text: String) {
        guard !model.isChatting else { return }
        model.sendChat(text, playbook: playbook, scan: scan)
        draft = ""
    }
}

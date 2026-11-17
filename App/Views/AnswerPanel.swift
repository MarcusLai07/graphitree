import SwiftUI

struct AskOutcome: Equatable, Sendable {
    let answer: QueryAnswer
    let items: [AnswerItem]

    var noiseCount: Int { items.filter(\.isNoise).count }
}

enum AskState: Equatable {
    case running
    case ready(AskOutcome)
    case failed(String)
}

/// One question to the graph, asked of the graph as it is and, when possible, with the rules applied.
struct AskSession: Equatable {
    let id = UUID()
    let question: String
    var now: AskState = .running
    /// Nil when there is no up-to-date clean graph to compare with.
    var withRules: AskState?
    var showsWithRules = false

    var shown: AskState { showsWithRules ? (withRules ?? now) : now }
}

/// Whether the answer can be compared with the clean graph, and if not, why.
enum AnswerComparison {
    case available
    case needsCleanGraph
    case noRules
}

/// The right-hand panel for an answer: what an agent would get back, and which of it is noise.
struct AnswerPanel: View {
    @Binding var session: AskSession
    let comparison: AnswerComparison
    /// Nodes that other projects' code links to by name match, such as `Json`.
    let suspectHubs: Set<String>
    let open: (String) -> Void
    let writeCleanGraph: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What an agent gets back").font(.callout.weight(.medium)).foregroundStyle(.secondary)
                Text(session.question)
                    .font(.headline)
                    .lineLimit(3)
                    .textSelection(.enabled)
                compareControl
                summary
            }
            .padding(14)
            Rectangle().fill(Palette.hairline).frame(height: 1)
            results
        }
    }

    @ViewBuilder
    private var compareControl: some View {
        switch comparison {
        case .available:
            Picker("Graph", selection: $session.showsWithRules) {
                Text("Now").tag(false)
                Text("With your rules").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        case .needsCleanGraph:
            HStack(spacing: 8) {
                Text("Write the clean graph, then ask again to compare with your rules.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("Write", action: writeCleanGraph).buttonStyle(GoldButtonStyle())
            }
        case .noRules:
            Text("No rules yet, so the clean graph would give the same answer.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var summary: some View {
        switch session.shown {
        case .running:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Asking graphify…").foregroundStyle(.secondary)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .ready(let outcome):
            VStack(alignment: .leading, spacing: 6) {
                Text(countLine(outcome)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                noiseChips(outcome)
                if let delta = comparisonLine { Text(delta).font(.caption).foregroundStyle(Palette.jade) }
            }
        }
    }

    private func isSuspectHub(_ item: AnswerItem) -> Bool {
        item.nodeID.map(suspectHubs.contains) ?? false
    }

    private func countLine(_ outcome: AskOutcome) -> String {
        let shown = outcome.items.count
        guard let found = outcome.answer.found else {
            return shown == 0 ? "graphify found nothing for that." : "\(shown.formatted()) \(shown == 1 ? "node" : "nodes") returned."
        }
        if let cut = outcome.answer.cut, cut > 0 {
            return "\(found.formatted()) found. \(shown.formatted()) fit in the answer, \(cut.formatted()) were cut to stay within the token budget."
        }
        return "\(found.formatted()) found, all \(shown.formatted()) returned."
    }

    private func noiseChips(_ outcome: AskOutcome) -> some View {
        let generated = outcome.items.filter(\.isGenerated).count
        let missing = outcome.items.filter { $0.isMissingFile && !$0.isGenerated }.count
        let hidden = outcome.items.filter(\.isHidden).count
        let hubs = outcome.items.filter { isSuspectHub($0) }.count
        return HStack(spacing: 6) {
            if generated > 0 { Tag(text: "\(generated) generated", colour: Palette.gold) }
            if hubs > 0 { Tag(text: "\(hubs) suspect \(hubs == 1 ? "hub" : "hubs")", colour: Palette.magenta) }
            if missing > 0 { Tag(text: "\(missing) from missing files", colour: Palette.gold) }
            if hidden > 0 { Tag(text: "\(hidden) hidden by your rules", colour: .secondary) }
            if generated + missing + hidden + hubs == 0, !outcome.items.isEmpty {
                Tag(text: "No noise found", colour: Palette.jade)
            }
        }
    }

    /// How much the rules trim the noise, once both answers are in.
    private var comparisonLine: String? {
        guard case .ready(let now) = session.now, case .ready(let clean)? = session.withRules else { return nil }
        let difference = now.noiseCount - clean.noiseCount
        guard difference != 0 else { return "Your rules don't change the noise in this answer." }
        return difference > 0
            ? "Your rules remove \(difference) noisy \(difference == 1 ? "node" : "nodes") from this answer."
            : "This answer has \(-difference) more noisy \(difference == -1 ? "node" : "nodes") with your rules."
    }

    @ViewBuilder
    private var results: some View {
        if case .ready(let outcome) = session.shown, !outcome.items.isEmpty {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(outcome.items) { item in
                        row(item)
                    }
                }
                .padding(8)
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            Spacer(minLength: 0)
        }
    }

    private func row(_ item: AnswerItem) -> some View {
        Button {
            if let nodeID = item.nodeID { open(nodeID) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.label)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.path.isEmpty ? "No source file" : item.path + (item.location.isEmpty ? "" : " " + item.location))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 4)
                if item.isGenerated {
                    Tag(text: "Generated", colour: Palette.gold)
                } else if item.isMissingFile {
                    Tag(text: "Missing", colour: Palette.gold)
                }
                if isSuspectHub(item) { Tag(text: "Suspect hub", colour: Palette.magenta) }
                if item.isHidden { Tag(text: "Hidden", colour: .secondary) }
            }
            .opacity(item.isNoise || item.isHidden || isSuspectHub(item) ? 0.75 : 1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(item.nodeID == nil)
        .help(item.nodeID == nil
            ? "Graphitree couldn't match this node to its index."
            : isSuspectHub(item) ? "Other projects link here only because a name matches. Review it under Cross-Project Links." : "Show it in the graph")
    }
}

private struct Tag: View {
    let text: String
    let colour: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(colour)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(colour.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
            .fixedSize()
    }
}

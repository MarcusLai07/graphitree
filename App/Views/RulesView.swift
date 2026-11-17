import SwiftUI

/// The cleanup rules saved from Graph health, each one undoable. Shown inside Build.
struct CleanupRulesList: View {
    @Environment(AppModel.self) private var model
    let snapshot: WorkspaceSnapshot

    private var orphaned: [RuleRow] { snapshot.rules.filter(\.isOrphaned) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if snapshot.unreadableLogLines > 0 {
                Label(
                    "\(snapshot.unreadableLogLines) \(snapshot.unreadableLogLines == 1 ? "line" : "lines") in curation.jsonl couldn't be read and are being ignored.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(Palette.coral)
            }
            if !orphaned.isEmpty {
                HStack {
                    Label(
                        "\(orphaned.count) \(orphaned.count == 1 ? "rule matches" : "rules match") nothing in this graph, usually because files moved.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    Spacer()
                    Button("Remove Those Rules") { model.undo(ruleIDs: orphaned.map(\.id)) }
                        .buttonStyle(SoftButtonStyle())
                }
            }
            if snapshot.rules.isEmpty {
                Text("None yet. When you hide or reject something from Graph health, the decision is saved here as a rule, and each one can be undone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(snapshot.rules) { rule in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(rule.summary).font(.callout).lineLimit(1).truncationMode(.middle)
                                    Text("\(rule.affects) · \(rule.at.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(rule.isOrphaned ? Palette.coral : .secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                Button("Undo") { model.undo(ruleIDs: [rule.id]) }
                                    .buttonStyle(SoftButtonStyle())
                                    .help("Undo this rule")
                            }
                            .padding(.vertical, 6)
                            Rectangle().fill(Palette.hairline).frame(height: 1)
                        }
                    }
                }
                .frame(maxHeight: min(CGFloat(snapshot.rules.count) * 46, 260))
            }
        }
    }
}

import AppKit
import SwiftUI

/// The right drawer for a selected project, community or file.
struct SelectionDrawer: View {
    @Environment(AppModel.self) private var model

    let node: SceneNode
    /// Set when the selection is a whole project, which is what findings are grouped by.
    let project: String?
    let snapshot: WorkspaceSnapshot
    let canOpen: Bool
    let drill: () -> Void
    let openList: (Detector) -> Void
    let review: (Finding) -> Void

    private var generated: [Finding] {
        guard let project else { return [] }
        return (snapshot.findings[.generated] ?? [])
            .filter { $0.project == project }
            .sorted { $0.count > $1.count }
    }

    private var suspects: [Finding] {
        guard let project else { return [] }
        return (snapshot.findings[.crossProject] ?? [])
            .filter { $0.project == project }
            .sorted { $0.count > $1.count }
    }

    private var generatedNodes: Int { generated.reduce(0) { $0 + $1.count } }

    private var folder: String? {
        guard let project else { return nil }
        return GraphSource(outDirectory: model.outDirectory).existingPath(for: project)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            stats.padding(.top, 12)
            if !generated.isEmpty { noiseSection }
            if !suspects.isEmpty { suspectSection }
            actions.padding(.top, 14)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .textSelection(.enabled)
                if let project {
                    Text(project)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 4)
            if let owner {
                Text(owner)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.gold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Palette.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var displayName: String {
        (node.label as NSString).lastPathComponent
    }

    /// `work` or `personal` for a project stored under one of those folders.
    private var owner: String? {
        guard let project, project.contains("/") else { return nil }
        return project.split(separator: "/").first.map { $0.prefix(1).uppercased() + $0.dropFirst() }
    }

    private var stats: some View {
        HStack(spacing: 6) {
            StatChip(title: "Nodes", value: node.value.formatted())
            if project != nil, node.value > 0 {
                StatChip(
                    title: "Generated",
                    value: (Double(generatedNodes) / Double(node.value)).formatted(.percent.precision(.fractionLength(0))),
                    isHighlighted: generatedNodes > 0
                )
                StatChip(title: "After hiding", value: max(node.value - generatedNodes, 0).formatted())
            }
        }
    }

    private var noiseSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Where the noise is", detector: .generated, total: generated.count)
            ForEach(generated.prefix(4)) { finding in
                FindingCard(finding: finding, title: relativeLocation(of: finding)) {
                    hideButton(for: finding)
                }
            }
        }
        .padding(.top, 14)
    }

    private var suspectSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Suspect links into this project", detector: .crossProject, total: suspects.count)
            ForEach(suspects.prefix(3)) { finding in
                FindingCard(finding: finding, title: finding.title) {
                    Button("Review") { review(finding) }
                        .buttonStyle(SoftButtonStyle())
                }
            }
        }
        .padding(.top, 14)
    }

    /// The largest item gets the gold button, because that's the decision that matters most.
    @ViewBuilder
    private func hideButton(for finding: Finding) -> some View {
        let button = Button("Hide") { model.remove([finding]) }
            .help("Save a rule that hides these nodes. You can undo it.")
        if finding.id == generated.first?.id {
            button.buttonStyle(GoldButtonStyle())
        } else {
            button.buttonStyle(SoftButtonStyle())
        }
    }

    /// The path inside the project, which says more than the last folder's name.
    private func relativeLocation(of finding: Finding) -> String {
        guard let project, finding.location.hasPrefix(project + "/") else { return finding.title }
        return String(finding.location.dropFirst(project.count + 1))
    }

    private func sectionTitle(_ title: String, detector: Detector, total: Int) -> some View {
        HStack {
            Text(title).font(.callout.weight(.medium)).foregroundStyle(.secondary)
            Spacer()
            if total > 1 {
                Button("Open List") { openList(detector) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Palette.gold)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 6) {
            if canOpen {
                Button(action: drill) {
                    Text("Drill In").frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle())
                .keyboardShortcut(.return, modifiers: [])
                .help("Open this level (Return)")
            }
            if let folder {
                Button("Open Folder") { NSWorkspace.shared.open(URL(fileURLWithPath: folder)) }
                    .buttonStyle(SoftButtonStyle())
                Button("Copy Path", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(folder, forType: .string)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(SoftButtonStyle())
                .help("Copy the folder's path")
            }
        }
    }
}

private struct StatChip: View {
    let title: String
    let value: String
    var isHighlighted = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .foregroundStyle(isHighlighted ? Palette.gold : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: shape)
        .overlay(shape.strokeBorder(isHighlighted ? Palette.gold.opacity(0.25) : Color.white.opacity(0.05)))
        .accessibilityElement(children: .combine)
    }
}

private struct FindingCard<Action: View>: View {
    let finding: Finding
    let title: String
    @ViewBuilder let action: Action

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(([finding.affects] + (finding.note.isEmpty ? [] : [finding.note])).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .help(finding.location)
            Spacer(minLength: 4)
            action
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.035), in: shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.05)))
    }
}

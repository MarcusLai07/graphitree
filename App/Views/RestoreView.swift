import AppKit
import SwiftUI

/// Restore from Backup: pick backups (this knowledge base's, or any GitHub repo Graphitree wrote),
/// and Graphitree joins them into a new graphify-out beside the root. The graph in use is never
/// touched; moving the restored one into place is a separate, explicit step.
struct RestorePane: View {
    @Environment(AppModel.self) private var model
    let plans: [GraphPlan]
    let logins: [String]

    @State private var sources: [BackupRestore.Source] = []
    @State private var picked: Set<String> = []
    @State private var login = ""
    @State private var repo = ""
    @State private var root = ""
    @State private var restored: BackupRestore.Restored?
    @State private var failure: String?
    @State private var placeMessage: String?

    private var chosen: [BackupRestore.Source] { sources.filter { picked.contains($0.id) } }
    private var liveGraph: URL { URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("graphify-out") }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Restore from backup").font(.headline)
                Text("Graphitree copies the backups you pick and joins them into a new folder beside \(AgentGuide.abbreviate(root)). Your graph in use isn't touched.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            sourcesCard
            rootCard
            HStack(spacing: 10) {
                Button(model.isRestoring ? "Restoring…" : "Restore \(chosen.count == 1 ? "1 Backup" : "\(chosen.count) Backups")") {
                    Task { await restore() }
                }
                .buttonStyle(GoldButtonStyle())
                .disabled(chosen.isEmpty || model.isRestoring || root.isEmpty)
                if chosen.count > 1 {
                    Text("The first one's graph-wide settings win.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !model.restoreLog.isEmpty {
                ScrollView {
                    Text(model.restoreLog)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 140)
                .padding(10)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
            if let failure {
                Text(failure).font(.caption).foregroundStyle(Palette.coral).fixedSize(horizontal: false, vertical: true)
            }
            if let restored { resultCard(restored) }
        }
        .onAppear(perform: setUp)
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backups").font(.body.weight(.semibold))
            if sources.isEmpty {
                Text("None are set up here. Add a backup repo below: any repo Graphitree backed up to works, from this Mac or another.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(sources) { source in
                Toggle(isOn: Binding(get: { picked.contains(source.id) }, set: { on in
                    if on { picked.insert(source.id) } else { picked.remove(source.id) }
                })) {
                    HStack(spacing: 6) {
                        Image(systemName: source.login == nil ? "laptopcomputer" : "lock").font(.caption).foregroundStyle(.secondary)
                        Text(source.name).font(.callout)
                        if let login = source.login, !source.name.hasPrefix(login + "/") {
                            Text("as \(login)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(.checkbox)
            }
            Divider().padding(.vertical, 2)
            HStack(spacing: 8) {
                Text("Add a repo").font(.caption).foregroundStyle(.secondary)
                Picker("Account", selection: $login) {
                    if logins.isEmpty { Text("No gh account").tag("") }
                    ForEach(logins, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .controlSize(.small)
                Text("/").foregroundStyle(.secondary)
                TextField("personal-kb", text: $repo)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(width: 160)
                    .onSubmit(addRepo)
                Button("Add", action: addRepo)
                    .buttonStyle(SoftButtonStyle())
                    .disabled(login.isEmpty || repo.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .modifier(RowCard())
    }

    private var rootCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Built from").font(.caption).foregroundStyle(.secondary)
                TextField("~/Documents/GitHub", text: $root)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .font(.caption.monospaced())
            }
            Text("The folder the graph's paths start from. The restored graph goes to \(AgentGuide.abbreviate(BackupRestore.destination(root: root).deletingLastPathComponent().deletingLastPathComponent().path))/, outside it, so a rebuild never reads it.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .modifier(RowCard())
    }

    private func resultCard(_ restored: BackupRestore.Restored) -> some View {
        let hasLive = FileManager.default.fileExists(atPath: liveGraph.path)
        return VStack(alignment: .leading, spacing: 8) {
            Label("Restored \(restored.nodes.formatted()) nodes and \(restored.edges.formatted()) edges from \(restored.backups) backup\(restored.backups == 1 ? "" : "s")", systemImage: "checkmark.circle")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Palette.jade)
            Text(AgentGuide.abbreviate(restored.folder.path)).font(.caption.monospaced()).textSelection(.enabled)
            ForEach(restored.notes, id: \.self) { note in
                Text(note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button("Open in Graphitree") { model.choose(restored.folder) }
                    .buttonStyle(SoftButtonStyle())
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([restored.folder]) }
                    .buttonStyle(SoftButtonStyle())
                if !hasLive {
                    Button("Put It in Place") { placeMessage = model.putRestoredInPlace(restored.folder, root: root) }
                        .buttonStyle(GoldButtonStyle())
                        .help("Moves it to \(AgentGuide.abbreviate(liveGraph.path)) and opens it")
                }
            }
            Text(hasLive
                 ? "Your graph in use is still at \(AgentGuide.abbreviate(liveGraph.path)). To switch, move that folder aside yourself and put this one in its place. Opening it here is only for looking: Graphitree won't rebuild a graph that isn't at its root."
                 : "Nothing is at \(AgentGuide.abbreviate(liveGraph.path)) yet, so Put It in Place moves it there. The next rebuild reads code again for free and reuses the saved AI work.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            if let placeMessage {
                Text(placeMessage).font(.caption).foregroundStyle(Palette.coral)
            }
        }
        .modifier(RowCard())
    }

    private func setUp() {
        guard sources.isEmpty else { return }
        sources = BackupRestore.sources(plans: plans)
        picked = Set(sources.map(\.id))
        root = model.graphRoot
        login = logins.first ?? ""
    }

    private func addRepo() {
        var name = repo.trimmingCharacters(in: .whitespaces)
        // A pasted "owner/repo" or URL works too.
        if let url = URL(string: name), url.host == "github.com" { name = url.path }
        let parts = name.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        let owner = parts.count >= 2 ? parts[parts.count - 2] : login
        let repoName = (parts.last ?? "").replacingOccurrences(of: ".git", with: "")
        guard !repoName.isEmpty, !owner.isEmpty else { return }
        var source = BackupRestore.Source.github(login: owner, repo: repoName)
        source.login = logins.contains(owner) ? owner : login
        if !sources.contains(where: { $0.id == source.id }) { sources.append(source) }
        picked.insert(source.id)
        repo = ""
    }

    private func restore() async {
        failure = nil
        restored = nil
        placeMessage = nil
        let path = (root as NSString).expandingTildeInPath
        switch await model.restore(chosen, root: path) {
        case .success(let result): restored = result
        case .failure(let error): failure = error.message
        }
    }
}

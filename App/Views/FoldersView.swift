import AppKit
import SwiftUI

/// Folders: what's in the graph and where it lives. Browse every node and each repo's pointer for
/// cloud agents, arrange projects into areas and graphs with the person's own labels, back each
/// graph up, and tidy up what's on disk.
struct FoldersView: View {
    @Environment(AppModel.self) private var model
    let openBuild: () -> Void

    init(openBuild: @escaping () -> Void, start: FoldersTab? = nil) {
        self.openBuild = openBuild
        // `-foldersTab backup` opens a tab at launch, for screenshots. Otherwise a link picks the
        // tab, and the rail opens Folders where it was last left.
        let defaults = UserDefaults.standard
        let launchTab = defaults.string(forKey: "foldersTab").flatMap(FoldersTab.init(rawValue:))
        let lastTab = defaults.string(forKey: Self.lastTabKey).flatMap(FoldersTab.init(rawValue:))
        _tab = State(initialValue: launchTab ?? start ?? lastTab ?? .browse)
        // `-browsePointers YES` opens Browse on the repos' pointers, for screenshots.
        _showsPointers = State(initialValue: defaults.bool(forKey: "browsePointers"))
    }

    private static let lastTabKey = "foldersLastTab"

    @State private var tab: FoldersTab
    @State private var browseQuery = ""
    @State private var showsBrowseDetails = true
    @State private var showsPointers: Bool

    private var root: String { model.graphRoot }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Folders", subtitle: subtitle) {
                if tab == .browse {
                    if !showsPointers { browseSearch }
                    Button { showsPointers.toggle() } label: {
                        Label("Pointers", systemImage: "doc.badge.gearshape").padding(.horizontal, 8)
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(ChromeButtonStyle(isOn: showsPointers))
                    .help("Pointers for cloud agents: put your playbook in each repo's AGENTS.md")
                    Button("Details", systemImage: "sidebar.right") { showsBrowseDetails.toggle() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(ChromeButtonStyle(isOn: showsBrowseDetails))
                        .keyboardShortcut("i")
                        .help("Show details (⌘I)")
                } else {
                    Button("Show in Finder", systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: root)])
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(ChromeButtonStyle())
                    .help("Show \(AgentGuide.abbreviate(root)) in Finder")
                }
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            Picker("Section", selection: $tab) {
                ForEach(FoldersTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            switch tab {
            case .browse:
                BrowseView(query: $browseQuery, showsInspector: $showsBrowseDetails, showsPointers: $showsPointers)
                    .id(model.outDirectory)
            case .arrange:
                ArrangeView(openBuild: openBuild, openBackup: { tab = .backup }, openTidy: { tab = .tidy })
            case .backup:
                BackupView(openArrange: { tab = .arrange })
            case .tidy:
                TidyView(openBuild: openBuild)
            }
        }
        .onChange(of: tab) { UserDefaults.standard.set(tab.rawValue, forKey: Self.lastTabKey) }
    }

    private var subtitle: String {
        switch tab {
        case .browse:
            return showsPointers ? "Pointers that put your playbook in each repo, for cloud agents" : "Every node in the graph, project by project"
        case .arrange:
            return "What each folder under \(AgentGuide.abbreviate(root)) is for, and which graph it's in"
        case .backup:
            return "Where each graph is backed up"
        case .tidy:
            return "What to keep and what can go under \(AgentGuide.abbreviate(root))"
        }
    }

    private var browseSearch: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search labels and paths", text: $browseQuery)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 9)
        .frame(width: 260, height: 28)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// A row per main folder: what it's for, a note for AI tools, whether it stays in the graph.
struct FolderLabelsEditor: View {
    @Binding var labels: [FolderLabel]
    let scan: FolderScanResult
    /// The person's labels to pick from.
    var kinds: [FolderPurpose] = FolderPurpose.defaults

    var body: some View {
        VStack(spacing: 0) {
            ForEach($labels) { $label in
                row($label)
                if label.id != labels.last?.id {
                    Rectangle().fill(Palette.hairline).frame(height: 1)
                }
            }
        }
        .modifier(RowCard())
    }

    private func info(_ path: String) -> FolderInfo? { scan.folders.first { $0.path == path } }

    private func row(_ label: Binding<FolderLabel>) -> some View {
        let folder = info(label.wrappedValue.path)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: label.wrappedValue.purpose.symbol)
                .foregroundStyle(label.wrappedValue.isIncluded ? Palette.gold : .secondary)
                .frame(width: 20)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(label.wrappedValue.path + "/").font(.body.weight(.medium)).lineLimit(1)
                    if let folder { Text(kind(folder)).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    Spacer(minLength: 8)
                    Picker("Purpose", selection: Binding(
                        get: { label.wrappedValue.purpose },
                        set: { purpose in
                            label.wrappedValue.purpose = purpose
                            label.wrappedValue.isIncluded = !purpose.isLeftOutByDefault
                        }
                    )) {
                        ForEach(kinds) { purpose in
                            Label(purpose.title, systemImage: purpose.symbol).tag(purpose)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .help(label.wrappedValue.purpose.detail)
                    Toggle("In graph", isOn: label.isIncluded)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .help(label.wrappedValue.isIncluded ? "graphify reads this folder" : "Left out of the graph")
                }
                TextField("What's it for? AI tools read this in the guide.", text: label.note)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                if folder?.looksLikeGroup == true || label.wrappedValue.holdsProjects {
                    Toggle("Each subfolder is a project", isOn: label.holdsProjects)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 9)
        .opacity(label.wrappedValue.isIncluded ? 1 : 0.7)
    }

    private func kind(_ folder: FolderInfo) -> String {
        var parts: [String] = []
        if let repo = folder.repo {
            parts.append(repo.hasOwnCommits == false ? "repo, no commits from you" : "repo")
        } else if !folder.children.isEmpty {
            parts.append("\(folder.children.count) repo\(folder.children.count == 1 ? "" : "s")")
        } else {
            parts.append("folder")
        }
        if let active = folder.lastActive {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            parts.append("active \(formatter.localizedString(for: active, relativeTo: .now))")
        }
        return parts.joined(separator: " · ")
    }
}

enum FoldersTab: String, CaseIterable, Identifiable {
    case browse, arrange, backup, tidy

    var id: String { rawValue }
    var title: String {
        switch self {
        case .browse: return "Browse"
        case .arrange: return "Arrange"
        case .backup: return "Back Up"
        case .tidy: return "Tidy Up"
        }
    }
}

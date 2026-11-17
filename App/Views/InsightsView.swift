import SwiftUI

/// What the last month shows: what AI tools asked the graph and Graphitree, what came back empty,
/// jobs with no pick, and packages in use that the playbook doesn't mention. Read on this Mac only.
struct InsightsView: View {
    @Environment(AppModel.self) private var model
    let openPlaybook: () -> Void

    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Insights", subtitle: "What AI tools asked in the last \(AppModel.insightDays) days")
            Rectangle().fill(Palette.hairline).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let message {
                        Text(message).font(.caption).foregroundStyle(Palette.gold).fixedSize(horizontal: false, vertical: true)
                    }
                    if let insights = model.insights {
                        tiles(insights)
                        missingPicks(insights)
                        emptyQuestions(insights)
                        projects(insights)
                        packages(insights)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Reading the last \(AppModel.insightDays) days of Claude Code sessions…").foregroundStyle(.secondary)
                        }
                    }
                    learnCard
                    privacyCard
                }
                .padding(18)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task { await model.loadInsights() }
    }

    private func tiles(_ insights: UsageInsights) -> some View {
        HStack(spacing: 8) {
            tile("Graph questions", "\(insights.questions)", "in \(insights.sessions) session\(insights.sessions == 1 ? "" : "s")")
            tile("Found nothing", "\(insights.emptyQuestions.count)", "different questions")
            tile("Picks asked", "\(insights.picksAsked)", "through graphitree and MCP")
            tile("Jobs with no pick", "\(insights.missingPicks.count)", insights.missingPicks.isEmpty ? "none" : "worth adding")
        }
    }

    private func tile(_ title: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Palette.gold.opacity(0.9))
            Text(value).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(RowCard())
    }

    private func section<Content: View>(_ title: String, _ detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 0) { content() }.modifier(RowCard())
        }
    }

    @ViewBuilder
    private func missingPicks(_ insights: UsageInsights) -> some View {
        if !insights.missingPicks.isEmpty {
            section("Jobs with no pick", "AI tools asked for these and your playbook had nothing, so they chose on their own.") {
                ForEach(insights.missingPicks, id: \.name) { job in
                    HStack {
                        Text(job.name).font(.callout)
                        Text("asked \(job.count) time\(job.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Ask the Chat") {
                            model.sendChat("Suggest a library for \(job.name) that fits my stack, and add it if I agree.", playbook: model.loadPlaybook(), scan: nil)
                            openPlaybook()
                        }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(model.isChatting)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    @ViewBuilder
    private func emptyQuestions(_ insights: UsageInsights) -> some View {
        if !insights.emptyQuestions.isEmpty {
            section("Questions that found nothing", "The graph may be missing what these ask about: check what Folders leaves out, or read docs in Build.") {
                ForEach(insights.emptyQuestions, id: \.self) { question in
                    Text("“\(question)”").font(.callout).padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private func projects(_ insights: UsageInsights) -> some View {
        if !insights.projects.isEmpty {
            let most = insights.projects.map(\.count).max() ?? 1
            section("Asked about most", "Where AI tools leaned on the graph. Projects missing here may not need it, or may not know about it.") {
                ForEach(insights.projects, id: \.name) { project in
                    HStack(spacing: 10) {
                        Text(project.name).font(.callout).frame(width: 220, alignment: .leading).lineLimit(1)
                        GeometryReader { proxy in
                            Capsule().fill(Palette.gold.opacity(0.7))
                                .frame(width: max(4, proxy.size.width * CGFloat(project.count) / CGFloat(most)), height: 6)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 14)
                        Text("\(project.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 30, alignment: .trailing)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    @ViewBuilder
    private func packages(_ insights: UsageInsights) -> some View {
        if !insights.unlistedPackages.isEmpty {
            section("Installed, but not in your playbook", "Packages your sessions added to projects. Add the ones you'd pick again, then draft their details in Playbook.") {
                FlowLayout(spacing: 6) {
                    ForEach(insights.unlistedPackages, id: \.name) { package in
                        Button { add(package.name) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus").font(.caption2)
                                Text(package.name).font(.caption)
                                if package.count > 1 {
                                    Text("\(package.count)").font(.caption2.weight(.bold)).foregroundStyle(Palette.jade)
                                }
                            }
                        }
                        .buttonStyle(ChipStyle(isOn: false))
                        .help("Used in \(package.count) folder\(package.count == 1 ? "" : "s"). Adds it to the playbook as a library to describe.")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var learnCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.text.rectangle").foregroundStyle(Palette.gold).font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text("Learn how you work").font(.body.weight(.semibold))
                Text("The Playbook chat can read your own messages from the last \(AppModel.insightDays) days of sessions and suggest How You Work notes and picks. You see the cost first, and nothing is saved until you apply it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Open in Chat") {
                model.wantsSessionLearning = true
                openPlaybook()
            }
            .buttonStyle(SoftButtonStyle())
        }
        .modifier(RowCard())
    }

    private var privacyCard: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $model.logsUsage) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep a log of what AI tools ask Graphitree")
                    Text("Questions to the graphitree command and Graphitree's MCP server, kept only on this Mac in ~/Library/Application Support/Graphitree/usage.jsonl. Sessions are read from ~/.claude/projects and stay on this Mac too.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Spacer()
                Button("Clear Log") {
                    model.clearUsageLog()
                    message = "Graphitree's log is cleared. Session files belong to Claude Code and are left alone."
                }
                .buttonStyle(SoftButtonStyle())
            }
        }
        .modifier(RowCard())
    }

    private func add(_ package: String) {
        var playbook = model.loadPlaybook()
        let before = playbook.libraries.count
        playbook.libraries = PlaybookImport.merging([PlaybookLibrary(name: package)], into: playbook.libraries)
        guard playbook.libraries.count > before else {
            message = "\(package) is already in the playbook."
            return
        }
        if let failure = model.savePlaybook(playbook) {
            message = "Couldn't add \(package): \(failure)"
        } else {
            message = "Added \(package) to the playbook. Draft its details in Playbook's Libraries tab."
            Task { await model.loadInsights() }
        }
    }
}

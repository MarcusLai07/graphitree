import SwiftUI

// The Playbook's Skills and Starters tabs: skills new repos get, and the repos that can get a
// starter, with what each seeded repo did with its starter since.

// MARK: - Skills

struct PlaybookSkillsTab: View {
    @Environment(AppModel.self) private var model
    let playbook: Playbook
    let edit: ((inout Playbook) -> Void) -> Void

    @State private var expanded: UUID?
    @State private var found: [Seeds.FoundSkill] = []
    @State private var includesShared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(summary).font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Add Skill", systemImage: "plus") {
                    let skill = PlaybookSkill(name: "")
                    edit { $0.skills.append(skill) }
                    expanded = skill.id
                }
            }
            ForEach(playbook.skills) { skill in
                card(skill).modifier(RowCard())
            }
            foundSection
        }
        .task { found = model.foundSkills() }
    }

    private var summary: String {
        guard !playbook.skills.isEmpty else { return "No skills yet." }
        let ready = playbook.skills.filter(\.isReady).count
        return "\(playbook.skills.count) skill\(playbook.skills.count == 1 ? "" : "s"), \(ready) ready for new repos"
    }

    // MARK: A skill

    @ViewBuilder
    private func card(_ skill: PlaybookSkill) -> some View {
        let isOpen = expanded == skill.id
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { expanded = isOpen ? nil : skill.id }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right").font(.caption).foregroundStyle(.secondary).frame(width: 10)
                    Text(skill.name.isEmpty ? "Untitled skill" : skill.name).font(.body.weight(.semibold).monospaced())
                    if skill.drafted { mark("draft") }
                    if skill.claudeOnly { mark("Claude Code only") }
                    if skill.reach != .everywhere { mark(skill.reach == .personal ? "personal only" : "named repos") }
                    if !skill.problems.isEmpty { mark("not ready") }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !isOpen, !skill.description.isEmpty {
                Text(skill.description).font(.caption).foregroundStyle(.secondary).lineLimit(2).padding(.leading, 18)
            }
            if isOpen { editor(skill).padding(.leading, 18) }
        }
    }

    private func mark(_ text: String) -> some View {
        Text(text).font(.caption2.weight(.medium)).padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.white.opacity(0.08), in: Capsule()).foregroundStyle(Palette.gold)
    }

    @ViewBuilder
    private func editor(_ skill: PlaybookSkill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            labelled("Name", detail: "Also its folder: lowercase letters, digits and hyphens.") {
                TextField("release-notes", text: binding(skill.id, \.name)).textFieldStyle(.roundedBorder).font(.body.monospaced())
            }
            labelled("Description", detail: "What it does and when to use it. Tools read this to decide whether to load it.") {
                TextField("Writes release notes from the commits since the last tag. Use when preparing a release.", text: binding(skill.id, \.description), axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(2...5)
            }
            labelled("Instructions", detail: "The rest of SKILL.md, in markdown.") {
                TextEditor(text: binding(skill.id, \.body))
                    .font(.callout.monospaced())
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140, maxHeight: 320)
                    .padding(6)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
            HStack(spacing: 12) {
                Picker("Goes to", selection: binding(skill.id, \.reach)) {
                    ForEach(PlaybookSkill.Reach.allCases) { Text($0.title).tag($0) }
                }
                .frame(width: 260)
                Toggle("Claude Code only", isOn: binding(skill.id, \.claudeOnly))
                    .help("Written for Claude Code alone, so it goes in .claude/skills/ where other tools don't look")
            }
            if skill.reach == .repos {
                TextField("Projects, such as personal/kiln, personal/ledger", text: Binding(
                    get: { skill.repos.joined(separator: ", ") },
                    set: { value in update(skill.id) { $0.repos = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } } }
                ))
                .textFieldStyle(.roundedBorder)
            }
            filesEditor(skill)
            if !skill.source.isEmpty {
                Text("Adopted from \(skill.source).").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(skill.problems, id: \.self) { problem in
                Label(problem, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(Palette.gold)
            }
            HStack {
                if skill.drafted {
                    Text("Written by AI or copied from a repo. Check it reads as a generic skill, then mark it checked: drafts don't go into repos.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Mark Checked") { update(skill.id) { $0.drafted = false } }.disabled(!skill.problems.isEmpty)
                }
                Spacer()
                Button("Remove", systemImage: "trash", role: .destructive) {
                    edit { $0.skills.removeAll { $0.id == skill.id } }
                }
            }
        }
    }

    private func filesEditor(_ skill: PlaybookSkill) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Other files").font(.caption.weight(.semibold))
                Text("Scripts or references the instructions point to.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Add File") { update(skill.id) { $0.files.append(SkillFile(path: "", text: "")) } }.controlSize(.small)
            }
            ForEach(Array(skill.files.enumerated()), id: \.offset) { index, _ in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("scripts/check.sh", text: Binding(
                            get: { playbook.skills.first { $0.id == skill.id }?.files[safe: index]?.path ?? "" },
                            set: { value in update(skill.id) { if $0.files.indices.contains(index) { $0.files[index].path = value } } }
                        ))
                        .textFieldStyle(.roundedBorder).font(.caption.monospaced())
                        Button("Remove File", systemImage: "minus.circle") { update(skill.id) { if $0.files.indices.contains(index) { $0.files.remove(at: index) } } }
                            .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    TextEditor(text: Binding(
                        get: { playbook.skills.first { $0.id == skill.id }?.files[safe: index]?.text ?? "" },
                        set: { value in update(skill.id) { if $0.files.indices.contains(index) { $0.files[index].text = value } } }
                    ))
                    .font(.caption.monospaced())
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60, maxHeight: 160)
                    .padding(4)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func labelled(_ title: String, detail: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            content()
        }
    }

    private func binding<Value>(_ id: UUID, _ path: WritableKeyPath<PlaybookSkill, Value>) -> Binding<Value> {
        Binding(
            get: { playbook.skills.first { $0.id == id }?[keyPath: path] ?? PlaybookSkill(name: "")[keyPath: path] },
            set: { value in update(id) { $0[keyPath: path] = value } }
        )
    }

    private func update(_ id: UUID, _ change: @escaping (inout PlaybookSkill) -> Void) {
        edit { book in
            if let index = book.skills.firstIndex(where: { $0.id == id }) { change(&book.skills[index]) }
        }
    }

    // MARK: Found in the repos

    @ViewBuilder
    private var foundSection: some View {
        let known = Set(playbook.skills.map(\.name))
        let own = found.filter { !$0.isShared }
        let shared = found.filter(\.isShared)
        if !found.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("In your repos")
                    .font(.caption.weight(.semibold)).tracking(0.8).textCase(.uppercase).foregroundStyle(Palette.gold.opacity(0.85))
                Text("Skills your repos wrote for themselves. Adopting one adds a draft to check before it goes anywhere.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(own) { foundRow($0, isKnown: known.contains($0.name)) }
                if !shared.isEmpty {
                    Toggle("Include \(shared.count) from shared folders, for a review of the whole graph", isOn: $includesShared)
                        .font(.caption)
                    if includesShared {
                        Text("Only the name comes over: write a generic version before it can go into a repo.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(shared) { foundRow($0, isKnown: known.contains($0.name)) }
                    }
                }
            }
            .modifier(RowCard())
        }
    }

    private func foundRow(_ skill: Seeds.FoundSkill, isKnown: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(skill.name).font(.callout.monospaced())
                    Text(skill.project).font(.caption).foregroundStyle(.secondary)
                    if skill.isShared { mark("shared folder") }
                }
                if !skill.description.isEmpty, !skill.isShared {
                    Text(skill.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            Button(isKnown ? "In Playbook" : "Adopt") {
                let draft = Seeds.adopt(skill)
                edit { $0.skills.append(draft) }
                expanded = draft.id
            }
            .disabled(isKnown)
            .controlSize(.small)
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: - Starters

struct PlaybookStartersTab: View {
    @Environment(AppModel.self) private var model
    /// Changes when the playbook does, so previews are built from what's saved.
    let playbookRevision: Int
    /// Told how many repos can get a starter, after each look.
    var offersChanged: (Int) -> Void = { _ in }

    @State private var survey = Seeds.Survey()
    @State private var isLoaded = false
    @State private var previewing: Seeds.Repo?
    @State private var opened: String?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let message {
                Text(message).font(.caption).foregroundStyle(Palette.gold).fixedSize(horizontal: false, vertical: true)
            }
            if !isLoaded {
                ProgressView().controlSize(.small)
            } else if survey.repos.isEmpty && survey.shared.isEmpty {
                Text("Starters are for a knowledge base of several repos with folder labels. Label the main folders in Folders first.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                group("Can get a starter", detail: "No instructions or skills of their own yet.", repos: survey.offers) { offerRow($0) }
                group("Seeded", detail: "Graphitree wrote their starter once and won't touch it again.", repos: seeded) { seededRow($0) }
                group("Their own setup", detail: "Left alone.", repos: own) { ownRow($0) }
                group("Skipped", detail: "", repos: skipped) { skippedRow($0) }
                footer
            }
        }
        .task(id: playbookRevision) { reload() }
        .sheet(item: $previewing) { repo in
            StarterPreview(repo: repo, items: model.starter(for: repo)) { items in
                previewing = nil
                write(repo, items: items)
            } cancel: {
                previewing = nil
            }
        }
    }

    private var seeded: [Seeds.Repo] { survey.repos.filter { if case .seeded = $0.state { return true } else { return false } } }
    private var own: [Seeds.Repo] { survey.repos.filter { if case .ownSetup = $0.state { return true } else { return false } } }
    private var skipped: [Seeds.Repo] { survey.repos.filter { $0.state == .skipped } }

    private func reload() {
        survey = model.starterSurvey()
        offersChanged(survey.offers.count)
        isLoaded = true
    }

    private func write(_ repo: Seeds.Repo, items: [Seeds.Item]) {
        switch model.seed(repo, items: items) {
        case .success(let result):
            var parts = ["Wrote \(result.written.count) file\(result.written.count == 1 ? "" : "s") in \(repo.path)"]
            if !result.linked.isEmpty { parts.append("linked \(result.linked.count) skill\(result.linked.count == 1 ? "" : "s") for Claude Code") }
            if !result.left.isEmpty { parts.append("left \(result.left.count) that were already there") }
            message = parts.joined(separator: ", ") + ". Nothing is committed."
        case .failure(let error):
            message = "Couldn't write the starter: \(error.localizedDescription)"
        }
        reload()
    }

    @ViewBuilder
    private func group(_ title: String, detail: String, repos: [Seeds.Repo], row: @escaping (Seeds.Repo) -> some View) -> some View {
        if !repos.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.caption.weight(.semibold)).tracking(0.8).textCase(.uppercase).foregroundStyle(Palette.gold.opacity(0.85))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(repos) { row($0) }
            }
            .modifier(RowCard())
        }
    }

    private func offerRow(_ repo: Seeds.Repo) -> some View {
        HStack(spacing: 8) {
            Text(repo.path).font(.callout.monospaced())
            if repo.isNew {
                Text("New")
                    .help("Made in the last two weeks").font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 2).background(Palette.gold, in: Capsule()).foregroundStyle(.black)
            }
            Spacer()
            Button("Skip") { message = model.setStarterSkipped(repo.path, true) }.controlSize(.small)
            Button("Preview…") { previewing = repo }.controlSize(.small)
        }
    }

    @ViewBuilder
    private func seededRow(_ repo: Seeds.Repo) -> some View {
        let isOpen = opened == repo.path
        VStack(alignment: .leading, spacing: 6) {
            Button {
                opened = isOpen ? nil : repo.path
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right").font(.caption).foregroundStyle(.secondary).frame(width: 10)
                    Text(repo.path).font(.callout.monospaced())
                    if case .seeded(let record) = repo.state {
                        Text(PlaybookFile.day(record.seededAt)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("What It Added").font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen { StarterChanges(statuses: model.starterStatus(of: repo.path)).padding(.leading, 18) }
        }
    }

    private func ownRow(_ repo: Seeds.Repo) -> some View {
        HStack(spacing: 8) {
            Text(repo.path).font(.callout.monospaced())
            Spacer()
            if case .ownSetup(let markers) = repo.state {
                Text(markers.prefix(3).joined(separator: ", ") + (markers.count > 3 ? " and \(markers.count - 3) more" : ""))
                    .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private func skippedRow(_ repo: Seeds.Repo) -> some View {
        HStack {
            Text(repo.path).font(.callout.monospaced())
            Spacer()
            Button("Offer Again") { message = model.setStarterSkipped(repo.path, false) }.controlSize(.small)
        }
    }

    @ViewBuilder
    private var footer: some View {
        let notes = [
            survey.shared.isEmpty ? nil : "\(survey.shared.count) repo\(survey.shared.count == 1 ? " is" : "s are") in shared folders (Work, Client): read into the knowledge base, never given a starter.",
            survey.unlabelled.isEmpty ? nil : "\(survey.unlabelled.count) repo\(survey.unlabelled.count == 1 ? " is" : "s are") in folders with no label yet. Label them in Folders to see them here.",
        ].compactMap { $0 }
        ForEach(notes, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
    }
}

/// What a seeded repo did with each file since.
struct StarterChanges: View {
    let statuses: [Seeds.FileStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if statuses.isEmpty { Text("Nothing on record.").font(.caption).foregroundStyle(.secondary) }
            ForEach(statuses) { file in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(file.path).font(.caption.monospaced())
                        Text(describe(file)).font(.caption).foregroundStyle(file.state == .changed ? Palette.gold : .secondary)
                    }
                    if !file.added.isEmpty {
                        Text(file.added.prefix(24).joined(separator: "\n") + (file.added.count > 24 ? "\n…and \(file.added.count - 24) more" : ""))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private func describe(_ file: Seeds.FileStatus) -> String {
        switch file.state {
        case .unchanged: return file.isLink ? "link as made" : "unchanged, so the graph leaves it out"
        case .gone: return file.isLink ? "link removed or changed" : "deleted"
        case .changed:
            var parts: [String] = []
            if !file.added.isEmpty { parts.append("\(file.added.count) line\(file.added.count == 1 ? "" : "s") added or reworded") }
            if file.removed > 0 { parts.append("\(file.removed) taken out") }
            return parts.isEmpty ? "changed" : parts.joined(separator: ", ")
        }
    }
}

/// Every file a starter would write, shown before anything is written.
private struct StarterPreview: View {
    let repo: Seeds.Repo
    let items: [Seeds.Item]
    let write: ([Seeds.Item]) -> Void
    let cancel: () -> Void

    @State private var shown: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Starter for \(repo.path)").font(.title3.weight(.semibold))
            Text("Written once and never changed by Graphitree again. Nothing that's already there is touched, and nothing is committed. If this repo is public, these files will be too once you commit them.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            List(items, selection: $shown) { item in
                HStack(spacing: 8) {
                    Image(systemName: icon(item)).foregroundStyle(item.isTaken ? Color.secondary : Palette.gold).frame(width: 16)
                    Text(item.path).font(.callout.monospaced())
                    Spacer()
                    Text(note(item)).font(.caption).foregroundStyle(.secondary)
                }
                .tag(item.path)
            }
            .frame(height: min(CGFloat(items.count) * 28 + 12, 200))
            ScrollView {
                Text(text(of: shown ?? items.first?.path))
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 220)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: cancel).keyboardShortcut(.cancelAction)
                Button("Write Starter") { write(items) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(items.allSatisfy(\.isTaken))
            }
        }
        .padding(20)
        .frame(width: 640, height: 600)
    }

    private func icon(_ item: Seeds.Item) -> String {
        if item.isTaken { return "minus.circle" }
        if case .link = item.kind { return "link" }
        return "doc.badge.plus"
    }

    private func note(_ item: Seeds.Item) -> String {
        if item.isTaken { return "already there, left alone" }
        if case .link(let target) = item.kind { return "link to \(target), for Claude Code" }
        return "new"
    }

    private func text(of path: String?) -> String {
        guard let item = items.first(where: { $0.path == path }) else { return "" }
        switch item.kind {
        case .file(let text): return text
        case .link(let target): return "A link to \(target), so Claude Code, which doesn't read .agents/skills yet, sees the same skill."
        }
    }
}

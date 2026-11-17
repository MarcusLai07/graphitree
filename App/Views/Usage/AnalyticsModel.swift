import Foundation
import SwiftUI

/// One provider's calls on this Mac, scanned from its tool's logs, and the sums the Usage page
/// draws from them.
@MainActor
final class AnalyticsModel: ObservableObject {
    /// One per provider for the app: what was scanned stays when the Usage panel closes, so
    /// reopening it shows the last scan at once and only rescans when that's over a minute old.
    static let claude = AnalyticsModel(.claude)
    static let codex = AnalyticsModel(.codex)

    static func of(_ provider: UsageProvider) -> AnalyticsModel {
        provider == .claude ? claude : codex
    }

    let provider: UsageProvider

    /// Every request in the local transcripts, oldest first.
    @Published private(set) var tokenSamples: [TokenSample] = []
    /// Whether the tool has left any logs on this Mac.
    @Published private(set) var hasLogs: Bool
    @Published private(set) var isLoading = false
    @Published private(set) var lastLoaded: Date?
    /// Stable model → chart color assignment, by all-time share.
    @Published private(set) var modelColors: [String: Color] = [:]
    /// Session id → title, from the transcripts' title lines.
    @Published private(set) var sessionTitles: [String: String] = [:]
    /// Claude Code's auto-compact window setting, when set.
    @Published private(set) var compactSetting: Int?

    /// Codex only: the plan's limits as Codex last logged them, every reading of them, the plan's
    /// name, and compressed logs that couldn't be read.
    @Published private(set) var limits: UsageSnapshot?
    @Published private(set) var limitHistory: [UsageSample] = []
    @Published private(set) var plan: String?
    @Published private(set) var unreadCompressed = 0

    private init(_ provider: UsageProvider) {
        self.provider = provider
        hasLogs = Self.logsExist(provider)
    }

    private nonisolated static func logsExist(_ provider: UsageProvider) -> Bool {
        switch provider {
        case .claude: return FileManager.default.fileExists(atPath: TranscriptStats.claudeFolder.appendingPathComponent("projects").path)
        case .codex: return CodexSessions.hasSessions()
        }
    }

    private var overviews: [String: (at: Date, overview: UsageOverview)] = [:]
    private var sessionLists: [String: (at: Date, projects: [ProjectSessions])] = [:]

    /// Rescans, unless the last scan is younger than `maxAge`. Claude: Claude Code's transcripts
    /// and Claude Desktop's local-agent sessions. Codex: its session logs, limits and all.
    /// Graphitree isn't sandboxed, so logs are read in place; nothing is copied or uploaded.
    func reload(maxAge: TimeInterval = 0) async {
        guard !isLoading else { return }
        if let lastLoaded, Date().timeIntervalSince(lastLoaded) < maxAge { return }
        isLoading = true
        defer { isLoading = false }

        hasLogs = Self.logsExist(provider)
        guard hasLogs else {
            lastLoaded = Date()
            return
        }
        switch provider {
        case .claude: await reloadClaude()
        case .codex: await reloadCodex()
        }
    }

    private func reloadCodex() async {
        let scan = await Task.detached(priority: .userInitiated) {
            CodexSessions.scan(since: .distantPast)
        }.value
        limits = scan.latest
        limitHistory = scan.limits
        plan = scan.plan
        unreadCompressed = scan.unreadCompressed
        apply(TranscriptScan(samples: scan.samples, titles: scan.titles))
    }

    private func reloadClaude() async {
        let folder = TranscriptStats.claudeFolder
        let desktop = TranscriptStats.desktopFolder
        let hasDesktop = FileManager.default.fileExists(atPath: desktop.path)
        let scan = await Task.detached(priority: .userInitiated) {
            var scan = TranscriptStats.scan(claudeFolder: folder, desktopFolder: hasDesktop ? desktop : nil, since: .distantPast)
            scan.samples.sort { $0.ts < $1.ts }
            return (scan, ContextTuning.compactSetting(claudeFolder: folder))
        }.value
        compactSetting = scan.1
        apply(scan.0)
    }

    /// Takes in a scan's requests (sorted oldest first) and session titles.
    func apply(_ scan: TranscriptScan) {
        tokenSamples = UsageSummary.fileBySessionFolder(scan.samples)
        sessionTitles = scan.titles
        overviews = [:]
        sessionLists = [:]
        var byModel: [String: Int] = [:]
        for sample in scan.samples where !sample.failed { byModel[sample.model, default: 0] += sample.tokens }
        let ordered = byModel.sorted { $0.value > $1.value }.map(\.key)
        modelColors = Dictionary(uniqueKeysWithValues: ordered.enumerated().map {
            ($0.element, modelPalette[$0.offset % modelPalette.count])
        })
        lastLoaded = Date()
    }

    /// The period's summary, reused for a minute (views ask on every draw).
    func overview(_ period: UsagePeriod) -> UsageOverview {
        let now = Date()
        if let cached = overviews[period.cacheKey], now.timeIntervalSince(cached.at) < 60 {
            return cached.overview
        }
        let overview = UsageSummary.summarize(tokenSamples, period: period, now: now)
        overviews[period.cacheKey] = (now, overview)
        return overview
    }

    /// Requests in a period, newest first (the Requests tab).
    func samples(in period: UsagePeriod) -> [TokenSample] {
        let range = period.range()
        return tokenSamples.reversed()
            .drop { $0.ts > range.upperBound }
            .prefix { $0.ts >= range.lowerBound }
            .map { $0 }
    }

    /// Sessions active in the period, grouped by project; both ordered by
    /// latest activity. Reused for a minute.
    func sessions(_ period: UsagePeriod) -> [ProjectSessions] {
        let now = Date()
        if let cached = sessionLists[period.cacheKey], now.timeIntervalSince(cached.at) < 60 {
            return cached.projects
        }
        let projects = UsageSummary.groupSessions(tokenSamples, titles: sessionTitles, range: period.range(now: now))
        sessionLists[period.cacheKey] = (now, projects)
        return projects
    }
}

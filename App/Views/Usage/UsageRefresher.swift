import Foundation
import SwiftUI

/// Reads the plan's limits every five minutes while Graphitree is open and records each reading,
/// so the Usage page can chart what was left over time. Ported from Claude Usage, without its
/// widgets and notifications.
///
/// It doesn't start on its own at first: the first reading asks for Claude Code's sign-in from the
/// keychain, which shows macOS's prompt, so that waits until the Usage page is opened. Once a
/// reading has worked, later launches start it straight away.
@MainActor
final class UsageRefresher: ObservableObject {
    /// One per app, so the history keeps going while the page is closed.
    static let shared = UsageRefresher()

    /// The last reading, as Anthropic sent it.
    @Published private(set) var reading: UsageSnapshot? = ClaudeUsageStore.cachedSnapshot
    /// When a reading was last tried, worked or not. Publishing it every five minutes redraws
    /// what shows `snapshot`, so a window that resets while readings fail drops to 0%.
    @Published private(set) var lastAttempt: Date?
    @Published private(set) var profile: AccountProfile? = ClaudeUsageStore.accountProfile
    /// Why the last reading failed. Cleared by the next one that works.
    @Published private(set) var lastError: UsageAPIError?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isRunning = false

    /// The last reading as it stands now: windows that have reset since read 0%. Everything
    /// that shows a figure uses this, never `reading`.
    var snapshot: UsageSnapshot? { reading?.asOf(Date()) }

    /// The last reading failed and an older one is showing.
    var isStale: Bool { lastError != nil && snapshot != nil }

    static let refreshInterval: TimeInterval = 5 * 60
    /// Plan and email rarely change; read them twice a day.
    static let profileMaxAge: TimeInterval = 12 * 3600

    private var timer: Timer?
    private var lastProfileAttempt: Date?

    /// The screenshot tool turns this off: it shows the last stored reading and never asks the
    /// keychain or Anthropic.
    static var readsLimits = true

    private init() {}

    /// Starts the five-minute readings, at once. Calling it again does nothing.
    func start() {
        guard !isRunning, Self.readsLimits else { return }
        isRunning = true
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Task { await refresh() }
    }

    /// Stops the readings, so nothing is written while Graphitree uninstalls itself.
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// Starts at launch only when an earlier reading worked, so a new install never shows the
    /// keychain prompt before the Usage page is opened.
    func startIfEnabled() {
        if ClaudeUsageStore.isEnabled { start() }
    }

    /// `force` is for the refresh button: it shrinks the freshness window to seconds, but still
    /// joins a request that's already out instead of sending another (the endpoint answers 429).
    func refresh(force: Bool = false) async {
        isRefreshing = true
        defer {
            isRefreshing = false
            lastAttempt = Date()
        }
        do {
            let fresh = try await UsageFetcher.shared.fetch(maxAge: force ? 5 : 60)
            reading = fresh
            lastError = nil
            ClaudeUsageStore.cachedSnapshot = fresh
            ClaudeUsageStore.isEnabled = true
            UsageHistory.append(fresh)
            await refreshProfileIfNeeded()
        } catch {
            lastError = UsageAPIError.from(error)
        }
    }

    /// Reads the plan and email after a reading works (the token is good then). A failure only
    /// costs the plan badge; it tries again an hour later.
    private func refreshProfileIfNeeded() async {
        if let profile, Date().timeIntervalSince(profile.fetchedAt) < Self.profileMaxAge { return }
        if let lastProfileAttempt, Date().timeIntervalSince(lastProfileAttempt) < 3600 { return }
        lastProfileAttempt = Date()
        guard let fetched = try? await UsageAPI.fetchProfile() else { return }
        profile = fetched
        ClaudeUsageStore.accountProfile = fetched
    }

    /// Asks the keychain again, after the prompt was turned down.
    func retrySignIn() async {
        await UsageAPI.TokenCache.shared.forget()
        await refresh(force: true)
    }
}

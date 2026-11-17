import Foundation

/// Every plan reading goes through here. The endpoint answers HTTP 429 under bursts, so:
///
/// 1. A reading younger than `maxAge` is served from the store without asking again.
/// 2. Callers that arrive while a request is out share it.
actor UsageFetcher {
    static let shared = UsageFetcher()

    private var inFlight: Task<UsageSnapshot, Error>?

    func fetch(maxAge: TimeInterval) async throws -> UsageSnapshot {
        if let cached = ClaudeUsageStore.cachedSnapshot,
           Date().timeIntervalSince(cached.fetchedAt) < maxAge {
            return cached
        }
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task { try await UsageAPI.fetchUsage() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}

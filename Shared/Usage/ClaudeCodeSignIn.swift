import Foundation
import Security

/// Claude Code's own sign-in, borrowed to ask Anthropic for the plan's limits. Claude Code keeps it
/// in the login keychain as "Claude Code-credentials". Graphitree only reads it: it never refreshes
/// or rewrites it, so it can't sign Claude Code out. When the borrowed token runs out, Claude Code
/// renews it the next time it runs, and the next refresh here picks the new one up.
///
/// The first read shows macOS's keychain prompt. "Always Allow" lets later reads go through quietly.
enum ClaudeCodeSignIn {
    struct Token: Equatable {
        let accessToken: String
        let expiresAt: Date?

        /// Within a minute of running out counts as run out: a request would race it.
        func isExpired(now: Date = Date()) -> Bool {
            guard let expiresAt else { return false }
            return expiresAt.timeIntervalSince(now) < 60
        }
    }

    enum Failure: Error, Equatable {
        /// Claude Code has never signed in on this Mac, or signed out.
        case notSignedIn
        /// The keychain prompt was turned down, or couldn't be shown.
        case denied
        /// The item is there but isn't in the shape Claude Code writes.
        case unreadable
    }

    static let service = "Claude Code-credentials"
    /// Claude Code's id in AI Models, whose health check says whether it's signed in.
    static let connectionID = UsageProvider.claude.connectionID

    private static let queue = DispatchQueue(label: "com.marcuslai.Graphitree.claude-sign-in")

    /// `read()` on a thread of its own. The first read waits for macOS's keychain prompt, which
    /// can stay open for minutes; on Swift's shared threads that wait would hold up other work.
    static func readInBackground() async -> Result<Token, Failure> {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: read()) }
        }
    }

    /// Reads the token now, waiting for the keychain prompt if macOS shows one. Callers keep the
    /// token while it's good, so the keychain is read once per token, not once per refresh.
    static func read() -> Result<Token, Failure> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return .failure(.unreadable) }
            return decode(data)
        case errSecItemNotFound:
            return .failure(.notSignedIn)
        case errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed:
            return .failure(.denied)
        default:
            return .failure(.unreadable)
        }
    }

    /// The keychain item's JSON: `{"claudeAiOauth": {"accessToken", "refreshToken", "expiresAt"}}`,
    /// with `expiresAt` in milliseconds.
    static func decode(_ data: Data) -> Result<Token, Failure> {
        struct Credentials: Decodable {
            struct OAuth: Decodable {
                let accessToken: String?
                let expiresAt: Double?
            }
            let claudeAiOauth: OAuth?
        }
        guard let credentials = try? JSONDecoder().decode(Credentials.self, from: data) else {
            return .failure(.unreadable)
        }
        guard let oauth = credentials.claudeAiOauth, let access = oauth.accessToken, !access.isEmpty else {
            return .failure(.notSignedIn)
        }
        return .success(Token(accessToken: access, expiresAt: oauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) }))
    }
}

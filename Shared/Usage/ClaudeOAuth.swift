import CryptoKit
import Foundation
import Security

/// Graphitree's own sign-in to Claude, so the plan's limits keep coming whether or not Claude Code
/// runs. The person signs in once in the browser and pastes back the code Anthropic's page shows.
/// Graphitree keeps the tokens in its own Keychain item and renews them itself. It's a sign-in of
/// its own, apart from Claude Code's, so renewing it never signs Claude Code out.
///
/// Without it, Graphitree borrows Claude Code's sign-in (`ClaudeCodeSignIn`), which only Claude
/// Code's terminal command renews: the Code tab in Claude's desktop app doesn't, so readings stop
/// about eight hours after the command last ran. Ported from Claude Usage's sign-in, with the same
/// public OAuth client Claude Code uses, which is the one Anthropic's limits endpoint accepts.
enum ClaudeOAuth {
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let redirectURI = "https://console.anthropic.com/oauth/code/callback"
    static let authorizeBase = "https://claude.ai/oauth/authorize"
    static let tokenEndpoint = URL(string: "https://console.anthropic.com/v1/oauth/token")!
    /// Enough to read the plan's limits and who's signed in. Not `org:create_api_key`, which
    /// Claude Code also asks for: Graphitree never makes API keys.
    static let scopes = "user:profile user:inference"

    enum Failure: Error, Equatable, LocalizedError {
        /// Nothing that looks like a code was pasted.
        case badCode
        /// The code belongs to another sign-in page than the one Graphitree opened last.
        case otherPage
        /// The sign-in has nothing to renew it with.
        case noRefreshToken
        /// Anthropic turned the code or the renewal down (HTTP 400 or 401): it's used up.
        case rejected(Int)
        /// Another failed answer.
        case failed(Int)

        var errorDescription: String? {
            switch self {
            case .badCode: return "Paste the whole code the sign-in page shows."
            case .otherPage: return "That code is from another sign-in page. Open the sign-in page again and use its code."
            case .noRefreshToken: return "Anthropic didn't send a way to renew the sign-in. Sign in again."
            case .rejected: return "Anthropic turned that code down. Codes work once and for a few minutes: open the sign-in page again."
            case .failed(let status): return "Signing in failed (HTTP \(status)). Try again."
            }
        }
    }

    /// The secret pair that proves the code is Graphitree's, plus the `state` that ties the page
    /// to it. A new one for each sign-in page.
    struct PKCE: Equatable {
        let verifier: String
        let challenge: String
        let state: String

        init() {
            self.init(verifier: Self.randomString(), state: Self.randomString())
        }

        init(verifier: String, state: String) {
            self.verifier = verifier
            self.state = state
            challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        }

        private static func randomString() -> String {
            var bytes = [UInt8](repeating: 0, count: 32)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            return Data(bytes).base64URLEncoded
        }
    }

    static func authorizeURL(pkce: PKCE) -> URL {
        var components = URLComponents(string: authorizeBase)!
        components.queryItems = [
            URLQueryItem(name: "code", value: "true"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: pkce.state),
        ]
        return components.url!
    }

    /// The code and state from what was pasted: `code#state` as the page shows it, or the page's
    /// whole address. Nil when there's no code.
    static func parse(pasted: String) -> (code: String, state: String?)? {
        let text = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("http"), let components = URLComponents(string: text),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty {
            return (code, components.queryItems?.first(where: { $0.name == "state" })?.value)
        }
        let parts = text.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard let code = parts.first, !code.isEmpty, !code.contains(where: \.isWhitespace) else { return nil }
        return (code, parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil)
    }

    /// Trades the pasted code for tokens.
    static func exchange(pasted: String, pkce: PKCE) async throws -> ClaudeTokens {
        guard let parsed = parse(pasted: pasted) else { throw Failure.badCode }
        if let state = parsed.state, state != pkce.state { throw Failure.otherPage }
        return try await requestTokens([
            "grant_type": "authorization_code",
            "code": parsed.code,
            "state": pkce.state,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "code_verifier": pkce.verifier,
        ], keeping: nil)
    }

    /// New tokens for old. Anthropic may send a new refresh token too, which replaces the old one.
    static func renew(_ tokens: ClaudeTokens) async throws -> ClaudeTokens {
        guard let refreshToken = tokens.refreshToken, !refreshToken.isEmpty else { throw Failure.noRefreshToken }
        return try await requestTokens([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ], keeping: refreshToken)
    }

    private static func requestTokens(_ body: [String: String], keeping refreshToken: String?) async throws -> ClaudeTokens {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw status == 400 || status == 401 ? Failure.rejected(status) : Failure.failed(status) }
        guard let tokens = tokens(from: data, keeping: refreshToken) else { throw Failure.failed(status) }
        return tokens
    }

    /// The token endpoint's answer. `expires_in` is in seconds from `now`; without a new refresh
    /// token the old one stays.
    static func tokens(from data: Data, keeping refreshToken: String?, now: Date = Date()) -> ClaudeTokens? {
        struct Answer: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double?
        }
        guard let answer = try? JSONDecoder().decode(Answer.self, from: data), !answer.access_token.isEmpty else { return nil }
        return ClaudeTokens(accessToken: answer.access_token,
                            refreshToken: answer.refresh_token ?? refreshToken,
                            expiresAt: answer.expires_in.map { now.addingTimeInterval($0) })
    }
}

/// Graphitree's own tokens for Claude.
struct ClaudeTokens: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?

    /// Within a minute of running out counts as run out: a request would race it.
    func isExpired(now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSince(now) < 60
    }
}

/// Where Graphitree keeps its own sign-in: one item in the login Keychain, which Graphitree made,
/// so reading it asks nothing. Uninstalling deletes it.
struct ClaudeSignInStore: Sendable {
    let keychain: AIKeychain

    static let standard = ClaudeSignInStore(keychain: AIKeychain(service: "Graphitree Claude sign-in"))
    static let account = "claude.ai"

    func load() -> ClaudeTokens? {
        guard let text = keychain.read(Self.account) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ClaudeTokens.self, from: Data(text.utf8))
    }

    func save(_ tokens: ClaudeTokens) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try keychain.save(String(decoding: try encoder.encode(tokens), as: UTF8.self), for: Self.account)
    }

    func clear() {
        keychain.delete(Self.account)
    }

    private static let queue = DispatchQueue(label: "com.marcuslai.Graphitree.claude-own-sign-in")

    /// `load()` off Swift's shared threads. A copy signed differently from the one that saved the
    /// item, such as a local build, gets macOS's keychain prompt, and the read waits for it.
    func loadInBackground() async -> ClaudeTokens? {
        await withCheckedContinuation { continuation in
            Self.queue.async { continuation.resume(returning: load()) }
        }
    }
}

extension Data {
    /// Base64 for URLs: `-` and `_` for `+` and `/`, without padding.
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

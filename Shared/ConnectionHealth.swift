import Foundation

// Whether each AI connection still works: Claude Code's sign-in, API keys, servers on this Mac and
// AWS profiles. Every check is free. Claude Code is asked on this Mac, a key is tried on its
// provider's list of models, which generates nothing, and a server on this Mac is asked which
// models it has. Keys only go to the addresses the app already sends that provider's requests to.
// The parts that decide what an answer means are pure, so the checks can test them.

// MARK: - What a check found

/// How one connection looked the last time Graphitree checked it.
struct ConnectionHealth: Equatable, Sendable {
    enum Level: Int, Comparable, Sendable {
        case ok = 0
        /// Graphitree couldn't tell, such as when the Mac is offline. This never prompts.
        case unknown = 1
        /// It works for now, but needs attention soon, or its server isn't running.
        case warning = 2
        /// It won't work until it's fixed.
        case broken = 3

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// What puts it right.
    enum Fix: Equatable, Sendable {
        /// Sign in to Claude Code again, with `claude auth login` in Terminal.
        case signIn
        /// Paste a new key, or correct the endpoint or profile.
        case replaceKey
        /// Open the app that runs the server.
        case startServer
        /// Pull the model, or pick one the server has.
        case pickModel
        /// Sign in to AWS again, with `aws sso login`.
        case signInToAWS(profile: String)
    }

    let level: Level
    /// A few words for the status pill, such as "Signed in" or "Key rejected".
    let status: String
    /// One or two plain sentences: what's true, and how to fix it when something's wrong.
    let detail: String
    var fix: Fix?

    var isProblem: Bool { level >= .warning }
    var isBroken: Bool { level == .broken }

    /// Two answers are the same problem when they'd say the same thing. A dismissed banner stays
    /// dismissed until the problem changes.
    var problemKey: String { "\(level.rawValue)|\(status)" }
}

// MARK: - Claude Code's sign-in

/// What `claude auth status --json` says.
struct ClaudeSignIn: Equatable, Sendable {
    var loggedIn: Bool
    /// "claude.ai" for a Pro or Max plan; otherwise how an API key reaches it.
    var method: String?
    /// "pro", "max", "team" or "enterprise".
    var plan: String?
    var expiresAt: Date?

    static func parse(_ data: Data) -> ClaudeSignIn? {
        // Anything printed around the JSON, such as an update notice, is ignored.
        let text = String(decoding: data, as: UTF8.self)
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let object = try? JSONSerialization.jsonObject(with: Data(text[start...end].utf8)) as? [String: Any],
              let loggedIn = object["loggedIn"] as? Bool else { return nil }
        return ClaudeSignIn(
            loggedIn: loggedIn,
            method: object["authMethod"] as? String,
            plan: object["subscriptionType"] as? String,
            expiresAt: (object["loginExpiresAt"] as? String).flatMap(ConnectionCheck.date)
        )
    }

    /// "Max plan", or nil when it isn't signed in with a plan.
    var planName: String? {
        guard method == nil || method == "claude.ai", let plan, !plan.isEmpty else { return nil }
        return plan.prefix(1).uppercased() + plan.dropFirst() + " plan"
    }
}

// MARK: - AWS profiles

struct AWSProfile: Equatable, Sendable {
    let name: String
    /// Set when the profile signs in through IAM Identity Center.
    var ssoStartURL: String?
}

enum AWSFiles {
    /// Profiles from ~/.aws/config (`[profile name]`, `[default]`) and ~/.aws/credentials (`[name]`).
    static func profiles(config: String, credentials: String) -> [String: AWSProfile] {
        var result: [String: AWSProfile] = [:]
        let configSections = sections(config)
        var sessions: [String: String] = [:]
        for (header, values) in configSections where header.hasPrefix("sso-session ") {
            sessions[String(header.dropFirst("sso-session ".count))] = values["sso_start_url"]
        }
        for (header, values) in configSections {
            let name: String
            if header == "default" { name = "default" } else if header.hasPrefix("profile ") { name = String(header.dropFirst("profile ".count)) } else { continue }
            let start = values["sso_start_url"] ?? values["sso_session"].flatMap { sessions[$0] }
            result[name] = AWSProfile(name: name, ssoStartURL: start)
        }
        for (header, _) in sections(credentials) where result[header] == nil {
            result[header] = AWSProfile(name: header, ssoStartURL: nil)
        }
        return result
    }

    /// Whether an IAM Identity Center sign-in for `startURL` is still good, from the tokens the AWS
    /// CLI caches. A token that can refresh itself counts. Nil when there's no token at all.
    static func ssoSignedIn(startURL: String, tokens: [Data], now: Date) -> Bool? {
        var found = false
        for data in tokens {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (object["startUrl"] as? String) == startURL else { continue }
            found = true
            if let refresh = object["refreshToken"] as? String, !refresh.isEmpty { return true }
            if let expires = (object["expiresAt"] as? String).flatMap(ConnectionCheck.date), expires > now { return true }
        }
        return found ? false : nil
    }

    private static func sections(_ text: String) -> [(String, [String: String])] {
        var result: [(String, [String: String])] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") || trimmed.hasPrefix(";") || trimmed.isEmpty { continue }
            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                let header = trimmed.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
                result.append((header.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " "), [:]))
            } else if let equals = trimmed.firstIndex(of: "="), !result.isEmpty {
                let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
                let value = trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespaces)
                result[result.count - 1].1[key] = value
            }
        }
        return result
    }
}

// MARK: - What each answer means

enum ConnectionCheck {
    /// A sign-in that ends sooner than this gets a warning.
    static let endsSoon: TimeInterval = 3 * 24 * 3600
    /// How often everything is checked again while the app is open.
    static let interval: TimeInterval = 6 * 3600
    /// The Messages API version the chat already sends.
    static let anthropicVersion = "2026-10-21"

    static func claudeCode(_ signIn: ClaudeSignIn?, now: Date) -> ConnectionHealth {
        guard let signIn else {
            return ConnectionHealth(level: .unknown, status: "Couldn't check", detail: "Graphitree couldn't read Claude Code's sign-in. Rebuilds still try it.")
        }
        guard signIn.loggedIn else {
            return ConnectionHealth(level: .broken, status: "Signed out", detail: "Claude Code is signed out, so rebuilds can't read docs. Sign in again in Terminal.", fix: .signIn)
        }
        let plan = signIn.planName.map { "your \($0)" } ?? "an API key"
        guard let expires = signIn.expiresAt else {
            return ConnectionHealth(level: .ok, status: "Signed in", detail: "Signed in with \(plan).")
        }
        let left = expires.timeIntervalSince(now)
        let day = expires.formatted(.dateTime.day().month(.abbreviated))
        if left <= 0 {
            return ConnectionHealth(level: .broken, status: "Sign-in ended", detail: "Claude Code's sign-in ended on \(day), so rebuilds can't read docs. Sign in again in Terminal.", fix: .signIn)
        }
        if left < endsSoon {
            let days = Int((left / 86400).rounded(.up))
            let when = days <= 1 ? "within a day" : "in \(days) days"
            return ConnectionHealth(level: .warning, status: "Sign-in ends \(when)", detail: "Signed in with \(plan). Sign in again before \(day) to keep building.", fix: .signIn)
        }
        return ConnectionHealth(level: .ok, status: "Signed in", detail: "Signed in with \(plan), until \(day).")
    }

    /// What a provider's answer to the list of models says about its key. A nil status means
    /// Graphitree couldn't reach it at all.
    static func apiKey(_ name: String, status: Int?, body: Data?) -> ConnectionHealth {
        guard let status else {
            return ConnectionHealth(level: .unknown, status: "Couldn't check", detail: "Graphitree couldn't reach \(name). It tries again later.")
        }
        let rejected = ConnectionHealth(level: .broken, status: "Key rejected", detail: "\(name) turned the key down (HTTP \(status)). It may have been revoked or replaced. Paste a new one.", fix: .replaceKey)
        switch status {
        case 200..<300:
            return ConnectionHealth(level: .ok, status: "Key works", detail: "\(name) accepted the key.")
        case 401, 403:
            return rejected
        case 402:
            return ConnectionHealth(level: .broken, status: "Billing problem", detail: "\(name) accepted the key, but says the account can't pay. Check billing on \(name)'s site.")
        case 400 where mentionsKey(body):
            // Google answers a bad key with 400 rather than 401.
            return rejected
        default:
            // Busy, rate-limited or down: none of these say anything about the key.
            return ConnectionHealth(level: .unknown, status: "Couldn't check", detail: "\(name) answered HTTP \(status), so Graphitree couldn't tell whether the key works. It tries again later.")
        }
    }

    private static func mentionsKey(_ body: Data?) -> Bool {
        guard let body else { return false }
        let text = String(decoding: body.prefix(4000), as: UTF8.self).lowercased()
        return text.contains("api key") || text.contains("api_key") || text.contains("apikey")
    }

    /// A server on this Mac. `models` is nil when nothing answered.
    static func localServer(_ name: String, address: String, models: [String]?, wanted: String?) -> ConnectionHealth {
        let shown = shortAddress(address)
        guard let models else {
            return ConnectionHealth(level: .warning, status: "Not running", detail: "Nothing answers at \(shown). Start \(name) before you rebuild, or docs are left out.", fix: .startServer)
        }
        if let wanted, !server(models, has: wanted) {
            let others = models.isEmpty ? "It has no models yet." : "It has \(models.prefix(3).joined(separator: ", "))\(models.count > 3 ? " and \(models.count - 3) more" : "")."
            return ConnectionHealth(level: .broken, status: "Model missing", detail: "\(shown) doesn't have \(wanted). \(others) Pull it, or pick one it has.", fix: .pickModel)
        }
        let what = wanted.map { "\($0) is ready" } ?? "\(models.count) model\(models.count == 1 ? "" : "s")"
        return ConnectionHealth(level: .ok, status: "Running", detail: "\(shown) · \(what).")
    }

    static func bedrock(profile: String, profiles: [String: AWSProfile], ssoSignedIn: Bool?) -> ConnectionHealth {
        guard let found = profiles[profile] else {
            return ConnectionHealth(level: .broken, status: "Profile missing", detail: "There's no AWS profile called \(profile) in ~/.aws. Add it with aws configure, or change the profile here.", fix: .replaceKey)
        }
        guard found.ssoStartURL != nil else {
            return ConnectionHealth(level: .ok, status: "Profile found", detail: "Uses the \(profile) profile from ~/.aws.")
        }
        if ssoSignedIn == true {
            return ConnectionHealth(level: .ok, status: "Signed in", detail: "Signed in to AWS with the \(profile) profile.")
        }
        return ConnectionHealth(level: .broken, status: "Signed out of AWS", detail: "The \(profile) profile's AWS sign-in has ended. Sign in again with aws sso login in Terminal.", fix: .signInToAWS(profile: profile))
    }

    // MARK: Requests

    /// The free request that shows whether a provider's key or server works: its list of models.
    /// Nil when the provider has nothing to ask, such as Bedrock, or a value is missing.
    static func request(for provider: ModelProvider, values: [String: String]) -> URLRequest? {
        func value(_ key: String) -> String? {
            let text = (values[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        var headers: [String: String] = [:]
        let address: String
        switch provider.id {
        case "anthropic":
            guard let key = value("ANTHROPIC_API_KEY") else { return nil }
            address = "https://api.anthropic.com/v1/models"
            headers = ["x-api-key": key, "anthropic-version": anthropicVersion]
        case "openai", "gemini", "kimi", "deepseek":
            guard let variable = provider.settings.first(where: \.isSecret)?.variable, let key = value(variable),
                  let base = hostedBase[provider.id] else { return nil }
            address = joined(base, "models")
            headers = ["Authorization": "Bearer \(key)"]
        case "azure":
            guard let key = value("AZURE_OPENAI_API_KEY"), let endpoint = value("AZURE_OPENAI_ENDPOINT") else { return nil }
            address = joined(endpoint, "openai/models") + "?api-version=2024-10-21"
            headers = ["api-key": key]
        case "ollama":
            address = joined(value("OLLAMA_BASE_URL") ?? "http://localhost:11434/v1", "models")
        case "openai-compatible":
            guard let base = value("OPENAI_BASE_URL") else { return nil }
            address = joined(base, "models")
        default:
            return nil
        }
        guard let url = URL(string: address), url.scheme == "https" || url.scheme == "http" else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: provider.access == .local ? 4 : 15)
        request.httpMethod = "GET"
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        return request
    }

    /// The same addresses the Playbook chat sends these providers' requests to.
    static let hostedBase: [String: String] = [
        "openai": "https://api.openai.com/v1",
        "gemini": "https://generativelanguage.googleapis.com/v1beta/openai",
        "kimi": "https://api.moonshot.ai/v1",
        "deepseek": "https://api.deepseek.com/v1",
    ]

    /// The model a local server should have: the one saved, or graphify's default.
    static func wantedModel(_ provider: ModelProvider, values: [String: String]) -> String? {
        let saved = (values[AIProviderStore.modelVariable] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !saved.isEmpty { return saved }
        return provider.needsModel ? nil : provider.defaultModel
    }

    /// Model names from an OpenAI-style list (`data[].id`) or Ollama's own (`models[].name`).
    static func modelIDs(_ data: Data) -> [String]? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let list = object["data"] as? [[String: Any]] { return list.compactMap { $0["id"] as? String } }
        if let list = object["models"] as? [[String: Any]] { return list.compactMap { ($0["name"] ?? $0["model"]) as? String } }
        return nil
    }

    /// Whether a server's list has the model. Ollama adds ":latest" to a name without a tag, and
    /// LM Studio can list a model under its folder.
    static func server(_ ids: [String], has model: String) -> Bool {
        let wanted = model.lowercased()
        return ids.contains { id in
            let id = id.lowercased()
            return id == wanted || id == wanted + ":latest" || id.hasSuffix("/" + wanted)
        }
    }

    static func shortAddress(_ address: String) -> String {
        var text = address
        for prefix in ["http://", "https://"] where text.hasPrefix(prefix) { text = String(text.dropFirst(prefix.count)) }
        if text.hasSuffix("/") { text = String(text.dropLast()) }
        if text.hasSuffix("/v1") { text = String(text.dropLast(3)) }
        return text
    }

    static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    private static func joined(_ base: String, _ path: String) -> String {
        (base.hasSuffix("/") ? String(base.dropLast()) : base) + "/" + path
    }
}

// MARK: - Which model builds

/// A model that can build the graph now.
struct ModelOption: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

/// What the AI Models row in the rail shows.
enum BuilderBadge: Equatable, Sendable {
    /// Nothing that can build is connected.
    case connect
    /// The person chose to build from code only.
    case codeOnly
    /// This model builds the graph. The level is nil until it has been checked.
    case model(id: String, level: ConnectionHealth.Level?)

    static func current(stored: String, options: [String], health: [String: ConnectionHealth]) -> BuilderBadge {
        guard !options.isEmpty else { return .connect }
        guard let id = BuildChoice.resolve(stored, options: options) else { return .codeOnly }
        return .model(id: id, level: health[id]?.level)
    }
}

extension BuildChoice {
    /// Whether the person has picked what builds, rather than leaving it to the first model found.
    static func isChosen(_ stored: String?) -> Bool {
        guard let stored, !stored.isEmpty else { return false }
        return stored != automatic && stored != codeOnly
    }

    /// The name shown for a coding tool's or provider's id.
    static func name(of id: String) -> String {
        AICatalog.codingTools.first { $0.id == id && $0.graphitreeBackend != nil }?.name
            ?? AICatalog.providers.first { $0.id == id }?.name
            ?? AICatalog.codingTools.first { $0.id == id }?.name
            ?? id
    }
}

/// The "Connect an AI model" screen a new install opens on.
enum FirstRun {
    /// Set once someone connects a model from that screen, or picks one in AI Models.
    static let doneKey = "aiSetupDone"

    /// It shows until something is connected and chosen. "Not now" hides it for this launch only.
    static func shows(hasOptions: Bool, stored: String?, isDone: Bool, skippedThisLaunch: Bool) -> Bool {
        if skippedThisLaunch { return false }
        if !hasOptions { return true }
        return !isDone && !BuildChoice.isChosen(stored)
    }
}

/// Which problem the main window raises, one at a time: the builder's warning or breakage first,
/// then another connection that's broken. Warnings about the others, such as a server that isn't
/// running, wait in AI Models. Dismissed problems stay quiet until they change.
enum ConnectionProblems {
    static func next(builder: String?, health: [String: ConnectionHealth], dismissed: [String: String]) -> String? {
        func isNew(_ id: String) -> Bool { health[id].map { dismissed[id] != $0.problemKey } ?? false }
        if let builder, let found = health[builder], found.isProblem, isNew(builder) { return builder }
        return health.filter { $0.key != builder && $0.value.isBroken && isNew($0.key) }
            .sorted { $0.key < $1.key }
            .first?.key
    }

    /// A usable model to switch to when the builder breaks.
    static func alternative(to builder: String, options: [String], health: [String: ConnectionHealth]) -> String? {
        options.first { $0 != builder && health[$0]?.isBroken != true }
    }
}

// MARK: - Running the checks

enum ConnectionChecker {
    /// Checks one coding tool or provider. Nil when Graphitree has no way to check it.
    static func check(_ id: String, home: String, store: AIProviderStore, now: Date = .now) async -> ConnectionHealth? {
        // Gemini CLI and the Gemini API share an id, so only a tool that builds is matched here.
        if let tool = AICatalog.codingTools.first(where: { $0.id == id && $0.graphitreeBackend != nil }) {
            guard let command = ToolLocator.command(tool.commands, home: home) else { return nil }
            return ConnectionCheck.claudeCode(await claudeSignIn(command: command), now: now)
        }
        guard let provider = AICatalog.providers.first(where: { $0.id == id }), store.isConfigured(provider) else { return nil }
        return await check(provider, values: store.values(for: provider), home: home, now: now)
    }

    /// Checks a provider with the values given, which may not be saved yet.
    static func check(_ provider: ModelProvider, values: [String: String], home: String, now: Date = .now) async -> ConnectionHealth {
        if provider.id == "bedrock" {
            let profile = (values["AWS_PROFILE"] ?? "").trimmingCharacters(in: .whitespaces)
            return bedrock(profile: profile.isEmpty ? "default" : profile, home: home, now: now)
        }
        guard let request = ConnectionCheck.request(for: provider, values: values) else {
            return ConnectionHealth(level: .broken, status: "Not set up", detail: "\(provider.name) is missing its key or server.", fix: .replaceKey)
        }
        let (status, body) = await fetch(request)
        if provider.access == .local {
            let models = status.flatMap { (200..<300).contains($0) ? body.flatMap(ConnectionCheck.modelIDs) : nil }
            let name = provider.id == "ollama" ? "Ollama" : "the server"
            return ConnectionCheck.localServer(name, address: request.url?.absoluteString ?? "", models: models, wanted: ConnectionCheck.wantedModel(provider, values: values))
        }
        return ConnectionCheck.apiKey(provider.name, status: status, body: body)
    }

    /// The models a local server has, or nil when nothing answers.
    static func serverModels(_ provider: ModelProvider, values: [String: String]) async -> [String]? {
        guard let request = ConnectionCheck.request(for: provider, values: values) else { return nil }
        let (status, body) = await fetch(request)
        guard let status, (200..<300).contains(status) else { return nil }
        return body.flatMap(ConnectionCheck.modelIDs)
    }

    static func claudeSignIn(command: String) async -> ClaudeSignIn? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                // Signed out exits with an error but still prints the JSON.
                let result = try? ProcessRunner.run(command, ["auth", "status", "--json"], timeout: 15)
                continuation.resume(returning: result.flatMap { ClaudeSignIn.parse(Data($0.output.utf8)) })
            }
        }
    }

    private static func bedrock(profile: String, home: String, now: Date) -> ConnectionHealth {
        let aws = URL(fileURLWithPath: home).appendingPathComponent(".aws")
        let config = (try? String(contentsOf: aws.appendingPathComponent("config"), encoding: .utf8)) ?? ""
        let credentials = (try? String(contentsOf: aws.appendingPathComponent("credentials"), encoding: .utf8)) ?? ""
        let profiles = AWSFiles.profiles(config: config, credentials: credentials)
        var signedIn: Bool?
        if let start = profiles[profile]?.ssoStartURL {
            let cache = aws.appendingPathComponent("sso/cache")
            let files = (try? FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil)) ?? []
            let tokens = files.filter { $0.pathExtension == "json" }.compactMap { try? Data(contentsOf: $0) }
            signedIn = AWSFiles.ssoSignedIn(startURL: start, tokens: tokens, now: now)
        }
        return ConnectionCheck.bedrock(profile: profile, profiles: profiles, ssoSignedIn: signedIn)
    }

    /// Nothing is cached or kept between checks, and nothing waits for a connection to appear.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    private static func fetch(_ request: URLRequest) async -> (Int?, Data?) {
        guard let (data, response) = try? await session.data(for: request) else { return (nil, nil) }
        return ((response as? HTTPURLResponse)?.statusCode, data)
    }
}

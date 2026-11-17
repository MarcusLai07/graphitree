import Foundation

// Checks for AI connections: what Claude Code's sign-in, a provider's answer and a local server's
// list mean, which model builds, which problem the window raises, and when first run shows.
// Nothing here goes to the network. Called from main.swift.

func connectionChecks() throws {
    let now = utc("2026-11-17T12:00:00Z")
    let day: TimeInterval = 86400

    // MARK: Claude Code's sign-in

    let statusJSON = #"""
    Update available: 2.1.330
    {"loggedIn": true, "authMethod": "claude.ai", "apiProvider": "firstParty", "loginExpiresAt": "2026-12-02T21:36:27.305Z", "subscriptionType": "max", "planTier": "max_5x"}
    """#
    let signIn = ClaudeSignIn.parse(Data(statusJSON.utf8))
    expectEqual(signIn?.loggedIn, true, "claude auth status is read, even with a notice before the JSON")
    check(abs((signIn?.expiresAt ?? .distantPast).timeIntervalSince(utc("2026-12-02T21:36:27Z")) - 0.305) < 0.01, "the sign-in's end date is read, fraction of a second and all")
    expectEqual(signIn?.planName, "Max plan", "the plan is named")
    expectEqual(ClaudeSignIn.parse(Data(#"{"loggedIn": false}"#.utf8))?.loggedIn, false, "signed out is read")
    check(ClaudeSignIn.parse(Data("error: unknown command".utf8)) == nil, "an older Claude Code without auth status gives nothing")
    expectEqual(ClaudeSignIn(loggedIn: true, method: "api_key", plan: nil).planName, nil, "an API key isn't a plan")

    func claude(endsIn seconds: TimeInterval?, loggedIn: Bool = true) -> ConnectionHealth {
        ConnectionCheck.claudeCode(ClaudeSignIn(loggedIn: loggedIn, method: "claude.ai", plan: "max", expiresAt: seconds.map { now.addingTimeInterval($0) }), now: now)
    }
    expectEqual(claude(endsIn: 15 * day).level, .ok, "a sign-in with weeks left is fine")
    check(claude(endsIn: 15 * day).detail.contains("Max plan"), "the detail says which plan")
    expectEqual(claude(endsIn: nil).level, .ok, "a sign-in with no end date is fine")
    let endsSoon = claude(endsIn: 2 * day - 60)
    expectEqual(endsSoon.level, .warning, "a sign-in ending in two days is a warning")
    expectEqual(endsSoon.status, "Sign-in ends in 2 days", "the warning says how long is left")
    expectEqual(endsSoon.fix, .signIn, "the warning offers to sign in again")
    expectEqual(claude(endsIn: 3 * day + 60).level, .ok, "three days and a bit is still fine")
    expectEqual(claude(endsIn: 3600).status, "Sign-in ends within a day", "under a day says so")
    let ended = claude(endsIn: -60)
    expectEqual(ended.level, .broken, "a sign-in past its end is broken")
    expectEqual(ended.fix, .signIn, "an ended sign-in offers to sign in again")
    let signedOut = claude(endsIn: 15 * day, loggedIn: false)
    expectEqual(signedOut.level, .broken, "signed out is broken, whatever the date says")
    expectEqual(signedOut.status, "Signed out", "signed out says so")
    expectEqual(ConnectionCheck.claudeCode(nil, now: now).level, .unknown, "no answer from Claude Code is unknown, not broken")

    // MARK: API keys

    expectEqual(ConnectionCheck.apiKey("OpenAI", status: 200, body: nil).level, .ok, "200 means the key works")
    for status in [401, 403] {
        let rejected = ConnectionCheck.apiKey("OpenAI", status: status, body: nil)
        check(rejected.level == .broken && rejected.fix == .replaceKey && rejected.detail.contains("HTTP \(status)"), "\(status) means the key was rejected")
    }
    let googleBadKey = Data(#"{"error": {"code": 400, "message": "API key not valid. Please pass a valid API key.", "status": "INVALID_ARGUMENT"}}"#.utf8)
    expectEqual(ConnectionCheck.apiKey("Google Gemini", status: 400, body: googleBadKey).status, "Key rejected", "Google's 400 for a bad key counts as rejected")
    expectEqual(ConnectionCheck.apiKey("Google Gemini", status: 400, body: Data(#"{"error": "bad request"}"#.utf8)).level, .unknown, "another 400 says nothing about the key")
    expectEqual(ConnectionCheck.apiKey("OpenAI", status: 402, body: nil).status, "Billing problem", "402 is a billing problem")
    for status in [404, 408, 429, 500, 503, 529] {
        expectEqual(ConnectionCheck.apiKey("OpenAI", status: status, body: nil).level, .unknown, "\(status) never prompts")
    }
    let offline = ConnectionCheck.apiKey("OpenAI", status: nil, body: nil)
    check(offline.level == .unknown && !offline.isProblem, "offline is unknown and raises nothing")

    // MARK: Servers on this Mac

    let notRunning = ConnectionCheck.localServer("Ollama", address: "http://localhost:11434/v1/models", models: nil, wanted: "qwen2.5-coder:7b")
    check(notRunning.level == .warning && notRunning.fix == .startServer && notRunning.detail.contains("localhost:11434"), "a server that doesn't answer is a warning that says where it looked")
    let missingModel = ConnectionCheck.localServer("Ollama", address: "http://localhost:11434/v1/models", models: ["llama3.2:3b"], wanted: "qwen2.5-coder:7b")
    check(missingModel.level == .broken && missingModel.fix == .pickModel && missingModel.detail.contains("llama3.2:3b"), "a missing model is broken and lists what the server has")
    expectEqual(ConnectionCheck.localServer("Ollama", address: "http://localhost:11434/v1/models", models: ["qwen2.5-coder:7b"], wanted: "qwen2.5-coder:7b").level, .ok, "the model there is fine")
    expectEqual(ConnectionCheck.localServer("the server", address: "http://localhost:1234/v1/models", models: [], wanted: nil).level, .ok, "a server with no model asked for is fine")
    check(ConnectionCheck.server(["llama3:latest"], has: "llama3"), "Ollama's :latest matches a name without a tag")
    check(ConnectionCheck.server(["lmstudio-community/Qwen2.5-7B"], has: "qwen2.5-7b"), "LM Studio's folder and case don't matter")
    check(!ConnectionCheck.server(["llama3.2:3b"], has: "llama3"), "a different model doesn't match")
    expectEqual(ConnectionCheck.modelIDs(Data(#"{"object": "list", "data": [{"id": "gpt-4.1-mini"}, {"id": "o3"}]}"#.utf8)), ["gpt-4.1-mini", "o3"], "an OpenAI-style list is read")
    expectEqual(ConnectionCheck.modelIDs(Data(#"{"models": [{"name": "qwen2.5-coder:7b"}]}"#.utf8)), ["qwen2.5-coder:7b"], "Ollama's own list is read")
    check(ConnectionCheck.modelIDs(Data("<html>".utf8)) == nil, "a page that isn't a list gives nothing")
    expectEqual(ConnectionCheck.shortAddress("http://localhost:11434/v1/"), "localhost:11434", "addresses are shown short")

    // MARK: Where checks go

    func provider(_ id: String) -> ModelProvider { AICatalog.providers.first { $0.id == id }! }
    let anthropicCheck = ConnectionCheck.request(for: provider("anthropic"), values: ["ANTHROPIC_API_KEY": "sk-test"])
    expectEqual(anthropicCheck?.url?.absoluteString, "https://api.anthropic.com/v1/models", "Anthropic's key is tried on its list of models")
    expectEqual(anthropicCheck?.httpMethod, "GET", "the check only reads")
    expectEqual(anthropicCheck?.value(forHTTPHeaderField: "x-api-key"), "sk-test", "Anthropic's key goes in its own header")
    expectEqual(anthropicCheck?.value(forHTTPHeaderField: "anthropic-version"), ConnectionCheck.anthropicVersion, "the API version is sent")
    let openAICheck = ConnectionCheck.request(for: provider("openai"), values: ["OPENAI_API_KEY": "sk-o"])
    expectEqual(openAICheck?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-o", "OpenAI's key goes as a bearer token")
    check(ConnectionCheck.request(for: provider("openai"), values: [:]) == nil, "no key, no check")
    check(ConnectionCheck.request(for: provider("bedrock"), values: ["AWS_PROFILE": "default"]) == nil, "Bedrock is checked on disk, not over the network")
    expectEqual(ConnectionCheck.request(for: provider("azure"), values: ["AZURE_OPENAI_API_KEY": "k", "AZURE_OPENAI_ENDPOINT": "https://me.openai.azure.com/"])?.url?.absoluteString, "https://me.openai.azure.com/openai/models?api-version=2024-10-21", "Azure is asked at its own endpoint")
    expectEqual(ConnectionCheck.request(for: provider("ollama"), values: [:])?.url?.absoluteString, "http://localhost:11434/v1/models", "Ollama is asked at its usual address")
    check((ConnectionCheck.request(for: provider("ollama"), values: [:])?.timeoutInterval ?? 99) <= 5, "a server on this Mac gets a short wait")
    expectEqual(ConnectionCheck.request(for: provider("openai-compatible"), values: ["OPENAI_BASE_URL": "http://localhost:1234/v1/"])?.url?.absoluteString, "http://localhost:1234/v1/models", "a trailing slash on the server is handled")
    expectEqual(ConnectionCheck.wantedModel(provider("ollama"), values: [:]), "qwen2.5-coder:7b", "Ollama checks graphify's default model when none is saved")
    expectEqual(ConnectionCheck.wantedModel(provider("openai-compatible"), values: [:]), nil, "a server with no saved model checks only that it answers")

    // Keys only go where the chat already sends them.
    let hostKeys = AIKeychain(service: "Graphitree checks \(UUID().uuidString)")
    let hostStore = AIProviderStore(defaults: checkSuite("hosts"), keychain: hostKeys)
    for id in ["anthropic", "openai", "gemini", "kimi", "deepseek"] {
        let hosted = provider(id)
        let variable = hosted.settings.first(where: \.isSecret)!.variable
        try hostStore.save([variable: "sk-\(id)"], for: hosted)
        let checkHost = ConnectionCheck.request(for: hosted, values: hostStore.values(for: hosted))?.url?.host
        var chatHost: String?
        if case .success(let engine) = ChatEngine.engine(for: id, home: "/nonexistent", store: hostStore) {
            switch engine.backend {
            case .anthropic: chatHost = "api.anthropic.com"
            case .openAI(let url, _, _): chatHost = URL(string: url)?.host
            case .claudeCode: chatHost = nil
            }
        }
        check(checkHost != nil && checkHost == chatHost, "\(hosted.name)'s key is checked at the host the chat uses (\(checkHost ?? "none"))")
        hostStore.remove(hosted)
    }

    // MARK: AWS

    let awsConfig = """
    [default]
    region = us-east-1

    [profile work]
    sso_session = acme
    sso_account_id = 123

    [profile old]
    sso_start_url = https://old.awsapps.com/start

    [sso-session acme]
    sso_start_url = https://acme.awsapps.com/start
    """
    let profiles = AWSFiles.profiles(config: awsConfig, credentials: "[keys]\naws_access_key_id = A\n")
    expectEqual(Set(profiles.keys), ["default", "work", "old", "keys"], "profiles come from config and credentials")
    expectEqual(profiles["work"]?.ssoStartURL, "https://acme.awsapps.com/start", "a profile's sso-session gives its start URL")
    expectEqual(profiles["old"]?.ssoStartURL, "https://old.awsapps.com/start", "an older SSO profile has its own start URL")
    expectEqual(profiles["default"]?.ssoStartURL, nil, "a profile with keys isn't SSO")
    func token(_ start: String, expires: String, refresh: Bool = false) -> Data {
        Data(#"{"startUrl": "\#(start)", "expiresAt": "\#(expires)"\#(refresh ? #", "refreshToken": "r""# : "")}"#.utf8)
    }
    let acme = "https://acme.awsapps.com/start"
    expectEqual(AWSFiles.ssoSignedIn(startURL: acme, tokens: [token(acme, expires: "2026-11-17T18:00:00Z")], now: now), true, "an SSO token that hasn't ended is signed in")
    expectEqual(AWSFiles.ssoSignedIn(startURL: acme, tokens: [token(acme, expires: "2026-11-17T08:00:00Z")], now: now), false, "an ended SSO token is signed out")
    expectEqual(AWSFiles.ssoSignedIn(startURL: acme, tokens: [token(acme, expires: "2026-11-17T08:00:00Z", refresh: true)], now: now), true, "a token that can refresh itself counts")
    expectEqual(AWSFiles.ssoSignedIn(startURL: acme, tokens: [token("https://other", expires: "2026-11-18T08:00:00Z")], now: now), nil, "another start URL's token doesn't count")
    expectEqual(ConnectionCheck.bedrock(profile: "missing", profiles: profiles, ssoSignedIn: nil).status, "Profile missing", "a missing profile is broken")
    expectEqual(ConnectionCheck.bedrock(profile: "default", profiles: profiles, ssoSignedIn: nil).level, .ok, "a profile with keys is fine")
    expectEqual(ConnectionCheck.bedrock(profile: "work", profiles: profiles, ssoSignedIn: false).fix, .signInToAWS(profile: "work"), "a signed-out SSO profile offers aws sso login")

    // MARK: Which model builds

    let fine = ConnectionHealth(level: .ok, status: "Signed in", detail: "")
    let soon = ConnectionHealth(level: .warning, status: "Sign-in ends in 2 days", detail: "", fix: .signIn)
    let gone = ConnectionHealth(level: .broken, status: "Key rejected", detail: "", fix: .replaceKey)
    expectEqual(BuilderBadge.current(stored: BuildChoice.automatic, options: [], health: [:]), .connect, "with nothing connected, the rail asks to connect")
    expectEqual(BuilderBadge.current(stored: BuildChoice.automatic, options: ["claude-code", "openai"], health: ["claude-code": fine]), .model(id: "claude-code", level: .ok), "automatic builds with the first model")
    expectEqual(BuilderBadge.current(stored: "openai", options: ["claude-code", "openai"], health: ["openai": gone]), .model(id: "openai", level: .broken), "a chosen model is current, with its health")
    expectEqual(BuilderBadge.current(stored: "openai", options: ["claude-code", "openai"], health: [:]), .model(id: "openai", level: nil), "a model not checked yet has no level")
    expectEqual(BuilderBadge.current(stored: BuildChoice.codeOnly, options: ["claude-code"], health: [:]), .codeOnly, "code only is shown as chosen")
    expectEqual(BuilderBadge.current(stored: "deepseek", options: ["claude-code"], health: [:]), .codeOnly, "a removed model builds code only, as rebuilds do")
    check(BuildChoice.isChosen("claude-code") && !BuildChoice.isChosen(BuildChoice.automatic) && !BuildChoice.isChosen(BuildChoice.codeOnly) && !BuildChoice.isChosen(nil), "only a named model counts as chosen")
    expectEqual(BuildChoice.name(of: "claude-code"), "Claude Code", "ids have names")
    expectEqual(BuildChoice.name(of: "gemini"), "Google Gemini", "the Gemini API, which can build, wins over Gemini CLI's matching id")

    // MARK: Which problem the window raises

    expectEqual(ConnectionProblems.next(builder: "claude-code", health: ["claude-code": soon], dismissed: [:]), "claude-code", "the builder's warning is raised")
    expectEqual(ConnectionProblems.next(builder: "claude-code", health: ["claude-code": soon], dismissed: ["claude-code": soon.problemKey]), nil, "a dismissed problem stays quiet")
    expectEqual(ConnectionProblems.next(builder: "claude-code", health: ["claude-code": signedOut], dismissed: ["claude-code": soon.problemKey]), "claude-code", "a dismissed warning that becomes broken is raised again")
    expectEqual(ConnectionProblems.next(builder: "claude-code", health: ["claude-code": fine, "ollama": notRunning], dismissed: [:]), nil, "another model's warning waits in AI Models")
    expectEqual(ConnectionProblems.next(builder: "claude-code", health: ["claude-code": fine, "openai": gone], dismissed: [:]), "openai", "another model that's broken is raised")
    expectEqual(ConnectionProblems.next(builder: nil, health: ["claude-code": fine], dismissed: [:]), nil, "nothing wrong, nothing raised")
    expectEqual(ConnectionProblems.alternative(to: "claude-code", options: ["claude-code", "openai", "ollama"], health: ["openai": gone]), "ollama", "the model offered instead is one that works")
    expectEqual(ConnectionProblems.alternative(to: "claude-code", options: ["claude-code"], health: [:]), nil, "with nothing else, nothing is offered")

    // MARK: First run

    check(FirstRun.shows(hasOptions: false, stored: nil, isDone: false, skippedThisLaunch: false), "a new install with nothing connected opens on first run")
    check(FirstRun.shows(hasOptions: false, stored: "claude-code", isDone: true, skippedThisLaunch: false), "it comes back when nothing is connected any more")
    check(FirstRun.shows(hasOptions: true, stored: BuildChoice.automatic, isDone: false, skippedThisLaunch: false), "a model found but not chosen still asks once")
    check(FirstRun.shows(hasOptions: true, stored: BuildChoice.codeOnly, isDone: false, skippedThisLaunch: false), "after Not now, it asks again next launch")
    check(!FirstRun.shows(hasOptions: true, stored: "claude-code", isDone: false, skippedThisLaunch: false), "a chosen model skips first run")
    check(!FirstRun.shows(hasOptions: true, stored: BuildChoice.codeOnly, isDone: true, skippedThisLaunch: false), "code only chosen after setup doesn't bring it back")
    check(!FirstRun.shows(hasOptions: false, stored: nil, isDone: false, skippedThisLaunch: true), "Not now hides it for this launch")
}

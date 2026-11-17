import Foundation

/// USD per million tokens.
struct ModelPrice: Equatable {
    let input: Double
    let output: Double
    let cacheRead: Double
    /// Cache writes kept for 5 minutes (1.25× input).
    let write5m: Double
    /// Cache writes kept for an hour (2× input).
    let write1h: Double

    /// The usual shape: cache writes 1.25× / 2× input; cache reads as given.
    init(_ input: Double, _ output: Double, cacheRead: Double) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        write5m = input * 1.25
        write1h = input * 2
    }
}

/// API list prices for the models Claude Code and Codex use, so the app can
/// show ≈ cost as Magpie does ("effective prices"), without a network call.
/// A subscription isn't billed per token: this is what the same calls would
/// cost on the API. Update when new models ship (claude.com/pricing,
/// developers.openai.com/api/docs/pricing).
enum ModelPricing {
    /// Keyed by display name ("Opus 5.5"), as transcripts are stored. Cache
    /// reads differ by model: 0.025× input on Fable 5.1/5.2, 0.05× on Opus
    /// and Sonnet 5.5, 0.1× elsewhere. Prices as of 2026-11.
    static let table: [String: ModelPrice] = {
        var table: [String: ModelPrice] = [
            "Fable 5.2": ModelPrice(8, 40, cacheRead: 0.20),
            "Fable 5.1": ModelPrice(10, 50, cacheRead: 0.25),
            "Fable 5": ModelPrice(10, 50, cacheRead: 1.00),
            "Opus 5.5": ModelPrice(4, 20, cacheRead: 0.20),
            "Opus 5": ModelPrice(5, 25, cacheRead: 0.50),
            "Opus 4.8": ModelPrice(5, 25, cacheRead: 0.50),
            "Opus 4.7": ModelPrice(5, 25, cacheRead: 0.50),
            "Opus 4.6": ModelPrice(5, 25, cacheRead: 0.50),
            "Opus 4.5": ModelPrice(5, 25, cacheRead: 0.50),
            "Opus 4.1": ModelPrice(15, 75, cacheRead: 1.50),
            "Opus 4": ModelPrice(15, 75, cacheRead: 1.50),
            "Sonnet 5.5": ModelPrice(2, 10, cacheRead: 0.10),
            "Sonnet 5": ModelPrice(2, 10, cacheRead: 0.20),
            "Sonnet 4.6": ModelPrice(3, 15, cacheRead: 0.30),
            "Sonnet 4.5": ModelPrice(3, 15, cacheRead: 0.30),
            "Sonnet 4": ModelPrice(3, 15, cacheRead: 0.30),
            "Sonnet 3.7": ModelPrice(3, 15, cacheRead: 0.30),
            "Haiku 5.5": ModelPrice(0.10, 0.50, cacheRead: 0.01),
            "Haiku 4.5": ModelPrice(1, 5, cacheRead: 0.10),
            "Haiku 3.5": ModelPrice(0.80, 4, cacheRead: 0.08),
        ]
        // Mythos models are priced as the Fable of the same version.
        for (name, price) in table where name.hasPrefix("Fable ") {
            table["Mythos" + name.dropFirst("Fable".count)] = price
        }
        return table
    }()

    /// Haiku 5.5 costs 5× more for a prompt over 100K tokens.
    private static let haikuLongPrompt = ModelPrice(0.50, 2.50, cacheRead: 0.05)

    /// OpenAI's standard prices for the models Codex offers, as of 2026-11, by model id: input,
    /// output, cached input. OpenAI doesn't charge for writing the cache. Models whose page lists
    /// no cached price (the Pro ones) bill cached input as input.
    private static let openAIPrices: [String: ModelPrice] = [
        "gpt-6-astra": ModelPrice(10, 50, cacheRead: 1.00),
        "gpt-6-sol": ModelPrice(2, 10, cacheRead: 0.20),
        "gpt-6-luna": ModelPrice(0.10, 0.50, cacheRead: 0.01),
        "gpt-6.1-sol": ModelPrice(2, 10, cacheRead: 0.10),
        "gpt-6.1-terra": ModelPrice(1, 5, cacheRead: 0.05),
        "gpt-5.6-sol": ModelPrice(4, 20, cacheRead: 0.40),
        "gpt-5.6-terra": ModelPrice(2, 12, cacheRead: 0.20),
        "gpt-5.6-luna": ModelPrice(0.20, 1.20, cacheRead: 0.02),
        "gpt-5.5": ModelPrice(5, 30, cacheRead: 0.50),
        "gpt-5.5-pro": ModelPrice(30, 180, cacheRead: 30),
        "gpt-5.4": ModelPrice(2.50, 15, cacheRead: 0.25),
        "gpt-5.4-pro": ModelPrice(30, 180, cacheRead: 30),
        "gpt-5.4-mini": ModelPrice(0.75, 4.50, cacheRead: 0.075),
        "gpt-5.4-nano": ModelPrice(0.20, 1.25, cacheRead: 0.02),
        "gpt-5.3-codex": ModelPrice(1.75, 14, cacheRead: 0.175),
        "gpt-5.2": ModelPrice(1.75, 14, cacheRead: 0.175),
        "gpt-5.2-pro": ModelPrice(21, 168, cacheRead: 21),
        "gpt-5.1": ModelPrice(1.25, 10, cacheRead: 0.125),
        "gpt-5": ModelPrice(1.25, 10, cacheRead: 0.125),
        "gpt-5-mini": ModelPrice(0.25, 2, cacheRead: 0.025),
        "gpt-5-nano": ModelPrice(0.05, 0.40, cacheRead: 0.005),
        "gpt-5-pro": ModelPrice(15, 120, cacheRead: 15),
    ]

    /// Over 272K tokens of prompt, these cost more.
    private static let openAILongContext: [String: ModelPrice] = [
        "gpt-6-astra": ModelPrice(20, 75, cacheRead: 2.00),
        "gpt-6-sol": ModelPrice(4, 15, cacheRead: 0.40),
        "gpt-6-luna": ModelPrice(0.20, 0.75, cacheRead: 0.02),
        "gpt-6.1-sol": ModelPrice(4, 15, cacheRead: 0.20),
        "gpt-6.1-terra": ModelPrice(2, 7.50, cacheRead: 0.10),
        "gpt-5.5": ModelPrice(10, 45, cacheRead: 1.00),
        "gpt-5.4": ModelPrice(5, 22.50, cacheRead: 0.50),
    ]
    private static let openAILongPrompt = 272_000

    /// The same prices by the name calls are stored under ("GPT-6.1 Sol").
    private static let openAIByName: [String: ModelPrice] = Dictionary(uniqueKeysWithValues:
        openAIPrices.map { (CodexSessions.displayName(for: $0.key), $0.value) })
    private static let openAILongByName: [String: ModelPrice] = Dictionary(uniqueKeysWithValues:
        openAILongContext.map { (CodexSessions.displayName(for: $0.key), $0.value) })

    static func price(for model: String, promptTokens: Int = 0) -> ModelPrice? {
        if model == "Haiku 5.5", promptTokens > 100_000 { return haikuLongPrompt }
        if let price = table[model] { return price }
        if promptTokens > openAILongPrompt, let long = openAILongByName[model] { return long }
        return openAIByName[model]
    }

    /// ≈ USD for one call; nil when the model isn't in the table.
    static func cost(model: String, input: Int, output: Int, cacheRead: Int,
                     cacheWrite: Int, cacheWrite1h: Int) -> Double? {
        guard let price = price(for: model, promptTokens: input + cacheRead + cacheWrite) else {
            return nil
        }
        let write1h = min(cacheWrite1h, cacheWrite)
        let write5m = cacheWrite - write1h
        let micro = Double(input) * price.input
            + Double(output) * price.output
            + Double(cacheRead) * price.cacheRead
            + Double(write5m) * price.write5m
            + Double(write1h) * price.write1h
        return micro / 1_000_000
    }
}

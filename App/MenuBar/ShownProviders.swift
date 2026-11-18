import Foundation

/// The AI tools whose usage Graphitree shows: the ones AI Models lists under Connected
/// (`UsageProvider.shown`). The Usage page's switch, the menu bar, the widgets and the alerts use
/// only these. Read at launch, with each five-minute reading, and whenever AI Models checks its
/// tools, so connecting or removing one shows at once.
@MainActor
final class ShownProviders: ObservableObject {
    static let shared = ShownProviders()

    @Published private(set) var providers: [UsageProvider]

    private init() {
        providers = UsageProvider.shown(home: NSHomeDirectory())
    }

    func refresh() {
        let current = UsageProvider.shown(home: NSHomeDirectory())
        guard current != providers else { return }
        providers = current
        UsageFeed.shared.shownChanged()
    }

    func contains(_ provider: UsageProvider) -> Bool { providers.contains(provider) }

    /// `wanted` when it's shown, otherwise the first one that is. Nil when none is.
    func pick(_ wanted: UsageProvider?) -> UsageProvider? {
        if let wanted, providers.contains(wanted) { return wanted }
        return providers.first
    }
}

import Foundation

/// Whose figures sit beside the menu bar icon: a provider's, or none. Saved as the provider's
/// `rawValue` ("claude"), or "none".
enum MenuBarFigures: RawRepresentable, Hashable, Identifiable {
    case provider(UsageProvider)
    case none

    static let claude = MenuBarFigures.provider(.claude)

    init?(rawValue: String) {
        if rawValue == "none" {
            self = .none
        } else if let provider = UsageProvider(rawValue: rawValue) {
            self = .provider(provider)
        } else {
            return nil
        }
    }

    var rawValue: String { provider?.rawValue ?? "none" }
    var id: String { rawValue }
    var title: String { provider?.name ?? "Icon only" }

    var provider: UsageProvider? {
        if case .provider(let provider) = self { return provider }
        return nil
    }

    /// What the picker offers: each shown provider, then the icon alone.
    static func choices(shown: [UsageProvider]) -> [MenuBarFigures] {
        shown.map(MenuBarFigures.provider) + [.none]
    }

    /// This choice as it applies now: a provider that's no longer shown gives way to the first one
    /// that is, or to the icon alone.
    func effective(shown: [UsageProvider]) -> MenuBarFigures {
        guard let provider, !shown.contains(provider) else { return self }
        return shown.first.map(MenuBarFigures.provider) ?? .none
    }
}

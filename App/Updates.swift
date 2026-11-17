import Combine
import Sparkle
import SwiftUI

/// Updates come from Graphitree's GitHub releases, through Sparkle. It checks once a day, and
/// Graphitree › Check for Updates… checks now. Sparkle shows what's new and, when the person
/// agrees, downloads the update and checks that it was signed with the release key and comes from
/// the same Apple team. Then it replaces the app and opens the new one. The feed and the public
/// key are in project.yml. Scripts/release.sh publishes a release.
@MainActor
final class Updates: ObservableObject {
    static let shared = Updates()

    @Published private(set) var canCheck = false
    private let controller: SPUStandardUpdaterController

    private init() {
        // A Debug build, run from Xcode, doesn't check, so working on Graphitree never offers to
        // replace the copy being worked on.
        #if DEBUG
        let starts = false
        #else
        let starts = true
        #endif
        controller = SPUStandardUpdaterController(startingUpdater: starts, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
    }

    func check() { controller.updater.checkForUpdates() }
}

/// Graphitree › Check for Updates…, off while a check is already running.
struct CheckForUpdatesButton: View {
    @ObservedObject var updates: Updates

    var body: some View {
        Button("Check for Updates…") { updates.check() }
            .disabled(!updates.canCheck)
    }
}

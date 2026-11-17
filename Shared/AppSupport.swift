import Foundation

/// Graphitree's folder in Application Support, which holds its indexes, chats, run and usage logs,
/// the Playbook backup and the graph backups.
enum AppSupport {
    static let folderName = "Graphitree"

    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}

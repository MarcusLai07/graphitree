import Foundation

/// The Playbook lab: a web page bundled with the app, built from `playground/`, where libraries
/// are tried live in a composer. `lab-manifest.json`, written by the same build, lists the
/// libraries the composer can place and the lab route that opens each one ("try/<id>"), so a
/// Playbook card can offer Try It.
struct LabCatalog: Equatable {
    struct Entry: Codable, Equatable {
        let name: String
        var aliases: [String] = []
        let route: String
        var job: String = ""
    }

    let entries: [Entry]

    /// The catalog bundled with the app. Empty where there's no lab, such as the command line.
    static let bundled: LabCatalog = {
        guard let url = Bundle.main.url(forResource: "lab-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? LabCatalog(data: data)
        else { return LabCatalog(entries: []) }
        return catalog
    }()

    init(entries: [Entry]) {
        self.entries = entries
    }

    init(data: Data) throws {
        struct File: Decodable { let libraries: [Entry] }
        entries = try JSONDecoder().decode(File.self, from: data).libraries
    }

    /// The lab route that opens a library, matched on its name or an alias, ignoring case, spaces
    /// and punctuation, so "Radix UI" finds "Radix" and "shadcn ui" finds "shadcn/ui".
    func route(for libraryName: String) -> String? {
        let wanted = Self.key(libraryName)
        guard !wanted.isEmpty else { return nil }
        return entries.first { entry in ([entry.name] + entry.aliases).contains { Self.key($0) == wanted } }?.route
    }

    /// Routes are plain words joined by slashes; anything else is dropped before a route reaches
    /// a script or URL.
    static func safeRoute(_ route: String) -> String {
        route.filter { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "-" || $0 == "/" }
    }

    static func key(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

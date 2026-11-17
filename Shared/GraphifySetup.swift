import Foundation

/// Getting graphify onto a Mac that doesn't have it, from the first-run screen. graphify makes
/// every graph Graphitree shows, and it's a Python tool, so it comes through uv. Astral's own
/// installer puts uv in ~/.local/bin and leaves shell profiles alone. Then `uv tool install
/// graphifyy` puts graphify there too, with a Python of its own when the Mac has none uv can use.
/// Uninstalling Graphitree leaves both, since other tools use graphify. It only says Graphitree
/// installed it, and how to remove it.
enum GraphifySetup {
    /// graphify's name on PyPI, with two y's.
    static let package = "graphifyy"
    static let uvInstaller = URL(string: "https://astral.sh/uv/install.sh")!
    /// Set when Graphitree installed graphify, so Uninstall Graphitree… can say so.
    static let installedKey = "installedGraphify"
    static let removeCommand = "uv tool uninstall \(package)"

    /// Where uv may already be: Astral's installer, then Homebrew on Apple silicon and on Intel.
    static func uvCandidates(home: String) -> [String] {
        ["\(home)/.local/bin/uv", "/opt/homebrew/bin/uv", "/usr/local/bin/uv"]
    }

    static func locateUV(home: String) -> String? {
        uvCandidates(home: home).first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// The same steps, for someone who'd rather use Terminal: Astral's usual command, then uv by
    /// its full path, since a Terminal window opened before it was installed can't find it yet.
    static func terminalCommands(hasUV: Bool) -> [String] {
        hasUV
            ? ["uv tool install \(package)"]
            : ["curl -LsSf \(uvInstaller.absoluteString) | sh", "~/.local/bin/uv tool install \(package)"]
    }

    enum Step: Equatable, Sendable {
        case uv
        case graphify

        var title: String {
            switch self {
            case .uv: return "Installing uv, which installs graphify…"
            case .graphify: return "Installing graphify. The first time, this also gets Python, so it can take a minute or two…"
            }
        }
    }

    struct Failure: LocalizedError, Equatable {
        let message: String
        var errorDescription: String? { message }
    }

    /// What installing does to the Mac. The checks swap these out, so nothing real is installed.
    struct Effects {
        /// Downloads a URL to a file.
        var download: (URL, URL) throws -> Void
        /// Runs a program with extra environment variables.
        var run: (String, [String], [String: String]) throws -> ProcessOutput
        var locateUV: () -> String?
        var locateGraphify: () -> String?

        static func live(home: String) -> Effects {
            Effects(
                download: { url, destination in
                    let result = try ProcessRunner.run("/usr/bin/curl", ["-fsSL", "--retry", "2", "-o", destination.path, url.absoluteString], timeout: 120)
                    guard result.status == 0 else {
                        throw Failure(message: "Couldn't download uv's installer. Check the internet connection and try again.")
                    }
                },
                run: { executable, arguments, environment in
                    try ProcessRunner.run(executable, arguments, environment: environment, timeout: 900)
                },
                locateUV: { GraphifySetup.locateUV(home: home) },
                locateGraphify: { GraphRebuilder.locateGraphify() }
            )
        }
    }

    /// Installs uv when it's missing, then graphify, and returns graphify's path. `onStep` says
    /// what's happening. Nothing runs when graphify is already there.
    static func install(effects: Effects, onStep: (Step) -> Void = { _ in }) throws -> String {
        if let graphify = effects.locateGraphify() { return graphify }

        var uv = effects.locateUV()
        if uv == nil {
            onStep(.uv)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("graphitree-uv-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let script = folder.appendingPathComponent("install.sh")
            try effects.download(uvInstaller, script)
            // UV_NO_MODIFY_PATH: Graphitree finds uv where it is, so shell profiles stay as they were.
            let result = try effects.run("/bin/sh", [script.path], ["UV_NO_MODIFY_PATH": "1"])
            guard result.status == 0 else { throw Failure(message: "uv's installer didn't finish. \(lastLines(result))") }
            uv = effects.locateUV()
        }
        guard let uv else { throw Failure(message: "uv's installer finished, but uv isn't in ~/.local/bin, where Graphitree looks.") }

        onStep(.graphify)
        let result = try effects.run(uv, ["tool", "install", package], [:])
        guard result.status == 0, let graphify = effects.locateGraphify() else {
            throw Failure(message: "graphify didn't install. \(lastLines(result))")
        }
        return graphify
    }

    /// The end of what a failed step printed, which is where it says why.
    static func lastLines(_ result: ProcessOutput) -> String {
        if result.timedOut { return "It took too long, so it was stopped." }
        let text = (result.errors + "\n" + result.output).trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = text.split(separator: "\n").suffix(4).joined(separator: "\n")
        return lines.isEmpty ? "It stopped with exit \(result.status)." : lines
    }
}

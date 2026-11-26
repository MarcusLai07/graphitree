import Foundation

/// The name and email a commit is signed with.
struct GitIdentity: Codable, Hashable, Sendable {
    let name: String
    let email: String

    var display: String { "\(name) <\(email)>" }
}

/// One `includeIf "gitdir:…"` rule from the global git config: commits made in repos under this
/// folder use the identity in the included file.
struct GitRule: Hashable, Identifiable, Sendable {
    /// Absolute, ending in `/`.
    let folder: String
    /// The included config file.
    let configFile: String
    let identity: GitIdentity?

    var id: String { folder }
}

/// The owner's git rules: their global identity and the folders that switch it. Read from git
/// itself, never guessed from folder names.
struct GitRules: Equatable, Sendable {
    var global: GitIdentity?
    /// Longest folder first, so the first match is the most specific.
    var rules: [GitRule]

    static let empty = GitRules(global: nil, rules: [])

    /// Reads the rules. `environment` lets the checks point git at a throwaway home.
    static func read(home: String = NSHomeDirectory(), environment: [String: String] = [:]) -> GitRules {
        let git = PlaybookBackup.git()
        func config(_ arguments: [String]) -> String? {
            guard let result = try? ProcessRunner.run(git, ["config"] + arguments, environment: environment, timeout: 10), result.status == 0 else { return nil }
            let value = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        func identity(_ scope: [String]) -> GitIdentity? {
            guard let name = config(scope + ["user.name"]), let email = config(scope + ["user.email"]) else { return nil }
            return GitIdentity(name: name, email: email)
        }
        var rules: [GitRule] = []
        for line in (config(["--global", "--get-regexp", "^includeif\\."]) ?? "").split(separator: "\n") {
            guard let space = line.firstIndex(of: " ") else { continue }
            let key = String(line[..<space])
            let file = expand(line[line.index(after: space)...].trimmingCharacters(in: .whitespaces), home: home)
            guard let folder = folder(fromKey: key, home: home) else { continue }
            rules.append(GitRule(folder: folder, configFile: file, identity: identity(["--file", file])))
        }
        return GitRules(global: identity(["--global"]), rules: rules.sorted { $0.folder.count > $1.folder.count })
    }

    /// `includeif.gitdir:~/Documents/GitHub/personal/.path` → `/Users/me/Documents/GitHub/personal/`.
    /// Only `gitdir:` and `gitdir/i:` folders are understood; other conditions are skipped.
    static func folder(fromKey key: String, home: String) -> String? {
        let lowered = key.lowercased()
        guard lowered.hasPrefix("includeif."), lowered.hasSuffix(".path") else { return nil }
        let condition = String(key.dropFirst("includeif.".count).dropLast(".path".count))
        var pattern: String
        if condition.lowercased().hasPrefix("gitdir/i:") {
            pattern = String(condition.dropFirst("gitdir/i:".count))
        } else if condition.lowercased().hasPrefix("gitdir:") {
            pattern = String(condition.dropFirst("gitdir:".count))
        } else {
            return nil
        }
        pattern = expand(pattern, home: home)
        // `foo/**` and `foo/` both mean everything under foo. Other globs are too loose to follow.
        if pattern.hasSuffix("**") { pattern.removeLast(2) }
        guard !pattern.contains("*"), pattern.hasPrefix("/") else { return nil }
        return pattern.hasSuffix("/") ? pattern : pattern + "/"
    }

    private static func expand(_ path: String, home: String) -> String {
        if path == "~" { return home }
        if path.hasPrefix("~/") { return home + String(path.dropFirst(1)) }
        return path
    }

    /// The rule covering a path, if any.
    func rule(for path: String) -> GitRule? {
        let folder = path.hasSuffix("/") ? path : path + "/"
        return rules.first { folder.hasPrefix($0.folder) }
    }

    /// The identity git gives commits made in repos at this path.
    func identity(for path: String) -> GitIdentity? { rule(for: path)?.identity ?? global }
}

/// Which GitHub login goes with each git rule, and guesses for it. A login can't be read from the
/// rules themselves, and remotes alone can't tell (owners like an organisation aren't logins), so
/// the person confirms it once. The empty folder `""` stands for everything no rule covers.
struct GitAccounts: Equatable, Sendable {
    var rules: GitRules
    /// Signed-in gh logins.
    var logins: [String]
    /// Rule folder (or `""`) to login, as the person confirmed or the guess.
    var loginByFolder: [String: String]

    /// The GitHub owner in a remote URL: `MarcusLai07` from `git@github-personal:MarcusLai07/x.git`
    /// or `https://github.com/MarcusLai07/x.git`.
    static func owner(ofRemote remote: String) -> String? {
        var text = remote
        for prefix in ["https://", "http://", "ssh://"] where text.hasPrefix(prefix) { text.removeFirst(prefix.count) }
        if let at = text.firstIndex(of: "@"), text[..<at].allSatisfy({ $0 != "/" }) { text = String(text[text.index(after: at)...]) }
        let parts = text.split(whereSeparator: { $0 == "/" || $0 == ":" }).map(String.init)
        return parts.count >= 3 ? parts[1] : nil
    }

    /// Guesses each rule's login from the remotes of repos under it: the signed-in login that owns
    /// the most of them. Confirmed choices always win.
    static func guess(rules: GitRules, logins: [String], remotesByPath: [String: String], confirmed: [String: String]) -> [String: String] {
        var counts: [String: [String: Int]] = [:]
        for (path, remote) in remotesByPath {
            guard let owner = owner(ofRemote: remote), let login = logins.first(where: { $0.caseInsensitiveCompare(owner) == .orderedSame }) else { continue }
            let folder = rules.rule(for: path)?.folder ?? ""
            counts[folder, default: [:]][login, default: 0] += 1
        }
        var result: [String: String] = [:]
        for folder in rules.rules.map(\.folder) + [""] {
            if let chosen = confirmed[folder], logins.contains(chosen) {
                result[folder] = chosen
            } else if let best = counts[folder]?.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key })?.key {
                result[folder] = best
            }
        }
        return result
    }

    func login(for path: String) -> String? { loginByFolder[rules.rule(for: path)?.folder ?? ""] }

    /// The identity to sign a backup pushed as this login: the rule that login goes with, else the
    /// global identity.
    func identity(forLogin login: String) -> GitIdentity? {
        if let folder = loginByFolder.first(where: { $0.value == login && !$0.key.isEmpty })?.key,
           let rule = rules.rules.first(where: { $0.folder == folder }) {
            return rule.identity ?? rules.global
        }
        return rules.global
    }

    /// The folders whose rule sends commits to this login, for showing next to it.
    func folders(forLogin login: String) -> [String] {
        loginByFolder.filter { $0.value == login }.map(\.key).sorted()
    }
}

/// Which host a remote reaches, through the owner's SSH aliases (`Host github-mine` with
/// `HostName github.com` in ~/.ssh/config).
enum GitHosts {
    /// `github-mine` from `git@github-mine:Owner/x.git`, `github.com` from an HTTPS URL.
    static func host(ofRemote remote: String) -> String? {
        var text = remote
        for prefix in ["https://", "http://", "ssh://", "git://"] where text.hasPrefix(prefix) { text.removeFirst(prefix.count) }
        if let at = text.firstIndex(of: "@"), text[..<at].allSatisfy({ $0 != "/" }) { text = String(text[text.index(after: at)...]) }
        let host = text.prefix { $0 != ":" && $0 != "/" }
        return host.isEmpty ? nil : host.lowercased()
    }

    /// Each SSH alias's real host name, lowercased. Patterns with wildcards are skipped.
    static func hostNames(sshConfig: String) -> [String: String] {
        var result: [String: String] = [:]
        var current: [String] = []
        for raw in sshConfig.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" || $0 == "=" })
            guard parts.count == 2 else { continue }
            let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \t=\""))
            switch parts[0].lowercased() {
            case "host": current = value.split(separator: " ").map { $0.lowercased() }.filter { !$0.contains("*") && !$0.contains("?") && !$0.hasPrefix("!") }
            case "match": current = []
            case "hostname": for alias in current where result[alias] == nil { result[alias] = value.lowercased() }
            default: break
            }
        }
        return result
    }

    static func readHostNames(home: String = NSHomeDirectory()) -> [String: String] {
        hostNames(sshConfig: (try? String(contentsOfFile: (home as NSString).appendingPathComponent(".ssh/config"), encoding: .utf8)) ?? "")
    }

    /// Whether a remote is on GitHub, directly or through an SSH alias.
    static func isGitHub(_ remote: String, hostNames: [String: String]) -> Bool {
        guard let host = host(ofRemote: remote) else { return false }
        return host == "github.com" || hostNames[host] == "github.com"
    }
}

import Foundation

// Checks for installing graphify from the first-run screen. The download and the programs are
// swapped out, so nothing is installed. Called from main.swift.

func graphifySetupChecks() throws {
    func output(_ status: Int32, _ text: String = "", errors: String = "") -> ProcessOutput {
        ProcessOutput(status: status, output: text, errors: errors, timedOut: false)
    }
    var ran: [[String]] = []
    var environments: [[String: String]] = []
    var steps: [GraphifySetup.Step] = []
    var uv: String?
    var graphify: String?
    func reset(uvAt: String?, graphifyAt: String?) {
        ran = []
        environments = []
        steps = []
        uv = uvAt
        graphify = graphifyAt
    }
    // A Mac where uv's installer puts uv in ~/.local/bin and `uv tool install` adds graphify,
    // unless `failing` says which step goes wrong.
    func effects(failing: String? = nil) -> GraphifySetup.Effects {
        GraphifySetup.Effects(
            download: { url, destination in
                ran.append(["download", url.absoluteString])
                try "#!/bin/sh\n".write(to: destination, atomically: true, encoding: .utf8)
            },
            run: { executable, arguments, environment in
                ran.append([executable] + arguments.map { $0.hasSuffix("/install.sh") ? "install.sh" : $0 })
                environments.append(environment)
                if executable == "/bin/sh" {
                    if failing == "uv" { return output(1, errors: "curl: (6) Could not resolve host") }
                    if failing != "uv-missing" { uv = "/h/.local/bin/uv" }
                } else if arguments.first == "tool" {
                    if failing == "graphify" { return output(2, errors: "line 1\nline 2\nline 3\nline 4\nerror: No solution found when resolving dependencies") }
                    graphify = "/h/.local/bin/graphify"
                }
                return output(0)
            },
            locateUV: { uv },
            locateGraphify: { graphify }
        )
    }
    func failure(_ body: () throws -> String) -> String? {
        do { _ = try body(); return nil } catch { return error.localizedDescription }
    }

    reset(uvAt: nil, graphifyAt: "/opt/homebrew/bin/graphify")
    expectEqual(try GraphifySetup.install(effects: effects()), "/opt/homebrew/bin/graphify", "graphify that's already installed is used as it is")
    expectEqual(ran, [], "and nothing is downloaded or run")

    reset(uvAt: nil, graphifyAt: nil)
    expectEqual(try GraphifySetup.install(effects: effects()) { steps.append($0) }, "/h/.local/bin/graphify", "on a Mac with neither, graphify ends up in ~/.local/bin")
    expectEqual(ran, [
        ["download", "https://astral.sh/uv/install.sh"],
        ["/bin/sh", "install.sh"],
        ["/h/.local/bin/uv", "tool", "install", "graphifyy"],
    ], "uv's own installer runs first, then that uv installs graphifyy")
    expectEqual(environments.first, ["UV_NO_MODIFY_PATH": "1"], "uv's installer leaves shell profiles alone")
    expectEqual(steps, [.uv, .graphify], "each step is shown as it starts")

    reset(uvAt: "/opt/homebrew/bin/uv", graphifyAt: nil)
    expectEqual(try GraphifySetup.install(effects: effects()) { steps.append($0) }, "/h/.local/bin/graphify", "with uv already installed")
    expectEqual(ran, [["/opt/homebrew/bin/uv", "tool", "install", "graphifyy"]], "only graphify is installed, with the uv that's there")
    expectEqual(steps, [.graphify], "and only that step is shown")

    reset(uvAt: nil, graphifyAt: nil)
    let offline = failure { try GraphifySetup.install(effects: effects(failing: "uv")) }
    check(offline?.hasPrefix("uv's installer didn't finish.") == true && offline?.contains("Could not resolve host") == true, "a failed uv install says so, with what the installer said")
    check(!ran.contains { $0.first == "/h/.local/bin/uv" }, "and graphify isn't tried")

    reset(uvAt: nil, graphifyAt: nil)
    check(failure { try GraphifySetup.install(effects: effects(failing: "uv-missing")) }?.hasPrefix("uv's installer finished, but uv isn't") == true, "an installer that ends without uv where it should be is a failure")

    reset(uvAt: "/opt/homebrew/bin/uv", graphifyAt: nil)
    let unresolved = failure { try GraphifySetup.install(effects: effects(failing: "graphify")) }
    check(unresolved?.hasPrefix("graphify didn't install.") == true, "a failed graphify install says so")
    check(unresolved?.contains("No solution found") == true && unresolved?.contains("line 1") == false, "with the last lines it printed, not all of it")

    expectEqual(GraphifySetup.terminalCommands(hasUV: true), ["uv tool install graphifyy"], "with uv, Terminal needs one command")
    expectEqual(GraphifySetup.terminalCommands(hasUV: false), ["curl -LsSf https://astral.sh/uv/install.sh | sh", "~/.local/bin/uv tool install graphifyy"], "without it, Astral's command, then uv by its full path")
    let timedOut = GraphifySetup.lastLines(ProcessOutput(status: 15, output: "", errors: "", timedOut: true))
    expectEqual(timedOut, "It took too long, so it was stopped.", "a step that runs too long says so")
}

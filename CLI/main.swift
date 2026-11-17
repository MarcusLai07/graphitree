import Foundation

// `graphitree`: the knowledge base and playbook from a terminal, a script or an AI tool's shell.
// `graphitree mcp` serves the same answers over MCP.

let usage = """
graphitree: your code knowledge base and playbook, for you and your AI tools.

  graphitree pick <job>            The library to use for a job, such as "toasts" or "date picker"
  graphitree stack                 The default stack for new work
  graphitree how                   How the owner likes to work
  graphitree playbook              The whole playbook
  graphitree ask "<question>"      The code involved in a task. Inside a labelled folder, asks
                                   that folder's graph
      --all                        Ask the whole graph
      --in <graph>                 Ask one of your separate graphs, such as --in Work. Inside a
                                   project, its own graph is used anyway
      --folder <name>              Ask one folder's graph
      --budget <tokens>            How much to return
  graphitree affected "<name>"     What depends on a function, class or file
  graphitree folders               What each main folder is for
  graphitree guide                 The agent guide
  graphitree where                 Which graph and folder graph would be used from here
  graphitree mcp                   Graphitree's MCP server, on stdin and stdout
  graphitree backup [graph]        Back up this knowledge base's graphs as set in Graphitree's
                                   Back Up, or one graph by name
      --if-due                     Only backups whose schedule says they're due
      --dry-run                    Say what would be saved, and write nothing
      --scheduled                  Every knowledge base's due backups
  graphitree background            What Graphitree's background job runs: `graphify update`
                                   with --update <root>, then every due backup
  graphitree uninstall             What uninstalling Graphitree would remove and keep
      --yes                        Uninstall it, moving everything to the Trash. Quit
                                   Graphitree first

  --graph <folder>                 Use this graphify-out folder, or the one inside this folder

"""

var arguments = Array(CommandLine.arguments.dropFirst())
var options: [String: String] = [:]
var flags = Set<String>()
var words: [String] = []
var index = 0
while index < arguments.count {
    let argument = arguments[index]
    switch argument {
    case "--graph", "--folder", "--budget", "--update", "--in":
        guard index + 1 < arguments.count else {
            FileHandle.standardError.write(Data("\(argument) needs a value.\n".utf8))
            exit(2)
        }
        options[argument] = arguments[index + 1]
        index += 2
    case "--all", "--json", "--if-due", "--dry-run", "--scheduled", "--yes":
        flags.insert(argument)
        index += 1
    case "-h", "--help", "help":
        print(usage, terminator: "")
        exit(0)
    default:
        words.append(argument)
        index += 1
    }
}

guard let command = words.first else {
    print(usage, terminator: "")
    exit(2)
}
let text = words.dropFirst().joined(separator: " ")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("graphitree: \(message)\n".utf8))
    exit(1)
}

/// `graphitree backup`: runs Graphitree's backups without the app.
func runBackup() -> Never {
    let started = Date()
    let stamp = { () -> String in ISO8601DateFormatter().string(from: Date()) }
    let confirmed = BackupJob.confirmedLogins()
    let lines: [BackupJob.Line]
    if flags.contains("--scheduled") {
        lines = BackupJob.runScheduled(confirmed: confirmed) { print("\(stamp()) \($0)") }
        // The background job's log only notes runs that did something.
        guard !lines.isEmpty else { exit(0) }
    } else {
        guard let out = GraphLocator.outDirectory(explicit: options["--graph"]) else {
            fail("couldn't find a graph. Run this inside a folder Graphitree maps, or pass --graph <folder>.")
        }
        let jobOptions = BackupJob.Options(only: text.isEmpty ? nil : text, ifDue: flags.contains("--if-due"), dryRun: flags.contains("--dry-run"))
        do {
            lines = try BackupJob.run(outDirectory: out, options: jobOptions, confirmed: confirmed) { print($0) }
        } catch {
            fail(error.localizedDescription)
        }
        if lines.isEmpty {
            print("Nothing is due.")
            exit(0)
        }
    }
    for line in lines {
        print("\(flags.contains("--scheduled") ? stamp() + " " : "")\(line.graph): \(line.failed ? "failed. " : "")\(line.message)")
    }
    if flags.contains("--scheduled") { print("\(stamp()) Done in \(Int(Date().timeIntervalSince(started))) s.") }
    exit(lines.contains(where: \.failed) ? 1 : 0)
}

/// `graphitree background`: the background job. Skips the run while graphify is busy, updates the
/// graph when asked, then runs every due backup. Running here rather than in a shell means macOS
/// asks for Documents access for Graphitree's command.
func runBackground() -> Never {
    let stamp = { () -> String in ISO8601DateFormatter().string(from: Date()) }
    guard !BackupJob.graphifyIsBusy() else {
        print("\(stamp()) graphify is already building, so this run is skipped.")
        exit(0)
    }
    if let root = options["--update"] {
        if let graphify = GraphRebuilder.locateGraphify() {
            print("\(stamp()) graphify update \(root)")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: graphify)
            process.arguments = ["update", root]
            process.currentDirectoryURL = URL(fileURLWithPath: root)
            process.standardOutput = FileHandle.standardOutput
            process.standardError = FileHandle.standardError
            do {
                try process.run()
                process.waitUntilExit()
                print("\(stamp()) graphify finished with exit \(process.terminationStatus)")
                // AI tools ask the folder slices and separate graphs, so they follow the new graph.
                let out = URL(fileURLWithPath: root).appendingPathComponent("graphify-out")
                if process.terminationStatus == 0, FileManager.default.fileExists(atPath: out.appendingPathComponent(FolderFile.fileName).path) {
                    if let failure = GraphSlicing.writeAll(outDirectory: out) {
                        print("\(stamp()) Cutting the graph: \(failure)")
                    } else {
                        print("\(stamp()) Cut the folder graphs and separate graphs again.")
                    }
                }
            } catch {
                print("\(stamp()) graphify couldn't start: \(error.localizedDescription)")
            }
        } else {
            print("\(stamp()) graphify isn't installed, so the graph wasn't updated.")
        }
    }
    // A failed update still lets backups run: one set to "daily" doesn't need a new graph.
    let lines = BackupJob.runScheduled(confirmed: BackupJob.confirmedLogins(), waitsForGraphify: false) { print("\(stamp()) \($0)") }
    for line in lines { print("\(stamp()) \(line.graph): \(line.failed ? "failed. " : "")\(line.message)") }
    exit(lines.contains(where: \.failed) ? 1 : 0)
}

/// `graphitree uninstall`: the same uninstall as Graphitree › Uninstall Graphitree…, for when the
/// app won't open. Without --yes it only says what it would do.
func runUninstall() -> Never {
    // The app this command ships in, or the usual copy when it runs from a build folder.
    let executable = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])).resolvingSymlinksInPath()
    let bundle = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let appURL = bundle.pathExtension == "app" ? bundle : URL(fileURLWithPath: "/Applications/Graphitree.app")
    let plan = UninstallPlan.current(appURL: appURL, settings: GraphLocator.graphitreeSettings)
    guard flags.contains("--yes") else {
        print(plan.text)
        print("\nRun `graphitree uninstall --yes` to do it.")
        exit(0)
    }
    if (try? ProcessRunner.run("/usr/bin/pgrep", ["-x", "Graphitree"], timeout: 5))?.status == 0 {
        fail("Graphitree is open. Quit it first, or use Graphitree › Uninstall Graphitree… in the app.")
    }
    let problems = Uninstaller.perform(plan)
    if problems.isEmpty {
        print("Graphitree is uninstalled. \(Uninstaller.trashNote)")
        exit(0)
    }
    print("Graphitree is uninstalled, except for this:")
    for problem in problems { print("  • " + problem) }
    exit(1)
}

if command == "backup" { runBackup() }
if command == "background" { runBackground() }
if command == "uninstall" { runUninstall() }

guard let out = GraphLocator.outDirectory(explicit: options["--graph"]) else {
    fail("couldn't find a graph. Open one in Graphitree, run this inside a folder Graphitree maps, or pass --graph <folder>.")
}
let source = GraphSource(outDirectory: out)
var tools = GraphitreeTools(source: source, cwd: FileManager.default.currentDirectoryPath)
tools.usageLog = UsageLog.isEnabled ? UsageLog.url : nil
if command == "mcp" { tools.via = "mcp" }

do {
    switch command {
    case "pick":
        guard !text.isEmpty else { fail("say which job, such as: graphitree pick toasts") }
        print(tools.pick(text))
    case "stack":
        print(tools.stack())
    case "how", "habits":
        print(tools.habits())
    case "playbook":
        print(tools.playbookText(), terminator: "")
    case "ask":
        guard !text.isEmpty else { fail("ask a question, such as: graphitree ask \"where are payments handled\"") }
        print(try tools.ask(text, folder: options["--folder"], graph: options["--in"], wholeGraph: flags.contains("--all"), ignoresCuts: flags.contains("--all"), budget: options["--budget"].flatMap(Int.init)))
    case "affected":
        guard !text.isEmpty else { fail("name a function, class or file") }
        print(try tools.affected(text, folder: options["--folder"], graph: options["--in"], ignoresCuts: flags.contains("--all")))
    case "folders":
        print(tools.folders())
    case "guide":
        let guide = out.appendingPathComponent(AgentGuide.fileName)
        guard let content = try? String(contentsOf: guide, encoding: .utf8) else { fail("there's no guide yet. Write it from Graphitree's AI Models panel.") }
        print(content, terminator: "")
    case "where":
        print("Graph: \(AgentGuide.abbreviate(source.graphURL.path))")
        print("Root: \(AgentGuide.abbreviate(source.rootPath))")
        if let cut = GraphCuts.entry(for: FileManager.default.currentDirectoryPath, source: source) {
            print("Here: the \(cut.name) graph, kept apart from your others, so questions go to \(AgentGuide.abbreviate(GraphCuts.url(of: cut, outDirectory: out).path))")
        } else if let slice = GraphLocator.slice(for: FileManager.default.currentDirectoryPath, source: source) {
            print("Here: the \(slice.folder)/ folder, so questions go to \(AgentGuide.abbreviate(slice.path))")
        } else {
            print("Here: questions go to the whole graph")
        }
    case "mcp":
        MCPServer(tools: tools).run()
    default:
        fail("unknown command \(command). Run graphitree --help.")
    }
} catch {
    fail(error.localizedDescription)
}

import Foundation

extension CodingToolState {
    /// AI Models lists the tool under Connected: it's on this Mac with graphify's skill or
    /// Graphitree's pointer in it. (Claude Code is also listed when Graphitree can build with it.)
    var isListed: Bool { isInstalled && (builds || reads) }
}

extension CodingTool {
    /// Whether AI Models lists the tool under Connected: Graphitree can build with it, or graphify's
    /// skill or Graphitree's pointer is in it.
    func isListedConnected(_ state: CodingToolState, home: String) -> Bool {
        if graphitreeBackend != nil, ToolLocator.command(commands, home: home) != nil { return true }
        return state.isListed
    }
}

extension UsageProvider {
    /// The coding tool in AI Models whose usage this is.
    var codingTool: CodingTool? { AICatalog.codingTools.first { $0.id == connectionID } }

    /// The providers whose tool AI Models lists under Connected, in the switch's order. Only these
    /// show on the Usage page, in the menu bar, on the widgets and in alerts. File checks only.
    static func shown(home: String) -> [UsageProvider] {
        allCases.filter { provider in
            guard let tool = provider.codingTool else { return false }
            return tool.isListedConnected(CodingToolState.read(tool, home: home), home: home)
        }
    }
}

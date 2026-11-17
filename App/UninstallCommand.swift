import AppKit

/// Graphitree › Uninstall Graphitree…: shows what goes and what stays, then uninstalls and quits.
/// The plan and the work are in `Shared/Uninstall.swift`.
@MainActor
enum UninstallCommand {
    static func confirmAndUninstall(model: AppModel) {
        guard !model.isRebuilding else {
            let alert = NSAlert()
            alert.messageText = "Graphitree is rebuilding the graph"
            alert.informativeText = "Wait for the rebuild to finish, or stop it, then uninstall."
            alert.runModal()
            return
        }
        let plan = UninstallPlan.current(
            appURL: Bundle.main.bundleURL,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? GraphLocator.graphitreeDefaults,
            settings: .standard
        )
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Uninstall Graphitree?"
        alert.informativeText = plan.summary.map { "• " + $0 }.joined(separator: "\n")
            + "\n\nIt keeps:\n" + plan.kept.map { "• " + $0 }.joined(separator: "\n")
            + "\n\n" + Uninstaller.trashNote
        let uninstall = alert.addButton(withTitle: "Uninstall")
        let cancel = alert.addButton(withTitle: "Cancel")
        uninstall.hasDestructiveAction = true
        // Return cancels, so the destructive choice always takes a click.
        uninstall.keyEquivalent = ""
        cancel.keyEquivalent = "\r"
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        model.stopChat()
        UsageRefresher.shared.stop()
        let problems = Uninstaller.perform(plan)
        if !problems.isEmpty {
            let report = NSAlert()
            report.messageText = "Graphitree is uninstalled, except for this"
            report.informativeText = problems.map { "• " + $0 }.joined(separator: "\n")
            report.runModal()
        }
        // Not NSApp.terminate: quitting normally saves window sizes and state again, into the
        // settings and folders just removed.
        exit(0)
    }
}

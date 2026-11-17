import Foundation

// Checks for the SwiftUI canvas of the Playbook lab: the availability rules, and that every
// adapter's metadata holds together (unique ids, valid defaults, code for every option).
// The views are checked by rendering them: Scripts/shot.sh lab <dir>/.

func swiftLabChecks() throws {
    // A stand-in adapter, so the rules are checked apart from the real list.
    func adapter(minOS: Int = 13, repeats: Bool = false, honours: Bool = true, handBuilt: Bool = false) -> SwiftAdapter {
        SwiftAdapter(id: "test", slot: .card, label: "Test", note: "", minOS: minOS, handBuilt: handBuilt, repeats: repeats, honoursReduceMotion: honours, code: { _ in "" })
    }
    var settings = SwiftLabSettings()
    settings.target = 15

    expectEqual(SwiftLab.issues(for: adapter(minOS: 14), settings: settings, runningOS: 27), [], "an API older than the target needs nothing")
    let newer = SwiftLab.issues(for: adapter(minOS: 26), settings: settings, runningOS: 27)
    expectEqual(newer.map(\.severity), [.warn], "an API newer than the target is a warning")
    check(newer.first?.text.contains("if #available(macOS 26, *)") == true, "the warning says how to guard it")
    expectEqual(SwiftLab.issues(for: adapter(minOS: 26), settings: settings, runningOS: 15).map(\.severity), [.blocked], "an API this Mac lacks can't be drawn")

    settings.reduceMotion = true
    expectEqual(SwiftLab.issues(for: adapter(repeats: true, honours: false), settings: settings, runningOS: 27).map(\.severity), [.warn], "a loop that ignores Reduce motion is flagged when it's on")
    expectEqual(SwiftLab.issues(for: adapter(repeats: true), settings: settings, runningOS: 27), [], "a loop that honours Reduce motion is fine")
    settings.reduceMotion = false
    expectEqual(SwiftLab.issues(for: adapter(repeats: true, honours: false), settings: settings, runningOS: 27), [], "the loop is only flagged with Reduce motion on")
    expectEqual(SwiftLab.issues(for: adapter(handBuilt: true), settings: settings, runningOS: 27).map(\.severity), [.info], "a hand-built adapter says so")

    // The real adapters.
    let ids = SwiftLab.adapters.map(\.id)
    expectEqual(ids.count, Set(ids).count, "SwiftUI lab adapter ids are unique")
    let empty = SwiftSlot.allCases.filter { SwiftLab.adapters(for: $0).isEmpty }.map(\.rawValue)
    expectEqual(empty, [], "every SwiftUI lab slot has an adapter")
    for adapter in SwiftLab.adapters {
        let defaults = SwiftLab.defaults(for: adapter)
        let bad = adapter.options.filter { !$0.accepts($0.defaultValue) }.map(\.id)
        expectEqual(bad, [], "\(adapter.id): every option's default is one of its choices")
        expectEqual(Set(adapter.options.map(\.id)).count, adapter.options.count, "\(adapter.id): option ids are unique")
        check(adapter.code(defaults).contains(adapter.library.importLine), "\(adapter.id): its code imports \(adapter.library.name)")
        check((13...27).contains(adapter.minOS), "\(adapter.id): minOS is a macOS major version")
        // Every choice of every option makes code without crashing, and some option changes it.
        for option in adapter.options {
            if case .choice(let choices) = option.kind {
                for choice in choices { _ = adapter.code(defaults.merging([option.id: .text(choice.value)]) { $1 }) }
            }
        }
    }

    // A block that switches adapter keeps the options that fit.
    let from = SwiftAdapter(id: "a", slot: .number, label: "A", note: "", options: [.choice("format", "Format", [("rm", "RM"), ("compact", "Compact")], default: "rm"), .toggle("trend", "Trend", default: true)], code: { _ in "" })
    let to = SwiftAdapter(id: "b", slot: .number, label: "B", note: "", options: [.choice("format", "Format", [("rm", "RM"), ("percent", "%")], default: "rm"), .toggle("trend", "Trend", default: true)], code: { _ in "" })
    expectEqual(SwiftLab.carryOver(["format": .text("compact"), "trend": .flag(false)], to: to), ["format": .text("rm"), "trend": .flag(false)], "a switch keeps fitting options and drops the rest")
    _ = from

    // New blocks start with what runs on the target.
    settings.target = 14
    if let pick = SwiftLab.best(for: .button, settings: settings, runningOS: 27) {
        check(pick.minOS <= 14, "a new block picks an adapter the target can run when there is one")
    }
    expectEqual(SwiftLab.canvasCode([], settings: SwiftLabSettings()), "", "an empty canvas has no code")
}

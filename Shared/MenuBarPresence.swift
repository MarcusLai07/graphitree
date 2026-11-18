import Foundation

/// Whether Graphitree's menu bar item is in the menu bar: what the person set, unless something
/// outside Graphitree hid the item while the setting was on, such as macOS or a menu bar manager.
///
/// AppKit reports the item's visibility after every change, Graphitree's own included. Those
/// reports never reach the setting. Written there, each one made SwiftUI set the item's visibility
/// again, which AppKit reported again, without end: 0.2.0 hung at launch on that, using all of a
/// core and gigabytes of memory. Graphitree takes an outside hide as it is, rather than showing the
/// item again, which would start a tug of war with whatever hid it.
struct MenuBarPresence: Equatable {
    /// Something outside Graphitree hid the item while the setting was on.
    private(set) var hiddenFromOutside = false

    func isInserted(setting: Bool) -> Bool { setting && !hiddenFromOutside }

    /// AppKit reports the item's visibility. With the setting off, the item is gone by Graphitree's
    /// choice, so an earlier outside hide is forgotten and turning the setting on shows it again.
    mutating func report(visible: Bool, setting: Bool) {
        hiddenFromOutside = setting && !visible
    }

    /// The person changed the setting: their choice wins over an earlier outside hide.
    mutating func settingChanged() {
        hiddenFromOutside = false
    }
}

import SwiftUI

// Graphitree's colours. Apart from the rest of the theme, so the widget extension can use them
// without the window's chrome.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Palette {
    static let ink = Color(hex: 0x04080A)
    static let canvasGlow = Color(hex: 0x1A4A4C)
    static let panel = Color(hex: 0x0D171B)
    static let hairline = Color.white.opacity(0.08)
    /// A card on a panel: a faint tile with a fainter edge.
    static let card = Color.white.opacity(0.035)
    static let cardStroke = Color.white.opacity(0.06)

    static let jade = Color(hex: 0x5ED6B2)
    static let violet = Color(hex: 0x8F7DFF)
    static let coral = Color(hex: 0xFF6B4A)
    static let slate = Color(hex: 0x5F6B72)
    /// Reserved for focus, selection and the one main action.
    static let gold = Color(hex: 0xF1CF86)
    /// Reserved for suspect links.
    static let magenta = Color(hex: 0xFF5FD2)

    /// Matches `series` and `other` in `Web/src/graph.js`.
    static func series(_ slot: Int) -> Color {
        switch slot {
        case 0: return jade
        case 1: return violet
        case 2: return coral
        default: return slate
        }
    }
}

import AppKit

/// Graphitree › About Graphitree: the standard About window, with credits that thank graphify and
/// Astral first, then list every third-party license (Resources/ThirdPartyNotices.txt, written by
/// Scripts/notices.py). Built here rather than from a Credits file, so the text follows dark mode.
@MainActor
enum AboutPanel {
    static func show() {
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits()])
        NSApp.activate()
    }

    static func credits() -> NSAttributedString {
        let size = NSFont.smallSystemFontSize
        let regular = NSFont.systemFont(ofSize: size)
        let bold = NSFont.boldSystemFont(ofSize: size)
        let text = NSMutableAttributedString()
        func add(_ string: String, _ font: NSFont = regular, link: String? = nil) {
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
            if let link, let url = URL(string: link) { attributes[.link] = url }
            text.append(NSAttributedString(string: string, attributes: attributes))
        }

        add("Built on ")
        add("graphify", bold, link: "https://github.com/Graphify-Labs/graphify")
        add(" by Graphify Labs, which makes every graph Graphitree shows, and installed with ")
        add("uv", bold, link: "https://github.com/astral-sh/uv")
        add(" by Astral. Please support their work: star graphify and uv on GitHub, and ")
        add("sponsor graphify", link: "https://github.com/sponsors/safishamsi")
        add(".\n\nAlso uses GRDB.swift, Sparkle, sigma.js, graphology, React and others, with components from ShitUI (")
        add("shitui.in", link: "https://shitui.in")
        add("). Their licenses follow.\n\n")
        if let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
           let notices = try? String(contentsOf: url, encoding: .utf8) {
            add(notices, .monospacedSystemFont(ofSize: size - 1, weight: .regular))
        }
        return text
    }
}

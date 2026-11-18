import AppKit

/// The menu bar's template images: Graphitree's tree alone, or with two small figures stacked
/// beside it (Session over Weekly). Template images, so the menu bar tints them as it tints its
/// own items. Ported from Claude Usage's, with Graphitree's mark in place of Claude's.
enum MenuBarIcon {
    /// The app icon's tree, small: the root node and its three branches.
    private static func drawMark(in rect: NSRect, ctx: CGContext) {
        let unit = rect.width / 16
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit) }
        let root = point(8, 11.6)
        let children = [point(2.6, 3.4), point(8, 2.7), point(13.4, 3.4)]
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineWidth(1.5 * unit)
        for child in children {
            ctx.move(to: root)
            ctx.addCurve(to: child,
                         control1: CGPoint(x: root.x + (child.x - root.x) * 0.1, y: root.y - 4.5 * unit),
                         control2: CGPoint(x: child.x, y: child.y + 3.6 * unit))
        }
        ctx.strokePath()
        ctx.fillEllipse(in: CGRect(x: root.x - 3 * unit, y: root.y - 3 * unit, width: 6 * unit, height: 6 * unit))
        for child in children {
            ctx.fillEllipse(in: CGRect(x: child.x - 2.1 * unit, y: child.y - 2.1 * unit, width: 4.2 * unit, height: 4.2 * unit))
        }
    }

    static let mark: NSImage = {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            drawMark(in: rect.insetBy(dx: 1, dy: 1), ctx: ctx)
            return true
        }
        image.isTemplate = true
        return image
    }()

    /// Session over Weekly, as used or left, the way the Usage page shows them. Empty when
    /// there's no reading, which leaves the mark alone.
    static func figures(_ snapshot: UsageSnapshot?, showLeft: Bool) -> [String] {
        guard let snapshot else { return [] }
        return [snapshot.session, snapshot.weekly].compactMap { $0.map { "\(figure($0, showLeft: showLeft))%" } }
    }

    /// Another tool's first two windows, as used or left.
    static func figures(_ windows: [LimitWindow], showLeft: Bool) -> [String] {
        windows.prefix(2).compactMap { window in
            window.utilization.map { "\(figure(UsageWindow(utilization: $0, resetsAt: window.resetsAt), showLeft: showLeft))%" }
        }
    }

    /// One window's whole percent used or left, as `MetricPresentation` shows it.
    static func figure(_ window: UsageWindow, showLeft: Bool) -> Int {
        let used = Int(window.utilization ?? 0)
        return showLeft ? max(0, 100 - used) : used
    }

    /// The mark with up to two figures stacked to its right, as one template image: a menu bar
    /// label shows a single image.
    static func label(_ figures: [String]) -> NSImage {
        guard !figures.isEmpty else { return mark }
        let font = NSFont.monospacedDigitSystemFont(ofSize: figures.count > 1 ? 9 : 11, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let sizes = figures.map { ($0 as NSString).size(withAttributes: attributes) }
        let textWidth = ceil(sizes.map(\.width).max() ?? 0)
        let lineHeight = ceil(sizes.map(\.height).max() ?? 0)
        let markSide: CGFloat = 16, gap: CGFloat = 3, height: CGFloat = 22
        let image = NSImage(size: NSSize(width: markSide + gap + textWidth, height: height), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            drawMark(in: NSRect(x: 0, y: (height - markSide) / 2, width: markSide, height: markSide), ctx: ctx)
            // Right-aligned lines, centred as a block, the first on top.
            let block = lineHeight * CGFloat(figures.count) - (figures.count > 1 ? 2 : 0)
            var y = (height + block) / 2 - lineHeight
            for (figure, size) in zip(figures, sizes) {
                (figure as NSString).draw(at: NSPoint(x: markSide + gap + textWidth - size.width, y: y), withAttributes: attributes)
                y -= lineHeight - 2
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

import AppKit
import SwiftUI

// The SwiftUI canvas of the Playbook lab, for GraphitreeShots:
//
//   GraphitreeShots lab <out.png> [-labSlots number,chart,banner] [-labSelect 0] [-labTarget 14]
//                                 [-labAppearance light] [-labReduceMotion YES] [-width 1320] [-height 880]
//   GraphitreeShots lab <dir>/    one PNG per slot, with every way of building it on the canvas
//
// `-labSlots` adds one block per slot, built the way the composer picks for a new block.
// `-labAdapters id,id` places those adapters instead. Nothing is saved: the canvas lives in memory.

@MainActor
func shootLab(output: URL) async throws {
    let defaults = UserDefaults.standard
    let settle = defaults.double(forKey: "settle") > 0 ? defaults.double(forKey: "settle") : 2.5
    let size = NSSize(
        width: defaults.double(forKey: "width") > 0 ? defaults.double(forKey: "width") : 1320,
        height: defaults.double(forKey: "height") > 0 ? defaults.double(forKey: "height") : 880
    )
    var settings = SwiftLabSettings()
    if defaults.integer(forKey: "labTarget") > 0 { settings.target = defaults.integer(forKey: "labTarget") }
    if let appearance = defaults.string(forKey: "labAppearance").flatMap(LabAppearance.init(rawValue:)) { settings.appearance = appearance }
    settings.reduceMotion = defaults.bool(forKey: "labReduceMotion")

    if output.hasDirectoryPath {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for slot in SwiftSlot.allCases {
            let canvas = SwiftLabCanvas(defaults: nil)
            canvas.settings = settings
            for adapter in SwiftLab.adapters(for: slot) { canvas.add(adapter.slot); canvas.setAdapter(adapter, for: canvas.blocks.last!.id) }
            canvas.selected = canvas.blocks.first?.id
            try await render(canvas, size: size, settle: settle, to: output.appendingPathComponent("\(slot.rawValue).png"))
        }
        return
    }

    let canvas = SwiftLabCanvas(defaults: nil)
    canvas.settings = settings
    if let ids = defaults.string(forKey: "labAdapters") {
        for id in ids.split(separator: ",").map(String.init) {
            guard let adapter = SwiftLab.adapterByID[id] else { throw ShotError(message: "no adapter \(id)") }
            canvas.add(adapter.slot)
            canvas.setAdapter(adapter, for: canvas.blocks.last!.id)
        }
    } else if let slots = defaults.string(forKey: "labSlots") {
        for name in slots.split(separator: ",").map(String.init) {
            guard let slot = SwiftSlot(rawValue: name) else { throw ShotError(message: "no slot \(name)") }
            canvas.add(slot)
        }
    }
    let select = defaults.object(forKey: "labSelect") as? Int ?? defaults.string(forKey: "labSelect").flatMap(Int.init)
    canvas.selected = select.flatMap { canvas.blocks.indices.contains($0) ? canvas.blocks[$0].id : nil }
    try await render(canvas, size: size, settle: settle, to: output)
}

@MainActor
private func render(_ canvas: SwiftLabCanvas, size: NSSize, settle: Double, to output: URL) async throws {
    let root = SwiftLabComposer(canvas: canvas)
        .frame(width: size.width, height: size.height)
        .background(Palette.panel)
        .preferredColorScheme(.dark)
        .tint(Palette.gold)
    let hosting = NSHostingView(rootView: root)
    hosting.frame = NSRect(origin: .zero, size: size)
    hosting.appearance = NSAppearance(named: .darkAqua)
    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = hosting
    window.isReleasedWhenClosed = false
    try await Task.sleep(for: .seconds(settle))
    hosting.layoutSubtreeIfNeeded()
    guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw ShotError(message: "couldn't make a bitmap") }
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ShotError(message: "couldn't encode the PNG") }
    try png.write(to: output)
    print("wrote \(output.path)")
}

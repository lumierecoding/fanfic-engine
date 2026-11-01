#!/usr/bin/env swift
// Draws the app icon and writes Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift Resources/AppIcon.icns

import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    print("usage: swift scripts/make-icon.swift <output .icns>")
    exit(1)
}
let output = URL(fileURLWithPath: arguments[1])

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels) / 1024

    // macOS icon grid: 824 pt artwork inside a 1024 pt canvas.
    let art = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: art, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(colors: [NSColor(red: 0.98, green: 0.42, blue: 0.55, alpha: 1),
                        NSColor(red: 0.47, green: 0.33, blue: 0.93, alpha: 1)])!
        .draw(in: shape, angle: -60)

    // Two books leaning together, and a heart above them.
    let books = NSImage.SymbolConfiguration(pointSize: 340 * s, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "books.vertical.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(books) {
        let size = symbol.size
        symbol.draw(in: CGRect(x: art.midX - size.width / 2, y: art.minY + 130 * s, width: size.width, height: size.height))
    }
    let heart = NSImage.SymbolConfiguration(pointSize: 150 * s, weight: .bold)
        .applying(.init(paletteColors: [NSColor.white.withAlphaComponent(0.95)]))
    if let symbol = NSImage(systemSymbolName: "heart.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(heart) {
        let size = symbol.size
        symbol.draw(in: CGRect(x: art.midX - size.width / 2, y: art.maxY - 95 * s - size.height, width: size.width, height: size.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let png = drawIcon(pixels: base * scale).representation(using: .png, properties: [:])!
        try png.write(to: iconset.appendingPathComponent(name))
    }
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try p.run()
p.waitUntilExit()
guard p.terminationStatus == 0 else { print("iconutil failed"); exit(1) }
print("Wrote \(output.path)")

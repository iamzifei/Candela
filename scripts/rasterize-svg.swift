// Renders an SVG to a PNG at an exact pixel size, preserving transparency.
//
// Exists because qlmanage — the obvious no-dependency way to rasterise an SVG
// on macOS — composites onto opaque white. That is correct for a QuickLook
// thumbnail and wrong for an app icon: every PNG it produced for the iconset
// had white corners, which the Dock then drew as a white card behind the
// artwork. NSImage reads SVG natively and keeps the vector, so drawing it into
// a cleared bitmap gives real alpha and real geometry at each size rather than
// a downsample of one big render.
//
// Usage:  swift scripts/rasterize-svg.swift <input.svg> <size> <output.png>
import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 4,
      let size = Int(arguments[2]), size > 0 else {
    FileHandle.standardError.write(
        "usage: rasterize-svg.swift <input.svg> <size> <output.png>\n".data(using: .utf8)!)
    exit(2)
}
let inputPath = arguments[1]
let outputPath = arguments[3]

guard let image = NSImage(contentsOfFile: inputPath) else {
    FileHandle.standardError.write("error: cannot read \(inputPath)\n".data(using: .utf8)!)
    exit(1)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else {
    FileHandle.standardError.write("error: cannot allocate bitmap\n".data(using: .utf8)!)
    exit(1)
}
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    FileHandle.standardError.write("error: cannot make context\n".data(using: .utf8)!)
    exit(1)
}
NSGraphicsContext.current = context
// Explicitly clear: a fresh NSBitmapImageRep's contents are undefined, and the
// whole point here is that untouched pixels stay transparent.
let bounds = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
bounds.fill(using: .copy)
context.imageInterpolation = .high
image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("error: cannot encode PNG\n".data(using: .utf8)!)
    exit(1)
}
do {
    try data.write(to: URL(fileURLWithPath: outputPath))
} catch {
    FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
    exit(1)
}

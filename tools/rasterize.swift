import AppKit

/// Rasterises an SVG into a transparent PNG.
///
///   rasterize.swift input.svg output.png [size]
///
/// AppKit has shipped an SVG decoder since Big Sur, so `NSImage` is enough and
/// the build needs no external tooling.
guard CommandLine.arguments.count >= 3 else {
    print("usage: rasterize.swift input.svg output.png [size]")
    exit(1)
}

let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
let size = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3]) ?? 256 : 256

guard let image = NSImage(contentsOfFile: input) else {
    print("cannot load \(input)")
    exit(1)
}

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                           pixelsWide: size,
                           pixelsHigh: size,
                           bitsPerSample: 8,
                           samplesPerPixel: 4,
                           hasAlpha: true,
                           isPlanar: false,
                           colorSpaceName: .deviceRGB,
                           bytesPerRow: 0,
                           bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: rect)
NSGraphicsContext.restoreGraphicsState()

let data = rep.representation(using: .png, properties: [:])
try data!.write(to: URL(fileURLWithPath: output))
print("wrote \(output) (\(size)x\(size))")

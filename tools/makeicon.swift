import Cocoa

// Renders the app icon: a rounded-square gradient with a cursor symbol.
// Usage: swift makeicon.swift <output.png>

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let side: CGFloat = 1024

let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else {
    FileHandle.standardError.write("no graphics context\n".data(using: .utf8)!)
    exit(1)
}

// Background: rounded square, Big Sur style proportions.
let inset: CGFloat = 100
let rect = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
let radius: CGFloat = 190

ctx.saveGState()
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
ctx.clip()

let colors = [
    NSColor(srgbRed: 0.36, green: 0.47, blue: 1.00, alpha: 1).cgColor,
    NSColor(srgbRed: 0.13, green: 0.16, blue: 0.52, alpha: 1).cgColor,
] as CFArray
if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: side),
                           end: CGPoint(x: side, y: 0),
                           options: [])
}
ctx.restoreGState()

// A soft inner edge so the tile reads as a physical object.
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerWidth: radius - 3, cornerHeight: radius - 3, transform: nil))
ctx.setStrokeColor(NSColor(white: 1, alpha: 0.22).cgColor)
ctx.setLineWidth(6)
ctx.strokePath()
ctx.restoreGState()

// Cursor glyph.
let config = NSImage.SymbolConfiguration(pointSize: 400, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))

var symbol: NSImage?
for name in ["cursorarrow.motionlines", "cursorarrow.rays", "cursorarrow"] {
    if let candidate = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        symbol = candidate
        break
    }
}

if let symbol {
    let size = symbol.size
    let scale = min(470 / size.width, 470 / size.height)
    let width = size.width * scale
    let height = size.height * scale
    symbol.draw(in: NSRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height))
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("could not encode png\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: output))
print("wrote \(output) \(rep.pixelsWide)x\(rep.pixelsHigh)")

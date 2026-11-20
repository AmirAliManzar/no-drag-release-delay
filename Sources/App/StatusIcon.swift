import Cocoa

/// The menu bar mark: the same cursor-with-motion-lines glyph the app icon
/// carries, rendered as a template image so it follows both appearances the
/// way native menu bar icons do.
enum StatusIcon {
    static func mark() -> NSImage {
        if let symbol = NSImage(systemSymbolName: "cursorarrow.motionlines",
                                accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .semibold)) {
            symbol.isTemplate = true
            return symbol
        }
        return fallback
    }

    /// Hand-drawn stand-in for `cursorarrow.motionlines`, used only if the
    /// symbol is ever unavailable. Same idea: pointer arrow, two motion lines.
    private static let fallback: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()

            // Pointer arrow, apex at the top left.
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: 4, y: 17))
            arrow.line(to: NSPoint(x: 4, y: 3.4))
            arrow.line(to: NSPoint(x: 8.4, y: 7.2))
            arrow.line(to: NSPoint(x: 10.6, y: 6.6))
            arrow.line(to: NSPoint(x: 6.8, y: 14.6))
            arrow.line(to: NSPoint(x: 5.9, y: 9.4))
            arrow.close()
            arrow.fill()

            // Motion lines, trailing to the top right.
            NSColor.black.setStroke()
            let lines = NSBezierPath()
            lines.lineWidth = 1.6
            lines.lineCapStyle = .round
            lines.move(to: NSPoint(x: 11.5, y: 15.5))
            lines.line(to: NSPoint(x: 13.8, y: 17))
            lines.move(to: NSPoint(x: 13.2, y: 12.6))
            lines.line(to: NSPoint(x: 16.2, y: 14.4))
            lines.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }()
}

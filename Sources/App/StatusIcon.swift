import Cocoa

/// The menu bar mark.
///
/// Drawn by hand rather than picked from SF Symbols so the glyph never changes
/// shape across macOS releases and there is exactly one mark in every state:
/// a missing permission or a pause only dims it (`appearsDisabled`) instead of
/// swapping in a different glyph — a warning triangle in the menu bar reads as
/// something broken, while the setup window explains the actual state.
enum StatusIcon {
    private static let cached = makeMouse()

    static func mouse() -> NSImage { cached }

    private static func makeMouse() -> NSImage {
        // Handler-based drawing stays vector, so the mark is crisp at any
        // scale the status bar or a screenshot tool asks for.
        let image = NSImage(size: NSSize(width: 19, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()

            // The body: a vertical capsule seen from above.
            let body = NSBezierPath(roundedRect: NSRect(x: 5, y: 1.5, width: 10, height: 15),
                                    xRadius: 5, yRadius: 5)
            body.lineWidth = 1.5
            body.stroke()

            // The button split, a third of the way down.
            let split = NSBezierPath()
            split.move(to: NSPoint(x: 5, y: 11.5))
            split.line(to: NSPoint(x: 15, y: 11.5))
            split.lineWidth = 1.25
            split.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }
}

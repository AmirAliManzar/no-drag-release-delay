import Cocoa

/// The menu bar mark is the app's own icon, scaled to bar height.
///
/// It is deliberately not a template image: the icon keeps its colours in both
/// appearances, matching the icon in the Dock and the About panel.
enum StatusIcon {
    static func appIcon() -> NSImage {
        let icon = (NSApp.applicationIconImage.copy() as? NSImage) ?? NSImage()
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }
}

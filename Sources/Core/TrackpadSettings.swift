import Foundation

/// Read-only view of the trackpad preferences that decide whether this app has
/// anything to do.
///
/// The values live in the per-device preference domains rather than in
/// `UserDefaults.standard`, so they are read through `CFPreferences` on demand
/// instead of being mirrored into our own defaults (which would go stale the
/// moment the user changes a setting).
enum TrackpadSettings {
    private static let domains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]

    /// "Use trackpad for dragging" — the parent switch for both tap-to-drag and
    /// three-finger drag.
    static var draggingEnabled: Bool { boolean("Dragging") ?? false }

    /// Drag lock keeps the button pressed after the finger lifts, which is a
    /// feature rather than a delay; the engine must not fight it.
    static var dragLockEnabled: Bool { boolean("DragLock") ?? false }

    static var threeFingerDragEnabled: Bool { boolean("TrackpadThreeFingerDrag") ?? false }

    /// The configuration this app is built for: tap to drag, no lock.
    static var tapDragWithoutLock: Bool { draggingEnabled && !dragLockEnabled && !threeFingerDragEnabled }

    private static func boolean(_ key: String) -> Bool? {
        for domain in domains {
            guard let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) else {
                continue
            }
            if let number = value as? NSNumber {
                return number.boolValue
            }
        }
        return nil
    }
}

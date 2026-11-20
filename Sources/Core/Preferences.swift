import Foundation

/// User-facing settings, backed by `UserDefaults`.
///
/// Presentation (menu bar / Dock) is deliberately *not* stored here as a single
/// enum: the two surfaces are independent, and the only invariant is that the
/// app must remain reachable through at least one of them.
final class Preferences {
    static let shared = Preferences()
    static let didChange = Notification.Name("Preferences.didChange")

    private enum Key {
        static let enabled = "enabled"
        static let showInMenuBar = "showInMenuBar"
        static let showInDock = "showInDock"
        static let completedOnboarding = "completedOnboarding"
    }

    private let store = UserDefaults.standard

    private init() {
        store.register(defaults: [
            Key.enabled: true,
            Key.showInMenuBar: true,
            Key.showInDock: false,
            Key.completedOnboarding: false,
        ])
    }

    var isEnabled: Bool {
        get { store.bool(forKey: Key.enabled) }
        set { store.set(newValue, forKey: Key.enabled); notifyChange() }
    }

    var showInMenuBar: Bool {
        get { store.bool(forKey: Key.showInMenuBar) }
        set { store.set(newValue, forKey: Key.showInMenuBar); notifyChange() }
    }

    var showInDock: Bool {
        get { store.bool(forKey: Key.showInDock) }
        set { store.set(newValue, forKey: Key.showInDock); notifyChange() }
    }

    var completedOnboarding: Bool {
        get { store.bool(forKey: Key.completedOnboarding) }
        set { store.set(newValue, forKey: Key.completedOnboarding); notifyChange() }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}

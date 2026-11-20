import Foundation

/// How the app presents itself in the system menu bar.
enum MenuBarMode: String {
    /// The icon is always visible.
    case always
    /// The icon is visible only while a Setup or About window is on screen.
    case windowOpen
    /// The icon is never visible.
    case never
}

/// User-facing settings, backed by `UserDefaults`.
///
/// Presentation is split across two surfaces: a three-way `menuBarMode` and a
/// `showInDock` boolean. The two are independent, and the only invariant is
/// that the app must remain reachable through at least one of them.
final class Preferences {
    static let shared = Preferences()
    static let didChange = Notification.Name("Preferences.didChange")

    private enum Key {
        static let enabled = "enabled"
        static let menuBarMode = "menuBarMode"
        static let showInDock = "showInDock"
        static let completedOnboarding = "completedOnboarding"
    }

    private let store = UserDefaults.standard

    private init() {
        store.register(defaults: [
            Key.enabled: true,
            Key.menuBarMode: MenuBarMode.always.rawValue,
            Key.showInDock: false,
            Key.completedOnboarding: false,
        ])
    }

    var isEnabled: Bool {
        get { store.bool(forKey: Key.enabled) }
        set { store.set(newValue, forKey: Key.enabled); notifyChange() }
    }

    var menuBarMode: MenuBarMode {
        get { MenuBarMode(rawValue: store.string(forKey: Key.menuBarMode) ?? "") ?? .always }
        set { store.set(newValue.rawValue, forKey: Key.menuBarMode); notifyChange() }
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

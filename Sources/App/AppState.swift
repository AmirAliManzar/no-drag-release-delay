import Cocoa
import Combine
import ServiceManagement

/// Everything the windows observe. A single source of truth keeps the menu bar,
/// the main window and the About panel in sync without a notification fan-out.
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var trusted = AXIsProcessTrusted()
    @Published private(set) var isEnabled = Preferences.shared.isEnabled
    @Published private(set) var menuBarMode = Preferences.shared.menuBarMode
    @Published private(set) var showInDock = Preferences.shared.showInDock
    @Published private(set) var autoUpdate = Preferences.shared.autoUpdate
    @Published private(set) var tapToDrag = TrackpadSettings.draggingEnabled
    @Published private(set) var dragLock = TrackpadSettings.dragLockEnabled
    @Published private(set) var threeFingerDrag = TrackpadSettings.threeFingerDragEnabled
    @Published private(set) var releases = 0
    @Published private(set) var swallowed = 0
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var needsMoveToApplications = Installer.needsMove

    /// Called when a setting that affects the app's presentation changes.
    var onPresentationChange: (() -> Void)?

    private init() {}

    func refresh() {
        assign(\.trusted, AXIsProcessTrusted())
        assign(\.isEnabled, Preferences.shared.isEnabled)
        assign(\.menuBarMode, Preferences.shared.menuBarMode)
        assign(\.showInDock, Preferences.shared.showInDock)
        assign(\.autoUpdate, Preferences.shared.autoUpdate)
        assign(\.tapToDrag, TrackpadSettings.draggingEnabled)
        assign(\.dragLock, TrackpadSettings.dragLockEnabled)
        assign(\.threeFingerDrag, TrackpadSettings.threeFingerDragEnabled)
        assign(\.releases, Engine.shared.releaseCount)
        assign(\.swallowed, Engine.shared.swallowedCount)
        assign(\.launchAtLogin, SMAppService.mainApp.status == .enabled)
    }

    /// A gesture only reaches the engine when both switches agree.
    var isOperational: Bool {
        trusted && isEnabled && tapToDrag && !dragLock && Engine.shared.tapReady
    }

    // MARK: - Mutations

    func setEnabled(_ value: Bool) {
        Preferences.shared.isEnabled = value
        refresh()
    }

    /// The two presentation surfaces are independent by design: hiding both
    /// menu bar and Dock leaves the engine working quietly in the background.
    func setMenuBarMode(_ value: MenuBarMode) {
        Preferences.shared.menuBarMode = value
        refresh()
        onPresentationChange?()
    }

    func setShowInDock(_ value: Bool) {
        Preferences.shared.showInDock = value
        refresh()
        onPresentationChange?()
    }

    func setAutoUpdate(_ value: Bool) {
        Preferences.shared.autoUpdate = value
        refresh()
    }

    func setLaunchAtLogin(_ value: Bool) {
        let service = SMAppService.mainApp
        do {
            if value {
                try service.register()
            } else {
                try service.unregister()
            }
            Log.shared.info("login item: \(value ? "enabled" : "disabled")")
        } catch {
            Log.shared.info("login item failed: \(error.localizedDescription)")
        }
        refresh()
    }

    // MARK: - Setup

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        // Give the system modal a beat to appear, then slide the exact pane in
        // behind it — unless the grant already landed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if !AXIsProcessTrusted() {
                self.openAccessibilitySettings()
            }
        }
    }

    func openAccessibilitySettings() {
        open([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        ])
    }

    func openTrackpadSettings() {
        open([
            "x-apple.systempreferences:com.apple.Trackpad-Settings.extension",
            "x-apple.systempreferences:com.apple.Accessibility-Settings.extension",
        ])
    }

    func openLog() {
        NSWorkspace.shared.activateFileViewerSelecting([Log.shared.url])
    }

    func installToApplications() {
        Installer.moveToApplications()
    }

    private func open(_ candidates: [String]) {
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }

    private func assign<T: Equatable>(_ path: ReferenceWritableKeyPath<AppState, T>, _ value: T) {
        if self[keyPath: path] != value {
            self[keyPath: path] = value
        }
    }
}

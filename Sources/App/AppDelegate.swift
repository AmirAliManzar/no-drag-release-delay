import Cocoa
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var enabledItem: NSMenuItem?
    private var menuBarItem: NSMenuItem?
    private var dockItem: NSMenuItem?
    private var loginItem: NSMenuItem?
    private var permissionItem: NSMenuItem?

    private var pollTimer: Timer?
    private var trusted = AXIsProcessTrusted()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.shared.info("launch \(Bundle.main.shortVersion)")

        AppState.shared.onPresentationChange = { [weak self] in self?.applyPresentation() }
        Engine.shared.onChange = { AppState.shared.refresh() }

        buildStatusMenu()
        applyPresentation()

        Engine.shared.start()

        startPolling()

        if !trusted || !Preferences.shared.completedOnboarding {
            DispatchQueue.main.async { WindowManager.shared.showMain() }
        }

        if !trusted {
            AppState.shared.requestAccessibility()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Engine.shared.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.showMain()
        return true
    }

    // MARK: - Presentation

    private func applyPresentation() {
        let useDock = Preferences.shared.showInDock

        NSApp.setActivationPolicy(useDock ? .regular : .accessory)
        NSApp.mainMenu = useDock ? MainMenu.build() : nil
        syncMenuBarVisibility()

        updateStatusIcon()
        refreshMenu()

        if useDock {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// The status item follows `menuBarMode`; `windowOpen` additionally needs
    /// to know whether a window is on screen, which the 0.5 s poll keeps fresh.
    ///
    /// The item is created and removed rather than toggled through
    /// `NSStatusItem.isVisible`: explicit creation is the one behaviour every
    /// macOS release agrees on, and an item that is only ever created while it
    /// should be on screen cannot linger hidden in the overflow area.
    private func syncMenuBarVisibility() {
        let mode = Preferences.shared.menuBarMode
        let shouldShow = mode == .always
            || (mode == .windowOpen && WindowManager.shared.hasVisibleWindow)

        if shouldShow, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.imagePosition = .imageOnly
            item.menu = statusMenu
            statusItem = item
            updateStatusIcon()
            Log.shared.info("status item shown (mode \(mode.rawValue))")
            // Where macOS actually placed the bar cell — the visible strip or
            // the overflow area — is not queryable through NSStatusItem, but
            // the button's own window knows.
            for delay in [0.5, 3.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let frame = self?.statusItem?.button?.window?.frame else { return }
                    let visible = self?.statusItem?.button?.window?.isVisible ?? false
                    Log.shared.info("status item frame \(Int(frame.origin.x)),\(Int(frame.origin.y)) \(Int(frame.width))x\(Int(frame.height)) visible=\(visible)")
                }
            }
        } else if !shouldShow, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
            Log.shared.info("status item hidden (mode \(mode.rawValue))")
        }
    }

    private func buildStatusMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        enabledItem = add(to: menu, "Enabled", #selector(toggleEnabled))
        menu.addItem(.separator())
        menuBarItem = add(to: menu, "Menu Bar", nil)
        menuBarItem?.submenu = buildMenuBarModeSubmenu()
        dockItem = add(to: menu, "Show in Dock", #selector(toggleDock))
        loginItem = add(to: menu, "Launch at Login", #selector(toggleLogin))
        menu.addItem(.separator())
        permissionItem = add(to: menu, "Grant Accessibility Access…", #selector(requestPermission))
        add(to: menu, "Setup & Test…", #selector(showMain))
        add(to: menu, "Open Diagnostics Log", #selector(openLog))
        menu.addItem(.separator())
        add(to: menu, "About No Drag Release Delay", #selector(showAbout))
        add(to: menu, "Quit No Drag Release Delay", #selector(quit), key: "q")

        statusMenu = menu
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }

        let tooltip: String
        if !Preferences.shared.isEnabled {
            tooltip = "No Drag Release Delay — paused"
        } else if !trusted {
            tooltip = "No Drag Release Delay — open Setup to grant access"
        } else {
            tooltip = "No Drag Release Delay — active"
        }

        button.image = StatusIcon.appIcon()
        button.appearsDisabled = !trusted || !Preferences.shared.isEnabled
        button.toolTip = tooltip
    }

    // MARK: - Menu

    @discardableResult
    private func add(to menu: NSMenu, _ title: String, _ action: Selector?, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    private func buildMenuBarModeSubmenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let modes: [(MenuBarMode, String)] = [
            (.always, "Always"),
            (.windowOpen, "While a Window is Open"),
            (.never, "Never"),
        ]
        for (mode, title) in modes {
            let item = NSMenuItem(title: title,
                                  action: #selector(setMenuBarModeFromMenu(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            submenu.addItem(item)
        }
        return submenu
    }

    private func refreshMenu() {
        enabledItem?.state = Preferences.shared.isEnabled ? .on : .off
        for item in menuBarItem?.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == Preferences.shared.menuBarMode.rawValue ? .on : .off
        }
        dockItem?.state = Preferences.shared.showInDock ? .on : .off
        loginItem?.state = AppState.shared.launchAtLogin ? .on : .off
        permissionItem?.isHidden = trusted
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        Preferences.shared.isEnabled.toggle()
        AppState.shared.refresh()
        updateStatusIcon()
        refreshMenu()
    }

    @objc private func setMenuBarModeFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = MenuBarMode(rawValue: raw) else { return }
        AppState.shared.setMenuBarMode(mode)
    }

    @objc private func toggleDock() {
        AppState.shared.setShowInDock(!Preferences.shared.showInDock)
    }

    @objc private func toggleLogin() {
        AppState.shared.setLaunchAtLogin(!AppState.shared.launchAtLogin)
        refreshMenu()
    }

    @objc private func requestPermission() {
        AppState.shared.requestAccessibility()
    }

    @objc func showMain() {
        WindowManager.shared.showMain()
    }

    @objc func showAbout() {
        WindowManager.shared.showAbout()
    }

    @objc private func openLog() {
        AppState.shared.openLog()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Permissions

    private func startPolling() {
        // Half a second keeps the setup window honest without measurably
        // costing anything; TCC is a cheap syscall.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshTrust()
            self?.syncMenuBarVisibility()
        }

        // The switch lives in System Settings, so the interesting transitions
        // happen while this app is in the background. Re-checking on every
        // application switch makes the UI flip the moment the user returns.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            self?.refreshTrust()
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil,
                                                          queue: .main) { [weak self] _ in
            self?.refreshTrust()
        }
    }

    private func refreshTrust() {
        let now = AXIsProcessTrusted()
        if now != trusted {
            trusted = now
            Log.shared.info("accessibility = \(now)")
            if now {
                Engine.shared.createTapIfPossible()
            }
            updateStatusIcon()
            refreshMenu()
        }

        AppState.shared.refresh()
    }
}

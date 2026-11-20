import Cocoa
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
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

        buildStatusItem()
        buildMenu()
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
        statusItem?.isVisible = Preferences.shared.showInMenuBar

        updateStatusIcon()
        refreshMenu()

        if useDock {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.imagePosition = .imageOnly
        statusItem = item
        updateStatusIcon()
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }

        let name: String
        let tooltip: String

        if !trusted {
            name = "exclamationmark.triangle.fill"
            tooltip = "No Drag Release Delay — accessibility access required"
        } else if !Preferences.shared.isEnabled {
            name = "cursorarrow.slash"
            tooltip = "No Drag Release Delay — paused"
        } else {
            name = "cursorarrow.motionlines"
            tooltip = "No Drag Release Delay — active"
        }

        if let image = NSImage(systemSymbolName: name, accessibilityDescription: tooltip) {
            image.isTemplate = true
            button.image = image
        }
        button.appearsDisabled = trusted && !Preferences.shared.isEnabled
        button.toolTip = tooltip
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        enabledItem = add(to: menu, "Enabled", #selector(toggleEnabled))
        menu.addItem(.separator())
        menuBarItem = add(to: menu, "Show in Menu Bar", #selector(toggleMenuBar))
        dockItem = add(to: menu, "Show in Dock", #selector(toggleDock))
        loginItem = add(to: menu, "Launch at Login", #selector(toggleLogin))
        menu.addItem(.separator())
        permissionItem = add(to: menu, "Grant Accessibility Access…", #selector(requestPermission))
        add(to: menu, "Setup & Test…", #selector(showMain))
        add(to: menu, "Open Diagnostics Log", #selector(openLog))
        menu.addItem(.separator())
        add(to: menu, "About No Drag Release Delay", #selector(showAbout))
        add(to: menu, "Quit No Drag Release Delay", #selector(quit), key: "q")

        statusItem?.menu = menu
    }

    @discardableResult
    private func add(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    private func refreshMenu() {
        enabledItem?.state = Preferences.shared.isEnabled ? .on : .off
        menuBarItem?.state = Preferences.shared.showInMenuBar ? .on : .off
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

    @objc private func toggleMenuBar() {
        AppState.shared.setShowInMenuBar(!Preferences.shared.showInMenuBar)
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
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }

            let now = AXIsProcessTrusted()
            if now != self.trusted {
                self.trusted = now
                Log.shared.info("accessibility = \(now)")
                if now {
                    Engine.shared.createTapIfPossible()
                }
                self.updateStatusIcon()
                self.refreshMenu()
            }

            AppState.shared.refresh()
        }
    }
}

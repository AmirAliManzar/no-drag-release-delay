import Cocoa
import SwiftUI

final class WindowManager {
    static let shared = WindowManager()

    private var mainWindow: NSWindow?
    private var aboutWindow: NSWindow?

    /// True while any app window is on screen — the menu bar's `windowOpen`
    /// mode keys off this so the icon stays within reach while it matters.
    var hasVisibleWindow: Bool {
        (mainWindow?.isVisible ?? false) || (aboutWindow?.isVisible ?? false)
    }

    func showMain() {
        if mainWindow == nil {
            let root = MainView(state: .shared,
                                onAbout: { [weak self] in self?.showAbout() }) { [weak self] in
                Preferences.shared.completedOnboarding = true
                self?.mainWindow?.close()
            }
            let controller = NSHostingController(rootView: root)
            controller.sizingOptions = [.intrinsicContentSize]
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.title = "No Drag Release Delay"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.setContentSize(controller.view.fittingSize)
            window.center()
            mainWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    /// Brings whichever window is already on screen back to the front. The
    /// activation-policy flip pushes open windows behind the frontmost app,
    /// which reads like the app just quit.
    func refocusVisibleWindow() {
        let window = mainWindow?.isVisible == true
            ? mainWindow
            : (aboutWindow?.isVisible == true ? aboutWindow : nil)
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func showAbout() {
        if aboutWindow == nil {
            let controller = NSHostingController(rootView: AboutView())
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable]
            window.title = "About"
            window.isReleasedWhenClosed = false
            window.center()
            aboutWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.makeKeyAndOrderFront(nil)
    }
}

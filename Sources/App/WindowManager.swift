import Cocoa
import SwiftUI

final class WindowManager {
    static let shared = WindowManager()

    private var mainWindow: NSWindow?
    private var aboutWindow: NSWindow?

    func showMain() {
        if mainWindow == nil {
            let root = MainView(state: .shared) { [weak self] in
                Preferences.shared.completedOnboarding = true
                self?.mainWindow?.close()
            }
            let controller = NSHostingController(rootView: root)
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

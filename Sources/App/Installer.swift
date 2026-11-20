import Cocoa

/// Handles the one thing a drag-and-drop installer cannot do on the user's
/// behalf: putting the bundle where it belongs.
///
/// Launching straight from a disk image or the Downloads folder works, but the
/// accessibility grant is keyed to the bundle path, so a later move would ask
/// for it again. Offering the copy up front avoids that second prompt.
enum Installer {
    static var needsMove: Bool {
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        if path.hasPrefix("/Applications/") { return false }
        if path.contains("/build/") { return false }
        return true
    }

    static func moveToApplications() {
        let source = Bundle.main.bundleURL
        let destination = URL(fileURLWithPath: "/Applications")
            .appendingPathComponent(source.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            Log.shared.info("installed to \(destination.path)")
            NSWorkspace.shared.open(destination)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
        } catch {
            Log.shared.info("install failed: \(error.localizedDescription)")
            NSWorkspace.shared.activateFileViewerSelecting([source])
        }
    }
}

import Foundation

/// Append-only diagnostic log at `~/Library/Logs/NoDragReleaseDelay.log`.
///
/// Writes are asynchronous and serialised, so the event-tap callback never
/// touches the file system and never blocks input.
final class Log {
    static let shared = Log()

    let url: URL

    private let queue = DispatchQueue(label: "com.amiralimanzar3.NoDragReleaseDelay.log")
    private let formatter: DateFormatter
    private var handle: FileHandle?

    private init() {
        let directory = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        url = directory.appendingPathComponent("NoDragReleaseDelay.log")

        formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"

        rotateIfNeeded()
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try? FileHandle(forWritingTo: url)
        _ = try? handle?.seekToEnd()
    }

    func info(_ message: String) {
        let date = Date()
        queue.async { [weak self] in
            guard let self, let handle = self.handle else { return }
            let line = "[\(self.formatter.string(from: date))] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            try? handle.write(contentsOf: data)
        }
    }

    private func rotateIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? UInt64, size > 1_000_000 else { return }

        let previous = url.deletingLastPathComponent().appendingPathComponent("NoDragReleaseDelay.old.log")
        try? FileManager.default.removeItem(at: previous)
        try? FileManager.default.moveItem(at: url, to: previous)
    }
}

import Cocoa
import Combine

/// Checks GitHub releases and updates the app in place.
///
/// GitHub's releases feed is the update feed — no Sparkle, no external
/// dependencies. When a newer `tag_name` appears, the matching `.pkg` is
/// downloaded and applied through `installer` with administrator privileges;
/// the package's postinstall script relaunches the fresh bundle. The signing
/// identity never changes between releases, so the Accessibility grant
/// survives every update.
final class Updater: ObservableObject {
    static let shared = Updater()

    enum Phase: Equatable {
        case idle
        case checking
        case available(String)   // a newer release, e.g. "1.3.0"
        case downloading(String)
        case installing(String)
        case upToDate
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle

    private let repoBase = "https://github.com/AmirAliManzar/no-drag-release-delay"
    private let apiURL = URL(string: "https://api.github.com/repos/AmirAliManzar/no-drag-release-delay/releases/latest")!
    private var autoTimer: Timer?

    private init() {
        rescheduleAutoCheck()
        NotificationCenter.default.addObserver(forName: Preferences.didChange,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            self?.rescheduleAutoCheck()
        }
    }

    var currentVersion: String { Bundle.main.shortVersion }

    /// Self-updating replaces the bundle in /Applications, so it is offered
    /// only when the app actually runs from there; anywhere else, the check
    /// still works but hands off to the releases page.
    var canSelfUpdate: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }

    var isBusy: Bool {
        switch phase {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    // MARK: - Checking

    func checkForUpdates() {
        guard !isBusy else { return }
        phase = .checking

        Task.detached { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(from: self?.apiURL ?? URL(fileURLWithPath: "/"))
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let tag = json?["tag_name"] as? String,
                      let assets = json?["assets"] as? [[String: Any]] else {
                    throw URLError(.cannotParseResponse)
                }
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                guard Self.isNewer(latest, than: self?.currentVersion ?? "") else {
                    DispatchQueue.main.async { self?.phase = .upToDate }
                    return
                }
                let assetName = "NoDragReleaseDelay-\(latest)-\(Self.arch).pkg"
                guard assets.contains(where: { ($0["name"] as? String) == assetName }) else {
                    DispatchQueue.main.async { self?.phase = .failed("no build for this architecture") }
                    return
                }
                DispatchQueue.main.async { self?.phase = .available(latest) }
            } catch {
                DispatchQueue.main.async { self?.phase = .failed("network") }
            }
        }
    }

    // MARK: - Installing

    func installUpdate() {
        guard case .available(let version) = phase else { return }
        guard canSelfUpdate else {
            NSWorkspace.shared.open(URL(string: "\(repoBase)/releases/latest")!)
            phase = .idle
            return
        }
        phase = .downloading(version)

        let assetURL = URL(string: "\(repoBase)/releases/download/v\(version)/NoDragReleaseDelay-\(version)-\(Self.arch).pkg")!
        Task.detached { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(from: assetURL)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                let pkg = FileManager.default.temporaryDirectory
                    .appendingPathComponent("NoDragReleaseDelay-\(version)-\(Self.arch).pkg")
                try data.write(to: pkg)
                DispatchQueue.main.async { self?.runInstaller(pkg: pkg, version: version) }
            } catch {
                DispatchQueue.main.async { self?.phase = .failed("download") }
            }
        }
    }

    /// `installer` replaces the root-owned bundle in /Applications and the
    /// package's postinstall relaunches; a safety relaunch runs regardless so
    /// a stale process can never outlive its own bundle.
    private func runInstaller(pkg: URL, version: String) {
        phase = .installing(version)

        let osascript = Process()
        osascript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osascript.arguments = ["-e",
                               "do shell script \"installer -pkg '\(pkg.path)' -target /\" with administrator privileges"]
        osascript.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self, self.phase == .installing(version) else { return }
                if process.terminationStatus != 0 {
                    self.phase = .available(version)
                    return
                }
                let relaunch = Process()
                relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
                relaunch.arguments = ["-c",
                                      "sleep 0.3; pkill -x NoDragReleaseDelay 2>/dev/null; sleep 0.3; open '/Applications/No Drag Release Delay.app'"]
                try? relaunch.run()
                NSApp.terminate(nil)
            }
        }
        try? osascript.run()
    }

    // MARK: - Auto check

    func rescheduleAutoCheck() {
        autoTimer?.invalidate()
        autoTimer = nil
        guard Preferences.shared.autoUpdate, canSelfUpdate else { return }

        // First pass shortly after launch, then every six hours.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard Preferences.shared.autoUpdate else { return }
            self?.checkForUpdates()
        }
        autoTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
    }

    // MARK: - Helpers

    private static var arch: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "arm64"
        #endif
    }

    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidates = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let currents = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(candidates.count, currents.count) {
            let new = index < candidates.count ? candidates[index] : 0
            let old = index < currents.count ? currents[index] : 0
            if new != old { return new > old }
        }
        return false
    }
}

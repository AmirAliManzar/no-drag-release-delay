import Foundation

enum Author {
    static let name = "Amir Ali Manzar"

    /// The canonical repository. Used by the About panel and by the updater-free
    /// "source" link, so it must stay in sync with the README.
    static let repository = URL(string: "https://github.com/amiralimanzar/no-drag-release-delay")!

    struct Link: Identifiable {
        let id: String
        let title: String
        let handle: String
        let url: URL
        let symbol: String
        let tint: String
    }

    static let links: [Link] = [
        Link(id: "github",
             title: "GitHub",
             handle: "amiralimanzar",
             url: URL(string: "https://github.com/amiralimanzar")!,
             symbol: "chevron.left.forwardslash.chevron.right",
             tint: "#24292F"),
        Link(id: "telegram",
             title: "Telegram",
             handle: "amiralimanzar",
             url: URL(string: "https://t.me/amiralimanzar")!,
             symbol: "paperplane.fill",
             tint: "#229ED9"),
        Link(id: "bale",
             title: "Bale",
             handle: "amiralimanzar3",
             url: URL(string: "https://ble.ir/amiralimanzar3")!,
             symbol: "bubble.left.fill",
             tint: "#00A693"),
        Link(id: "linkedin",
             title: "LinkedIn",
             handle: "amiralimanzar",
             url: URL(string: "https://www.linkedin.com/in/amiralimanzar")!,
             symbol: "briefcase.fill",
             tint: "#0A66C2"),
    ]
}

extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}

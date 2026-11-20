import Foundation

enum Author {
    static let name = "Amir Ali Manzar"

    /// The canonical repository. Used by the About panel and by the updater-free
    /// "source" link, so it must stay in sync with the README.
    static let repository = URL(string: "https://github.com/AmirAliManzar/no-drag-release-delay")!

    struct Link: Identifiable {
        /// Matches a vector file in `Resources/BrandIcons/<id>.svg`.
        let id: String
        let title: String
        let handle: String
        let url: URL
        let tint: String
        /// SF Symbol fallback for links that have no bundled brand mark.
        let symbol: String?

        init(id: String, title: String, handle: String, url: URL, tint: String, symbol: String? = nil) {
            self.id = id
            self.title = title
            self.handle = handle
            self.url = url
            self.tint = tint
            self.symbol = symbol
        }
    }

    static let links: [Link] = [
        Link(id: "email",
             title: "Email",
             handle: "contact@amiralimanzar.ir",
             url: URL(string: "mailto:contact@amiralimanzar.ir")!,
             tint: "#1E88E5",
             symbol: "envelope.fill"),
        Link(id: "github",
             title: "GitHub",
             handle: "amiralimanzar",
             url: URL(string: "https://github.com/AmirAliManzar")!,
             tint: "#24292F"),
        Link(id: "telegram",
             title: "Telegram",
             handle: "amiralimanzar1",
             url: URL(string: "https://t.me/amiralimanzar1")!,
             tint: "#229ED9"),
        Link(id: "instagram",
             title: "Instagram",
             handle: "amiralimanzar.ir",
             url: URL(string: "https://instagram.com/amiralimanzar.ir")!,
             tint: "#E4405F"),
        Link(id: "bale",
             title: "Bale",
             handle: "amiralimanzar1",
             url: URL(string: "https://ble.ir/amiralimanzar1")!,
             tint: "#00B894"),
        Link(id: "linkedin",
             title: "LinkedIn",
             handle: "amirali-manzar",
             url: URL(string: "https://www.linkedin.com/in/amirali-manzar")!,
             tint: "#0A66C2"),
    ]
}

extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}

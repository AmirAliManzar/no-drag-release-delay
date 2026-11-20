import SwiftUI
import AppKit

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 84, height: 84)

            VStack(spacing: 2) {
                Text("No Drag Release Delay")
                    .font(.system(size: 18, weight: .bold))
                Text("Version \(Bundle.main.shortVersion) · MIT")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Text("Releases a tap-drag the moment the last finger leaves the trackpad, so a drop lands immediately instead of a few hundred milliseconds later.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            Divider()

            VStack(spacing: 1) {
                ForEach(Author.links) { link in
                    BrandRow(link: link)
                }
            }

            Divider()

            VStack(spacing: 2) {
                Text(Author.name)
                    .font(.system(size: 12, weight: .semibold))
                Text("Designed and written with Claude")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Button {
                    NSWorkspace.shared.open(Author.repository)
                } label: {
                    Text("Source code")
                        .font(.system(size: 9))
                        .underline()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

                Text("© 2026 \(Author.name) · MIT")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}

private final class HoverState: ObservableObject {
    @Published var isHovering = false
}

private struct BrandRow: View {
    let link: Author.Link
    @StateObject private var hover = HoverState()

    var body: some View {
        Button {
            NSWorkspace.shared.open(link.url)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(hex: link.tint).opacity(0.15))
                    brandImage
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 0) {
                    Text(link.title)
                        .font(.system(size: 11, weight: .medium))
                    Text(link.handle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hover.isHovering ? Color.primary.opacity(0.05) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover.isHovering = $0 }
    }

    /// The brand's own mark, bundled as a vector and rendered as a template so
    /// it follows the accent colour and both appearances.
    private var brandImage: some View {
        Group {
            if let image = Bundle.main.brandIcon(link.id) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(Color(hex: link.tint))
            } else {
                Image(systemName: link.symbol ?? "link")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: link.tint))
            }
        }
    }
}

extension Bundle {
    /// Loads `Resources/BrandIcons/<id>.svg`. AppKit has shipped an SVG decoder
    /// since Big Sur; the mark is marked as a template so callers can tint it.
    func brandIcon(_ id: String) -> NSImage? {
        guard let url = url(forResource: id, withExtension: "svg", subdirectory: "BrandIcons"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = true
        return image
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255,
                  opacity: 1)
    }
}

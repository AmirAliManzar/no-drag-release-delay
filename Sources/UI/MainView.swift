import SwiftUI

struct MainView: View {
    @ObservedObject var state: AppState
    var onAbout: () -> Void = {}
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if state.needsMoveToApplications {
                moveBanner
            }
            section("Setup") { setup }
            section("Options") { options }
            DragTestCard()
            section("About") { aboutLinks }
            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 14)
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("No Drag Release Delay")
                    .font(.system(size: 18, weight: .semibold))
                Text("A tap-drag ends the instant the last finger lifts.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            StatusPill(active: state.isOperational,
                       text: statusText)
        }
    }

    private var statusText: String {
        if !state.isEnabled { return "Paused" }
        if !state.trusted { return "Needs permission" }
        if !state.tapToDrag { return "Tap to drag is off" }
        if state.dragLock { return "Drag lock is on" }
        return Engine.shared.tapReady ? "Active" : "Starting…"
    }

    // MARK: - Move banner

    private var moveBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("Move to Applications")
                    .font(.system(size: 12, weight: .semibold))
                Text("Keeps the permission grant stable across updates.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Install") { state.installToApplications() }
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
    }

    // MARK: - Setup

    private var setup: some View {
        VStack(spacing: 0) {
            StepRow(done: state.trusted,
                    index: 1,
                    title: "Accessibility access",
                    detail: state.trusted
                        ? "Granted — the app can watch the trackpad and post the release."
                        : "Needed so the app can watch the trackpad and post the release.",
                    actionTitle: state.trusted ? "Open Settings" : "Grant",
                    action: state.requestAccessibility)

            if !state.trusted {
                accessGuide
            }

            divider

            StepRow(done: state.tapToDrag,
                    index: 2,
                    title: "Tap to drag",
                    detail: state.tapToDrag
                        ? "On — double-tap and hold to drag."
                        : "In Trackpad → Trackpad Options…, set “Dragging style” to “Without Drag Lock”.",
                    actionTitle: "Open",
                    action: state.openTrackpadSettings)

            divider

            StepRow(done: !state.dragLock,
                    index: 3,
                    title: "Drag lock off",
                    detail: state.dragLock
                        ? "On — the app deliberately leaves releases alone."
                        : "Off — releases are handled by this app.",
                    actionTitle: state.dragLock ? "Open" : nil,
                    action: state.dragLock ? state.openTrackpadSettings : nil)
        }
        .background(card)
    }

    /// The permission dance in System Settings, spelled out: the exact panel
    /// opens with the button above, these are the steps inside it, and the
    /// step above ticks itself off the moment the grant lands (the 0.5 s poll
    /// notices without a restart).
    private var accessGuide: some View {
        VStack(alignment: .leading, spacing: 3) {
            guideLine("Press + in the Accessibility list — or drag the app from Applications into it.")
            guideLine("Pick “No Drag Release Delay” and switch its toggle on.")
            guideLine("This window ticks itself off the moment it is granted.")
        }
        .padding(.leading, 40)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
    }

    private func guideLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Options

    private var options: some View {
        VStack(alignment: .leading, spacing: 0) {
            toggle("Enabled", isOn: state.isEnabled, set: state.setEnabled)
            divider
            modeRow
            divider
            toggle("Show in Dock", isOn: state.showInDock, set: state.setShowInDock)
            divider
            toggle("Launch at login", isOn: state.launchAtLogin, set: state.setLaunchAtLogin)
        }
        .background(card)
    }

    private var modeRow: some View {
        HStack {
            Text("Menu bar").font(.system(size: 12))
            Spacer(minLength: 12)
            // Natural size: a fixed frame smaller than the three segments
            // makes the control overflow the card padding.
            Picker(selection: Binding(get: { state.menuBarMode }, set: state.setMenuBarMode)) {
                Text("Always").tag(MenuBarMode.always)
                Text("Window open").tag(MenuBarMode.windowOpen)
                Text("Never").tag(MenuBarMode.never)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: - Footer

    /// The developer summary and its links live in the window itself, so
    /// reaching About never depends on finding the status item.
    private var aboutLinks: some View {
        HStack(spacing: 12) {
            Text("Amir Ali Manzar")
                .font(.system(size: 10, weight: .medium))
            ForEach(Author.links) { link in
                BrandLinkButton(link: link)
            }
            Spacer(minLength: 8)
            Button("More…") { onAbout() }
                .buttonStyle(.borderless)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("\(state.releases) released")
            if state.swallowed > 0 {
                Text("·")
                Text("\(state.swallowed) duplicate clicks prevented")
            }
            Spacer()
            Button("Log") { state.openLog() }
                .buttonStyle(.borderless)
                .font(.system(size: 10))
            Button("Done", action: onDone)
                .keyboardShortcut(.defaultAction)
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }

    // MARK: - Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            content()
        }
    }

    /// macOS settings row: label on the left edge, control on the right edge.
    private func toggle(_ title: String, isOn: Bool, set: @escaping (Bool) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 12))
            Spacer(minLength: 12)
            Toggle("", isOn: Binding(get: { isOn }, set: set))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var divider: some View {
        Divider().padding(.leading, 12)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07))
            )
    }
}

// MARK: - Rows

private struct StatusPill: View {
    let active: Bool
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(active ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.primary.opacity(0.06))
        )
    }
}

private struct StepRow: View {
    let done: Bool
    let index: Int
    let title: String
    let detail: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(done ? Color.green.opacity(0.16) : Color.orange.opacity(0.16))
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.green)
                } else {
                    Text("\(index)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.orange)
                }
            }
            .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// A compact tap-through mark for one of the author's links; brand marks come
/// from the bundled vectors, the email falls back to its SF Symbol.
private struct BrandLinkButton: View {
    let link: Author.Link

    var body: some View {
        Button {
            NSWorkspace.shared.open(link.url)
        } label: {
            mark
                .frame(width: 15, height: 15)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(link.title) — \(link.handle)")
    }

    @ViewBuilder private var mark: some View {
        if link.id == "email", let symbol = link.symbol {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        } else if let image = Bundle.main.brandIcon(link.id) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Image(systemName: link.symbol ?? "link")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

/// A drag target that makes the difference visible: with the app working the
/// card stops the moment the finger lifts, without it the card keeps following
/// the cursor for a few frames after the release.
///
/// State lives in an `ObservableObject` rather than `@State` because SwiftUI's
/// state macros ship with Xcode's plugin host, and this project builds with the
/// Command Line Tools alone.
private final class DragTestModel: ObservableObject {
    @Published var offset: CGSize = .zero
    @Published var isDragging = false
    @Published var drops = 0
}

private struct DragTestCard: View {
    @StateObject private var model = DragTestModel()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(model.isDragging ? 0.16 : 0.08))

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.35),
                              style: StrokeStyle(lineWidth: 1, dash: [5, 4]))

            HStack(spacing: 10) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.isDragging ? "Now let go…" : "Try it here")
                        .font(.system(size: 12, weight: .semibold))
                    Text(model.drops == 0
                         ? "Double-tap, drag this card, then lift your finger."
                         : "Released \(model.drops) time\(model.drops == 1 ? "" : "s"). Drag again.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 66)
        .offset(model.offset)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    model.isDragging = true
                    model.offset = value.translation
                }
                .onEnded { _ in
                    model.isDragging = false
                    model.drops += 1
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        model.offset = .zero
                    }
                }
        )
    }
}

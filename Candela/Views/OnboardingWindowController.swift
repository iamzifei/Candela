import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted by Settings > "Show Welcome Guide"; AppDelegate closes the panel and opens the guide.
    static let candelaShowWelcomeGuide = Notification.Name("candela.showWelcomeGuide")
}

/// One page of the welcome guide.
struct GuidePage {
    let icon: String   // SF Symbol name
    let title: String
    let body: String
    /// Cropped screenshot (Resources/Guide/guide-N.jpg, demo data), nil when running unbundled.
    var image: NSImage?
}

final class OnboardingModel: ObservableObject {
    @Published var page = 0
}

/// First-run welcome guide: five short pages, each with a screenshot of the
/// panel page it explains. Shown once per `Onboarding.currentVersion` and
/// reopenable from Settings > "Show Welcome Guide".
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    /// "Open Candela" on the last page: close the guide and open the panel.
    var onOpenPanel: (() -> Void)?

    private let model = OnboardingModel()
    private var window: NSWindow?
    private var keyMonitor: Any?

    /// Called at launch: shows the guide only if this version hasn't been seen.
    func showIfNeeded() {
        let seen = UserDefaults.standard.integer(forKey: Onboarding.seenKey)
        guard Onboarding.shouldShow(seenVersion: seen) else { return }
        show()
    }

    func show() {
        // Already open: bring it forward and keep the page.
        if let window, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        // Marked seen as soon as it is shown: closing early is a clear "not now",
        // and it stays one click away in Settings.
        UserDefaults.standard.set(Onboarding.currentVersion, forKey: Onboarding.seenKey)
        model.page = 0

        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(origin: .zero, size: OnboardingView.size),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.title = String(localized: "Welcome to Candela")
            w.isReleasedWhenClosed = false
            w.collectionBehavior.insert(.moveToActiveSpace)
            w.delegate = self
            window = w
        }
        window?.contentView = NSHostingView(rootView: OnboardingView(
            model: model,
            pages: Self.pages(),
            onFinish: { [weak self] in self?.finish() },
            onClose: { [weak self] in self?.window?.close() }
        ))
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    private func finish() {
        window?.close()
        // Let the guide go away before the panel opens.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.onOpenPanel?()
        }
    }

    // Left/right arrows page, Return = next (or "Open Candela" on the last page), Esc closes.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Delivered on the main thread, so the main actor is current. Only the
            // key code crosses into the isolated block (NSEvent is not Sendable).
            let code = event.keyCode
            let handled = MainActor.assumeIsolated { self?.handleKey(code) ?? false }
            return handled ? nil : event
        }
    }

    /// Returns true when the key was consumed.
    private func handleKey(_ code: UInt16) -> Bool {
        guard let window, window.isKeyWindow else { return false }
        switch code {
        case 123: model.page = Onboarding.page(model.page, step: -1)
        case 124: model.page = Onboarding.page(model.page, step: 1)
        case 36, 76:
            if model.page == Onboarding.pageCount - 1 {
                finish()
            } else {
                model.page = Onboarding.page(model.page, step: 1)
            }
        case 53: window.close()
        default: return false
        }
        return true
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = nil
        }
    }

    // MARK: content

    private static func screenshot(_ n: Int) -> NSImage? {
        Bundle.main.url(forResource: "guide-\(n)", withExtension: "jpg").flatMap(NSImage.init(contentsOf:))
    }

    // Literal keys on purpose: Xcode's string extraction only sees literals.
    static func pages() -> [GuidePage] {
        // swiftlint:disable line_length
        let pages: [GuidePage] = [
            GuidePage(icon: "sun.max", title: String(localized: "Welcome to Candela"),
                      body: String(localized: "Candela lives in your menu bar. Click its icon to open the panel: every connected display gets its own brightness slider. A Software tag means that display has no DDC support, so Candela dims it in software.")),
            GuidePage(icon: "slider.horizontal.3", title: String(localized: "One slider for the whole desk"),
                      body: String(localized: "Combined moves every display together. Below it, switch Dark Mode, Night Shift and True Tone, or save your current setup as a preset.")),
            GuidePage(icon: "display", title: String(localized: "Sharp, readable resolution"),
                      body: String(localized: "Open a display to change its resolution and refresh rate. Candela lists the sharp 2× modes macOS hides on third-party monitors. Combined brightness sets where this display sits when the combined slider is at the bottom, so two panels can match.")),
            GuidePage(icon: "wrench.and.screwdriver", title: String(localized: "Tools for your desk"),
                      body: String(localized: "Tools holds Keep Awake, Virtual Displays, iPad Display and Arrange Displays.")),
            GuidePage(icon: "gearshape", title: String(localized: "Brightness keys and settings"),
                      body: String(localized: "Settings is where you choose what the brightness keys control. Sending them to external displays needs Accessibility access: turn on the switch under Brightness Keys and macOS asks once. Language and Launch at Login are here too."))
        ]
        // swiftlint:enable line_length
        return pages.enumerated().map { i, page in
            var page = page
            page.image = screenshot(i + 1)
            return page
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let pages: [GuidePage]
    let onFinish: () -> Void
    let onClose: () -> Void

    private var isLast: Bool { model.page == pages.count - 1 }

    var body: some View {
        let page = pages[min(model.page, pages.count - 1)]
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 28) {
                // Fixed frame so the text doesn't jump between pages.
                ZStack {
                    if let image = page.image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: Self.imageSize.width, height: Self.imageSize.height)

                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: page.icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text(page.title)
                        .font(.system(size: 24, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(page.body)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 20)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 12)

            Divider()
            HStack {
                if !isLast {
                    Button(String(localized: "Skip"), action: onClose)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == model.page ? Color.accentColor : Color.primary.opacity(0.2))
                            .frame(width: 7, height: 7)
                            .onTapGesture { model.page = i }
                    }
                }
                .accessibilityHidden(true)
                Spacer()
                if model.page > 0 {
                    Button(String(localized: "Back")) { model.page = Onboarding.page(model.page, step: -1) }
                }
                if isLast {
                    Button(String(localized: "Open Candela"), action: onFinish)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(String(localized: "Next")) { model.page = Onboarding.page(model.page, step: 1) }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    static let imageSize = CGSize(width: 250, height: 380)
    static let size = CGSize(width: 720, height: 470)
}

// MARK: - Settings row

/// "Show Welcome Guide" row at the bottom of Settings.
struct WelcomeGuideRow: View {
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            MenuItemIcon(systemName: "questionmark.circle", color: .teal, active: true)
                .accessibilityHidden(true)
            Text("Show Welcome Guide")
                .font(.body)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .menuRowHover(isHovered)
        .contentShape(Rectangle())
        .onTapGesture { NotificationCenter.default.post(name: .candelaShowWelcomeGuide, object: nil) }
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Show Welcome Guide"))
        .accessibilityAddTraits(.isButton)
    }
}

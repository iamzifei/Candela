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
    /// Language the guide is drawn in (a code from `Onboarding.languages`).
    @Published var language = "en"
    /// Language the rest of the UI was launched in; the picker says the rest
    /// follows on next launch whenever `language` differs from it.
    var launchLanguage = "en"
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
            bringToFront()
            return
        }
        // Marked seen as soon as it is shown: closing early is a clear "not now",
        // and it stays one click away in Settings.
        UserDefaults.standard.set(Onboarding.currentVersion, forKey: Onboarding.seenKey)
        model.page = 0
        model.launchLanguage = Onboarding.bestLanguage(preferred: Bundle.main.preferredLocalizations)
        // An explicit in-app choice wins; otherwise the best match for the system's list.
        model.language = AppLanguage.current == .system
            ? Onboarding.bestLanguage(preferred: Locale.preferredLanguages)
            : AppLanguage.current.rawValue

        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(origin: .zero, size: OnboardingView.size),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
                        w.isReleasedWhenClosed = false
            w.collectionBehavior.insert(.moveToActiveSpace)
            w.delegate = self
            window = w
        }
        window?.title = Self.text("Welcome to Candela", model.language)
        window?.contentView = NSHostingView(rootView: OnboardingView(
            model: model,
            onFinish: { [weak self] in self?.finish() },
            onClose: { [weak self] in self?.window?.close() },
            onLanguage: { [weak self] code in self?.setLanguage(code) }
        ))
        window?.center()
        bringToFront()
        installKeyMonitor()
    }

    /// Candela is a menu-bar (LSUIElement) app, so nothing brings a window forward
    /// for it: activate explicitly and order the window front even if another app
    /// is active, or the first-run guide would open behind whatever the user has.
    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    /// Picker change: redraw the guide now, and store it as the app's language
    /// (the same AppleLanguages override as Settings > Language). The rest of the
    /// UI reads its language once at launch, so it follows on the next launch.
    private func setLanguage(_ code: String) {
        model.language = code
        window?.title = Self.text("Welcome to Candela", code)
        if let language = AppLanguage(rawValue: code) { AppLanguage.store(language) }
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

    /// The .lproj bundle for a language code, or the main bundle when there is none
    /// (an unbundled dev run). Lets the guide draw in a language other than the
    /// one the process launched in.
    static func bundle(for code: String) -> Bundle {
        Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    /// `String(localized:)` with a runtime key; every key used here is also a literal
    /// in `pages(language:)` / the view, which is what string extraction sees.
    static func text(_ key: String.LocalizationValue, _ code: String) -> String {
        String(localized: key, bundle: bundle(for: code))
    }

    // swiftlint:disable line_length
    static func pages(language code: String) -> [GuidePage] {
        let b = bundle(for: code)
        let pages: [GuidePage] = [
            GuidePage(icon: "sun.max", title: String(localized: "Welcome to Candela", bundle: b),
                      body: String(localized: "Candela lives in your menu bar. Click its icon to open the panel: every connected display gets its own brightness slider. A Software tag means that display has no DDC support, so Candela dims it in software.", bundle: b)),
            GuidePage(icon: "slider.horizontal.3", title: String(localized: "One slider for the whole desk", bundle: b),
                      body: String(localized: "Combined moves every display together. Below it, switch Dark Mode, Night Shift and True Tone, or save your current setup as a preset.", bundle: b)),
            GuidePage(icon: "display", title: String(localized: "Sharp, readable resolution", bundle: b),
                      body: String(localized: "Open a display to change its resolution and refresh rate. Candela lists the sharp 2× modes macOS hides on third-party monitors. Combined brightness sets where this display sits when the combined slider is at the bottom, so two panels can match.", bundle: b)),
            GuidePage(icon: "wrench.and.screwdriver", title: String(localized: "Tools for your desk", bundle: b),
                      body: String(localized: "Tools holds Keep Awake, Virtual Displays, iPad Display and Arrange Displays.", bundle: b)),
            GuidePage(icon: "gearshape", title: String(localized: "Brightness keys and settings", bundle: b),
                      body: String(localized: "Settings is where you choose what the brightness keys control. Sending them to external displays needs Accessibility access: turn on the switch under Brightness Keys and macOS asks once. Language and Launch at Login are here too.", bundle: b))
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
    let onFinish: () -> Void
    let onClose: () -> Void
    let onLanguage: (String) -> Void

    private var isLast: Bool { model.page == Onboarding.pageCount - 1 }

    /// Each name in its own language, like Settings > Language.
    private static let languageNames = ["en": "English", "zh-Hans": "简体中文", "zh-Hant": "繁體中文"]

    var body: some View {
        let lang = model.language
        let pages = OnboardingWindowController.pages(language: lang)
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
                    if model.page == 0 { languagePicker(lang) }
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
                    Button(OnboardingWindowController.text("Skip", lang), action: onClose)
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
                    Button(OnboardingWindowController.text("Back", lang)) { model.page = Onboarding.page(model.page, step: -1) }
                }
                if isLast {
                    Button(OnboardingWindowController.text("Open Candela", lang), action: onFinish)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(OnboardingWindowController.text("Next", lang)) { model.page = Onboarding.page(model.page, step: 1) }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    /// First-page language picker: re-renders the guide at once and sets the app's language.
    private func languagePicker(_ lang: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(selection: Binding(get: { model.language }, set: onLanguage)) {
                ForEach(Onboarding.languages, id: \.self) { Text(Self.languageNames[$0] ?? $0).tag($0) }
            } label: {
                Text(OnboardingWindowController.text("Language", lang))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel(Text(OnboardingWindowController.text("Language", lang)))
            if lang != model.launchLanguage {
                Text(OnboardingWindowController.text("The rest of Candela switches language the next time it launches.", lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

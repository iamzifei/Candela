import SwiftUI
import AppKit

/// The interface language, as an explicit choice rather than only whatever macOS
/// decides.
///
/// The app ships English, 简体中文 and 繁體中文, and until now the only way to reach
/// the Chinese ones was to change the whole system's language — which is a large
/// thing to do to read one menu bar panel, and leaves someone who runs an English
/// system but reads Chinese with no way to get there at all.
///
/// A language change needs a relaunch: AppleLanguages is read once when the bundle
/// is loaded, so nothing already on screen re-reads its strings. The row says so and
/// offers to do it, rather than changing the setting and appearing to do nothing.
struct LanguageRow: View {
    @Binding var expanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            ExpandableRow(
                icon: "globe",
                iconColor: .accentColor,
                iconActive: true,
                // String(localized:) so the key is extracted. ExpandableRow resolves
                // its label through NSLocalizedString at render time, but a variable
                // is invisible to Xcode's string extraction — "Language" never
                // reached the catalog, so the lookup had nothing to find and the row
                // stayed English on a Chinese system. Every other caller of this row
                // already does it this way.
                label: String(localized: "Language"),
                subtitle: AppLanguage.current.title,
                isExpanded: $expanded
            )

            VStack(spacing: 0) {
                ForEach(AppLanguage.allCases) { language in
                    CheckmarkRow(
                        label: language.title,
                        isSelected: language == AppLanguage.current
                    ) {
                        AppLanguage.select(language)
                    }
                }
            }
            .padding(.leading, 8)
            .curtainReveal(expanded)
        }
    }
}

/// The languages the bundle actually carries, plus following the system.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    /// Each name is written in its own language: someone looking for 繁體中文 is not
    /// helped by seeing "Traditional Chinese" in a language they cannot read.
    var title: String {
        switch self {
        case .system:             return String(localized: "System")
        case .english:            return "English"
        case .simplifiedChinese:  return "简体中文"
        case .traditionalChinese: return "繁體中文"
        }
    }

    private static let key = "AppleLanguages"

    static var current: AppLanguage {
        guard let stored = UserDefaults.standard.stringArray(forKey: key)?.first,
              let match = allCases.first(where: { $0.rawValue == stored })
        else { return .system }
        return match
    }

    /// Writes the choice and offers a relaunch.
    ///
    /// Removing the key rather than writing a value is what "follow the system"
    /// means here — an explicit list of one is still an override, and would pin the
    /// app to today's system language if the system's changed later.
    static func select(_ language: AppLanguage) {
        guard language != current else { return }
        if language == .system {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: key)
        }
        offerRelaunch()
    }

    private static func offerRelaunch() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Relaunch to change the language?")
        alert.informativeText = String(
            localized: "Candela reads its language once at launch, so the new one applies after it restarts.")
        alert.addButton(withTitle: String(localized: "Relaunch"))
        alert.addButton(withTitle: String(localized: "Later"))
        // Above the panel, which is a floating window and would otherwise cover it.
        alert.window.level = .modalPanel
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}

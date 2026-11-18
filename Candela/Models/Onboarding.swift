import Foundation

/// When to show the first-run welcome guide, and how its pages step.
/// Pure logic (no AppKit) so the unit-test target can compile it on its own;
/// the window itself lives in Views/OnboardingWindowController.swift.
enum Onboarding {
    /// UserDefaults key holding the last guide version the user was shown.
    static let seenKey = "candela.onboardingSeenVersion"

    /// Bump when the guide gains content worth showing to existing users again.
    /// Version 1 = the first guide (0.2.0).
    static let currentVersion = 1

    /// Pages: welcome, combined + quick toggles, resolution, tools, settings + keys.
    static let pageCount = 5

    /// The stored value is the last guide version shown (0 when the key is
    /// missing: a fresh install, or an upgrade from 0.1.x).
    static func shouldShow(seenVersion: Int) -> Bool {
        seenVersion < currentVersion
    }

    /// Moves `step` pages from `index`, never past either end.
    static func page(_ index: Int, step: Int) -> Int {
        min(max(0, index + step), pageCount - 1)
    }

    /// Reads the stored value from `defaults`. A truly fresh install has no key at
    /// all, and `integer(forKey:)` returns 0 for a missing key, so it shows.
    static func shouldShow(in defaults: UserDefaults) -> Bool {
        shouldShow(seenVersion: defaults.integer(forKey: seenKey))
    }

    static func markSeen(in defaults: UserDefaults) {
        defaults.set(currentVersion, forKey: seenKey)
    }

    // MARK: language

    /// The languages the app bundle carries (codes match the .lproj names).
    static let languages = ["en", "zh-Hans", "zh-Hant"]

    /// The best supported language for a macOS preferred-languages list.
    ///
    /// First entry that maps wins: Traditional Chinese (Hant, or the TW/HK/MO
    /// regions) -> zh-Hant, any other Chinese -> zh-Hans, English -> en. An
    /// unsupported language (say Japanese) is skipped in favour of the next
    /// preference, and an empty or all-unsupported list falls back to English.
    static func bestLanguage(preferred: [String]) -> String {
        for raw in preferred {
            let tag = raw.replacingOccurrences(of: "_", with: "-")
            let parts = tag.split(separator: "-").map { $0.lowercased() }
            guard let base = parts.first else { continue }
            if base == "zh" {
                if parts.contains("hans") { return "zh-Hans" }
                if parts.contains("hant") || !Set(parts).isDisjoint(with: ["tw", "hk", "mo"]) { return "zh-Hant" }
                return "zh-Hans"
            }
            if base == "en" { return "en" }
        }
        return "en"
    }
}

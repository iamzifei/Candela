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
}

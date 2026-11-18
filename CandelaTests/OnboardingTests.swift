import XCTest
@testable import Candela

final class OnboardingTests: XCTestCase {
    func testFreshInstallAndUpgradeSeeTheGuide() {
        XCTAssertTrue(Onboarding.shouldShow(seenVersion: 0))
    }

    func testSeenCurrentVersionIsNotShownAgain() {
        XCTAssertFalse(Onboarding.shouldShow(seenVersion: Onboarding.currentVersion))
        XCTAssertFalse(Onboarding.shouldShow(seenVersion: Onboarding.currentVersion + 1))
    }

    func testPagingIsClampedAtBothEnds() {
        XCTAssertEqual(Onboarding.page(0, step: -1), 0)
        XCTAssertEqual(Onboarding.page(0, step: 1), 1)
        XCTAssertEqual(Onboarding.page(Onboarding.pageCount - 1, step: 1), Onboarding.pageCount - 1)
        XCTAssertEqual(Onboarding.page(2, step: -1), 1)
    }

    // MARK: first run

    func testTrulyFreshDefaultsShowAndThenStayDismissed() {
        let suite = "candela.test.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertNil(defaults.object(forKey: Onboarding.seenKey))
        XCTAssertTrue(Onboarding.shouldShow(in: defaults))
        Onboarding.markSeen(in: defaults)
        XCTAssertFalse(Onboarding.shouldShow(in: defaults))
    }

    func testUpgradeFromBeforeTheGuideShowsOnce() {
        let suite = "candela.test.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "candela.didMigrateLegacyDefaults")  // an existing install, no guide key
        XCTAssertTrue(Onboarding.shouldShow(in: defaults))
    }

    // MARK: language default

    func testBestLanguageMapping() {
        XCTAssertEqual(Onboarding.bestLanguage(preferred: ["zh-Hant-TW"]), "zh-Hant")
        XCTAssertEqual(Onboarding.bestLanguage(preferred: ["zh-TW"]), "zh-Hant")
        XCTAssertEqual(Onboarding.bestLanguage(preferred: ["zh-HK"]), "zh-Hant")
        XCTAssertEqual(Onboarding.bestLanguage(preferred: ["zh-Hant"]), "zh-Hant")
        XCTAssertEqual(Onboarding.bestLanguage(preferred: ["zh-Hans-CN"]), "zh-Hans")
        XCTAssertEqual(Onboarding.bestLanguage(preferred: ["zh-CN"]), "zh-Hans")
        XCTAssertEqual(Onboarding.bestLanguage(preferred: ["zh"]), "zh-Hans")
        XCTAssertEqual(Onboarding.bestLanguage(preferred: ["en-AU"]), "en")
        // Unsupported languages defer to the next preference, then to English.
        XCTAssertEqual(Onboarding.bestLanguage(preferred: ["ja-JP", "zh-Hant-TW"]), "zh-Hant")
        XCTAssertEqual(Onboarding.bestLanguage(preferred: ["fr-FR"]), "en")
        XCTAssertEqual(Onboarding.bestLanguage(preferred: []), "en")
    }
}

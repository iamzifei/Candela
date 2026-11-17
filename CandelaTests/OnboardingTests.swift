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
}

import XCTest
@testable import Candela

final class CombinedMappingTests: XCTestCase {

    /// An uncalibrated display must behave exactly as it did before floors existed,
    /// or every desk that was already matched gets worse on upgrade.
    func testZeroFloorIsTheIdentityMapping() {
        for level in stride(from: 0.0, through: 100.0, by: 12.5) {
            XCTAssertEqual(CombinedMapping.position(forCombined: level, floor: 0), level, accuracy: 0.0001)
            XCTAssertEqual(CombinedMapping.combinedLevel(forPosition: level, floor: 0), level, accuracy: 0.0001)
        }
    }

    /// The point of the floor: at the bottom of the combined slider the display sits
    /// at its floor, not at black.
    func testFloorHoldsTheBottomOfTheRange() {
        XCTAssertEqual(CombinedMapping.position(forCombined: 0, floor: 25), 25, accuracy: 0.0001)
    }

    /// The top is not calibrated — every display reaches its own maximum.
    func testTopOfRangeIsAlwaysFull() {
        for floor in [0.0, 10.0, 25.0, 60.0, 95.0] {
            XCTAssertEqual(CombinedMapping.position(forCombined: 100, floor: floor), 100, accuracy: 0.0001)
        }
    }

    func testPositionAndCombinedLevelAreInverses() {
        for floor in [0.0, 15.0, 40.0, 80.0] {
            for level in stride(from: 0.0, through: 100.0, by: 10.0) {
                let position = CombinedMapping.position(forCombined: level, floor: floor)
                XCTAssertEqual(
                    CombinedMapping.combinedLevel(forPosition: position, floor: floor),
                    level, accuracy: 0.0001,
                    "floor \(floor), level \(level)")
            }
        }
    }

    /// Calibration solves for the floor that reproduces what the user just matched
    /// by eye, so applying it must put the display back exactly where they left it.
    func testCalibrationReproducesTheMatchedPosition() {
        let cases: [(level: Double, matched: Double)] = [
            (20, 36), (10, 30), (50, 60), (0, 25), (75, 80)
        ]
        for (level, matched) in cases {
            guard let floor = CombinedMapping.floor(matching: matched, atCombined: level) else {
                return XCTFail("expected a floor for level \(level)")
            }
            XCTAssertEqual(
                CombinedMapping.position(forCombined: level, floor: floor),
                matched, accuracy: 0.0001,
                "level \(level) matched at \(matched)")
        }
    }

    /// Matching at the very bottom is the direct case: the floor is what you see.
    func testCalibratingAtZeroSetsTheFloorDirectly() {
        XCTAssertEqual(CombinedMapping.floor(matching: 30, atCombined: 0), 30)
    }

    /// At the top every floor produces the same position, so the observation carries
    /// no information about the floor and must not be turned into one.
    func testCalibratingAtFullBrightnessIsRefused() {
        XCTAssertNil(CombinedMapping.floor(matching: 100, atCombined: 100))
    }

    /// A display the user dimmed BELOW the combined level wants a floor under zero;
    /// there is no such thing, and the clamp must not produce one.
    func testFloorNeverGoesNegative() {
        let floor = CombinedMapping.floor(matching: 10, atCombined: 40)
        XCTAssertEqual(floor, 0)
    }

    /// A collapsed range would pin a display at one brightness with nothing in the UI
    /// explaining why it stopped responding.
    func testFloorIsCappedBelowFull() {
        XCTAssertEqual(CombinedMapping.clampFloor(200), CombinedMapping.maximumFloor)
        let floor = CombinedMapping.floor(matching: 99.9, atCombined: 1) ?? 0
        XCTAssertLessThanOrEqual(floor, CombinedMapping.maximumFloor)
        XCTAssertGreaterThan(
            CombinedMapping.position(forCombined: 100, floor: floor),
            CombinedMapping.position(forCombined: 0, floor: floor))
    }

    /// The reported failure, as a test: a DDC display whose backlight floors at 25%
    /// and a software-dimmed display that really does reach black, driven to the
    /// bottom together. Uncalibrated they are 25 points apart — one lit, one black.
    /// Calibrated, they land together.
    func testTheReportedFailureIsClosed() {
        let ddcFloor = 25.0    // this panel is still visibly lit at VCP 0
        let softFloor = CombinedMapping.floor(matching: 25, atCombined: 0)!

        let ddcAtBottom = CombinedMapping.position(forCombined: 0, floor: ddcFloor)
        let softAtBottom = CombinedMapping.position(forCombined: 0, floor: softFloor)
        XCTAssertEqual(ddcAtBottom, softAtBottom, accuracy: 0.0001)

        // And they stay together on the way up, not just at the endpoint.
        for level in stride(from: 0.0, through: 100.0, by: 20.0) {
            XCTAssertEqual(
                CombinedMapping.position(forCombined: level, floor: ddcFloor),
                CombinedMapping.position(forCombined: level, floor: softFloor),
                accuracy: 0.0001)
        }
    }
}

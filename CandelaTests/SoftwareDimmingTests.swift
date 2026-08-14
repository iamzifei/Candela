import XCTest

/// `SoftwareDimming` is compiled into this target directly (see project.yml), so no
/// `@testable import Candela` is needed.
///
/// These assert the property that matters on a multi-display desk: asking for N% of
/// the light gives about N% of the light, so a software-dimmed display and a
/// DDC-driven one stay together on the combined slider instead of one going black
/// while the other is still readable.
final class SoftwareDimmingTests: XCTestCase {

    private func luminance(atPercent percent: Double) -> Double {
        SoftwareDimming.approximateLuminance(
            forFactor: SoftwareDimming.transferFactor(forPercent: percent))
    }

    // MARK: - The property the fix exists for

    func testRequestedPercentYieldsRoughlyThatMuchLight() {
        for percent in [10.0, 20.0, 35.0, 50.0, 75.0, 90.0] {
            XCTAssertEqual(luminance(atPercent: percent), percent / 100.0, accuracy: 0.01,
                           "asking for \(percent)% should give about \(percent)% of the light")
        }
    }

    func testLinearScalingWouldHaveBeenFarDarker() {
        // What the old code did, kept as a regression guard: at 20% the linear scale
        // put out 2.9% of the light, which reads as a dark screen next to a DDC
        // display sitting at 20%.
        let linear = pow(0.20, SoftwareDimming.assumedEOTF)
        XCTAssertLessThan(linear, 0.04)
        XCTAssertEqual(luminance(atPercent: 20), 0.20, accuracy: 0.01)
        XCTAssertGreaterThan(luminance(atPercent: 20), linear * 5)
    }

    // MARK: - Endpoints

    func testFullBrightnessIsUnchanged() {
        XCTAssertEqual(SoftwareDimming.transferFactor(forPercent: 100), 1.0, accuracy: 0.0001)
    }

    func testZeroClampsToTheFloorRatherThanBlack() {
        XCTAssertEqual(SoftwareDimming.transferFactor(forPercent: 0),
                       SoftwareDimming.minimumFactor, accuracy: 0.0001)
    }

    func testNegativeInputIsClampedNotReflected() {
        XCTAssertEqual(SoftwareDimming.transferFactor(forPercent: -30),
                       SoftwareDimming.minimumFactor, accuracy: 0.0001)
    }

    func testFloorOnlyEngagesNearTheBottom() {
        // 5% must still be above the floor, otherwise the bottom of the slider is a
        // dead zone where dragging changes nothing.
        XCTAssertGreaterThan(SoftwareDimming.transferFactor(forPercent: 5),
                             SoftwareDimming.minimumFactor)
    }

    // MARK: - Boost region

    func testBoostRegionPassesThroughUncorrected() {
        // BrightnessBoostService drives EDR by calling in with percent > 100 as a raw
        // multiplier. Applying the dimming correction there — or clamping to 1.0 —
        // would break Extra Brightness.
        XCTAssertEqual(SoftwareDimming.transferFactor(forPercent: 160), 1.6, accuracy: 0.0001)
        XCTAssertEqual(SoftwareDimming.transferFactor(forPercent: 100.5), 1.005, accuracy: 0.0001)
    }

    // MARK: - Shape

    func testMonotonic() {
        var previous = 0.0
        for percent in stride(from: 0.0, through: 100.0, by: 1.0) {
            let factor = SoftwareDimming.transferFactor(forPercent: percent)
            XCTAssertGreaterThanOrEqual(factor, previous, "not monotonic at \(percent)%")
            previous = factor
        }
    }

    func testNeverExceedsFullWhiteWhileDimming() {
        for percent in stride(from: 0.0, through: 100.0, by: 1.0) {
            XCTAssertLessThanOrEqual(SoftwareDimming.transferFactor(forPercent: percent), 1.0)
        }
    }
}

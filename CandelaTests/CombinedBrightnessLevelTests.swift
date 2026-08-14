import XCTest

/// The property these protect is the one the `.combined` brightness-key mode exists
/// for: every display lands on one level, so none can bottom out while another is
/// still lit — the failure the per-display stepping in `.allDisplays` allows.
final class CombinedBrightnessLevelTests: XCTestCase {

    func testLevelIsTheMeanOfPositions() {
        XCTAssertEqual(CombinedBrightnessLevel.level(ofPositions: [100, 50]), 75, accuracy: 0.001)
        XCTAssertEqual(CombinedBrightnessLevel.level(ofPositions: [40, 40, 40]), 40, accuracy: 0.001)
    }

    func testEmptyDeskReadsMidScale() {
        // No displays: the slider still needs a handle position, and 50 keeps a
        // reconnect from snapping to an end.
        XCTAssertEqual(CombinedBrightnessLevel.level(ofPositions: []), 50, accuracy: 0.001)
    }

    func testBoostedDisplayCountsByPositionNotAbsoluteValue() {
        // A display boosted to 160/160 sits at 100% of its own range, the same as a
        // plain one at 100/100 — otherwise the combined level would read above 100
        // as soon as Extra Brightness is on.
        let boosted = 160.0 / 160.0 * 100.0
        let plain = 100.0 / 100.0 * 100.0
        XCTAssertEqual(CombinedBrightnessLevel.level(ofPositions: [boosted, plain]), 100, accuracy: 0.001)
    }

    // MARK: - Stepping

    func testStepsByPercentagePoints() {
        XCTAssertEqual(CombinedBrightnessLevel.stepped(from: 50, by: 6.25), 56.25, accuracy: 0.001)
        XCTAssertEqual(CombinedBrightnessLevel.stepped(from: 50, by: -6.25), 43.75, accuracy: 0.001)
    }

    func testClampsAtBothEnds() {
        XCTAssertEqual(CombinedBrightnessLevel.stepped(from: 97, by: 6.25), 100, accuracy: 0.001)
        XCTAssertEqual(CombinedBrightnessLevel.stepped(from: 3, by: -6.25), 0, accuracy: 0.001)
    }

    /// The whole point of the mode: displays that start apart converge and then move
    /// as one, and the bottom is reached by all of them at once.
    func testDisplaysConvergeAndStayTogether() {
        var positions = [80.0, 20.0]
        let step = -100.0 / 16.0

        // First press pulls both to one level.
        var level = CombinedBrightnessLevel.stepped(
            from: CombinedBrightnessLevel.level(ofPositions: positions), by: step)
        positions = positions.map { _ in level }
        XCTAssertEqual(positions[0], positions[1], accuracy: 0.001)

        // Every press after that keeps them equal, including at the floor.
        for _ in 0..<20 {
            level = CombinedBrightnessLevel.stepped(
                from: CombinedBrightnessLevel.level(ofPositions: positions), by: step)
            positions = positions.map { _ in level }
            XCTAssertEqual(positions[0], positions[1], accuracy: 0.001)
        }
        XCTAssertEqual(level, 0, accuracy: 0.001, "holding the key down should reach the floor")
    }

    func testIndependentSteppingIsWhatDiverges() {
        // Documents why the mode exists rather than reusing .allDisplays: stepping each
        // display inside its own range leaves one at the floor while the other is still
        // lit, and nothing brings them back.
        var a = 20.0, b = 80.0
        let step = -100.0 / 16.0
        for _ in 0..<5 {
            a = max(0, a + step)
            b = max(0, b + step)
        }
        XCTAssertEqual(a, 0, accuracy: 0.001)
        XCTAssertGreaterThan(b, 45)
    }
}

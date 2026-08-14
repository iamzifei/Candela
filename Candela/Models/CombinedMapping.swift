import Foundation

/// Where one display sits inside a combined brightness move.
///
/// Driving every display to the same percentage does not make them look the same,
/// and no amount of arithmetic can fix that on its own. Two panels differ in how
/// much light they emit at full output and in how their backlight responds on the
/// way down, and macOS reports neither: probing a Gigabyte M28U and a ViewSonic
/// VX1622-4K, both answer `maximumPotentialExtendedDynamicRangeColorComponentValue`
/// = 1.0 and reference EDR = 0.0, which is to say "SDR, no absolute figure". There
/// is no measurement to normalise against without a colorimeter.
///
/// The mismatch is worst at the bottom, which is where it was reported. A monitor
/// dimmed over DDC keeps a backlight floor — at VCP 0x10 = 0 most panels are dim
/// but plainly still lit — while a monitor with no working DDC is dimmed by scaling
/// its gamma table, which really does approach black. Sent the same 0%, one display
/// is readable and its neighbour looks switched off.
///
/// So the human eye is the instrument. Each display gets a floor: the position it
/// takes when the combined slider is at the bottom. The user matches the displays
/// by eye once, the app solves for the floor, and every combined move afterwards
/// keeps them together.
///
/// The top is deliberately not calibrated. "All the way up" means each panel's own
/// maximum — that is what people reach for the top of the slider expecting, and
/// holding a brighter display back to match a dimmer one throws away light the user
/// paid for. What is being matched here is the *range*, not the absolute output.
///
/// Positions are percentages of a display's own scale (`brightness / maxBrightness`),
/// the same unit `CombinedBrightnessLevel` uses, so a display boosted to 160 nits of
/// headroom still reads 100 at the top.
enum CombinedMapping {

    /// Floors are held below this so the range can never collapse to a point, which
    /// would leave a display unable to move at all and no obvious way to notice why.
    static let maximumFloor = 95.0

    /// Where `display` should sit when the combined level is `level`.
    static func position(forCombined level: Double, floor: Double) -> Double {
        let f = clampFloor(floor)
        return f + max(0, min(100, level)) / 100.0 * (100.0 - f)
    }

    /// The combined level a display at `position` corresponds to — the inverse of
    /// `position(forCombined:floor:)`.
    ///
    /// Needed for the slider handle: the combined level is read back from where the
    /// displays actually are, so without inverting each display's own floor a
    /// calibrated display would drag the shared handle away from the level that put
    /// it there.
    static func combinedLevel(forPosition position: Double, floor: Double) -> Double {
        let f = clampFloor(floor)
        return max(0, min(100, (position - f) / (100.0 - f) * 100.0))
    }

    /// The floor that puts a display at `position` when the combined level is `level`.
    ///
    /// This is the calibration step: the user has moved one display until it matches
    /// its neighbours, and this reads that adjustment back as a floor.
    ///
    /// - Returns: nil at a combined level of 100, where every floor produces the same
    ///   position and the observation says nothing. Calibrating has to happen with the
    ///   slider down, which is also the only place the difference is visible.
    static func floor(matching position: Double, atCombined level: Double) -> Double? {
        guard level < 100 else { return nil }
        let l = max(0, level) / 100.0
        return clampFloor((position - level) / (1 - l))
    }

    /// Held inside 0...`maximumFloor`.
    static func clampFloor(_ floor: Double) -> Double {
        max(0, min(maximumFloor, floor))
    }
}

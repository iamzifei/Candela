import Foundation

/// The single 0–100 figure that stands for "how bright the desk is".
///
/// Each display contributes its position within its own range, so a display boosted
/// to 160/160 and a plain one at 100/100 both count as 100%. Shared by the Combined
/// slider and the `.combined` brightness-key mode so the slider and the keys cannot
/// disagree about what the current level is — they read and write the same number.
enum CombinedBrightnessLevel {

    /// The combined level for displays at `positions`, each expressed as a percentage
    /// of that display's own maximum.
    ///
    /// A plain mean, not a minimum or a maximum: it is the figure the slider handle
    /// sits at, and stepping it moves every display by the same proportion.
    static func level(ofPositions positions: [Double]) -> Double {
        guard !positions.isEmpty else { return 50 }
        return positions.reduce(0, +) / Double(positions.count)
    }

    /// `level` moved by `step` percentage points, held inside 0–100.
    ///
    /// Clamping the combined level rather than each display separately is the point of
    /// the mode: stepping displays independently lets one bottom out at 0 while another
    /// is still at 40, and once they have diverged nothing brings them back. Here every
    /// display is driven to one level, so they stay together at both ends.
    static func stepped(from level: Double, by step: Double) -> Double {
        max(0, min(100, level + step))
    }
}

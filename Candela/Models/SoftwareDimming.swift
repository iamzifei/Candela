import Foundation

/// Maps a brightness percentage to the scale factor applied to a display's gamma
/// transfer table.
///
/// Software dimming works by scaling the values the transfer table emits, which are
/// *signal* levels, not luminance. The panel then applies its own EOTF — near enough
/// to gamma 2.2 for any SDR display — so scaling the signal by `k` scales luminance
/// by `k^2.2`, not by `k`.
///
/// Scaling the table linearly therefore darkens far faster than the number on the
/// slider suggests, and much faster than DDC, whose backlight value tracks luminance
/// roughly linearly. On a two-monitor desk where one display has hardware brightness
/// and the other does not, the combined slider drove them badly apart:
///
///     slider   DDC display     software display (linear scaling)
///     50%      ~50% luminance  0.50^2.2 = 22%
///     20%      ~20% luminance  0.20^2.2 = 2.9%
///
/// At 20% one screen was readable and the other looked switched off. Raising the
/// signal to the inverse power puts the software path back on the same luminance
/// curve as the hardware one.
///
/// This corrects the shape of the response, not absolute luminance: two panels at
/// "50%" still differ by whatever their maximum outputs and actual EOTFs differ by,
/// which nothing short of a colorimeter can equalise. What it guarantees is that
/// both move together, and that neither reaches black while the other is still lit.
enum SoftwareDimming {

    /// The EOTF assumed for an SDR panel. sRGB and Display P3 content both target
    /// approximately this, and the correction is not sensitive to small errors —
    /// 2.0 or 2.4 shifts mid-slider luminance by only a few percent.
    static let assumedEOTF = 2.2

    /// Floor on the table scale, so the bottom of the slider is very dark but never
    /// a black screen the user cannot navigate back from.
    static let minimumFactor = 0.05

    /// The transfer-table scale factor for `percent` of full brightness.
    ///
    /// - Parameter percent: 0–100 for dimming. Values above 100 are the EDR boost
    ///   region, where `BrightnessBoostService` drives the table above 1.0 as a raw
    ///   multiplier; those pass through uncorrected, since the correction describes
    ///   dimming an SDR signal and has no meaning past the panel's SDR white.
    static func transferFactor(forPercent percent: Double) -> Double {
        guard percent <= 100 else { return percent / 100.0 }
        let requested = max(0.0, percent / 100.0)
        return max(minimumFactor, pow(requested, 1.0 / assumedEOTF))
    }

    /// The luminance `transferFactor(forPercent:)` is aiming for, as a fraction of
    /// full. Used by tests to state the intent — that requesting 20% yields about
    /// 20% of the light, not 3% — rather than restating the formula.
    static func approximateLuminance(forFactor factor: Double) -> Double {
        pow(factor, assumedEOTF)
    }
}

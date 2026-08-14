// scripts/check-boost-math.swift
// Runnable check for BrightnessBoostMath. Run:
//   cat Candela/Utilities/BrightnessBoostMath.swift scripts/check-boost-math.swift | swift -

// sliderMax: no meaningful headroom means the scale stays at 100.
assert(BrightnessBoostMath.sliderMax(potentialHeadroom: 1.0) == 100)
assert(BrightnessBoostMath.sliderMax(potentialHeadroom: 1.04) == 100)
// Capped at 200 however large the potential headroom is.
assert(BrightnessBoostMath.sliderMax(potentialHeadroom: 16.0) == 200)
// Small honest headroom scales the boost region down.
assert(BrightnessBoostMath.sliderMax(potentialHeadroom: 1.3) == 130)

// overlayFactor: at or below 100 there is no boost.
assert(BrightnessBoostMath.overlayFactor(brightness: 50, sliderMax: 200, currentEDR: 4.0, potentialHeadroom: 16.0) == 1.0)
assert(BrightnessBoostMath.overlayFactor(brightness: 100, sliderMax: 200, currentEDR: 4.0, potentialHeadroom: 16.0) == 1.0)
// t=0 (bottom of the boost region) -> 1.0.
assert(abs(BrightnessBoostMath.overlayFactor(brightness: 100.001, sliderMax: 200, currentEDR: 4.0, potentialHeadroom: 16.0) - 1.0) < 0.001)
// Exponential mapping: t=0.5 -> sqrt(headroom), t=1 -> the full live headroom.
assert(abs(BrightnessBoostMath.overlayFactor(brightness: 150, sliderMax: 200, currentEDR: 4.0, potentialHeadroom: 16.0) - 2.0) < 0.001)
assert(abs(BrightnessBoostMath.overlayFactor(brightness: 200, sliderMax: 200, currentEDR: 4.0, potentialHeadroom: 16.0) - 4.0) < 0.001)
// The factor never exceeds the live headroom, whatever the slider says.
assert(BrightnessBoostMath.overlayFactor(brightness: 200, sliderMax: 200, currentEDR: 1.3, potentialHeadroom: 16.0) <= 1.3 + 0.001)
// Headroom sagging (ABL/thermals) eases the same slider position down.
assert(BrightnessBoostMath.overlayFactor(brightness: 200, sliderMax: 200, currentEDR: 2.5, potentialHeadroom: 16.0) <
       BrightnessBoostMath.overlayFactor(brightness: 200, sliderMax: 200, currentEDR: 4.0, potentialHeadroom: 16.0))

// HDR-not-ready gate (currentEDR <= 1.05): a flat pending nudge, never the
// target computed from unramped headroom.
assert(abs(BrightnessBoostMath.overlayFactor(brightness: 150, sliderMax: 200, currentEDR: 1.0, potentialHeadroom: 16.0) - 1.12) < 0.001)
assert(abs(BrightnessBoostMath.overlayFactor(brightness: 101, sliderMax: 200, currentEDR: 1.0, potentialHeadroom: 16.0) - 1.12) < 0.001)

// SDR gate (potentialHeadroom <= 1.05): a display that can never ramp EDR
// gets the identity factor, not the pending nudge, however boosted the
// slider looks. Real potential headroom (line 29 above) still gets the nudge.
assert(BrightnessBoostMath.overlayFactor(brightness: 150, sliderMax: 200, currentEDR: 1.0, potentialHeadroom: 1.0) == 1.0)

// externalBoostFactor: gamma-table mapping for externals; fixed luminance
// ceiling converted to the encoded domain, never the OS-reported live headroom.
assert(BrightnessBoostMath.externalBoostFactor(brightness: 50, sliderMax: 200) == 1.0)
assert(BrightnessBoostMath.externalBoostFactor(brightness: 100, sliderMax: 200) == 1.0)
assert(abs(BrightnessBoostMath.externalBoostFactor(brightness: 100.001, sliderMax: 200) - 1.0) < 0.001)
// Encoded-domain ceiling: luminance ceiling through 1/gamma (4.0^(1/2.2) ~ 1.88).
let c = pow(BrightnessBoostMath.externalBoostCeilingLuminance, 1.0 / BrightnessBoostMath.externalDisplayGamma)
assert(abs(BrightnessBoostMath.externalBoostFactor(brightness: 200, sliderMax: 200) - c) < 0.001)
// Exponential pacing: t=0.5 -> sqrt of the encoded ceiling.
assert(abs(BrightnessBoostMath.externalBoostFactor(brightness: 150, sliderMax: 200) - c.squareRoot()) < 0.001)
// Slider overshoot clamps at the ceiling.
assert(BrightnessBoostMath.externalBoostFactor(brightness: 250, sliderMax: 200) <= c + 0.001)
// Sanity: the encoded top stays well under the first attempt's 2.5, which
// washed out on hardware (7.5x mid-tone luminance).
assert(c < 2.0)

print("check-boost-math: all assertions passed")

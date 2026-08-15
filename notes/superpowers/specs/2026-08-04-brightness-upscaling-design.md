# Extra Brightness (XDR/HDR brightness upscaling)

Status: approved design, pre-implementation.
Date: 2026-08-04

## Purpose

Let users push a display's brightness beyond the normal 100% cap by using the
display's HDR/EDR headroom, the same capability BetterDisplay sells as
"brightness upscaling" (Pro) and BrightIntosh/Vivid ship for built-in panels.
Crisp's version must feel native: one toggle, then the existing brightness
controls simply reach further. Free, like every Crisp feature.

## Scope

- Built-in Apple XDR panels (MacBook Pro 2021+, Pro Display XDR) and
  third-party HDR-capable external monitors, in one release.
- Technique: EDR overlay (approach A below). No gamma-table boost, no private
  XDR preset hacks.
- Not in v1 (recorded as future options, do not build now):
  - auto-disable on battery
  - HDR-video detection to avoid overblown highlights (documented caveat only)
  - custom OSD
  - native private-API unlock for built-in panels ("approach C later" is a
    separate future decision, nothing in v1 prepares for it)

## How the technique works

HDR-capable panels reserve brightness above the SDR maximum for HDR content
(EDR headroom). We composite a fullscreen, click-through, invisible window per
boosted display containing a static EDR-enabled Metal layer whose uniform color
value exceeds 1.0, blended multiplicatively. The window server multiplies every
pixel beneath it, pushing the whole desktop into the headroom. Public API only
(CAMetalLayer.wantsExtendedDynamicRangeContent, extended linear color space,
NSScreen.maximumExtendedDynamicRangeColorComponentValue). Proven in production
by BrightIntosh and Vivid.

Rejected alternatives:
- Gamma/color-table scaling: Apple Silicon only, clips HDR content, relies on
  undocumented table behavior, and would add a third writer to the
  BrightnessService/GammaService single-writer gamma contract.
- Private-API native XDR unlock: built-in panels only, breaks across macOS
  releases (Apple broke BetterDisplay's variant in macOS 26.3).

## UX design

Toggle row, then native controls. No "boost" concept surfaces in the UI.

- New row in the display detail section (same family as Notch hiding and Auto
  Brightness): 26pt icon chip, label "Extra Brightness", a switch. Shown only
  for eligible displays; ineligible displays never see the row. Localized
  (en + zh-Hans).
- Built-in XDR, toggle on: the brightness slider range extends beyond 100%
  immediately (to roughly 160% depending on reported headroom).
- External HDR monitor in SDR mode, toggle on: Crisp switches the monitor to
  HDR mode first (equivalent to the System Settings checkbox; a brief re-sync
  blink is expected OS behavior), then extends the slider. Toggle off restores
  SDR only if Crisp enabled it.
- Slider: the existing per-display slider runs 0 to the display's true maximum.
  100% keeps today's meaning (hardware maximum), values above it are the boost
  region. No second slider.
- Brightness keys: keep native 1/16 steps and continue past 100% when the
  toggle is on. The native macOS OSD (already driven by Crisp) shows position
  across the full extended range.
- Persistence: toggle state and brightness level are remembered per display
  UUID and survive app restart, reconnect, and sleep/wake.

Doctrine check (notes/DESIGN.md): adjustment stays a slider (Panels HIG), the
row uses the uniform 26pt icon chip (Menus HIG all-or-none), on/off attribute
is a switch consistent with existing rows, no new panel depth.

## Behavior model

`DisplayInfo.brightness` stays the canonical 0-based UI value; the ceiling
becomes per-display:

- `DisplayInfo.maxBrightness`: 100 when boost is off or unsupported; above 100
  when on, derived from the display's reported EDR headroom.
- Existing hard-coded 0...100 clamps change to 0...maxBrightness.
- 0-100%: today's pipeline untouched (Apple native / DDC / software dimming).
  Overlay inactive (factor 1.0).
- Above 100%: hardware pinned at its max; the excess maps linearly to the
  overlay multiplier, from 1.0 up to the current reported headroom
  (NSScreen.maximumExtendedDynamicRangeColorComponentValue). Headroom is
  re-read on every brightness change and on screen-parameter changes because
  macOS adjusts it dynamically (thermals, panel state). This makes the boost
  self-calibrating per monitor: a DisplayHDR-400 panel simply gets a small
  honest boost.
- Combined (all-displays) slider becomes proportional: value v% sets each
  display to v% of its own range. Identical to today for non-boosted displays.

## Architecture

Two new units, both following house patterns:

- `BrightnessBoostService` (@MainActor singleton): policy. Eligibility
  detection (built-in XDR via reported potential headroom; externals via HDR
  capability), brightness-to-multiplier mapping, per-display persistence
  (display UUID keyed, UserDefaults), HDR mode switching for externals via the
  dlopen'd MonitorPanel.framework pattern DisplayPresetService already uses
  (the one likely-private-API piece), and lifecycle: reapply on wake/reconnect
  (AppDelegate.setupStartupBehavior), teardown plus SDR restore on quit.
- `EDROverlayManager` (@MainActor singleton, modeled on NotchOverlayManager):
  one borderless, click-through, all-spaces fullscreen window per boosted
  display, above .screenSaver level, containing a static EDR Metal layer with
  multiplicative blend. Re-renders only when the factor changes (idle GPU cost
  ~zero). Handles display disconnect via the same screen-reconfiguration path.

Touched existing code, kept minimal:

- `BrightnessService`: clamp to maxBrightness, route the >100 portion to
  BrightnessBoostService. Gamma paths untouched.
- `DisplayInfo`: maxBrightness plus boost eligibility/enabled flags.
- `BrightnessSliderView` / `CombinedBrightnessView`: range binding and
  proportional combined mapping.
- `DisplayDetailView`: the toggle row.
- `AppDelegate`: wake/terminate hooks.

GammaService is not touched; the overlay never writes gamma tables, so the
existing two-party single-writer contract stays two-party.

## Error handling

- HDR switch or overlay creation fails: toggle quietly reverts to off, no
  dialogs.
- Reported headroom is ~1.0: display treated as ineligible, no toggle shown.
- App quit: overlays torn down, SDR restored where Crisp enabled HDR (a boosted
  HDR-mode monitor without Crisp running would otherwise be stuck bright with
  no DDC control).

## Known caveats (shipped as documentation, not code)

- Real HDR video can look overblown while boost is active.
- Sustained maximum brightness increases power draw (roughly 2x on built-in
  panels at full boost) and long-term LED wear; macOS's own thermal management
  still applies and may dim under load.
- Most external monitors ignore DDC brightness in HDR mode; below 100% Crisp's
  existing software-dimming fallback covers them.

## Implementation order

1. Hardware spike first: prove the overlay math (built-in panel) and the
   external HDR mode switch on real displays before wiring any UI.
2. Then services, model/slider changes, toggle row, persistence, lifecycle.

## Testing

- Unit tests: brightness-to-factor mapping, eligibility logic (plain
  functions, no UI).
- Manual on-hardware checklist: built-in boost, external boost, sleep/wake,
  reconnect, quit restores SDR and identity, HDR video caveat, combined slider
  with mixed boosted/non-boosted displays, brightness keys past 100%.
- scripts/check-translations.py gates the new strings (zh-Hans coverage).

## Revision 2026-08-05

HDR is now its own explicit, visible per-display toggle row (HDRToggleView),
placed above Extra Brightness in the detail view. Extra Brightness still
auto-enables HDR on an SDR external when it needs the headroom, but no longer
reverts it, neither on boost disable nor on app quit. Rationale: a user who
had HDR on independently of boost, or who turned it on and wants it to stay
on, must not have it silently switched off out from under them.

Boost now auto-disables itself, with the same collapse a manual toggle-off
drives, when an external display's HDR capability disappears out from under
it (HDR turned off in System Settings, or a mode switch dropping HDR
advertisement); the persisted enable flag clears with it, so the toggle never
lingers on with boost inert underneath. The pending EDR-ramp trigger factor
(1.12) now applies only while the display still advertises EDR potential, not
to a display genuinely back in SDR. Known interaction: injected HiDPI scaled
modes do not advertise HDR on at least some external monitors (observed on
the AOC Q27G3XMN), so entering one while HDR is active drops HDR capability
until a native mode is restored; HDR flips are flash-free from native modes,
but force a re-sync flash from HiDPI ones.

A failed boost enable rolls back the HDR switch it made itself (a
half-engaged switch, preference recorded but the mode never applied, leaves
macOS rendering HDR intent into an SDR link, washing the screen out); a
user-set HDR mode is still never touched.

Verification status: fully hardware-verified on both display classes. The
built-in XDR path passed first (boost, headroom ceiling, collapse,
white-out). The external path passed the full protocol on the AOC Q27G3XMN
over DisplayPort/USB-C (the earlier HDMI link could not hold an HDR
handshake at 1440p 144Hz; over DP the panel runs 165Hz with HDR advertised
and ~11.5x potential EDR headroom): HDR on holds with no torn washout,
boost visibly exceeds SDR max with no white-out, boost off leaves HDR on,
HDR off collapses boost first, and cutting HDR from System Settings
mid-boost auto-disables boost and resyncs the HDR toggle row.

Three external-path behaviors were added during that verification pass:
(1) While a display is in HDR mode it owns its luminance and silently
discards DDC brightness writes (they still ack), so BrightnessService
routes the whole 0-100 range through software gamma dimming for the
duration; hardware DDC control resumes automatically when HDR goes off.
(2) EDR overlay windows re-align their frame on every keep-alive render:
an HDR flip's reconfiguration can move screens while the lone
didChangeScreenParameters notification fires mid-transition, which
briefly left the overlay multiplying a strip of the neighboring display.
(3) The HDR toggle row re-reads live state on debounced screen
reconfigurations, so HDR changes made in System Settings while the panel
is open are reflected within a second.

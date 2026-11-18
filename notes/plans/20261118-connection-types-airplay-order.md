# Connection types, AirPlay displays, panel order (2026-11-18)

James: "更新candela，让他支持airplay和外接显示器的外接方式，排序等等".
Scope he picked (AskUserQuestion): recognise + try to connect AirPlay from Candela (fall back to recognise only and say so), and a user-set display order in the panel.

## Findings (measured, 11-18, macOS 26, M5 Pro)
- `CoreDisplay_DisplayCreateInfoDictionary(id)` has `kCGDisplayIsAirPlay`, `kCGDisplayIsVirtualDevice`, `IODisplayLocation` (IOService path of the framebuffer), `IODisplayIsHDMISink`.
- The framebuffer at that path (IOMobileFramebufferShim) has `Transport = {Upstream=DP, Downstream=HDMI|DP}`. Here M28U is HDMI and VX1622 is DP.
- In-app AirPlay connect is **blocked**: `AVOutputDeviceDiscoverySession` returns 0 devices and `+[AVOutputContext sharedSystemScreenContext]` returns nil in an unentitled process. Bonjour does see 7 receivers. Control Center holds `com.apple.avfoundation.allows-access-to-device-list`, `allow-system-wide-context` and `allows-set-output-device`, which are Apple-only entitlements.
- Control Center's AX tree is empty from outside, so UI-driving it isn't an option either.

## Build
1. `DisplayConnection` (pure classifier) covers Built-in, HDMI, DisplayPort, AirPlay, Sidecar, Virtual and External, with unit tests.
2. `DisplayConnectionService` reads CoreDisplay and IORegistry. `DisplayInfo.connection` is set on add and on screen-parameter change.
3. The panel row subtitle reads "HDMI · 2560 × 1440".
4. Panel order:
   - `DisplayOrder` is pure, with tests.
   - The order persists by display UUID.
   - Reordering is available from the row's context menu (Move Up / Move Down / Reset) and from an "Order" card on the display page.
5. AirPlay display page gets a "Use as separate display" switch (mirror vs extend, via MirrorService), like Sidecar.
6. Tools page gets an "AirPlay Display" row that opens System Settings › Displays, where the "+" menu connects AirPlay.
7. Three languages, then make check, release 0.3.0 (minor), and install the notarized build.

## Acceptance
- [x] Tests green (124), lint + loc-key check green; hant-check was already broken in 0.2.2 (catalog re-serialised as JSON) — not fixed, translations complete per check-translations.py
- [x] Panel shows HDMI (M28U) / DisplayPort (VX1622) — window-ID capture of the panel only
- [x] Saved order applied after relaunch (wrote the pref, relaunched, order flipped; pref removed after)
- [x] v0.3.0 released + notarized, appcast + tap updated, /Applications = 0.3.0 Notarized Developer ID; CI green again (f6f8299)

## Not verifiable here
- A real AirPlay display: connecting one would change James's live display setup.
- Sidecar classification also needs an iPad connected.

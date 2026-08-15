# Extra Brightness (EDR Upscaling) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-display "Extra Brightness" toggle that extends the existing brightness slider and keys beyond 100% by compositing an EDR multiply overlay, on built-in XDR panels and external HDR monitors.

**Architecture:** A fullscreen invisible EDR Metal overlay per boosted display multiplies all content into the HDR headroom (`EDROverlayManager`, modeled on `NotchOverlayManager`). `BrightnessBoostService` owns policy: eligibility, HDR mode switching for externals (private MonitorPanel.framework, same dlopen pattern as `DisplayPresetService`), persistence, lifecycle. `DisplayInfo` gains a per-display `maxBrightness` ceiling; `BrightnessService` pins hardware at 100 and routes the excess to the overlay.

**Tech Stack:** Swift 6 (`-swift-version 5` in the dev loop), SwiftUI + AppKit, Metal (CAMetalLayer EDR), CoreGraphics, private MonitorPanel.framework via dlopen/KVC.

**Spec:** `docs/superpowers/specs/2026-08-04-brightness-upscaling-design.md`

**Build/check commands:**
- Compile check: `make compile` (swiftc, no Xcode needed). Expected: exits 0, prints "Done. ./Crisp-bin built".
- Run on machine: `make dev` (swaps binary into /Applications/Crisp.app and relaunches).
- Boost math check: `cat Crisp/Utilities/BrightnessBoostMath.swift scripts/check-boost-math.swift | swift -` (created in Task 2).
- Translations gate: `python3 scripts/check-translations.py`.

**House rules that apply to every task:**
- No em dashes in comments, strings, or commit messages.
- New user-facing strings go through `Localizable.xcstrings` with a zh-Hans unit (Task 7).
- Never write gamma tables from new code; the overlay path must not touch `CGSetDisplayTransferByTable`.
- `@MainActor` for anything owning NSWindow/NSView or published UI state.

---

### Task 1: Hardware spike (validate the technique before building anything)

Proves on this machine: (a) the EDR multiply overlay visibly brightens the screen, (b) what EDR headroom values macOS reports per display, (c) which MonitorPanel selectors exist for external HDR mode. Findings feed constants and selector names in Tasks 3-4.

**Files:**
- Create: `scripts/edr-spike.swift`

- [ ] **Step 1: Write the spike script**

```swift
// Diagnostic spike for the Extra Brightness feature. Run: swift scripts/edr-spike.swift
// 1) Prints EDR headroom values for every screen.
// 2) Dumps MonitorPanel MPDisplay HDR-related properties/selectors per display.
// 3) Shows a fullscreen EDR multiply overlay (factor 1.5) on the main screen for 8s.
//    Expected on an XDR/HDR display: the whole desktop visibly brightens.
import AppKit
import Metal
import ObjectiveC.runtime

// ---- 1) EDR headroom per screen ----
for screen in NSScreen.screens {
    let did = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    print("screen \(did) '\(screen.localizedName)'")
    print("  maximumEDR (current):   \(screen.maximumExtendedDynamicRangeColorComponentValue)")
    print("  maximumPotentialEDR:    \(screen.maximumPotentialExtendedDynamicRangeColorComponentValue)")
    print("  maximumReferenceEDR:    \(screen.maximumReferenceExtendedDynamicRangeColorComponentValue)")
}

// ---- 2) MonitorPanel HDR probe ----
if dlopen("/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel", RTLD_LAZY) != nil,
   let cls = NSClassFromString("MPDisplayMgr") as? NSObject.Type {
    let mgr = cls.init()
    if let displays = mgr.value(forKey: "displays") as? [NSObject] {
        for d in displays {
            let did = d.value(forKey: "displayID") as? UInt32 ?? 0
            print("MPDisplay \(did):")
            // Dump every property name so we discover the real HDR key names.
            var count: UInt32 = 0
            if let props = class_copyPropertyList(object_getClass(d), &count) {
                let names = (0..<Int(count)).map { String(cString: property_getName(props[$0])) }
                free(props)
                print("  properties: \(names.sorted().joined(separator: ", "))")
            }
            // Probe the candidate HDR selectors directly.
            for sel in ["hasHDRModes", "preferHDRModes", "setPreferHDRModes:"] {
                print("  responds to \(sel): \(d.responds(to: NSSelectorFromString(sel)))")
            }
        }
    }
} else {
    print("MonitorPanel unavailable")
}

// ---- 3) EDR multiply overlay on the main screen ----
guard let screen = NSScreen.main else { exit(1) }
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless],
                      backing: .buffered, defer: false, screen: screen)
window.isReleasedWhenClosed = false
window.backgroundColor = .clear
window.isOpaque = false
window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
window.ignoresMouseEvents = true
window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
window.hasShadow = false

let metalLayer = CAMetalLayer()
let device = MTLCreateSystemDefaultDevice()!
metalLayer.device = device
metalLayer.pixelFormat = .rgba16Float
metalLayer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
metalLayer.wantsExtendedDynamicRangeContent = true
metalLayer.isOpaque = false
metalLayer.frame = CGRect(origin: .zero, size: screen.frame.size)
// Uniform color: an 8x8 drawable scaled to fullscreen costs nothing.
metalLayer.drawableSize = CGSize(width: 8, height: 8)
metalLayer.compositingFilter = "multiplyBlendMode"

let host = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
host.wantsLayer = true
host.layer = metalLayer
window.contentView = host

let factor = 1.5
let queue = device.makeCommandQueue()!
func render() {
    guard let drawable = metalLayer.nextDrawable() else { print("no drawable"); return }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = drawable.texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColor(red: factor, green: factor, blue: factor, alpha: 1.0)
    let cmd = queue.makeCommandBuffer()!
    cmd.makeRenderCommandEncoder(descriptor: pass)!.endEncoding()
    cmd.present(drawable)
    cmd.commit()
}
render()
window.orderFrontRegardless()
print("Overlay up at factor \(factor) for 8 seconds. Screen should visibly brighten...")
DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
    window.close()
    print("Done.")
    app.terminate(nil)
}
app.run()
```

- [ ] **Step 2: Run it and record findings**

Run: `swift scripts/edr-spike.swift`
Expected: prints EDR values (built-in XDR should show maximumPotentialEDR well above 1.0), MPDisplay property dump, then the screen visibly brightens for 8 seconds. Ask the user to confirm the brightening if the executor cannot observe it.

Record in the commit message and in a comment at the top of the script:
- the reported EDR numbers per display
- which HDR property/selector names MPDisplay actually has (search the property dump for names containing "hdr"/"HDR")
- whether the overlay visibly brightened

**If the overlay does not brighten:** try `compositingFilter = "multiply"` instead of `"multiplyBlendMode"`, and confirm the display is not in a reference preset that disables EDR. STOP and reassess with the user if neither works, the whole approach depends on this step.

- [ ] **Step 3: Commit**

```bash
git add scripts/edr-spike.swift
git commit -m "chore: add EDR overlay hardware spike script with findings"
```

---

### Task 2: BrightnessBoostMath (pure logic + runnable check)

The only pure logic in the feature: slider ceiling from headroom, and overlay factor from a slider value. TDD via a swiftc-compiled assert script (the repo has no XCTest target and the dev loop is Command Line Tools only; this mirrors the `scripts/check-translations.py` check-script precedent).

**Files:**
- Create: `Crisp/Utilities/BrightnessBoostMath.swift`
- Create: `scripts/check-boost-math.swift`

- [ ] **Step 1: Write the failing check**

```swift
// scripts/check-boost-math.swift
// Runnable check for BrightnessBoostMath. Build and run:
//   cat Crisp/Utilities/BrightnessBoostMath.swift scripts/check-boost-math.swift | swift -

// sliderMax: no meaningful headroom means the scale stays at 100.
assert(BrightnessBoostMath.sliderMax(potentialHeadroom: 1.0) == 100)
assert(BrightnessBoostMath.sliderMax(potentialHeadroom: 1.04) == 100)
// Modest HDR monitor: honest small extension.
assert(BrightnessBoostMath.sliderMax(potentialHeadroom: 1.3) == 130)
// XDR reports huge potential (16.0); the UI scale caps at 200%.
assert(BrightnessBoostMath.sliderMax(potentialHeadroom: 16.0) == 200)

// overlayFactor: at or below 100 there is no boost.
assert(BrightnessBoostMath.overlayFactor(brightness: 50, sliderMax: 200, currentHeadroom: 2.0) == 1.0)
assert(BrightnessBoostMath.overlayFactor(brightness: 100, sliderMax: 200, currentHeadroom: 2.0) == 1.0)
// Midpoint of the boost region maps to the midpoint of available headroom.
assert(abs(BrightnessBoostMath.overlayFactor(brightness: 150, sliderMax: 200, currentHeadroom: 2.0) - 1.5) < 0.001)
// Top of the slider asks for exactly the current headroom, never more.
assert(abs(BrightnessBoostMath.overlayFactor(brightness: 200, sliderMax: 200, currentHeadroom: 1.6) - 1.6) < 0.001)
// Values past the slider max clamp to the headroom.
assert(abs(BrightnessBoostMath.overlayFactor(brightness: 400, sliderMax: 200, currentHeadroom: 1.6) - 1.6) < 0.001)
// Degenerate inputs never produce a boost.
assert(BrightnessBoostMath.overlayFactor(brightness: 150, sliderMax: 100, currentHeadroom: 2.0) == 1.0)
assert(BrightnessBoostMath.overlayFactor(brightness: 150, sliderMax: 200, currentHeadroom: 1.0) == 1.0)

print("check-boost-math: all assertions passed")
```

- [ ] **Step 2: Run to verify it fails**

Run: `swiftc -swift-version 5 Crisp/Utilities/BrightnessBoostMath.swift scripts/check-boost-math.swift -o /tmp/check-boost-math`
Expected: FAILS to compile ("no such file" for BrightnessBoostMath.swift).

- [ ] **Step 3: Implement the math**

```swift
// Crisp/Utilities/BrightnessBoostMath.swift
import Foundation

/// Pure mapping logic for the Extra Brightness (EDR upscaling) feature.
/// Kept free of AppKit so scripts/check-boost-math.swift can compile it standalone.
enum BrightnessBoostMath {
    /// UI slider ceiling for a display, from its potential EDR headroom.
    /// Headroom at or below 1.05 is noise, not a usable boost. XDR panels report
    /// very large potential values (16.0); the scale caps at 200% so the boost
    /// region stays a meaningful fraction of the slider.
    static func sliderMax(potentialHeadroom: Double) -> Double {
        guard potentialHeadroom > 1.05 else { return 100 }
        return (100 * min(potentialHeadroom, 2.0)).rounded()
    }

    /// Overlay multiplier for a brightness value on the extended scale.
    /// 0...100 is the hardware range (factor 1.0). 100...sliderMax maps linearly
    /// onto 1.0...currentHeadroom, clamped, so the top of the slider always asks
    /// for exactly what the display can give right now (headroom is dynamic:
    /// macOS shrinks it under thermal load and at low panel brightness).
    static func overlayFactor(brightness: Double, sliderMax: Double, currentHeadroom: Double) -> Double {
        guard brightness > 100, sliderMax > 100, currentHeadroom > 1.0 else { return 1.0 }
        let t = min(1.0, (brightness - 100) / (sliderMax - 100))
        return 1.0 + t * (currentHeadroom - 1.0)
    }
}
```

- [ ] **Step 4: Run the check to verify it passes**

Run: `cat Crisp/Utilities/BrightnessBoostMath.swift scripts/check-boost-math.swift | swift -`
Expected: `check-boost-math: all assertions passed`

- [ ] **Step 5: Verify the app still compiles**

Run: `make compile`
Expected: exits 0.

- [ ] **Step 6: Commit**

```bash
git add Crisp/Utilities/BrightnessBoostMath.swift scripts/check-boost-math.swift
git commit -m "feat: add BrightnessBoostMath mapping with runnable check"
```

---

### Task 3: EDROverlayManager

Per-display EDR multiply overlay windows. Mirrors `NotchOverlayManager` (Crisp/Services/NotchOverlayManager.swift) exactly in lifecycle shape; the Metal layer content is new and comes straight from the validated spike.

**Files:**
- Create: `Crisp/Services/EDROverlayManager.swift`

- [ ] **Step 1: Implement the manager**

Use the spike's validated `compositingFilter` string (Task 1 findings); the code below assumes `"multiplyBlendMode"`, adjust if the spike settled on `"multiply"`.

```swift
// Crisp/Services/EDROverlayManager.swift
import AppKit
import Metal
import QuartzCore

/// Fullscreen invisible EDR overlay per display that multiplies all content
/// beneath it into the HDR headroom, brightening the whole desktop beyond the
/// SDR maximum. Lifecycle mirrors NotchOverlayManager: one borderless
/// click-through window per CGDirectDisplayID, torn down when the screen goes
/// away. Content is a uniform EDR color (value > 1.0) in a CAMetalLayer with a
/// multiply compositing filter; it re-renders only when the factor changes, so
/// idle GPU cost is zero.
@MainActor
final class EDROverlayManager {
    static let shared = EDROverlayManager()

    private struct Overlay {
        let window: NSWindow
        let layer: CAMetalLayer
        var factor: Double
    }

    private var overlays: [CGDirectDisplayID: Overlay] = [:]
    private let device = MTLCreateSystemDefaultDevice()
    private lazy var commandQueue = device?.makeCommandQueue()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Apply a multiplier to a display. factor <= 1.0 removes the overlay.
    /// Returns false when an overlay was needed but could not be created
    /// (no Metal device, no screen), so callers can revert the toggle.
    @discardableResult
    func setFactor(_ factor: Double, for displayID: CGDirectDisplayID) -> Bool {
        guard factor > 1.001 else {
            removeOverlay(for: displayID)
            return true
        }
        if overlays[displayID] == nil {
            guard makeOverlay(for: displayID) else { return false }
        }
        guard var overlay = overlays[displayID] else { return false }
        // Skip sub-0.5% changes to avoid pointless re-renders during fades.
        guard abs(overlay.factor - factor) > 0.005 else { return true }
        overlay.factor = factor
        overlays[displayID] = overlay
        render(overlay)
        return true
    }

    func removeOverlay(for displayID: CGDirectDisplayID) {
        overlays[displayID]?.window.close()
        overlays.removeValue(forKey: displayID)
    }

    func removeAll() {
        for id in Array(overlays.keys) { removeOverlay(for: id) }
    }

    /// Re-render every overlay (Metal drawables can be lost across sleep).
    func rerenderAll() {
        for overlay in overlays.values { render(overlay) }
    }

    private func makeOverlay(for displayID: CGDirectDisplayID) -> Bool {
        guard let screen = NSScreen.screen(for: displayID),
              let device else { return false }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        // One notch above the notch cover so multiply applies to everything;
        // multiplying the notch cover's black stays black, so order is safe
        // either way, but a deterministic z-order beats an ambient one.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.hasShadow = false

        let metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .rgba16Float
        metalLayer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        metalLayer.wantsExtendedDynamicRangeContent = true
        metalLayer.isOpaque = false
        metalLayer.frame = CGRect(origin: .zero, size: screen.frame.size)
        // Uniform color: an 8x8 drawable scaled to fullscreen costs nothing.
        metalLayer.drawableSize = CGSize(width: 8, height: 8)
        metalLayer.compositingFilter = "multiplyBlendMode"

        let host = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        host.wantsLayer = true
        host.layer = metalLayer
        window.contentView = host
        window.orderFrontRegardless()

        overlays[displayID] = Overlay(window: window, layer: metalLayer, factor: 1.0)
        return true
    }

    private func render(_ overlay: Overlay) {
        guard let commandQueue,
              let drawable = overlay.layer.nextDrawable() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let f = overlay.factor
        pass.colorAttachments[0].clearColor = MTLClearColor(red: f, green: f, blue: f, alpha: 1.0)
        guard let cmd = commandQueue.makeCommandBuffer(),
              let encoder = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    @objc private func screenParametersChanged() {
        var toRemove: [CGDirectDisplayID] = []
        for (displayID, overlay) in overlays {
            guard let screen = NSScreen.screen(for: displayID) else {
                overlay.window.close()
                toRemove.append(displayID)
                continue
            }
            overlay.window.setFrame(screen.frame, display: true)
            overlay.layer.frame = CGRect(origin: .zero, size: screen.frame.size)
        }
        for id in toRemove { overlays.removeValue(forKey: id) }
    }
}
```

- [ ] **Step 2: Compile check**

Run: `make compile`
Expected: exits 0.

- [ ] **Step 3: Commit**

```bash
git add Crisp/Services/EDROverlayManager.swift
git commit -m "feat: add EDROverlayManager for per-display EDR multiply overlays"
```

---

### Task 4: BrightnessBoostService (policy: eligibility, HDR switch, persistence, lifecycle)

**Files:**
- Create: `Crisp/Services/BrightnessBoostService.swift`

Uses the HDR selector names discovered in Task 1. The code below uses the candidate names `hasHDRModes` / `preferHDRModes` / `setPreferHDRModes:`; replace them with the spike's findings if they differ. If the spike found NO working HDR selectors, keep `switchHDR` returning false and externals simply require HDR to already be on (eligibility still detects HDR-mode externals via live headroom); note that in the commit message.

- [ ] **Step 1: Implement the service**

```swift
// Crisp/Services/BrightnessBoostService.swift
import AppKit
import CoreGraphics

/// Policy brain for the Extra Brightness (EDR upscaling) feature. Decides which
/// displays can boost, maps brightness above 100% to an overlay factor (via
/// BrightnessBoostMath + EDROverlayManager), switches external monitors in and
/// out of HDR mode (private MonitorPanel.framework, same dlopen + KVC pattern
/// as DisplayPresetService), and persists the per-display toggle by displayUUID.
@MainActor
final class BrightnessBoostService {
    static let shared = BrightnessBoostService()

    /// MPDisplayMgr instance; nil when MonitorPanel is unavailable.
    private let manager: NSObject? = {
        guard dlopen("/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel", RTLD_LAZY) != nil,
              let cls = NSClassFromString("MPDisplayMgr") as? NSObject.Type else { return nil }
        return cls.init()
    }()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - Persistence (displayUUID keyed, survives displayID reassignment)

    private func enabledKey(_ uuid: String) -> String { "crisp.BoostEnabled.\(uuid)" }
    private func switchedHDRKey(_ uuid: String) -> String { "crisp.BoostSwitchedHDR.\(uuid)" }

    func isEnabled(for display: DisplayInfo) -> Bool {
        UserDefaults.standard.bool(forKey: enabledKey(display.displayUUID))
    }

    // MARK: - Screen and headroom helpers

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screen(for: displayID)
    }

    /// Potential headroom: what the display could do (basis for eligibility and
    /// the slider ceiling). 1.0 on SDR-only displays.
    private func potentialHeadroom(for displayID: CGDirectDisplayID) -> Double {
        guard let s = screen(for: displayID) else { return 1.0 }
        return Double(s.maximumPotentialExtendedDynamicRangeColorComponentValue)
    }

    /// Current headroom: what the display can do right now (basis for the
    /// overlay factor; macOS moves this with panel brightness and thermals).
    private func currentHeadroom(for displayID: CGDirectDisplayID) -> Double {
        guard let s = screen(for: displayID) else { return 1.0 }
        return Double(s.maximumExtendedDynamicRangeColorComponentValue)
    }

    // MARK: - Eligibility

    /// A display can boost when it reports usable EDR headroom (built-in XDR,
    /// or an external already in HDR mode) or when we know how to switch it
    /// into HDR mode (external with MonitorPanel HDR support).
    func isEligible(_ display: DisplayInfo) -> Bool {
        guard display.isOnline, !VirtualDisplayService.shared.isVirtualDisplay(display.displayID) else { return false }
        if potentialHeadroom(for: display.displayID) > 1.05 { return true }
        if !display.isBuiltin, supportsHDRMode(display.displayID) { return true }
        return false
    }

    // MARK: - Toggle

    /// Enable or disable boost. Async because switching an external monitor to
    /// HDR mode takes a moment to settle. Returns false when enabling failed
    /// (caller reverts the toggle UI).
    @discardableResult
    func setEnabled(_ enabled: Bool, for display: DisplayInfo) async -> Bool {
        let uuid = display.displayUUID
        if enabled {
            // Externals in SDR mode: switch to HDR first, remember that we did.
            if !display.isBuiltin, potentialHeadroom(for: display.displayID) <= 1.05 {
                guard supportsHDRMode(display.displayID), setHDRMode(true, for: display.displayID) else { return false }
                UserDefaults.standard.set(true, forKey: switchedHDRKey(uuid))
                // Give WindowServer a moment to re-sync the display in HDR mode.
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            let potential = potentialHeadroom(for: display.displayID)
            let newMax = BrightnessBoostMath.sliderMax(potentialHeadroom: potential)
            guard newMax > 100 else {
                // HDR came up without usable headroom: undo and fail quietly.
                undoHDRSwitchIfNeeded(for: display)
                return false
            }
            UserDefaults.standard.set(true, forKey: enabledKey(uuid))
            display.maxBrightness = newMax
            syncOverlay(for: display)
            return true
        } else {
            UserDefaults.standard.set(false, forKey: enabledKey(uuid))
            display.maxBrightness = 100
            if display.brightness > 100 {
                // Settle back to hardware max; the fade also walks the overlay down.
                BrightnessService.shared.setBrightnessSmooth(100, for: display)
            }
            EDROverlayManager.shared.removeOverlay(for: display.displayID)
            undoHDRSwitchIfNeeded(for: display)
            return true
        }
    }

    private func undoHDRSwitchIfNeeded(for display: DisplayInfo) {
        let key = switchedHDRKey(display.displayUUID)
        guard UserDefaults.standard.bool(forKey: key) else { return }
        _ = setHDRMode(false, for: display.displayID)
        UserDefaults.standard.set(false, forKey: key)
    }

    // MARK: - Overlay sync (called on every brightness change)

    /// Recompute and apply the overlay factor for the display's current
    /// brightness. Spike finding: current headroom reads 1.0 until EDR content
    /// is on screen, so gating on it would deadlock the overlay off. Instead
    /// map onto the capped potential, and clamp by current headroom only once
    /// macOS has ramped it above 1. Headroom changes post
    /// didChangeScreenParameters (observed above), so the factor converges to
    /// what the panel can actually deliver within a beat of engaging.
    func syncOverlay(for display: DisplayInfo) {
        guard display.maxBrightness > 100 else { return }
        let ceiling = min(potentialHeadroom(for: display.displayID), 2.0)
        var factor = BrightnessBoostMath.overlayFactor(
            brightness: display.brightness,
            sliderMax: display.maxBrightness,
            currentHeadroom: ceiling
        )
        let current = currentHeadroom(for: display.displayID)
        if current > 1.0 { factor = min(factor, current) }
        EDROverlayManager.shared.setFactor(factor, for: display.displayID)
    }

    // MARK: - Lifecycle

    /// Re-establish boost state for every connected display. Called at launch,
    /// after wake, and on display reconfiguration.
    func reapplyAll() {
        for display in DisplayManagerAccessor.shared.displays where isEnabled(for: display) {
            guard isEligible(display) else { continue }
            let potential = potentialHeadroom(for: display.displayID)
            let newMax = BrightnessBoostMath.sliderMax(potentialHeadroom: potential)
            guard newMax > 100 else { continue }
            display.maxBrightness = newMax
            syncOverlay(for: display)
        }
        EDROverlayManager.shared.rerenderAll()
    }

    /// Quit: drop overlays (they die with the process anyway) and restore SDR
    /// on externals we switched, so a monitor is never left in HDR mode with
    /// no boost and no DDC control.
    func prepareForTermination() {
        EDROverlayManager.shared.removeAll()
        for display in DisplayManagerAccessor.shared.displays {
            undoHDRSwitchIfNeeded(for: display)
        }
    }

    @objc private func screenParametersChanged() {
        // Reconcile after connect/disconnect storms settle (mirrors the panel's
        // own debounce; mid-reconfig geometry and headroom reads are garbage).
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.reapplyAll()
        }
    }

    // MARK: - MonitorPanel HDR mode (private API; selectors verified by the Task 1 spike)

    private func mpDisplay(for displayID: CGDirectDisplayID) -> NSObject? {
        guard let displays = manager?.value(forKey: "displays") as? [NSObject] else { return nil }
        return displays.first { ($0.value(forKey: "displayID") as? UInt32) == displayID }
    }

    private func supportsHDRMode(_ displayID: CGDirectDisplayID) -> Bool {
        guard let d = mpDisplay(for: displayID) else { return false }
        return (d.value(forKey: "hasHDRModes") as? Bool) == true
    }

    @discardableResult
    private func setHDRMode(_ on: Bool, for displayID: CGDirectDisplayID) -> Bool {
        guard let d = mpDisplay(for: displayID) else { return false }
        let sel = NSSelectorFromString("setPreferHDRModes:")
        guard d.responds(to: sel) else { return false }
        typealias Fn = @convention(c) (NSObject, Selector, Bool) -> Void
        unsafeBitCast(d.method(for: sel), to: Fn.self)(d, sel, on)
        return true
    }
}
```

- [ ] **Step 2: Compile check**

Run: `make compile`
Expected: FAILS: `DisplayInfo` has no `maxBrightness` yet. That property lands in Task 5; to keep this task independently committable, add it now as part of this step (it is a one-line model change Task 5 builds on):

In `Crisp/Models/DisplayInfo.swift`, after `@Published var brightness: Double` (line 18), add:

```swift
    /// UI brightness ceiling. 100 normally; above 100 while Extra Brightness
    /// (EDR upscaling) is enabled, where the range 100...maxBrightness maps to
    /// the EDR overlay boost instead of hardware.
    @Published var maxBrightness: Double = 100.0
```

Re-run: `make compile`
Expected: exits 0.

- [ ] **Step 3: Commit**

```bash
git add Crisp/Services/BrightnessBoostService.swift Crisp/Models/DisplayInfo.swift
git commit -m "feat: add BrightnessBoostService policy and DisplayInfo.maxBrightness"
```

---

### Task 5: BrightnessService integration (extended clamps, hardware pinning, refresh guards)

**Files:**
- Modify: `Crisp/Services/BrightnessService.swift`

- [ ] **Step 1: Extend `setBrightness` (line 321)**

Replace the clamp and the built-in/external branches so hardware writes pin at 100 and the boost syncs after. The full modified method:

```swift
    @MainActor
    func setBrightness(_ brightness: Double, for display: DisplayInfo, isAutoAdjust: Bool = false) async {
        let clamped = max(0.0, min(display.maxBrightness, brightness))
        // Hardware only ever sees 0...100; the region above is the EDR overlay's.
        let hardware = min(clamped, 100.0)
        let isBuiltin = display.isBuiltin
        let displayID = display.displayID

        // Record manual adjust time so auto-brightness can honour the cooldown period.
        if !isAutoAdjust {
            manualAdjustLock.withLock {
                lastManualAdjustDate = Date()
            }
            PresetService.shared.noteManualChange()
            noteManualBrightnessChange(displayID: displayID, isBuiltin: isBuiltin, value: clamped)
        }

        if isBuiltin {
            let value = Float(hardware / 100.0)
            display.brightness = clamped
            queue.async { [weak self] in
                self?.setInternalBrightness(value)
            }
        } else {
            display.brightness = clamped
            // Check current DDC availability status
            let currentStatus: Bool? = ddcAvailableLock.withLock { ddcAvailable[displayID] }

            if currentStatus == false {
                // DDC known unavailable, go straight to software fallback
                queue.async { [weak self] in
                    self?.setSoftwareBrightness(hardware, for: displayID)
                }
            } else {
                writeDDCBrightnessCoalesced(percent: hardware, for: displayID)
            }
        }
        BrightnessBoostService.shared.syncOverlay(for: display)
    }
```

Note the external branch also gains `display.brightness = clamped` (the built-in branch already had it); callers that set `display.brightness` themselves are unaffected, and the boost sync needs the model value current.

- [ ] **Step 2: Extend `setBrightnessSmooth` (line 504)**

Replace the clamp line and all three animate handlers:

```swift
        let clamped = max(0.0, min(display.maxBrightness, targetBrightness))
```

Built-in handler:

```swift
            anim.animate(from: fromBrightness, to: clamped, steps: smoothSteps, duration: duration) { [weak self, weak display] value, _ in
                guard let self, let display else { return }
                display.brightness = value
                let floatVal = Float(min(value, 100.0) / 100.0)
                self.queue.async { self.setInternalBrightness(floatVal) }
                BrightnessBoostService.shared.syncOverlay(for: display)
            }
```

Software (gamma) handler:

```swift
                anim.animate(from: fromBrightness, to: clamped, steps: smoothSteps, duration: duration) { [weak display] value, _ in
                    guard let display else { return }
                    display.brightness = value
                    BrightnessService.shared.setSoftwareBrightness(min(value, 100.0), for: displayID)
                    BrightnessBoostService.shared.syncOverlay(for: display)
                }
```

DDC handler:

```swift
                anim.animate(from: fromBrightness, to: clamped, steps: smoothSteps, duration: duration) { [weak self, weak display] value, _ in
                    guard let self, let display else { return }
                    display.brightness = value
                    self.writeDDCBrightnessCoalesced(percent: min(value, 100.0), for: displayID)
                    BrightnessBoostService.shared.syncOverlay(for: display)
                }
```

(The handlers run on the main thread via `BrightnessAnimator`'s main-runloop Timer, and `setBrightnessSmooth` is `@MainActor`, so calling the `@MainActor` boost service from them is safe; match the existing pattern of touching `display.brightness` there.)

- [ ] **Step 3: Guard hardware read-back from clobbering a boosted value**

While boosted above 100, the hardware reads ~100 and every read-back path would snap the model (and slider) down. Crisp owns the value while boosting, so skip adoption when boosted:

In `refreshBrightness` (line 230), at the top of the method body add:

```swift
        // While boosted above 100 the hardware pins at max and reads back ~100;
        // adopting that would snap the slider out of the boost region. Crisp
        // owns the value while Extra Brightness is engaged.
        if display.brightness > 100.0 { return }
```

In the top-level callback `_crispBuiltinBrightnessChanged` (line 49), inside the `Task { @MainActor in ... }` after the `display` guard, add the same skip before the jitter check:

```swift
        guard display.brightness <= 100.0 else { return }
```

- [ ] **Step 4: Compile check**

Run: `make compile`
Expected: exits 0.

- [ ] **Step 5: Commit**

```bash
git add Crisp/Services/BrightnessService.swift
git commit -m "feat: route brightness above 100 to the EDR boost overlay"
```

---

### Task 6: Slider, combined slider, brightness keys, HUD scaling

**Files:**
- Modify: `Crisp/Views/BrightnessSliderView.swift`
- Modify: `Crisp/Services/BrightnessKeyService.swift`

- [ ] **Step 1: Per-display slider range (BrightnessSliderView.swift line 108)**

```swift
                Slider(value: $localBrightness, in: 0...max(100.0, display.maxBrightness)) { editing in
```

And the accessibility value (line 141) becomes percent-of-extended-scale as a raw number (unchanged format, values can now exceed 100, which is the honest reading):

no change needed, `"\(Int(localBrightness))%"` already reports it.

The step helper (line 199) clamps to the ceiling:

```swift
    private func step(_ delta: Double) {
        let target = max(0, min(display.maxBrightness, display.brightness + delta))
        // The smooth fade updates display.brightness per frame; localBrightness
        // follows through the existing onChange sync.
        BrightnessService.shared.setBrightnessSmooth(target, for: display)
    }
```

- [ ] **Step 2: Combined slider goes proportional (CombinedBrightnessView, line 207)**

The combined scale stays 0...100; each display maps it onto its own range, which is identical to today for non-boosted displays. Replace `averageBrightness`:

```swift
    private var averageBrightness: Double {
        guard !displays.isEmpty else { return 50 }
        // Proportional: each display contributes its position within its own
        // range, so a boosted display at 160/160 and a plain one at 100/100
        // both read as 100%.
        return displays.map { $0.brightness / $0.maxBrightness * 100.0 }.reduce(0, +) / Double(displays.count)
    }
```

And every place the combined view pushes a value to a display converts the 0...100 combined value onto that display's range. Four call sites inside `CombinedBrightnessView.body` and `stepAll`:

Click-glide (line 248):

```swift
                            for display in displays {
                                BrightnessService.shared.setBrightnessSmooth(combinedBrightness / 100.0 * display.maxBrightness, for: display)
                            }
```

Drag-end flush (line 257):

```swift
                                for display in displays {
                                    await BrightnessService.shared.setBrightness(combinedBrightness / 100.0 * display.maxBrightness, for: display)
                                }
```

Live drag (line 277):

```swift
                    Task { @MainActor in
                        for display in displays {
                            let target = newValue / 100.0 * display.maxBrightness
                            display.brightness = target
                            await BrightnessService.shared.setBrightness(target, for: display)
                        }
                    }
```

`stepAll` (line 313):

```swift
    private func stepAll(_ delta: Double) {
        let target = max(0, min(100, combinedBrightness + delta))
        for display in displays {
            BrightnessService.shared.setBrightnessSmooth(target / 100.0 * display.maxBrightness, for: display)
        }
    }
```

- [ ] **Step 3: Brightness keys walk past 100 (BrightnessKeyService.swift lines 366 and 390)**

Both clamp sites change from the literal 100 to the display's ceiling, and the HUD shows position on the extended scale. Line 366 (under-cursor path):

```swift
            let newBrightness = max(0.0, min(display.maxBrightness, display.brightness + step))
```

and its HUD call (line 374):

```swift
                BrightnessHUDService.shared.show(brightness: newBrightness / display.maxBrightness * 100.0, on: screen)
```

Line 390 (`adjustDisplays`):

```swift
            let newBrightness = max(0.0, min(display.maxBrightness, display.brightness + step))
```

and its HUD call (line 395):

```swift
                BrightnessHUDService.shared.show(brightness: newBrightness / display.maxBrightness * 100.0, on: screen)
```

- [ ] **Step 4: Compile check**

Run: `make compile`
Expected: exits 0.

- [ ] **Step 5: Commit**

```bash
git add Crisp/Views/BrightnessSliderView.swift Crisp/Services/BrightnessKeyService.swift
git commit -m "feat: extend brightness slider, combined slider, and keys past 100"
```

---

### Task 7: Extra Brightness toggle row + localization

**Files:**
- Create: `Crisp/Views/ExtraBrightnessView.swift`
- Modify: `Crisp/Views/DisplayDetailView.swift:77`
- Modify: `Crisp/Resources/Localizable.xcstrings`

- [ ] **Step 1: The toggle row (mirrors NotchView's shape exactly)**

```swift
// Crisp/Views/ExtraBrightnessView.swift
import SwiftUI
import AppKit

/// Per-display "Extra Brightness" toggle: unlocks the brightness slider beyond
/// 100% by engaging the EDR upscaling overlay. Rendered only for displays that
/// can actually boost (built-in XDR panels, HDR-capable externals). For an
/// external in SDR mode, enabling also switches the monitor into HDR mode.
struct ExtraBrightnessView: View {
    @ObservedObject var display: DisplayInfo
    @State private var isOn: Bool = false
    @State private var isHovered = false
    /// Guards the onChange handler while we set isOn programmatically
    /// (initial sync, revert on failure), so those writes do not re-trigger
    /// the service.
    @State private var isProgrammaticChange = false

    var body: some View {
        if BrightnessBoostService.shared.isEligible(display) {
            HStack {
                MenuItemIcon(systemName: "sun.max.fill", color: .yellow, active: isOn)
                Text("Extra Brightness")
                    .font(.body)
                Spacer()
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .onChange(of: isOn) { _, newValue in
                        guard !isProgrammaticChange else { return }
                        Task { @MainActor in
                            let ok = await BrightnessBoostService.shared.setEnabled(newValue, for: display)
                            if !ok {
                                // Quiet revert, per the spec: no dialogs.
                                isProgrammaticChange = true
                                isOn = false
                                isProgrammaticChange = false
                            }
                        }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .menuRowHover(isHovered)
            .onHover { isHovered = $0 }
            .onAppear {
                isProgrammaticChange = true
                isOn = BrightnessBoostService.shared.isEnabled(for: display)
                isProgrammaticChange = false
            }
        }
    }
}
```

- [ ] **Step 2: Add the row to DisplayDetailView**

In `Crisp/Views/DisplayDetailView.swift`, after `DisconnectDisplayRow(display: display)` (line 77) and before `SystemAutoBrightnessView(display: display)`, insert:

```swift
            // Extra Brightness (EDR upscaling), shown only for displays with
            // usable HDR headroom (built-in XDR, HDR-capable externals)
            ExtraBrightnessView(display: display)
```

- [ ] **Step 3: Localize the new string**

Open `Crisp/Resources/Localizable.xcstrings` (JSON). Add this entry to the top-level `"strings"` dictionary, alphabetically ordered among its siblings, matching the shape of existing entries:

```json
    "Extra Brightness" : {
      "extractionState" : "manual",
      "localizations" : {
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "额外亮度"
          }
        }
      }
    },
```

Run: `python3 scripts/check-translations.py`
Expected: passes (no missing zh-Hans units).

- [ ] **Step 4: Compile check**

Run: `make compile`
Expected: exits 0.

- [ ] **Step 5: Commit**

```bash
git add Crisp/Views/ExtraBrightnessView.swift Crisp/Views/DisplayDetailView.swift Crisp/Resources/Localizable.xcstrings
git commit -m "feat: add Extra Brightness toggle row to display details"
```

---

### Task 8: App lifecycle hooks (launch, wake, quit)

**Files:**
- Modify: `Crisp/App/AppDelegate.swift:191` (launch), `Crisp/App/AppDelegate.swift:294-301` (wake loop), `Crisp/App/AppDelegate.swift:269-276` (terminate)

- [ ] **Step 1: Launch reapply**

In `applicationDidFinishLaunching`, right after `_ = AutoBrightnessService.shared` (line 191), add:

```swift
        // Re-establish Extra Brightness (EDR upscaling) for displays whose
        // toggle is persisted on. Deferred a beat so DisplayManager's initial
        // display list is populated.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            BrightnessBoostService.shared.reapplyAll()
        }
```

- [ ] **Step 2: Wake reapply**

In `setupStartupBehavior`'s `onWake` closure, after the `for display in dm.displays { ... }` loop (line 301), add:

```swift
                // Re-establish EDR boost overlays (Metal drawables and HDR
                // mode may not survive sleep).
                BrightnessBoostService.shared.reapplyAll()
```

- [ ] **Step 3: Quit restore**

In `applicationWillTerminate` (line 269), before `VirtualDisplayService.shared.destroyAll()`, add:

```swift
        // Drop EDR overlays and restore SDR on externals Crisp switched to HDR,
        // so no monitor is left bright with no boost and no DDC control.
        BrightnessBoostService.shared.prepareForTermination()
```

- [ ] **Step 4: Compile check**

Run: `make compile`
Expected: exits 0.

- [ ] **Step 5: Commit**

```bash
git add Crisp/App/AppDelegate.swift
git commit -m "feat: wire Extra Brightness into launch, wake, and quit lifecycle"
```

---

### Task 9: On-hardware verification (manual checklist)

**Files:** none (verification only). Run `make dev` to install the build, then walk the checklist with the user. Record results; any failure becomes a fix task before this feature is called done.

- [ ] **Step 1: Install the build**

Run: `make dev`
Expected: compiles, swaps into /Applications/Crisp.app, relaunches.

- [ ] **Step 2: Built-in panel checklist (user confirms visually)**

1. Built-in XDR display shows the "Extra Brightness" row; an SDR external (if any) does not.
2. Toggle on: slider range extends (thumb position shifts proportionally); dragging past 100% visibly brightens beyond the normal max.
3. Brightness keys walk past 100% with native OSD chiclets tracking the extended scale.
4. Slider below 100% behaves exactly as before (hardware backlight, no overlay).
5. Toggle off while boosted: brightness settles at 100%, screen returns to normal max.
6. Quit Crisp while boosted: extra brightness disappears (overlay dies with the process). Relaunch: boost re-establishes automatically.
7. Sleep/wake while boosted: boost re-establishes after wake.
8. Screenshot (Cmd-Shift-3) and screen recording while boosted: note (not fix) any visual differences; this is a known-caveat category.
9. Play an HDR video while boosted: expect possibly overblown highlights (documented caveat, not a bug).

- [ ] **Step 3: External HDR monitor checklist (if one is available)**

1. HDR-capable external in SDR mode shows the row; toggling on switches it to HDR (brief blink), then the slider extends.
2. Boost region brightens visibly (magnitude depends on the monitor's real headroom).
3. Below 100%, brightness control still works (DDC in HDR mode is flaky on many monitors; software dimming fallback is acceptable and expected on some).
4. Toggle off restores SDR mode.
5. Combined slider with one boosted and one normal display: both move proportionally through their own ranges.
6. Quit Crisp with a boosted external: monitor returns to SDR.
7. Unplug and replug the boosted external: boost re-establishes after the reconnect settles.

- [ ] **Step 4: Update README feature list**

In `README.md`, extend the "Brightness everywhere" bullet with the new capability, matching the existing voice:

```markdown
- **Brightness everywhere**: controls the real backlight of external monitors (DDC), dims via software on monitors that don't support that, and can keep dimming below the hardware minimum. Extra Brightness pushes XDR MacBook screens and HDR monitors beyond 100% using their HDR headroom (a BetterDisplay Pro feature, free here). Smooth fades, and brightness keys that follow the pointer, target all displays, or a chosen subset
```

- [ ] **Step 5: Final commit**

```bash
git add README.md
git commit -m "docs: mention Extra Brightness in the README feature list"
```

---

## Deviations and escalation

- If the Task 1 spike shows the overlay does not brighten with either compositing filter string, STOP: the core approach needs rethinking with the user (options: CoreImage/CIColorMatrix variant, gamma approach). Do not build Tasks 3-9 on an unvalidated technique.
- If MonitorPanel has no usable HDR selectors, ship built-in-XDR plus already-in-HDR externals (eligibility handles this automatically), and record a follow-up for HDR switching. That is a scope note for the user, not a silent decision.
- Constants likely to need tuning from spike data: the 1.05 eligibility floor, the 2.0 slider cap, the 2s HDR settle delay. Tune from evidence, note in commits.

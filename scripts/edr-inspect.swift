// Inspection probe: run while another app's brightness boost is active to see
// which mechanism it uses. Run: swift scripts/edr-inspect.swift
// Prints, for the built-in panel: EDR headroom (current/potential), gamma table
// endpoints (a scaled table means a gamma technique), and any overlay-like
// windows other apps have parked over the screen (an EDR multiply overlay).
import AppKit

func builtinScreen() -> NSScreen? {
    NSScreen.screens.first { screen in
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }
}
guard let screen = builtinScreen(),
      let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
else { print("no built-in screen"); exit(1) }

func snapshot(_ label: String) {
    let cur = screen.maximumExtendedDynamicRangeColorComponentValue
    let pot = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
    let ref = screen.maximumReferenceExtendedDynamicRangeColorComponentValue
    var red = [CGGammaValue](repeating: 0, count: 256)
    var green = [CGGammaValue](repeating: 0, count: 256)
    var blue = [CGGammaValue](repeating: 0, count: 256)
    var count: UInt32 = 0
    let err = CGGetDisplayTransferByTable(displayID, 256, &red, &green, &blue, &count)
    let gamma = err == .success
        ? String(format: "last RGB %.4f %.4f %.4f  max %.4f", red[255], green[255], blue[255],
                 max(red.max() ?? 0, max(green.max() ?? 0, blue.max() ?? 0)))
        : "read failed (\(err.rawValue))"
    print("\(label): currentEDR=\(String(format: "%.4f", cur)) potentialEDR=\(String(format: "%.4f", pot)) referenceEDR=\(String(format: "%.4f", ref)) | gamma \(gamma)")
}

func overlayWindows() {
    guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
    else { print("window list unavailable"); return }
    let screenArea = screen.frame.width * screen.frame.height
    print("Fullscreen-ish windows from other apps (owner, level, bounds):")
    for w in info {
        guard let owner = w[kCGWindowOwnerName as String] as? String,
              owner != "Candela", owner != "Window Server", owner != "Dock", owner != "Finder",
              let b = w[kCGWindowBounds as String] as? [String: CGFloat],
              let width = b["Width"], let height = b["Height"] else { continue }
        let level = w[kCGWindowLayer as String] as? Int ?? 0
        // High-level or near-fullscreen windows only; normal app windows are noise.
        if width * height > screenArea * 0.8 || level > 1000 {
            print("  \(owner)  level=\(level)  \(Int(width))x\(Int(height))")
        }
    }
}

print("Built-in panel \(displayID), \(Int(screen.frame.width))x\(Int(screen.frame.height))")
snapshot("t=0s")
overlayWindows()
var tick = 0
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
    tick += 1
    snapshot("t=\(tick)s")
    if tick >= 8 {
        timer.invalidate()
        overlayWindows()
        print("Done.")
        exit(0)
    }
}
RunLoop.main.run()

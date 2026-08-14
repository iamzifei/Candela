// Diagnostic for the washed-out external: per-display gamma table endpoints
// (a non-identity table means software dimming or a leftover scale is
// active) and every Candela-owned window with bounds and level (a stranded
// EDR overlay would show as a display-sized window at very high level).
// Run: swift scripts/washout-probe.swift
import AppKit

for screen in NSScreen.screens {
    guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    else { continue }
    var red = [CGGammaValue](repeating: 0, count: 256)
    var green = [CGGammaValue](repeating: 0, count: 256)
    var blue = [CGGammaValue](repeating: 0, count: 256)
    var count: UInt32 = 0
    let err = CGGetDisplayTransferByTable(id, 256, &red, &green, &blue, &count)
    let gamma = err == .success
        ? String(format: "last RGB %.4f %.4f %.4f  min %.4f", red[255], green[255], blue[255],
                 min(red[1], min(green[1], blue[1])))
        : "read failed (\(err.rawValue))"
    print("Display \(id) \(screen.localizedName): gamma \(gamma)")
}

guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
else { print("window list unavailable"); exit(1) }
print("Candela-owned on-screen windows (level, bounds):")
for w in info {
    guard let owner = w[kCGWindowOwnerName as String] as? String, owner == "Candela",
          let b = w[kCGWindowBounds as String] as? [String: CGFloat],
          let width = b["Width"], let height = b["Height"],
          let x = b["X"], let y = b["Y"] else { continue }
    let level = w[kCGWindowLayer as String] as? Int ?? 0
    print("  level=\(level)  \(Int(width))x\(Int(height)) at (\(Int(x)),\(Int(y)))")
}

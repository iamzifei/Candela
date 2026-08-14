// Runtime-floor probe for issue #22: checks every private API surface Candela
// touches, on whatever macOS it runs on. The compile floor is 14.0, but the
// dev/release binaries link with `-undefined dynamic_lookup`, so a symbol
// missing at runtime crashes at FIRST CALL, not at launch; this probe resolves
// each one explicitly and prints a PASS/FAIL table instead.
//
// Build (any Mac):  swiftc -O -target arm64-apple-macos14.0 scripts/runtime-floor-probe.swift -o runtime-floor-probe
// Run inside the target-OS VM or machine:  ./runtime-floor-probe
// Exit code: number of FAILs (0 = floor holds).
import AppKit

var failures = 0

func check(_ name: String, _ ok: Bool, note: String = "") {
    let mark = ok ? "PASS" : "FAIL"
    if !ok { failures += 1 }
    print("[\(mark)] \(name)\(note.isEmpty ? "" : "  (\(note))")")
}

func dlopenCheck(_ path: String) -> UnsafeMutableRawPointer? {
    let h = dlopen(path, RTLD_LAZY)
    check("dlopen \(path)", h != nil)
    return h
}

func symCheck(_ handle: UnsafeMutableRawPointer?, _ symbol: String) {
    guard let handle else { check("dlsym \(symbol)", false, note: "framework missing"); return }
    check("dlsym \(symbol)", dlsym(handle, symbol) != nil)
}

let version = ProcessInfo.processInfo.operatingSystemVersion
print("macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
print(String(repeating: "-", count: 60))

// MARK: DisplayServices (brightness get/set/observe, ambient light)
let ds = dlopenCheck("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices")
for sym in [
    "DisplayServicesGetBrightness",
    "DisplayServicesSetBrightness",
    "DisplayServicesRegisterForBrightnessChangeNotifications",
    "DisplayServicesUnregisterForBrightnessChangeNotifications",
    "DisplayServicesAmbientLightCompensationEnabled",
    "DisplayServicesEnableAmbientLightCompensation",
] { symCheck(ds, sym) }

// MARK: CoreDisplay (user brightness read)
let cd = dlopenCheck("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay")
symCheck(cd, "CoreDisplay_Display_GetUserBrightness")

// MARK: SkyLight (appearance theme)
let sl = dlopenCheck("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight")
for sym in [
    "SLSGetAppearanceThemeLegacy",
    "SLSSetAppearanceThemeLegacy",
    "SLSSetAppearanceThemeNotifying",
    // Bridging-header externs resolved via dynamic_lookup at first call:
    "SLSConfigureDisplayEnabled",
    "SLSGetDisplayList",
] { symCheck(sl, sym) }

// MARK: CoreGraphics/SkyLight CGS externs from the bridging header
for sym in [
    "CGSConfigureDisplayMode",
    "CGSMainConnectionID",
    "CGSGetNumberOfDisplayModes",
    "CGSGetDisplayModeDescriptionOfLength",
] { check("dynamic_lookup \(sym)", dlsym(dlopen(nil, RTLD_LAZY), sym) != nil) }

// MARK: IOAVService (Apple Silicon DDC; CoreDisplay exports these)
for sym in [
    "IOAVServiceCreate",
    "IOAVServiceCreateWithService",
    "IOAVServiceReadI2C",
    "IOAVServiceWriteI2C",
] { check("dynamic_lookup \(sym)", dlsym(dlopen(nil, RTLD_LAZY), sym) != nil) }

// MARK: CoreBrightness (Night Shift / True Tone)
_ = dlopenCheck("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness")
let cbClient = NSClassFromString("CBBlueLightClient") as? NSObject.Type
check("class CBBlueLightClient", cbClient != nil)
if let cls = cbClient {
    let inst = cls.init()
    check("CBBlueLightClient responds setStatusNotificationBlock:",
          inst.responds(to: NSSelectorFromString("setStatusNotificationBlock:")))
    check("CBBlueLightClient responds getBlueLightStatus:",
          inst.responds(to: NSSelectorFromString("getBlueLightStatus:")))
}
check("class CBTrueToneClient", NSClassFromString("CBTrueToneClient") != nil)
// Informational only: absent even on macOS 26 and optional-chained in
// CoreBrightnessService, so a miss is a degraded path, not a floor break.
print("[info] class NSGlobalPreferenceTransition: \(NSClassFromString("NSGlobalPreferenceTransition") != nil ? "present" : "absent")")

// MARK: MonitorPanel (HDR mode toggle, display presets)
_ = dlopenCheck("/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel")
let mpMgr = NSClassFromString("MPDisplayMgr") as? NSObject.Type
check("class MPDisplayMgr", mpMgr != nil)
if let mgr = mpMgr?.init() {
    let displays = mgr.value(forKey: "displays") as? [NSObject]
    check("MPDisplayMgr.displays KVC", displays != nil, note: "\(displays?.count ?? 0) displays")
    if let d = displays?.first {
        // responds(to: getter) instead of valueForKey: an undefined key throws
        // NSUnknownKeyException, which Swift cannot catch, and the probe must
        // report, not crash. Keys mirror DisplayPresetService/BrightnessBoostService.
        for key in ["displayID", "hasHDRModes", "preferHDRModes", "hasPresets", "presets", "activePreset"] {
            check("MPDisplay getter \(key)", d.responds(to: NSSelectorFromString(key)))
        }
        check("MPDisplay responds setPreferHDRModes:", d.responds(to: NSSelectorFromString("setPreferHDRModes:")))
        check("MPDisplay responds setActivePreset:", d.responds(to: NSSelectorFromString("setActivePreset:")))
        if let preset = (d.value(forKey: "presets") as? [NSObject])?.first {
            for key in ["isValid", "presetName", "presetIndex"] {
                check("MPDisplayPreset getter \(key)", preset.responds(to: NSSelectorFromString(key)))
            }
        } else {
            print("[info] no presets on first display; preset-key checks skipped")
        }
    } else {
        check("MPDisplay per-display checks", false, note: "no MPDisplays enumerated")
    }
}

// MARK: CGVirtualDisplay (virtual displays)
for cls in ["CGVirtualDisplayDescriptor", "CGVirtualDisplayMode", "CGVirtualDisplaySettings", "CGVirtualDisplay"] {
    check("class \(cls)", NSClassFromString(cls) != nil)
}

// MARK: Public but load-bearing: gamma table round trip on the main display
let mainID = CGMainDisplayID()
var r = [CGGammaValue](repeating: 0, count: 256)
var g = r; var b = r; var count: UInt32 = 0
let readErr = CGGetDisplayTransferByTable(mainID, 256, &r, &g, &b, &count)
check("CGGetDisplayTransferByTable", readErr == .success)
let writeErr = CGSetDisplayTransferByTable(mainID, count, &r, &g, &b)
check("CGSetDisplayTransferByTable (identity rewrite)", writeErr == .success)

print(String(repeating: "-", count: 60))
print(failures == 0 ? "FLOOR HOLDS: all checks passed" : "\(failures) FAILURES")
exit(Int32(failures))

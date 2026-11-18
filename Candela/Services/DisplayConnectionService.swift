import Foundation
import CoreGraphics
import IOKit

/// Reads how each display is attached: built-in, HDMI, DisplayPort, AirPlay,
/// Sidecar or virtual. The decision is `DisplayConnection.classify`; this only
/// gathers its inputs.
///
/// Two sources, both read-only:
/// - CoreDisplay's info dictionary (`CoreDisplay_DisplayCreateInfoDictionary`, a
///   private but long-stable export MonitorControl also relies on) carries
///   `kCGDisplayIsAirPlay`, `kCGDisplayIsVirtualDevice`, `IODisplayIsHDMISink`
///   and `IODisplayLocation`, the IOService path of the display's framebuffer.
/// - That framebuffer node carries `Transport = {Upstream = DP; Downstream = HDMI}`
///   on Apple Silicon. Following the path directly means no identity matching, so
///   two identical monitors cannot be crossed the way DDC channels can.
///
/// The function is looked up with dlsym rather than declared, so a macOS that drops
/// it degrades to "External" instead of failing to launch.
enum DisplayConnectionService {
    private typealias InfoDictionaryFn = @convention(c) (CGDirectDisplayID) -> Unmanaged<CFDictionary>?

    private static let infoDictionary: InfoDictionaryFn? = {
        guard let handle = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY),
              let sym = dlsym(handle, "CoreDisplay_DisplayCreateInfoDictionary")
        else { return nil }
        return unsafeBitCast(sym, to: InfoDictionaryFn.self)
    }()

    /// Classifies one display. Cheap (one dictionary copy and one registry lookup),
    /// so it runs on the main actor when a display is added or screens change.
    @MainActor
    static func connection(for displayID: CGDirectDisplayID) -> DisplayConnection {
        DisplayConnection.classify(signals(for: displayID))
    }

    @MainActor
    static func signals(for displayID: CGDirectDisplayID) -> DisplayConnection.Signals {
        var s = DisplayConnection.Signals()
        s.isBuiltin = CGDisplayIsBuiltin(displayID) != 0
        s.isSidecar = SidecarService.shared.isSidecarDisplay(displayID)
        s.isVirtual = VirtualDisplayService.shared.isVirtualDisplay(displayID)

        guard let info = infoDictionary?(displayID)?.takeRetainedValue() as? [String: Any]
        else { return s }
        s.isAirPlay = bool(info["kCGDisplayIsAirPlay"])
        s.isVirtual = s.isVirtual || bool(info["kCGDisplayIsVirtualDevice"])
        s.isHDMISink = bool(info["IODisplayIsHDMISink"])
        if let path = info["IODisplayLocation"] as? String {
            s.downstreamTransport = downstreamTransport(atServicePath: path)
        }
        return s
    }

    /// `Transport.Downstream` of the framebuffer at an IOService path, e.g.
    /// "IOService:/AppleARMPE/arm-io@10F00000/AppleSoCIO/dispext1@90000000/IOMobileFramebufferShim".
    /// Searches the node and its children: the property sits on the shim itself on
    /// current releases, one level down on some earlier ones.
    private static func downstreamTransport(atServicePath path: String) -> String? {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, path)
        guard entry != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(entry) }
        let value = IORegistryEntrySearchCFProperty(
            entry, kIOServicePlane, "Transport" as CFString, kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively))
        return (value as? [String: Any])?["Downstream"] as? String
    }

    private static func bool(_ value: Any?) -> Bool {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        return false
    }
}

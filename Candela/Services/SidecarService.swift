import AppKit
import Combine
import os.log

/// Connects and disconnects an iPad as a display, through SidecarCore.
///
/// macOS only offers this from Control Centre's Screen Mirroring menu, and only as
/// "connect with whatever settings were last used" — the extend-or-mirror choice
/// lives in System Settings, several clicks away from the thing you are trying to
/// do. Here it is a switch next to the display it affects.
///
/// SidecarCore is a private framework, so nothing here is linked: the framework is
/// `dlopen`ed on first use, the classes are looked up by name, and the objects are
/// bit-cast onto the protocols in the bridging header. That indirection is not
/// stylistic — declaring the classes as `@interface` makes dyld demand their symbols
/// at launch, before anything can dlopen the framework, and the app aborts before
/// `main`. Every entry point checks `isAvailable`, so a Mac without Sidecar shows no
/// section rather than failing.
@MainActor
final class SidecarService: ObservableObject, @unchecked Sendable {
    static let shared = SidecarService()

    private static let log = Logger(subsystem: "com.candela.app", category: "sidecar")

    /// One nearby iPad, flattened out of the private objects at read time.
    ///
    /// A value type rather than the live object: the rows are SwiftUI state that can
    /// outlive a refresh, and `SidecarDevice` is neither Sendable nor something to
    /// hold across actor hops. `handle` is kept only to pass back to the manager.
    struct Device: Identifiable {
        let id: String
        let name: String
        let kind: String
        fileprivate let handle: AnyObject
    }

    /// Devices that could be connected right now.
    @Published private(set) var available: [Device] = []
    /// Identifiers of the devices currently serving as a display.
    @Published private(set) var connectedIDs: Set<String> = []
    /// Identifiers with a connect or disconnect in flight, so a row can show progress
    /// and refuse a second tap.
    @Published private(set) var busy: Set<String> = []
    /// Last failure, shown inline on the section like the virtual-display errors.
    @Published var lastError: String?

    // MARK: - Preferences

    /// Extend rather than mirror. Persisted: it is a standing preference about how
    /// you work, not a per-connection decision.
    @Published var useAsSeparateDisplay: Bool {
        didSet { defaults.set(useAsSeparateDisplay, forKey: Keys.separateDisplay) }
    }
    @Published var showSidebar: Bool {
        didSet { defaults.set(showSidebar, forKey: Keys.sidebar) }
    }
    @Published var showTouchBar: Bool {
        didSet { defaults.set(showTouchBar, forKey: Keys.touchBar) }
    }

    private enum Keys {
        static let separateDisplay = "candela.sidecar.useAsSeparateDisplay"
        static let sidebar         = "candela.sidecar.showSidebar"
        static let touchBar        = "candela.sidecar.showTouchBar"
    }

    private let defaults = UserDefaults.standard

    private init() {
        // Defaults when nothing is stored: extend, which is why most people reach for
        // Sidecar, with the sidebar on, matching macOS.
        useAsSeparateDisplay = defaults.object(forKey: Keys.separateDisplay) as? Bool ?? true
        showSidebar = defaults.object(forKey: Keys.sidebar) as? Bool ?? true
        showTouchBar = defaults.object(forKey: Keys.touchBar) as? Bool ?? false
    }

    // MARK: - Runtime lookup

    /// Whether the framework loaded and this Mac supports Sidecar.
    ///
    /// Resolved once: the answer cannot change while the app runs.
    private(set) lazy var isAvailable: Bool = {
        guard dlopen("/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore",
                     RTLD_LAZY) != nil else {
            Self.log.info("SidecarCore did not load; hiding the section")
            return false
        }
        guard let anyClass = NSClassFromString("SidecarDisplayManager"),
              NSClassFromString("SidecarDisplayConfig") != nil else {
            Self.log.info("SidecarCore classes missing after dlopen; hiding the section")
            return false
        }
        // `as AnyObject` first: bit-casting the metatype straight onto the protocol
        // segfaults inside objc_msgSend, because Swift's AnyClass is not the bare
        // class pointer the runtime expects as a receiver.
        let classObject = anyClass as AnyObject
        guard classObject.responds(to: NSSelectorFromString("isSupported")),
              classObject.responds(to: NSSelectorFromString("sharedManager")) else {
            Self.log.info("SidecarDisplayManager is missing its class methods; hiding the section")
            return false
        }
        return unsafeBitCast(classObject, to: CandelaSidecarManagerClass.self).isSupported()
    }()

    private var manager: CandelaSidecarDisplayManager? {
        guard isAvailable, let anyClass = NSClassFromString("SidecarDisplayManager")
        else { return nil }
        return unsafeBitCast(anyClass as AnyObject, to: CandelaSidecarManagerClass.self)
            .sharedManager()
    }

    private func describe(_ object: AnyObject) -> Device? {
        let device = unsafeBitCast(object, to: CandelaSidecarDevice.self)
        // Devices that cannot serve a desktop are dropped rather than shown and then
        // failing: an iPad can be reachable for pencil input yet not offer a display.
        guard device.offersAdditionalDisplay else { return nil }
        return Device(id: device.identifier.uuidString, name: device.name,
                      kind: device.localizedDeviceType, handle: object)
    }

    // MARK: - Device list

    /// Re-reads the device lists. Driven by panel opens rather than polled: the lists
    /// come from a system service and nothing here is live while the panel is closed.
    func refresh() {
        guard let manager else { return }
        available = manager.devices.compactMap { describe($0 as AnyObject) }
        connectedIDs = Set(manager.connectedDevices.map {
            unsafeBitCast($0 as AnyObject, to: CandelaSidecarDevice.self).identifier.uuidString
        })
    }

    func isConnected(_ device: Device) -> Bool { connectedIDs.contains(device.id) }

    // MARK: - Connect / disconnect

    func toggle(_ device: Device) {
        if isConnected(device) {
            disconnect(device)
        } else {
            connect(device)
        }
    }

    func connect(_ device: Device) {
        guard let manager, !busy.contains(device.id),
              let configClass = NSClassFromString("SidecarDisplayConfig") as? NSObject.Type
        else { return }
        busy.insert(device.id)
        lastError = nil

        // Built here rather than fetched: configForDevice: returns nil for anything
        // not already connected. Properties left unset stay nil, which SidecarCore
        // reads as "use the system default", so only the flags shown in the UI are
        // overridden.
        let config = unsafeBitCast(configClass.init(), to: CandelaSidecarDisplayConfig.self)
        config.configureDisplayExclusiveMode = NSNumber(value: useAsSeparateDisplay)
        config.showSideBar = NSNumber(value: showSidebar)
        config.showTouchBar = NSNumber(value: showTouchBar)

        // The identifier, not the Device: the completion block is @Sendable.
        let id = device.id
        manager.connect(toDevice: device.handle, withConfig: config) { [weak self] error in
            // SidecarCore calls back on an arbitrary queue.
            Task { @MainActor in self?.finish(id, error: error, verb: "connect") }
        }
    }

    func disconnect(_ device: Device) {
        guard let manager, !busy.contains(device.id) else { return }
        busy.insert(device.id)
        lastError = nil
        let id = device.id
        manager.disconnect(fromDevice: device.handle) { [weak self] error in
            Task { @MainActor in self?.finish(id, error: error, verb: "disconnect") }
        }
    }

    private func finish(_ id: String, error: Error?, verb: String) {
        busy.remove(id)
        if let error {
            Self.log.error("\(verb, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
        // The service's own lists lag the call, so read again after a beat and let the
        // row settle on the real state rather than an optimistic one.
        refresh()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.refresh()
        }
    }
}

import Foundation

/// How a display is attached to this Mac, as shown under its name in the panel.
///
/// Read from what macOS itself records rather than guessed from vendor IDs:
/// CoreDisplay's per-display info dictionary says whether a display is AirPlay or
/// virtual, and the framebuffer it points at carries the cable's downstream link
/// ("HDMI" or "DP"). See `DisplayConnectionService` for where each input comes from.
enum DisplayConnection: Equatable, Sendable {
    case builtin
    case hdmi
    case displayPort
    case airPlay
    case sidecar
    case virtual
    /// Attached some way we could not identify (DisplayLink, an unusual adapter).
    case external

    /// Everything the classifier needs, flattened out of CoreGraphics, CoreDisplay
    /// and the IORegistry so the decision itself is a pure, testable function.
    struct Signals: Equatable, Sendable {
        var isBuiltin = false
        /// `kCGDisplayIsAirPlay` from CoreDisplay.
        var isAirPlay = false
        /// `kCGDisplayIsVirtualDevice` from CoreDisplay, or a display Candela created.
        var isVirtual = false
        /// The display is the one a connected Sidecar session is running on.
        var isSidecar = false
        /// `Transport.Downstream` of the framebuffer, e.g. "HDMI" or "DP". Nil when
        /// the display has no framebuffer node (AirPlay, DisplayLink, virtual).
        var downstreamTransport: String?
        /// `IODisplayIsHDMISink` from CoreDisplay: the sink identified itself as
        /// HDMI in its EDID. Used only when the transport is missing.
        var isHDMISink = false
    }

    /// Picks the connection. Order matters: Sidecar sessions are carried over the
    /// same wireless machinery as AirPlay, so the more specific answer wins first,
    /// and anything wireless or virtual is decided before looking at cables.
    static func classify(_ s: Signals) -> DisplayConnection {
        if s.isBuiltin { return .builtin }
        if s.isSidecar { return .sidecar }
        if s.isAirPlay { return .airPlay }
        if s.isVirtual { return .virtual }
        switch s.downstreamTransport?.uppercased() {
        case "HDMI": return .hdmi
        // USB-C and Thunderbolt monitors both arrive as DisplayPort; the framebuffer
        // cannot tell those apart, so neither do we.
        case "DP", "EDP": return .displayPort
        default: break
        }
        return s.isHDMISink ? .hdmi : .external
    }

    /// Short label for the panel row. Port names are not translated (they are
    /// printed on the cable); the generic words are.
    var label: String {
        switch self {
        case .builtin:     return String(localized: "Built-in")
        case .hdmi:        return "HDMI"
        case .displayPort: return "DisplayPort"
        case .airPlay:     return "AirPlay"
        case .sidecar:     return "Sidecar"
        case .virtual:     return String(localized: "Virtual")
        case .external:    return String(localized: "External")
        }
    }

    /// Wireless displays are mirrored or extended like Sidecar, and have no cable,
    /// so no DDC; the panel uses this to offer the mirror/extend switch.
    var isWireless: Bool { self == .airPlay || self == .sidecar }
}

/// The user's display order in the panel, kept as stable display UUIDs.
///
/// Pure so it can be tested: `DisplayManager` owns persistence and publishing.
enum DisplayOrder {
    /// Orders `defaultOrder` (the automatic order, already sorted) by `saved`.
    /// Displays the user has placed keep their saved relative order; displays never
    /// placed (newly connected) keep their automatic position relative to each
    /// other and go after the placed ones. An empty `saved` means automatic.
    static func apply(saved: [String], to defaultOrder: [String]) -> [String] {
        guard !saved.isEmpty else { return defaultOrder }
        let rank = Dictionary(saved.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let placed = defaultOrder.filter { rank[$0] != nil }.sorted { rank[$0]! < rank[$1]! }
        let unplaced = defaultOrder.filter { rank[$0] == nil }
        return placed + unplaced
    }

    /// Moves `uuid` one place up (`offset` -1) or down (+1) within `current`, the
    /// order on screen. Returns the new full order to save, or nil at an edge.
    ///
    /// The saved list is the whole visible order after a move, so a display that is
    /// disconnected later keeps its place and comes back to it; `apply` ignores
    /// saved entries that are not connected.
    static func move(_ uuid: String, by offset: Int, in current: [String]) -> [String]? {
        guard let i = current.firstIndex(of: uuid) else { return nil }
        let j = i + offset
        guard current.indices.contains(j) else { return nil }
        var next = current
        next.swapAt(i, j)
        return next
    }

    /// Merges a new visible order into the saved one without forgetting displays
    /// that are not connected right now: they keep their slot relative to the
    /// displays around them.
    static func merge(visible: [String], into saved: [String]) -> [String] {
        let visibleSet = Set(visible)
        var result: [String] = []
        var next = visible.makeIterator()
        for uuid in saved {
            if visibleSet.contains(uuid) {
                if let v = next.next() { result.append(v) }
            } else {
                result.append(uuid)
            }
        }
        while let v = next.next() { result.append(v) }
        return result
    }
}

import CoreGraphics

/// Which page the panel is showing.
///
/// The panel used to put everything on one page and disclose it with nested
/// accordions — eleven independent open/closed flags, three taps deep to reach the
/// resolution list or the virtual displays. That trades two bad options against
/// each other: expand more and the panel grows past the screen, collapse more and
/// everything worth reaching is buried. Control Centre does not make that trade —
/// tapping Wi-Fi replaces the panel's contents and offers a back arrow — so
/// neither does this.
enum PanelRoute: Equatable {
    case root
    /// One display's settings: resolution, refresh rate, colour, image adjustment.
    case display(CGDirectDisplayID)
    /// The full mode list for a display, the one page long enough to earn its own.
    case allResolutions(CGDirectDisplayID)
    /// Keep Awake plus the three things that manage displays rather than adjust one.
    case tools
    case virtualDisplays
    case sidecar
    case arrangement
    case settings

    /// The page this one goes back to.
    var parent: PanelRoute? {
        switch self {
        case .root: nil
        case .display: .root
        case .allResolutions(let id): .display(id)
        case .tools, .settings: .root
        case .virtualDisplays, .sidecar, .arrangement: .tools
        }
    }

    /// The display this page belongs to, so a disconnect can pop back to root.
    var displayID: CGDirectDisplayID? {
        switch self {
        case .display(let id), .allResolutions(let id): id
        case .root, .tools, .virtualDisplays, .sidecar, .arrangement, .settings: nil
        }
    }

    /// The page's own title, shown next to the back arrow.
    ///
    /// Display pages are absent: their title is the display's name, which only the
    /// caller has.
    var title: String? {
        switch self {
        case .root, .display, .allResolutions: nil
        case .tools: String(localized: "Tools")
        case .virtualDisplays: String(localized: "Virtual Displays")
        case .sidecar: String(localized: "iPad Display")
        case .arrangement: String(localized: "Arrange Displays")
        case .settings: String(localized: "Settings")
        }
    }
}

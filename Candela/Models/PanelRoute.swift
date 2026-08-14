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

    /// The page this one goes back to.
    var parent: PanelRoute? {
        switch self {
        case .root: nil
        case .display: .root
        case .allResolutions(let id): .display(id)
        }
    }

    /// The display this page belongs to, so a disconnect can pop back to root.
    var displayID: CGDirectDisplayID? {
        switch self {
        case .root: nil
        case .display(let id), .allResolutions(let id): id
        }
    }
}

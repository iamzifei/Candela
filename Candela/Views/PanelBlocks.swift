import SwiftUI
import AppKit

// The panel's content, decomposed into split-canvas blocks (notes/panel-resize.md).
// Each block renders at its natural size and never animates its own geometry;
// the AppKit canvas animates the clips and the window. Nested reveals INSIDE a
// block (Support, Brightness Keys targets, resolution lists) still use the
// SwiftUI curtain at the same duration; the block reports its height per frame
// and the window spring tracks it.

/// Section open/close state, lifted out of the view tree so both the SwiftUI
/// headers (chevrons, bindings) and the AppKit canvas (clip targets) share it.
@MainActor
final class PanelSectionState: ObservableObject {
    /// The page being shown. Changing it rebuilds the block list rather than
    /// animating a reveal, so the panel's height follows the page it is on
    /// instead of the sum of everything anyone has ever expanded.
    @Published var route: PanelRoute = .root
    // The sections that remain inside a display's page. Lifted out of view @State
    // so each reveal is its own canvas block: the clip animates, the content
    // renders once, nothing re-renders per frame.
    //
    // The flags for Tools, its three sub-sections, Settings, the display detail
    // and the full resolution list are gone — those are pages now, and a flag for
    // a section that no longer collapses is a lie about how the panel works.
    @Published var resolutionOpenIDs: Set<CGDirectDisplayID> = []
    @Published var refreshOpenIDs: Set<CGDirectDisplayID> = []
    @Published var profileOpenIDs: Set<CGDirectDisplayID> = []
    @Published var imageOpenIDs: Set<CGDirectDisplayID> = []

    /// Go back one page, if there is one.
    @discardableResult
    func goBack() -> Bool {
        guard let parent = route.parent else { return false }
        route = parent
        return true
    }

    /// Reopen collapsed, like a native menu (called once the panel finished hiding).
    func collapseAll() {
        route = .root
        resolutionOpenIDs.removeAll()
        refreshOpenIDs.removeAll()
        profileOpenIDs.removeAll()
        imageOpenIDs.removeAll()
    }

    /// Drop state for displays that disappeared (disconnect, reconfiguration).
    func retainDisplays(_ valid: Set<CGDirectDisplayID>) {
        // A page for a display that just vanished has nothing to show, and its back
        // arrow would be the only way out of a blank panel.
        if let id = route.displayID, !valid.contains(id) { route = .root }
        resolutionOpenIDs.formIntersection(valid)
        refreshOpenIDs.formIntersection(valid)
        profileOpenIDs.formIntersection(valid)
        imageOpenIDs.formIntersection(valid)
    }

    /// Binding into one of the per-display sets, for ExpandableRow chevrons.
    func openBinding(
        _ keyPath: ReferenceWritableKeyPath<PanelSectionState, Set<CGDirectDisplayID>>,
        _ id: CGDirectDisplayID
    ) -> Binding<Bool> {
        Binding(
            get: { self[keyPath: keyPath].contains(id) },
            set: {
                if $0 { self[keyPath: keyPath].insert(id) } else { self[keyPath: keyPath].remove(id) }
            }
        )
    }
}

/// Wraps a block's content with the fixed panel width, natural-height sizing,
/// and the height reporter feeding the canvas.
struct BlockHost<Content: View>: View {
    let onHeight: (CGFloat) -> Void
    @ViewBuilder var content: Content

    var body: some View {
        // Report the content's natural height (its final, fully-laid-out size);
        // the canvas springs the clip to it.
        content
            .frame(width: 308)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeight($0) }
            // Top-glue, exactly like 1.3.2's PanelRootView (which has no
            // .fixedSize here): the AppKit host is a canvas at the FINAL block
            // height, but a nested curtain renders the content shorter
            // mid-reveal. Without this, NSHostingView CENTERS the shorter content
            // in the taller canvas, so the whole block (its top row included)
            // drops and floats back up: the "inner menu top drifts" on open.
            // Pinning to .top spills the excess off the bottom (clipped by the
            // block's clip) so the top never moves. A .fixedSize on the measured
            // content defeats this fill, so it is deliberately absent.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// An ExpandableRow bound to a PanelSectionState flag. Observes the state so
/// the chevron re-renders when the flag flips (a plain ad-hoc Binding inside
/// a static block closure would never re-render).
struct ExpandableRowStateful: View {
    let icon: String
    var iconColor: Color = .blue
    var iconActive: Bool = true
    let label: String
    @ObservedObject var state: PanelSectionState
    let key: ReferenceWritableKeyPath<PanelSectionState, Bool>

    var body: some View {
        ExpandableRow(
            icon: icon,
            iconColor: iconColor,
            iconActive: iconActive,
            label: label,
            isExpanded: Binding(
                get: { state[keyPath: key] },
                set: { state[keyPath: key] = $0 }
            )
        )
    }
}

/// Display name row + inline brightness slider. Stacked displays are separated by
/// the gap between their cards now, not by padding inside them.
struct DisplayHeaderBlock: View {
    @ObservedObject var display: DisplayInfo
    let isFirst: Bool
    @ObservedObject var state: PanelSectionState
    @ObservedObject private var settings = SettingsService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Pushes to the display's own page rather than expanding in place;
            // `isExpanded` stays false so the chevron points right, at the page it
            // opens, instead of down at a reveal that no longer happens here.
            DisplayRowView(
                display: display,
                isExpanded: false,
                onToggleExpand: {
                    withAnimation(.panelResize) {
                        state.route = .display(display.displayID)
                    }
                }
            )
            BrightnessSliderView(display: display, compact: true)
                .padding(.bottom, 4)

            // Speaker volume, only for monitors that answered the DDC volume
            // probe (issue #23), and only while the setting is on (keys keep
            // working either way). Toggling the setting re-renders this block;
            // the height change flows through BlockHost to the panel spring.
            if settings.showVolumeSliders && display.volumeSupported {
                VolumeSliderView(display: display)
                    .padding(.bottom, 4)
            }
        }
    }
}

/// A group of controls on its own rounded surface, with a gap to its neighbours.
///
/// Control Centre is not one panel divided by hairlines — it is a set of separate
/// rounded surfaces with space between them: Wi-Fi, Bluetooth and AirDrop are
/// individual capsules, Display and Sound are wider cards, and the gaps are what
/// group them. This panel was the other thing, one flat sheet with dividers, which
/// is why it read as close-but-not-quite next to the system's own.
///
/// A fill rather than another glass layer: the panel's backdrop is already
/// NSGlassEffectView, and stacking glass on glass doubles the blur into something
/// muddier than either. A translucent white over the existing glass is what reads
/// as a raised surface here.
struct PanelCard<Content: View>: View {
    var title: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
            }
            content
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        )
        .padding(.horizontal, 10)
        // Tight: the gap between cards is doing the grouping that dividers used to,
        // and every point spent on it is a point of panel height. The whole reason
        // for the page split was that this panel was getting too tall.
        .padding(.vertical, 2)
    }
}

/// Space between two groups of rows on a page.
///
/// The root panel separates its groups with `PanelCard`, which draws a surface and
/// takes the gap for free. A page cannot do the same: each row here is its own
/// canvas block so it can reveal and collapse independently, and one card cannot
/// span several blocks. Without something between them, Resolution, Refresh Rate,
/// Colour Profile and the display actions all ran together as a single list —
/// nothing said where one subject ended and the next began.
struct PanelGroupGap: View {
    var body: some View {
        Color.clear.frame(height: 14)
    }
}

/// The top row of any page below the root: a back chevron and the page's title.
///
/// The chevron and the title are one target, as they are in Settings and in
/// Control Centre's own sub-pages — the title is where people aim, and a 12pt
/// chevron alone is a small thing to hit in a floating panel.
struct PanelBackHeader: View {
    let title: String
    let onBack: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .menuRowHover(isHovered)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onBack)
        .accessibilityElement(children: .combine)
        // The title names the page you are ON, not the one this goes back to — three
        // of the four pages using this header pass their own name. "Back to M28U"
        // announced while standing on the M28U page was simply false; the title plus
        // a hint says what is true on every page.
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text("Goes back"))
        .accessibilityAddTraits(.isButton)
    }
}

/// A row that opens another page. The chevron points right, the way every
/// drill-in row on this platform does.
struct PanelPushRow: View {
    let icon: String
    var iconColor: Color = .accentColor
    var iconActive: Bool = false
    let label: String
    var detail: String?
    let onPush: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            MenuItemIcon(systemName: icon, color: iconColor, active: iconActive)
                .accessibilityHidden(true)
            Text(label)
                .font(.body)
                .lineLimit(1)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .menuRowHover(isHovered)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onPush)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.map { "\(label), \($0)" } ?? label)
        .accessibilityAddTraits(.isButton)
    }
}

/// Keep Awake: hold a power assertion so the display and system don't
/// idle-sleep. Session-only (KeepAwakeService), off each launch.
struct KeepAwakeRow: View {
    @ObservedObject private var keepAwake = KeepAwakeService.shared

    var body: some View {
        Toggle(isOn: Binding(
            get: { keepAwake.isActive },
            set: { keepAwake.setActive($0) }
        )) {
            HStack(spacing: 8) {
                MenuItemIcon(systemName: "cup.and.saucer.fill", color: .orange, active: keepAwake.isActive)
                    .accessibilityHidden(true)
                Text("Keep Awake")
                    .font(.body)
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
}

/// Update notice; renders nothing (height 0) until an update is known, so the
/// block glides in via the normal height-change path.
struct UpdateBlockView: View {
    @ObservedObject private var updateService = UpdateService.shared

    var body: some View {
        if updateService.hasUpdate, let ver = updateService.latestVersion {
            // The banner comes from the GitHub release list, which is what tells
            // us a version exists at all; the tap hands over to Sparkle, which
            // downloads it, checks the EdDSA signature and installs in place.
            // Falling back to the release page keeps the button useful in an
            // unbundled build, where Sparkle has nothing to replace.
            UpdateRow(version: ver) {
                if UpdaterService.shared.canCheckForUpdates {
                    UpdaterService.shared.checkForUpdates()
                } else {
                    updateService.openReleasePage()
                }
            }
        }
    }
}

/// Fixed footer under the scroll region: divider + Quit, like the Wi-Fi
/// menu's settings footer.
struct PanelFooterBlock: View {
    @State private var quitHovered = false

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.25).padding(.horizontal, 12)
            HStack {
                Text("Quit Candela")
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .menuRowHover(quitHovered)
            .contentShape(Rectangle())
            .onTapGesture {
                NSApplication.shared.terminate(nil)
            }
            .onHover { quitHovered = $0 }
            .padding(.top, 4)
        }
        .padding(.bottom, 8)
    }
}

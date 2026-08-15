import SwiftUI

// The expanded per-display detail, split into canvas blocks (notes/panel-resize.md):
// the mode section (DisplayModeListView.swift), then the preset / color-profile
// section, image adjustment, and the trailing toggle rows below. Each dropdown
// is its own block so the canvas animates its reveal as a clip over content that
// rendered once; nothing SwiftUI-animates block geometry.

/// Per-display preset / color-profile names, shared by the header row (subtitle)
/// and the body list, which are separate blocks. Created per display when the
/// block list is (re)built; the block hosts retain it.
@MainActor
final class DisplayProfileController: ObservableObject {
    let display: DisplayInfo
    @Published var presetName: String = ""
    @Published var activeProfileName: String = ""

    init(display: DisplayInfo) {
        self.display = display
    }

    func reload() {
        activeProfileName = ColorProfileService.shared.currentColorSpaceName(for: display.displayID)
        let svc = DisplayPresetService.shared
        if let idx = svc.activePresetIndex(for: display.displayID) {
            presetName = svc.presets(for: display.displayID)
                .first(where: { $0.index == idx })?.name ?? ""
        } else {
            presetName = ""
        }
    }

    func refreshActiveProfileName() {
        activeProfileName = ColorProfileService.shared.currentColorSpaceName(for: display.displayID)
    }
}

/// Preset (XDR builtin panels, mirrors the System Settings "Preset" menu) or
/// Color Profile header row; the two are mutually exclusive, matching System
/// Settings (XDR panels get Preset instead of a profile picker).
struct ProfileHeadBlock: View {
    @ObservedObject var controller: DisplayProfileController
    @ObservedObject var state: PanelSectionState

    var body: some View {
        Group {
            if !controller.presetName.isEmpty {
                ExpandableRow(
                    icon: "camera.filters",
                    iconActive: false,
                    label: "Preset",
                    subtitle: controller.presetName,
                    isExpanded: state.openBinding(\.profileOpenIDs, controller.display.displayID)
                )
            } else {
                ExpandableRow(
                    icon: "paintpalette.fill",
                    iconActive: false,
                    label: "Color Profile",
                    subtitle: controller.activeProfileName,
                    isExpanded: state.openBinding(\.profileOpenIDs, controller.display.displayID)
                )
            }
        }
        .task { controller.reload() }
        // The active profile changes outside this view: System Settings, and
        // HDR mode switches (macOS swaps the display's profile with the mode).
        // Re-read on panel open and on screen reconfiguration, debounced
        // because mode switches emit bursts.
        .onReceive(NotificationCenter.default.publisher(for: .candelaPanelDidOpen)) { _ in
            controller.refreshActiveProfileName()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        ) { _ in
            controller.refreshActiveProfileName()
        }
    }
}

/// The preset or color-profile list under the header row.
struct ProfileBodyBlock: View {
    @ObservedObject var controller: DisplayProfileController

    var body: some View {
        if !controller.presetName.isEmpty {
            DisplayPresetView(displayID: controller.display.displayID, activeName: $controller.presetName)
        } else {
            ColorProfileView(display: controller.display, activeProfileName: $controller.activeProfileName)
        }
    }
}

/// Image adjustment header row.
struct ImageHeadBlock: View {
    let display: DisplayInfo
    @ObservedObject var state: PanelSectionState

    var body: some View {
        ExpandableRow(
            icon: "slider.horizontal.3",
            iconActive: false,
            label: "Image Adjustment",
            isExpanded: state.openBinding(\.imageOpenIDs, display.displayID)
        )
    }
}

/// Image adjustment sliders.
struct ImageBodyBlock: View {
    let display: DisplayInfo
    @ObservedObject var state: PanelSectionState

    var body: some View {
        ImageAdjustmentView(display: display, isExpanded: state.imageOpenIDs.contains(display.displayID))
            .padding(.leading, 8)
    }
}

/// The plain rows below the dropdown sections.
struct DetailTailBlock: View {
    let display: DisplayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionDivider()

            // Set as main display
            MainDisplayView(display: display)

            // Disconnect this physical display (Apple Silicon only; hidden for the last screen)
            DisconnectDisplayRow(display: display)

            // HDR: explicit per-display HDR mode toggle, shown only for
            // HDR-capable externals (built-in never offers this, matching
            // System Settings). Placed above Extra Brightness: cause before
            // effect, since enabling boost on an SDR external switches this on.
            HDRToggleView(display: display)

            // Extra Brightness (EDR upscaling), shown only for displays with
            // usable HDR headroom (built-in XDR, HDR-capable externals)
            ExtraBrightnessView(display: display)

            // macOS "Automatically adjust brightness" (ambient light), grouped with the
            // other built-in-only toggles; renders only on ALS panels, absent on externals.
            SystemAutoBrightnessView(display: display)

            // Notch management (built-in with notch only)
            NotchView(display: display)
        }
    }
}

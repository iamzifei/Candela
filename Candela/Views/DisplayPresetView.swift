import SwiftUI

/// Reference-mode preset picker, mirroring the System Settings "Preset" menu
/// for displays that have presets (XDR builtin panels). A native checkmarked
/// list (same style as the resolution list), not a nested popup.
struct DisplayPresetView: View {
    let displayID: CGDirectDisplayID
    /// The parent row's subtitle; updated here so it refreshes on switch.
    @Binding var activeName: String
    /// Optimistic override set on tap; nil means "use the live active index".
    @State private var selectedIndex: Int?

    // Computed (not loaded in .onAppear) so the list is full-height on the first
    // frame, letting this section's expand animation match Resolution/Refresh,
    // which also compute their list. Loading in .onAppear grew the height
    // mid-spring, so the open animation looked different.
    private var presets: [DisplayPresetService.Preset] {
        DisplayPresetService.shared.presets(for: displayID)
    }
    private var activeIndex: Int? {
        selectedIndex ?? DisplayPresetService.shared.activePresetIndex(for: displayID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(presets) { preset in
                CheckmarkRow(
                    label: preset.name,
                    isSelected: preset.index == activeIndex
                ) {
                    select(preset)
                }
            }
        }
    }

    private func select(_ preset: DisplayPresetService.Preset) {
        guard preset.index != activeIndex else { return }
        if DisplayPresetService.shared.setActivePreset(index: preset.index, for: displayID) {
            selectedIndex = preset.index
            activeName = preset.name
        }
    }
}

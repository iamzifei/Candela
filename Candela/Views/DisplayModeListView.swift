import SwiftUI
import AppKit

// Resolution and refresh-rate selection as native checkmarked lists, each a
// top-level expandable row like the System Settings display menu: resolution is
// one click away (not nested under a "Display Mode" popup), and refresh rate is
// its own section, shown only when the current resolution offers more than one.
//
// Split into canvas blocks (notes/panel-resize.md): the header rows, the dropdown
// lists, and the trailing rows are separate PanelBlocks, so opening a dropdown
// animates a clip over content that rendered once at natural height. The shared
// mutable state lives in DisplayModeController, in its own file.

// MARK: - Blocks

/// Resolution header row: its own block, always visible while the display's
/// detail is expanded.
struct ResolutionHeadBlock: View {
    @ObservedObject var controller: DisplayModeController
    private var display: DisplayInfo { controller.display }
    @ObservedObject var state: PanelSectionState

    var body: some View {
        ExpandableRow(
            icon: "rectangle.on.rectangle",
            iconActive: false,
            label: "Resolution",
            subtitle: controller.currentGroup?.menuLabel,
            isExpanded: state.openBinding(\.resolutionOpenIDs, display.displayID)
        )
    }
}

/// The Resolution picker: a "looks like" slider (matching System Settings) over
/// sliderModes, with the full exact-mode list kept behind a "Show all resolutions"
/// disclosure (its own block, below). Falls back to the plain list when there
/// are too few slider stops.
struct ResolutionSliderBlock: View {
    @ObservedObject var controller: DisplayModeController
    private var display: DisplayInfo { controller.display }
    @ObservedObject var state: PanelSectionState

    var body: some View {
        let modes = controller.sliderModes
        if modes.count >= 2 {
            VStack(alignment: .leading, spacing: 0) {
                modeSlider(modes)
                // Pushes to its own page: this list is the longest thing in the
                // panel, and revealing it in place was the third tap of a
                // three-deep accordion.
                PanelPushRow(
                    icon: "list.bullet",
                    label: String(localized: "Show all resolutions"),
                    onPush: {
                        withAnimation(.panelResize) {
                            state.route = .allResolutions(display.displayID)
                        }
                    }
                )
            }
        } else {
            ResolutionListView(controller: controller)
        }
    }

    @ViewBuilder
    private func modeSlider(_ modes: [DisplayMode]) -> some View {
        if modes.count >= 2 {
            let defaultIdx = controller.defaultSliderIndex(modes)
            VStack(alignment: .leading, spacing: 2) {
                // Continuous slider (no native step, which would swap in a bar-style thumb)
                // so its knob matches the brightness slider above. Snapped to whole stops
                // live via onChange, so it still clicks tick-to-tick with the round knob.
                // The mode only switches on release; dragging just moves the knob/label.
                Slider(
                    value: $controller.sliderIndex,
                    in: 0...Double(modes.count - 1),
                    onEditingChanged: { editing in
                        if !editing { controller.applySmooth(modes) }
                    }
                )
                .controlSize(.small)
                .tint(Color.accentColor)
                .onChange(of: controller.sliderIndex) { _, v in
                    let snapped = v.rounded()
                    if snapped != controller.sliderIndex { controller.sliderIndex = snapped }
                }

                stepMarks(count: modes.count, defaultIdx: defaultIdx)

                HStack(spacing: 0) {
                    Text("Larger Text")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(controller.looksLikeLabel(modes))
                        .font(.caption2)
                    Spacer()
                    Text("More Space")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .onAppear { controller.sliderIndex = controller.currentSmoothIndex(modes) }
            .onChange(of: display.currentDisplayMode?.id) { _, _ in
                if !controller.smoothBusy { controller.sliderIndex = controller.currentSmoothIndex(modes) }
            }
        }
    }

    /// A tick per stop, with the default stop drawn as a filled dot on top of its tick
    /// (the way BetterDisplay marks it). A dot rather than a "Default" label stays clean
    /// even when the default sits at the very edge. Positioned to track the slider thumb,
    /// which is inset from the track edges by ~half its width (see markX's thumbInset).
    ///
    /// The per-step ticks are dropped once the ladder is dense (smooth scaling on, ~80
    /// stops): at that count they read as an illegible picket fence and fight the
    /// continuous "smooth" feel, so the slider shows only the default dot and leans on
    /// the live "· NNN%" label. Ticks stay for the sparse default ladder.
    private func stepMarks(count: Int, defaultIdx: Int?) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if count <= 12 {
                    ForEach(0..<count, id: \.self) { i in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.45))
                            .frame(width: 1, height: 4)
                            .position(x: markX(i, count: count, width: geo.size.width), y: 3)
                    }
                }
                if let di = defaultIdx, count > 1 {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                        .position(x: markX(di, count: count, width: geo.size.width), y: 3)
                }
            }
        }
        .frame(height: 8)
    }

    /// X of stop `index` along a slider of the given width, accounting for the thumb inset.
    private func markX(_ index: Int, count: Int, width: Double) -> Double {
        let thumbInset = 8.0
        let frac = count > 1 ? Double(index) / Double(count - 1) : 0
        return thumbInset + frac * max(width - thumbInset * 2, 1)
    }
}

/// The full exact-mode list behind "Show all resolutions". Rendered only in the
/// slider case; the fallback (too few stops) shows the list inline in
/// ResolutionSliderBlock instead.
struct ResolutionFullListBlock: View {
    @ObservedObject var controller: DisplayModeController
    private var display: DisplayInfo { controller.display }

    var body: some View {
        if controller.sliderModes.count >= 2 {
            ResolutionListView(controller: controller)
        }
    }
}

/// The checkmarked resolution list, grouped HiDPI / Non-HiDPI.
private struct ResolutionListView: View {
    @ObservedObject var controller: DisplayModeController
    private var display: DisplayInfo { controller.display }

    var body: some View {
        let groups = controller.resolutionGroups
        if groups.isEmpty {
            Text("No display modes available")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        } else {
            // HiDPI is surfaced once as a section header instead of per-row. The
            // native "(Default)" mode is neither HiDPI nor low-resolution, so it sits
            // alone at the top; everything else splits into HiDPI / Non-HiDPI.
            let defaults = groups.filter { $0.isDefault }
            let hiDPI = groups.filter { $0.isHiDPI }
            let lowRes = groups.filter { !$0.isHiDPI && !$0.isDefault }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(defaults) { resolutionRow($0, label: $0.menuLabel) }
                if !hiDPI.isEmpty {
                    resolutionSectionHeader("HiDPI")
                    ForEach(hiDPI) { resolutionRow($0, label: $0.resolutionString) }
                }
                if !lowRes.isEmpty {
                    // "Non-HiDPI" (not "Low Resolution"): accurate for both the
                    // external's soft 1x twins and the built-in's big 1x modes
                    // (e.g. 3024x1964, high pixel count but non-Retina).
                    resolutionSectionHeader("Non-HiDPI")
                    ForEach(lowRes) { resolutionRow($0, label: $0.resolutionString) }
                }
            }
        }
    }

    private func resolutionRow(_ group: ResolutionGroup, label: String) -> some View {
        CheckmarkRow(
            label: label,
            isSelected: group.id == controller.currentGroup?.id,
            isPending: group.id == controller.pendingResolutionID
        ) {
            controller.selectResolution(group)
        }
    }

    // LocalizedStringKey, not String: Text(String) is the non-localizing overload.
    private func resolutionSectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Refresh Rate header row: a sibling section, not nested under resolution.
/// Only shown when the current resolution actually offers a choice.
struct RefreshHeadBlock: View {
    @ObservedObject var controller: DisplayModeController
    private var display: DisplayInfo { controller.display }
    @ObservedObject var state: PanelSectionState

    var body: some View {
        if let group = controller.currentGroup, group.hasMultipleRates {
            ExpandableRow(
                icon: "waveform",
                iconActive: false,
                label: "Refresh Rate",
                subtitle: controller.currentMode.map(controller.refreshLabel),
                isExpanded: state.openBinding(\.refreshOpenIDs, display.displayID)
            )
        }
    }
}

/// The checkmarked refresh-rate list for the current resolution group.
struct RefreshListBlock: View {
    @ObservedObject var controller: DisplayModeController
    private var display: DisplayInfo { controller.display }

    var body: some View {
        if let group = controller.currentGroup, group.hasMultipleRates {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(group.modes) { mode in
                    CheckmarkRow(
                        label: controller.refreshLabel(mode),
                        isSelected: mode.id == controller.currentMode?.id,
                        isPending: mode.id == controller.pendingRefreshID
                    ) {
                        controller.selectRefresh(mode)
                    }
                }
            }
        }
    }
}

/// Trailing rows of the mode section: the smooth-scaling switch (externals
/// only), the transient switch-failure message, and the section divider.
struct ModeTailBlock: View {
    @ObservedObject var controller: DisplayModeController
    private var display: DisplayInfo { controller.display }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Smooth scaling: on/off switch for the dense HiDPI ladder the Resolution slider
            // steps through. External displays only (built-ins already scale via System Settings).
            if !display.isBuiltin {
                smoothScalingSection
            }

            if let msg = controller.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .transition(.opacity)
            }

            SectionDivider()
        }
    }

    /// Smooth scaling as an on/off switch. ON injects the dense HiDPI ladder (admin write +
    /// soft-reconnect, screen blanks ~1s); OFF removes the override + soft-reconnects, falling
    /// back to the panel's standard CGS scaled modes (HiDPI intact, just coarser steps). The
    /// switch tracks ground truth (are the dense modes enumerated), not a stored flag.
    private var smoothScalingSection: some View {
        Toggle(isOn: Binding(get: { controller.smoothOn }, set: { controller.userToggleSmooth($0) })) {
            HStack(spacing: 8) {
                // Track ground truth (are the dense modes live), not the optimistic switch value,
                // so the icon doesn't recolor or shift while the admin prompt blocks. The switch
                // still flips instantly for responsiveness; the icon settles when modes re-enumerate.
                MenuItemIcon(systemName: "slider.horizontal.below.rectangle", color: .blue, active: controller.smoothModesPresent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Smooth scaling")
                        .font(.body)
                    if let hint = controller.smoothSubtitle {
                        Text(hint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if controller.smoothBusy {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
        }
                // Explicit: a Toggle whose label is an HStack of an icon and a Text does
                // not reliably hand that Text to VoiceOver here — the control was
                // announced as an unnamed checkbox, so a screen-reader user heard its
                // state without ever hearing what it was.
                .accessibilityLabel(Text("Smooth scaling"))
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .onAppear {
            controller.smoothOn = controller.smoothModesPresent
            controller.refreshSmoothWouldPrompt()
        }
        .onChange(of: controller.smoothModesPresent) { _, present in
            // Adopt external truth (reconnect, another app) unless our own toggle is settling.
            if !controller.smoothBusy { controller.smoothOn = present }
        }
    }
}

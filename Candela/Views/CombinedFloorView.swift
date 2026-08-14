import SwiftUI

/// Calibrates where one display sits at the bottom of the combined slider.
///
/// This exists because the combined slider cannot match displays on its own. Sending
/// two panels the same percentage does not produce the same amount of light, and
/// macOS reports no absolute figure to normalise against (see `CombinedMapping`).
/// The eye is the instrument, so this is the control that lets the user use it.
///
/// Dragging drives the display to the value live: the preview *is* the calibration,
/// which is why there is no separate "apply" step and no reading to interpret. Put
/// the combined slider at the bottom, come in here, and drag until this display
/// matches the ones beside it.
struct CombinedFloorView: View {
    @ObservedObject var display: DisplayInfo
    @ObservedObject private var settings = SettingsService.shared

    @State private var floor: Double = 0
    @State private var isDragging = false
    /// The brightness to put back when the drag ends, so calibrating does not also
    /// silently change where the display is sitting right now.
    @State private var restoreTo: Double?

    private var isCalibrated: Bool { floor > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Slider(value: $floor, in: 0...CombinedMapping.maximumFloor) { editing in
                    if editing {
                        isDragging = true
                        restoreTo = display.brightness
                    } else {
                        isDragging = false
                        settings.setCombinedFloor(floor > 0 ? floor : nil,
                                                  forDisplayUUID: display.displayUUID)
                        // Put the display back where it was. The floor describes the
                        // bottom of a future combined move, not a brightness to leave
                        // the display sitting at.
                        if let restoreTo {
                            Task { @MainActor in
                                await BrightnessService.shared.setBrightness(restoreTo, for: display)
                            }
                        }
                        restoreTo = nil
                    }
                }
                .controlSize(.small)
                .accessibilityLabel("Combined brightness floor")
                .accessibilityValue("\(Int(floor))%")
                .onChange(of: floor) { _, newValue in
                    guard isDragging else { return }
                    Task { @MainActor in
                        await BrightnessService.shared.setBrightness(
                            newValue / 100.0 * display.maxBrightness, for: display)
                    }
                }

                if isCalibrated {
                    Button {
                        floor = 0
                        settings.setCombinedFloor(nil, forDisplayUUID: display.displayUUID)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Reset combined brightness floor")
                }
            }

            Text(isCalibrated
                 ? "This display stops at \(Int(floor))% when the combined slider is at the bottom."
                 : "Where this display sits when the combined slider is at the bottom. Drag until it matches the displays beside it.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .task(id: display.displayUUID) {
            floor = settings.combinedFloor(forDisplayUUID: display.displayUUID)
        }
    }
}

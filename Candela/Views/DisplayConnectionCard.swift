import SwiftUI
import CoreGraphics

/// "Connection" card on a display's page: how the display is attached, extend or
/// mirror for wireless displays, and where the display sits in the panel.
///
/// AirPlay displays are connected from Control Centre or System Settings (macOS
/// keeps that list to its own apps; see notes/plans/20261118-connection-types-airplay-order.md),
/// but once connected they are ordinary CG displays, so extend-versus-mirror is the
/// same display mirroring Sidecar uses and can change live from here.
struct DisplayConnectionCard: View {
    @ObservedObject var display: DisplayInfo
    @ObservedObject var displayManager: DisplayManager

    var body: some View {
        PanelCard(title: "Connection") {
            HStack(spacing: 8) {
                MenuItemIcon(systemName: Self.icon(for: display.connection), color: .accentColor)
                    .accessibilityHidden(true)
                Text("Connected via")
                Spacer()
                Text(display.connection.label)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)

            if display.connection.isWireless {
                SeparateDisplayToggle(display: display)
            }

            if displayManager.panelDisplays().count > 1 {
                PanelOrderRow(display: display, displayManager: displayManager)
            }
        }
    }

    static func icon(for connection: DisplayConnection) -> String {
        switch connection {
        case .builtin:     return "laptopcomputer"
        case .hdmi, .displayPort, .external: return "cable.connector.horizontal"
        case .airPlay:     return "airplayvideo"
        case .sidecar:     return "ipad.landscape"
        case .virtual:     return "display.2"
        }
    }
}

/// Extend (on) or mirror the main display (off), applied immediately.
private struct SeparateDisplayToggle: View {
    @ObservedObject var display: DisplayInfo
    @State private var isSeparate = true
    @State private var isBusy = false

    var body: some View {
        Toggle(isOn: Binding(get: { isSeparate }, set: { apply($0) })) {
            HStack(spacing: 8) {
                MenuItemIcon(systemName: "rectangle.on.rectangle", color: .accentColor, active: isSeparate)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Use as separate display")
                    Text("Off mirrors this Mac instead")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        // The main display has nothing to mirror; the switch would snap back.
        .disabled(isBusy || display.isMain)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .onAppear { isSeparate = !MirrorService.shared.isMirroring(display.displayID) }
    }

    private func apply(_ separate: Bool) {
        let id = display.displayID
        isSeparate = separate
        isBusy = true
        Task { @MainActor in
            if separate {
                _ = await MirrorService.shared.disableMirror(displayID: id)
            } else {
                let main = CGMainDisplayID()
                if main != id { _ = await MirrorService.shared.enableMirror(source: main, target: id) }
            }
            // Report what actually happened, not what was asked for.
            isSeparate = !MirrorService.shared.isMirroring(id)
            isBusy = false
        }
    }
}

/// Up / down buttons for the display's place in the panel.
private struct PanelOrderRow: View {
    @ObservedObject var display: DisplayInfo
    @ObservedObject var displayManager: DisplayManager

    var body: some View {
        HStack(spacing: 8) {
            MenuItemIcon(systemName: "arrow.up.arrow.down", color: .accentColor)
                .accessibilityHidden(true)
            Text("Order in panel")
            Spacer()
            Button {
                displayManager.moveInPanel(display, by: -1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(!displayManager.canMoveInPanel(display, by: -1))
            .accessibilityLabel(Text("Move Up"))
            Button {
                displayManager.moveInPanel(display, by: 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(!displayManager.canMoveInPanel(display, by: 1))
            .accessibilityLabel(Text("Move Down"))
            if displayManager.hasCustomPanelOrder {
                Button {
                    displayManager.resetPanelOrder()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help(Text("Reset Display Order"))
                .accessibilityLabel(Text("Reset Display Order"))
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

import SwiftUI

/// "iPad Display" section in the tools area: connect an iPad over Sidecar, and set
/// how it connects.
///
/// macOS puts the connect action in Control Centre's Screen Mirroring menu and the
/// extend-or-mirror choice in System Settings, so changing how you use the iPad
/// means leaving what you were doing. Both live here, next to the displays they sit
/// beside.
struct SidecarView: View {
    @StateObject private var service = SidecarService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if service.available.isEmpty {
                // Same centred empty state as the virtual display list; a
                // label-column indent reads as an orphaned row with no icon.
                Text("No iPad nearby")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                ForEach(service.available) { device in
                    SidecarDeviceRow(
                        name: device.name,
                        kind: device.kind,
                        isConnected: service.isConnected(device),
                        isBusy: service.busy.contains(device.id),
                        onTap: { service.toggle(device) }
                    )
                }
            }

            if let error = service.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }

            SectionDivider()
                .padding(.vertical, 2)

            // This one takes effect immediately, connected or not: it is ordinary
            // display mirroring rather than part of the Sidecar session.
            SidecarOptionToggle(
                icon: "rectangle.on.rectangle",
                label: "Use as separate display",
                subtitle: "Off mirrors this Mac instead",
                isOn: $service.useAsSeparateDisplay
            )
            SidecarOptionToggle(
                icon: "sidebar.left",
                label: "Show sidebar",
                subtitle: nil,
                isOn: $service.showSidebar
            )
            SidecarOptionToggle(
                icon: "rectangle.bottomthird.inset.filled",
                label: "Show Touch Bar",
                subtitle: nil,
                isOn: $service.showTouchBar
            )
            // Unlike the mirroring switch above, these two are part of the session
            // config SidecarCore reads when it opens, so they cannot change a running
            // one. Said out loud, because a switch that moves and changes nothing
            // reads as broken rather than as deferred.
            Text("The sidebar and Touch Bar apply the next time you connect")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 2)
                .padding(.bottom, 6)
        }
        // Hopped off the current update rather than called inline: every block is
        // rendered once at natural height during the panel's warm-up, so this runs
        // inside a layout pass, and refresh() publishes. Mutating observed state from
        // within a view update traps.
        .onAppear {
            Task { @MainActor in service.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .candelaPanelDidOpen)) { _ in
            Task { @MainActor in service.refresh() }
        }
    }
}

/// One nearby iPad. Tapping connects or disconnects.
struct SidecarDeviceRow: View {
    let name: String
    let kind: String
    let isConnected: Bool
    let isBusy: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            MenuItemIcon(systemName: "ipad.landscape", color: .blue, active: isConnected)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.body)
                    .lineLimit(1)
                Text(kind)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isBusy {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else if isConnected {
                Text("Connected")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .menuRowHover(isHovered)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { if !isBusy { onTap() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityValue(isConnected ? "Connected" : "Not connected")
        .accessibilityAddTraits(.isButton)
    }
}

/// A switch row matching the ones in Settings.
private struct SidecarOptionToggle: View {
    let icon: String
    let label: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                MenuItemIcon(systemName: icon, color: .accentColor, active: isOn)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.body)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

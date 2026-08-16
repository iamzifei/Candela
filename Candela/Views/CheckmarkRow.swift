import SwiftUI

// The checkmark row and its disclosure variant. Lifted out of DisplayModeListView
// because they are not about display modes: the language picker uses the same row,
// and a shared control living inside the file of its first caller is how a view
// file grows to nine hundred lines.

// MARK: - Checkmark row

/// One selectable line in a native display-menu list (resolution, refresh rate,
/// preset): a leading checkmark column, the label, and a hover highlight. The
/// checkmark slot becomes a spinner while an async switch is pending.
struct CheckmarkRow: View {
    let label: String
    let isSelected: Bool
    var isPending: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if isPending {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .opacity(isSelected ? 1 : 0)
                }
            }
            .frame(width: 16)
            Text(label)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
            Spacer()
        }
        .padding(.leading, 24)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .menuRowHover(isHovered)
        .contentShape(Rectangle())
        .onTapGesture {
            guard PanelOpenGuard.allowsActivation, !isSelected, !isPending else { return }
            action()
        }
        .onHover { isHovered = $0 }
        .accessibilityLabel(
            isSelected
                ? "\(NSLocalizedString(label, comment: ""))\(NSLocalizedString(", selected", comment: ""))"
                : NSLocalizedString(label, comment: "")
        )
        .accessibilityAddTraits(.isButton)
    }
}

/// A subordinate disclosure line (indented, chevron, hover) that reveals the full
/// "Show all resolutions" list beneath the Resolution slider. Lighter than
/// ExpandableRow (no leading icon chip) so it reads as a child of the slider.
private struct DisclosureSubRow: View {
    let label: LocalizedStringKey
    @Binding var isExpanded: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .accessibilityHidden(true)
        }
        .padding(.leading, 24)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .menuRowHover(isHovered)
        .contentShape(Rectangle())
        .onTapGesture {
            guard PanelOpenGuard.allowsActivation else { return }
            withAnimation(.panelResize) { isExpanded.toggle() }
        }
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(.isButton)
    }
}

import SwiftUI

/// The amber on/off switch from the design (44×26).
struct AmberSwitch: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Theme.amber : Theme.switchOff)
                    .frame(width: 44, height: 26)
                Circle()
                    .fill(isOn ? Color.white : Theme.knobOff)
                    .frame(width: 22, height: 22)
                    .padding(2)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// A row inside the grouped toggle card: icon tile, title, subtitle, trailing control.
struct FeatureRow<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    var subtitleColor: Color = Theme.secondary
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.iconTile)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(subtitleColor)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(12)
    }
}

struct StatusChip: View {
    let icon: String
    let text: String
    var warning = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(warning ? Theme.warnText : Theme.chipText)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(warning ? Theme.warnBackground : Theme.card))
    }
}

/// Small filled button used for "Grant…", "Run Setup…" and similar.
struct PillButton: View {
    let title: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: prominent ? .bold : .semibold))
                .foregroundColor(prominent ? Theme.onAmber : Theme.text)
                .padding(.horizontal, prominent ? 12 : 10)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(prominent ? Theme.amber : Theme.iconTile))
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}

/// Borderless footer button that highlights on hover.
struct FooterButton: View {
    let icon: String
    var title: String?
    let action: () -> Void
    @State var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundColor(title == nil ? Theme.secondary : Theme.text)
            .padding(.horizontal, title == nil ? 0 : 10)
            .frame(minWidth: 32, minHeight: 32)
            .background(RoundedRectangle(cornerRadius: 7).fill(hovering ? Theme.card : Color.clear))
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(title ?? "Quit StillOnMac")
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.5)
            .foregroundColor(Theme.secondary)
    }
}

struct CardDivider: View {
    var inset: CGFloat = 12

    var body: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

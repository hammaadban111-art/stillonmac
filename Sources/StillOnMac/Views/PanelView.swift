import SwiftUI

/// The menu bar popover.
struct PanelView: View {
    @EnvironmentObject var state: AppState
    let openSettings: () -> Void
    let displayOff: () -> Void
    let quit: () -> Void

    enum Tab {
        case keepOn, memory
    }

    @State var tab = Tab.keepOn

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(EdgeInsets(top: 12, leading: 12, bottom: 0, trailing: 12))
            switch tab {
            case .keepOn:
                keepOnTab
            case .memory:
                MemoryView()
            }
        }
        .frame(width: 340)
        .background(Theme.background)
        .foregroundColor(Theme.text)
    }

    private var keepOnTab: some View {
        VStack(spacing: 0) {
            header
            if !state.helperInstalled {
                setupBanner
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            mainToggle
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            featureCard
                .padding(.horizontal, 12)
            chips
                .padding(.horizontal, 12)
                .padding(.top, 12)
            Rectangle()
                .fill(Theme.divider)
                .frame(height: 1)
                .padding(.top, 12)
            footer
        }
    }

    // MARK: Tabs

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton("Keep On", .keepOn)
            tabButton("Memory", .memory)
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.card))
    }

    private func tabButton(_ title: String, _ value: Tab) -> some View {
        let selected = tab == value
        return Button {
            tab = value
        } label: {
            Text(title)
                .font(.system(size: 12, weight: selected ? .bold : .semibold))
                .foregroundColor(selected ? Theme.text : Theme.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Theme.cardBorder : Color.clear))
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(state.keepOn ? Theme.amberTile : Theme.iconTile)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: state.keepOn ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(state.keepOn ? Theme.amber : Theme.secondary)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("StillOnMac")
                    .font(.system(size: 15, weight: .bold))
                if state.keepOn, let since = state.awakeSince {
                    TimelineView(.periodic(from: Date(), by: 30)) { _ in
                        Text("Awake 24/7 · on for \(Format.duration(since: since))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.amber)
                    }
                } else {
                    Text("Sleep allowed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.secondary)
                }
            }
            Spacer()
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
    }

    // MARK: Setup banner

    private var setupBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("One-time setup needed", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.warnText)
            Text("Staying on with the lid closed and no display needs a small helper. Takes 10 seconds and your password once.")
                .font(.system(size: 12))
                .foregroundColor(Theme.warnBody)
                .fixedSize(horizontal: false, vertical: true)
            if let error = state.setupError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.warnText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PillButton(title: "Run Setup…", prominent: true) { state.runSetup() }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.warnBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.warnBorder, lineWidth: 1))
    }

    // MARK: Main toggle

    private var mainToggle: some View {
        Button {
            state.keepOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "power")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(state.keepOn ? Theme.onAmber : Theme.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep Mac On")
                        .font(.system(size: 15, weight: .bold))
                    Text(state.keepOn ? "No sleep, even with the lid shut and no display" : "Click to stop all sleep")
                        .font(.system(size: 12, weight: state.keepOn ? .medium : .regular))
                        .foregroundColor(state.keepOn ? Theme.onAmber : Theme.secondary)
                }
                Spacer(minLength: 0)
                Text(state.keepOn ? "ON" : "OFF")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(0.7)
                    .foregroundColor(state.keepOn ? Theme.onAmber : Theme.secondary)
            }
            .foregroundColor(state.keepOn ? Theme.onAmber : Theme.text)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(state.keepOn ? Theme.amber : Theme.card))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(state.keepOn ? Color.clear : Theme.cardBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Keep Mac On")
        .accessibilityValue(state.keepOn ? "On" : "Off")
    }

    // MARK: Feature toggles

    private var featureCard: some View {
        VStack(spacing: 0) {
            FeatureRow(
                icon: "lock.shield",
                title: "Block Shutdown & Restart",
                subtitle: state.allowNextShutdown ? "Next restart will be allowed" : "Cancels restart, shut down and log out"
            ) {
                AmberSwitch(isOn: $state.blockShutdown, label: "Block shutdown and restart")
            }
            CardDivider(inset: 54)
            FeatureRow(
                icon: "xmark.rectangle",
                title: "Auto-Quit Closed Apps",
                subtitle: state.accessibilityGranted
                    ? "Quits an app \(Int(state.graceSeconds))s after its last window closes"
                    : "Needs Accessibility access",
                subtitleColor: state.accessibilityGranted ? Theme.secondary : Theme.warnText
            ) {
                if state.accessibilityGranted {
                    AmberSwitch(isOn: $state.autoQuit, label: "Auto-quit closed apps")
                } else {
                    PillButton(title: "Grant…") { state.requestAccessibility() }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }

    // MARK: Chips

    private var chips: some View {
        HStack(spacing: 6) {
            StatusChip(
                icon: state.onCharger ? "powerplug" : "battery.25",
                text: state.onCharger ? "Charger connected" : "On battery",
                warning: !state.onCharger
            )
            StatusChip(icon: "laptopcomputer", text: state.lidClosed ? "Lid closed" : "Lid open")
            StatusChip(
                icon: state.helperInstalled ? "checkmark" : "exclamationmark.triangle",
                text: state.helperInstalled ? "Helper ready" : "Helper missing",
                warning: !state.helperInstalled
            )
            Spacer(minLength: 0)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 4) {
            FooterButton(icon: "display", title: "Display Off Now", action: displayOff)
            FooterButton(icon: "slider.horizontal.3", title: "Settings…", action: openSettings)
            Spacer()
            FooterButton(icon: "rectangle.portrait.and.arrow.right", action: quit)
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
    }
}

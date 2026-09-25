import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    let close: () -> Void

    let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.amberTile)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Theme.amber)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("Set up StillOnMac")
                    .font(.system(size: 26, weight: .bold))
                Text("Three quick steps and your Mac stays on 24/7, lid closed, monitor on or off.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.secondary)
            }

            VStack(spacing: 10) {
                step(
                    number: 1,
                    title: "Install lid-closed helper",
                    detail: "Lets the Mac stay awake with no display. Asks for your password once.",
                    done: state.helperInstalled,
                    isCurrent: !state.helperInstalled
                ) {
                    PillButton(title: "Install…", prominent: true) { state.runSetup() }
                }
                step(
                    number: 2,
                    title: "Allow Accessibility",
                    detail: "Needed to see when an app has no windows left.",
                    done: state.accessibilityGranted,
                    isCurrent: state.helperInstalled && !state.accessibilityGranted
                ) {
                    PillButton(title: "Open Settings", prominent: true) { state.requestAccessibility() }
                }
                step(
                    number: 3,
                    title: "Turn on Keep Mac On",
                    detail: "Click the cup in the menu bar any time to switch it off.",
                    done: state.keepOn,
                    isCurrent: state.helperInstalled && state.accessibilityGranted && !state.keepOn
                ) {
                    PillButton(title: "Turn On", prominent: true) { state.keepOn = true }
                }
            }

            if let error = state.setupError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.warnText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack {
                Button("Skip for now", action: close)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.chipText)
                Spacer()
                Button(action: close) {
                    Text(allDone ? "Done" : "Continue")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.onAmber)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.amber))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(36)
        .frame(width: 600, height: 600, alignment: .topLeading)
        .background(Theme.background)
        .foregroundColor(Theme.text)
        .onReceive(refresh) { _ in state.refreshStatus() }
    }

    private var allDone: Bool {
        state.helperInstalled && state.accessibilityGranted && state.keepOn
    }

    private func step<Action: View>(
        number: Int,
        title: String,
        detail: String,
        done: Bool,
        isCurrent: Bool,
        @ViewBuilder action: () -> Action
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? Color(hex: 0x1F4A2C) : (isCurrent ? Theme.amber : Theme.iconTile))
                    .frame(width: 28, height: 28)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(Theme.good)
                } else {
                    Text("\(number)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(isCurrent ? Theme.onAmber : Theme.chipText)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .bold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if done {
                Text("Done")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.good)
            } else if isCurrent {
                action()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrent ? Theme.amber : Color.clear, lineWidth: 1)
        )
    }
}

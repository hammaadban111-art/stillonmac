import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                general
                status
                shutdown
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            autoQuit
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(width: 720, height: 560)
        .background(Theme.background)
        .foregroundColor(Theme.text)
        .tint(Theme.amber)
    }

    // MARK: General

    private var general: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "General")
            VStack(spacing: 0) {
                checkboxRow("Launch at login", isOn: $state.launchAtLogin)
                CardDivider()
                checkboxRow("Turn Keep Mac On at launch", isOn: $state.keepOnAtLaunch)
                CardDivider()
                checkboxRow("Notify when restart is blocked", isOn: $state.notifyOnBlock)
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        }
    }

    private func checkboxRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            Toggle(title, isOn: isOn)
                .toggleStyle(.checkbox)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    // MARK: Status

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Status")
            VStack(spacing: 0) {
                statusRow("Accessibility", ok: state.accessibilityGranted, okText: "Granted") {
                    PillButton(title: "Grant…") { state.requestAccessibility() }
                }
                CardDivider()
                statusRow("Lid-closed helper", ok: state.helperInstalled, okText: "Installed") {
                    PillButton(title: "Install…", prominent: true) { state.runSetup() }
                }
                CardDivider()
                statusRow("Auto macOS update installs", ok: state.autoUpdatesOff, okText: "Off") {
                    Text("On · run setup")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.warnText)
                }
                CardDivider()
                statusRow("Lid-closed sleep", ok: state.lidSleepDisabled, okText: "Disabled") {
                    Text("Allowed")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.secondary)
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            if let error = state.setupError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.warnText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusRow<Fix: View>(
        _ title: String, ok: Bool, okText: String, @ViewBuilder fix: () -> Fix
    ) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            if ok {
                Text(okText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.good)
            } else {
                fix()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    // MARK: Shutdown

    private var shutdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Shutdown")
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Let the next restart through").font(.system(size: 13))
                    Text("For a planned update. Blocking resumes after.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.secondary)
                }
                Spacer()
                PillButton(title: state.allowNextShutdown ? "Allowed · Undo" : "Allow Once") {
                    state.allowNextShutdown.toggle()
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        }
    }

    // MARK: Auto-Quit

    private struct AppEntry: Identifiable {
        let id: String
        let name: String
        let icon: NSImage?
    }

    private var entries: [AppEntry] {
        var ids = Set(state.excludedBundleIDs).union(AppState.alwaysExcluded)
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier {
                ids.insert(id)
            }
        }
        return ids.map { id in
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            let name = url.map { FileManager.default.displayName(atPath: $0.path) } ?? id
            let icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
            let trimmed = name.hasSuffix(".app") ? String(name.dropLast(4)) : name
            return AppEntry(id: id, name: trimmed, icon: icon)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static let notes = [
        "com.apple.finder": "always",
        "com.apple.Terminal": "runs Claude Code",
    ]

    private var autoQuit: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Auto-Quit")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Quit after last window closes").font(.system(size: 13))
                    Spacer()
                    Text("\(Int(state.graceSeconds)) s")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.amber)
                }
                Slider(value: $state.graceSeconds, in: 3...60, step: 1)
                    .accessibilityLabel("Seconds before quitting")
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))

            Text("Never auto-quit these apps")
                .font(.system(size: 12))
                .foregroundColor(Theme.secondary)
                .padding(.top, 4)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(entries) { entry in
                            appRow(entry)
                            CardDivider(inset: 0)
                        }
                    }
                }
                HStack {
                    PillButton(title: "Add App…") { addApp() }
                    Spacer()
                }
                .padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func appRow(_ entry: AppEntry) -> some View {
        let locked = AppState.alwaysExcluded.contains(entry.id)
        return HStack(spacing: 10) {
            if let icon = entry.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.iconTile)
                    .frame(width: 22, height: 22)
            }
            Text(entry.name)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer()
            if let note = Self.notes[entry.id] {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.secondary)
            }
            Toggle(entry.name, isOn: Binding(
                get: { state.isExcluded(entry.id) },
                set: { state.setExcluded(entry.id, $0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(locked)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Never Auto-Quit"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier {
                state.setExcluded(id, true)
            }
        }
    }
}

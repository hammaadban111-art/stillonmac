import AppKit
import Combine
import SwiftUI

/// Settings, live status, and the actions the UI triggers.
final class AppState: ObservableObject {
    static let shared = AppState()

    private enum Keys {
        static let keepOn = "keepOn"
        static let blockShutdown = "blockShutdown"
        static let autoQuit = "autoQuit"
        static let graceSeconds = "graceSeconds"
        static let excluded = "excludedBundleIDs"
        static let keepOnAtLaunch = "keepOnAtLaunch"
        static let notifyOnBlock = "notifyOnBlock"
        static let onboardingDone = "onboardingDone"
    }

    /// Never auto-quit, whatever the exclusion list says.
    static let alwaysExcluded: Set<String> = ["com.apple.finder"]
    static let defaultExcluded = [
        "com.apple.finder",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.anthropic.claudefordesktop",
    ]

    private let defaults = UserDefaults.standard
    private let awake = AwakeController()
    private let quitter = AutoQuitter()
    private var statusTimer: Timer?

    // MARK: Settings

    @Published var keepOn: Bool {
        didSet {
            guard keepOn != oldValue else { return }
            defaults.set(keepOn, forKey: Keys.keepOn)
            applyKeepOn()
        }
    }

    @Published var blockShutdown: Bool {
        didSet { defaults.set(blockShutdown, forKey: Keys.blockShutdown) }
    }

    @Published var autoQuit: Bool {
        didSet {
            defaults.set(autoQuit, forKey: Keys.autoQuit)
            quitter.isEnabled = autoQuit
        }
    }

    @Published var graceSeconds: Double {
        didSet {
            defaults.set(graceSeconds, forKey: Keys.graceSeconds)
            quitter.graceSeconds = graceSeconds
        }
    }

    @Published var excludedBundleIDs: [String] {
        didSet { defaults.set(excludedBundleIDs, forKey: Keys.excluded) }
    }

    @Published var keepOnAtLaunch: Bool {
        didSet { defaults.set(keepOnAtLaunch, forKey: Keys.keepOnAtLaunch) }
    }

    @Published var notifyOnBlock: Bool {
        didSet { defaults.set(notifyOnBlock, forKey: Keys.notifyOnBlock) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            LoginItem.set(launchAtLogin)
        }
    }

    var onboardingDone: Bool {
        get { defaults.bool(forKey: Keys.onboardingDone) }
        set { defaults.set(newValue, forKey: Keys.onboardingDone) }
    }

    /// One restart or shutdown gets through, then blocking resumes.
    @Published var allowNextShutdown = false

    // MARK: Live status

    @Published private(set) var awakeSince: Date?
    @Published private(set) var helperInstalled = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var autoUpdatesOff = false
    @Published private(set) var lidSleepDisabled = false
    @Published private(set) var onCharger = true
    @Published private(set) var lidClosed = false
    @Published private(set) var setupError: String?

    private init() {
        // `self.defaults` can't be read until every stored property is set.
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Keys.keepOn: false,
            Keys.blockShutdown: true,
            Keys.autoQuit: false,
            Keys.graceSeconds: 10.0,
            Keys.excluded: Self.defaultExcluded,
            Keys.keepOnAtLaunch: true,
            Keys.notifyOnBlock: true,
        ])
        keepOn = false // applied in start()
        blockShutdown = defaults.bool(forKey: Keys.blockShutdown)
        autoQuit = defaults.bool(forKey: Keys.autoQuit)
        graceSeconds = defaults.double(forKey: Keys.graceSeconds)
        excludedBundleIDs = defaults.stringArray(forKey: Keys.excluded) ?? Self.defaultExcluded
        keepOnAtLaunch = defaults.bool(forKey: Keys.keepOnAtLaunch)
        notifyOnBlock = defaults.bool(forKey: Keys.notifyOnBlock)
        launchAtLogin = LoginItem.isEnabled
    }

    func start() {
        quitter.graceSeconds = graceSeconds
        quitter.excludedBundleIDs = { [weak self] in
            Set(self?.excludedBundleIDs ?? []).union(AppState.alwaysExcluded)
        }
        quitter.isEnabled = autoQuit
        quitter.start()

        refreshStatus()
        if keepOnAtLaunch || defaults.bool(forKey: Keys.keepOn) {
            keepOn = true
        }
        statusTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    /// Lets the Mac sleep again when the app quits. The saved toggle is kept,
    /// so the next launch turns it back on.
    func prepareForQuit() {
        awake.setOn(false)
    }

    // MARK: Status

    func refreshStatus() {
        let pmset = SystemStatus.pmsetSettings()
        update(\.helperInstalled, SystemStatus.helperInstalled)
        update(\.accessibilityGranted, SystemStatus.accessibilityGranted)
        update(\.autoUpdatesOff, SystemStatus.autoMacOSUpdatesOff)
        update(\.lidSleepDisabled, pmset["SleepDisabled"] == "1")
        update(\.onCharger, SystemStatus.onCharger)
        update(\.lidClosed, SystemStatus.lidClosed)

        // Something else may have reset it; put it back.
        if keepOn && helperInstalled && !lidSleepDisabled {
            if awake.setLidSleepDisabled(true) {
                lidSleepDisabled = true
            }
        }
    }

    private func update<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<AppState, T>, _ value: T) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }

    private func applyKeepOn() {
        awake.setOn(keepOn)
        awakeSince = keepOn ? Date() : nil
        refreshStatus()
    }

    // MARK: Actions

    /// Runs the bundled setup script as root through the standard macOS password prompt.
    func runSetup() {
        guard let script = Bundle.main.path(forResource: "setup-power", ofType: "sh") else {
            setupError = "setup-power.sh is missing from the app bundle. Rebuild with scripts/build.sh."
            return
        }
        let command = "/bin/bash \(Shell.quote(script)) \(Shell.quote(NSUserName()))"
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"

        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error = error {
            let code = error[NSAppleScript.errorNumber] as? Int
            // -128 = the user pressed Cancel.
            setupError = code == -128 ? nil : (error[NSAppleScript.errorMessage] as? String ?? "Setup failed.")
        } else {
            setupError = nil
        }
        refreshStatus()
        if keepOn {
            awake.setOn(true)
            refreshStatus()
        }
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary // kAXTrustedCheckOptionPrompt
        if !AXIsProcessTrustedWithOptions(options),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        refreshStatus()
    }

    /// Sleeps the display after a short delay, so the click that triggered it
    /// (and the popover closing) doesn't wake it straight back up.
    func displayOffNow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            Shell.run("/usr/bin/pmset", ["displaysleepnow"])
        }
    }

    func isExcluded(_ bundleID: String) -> Bool {
        AppState.alwaysExcluded.contains(bundleID) || excludedBundleIDs.contains(bundleID)
    }

    func setExcluded(_ bundleID: String, _ excluded: Bool) {
        if excluded {
            if !excludedBundleIDs.contains(bundleID) {
                excludedBundleIDs.append(bundleID)
            }
        } else {
            excludedBundleIDs.removeAll { $0 == bundleID }
        }
    }
}

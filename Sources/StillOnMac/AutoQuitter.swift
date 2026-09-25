import AppKit
import ApplicationServices

/// Quits a regular app once its last window has been closed.
///
/// An app is only quit after we have seen it with at least one window and
/// then with none for `graceSeconds`. Switching Spaces or displays resets
/// what we have seen, because windows on other Spaces drop out of the
/// Accessibility window list and would otherwise look closed.
final class AutoQuitter {
    var isEnabled = false {
        didSet { if !isEnabled { reset() } }
    }
    var graceSeconds: TimeInterval = 10
    var excludedBundleIDs: () -> Set<String> = { [] }

    private var timer: Timer?
    private var hadWindows = Set<pid_t>()
    private var emptySince: [pid_t: Date] = [:]
    private var observers: [NSObjectProtocol] = []

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.reset() })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.reset() })
    }

    func reset() {
        hadWindows.removeAll()
        emptySince.removeAll()
    }

    private func tick() {
        guard isEnabled, AXIsProcessTrusted() else {
            reset()
            return
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let excluded = excludedBundleIDs()
        let now = Date()
        var alive = Set<pid_t>()

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let pid = app.processIdentifier
            guard pid != ownPID,
                  let bundleID = app.bundleIdentifier,
                  !excluded.contains(bundleID),
                  !app.isTerminated,
                  !app.isHidden
            else { continue }
            alive.insert(pid)

            guard let count = Self.windowCount(pid: pid) else { continue }
            if count > 0 {
                hadWindows.insert(pid)
                emptySince[pid] = nil
                continue
            }
            guard hadWindows.contains(pid) else { continue }

            guard let since = emptySince[pid] else {
                emptySince[pid] = now
                continue
            }
            if now.timeIntervalSince(since) >= graceSeconds {
                hadWindows.remove(pid)
                emptySince[pid] = nil
                app.terminate()
            }
        }

        hadWindows.formIntersection(alive)
        emptySince = emptySince.filter { alive.contains($0.key) }
    }

    /// Number of windows the app exposes through Accessibility (minimised ones
    /// included), or nil when the app does not answer.
    static func windowCount(pid: pid_t) -> Int? {
        let element = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success else {
            return nil
        }
        return (value as? [AXUIElement])?.count
    }
}

import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState.shared
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var userRequestedQuit = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Never let macOS silently kill us; quits must go through applicationShouldTerminate.
        ProcessInfo.processInfo.disableSuddenTermination()
        ProcessInfo.processInfo.disableAutomaticTermination("StillOnMac keeps the Mac awake")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = NSHostingController(rootView: PanelView(
            openSettings: { [weak self] in self?.showSettings() },
            displayOff: { [weak self] in
                self?.popover.performClose(nil)
                self?.state.displayOffNow()
            },
            quit: { [weak self] in self?.quit() }
        ).environmentObject(state))

        state.$keepOn
            .receive(on: RunLoop.main)
            .sink { [weak self] on in self?.updateIcon(keepOn: on) }
            .store(in: &cancellables)

        Notifier.shared.setup()
        Notifier.shared.onAllowOnce = { [weak self] in self?.state.allowNextShutdown = true }

        state.start()
        updateIcon(keepOn: state.keepOn)

        if !state.onboardingDone && (!state.helperInstalled || !state.accessibilityGranted) {
            showOnboarding()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if userRequestedQuit {
            return .terminateNow
        }
        if state.blockShutdown && ShutdownBlocker.isSystemQuit() {
            if state.allowNextShutdown {
                state.allowNextShutdown = false
                return .terminateNow
            }
            if state.notifyOnBlock {
                Notifier.shared.postRestartBlocked()
            }
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.prepareForQuit()
    }

    // MARK: Menu bar

    private func updateIcon(keepOn: Bool) {
        guard let button = statusItem?.button else { return }
        let name = keepOn ? "cup.and.saucer.fill" : "cup.and.saucer"
        var image = NSImage(systemSymbolName: name, accessibilityDescription: "StillOnMac")
        if keepOn {
            image = image?.withSymbolConfiguration(.init(paletteColors: [Theme.menuBarAmber]))
            image?.isTemplate = false
        } else {
            image?.isTemplate = true
        }
        button.image = image
        button.toolTip = keepOn ? "StillOnMac: awake 24/7" : "StillOnMac: sleep allowed"
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            state.refreshStatus()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: Windows

    private func showSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            settingsWindow = makeWindow(
                title: "StillOnMac Settings",
                size: NSSize(width: 720, height: 560),
                root: SettingsView().environmentObject(state)
            )
        }
        present(settingsWindow)
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = makeWindow(
                title: "Set up StillOnMac",
                size: NSSize(width: 600, height: 600),
                root: OnboardingView(close: { [weak self] in
                    self?.state.onboardingDone = true
                    self?.onboardingWindow?.close()
                }).environmentObject(state)
            )
        }
        present(onboardingWindow)
    }

    private func makeWindow<V: View>(title: String, size: NSSize, root: V) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(hex: 0x242228)
        window.contentViewController = NSHostingController(rootView: root)
        window.setContentSize(size)
        window.center()
        return window
    }

    private func present(_ window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func quit() {
        userRequestedQuit = true
        NSApp.terminate(nil)
    }
}

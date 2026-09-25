import Foundation
import IOKit.pwr_mgt

/// Keeps the system and display awake.
///
/// Power assertions stop idle sleep, but macOS still sleeps a closed-lid
/// laptop once no external display is attached. `pmset disablesleep 1`
/// covers that case; it needs root, which the one-time setup grants through
/// a narrow sudoers rule.
final class AwakeController {
    private static let assertionTypes = [
        "PreventUserIdleDisplaySleep",
        "PreventUserIdleSystemSleep",
        "PreventSystemSleep",
    ]

    private var assertionIDs: [IOPMAssertionID] = []

    /// Returns false when the lid-closed part could not be applied (helper missing).
    @discardableResult
    func setOn(_ on: Bool) -> Bool {
        if on {
            createAssertions()
        } else {
            releaseAssertions()
        }
        return setLidSleepDisabled(on)
    }

    @discardableResult
    func setLidSleepDisabled(_ disabled: Bool) -> Bool {
        let result = Shell.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"])
        return result.status == 0
    }

    private func createAssertions() {
        guard assertionIDs.isEmpty else { return }
        for type in Self.assertionTypes {
            var id = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "StillOnMac: Keep Mac On 24/7" as CFString,
                &id
            )
            if result == kIOReturnSuccess {
                assertionIDs.append(id)
            }
        }
    }

    private func releaseAssertions() {
        for id in assertionIDs {
            IOPMAssertionRelease(id)
        }
        assertionIDs.removeAll()
    }
}

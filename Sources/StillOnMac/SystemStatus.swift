import ApplicationServices
import Foundation
import IOKit
import IOKit.ps

/// Read-only probes of the machine's power and permission state.
enum SystemStatus {
    static let sudoersPath = "/etc/sudoers.d/stillonmac"

    static var helperInstalled: Bool {
        FileManager.default.fileExists(atPath: sudoersPath)
    }

    static var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// `pmset -g` as key → value, e.g. "SleepDisabled" → "1".
    static func pmsetSettings() -> [String: String] {
        let output = Shell.run("/usr/bin/pmset", ["-g"]).output
        var settings: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.count >= 2 {
                settings[String(parts[0])] = String(parts[1])
            }
        }
        return settings
    }

    static var autoMacOSUpdatesOff: Bool {
        let prefs = NSDictionary(contentsOfFile: "/Library/Preferences/com.apple.SoftwareUpdate.plist")
        return (prefs?["AutomaticallyInstallMacOSUpdates"] as? Bool) == false
    }

    static var onCharger: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
        else { return true }
        return (type as String) == kIOPSACPowerValue
    }

    static var lidClosed: Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
        return (value as? Bool) ?? false
    }
}

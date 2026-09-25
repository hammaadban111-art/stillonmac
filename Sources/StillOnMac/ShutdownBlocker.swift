import AppKit

/// Recognises the quit Apple Event macOS sends to every app before a
/// restart, shutdown or logout. Cancelling that quit aborts the whole
/// sequence and macOS reports "StillOnMac interrupted restart".
enum ShutdownBlocker {
    private static func fourCharCode(_ s: String) -> OSType {
        s.utf8.reduce(0) { ($0 << 8) | OSType($1) }
    }

    private static let quitReasonKey = AEKeyword(ShutdownBlocker.fourCharCode("why?"))

    private static let systemQuitReasonCodes: [String] = [
        "logo", // kAELogOut
        "rlgo", // kAEReallyLogOut
        "rrst", // kAEShowRestartDialog
        "rsdn", // kAEShowShutdownDialog
        "rest", // kAERestart
        "shut", // kAEShutDown
    ]

    private static let systemQuitReasons = Set(systemQuitReasonCodes.map { ShutdownBlocker.fourCharCode($0) })

    /// True when the current quit request comes from a restart, shutdown or logout.
    static func isSystemQuit() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              let reason = event.attributeDescriptor(forKeyword: quitReasonKey)?.enumCodeValue
        else { return false }
        return systemQuitReasons.contains(reason)
    }
}

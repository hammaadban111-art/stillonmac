import Foundation

/// Runs a shell command as root behind the standard macOS password prompt.
enum AdminRunner {
    enum Outcome {
        case ok
        case cancelled
        case failed(String)
    }

    static func run(_ command: String) -> Outcome {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"

        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard let error = error else { return .ok }
        // -128 = the user pressed Cancel.
        if (error[NSAppleScript.errorNumber] as? Int) == -128 {
            return .cancelled
        }
        return .failed(error[NSAppleScript.errorMessage] as? String ?? "The command failed.")
    }
}

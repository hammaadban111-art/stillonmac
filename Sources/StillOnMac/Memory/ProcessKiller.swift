import AppKit
import Darwin

/// Something the Memory list can stop: a whole app or one process.
struct StopTarget {
    let id: String
    let name: String
    let pid: pid_t
    let app: NSRunningApplication?

    init(row: MemoryRow) {
        id = row.id
        name = row.name
        pid = row.pid
        app = row.app
    }

    init(process: ProcessEntry) {
        id = "pid:\(process.pid)"
        name = process.name
        pid = process.pid
        app = nil
    }
}

enum ProcessKiller {
    enum Outcome {
        case requested
        case needsAdmin
        case failed(String)
    }

    /// Stopping these would crash or log out the Mac.
    private static let protectedNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "loginwindow", "opendirectoryd",
        "configd", "securityd", "coreservicesd", "notifyd", "diskarbitrationd",
        "UserEventAgent", "logd", "powerd", "StillOnMac",
    ]

    static func isProtected(pid: pid_t, name: String) -> Bool {
        pid <= 1 || pid == ProcessInfo.processInfo.processIdentifier || protectedNames.contains(name)
    }

    /// Polite stop: apps get a normal Quit (they can still ask to save), processes get SIGTERM.
    static func stop(_ target: StopTarget) -> Outcome {
        if let app = target.app {
            return app.terminate() ? .requested : .failed("\(target.name) refused to quit.")
        }
        return send(SIGTERM, to: target.pid)
    }

    /// Immediate stop, for when the polite one was ignored.
    static func forceStop(_ target: StopTarget) -> Outcome {
        if let app = target.app {
            return app.forceTerminate() ? .requested : .failed("Couldn't force quit \(target.name).")
        }
        return send(SIGKILL, to: target.pid)
    }

    /// For processes owned by root or another user.
    static func stopAsAdmin(_ target: StopTarget, force: Bool) -> Outcome {
        switch AdminRunner.run("/bin/kill -\(force ? "KILL" : "TERM") \(target.pid)") {
        case .ok: return .requested
        case .cancelled: return .needsAdmin
        case .failed(let message): return .failed(message)
        }
    }

    static func isRunning(pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    private static func send(_ sig: Int32, to pid: pid_t) -> Outcome {
        if kill(pid, sig) == 0 {
            return .requested
        }
        if errno == EPERM {
            return .needsAdmin
        }
        if errno == ESRCH {
            return .requested // already gone
        }
        return .failed(String(cString: strerror(errno)))
    }
}

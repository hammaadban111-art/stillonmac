import AppKit
import Darwin

struct ProcessEntry: Identifiable {
    let pid: pid_t
    let uid: uid_t
    let bytes: UInt64
    let ageSeconds: Int
    let path: String
    let label: String

    var id: pid_t { pid }
    var name: String { (path as NSString).lastPathComponent }
}

/// One line in the Memory list: either a whole app (with its helper
/// processes) or a single standalone process.
struct MemoryRow: Identifiable {
    let id: String
    let label: String
    let name: String
    let bytes: UInt64
    let ageSeconds: Int
    let pid: pid_t
    let app: NSRunningApplication?
    let children: [ProcessEntry]
    let isProtected: Bool
}

struct MemorySnapshot {
    enum Pressure {
        case normal, busy, critical
    }

    let usedBytes: UInt64
    let totalBytes: UInt64
    let pressure: Pressure
    let rows: [MemoryRow]
}

/// Samples memory use. Only runs while the Memory tab is on screen, so the
/// app costs nothing in the background.
final class MemorySampler: ObservableObject {
    @Published private(set) var snapshot: MemorySnapshot?

    static let rowLimit = 15

    private var timer: Timer?
    private var isSampling = false
    private let queue = DispatchQueue(label: "StillOnMac.memory", qos: .utility)

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func sample() {
        guard !isSampling else { return }
        isSampling = true
        let apps: [(path: String, app: NSRunningApplication)] = NSWorkspace.shared.runningApplications
            .compactMap { app in app.bundleURL.map { ($0.path, app) } }
            // Longest path first, so an app nested inside another app's bundle wins.
            .sorted { $0.path.count > $1.path.count }

        queue.async { [weak self] in
            let snapshot = MemorySampler.take(apps: apps)
            DispatchQueue.main.async {
                self?.snapshot = snapshot
                self?.isSampling = false
            }
        }
    }

    // MARK: Snapshot

    private struct RawProcess {
        let pid: pid_t
        let uid: uid_t
        let bytes: UInt64
        let ageSeconds: Int
        let path: String
    }

    private static func take(apps: [(path: String, app: NSRunningApplication)]) -> MemorySnapshot {
        let processes = readProcesses()

        var groups: [String: (app: NSRunningApplication, members: [RawProcess])] = [:]
        var standalone: [RawProcess] = []
        for process in processes {
            if let match = apps.first(where: { process.path.hasPrefix($0.path + "/") }) {
                groups[match.path, default: (app: match.app, members: [])].members.append(process)
            } else {
                standalone.append(process)
            }
        }

        var rows: [MemoryRow] = []
        for (_, group) in groups {
            let app = group.app
            let appName = app.localizedName ?? "App"
            let children = group.members
                .map { entry($0, appName: appName) }
                .sorted { $0.bytes > $1.bytes }
            let main = group.members.first { $0.pid == app.processIdentifier }
            let pid = app.processIdentifier
            rows.append(MemoryRow(
                id: "app:\(pid)",
                label: ProcessDescriber.appLabel(bundleID: app.bundleIdentifier),
                name: appName,
                bytes: group.members.reduce(0) { $0 + $1.bytes },
                ageSeconds: main?.ageSeconds ?? group.members.map(\.ageSeconds).max() ?? 0,
                pid: pid,
                app: app,
                children: children.count > 1 ? children : [],
                isProtected: ProcessKiller.isProtected(pid: pid, name: appName)
            ))
        }
        for process in standalone {
            let described = entry(process, appName: nil)
            rows.append(MemoryRow(
                id: "pid:\(process.pid)",
                label: described.label,
                name: described.name,
                bytes: process.bytes,
                ageSeconds: process.ageSeconds,
                pid: process.pid,
                app: nil,
                children: [],
                isProtected: ProcessKiller.isProtected(pid: process.pid, name: described.name)
            ))
        }
        rows.sort { $0.bytes > $1.bytes }

        let (used, total) = systemMemory()
        return MemorySnapshot(
            usedBytes: used,
            totalBytes: total,
            pressure: pressure(),
            rows: Array(rows.prefix(rowLimit))
        )
    }

    private static func entry(_ process: RawProcess, appName: String?) -> ProcessEntry {
        let name = (process.path as NSString).lastPathComponent
        return ProcessEntry(
            pid: process.pid,
            uid: process.uid,
            bytes: process.bytes,
            ageSeconds: process.ageSeconds,
            path: process.path,
            label: ProcessDescriber.label(name: name, path: process.path, appName: appName)
        )
    }

    /// Every process via `ps`, which can see other users' processes too.
    /// For our own processes the resident size is replaced by the memory
    /// footprint, the figure Activity Monitor shows.
    private static func readProcesses() -> [RawProcess] {
        let output = Shell.run("/bin/ps", ["-axo", "pid=,uid=,rss=,etime=,comm="]).output
        let myUID = getuid()
        var result: [RawProcess] = []
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard fields.count == 5,
                  let pid = pid_t(fields[0]),
                  let uid = uid_t(fields[1]),
                  let rssKB = UInt64(fields[2])
            else { continue }
            let path = fields[4].trimmingCharacters(in: .whitespaces)
            var bytes = rssKB * 1024
            if uid == myUID, let footprint = footprint(pid: pid) {
                bytes = footprint
            }
            guard bytes > 0 else { continue }
            result.append(RawProcess(
                pid: pid,
                uid: uid,
                bytes: bytes,
                ageSeconds: parseElapsed(fields[3]),
                path: path
            ))
        }
        return result
    }

    private static func footprint(pid: pid_t) -> UInt64? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? info.ri_phys_footprint : nil
    }

    /// `ps` elapsed time: "[[dd-]hh:]mm:ss" → seconds.
    static func parseElapsed(_ text: Substring) -> Int {
        var days = 0
        var clock = text
        if let dash = text.firstIndex(of: "-") {
            days = Int(text[..<dash]) ?? 0
            clock = text[text.index(after: dash)...]
        }
        let seconds = clock.split(separator: ":").reduce(0) { $0 * 60 + (Int($1) ?? 0) }
        return days * 86_400 + seconds
    }

    /// Used the way Activity Monitor counts it: app memory + wired + compressed.
    private static func systemMemory() -> (used: UInt64, total: UInt64) {
        let total = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, total) }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = UInt64(pageSize)
        let appPages = UInt64(stats.internal_page_count) - min(UInt64(stats.purgeable_count), UInt64(stats.internal_page_count))
        let used = (appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
        return (min(used, total), total)
    }

    private static func pressure() -> MemorySnapshot.Pressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else {
            return .normal
        }
        switch level {
        case 4...: return .critical
        case 2...: return .busy
        default: return .normal
        }
    }
}

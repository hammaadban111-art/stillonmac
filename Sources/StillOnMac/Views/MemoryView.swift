import AppKit
import SwiftUI

/// The Memory tab: what is using RAM, for how long, with a stop button on each line.
struct MemoryView: View {
    @StateObject var sampler = MemorySampler()
    @State var expanded: Set<String> = []
    @State var confirming: String?
    /// When a polite stop was sent; after a few seconds a Force button appears.
    @State var stopRequested: [String: Date] = [:]
    @State var needsAdmin: Set<String> = []
    @State var message: String?

    private static let forceAfter: TimeInterval = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
            list
                .padding(.horizontal, 12)
            if let message = message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.warnText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
            }
            footer
        }
        .onAppear { sampler.start() }
        .onDisappear { sampler.stop() }
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.willShowNotification)) { _ in
            sampler.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.didCloseNotification)) { _ in
            sampler.stop()
            confirming = nil
        }
        .onReceive(sampler.$snapshot) { snapshot in
            forgetGone(snapshot)
        }
    }

    /// Drops pending-stop state for things that are no longer listed.
    private func forgetGone(_ snapshot: MemorySnapshot?) {
        guard let rows = snapshot?.rows else { return }
        var live = Set(rows.map(\.id))
        for row in rows {
            for child in row.children {
                live.insert("pid:\(child.pid)")
            }
        }
        stopRequested = stopRequested.filter { live.contains($0.key) }
        needsAdmin = needsAdmin.filter { live.contains($0) }
    }

    // MARK: Header

    private var header: some View {
        let snapshot = sampler.snapshot
        let used = snapshot?.usedBytes ?? 0
        let total = snapshot?.totalBytes ?? ProcessInfo.processInfo.physicalMemory
        let fraction = total > 0 ? min(1, Double(used) / Double(total)) : 0
        let strained = (snapshot?.pressure ?? .normal) != .normal

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot == nil ? "Checking…" : Self.gigabytes(used))
                    .font(.system(size: 15, weight: .bold))
                + Text(snapshot == nil ? "" : " of \(Self.gigabytes(total)) GB used")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.secondary)
                Spacer()
                StatusChip(icon: "gauge.medium", text: pressureText, warning: strained)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.divider)
                    Capsule()
                        .fill(strained ? Theme.warnText : Theme.amber)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 8)
            .accessibilityElement()
            .accessibilityLabel("Memory used")
            .accessibilityValue("\(Int(fraction * 100)) percent")
            Text("Biggest first · updates every 3 s while open")
                .font(.system(size: 11))
                .foregroundColor(Theme.secondary)
        }
    }

    private var pressureText: String {
        switch sampler.snapshot?.pressure ?? .normal {
        case .normal: return "Normal"
        case .busy: return "Busy"
        case .critical: return "Critical"
        }
    }

    /// "5.9" (the unit is added by the caller).
    private static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f", Double(bytes) / 1_073_741_824)
    }

    // MARK: List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sampler.snapshot?.rows ?? []) { row in
                    rowView(row)
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
            }
        }
        .frame(height: 420)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func rowView(_ row: MemoryRow) -> some View {
        let target = StopTarget(row: row)
        VStack(alignment: .leading, spacing: 0) {
            if confirming == row.id {
                confirmBar(target)
            } else {
                HStack(spacing: 8) {
                    if row.children.isEmpty {
                        Color.clear.frame(width: 18, height: 18)
                    } else {
                        Button {
                            toggle(row.id)
                        } label: {
                            Image(systemName: expanded.contains(row.id) ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.secondary)
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(expanded.contains(row.id) ? "Hide processes" : "Show processes")
                    }
                    titleBlock(label: row.label, name: row.name, bytes: row.bytes, age: row.ageSeconds, size: 12)
                    Spacer(minLength: 4)
                    trailing(target, isProtected: row.isProtected, size: 16)
                }
                .padding(EdgeInsets(top: 9, leading: 8, bottom: 9, trailing: 10))
            }
            if expanded.contains(row.id) && confirming != row.id {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(row.children) { child in
                        let childTarget = StopTarget(process: child)
                        if confirming == childTarget.id {
                            confirmBar(childTarget)
                        } else {
                            HStack(spacing: 8) {
                                titleBlock(label: child.label, name: child.name, bytes: child.bytes, age: child.ageSeconds, size: 11)
                                Spacer(minLength: 4)
                                trailing(childTarget, isProtected: false, size: 13)
                            }
                        }
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 34, bottom: 8, trailing: 10))
            }
        }
    }

    /// "(Emulator) qemu-system-aarch64" over "2.1 GB · running 3h 12m".
    private func titleBlock(label: String, name: String, bytes: UInt64, age: Int, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            (Text("(\(label)) ").font(.system(size: size, weight: .bold)).foregroundColor(Theme.amber)
                + Text(name).font(.system(size: size, design: .monospaced)).foregroundColor(Theme.chipText))
                .lineLimit(1)
                .truncationMode(.tail)
            (Text(Format.bytes(bytes)).font(.system(size: size - 1, weight: .bold)).foregroundColor(Theme.text)
                + Text(" · running \(Format.duration(seconds: age))").font(.system(size: size - 1)).foregroundColor(Theme.secondary))
                .lineLimit(1)
        }
        .help("\(name) · \(Format.bytes(bytes))")
    }

    @ViewBuilder
    private func trailing(_ target: StopTarget, isProtected: Bool, size: CGFloat) -> some View {
        if isProtected {
            Image(systemName: "lock.fill")
                .font(.system(size: size - 3))
                .foregroundColor(Theme.switchOff)
                .frame(width: 28, height: 28)
                .help("macOS needs this to keep running")
                .accessibilityLabel("Can't be stopped")
        } else if needsAdmin.contains(target.id) {
            PillButton(title: "Stop as Admin") { stopAsAdmin(target) }
        } else if let asked = stopRequested[target.id] {
            if Date().timeIntervalSince(asked) >= Self.forceAfter {
                PillButton(title: "Force Quit", prominent: true) { forceStop(target) }
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
            }
        } else {
            Button {
                confirming = target.id
                message = nil
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: size))
                    .foregroundColor(Theme.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Stop \(target.name)")
            .accessibilityLabel("Stop \(target.name)")
        }
    }

    private func confirmBar(_ target: StopTarget) -> some View {
        HStack(spacing: 8) {
            (Text("Stop \(target.name)? ").bold().foregroundColor(Theme.warnText)
                + Text("Unsaved work may be lost.").foregroundColor(Theme.warnBody))
                .font(.system(size: 12))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            PillButton(title: "Cancel") { confirming = nil }
            PillButton(title: "Stop", prominent: true) { stop(target) }
        }
        .padding(EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 10))
        .background(Theme.warnBackground)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button("Open Activity Monitor") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.amber)
            Spacer()
            if let count = sampler.snapshot?.rows.count, count > 0 {
                Text("Top \(count)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.secondary)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
    }

    // MARK: Actions

    private func toggle(_ id: String) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    private func stop(_ target: StopTarget) {
        confirming = nil
        handle(ProcessKiller.stop(target), for: target)
    }

    private func forceStop(_ target: StopTarget) {
        handle(ProcessKiller.forceStop(target), for: target)
    }

    private func stopAsAdmin(_ target: StopTarget) {
        handle(ProcessKiller.stopAsAdmin(target, force: false), for: target)
    }

    private func handle(_ outcome: ProcessKiller.Outcome, for target: StopTarget) {
        switch outcome {
        case .requested:
            needsAdmin.remove(target.id)
            stopRequested[target.id] = Date()
            message = nil
            // Refresh soon so a stopped process drops off the list quickly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { sampler.sample() }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.forceAfter + 0.2) { sampler.sample() }
        case .needsAdmin:
            needsAdmin.insert(target.id)
            message = "\(target.name) belongs to macOS or another user. Stopping it needs your password."
        case .failed(let text):
            message = text
        }
    }
}

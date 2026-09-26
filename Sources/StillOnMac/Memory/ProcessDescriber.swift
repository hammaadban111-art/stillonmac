import Foundation

/// Turns technical process and app names into a few plain words,
/// e.g. "qemu-system-aarch64" → "Emulator".
enum ProcessDescriber {
    private struct Rule {
        let label: String
        /// Receives the lowercased executable name and lowercased full path.
        let matches: (String, String) -> Bool
    }

    private static func named(_ names: String..., label: String) -> Rule {
        let set = Set(names)
        return Rule(label: label) { name, _ in set.contains(name) }
    }

    private static func prefixed(_ prefixes: String..., label: String) -> Rule {
        Rule(label: label) { name, _ in prefixes.contains { name.hasPrefix($0) } }
    }

    private static func nameContains(_ parts: String..., label: String) -> Rule {
        Rule(label: label) { name, _ in parts.contains { name.contains($0) } }
    }

    private static func pathContains(_ parts: String..., label: String) -> Rule {
        Rule(label: label) { _, path in parts.contains { path.contains($0) } }
    }

    /// First match wins, so more specific rules come first.
    private static let rules: [Rule] = [
        // Emulators and virtual machines
        prefixed("qemu-system", label: "Emulator"),
        pathContains("/android/sdk/emulator/", "/emulator/qemu/", label: "Android Emulator"),
        named("launchd_sim", label: "iPhone Simulator"),
        pathContains("coresimulator", label: "iPhone Simulator"),
        nameContains("virtualization.virtualmachine", "virtualmachine.xpc", label: "Virtual machine"),
        prefixed("com.docker", label: "Docker"),
        named("docker", "vpnkit", "dockerd", "containerd", label: "Docker"),

        // Browsers and Electron apps
        nameContains("helper (renderer)", label: "Browser tab"),
        nameContains("helper (gpu)", label: "Graphics helper"),
        nameContains("helper (plugin)", label: "Plugin"),
        named("com.apple.webkit.webcontent", label: "Web page"),
        named("com.apple.webkit.gpu", label: "Web graphics"),
        named("com.apple.webkit.networking", label: "Web downloads"),

        // Developer tools
        named("claude", label: "Claude Code"),
        named("node", label: "Node.js script"),
        named("deno", "bun", label: "JavaScript runtime"),
        prefixed("python", label: "Python script"),
        named("java", label: "Java app"),
        named("ruby", label: "Ruby script"),
        named("php", label: "PHP script"),
        named("swift-frontend", "swift-driver", "swift-build", label: "Swift compiler"),
        named("clang", "cc1", "ld", "ld64", label: "C compiler"),
        named("rustc", "cargo", "rust-analyzer", label: "Rust compiler"),
        named("sourcekitservice", "sourcekit-lsp", label: "Xcode code helper"),
        named("xcbbuildservice", label: "Xcode build"),
        nameContains("language_server", "languageserver", "tsserver", label: "Code helper"),
        named("git", label: "Git"),
        named("ssh", "sshd", label: "Remote login"),
        named("zsh", "bash", "sh", "fish", "login", label: "Terminal shell"),
        named("caffeinate", label: "Keep-awake"),
        named("stillonmac", label: "This app"),

        // macOS
        named("kernel_task", label: "macOS core"),
        named("launchd", label: "macOS starter"),
        named("windowserver", label: "Screen drawing"),
        prefixed("mds", "mdworker", "mdbulkimport", label: "Spotlight indexing"),
        named("corespotlightd", "spotlight", label: "Spotlight"),
        named("photoanalysisd", "mediaanalysisd", "photolibraryd", label: "Photos analysis"),
        named("backupd", "backupd-helper", label: "Time Machine"),
        named("bird", "cloudd", "fileproviderd", label: "iCloud sync"),
        named("softwareupdated", label: "Software update"),
        named("coreaudiod", label: "Sound"),
        named("loginwindow", label: "Login session"),
        named("dock", label: "Dock"),
        named("controlcenter", label: "Control Center"),
        named("systemuiserver", label: "Menu bar"),
        named("syspolicyd", "trustd", label: "Security check"),
        prefixed("xprotect", label: "Malware scan"),
        named("nsurlsessiond", label: "Background downloads"),
        named("logd", label: "System logs"),
        named("siriknowledged", "suggestd", "knowledge-agent", label: "Siri suggestions"),
        named("finder", label: "Finder"),
    ]

    private static let appLabels: [String: String] = [
        "com.apple.iphonesimulator": "iPhone Simulator",
        "com.google.android.studio": "Android Studio",
        "com.docker.docker": "Docker",
        "com.utmapp.utm": "Virtual machine",
        "com.parallels.desktop.console": "Virtual machine",
        "com.vmware.fusion": "Virtual machine",
        "com.apple.dt.xcode": "Xcode",
        "com.microsoft.vscode": "Code editor",
        "com.todesktop.230313mzl4w4u92": "Code editor",
        "com.apple.safari": "Web browser",
        "com.google.chrome": "Web browser",
        "org.mozilla.firefox": "Web browser",
        "company.thebrowser.browser": "Web browser",
        "com.brave.browser": "Web browser",
        "com.microsoft.edgemac": "Web browser",
        "com.apple.terminal": "Terminal",
        "com.googlecode.iterm2": "Terminal",
        "com.anthropic.claudefordesktop": "Claude app",
        "com.spotify.client": "Music",
        "com.apple.music": "Music",
        "com.tinyspeck.slackmacgap": "Chat app",
        "com.hnc.discord": "Chat app",
        "net.whatsapp.whatsapp": "Chat app",
        "us.zoom.xos": "Video call",
        "com.apple.mail": "Email",
        "com.apple.finder": "Finder",
        "com.apple.activitymonitor": "Activity Monitor",
    ]

    /// Plain-words label for a whole app.
    static func appLabel(bundleID: String?) -> String {
        guard let id = bundleID?.lowercased() else { return "App" }
        return appLabels[id] ?? "App"
    }

    /// Plain-words label for a single process.
    /// - Parameter appName: the app this process belongs to, if any.
    static func label(name: String, path: String, appName: String?) -> String {
        let lowerName = name.lowercased()
        let lowerPath = path.lowercased()
        if let rule = rules.first(where: { $0.matches(lowerName, lowerPath) }) {
            return rule.label
        }
        if let appName = appName {
            return "Part of \(appName)"
        }
        if let bundle = enclosingAppName(path) {
            return "Part of \(bundle)"
        }
        let systemPrefixes = ["/system/", "/usr/libexec/", "/usr/sbin/", "/sbin/", "/library/apple/"]
        if systemPrefixes.contains(where: { lowerPath.hasPrefix($0) }) {
            return "macOS service"
        }
        return "Background process"
    }

    /// "…/Foo.app/Contents/MacOS/bar" → "Foo".
    private static func enclosingAppName(_ path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return nil }
        let bundlePath = path[..<range.lowerBound]
        return bundlePath.split(separator: "/").last.map(String.init)
    }
}

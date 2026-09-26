import Foundation

enum Format {
    /// "2d 4h", "3h 12m", "7m", "<1m".
    static func duration(seconds: Int) -> String {
        let seconds = max(0, seconds)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }

    static func duration(since date: Date) -> String {
        duration(seconds: Int(Date().timeIntervalSince(date)))
    }

    /// "2.1 GB", "640 MB".
    static func bytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        return "\(max(1, Int((Double(bytes) / 1_048_576).rounded()))) MB"
    }
}

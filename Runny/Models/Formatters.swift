import Foundation

enum Fmt {
    static func unitMeters(metric: Bool) -> Double { metric ? 1000 : 1609.344 }

    /// "24:31" or "1:02:11"
    static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "5.02"
    static func distance(_ meters: Double, metric: Bool) -> String {
        String(format: "%.2f", meters / unitMeters(metric: metric))
    }

    /// "12.4" — one decimal, for dashboard numbers.
    static func distanceShort(_ meters: Double, metric: Bool) -> String {
        String(format: "%.1f", meters / unitMeters(metric: metric))
    }

    static func distanceUnit(metric: Bool) -> String { metric ? "km" : "mi" }

    /// "5:24" from seconds-per-unit, or "--:--" when unavailable.
    static func pace(_ secondsPerUnit: TimeInterval?) -> String {
        guard let p = secondsPerUnit, p.isFinite, p > 0, p < 5400 else { return "--:--" }
        let s = Int(p.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func paceUnit(metric: Bool) -> String { metric ? "/km" : "/mi" }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy · HH:mm"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }
    static func shortDate(_ date: Date) -> String { shortDateFormatter.string(from: date) }
    static func month(_ date: Date) -> String { monthFormatter.string(from: date) }
    static func weekday(_ date: Date) -> String { weekdayFormatter.string(from: date).uppercased() }
}
